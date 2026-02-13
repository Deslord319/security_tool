import { AppColors, AppStyles } from '../constants/AppConstants'
import { PeripheralService } from '../services/PeripheralService'
import { InterfaceControlItem } from '../components/InterfaceControlItem'
import { AddWhitelistDialog } from '../components/AddWhitelistDialog'
import { AddBlacklistDialog } from '../components/AddBlacklistDialog'
import { DeviceRecord, DeviceControlRecord, PeripheralType, getPeripheralTypeLabel } from '../models/DataModels'
import { usbManager } from '@kit.MDMKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { promptAction } from '@kit.ArkUI'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'

const TAG = 'PeripheralPage'

@Component
export struct PeripheralPage {
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  @State currentTab: number = 0
  @State isLoading: boolean = false

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
  @State deviceRecords: DeviceRecord[] = []

  // 设备管控记录（独立数据源）
  @State deviceControlRecords: DeviceControlRecord[] = []
  private deviceControlPolicyOptions: SelectOption[] = [
    { value: '允许' },
    { value: '禁用' },
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
    this.loadAllData()
  }

  loadAllData() {
    this.isLoading = true

    // 加载接口管控状态
    this.usbDisabled = PeripheralService.getInterfaceDisabled('usb')
    this.btDisabled = PeripheralService.getInterfaceDisabled('bluetooth')
    this.wifiDisabled = PeripheralService.getInterfaceDisabled('wifi')
    this.hdcDisabled = PeripheralService.getInterfaceDisabled('hdc')

    // 加载 USB 存储策略
    let policy = PeripheralService.getUsbStoragePolicy()
    if (policy === usbManager.UsbPolicy.READ_ONLY) {
      this.usbStoragePolicyIndex = 0
    } else if (policy === usbManager.UsbPolicy.READ_WRITE) {
      this.usbStoragePolicyIndex = 1
    } else {
      this.usbStoragePolicyIndex = 2
    }

    // 加载黑白名单
    this.usbWhitelist = PeripheralService.getUsbWhitelist()
    this.usbBlacklist = PeripheralService.getUsbBlacklist()
    this.btWhitelist = PeripheralService.getBluetoothWhitelist()

    // 模拟设备连接记录
    this.deviceRecords = [
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

    // 模拟设备管控记录（已纳管设备子集）
    this.deviceControlRecords = [
      {
        deviceName: 'ShineOptics FHD Camera',
        deviceType: PeripheralType.USB_CAMERA,
        deviceId: 'VID:2B7E PID:B5A2',
        connectTime: '2026-02-09 16:01:19',
        policyIndex: 0
      },
      {
        deviceName: 'SanDisk Ultra USB 3.0',
        deviceType: PeripheralType.USB_STORAGE,
        deviceId: 'VID:0781 PID:5583',
        connectTime: '2026-02-09 14:30:08',
        policyIndex: 1
      }
    ]

    this.isLoading = false
  }

  // ========== 接口管控操作 ==========

  handleInterfaceToggle(feature: string, disallow: boolean) {
    let success = PeripheralService.setInterfaceDisabled(feature, disallow)
    if (success) {
      if (feature === 'usb') this.usbDisabled = disallow
      else if (feature === 'bluetooth') this.btDisabled = disallow
      else if (feature === 'wifi') this.wifiDisabled = disallow
      else if (feature === 'hdc') this.hdcDisabled = disallow
      try {
        promptAction.showToast({ message: `${feature} 已${disallow ? '禁用' : '启用'}` })
      } catch (e) {
        hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
      }
    } else {
      try {
        promptAction.showToast({ message: '操作失败，请检查权限' })
      } catch (e) {
        hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
      }
    }
  }

  handleUsbStoragePolicyChange(index: number) {
    let policyMap: usbManager.UsbPolicy[] = [
      usbManager.UsbPolicy.READ_ONLY,
      usbManager.UsbPolicy.READ_WRITE,
      usbManager.UsbPolicy.DISABLED
    ]
    let success = PeripheralService.setUsbStoragePolicy(policyMap[index])
    if (success) {
      this.usbStoragePolicyIndex = index
      try {
        promptAction.showToast({ message: 'USB 存储策略已更新' })
      } catch (e) {
        hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
      }
    }
  }

  // ========== 白名单操作 ==========

  handleAddUsbWhitelist(vendorId: number, productId: number) {
    let device: usbManager.UsbDeviceId = { vendorId: vendorId, productId: productId }
    let success = PeripheralService.addUsbWhitelist([device])
    if (success) {
      this.usbWhitelist = PeripheralService.getUsbWhitelist()
      try {
        promptAction.showToast({ message: 'USB 白名单已添加' })
      } catch (e) {
        hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
      }
    } else {
      try {
        promptAction.showToast({ message: '添加失败，请检查权限' })
      } catch (e) {
        hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
      }
    }
  }

  handleRemoveUsbWhitelist(device: usbManager.UsbDeviceId) {
    let success = PeripheralService.removeUsbWhitelist([device])
    if (success) {
      this.usbWhitelist = PeripheralService.getUsbWhitelist()
      try {
        promptAction.showToast({ message: '已从白名单移除' })
      } catch (e) {
        hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
      }
    }
  }

  handleAddBluetoothWhitelist(mac: string) {
    let success = PeripheralService.addBluetoothWhitelist([mac])
    if (success) {
      this.btWhitelist = PeripheralService.getBluetoothWhitelist()
      try {
        promptAction.showToast({ message: '蓝牙白名单已添加' })
      } catch (e) {
        hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
      }
    } else {
      try {
        promptAction.showToast({ message: '添加失败，请检查权限' })
      } catch (e) {
        hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
      }
    }
  }

  handleRemoveBluetoothWhitelist(mac: string) {
    let success = PeripheralService.removeBluetoothWhitelist([mac])
    if (success) {
      this.btWhitelist = PeripheralService.getBluetoothWhitelist()
      try {
        promptAction.showToast({ message: '已从蓝牙白名单移除' })
      } catch (e) {
        hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
      }
    }
  }

  // ========== 黑名单操作 ==========

  handleAddUsbBlacklist(baseClass: number, subClass: number, protocol: number) {
    let deviceType: usbManager.UsbDeviceType = {
      baseClass: baseClass,
      subClass: subClass,
      protocol: protocol,
      descriptor: usbManager.Descriptor.INTERFACE
    }
    let success = PeripheralService.addUsbBlacklist([deviceType])
    if (success) {
      this.usbBlacklist = PeripheralService.getUsbBlacklist()
      try {
        promptAction.showToast({ message: 'USB 黑名单已添加' })
      } catch (e) {
        hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
      }
    } else {
      try {
        promptAction.showToast({ message: '添加失败，请检查权限' })
      } catch (e) {
        hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
      }
    }
  }

  handleRemoveUsbBlacklist(deviceType: usbManager.UsbDeviceType) {
    let success = PeripheralService.removeUsbBlacklist([deviceType])
    if (success) {
      this.usbBlacklist = PeripheralService.getUsbBlacklist()
      try {
        promptAction.showToast({ message: '已从黑名单移除' })
      } catch (e) {
        hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
      }
    }
  }

  // ========== 设备管控操作 ==========

  handleDeviceControlPolicyChange(recordIndex: number, policyIndex: number) {
    let updated: DeviceControlRecord[] = [...this.deviceControlRecords]
    updated[recordIndex] = {
      deviceName: updated[recordIndex].deviceName,
      deviceType: updated[recordIndex].deviceType,
      deviceId: updated[recordIndex].deviceId,
      connectTime: updated[recordIndex].connectTime,
      policyIndex: policyIndex
    }
    this.deviceControlRecords = updated
    let policyLabels = ['允许', '禁用', '未配置']
    try {
      promptAction.showToast({ message: `${updated[recordIndex].deviceName} 策略已更新为「${policyLabels[policyIndex]}」` })
    } catch (e) {
      hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
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
        Column({ space: 4 }) {
          Text('外设管理')
            .fontSize(AppStyles.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          Text('通过 MDM Kit 管控 USB、蓝牙、Wi-Fi 等外设接口，配置设备黑白名单策略')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
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
  @Builder
  deviceRecordsBuilder() {
    Column() {
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
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 1, color: AppColors.getColors(this.currentTheme).BORDER, startMargin: 0, endMargin: 0 })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD })
  }

  // ==================== Tab 2: 接口管控 ====================
  @Builder
  interfaceControlBuilder() {
    Scroll() {
      Column({ space: 0 }) {
        Column() {
          InterfaceControlItem({
            label: 'USB 接口',
            description: '全局禁用 USB 后，所有 USB 管控策略将不生效。系统仅允许键盘鼠标接入。',
            options: ['按策略生效', '全局禁用'],
            selectedIndex: this.usbDisabled ? 1 : 0,
            onSelect: (index: number) => {
              this.handleInterfaceToggle('usb', index === 1)
            }
          })

          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          InterfaceControlItem({
            label: 'USB 存储设备',
            description: '控制 USB 存储设备的访问策略：只读 / 读写 / 禁止访问。',
            options: ['只读', '读写', '禁止访问'],
            selectedIndex: this.usbStoragePolicyIndex,
            onSelect: (index: number) => {
              this.handleUsbStoragePolicyChange(index)
            }
          })

          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)


          InterfaceControlItem({
            label: '蓝牙',
            description: '全局禁用/启用蓝牙功能。',
            options: ['启用', '禁用'],
            selectedIndex: this.btDisabled ? 1 : 0,
            onSelect: (index: number) => {
              this.handleInterfaceToggle('bluetooth', index === 1)
            }
          })

          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          InterfaceControlItem({
            label: 'Wi-Fi',
            description: '全局禁用/启用 Wi-Fi 功能。',
            options: ['启用', '禁用'],
            selectedIndex: this.wifiDisabled ? 1 : 0,
            onSelect: (index: number) => {
              this.handleInterfaceToggle('wifi', index === 1)
            }
          })

          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          InterfaceControlItem({
            label: 'HDC (调试接口)',
            description: '全局禁用/启用 HDC 调试接口。',
            options: ['启用', '禁用'],
            selectedIndex: this.hdcDisabled ? 1 : 0,
            onSelect: (index: number) => {
              this.handleInterfaceToggle('hdc', index === 1)
            }
          })
        }
        .borderRadius(AppStyles.RADIUS_LG)
        .clip(true)
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
          Text('暂无已知设备')
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
          Text('最近连接时间').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
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
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .selectedOptionFont({ size: AppStyles.FONT_SIZE_CAPTION })
                  .optionFont({ size: AppStyles.FONT_SIZE_CAPTION })
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
                      promptAction.showToast({ message: '查看详情（待实现）' })
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
                promptAction.showToast({ message: '下载模板（待实现）' })
              } catch (e) {
                hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
              }
            })
          Text('导入设备管控清单')
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontColor(AppColors.BRAND_PRIMARY)
            .onClick(() => {
              try {
                promptAction.showToast({ message: '导入清单（待实现）' })
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
  }

  // ==================== Tab 4: 黑白名单 ====================
  @Builder
  blackWhiteListBuilder() {
    Scroll() {
      Column({ space: 24 }) {
        // USB 设备白名单
        Column({ space: 12 }) {
          Row() {
            Text('USB 设备白名单 (按设备ID)')
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
            Text('Vendor ID').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
            Text('Product ID').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
            Text('操作').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
          .borderRadius({ topLeft: AppStyles.RADIUS_MD, topRight: AppStyles.RADIUS_MD })

          if (this.usbWhitelist.length === 0) {
            Text('暂无白名单设备')
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

        // USB 设备类型黑名单
        Column({ space: 12 }) {
          Row() {
            Text('USB 设备黑名单 (按设备类型)')
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
            Text('Base Class').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
            Text('Sub Class').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
            Text('Protocol').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
            Text('操作').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
          .borderRadius({ topLeft: AppStyles.RADIUS_MD, topRight: AppStyles.RADIUS_MD })

          if (this.usbBlacklist.length === 0) {
            Text('暂无黑名单设备类型')
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

        // 蓝牙白名单
        Column({ space: 12 }) {
          Row() {
            Text('蓝牙设备白名单 (按MAC地址)')
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
            Text('暂无蓝牙白名单设备')
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
