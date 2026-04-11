export class Ipv4Utils {
  static isValidIpv4(address: string): boolean {
    return Ipv4Utils.parseIpv4(address) !== null
  }

  static isValidIpv4OrCidr(value: string): boolean {
    let parts = value.split('/')
    if (parts.length > 2 || !Ipv4Utils.isValidIpv4(parts[0].trim())) {
      return false
    }
    if (parts.length === 1) {
      return true
    }
    let mask = parts[1].trim()
    if (!/^\d+$/.test(mask)) {
      return false
    }
    let maskValue = Number(mask)
    return Number.isInteger(maskValue) && maskValue >= 0 && maskValue <= 32
  }

  static parseIpv4(address: string): number | null {
    let segments = address.split('.')
    if (segments.length !== 4) {
      return null
    }
    let result = 0
    for (let i = 0; i < segments.length; i++) {
      let segment = segments[i]
      if (!/^\d+$/.test(segment)) {
        return null
      }
      let value = Number(segment)
      if (!Number.isInteger(value) || value < 0 || value > 255 || `${value}` !== segment) {
        return null
      }
      result = result * 256 + value
    }
    return result
  }
}
