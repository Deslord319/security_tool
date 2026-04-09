import { AppText } from '../constants/StringCatalog'
import { PeripheralExportStrings } from '../constants/modules/PeripheralStrings'

export class ExportMessageUtils {
  static buildDownloadCenterDisplayPath(fileName: string): string {
    return `${PeripheralExportStrings.DOWNLOAD_PATH_PREFIX}/${AppText.NAME}/${fileName}`
  }

  static buildExportSuccessText(fileName: string): string {
    return `${PeripheralExportStrings.SUCCESS_PREFIX}${ExportMessageUtils.buildDownloadCenterDisplayPath(fileName)}`
  }
}
