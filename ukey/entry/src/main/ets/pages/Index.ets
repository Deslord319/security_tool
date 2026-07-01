import { common } from '@kit.AbilityKit'
import {
  LockScreenAuthRepository,
  PreferencesLockScreenAuthRepository
} from '../services/identity/lockscreen-auth/LockScreenAuthRepository'
import {
  LockScreenCustomAuthEnrollmentService
} from '../services/identity/lockscreen-auth/LockScreenCustomAuthEnrollmentService'
import {
  LockScreenUKeyActiveCredential,
  LockScreenUKeyDevice
} from '../models/identity/lockscreen-auth/LockScreenAuthModels'
import {
  PreferencesLockScreenUKeyActiveCredentialRepository
} from '../services/identity/lockscreen-auth/LockScreenUKeyBindingRepository'
import {
  DdkLockScreenUKeyDeviceService,
  LockScreenUKeyDeviceProvider,
  UsbLockScreenUKeyDeviceService
} from '../services/identity/lockscreen-auth/LockScreenUKeyDeviceService'
import { UKeyRuntimeManager } from '../runtime/UKeyRuntimeManager'
import { LogUtils } from '../utils/LogUtils'
import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { SectionCard } from '../components/SettingsSectionCard'
import { SectionActionRow, SectionToggleRow } from '../components/SectionRows'

const TAG = 'UKeyIndex'
const CURRENT_DEVICE_REFRESH_INTERVAL_MS = 1000

@Entry
@Component
struct Index {
  @State private currentTheme: ThemeMode = ThemeMode.LIGHT
  @State private ukeyUnlockEnabled: boolean = true
  @State private loading: boolean = false
  @State private saving: boolean = false
  @State private statusMessage: string = ''
  @State private currentDevices: LockScreenUKeyDevice[] = []
  @State private currentDeviceMessage: string = ''
  @State private activeCredential: LockScreenUKeyActiveCredential | null = null
  private currentDeviceRefreshTimer: number = -1

  private readonly configRepository: LockScreenAuthRepository = new PreferencesLockScreenAuthRepository()
  private readonly activeCredentialRepository: PreferencesLockScreenUKeyActiveCredentialRepository =
    new PreferencesLockScreenUKeyActiveCredentialRepository()
  private readonly enrollmentService: LockScreenCustomAuthEnrollmentService = new LockScreenCustomAuthEnrollmentService()
  private readonly ddkDeviceProvider: LockScreenUKeyDeviceProvider = new DdkLockScreenUKeyDeviceService()
  private readonly usbFallbackDeviceProvider: LockScreenUKeyDeviceProvider = new UsbLockScreenUKeyDeviceService()

  aboutToAppear(): void {
    this.refreshState()
    this.startCurrentDeviceRefresh()
  }

  aboutToDisappear(): void {
    this.stopCurrentDeviceRefresh()
  }

  private getPageContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private async refreshState(): Promise<void> {
    if (this.loading) {
      return
    }
    this.loading = true
    try {
      let context = this.getPageContext()
      let config = await this.configRepository.loadConfig(context)
      let activeCredential = await this.activeCredentialRepository.loadActiveCredential(context)
      this.ukeyUnlockEnabled = config.ukeyUnlockEnabled
      this.refreshCurrentDevices()
      this.activeCredential = activeCredential
      this.statusMessage = '状态已刷新'
    } catch (err) {
      LogUtils.warn(TAG, `refreshState failed: ${JSON.stringify(err)}`)
      this.statusMessage = '状态刷新失败'
    } finally {
      this.loading = false
    }
  }

  private refreshCurrentDevices(): void {
    let ddkResult = this.ddkDeviceProvider.getCandidateDevices()
    if (ddkResult.success) {
      this.currentDevices = ddkResult.data ?? []
      this.currentDeviceMessage = this.buildCurrentDeviceMessage(this.currentDevices)
      return
    }

    let fallbackResult = this.usbFallbackDeviceProvider.getCandidateDevices()
    if (fallbackResult.success) {
      this.currentDevices = fallbackResult.data ?? []
      this.currentDeviceMessage = this.buildCurrentDeviceMessage(this.currentDevices)
      return
    }

    this.currentDevices = []
    this.currentDeviceMessage = ddkResult.errorMessage ?? fallbackResult.errorMessage ?? 'UKey 读取失败'
  }

  private startCurrentDeviceRefresh(): void {
    if (this.currentDeviceRefreshTimer >= 0) {
      return
    }
    this.currentDeviceRefreshTimer = setInterval(() => {
      this.refreshCurrentDevices()
    }, CURRENT_DEVICE_REFRESH_INTERVAL_MS)
  }

  private stopCurrentDeviceRefresh(): void {
    if (this.currentDeviceRefreshTimer < 0) {
      return
    }
    clearInterval(this.currentDeviceRefreshTimer)
    this.currentDeviceRefreshTimer = -1
  }

  private buildCurrentDeviceMessage(devices: LockScreenUKeyDevice[]): string {
    if (devices.length === 0) {
      return '未识别到 UKey'
    }
    if (devices.length === 1) {
      return '已识别 1 把 UKey'
    }
    return `已识别 ${devices.length} 把 UKey`
  }

