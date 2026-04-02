export class LogServiceErrors {
  static extractErrorCode(err: Object): number | undefined {
    let codeValue = (err as Record<string, Object>)['code']
    if (typeof codeValue === 'number') {
      return codeValue
    }
    if (typeof codeValue === 'string') {
      let parsed = Number(codeValue)
      return Number.isNaN(parsed) ? undefined : parsed
    }
    return undefined
  }

  static extractErrorText(err: Object): string {
    let message = (err as Record<string, Object>)['message']
    if (typeof message === 'string' && message.trim().length > 0) {
      return message.toLowerCase()
    }
    return JSON.stringify(err).toLowerCase()
  }
}
