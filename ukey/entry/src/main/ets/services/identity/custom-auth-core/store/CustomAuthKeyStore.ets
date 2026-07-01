import { asset } from '@kit.AssetStoreKit'
import { LogUtils } from '../../../../utils/LogUtils'

const TAG = 'CustomAuth.KeyStore'

const SHARED_KEY_LENGTH = 32
const AUTHENTICATOR_SECRET_LENGTH = 32
const AUTHENTICATOR_SECRET_SEQ_LENGTH = 4
const KEY_MATERIAL_SECRET_LENGTH = SHARED_KEY_LENGTH + AUTHENTICATOR_SECRET_LENGTH + AUTHENTICATOR_SECRET_SEQ_LENGTH // 68
const LEGACY_AUTHENTICATOR_SECRET_SEQ_LENGTH = 8
const LEGACY_KEY_MATERIAL_SECRET_LENGTH = SHARED_KEY_LENGTH + AUTHENTICATOR_SECRET_LENGTH + LEGACY_AUTHENTICATOR_SECRET_SEQ_LENGTH // 72
const CUSTOM_AUTH_KEY_ALIAS_PREFIX = 'custom_auth_'

// Per-template key material. authenticatorSecretSeq is a u32.
export interface KeyMaterial {
  sharedKey: Uint8Array
  authenticatorSecret: Uint8Array
  authenticatorSecretSeq: number
}

function stringToBytes(str: string): Uint8Array {
  const arr = new Uint8Array(str.length)
  for (let i = 0; i < str.length; i++) {
    arr[i] = str.charCodeAt(i)
  }
  return arr
}

function bytesToString(bytes: Uint8Array): string {
  let str = ''
  for (let i = 0; i < bytes.length; i++) {
    str += String.fromCharCode(bytes[i])
  }
  return str
}

function buildAlias(templateId: string): Uint8Array {
  return stringToBytes(`${CUSTOM_AUTH_KEY_ALIAS_PREFIX}${templateId}`)
}

const KEY_GROUP_LABEL = stringToBytes('ca_keys')

function encodeUint32Le(value: number): Uint8Array {
  if (Math.floor(value) !== value || value < 0 || value > 0xFFFFFFFF) {
    throw new Error(`encodeUint32Le: value out of u32 range: ${value}`)
  }
  let v = value
  const bytes = new Uint8Array(AUTHENTICATOR_SECRET_SEQ_LENGTH)
  for (let i = 0; i < AUTHENTICATOR_SECRET_SEQ_LENGTH; i++) {
    bytes[i] = v & 0xFF
    v = Math.floor(v / 256)
  }
  return bytes
}

function decodeUint32Le(bytes: Uint8Array): number {
  if (bytes.length !== AUTHENTICATOR_SECRET_SEQ_LENGTH) {
    throw new Error(`decodeUint32Le: expected ${AUTHENTICATOR_SECRET_SEQ_LENGTH} bytes, got ${bytes.length}`)
  }
  let value = 0
  for (let i = 0; i < bytes.length; i++) {
    value |= (bytes[i] << (i * 8))
  }
  return value >>> 0
}

function decodeLegacyUint64BeAsUint32(bytes: Uint8Array): number | null {
  if (bytes.length !== LEGACY_AUTHENTICATOR_SECRET_SEQ_LENGTH) {
    return null
  }
  for (let i = 0; i < 4; i++) {
    if (bytes[i] !== 0) {
      return null
    }
  }
  let value = 0
  for (let i = 4; i < LEGACY_AUTHENTICATOR_SECRET_SEQ_LENGTH; i++) {
    value = (value * 256) + bytes[i]
  }
  return value >>> 0
}

