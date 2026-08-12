export interface LogListItemViewData {
  eventLabel: string
  title: string
  context?: string
}
export interface LogDisplayField {
  key: string
  label: string
  value: string
  fullWidth: boolean
}

export interface LogDetailSection {
  id: string
  title: string
  fields: LogDisplayField[]
}

export interface LogDetailViewData {
  title: string
  typeLabel: string
  timestamp: string
  sections: LogDetailSection[]
}
