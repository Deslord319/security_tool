import { CommonStrings } from '../constants/CommonStrings'

export class ExportMessageUtils {
  static buildDownloadCenterDisplayPath(fileName: string): string {
    return `下载/${CommonStrings.appName}/${fileName}`
  }

  static buildExportSuccessText(fileName: string): string {
    return `导出成功：${ExportMessageUtils.buildDownloadCenterDisplayPath(fileName)}`
  }
}
