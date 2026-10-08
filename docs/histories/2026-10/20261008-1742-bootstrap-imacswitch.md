## [2026-10-08 17:42] | Task: 建立独立 iMacSwitch 应用

### 🤖 Execution Context

- **Agent ID**: `TRAE`
- **Base Model**: `GPT-5`
- **Runtime**: `Trae CLI on macOS`

### 📥 User Query

> 把已经验证的双 Mac 自动外设切换核心迁移为独立、精简的 iMacSwitch，并建立 GitHub 更新检测与自动签名发布链路。

### 🛠 Changes Overview

**Scope:** macOS 应用、AWDL/Bluetooth 移交、边缘触发、GitHub Actions 与项目文档。

**Key Actions:**

- **精简迁移**: 迁入蓝牙外设管理、安全配对、AWDL 点对点发现和屏幕边缘驻留自动移交，隔离旧产品的协议、Keychain 与 Bonjour 命名空间。
- **可靠移交**: 保留真实蓝牙断开状态等待、选中外设串行处理、失败中止与回滚，降低设备遗留在错误主机上的概率。
- **独立发布**: 将 Bundle ID、产品名、更新检测与发布链接切换到 iMacSwitch，增加 Universal 构建、`.app.zip` / `.dmg` 打包和 tag 驱动的 Developer ID 签名及 notarization 流程。
- **仓库收敛**: 补齐架构、安全、可靠性、CI/CD、产品与贡献文档，使仓库只保留应用运行和维护需要的内容。

### 🧠 Design Intent (Why)

两台 Mac 不一定共享局域网，因此设备发现和命令传输必须保留 AWDL peer-to-peer 能力。新仓库采用独立协议与凭据命名空间，避免旧应用状态相互污染；发布采用少依赖的 tag 流程，让每个正式版本都能生成可验证、可安装的签名制品。

### 📁 Files Modified

- `iMacSwitch/`
- `iMacSwitch.xcodeproj/`
- `.github/workflows/ci.yml`
- `.github/workflows/release.yml`
- `scripts/build.sh`
- `scripts/package.sh`
- `README.md`
- `docs/ARCHITECTURE.md`
- `docs/CICD.md`
- `docs/SECURITY.md`
- `docs/RELIABILITY.md`
