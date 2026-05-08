export class Ipv4Utils {
  static isValidIpv4(address: string): boolean {
    return Ipv4Utils.parseIpv4(address) !== null
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
      if (value < 0 || value > 255 || `${value}` !== segment) {
        return null
      }
      result = result * 256 + value
    }
    return result
  }
}
