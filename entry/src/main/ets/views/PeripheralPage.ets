import { AppColors, AppStyles } from '../constants/AppConstants'
import { PeripheralService } from '../services/PeripheralService'
import { PeripheralConnectionRecordService } from '../services/PeripheralConnectionRecordService'
import { LogStorageService } from '../services/LogStorageService'
import { PeripheralTraceRepository } from '../services/PeripheralTraceRepository'
import { PeripheralRuntimeEventService } from '../services/PeripheralRuntimeEventService'
import { InterfaceControlItem } from '../components/InterfaceControlItem'
import { AddWhitelistDialog } from '../components/AddWhitelistDialog'
import { AddBlacklistDialog } from '../components/AddBlacklistDialog'
import {
  AdminActivationState,
  DeviceRecord,
  DeviceControlRecord,
  PeripheralConnectionFilter,
  PeripheralConnectionRecord,
  OperationResult,
  PeripheralType,
  LogEventResult,
  formatLogTimestamp,
  getLogEventResultLabel,
  getPeripheralRecordActionLabel,
  getPeripheralRecordPolicyHitLabel,
  getPeripheralRecordSourceLabel,
  getPeripheralTypeLabel,
  ParsedUsbId,
  parseUsbDeviceId,
  parseBluetoothMac,
  formatUsbDeviceId,
  inferUsbBaseClass,
  inferPeripheralTypeFromBaseClass
} from '../models/DataModels'
import { usbManager } from '@kit.MDMKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { promptAction } from '@kit.ArkUI'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { EnterpriseAdminService } from '../services/EnterpriseAdminService'
import { BackNavButton } from '../components/BackNavButton'
import { HoverUtils } from '../utils/HoverUtils'
import { FormControlUtils } from '../utils/FormControlUtils'

const TAG = 'PeripheralPage'
type PeripheralResultData =
  boolean |
  number |
  string |
  usbManager.UsbPolicy |
  usbManager.UsbDeviceId[] |
  usbManager.UsbDeviceType[] |
  void

@Component
export struct PeripheralPage {
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onBack: () => void = () => {}
  @State currentTab: number = 0
  @State hoveredPanelIndex: number = -1
  @State hoveredDeviceRecordIndex: number = -1
  @State isLoading: boolean = false
  @State adminState: AdminActivationState = {
    activated: false,
    enableCommand: EnterpriseAdminService.buildEnableCommand(),
    adminType: EnterpriseAdminService.DEFAULT_ADMIN_TYPE
  }

  // 接口管控状态
  @State usbDisabled: boolean = false
  @State btDisabled: boolean = false
  @State wifiDisabled: boolean = false
  @State hdcDisabled: boolean = false
  @State usbStoragePolicyIndex: number = 0

  // 黑白名单数据
  @State usbWhitelist: usbManager.UsbDeviceId[] = []
  @State usbBlacklist: usbManager.UsbDeviceType[] = []
  @State btWhitelist: string[] = []

  // 设备连接记录（本地模拟数据）
  @State deviceRecords: PeripheralConnectionRecord[] = []
  @State recordFilterTypeIndex: number = 0
  @State recordFilterResultIndex: number = 0
  @State recordFilterSourceIndex: number = 1
  @State recordFilterKeyword: string = ''
  @State recordHintMessage: string = ''
  private recordStorageListenerId: number = -1
  private traceStorageListenerId: number = -1
  private recordAutoRefreshTimerId: number = -1
  private readonly recordAutoRefreshIntervalMs: number = 2000
  private readonly recordTypeFilterOptions: SelectOption[] = [
    { value: '全部类型' },
    { value: 'USB' },
    { value: '蓝牙' }
  ]
  private readonly recordResultFilterOptions: SelectOption[] = [
    { value: '全部结果' },
    { value: '成功' },
    { value: '已阻止' },
    { value: '失败' }
  ]
  private readonly recordSourceFilterOptions: SelectOption[] = [
    { value: '全部来源' },
    { value: '实时事件' },
    { value: '仅运行时' },
    { value: '仅审计' },
    { value: '仅快照' }
  ]
  private readonly usbRecordTypes: PeripheralType[] = [
    PeripheralType.USB_STORAGE,
    PeripheralType.USB_CAMERA,
    PeripheralType.USB_PRINTER,
    PeripheralType.USB_OTHER
  ]

