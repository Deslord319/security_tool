export class PermissionRefreshCoordinator {
  private activeRefreshPromise: Promise<boolean> | null = null
  private activeRefreshIncludesAccounts: boolean = false
  private eventRefreshPromise: Promise<boolean> | null = null
  private accountChangeRefreshPending: boolean = false
  private accountChangeTask: (() => Promise<boolean>) | null = null
  private applicationChangeRefreshPending: boolean = false
  private applicationChangeTask: (() => Promise<boolean>) | null = null

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
    this.accountChangeTask = task
    if (this.eventRefreshPromise !== null) {
      return await this.eventRefreshPromise
    }
    let refreshPromise = this.runEventRefreshLoop()
    this.eventRefreshPromise = refreshPromise
    try {
      return await refreshPromise
    } finally {
      if (this.eventRefreshPromise === refreshPromise) {
        this.eventRefreshPromise = null
      }
    }
  }

  async enqueueApplicationChange(task: () => Promise<boolean>): Promise<boolean> {
    this.applicationChangeRefreshPending = true
    this.applicationChangeTask = task
    if (this.eventRefreshPromise !== null) {
      return await this.eventRefreshPromise
    }
    let refreshPromise = this.runEventRefreshLoop()
    this.eventRefreshPromise = refreshPromise
    try {
      return await refreshPromise
    } finally {
      if (this.eventRefreshPromise === refreshPromise) {
        this.eventRefreshPromise = null
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

  private async runEventRefreshLoop(): Promise<boolean> {
    let allSucceeded = true
    while (this.accountChangeRefreshPending || this.applicationChangeRefreshPending) {
      await this.waitForActiveRefresh()
      if (this.accountChangeRefreshPending) {
        this.accountChangeRefreshPending = false
        this.applicationChangeRefreshPending = false
        let task = this.accountChangeTask
        if (task !== null) {
          let success = await this.startRefresh(true, task)
          allSucceeded = allSucceeded && success
        }
        continue
      }
      this.applicationChangeRefreshPending = false
      let task = this.applicationChangeTask
      if (task !== null) {
        let success = await this.startRefresh(false, task)
        allSucceeded = allSucceeded && success
      }
    }
    return allSucceeded
  }

  private async waitForActiveRefresh(): Promise<void> {
    while (this.activeRefreshPromise !== null) {
      await this.activeRefreshPromise
    }
  }
}
