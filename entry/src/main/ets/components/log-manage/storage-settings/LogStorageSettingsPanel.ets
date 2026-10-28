import { LogManageSettingStrings } from '../../../constants/modules/LogManageStrings'
import {
  DEFAULT_LOG_STORAGE_CONFIG,
  LOG_MAX_ENTRIES_OPTIONS,
  LOG_RETENTION_OPTIONS
} from '../../../models/LogModels'
import { ThemeMode } from '../../../theme/ThemeColors'
import { SectionCard } from '../../SettingsSectionCard'
import { SectionSelectRow } from '../../SectionRows'

@ComponentV2
export struct LogStorageSettingsPanel {
  @Param maxLocalEntries: number = DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries
  @Param retentionDays: number = DEFAULT_LOG_STORAGE_CONFIG.retentionDays
  @Param formControlWidth: number = 140
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onSelectMaxEntries: (index: number) => void = () => {}
  @Event onSelectRetentionDays: (index: number) => void = () => {}

  private buildMaxEntriesOptions(): SelectOption[] {
    return LOG_MAX_ENTRIES_OPTIONS.map((value: number): SelectOption => ({ value: `${value}` } as SelectOption))
  }

  private buildRetentionOptions(): SelectOption[] {
    return LOG_RETENTION_OPTIONS.map((value: number): SelectOption => ({ value: `${value}` } as SelectOption))
  }

  private getSelectedMaxEntriesIndex(): number {
    let index = LOG_MAX_ENTRIES_OPTIONS.indexOf(this.maxLocalEntries)
    return index >= 0 ? index : 0
  }

  private getSelectedRetentionIndex(): number {
    let index = LOG_RETENTION_OPTIONS.indexOf(this.retentionDays)
    return index >= 0 ? index : 0
  }

  @Builder
  private settingsContent() {
    SectionSelectRow({
      title: $r('app.string.log_manage_setting_max_entries_label'),
      description: $r('app.string.log_manage_setting_max_entries_description'),
      options: this.buildMaxEntriesOptions(),
      selectedIndex: this.getSelectedMaxEntriesIndex(),
      value: `${this.maxLocalEntries}`,
      selectWidth: this.formControlWidth,
      currentTheme: this.currentTheme,
      onSelect: this.onSelectMaxEntries
    })

    Divider()

    SectionSelectRow({
      title: $r('app.string.log_manage_setting_retention_days_label'),
      description: $r('app.string.log_manage_setting_retention_days_description'),
      options: this.buildRetentionOptions(),
      selectedIndex: this.getSelectedRetentionIndex(),
      value: `${this.retentionDays}`,
      selectWidth: this.formControlWidth,
      currentTheme: this.currentTheme,
      onSelect: this.onSelectRetentionDays
    })
  }

  build() {
    SectionCard({
      title: $r('app.string.log_manage_page_settings_title'),
      currentTheme: this.currentTheme,
      content: () => {
        this.settingsContent()
      }
    })
  }
}
