import { common } from '@kit.AbilityKit'
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit'
import {
  LockScreenAuthRepository,
  PreferencesLockScreenAuthRepository
} from '../services/identity/lockscreen-auth/LockScreenAuthRepository'
import {
  CustomAuthCredentialVerificationSummary,
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
  LockScreenUKeyDeviceProvider
} from '../services/identity/lockscreen-auth/LockScreenUKeyDeviceService'
import { UKeyRuntimeManager } from '../runtime/UKeyRuntimeManager'
import { LogUtils } from '../utils/LogUtils'
import { AppColors, AppStyles } from '../constants/AppConstants'
import { ThemeMode } from '../theme/ThemeColors'
import { SectionCard } from '../components/SettingsSectionCard'
import { SectionActionRow, SectionToggleRow } from '../components/SectionRows'

const TAG = 'UKeyIndex'
const USB_ATTACH_REFRESH_DELAYS_MS: number[] = [300, 1000, 2500]
const USB_DETACH_REFRESH_DELAY_MS = 600

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
  @State private visibleCredentialAvailable: boolean = false
  @State private visibleCredentialId: string = ''
  @State private visibleCredentialCreatedAt: number = 0
  @State private visibleCredentialLifecycle: string = ''
  @State private visibleCredentialActive: boolean = false
  @State private verifyingCredential: boolean = false
  @State private credentialSubmitting: boolean = false
  @State private systemPinInput: string = ''
  @State private ukeyPasswordInput: string = ''
  @State private verifyUKeyPasswordInput: string = ''
  private runtimeStateRefreshInFlight: boolean = false
  private usbSubscriber: commonEventManager.CommonEventSubscriber | null = null

  private readonly configRepository: LockScreenAuthRepository = new PreferencesLockScreenAuthRepository()
  private readonly activeCredentialRepository: PreferencesLockScreenUKeyActiveCredentialRepository =
    new PreferencesLockScreenUKeyActiveCredentialRepository()
  private readonly enrollmentService: LockScreenCustomAuthEnrollmentService = new LockScreenCustomAuthEnrollmentService()
  private readonly ddkDeviceProvider: LockScreenUKeyDeviceProvider = new DdkLockScreenUKeyDeviceService()

  aboutToAppear(): void {
    this.refreshState()
    this.registerUKeyDeviceEvents()
  }

  aboutToDisappear(): void {
    this.unregisterUKeyDeviceEvents()
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
      await this.enrollmentService.reconcileSystemCredentials(context)
      let activeCredential = await this.activeCredentialRepository.loadActiveCredential(context)
      this.ukeyUnlockEnabled = config.ukeyUnlockEnabled
      this.refreshCurrentDevices()
      this.updateActiveCredential(activeCredential)
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

    this.currentDevices = []
    this.currentDeviceMessage = ddkResult.errorMessage ?? 'UKey 读取失败'
  }

  private async refreshRuntimeState(): Promise<void> {
    if (this.runtimeStateRefreshInFlight) {
      return
    }
    this.runtimeStateRefreshInFlight = true
    try {
      this.refreshCurrentDevices()
      let context = this.getPageContext()
      await this.enrollmentService.reconcileSystemCredentials(context)
      this.updateActiveCredential(await this.activeCredentialRepository.loadActiveCredential(context))
    } catch (err) {
      LogUtils.warn(TAG, `refreshRuntimeState failed: ${JSON.stringify(err)}`)
    } finally {
      this.runtimeStateRefreshInFlight = false
    }
  }

  private registerUKeyDeviceEvents(): void {
    if (this.usbSubscriber) {
      return
    }
    let subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
      events: [
        commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED,
        commonEventManager.Support.COMMON_EVENT_USB_DEVICE_DETACHED
      ]
    }
    commonEventManager.createSubscriber(subscribeInfo, (err: BusinessError, subscriber) => {
      if (err) {
        LogUtils.warn(TAG, `create USB subscriber failed: ${JSON.stringify(err)}`)
        return
      }
      this.usbSubscriber = subscriber
      commonEventManager.subscribe(subscriber, (callbackErr: BusinessError, data: commonEventManager.CommonEventData) => {
        if (callbackErr) {
          LogUtils.warn(TAG, `USB event callback failed: ${JSON.stringify(callbackErr)}`)
          return
        }
        this.handleUKeyDeviceEvent(data)
      })
    })
  }

  private unregisterUKeyDeviceEvents(): void {
    let subscriber = this.usbSubscriber
    this.usbSubscriber = null
    if (!subscriber) {
      return
    }
    commonEventManager.unsubscribe(subscriber, (err?: BusinessError) => {
      if (err) {
        LogUtils.warn(TAG, `unsubscribe USB event failed: ${JSON.stringify(err)}`)
      }
    })
  }

  private handleUKeyDeviceEvent(data: commonEventManager.CommonEventData): void {
    let eventName = data.event ?? ''
    if (eventName === commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED) {
      this.scheduleRuntimeStateRefresh(USB_ATTACH_REFRESH_DELAYS_MS)
      return
    }
    if (eventName === commonEventManager.Support.COMMON_EVENT_USB_DEVICE_DETACHED) {
      this.scheduleRuntimeStateRefresh([USB_DETACH_REFRESH_DELAY_MS])
      return
    }
    this.refreshRuntimeState()
  }

  private scheduleRuntimeStateRefresh(delaysMs: number[]): void {
    for (let delayMs of delaysMs) {
      setTimeout(() => {
        this.refreshRuntimeState()
      }, delayMs)
    }
  }

  private updateActiveCredential(credential: LockScreenUKeyActiveCredential | null): void {
    if (!credential ||
      (credential.lifecycle !== 'active' && credential.lifecycle !== 'inactive') ||
      credential.userCredentials.length === 0 ||
      credential.userCredentials[0].credentialIdHex.length === 0) {
      this.visibleCredentialAvailable = false
      this.visibleCredentialId = ''
      this.visibleCredentialCreatedAt = 0
      this.visibleCredentialLifecycle = ''
      this.visibleCredentialActive = false
      return
    }
    this.visibleCredentialAvailable = true
    this.visibleCredentialId = credential.userCredentials[0].credentialIdHex
    this.visibleCredentialCreatedAt = credential.createdAt
    this.visibleCredentialLifecycle = credential.lifecycle
    this.visibleCredentialActive = credential.lifecycle === 'active'
  }

  private buildCurrentDeviceMessage(devices: LockScreenUKeyDevice[]): string {
    if (devices.length === 0) {
      return ''
    }
    if (devices.length === 1) {
      return '已识别 1 把 UKey'
    }
    return `已识别 ${devices.length} 把 UKey`
  }

  private hasVisibleCredential(): boolean {
    return this.visibleCredentialAvailable
  }

  private hasVerifiableActiveCredential(): boolean {
    return this.visibleCredentialActive
  }

  private hasOperableUKey(): boolean {
    if (!this.ukeyUnlockEnabled) {
      return false
    }
    if (this.visibleCredentialAvailable) {
      return this.visibleCredentialActive
    }
    return this.currentDevices.length > 0
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
      }
      this.statusMessage = ''
      await this.refreshState()
    } catch (err) {
      this.ukeyUnlockEnabled = previous
      LogUtils.warn(TAG, `handleEnabledChange failed: ${JSON.stringify(err)}`)
      this.statusMessage = '开关处理失败'
    } finally {
      this.saving = false
    }
  }

  private async handleCredentialAuthVerify(): Promise<void> {
    if (this.verifyingCredential || this.loading || this.saving) {
      return
    }
    if (!this.hasVerifiableActiveCredential()) {
      return
    }
    let ukeyPassword = this.verifyUKeyPasswordInput.trim()
    if (ukeyPassword.length === 0) {
      this.statusMessage = '请输入 UKey 密码'
      return
    }
    this.verifyingCredential = true
    this.statusMessage = '正在验证 UKEY解锁凭据认证能力'
    try {
      let context = this.getPageContext()
      let result = await this.enrollmentService.verifyActiveCredentials(context, ukeyPassword)
      this.updateActiveCredential(await this.activeCredentialRepository.loadActiveCredential(context))
      this.statusMessage = result.success ? this.buildVerificationSuccessMessage(result.data ?? null) :
        (result.userMessage ?? result.errorMessage ?? 'UKEY解锁凭据认证验证失败')
    } catch (err) {
      LogUtils.warn(TAG, `handleCredentialAuthVerify failed: ${JSON.stringify(err)}`)
      this.statusMessage = 'UKEY解锁凭据认证验证失败'
    } finally {
      this.verifyUKeyPasswordInput = ''
      this.verifyingCredential = false
    }
  }

  private async handleAddCredential(): Promise<void> {
    if (this.credentialSubmitting || this.loading || this.saving) {
      return
    }
    let systemPin = this.systemPinInput.trim()
    let ukeyPassword = this.ukeyPasswordInput.trim()
    if (systemPin.length === 0) {
      this.statusMessage = '请输入系统 PIN'
      return
    }
    if (ukeyPassword.length === 0) {
      this.statusMessage = '请输入 UKey 密码'
      return
    }
    this.credentialSubmitting = true
    this.statusMessage = '正在添加 UKEY解锁凭据'
    try {
      let context = this.getPageContext()
      let result = await this.enrollmentService.addCredentialWithUserInput(context, systemPin, ukeyPassword)
      this.updateActiveCredential(await this.activeCredentialRepository.loadActiveCredential(context))
      this.statusMessage = result.success ? 'UKEY解锁凭据已添加' :
        (result.userMessage ?? result.errorMessage ?? 'UKEY解锁凭据添加失败')
    } catch (err) {
      LogUtils.warn(TAG, `handleAddCredential failed: ${JSON.stringify(err)}`)
      this.statusMessage = 'UKEY解锁凭据添加失败'
    } finally {
      this.systemPinInput = ''
      this.ukeyPasswordInput = ''
      this.credentialSubmitting = false
    }
  }

  private async handleDeleteCredential(): Promise<void> {
    if (this.credentialSubmitting || this.loading || this.saving) {
      return
    }
    if (!this.hasVisibleCredential()) {
      return
    }
    let systemPin = this.systemPinInput.trim()
    if (systemPin.length === 0) {
      this.statusMessage = '请输入系统 PIN'
      return
    }
    this.credentialSubmitting = true
    this.statusMessage = '正在删除 UKEY解锁凭据'
    try {
      let context = this.getPageContext()
      let result = await this.enrollmentService.deleteActiveCredentialByPin(context, systemPin)
      this.updateActiveCredential(await this.activeCredentialRepository.loadActiveCredential(context))
      this.statusMessage = result.success ? 'UKEY解锁凭据已删除' :
        (result.userMessage ?? result.errorMessage ?? 'UKEY解锁凭据删除失败')
    } catch (err) {
      LogUtils.warn(TAG, `handleDeleteCredential failed: ${JSON.stringify(err)}`)
      this.statusMessage = 'UKEY解锁凭据删除失败'
    } finally {
      this.systemPinInput = ''
      this.ukeyPasswordInput = ''
      this.credentialSubmitting = false
    }
  }

  private buildVerificationSuccessMessage(summary: CustomAuthCredentialVerificationSummary | null): string {
    if (!summary) {
      return 'UKEY解锁凭据认证验证完成'
    }
    return `认证成功 ${summary.successCount}/${summary.total}`
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
      description: '开启后认证器允许使用已添加的 UKEY解锁凭据',
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
      description: this.statusMessage,
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
  private credentialVerificationCardContent() {
    Column({ space: 12 }) {
      TextInput({ text: this.verifyUKeyPasswordInput, placeholder: '验证 UKey 密码' })
        .type(InputType.Password)
        .height(36)
        .width('100%')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .placeholderColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
        .borderRadius(AppStyles.RADIUS_SM)
        .border({
          width: AppStyles.DIVIDER_HEIGHT,
          color: AppColors.getColors(this.currentTheme).BORDER,
          style: BorderStyle.Solid
        })
        .enabled(this.ukeyUnlockEnabled && this.hasVerifiableActiveCredential() && !this.loading && !this.saving &&
          !this.verifyingCredential)
        .onChange((value: string) => {
          this.verifyUKeyPasswordInput = value
        })

      Button(this.verifyingCredential ? '验证中' : '验证凭据')
        .type(ButtonType.Normal)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Regular)
        .fontColor(Color.White)
        .backgroundColor(AppColors.BRAND_PRIMARY)
        .borderRadius(AppStyles.RADIUS_SM)
        .height(36)
        .width(128)
        .stateEffect(true)
        .enabled(this.ukeyUnlockEnabled && this.hasVerifiableActiveCredential() && !this.loading && !this.saving &&
          !this.verifyingCredential)
        .opacity(this.ukeyUnlockEnabled && this.hasVerifiableActiveCredential() && !this.loading && !this.saving &&
          !this.verifyingCredential ? 1 : 0.56)
        .onClick(() => {
          this.handleCredentialAuthVerify()
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
  }

  @Builder
  private credentialOperationCardContent() {
    Column({ space: 12 }) {
      TextInput({ text: this.systemPinInput, placeholder: '系统 PIN' })
        .type(InputType.Password)
        .height(36)
        .width('100%')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .placeholderColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
        .borderRadius(AppStyles.RADIUS_SM)
        .border({
          width: AppStyles.DIVIDER_HEIGHT,
          color: AppColors.getColors(this.currentTheme).BORDER,
          style: BorderStyle.Solid
        })
        .enabled(this.hasOperableUKey() && !this.loading && !this.saving && !this.credentialSubmitting)
        .onChange((value: string) => {
          this.systemPinInput = value
        })

      TextInput({ text: this.ukeyPasswordInput, placeholder: 'UKey 密码' })
        .type(InputType.Password)
        .height(36)
        .width('100%')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .placeholderColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
        .borderRadius(AppStyles.RADIUS_SM)
        .border({
          width: AppStyles.DIVIDER_HEIGHT,
          color: AppColors.getColors(this.currentTheme).BORDER,
          style: BorderStyle.Solid
        })
        .enabled(this.hasOperableUKey() && !this.loading && !this.saving && !this.credentialSubmitting)
        .onChange((value: string) => {
          this.ukeyPasswordInput = value
        })

      Row({ space: 10 }) {
        Button(this.credentialSubmitting ? '处理中' : '添加凭据')
          .type(ButtonType.Normal)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Regular)
          .fontColor(Color.White)
          .backgroundColor(AppColors.BRAND_PRIMARY)
          .borderRadius(AppStyles.RADIUS_SM)
          .height(36)
          .width(112)
          .stateEffect(true)
          .enabled(this.hasOperableUKey() && !this.loading && !this.saving && !this.credentialSubmitting)
          .opacity(this.hasOperableUKey() && !this.loading && !this.saving && !this.credentialSubmitting ? 1 : 0.56)
          .onClick(() => {
            this.handleAddCredential()
          })

        Button(this.credentialSubmitting ? '处理中' : '删除凭据')
          .type(ButtonType.Normal)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Regular)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)
          .borderRadius(AppStyles.RADIUS_SM)
          .height(36)
          .width(112)
          .stateEffect(true)
          .enabled(this.hasVerifiableActiveCredential() && !this.loading && !this.saving && !this.credentialSubmitting)
          .opacity(this.hasVerifiableActiveCredential() && !this.loading && !this.saving && !this.credentialSubmitting ?
            1 : 0.56)
          .onClick(() => {
            this.handleDeleteCredential()
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
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
      Blank()
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
    if (!this.hasVisibleCredential()) {
      Blank()
    } else {
      Column({ space: 12 }) {
        Row() {
          Text('凭据 ID')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
            .width(116)
          Text(this.visibleCredentialId.length > 0 ? this.visibleCredentialId : '-')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
            .layoutWeight(1)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Row() {
          Text('创建时间')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
            .width(116)
          Text(this.formatTime(this.visibleCredentialCreatedAt))
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
            .layoutWeight(1)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Row() {
          Text('状态')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
            .width(116)
          Text(this.visibleCredentialLifecycle.length > 0 ? this.visibleCredentialLifecycle : '-')
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
      .width('100%')
    }
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Image($r('app.media.startIcon'))
          .width(28)
          .height(28)
          .objectFit(ImageFit.Contain)
          .draggable(false)

        Text('ukey解锁工具')
          .fontSize(AppStyles.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
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
            title: '凭据操作',
            currentTheme: this.currentTheme,
            content: () => {
              this.credentialOperationCardContent()
            }
          })

          SectionCard({
            title: '凭据认证验证',
            currentTheme: this.currentTheme,
            content: () => {
              this.credentialVerificationCardContent()
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
