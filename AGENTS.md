# ai_work_flow_demo2 开发入口

本项目交付 Android 和 iOS 应用。Flutter 开发从 [Flutter 工作流入口](AI-Native/flutter/AGENTS.md) 进入。先读取[项目画像](AI-Native/flutter/architecture/system-landscape.md)，按[使用手册](AI-Native/flutter/USAGE.md)选择需求拆卡、页面详设或功能编码。

工作流文档和迭代工件以 `AI-Native/flutter/` 为根。应用根为当前目录，入口在 [lib/main.dart](lib/main.dart)。验收时在项目根运行 `bash AI-Native/flutter/scripts/validate-skills.sh`、`flutter analyze` 和 `flutter test`。功能代码按[审查规则](AI-Native/flutter/rules/code-review.md)送审。