// SECRET = sharedKey(32) || authenticatorSecret(32) || seqLE(4).
function buildSecret(sharedKey: Uint8Array, authenticatorSecret: Uint8Array, seq: number): Uint8Array {
  const seqLe = encodeUint32Le(seq)
  const secret = new Uint8Array(KEY_MATERIAL_SECRET_LENGTH)
  secret.set(sharedKey, 0)
  secret.set(authenticatorSecret, SHARED_KEY_LENGTH)
  secret.set(seqLe, SHARED_KEY_LENGTH + AUTHENTICATOR_SECRET_LENGTH)
  return secret
}

function parseCurrentSecret(secret: Uint8Array): KeyMaterial | null {
  if (secret.length !== KEY_MATERIAL_SECRET_LENGTH) {
    LogUtils.error(TAG, `parseSecret: bad length ${secret.length}, expect ${KEY_MATERIAL_SECRET_LENGTH}`)
    return null
  }
  return {
    sharedKey: secret.slice(0, SHARED_KEY_LENGTH),
    authenticatorSecret: secret.slice(SHARED_KEY_LENGTH, SHARED_KEY_LENGTH + AUTHENTICATOR_SECRET_LENGTH),
    authenticatorSecretSeq: decodeUint32Le(secret.slice(SHARED_KEY_LENGTH + AUTHENTICATOR_SECRET_LENGTH, KEY_MATERIAL_SECRET_LENGTH)),
  }
}

function parseLegacySecret(secret: Uint8Array): KeyMaterial | null {
  if (secret.length !== LEGACY_KEY_MATERIAL_SECRET_LENGTH) {
    LogUtils.error(TAG, `parseLegacySecret: bad length ${secret.length}, expect ${LEGACY_KEY_MATERIAL_SECRET_LENGTH}`)
    return null
  }
  const seq = decodeLegacyUint64BeAsUint32(secret.slice(
    SHARED_KEY_LENGTH + AUTHENTICATOR_SECRET_LENGTH,
    LEGACY_KEY_MATERIAL_SECRET_LENGTH,
  ))
  if (seq === null) {
    LogUtils.error(TAG, 'parseLegacySecret: seq exceeds u32 range')
    return null
  }
  return {
    sharedKey: secret.slice(0, SHARED_KEY_LENGTH),
    authenticatorSecret: secret.slice(SHARED_KEY_LENGTH, SHARED_KEY_LENGTH + AUTHENTICATOR_SECRET_LENGTH),
    authenticatorSecretSeq: seq,
  }
}

function migrateLegacySecret(templateId: string, alias: Uint8Array, secret: Uint8Array): KeyMaterial | null {
  const material = parseLegacySecret(secret)
  if (!material) {
    return null
  }
  const migratedSecret = buildSecret(material.sharedKey, material.authenticatorSecret, material.authenticatorSecretSeq)
  try {
    const query: Map<asset.Tag, asset.Value> = new Map()
    query.set(asset.Tag.ALIAS, alias)
    const attrsToUpdate: Map<asset.Tag, asset.Value> = new Map()
    attrsToUpdate.set(asset.Tag.SECRET, migratedSecret)
    asset.updateSync(query, attrsToUpdate)
    LogUtils.info(TAG, `migrateLegacySecret: templateId=${templateId} migrated 72B->68B seq=${material.authenticatorSecretSeq}`)
    return material
  } catch (e) {
    material.sharedKey.fill(0)
    material.authenticatorSecret.fill(0)
    LogUtils.error(TAG, `migrateLegacySecret: templateId=${templateId} updateSync failed: ${e}`)
    return null
  } finally {
    migratedSecret.fill(0)
  }
}

