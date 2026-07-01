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
  LockScreenUKeyBinding
} from '../models/identity/lockscreen-auth/LockScreenAuthModels'
import {
  PreferencesLockScreenUKeyActiveCredentialRepository,
  PreferencesLockScreenUKeyBindingRepository
} from '../services/identity/lockscreen-auth/LockScreenUKeyBindingRepository'
import { UKeyRuntimeManager } from '../runtime/UKeyRuntimeManager'
import { LogUtils } from '../utils/LogUtils'
import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { SectionCard } from '../components/SettingsSectionCard'
import { SectionActionRow, SectionToggleRow } from '../components/SectionRows'

const TAG = 'UKeyIndex'

@Entry
@Component
struct Index {
  @State private currentTheme: ThemeMode = ThemeMode.LIGHT
  @State private ukeyUnlockEnabled: boolean = true
  @State private loading: boolean = false
  @State private saving: boolean = false
  @State private statusMessage: string = ''
  @State private binding: LockScreenUKeyBinding | null = null
  @State private activeCredential: LockScreenUKeyActiveCredential | null = null

  private readonly configRepository: LockScreenAuthRepository = new PreferencesLockScreenAuthRepository()
  private readonly bindingRepository: PreferencesLockScreenUKeyBindingRepository =
    new PreferencesLockScreenUKeyBindingRepository()
  private readonly activeCredentialRepository: PreferencesLockScreenUKeyActiveCredentialRepository =
    new PreferencesLockScreenUKeyActiveCredentialRepository()
  private readonly enrollmentService: LockScreenCustomAuthEnrollmentService = new LockScreenCustomAuthEnrollmentService()

  aboutToAppear(): void {
    this.refreshState()
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
      let binding = await this.bindingRepository.loadBinding(context)
      let activeCredential = await this.activeCredentialRepository.loadActiveCredential(context)
      this.ukeyUnlockEnabled = config.ukeyUnlockEnabled
      this.binding = binding
      this.activeCredential = activeCredential
      this.statusMessage = '状态已刷新'
    } catch (err) {
      LogUtils.warn(TAG, `refreshState failed: ${JSON.stringify(err)}`)
      this.statusMessage = '状态刷新失败'
    } finally {
      this.loading = false
    }
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
        this.statusMessage = result.success ? '已停用，活动凭据已清理' :
          (result.userMessage ?? result.errorMessage ?? '已停用，活动凭据清理失败')
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
      description: this.statusMessage.length > 0 ? this.statusMessage : '读取本应用保存的 UKey 绑定和活动凭据',
      actionLabel: '刷新',
      isEnabled: !this.loading && !this.saving,
      currentTheme: this.currentTheme,
      onTap: () => {
        this.refreshState()
      }
    })
  }

  @Builder
  private bindingCardContent() {
    Column({ space: 14 }) {
      this.bindingContent()
    }
    .width('100%')
    .padding(16)
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
  private bindingContent() {
    if (!this.binding) {
      Text('未绑定 UKey')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .width('100%')
        .height(56)
        .textAlign(TextAlign.Center)
    } else {
      Column({ space: 12 }) {
        this.infoRow('设备名称', this.binding.deviceName)
        this.infoRow('设备 ID', this.binding.deviceId)
        this.infoRow('指纹', this.binding.fingerprint)
        this.infoRow('用户 ID', `${this.binding.userId}`)
        this.infoRow('绑定时间', this.formatTime(this.binding.boundAt))
        this.infoRow('标识类型', this.binding.stableIdentifier ? 'serial' : '弱标识')
      }
      .width('100%')
    }
  }

  @Builder
  private activeCredentialContent() {
    if (!this.activeCredential) {
      Text('当前无活动凭据')
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
            title: '当前绑定 Key',
            currentTheme: this.currentTheme,
            content: () => {
              this.bindingCardContent()
            }
          })

          SectionCard({
            title: '活动凭据',
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