  // 设备管控记录（独立数据源）
  @State deviceControlRecords: DeviceControlRecord[] = []
  private deviceControlPolicyOptions: SelectOption[] = [
    { value: '允许' },
    { value: '禁止' },
    { value: '未配置' }
  ]
  // 弹窗控制器
  private usbWhitelistDialogController: CustomDialogController = new CustomDialogController({
    builder: AddWhitelistDialog({
      mode: 'usb',
      onConfirmUsb: (vendorId: number, productId: number, _remark: string) => {
        this.handleAddUsbWhitelist(vendorId, productId)
      }
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  })

  private btWhitelistDialogController: CustomDialogController = new CustomDialogController({
    builder: AddWhitelistDialog({
      mode: 'bluetooth',
      onConfirmBluetooth: (mac: string, _remark: string) => {
        this.handleAddBluetoothWhitelist(mac)
      }
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  })

  private blacklistDialogController: CustomDialogController = new CustomDialogController({
    builder: AddBlacklistDialog({
      onConfirm: (baseClass: number, subClass: number, protocol: number, _desc: string) => {
        this.handleAddUsbBlacklist(baseClass, subClass, protocol)
      }
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  })

  aboutToAppear() {
    this.refreshAdminActivationState()
    this.loadAllData()
    this.subscribeRecordStorageChange()
    this.subscribeTraceStorageChange()
    this.startRecordAutoRefresh()
  }

  aboutToDisappear() {
    this.unsubscribeRecordStorageChange()
    this.unsubscribeTraceStorageChange()
    this.stopRecordAutoRefresh()
  }

  private subscribeRecordStorageChange(): void {
    this.unsubscribeRecordStorageChange()
    this.recordStorageListenerId = LogStorageService.addChangeListener(() => {
      this.reloadDeviceRecords()
    })
  }

  private unsubscribeRecordStorageChange(): void {
    if (this.recordStorageListenerId < 0) {
      return
    }
    LogStorageService.removeChangeListener(this.recordStorageListenerId)
    this.recordStorageListenerId = -1
  }

  private subscribeTraceStorageChange(): void {
    this.unsubscribeTraceStorageChange()
    this.traceStorageListenerId = PeripheralTraceRepository.addChangeListener(() => {
      this.reloadDeviceRecords()
    })
  }

  private unsubscribeTraceStorageChange(): void {
    if (this.traceStorageListenerId < 0) {
      return
    }
    PeripheralTraceRepository.removeChangeListener(this.traceStorageListenerId)
    this.traceStorageListenerId = -1
  }
  private startRecordAutoRefresh(): void {
    this.stopRecordAutoRefresh()
    this.recordAutoRefreshTimerId = setInterval(() => {
      this.reloadDeviceRecords()
    }, this.recordAutoRefreshIntervalMs)
  }

  private stopRecordAutoRefresh(): void {
    if (this.recordAutoRefreshTimerId < 0) {
      return
    }
    clearInterval(this.recordAutoRefreshTimerId)
    this.recordAutoRefreshTimerId = -1
  }

  private buildRecordFilter(): PeripheralConnectionFilter {
    let filter: PeripheralConnectionFilter = {}
    if (this.recordFilterTypeIndex === 1) {
      filter.deviceTypes = this.usbRecordTypes
    } else if (this.recordFilterTypeIndex === 2) {
      filter.deviceTypes = [PeripheralType.BLUETOOTH]
    }

    if (this.recordFilterResultIndex > 0) {
      let resultMap: LogEventResult[] = [
        LogEventResult.SUCCESS,
        LogEventResult.BLOCKED,
        LogEventResult.FAILED
      ]
      filter.results = [resultMap[this.recordFilterResultIndex - 1]]
    }

    if (this.recordFilterSourceIndex === 1) {
      filter.sources = ['runtime_event', 'audit_event']
    } else if (this.recordFilterSourceIndex === 2) {
      filter.sources = ['runtime_event']
    } else if (this.recordFilterSourceIndex === 3) {
      filter.sources = ['audit_event']
    } else if (this.recordFilterSourceIndex === 4) {
      filter.sources = ['policy_snapshot']
    }

    let keyword = this.recordFilterKeyword.trim()
    if (keyword.length > 0) {
      filter.keyword = keyword
    }
    return filter
  }

  private reloadDeviceRecords(): void {
    this.deviceRecords = PeripheralConnectionRecordService.queryRecords(this.buildRecordFilter())
    let hasRealtime = this.deviceRecords.some((record: PeripheralConnectionRecord) => {
      return record.source === 'runtime_event' || record.source === 'audit_event'
    })
    let hasSnapshot = this.deviceRecords.some((record: PeripheralConnectionRecord) => record.source === 'policy_snapshot')
    let runtimeHint = this.buildRuntimeDegradeHint()

    if (this.deviceRecords.length === 0) {
      this.recordHintMessage = runtimeHint
      return
    }

    if (!hasRealtime && hasSnapshot) {
      this.recordHintMessage = runtimeHint.length > 0
        ? runtimeHint + ' 当前仅展示策略快照，时间范围内暂无实时连接或审计事件。'
        : '当前仅展示策略快照，时间范围内暂无实时连接或审计事件。'
      return
    }

    if (hasRealtime && hasSnapshot) {
      this.recordHintMessage = runtimeHint.length > 0
        ? runtimeHint + ' 已展示实时事件，快照记录仅用于策略参考。'
        : '已展示实时事件，快照记录仅用于策略参考。'
      return
    }

    this.recordHintMessage = runtimeHint
  }

  private buildRuntimeDegradeHint(): string {
    let runtimeStatus = PeripheralRuntimeEventService.getStatus()
    if (runtimeStatus.capabilities.usbRuntimeEvents) {
      return ''
    }
    return '当前版本未启用运行时采集，已使用审计事件和策略快照。'
  }
  private refreshAdminActivationState(): void {
    this.adminState = EnterpriseAdminService.probeActivation()
  }

  private ensureAdminReady(action: string): boolean {
    this.refreshAdminActivationState()
    if (this.adminState.activated) {
      return true
    }
    let reasonText: string = this.adminState.errorMessage || '企业管理员未激活'
    let codeText: string = this.adminState.errorCode !== undefined ? ' (' + this.adminState.errorCode + ')' : ''
    promptAction.showToast({ message: action + '不可用：' + reasonText + codeText })
    return false
  }

  private showOperationFailure(action: string, result: OperationResult<PeripheralResultData>): void {
    if (result.isAdminMissing) {
      let reasonText: string = result.errorMessage || '企业管理员未激活'
      let codeText: string = result.errorCode !== undefined ? ' (' + result.errorCode + ')' : ''
      promptAction.showToast({ message: action + '失败：' + reasonText + codeText })
      return
    }
    let codeText: string = result.errorCode !== undefined ? '错误码：' + result.errorCode + '\n' : ''
    let reasonText: string = result.errorMessage || (action + '失败')
    let suggestionText: string = result.suggestion || '请检查权限声明、签名模板和策略激活状态后重试。'
    AlertDialog.show({
      title: action + '失败',
      message: codeText + '原因：' + reasonText + '\n建议：' + suggestionText,
      primaryButton: { value: '关闭', action: (): void => {} }
    })
  }

  loadAllData() {
    this.isLoading = true
    this.refreshAdminActivationState()

    if (this.adminState.activated) {
      // 加载接口管控状态
      let usbState = PeripheralService.getInterfaceDisabledWithResult('usb')
      let btState = PeripheralService.getInterfaceDisabledWithResult('bluetooth')
      let wifiState = PeripheralService.getInterfaceDisabledWithResult('wifi')
      let hdcState = PeripheralService.getInterfaceDisabledWithResult('hdc')
      this.usbDisabled = usbState.data ?? false
      this.btDisabled = btState.data ?? false
      this.wifiDisabled = wifiState.data ?? false
      this.hdcDisabled = hdcState.data ?? false

      // 加载 USB 存储策略
      let policyResult = PeripheralService.getUsbStoragePolicyWithResult()
      let policy = policyResult.data ?? usbManager.UsbPolicy.READ_WRITE
      if (policy === usbManager.UsbPolicy.READ_ONLY) {
        this.usbStoragePolicyIndex = 0
      } else if (policy === usbManager.UsbPolicy.READ_WRITE) {
        this.usbStoragePolicyIndex = 1
      } else {
        this.usbStoragePolicyIndex = 2
      }

      // 加载黑白名单
      this.usbWhitelist = PeripheralService.getUsbWhitelistWithResult().data ?? []
      this.usbBlacklist = PeripheralService.getUsbBlacklistWithResult().data ?? []
      this.btWhitelist = PeripheralService.getBluetoothWhitelistWithResult().data ?? []
    } else {
      this.usbDisabled = false
      this.btDisabled = false
      this.wifiDisabled = false
      this.hdcDisabled = false
      this.usbStoragePolicyIndex = 1
      this.usbWhitelist = []
      this.usbBlacklist = []
      this.btWhitelist = []
    }

    // 模拟设备连接记录
    this.reloadDeviceRecords()
    /*
      {
        deviceName: 'ShineOptics FHD Camera',
        deviceType: PeripheralType.USB_CAMERA,
        deviceId: 'VID:2B7E PID:B5A2',
        connectTime: '2026-02-09 16:01:19',
        policy: '允许'
      },
      {
        deviceName: 'SanDisk Ultra USB 3.0',
        deviceType: PeripheralType.USB_STORAGE,
        deviceId: 'VID:0781 PID:5583',
        connectTime: '2026-02-09 14:30:08',
        policy: '拒绝'
      },
      {
        deviceName: 'HP LaserJet Pro M404',
        deviceType: PeripheralType.USB_PRINTER,
        deviceId: 'VID:03F0 PID:0C17',
        connectTime: '2026-02-09 10:15:42',
        policy: '允许'
      },
      {
        deviceName: 'Logitech MX Keys',
        deviceType: PeripheralType.BLUETOOTH,
        deviceId: 'MAC: AA:BB:CC:DD:EE:01',
        connectTime: '2026-02-09 09:00:05',
        policy: '允许'
      }
    ]
    */

    // 从 MDM API 加载设备管控记录
    if (this.adminState.activated) {
      this.loadDeviceControlData()
    } else {
      this.deviceControlRecords = []
    }

    this.isLoading = false
  }

  // ========== 设备管控数据加载 ==========

  // 常见设备 VID/PID -> 名称映射
  private static USB_DEVICE_NAMES: Map<string, string> = new Map([
    ['2B7E_B5A2', 'ShineOptics FHD Camera'],
    ['0781_5583', 'SanDisk Ultra USB 3.0'],
    ['03F0_0C17', 'HP LaserJet Pro M404'],
    ['046D_C52B', 'Logitech Unifying Receiver'],
    ['8087_0026', 'Intel Wireless Bluetooth'],
    ['0BDA_8153', 'Realtek USB Ethernet'],
  ])

  private static BT_DEVICE_NAMES: Map<string, string> = new Map([
    ['AA:BB:CC:DD:EE:01', 'Logitech MX Keys'],
  ])

  inferUsbDeviceName(vendorId: number, productId: number): string {
    let key = `${vendorId.toString(16).toUpperCase().padStart(4, '0')}_${productId.toString(16).toUpperCase().padStart(4, '0')}`
    let name = PeripheralPage.USB_DEVICE_NAMES.get(key)
    if (name) {
      return name
    }
    return `USB 设备 (${formatUsbDeviceId(vendorId, productId)})`
  }

  inferBluetoothDeviceName(mac: string): string {
    let name = PeripheralPage.BT_DEVICE_NAMES.get(mac)
    if (name) {
      return name
    }
    return `蓝牙设备 (${mac})`
  }

  loadDeviceControlData() {
    let records: DeviceControlRecord[] = []

    // 1. 从 USB 白名单加载（策略=允许）
    let usbWhitelist = PeripheralService.getUsbWhitelistWithResult().data ?? []
    for (let device of usbWhitelist) {
      records.push({
        deviceName: this.inferUsbDeviceName(device.vendorId, device.productId),
        deviceType: PeripheralType.USB_OTHER,
        deviceId: formatUsbDeviceId(device.vendorId, device.productId),
        connectTime: '--',
        policyIndex: 0
      })
    }

    // 2. 尝试从 USB 黑名单推断设备类型并更新已有记录
    let usbBlacklist = PeripheralService.getUsbBlacklistWithResult().data ?? []
    for (let deviceType of usbBlacklist) {
      let peripheralType = inferPeripheralTypeFromBaseClass(deviceType.baseClass)
      // 更新匹配设备的类型
      for (let i = 0; i < records.length; i++) {
        if (records[i].deviceType === PeripheralType.USB_OTHER) {
          // 暂保留 USB_OTHER，后续可扩展
        }
      }
    }

    // 3. 从蓝牙白名单加载（策略=允许）
    let btWhitelist = PeripheralService.getBluetoothWhitelistWithResult().data ?? []
    for (let mac of btWhitelist) {
      records.push({
        deviceName: this.inferBluetoothDeviceName(mac),
        deviceType: PeripheralType.BLUETOOTH,
        deviceId: `MAC: ${mac}`,
        connectTime: '--',
        policyIndex: 0
      })
    }

    this.deviceControlRecords = records
    hilog.info(0x0002, TAG, `loadDeviceControlData: ${records.length} devices loaded`)
  }

  // ========== 接口管控操作 ==========

  handleInterfaceToggle(feature: string, disallow: boolean) {
    if (!this.ensureAdminReady('接口管控')) {
      return
    }

    let result = PeripheralService.setInterfaceDisabledWithResult(feature, disallow)
    if (result.success) {
      if (feature === 'usb') this.usbDisabled = disallow
      else if (feature === 'bluetooth') this.btDisabled = disallow
      else if (feature === 'wifi') this.wifiDisabled = disallow
      else if (feature === 'hdc') this.hdcDisabled = disallow
      try {
        let featureLabel = this.getInterfaceFeatureLabel(feature)
        promptAction.showToast({ message: featureLabel + (disallow ? '已禁用' : '已启用') })
      } catch (e) {
        hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
      }
    } else {
      this.showOperationFailure('接口管控', result)
    }
  }

  private getInterfaceFeatureLabel(feature: string): string {
    if (feature === 'usb') {
      return 'USB 接口'
    }
    if (feature === 'bluetooth') {
      return '蓝牙接口'
    }
    if (feature === 'wifi') {
      return 'Wi-Fi 接口'
    }
    if (feature === 'hdc') {
      return 'HDC 调试接口'
    }
    return feature
  }

  handleUsbStoragePolicyChange(index: number) {
    if (!this.ensureAdminReady('设置 USB 存储策略')) {
      return
    }
    let policyMap: usbManager.UsbPolicy[] = [
      usbManager.UsbPolicy.READ_ONLY,
      usbManager.UsbPolicy.READ_WRITE,
      usbManager.UsbPolicy.DISABLED
    ]
    let result = PeripheralService.setUsbStoragePolicyWithResult(policyMap[index])
    if (result.success) {
      this.usbStoragePolicyIndex = index
      try {
        promptAction.showToast({ message: 'USB 存储策略已更新' })
      } catch (e) {
        hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
      }
      return
    }
    this.showOperationFailure('设置 USB 存储策略', result)
  }

  // ========== 白名单操作 ==========

  handleAddUsbWhitelist(vendorId: number, productId: number) {
    if (!this.ensureAdminReady('添加 USB 白名单')) {
      return
    }
    let device: usbManager.UsbDeviceId = { vendorId: vendorId, productId: productId }
    let result = PeripheralService.addUsbWhitelistWithResult([device])
    if (result.success) {
      this.usbWhitelist = PeripheralService.getUsbWhitelistWithResult().data ?? []
      this.reloadDeviceRecords()
      try {
        promptAction.showToast({ message: 'USB 白名单已添加' })
      } catch (e) {
        hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
      }
    } else {
      this.showOperationFailure('添加 USB 白名单', result)
    }
  }

  handleRemoveUsbWhitelist(device: usbManager.UsbDeviceId) {
    if (!this.ensureAdminReady('移除 USB 白名单')) {
      return
    }
    let result = PeripheralService.removeUsbWhitelistWithResult([device])
    if (result.success) {
      this.usbWhitelist = PeripheralService.getUsbWhitelistWithResult().data ?? []
      this.reloadDeviceRecords()
      try {
        promptAction.showToast({ message: 'USB 白名单项已移除' })
      } catch (e) {
        hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
      }
      return
    }
    this.showOperationFailure('移除 USB 白名单', result)
  }

  handleAddBluetoothWhitelist(mac: string) {
    if (!this.ensureAdminReady('添加蓝牙白名单')) {
      return
    }
    let result = PeripheralService.addBluetoothWhitelistWithResult([mac])
    if (result.success) {
      this.btWhitelist = PeripheralService.getBluetoothWhitelistWithResult().data ?? []
      this.reloadDeviceRecords()
      try {
        promptAction.showToast({ message: '蓝牙白名单已添加' })
      } catch (e) {
        hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
      }
    } else {
      this.showOperationFailure('添加蓝牙白名单', result)
    }
  }

  handleRemoveBluetoothWhitelist(mac: string) {
    if (!this.ensureAdminReady('移除蓝牙白名单')) {
      return
    }
    let result = PeripheralService.removeBluetoothWhitelistWithResult([mac])
    if (result.success) {
      this.btWhitelist = PeripheralService.getBluetoothWhitelistWithResult().data ?? []
      this.reloadDeviceRecords()
      try {
        promptAction.showToast({ message: '蓝牙白名单项已移除' })
      } catch (e) {
        hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
      }
      return
    }
    this.showOperationFailure('移除蓝牙白名单', result)
  }

  // ========== 黑名单操作 ==========

  handleAddUsbBlacklist(baseClass: number, subClass: number, protocol: number) {
    if (!this.ensureAdminReady('添加 USB 黑名单')) {
      return
    }
    let deviceType: usbManager.UsbDeviceType = {
      baseClass: baseClass,
      subClass: subClass,
      protocol: protocol,
      descriptor: usbManager.Descriptor.INTERFACE
    }
    let result = PeripheralService.addUsbBlacklistWithResult([deviceType])
    if (result.success) {
      this.usbBlacklist = PeripheralService.getUsbBlacklistWithResult().data ?? []
      this.reloadDeviceRecords()
      try {
        promptAction.showToast({ message: 'USB 黑名单已添加' })
      } catch (e) {
        hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
      }
    } else {
      this.showOperationFailure('添加 USB 黑名单', result)
    }
  }

  handleRemoveUsbBlacklist(deviceType: usbManager.UsbDeviceType) {
    if (!this.ensureAdminReady('移除 USB 黑名单')) {
      return
    }
    let result = PeripheralService.removeUsbBlacklistWithResult([deviceType])
    if (result.success) {
      this.usbBlacklist = PeripheralService.getUsbBlacklistWithResult().data ?? []
      this.reloadDeviceRecords()
      try {
        promptAction.showToast({ message: 'USB 黑名单项已移除' })
      } catch (e) {
        hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
      }
      return
    }
    this.showOperationFailure('移除 USB 黑名单', result)
  }

  // ========== 设备管控操作 ==========

  handleDeviceControlPolicyChange(recordIndex: number, policyIndex: number) {
    if (!this.ensureAdminReady('修改设备管控策略')) {
      return
    }
    let record = this.deviceControlRecords[recordIndex]
    let success = false
    let failedResult: OperationResult<PeripheralResultData> | undefined = undefined
    let policyLabels: string[] = ['允许', '禁止', '未配置']

    if (record.deviceType === PeripheralType.BLUETOOTH) {
      // 蓝牙设备策略变更
      let mac = parseBluetoothMac(record.deviceId)
      if (!mac) {
        hilog.error(0x0002, TAG, `parseBluetoothMac failed: ${record.deviceId}`)
        return
      }
      if (policyIndex === 0) {
        let result = PeripheralService.addBluetoothWhitelistWithResult([mac])
        success = result.success
        if (!result.success) {
          failedResult = result
        }
      } else {
        let result = PeripheralService.removeBluetoothWhitelistWithResult([mac])
        success = result.success
        if (!result.success) {
          failedResult = result
        }
      }
    } else {
      // USB 设备策略变更
      let parsed = parseUsbDeviceId(record.deviceId)
      if (!parsed) {
        hilog.error(0x0002, TAG, `parseUsbDeviceId failed: ${record.deviceId}`)
        return
      }
      let device: usbManager.UsbDeviceId = {
        vendorId: parsed.vendorId,
        productId: parsed.productId
      }
      if (policyIndex === 0) {
        // 允许：加入白名单
        let result = PeripheralService.addUsbWhitelistWithResult([device])
        success = result.success
        if (!result.success) {
          failedResult = result
        }
      } else if (policyIndex === 1) {
        // 禁用：从白名单移除 + 按类型加入黑名单
        let removeResult = PeripheralService.removeUsbWhitelistWithResult([device])
        if (!removeResult.success) {
          failedResult = removeResult
        }
        let baseClass = inferUsbBaseClass(record.deviceType)
        if (baseClass > 0) {
          let deviceType: usbManager.UsbDeviceType = {
            baseClass: baseClass,
            subClass: 0,
            protocol: 0,
            descriptor: usbManager.Descriptor.INTERFACE
          }
          let addBlackResult = PeripheralService.addUsbBlacklistWithResult([deviceType])
          if (!addBlackResult.success) {
            failedResult = addBlackResult
          }
        }
        success = failedResult === undefined
      } else {
        // 未配置：从白名单移除
        let result = PeripheralService.removeUsbWhitelistWithResult([device])
        success = result.success
        if (!result.success) {
          failedResult = result
        }
      }
    }

    if (success) {
      // 重新从 MDM API 加载设备列表
      this.loadDeviceControlData()
      // 同步刷新黑白名单 tab 数据
      this.usbWhitelist = PeripheralService.getUsbWhitelistWithResult().data ?? []
      this.usbBlacklist = PeripheralService.getUsbBlacklistWithResult().data ?? []
      this.btWhitelist = PeripheralService.getBluetoothWhitelistWithResult().data ?? []
      this.reloadDeviceRecords()
      try {
        promptAction.showToast({ message: record.deviceName + ' 策略已设置为' + policyLabels[policyIndex] })
      } catch (e) {
        hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
      }
    } else {
      this.showOperationFailure('修改设备管控策略', failedResult || {
        success: false,
        errorMessage: '修改设备策略失败'
      } as OperationResult<PeripheralResultData>)
    }
  }

  // ========== Tab Builder ==========

  @Builder
  tabBuilder(title: string, index: number) {
    Text(title)
      .fontSize(AppStyles.FONT_SIZE_BODY)
      .fontWeight(this.currentTab === index ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.currentTab === index ? AppColors.BRAND_PRIMARY : AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
      .opacity(this.currentTab === index ? 1 : AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
  }

  formatHex(num: number): string {
    return '0x' + num.toString(16).toUpperCase().padStart(2, '0')
  }

  // ========== Build ==========

  build() {
    Column() {
      // 页面头部
      Row() {
        Row({ space: 8 }) {
          BackNavButton({
            onBack: () => {
              this.onBack()
            }
          })

          Column({ space: 4 }) {
            Text('外设管理')
              .fontSize(AppStyles.FONT_SIZE_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
            Text('管控 USB、蓝牙、Wi-Fi 等外设接口，配置设备黑白名单策略')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Top)
      }
      .width('100%')
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_LG })

      // Tab 切换
      Tabs({ barPosition: BarPosition.Start }) {
        TabContent() {
          this.deviceRecordsBuilder()
        }.tabBar(this.tabBuilder('设备连接记录', 0))

        TabContent() {
          this.interfaceControlBuilder()
        }.tabBar(this.tabBuilder('接口管控', 1))

        TabContent() {
          this.deviceControlBuilder()
        }.tabBar(this.tabBuilder('设备管控', 2))

        TabContent() {
          this.blackWhiteListBuilder()
        }.tabBar(this.tabBuilder('黑白名单', 3))
      }
      .barMode(BarMode.Fixed)
      .barWidth('100%')
      .onChange((index: number) => {
        this.currentTab = index
      })
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  // ==================== Tab 1: 设备连接记录 ====================
  private getDeviceRecordAllowCount(): number {
    return this.deviceRecords.filter((record: DeviceRecord) => record.policy === '允许').length
  }

  private getDeviceRecordBlockCount(): number {
    return this.deviceRecords.filter((record: DeviceRecord) => record.policy !== '允许').length
  }

  private getDeviceRecordPolicyTextColor(policy: string | undefined): string {
    return policy === '允许'
      ? AppColors.getColors(this.currentTheme).TAG_GREEN_TEXT
      : AppColors.getColors(this.currentTheme).TAG_RED_TEXT
  }

  private getDeviceRecordPolicyBgColor(policy: string | undefined): string {
    return policy === '允许'
      ? AppColors.getColors(this.currentTheme).TAG_GREEN_BG
      : AppColors.getColors(this.currentTheme).TAG_RED_BG
  }

  private getDeviceRecordPolicySummary(policy: string | undefined): string {
    return policy === '允许' ? '已按当前接口策略放行' : '已被当前接口策略拦截'
  }

  @Builder
  deviceRecordItem(record: DeviceRecord, index: number) {
    Row({ space: 16 }) {
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Text(record.deviceName)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(getPeripheralTypeLabel(record.deviceType))
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_TEXT)
            .backgroundColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_BG)
            .borderRadius(AppStyles.RADIUS_SM)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        }

        Text(record.deviceId)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row({ space: 20 }) {
          Column({ space: 4 }) {
            Text('连接时间')
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
            Text(record.connectTime)
              .fontSize(AppStyles.FONT_SIZE_SMALL)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          }
          .alignItems(HorizontalAlign.Start)

          Column({ space: 4 }) {
            Text('策略结果')
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
            Text(this.getDeviceRecordPolicySummary(record.policy))
              .fontSize(AppStyles.FONT_SIZE_SMALL)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column({ space: 8 }) {
        Text(record.policy)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getDeviceRecordPolicyTextColor(record.policy))
          .backgroundColor(this.getDeviceRecordPolicyBgColor(record.policy))
          .borderRadius(AppStyles.RADIUS_SM)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })

        Text(record.policy === '允许' ? '命中白名单 / 默认放行' : '命中限制规则')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .textAlign(TextAlign.End)
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 18, bottom: 18 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .translate({ y: HoverUtils.getTranslateY(this.hoveredDeviceRecordIndex === index, 2) })
    .onHover((isHover: boolean) => {
      HoverUtils.animate(() => {
        this.hoveredDeviceRecordIndex = isHover ? index : -1
      })
    })
  }

  @Builder
  deviceRecordsPanel() {
    Scroll() {
      Column({ space: 0 }) {
        Column({ space: 0 }) {
          if (this.deviceRecords.length === 0) {
            Column({ space: 10 }) {
              Text('暂无设备连接记录')
                .fontSize(AppStyles.FONT_SIZE_BODY)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

              Text('请连接 USB 或蓝牙设备以生成记录。')
                .fontSize(AppStyles.FONT_SIZE_CAPTION)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 42, bottom: 42 })
            .alignItems(HorizontalAlign.Center)
          } else {
            Column({ space: 0 }) {
              ForEach(this.deviceRecords, (record: DeviceRecord, index: number) => {
                Column({ space: 0 }) {
                  this.deviceRecordItem(record, index)
                  if (index < this.deviceRecords.length - 1) {
                    Divider()
                      .color(AppColors.getColors(this.currentTheme).BORDER)
                      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
                      .margin({ left: 20, right: 20 })
                  }
                }
              })
            }
            .width('100%')
          }
        }
        .borderRadius(AppStyles.RADIUS_LG)
        .clip(true)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .border({
          width: 1,
          color: this.hoveredPanelIndex === 0 ? AppColors.BRAND_PRIMARY : AppColors.getColors(this.currentTheme).BORDER
        })
        .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 0, true))
        .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 0, 4) })
        .onHover((isHover: boolean) => {
          HoverUtils.animate(() => {
            this.hoveredPanelIndex = isHover ? 0 : -1
          })
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD, bottom: AppStyles.PADDING_MD })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .align(Alignment.Top)
  }

  private getConnectionRuntimeCount(): number {
    return this.deviceRecords.filter((record: PeripheralConnectionRecord) => record.source === 'runtime_event').length
  }

  private getConnectionAuditCount(): number {
    return this.deviceRecords.filter((record: PeripheralConnectionRecord) => record.source === 'audit_event').length
  }

  private getConnectionSnapshotCount(): number {
    return this.deviceRecords.filter((record: PeripheralConnectionRecord) => record.source === 'policy_snapshot').length
  }

  private getConnectionConnectCount(): number {
    return this.deviceRecords.filter((record: PeripheralConnectionRecord) => {
      return record.source !== 'policy_snapshot' && record.action === 'connect'
    }).length
  }

  private getConnectionDisconnectCount(): number {
    return this.deviceRecords.filter((record: PeripheralConnectionRecord) => {
      return record.source !== 'policy_snapshot' && record.action === 'disconnect'
    }).length
  }

  private getConnectionInterceptCount(): number {
    return this.deviceRecords.filter((record: PeripheralConnectionRecord) => {
      return record.source !== 'policy_snapshot' && record.action === 'intercept'
    }).length
  }

  private getConnectionTypeFilterLabel(): string {
    let option = this.recordTypeFilterOptions[this.recordFilterTypeIndex]
    return option ? option.value as string : this.recordTypeFilterOptions[0].value as string
  }

  private getConnectionResultFilterLabel(): string {
    let option = this.recordResultFilterOptions[this.recordFilterResultIndex]
    return option ? option.value as string : this.recordResultFilterOptions[0].value as string
  }

  private getConnectionSourceFilterLabel(): string {
    let option = this.recordSourceFilterOptions[this.recordFilterSourceIndex]
    return option ? option.value as string : this.recordSourceFilterOptions[0].value as string
  }

  private getConnectionResultLabel(record: PeripheralConnectionRecord): string {
    if (record.source === 'policy_snapshot') {
      return '快照'
    }
    return getLogEventResultLabel(record.result)
  }

  private getConnectionResultTextColor(record: PeripheralConnectionRecord): string {
    if (record.source === 'policy_snapshot') {
      return AppColors.getColors(this.currentTheme).TAG_GRAY_TEXT
    }
    if (record.result === LogEventResult.SUCCESS) {
      return AppColors.getColors(this.currentTheme).TAG_GREEN_TEXT
    }
    if (record.result === LogEventResult.BLOCKED) {
      return AppColors.getColors(this.currentTheme).TAG_RED_TEXT
    }
    return AppColors.getColors(this.currentTheme).TAG_ORANGE_TEXT
  }

  private getConnectionResultBgColor(record: PeripheralConnectionRecord): string {
    if (record.source === 'policy_snapshot') {
      return AppColors.getColors(this.currentTheme).TAG_GRAY_BG
    }
    if (record.result === LogEventResult.SUCCESS) {
      return AppColors.getColors(this.currentTheme).TAG_GREEN_BG
    }
    if (record.result === LogEventResult.BLOCKED) {
      return AppColors.getColors(this.currentTheme).TAG_RED_BG
    }
    return AppColors.getColors(this.currentTheme).TAG_ORANGE_BG
  }

  private getConnectionPolicyHitLabel(record: PeripheralConnectionRecord): string {
    if (record.source === 'policy_snapshot') {
      return '未审计'
    }
    return getPeripheralRecordPolicyHitLabel(record.policyHit)
  }

  private formatConnectionTime(record: PeripheralConnectionRecord): string {
    if (record.timestamp <= 0) {
      return '--'
    }
    return formatLogTimestamp(record.timestamp)
  }

  @Builder
  private connectionStatItem(title: string, value: string, valueColor: string) {
    Column({ space: 4 }) {
      Text(title)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      Text(value)
        .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(valueColor)
    }
    .layoutWeight(1)
    .padding({ top: 10, bottom: 10 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_MD)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private connectionRecordStatsPanel() {
    Row({ space: 8 }) {
      this.connectionStatItem('运行时', `${this.getConnectionRuntimeCount()}`, AppColors.BRAND_PRIMARY)
      this.connectionStatItem('审计', `${this.getConnectionAuditCount()}`, AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)
      this.connectionStatItem('连接', `${this.getConnectionConnectCount()}`, AppColors.getColors(this.currentTheme).TAG_GREEN_TEXT)
      this.connectionStatItem('断开', `${this.getConnectionDisconnectCount()}`, AppColors.getColors(this.currentTheme).TAG_ORANGE_TEXT)
      this.connectionStatItem('拦截', `${this.getConnectionInterceptCount()}`, AppColors.getColors(this.currentTheme).TAG_RED_TEXT)
      this.connectionStatItem('快照', `${this.getConnectionSnapshotCount()}`, AppColors.getColors(this.currentTheme).TAG_GRAY_TEXT)
    }
    .width('100%')
    .padding({
      left: AppStyles.PADDING_LG,
      right: AppStyles.PADDING_LG,
      top: AppStyles.PADDING_MD
    })
  }
  @Builder
  private connectionRecordFilterToolbar() {
    Row({ space: 8 }) {
      Select(this.recordTypeFilterOptions)
        .selected(this.recordFilterTypeIndex)
        .value(this.getConnectionTypeFilterLabel())
        .font({ size: AppStyles.FONT_SIZE_BODY })
        .fontColor(FormControlUtils.text(this.currentTheme))
        .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
        .optionFont({ size: AppStyles.FONT_SIZE_BODY })
        .width(120)
        .height(36)
        .backgroundColor(FormControlUtils.background(this.currentTheme))
        .borderRadius(AppStyles.RADIUS_SM)
        .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
        .onSelect((index: number) => {
          this.recordFilterTypeIndex = index
          this.reloadDeviceRecords()
        })

      Select(this.recordResultFilterOptions)
        .selected(this.recordFilterResultIndex)
        .value(this.getConnectionResultFilterLabel())
        .font({ size: AppStyles.FONT_SIZE_BODY })
        .fontColor(FormControlUtils.text(this.currentTheme))
        .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
        .optionFont({ size: AppStyles.FONT_SIZE_BODY })
        .width(120)
        .height(36)
        .backgroundColor(FormControlUtils.background(this.currentTheme))
        .borderRadius(AppStyles.RADIUS_SM)
        .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
        .onSelect((index: number) => {
          this.recordFilterResultIndex = index
          this.reloadDeviceRecords()
        })

      Select(this.recordSourceFilterOptions)
        .selected(this.recordFilterSourceIndex)
        .value(this.getConnectionSourceFilterLabel())
        .font({ size: AppStyles.FONT_SIZE_BODY })
        .fontColor(FormControlUtils.text(this.currentTheme))
        .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
        .optionFont({ size: AppStyles.FONT_SIZE_BODY })
        .width(140)
        .height(36)
        .backgroundColor(FormControlUtils.background(this.currentTheme))
        .borderRadius(AppStyles.RADIUS_SM)
        .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
        .onSelect((index: number) => {
          this.recordFilterSourceIndex = index
          this.reloadDeviceRecords()
        })

      TextInput({ placeholder: '按关键字或设备 ID 过滤', text: this.recordFilterKeyword })
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(FormControlUtils.text(this.currentTheme))
        .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
        .backgroundColor(FormControlUtils.background(this.currentTheme))
        .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
        .borderRadius(AppStyles.RADIUS_SM)
        .height(36)
        .layoutWeight(1)
        .onChange((value: string) => {
          this.recordFilterKeyword = value
          this.reloadDeviceRecords()
        })

      Button('刷新')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .borderRadius(AppStyles.RADIUS_SM)
        .height(36)
        .onClick(() => {
          this.reloadDeviceRecords()
        })
    }
    .width('100%')
    .padding({
      left: AppStyles.PADDING_LG,
      right: AppStyles.PADDING_LG,
      top: AppStyles.PADDING_SM
    })
  }
  @Builder
  private connectionRecordHintView() {
    if (this.recordHintMessage.length > 0) {
      Row() {
        Text(this.recordHintMessage)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_ORANGE_TEXT)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({
        left: AppStyles.PADDING_LG,
        right: AppStyles.PADDING_LG,
        top: 6,
        bottom: 4
      })
    }
  }

  @Builder
  private connectionRecordItem(record: PeripheralConnectionRecord, index: number) {
    Row({ space: 16 }) {
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Text(record.deviceName)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(getPeripheralTypeLabel(record.deviceType))
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_TEXT)
            .backgroundColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_BG)
            .borderRadius(AppStyles.RADIUS_SM)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        }

        Text(record.deviceId)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row({ space: 8 }) {
          Text(getPeripheralRecordSourceLabel(record.source))
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)
            .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)
            .borderRadius(AppStyles.RADIUS_SM)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })

          Text(getPeripheralRecordActionLabel(record.action))
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TAG_ORANGE_TEXT)
            .backgroundColor(AppColors.getColors(this.currentTheme).TAG_ORANGE_BG)
            .borderRadius(AppStyles.RADIUS_SM)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        }

