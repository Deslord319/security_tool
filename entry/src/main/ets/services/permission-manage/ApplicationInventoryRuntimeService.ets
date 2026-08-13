import {
  ApplicationInventoryChangePayload,
  ApplicationInventoryChangeSubscription,
  ApplicationInventoryEventBus
} from './ApplicationInventoryEventBus'
import { LogUtils } from '../../utils/LogUtils'

const TAG = 'AppInventoryRuntime'

export type ApplicationInventoryChangeConsumer = (payload: ApplicationInventoryChangePayload) => Promise<void>

export class ApplicationInventoryRuntimeService {
  private subscription: ApplicationInventoryChangeSubscription | null = null
  private subscribing: boolean = false
  private active: boolean = false
  private subscribeToken: number = 0
  private latestPayload: ApplicationInventoryChangePayload | null = null
  private readonly consumer: ApplicationInventoryChangeConsumer

  constructor(consumer: ApplicationInventoryChangeConsumer) {
    this.consumer = consumer
  }

  start(): void {
    if (this.subscription || this.subscribing) {
      return
    }
    this.active = true
    this.subscribing = true
    let token = ++this.subscribeToken
    ApplicationInventoryEventBus.subscribe(async (payload: ApplicationInventoryChangePayload): Promise<void> => {
      this.latestPayload = payload
      await this.consumer(payload)
    }).then((subscription: ApplicationInventoryChangeSubscription | null) => {
      if (token !== this.subscribeToken || !this.active) {
        ApplicationInventoryEventBus.unsubscribe(subscription)
        return
      }
      this.subscribing = false
      this.subscription = subscription
      if (!subscription) {
        LogUtils.warn(TAG, 'application inventory runtime subscriber not created')
      }
    }).catch((err: Error) => {
      if (token === this.subscribeToken) {
        this.subscribing = false
      }
      LogUtils.warn(TAG, 'start application inventory runtime subscriber failed: %{public}s', JSON.stringify(err))
    })
  }

  stop(): void {
    this.active = false
    this.subscribeToken++
    ApplicationInventoryEventBus.unsubscribe(this.subscription)
    this.subscription = null
    this.subscribing = false
  }

  getLatestPayload(): ApplicationInventoryChangePayload | null {
    return this.latestPayload
  }
}
