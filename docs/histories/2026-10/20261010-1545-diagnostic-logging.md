## [2026-10-10 15:45] | Task: 增加双机故障诊断和迟到断开恢复

### 🤖 Execution Context

- **Agent ID**: TRAE
- **Base Model**: GPT-5
- **Runtime**: Trae CLI

### 📥 User Query

> 确认 iMacSwitch 的更新来源；针对偶发交接后两台都未连接，以及睡眠或锁屏后设备丢失，增加可从两台 Mac 分别导出的诊断日志。

### 🛠 Changes Overview

**Scope:** update checking, handoff reliability, Bluetooth recovery, lifecycle/network observability, Settings, documentation

**Key Actions:**

- 增加有界滚动 JSONL 日志，记录交接、蓝牙、AWDL/Bonjour、睡眠唤醒、自动重连、生命周期和更新检查结果。
- 在 Settings → Other 增加用户主动导出；同一外设在两台 Mac 上使用相同脱敏哈希，便于对齐时间线。
- 修复释放超过 10 秒后底层操作迟到完成时，断开通知被主动释放标记吞掉、设备可能留在两台 Mac 之外的竞态；全量切换的部分断开也会恢复。
- GitHub Releases API 被匿名限流时，回退到 `/releases/latest` 页面重定向读取版本。
- 明确当前更新器不是 Sparkle，只检测并打开发布页，不自动替换应用。

### 🧠 Design Intent (Why)

偶发跨机蓝牙问题无法仅依赖 Console 重现。持久、相关、脱敏的本地事件能区分发送端释放、接收端配对、网络掉线、睡眠释放和重连判断，同时避免遥测和敏感信息外泄。代码审查确认了一个可直接修复的迟到断开空窗，因此在不改变协议的前提下增加了本机恢复观察期。

### 📁 Files Modified

- `iMacSwitch/Manager/DiagnosticLogger.swift`
- `iMacSwitch/Model/Store/BluetoothPeripheralStore.swift`
- `iMacSwitch/Manager/IncomingConnection.swift`
- `iMacSwitch/Manager/OutgoingConnection.swift`
- `iMacSwitch/Manager/SleepMonitor.swift`
- `iMacSwitch/Manager/UpdateChecker.swift`
- `iMacSwitch/View/Settings/OtherSettingsView.swift`
- `docs/RELIABILITY.md`
- `docs/SECURITY.md`