        Row({ space: 20 }) {
          Column({ space: 4 }) {
            Text('连接时间')
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
            Text(this.formatConnectionTime(record))
              .fontSize(AppStyles.FONT_SIZE_SMALL)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          }
          .alignItems(HorizontalAlign.Start)

          Column({ space: 4 }) {
            Text('策略说明')
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
            Text(record.summary)
              .fontSize(AppStyles.FONT_SIZE_SMALL)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column({ space: 8 }) {
        Text(this.getConnectionResultLabel(record))
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getConnectionResultTextColor(record))
          .backgroundColor(this.getConnectionResultBgColor(record))
          .borderRadius(AppStyles.RADIUS_SM)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })

        Text(this.getConnectionPolicyHitLabel(record))
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .textAlign(TextAlign.End)
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 18, bottom: 18 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .translate({ y: HoverUtils.getTranslateY(this.hoveredDeviceRecordIndex === index, 2) })
    .onHover((isHover: boolean) => {
      HoverUtils.animate(() => {
        this.hoveredDeviceRecordIndex = isHover ? index : -1
      })
    })
  }

  @Builder
  private connectionRecordsPanel() {
    Scroll() {
      Column({ space: 0 }) {
        this.connectionRecordStatsPanel()
        this.connectionRecordFilterToolbar()
        this.connectionRecordHintView()

        Column({ space: 0 }) {
          if (this.deviceRecords.length === 0) {
            Column({ space: 10 }) {
              Text('暂无设备连接记录')
                .fontSize(AppStyles.FONT_SIZE_BODY)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

              Text('暂无实时记录，请重新插拔设备后刷新。')
                .fontSize(AppStyles.FONT_SIZE_CAPTION)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 42, bottom: 42 })
            .alignItems(HorizontalAlign.Center)
          } else {
            Column({ space: 0 }) {
              ForEach(this.deviceRecords, (record: PeripheralConnectionRecord, index: number) => {
                Column({ space: 0 }) {
                  this.connectionRecordItem(record, index)
                  if (index < this.deviceRecords.length - 1) {
                    Divider()
                      .color(AppColors.getColors(this.currentTheme).BORDER)
                      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
                      .margin({ left: 20, right: 20 })
                  }
                }
              })
            }
            .width('100%')
          }
        }
        .borderRadius(AppStyles.RADIUS_LG)
        .clip(true)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .border({
          width: 1,
          color: this.hoveredPanelIndex === 0 ? AppColors.BRAND_PRIMARY : AppColors.getColors(this.currentTheme).BORDER
        })
        .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 0, true))
        .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 0, 4) })
        .onHover((isHover: boolean) => {
          HoverUtils.animate(() => {
            this.hoveredPanelIndex = isHover ? 0 : -1
          })
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .padding({
        left: AppStyles.PADDING_LG,
        right: AppStyles.PADDING_LG,
        top: AppStyles.PADDING_MD,
        bottom: AppStyles.PADDING_MD
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .align(Alignment.Top)
  }

  @Builder
  deviceRecordsBuilder() {
    if (true) {
      this.connectionRecordsPanel()
    } else {
      /*
      Column() {
      Column({ space: 4 }) {
        Text('设备连接记录')
          .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        Text('查看最近接入过的外设身份、连接时间与当前命中策略。')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })
      .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
      .borderRadius({ topLeft: AppStyles.RADIUS_LG, topRight: AppStyles.RADIUS_LG })

      if (this.deviceRecords.length === 0) {
        Column({ space: 12 }) {
          Text('暂无设备连接记录')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .borderRadius({ bottomLeft: AppStyles.RADIUS_LG, bottomRight: AppStyles.RADIUS_LG })
      } else {
        // 表头
        Row() {
          Text('设备名称').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(2)
          Text('设备类型').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1.5)
          Text('设备标识').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(2)
          Text('连接时间').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(2)
          Text('策略').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
        .borderRadius({ topLeft: AppStyles.RADIUS_LG, topRight: AppStyles.RADIUS_LG })

        // 数据列表
        List() {
          ForEach(this.deviceRecords, (record: DeviceRecord) => {
            ListItem() {
              Row() {
                Text(record.deviceName)
                  .fontSize(AppStyles.FONT_SIZE_SMALL)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
                  .layoutWeight(2)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(getPeripheralTypeLabel(record.deviceType))
                  .fontSize(AppStyles.FONT_SIZE_CAPTION)
                  .fontColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_TEXT)
                  .backgroundColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_BG)
                  .borderRadius(4)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .layoutWeight(1.5)

                Text(record.deviceId)
                  .fontSize(AppStyles.FONT_SIZE_SMALL)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
                  .layoutWeight(2)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(record.connectTime)
                  .fontSize(AppStyles.FONT_SIZE_SMALL)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
                  .layoutWeight(2)

                Text(record.policy)
                  .fontSize(AppStyles.FONT_SIZE_CAPTION)
                  .fontColor(record.policy === '允许' ? AppColors.getColors(this.currentTheme).TAG_GREEN_TEXT : AppColors.getColors(this.currentTheme).TAG_RED_TEXT)
                  .backgroundColor(record.policy === '允许' ? AppColors.getColors(this.currentTheme).TAG_GREEN_BG : AppColors.getColors(this.currentTheme).TAG_RED_BG)
                  .borderRadius(4)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .layoutWeight(1)
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
              .border({
                width: { bottom: 1 },
                color: AppColors.getColors(this.currentTheme).BORDER
              })
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 1, color: AppColors.getColors(this.currentTheme).BORDER, startMargin: 0, endMargin: 0 })
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .borderRadius({ bottomLeft: AppStyles.RADIUS_LG, bottomRight: AppStyles.RADIUS_LG })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD })
    .border({
      width: 1,
      color: this.hoveredPanelIndex === 0 ? AppColors.BRAND_PRIMARY : Color.Transparent
    })
    .borderRadius(AppStyles.RADIUS_LG)
    .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 0, true))
    .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 0, 4) })
    .onHover((isHover: boolean) => {
      HoverUtils.animate(() => {
        this.hoveredPanelIndex = isHover ? 0 : -1
      })
    })
      */
    }
  }

  // ==================== Tab 2: 接口管控 ====================
  @Builder
  interfaceControlBuilder() {
    Scroll() {
      Column({ space: 0 }) {
        Column() {
          InterfaceControlItem({
            label: 'USB 接口',
            description: '启用或禁用 USB 接口。禁用后将阻止 USB 控制操作。',
            options: ['启用', '禁用'],
            selectedIndex: this.usbDisabled ? 1 : 0,
            onSelect: (index: number) => {
              this.handleInterfaceToggle('usb', index === 1)
            }
          })

          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          InterfaceControlItem({
            label: 'USB 存储设备',
            description: '设置 USB 存储策略：只读、读写或禁止访问。',
            options: ['只读', '读写', '禁止访问'],
            selectedIndex: this.usbStoragePolicyIndex,
            onSelect: (index: number) => {
              this.handleUsbStoragePolicyChange(index)
            }
          })

          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)


          InterfaceControlItem({
            label: '蓝牙',
            description: '启用或禁用蓝牙接口。',
            options: ['启用', '禁用'],
            selectedIndex: this.btDisabled ? 1 : 0,
            onSelect: (index: number) => {
              this.handleInterfaceToggle('bluetooth', index === 1)
            }
          })

          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          InterfaceControlItem({
            label: 'Wi-Fi',
            description: '启用或禁用 Wi-Fi 接口。',
            options: ['启用', '禁用'],
            selectedIndex: this.wifiDisabled ? 1 : 0,
            onSelect: (index: number) => {
              this.handleInterfaceToggle('wifi', index === 1)
            }
          })

          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          InterfaceControlItem({
            label: 'HDC (调试接口)',
            description: '启用或禁用 HDC 调试接口。',
            options: ['启用', '禁用'],
            selectedIndex: this.hdcDisabled ? 1 : 0,
            onSelect: (index: number) => {
              this.handleInterfaceToggle('hdc', index === 1)
            }
          })
        }
        .borderRadius(AppStyles.RADIUS_LG)
        .clip(true)
        .border({
          width: 1,
          color: this.hoveredPanelIndex === 1 ? AppColors.BRAND_PRIMARY : AppColors.getColors(this.currentTheme).BORDER
        })
        .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 1, true))
        .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 1, 4) })
        .onHover((isHover: boolean) => {
          HoverUtils.animate(() => {
            this.hoveredPanelIndex = isHover ? 1 : -1
          })
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .align(Alignment.Top)
  }

  // ==================== Tab 3: 设备管控 ====================
  @Builder
  deviceControlBuilder() {
    Column() {
      if (this.deviceControlRecords.length === 0) {
        Column({ space: 12 }) {
          Text('暂无已纳管设备，请在「黑白名单」中添加设备')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        // 表头
        Row() {
          Text('设备名称').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(2)
          Text('设备类型').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1.5)
          Text('设备标识').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(2)
          Text('场景').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(2)
          Text('管控策略').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1.5)
          Text('操作').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(0.8)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
        .borderRadius({ topLeft: AppStyles.RADIUS_LG, topRight: AppStyles.RADIUS_LG })

        List() {
          ForEach(this.deviceControlRecords, (record: DeviceControlRecord, index: number) => {
            ListItem() {
              Row() {
                Text(record.deviceName)
                  .fontSize(AppStyles.FONT_SIZE_SMALL)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
                  .layoutWeight(2)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(getPeripheralTypeLabel(record.deviceType))
                  .fontSize(AppStyles.FONT_SIZE_CAPTION)
                  .fontColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_TEXT)
                  .backgroundColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_BG)
                  .borderRadius(4)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .layoutWeight(1.5)

                Text(record.deviceId)
                  .fontSize(AppStyles.FONT_SIZE_SMALL)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
                  .layoutWeight(2)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(record.connectTime)
                  .fontSize(AppStyles.FONT_SIZE_SMALL)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
                  .layoutWeight(2)

                // 管控策略下拉选择框
                Select(this.deviceControlPolicyOptions)
                  .selected(record.policyIndex)
                  .value(this.deviceControlPolicyOptions[record.policyIndex].value as string)
                  .font({ size: AppStyles.FONT_SIZE_CAPTION })
                  .fontColor(FormControlUtils.text(this.currentTheme))
                  .selectedOptionFont({ size: AppStyles.FONT_SIZE_CAPTION })
                  .optionFont({ size: AppStyles.FONT_SIZE_CAPTION })
                  .backgroundColor(FormControlUtils.background(this.currentTheme))
                  .borderRadius(AppStyles.RADIUS_SM)
                  .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
                  .layoutWeight(1.5)
                  .onSelect((selectIndex: number) => {
                    this.handleDeviceControlPolicyChange(index, selectIndex)
                  })

                // 操作列：详情按钮
                Text('详情')
                  .fontSize(AppStyles.FONT_SIZE_CAPTION)
                  .fontColor(AppColors.BRAND_PRIMARY)
                  .layoutWeight(0.8)
                  .textAlign(TextAlign.Center)
                  .onClick(() => {
                    try {
                      promptAction.showToast({ message: '场景详情功能开发中。' })
                    } catch (e) {
                      hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
                    }
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 1, color: AppColors.getColors(this.currentTheme).BORDER, startMargin: 0, endMargin: 0 })

        // 底部操作栏
        Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
        Row() {
          Text('下载设备管控模板')
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontColor(AppColors.BRAND_PRIMARY)
            .onClick(() => {
              try {
                promptAction.showToast({ message: '下载模板功能开发中。' })
              } catch (e) {
                hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
              }
            })
          Text('导入设备管控清单')
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontColor(AppColors.BRAND_PRIMARY)
            .onClick(() => {
              try {
                promptAction.showToast({ message: '导入清单功能开发中。' })
              } catch (e) {
                hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
              }
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .justifyContent(FlexAlign.SpaceBetween)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD })
    .border({
      width: 1,
      color: this.hoveredPanelIndex === 2 ? AppColors.SUCCESS : Color.Transparent
    })
    .borderRadius(AppStyles.RADIUS_LG)
    .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 2, true))
    .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 2, 4) })
    .onHover((isHover: boolean) => {
      HoverUtils.animate(() => {
        this.hoveredPanelIndex = isHover ? 2 : -1
      })
    })
  }

  // ==================== Tab 4: 黑白名单 ====================
  @Builder
  blackWhiteListBuilder() {
    Scroll() {
      Column({ space: 24 }) {
        // USB 设备白名单
        Column({ space: 12 }) {
          Row() {
            Text('USB 设备白名单（按设备ID）')
              .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
              .layoutWeight(1)
            Button('+ 添加')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(Color.White)
              .backgroundColor(AppColors.BRAND_PRIMARY)
              .borderRadius(AppStyles.RADIUS_MD)
              .height(32)
              .onClick(() => {
                this.usbWhitelistDialogController.open()
              })
          }
          .width('100%')

          // 表头
          Row() {
            Text('厂商 ID').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
            Text('产品 ID').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
            Text('操作').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
          .borderRadius({ topLeft: AppStyles.RADIUS_MD, topRight: AppStyles.RADIUS_MD })

          if (this.usbWhitelist.length === 0) {
            Text('暂无 USB 白名单项。')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
              .padding(24)
              .width('100%')
              .textAlign(TextAlign.Center)
              .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
              .borderRadius({ bottomLeft: AppStyles.RADIUS_MD, bottomRight: AppStyles.RADIUS_MD })
          } else {
            Column() {
              ForEach(this.usbWhitelist, (device: usbManager.UsbDeviceId) => {
                Row() {
                  Text(this.formatHex(device.vendorId))
                    .fontSize(AppStyles.FONT_SIZE_SMALL)
                    .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                    .layoutWeight(1)
                  Text(this.formatHex(device.productId))
                    .fontSize(AppStyles.FONT_SIZE_SMALL)
                    .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                    .layoutWeight(1)
                  Text('删除')
                    .fontSize(AppStyles.FONT_SIZE_CAPTION)
                    .fontColor(AppColors.DANGER)
                    .layoutWeight(1)
                    .onClick(() => {
                      this.handleRemoveUsbWhitelist(device)
                    })
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
              })
            }
            .borderRadius({ bottomLeft: AppStyles.RADIUS_MD, bottomRight: AppStyles.RADIUS_MD })
            .clip(true)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .borderRadius(AppStyles.RADIUS_LG)
        .border({
          width: 1,
          color: this.hoveredPanelIndex === 3 ? AppColors.BRAND_PRIMARY : AppColors.getColors(this.currentTheme).BORDER
        })
        .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 3, true))
        .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 3, 4) })
        .onHover((isHover: boolean) => {
          HoverUtils.animate(() => {
            this.hoveredPanelIndex = isHover ? 3 : -1
          })
        })

        // USB 设备类型黑名单
        Column({ space: 12 }) {
          Row() {
            Text('USB 设备黑名单（按设备类型）')
              .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
              .layoutWeight(1)
            Button('+ 添加')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(Color.White)
              .backgroundColor(AppColors.BRAND_PRIMARY)
              .borderRadius(AppStyles.RADIUS_MD)
              .height(32)
              .onClick(() => {
                this.blacklistDialogController.open()
              })
          }
          .width('100%')

          Row() {
            Text('基础类').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
            Text('子类').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
            Text('协议').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
            Text('操作').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
          .borderRadius({ topLeft: AppStyles.RADIUS_MD, topRight: AppStyles.RADIUS_MD })

          if (this.usbBlacklist.length === 0) {
            Text('暂无 USB 黑名单项。')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
              .padding(24)
              .width('100%')
              .textAlign(TextAlign.Center)
              .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
              .borderRadius({ bottomLeft: AppStyles.RADIUS_MD, bottomRight: AppStyles.RADIUS_MD })
          } else {
            Column() {
              ForEach(this.usbBlacklist, (dt: usbManager.UsbDeviceType) => {
                Row() {
                  Text(this.formatHex(dt.baseClass))
                    .fontSize(AppStyles.FONT_SIZE_SMALL)
                    .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                    .layoutWeight(1)
                  Text(this.formatHex(dt.subClass))
                    .fontSize(AppStyles.FONT_SIZE_SMALL)
                    .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                    .layoutWeight(1)
                  Text(this.formatHex(dt.protocol))
                    .fontSize(AppStyles.FONT_SIZE_SMALL)
                    .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                    .layoutWeight(1)
                  Text('删除')
                    .fontSize(AppStyles.FONT_SIZE_CAPTION)
                    .fontColor(AppColors.DANGER)
                    .layoutWeight(1)
                    .onClick(() => {
                      this.handleRemoveUsbBlacklist(dt)
                    })
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
              })
            }
            .borderRadius({ bottomLeft: AppStyles.RADIUS_MD, bottomRight: AppStyles.RADIUS_MD })
            .clip(true)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .borderRadius(AppStyles.RADIUS_LG)
        .border({
          width: 1,
          color: this.hoveredPanelIndex === 4 ? AppColors.WARNING : AppColors.getColors(this.currentTheme).BORDER
        })
        .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 4, true))
        .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 4, 4) })
        .onHover((isHover: boolean) => {
          HoverUtils.animate(() => {
            this.hoveredPanelIndex = isHover ? 4 : -1
          })
        })

        // 蓝牙白名单
        Column({ space: 12 }) {
          Row() {
            Text('蓝牙设备白名单（按MAC地址）')
              .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
              .layoutWeight(1)
            Button('+ 添加')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(Color.White)
              .backgroundColor(AppColors.BRAND_PRIMARY)
              .borderRadius(AppStyles.RADIUS_MD)
              .height(32)
              .onClick(() => {
                this.btWhitelistDialogController.open()
              })
          }
          .width('100%')

          Row() {
            Text('MAC 地址').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
            Text('操作').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
          .borderRadius({ topLeft: AppStyles.RADIUS_MD, topRight: AppStyles.RADIUS_MD })

          if (this.btWhitelist.length === 0) {
            Text('暂无蓝牙白名单项。')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
              .padding(24)
              .width('100%')
              .textAlign(TextAlign.Center)
              .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
              .borderRadius({ bottomLeft: AppStyles.RADIUS_MD, bottomRight: AppStyles.RADIUS_MD })
          } else {
            Column() {
              ForEach(this.btWhitelist, (mac: string) => {
                Row() {
                  Text(mac)
                    .fontSize(AppStyles.FONT_SIZE_SMALL)
                    .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                    .layoutWeight(1)
                  Text('删除')
                    .fontSize(AppStyles.FONT_SIZE_CAPTION)
                    .fontColor(AppColors.DANGER)
                    .layoutWeight(1)
                    .onClick(() => {
                      this.handleRemoveBluetoothWhitelist(mac)
                    })
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
              })
            }
            .borderRadius({ bottomLeft: AppStyles.RADIUS_MD, bottomRight: AppStyles.RADIUS_MD })
            .clip(true)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .borderRadius(AppStyles.RADIUS_LG)
        .border({
          width: 1,
          color: this.hoveredPanelIndex === 5 ? AppColors.SUCCESS : AppColors.getColors(this.currentTheme).BORDER
        })
        .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 5, true))
        .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 5, 4) })
        .onHover((isHover: boolean) => {
          HoverUtils.animate(() => {
            this.hoveredPanelIndex = isHover ? 5 : -1
          })
        })
      }
      .width('100%')
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD, bottom: AppStyles.PADDING_LG })
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .align(Alignment.Top)
  }
}








