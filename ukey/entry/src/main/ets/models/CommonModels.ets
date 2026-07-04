export interface OperationResult<T = void> {
  success: boolean
  data?: T
  errorCode?: number
  errorMessage?: string
  userMessage?: string
  stage?: string
  suggestion?: string
}
