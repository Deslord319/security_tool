import { connection } from '@kit.ConnectivityKit'
import { formatBluetoothDeviceId } from '../../../models/PeripheralModels'
import { LogUtils } from '../../../utils/LogUtils'
import { BluetoothDeviceNameResolver } from './BluetoothDeviceNameResolver'
import { BluetoothRuntimeConnectionStore } from './BluetoothRuntimeConnectionStore'
import { PeripheralConnectionRecordProducerEvent } from './PeripheralConnectionRecordProducerContract'

const TAG = 'BluetoothRecordCoordinator'
const DEFAULT_PAIRING_SESSION_TIMEOUT_MS = 30000
const DEFAULT_BONDED_FINAL_ACL_WAIT_MS = 3000

type PairingCandidateState = 'pending' | 'finalizing' | 'discarded'

interface BluetoothPairingSession {
  id: number
  state: 'bonding' | 'bonded'
  bondingDeviceId: string
  finalDeviceId: string
}

interface BluetoothPairingCandidate {
  eventKey: string
  event: PeripheralConnectionRecordProducerEvent
  deviceId: string
  namePromise: Promise<string>
  state: PairingCandidateState
  generation: number
}

export type BluetoothRecordSink = (event: PeripheralConnectionRecordProducerEvent) => Promise<boolean>

export class BluetoothConnectionRecordCoordinator {
  private readonly nameResolver: BluetoothDeviceNameResolver
  private readonly pairingSessionTimeoutMs: number
  private readonly bondedFinalAclWaitMs: number
  private recordSink: BluetoothRecordSink | null = null
  private pairStateProviderForTest: ((deviceId: string) => connection.BondState) | null = null
  private session: BluetoothPairingSession | null = null
  private pairingCandidates: Map<string, BluetoothPairingCandidate> =
    new Map<string, BluetoothPairingCandidate>()
  private pairingTimeoutId: number = 0
  private bondedWaitTimeoutId: number = 0
  private nextEventId: number = 1
  private nextSessionId: number = 1
  private generation: number = 1

  constructor(
    nameResolver?: BluetoothDeviceNameResolver,
    pairingSessionTimeoutMs: number = DEFAULT_PAIRING_SESSION_TIMEOUT_MS,
    bondedFinalAclWaitMs: number = DEFAULT_BONDED_FINAL_ACL_WAIT_MS
  ) {
    this.nameResolver = nameResolver ?? new BluetoothDeviceNameResolver()
    this.pairingSessionTimeoutMs = pairingSessionTimeoutMs
    this.bondedFinalAclWaitMs = bondedFinalAclWaitMs
  }

  setRecordSink(recordSink: BluetoothRecordSink | null): void {
    this.recordSink = recordSink
  }

  setPairStateProviderForTest(
    provider: ((deviceId: string) => connection.BondState) | null
  ): void {
    this.pairStateProviderForTest = provider
  }

  async handleEvent(event: PeripheralConnectionRecordProducerEvent): Promise<boolean> {
    if (event.channel === 'bluetooth_bond') {
      return this.handleBondEvent(event)
    }
    if (event.channel !== 'bluetooth_acl' || !event.bluetoothAcl) {
      return false
    }
    return this.handleAclEvent(event)
  }

  stop(): void {
    this.generation++
    this.closeSession(true)
    this.nameResolver.stop()
  }

