import { describe, expect, it } from '@ohos/hypium'
import { LooseRecord, LooseValue } from '../../main/ets/types/LooseValueTypes'
import {
  generateRandomSuffix,
  pickStringFromRecords,
  pickNumberFromRecords
} from '../../main/ets/utils/ValuePicker'

class TestRecord {
  name?: LooseValue
  value?: LooseValue
  first?: LooseValue
  second?: LooseValue
  count?: LooseValue
  a?: LooseValue
  b?: LooseValue
}

function asRecord(record: TestRecord): LooseRecord {
  return record as LooseRecord
}

export default function valuePickerTest() {
  describe('ValuePicker', () => {
    describe('generateRandomSuffix', () => {
      it('should generate suffix with default length 8', 0, () => {
        let suffix = generateRandomSuffix()

        expect(suffix.length).assertEqual(8)
      })

      it('should generate suffix with custom length', 0, () => {
        let suffix = generateRandomSuffix(12)

        expect(suffix.length > 0).assertTrue()
        expect(suffix.length <= 12).assertTrue()
      })

      it('should generate different suffixes', 0, () => {
        let suffix1 = generateRandomSuffix()
        let suffix2 = generateRandomSuffix()

        expect(suffix1 !== suffix2).assertTrue()
      })

      it('should generate alphanumeric characters only', 0, () => {
        let suffix = generateRandomSuffix(20)

        expect(/^[a-z0-9]+$/.test(suffix)).assertTrue()
      })
    })

    describe('pickStringFromRecords', () => {
      it('should pick string from single record', 0, () => {
        let record = asRecord(new TestRecord())
        ;(record as TestRecord).name = 'test'
        ;(record as TestRecord).value = 123
        let result = pickStringFromRecords(record, ['name'])

        expect(result).assertEqual('test')
      })

      it('should pick first matching key', 0, () => {
        let record = asRecord(new TestRecord())
        ;(record as TestRecord).first = 'one'
        ;(record as TestRecord).second = 'two'
        let result = pickStringFromRecords(record, ['first', 'second'])

        expect(result).assertEqual('one')
      })

      it('should skip missing keys', 0, () => {
        let record = asRecord(new TestRecord())
        ;(record as TestRecord).name = 'test'
        let result = pickStringFromRecords(record, ['missing', 'name'])

        expect(result).assertEqual('test')
      })

      it('should return undefined when no match', 0, () => {
        let record = asRecord(new TestRecord())
        ;(record as TestRecord).value = 123
        let result = pickStringFromRecords(record, ['name'])

        expect(result).assertEqual(undefined)
      })

      it('should trim whitespace from string', 0, () => {
        let record = asRecord(new TestRecord())
        ;(record as TestRecord).name = '  test  '
        let result = pickStringFromRecords(record, ['name'])

        expect(result).assertEqual('test')
      })

      it('should skip empty strings', 0, () => {
        let record = asRecord(new TestRecord())
        ;(record as TestRecord).name = '   '
        let result = pickStringFromRecords(record, ['name'])

        expect(result).assertEqual(undefined)
      })

      it('should pick from array of records', 0, () => {
        let left = asRecord(new TestRecord()); (left as TestRecord).a = 'first'
        let right = asRecord(new TestRecord()); (right as TestRecord).b = 'second'
        let records: LooseRecord[] = [left, right]
        let result = pickStringFromRecords(records, ['b'])

        expect(result).assertEqual('second')
      })

      it('should return undefined for empty array', 0, () => {
        let records: LooseRecord[] = []
        let result = pickStringFromRecords(records, ['name'])

        expect(result).assertEqual(undefined)
      })
    })

    describe('pickNumberFromRecords', () => {
      it('should pick number from single record', 0, () => {
        let record = asRecord(new TestRecord())
        ;(record as TestRecord).count = 42
        ;(record as TestRecord).name = 'test'
        let result = pickNumberFromRecords(record, ['count'])

        expect(result).assertEqual(42)
      })

      it('should pick number from string value', 0, () => {
        let record = asRecord(new TestRecord())
        ;(record as TestRecord).count = '123'
        let result = pickNumberFromRecords(record, ['count'])

        expect(result).assertEqual(123)
      })

      it('should skip non-numeric strings', 0, () => {
        let record = asRecord(new TestRecord())
        ;(record as TestRecord).count = 'abc'
        ;(record as TestRecord).value = 10
        let result = pickNumberFromRecords(record, ['count', 'value'])

        expect(result).assertEqual(10)
      })

      it('should return undefined when no match', 0, () => {
        let record = asRecord(new TestRecord())
        ;(record as TestRecord).name = 'test'
        let result = pickNumberFromRecords(record, ['count'])

        expect(result).assertEqual(undefined)
      })

      it('should parse hex string when supportHex is true', 0, () => {
        let record = asRecord(new TestRecord())
        ;(record as TestRecord).value = '0xFF'
        let result = pickNumberFromRecords(record, ['value'], true)

        expect(result).assertEqual(255)
      })

      it('should parse hex string with uppercase prefix', 0, () => {
        let record = asRecord(new TestRecord())
        ;(record as TestRecord).value = '0X10'
        let result = pickNumberFromRecords(record, ['value'], true)

        expect(result).assertEqual(16)
      })

      it('should not parse hex when supportHex is false', 0, () => {
        let record = asRecord(new TestRecord())
        ;(record as TestRecord).value = '0xFF'
        let result = pickNumberFromRecords(record, ['value'], false)

        expect(result).assertEqual(255)
      })

      it('should pick from array of records', 0, () => {
        let left = asRecord(new TestRecord()); (left as TestRecord).a = 1
        let right = asRecord(new TestRecord()); (right as TestRecord).b = 2
        let records: LooseRecord[] = [left, right]
        let result = pickNumberFromRecords(records, ['b'])

        expect(result).assertEqual(2)
      })

      it('should handle Infinity values', 0, () => {
        let record = asRecord(new TestRecord())
        ;(record as TestRecord).value = Infinity
        let result = pickNumberFromRecords(record, ['value'])

        expect(result).assertEqual(undefined)
      })

      it('should handle NaN values', 0, () => {
        let record = asRecord(new TestRecord())
        ;(record as TestRecord).value = Number.NaN
        let result = pickNumberFromRecords(record, ['value'])

        expect(result).assertEqual(undefined)
      })
    })
  })
}