// Store or overwrite one template record atomically. Never use remove-then-add here.
export function storeKeys(templateId: string, sharedKey: Uint8Array, authenticatorSecret: Uint8Array): boolean {
  const alias = buildAlias(templateId)
  const secret = buildSecret(sharedKey, authenticatorSecret, 1)
  const labelBytes = stringToBytes(templateId) // DATA_LABEL_NORMAL_1 = templateId
  let created = false

  try {
    // querySync throws when no asset matches; treat that as a missing record.
    let exists = false
    try {
      const existsQuery: Map<asset.Tag, asset.Value> = new Map()
      existsQuery.set(asset.Tag.ALIAS, alias)
      existsQuery.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ATTRIBUTES)
      exists = asset.querySync(existsQuery).length > 0
    } catch (e) {
      exists = false
    }

    if (exists) {
      // Existing record: only replace SECRET.
      const updateQuery: Map<asset.Tag, asset.Value> = new Map()
      updateQuery.set(asset.Tag.ALIAS, alias)
      const attrsToUpdate: Map<asset.Tag, asset.Value> = new Map()
      attrsToUpdate.set(asset.Tag.SECRET, secret)
      asset.updateSync(updateQuery, attrsToUpdate)
    } else {
      // New record: write all attributes in one addSync call.
      const attrs: Map<asset.Tag, asset.Value> = new Map()
      attrs.set(asset.Tag.ALIAS, alias)
      attrs.set(asset.Tag.SECRET, secret)
      attrs.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_POWERED_ON)
      attrs.set(asset.Tag.SYNC_TYPE, asset.SyncType.NEVER)
      attrs.set(asset.Tag.DATA_LABEL_NORMAL_1, labelBytes)
      attrs.set(asset.Tag.DATA_LABEL_NORMAL_2, KEY_GROUP_LABEL)
      asset.addSync(attrs)
      created = true
    }
    LogUtils.info(TAG, `storeKeys: templateId=${templateId} success (${created ? 'add' : 'update'})`)
    return true
  } catch (e) {
    LogUtils.error(TAG, `storeKeys: templateId=${templateId} failed: ${e}`)
    return false
  } finally {
    // Clear the temporary packed SECRET.
    secret.fill(0)
  }
}

// Return null when the record is missing or malformed.
export function loadKeys(templateId: string): KeyMaterial | null {
  const alias = buildAlias(templateId)
  const query: Map<asset.Tag, asset.Value> = new Map()
  query.set(asset.Tag.ALIAS, alias)
  query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL)

  try {
    const results = asset.querySync(query)
    if (results.length === 0) {
      LogUtils.warn(TAG, `loadKeys: templateId=${templateId} not found`)
      return null
    }
    const secret = results[0].get(asset.Tag.SECRET) as Uint8Array
    if (secret === undefined) {
      LogUtils.error(TAG, `loadKeys: templateId=${templateId} no SECRET`)
      return null
    }
    let material: KeyMaterial | null = null
    if (secret.length === KEY_MATERIAL_SECRET_LENGTH) {
      material = parseCurrentSecret(secret)
    } else if (secret.length === LEGACY_KEY_MATERIAL_SECRET_LENGTH) {
      material = migrateLegacySecret(templateId, alias, secret)
    } else {
      LogUtils.error(TAG, `loadKeys: templateId=${templateId} bad SECRET length ${secret.length}`)
    }
    // parseSecret copied the fields; clear the raw SECRET buffer.
    secret.fill(0)
    return material
  } catch (e) {
    LogUtils.error(TAG, `loadKeys: templateId=${templateId} failed: ${e}`)
    return null
  }
}

export function deleteKeys(templateId: string): boolean {
  const alias = buildAlias(templateId)
  const query: Map<asset.Tag, asset.Value> = new Map()
  query.set(asset.Tag.ALIAS, alias)

  try {
    asset.removeSync(query)
    LogUtils.info(TAG, `deleteKeys: templateId=${templateId} success`)
    return true
  } catch (e) {
    LogUtils.error(TAG, `deleteKeys: templateId=${templateId} failed: ${e}`)
    return false
  }
}

