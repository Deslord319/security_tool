import { describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { CsvFileExportService } from '../../main/ets/services/common/export/CsvFileExportService'

class FakeContext {
}

export default function csvFileExportServiceTest() {
  describe('CsvFileExportService', () => {
    it('should escape csv values containing comma', 0, () => {
      let escaped = CsvFileExportService.escapeCsvValue('hello,world')

      expect(escaped).assertEqual('"hello,world"')
    })

    it('should escape csv values containing quote', 0, () => {
      let escaped = CsvFileExportService.escapeCsvValue('say "hello"')

      expect(escaped).assertEqual('"say ""hello"""')
    })

    it('should escape csv values containing newline', 0, () => {
      let escaped = CsvFileExportService.escapeCsvValue('line1\nline2')

      expect(escaped).assertEqual('"line1\nline2"')
    })

    it('should not escape simple values', 0, () => {
      let escaped = CsvFileExportService.escapeCsvValue('simple value')

      expect(escaped).assertEqual('simple value')
    })

    it('should handle empty string', 0, () => {
      let escaped = CsvFileExportService.escapeCsvValue('')

      expect(escaped).assertEqual('')
    })

    it('should return context_missing when context is null for saveText', 0, async () => {
      let result = await CsvFileExportService.saveText(null, 'content')

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('context_missing')
    })

    it('should return empty when content is empty for saveText', 0, async () => {
      let result = await CsvFileExportService.saveText(new FakeContext() as common.UIAbilityContext, '')

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('empty')
    })

    it('should return context_missing when context is null for saveByWriter', 0, async () => {
      let result = await CsvFileExportService.saveByWriter(null, 'prefix', async () => {})

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('context_missing')
    })

    it('should expose writeChunk helper', 0, () => {
      expect(typeof CsvFileExportService.writeChunk).assertEqual('function')
      expect(true).assertTrue()
    })
  })
}
