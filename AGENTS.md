# PROJECT KNOWLEDGE BASE

**Generated:** 2026-10-28
**Branch:** master

## OVERVIEW

Windows 本地简繁转换桌面工具。C# 5 + WinForms（.NET Framework 4.8 / x64），左栏输入、右栏实时输出，完全离线，不依赖任何外部安装或本地项目。

OpenCC 引擎与词典在**编译期内嵌进 exe**，`dist\` 只有一个可执行文件；首次运行把它释放到用户缓存目录再加载，因此分发不需要任何附带文件。

本仓库以 **Gitee 为唯一真源**：`origin` 只推 Gitee；GitHub 由 `.github/workflows/sync-from-gitee.yml` 定时从 Gitee 镜像（国内网络直推 GitHub 不稳定，故本地不再推 GitHub）。远程地址以 `git remote -v` 为准。

## SENSITIVE DATA POLICY

本文件会提交到公开仓库，编辑时必须遵守：

- 禁止写入密码、API key、token、SSH 私钥、证书、Cookie。
- 禁止写入个人邮箱、手机号、真实姓名、内网地址、私有仓库凭据。
- 禁止写入本机用户名目录或具体绝对路径；用 `%WINDIR%` 等环境变量或 `git remote -v` 之类的命令代替。
- 禁止写入客户 / 公司内部数据。

只记录项目结构、构建命令、语言 / 框架约束与通用坑位。

## STRUCTURE

```
JianFanConv/
├── .github/workflows/        定时把 Gitee 镜像到 GitHub 的工作流
├── src/Program.cs            唯一源码（约 1150 行）
├── vendor/opencc/            内置 OpenCC 引擎+词库+许可（构建期素材；编译时嵌入 exe）
├── build.ps1                 一键构建（清空 dist → 校验并内嵌 vendor 素材 → 编译）
├── release.ps1               一键发版（构建/打包/推 Gitee/建双平台 release，ASCII-only）
├── dist/                     构建产物（已 gitignore；只有 JianFanConverter.exe）
├── .gitignore                忽略 dist/、运行时缓存与发布临时文件
├── LICENSE                   应用代码 MIT 许可
├── AGENTS.md                 维护者 / agent 约定（本文件）
└── README.md                 面向使用者的运行 / 构建 / 修改说明
```

## WHERE TO LOOK

| 任务 | 位置 | 说明 |
|---|---|---|
| 改界面 / 布局 / 交互 | `src/Program.cs` 的 `MainForm` / `BuildUi` | 手写 WinForms，无 designer |
| 改颜色 / 字体 | `Theme` | 唯一配色与字体来源 |
| 改内嵌运行时的释放 / 缓存 | `RuntimeAssets` | 资源名、缓存目录、`RuntimeTag` |
| 改转换逻辑 / 引擎 | `OpenCC` / `OpenCCEngine` | P/Invoke 包装 + 实例缓存 |
| 改方向切换 | `OnDirectionChanged` | `_s2t` 布尔控制方向 |
| 改实时转换 | `StartConversion` | 200 ms 防抖 + 后台线程 + 版本号 |
| 改滚动条 | `AutoScrollTextBox` | 不满一屏隐藏，超出显示 |
| 改构建 / 打包 | `build.ps1` | 只从 `vendor/` 取素材并以 `/resource` 内嵌 |
| 升级 OpenCC | `vendor/opencc/` | 必须同步 LICENSE / NOTICE.txt，并 bump `RuntimeTag` |
| 发版 | 本文「发布流程」 | 构建 → 压缩 → 打 tag → 推 Gitee（GitHub 自动镜像） |

## CODE MAP

| Symbol | Type | Location | Role |
|---|---|---|---|
| `Program.Main` | method | Program.cs:24 | DPI、异常处理、释放运行时、`Application.Run` |
| `RuntimeAssets` | static class | Program.cs:114 | 内嵌资源提取到缓存目录 + 完整性校验 |
| `OpenCC` | class | Program.cs:254 | `opencc.dll` P/Invoke 包装，单实例 |
| `OpenCCEngine` | static class | Program.cs:357 | 运行时目录 + s2t/t2s 懒加载缓存 + 全局锁 |
| `Theme` | static class | Program.cs:407 | 颜色/字体常量 + 圆角路径 |
| `HeaderPanel` / `RoundedCard` | control | Program.cs:449 / :466 | 头部与卡片容器 |
| `SegmentedControl` | control | Program.cs:490 | `简 → 繁` / `繁 → 简` 分段开关 |
| `FlatButton` / `LinkButton` | control | Program.cs:620 / :657 | 自绘按钮 |
| `AutoScrollTextBox` | control | Program.cs:699 | 自适应滚动条 |
| `MainForm` | class | Program.cs:758 | 窗口、布局、事件 |
| `BuildUi` | method | Program.cs:794 | 全部控件构造与布局 |
| `OnDirectionChanged` / `StartConversion` | method | Program.cs:1055 / :1063 | 方向切换 / 防抖后转换并回写 UI |

行号会随改动漂移；优先按符号名 grep，不要死信行号。

## COMMANDS

```powershell
# 构建（仓库根目录；无 SDK / 无 NuGet）
powershell -ExecutionPolicy Bypass -File build.ps1

