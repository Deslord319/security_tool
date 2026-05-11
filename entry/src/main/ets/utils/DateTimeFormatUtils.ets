export function formatStandardDateTime(timestamp: number): string {
  let date = new Date(timestamp)
  return `${date.getFullYear()}-${padTwoDigits(date.getMonth() + 1)}-${padTwoDigits(date.getDate())} ${padTwoDigits(date.getHours())}:${padTwoDigits(date.getMinutes())}:${padTwoDigits(date.getSeconds())}`
}

export function formatStandardDateTimeOrFallback(timestamp: number, fallback: string): string {
  if (timestamp <= 0) {
    return fallback
  }
  return formatStandardDateTime(timestamp)
}

export function formatCompactDateTime(timestamp: number): string {
  let date = new Date(timestamp)
  let datePart = `${date.getFullYear()}${padTwoDigits(date.getMonth() + 1)}${padTwoDigits(date.getDate())}`
  let timePart = `${padTwoDigits(date.getHours())}${padTwoDigits(date.getMinutes())}${padTwoDigits(date.getSeconds())}`
  return `${datePart}_${timePart}`
}

function padTwoDigits(value: number): string {
  return value.toString().padStart(2, '0')
}
