export interface StorageResult<T> {
  success: boolean
  code: 'ok' | 'read_failed' | 'save_failed' | 'storage_init_failed' | 'data_corrupted'
  message?: string
  data?: T
}
