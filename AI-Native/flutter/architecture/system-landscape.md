# ai_work_flow_demo2 项目画像

第 3.1 节是本工作流的技术基线。接入负责人用实际仓库补充版本、路径和构建配置。项目事实在本文件维护，Story / DD 引用具体版本与范围。

## 一、产品全景

当前工程是 Flutter 初始计数器应用。首页显示计数，点击加号递增。首个业务需求、设计稿与验收范围由实际需求确定。

## 二、系统边界

工程包含 Android 与 iOS 宿主。计数器在页面内维护状态，当前无后端、持久化或第三方业务 SDK 接入。

## 三、技术栈与目录结构

### 3.1 技术栈

当前入口使用 MaterialApp、StatefulWidget 和 setState。pubspec 声明 Flutter、cupertino_icons，开发依赖为 flutter_test 与 flutter_lints。下表是后续业务开发的选型基线，按本卡涉及的能力选用。已有工程采用不同方案时，在本节记录实际选型、适用模块及原因，供详设与审查共同引用。依赖版本以业务工程的 SDK 约束、pubspec.yaml 和 pubspec.lock 为准。

| 领域 | 约定方案 | 实现要求 |
|---|---|---|
| 项目架构 | 按业务模块组织的 MVVM（Model–View–ViewModel） | View（Widget）渲染状态和转发交互，ViewModel 管理页面状态与操作，Model 层由领域模型、Repository 和 Service 组成。已有 Controller 承担相同职责时可沿用其名称。见[分层约定](../rules/flutter-project.md)。 |
| 网络请求 | Dio | 按信任域配置客户端，统一超时、鉴权、取消、错误转换。 |
| 状态共享 | Riverpod（flutter_riverpod） | 页面和会话状态按生命周期提供，切换账号时隔离状态。 |
| 页面局部状态 | setState、ValueNotifier | 展开、显隐和输入交互由 Widget 就近管理。创建 ValueNotifier 的对象负责释放它。 |
| 分页列表（下拉刷新 + 上拉加载更多） | 复用项目的分页列表组件，或用 Flutter SDK 组合实现 | 页面通过同一个列表组件绑定刷新和加载下一页，触发条件、底部状态及请求处理见[列表刷新与分页](../rules/flutter-project.md#81-列表刷新与分页)。 |
| 路由 | go_router | 集中声明路由、登录重定向、深链解析与恢复目标。 |
| 轻量配置 | shared_preferences | 保存主题、语言和引导页标记。 |
| 敏感信息 | flutter_secure_storage | 保存需要持久化的少量凭据，随会话失效清理。 |
| 结构化存储 | Drift / SQLite | 离线记录、查询与事务使用数据库，升级时验证旧库迁移。 |
| 应用内事件 | 类型化 Stream，按需封装事件分发 | 声明事件类型、作用域和所有者，取消订阅；需要重放的业务事实另行保存。 |
| 数据模型 | 不可变对象 + JSON 序列化 | 明确线上字段与 Dart 属性映射，按契约解析。领域模型与传输 DTO 在数据边界转换。 |
| 依赖注入 | Riverpod Provider + 构造函数注入 | Provider 组装 Service、Repository 和 Controller；类通过构造函数声明依赖，测试可传入替身。 |
| 测试 | 单元测试、Widget 测试、集成测试 | 按 AC 和风险选择层级，原生能力按目标设备补验。 |
| 质量检查 | Dart formatter、Flutter analyzer、CI | 应用 PR 自动执行格式、静态分析和测试。命令见[测试规则](../rules/testing-release.md)。 |

接入时记录 Flutter/Dart 版本、Android 的 JDK/Gradle/Kotlin 与 minSdk/targetSdk、iOS 的 Xcode/Swift 与 deployment target，以及设备矩阵、推送供应商、性能预算、构建命令和发布负责人。

### 3.2 目录结构

应用根为项目根 `.`，入口是 `lib/main.dart`。MyApp 装配主题，MyHomePage 显示计数并处理点击。当前没有抽取业务公共组件，分页列表按首个相关 Story 选择和登记。Widget 冒烟测试在 `test/widget_test.dart`。工作流位于 `AI-Native/flutter/`。

### 3.3 构建变体与包体预算

当前应用版本 1.0.0+1，Dart 约束 ^3.11.5。接入时本机 Flutter 3.41.10-ohos-1.0.1、Dart 3.11.5。Android 使用 Gradle 8.14、AGP 8.11.1、Kotlin 2.2.20，Java 编译目标 17，minSdk 和 targetSdk 取自 Flutter 插件。iOS scheme 为 Runner，部署目标 13.0。自定义环境与包体预算待业务确定。

## 四、集成与契约

### 4.1 API 契约（唯一真相）

当前本地计数器的 API 范围为 N/A。首张网络卡从后端取得 OpenAPI 快照与 VERSION，同步到线根的 `docs/handoff/`，再登记环境、operationId 和成功判据。

### 4.2 鉴权流程

当前无登录流程。涉及会话的 Story 按届时交接的契约登记鉴权与恢复行为。

### 4.3 错误码分层（与后端对齐）

当前无服务端错误码。接入接口后按实际契约填写，展示方式见[错误展示规则](../rules/error-display-conventions.md)。

## 五、AI Native 工程资产

| 层级 | 路径 | 职责 |
|------|------|------|
| 执行层 | `skills/flutter-*/SKILL.md` | Agent 运行时步骤 |
| 横切层 | `rules/*.md` | 编码与文档规范 |
| 样例层 | `docs/**/_golden/` | Few-shot 标准样例 |
| 配置 | `config/current-sprint` | 当前迭代 |
| 词表 | `glossary/domain-glossary.md` | 术语一致 |

## 六、与后端流水线的协作

```text
后端：story-splitting → detail-design → OpenAPI 定稿 → tag
              ↓
        发布 handoff 包（OpenAPI + VERSION + Story 摘要/stories-index）
              ↓
客户端：同步 docs/handoff/ → flutter-story-splitting → flutter-detail-design → flutter-feature-coding
              ↓
        联调（同一 OpenAPI tag 与后端环境一致）
```

**原则**：涉及后端调用的卡先定稿 OpenAPI，再跑相关详设；接口/字段/错误码变更**必须先改后端 OpenAPI**，再同步本仓——客户端仓永远不直接改契约。

---

## 变更记录

| 日期 | 变更 |
|------|------|
| 2026-11-18 | 按当前应用工程完成首次接入 |
