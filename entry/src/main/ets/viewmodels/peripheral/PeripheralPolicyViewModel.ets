/**
 * 外设策略 ViewModel
 */
import { Observed } from '@kit.ArkUI'
import { PeripheralViewModelBase } from './PeripheralViewModelBase'
import { PeripheralService } from '../../services/PeripheralService'
import { PeripheralPolicyRecord, PeripheralBlacklistTemplate, PeripheralWhitelistCandidate, PeripheralCandidateSource, PeripheralType, usbManager, parseUsbDeviceId, parseBluetoothMac, formatUsbDeviceId, inferUsbBaseClass, inferPeripheralTypeFromBaseClass } from '../../models/DataModels'

@Observed
export class PeripheralPolicyViewModel extends PeripheralViewModelBase {
  @Observed usbWhitelist: usbManager.UsbDeviceId[] = []
  @Observed usbBlacklist: usbManager.UsbDeviceType[] = []
  @Observed btWhitelist: string[] = []
  @Observed connectedUsbDevices: usbManager.USBDevice[] = []
  @Observed policyRecords: PeripheralPolicyRecord[] = []
  @Observed policyUpdatingKeys: string[] = []
  @Observed renderVersion: number = 0
  @Observed isExporting: boolean = false

  protected async onInitialize(): Promise<void> { await this.reloadAllData() }

  async reloadAllData(): Promise<void> {
    this.isLoading = true
    try {
      this.usbWhitelist = PeripheralService.getUsbWhitelistWithResult().data ?? []
      this.usbBlacklist = PeripheralService.getUsbBlacklistWithResult().data ?? []
      this.btWhitelist = PeripheralService.getBluetoothWhitelistWithResult().data ?? []
      this.loadPeripheralPolicyData()
      this.renderVersion++
    } finally { this.isLoading = false }
  }

