[English](README.md) | 中文

# PowerShell + Windows Terminal 美化部署包

统一配色:**Catppuccin Mocha**(深色)。目标是让 PowerShell 提示符、Windows Terminal
外观在不同设备上保持一致,后续其他工具(如 Hermes Agent)如支持自定义配色,也建议
对齐同一套色板。

## 给 AI Agent 的执行说明

若由 AI Agent 执行本部署:直接运行

```powershell
pwsh -ExecutionPolicy Bypass -File .\setup.ps1
```

(仅需 PowerShell 侧、不动 Windows Terminal 配色则加 `-SkipWindowsTerminal`)。

执行前不需要向用户确认细节,脚本本身是幂等的、每一步都会打印状态并在覆盖已有文件前
自动备份。运行完提示用户完全关闭并重新打开 Windows Terminal 即可。若脚本输出中出现
`WARN`,把该行原文贴给用户,不要自行静默忽略或猜测处理方式(常见的 WARN 场景见下面
"脚本做了什么"一节)。

## 这套配置包含什么

| 组件 | 作用 |
| --- | --- |
| [oh-my-posh](https://ohmyposh.dev/) | PowerShell 提示符引擎,加载 Catppuccin Mocha 主题 |
| [Maple Mono NF CN](https://github.com/subframe7536/maple-font) | 提示符图标 + 中文字形的等宽字体(见下面"字体与中文显示"),没有管理员权限时会回退成纯拉丁字符的 CaskaydiaCove Nerd Font |
| PSReadLine | 命令行语法高亮 + 历史预测(内置模块,只做配置) |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | `z <目录名>` 智能跳转,记住常用路径 |
| [eza](https://github.com/eza-community/eza) | 带图标的 `ls` 替代品,接管 `ls`/`ll`/`la`/`lt` |
| [fzf](https://github.com/junegunn/fzf) + PSFzf | 模糊搜索:`Ctrl+T` 找文件、`Ctrl+R` 搜历史、`Alt+C` 切目录 |
| Windows Terminal 配色 | 新增 "Catppuccin Mocha" 配色方案并设为默认,深色 + 82% 毛玻璃透明度 |

## 前置条件

- Windows 10 1809+ / Windows 11
- 已安装 `winget`(自带 App Installer;如果没有,先去 Microsoft Store 装 "App Installer")
- 已安装 Windows Terminal(Microsoft Store 版或 winget 版均可)
- 网络能访问 `cdn.ohmyposh.dev`(下载主题)、`github.com`(下载中文 Nerd Font)以及 `winget` 配置的软件源
- 想要中文正常显示,需要用**管理员身份**打开 PowerShell 窗口再运行脚本(原因见下面
  "字体与中文显示")。不用管理员也能跑,只是字体会回退成纯拉丁字符版本。

## 一键部署

1. 把整个 `terminal-setup` 文件夹拷贝到目标设备(U盘 / OneDrive / git 仓库均可)。
2. 打开任意一个 PowerShell 窗口(5.1 或 7 都行),`cd` 到该文件夹,执行:

   ```powershell
   pwsh -ExecutionPolicy Bypass -File .\setup.ps1
   ```

   如果当前机器还没装 PowerShell 7,脚本会先用 `winget` 装好 pwsh,然后提示你
   用上面同一条命令重新执行一次(profile 路径和 PSReadLine 特性是 pwsh 7+ 专属的,
   不能在 Windows PowerShell 5.1 里配置)。

3. 脚本跑完后,**完全关闭并重新打开 Windows Terminal**(已打开的窗口不会自动刷新
   配色和字体)。

### 只想要 PowerShell 那一半,不想动 Windows Terminal 配色?

```powershell
pwsh -ExecutionPolicy Bypass -File .\setup.ps1 -SkipWindowsTerminal
```

## 远程服务器(Linux / bash)

对于 SSH 上去的 Debian/Ubuntu 服务器 —— 那边没有 Windows Terminal 配色可改,
但你连接用的*客户端*终端仍然需要 Nerd Font,这部分由本地的 `setup.ps1` 负责:

```bash
curl -fsSL https://raw.githubusercontent.com/TecFancy/posh-mocha/master/setup-linux.sh | bash
```

如果服务器连不上 `raw.githubusercontent.com`,改成先把文件传过去
(例如 `scp setup-linux.sh myserver:/tmp/`)再执行 `bash setup-linux.sh`。

这个脚本通过 `apt` 安装 oh-my-posh(同一套 Catppuccin Mocha 主题,从
`cdn.ohmyposh.dev` 而非 GitHub 下载)、zoxide、eza、fzf,并把它们接入
`~/.bashrc` 里一个带标记的配置块。幂等 —— 修改前会备份 `~/.bashrc`,
重复执行时会替换(而不是重复追加)自己那一块。具体细节见
`setup-linux.sh` 开头的注释,步骤顺序和 `setup.ps1` 保持一致。

## 脚本做了什么(幂等,可重复执行)

1. 检查 `winget` 是否存在,没有则报错退出。
2. 检查/安装 PowerShell 7(pwsh)。
3. 通过 `winget` 安装 oh-my-posh、zoxide、fzf、eza(已安装则跳过)。
4. 装字体(已装则跳过):
   - **管理员权限**:从 GitHub 下载 `Maple Mono NF CN`,系统级安装到
     `C:\Windows\Fonts` + 注册到 `HKLM`,重启字体缓存服务并广播字体变更
     通知,让当前会话里的所有程序(包括 Windows Terminal 这类打包应用)
     立即能识别到。
   - **非管理员**:回退用 `oh-my-posh font install CascadiaCode` 装纯拉丁
     字符的 Nerd Font,并打印 WARN 提示中文会显示不一致。
5. 安装 PSFzf 模块(已装则跳过)。
6. 下载 oh-my-posh 官方 Catppuccin Mocha 主题 json 到 `~\.config\oh-my-posh\`。
7. 把 `Microsoft.PowerShell_profile.ps1` 复制到 `$PROFILE` 指向的路径。
   **如果目标机器已经有 profile 文件,脚本会先备份成
   `xxx.ps1.bak-时间戳`,再覆盖**,不会静默丢失你原有的自定义内容
   (备份后需要你手动把旧内容里想保留的部分合并回新 profile)。
8. 修改 Windows Terminal 的 `settings.json`:
   - 修改前先备份一份 `settings.json.bak-时间戳`。
   - 新增 "Catppuccin Mocha" 配色方案(如果已存在同名方案会先移除旧的再插入新的,
     不会产生重复)。
   - `profiles.defaults` 里设置该配色、字体、`opacity: 82`、`useAcrylic: true`。
   - 如果检测到 "PowerShell"(pwsh,`Windows.Terminal.PowershellCore` 来源)的
     profile,把它设为 `defaultProfile`;如果这台机器上 Windows Terminal 还没
     识别到 pwsh(比如刚装完 pwsh 还没打开过 Windows Terminal),会跳过这一步
     并提示你打开一次 Windows Terminal 后重新执行脚本。
   - `theme` 设为 `dark`(应用整体外观,不跟随系统)。
   - **如果 `settings.json` 里手写过 `//` 注释**(非标准 JSON,但 Windows
     Terminal 能容忍),脚本的 JSON 解析会失败,此时会自动从刚才的备份还原
     文件、不做任何改动,并在终端打印警告。遇到这种情况,建议先手动删掉
     注释行再重新执行,或者干脆手动照着下面"手动步骤"里的配色抄一遍。

## 手动步骤(脚本覆盖不到的部分)

- **Hermes Agent 配色**:目前还没确认它的主题设置入口和是否支持自定义色板,
  所以没有自动化。等确认了配置方式,再对齐下面这套 Catppuccin Mocha 色值。
- **字体在旧版应用里显示异常**:极少数老旧终端程序对 Nerd Font 的图标字形支持
  不好,如果遇到方块乱码,把该程序的字体单独设回 `Cascadia Code`(不带 Nerd
  Font 后缀的原版)即可,不影响其他地方。

## 字体与中文显示

**根因**:CaskaydiaCove 之类的纯 Nerd Font 不含中文字形,终端遇到中文字符时会
自动 fallback 到系统默认中文字体,导致中英文字重、宽度不一致,连带把
oh-my-posh 的分段对齐、竖线都弄歪。`Maple Mono NF CN` 把 Nerd Font 图标和
等宽对齐的中文字形合并进同一个字体家族,从根上解决这个问题。

**装好字体但 Windows Terminal 还是报"找不到字体"**:Windows Terminal 是打包
(MSIX/AppContainer)应用,只能看到系统级("为所有用户安装",装到
`C:\Windows\Fonts` + 注册在 `HKLM`)的字体,看不到仅当前用户级("为我安装",
只在 `HKCU` 注册)的字体 —— 哪怕字体文件确实已经复制到磁盘上、哪怕
`AddFontResourceEx` 已经把它加载进了当前会话。这也是为什么 `setup.ps1`
的字体安装步骤需要管理员权限才会走系统级安装路径;非管理员运行时会自动
回退成仅拉丁字符的 CaskaydiaCove Nerd Font,并打印 WARN 提示。

如果系统级装完之后 Windows Terminal 依然弹"找不到字体": 完全关闭所有
Windows Terminal 窗口重新打开;如果还不行,重启一次"Windows 字体缓存服务"
(`Restart-Service FontCache`,脚本里已经会自动做这一步),或者直接注销
重新登录一次让系统彻底刷新。

**SSH 到 Linux 服务器时中文显示也不对?** 这和 `setup-linux.sh` 无关 ——
字体渲染完全发生在*客户端*(也就是本机的 Windows Terminal),不管你是在本地
PowerShell 还是 SSH 到远程服务器,显示用的都是本机装好的这套字体。把
`setup.ps1` 跑一遍(管理员权限)就同时解决了本地和远程两种场景,
`setup-linux.sh` 不需要做任何改动。

## Catppuccin Mocha 色值参考(用于手动对齐其他工具)

| 用途 | 颜色 | HEX |
| --- | --- | --- |
| 背景 | ⬛ | `#1E1E2E` |
| 前景/正文 | ⬜ | `#CDD6F4` |
| 红(error) | 🟥 | `#F38BA8` |
| 绿(success/string) | 🟩 | `#A6E3A1` |
| 黄(warning) | 🟨 | `#F9E2AF` |
| 蓝(command/info) | 🟦 | `#89B4FA` |
| 紫(keyword/type) | 🟪 | `#CBA6F7` |
| 青(operator) | 🟦 | `#94E2D5` |
| 橙(number) | 🟧 | `#FAB387` |
| 粉(cursor) | 🌸 | `#F5E0DC` |
| 选区背景 | ▪ | `#585B70` |
| 注释/暗前景 | ▪ | `#6C7086` |

完整调色板(全部 26 色)见: <https://catppuccin.com/palette/>
以及 JSON 形式:<https://raw.githubusercontent.com/catppuccin/palette/main/palette.json>

## 回滚

- PowerShell profile:用脚本生成的 `.bak-时间戳` 备份文件覆盖回 `$PROFILE` 即可。
- Windows Terminal:用 `settings.json.bak-时间戳` 覆盖回
  `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`。
- CLI 工具(oh-my-posh/zoxide/eza/fzf):`winget uninstall --id <包 ID>`。
- Nerd Font:`Maple Mono NF CN` 是系统级安装的,直接在"设置 → 字体"里搜索
  "Maple Mono NF CN" 逐个卸载即可(会自动清理 `HKLM` 注册项和
  `C:\Windows\Fonts` 下的文件)。回退场景装的 `CaskaydiaCove` 是当前用户级
  安装,同样在"设置 → 字体"里搜索卸载(oh-my-posh 本身不提供卸载命令)。
- `setup-linux.sh`(远程服务器):用它生成的 `.bak-时间戳` 备份覆盖回
  `~/.bashrc`,再执行 `sudo apt remove zoxide eza fzf` 和
  `rm ~/.local/bin/oh-my-posh`。