  private async handleEnabledChange(value: boolean): Promise<void> {
    if (this.saving) {
      return
    }
    let previous = this.ukeyUnlockEnabled
    this.ukeyUnlockEnabled = value
    this.saving = true
    try {
      let context = this.getPageContext()
      let saved = await this.configRepository.saveConfig(context, {
        ukeyUnlockEnabled: value
      })
      if (!saved) {
        this.ukeyUnlockEnabled = previous
        this.statusMessage = '开关保存失败'
        return
      }
      if (value) {
        await UKeyRuntimeManager.getInstance().reconcileOnStartup()
        this.statusMessage = '已启用，已触发一次 UKey 对账'
      } else {
        let result = await this.enrollmentService.disableAndDeleteActiveCredential(context)
        this.statusMessage = result.success ? '已停用，UKEY解锁凭据已清理' :
          (result.userMessage ?? result.errorMessage ?? '已停用，UKEY解锁凭据清理失败')
      }
      await this.refreshState()
    } catch (err) {
      this.ukeyUnlockEnabled = previous
      LogUtils.warn(TAG, `handleEnabledChange failed: ${JSON.stringify(err)}`)
      this.statusMessage = '开关处理失败'
    } finally {
      this.saving = false
    }
  }

  private formatTime(value: number): string {
    if (!Number.isFinite(value) || value <= 0) {
      return '-'
    }
    try {
      return new Date(value).toLocaleString()
    } catch (_err) {
      return `${value}`
    }
  }

  @Builder
  private switchContent() {
    SectionToggleRow({
      title: 'UKey 锁屏认证',
      description: '开启后插入首把 UKey 会注入锁屏 CustomAuth 凭据',
      isOn: this.ukeyUnlockEnabled,
      processing: this.saving,
      enabledValue: !this.loading && !this.saving,
      currentTheme: this.currentTheme,
      onChange: (value: boolean) => {
        this.handleEnabledChange(value)
      }
    })

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    SectionActionRow({
      title: '当前状态',
      description: this.statusMessage.length > 0 ? this.statusMessage : '读取本应用保存的 UKEY解锁凭据和当前 UKey 设备',
      actionLabel: '刷新',
      isEnabled: !this.loading && !this.saving,
      currentTheme: this.currentTheme,
      onTap: () => {
        this.refreshState()
      }
    })
  }

  @Builder
  private activeCredentialCardContent() {
    Column({ space: 14 }) {
      this.activeCredentialContent()
    }
    .width('100%')
    .padding(16)
  }

  @Builder
  private currentDeviceCardContent() {
    Column({ space: 14 }) {
      this.currentDeviceContent()
    }
    .width('100%')
    .padding(16)
  }

  @Builder
  private infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .width(116)
      Text(value.length > 0 ? value : '-')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private currentDeviceContent() {
    if (this.currentDevices.length === 0) {
      Text(this.currentDeviceMessage.length > 0 ? this.currentDeviceMessage : '未识别到 UKey')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .width('100%')
        .height(56)
        .textAlign(TextAlign.Center)
    } else {
      Column({ space: 12 }) {
        Text(this.currentDeviceMessage)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .width('100%')

        ForEach(this.currentDevices, (device: LockScreenUKeyDevice, index: number) => {
          Column({ space: 10 }) {
            if (this.currentDevices.length > 1) {
              this.infoRow('序号', `${index + 1}`)
            }
            this.infoRow('设备名称', device.deviceName)
            this.infoRow('Serial', device.serial)
          }
          .width('100%')
        }, (device: LockScreenUKeyDevice, index: number): string => `${index}-${device.fingerprint}`)
      }
      .width('100%')
    }
  }

  @Builder
  private activeCredentialContent() {
    if (!this.activeCredential) {
      Text('当前无 UKEY解锁凭据')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .width('100%')
    } else {
      Column({ space: 12 }) {
        this.infoRow('生命周期', this.activeCredential.lifecycle)
        this.infoRow('凭据 ID', this.activeCredential.credentialIdHex)
        this.infoRow('创建时间', this.formatTime(this.activeCredential.createdAt))
      }
      .width('100%')
    }
  }

  build() {
    Column() {
      Row() {
        Text('ukey解锁工具')
          .fontSize(AppStyles.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({
        left: AppStyles.PADDING_LG,
        right: AppStyles.PADDING_LG,
        top: AppStyles.PADDING_MD,
        bottom: AppStyles.PADDING_MD
      })

      Scroll() {
        Column({ space: 16 }) {
          SectionCard({
            title: '认证开关',
            currentTheme: this.currentTheme,
            content: () => {
              this.switchContent()
            }
          })

          SectionCard({
            title: 'UKey设备',
            currentTheme: this.currentTheme,
            content: () => {
              this.currentDeviceCardContent()
            }
          })

          SectionCard({
            title: 'UKEY解锁凭据',
            currentTheme: this.currentTheme,
            content: () => {
              this.activeCredentialCardContent()
            }
          })
        }
        .width('100%')
        .padding({
          left: AppStyles.PADDING_LG,
          right: AppStyles.PADDING_LG,
          bottom: AppStyles.PADDING_LG
        })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }
}
