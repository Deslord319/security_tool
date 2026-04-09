export class FakePreferenceStore {
  private values: Map<string, Object> = new Map<string, Object>()
  failGet: boolean = false
  failPut: boolean = false

  async get(key: string, defaultValue?: Object): Promise<Object> {
    if (this.failGet) {
      throw new Error('fake_get_failed')
    }
    return this.values.has(key) ? this.values.get(key)! : (defaultValue as Object)
  }

  async put(key: string, value: Object): Promise<void> {
    if (this.failPut) {
      throw new Error('fake_put_failed')
    }
    this.values.set(key, value)
  }

  async flush(): Promise<void> {}
}
