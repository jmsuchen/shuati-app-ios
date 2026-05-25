# 刷题 App 项目方案

## 1. 项目定位

本项目是一个面向自学、备考和内部培训的 iOS 刷题 App。用户上传题库文件后，系统自动识别题目内容，并通过 DeepSeek V4 API 生成“挖空练习”。练习过程中 App 实时判断用户答案对错，答错后展示正确答案和解析，完成后生成得分报告，并支持一键基于同一题库重新出题。

开发方式：使用 Xcode 原生开发，推荐 SwiftUI + SwiftData + async/await。

目标平台：iOS 17 及以上，后续可扩展 iPadOS 和 macOS。

## 2. 核心目标

1. 降低制题成本：从 docx 或 markdown 题库自动生成可练习题目。
2. 提升练习效率：以填空、即时反馈、错题复盘为核心体验。
3. 支持重复训练：完成后可一键重新生成不同挖空版本。
4. 形成学习闭环：记录分数、正确率、错题、重练次数和题库表现。

## 3. 用户角色

主要用户：

- 学生：上传复习资料，进行背诵和知识点检测。
- 教师/培训者：上传标准题库，快速生成训练内容。
- 自学用户：把 markdown 笔记或 Word 文档转成练习。

## 4. MVP 功能范围

### 4.1 文件上传

支持格式：

- `.docx`
- `.md`
- `.markdown`

上传入口：

- iOS 文件选择器
- 分享到 App
- 后续版本可支持 iCloud Drive、OneDrive、Notion 导出文件

文件处理策略：

- Markdown：本地直接解析文本结构。
- docx：本地提取正文文本，保留标题、段落、列表等基础结构。
- 文件过大时按章节或段落切分，避免一次请求超出模型上下文。

### 4.2 题库解析

系统将上传内容转换为统一的 `QuestionSource` 数据结构：

- 标题
- 原文片段
- 知识点标签
- 可挖空关键词
- 难度建议
- 来源位置

解析流程：

1. 文件读取。
2. 文本清洗。
3. 段落/标题/列表结构识别。
4. 调用 DeepSeek V4 生成候选挖空题。
5. 本地校验返回 JSON。
6. 写入本地题库。

### 4.3 自动挖空练习

题型以填空题为 MVP 核心：

- 单空填空。
- 多空填空。
- 关键词遮盖。
- 概念定义挖空。

示例：

原文：

```text
SwiftUI 使用声明式语法构建用户界面。
```

生成：

```text
SwiftUI 使用 ____ 语法构建用户界面。
```

答案：

```text
声明式
```

### 4.4 实时反馈

用户提交每一道题后立即反馈：

- 正确：显示通过状态，进入下一题。
- 错误：显示正确答案，可展开查看原文和简短解析。
- 部分正确：多空题按空位逐项标记。

判分策略：

- 优先本地精确匹配。
- 支持忽略大小写、首尾空格、中文标点差异。
- 后续可增加语义等价判断，但 MVP 不建议每次答题都调用 API，以控制成本和延迟。

### 4.5 评分系统

一次练习结束后生成结果页：

- 总分：0-100。
- 正确题数。
- 错误题数。
- 正确率。
- 平均答题时间。
- 连续正确数。
- 本轮难度。
- 错题列表。

推荐评分公式：

```text
基础分 = 正确题数 / 总题数 * 100
时间奖励 = min(5, 标准时间节省比例 * 5)
错误惩罚 = 重复错误题数 * 1
最终分 = clamp(基础分 + 时间奖励 - 错误惩罚, 0, 100)
```

MVP 可先使用基础分，待数据稳定后再启用时间奖励和错误惩罚。

### 4.6 一键再出题

练习结束后提供“再练一次”按钮：

- 使用同一题库重新生成题目。
- 可排除上一轮完全相同的挖空位置。
- 可优先选择上一轮错题相关段落。
- 可选择题量：10、20、30、全部。

推荐策略：

- 第一次再出题：错题优先 60%，新题 40%。
- 连续练习：根据掌握度动态降低已熟练知识点出现频率。

## 5. 非 MVP 后续功能

- 选择题、判断题、排序题。
- OCR 图片题库导入。
- PDF 导入。
- 云同步。
- 教师端题库分发。
- 班级排行榜。
- 学习计划和提醒。
- Apple Shortcuts / App Intents：例如“开始今天的错题练习”。

## 6. 产品信息架构

主 Tab 建议：

