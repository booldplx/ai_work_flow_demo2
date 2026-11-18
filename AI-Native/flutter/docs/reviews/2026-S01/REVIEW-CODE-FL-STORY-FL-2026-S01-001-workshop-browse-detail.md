# REVIEW-CODE-FL-STORY-FL-2026-S01-001-workshop-browse-detail

| 字段 | 值 |
|---|---|
| 审查对象 | [STORY-FL-2026-S01-001](../../requirements/2026-S01/STORY-FL-2026-S01-001-workshop-browse-detail.md)，A1–A4 |
| 审查阶段 / 档位 | FL / L2 |
| 审查范围 | 第 01 卡新增业务模型、Service、Repository、ViewModel、页面、路由、字体资产与测试，以及本次 pubspec、Android debug HTTP 和 iOS CocoaPods / Debug 模拟器配置 |
| 上游工件 | [DD](../../design/2026-S01/DD-FL-2026-S01-001-workshop-browse-detail.md) · [OpenAPI](../../handoff/openapi/workshops.yaml) · [VERSION](../../handoff/VERSION) |
| 技术选型 | MVVM、Dio 5.11.1、flutter_riverpod 3.3.2、go_router 17.5.0，构造注入 Repository，ChangeNotifier ViewModel 经 Riverpod 提供 |
| 自动门禁 | 格式检查 8 个 Dart 文件 0 变更，flutter analyze 无问题，flutter test 13 passed，Flutter 工作流校验通过，git diff --check 通过 |
| 审查人 | 独立只读审查 agent review_workshop，实现者记录结论 |
| 平台证据 | iPhone 18 Pro（iOS 27.2）与 NOH-AN00（Android 12 / API 31）。两端 Debug 真实 HTTP 设备集成测试各通过 1 项。Android 通过 USB 端口转发访问 127.0.0.1:8765。 |
| UI 对照 | [P1 截图](evidence/P1-ios.png) · [P2 截图](evidence/P2-ios.png)。对照 v1.0.0 原稿的衬线标题、月日、信息分隔、强调色与底栏。P2 截图为第二页 w05。短列表增加加载更多，首卡隐藏预约按钮并禁用我的预约，依据已确认 DD。 |
| 未验证 | Android 系统返回键和截图、iOS 交互式返回手势、最低系统版本的设备运行待验。两端集成用例使用页面返回按钮，Widget 验证 push/pop。 |

## TDD 与 AC 证据

先新增分页、失败恢复和详情跳转测试并执行，首次因目标业务类尚未实现而编译失败。完成实现后全量 13 个单元与 Widget 测试通过，追加真实 HTTP 集成测试也通过。网络错误使用可控 Completer fake，Repository HTTP 用例采用测试独立端口的本地 HttpServer。

| AC | 测试与结果 |
|---|---|
| A1 | 分页请求去重、末页停止、短列表加载更多、空数组通过。真实 HTTP 在 iOS 模拟器和 Android 真机验证首批 w01–w03 与第二页加载。 |
| A2 | Widget 验证 w05 路径、详情独立读取、底栏隐藏、返回保留滚动偏移及已加载页，刷新替换第一页通过。iOS 模拟器和 Android 真机以真实 HTTP 验证第二页进入木匙打磨、内容与返回偏移、刷新通过。 |
| A3 | 首载／追加／刷新失败保留内容与重试，重试原页，刷新成功或失败后均丢弃旧追加响应通过。Widget 验证空态与错误恢复通过。 |
| A4 | 不存在详情返回入口、网络失败重试同一 ID、加载中返回及迟到结果、大字号和 320 宽布局通过。iOS 模拟器和 Android 真机的真实 HTTP 404 与回发现通过。 |

## 审查问题与处理

- 详情信息行原使用未拉满宽度的 Wrap。已改为全宽标签与值右对齐，大字号纵排。
- 滚动追加已加入向页尾滚动方向判断，避免下拉动作触发追加。
- Regular 字体下载曾中断，已恢复完成并核对 OTF 表边界，重新构建和截取最终截图。

上述代码问题已修复并重跑自动测试，独立审查结论通过。P1/P2 最终截图由实现者对照登记。

## 本机复现命令

模拟服务已在本机 8765 运行，以下命令可在独立终端启动服务。

```bash
cd /Users/laopi/Desktop/Test/周末工坊预约
python3 mock/server.py
```

本次目标模拟器为 iPhone 18 Pro，UDID 为 01697C7D-44DC-4D3B-8D74-EB33E7980778。已启动时可直接运行应用。

```bash
open -a Simulator
xcrun simctl boot 01697C7D-44DC-4D3B-8D74-EB33E7980778
cd /Users/laopi/Desktop/Project/ai_work_flow_demo2
flutter run -d 01697C7D-44DC-4D3B-8D74-EB33E7980778 --dart-define=API_BASE_URL=http://127.0.0.1:8765/api/v1
```

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
bash AI-Native/flutter/scripts/validate-skills.sh
flutter test integration_test/workshop_http_test.dart -d 01697C7D-44DC-4D3B-8D74-EB33E7980778 --dart-define=API_BASE_URL=http://127.0.0.1:8765/api/v1
```

Xcode 27 模拟器 SDK 要求 iOS 15 起的部署目标，本次在 Debug 的模拟器条件配置及 Pods 中设置为 15.0。Android debug manifest 开放本地 HTTP。Noto Serif CJK SC Regular / Bold 与 OFL 许可随应用打包，字体约 48 MB，包体优化留待实际预算确定。

## 结论

- 审查档位：L2
- P0：0
- P1：0
- P2：0
- 结论：通过
