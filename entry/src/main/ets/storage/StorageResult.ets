export interface StorageResult<TCode extends string = string, TData = void> {
  success: boolean
  code: TCode
  message?: string
  data?: TData
}
