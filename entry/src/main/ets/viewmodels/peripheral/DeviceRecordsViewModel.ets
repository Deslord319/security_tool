/**
 * 设备记录 ViewModel
 */
import { Observed } from '@kit.ArkUI'
import { PeripheralViewModelBase } from './PeripheralViewModelBase'
import { PeripheralConnectionRecordService } from '../../services/PeripheralConnectionRecordService'
import { PeripheralTraceRepository } from '../../services/PeripheralTraceRepository'
import { PeripheralConnectionRecord, LogExportFormat, formatLogTimestamp, getPeripheralRecordActionLabel, getPeripheralRecordPolicyHitLabel, getPeripheralRecordSourceLabel } from '../../models/DataModels'
import { LogStorageService } from '../../services/LogStorageService'

export interface ConnectionHistoryItem { time: string; policy: string; result: string }

@Observed
export class DeviceRecordsViewModel extends PeripheralViewModelBase {
  @Observed deviceRecords: PeripheralConnectionRecord[] = []
  @Observed selectedRecord: PeripheralConnectionRecord | null = null
  @Observed isDetailVisible: boolean = false
  @Observed detailHostWidth: number = 0
  @Observed isExporting: boolean = false
  private traceStorageListenerId: number = -1

  protected async onInitialize(): Promise<void> { await this.reloadRecords(); this.subscribeTraceStorageChange() }
  protected onDestroy(): void { this.unsubscribeTraceStorageChange() }
  reloadRecords(): void { try { this.deviceRecords = PeripheralConnectionRecordService.queryRecords() } catch (err) { this.handleOperationResult(false, '加载设备记录', err) } }
  openConnectionDetailDialog(record: PeripheralConnectionRecord): void { this.selectedRecord = record; this.isDetailVisible = true }
  closeConnectionDetailDialog(): void { this.isDetailVisible = false; this.selectedRecord = null }
  async exportConnectionHistory(): Promise<boolean> {
    if (this.deviceRecords.length === 0) { this.errorMessage = '没有可导出的记录'; return false }
    this.isExporting = true
    try { if (!this.context) throw new Error('Context not initialized'); await LogStorageService.init(this.context); const csv = this.buildConnectionHistoryCsvV2(this.deviceRecords); const result = await LogStorageService.exportContentToFile(csv, LogExportFormat.CSV, 'manual', { fileNamePrefix: 'peripheral_connection_history', count: this.deviceRecords.length, emptyErrorMessage: '无可导出记录' }); return result.success }
    catch (err) { this.handleOperationResult(false, '导出失败', err); return false }
    finally { this.isExporting = false }
  }
  getConnectionHistoryItems(record: PeripheralConnectionRecord | null): ConnectionHistoryItem[] { if (!record) return []; return [{ time: formatLogTimestamp(record.timestamp), policy: getPeripheralRecordPolicyHitLabel(record.policyHit), result: record.result === 'success' ? '成功' : '失败' }] }
  formatConnectionTime(record: PeripheralConnectionRecord): string { return formatLogTimestamp(record.timestamp) }
  normalizeConnectionDetailValue(value: string | null): string { return value || '未知' }
  getConnectionEventLabel(record: PeripheralConnectionRecord | null): string { return record ? getPeripheralRecordActionLabel(record.action) : '' }
  private subscribeTraceStorageChange(): void { this.unsubscribeTraceStorageChange(); this.traceStorageListenerId = PeripheralTraceRepository.addChangeListener(() => this.reloadRecords()) }
  private unsubscribeTraceStorageChange(): void { if (this.traceStorageListenerId > 0) PeripheralTraceRepository.removeChangeListener(this.traceStorageListenerId) }
  private buildConnectionHistoryCsvV2(records: PeripheralConnectionRecord[]): string { const lines = ['时间，设备类型，设备标识，事件，来源，策略匹配，结果']; for (const r of records) lines.push([formatLogTimestamp(r.timestamp), this.getPeripheralTypeLabel(r.deviceType), r.deviceId, getPeripheralRecordActionLabel(r.action), getPeripheralRecordSourceLabel(r.source), getPeripheralRecordPolicyHitLabel(r.policyHit), r.result === 'success' ? '成功' : '失败'].join(',')); return lines.join('\n') }
  private getPeripheralTypeLabel(type: number): string { const map: Record<number, string> = { 0: 'USB 存储', 1: 'USB 输入', 2: 'USB 音频', 3: 'USB 视频', 4: 'USB 打印机', 5: 'USB 网卡', 6: '其他 USB', 7: '蓝牙' }; return map[type] || '未知' }
}