  loadConnectedUsbDevices(): void { this.connectedUsbDevices = [] }
  async addToUsbWhitelist(vendorId: number, productId: number): Promise<boolean> {
    if (!this.ensureAdminReady('添加到 USB 白名单')) return false
    const result = PeripheralService.addUsbWhitelistWithResult([{ vendorId, productId }])
    if (result.success) await this.reloadAllData()
    else this.handleOperationResult(false, '添加到 USB 白名单', result.error)
    return result.success
  }
  async addToBluetoothWhitelist(mac: string): Promise<boolean> {
    if (!this.ensureAdminReady('添加到蓝牙白名单')) return false
    const result = PeripheralService.addBluetoothWhitelistWithResult([mac])
    if (result.success) await this.reloadAllData()
    else this.handleOperationResult(false, '添加到蓝牙白名单', result.error)
    return result.success
  }
  async removeFromWhitelist(deviceType: PeripheralType, deviceId: string): Promise<boolean> {
    if (!this.ensureAdminReady('从白名单移除')) return false
    try {
      if (deviceType === PeripheralType.BLUETOOTH) { const mac = parseBluetoothMac(deviceId); if (!mac) throw new Error('Invalid MAC'); const result = PeripheralService.removeBluetoothWhitelistWithResult([mac]); if (result.success) { await this.reloadAllData(); return true }; this.handleOperationResult(false, '从蓝牙白名单移除', result.error) }
      else { const parsed = parseUsbDeviceId(deviceId); if (!parsed) throw new Error('Invalid USB ID'); const result = PeripheralService.removeUsbWhitelistWithResult([{ vendorId: parsed.vendorId, productId: parsed.productId }]); if (result.success) { await this.reloadAllData(); return true }; this.handleOperationResult(false, '从 USB 白名单移除', result.error) }
      return false
    } catch (err) { this.handleOperationResult(false, '从白名单移除', err); return false }
  }
  async addToUsbBlacklist(baseClass: number, subClass: number, protocol: number): Promise<boolean> {
    if (!this.ensureAdminReady('添加到 USB 黑名单')) return false
    const result = PeripheralService.addUsbBlacklistWithResult([{ baseClass, subClass, protocol }])
    if (result.success) await this.reloadAllData()
    else this.handleOperationResult(false, '添加到 USB 黑名单', result.error)
    return result.success
  }
  async exportPeripheralPolicyRecords(): Promise<boolean> {
    if (this.policyRecords.length === 0) { this.errorMessage = '没有可导出的策略记录'; return false }
    this.isExporting = true
    try { return true } catch (err) { this.handleOperationResult(false, '导出策略记录', err); return false } finally { this.isExporting = false }
  }
  getUsbWhitelistCandidates(): PeripheralWhitelistCandidate[] {
    const items: Map<string, PeripheralWhitelistCandidate> = new Map()
    const disabledKeys = this.usbWhitelist.map(d => formatUsbDeviceId(d.vendorId, d.productId).toUpperCase())
    for (const device of this.connectedUsbDevices) {
      const key = formatUsbDeviceId(device.vendorId, device.productId).toUpperCase()
      if (items.has(key)) continue
      items.set(key, { id: `usb_${key}`, deviceName: this.buildUsbDisplayName(device.manufacturerName, device.productName, device.vendorId, device.productId), deviceType: inferPeripheralTypeFromBaseClass(device.clazz), deviceId: formatUsbDeviceId(device.vendorId, device.productId), timestamp: Date.now(), source: PeripheralCandidateSource.CONNECTED_USB, vendorId: device.vendorId, productId: device.productId, isConnected: true, disabled: disabledKeys.includes(key) })
    }
    return Array.from(items.values())
  }
  getBluetoothWhitelistCandidates(): PeripheralWhitelistCandidate[] { return [] }
  getUsbBlacklistTemplates(): PeripheralBlacklistTemplate[] {
    const disabledKeys = this.usbBlacklist.map(i => `${i.baseClass}_${i.subClass}_${i.protocol}`.toUpperCase())
    const templates = [{ title: 'USB 存储', description: 'U 盘等', baseClass: 8 }, { title: 'USB 输入', description: '键盘鼠标', baseClass: 3 }, { title: 'USB 音频', description: '麦克风等', baseClass: 1 }, { title: 'USB 视频', description: '摄像头', baseClass: 14 }, { title: 'USB 打印机', description: '打印机', baseClass: 7 }, { title: 'USB 网卡', description: '网卡', baseClass: 2 }]
    return templates.filter(t => !disabledKeys.includes(`${t.baseClass}_0_0`.toUpperCase())).map(t => ({ ...t, subClass: 0, protocol: 0 }))
  }
  private loadPeripheralPolicyData(): void {
    const records: PeripheralPolicyRecord[] = []
    for (const d of this.usbWhitelist) records.push({ deviceName: `USB (${formatUsbDeviceId(d.vendorId, d.productId)})`, deviceType: PeripheralType.USB_OTHER, deviceId: formatUsbDeviceId(d.vendorId, d.productId), policyHit: 'whitelist', source: 'manual', action: 'allow', timestamp: Date.now() })
    for (const mac of this.btWhitelist) records.push({ deviceName: `蓝牙 (${mac})`, deviceType: PeripheralType.BLUETOOTH, deviceId: `MAC: ${mac}`, policyHit: 'whitelist', source: 'manual', action: 'allow', timestamp: Date.now() })
    this.policyRecords = records
  }
  private buildUsbDisplayName(manufacturer?: string, product?: string, vendorId?: number, productId?: number): string {
    const m = manufacturer?.trim() || '', p = product?.trim() || ''
    if (m && p) return `${m} ${p}`; if (m) return m; if (p) return p
    if (typeof vendorId === 'number' && typeof productId === 'number') return `USB (${formatUsbDeviceId(vendorId, productId)})`
    return 'USB Device'
  }
}
