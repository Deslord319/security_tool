import { rpc } from '@kit.IPCKit'
import { LogUtils } from '../../../../utils/LogUtils'
import type { EnrollCallbackResult, PromptInfo, AuthCallbackResult } from './CustomAuthTypes'
import { writeByteArray, writeEncryptedData, writeTemplateId } from './CustomAuthIpcCodec'
import { CUSTOM_AUTH_CALLBACK_DESCRIPTOR, IpcCode } from './CustomAuthTypes'

const TAG = 'CustomAuth.Callback'

async function sendOneway(proxy: rpc.IRemoteObject, cmd: number, writer: (data: rpc.MessageSequence) => void): Promise<void> {
  const data = rpc.MessageSequence.create()
  const reply = rpc.MessageSequence.create()
  const option = new rpc.MessageOption(rpc.MessageOption.TF_ASYNC)
  try {
    data.writeInterfaceToken(CUSTOM_AUTH_CALLBACK_DESCRIPTOR)
    writer(data)
    await proxy.sendMessageRequest(cmd, data, reply, option)
  } catch (e) {
    // Keep callback failures visible; otherwise the framework only clears after timeout.
    LogUtils.error(TAG, `sendOneway callback failed: cmd=${cmd}, err=${e}`)
  } finally {
    data.reclaim()
    reply.reclaim()
  }
}

export async function callOnEnrollResult(proxy: rpc.IRemoteObject, result: EnrollCallbackResult): Promise<void> {
  await sendOneway(proxy, IpcCode.COMMAND_ON_ENROLL_RESULT, (data) => {
    data.writeInt(result.resultCode)
    writeByteArray(data, result.challenge)
    writeByteArray(data, result.publicKey)
  })
}

export async function callOnAuthResult(proxy: rpc.IRemoteObject, result: AuthCallbackResult): Promise<void> {
  await sendOneway(proxy, IpcCode.COMMAND_ON_AUTH_RESULT, (data) => {
    data.writeInt(result.resultCode)
    writeTemplateId(data, result.templateId)
    writeEncryptedData(data, result.encryptedData)
  })
}

export async function callOnPrompt(proxy: rpc.IRemoteObject, prompt: PromptInfo): Promise<void> {
  await sendOneway(proxy, IpcCode.COMMAND_ON_PROMPT, (data) => {
    writeTemplateId(data, prompt.templateId)
    writeEncryptedData(data, prompt.encryptedData)
  })
}
