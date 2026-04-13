export type LooseValue = string | number | boolean | Object | undefined
export type LooseRecord = Record<string, LooseValue>
export type ErrorLike = Object | LooseRecord