1. 题库
2. 练习
3. 错题
4. 统计
5. 设置

核心页面：

- 题库列表页
- 文件导入页
- 题库详情页
- 生成题目进度页
- 练习答题页
- 答题反馈弹层
- 练习结果页
- 错题本页
- API 设置页

## 7. 核心用户流程

### 7.1 首次使用

1. 用户打开 App。
2. App 引导用户配置 DeepSeek API Key，或使用服务端托管密钥方案。
3. 用户上传 docx 或 markdown 文件。
4. App 解析文件并生成题库。
5. 用户选择题量并开始练习。
6. 用户答题并获得实时反馈。
7. 完成后查看成绩。
8. 点击“再练一次”重新出题。

### 7.2 常规练习

1. 用户进入题库。
2. 选择已有题库。
3. 点击“开始练习”或“错题重练”。
4. 完成练习。
5. 查看分数和错题。

## 8. 技术架构

### 8.1 iOS 客户端

推荐技术栈：

- SwiftUI：界面开发。
- SwiftData：本地题库、练习记录、错题存储。
- Foundation `URLSession`：DeepSeek API 请求。
- UniformTypeIdentifiers：文件类型识别。
- FileImporter / Document Picker：文件导入。
- async/await：异步解析、网络请求、生成任务。
- Keychain：保存用户 API Key。

### 8.2 模块划分

```text
App
├── Core
│   ├── Models
│   ├── Services
│   ├── Persistence
│   └── Utilities
├── Features
│   ├── Library
│   ├── Import
│   ├── Generation
│   ├── Practice
│   ├── Mistakes
│   ├── Stats
│   └── Settings
└── Resources
```

### 8.3 服务层

```text
DocumentImportService
MarkdownParser
DocxTextExtractor
QuestionGenerationService
DeepSeekClient
PracticeSessionService
ScoringService
MistakeReviewService
```

## 9. DeepSeek V4 API 接入方案

根据 DeepSeek 官方文档，API 支持 OpenAI 兼容格式，OpenAI 兼容 `base_url` 为：

```text
https://api.deepseek.com
```

当前文档列出的 V4 模型包括：

- `deepseek-v4-flash`
- `deepseek-v4-pro`

推荐使用：

- 默认生成题目：`deepseek-v4-flash`
- 复杂长文档、结构化质量要求高：`deepseek-v4-pro`

### 9.1 请求职责

DeepSeek 只负责高价值生成任务：

- 从原文生成挖空题。
- 为每题生成标准答案。
- 为每题生成短解析。
- 标注难度和知识点。

不建议每次用户输入答案都调用模型。答题判定优先本地完成，以获得即时反馈并降低 API 成本。

### 9.2 生成题目 Prompt 目标

要求模型返回严格 JSON：

```json
{
  "questions": [
    {
      "stem": "SwiftUI 使用 ____ 语法构建用户界面。",
      "answers": ["声明式"],
      "sourceText": "SwiftUI 使用声明式语法构建用户界面。",
      "explanation": "声明式语法描述界面状态，而不是逐步命令式更新 UI。",
      "difficulty": "easy",
      "knowledgeTags": ["SwiftUI", "声明式 UI"]
    }
  ]
}
```

### 9.3 API Key 安全

有两种方案：

方案 A：用户自带 API Key。

- Key 存入 iOS Keychain。
- 优点：后端成本低，开发快。
- 缺点：用户配置门槛高。

方案 B：自建后端代理。

- App 请求自家服务端，服务端再调用 DeepSeek。
- 优点：体验更好，可做额度、风控和日志。
- 缺点：需要后端和运维成本。

MVP 推荐方案 A；商业化版本推荐方案 B。

## 10. 数据模型草案

```swift
@Model
final class QuestionBank {
    var id: UUID
    var title: String
    var sourceFileName: String
    var createdAt: Date
    var questions: [PracticeQuestion]
}

@Model
final class PracticeQuestion {
    var id: UUID
    var stem: String
    var answers: [String]
    var sourceText: String
    var explanation: String
    var difficulty: String
    var knowledgeTags: [String]
}

@Model
final class PracticeSession {
    var id: UUID
    var bankID: UUID
    var startedAt: Date
    var finishedAt: Date?
    var score: Double
    var answers: [AnswerRecord]
}

@Model
final class AnswerRecord {
    var id: UUID
    var questionID: UUID
    var userAnswers: [String]
    var isCorrect: Bool
    var elapsedSeconds: Double
}
```

