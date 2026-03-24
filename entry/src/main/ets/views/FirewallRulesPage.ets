import { AppColors, AppStyles } from '../constants/AppConstants'
import { FirewallService } from '../services/FirewallService'
import { FirewallCustomRuleService } from '../services/FirewallCustomRuleService'
import { FirewallModeService } from '../services/FirewallModeService'
import { AddRuleDialog } from '../components/AddRuleDialog'
import { BackNavButton } from '../components/BackNavButton'
import { DirectionCard } from '../components/DirectionCard'
import { netFirewall } from '@kit.NetworkKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { common } from '@kit.AbilityKit'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { FirewallPresetMode } from '../models/DataModels'
import { ResultDialogHelper } from '../utils/ResultDialogHelper'

const TAG = 'FirewallRulesPage'
@Component
export struct FirewallRulesPage {
  @Prop currentMode: FirewallPresetMode = 'custom'
  @State rules: netFirewall.NetFirewallRule[] = []
  @State conflictNotice: string = ''
  @State currentTab: number = 0
  @State isLoading: boolean = false
  onBack: () => void = () => {}
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  private addRuleDialogController: CustomDialogController = new CustomDialogController({
    builder: AddRuleDialog({
      onClose: () => {
        this.addRuleDialogController.close()
      },
      onConfirm: (rule: netFirewall.NetFirewallRule) => {
        this.handleAddRule(rule)
      }
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  })

  aboutToAppear() {
    if (this.currentMode !== 'custom') {
      ResultDialogHelper.openAlertDialog(this.getUIContext(), 'failure', '仅自定义模式可进入规则页')
      this.onBack()
      return
    }
    this.loadRules()
  }

  async loadRules() {
    this.isLoading = true
    let context = getContext(this) as common.UIAbilityContext
    this.rules = await FirewallCustomRuleService.listRules(context)
    this.updateConflictNotice()
    this.isLoading = false
  }

  private async persistRules(nextRules: netFirewall.NetFirewallRule[], successMessage: string): Promise<void> {
    let context = getContext(this) as common.UIAbilityContext
    let previousRules = this.rules.map((rule: netFirewall.NetFirewallRule) => FirewallService.cloneRuleForCreate(rule))
    let result = await FirewallModeService.applyCustomRules(context, nextRules)
    if (!result.success) {
      ResultDialogHelper.openAlertDialog(
        this.getUIContext(),
        'failure',
        result.errorMessage?.length ? result.errorMessage : '自定义规则下发失败'
      )
      return
    }
    let saved = await FirewallCustomRuleService.replaceAllRules(context, nextRules)
    if (!saved) {
      let rollbackResult = await FirewallModeService.applyCustomRules(context, previousRules)
      if (!rollbackResult.success) {
        ResultDialogHelper.openAlertDialog(
          this.getUIContext(),
          'failure',
          '规则已下发，但本地保存失败，请重新进入页面确认'
        )
        return
      }
      await this.loadRules()
      ResultDialogHelper.openAlertDialog(this.getUIContext(), 'failure', '自定义规则保存失败，已恢复原策略')
      return
    }
    await this.loadRules()
    hilog.info(0x0001, TAG, 'persistRules success')
  }

  async handleAddRule(rule: netFirewall.NetFirewallRule) {
    let conflict = FirewallService.findRuleConflict(this.rules, rule)
    if (conflict) {
      if (conflict.kind === 'duplicate') {
        ResultDialogHelper.openAlertDialog(this.getUIContext(), 'failure', '存在重复规则')
        return
      }
      if (conflict.kind === 'hard_conflict') {
        let conflictRule = conflict.existingRule
        void this.getUIContext().showAlertDialog({
          title: '存在冲突规则',
          message: '发现动作相反的同类规则，是否用新规则覆盖旧规则？',
          primaryButton: {
            value: '覆盖',
            action: () => {
              this.replaceConflictRule(conflictRule, rule, false)
            }
          },
          secondaryButton: {
            value: '取消',
            action: () => {}
          }
        })
        return
      }
      if (conflict.kind === 'overlap_conflict') {
        void this.getUIContext().showAlertDialog({
          title: '规则范围重叠',
          message: '新规则与现有规则有重叠，仍然继续保存并重新下发吗？',
          primaryButton: {
            value: '继续',
            action: () => {
              this.addRuleDirectly(rule)
            }
          },
          secondaryButton: {
            value: '取消',
            action: () => {}
          }
        })
        return
      }
    }
    await this.addRuleDirectly(rule)
  }

  private async addRuleDirectly(rule: netFirewall.NetFirewallRule): Promise<void> {
    let nextRules = [...this.rules, rule]
    await this.persistRules(nextRules, '自定义规则已新增')
  }

  private openEditRuleDialog(rule: netFirewall.NetFirewallRule): void {
    let dialogController = new CustomDialogController({
      builder: AddRuleDialog({
        onClose: () => {
          dialogController.close()
        },
        initialRule: rule,
        isEditMode: true,
        onConfirm: (updatedRule: netFirewall.NetFirewallRule) => {
          this.handleEditRule(updatedRule)
        }
      }),
      autoCancel: true,
      customStyle: true,
      alignment: DialogAlignment.Center
    })
    dialogController.open()
  }

  async handleEditRule(rule: netFirewall.NetFirewallRule) {
    let currentRuleId = this.getLocalRuleId(rule)
    let comparableRules = this.rules.filter((item: netFirewall.NetFirewallRule) => this.getLocalRuleId(item) !== currentRuleId)
    let conflict = FirewallService.findRuleConflict(comparableRules, rule)
    if (conflict) {
      if (conflict.kind === 'duplicate') {
        ResultDialogHelper.openAlertDialog(this.getUIContext(), 'failure', '存在重复规则')
        return
      }
      if (conflict.kind === 'hard_conflict') {
        let conflictRule = conflict.existingRule
        void this.getUIContext().showAlertDialog({
          title: '存在冲突规则',
          message: '发现动作相反的同类规则，是否删除旧规则并保存本次修改？',
          primaryButton: {
            value: '覆盖',
            action: () => {
              this.replaceConflictRule(conflictRule, rule, true)
            }
          },
          secondaryButton: {
            value: '取消',
            action: () => {}
          }
        })
        return
      }
      if (conflict.kind === 'overlap_conflict') {
        void this.getUIContext().showAlertDialog({
          title: '规则范围重叠',
          message: '修改后的规则与现有规则有重叠，是否继续保存？',
          primaryButton: {
            value: '继续',
            action: () => {
              this.updateRuleDirectly(rule)
            }
          },
          secondaryButton: {
            value: '取消',
            action: () => {}
          }
        })
        return
      }
    }
    await this.updateRuleDirectly(rule)
  }

  private async updateRuleDirectly(rule: netFirewall.NetFirewallRule): Promise<void> {
    let localRuleId = this.getLocalRuleId(rule)
    let nextRules = this.rules.map((item: netFirewall.NetFirewallRule) =>
      this.getLocalRuleId(item) === localRuleId ? rule : item
    )
    await this.persistRules(nextRules, '自定义规则已更新')
  }

  private async replaceConflictRule(
    conflictRule: netFirewall.NetFirewallRule,
    nextRule: netFirewall.NetFirewallRule,
    isEditMode: boolean
  ): Promise<void> {
    let conflictRuleId = this.getLocalRuleId(conflictRule)
    let nextRules = this.rules.filter((item: netFirewall.NetFirewallRule) => this.getLocalRuleId(item) !== conflictRuleId)
    if (isEditMode) {
      let currentRuleId = this.getLocalRuleId(nextRule)
      nextRules = nextRules.map((item: netFirewall.NetFirewallRule) =>
        this.getLocalRuleId(item) === currentRuleId ? nextRule : item
      )
    } else {
      nextRules.push(nextRule)
    }
    await this.persistRules(nextRules, isEditMode ? '冲突规则已替换并保存' : '冲突规则已覆盖')
  }

  async handleDeleteRule(rule: netFirewall.NetFirewallRule) {
    void this.getUIContext().showAlertDialog({
      title: '删除规则',
      message: '删除后会立即重新下发当前自定义策略，是否继续？',
      primaryButton: {
        value: '删除',
        action: () => {
          this.deleteRuleDirectly(rule)
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    })
  }

  private async deleteRuleDirectly(rule: netFirewall.NetFirewallRule): Promise<void> {
    let localRuleId = this.getLocalRuleId(rule)
    let nextRules = this.rules.filter((item: netFirewall.NetFirewallRule) => this.getLocalRuleId(item) !== localRuleId)
    await this.persistRules(nextRules, '自定义规则已删除')
  }

  private getLocalRuleId(rule: netFirewall.NetFirewallRule): number | undefined {
    return FirewallService.getRulePrimaryKey(rule)
  }

  private updateConflictNotice(): void {
    let summary = FirewallService.summarizeConflicts(this.rules)
    let parts: string[] = []
    if (summary.duplicates > 0) {
      parts.push(`重复 ${summary.duplicates} 条`)
    }
    if (summary.hardConflicts > 0) {
      parts.push(`硬冲突 ${summary.hardConflicts} 条`)
    }
    if (summary.overlapConflicts > 0) {
      parts.push(`范围重叠 ${summary.overlapConflicts} 条`)
    }
    this.conflictNotice = parts.length > 0 ? `当前自定义规则集中存在：${parts.join('，')}` : ''
  }

  getFilteredRules(): netFirewall.NetFirewallRule[] {
    if (this.currentTab === 0) {
      return this.rules
    }
    
    // 根据 Tab 索引确定要过滤的规则类型
    const targetType = (() => {
      switch (this.currentTab) {
        case 1: return netFirewall.NetFirewallRuleType.RULE_IP
        case 2: return netFirewall.NetFirewallRuleType.RULE_DOMAIN
        case 3: return netFirewall.NetFirewallRuleType.RULE_DNS
        default: return null
      }
    })()
    
    if (!targetType) return this.rules
    return this.rules.filter((rule: netFirewall.NetFirewallRule) => rule.type === targetType)
  }

  countRulesByType(type: netFirewall.NetFirewallRuleType): number {
    return this.rules.filter((rule: netFirewall.NetFirewallRule) => rule.type === type).length
  }

  countRulesByDirection(direction: netFirewall.NetFirewallRuleDirection): number {
    return this.rules.filter((rule: netFirewall.NetFirewallRule) => rule.direction === direction).length
  }

  getRuleTypeLabel(type: netFirewall.NetFirewallRuleType): string {
    switch (type) {
      case netFirewall.NetFirewallRuleType.RULE_IP:
        return 'IP'
      case netFirewall.NetFirewallRuleType.RULE_DOMAIN:
        return '域名'
      case netFirewall.NetFirewallRuleType.RULE_DNS:
        return 'DNS'
      default:
        return '未知'
    }
  }

  getRuleTypeBgColor(type: netFirewall.NetFirewallRuleType): string {
    switch (type) {
      case netFirewall.NetFirewallRuleType.RULE_IP:
        return AppColors.getColors(this.currentTheme).TAG_BLUE_BG
      case netFirewall.NetFirewallRuleType.RULE_DOMAIN:
        return AppColors.getColors(this.currentTheme).TAG_PURPLE_BG
      case netFirewall.NetFirewallRuleType.RULE_DNS:
        return AppColors.getColors(this.currentTheme).TAG_GREEN_BG
      default:
        return AppColors.getColors(this.currentTheme).TAG_GRAY_BG
    }
  }

  getRuleTypeTextColor(type: netFirewall.NetFirewallRuleType): string {
    switch (type) {
      case netFirewall.NetFirewallRuleType.RULE_IP:
        return AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT
      case netFirewall.NetFirewallRuleType.RULE_DOMAIN:
        return AppColors.getColors(this.currentTheme).TAG_PURPLE_TEXT
      case netFirewall.NetFirewallRuleType.RULE_DNS:
        return AppColors.getColors(this.currentTheme).TAG_GREEN_TEXT
      default:
        return AppColors.getColors(this.currentTheme).TAG_GRAY_TEXT
    }
  }

  getRuleIcon(type: netFirewall.NetFirewallRuleType): Resource {
    switch (type) {
      case netFirewall.NetFirewallRuleType.RULE_IP:
        return $r('app.media.network')
      case netFirewall.NetFirewallRuleType.RULE_DOMAIN:
        return $r('app.media.globe')
      case netFirewall.NetFirewallRuleType.RULE_DNS:
        return $r('app.media.server')
      default:
        return $r('app.media.firewall')
    }
  }

  getDirectionLabel(dir: netFirewall.NetFirewallRuleDirection): string {
    return dir === netFirewall.NetFirewallRuleDirection.RULE_IN ? '入站' : '出站'
  }

  getActionLabel(action: netFirewall.FirewallRuleAction): string {
    return action === netFirewall.FirewallRuleAction.RULE_ALLOW ? '允许' : '阻止'
  }

  getActionBgColor(action: netFirewall.FirewallRuleAction): string {
    return action === netFirewall.FirewallRuleAction.RULE_ALLOW
      ? AppColors.getColors(this.currentTheme).TAG_GREEN_BG
      : AppColors.getColors(this.currentTheme).TAG_RED_BG
  }

  getActionTextColor(action: netFirewall.FirewallRuleAction): string {
    return action === netFirewall.FirewallRuleAction.RULE_ALLOW
      ? AppColors.getColors(this.currentTheme).TAG_GREEN_TEXT
      : AppColors.getColors(this.currentTheme).TAG_RED_TEXT
  }

  getRuleAddress(rule: netFirewall.NetFirewallRule): string {
    if (rule.type === netFirewall.NetFirewallRuleType.RULE_IP) {
      let ip = rule.remoteIps?.[0]
      if (!ip?.address) {
        return '-'
      }
      return ip.mask !== undefined && ip.mask < 32 ? `${ip.address}/${ip.mask}` : ip.address
    }
    if (rule.type === netFirewall.NetFirewallRuleType.RULE_DOMAIN) {
      return rule.domains?.[0]?.domain ?? '-'
    }
    if (rule.type === netFirewall.NetFirewallRuleType.RULE_DNS) {
      return rule.dns?.primaryDns ?? '-'
    }
    return '-'
  }

  getRuleLocalPort(rule: netFirewall.NetFirewallRule): string {
    let port = rule.localPorts?.[0]
    if (!port) {
      return 'ALL'
    }
    return port.startPort === port.endPort ? `${port.startPort}` : `${port.startPort}-${port.endPort}`
  }

  getRuleRemotePort(rule: netFirewall.NetFirewallRule): string {
    let port = rule.remotePorts?.[0]
    if (!port) {
      return 'ALL'
    }
    return port.startPort === port.endPort ? `${port.startPort}` : `${port.startPort}-${port.endPort}`
  }

  getProtocolLabel(rule: netFirewall.NetFirewallRule): string {
    if (rule.protocol === undefined || rule.protocol === null) {
      return 'ALL'
    }
    switch (rule.protocol) {
      case 6:
        return 'TCP'
      case 17:
        return 'UDP'
      case 1:
        return 'ICMP'
      default:
        return 'ALL'
    }
  }

  getTabCount(index: number): number {
    switch (index) {
      case 0:
        return this.rules.length
      case 1:
        return this.countRulesByType(netFirewall.NetFirewallRuleType.RULE_IP)
      case 2:
        return this.countRulesByType(netFirewall.NetFirewallRuleType.RULE_DOMAIN)
      case 3:
        return this.countRulesByType(netFirewall.NetFirewallRuleType.RULE_DNS)
      default:
        return 0
    }
  }

  @Builder
  tabBuilder(title: string, index: number) {
    Row({ space: 8 }) {
      Text(title)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(this.currentTab === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.currentTab === index ? AppColors.BRAND_PRIMARY : AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(this.currentTab === index ? 1 : AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)

      Text(`${this.getTabCount(index)}`)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.currentTab === index ? Color.White : AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(this.currentTab === index ? 1 : AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .padding({ left: 8, right: 8, top: 2, bottom: 2 })
        .backgroundColor(this.currentTab === index ? AppColors.BRAND_PRIMARY : AppColors.getColors(this.currentTheme).BG_COMPONENT)
        .borderRadius(10)
    }
    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
    .backgroundColor(this.currentTab === index ? AppColors.getColors(this.currentTheme).BG_CARD : Color.Transparent)
    .borderRadius(AppStyles.RADIUS_MD)
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row() {
          Column({ space: 4 }) {
            Row({ space: 8 }) {
              BackNavButton({
                onBack: () => {
                  this.onBack()
                }
              })
              Text('自定义规则')
                .fontSize(AppStyles.FONT_SIZE_TITLE)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            }

            Text('当前页面只维护自定义模式规则。保存后会重新下发整套自定义策略。')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Button('+ 新增规则')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(Color.White)
            .backgroundColor(AppColors.BRAND_PRIMARY)
            .borderRadius(AppStyles.RADIUS_MD)
            .height(36)
            .onClick(() => {
              this.addRuleDialogController.open()
            })
        }
        .width('100%')

        if (this.conflictNotice.length > 0) {
          Row({ space: 8 }) {
            Text('注意')
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontWeight(FontWeight.Medium)
              .fontColor('#8A5200')
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor('#FFE8B3')
              .borderRadius(10)

            Text(this.conflictNotice)
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor('#8A5200')
              .layoutWeight(1)
          }
          .width('100%')
          .padding(12)
          .backgroundColor('#FFF7E6')
          .borderRadius(AppStyles.RADIUS_MD)
          .border({ width: 1, color: '#FFD591' })
        }

        Row({ space: 16 }) {
          DirectionCard({
            label: '入站规则',
            count: this.countRulesByDirection(netFirewall.NetFirewallRuleDirection.RULE_IN),
            gradientStart: '#FF9500',
            gradientEnd: '#FFCC00',
            icon: $r('app.media.arrow_down')
          })
            .layoutWeight(1)

          DirectionCard({
            label: '出站规则',
            count: this.countRulesByDirection(netFirewall.NetFirewallRuleDirection.RULE_OUT),
            gradientStart: '#0A84FF',
            gradientEnd: '#00C6FF',
            icon: $r('app.media.arrow_up')
          })
            .layoutWeight(1)
        }
        .width('100%')

        Tabs({ barPosition: BarPosition.Start }) {
          TabContent() {
            this.ruleListBuilder()
          }.tabBar(this.tabBuilder('全部规则', 0))

          TabContent() {
            this.ruleListBuilder()
          }.tabBar(this.tabBuilder('IP规则', 1))

          TabContent() {
            this.ruleListBuilder()
          }.tabBar(this.tabBuilder('域名规则', 2))

          TabContent() {
            this.ruleListBuilder()
          }.tabBar(this.tabBuilder('DNS规则', 3))
        }
        .barMode(BarMode.Scrollable)
        .barBackgroundColor(Color.Transparent)
        .divider(null)
        .onChange((index: number) => {
          this.currentTab = index
        })
        .layoutWeight(1)
      }
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_LG, bottom: AppStyles.PADDING_LG })
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  @Builder
  ruleListBuilder() {
    Column() {
      if (this.isLoading) {
        Column({ space: 10 }) {
          LoadingProgress()
            .width(42)
            .height(42)
          Text('正在加载自定义规则...')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.getFilteredRules().length === 0) {
        Column({ space: 10 }) {
          Text('当前没有自定义规则')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        List({ space: 12 }) {
          ForEach(this.getFilteredRules(), (rule: netFirewall.NetFirewallRule) => {
            ListItem() {
              Column({ space: 14 }) {
                Row({ space: 12 }) {
                  Column() {
                    Image(this.getRuleIcon(rule.type))
                      .width(18)
                      .height(18)
                      .fillColor(Color.White)
                  }
                  .width(40)
                  .height(40)
                  .borderRadius(12)
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)
                  .backgroundColor(this.getRuleTypeTextColor(rule.type))

                  Column({ space: 6 }) {
                    Text(rule.name ?? '-')
                      .fontSize(AppStyles.FONT_SIZE_BODY)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    Row({ space: 8 }) {
                      Text(this.getRuleTypeLabel(rule.type))
                        .fontSize(AppStyles.FONT_SIZE_CAPTION)
                        .fontColor(this.getRuleTypeTextColor(rule.type))
                        .backgroundColor(this.getRuleTypeBgColor(rule.type))
                        .borderRadius(10)
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 })

                      Text(this.getDirectionLabel(rule.direction))
                        .fontSize(AppStyles.FONT_SIZE_CAPTION)
                        .fontColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)
                        .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)
                        .borderRadius(10)
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 })

                      Text(this.getActionLabel(rule.action))
                        .fontSize(AppStyles.FONT_SIZE_CAPTION)
                        .fontColor(this.getActionTextColor(rule.action))
                        .backgroundColor(this.getActionBgColor(rule.action))
                        .borderRadius(10)
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    }
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Row({ space: 8 }) {
                    Button('删除')
                      .fontSize(AppStyles.FONT_SIZE_CAPTION)
                      .fontColor(AppColors.DANGER)
                      .backgroundColor(AppColors.getColors(this.currentTheme).TAG_RED_BG)
                      .borderRadius(AppStyles.RADIUS_SM)
                      .height(30)
                      .onClick(() => {
                        this.handleDeleteRule(rule)
                      })
                  }
                }
                .width('100%')

                Column({ space: 10 }) {
                  this.detailRow('远端地址', this.getRuleAddress(rule))
                  this.detailRow('本地端口', this.getRuleLocalPort(rule))
                  this.detailRow('远端端口', this.getRuleRemotePort(rule))
                  this.detailRow('协议', this.getProtocolLabel(rule))
                }
                .width('100%')
              }
              .width('100%')
              .padding(18)
              .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
              .borderRadius(AppStyles.RADIUS_LG)
              .border({
                width: 1,
                color: AppColors.getColors(this.currentTheme).BORDER
              })
              .onClick(() => {
                this.openEditRuleDialog(rule)
              })
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: AppStyles.PADDING_MD, bottom: 2 })
  }

  @Builder
  detailRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .width(92)

      Text(value)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}