// Used by remove() to distinguish NOT_ENROLLED from delete failure.
export function aliasExists(templateId: string): boolean {
  const query: Map<asset.Tag, asset.Value> = new Map()
  query.set(asset.Tag.ALIAS, buildAlias(templateId))
  query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ATTRIBUTES)
  try {
    return asset.querySync(query).length > 0
  } catch (e) {
    LogUtils.error(TAG, `aliasExists: templateId=${templateId} query failed: ${e}`)
    return false
  }
}

// Rotate authenticatorSecret and seq in one SecurityAsset update.
export function updateAuthSecretAndSeq(templateId: string, newAuthenticatorSecret: Uint8Array): number | null {
  const material = loadKeys(templateId)
  if (!material) {
    LogUtils.error(TAG, `updateAuthSecretAndSeq: templateId=${templateId} not found`)
    return null
  }
  const newSeq = material.authenticatorSecretSeq + 1
  if (newSeq > 0xFFFFFFFF) {
    material.sharedKey.fill(0)
    material.authenticatorSecret.fill(0)
    LogUtils.error(TAG, `updateAuthSecretAndSeq: templateId=${templateId} seq cap reached`)
    return null
  }
  const alias = buildAlias(templateId)
  const newSecret = buildSecret(material.sharedKey, newAuthenticatorSecret, newSeq)
  // Old material is only needed to pack the replacement SECRET.
  material.sharedKey.fill(0)
  material.authenticatorSecret.fill(0)

  try {
    const query: Map<asset.Tag, asset.Value> = new Map()
    query.set(asset.Tag.ALIAS, alias)
    const attrsToUpdate: Map<asset.Tag, asset.Value> = new Map()
    attrsToUpdate.set(asset.Tag.SECRET, newSecret)
    asset.updateSync(query, attrsToUpdate)
    LogUtils.info(TAG, `updateAuthSecretAndSeq: templateId=${templateId} seq=${newSeq} success`)
    return newSeq
  } catch (e) {
    // Keep the old record intact and let the caller fail this authentication attempt.
    LogUtils.error(TAG, `updateAuthSecretAndSeq: templateId=${templateId} updateSync failed: ${e}`)
    return null
  } finally {
    // Clear the temporary packed replacement SECRET.
    newSecret.fill(0)
  }
}

// List all templateIds stored by this authenticator.
export function listAllTemplateIds(): string[] {
  const query: Map<asset.Tag, asset.Value> = new Map()
  query.set(asset.Tag.DATA_LABEL_NORMAL_2, KEY_GROUP_LABEL)
  query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ATTRIBUTES)

  try {
    const results = asset.querySync(query)
    const ids: string[] = []
    for (const result of results) {
      const aliasBytes = result.get(asset.Tag.ALIAS) as Uint8Array
      if (aliasBytes === undefined) {
        continue
      }
      const aliasStr = bytesToString(aliasBytes)
      if (aliasStr.startsWith(CUSTOM_AUTH_KEY_ALIAS_PREFIX)) {
        const id = aliasStr.substring(CUSTOM_AUTH_KEY_ALIAS_PREFIX.length)
        if (id.length > 0) {
          ids.push(id)
        }
      }
    }
    ids.sort()
    LogUtils.info(TAG, `listAllTemplateIds: found ${ids.length} templates`)
    return ids
  } catch (e) {
    LogUtils.error(TAG, `listAllTemplateIds: failed: ${e}`)
    return []
  }
}

// Drop records that are no longer reported by the framework and return remaining templateIds.
export function reconcile(validTemplateIds: string[]): string[] {
  const all = listAllTemplateIds()
  const valid = new Set<string>(validTemplateIds)
  const held: string[] = []
  let deletedCount = 0
  for (const id of all) {
    if (valid.has(id)) {
      held.push(id)
    } else if (deleteKeys(id)) {
      deletedCount++
    }
  }
  if (deletedCount > 0) {
    LogUtils.info(TAG, `reconcile: deleted ${deletedCount} orphan templates, held=${held.length}`)
  }
  return held
}