实际开发时，SwiftData 对数组和关系建模需要按 Xcode 当前版本能力微调。

## 11. UI 设计原则

- 首屏直接展示题库列表和导入按钮。
- 答题页保持专注，不放复杂说明。
- 对错反馈要明显，但不要打断用户节奏。
- 错误答案页必须展示正确答案、原文和解析。
- 结果页突出分数、正确率和“再练一次”。
- 题库生成过程要显示进度和可取消状态。

## 12. Xcode 开发计划

### 阶段 1：项目初始化，2-3 天

- 创建 Xcode SwiftUI 项目。
- 搭建 TabView + NavigationStack。
- 建立 SwiftData 模型。
- 建立基础主题和组件。

交付物：

- 可运行 App 骨架。
- 题库、练习、错题、统计、设置 Tab。

### 阶段 2：文件导入与解析，4-6 天

- 实现 markdown 文件读取。
- 实现 docx 文本提取。
- 建立文本清洗和分段逻辑。
- 添加导入失败处理。

交付物：

- 用户可上传文件并看到解析后的文本预览。

### 阶段 3：DeepSeek 出题，5-7 天

- 实现 DeepSeekClient。
- 设计 JSON Prompt。
- 实现分段生成和结果合并。
- 增加 JSON Schema 校验与错误重试。
- 保存生成题目到本地。

交付物：

- 可从上传题库生成填空题。

### 阶段 4：练习与实时反馈，5-7 天

- 实现练习会话。
- 实现答题输入、提交、判定。
- 实现正确/错误/部分正确反馈。
- 答错展示正确答案、原文、解析。

交付物：

- 完整刷题闭环可用。

### 阶段 5：评分与再出题，3-5 天

- 实现分数计算。
- 实现结果页。
- 实现错题记录。
- 实现一键再出题。

交付物：

- 用户完成后可看分数，并再次生成新一轮题目。

### 阶段 6：测试与优化，4-6 天

- 单元测试：评分、答案判定、JSON 解析。
- UI 测试：导入、生成、答题、结果流程。
- 性能测试：大文件导入、题目生成进度。
- 体验优化：错误提示、空状态、加载状态。

交付物：

- 可进行 TestFlight 内测的版本。

## 13. 里程碑

| 里程碑 | 时间 | 结果 |
| --- | --- | --- |
| M1 原型可跑 | 第 1 周 | App 骨架、文件导入、文本预览 |
| M2 自动出题 | 第 2 周 | DeepSeek 生成填空题并保存 |
| M3 完整练习闭环 | 第 3 周 | 答题、反馈、得分、错题 |
| M4 内测版本 | 第 4 周 | 再出题、测试、稳定性优化 |

## 14. 测试重点

- docx 解析是否丢失正文。
- markdown 标题、列表、代码块是否处理正确。
- DeepSeek 返回非法 JSON 时是否可恢复。
- 大文档是否会超时或超上下文。
- 答案判定是否过严或过松。
- 断网、API Key 错误、余额不足时是否有清晰提示。
- 重复生成是否真的避免完全相同题目。

## 15. 风险与对策

| 风险 | 影响 | 对策 |
| --- | --- | --- |
| DeepSeek 输出格式不稳定 | 题目无法保存 | 使用严格 JSON Prompt、本地校验、失败重试 |
| docx 格式复杂 | 解析不完整 | MVP 先支持正文，复杂表格后续支持 |
| API 成本过高 | 商业化压力 | 本地判分、分段缓存、题库复用 |
| 答案等价判断困难 | 用户误判体验差 | 先支持标准化规则，再加入可选语义判定 |
| 大文件生成慢 | 用户等待时间长 | 分段生成、进度展示、后台任务 |
| API Key 泄露 | 安全风险 | Keychain 保存，商业版改后端代理 |

## 16. 推荐验收标准

MVP 完成时应满足：

- 可导入 markdown 和 docx 文件。
- 可从文件生成至少 10 道填空题。
- 可完成一轮练习并实时看到对错。
- 答错后显示正确答案和解析。
- 结束后显示分数、正确率、错题。
- 可点击“再练一次”生成新一轮题。
- 断网或 API 错误时有可理解的提示。

## 17. 官方资料参考

- DeepSeek API Quick Start: https://api-docs.deepseek.com/
- DeepSeek Models API: https://api-docs.deepseek.com/api/list-models

