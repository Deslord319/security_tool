export class FakeSystemSettingsPort {
  openResult: boolean = true

  async openPasswordSettings(): Promise<boolean> {
    return this.openResult
  }
}
