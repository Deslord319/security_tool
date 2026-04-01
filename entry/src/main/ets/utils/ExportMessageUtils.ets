import { CommonStrings } from '../constants/CommonStrings'
import { PeripheralStrings } from '../constants/modules/PeripheralStrings'

export class ExportMessageUtils {
  static buildDownloadCenterDisplayPath(fileName: string): string {
    return `${PeripheralStrings.exportDownloadPathPrefix}/${CommonStrings.appName}/${fileName}`
  }

  static buildExportSuccessText(fileName: string): string {
    return `${PeripheralStrings.exportSuccessPrefix}${ExportMessageUtils.buildDownloadCenterDisplayPath(fileName)}`
  }
}
