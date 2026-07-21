export class PermissionRefreshCoordinator {
  private activeRefreshPromise: Promise<boolean> | null = null
  private activeRefreshIncludesAccounts: boolean = false
  private accountChangeRefreshPromise: Promise<boolean> | null = null
  private accountChangeRefreshPending: boolean = false

  async runCurrentAccount(task: () => Promise<boolean>): Promise<boolean> {
    if (this.activeRefreshPromise !== null) {
      return await this.activeRefreshPromise
    }
    return await this.startRefresh(false, task)
  }

  async runIncludingAccounts(task: () => Promise<boolean>): Promise<boolean> {
    while (this.activeRefreshPromise !== null) {
      if (this.activeRefreshIncludesAccounts) {
        return await this.activeRefreshPromise
      }
      await this.activeRefreshPromise
    }
    return await this.startRefresh(true, task)
  }

  async enqueueAccountChange(task: () => Promise<boolean>): Promise<boolean> {
    this.accountChangeRefreshPending = true
    if (this.accountChangeRefreshPromise !== null) {
      return await this.accountChangeRefreshPromise
    }
    let refreshPromise = this.runAccountChangeRefreshLoop(task)
    this.accountChangeRefreshPromise = refreshPromise
    try {
      return await refreshPromise
    } finally {
      if (this.accountChangeRefreshPromise === refreshPromise) {
        this.accountChangeRefreshPromise = null
      }
    }
  }

  private async startRefresh(
    includesAccounts: boolean,
    task: () => Promise<boolean>
  ): Promise<boolean> {
    this.activeRefreshIncludesAccounts = includesAccounts
    let refreshPromise = task()
    this.activeRefreshPromise = refreshPromise
    try {
      return await refreshPromise
    } finally {
      if (this.activeRefreshPromise === refreshPromise) {
        this.activeRefreshPromise = null
        this.activeRefreshIncludesAccounts = false
      }
    }
  }

  private async runAccountChangeRefreshLoop(task: () => Promise<boolean>): Promise<boolean> {
    while (this.accountChangeRefreshPending) {
      await this.waitForActiveRefresh()
      this.accountChangeRefreshPending = false
      let success = await this.startRefresh(true, task)
      if (!success) {
        return false
      }
    }
    return true
  }

  private async waitForActiveRefresh(): Promise<void> {
    while (this.activeRefreshPromise !== null) {
      await this.activeRefreshPromise
    }
  }
}
