import { rpc } from '@kit.IPCKit'
import { LogUtils } from '../../../../utils/LogUtils'
import {
  writeInitOutput,
  readStringArray,
  readTemplateId,
  readByteArray,
  readBeginEnrollInput,
  readEndEnrollInput,
  writeEndEnrollOutput,
  readBeginAuthenticateInput,
} from './CustomAuthIpcCodec'
import { callOnEnrollResult, callOnPrompt, callOnAuthResult } from './AuthCallbackProxy'
import { CustomAuthenticatorService } from '../service/CustomAuthenticatorService'
import type { EnrollCallbackResult, AuthCallbackResult, PromptInfo } from './CustomAuthTypes'
import { CUSTOM_AUTH_INTERFACE_DESCRIPTOR, IpcCode } from './CustomAuthTypes'

const TAG = 'CustomAuth.Stub'

export class CustomAuthStub extends rpc.RemoteObject {
  private service: CustomAuthenticatorService
  private authCallbacks: Map<number, rpc.IRemoteObject> = new Map()

  constructor() {
    super(CUSTOM_AUTH_INTERFACE_DESCRIPTOR)
    this.service = new CustomAuthenticatorService()
  }

  onRemoteMessageRequest(code: number, data: rpc.MessageSequence, reply: rpc.MessageSequence,
    options: rpc.MessageOption): boolean | Promise<boolean> {
    try {
      const descriptor = data.readInterfaceToken()
      if (descriptor !== CUSTOM_AUTH_INTERFACE_DESCRIPTOR) {
        LogUtils.error(TAG, `descriptor mismatch: ${descriptor}`)
        return false
      }
    } catch (e) {
      LogUtils.error(TAG, `readInterfaceToken exception: ${e}`)
      return false
    }

    switch (code) {
      case IpcCode.COMMAND_INIT_AUTHENTICATOR:
        return this.handleInitAuthenticator(data, reply)
      case IpcCode.COMMAND_BEGIN_ENROLL:
        return this.handleBeginEnroll(data, reply)
      case IpcCode.COMMAND_END_ENROLL:
        return this.handleEndEnroll(data, reply)
      case IpcCode.COMMAND_BEGIN_AUTHENTICATE:
        return this.handleBeginAuthenticate(data, reply)
      case IpcCode.COMMAND_SUBMIT_PASSCODE:
        return this.handleSubmitPasscode(data, reply)
      case IpcCode.COMMAND_REMOVE:
        return this.handleRemove(data, reply)
      case IpcCode.COMMAND_CANCEL:
        return this.handleCancel(data, reply)
      default:
        LogUtils.warn(TAG, `unknown code: ${code}`)
        return false
    }
  }

  private handleInitAuthenticator(data: rpc.MessageSequence, reply: rpc.MessageSequence): boolean {
    try {
      const templateIds = readStringArray(data)
      const result = this.service.initAuthenticator(templateIds)
      reply.writeInt(result.resultCode)
      writeInitOutput(reply, result.initOutput)
      LogUtils.info(TAG, `handleInitAuthenticator done: resultCode=${result.resultCode}, held=${result.initOutput.authenticatorTemplateIds.length}`)
      return true
    } catch (e) {
      LogUtils.error(TAG, `handleInitAuthenticator exception: ${e}`)
      return false
    }
  }

  private async handleBeginEnroll(data: rpc.MessageSequence, reply: rpc.MessageSequence): Promise<boolean> {
    try {
      const input = readBeginEnrollInput(data)
      const callback = data.readRemoteObject()
      LogUtils.info(TAG, `handleBeginEnroll: requestId=${input.requestId}, hasCallback=${callback !== null}`)

      const result: EnrollCallbackResult = await this.service.beginEnroll(input)

      reply.writeInt(result.resultCode)

      if (result.resultCode === 0 && callback !== null) {
        callOnEnrollResult(callback, result)
      }

      LogUtils.info(TAG, `handleBeginEnroll done: resultCode=${result.resultCode}`)
      return true
    } catch (e) {
      LogUtils.error(TAG, `handleBeginEnroll exception: ${e}`)
      return false
    }
  }

