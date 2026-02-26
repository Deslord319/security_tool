/**
 * 测试运行器页面
 * 显示测试执行状态
 */
@Entry
@Component
struct Index {
  @State message: string = 'Running tests...'

  build() {
    Column() {
      Text(this.message)
        .fontSize(24)
        .fontWeight(FontWeight.Medium)
    }
    .height('100%')
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }
}
