# 建立 iMacSwitch 独立应用与发布链路

## 目标

把已经验证的双 Mac 自动外设切换能力迁移为独立、精简的 `iMacSwitch` macOS 菜单栏应用，并建立可重复的签名、打包和 GitHub Release 流程。

## 范围

- 包含：蓝牙外设管理、AWDL 点对点发现、安全配对、屏幕边缘驻留切换、必要设置和菜单栏状态。
- 包含：针对 `ifuryst/iMacSwitch` 的更新检测、CI 构建、Developer ID 签名、notarization、`.app.zip` 与 `.dmg` 产物。
- 不包含：旧仓库截图、旧发布历史、旧仓库品牌和与自动切换无关的开发遗留。

## 背景

- 相关文档：`docs/ARCHITECTURE.md`、`docs/CICD.md`、`docs/SECURITY.md`。
- 相关代码路径：`iMacSwitch/`、`iMacSwitch.xcodeproj/`、`.github/workflows/`。
- 已知约束：两台 Mac 不保证处于同一局域网；通信必须支持 AWDL。不得把证书、私钥或密码提交到 Git。

## 风险

- 风险：Bluetooth 私有 remove 行为和 macOS 断开回调存在时序差异。
- 缓解方式：等待真实 IOBluetooth 状态最多 10 秒，并在失败时停止批量移交和回滚。
- 风险：签名或 notarization 凭据配置错误会生成无法顺利安装的产物。
- 缓解方式：本地验证签名，CI 中显式校验证书、notary 结果和 stapling。

## 里程碑

1. 从已验证实现迁移最小可运行工程并完成品牌隔离。
2. 补齐真实项目文档、测试入口和更新检测。
3. 建立 GitHub 仓库、签名发布流水线并验证远端执行。

## 验证方式

- 命令：`make ci`。
- 手工检查：两台 Mac 配对、AWDL 发现、边缘驻留后选中外设按顺序移交。
- 观测检查：应用日志包含 AWDL scoped 地址、edge trigger、release/disconnect/connect 结果。

## 进度记录

- [x] 确认源仓库已验证状态并完成本地提交。
- [x] 完成精简迁移和品牌隔离。
- [x] 完成本地构建与产物验证。
- [ ] 创建 GitHub 仓库并推送。
- [ ] 配置 Apple 标识、签名 secrets 和发布流水线。

## 决策记录

- 2026-10-08：新仓库保留安全配对和 AWDL 传输，因为它们是跨网络自动切换的必要核心，不继承旧仓库的展示素材与发布历史。
- 2026-10-08：发布流程采用 tag 驱动，`vX.Y.Z` 标签生成签名并 notarize 的 `.app.zip` 和 `.dmg`，避免引入独立的 Node 发布工具链。
