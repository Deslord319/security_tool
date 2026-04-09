export interface FakeAuthResult {
  success: boolean
  reason?: string
  errorCode?: number
  message?: string
}

export class FakeAuthPort {
  availability: boolean = true
  result: FakeAuthResult = { success: true }

  checkAvailability(): boolean {
    return this.availability
  }

  async authenticate(): Promise<FakeAuthResult> {
    return this.result
  }
}
