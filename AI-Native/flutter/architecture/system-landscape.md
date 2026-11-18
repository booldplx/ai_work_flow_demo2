# ai_work_flow_demo2 项目画像

第 3.1 节是本工作流的技术基线。接入负责人用实际仓库补充版本、路径和构建配置。项目事实在本文件维护，Story / DD 引用具体版本与范围。

## 一、产品全景

当前应用已实现周末工坊预约 Demo 第 01 卡的发现和只读详情。产品面向想在周末体验手作的用户，覆盖 Android 和 iOS，使用简体中文。Demo 从「发现」进入，用户可以分页浏览活动、查看详情、免费预约一席，再到「我的预约」查看或取消。取消后可再次预约。

体验范围包含加载、空态、失败重试、预约冲突、跨页状态同步和同库重启恢复。场次为固定演练数据，按东八区展示，可跨日期重复演练。账号注册与登录、支付、候补、推送和后台管理留待后续版本。

页面采用随需求提供的 v1.0.0 设计稿。[P1 发现](../docs/prototype/周末工坊/v1.0.0/P1-发现.png) · [P2 活动详情](../docs/prototype/周末工坊/v1.0.0/P2-活动详情.png) · [P3 我的预约](../docs/prototype/周末工坊/v1.0.0/P3-我的预约.png)

## 二、系统边界

工程包含 Android 与 iOS 宿主。第 01 卡通过 HTTP 读取活动与详情。周末工坊 Demo 使用资料包中的本地模拟服务。应用负责页面交互、提交互斥和读回恢复，模拟服务负责计算余位、限制固定体验者每场最多一笔有效预约、扣还席位及持久化。

## 三、技术栈与目录结构

### 3.1 技术栈

当前入口使用 MaterialApp.router，业务采用 Riverpod Provider 组装和构造注入，ChangeNotifier ViewModel 发布状态。pubspec 已声明 Flutter、cupertino_icons、Dio、flutter_riverpod 和 go_router，开发依赖包含 flutter_test、flutter_lints 和 integration_test。下表是后续业务开发的选型基线，按本卡涉及的能力选用。已有工程采用不同方案时，在本节记录实际选型、适用模块及原因，供详设与审查共同引用。依赖版本以业务工程的 SDK 约束、pubspec.yaml 和 pubspec.lock 为准。

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

应用根为项目根 `.`，入口是 `lib/main.dart`。第 01 卡已实现 `WorkshopApp`，采用 MVVM、Dio 5.11.1、flutter_riverpod 3.3.2 和 go_router 17.5.0，精确版本以 pubspec.lock 为准。业务位于 `lib/features/workshops/`，`presentation/pages.dart` 中的 `RefreshablePagedList` 组合 SDK 刷新与分页，发现 ViewModel 持有列表快照，详情 ViewModel 按路由 ID 读取数据。测试在 `test/features/workshops/`，真实 HTTP 模拟器用例在 `integration_test/workshop_http_test.dart`。工作流位于 `AI-Native/flutter/`。

### 3.3 构建变体与包体预算

当前应用版本 1.0.0+1，Dart 约束 ^3.11.5。接入时本机 Flutter 3.41.10-ohos-1.0.1、Dart 3.11.5。Android 使用 Gradle 8.14、AGP 8.11.1、Kotlin 2.2.20，Java 编译目标 17，minSdk 和 targetSdk 取自 Flutter 插件。iOS scheme 为 Runner，部署目标 13.0。第 01 卡通过 String.fromEnvironment 的 API_BASE_URL 注入模拟服务地址。Xcode 27 的 Debug 模拟器配置和 Pods 将模拟器部署目标设为 15.0，设备部署目标仍以宿主工程配置为准。Android debug manifest 允许本地 HTTP。应用内打包 Noto Serif CJK SC Regular/Bold 及 OFL 许可。包体预算待业务确定。

## 四、集成与契约

### 4.1 API 契约（唯一真相）

周末工坊模拟契约锁定为 `workshops-demo v1.0.0`（2026-11-18）。OpenAPI 3.0.3 的服务前缀为 `/api/v1`。以契约为准读取请求、响应、状态码与示例。 [OpenAPI 快照](../docs/handoff/openapi/workshops.yaml) · [VERSION](../docs/handoff/VERSION)

| operationId | 方法与相对路径 | 成功判据 |
|---|---|---|
| `listWorkshops` | GET `/workshops` | 200，`items` 和 `nextPage`；默认从 1 开始，每页 3 条，`nextPage=null` 到末页 |
| `getWorkshop` | GET `/workshops/{workshopId}` | 200，活动详情含 `remaining` 和 `myReservationId` |
| `createReservation` | POST `/reservations` | 201，返回预约和更新后的 `workshop` |
| `listReservations` | GET `/reservations` | 200，当前体验者有效预约的 `items`，最近创建在前 |
| `cancelReservation` | DELETE `/reservations/{reservationId}` | 204，响应体为空，跳过 JSON 解析 |

模拟服务入口为资料目录 `/Users/laopi/Desktop/Test/周末工坊预约/` 下的 `python3 mock/server.py`，仅监听开发机回环。默认数据库 `mock/local.sqlite3` 随同一数据库文件保留预约，使用 `--db` 可指定独立演练库。Flutter 调试地址按联调说明通过 `--dart-define=API_BASE_URL=…` 传入，以下为后续接入环境。 [联调说明](/Users/laopi/Desktop/Test/周末工坊预约/联调说明.md)

| 环境 | `API_BASE_URL` |
|---|---|
| Mac / iOS Simulator | `http://127.0.0.1:8765/api/v1` |
| Android Studio Emulator | `http://10.0.2.2:8765/api/v1` |
| Android USB 调试设备 | 执行 `adb reverse tcp:8765 tcp:8765` 后使用 `http://127.0.0.1:8765/api/v1` |
| iOS 真机 | 需要设备可达的调试服务地址 |

### 4.2 鉴权流程

周末工坊模拟服务固定一位体验者，无 token、登录或刷新流程。预约归属由服务端按固定体验者处理。

### 4.3 错误码分层（与后端对齐）

成功以各 operation 的 HTTP 状态判定。错误响应含 `code` 与 `message`，`400/BAD_REQUEST` 表示分页参数或创建请求体无效，`404/NOT_FOUND` 表示目标记录不存在，创建时的 `409/FULL` 与 `409/ALREADY_BOOKED` 分别表示满额与已有有效预约。写入超时或断线时先查询服务端结果，再恢复交互。 反馈方式参见[错误展示规则](../rules/error-display-conventions.md)。

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
| 2026-11-18 | 登记周末工坊预约的产品范围、设计稿和模拟契约 workshops-demo v1.0.0 |