  private async handleEndEnroll(data: rpc.MessageSequence, reply: rpc.MessageSequence): Promise<boolean> {
    try {
      const input = readEndEnrollInput(data)
      const output = await this.service.endEnroll(input)
      writeEndEnrollOutput(reply, output)
      return true
    } catch (e) {
      LogUtils.error(TAG, `handleEndEnroll exception: ${e}`)
      return false
    }
  }

  private async handleBeginAuthenticate(data: rpc.MessageSequence,
    reply: rpc.MessageSequence): Promise<boolean> {
    try {
      const input = readBeginAuthenticateInput(data)
      const callback = data.readRemoteObject()
      LogUtils.info(TAG,
        `handleBeginAuthenticate: requestId=${input.requestId}, userId=${input.userId}, hasCallback=${callback !== null}`)

      const result = await this.service.beginAuthenticate(input)

      reply.writeInt(result.resultCode)

      if (callback !== null) {
        if (result.completed) {
          const authResult: AuthCallbackResult = {
            resultCode: result.resultCode,
            templateId: result.templateId,
            encryptedData: result.encryptedData,
          }
          callOnAuthResult(callback, authResult)
        } else if (result.resultCode === 0) {
          // Prompt mode completes later through submitPasscode.
          this.authCallbacks.set(input.requestId, callback)
          const prompt: PromptInfo = { templateId: result.templateId, encryptedData: result.encryptedData }
          callOnPrompt(callback, prompt)
        }
      }

      LogUtils.info(TAG, `handleBeginAuthenticate done: resultCode=${result.resultCode}, templateId=${result.templateId}, completed=${result.completed ?? false}`)
      return true
    } catch (e) {
      LogUtils.error(TAG, `handleBeginAuthenticate exception: ${e}`)
      return false
    }
  }

  private async handleSubmitPasscode(data: rpc.MessageSequence,
    reply: rpc.MessageSequence): Promise<boolean> {
    try {
      const requestId = data.readInt()
      // count=0 has no following payload.
      const passcodeCount = data.readInt()
      const passcodeCipherText: number[] = passcodeCount === 0 ? [] : readByteArray(data, passcodeCount)
      LogUtils.info(TAG, `handleSubmitPasscode: requestId=${requestId}, passcodeLen=${passcodeCipherText.length}`)

      const result: AuthCallbackResult = await this.service.submitPasscode(requestId, passcodeCipherText)

      reply.writeInt(result.resultCode)

      const cb = this.authCallbacks.get(requestId)
      if (cb !== undefined) {
        callOnAuthResult(cb, result)
        this.authCallbacks.delete(requestId)
      }

      LogUtils.info(TAG, `handleSubmitPasscode done: resultCode=${result.resultCode}, templateId=${result.templateId}`)
      return true
    } catch (e) {
      LogUtils.error(TAG, `handleSubmitPasscode exception: ${e}`)
      return false
    }
  }

  private async handleRemove(data: rpc.MessageSequence, reply: rpc.MessageSequence): Promise<boolean> {
    try {
      const templateId = readTemplateId(data)
      const resultCode = await this.service.remove(templateId)
      reply.writeInt(resultCode)
      return true
    } catch (e) {
      LogUtils.error(TAG, `handleRemove exception: ${e}`)
      return false
    }
  }

  private async handleCancel(data: rpc.MessageSequence, reply: rpc.MessageSequence): Promise<boolean> {
    try {
      const requestId = data.readInt()
      const resultCode = await this.service.cancel(requestId)
      this.authCallbacks.delete(requestId)
      reply.writeInt(resultCode)
      return true
    } catch (e) {
      LogUtils.error(TAG, `handleCancel exception: ${e}`)
      return false
    }
  }
}
