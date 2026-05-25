# 刷题 App

原生 iOS SwiftUI 刷题应用，用于从文档或手动录入的材料中识别可练习内容，并在练习时按选择的题型即时出题。

## 功能

- 题库、练习、错题、统计、设置五个模块。
- 支持导入 markdown、txt、docx，也支持手动录入材料。
- 题库页只保存材料，不提前挖空、不提前确定题型。
- 进入练习时选择题量和题型：填空、选择、判断、混合。
- 选择题会生成 4 个选项；重新出卷会尽量更换挖空位置。
- 未完成练习可继续或重新开始。
- 错题支持复练、单题练习、显示答案解析、单题删除和多选删除。
- 设置页可配置错题连对几次后自动移除。
- DeepSeek API Key 支持内置配置，也支持用户在设置中覆盖。

## 本地运行

1. 用 Xcode 打开 `刷题App.xcodeproj`。
2. 选择 `刷题App` scheme 和 iOS 17+ 设备或模拟器。
3. 真机运行时，在 Signing & Capabilities 中选择你的 Team。
4. 点击 Xcode 的运行按钮安装到设备。

## API 配置

复制 `Config/APISecrets.example.xcconfig` 为 `Config/APISecrets.local.xcconfig`，然后填写：

```text
DEEPSEEK_API_KEY = your_api_key_here
```

`Config/APISecrets.local.xcconfig` 已被 `.gitignore` 排除，不会上传到 GitHub。

## 构建检查

```bash
xcodebuild -quiet -project 刷题App.xcodeproj -scheme 刷题App -configuration Debug -destination generic/platform=iOS -derivedDataPath ./DerivedData CODE_SIGNING_ALLOWED=NO build
```
