# REVIEW-CODE-FL-STORY-FL-2026-S01-002-workshop-create-reservation

| 项 | 结果 |
|---|---|
| 审查对象 | [Story 02](../../requirements/2026-S01/STORY-FL-2026-S01-002-workshop-create-reservation.md)，B1–B6 |
| 阶段 / 档位 | Flutter 实现 / L2 |
| 审查人 | 独立只读 agent review_card2，实现者记录结果 |
| 上游 | [已确认 DD](../../design/2026-S01/DD-FL-2026-S01-002-workshop-create-reservation.md) · [OpenAPI](../../handoff/openapi/workshops.yaml) · [VERSION](../../handoff/VERSION) |
| 范围 | workshops.dart、workshop_session.dart、view_models.dart、pages.dart，对应 Repository / ViewModel / Widget 测试及 create_reservation_http_test.dart |
| 技术选型 | 延续 MVVM、Dio、Riverpod 与 go_router，数据层 WorkshopSession 协调会话快照与在途创建 |
| 自动门禁 | Dart 格式检查通过，flutter analyze 无问题，flutter test 32 passed，Flutter 工作流校验通过，git diff --check 通过 |
| 设备证据 | NOH-AN00 Android 12 / API 31 与 iPhone 18 Pro iOS 27.2，真实 HTTP 预约集成用例各 1 passed |
| 其他记录 | 首批测试在实现前执行并失败。使用独立临时 SQLite 演练数据库验证创建，日常模拟服务地址为 8765。 |
| 待验 | 提交期间的 Android 系统返回、iOS 交互式返回手势、切后台恢复的设备操作，以及最低系统版本。已用可控 fake 验证提交中离页、共享在途请求与结果恢复，待验设备操作由后续设备验收补齐。 |

## 验收结果

| AC | 已验证 |
|---|---|
| B1 | Widget 验证提交中、成功 Toast、详情余位变化、返回发现已预约与余位同屏。两端真实服务预约成功，201 响应与对应行同步通过。 |
| B2 | ViewModel 和共享会话测试验证快速重复提交只发一笔 POST，ALREADY_BOOKED 后重新 GET。两端真实服务再次创建返回 409 / ALREADY_BOOKED，余位没有再次扣减。 |
| B3 | 满额详情禁止创建的单测与两端页面禁用验证通过。FULL 冲突与读回状态采用可控 fake 覆盖。 |
| B4 | 提交中离页后重进、同活动共享 Future、未知结果阻止新创建、查询失败与重试、取消的旧响应及旧分页均通过。第 03 卡接入后联验 P3 仅一条预约。 |
| B5 | 本地 HttpServer 验证 POST 404 分类，Widget 验证活动不存在及操作区收起。 |
| B6 | 本地 HttpServer 验证 POST 400 分类，Widget 验证参数错误 Toast、按钮恢复与离页清理。 |

第 01 卡原有分页、失败恢复、详情路由和滚动位置测试包含在 32 项回归中。

## 审查发现与闭环

| 级别 | 发现 | 处理 |
|---|---|---|
| P1 | 缓存详情仍有 GET 在途时，提交取消旧 token 后，旧读取失败可能覆盖新预约结果 | 提交前使旧 token 身份失效，增加缓存 GET 取消后 POST 成功的回归，已通过 |
| P2 | 取消的旧读取可能在 ViewModel 拒绝结果前先发布共享快照 | 在共享层 await 返回后、发布前检查 CancelToken 与所有者生命周期，增加旧页取消和旧详情迟到回归，已通过 |

独立审查未发现剩余阻塞问题。最终截图核对时，Toast 定位改为在本帧操作区布局完成后计算，并增加 Toast 位于操作区上方的几何断言，已通过。

## 视觉与截图

保留第 01 卡字体、暖白主题、信息分隔和底栏。P2 新增底部预约按钮、已预约状态与禁用的查看入口。Toast 为 2 秒轻提示，位于操作区上方。P1 原位展示已预约与最新余位。以下为实际设备截图。

- Android。[预约前](evidence-card2/P2-android-before.png) · [预约成功](evidence-card2/P2-android-success.png) · [发现同步](evidence-card2/P1-android-booked.png)
- iOS。[预约前](evidence-card2/P2-ios-before.png) · [预约成功](evidence-card2/P2-ios-success.png) · [发现同步](evidence-card2/P1-ios-booked.png)

最终 Android 演练为 w01 余 3 → 2 席，iOS 演练为 w03 余 5 → 4 席，分别完成真实创建和重复预约冲突校验。

## 命令

日常 Android USB 调试使用本地服务 8765。

```bash
cd /Users/laopi/Desktop/Project/ai_work_flow_demo2
adb -s PQY0220A09036794 reverse tcp:8765 tcp:8765
flutter run -d PQY0220A09036794 --dart-define=API_BASE_URL=http://127.0.0.1:8765/api/v1
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
bash AI-Native/flutter/scripts/validate-skills.sh
```

真实创建用例要求 TEST_WORKSHOP_ID 对应活动起初没有预约。用独立端口与全新数据库启动资料包的模拟服务，再将地址传给用例。

```bash
python3 /Users/laopi/Desktop/Test/周末工坊预约/mock/server.py --port 8879 --db /tmp/workshop-fresh-run.sqlite3
```

```bash
adb -s PQY0220A09036794 reverse tcp:8879 tcp:8879
flutter test integration_test/create_reservation_http_test.dart -d PQY0220A09036794 --dart-define=API_BASE_URL=http://127.0.0.1:8879/api/v1
flutter test integration_test/create_reservation_http_test.dart -d 01697C7D-44DC-4D3B-8D74-EB33E7980778 --dart-define=API_BASE_URL=http://127.0.0.1:8879/api/v1 --dart-define=TEST_WORKSHOP_ID=w03
```

## 结论

- 审查档位：L2
- P0：0
- P1：0
- P2：0
- 结论：通过
