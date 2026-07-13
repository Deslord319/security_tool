import { BluetoothRuntimeConnectionStore } from './BluetoothRuntimeConnectionStore'

const NAME_RETRY_AT_MS: number[] = [500, 1500]

export class BluetoothDeviceNameResolver {
  private generations: Map<string, number> = new Map<string, number>()
  private nowProvider: () => number = () => Date.now()
  private waitProvider: (delayMs: number) => Promise<void> = (delayMs: number) => {
    return new Promise<void>((resolve) => setTimeout(resolve, delayMs))
  }

  setTimingProvidersForTest(
    nowProvider: (() => number) | null,
    waitProvider: ((delayMs: number) => Promise<void>) | null
  ): void {
    this.nowProvider = nowProvider ?? (() => Date.now())
    this.waitProvider = waitProvider ?? ((delayMs: number) => {
      return new Promise<void>((resolve) => setTimeout(resolve, delayMs))
    })
  }

  resolveImmediate(deviceId: string): string {
    return BluetoothRuntimeConnectionStore.queryAndCacheDeviceName(deviceId)
  }

  async resolve(
    eventKey: string,
    deviceId: string,
    occurAt: number,
    immediateName: string
  ): Promise<string> {
    const generation = (this.generations.get(eventKey) ?? 0) + 1
    this.generations.set(eventKey, generation)

    if (BluetoothRuntimeConnectionStore.isValidResolvedDeviceName(immediateName)) {
      this.generations.delete(eventKey)
      return immediateName.trim()
    }
    const cachedName = BluetoothRuntimeConnectionStore.getCachedDeviceName(deviceId)
    if (BluetoothRuntimeConnectionStore.isValidResolvedDeviceName(cachedName)) {
      this.generations.delete(eventKey)
      return cachedName.trim()
    }

    for (const retryAt of NAME_RETRY_AT_MS) {
      const remaining = Math.max(0, occurAt + retryAt - this.nowProvider())
      if (remaining > 0) {
        await this.waitProvider(remaining)
      }
      if (!this.isActive(eventKey, generation)) {
        return ''
      }
      const queriedName = BluetoothRuntimeConnectionStore.queryAndCacheDeviceName(deviceId)
      if (BluetoothRuntimeConnectionStore.isValidResolvedDeviceName(queriedName)) {
        this.generations.delete(eventKey)
        return queriedName.trim()
      }
    }
    this.generations.delete(eventKey)
    return ''
  }

  cancel(eventKey: string): void {
    this.generations.delete(eventKey)
  }

  stop(): void {
    for (const eventKey of Array.from(this.generations.keys())) {
      this.cancel(eventKey)
    }
    this.generations.clear()
  }

  private isActive(eventKey: string, generation: number): boolean {
    return this.generations.get(eventKey) === generation
  }
}
