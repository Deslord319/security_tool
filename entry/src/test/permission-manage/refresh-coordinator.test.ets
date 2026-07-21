import { describe, expect, it } from '@ohos/hypium'
import { PermissionRefreshCoordinator } from '../../main/ets/viewmodels/permission-manage/PermissionRefreshCoordinator'

interface DeferredBoolean {
  promise: Promise<boolean>
  resolve: (value: boolean) => void
  reject: (reason: Error) => void
}

function createDeferredBoolean(): DeferredBoolean {
  let resolvePromise: (value: boolean) => void = (_value: boolean): void => {}
  let rejectPromise: (reason: Error) => void = (_reason: Error): void => {}
  let promise = new Promise<boolean>((resolve, reject) => {
    resolvePromise = resolve
    rejectPromise = reject
  })
  return {
    promise: promise,
    resolve: resolvePromise,
    reject: rejectPromise
  } as DeferredBoolean
}

async function flushMicrotasks(): Promise<void> {
  await Promise.resolve()
  await Promise.resolve()
  await Promise.resolve()
}

export default function permissionRefreshCoordinatorTest() {
  describe('PermissionRefreshCoordinator', () => {
    it('should reuse an in-flight current-account refresh', 0, async (done: Function) => {
      let coordinator = new PermissionRefreshCoordinator()
      let deferred = createDeferredBoolean()
      let taskCount = 0
      let task = (): Promise<boolean> => {
        taskCount++
        return deferred.promise
      }

      let first = coordinator.runCurrentAccount(task)
      let second = coordinator.runCurrentAccount(task)

      expect(taskCount).assertEqual(1)
      deferred.resolve(true)
      expect(await first).assertTrue()
      expect(await second).assertTrue()
      expect(taskCount).assertEqual(1)
      done()
    })

    it('should run a full refresh after an active current-account refresh', 0, async (done: Function) => {
      let coordinator = new PermissionRefreshCoordinator()
      let deferred = createDeferredBoolean()
      let order: string[] = []
      let current = coordinator.runCurrentAccount(async (): Promise<boolean> => {
        order.push('current-start')
        let result = await deferred.promise
        order.push('current-end')
        return result
      })
      let full = coordinator.runIncludingAccounts(async (): Promise<boolean> => {
        order.push('full')
        return true
      })

      await flushMicrotasks()
      expect(order.length).assertEqual(1)
      deferred.resolve(true)
      expect(await current).assertTrue()
      expect(await full).assertTrue()
      expect(order.join(',')).assertEqual('current-start,current-end,full')
      done()
    })

    it('should reuse an in-flight full refresh', 0, async (done: Function) => {
      let coordinator = new PermissionRefreshCoordinator()
      let deferred = createDeferredBoolean()
      let taskCount = 0
      let task = (): Promise<boolean> => {
        taskCount++
        return deferred.promise
      }

      let first = coordinator.runIncludingAccounts(task)
      let second = coordinator.runIncludingAccounts(task)

      expect(taskCount).assertEqual(1)
      deferred.resolve(true)
      expect(await first).assertTrue()
      expect(await second).assertTrue()
      expect(taskCount).assertEqual(1)
      done()
    })

    it('should wait for a normal refresh before processing an account event', 0, async (done: Function) => {
      let coordinator = new PermissionRefreshCoordinator()
      let deferred = createDeferredBoolean()
      let eventTaskCount = 0
      let current = coordinator.runCurrentAccount((): Promise<boolean> => deferred.promise)
      let accountEvent = coordinator.enqueueAccountChange(async (): Promise<boolean> => {
        eventTaskCount++
        return true
      })

      await flushMicrotasks()
      expect(eventTaskCount).assertEqual(0)
      deferred.resolve(true)
      expect(await current).assertTrue()
      expect(await accountEvent).assertTrue()
      expect(eventTaskCount).assertEqual(1)
      done()
    })

    it('should coalesce account events into one trailing refresh', 0, async (done: Function) => {
      let coordinator = new PermissionRefreshCoordinator()
      let firstRefresh = createDeferredBoolean()
      let taskCount = 0
      let task = (): Promise<boolean> => {
        taskCount++
        return taskCount === 1 ? firstRefresh.promise : Promise.resolve(true)
      }

      let firstEvent = coordinator.enqueueAccountChange(task)
      await flushMicrotasks()
      expect(taskCount).assertEqual(1)
      let secondEvent = coordinator.enqueueAccountChange(task)
      let thirdEvent = coordinator.enqueueAccountChange(task)
      firstRefresh.resolve(true)

      expect(await firstEvent).assertTrue()
      expect(await secondEvent).assertTrue()
      expect(await thirdEvent).assertTrue()
      expect(taskCount).assertEqual(2)
      done()
    })

    it('should schedule another trailing refresh for an event arriving during the trailing refresh', 0,
      async (done: Function) => {
        let coordinator = new PermissionRefreshCoordinator()
        let firstRefresh = createDeferredBoolean()
        let secondRefresh = createDeferredBoolean()
        let taskCount = 0
        let task = (): Promise<boolean> => {
          taskCount++
          if (taskCount === 1) {
            return firstRefresh.promise
          }
          if (taskCount === 2) {
            return secondRefresh.promise
          }
          return Promise.resolve(true)
        }

        let firstEvent = coordinator.enqueueAccountChange(task)
        await flushMicrotasks()
        let secondEvent = coordinator.enqueueAccountChange(task)
        firstRefresh.resolve(true)
        await flushMicrotasks()
        expect(taskCount).assertEqual(2)
        let thirdEvent = coordinator.enqueueAccountChange(task)
        secondRefresh.resolve(true)

        expect(await firstEvent).assertTrue()
        expect(await secondEvent).assertTrue()
        expect(await thirdEvent).assertTrue()
        expect(taskCount).assertEqual(3)
        done()
      })

    it('should release the current refresh after a false result', 0, async (done: Function) => {
      let coordinator = new PermissionRefreshCoordinator()
      let taskCount = 0

      expect(await coordinator.runCurrentAccount(async (): Promise<boolean> => {
        taskCount++
        return false
      })).assertFalse()
      expect(await coordinator.runCurrentAccount(async (): Promise<boolean> => {
        taskCount++
        return true
      })).assertTrue()
      expect(taskCount).assertEqual(2)
      done()
    })

    it('should release the current refresh after an exception', 0, async (done: Function) => {
      let coordinator = new PermissionRefreshCoordinator()
      let caught = false
      try {
        await coordinator.runCurrentAccount(async (): Promise<boolean> => {
          throw new Error('refresh failed')
        })
      } catch (_err) {
        caught = true
      }

      expect(caught).assertTrue()
      expect(await coordinator.runCurrentAccount(async (): Promise<boolean> => true)).assertTrue()
      done()
    })

    it('should run a requested full refresh after a false current refresh result', 0, async (done: Function) => {
      let coordinator = new PermissionRefreshCoordinator()
      let currentRefresh = createDeferredBoolean()
      let fullTaskCount = 0
      let current = coordinator.runCurrentAccount((): Promise<boolean> => currentRefresh.promise)
      let full = coordinator.runIncludingAccounts(async (): Promise<boolean> => {
        fullTaskCount++
        return true
      })

      currentRefresh.resolve(false)
      expect(await current).assertFalse()
      expect(await full).assertTrue()
      expect(fullTaskCount).assertEqual(1)
      done()
    })

    it('should release the account event loop after a failed refresh result', 0, async (done: Function) => {
      let coordinator = new PermissionRefreshCoordinator()
      let taskCount = 0

      expect(await coordinator.enqueueAccountChange(async (): Promise<boolean> => {
        taskCount++
        return false
      })).assertFalse()
      expect(await coordinator.enqueueAccountChange(async (): Promise<boolean> => {
        taskCount++
        return true
      })).assertTrue()
      expect(taskCount).assertEqual(2)
      done()
    })
  })
}
