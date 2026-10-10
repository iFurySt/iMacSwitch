# 可导出诊断日志与交接可靠性排查

## 目标

为两台 Mac 上偶发的“交接后两边都未连接”和“睡眠/锁屏后外设丢失”提供可关联、可持久化、可直接从 Settings → Other 导出的诊断证据，同时保证日志有界、默认开启且不包含配对密钥或原始设备地址。

## 范围

- 包含：滚动 JSONL 日志、稳定脱敏标识、会话与操作关联标识、交接/蓝牙/网络/睡眠唤醒/自动重连/更新检查埋点、Other 中导出入口、GitHub Release 检查限流回退。
- 不包含：上传遥测、后台发送日志、修改配对协议、引入 Sparkle、未经日志证据确认的大范围交接状态机重写。

## 背景

- 相关文档：`docs/ARCHITECTURE.md`、`docs/RELIABILITY.md`、`docs/SECURITY.md`。
- 相关代码路径：`iMacSwitch/Manager/`、`iMacSwitch/Model/Store/BluetoothPeripheralStore.swift`、`iMacSwitch/AppDelegate/AppDelegate.swift`、`iMacSwitch/View/Settings/OtherSettingsView.swift`。
- 已知约束：两台 Mac 不共享普通局域网，通信依赖 Bonjour/AWDL；应用沙盒开启；不能在日志中写入 PSK、配对码、原始 MAC 地址或原始网络地址。

## 风险

- 风险：高频重连探测产生过多日志或 I/O。
- 缓解方式：只记录状态变化和关键探测结论，日志按文件大小轮转并限制保留数量。
- 风险：导出内容泄漏设备标识或认证材料。
- 缓解方式：设备和 peer 使用稳定 SHA-256 短标识；日志 API 只接受显式结构化字段，不记录密钥和协议载荷。
- 风险：睡眠前异步日志尚未落盘。
- 缓解方式：关键 power 事件使用同步写入/flush，导出前同步刷新日志队列。

## 里程碑

1. 确认更新机制、交接失败分支和睡眠释放路径。
2. 实现有界持久日志和导出，再覆盖关键状态转换。
3. 更新文档，完成构建、导出与发布验证。

## 验证方式

- 命令：`make check`、`make ci`。
- 手工检查：启动 Debug/Release App，Settings → Other 导出单个诊断文件，确认按时间排序且可读。
- 观测检查：确认日志包含 app launch、更新检查、peer discovery、handoff、sleep/wake、reconnect 和 export snapshot；确认不出现原始 MAC、host、PSK 或配对码。

## 进度记录

- [x] 确认当前更新器为 GitHub Releases 自有检查器而非 Sparkle；登录态 API 和 `/releases/latest` 均指向 `v1.0.0`。
- [x] 梳理单设备/批量/全量交接、失败回滚、睡眠释放和自动重连路径。
- [x] 完成滚动日志和导出实现。
- [x] 完成关键路径埋点。
- [x] 完成文档、CI、安装包和发布验证。

## 决策记录

- 2026-10-10：采用本地有界 JSONL 文件而不是仅依赖 Unified Logging，因为故障发生后用户需要从两台 Mac 各自导出确定性证据。
- 2026-10-10：本轮不引入 Sparkle；保留轻量 GitHub Releases 提示器，并增加不消耗 API quota 的 release-page 回退。真正的应用内下载/替换需要单独配置 Sparkle appcast 与 EdDSA 发布签名。
- 2026-10-10：不在没有证据时改写睡眠释放策略；先记录 IOKit power event、释放判定和唤醒重连结果，以区分锁屏、系统睡眠和接管失败。
- 2026-10-10：代码审查确认释放操作可能在 10 秒等待超时后迟到完成。清除主动释放抑制并增加 10 秒恢复观察期；全量切换超时对所有设备执行同样恢复。
- 2026-10-10：`make ci` 和远端 CI run `38035465717` 通过；Signed Release run `38035543621` 通过。重新下载的 v1.0.1 App 和 DMG 均通过签名、staple 与 Gatekeeper 检查，latest API 和页面重定向都指向 v1.0.1。