  private async handleAclEvent(event: PeripheralConnectionRecordProducerEvent): Promise<boolean> {
    const payload = event.bluetoothAcl
    if (!payload || (payload.action !== 'connect' && payload.action !== 'disconnect')) {
      return false
    }
    const rawDeviceId = (payload.deviceId ?? '').trim()
    if (rawDeviceId.length === 0) {
      return false
    }

    const deviceId = this.normalizeDeviceId(rawDeviceId)
    const occurAt = Number.isFinite(payload.occurAt) && payload.occurAt > 0 ? payload.occurAt : Date.now()
    let initialName = this.nameResolver.resolveImmediate(rawDeviceId)
    if (!BluetoothRuntimeConnectionStore.isValidResolvedDeviceName(initialName)) {
      initialName = BluetoothRuntimeConnectionStore.getCachedDeviceName(rawDeviceId)
    }

    if (payload.action === 'connect') {
      BluetoothRuntimeConnectionStore.trackConnectedDevice(
        rawDeviceId,
        this.serializeAclPayload(event),
        initialName
      )
    } else {
      BluetoothRuntimeConnectionStore.forgetConnectedDevice(rawDeviceId)
    }

    const pairState = this.queryPairState(rawDeviceId)
    if (payload.action === 'disconnect' && this.shouldDiscardPairingDisconnect(deviceId, pairState)) {
      this.discardCandidate(deviceId)
      if (this.session?.state === 'bonded' && this.session.finalDeviceId === deviceId) {
        this.closeSession(true)
      }
      return true
    }

    const eventKey = `${occurAt}_${this.nextEventId++}`
    const generation = this.generation
    const namePromise = this.nameResolver.resolve(eventKey, rawDeviceId, occurAt, initialName)
    if (payload.action === 'connect' && pairState !== connection.BondState.BOND_STATE_BONDED &&
      this.shouldHoldForBond(deviceId, pairState)) {
      if (!this.session) {
        this.startPairingSession(deviceId)
      }
      const candidate = this.rememberPairingCandidate(eventKey, event, deviceId, namePromise, generation)
      if (this.session?.state === 'bonded' && this.session.finalDeviceId === deviceId) {
        this.clearBondedWaitTimer()
        return this.finalizePairingCandidate(candidate)
      }
      return true
    }

    const deviceName = await namePromise
    if (generation !== this.generation) {
      return true
    }
    if (!BluetoothRuntimeConnectionStore.isValidResolvedDeviceName(deviceName)) {
      return true
    }
    const persisted = await this.persistNamedAcl(event, deviceName)
    if (
      persisted &&
      payload.action === 'connect' &&
      pairState === connection.BondState.BOND_STATE_BONDED &&
      this.matchesCurrentPairingTarget(deviceId)
    ) {
      this.closeSession(true)
    }
    return persisted
  }

  private async handleBondEvent(event: PeripheralConnectionRecordProducerEvent): Promise<boolean> {
    const payload = event.bluetoothBond
    if (!payload || (payload.deviceId ?? '').trim().length === 0) {
      return false
    }
    const deviceId = this.normalizeDeviceId(payload.deviceId)
    switch (payload.state) {
      case connection.BondState.BOND_STATE_BONDING:
        this.startPairingSession(deviceId)
        return true
      case connection.BondState.BOND_STATE_BONDED:
        await this.completePairingSession(deviceId)
        return true
      case connection.BondState.BOND_STATE_INVALID:
        LogUtils.warn(TAG, `bluetooth pairing failed: cause=${payload.cause ?? -1}`)
        this.closeSession(true)
        return true
      default:
        return false
    }
  }

  private startPairingSession(deviceId: string): void {
    const currentSession = this.session
    if (currentSession?.state === 'bonding') {
      currentSession.bondingDeviceId = deviceId
      return
    }
    this.closeSession(true)
    const session: BluetoothPairingSession = {
      id: this.nextSessionId++,
      state: 'bonding',
      bondingDeviceId: deviceId,
      finalDeviceId: ''
    }
    this.session = session
    this.schedulePairingTimeout(session)
  }

  private schedulePairingTimeout(session: BluetoothPairingSession): void {
    this.pairingTimeoutId = setTimeout(() => {
      if (this.session?.id === session.id) {
        LogUtils.warn(TAG, 'bluetooth pairing session timed out')
        this.closeSession(true)
      }
    }, this.pairingSessionTimeoutMs)
  }

  private async completePairingSession(deviceId: string): Promise<void> {
    this.clearSessionTimers()
    const session: BluetoothPairingSession = this.session ?? {
      id: this.nextSessionId++,
      state: 'bonded',
      bondingDeviceId: deviceId,
      finalDeviceId: deviceId
    }
    session.state = 'bonded'
    session.finalDeviceId = deviceId
    this.session = session

    for (const candidate of Array.from(this.pairingCandidates.values())) {
      if (candidate.deviceId !== deviceId) {
        this.discardCandidate(candidate.deviceId)
      }
    }
    const candidate = this.pairingCandidates.get(deviceId)
    if (candidate && BluetoothRuntimeConnectionStore.hasConnectedDevice(deviceId)) {
      await this.finalizePairingCandidate(candidate)
      return
    }
    if (BluetoothRuntimeConnectionStore.hasConnectedDevice(deviceId)) {
      this.closeSession(true)
      return
    }
    this.bondedWaitTimeoutId = setTimeout(() => {
      if (this.session?.id === session.id) {
        LogUtils.info(TAG, 'bonded device final acl wait timed out')
        this.closeSession(true)
      }
    }, this.bondedFinalAclWaitMs)
  }

