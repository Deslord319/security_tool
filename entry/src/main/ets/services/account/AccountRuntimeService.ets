import {
  AccountChangeEventBus,
  AccountChangeEventPayload,
  AccountChangeSubscription
} from './AccountChangeEventBus'
import { LogUtils } from '../../utils/LogUtils'

const TAG = 'AccountRuntimeService'

export type AccountRuntimeChangeConsumer = (payload: AccountChangeEventPayload) => Promise<void>

export class AccountRuntimeService {
  private subscription: AccountChangeSubscription | null = null
  private subscribing: boolean = false
  private active: boolean = false
  private subscribeToken: number = 0
  private latestPayload: AccountChangeEventPayload | null = null
  private readonly consumer: AccountRuntimeChangeConsumer

  constructor(consumer: AccountRuntimeChangeConsumer) {
    this.consumer = consumer
  }

  start(): void {
    if (this.subscription || this.subscribing) {
      return
    }
    this.active = true
    this.subscribing = true
    let token = ++this.subscribeToken
    AccountChangeEventBus.subscribe(async (payload: AccountChangeEventPayload): Promise<void> => {
      await this.handleAccountChange(payload)
    }).then((subscription: AccountChangeSubscription | null) => {
      if (token !== this.subscribeToken || !this.active) {
        AccountChangeEventBus.unsubscribe(subscription)
        return
      }
      this.subscribing = false
      this.subscription = subscription
      if (!subscription) {
        LogUtils.warn(TAG, 'account runtime subscriber not created')
      }
    }).catch((err: Error) => {
      if (token === this.subscribeToken) {
        this.subscribing = false
      }
      LogUtils.warn(TAG, 'start account runtime subscriber failed: %{public}s', JSON.stringify(err))
    })
  }

  stop(): void {
    this.active = false
    this.subscribeToken++
    AccountChangeEventBus.unsubscribe(this.subscription)
    this.subscription = null
    this.subscribing = false
  }

  getLatestPayload(): AccountChangeEventPayload | null {
    return this.latestPayload
  }

  private async handleAccountChange(payload: AccountChangeEventPayload): Promise<void> {
    this.latestPayload = payload
    await this.consumer(payload)
  }
}
