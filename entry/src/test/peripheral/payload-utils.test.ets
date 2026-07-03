import { describe, expect, it } from '@ohos/hypium'
import { LooseRecord, LooseValue } from '../../main/ets/types/LooseValueTypes'
import {
  collectPayloadSources,
  pickNumber,
  pickString,
  pushRecord,
  toRecord,
  readObjectField,
  parseJsonObjectField,
  readDeviceField,
  toRecordArray
} from '../../main/ets/services/peripheral/connection-record/PeripheralConnectionRecordPayloadUtils'

class TestRecord {
  name?: LooseValue
  value?: LooseValue
  key?: LooseValue
  nested?: LooseValue
  inner?: LooseValue
  str?: LooseValue
  num?: LooseValue
  data?: LooseValue
  valid?: LooseValue
  invalid?: LooseValue
  empty?: LooseValue
  obj?: LooseValue
  device?: LooseValue
  remoteDevice?: LooseValue
  bluetoothDevice?: LooseValue
  usbDevice?: LooseValue
  other?: LooseValue
  id?: LooseValue
  a?: LooseValue
  b?: LooseValue
  parameters?: LooseValue
  want?: LooseValue
}

function asRecord(record: TestRecord): LooseRecord {
  return record as LooseRecord
}

export default function peripheralPayloadUtilsTest() {
  describe('PeripheralConnectionRecordPayloadUtils', () => {
    it('should convert object to record', 0, () => {
      let obj = asRecord(new TestRecord())
      ;(obj as TestRecord).name = 'test'
      ;(obj as TestRecord).value = 123
      let record = toRecord(obj)

      expect(record !== undefined).assertTrue()
      expect(record!.name).assertEqual('test')
      expect(record!.value).assertEqual(123)
    })

    it('should return undefined for null or non-object values', 0, () => {
      expect(toRecord(null)).assertEqual(undefined)
      expect(toRecord(undefined)).assertEqual(undefined)
      expect(toRecord('string')).assertEqual(undefined)
      expect(toRecord(123)).assertEqual(undefined)
    })

    it('should push record to target array', 0, () => {
      let target: LooseRecord[] = []
      let record = asRecord(new TestRecord())
      ;(record as TestRecord).key = 'value'

      pushRecord(target, record)

      expect(target.length).assertEqual(1)
      expect(target[0]).assertEqual(record)
    })

    it('should not push undefined or duplicate records', 0, () => {
      let target: LooseRecord[] = []
      let record = asRecord(new TestRecord())
      ;(record as TestRecord).key = 'value'

      pushRecord(target, record)
      pushRecord(target, undefined)
      pushRecord(target, record)

      expect(target.length).assertEqual(1)
    })

    it('should read object field from record', 0, () => {
      let nested = asRecord(new TestRecord())
      ;(nested as TestRecord).inner = 'value'
      let record = asRecord(new TestRecord())
      ;(record as TestRecord).nested = nested
      let result = readObjectField(record, 'nested')

      expect(result !== undefined).assertTrue()
      expect(result!.inner).assertEqual('value')
    })

    it('should return undefined for missing or non-object field', 0, () => {
      let record = asRecord(new TestRecord())
      ;(record as TestRecord).str = 'value'
      ;(record as TestRecord).num = 123

      expect(readObjectField(record, 'missing')).assertEqual(undefined)
      expect(readObjectField(record, 'str')).assertEqual(undefined)
      expect(readObjectField(undefined, 'any')).assertEqual(undefined)
    })

    it('should parse json object field', 0, () => {
      let record = asRecord(new TestRecord())
      ;(record as TestRecord).data = '{"name":"test","value":123}'
      let result = parseJsonObjectField(record, 'data')

      expect(result !== undefined).assertTrue()
      expect(result!.name).assertEqual('test')
      expect(result!.value).assertEqual(123)
    })

    it('should return undefined for invalid json or non-string field', 0, () => {
      let objectValue = asRecord(new TestRecord())
      ;(objectValue as TestRecord).a = 1
      let record = asRecord(new TestRecord())
      ;(record as TestRecord).valid = '{"ok":true}'
      ;(record as TestRecord).invalid = 'not json'
      ;(record as TestRecord).empty = ''
      ;(record as TestRecord).obj = objectValue

      expect(parseJsonObjectField(record, 'invalid')).assertEqual(undefined)
      expect(parseJsonObjectField(record, 'empty')).assertEqual(undefined)
      expect(parseJsonObjectField(record, 'obj')).assertEqual(undefined)
      expect(parseJsonObjectField(undefined, 'any')).assertEqual(undefined)
    })

    it('should read device field from various keys', 0, () => {
      let device1 = asRecord(new TestRecord()); (device1 as TestRecord).id = 'dev1'
      let device2 = asRecord(new TestRecord()); (device2 as TestRecord).id = 'dev2'
      let device3 = asRecord(new TestRecord()); (device3 as TestRecord).id = 'dev3'
      let device4 = asRecord(new TestRecord()); (device4 as TestRecord).id = 'dev4'
      let record1 = asRecord(new TestRecord()); (record1 as TestRecord).device = device1
      let record2 = asRecord(new TestRecord()); (record2 as TestRecord).remoteDevice = device2
      let record3 = asRecord(new TestRecord()); (record3 as TestRecord).bluetoothDevice = device3
      let record4 = asRecord(new TestRecord()); (record4 as TestRecord).usbDevice = device4

      expect(readDeviceField(record1)!.id).assertEqual('dev1')
      expect(readDeviceField(record2)!.id).assertEqual('dev2')
      expect(readDeviceField(record3)!.id).assertEqual('dev3')
      expect(readDeviceField(record4)!.id).assertEqual('dev4')
    })

    it('should return undefined when no device field found', 0, () => {
      let other = asRecord(new TestRecord()); (other as TestRecord).id = 'dev'
      let record = asRecord(new TestRecord()); (record as TestRecord).other = other

      expect(readDeviceField(record)).assertEqual(undefined)
      expect(readDeviceField(undefined)).assertEqual(undefined)
    })

    it('should convert array to record array', 0, () => {
      let arr: LooseValue[] = [
        asRecord(new TestRecord()),
        asRecord(new TestRecord()),
        'string',
        undefined
      ]
      ;((arr[0] as LooseRecord) as TestRecord).a = 1
      ;((arr[1] as LooseRecord) as TestRecord).b = 2

      let result = toRecordArray(arr)

      expect(result.length).assertEqual(2)
      expect(result[0].a).assertEqual(1)
      expect(result[1].b).assertEqual(2)
    })

    it('should return empty array for non-array input', 0, () => {
      expect(toRecordArray(null).length).assertEqual(0)
      expect(toRecordArray(undefined).length).assertEqual(0)
      expect(toRecordArray(asRecord(new TestRecord())).length).assertEqual(0)
      expect(toRecordArray('string').length).assertEqual(0)
    })

    it('should collect payload sources from event data', 0, () => {
      let device1 = asRecord(new TestRecord()); (device1 as TestRecord).id = 'dev1'
      let device2 = asRecord(new TestRecord()); (device2 as TestRecord).id = 'dev2'
      let parameters = asRecord(new TestRecord()); (parameters as TestRecord).device = device1
      let wantParameters = asRecord(new TestRecord()); (wantParameters as TestRecord).usbDevice = device2
      let want = asRecord(new TestRecord()); (want as TestRecord).parameters = wantParameters
      let data = asRecord(new TestRecord()); (data as TestRecord).parameters = parameters; (data as TestRecord).want = want

      let sources = collectPayloadSources(data)

      expect(sources.length > 0).assertTrue()
    })

    it('should pick number from sources', 0, () => {
      let source1 = asRecord(new TestRecord()); (source1 as TestRecord).value = 123
      let source2 = asRecord(new TestRecord()); (source2 as TestRecord).other = 456
      let sources: LooseRecord[] = [source1, source2]

      let result = pickNumber(sources, ['value'])

      expect(result).assertEqual(123)
    })

    it('should return NaN when number not found', 0, () => {
      let source = asRecord(new TestRecord()); (source as TestRecord).str = 'text'
      let sources: LooseRecord[] = [source]

      let result = pickNumber(sources, ['missing'])

      expect(Number.isNaN(result)).assertTrue()
    })

    it('should pick string from sources', 0, () => {
      let source1 = asRecord(new TestRecord()); (source1 as TestRecord).name = 'test'
      let source2 = asRecord(new TestRecord()); (source2 as TestRecord).other = 'value'
      let sources: LooseRecord[] = [source1, source2]

      let result = pickString(sources, ['name'])

      expect(result).assertEqual('test')
    })

    it('should return empty string when string not found', 0, () => {
      let source = asRecord(new TestRecord()); (source as TestRecord).num = 123
      let sources: LooseRecord[] = [source]

      let result = pickString(sources, ['missing'])

      expect(result).assertEqual('')
    })
  })
}
