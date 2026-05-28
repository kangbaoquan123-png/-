# 维多利亚（Victoria）

> Godot 4 驱动的 AI 视觉小说 —— 与拥有记忆和情感的维多利亚，共度每一天。

## 简介

《维多利亚》是一款基于 Godot 4 引擎的 AI 视觉小说。你将在游戏中与一位名叫"维多利亚"的 AI 少女相遇，通过自然语言对话与她互动。她拥有三层记忆系统、动态好感度、情感表达和时间感知能力——每一次对话都是独特的体验。

### 核心特性

- **AI 实时对话**：支持 DeepSeek、OpenAI、SiliconFlow、OpenRouter、Gemini 等多种 LLM 后端
- **三层记忆系统**：事实记忆层（偏好抽取）→ 中期记忆层（日内摘要）→ 长期向量层（可扩展 Pinecone）
- **动态好感度系统**：60 阶段触发 + 100 真相结局，好感变化实时影响角色态度
- **表情线索解析**：AI 回复中的 `[P:信号]` 标记自动映射角色立绘（日常/害羞/担忧/激动等）
- **时间推进系统**：早晨→下午→夜晚完整日循环，夜间触发记忆整理
- **沉浸式场景**：多房间切换 + 黑场转场 + 脚步声，1080p 高清背景
- **打字机对话效果**：逐字显示，可瞬间补全
- **运行时存档恢复**：自动保存/恢复游戏状态

## 截图

### 游戏场景

| 客厅（早晨） | 维多利亚的房间（早晨） | 厨房（早晨） |
|:---:|:---:|:---:|
| ![客厅](assets/backgrounds/living_room_morning.png) | ![房间](assets/backgrounds/sister_room_morning.png) | ![厨房](assets/backgrounds/kitchen_morning.jpg) |

<details>
<summary>更多场景（点击展开）</summary>

| 客厅（午后） | 客厅（夜晚） | 维多利亚的房间（午后） |
|:---:|:---:|:---:|
| ![客厅午后](assets/backgrounds/living_room_afternoon.png) | ![客厅夜晚](assets/backgrounds/living_room_night.png) | ![房间午后](assets/backgrounds/sister_room_afternoon.png) |

</details>

### 角色立绘

| 日常 | 害羞 | 担忧 | 生气 |
|:---:|:---:|:---:|:---:|
| ![日常](assets/characters/everyday.png) | ![害羞](assets/characters/shy.png) | ![担忧](assets/characters/worry.png) | ![生气](assets/characters/dislike.png) |

| 维多利亚（默认） | 害羞2 | 嫌弃 |
|:---:|:---:|:---:|
| ![默认](assets/characters/victoria_default.png) | ![害羞2](assets/characters/shy2.png) | ![嫌弃](assets/characters/cross.png) |

## 快速开始

### 环境要求

- [Godot 4.6+](https://godotengine.org/)
- Godot LLM GDExtension（已包含在 `addons/godot_llm/`）
- 至少一个 LLM API Key（DeepSeek 推荐）

### 导入项目

1. 克隆仓库
2. 用 Godot 4.6+ 打开 `project.godot`
3. 运行项目

### 配置 AI

在游戏主菜单中填写你的 API 配置：
- **API 提供商**：DeepSeek / OpenAI / SiliconFlow / OpenRouter / Gemini
- **API Key**：你的 API 密钥
- **模型名称**：如 `deepseek-chat`、`gpt-4o`

所有配置保存在本地，不会上传到任何服务器。

## 构建发布

### Windows

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build_windows_release.ps1
```

输出：`build/windows/Victoria.exe`

### Android

```powershell
# 首次配置 Android SDK
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\setup_android_export.ps1

# 构建 APK
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build_windows_release.ps1 -Target Android
```

输出：`build/android/Victoria.apk`

## 项目结构

```
├── addons/godot_llm/     # Godot LLM GDExtension（本地 AI 推理）
├── assets/               # 美术 & 音频资源
│   ├── audio/            # 背景音乐 & 音效
│   ├── backgrounds/      # 场景背景（客厅/厨房/卧室等）
│   ├── characters/       # 角色立绘
│   ├── fonts/            # 字体
│   └── gui/              # UI 组件
├── data/                 # 剧情数据（JSON）
├── models/               # 本地嵌入模型（bge-small-zh）
├── scripts/
│   ├── ai/               # AI 对话 & 记忆系统
│   ├── config/           # 场景配置
│   ├── core/             # 核心状态管理
│   ├── game/             # 游戏主逻辑 & UI
│   └── tools/            # 开发调试工具
└── tools/                # 构建脚本
```

## 技术架构

| 系统 | 说明 |
|------|------|
| 对话引擎 | 多 LLM 后端支持，运行时切换 |
| 记忆系统 | 事实层 + 中期层 + 长期向量层（可接 Pinecone） |
| 好感度 | 数值化好感 + 阶段态度 + 正负变化视觉反馈 |
| 表情系统 | AI 输出 `[P:信号]` → 自动映射立绘切换 |
| 状态持久化 | `user://victoria_runtime_save.json` 自动存档 |
| 嵌入模型 | bge-small-zh-v1.5（本地 GGUF，无需联网） |

## 许可证

MIT License - 详见 [LICENSE](./LICENSE)
