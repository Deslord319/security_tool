import { describe, expect, it } from '@ohos/hypium'
import { TimedLoadingDialogRunner } from '../../main/ets/utils/TimedLoadingDialogRunner'

class FakeDialogController {
  open(): void {
  }

  close(): void {
  }

  getState(): boolean {
    return true
  }
}

class FakeResult {
  name: string = 'test'
  value: number = 123
}

export default function timedLoadingDialogRunnerTest() {
  describe('TimedLoadingDialogRunner', () => {
    it('should create instance with log tag', 0, () => {
      let runner = new TimedLoadingDialogRunner('TestTag')

      expect(runner !== undefined).assertTrue()
    })

    it('should close gracefully when not opened', 0, () => {
      let runner = new TimedLoadingDialogRunner('TestTag')

      runner.closeIfOpen('not-opened')

      expect(true).assertTrue()
    })

    it('should handle multiple close calls', 0, () => {
      let runner = new TimedLoadingDialogRunner('TestTag')

      runner.closeIfOpen('first')
      runner.closeIfOpen('second')
      runner.closeIfOpen('third')

      expect(true).assertTrue()
    })

    it('should run task and return result', 0, async () => {
      let runner = new TimedLoadingDialogRunner('TestTag')
      let createController = (_message: string): CustomDialogController => new FakeDialogController() as CustomDialogController

      let result = await runner.run(
        'test-scene',
        'Loading...',
        async () => 'test-result',
        createController,
        0,
        0
      )

      expect(result).assertEqual('test-result')
    })

    it('should run task with number result', 0, async () => {
      let runner = new TimedLoadingDialogRunner('TestTag')
      let createController = (_message: string): CustomDialogController => new FakeDialogController() as CustomDialogController

      let result = await runner.run(
        'test-scene',
        'Loading...',
        async () => 42,
        createController,
        0,
        0
      )

      expect(result).assertEqual(42)
    })

    it('should run task with object result', 0, async () => {
      let runner = new TimedLoadingDialogRunner('TestTag')
      let createController = (_message: string): CustomDialogController => new FakeDialogController() as CustomDialogController

      let result = await runner.run(
        'test-scene',
        'Loading...',
        async (): Promise<FakeResult> => new FakeResult(),
        createController,
        0,
        0
      )

      expect(result.name).assertEqual('test')
      expect(result.value).assertEqual(123)
    })

    it('should handle task that throws error', 0, async () => {
      let runner = new TimedLoadingDialogRunner('TestTag')
      let createController = (_message: string): CustomDialogController => new FakeDialogController() as CustomDialogController

      try {
        await runner.run(
          'test-scene',
          'Loading...',
          async () => {
            throw new Error('task failed')
          },
          createController,
          0,
          0
        )
        expect(false).assertTrue()
      } catch (err) {
        expect(true).assertTrue()
      }
    })

    it('should handle controller open failure', 0, async () => {
      let runner = new TimedLoadingDialogRunner('TestTag')
      let createController = (_message: string): CustomDialogController => ({
        open: (): void => {
          throw new Error('open failed')
        },
        close: (): void => {},
        getState: (): boolean => true
      } as CustomDialogController)

      let result = await runner.run(
        'test-scene',
        'Loading...',
        async () => 'success',
        createController,
        0,
        0
      )

      expect(result).assertEqual('success')
    })
  })
}
