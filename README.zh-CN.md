# SSH Launch

macOS 原生 SSH 启动器：选择服务器和远程目录，同时打开 VS Code Remote SSH 与本地 Terminal。

不内置个人账号、学校服务器、VPN 地址或密码。服务器来自 SSH 配置，目录建议来自 VS Code 本机历史；密码仅在用户选择保存时进入 macOS Keychain。

## 交给 Claude Code / Codex 安装

复制下面这段：

> 请在我的 Mac 上安装 https://github.com/xxyyffyeah/ssh-launch 。克隆到一个新目录，先阅读 AGENTS.md、docs/INSTALL.md 和 docs/AGENT_INSTALL_PROMPT.md，检查安装脚本，再构建、运行离线测试并安装到 ~/Applications。只在本机发现已有 SSH 服务器和 VS Code 远程目录，不读取私钥、不导出 Keychain、不上传本机配置或日志。服务器不明确时询问我。保留现有 SSH 配置、VS Code 设置和正在运行的连接。需要修改连接共享配置前说明范围并取得同意，先备份。凭据由我在安全窗口输入；辅助功能授权、主机指纹确认和 MFA 由我完成。最后检查安装结果，并明确说明尚未验证的部分。

## 手动安装

```sh
git clone https://github.com/xxyyffyeah/ssh-launch.git
cd ssh-launch
bash scripts/test.sh
bash scripts/install.sh
open "$HOME/Applications/SSH Launch.app"
```

要求 macOS 13+、Apple Command Line Tools、VS Code 和 Remote - SSH 扩展。测试需要 Python 3，应用运行不需要。

首次使用需在「系统设置 → 隐私与安全性 → 辅助功能」启用 SSH Launch。安装本身不会修改 SSH 配置；第一次连接发现未配置连接共享时，应用会先询问并备份。

这是 0.1.0 源码版本：支持 OpenSSH 与 VS Code Remote SSH 兼容的服务器和 POSIX 远程 shell；VPN 通过用户配置的本地前置脚本接入，并不是所有 VPN 的免配置自动登录工具。系统权限和 MFA 不能无人值守批准。

详细信息见 [英文说明](README.md)、[安装文档](docs/INSTALL.md)、[安全说明](SECURITY.md)。
