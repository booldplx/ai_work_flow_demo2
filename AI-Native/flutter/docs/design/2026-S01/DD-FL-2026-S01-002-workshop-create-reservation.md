# DD-FL-2026-S01-002 · 创建预约

## 1. 范围与依据

| 项 | 内容 |
|---|---|
| 状态 | 已确认 · 2026-S01 · Android / iOS · 简体中文 |
| 对应 Story | [STORY-FL-2026-S01-002](../../requirements/2026-S01/STORY-FL-2026-S01-002-workshop-create-reservation.md)，B1–B6 |
| 前置能力 | 第 01 卡已完成的 P1 分页、P2 按 ID 读取详情、来源返回和滚动位置保留。 [第 01 卡 DD](DD-FL-2026-S01-001-workshop-browse-detail.md) |
| 接口与版本 | [OpenAPI](../../handoff/openapi/workshops.yaml) · [workshops-demo v1.0.0](../../handoff/VERSION) |
| 技术基线 | MVVM、Riverpod Provider 与构造注入、ChangeNotifier、Dio、go_router。 [系统画像 §3](../../../architecture/system-landscape.md#三技术栈与目录结构) |
| 调试地址 | 继续由 `String.fromEnvironment('API_BASE_URL')` 注入，默认 `http://127.0.0.1:8765/api/v1`，Android USB 真机使用 `adb reverse tcp:8765 tcp:8765`。 [联调说明](/Users/laopi/Desktop/Test/周末工坊预约/联调说明.md) |

本卡覆盖详情预约一席、提交互斥、冲突与失败、离页恢复、发现页余位和预约状态同步。用户已确认发现行同时显示「已预约」和最新余位，创建 404 沿用「活动不存在」和返回入口，创建 400 Toast 提示「参数错误」。

完整「查看我的预约」跳转和 P3 由第 03 卡接入，第 02 卡成功操作区显示「已预约」和禁用的「查看我的预约」，第 03 卡接入后启用真实跳转。 [交互与视觉](/Users/laopi/Desktop/Test/周末工坊预约/交互与视觉.md)

## 2. 路由与跨卡交接

| 入口与操作 | 参数与导航 | 数据与位置 |
|---|---|---|
| P1 点活动整行 | 命名路由 workshop，路径 `/workshops/:workshopId`，字符串 ID | P2 按 ID 重读详情，隐藏底栏，显示符合当前资格的操作区 |
| P2 点击预约 | 使用路由对应的 `Workshop.id` 创建预约 | 201 后留在 P2，更新余位与预约状态 |
| P2 普通返回 | 页面返回、Android 系统返回、iOS 返回手势均 pop 回来源 | P1 保留已加载页、nextPage 和原滚动控制器，对应活动就地更新 |
| P2 直接打开且无来源 | 只凭 ID 读取，返回时 go 到 `/discover` | 发现首载读取最新活动与预约状态 |
| P2 预约后「查看我的预约」 | 第 03 卡导航到 `/reservations` 根页面并移除当前详情 | 第 03 卡再从 P3 推入 P2 时返回来源为 P3 |

提交期间所有返回方式继续可用。路由返回本身不决定预约结果。重新进入同一活动时，读取应用会话内的该活动提交状态，按第 5 节等待或重新查询。当前服务固定一位体验者，无登录跳转或认证恢复。

## 3. 现有资产与实现职责

| 现有文件 / 对象 | 本卡扩展 |
|---|---|
| `lib/main.dart` / WorkshopApp | 复用 Dio 实例、基础地址和 Riverpod 根注入，Repository 生命周期覆盖发现与详情 |
| `data/workshops.dart` / Workshop、WorkshopPage | 复用不可变模型及东八区时间语义，新增 Reservation 响应模型 |
| `data/workshops.dart` / WorkshopService | 复用读取接口，增加创建 POST 的方法与严格的 201 判定 |
| `data/workshops.dart` / WorkshopRepository、HttpWorkshopRepository | 增加 createReservation，结构化错误与预约操作状态，发布活动更新 |
| `presentation/view_models.dart` / DetailViewModel | 协调详情读、预约提交、冲突读回、结果未知与重试查询 |
| `presentation/view_models.dart` / DiscoverViewModel | 订阅当前会话的活动更新，按 ID 替换已加载行，合并分页返回与活动更新 |
| `presentation/pages.dart` / WorkshopDetailPage、WorkshopRow | 增加详情底部操作区与一次性反馈，复用已预约与余位同屏的行展示 |
| `presentation/pages.dart` / RefreshablePagedList | 复用刷新、追加、失败重试及滚动控制器，接收更新后的列表快照 |

上表文件名相对应用根的 `lib/features/workshops/`，main.dart 相对应用根。

| 层 | 责任与输入输出 |
|---|---|
| View | 展示详情和操作区，按钮回调交给 ViewModel。返回由页面处理。监听有唯一序号的反馈事件，显示成功或错误 Toast 一次。Widget 重建不会重放反馈。 |
| DetailViewModel | 接收 `workshopId` 与 Repository。输出活动、详情读取阶段、预约操作阶段和一次性反馈。提交资格从当前活动与操作阶段派生，submit 在发请求前同步设为提交中。queryResult 只调用详情 GET。 |
| DiscoverViewModel | 管理分页与已加载列表。订阅 Repository 的活动快照，将已有行按 ID 原位替换，不插入未加载的活动，不清空分页。 |
| Repository | `createReservation(workshopId)` 返回 `Future<Reservation>`，`getWorkshop(id)` 和 `listWorkshops(page)` 沿用既有输入输出。维护每场正在执行或结果待确认的预约操作，发布可观察的最新活动快照。 |
| Service / Dio | POST JSON 和响应解析、HTTP 状态与错误码分类、传输失败识别。接收现有超时配置，创建操作通过明确的单次请求执行。 |

Repository 当前将多种错误统一收敛为 WorkshopFailure。本卡扩展为可识别的 HTTP 状态、契约 code、传输失败与解析失败信息，让 ViewModel 能分别处理 FULL、ALREADY_BOOKED、NOT_FOUND 和 BAD_REQUEST。既有第 01 卡读取失败与 notFound 的展示行为继续使用同一错误映射。

## 4. Widget 树、参数与视觉

```text
WorkshopDetailPage(workshopId)
  ├─ SafeArea
  │   ├─ 返回按钮
  │   └─ Expanded · 第 01 卡详情正文或其读取反馈
  ├─ bottomNavigationBar · SafeArea
  │   └─ ReservationActionPanel
  │       ├─ 可预约 → 预约活动
  │       ├─ 提交中 → 预约中…
  │       ├─ 已预约 → 已预约 + 查看我的预约（第 02 卡禁用）
  │       ├─ 未预约且满额 → 已满额
  │       └─ 结果未知 / 冲突查询失败 → 重新查询
  └─ 一次性 Toast

DiscoverPage
  └─ 原分页组件 → WorkshopRow
       └─ 同一行内纵排 已预约 / 余 N 席
```

ReservationActionPanel 接收派生的操作显示状态、onReserve、onQueryResult，以及由第 03 卡提供的 onViewReservations。第 02 卡该回调为空，查看入口使用禁用语义和次级文字。查询中显示「查询中…」并禁用重复查询。已预约优先于满额，正文中的余位始终取 remaining。详情加载或活动不存在时收起操作区，加载失败时沿用第 01 卡读取重试。

| Story 稿件 | 状态与映射 |
|---|---|
| P2 预约前详情及预约入口 | 正文复用第 01 卡，新增底部红棕操作条「预约活动」，与原稿对照。 [P2 v1.0.0](../../prototype/周末工坊/v1.0.0/P2-活动详情.png) |
| P1 返回后列表布局 | 复用原分页及行布局，已预约活动在同一活动行内显示已预约和余位。第 01 卡已确认同屏纵排样式。 [P1 v1.0.0](../../prototype/周末工坊/v1.0.0/P1-发现.png) |
| P2 提交中、成功后、满额禁用、冲突反馈、重新查询 | 有交互说明，无独立稿，已确认沿用第 01 卡主题与本节布局 |
| P2 创建 404 与 400 Toast | 404 状态复用第 01 卡 FeedbackPanel 与返回入口，400 文案已确认。Toast 的显示方式已按本节实现取值确认 |
| P3 预约成功后的列表 | 本卡的跨卡目标稿，由第 03 卡交付。 [P3 v1.0.0](../../prototype/周末工坊/v1.0.0/P3-我的预约.png) |

三张原稿均为 502 × 1016 px。继续采用第 01 卡确认的 Noto Serif CJK SC、暖白 #F7F5F2、墨色 #1C1B19、次级文字 #625D57 和红棕 #963E2A。

操作区最小高度 64 逻辑像素，按钮文字 22/30，触控区域至少 48。可预约时红棕底、暖白字。提交中保留原位并替换文字和禁用语义。满额操作使用次级文字及禁用状态。成功后状态与查看入口在操作区纵排，高度随文字放大增长。正文放在剩余空间滚动，底部 SafeArea 包住操作区，返回始终可触达。

Toast 使用应用内 Overlay，在操作区上方显示文字，2 秒后消失，支持无障碍播报。一次动作仅展示一次，不记录到状态历史中。Overlay 与计时器由当前页面的反馈展示对象管理，页面释放时清理。B6 使用该 Toast 显示「参数错误」。

## 5. 预约状态、互斥与离页恢复

详情读取阶段沿用 loading、ready、notFound、loadError。预约阶段独立于正文，明确区分 idle、submitting、reconciling、unknown。预约资格在 idle 且详情有效时计算。

| 当前条件 / 触发 | 下一阶段 | 用户可见结果与数据处理 |
|---|---|---|
| 详情 GET 200，myReservationId 非空 | idle，已预约 | 显示已预约及最新余位，采用已预约操作区 |
| 详情 GET 200，未预约且 remaining > 0 | idle，可预约 | 启用「预约活动」 |
| 详情 GET 200，未预约且 remaining = 0 | idle，满额 | 显示已满额并禁用预约 |
| 可预约时提交 | submitting | 同步禁用按钮并显示「预约中…」，单次 POST |
| POST 201 且 Reservation 解析成功 | idle，已预约 | 以响应 workshop 更新详情及共享快照，提示「预约成功」 |
| POST 409 / ALREADY_BOOKED | reconciling | 提示「你已预约此活动」，随后同 ID GET，成功后使用最新资格 |
| POST 409 / FULL | reconciling | 提示「名额已满」，随后同 ID GET，成功后使用最新资格 |
| 冲突后的 GET 失败 | unknown | 保留已有正文并提供「重新查询」，提交维持禁用 |
| POST 404 / NOT_FOUND | 详情 notFound | 显示「活动不存在」和返回入口，收起正文操作区 |
| POST 400 / BAD_REQUEST | idle | Toast「参数错误」，结束提交，保留详情，按现有资格恢复操作 |
| POST 超时、断线、取消或 201 体无法解析 | unknown | 保留正文，显示「预约结果待确认」和「重新查询」，先 GET 查询结果 |
| unknown 时点重新查询 | reconciling | 单次同 ID GET，显示查询中。失败回 unknown，200 后按服务端资格恢复，404 按活动不存在处理 |

对未知 HTTP 失败保守进入结果待确认，避免在没有读取结果时重复创建。用户明确点击预约是创建入口，重新查询通过 GET 恢复后再次点击才发起下一笔创建。契约中没有幂等键字段，每场最多一笔有效预约由服务端唯一性规则保证。

Repository 在当前应用会话内按 workshopId 维护在途提交。相同活动并发提交共用同一 Future，第二次点击与重新进页均不会再发 POST。ViewModel 的同步禁用与 Repository 的在途互斥共同覆盖快速点击和路由切换。

提交 Future 的所有者是会话内 Repository。P2 退出时取消该页专用的读取与订阅，正在执行的创建保留至其有限超时结束。结果写入 Repository 的操作记录和共享活动快照。已经退出的页面不会再显示 Toast 或写入页面状态。再次进入同 ID 时，在途提交优先显示提交中，等待结束后重新 GET 对齐服务端。GET 较早到达的未预约结果无法覆盖尚未结束的提交。

应用终止后内存操作记录释放，下一次启动按服务端查询。HTTP 超时后的 GET 只说明查询时刻的状态，服务端仍可能稍后完成旧请求，因此客户端不根据 GET 推断旧 POST 被撤销。后续显式重试仍受服务端有效预约唯一性约束。

## 6. P1 / P2 同步及乱序保护

1. Repository 发布活动更新的来源为创建 201 的 Reservation.workshop，以及详情 GET 200 的 Workshop。发现 ViewModel 初始化时读取已有快照，并在生命周期内订阅更新。即时通知同时落入可重读的快照，避免发现页不在树中时丢失结果。
2. 创建成功按返回的 workshop 原位更新 P1 对应活动和 P2 正文。w01 的 remaining 从 3 变 2，myReservationId 从 null 变为非空整数。同一行保留 ID、排序和行键。用户返回 P1 时同步已完成，无需整页刷新。
3. 为避免「余 2 席」和「已预约」让行高度跳变，单行状态区在正常字号下预留两行的最小高度。窄屏／大字号导致布局重新换行时，以原可见行 ID 和行内偏移保持阅读位置，布局完成后限制偏移在有效范围。共享快照更新与分页更新都沿用原滚动控制器。
4. Repository 内部维护活动更新的本地版本和提交阶段。每次列表或详情读请求记录发起时的版本，读响应合入时按 ID 检查版本。请求发出后已发生预约写入或详情读回的活动，采用共享新快照，其他活动可正常追加或替换。创建期间发起的读结果不能覆盖该活动的提交阶段，创建结束后的权威读取再解除这一保护。
5. DiscoverViewModel 继续处理第 01 卡的刷新代次，刷新使旧分页响应失效。跨页同步只更新已加载活动内容，保持 nextPage 与页成员关系。后续主动刷新仍用 listWorkshops 取第一页，普通返回保留现有分页。
6. DetailViewModel 用路由实例与请求序号忽略过期详情响应。201 或冲突读回生效时，同时废弃更早的详情读结果。切到其他活动后，旧活动完成只更新其自己的共享快照。
7. unknown 的提交标记在当前应用会话内按活动保留，重新进入优先查询或等待现有在途操作。冲突后成功 GET、未知结果查询 GET 200 或明确 404 可校准标记。页面释放取消订阅，Repository 随应用作用域销毁时关闭观察通道。

本地版本、阶段和请求序号为客户端协调信息。网络字段沿用本次 OpenAPI。后续第 03 卡的取消也可通过同一共享活动更新入口归还席位，本卡以创建链路和读取接口为验收范围。

## 7. 契约模型与 B1–B6 映射

| operation / schema | 输入输出与实现依据 |
|---|---|
| createReservation 请求 | POST `/reservations`，JSON `{"workshopId":"w01"}`，workshopId 为必填字符串，一次一席 |
| Reservation | 201 响应必填 `id`（整数 ≥ 1）与 `workshop`（完整 Workshop），示例为预约 id=1、w01 余 2 席、myReservationId=1 |
| Workshop | remaining 为整数 ≥ 0，myReservationId 必填且可为 null，非空为整数 ≥ 1。日期按 UTC+08:00 展示 |
| Error | 必填 code 与 message，POST 400 BAD_REQUEST、404 NOT_FOUND、409 FULL 或 ALREADY_BOOKED |
| getWorkshop / listWorkshops | HTTP 200 解析既有模型，分页首页与追加仍使用第 01 卡约定。读响应与共享快照按第 6 节合并 |

响应模型采用不可变对象，Reservation.workshop 复用既有 Workshop 解析。缺少必填字段、类型错误或成功响应内的活动 ID 与请求不一致，作为创建结果待确认并读回。对已知 HTTP 错误先分类状态与 code，再选择反馈，避免使用未知响应正文作为提示。

| AC | operationId | Method | Path（相对 /api/v1） | 成功展示 | 失败展示 |
|---|---|---|---|---|---|
| B1 | createReservation | POST | /reservations | Reservation 示例 w01 余 2 席，详情已预约，发现对应行已预约＋余 2 席 | 转入 B2–B6 对应分支 |
| B1 | getWorkshop | GET | /workshops/{workshopId} | Workshop 示例预约前余 3 席 | 沿用详情读取错误与返回 |
| B1 | listWorkshops | GET | /workshops | 正常分页与后续刷新读取最新活动，返回保留原页和位置 | 沿用第 01 卡分页失败反馈 |
| B2 | createReservation | POST | /reservations | 同一提交期间请求数为 1 | 409 / ALREADY_BOOKED 示例提示你已预约此活动 |
| B2 | getWorkshop | GET | /workshops/{workshopId} | 冲突后读回已预约 | 查询失败时重新查询 |
| B3 | getWorkshop | GET | /workshops/{workshopId} | w02 remaining=0 且无预约时按钮禁用 | 读取错误可重试 |
| B3 | createReservation | POST | /reservations | 资格按服务端最新数据决定 | 409 / FULL 示例提示名额已满并触发 getWorkshop |
| B4 | createReservation | POST | /reservations | 离页后 201 仍更新共享快照 | 超时、断线或解析失败显示结果待确认 |
| B4 | getWorkshop | GET | /workshops/{workshopId} | 重进详情或重新查询按当前服务端资格恢复 | 查询失败保留正文与查询入口 |
| B4 | listWorkshops | GET | /workshops | 后续列表读取与共享更新一致，丢弃过期快照 | 失败保留已加载列表 |
| B5 | createReservation | POST | /reservations | 明确失败后结束提交 | 404 / NOT_FOUND，活动不存在与返回入口 |
| B6 | createReservation | POST | /reservations | 明确失败后结束提交 | 400 / BAD_REQUEST，Toast 参数错误 |

## 8. B1–B6 验证计划

| AC | 单元 / Widget 验证 | Android / iOS 联调证据 |
|---|---|---|
| B1 | 可控 fake 返回 w01 余 3 席，点击时显示预约中，201 后已预约和余 2 席，成功反馈一次。返回 P1 后行状态、分页页数与位置保持 | 独立演练库完成一次真实预约，记录 POST JSON、201 及 P1/P2 运行截图 |
| B2 | 同帧连续点击、等待期间重复点击、离页后再入同 ID 均最多一笔在途 POST。模拟 ALREADY_BOOKED 后核对提示和 GET，读回更新资格 | 按联调说明从终端创建同场预约，App 用陈旧详情再提交，验证 409 与恢复 |
| B3 | w02 初始禁用且不发 POST。fake 以旧详情收到 FULL，核对 GET、已满额与已预约优先级。冲突读回失败后只显示查询入口 | GET w02 验初始满额。陈旧余位导致 FULL 用 fake 验证，按实际执行记录结果 |
| B4 | 延迟 POST 时返回或切后台，重新进入不会重发。超时、断线、201 无效体分别进入待确认，查询成功／失败、无来源返回均覆盖。列表和详情旧响应晚到不覆盖成功结果，刷新／追加交错保持分页。已退出页面没有 Toast | Android 返回键、页面返回、iOS 返回手势分别在提交中操作。网络恢复后重进详情，按同库服务状态核对。P3 无重复记录与第 03 卡 C1 联验 |
| B5 | fake POST 404，页面为活动不存在且仍可返回，校验第 01 卡读取 404 回归 | Service 层测试本地 HTTP 404 / NOT_FOUND 响应，模拟器验证相同可见结果 |
| B6 | fake POST 400，单次 Toast 参数错误，重建不重放，正文保留、按钮恢复，Overlay 按时与离页清理 | Service 层测试本地 HTTP 400 / BAD_REQUEST 响应，两端验证 Toast 位置、安全区和可读性 |

Repository 用本地 HttpServer 或 Dio 测试适配器核对请求字段、状态与 Error 解码，客户端不得自行增加幂等字段。ViewModel 用可控制完成顺序的 Future 覆盖 GET、POST、分页乱序及多路由在途互斥。原有 A1–A4 单测、Widget 和真实 HTTP 用例作为回归。

后续编码运行格式检查、flutter analyze、flutter test 和 Flutter 工作流校验，设备记录系统版本、字体倍率及差异。上述为验收计划，本轮产物为 DD。

## 9. 性能与资源释放

- 列表仍为惰性构建。活动变更只更新对应行数据，操作状态由详情局部监听，静态日期、标题与底栏避免随提交状态重复重建。
- 页面取消自身 GET、监听、Toast 计时器和 Overlay。Repository 的创建请求采用有限连接、发送与接收超时，操作完成后释放请求记录中的 Future 引用，保留必要的结果阶段及活动快照。
- 程序恢复前台时，详情若处在 unknown 则启动一次结果查询，在途提交继续等待同一 Future。重复生命周期回调通过查询互斥去重，已在当前页完成并展示的成功 Toast 不重放。
- 创建接口的日志沿用项目规则，仅记录 operationId、状态、耗时及脱敏关联信息。 [请求层规则](../../../rules/api-client-conventions.md) · [状态与存储](../../../rules/state-storage-events.md) · [错误展示](../../../rules/error-display-conventions.md) · [性能规则](../../../rules/flutter-performance.md)

## 10. 确认记录

用户于 2026-11-18 确认采用建议方案。

- 第 02 卡成功后显示「已预约」和禁用的「查看我的预约」，第 03 卡接入后启用真实跳转。
- 提交中、满额禁用、成功操作区、结果待确认与重新查询等无独立稿状态沿用第 01 卡主题，按第 4 节布局及实现取值验收。
- Toast 使用操作区上方的应用内轻提示，2 秒后消失，支持无障碍播报，并按页面生命周期清理。
- 创建 404 沿用活动不存在与返回入口，创建 400 Toast 提示「参数错误」，沿用此前确认。
