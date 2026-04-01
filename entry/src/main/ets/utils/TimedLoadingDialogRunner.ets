import { LogUtils } from './utils/LogUtils'
type DialogControllerFactory = (message: string) => CustomDialogController
  private openedAt: number = 0
  private controller?: CustomDialogController
  private readonly logTag: string
  private readonly logDomain: number
  constructor(logTag: string, logDomain: number) {
    this.logTag = logTag
    this.logDomain = logDomain
  }
  async run<T>(
    sceneTag: string,
    message: string,
    task: () => Promise<T>,
    createController: DialogControllerFactory,
    minDurationMs: number = 500,
    renderReadyDelayMs: number = 0
  ): Promise<T> {
    await this.open(sceneTag, message, createController, minDurationMs)
    await this.waitRenderReady(sceneTag, renderReadyDelayMs)
    try {
      return await task()
    } finally {
      await this.waitMinimumDuration(sceneTag, minDurationMs)
      this.closeIfOpen(sceneTag)
    }
  }
  closeIfOpen(sceneTag: string = 'manual-close'): void {
    if (!this.controller) {
      this.openedAt = 0
      return
    }
    const elapsed = this.openedAt > 0 ? Date.now() - this.openedAt : 0
    try {
      this.controller.close()
      LogUtils.info(
        this.logTag,
        `loading dialog closed: scene=${sceneTag}, elapsedMs=${elapsed}`
      )
    } catch (err) {
      LogUtils.warn(
        this.logTag,
        `loading dialog close failed: scene=${sceneTag}, err=${JSON.stringify(err)}`
      )
    } finally {
      this.controller = undefined
      this.openedAt = 0
    }
  }
  private async open(
    sceneTag: string,
    message: string,
    createController: DialogControllerFactory,
    minDurationMs: number
  ): Promise<void> {
    if (this.controller) {
      LogUtils.warn(this.logTag, `loading dialog already open: scene=${sceneTag}`)
      return
    }
    try {
      this.controller = createController(message)
      this.controller.open()
      this.openedAt = Date.now()
      LogUtils.info(this.logTag, `loading dialog opened: scene=${sceneTag}, minDurationMs=${minDurationMs}`)
    } catch (err) {
      this.controller = undefined
      this.openedAt = 0
      LogUtils.warn(
        this.logTag,
        `loading dialog open failed: scene=${sceneTag}, err=${JSON.stringify(err)}`
      )
    }
  }
  private async waitMinimumDuration(sceneTag: string, minDurationMs: number): Promise<void> {
    if (!this.controller || this.openedAt <= 0) {
      return
    }
    const elapsed = Date.now() - this.openedAt
    const remaining = minDurationMs - elapsed
    if (remaining <= 0) {
      return
    }
    LogUtils.info(
      this.logTag,
      `loading dialog waiting minimum duration: scene=${sceneTag}, remainingMs=${remaining}`
    )
    await new Promise<void>((resolve: () => void) => {
      setTimeout(() => resolve(), remaining)
    })
  }
  private async waitRenderReady(sceneTag: string, renderReadyDelayMs: number): Promise<void> {
    if (!this.controller || renderReadyDelayMs <= 0) {
      return
    }
    LogUtils.info(
      this.logTag,
      `loading dialog waiting render ready: scene=${sceneTag}, delayMs=${renderReadyDelayMs}`
    )
    await new Promise<void>((resolve: () => void) => {
      setTimeout(() => resolve(), renderReadyDelayMs)
    })
  }
}
