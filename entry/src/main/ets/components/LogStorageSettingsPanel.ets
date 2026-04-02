import { AppColors, AppStyles } from '../constants/AppConstants'
import { LogManageStrings } from '../constants/modules/LogManageStrings'
import { LOG_MAX_ENTRIES_OPTIONS, LOG_RETENTION_OPTIONS } from '../models/DataModels'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { LogStorageSettingsViewModel } from '../viewmodels/log-manage/LogStorageSettingsViewModel'
import { SectionCard } from './SettingsSectionCard'
import { SectionSelectRow } from './SectionRows'

@Component
export struct LogStorageSettingsPanel {
  @ObjectLink viewModel: LogStorageSettingsViewModel
  formControlWidth: number = 140
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  private buildMaxEntriesOptions(): SelectOption[] {
    return LOG_MAX_ENTRIES_OPTIONS.map((value: number): SelectOption => ({ value: `${value}` } as SelectOption))
  }

  private buildRetentionOptions(): SelectOption[] {
    return LOG_RETENTION_OPTIONS.map((value: number): SelectOption => ({ value: `${value}` } as SelectOption))
  }

  private getSelectedMaxEntriesIndex(): number {
    let index = LOG_MAX_ENTRIES_OPTIONS.indexOf(this.viewModel.state.maxLocalEntries)
    return index >= 0 ? index : 0
  }

  private getSelectedRetentionIndex(): number {
    let index = LOG_RETENTION_OPTIONS.indexOf(this.viewModel.state.retentionDays)
    return index >= 0 ? index : 0
  }

  @Builder
  private settingsContent() {
    SectionSelectRow({
      title: LogManageStrings.maxEntriesLabel,
      description: LogManageStrings.maxEntriesDescription,
      options: this.buildMaxEntriesOptions(),
      selectedIndex: this.getSelectedMaxEntriesIndex(),
      value: `${this.viewModel.state.maxLocalEntries}`,
      selectWidth: this.formControlWidth,
      onSelect: (index: number) => this.viewModel.setMaxLocalEntries(LOG_MAX_ENTRIES_OPTIONS[index] ?? LOG_MAX_ENTRIES_OPTIONS[0])
    })

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    SectionSelectRow({
      title: LogManageStrings.retentionDaysLabel,
      description: LogManageStrings.retentionDaysDescription,
      options: this.buildRetentionOptions(),
      selectedIndex: this.getSelectedRetentionIndex(),
      value: `${this.viewModel.state.retentionDays}`,
      selectWidth: this.formControlWidth,
      onSelect: (index: number) => this.viewModel.setRetentionDays(LOG_RETENTION_OPTIONS[index] ?? LOG_RETENTION_OPTIONS[0])
    })
  }

  build() {
    SectionCard({
      title: LogManageStrings.settingsTitle,
      content: () => {
        this.settingsContent()
      }
    })
  }
}
