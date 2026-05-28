# Ren'Py -> Godot 迁移记录（阶段 2）

当前 Godot 工程：`C:/baidunetdiskdownload/维多利亚`

## 已保住的核心系统（你点名的部分）

1. **超长 victoria_prompt（角色设定主干）**
   - 背景故事（疗养院经历）
   - 核心秘密（仿生人）
   - 性格四层（体贴、细腻、自然、占有欲）
   - 情感博弈法则（拒绝百依百顺、镜像回应）
   - 文件：`res://scripts/ai/victoria_prompt_builder.gd`

2. **三层记忆模型（memory_facts / mid_memory_entries / 长期向量层）**
   - 事实层：偏好抽取、覆盖更新
   - 中期层：日内摘要、窗口保留、过期归档
   - 长期层：长期记录池（保留 Pinecone 层接口语义）
   - 文件：`res://scripts/ai/victoria_memory.gd`

3. **好感度更新系统**
   - 阶段态度：`v_love_stage_attitude`
   - 解析器：`extract_love_change`（兼容全角/半角）
   - 文件：
     - `res://scripts/core/victoria_state.gd`
     - `res://scripts/ai/victoria_reply_parser.gd`

4. **时间推进（shift_time_logic）**
   - 白天推进与夜晚跨天逻辑
   - 夜晚触发记忆整理再进入新一天
   - 文件：`res://scripts/core/victoria_state.gd`

5. **房间切换沉浸感**
   - 脚步声：`assets/audio/footstep.ogg`
   - 黑场转场动画（fade）
   - 文本换房指令 + 按钮换房
   - 文件：`res://node_2d.gd`

6. **好感度条视觉反馈**
   - 右侧纵向条 + 数值/百分比
   - 正负变化时颜色闪动反馈
   - 文件：`res://node_2d.gd`

7. **打字机对话效果**
   - `TYPEWRITER_CPS = 32`
   - 逐字显示 + “继续”键可瞬间补全
   - 文件：`res://node_2d.gd`

8. **表情线索解析（P 标记）**
   - 支持从回复中提取 `[P:信号]` 并映射立绘（日常/害羞/肢体害羞/担忧/激动/撒娇生气）
   - 文件：`res://scripts/ai/victoria_reply_parser.gd`

9. **60 阶段触发 + 100 真相结局**
   - 好感 >= 60 时一次性阶段台词
   - 好感 >= 100 时进入“真相结局”并锁定本周目
   - 文件：`res://node_2d.gd`

10. **运行时存档恢复（Godot 本地）**
   - 自动写入 `user://victoria_runtime_save.json`
   - 启动时自动恢复周目状态（时间、好感、三层记忆、房间、对话进度）
   - 文件：`res://node_2d.gd` + `res://scripts/core/victoria_state.gd`

## 本次新增/重写文件

- `res://node_2d.gd`
- `res://scripts/core/victoria_state.gd`
- `res://scripts/ai/victoria_prompt_builder.gd`
- `res://scripts/ai/victoria_memory.gd`
- `res://scripts/ai/victoria_reply_parser.gd`
- `res://data/prologue_story.json`

## 已同步资源

- 背景：`assets/backgrounds/*`
- 立绘：`assets/characters/*`
- 音效：`assets/audio/footstep.ogg`

## 说明

- 当前仍支持“离线回退回复”（未配置 `DEEPSEEK_API_KEY` 时）。
- 若配置了 `DEEPSEEK_API_KEY`，会走真实在线对话。
- Pinecone 现阶段保留为“长期向量层架构与字段语义”，下一阶段可接入真实向量检索与 upsert API。
