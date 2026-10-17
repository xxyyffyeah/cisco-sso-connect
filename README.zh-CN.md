# SSH Launch

**macOS 上的一键 Cisco VPN／SSO 自动连接工具；VS Code 和 Terminal 是可选的后续操作。**

核心流程：打开 Cisco Secure Client → 连接指定 VPN → 处理支持的 SSO 页面 → 等待 VPN 连通。不是必须连远程开发环境才能使用。

## 三个独立选项

- **Connect Cisco VPN / SSO**：默认开启，负责 VPN／SSO 主流程。
- **Open VS Code**：默认关闭，需要时恢复／打开 Remote SSH 项目。
- **Open local Terminal**：默认关闭，需要时打开对应服务器和目录。

可以只连接 VPN，也可以连接后只打开其中一个应用，或两个都打开。关闭 Cisco 选项后仍可单独使用 SSH 功能。程序记住选择；仅连接 VPN 不要求安装 VS Code 或配置 SSH。

## SSO 自动化范围

在能够识别的 Cisco 内嵌登录页上，程序只向用户配置的可信 HTTPS 登录来源填充明确识别的用户名和密码框。SSO 密码在原生安全窗口中设置，只保存到 macOS Keychain。

Connect、Next、密码提交及已批准通知的 Accept，每轮最多各尝试一次。MFA／Duo、陌生通知、外部浏览器登录及不能识别的页面仍由本人处理；不会无限重试，也不会绕过双因素认证。详见 [Cisco／SSO 配置](docs/CISCO_SSO.md)。

## 交给 Claude Code／Codex 安装

复制下面这段：

> 请安装 https://github.com/xxyyffyeah/ssh-launch 。先阅读 AGENTS.md、docs/INSTALL.md 和 docs/AGENT_INSTALL_PROMPT.md，检查脚本，再构建、运行离线测试并安装到 ~/Applications。重点配置 Cisco VPN／SSO：先在本机发现客户端和 VPN 地址，不明确时询问我。VS Code 和 Terminal 默认都不开启，只有我选择使用时才读取 SSH 服务器和远程目录历史。不要读取私钥、导出 Keychain、上传本机配置，或让我在聊天中提供密码。密码由我在应用的安全设置窗口中输入；辅助功能授权、主机指纹与 MFA 由我批准。不要断开已有 VPN／SSH 会话，并明确报告未验证的部分。

## 手动安装

```sh
git clone https://github.com/xxyyffyeah/ssh-launch.git
cd ssh-launch
bash scripts/test.sh
bash scripts/install.sh
open "$HOME/Applications/SSH Launch.app"
```

要求 macOS 13+、Apple Command Line Tools、测试用 Python 3。VPN 模式需要组织提供的 Cisco Secure Client；只有选用 VS Code 时才需要 VS Code 和 Remote - SSH 扩展。

首次使用在「系统设置 → 隐私与安全性 → 辅助功能」启用 SSH Launch，然后填写 VPN 地址。SSO Settings 可设置登录来源、用户名、Keychain 密码和允许自动接受的完整通知文字。默认不自动接受任何通知。

0.2.0 是源码版本；不内置私人账号、学校端点、密码或项目路径，也不承诺兼容所有 SSO 页面。原有本机专用启动器不受影响。[英文文档](README.md) · [安全说明](SECURITY.md)
