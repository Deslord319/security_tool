import { describe, expect, it } from '@ohos/hypium'
import { ExportMessageUtils } from '../../main/ets/utils/ExportMessageUtils'

export default function exportMessageUtilsTest() {
  describe('ExportMessageUtils', () => {
    it('should build download center display path', 0, () => {
      let path = ExportMessageUtils.buildDownloadCenterDisplayPath('test.csv')

      expect(path.indexOf('test.csv') > 0).assertTrue()
    })

    it('should build export success text', 0, () => {
      let text = ExportMessageUtils.buildExportSuccessText('records.csv')

      expect(text.indexOf('records.csv') > 0).assertTrue()
    })

    it('should handle empty file name', 0, () => {
      let path = ExportMessageUtils.buildDownloadCenterDisplayPath('')

      expect(path !== undefined).assertTrue()
    })

    it('should handle special characters in file name', 0, () => {
      let text = ExportMessageUtils.buildExportSuccessText('test-file_2024.csv')

      expect(text.indexOf('test-file_2024.csv') > 0).assertTrue()
    })
  })
}