  private rememberPairingCandidate(
    eventKey: string,
    event: PeripheralConnectionRecordProducerEvent,
    deviceId: string,
    namePromise: Promise<string>,
    generation: number
  ): BluetoothPairingCandidate {
    this.discardCandidate(deviceId)
    const candidate: BluetoothPairingCandidate = {
      eventKey: eventKey,
      event: event,
      deviceId: deviceId,
      namePromise: namePromise,
      state: 'pending',
      generation: generation
    }
    this.pairingCandidates.set(deviceId, candidate)
    return candidate
  }

  private async finalizePairingCandidate(candidate: BluetoothPairingCandidate): Promise<boolean> {
    if (candidate.state !== 'pending') {
      return true
    }
    candidate.state = 'finalizing'
    const deviceName = await candidate.namePromise
    if (
      candidate.generation !== this.generation ||
      this.pairingCandidates.get(candidate.deviceId) !== candidate ||
      this.session?.state !== 'bonded' ||
      this.session.finalDeviceId !== candidate.deviceId ||
      !BluetoothRuntimeConnectionStore.hasConnectedDevice(candidate.deviceId)
    ) {
      return true
    }
    this.pairingCandidates.delete(candidate.deviceId)
    if (!BluetoothRuntimeConnectionStore.isValidResolvedDeviceName(deviceName)) {
      this.closeSession(true)
      return true
    }
    const persisted = await this.persistNamedAcl(candidate.event, deviceName)
    this.closeSession(true)
    return persisted
  }

  private shouldHoldForBond(deviceId: string, pairState: connection.BondState): boolean {
    return pairState === connection.BondState.BOND_STATE_BONDING || this.matchesCurrentPairingTarget(deviceId)
  }

  private shouldDiscardPairingDisconnect(
    deviceId: string,
    pairState: connection.BondState
  ): boolean {
    return this.pairingCandidates.has(deviceId) ||
      pairState === connection.BondState.BOND_STATE_BONDING ||
      this.matchesCurrentPairingTarget(deviceId)
  }

  private matchesCurrentPairingTarget(deviceId: string): boolean {
    const session = this.session
    if (!session) {
      return false
    }
    return session.bondingDeviceId === deviceId || session.finalDeviceId === deviceId
  }

  private discardCandidate(deviceId: string): void {
    const candidate = this.pairingCandidates.get(deviceId)
    if (!candidate) {
      return
    }
    candidate.state = 'discarded'
    this.nameResolver.cancel(candidate.eventKey)
    this.pairingCandidates.delete(deviceId)
  }

  private queryPairState(deviceId: string): connection.BondState {
    try {
      const provider = this.pairStateProviderForTest
      return provider ? provider(deviceId) : connection.getPairState(deviceId)
    } catch (err) {
      LogUtils.warn(TAG, `getPairState failed: message=${(err as Error).message ?? JSON.stringify(err)}`)
      return connection.BondState.BOND_STATE_INVALID
    }
  }

  private async persistNamedAcl(
    event: PeripheralConnectionRecordProducerEvent,
    deviceName: string
  ): Promise<boolean> {
    const payload = event.bluetoothAcl
    if (!payload || !this.recordSink) {
      return false
    }
    return this.recordSink({
      source: 'runtime',
      channel: 'bluetooth_acl',
      eventName: event.eventName,
      bluetoothAcl: {
        deviceId: payload.deviceId,
        action: payload.action,
        occurAt: payload.occurAt,
        deviceName: deviceName.trim()
      }
    })
  }

  private closeSession(discardCandidates: boolean): void {
    this.clearSessionTimers()
    if (discardCandidates) {
      for (const deviceId of Array.from(this.pairingCandidates.keys())) {
        this.discardCandidate(deviceId)
      }
    }
    this.session = null
  }

  private clearSessionTimers(): void {
    if (this.pairingTimeoutId > 0) {
      clearTimeout(this.pairingTimeoutId)
      this.pairingTimeoutId = 0
    }
    this.clearBondedWaitTimer()
  }

  private clearBondedWaitTimer(): void {
    if (this.bondedWaitTimeoutId > 0) {
      clearTimeout(this.bondedWaitTimeoutId)
      this.bondedWaitTimeoutId = 0
    }
  }

  private normalizeDeviceId(deviceId: string): string {
    return formatBluetoothDeviceId(BluetoothRuntimeConnectionStore.normalizeRawDeviceId(deviceId))
  }

  private serializeAclPayload(event: PeripheralConnectionRecordProducerEvent): string {
    try {
      return JSON.stringify(event.bluetoothAcl ?? {})
    } catch (err) {
      LogUtils.warn(TAG, `serialize bluetooth acl event failed: ${JSON.stringify(err)}`)
      return ''
    }
  }
}