# 运行（构建后生成；dist 内只有这一个文件）
dist\JianFanConverter.exe

# 冷启动复现（清掉运行时缓存，验证首次释放）
Remove-Item "$env:LOCALAPPDATA\JianFanConv" -Recurse -Force -ErrorAction SilentlyContinue
```

`dist/` 不入库，新克隆的仓库没有 exe，必须先构建。无测试框架、无 CI。改完必须做的最小自检：

1. 简→繁：`汉字转换测试，软件和硬件。` → `漢字轉換測試，軟件和硬件。`
2. 繁→简：`漢字轉換測試，軟體和硬體。` → `汉字转换测试，软体和硬体。`
3. `复制` 后剪贴板 = 右栏内容；`清空` 后两栏为空。
4. 单文件分发：把 `dist\JianFanConverter.exe` **单独**拷到空目录运行，确认能转换（不是只在仓库里能跑）。

## CONVENTIONS (deviations only)

- **C# 5 only**：构建用系统自带 `%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe`。禁用 `$""`、`?.`、`nameof`、表达式体成员、模式匹配等 C# 6+ 语法。
- **No project files**：无 `.csproj` / `.sln` / designer / NuGet；源码单文件，UI 全手写。不要引入 WPF / Electron / HTML。
- **Source encoding**：`.cs` 为 UTF-8，中文界面字符串直接写；编译参数含 `/codepage:65001`。
- **build.ps1 保持 ASCII**：图标里的「简」用 `[char]0x7B80` 生成；不要加入中文字面量（PowerShell 5.1 无 BOM 会乱码）。
- **原生互操作**：`opencc_open_w` 传绝对宽字符路径；`SetDllDirectory(<释放目录>)` 必须在**任何** `opencc` DllImport 之前执行；每个方向缓存一个实例，调用必须持锁（C API 非线程安全）；退出时 `opencc_close`。
- **素材流向单一**：`vendor/opencc/` → 编译期 `/resource:...,JianFanConverter.Runtime.<文件名>` → 运行时释放到缓存；`dist/` 只有 exe，是生成物。
- **UI 文案中文**：沿用 OpenCC 术语（原文 / 结果 / 粘贴 / 复制 / 清空）。
- **提交范围**：只提交 `src/`、`vendor/`、`.github/`、`build.ps1`、`README.md`、`AGENTS.md`、`LICENSE`；`dist/`、`*.zip`、`release-notes-*.md` 都不入库（已在 `.gitignore`）。

## ANTI-PATTERNS (THIS PROJECT)

- 禁止在 `build.ps1` 或源码中出现本机绝对路径或外部安装目录；构建只能读 `vendor/`。
- 禁止把运行时资产改回“与 exe 同目录”的分发方式；那会退回到多文件分发，破坏单文件 exe 的唯一价值。
- 禁止在 `SetDllDirectory` 之前触发任何 `opencc` DllImport（DllImport 一旦发生，DLL 搜索路径就锁定，之后改目录无效）。
- 禁止改了 `vendor/opencc/` 内容却不 bump `RuntimeAssets.RuntimeTag`（缓存目录名不变会继续命中旧文件）。
- 禁止删除/清理其它 `runtime-*` 缓存目录（可能正被另一个运行中的实例加载）。
- 禁止引入 GPL 代码；本仓库只允许 MIT 应用代码 + Apache-2.0 的 OpenCC 资产，`vendor/opencc/LICENSE` 与 `NOTICE.txt` 必须保留。
- 禁止手改 `dist/`（每次构建会清空）；禁止把源码或构建产物提交进仓库。
- 禁止删除 `opencc_convert_utf8_free` / `opencc_close`；禁止无锁调用转换。
- 禁止为“顺手”引入 SDK、NuGet、网络请求、安装包或第二个源码文件。
- 禁止假设 `dotnet build` 可用。

## GOTCHAS

- 构建环境默认**没有 .NET SDK**（`dotnet --list-sdks` 为空），只有 .NET Framework 4.8 运行时 + 自带 csc；只能用 `build.ps1`。
- 仅 Win10/11 **x64**；`opencc.dll` 是 x64。
- 首次运行把 7 个运行时文件释放到 `%LOCALAPPDATA%\JianFanConv\runtime-<tag>\`（该目录不可写时退到 `%TEMP%\JianFanConv\runtime-<tag>\`）。验证冷启动前必须先删掉它，否则测的是热启动。
- 已存在且长度与内嵌资源一致的文件不会重写；长度不符会重新释放。旧 tag 目录不清理。
- OpenCC 标准 t2s 会把 `軟體` 转成 `软体`（不是 `软件`）；不要用“更自然”的期望值改自检。
- UI 自动化（实测有效）：`WM_SETTEXT` 能设文本且可 `WM_GETTEXT` 回读校验，但**不触发 `TextChanged`**；要触发转换就向文本为 `方向切换` 的 HWND 发 `WM_KEYDOWN`（`VK_RIGHT`=0x27 / `VK_LEFT`=0x25），走 `OnDirectionChanged → StartConversion`。
- UI 自动化（坐标陷阱）：`WM_LBUTTONDOWN/UP` 的 lParam 必须是 **client 相对坐标**；`GetWindowRect` 给的是屏幕坐标，直接当 client 坐标用会越界，`SegmentedControl.HitSegment` 返回 -1，点击静默失效。
- 控件枚举：`EnumChildWindows` 本身就会递归枚举全部后代；再手动递归会重复计数（表现为 EDIT 控件数量翻倍）。按 HWND 去重。
- 截图需 DPI 感知 + `DWMWA_EXTENDED_FRAME_BOUNDS`，否则边缘会带入其它窗口内容。
- 布局按物理像素写死、字体按 DPI 放大；高缩放下比例会变，改布局时在 100% / 125% 都看一眼。
- `AutoScrollTextBox`：文本 > 20000 字符时不再测量、直接显示滚动条（性能保护）。
- exe 未签名，首次运行可能触发 SmartScreen。
- 新克隆仓库没有 `dist/`（被 `.gitignore` 排除），先构建再运行/验证。
- Gitee 与 GitHub 都走 SSH。本机 `~/.ssh/config` 有 `Host github.com` 块，指向专用密钥 `id_ed25519_github`（带 `IdentitiesOnly yes`）；Gitee 用默认的 `id_ed25519`。两把钥匙互不影响，这些**都是本机配置、不入库**，换机器要重新生成并在各自账户注册。
- 若本机 SSH 到 GitHub 不通，可改用 `ssh.github.com:443`（在 `Host github.com` 块里加 `HostName ssh.github.com` + `Port 443`）；这比配 HTTPS 代理稳定，`gh` 的 API 调用不受影响。
- GitHub 侧内容由工作流从 Gitee `--mirror` 强推而来：Gitee 上删掉的分支/标签，GitHub 上也会被删；不要在 GitHub 侧直接提交或开分支，会被下一次同步覆盖。
- 工作流生效有前提：`.github/workflows/sync-from-gitee.yml` 必须已在 GitHub 的默认分支上，否则它没机会运行。首次落地要同时推 Gitee 和 GitHub 各一次，之后才是 Gitee 单推。
- GitHub Actions 的 `schedule` 在免费额度下经常延迟十几分钟甚至更久，不能当作「秒级同步」用；需要立刻同步就 `gh workflow run sync-from-gitee.yml`。
- `--mirror` 只同步 git 引用（分支 / 标签 / 提交），**Gitee 的发行版与附件不会出现在 GitHub**。两边 release 要分别创建：Gitee 网页上传 zip，GitHub 侧用 `gh release create v<版本> JianFanConverter-v<版本>-win-x64.zip --notes-file ...`。
- Gitee API 的响应头不带 `charset`，PowerShell 的 `Invoke-RestMethod` 会按 Latin-1 解码，`name` / `body` 全是乱码（`id` 和附件名是 ASCII，不受影响）。要校验 Gitee 返回的中文，用 `curl.exe` 落盘再以 UTF-8 解析，别用 `Invoke-RestMethod` 直接比较。
- Gitee 创建发行版只接受 **form 编码**（JSON body 会返回 `405 Not Allowed`）；查询不存在的 tag 返回 **HTTP 200 + body `null`**（不是 404），所以判断「发行版是否已存在」要看 `id` 而不是状态码。
- 默认分支 `master`；远程配置以 `git remote -v` 为准。

## 发布流程

```powershell
# 一条命令发版：构建 → 打包 → 打 tag → 推 Gitee → 建 Gitee 发行版并传附件 → 触发镜像 → 建 GitHub release
# 前置：先写好 release-notes-v<版本>.md（首个 "## " 行会作为发行版标题）
powershell -ExecutionPolicy Bypass -File release.ps1 -Version 1.0.2
```

- `release.ps1` 的 `GITEE_TOKEN`（Gitee 私人令牌，需 `projects` 权限）从环境变量读取，顺序为进程 → User → Machine；**不要写进任何文件或提交**。
- 只重跑某一环时用开关：`-SkipBuild` / `-SkipZip` / `-SkipGitPush` / `-SkipGitee` / `-SkipGitHub`。脚本对已存在的 tag、发行版、同名附件都是幂等的，可以安全重跑。
- 脚本是 **ASCII-only**（同 `build.ps1` 的理由）；发行版标题从说明文件的标题行派生，不要在脚本里写中文字面量。
- 手动兜底流程：`build.ps1` → `Compress-Archive -Path dist\*`（注意 `dist\*`，不要用 `dist`，否则解压多一层目录）→ `git tag -a` → `git push origin master --tags` → Gitee 网页建 release 上传 zip。
- `git push origin` 只推 Gitee（唯一真源）。GitHub 通常十几分钟内自动同步；想立刻同步用 `gh workflow run sync-from-gitee.yml`。
- 需要应急直推 GitHub 时用 `git push github master --tags`（`github` remote 仍保留）。
- GitHub 的 release 由脚本调 `gh release create` 创建。`--mirror` 只同步 git 引用，**附件不会跨平台**。
- 发行版说明里写清 SHA256、环境要求（Win10/11 x64、.NET Framework 4.8）、SmartScreen 提示与许可声明。
- zip 与说明文件都是发布临时物（已在 `.gitignore`），上传后删除。

## NOTES

- 应用不读取/保存用户配置；唯一的落盘是 `%LOCALAPPDATA%\JianFanConv\runtime-<tag>\` 运行时缓存，可以随时删除，下次启动自动重建。
- 授权：应用代码采用 MIT（根目录 `LICENSE`）；OpenCC 引擎与词典为 Apache-2.0（见 `vendor/opencc/LICENSE`），随程序内嵌分发。
- `README.md` 面向使用者；本文件面向改代码的 agent / 维护者。
