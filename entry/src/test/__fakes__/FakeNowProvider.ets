export class FakeNowProvider {
  private currentValue: number

  constructor(seed: number = 1700000000000) {
    this.currentValue = seed
  }

  now(): number {
    return this.currentValue
  }

  set(value: number): void {
    this.currentValue = value
  }
}
