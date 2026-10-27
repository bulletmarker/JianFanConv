# PROJECT KNOWLEDGE BASE

**Generated:** 2026-10-27
**Branch:** master

## OVERVIEW

Windows 本地简繁转换桌面工具。C# 5 + WinForms（.NET Framework 4.8 / x64），自带 OpenCC 引擎，左栏输入、右栏实时输出，完全离线，不依赖 ConvertZZ 或其他本地项目。

本仓库为独立仓库，默认分支 `master`；远程地址以 `git remote -v` 为准。

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
├── src/Program.cs            唯一源码（989 行）
├── vendor/opencc/            内置 OpenCC 引擎+词库+许可（构建素材；升级需同步许可）
├── build.ps1                 一键构建（清空 dist → 复制 vendor → 编译）
├── dist/                     构建产物（已 gitignore；clone 后需先构建）
├── .gitignore                忽略 dist/ 及临时文件
├── LICENSE                   应用代码 MIT 许可
├── AGENTS.md                 维护者 / agent 约定（本文件）
└── README.md                 面向使用者的运行 / 构建 / 修改说明
```

## WHERE TO LOOK

| 任务 | 位置 | 说明 |
|---|---|---|
| 改界面 / 布局 / 交互 | `src/Program.cs` 的 `MainForm` / `BuildUi` | 手写 WinForms，无 designer |
| 改颜色 / 字体 | `Theme` | 唯一配色与字体来源 |
| 改转换逻辑 / 引擎 | `OpenCC` / `OpenCCEngine` | P/Invoke 包装 + 实例缓存 |
| 改方向切换 | `OnDirectionChanged` | `_s2t` 布尔控制方向 |
| 改实时转换 | `StartConversion` | 200 ms 防抖 + 后台线程 + 版本号 |
| 改滚动条 | `AutoScrollTextBox` | 不满一屏隐藏，超出显示 |
| 改构建 / 打包 | `build.ps1` | 只从 `vendor/` 取素材 |
| 升级 OpenCC | `vendor/opencc/` | 必须同步更新 LICENSE / NOTICE.txt |

## CODE MAP

| Symbol | Type | Location | Role |
|---|---|---|---|
| `Program.Main` | method | Program.cs:22 | DPI、异常处理、启动文件检查、`Application.Run` |
| `OpenCC` | class | Program.cs:92 | `opencc.dll` P/Invoke 包装，单实例 |
| `OpenCCEngine` | static class | Program.cs:195 | s2t/t2s 懒加载缓存 + 全局锁 |
| `Theme` | static class | Program.cs:250 | 颜色/字体常量 + 圆角路径 |
| `SegmentedControl` | control | Program.cs:333 | `简 → 繁` / `繁 → 简` 分段开关 |
| `FlatButton` / `LinkButton` | control | Program.cs:463 / :500 | 自绘按钮 |
| `AutoScrollTextBox` | control | Program.cs:542 | 自适应滚动条 |
| `MainForm` | class | Program.cs:601 | 窗口、布局、事件 |
| `StartConversion` | method | Program.cs:906 | 防抖后转换并回写 UI |

行号会随改动漂移；优先按符号名 grep，不要死信行号。

## COMMANDS

```powershell
# 构建（仓库根目录；无 SDK / 无 NuGet）
powershell -ExecutionPolicy Bypass -File build.ps1

# 运行（构建后生成）
dist\JianFanConverter.exe
```

`dist/` 不入库，新克隆的仓库没有 exe，必须先构建。无测试框架、无 CI。改完必须做的最小自检：

1. 简→繁：`汉字转换测试，软件和硬件。` → `漢字轉換測試，軟件和硬件。`
2. 繁→简：`漢字轉換測試，軟體和硬體。` → `汉字转换测试，软体和硬体。`
3. `复制` 后剪贴板 = 右栏内容；`清空` 后两栏为空。

## CONVENTIONS (deviations only)

- **C# 5 only**：构建用系统自带 `%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe`。禁用 `$""`、`?.`、`nameof`、表达式体成员、模式匹配等 C# 6+ 语法。
- **No project files**：无 `.csproj` / `.sln` / designer / NuGet；源码单文件，UI 全手写。不要引入 WPF / Electron / HTML。
- **Source encoding**：`.cs` 为 UTF-8，中文界面字符串直接写；编译参数含 `/codepage:65001`。
- **build.ps1 保持 ASCII**：图标里的「简」用 `[char]0x7B80` 生成；不要加入中文字面量（PowerShell 5.1 无 BOM 会乱码）。
- **原生互操作**：`opencc_open_w` 传绝对宽字符路径；启动时 `SetDllDirectory(exeDir)`；每个方向缓存一个实例，调用必须持锁（C API 非线程安全）；退出时 `opencc_close`。
- **UI 文案中文**：沿用 OpenCC / ConvertZZ 的术语（原文 / 结果 / 粘贴 / 复制 / 清空）。
- **素材流向单一**：`vendor/opencc/` → `dist/`；`dist/` 是生成物。
- **提交范围**：只提交 `src/`、`vendor/`、`build.ps1`、`README.md`、`AGENTS.md`、`LICENSE`；不要提交 `dist/`。

## ANTI-PATTERNS (THIS PROJECT)

- 禁止在 `build.ps1` 或源码中出现本机绝对路径或外部安装目录（如 ConvertZZ 的安装路径）；构建只能读 `vendor/`。
- 禁止复制 ConvertZZ 源码（GPL-3.0）；OpenCC 资产为 Apache-2.0，`vendor/opencc/LICENSE` 与 `NOTICE.txt` 必须保留。
- 禁止手改 `dist/`（每次构建会清空）；禁止把源码或构建产物提交进仓库。
- 禁止删除 `opencc_convert_utf8_free` / `opencc_close`；禁止无锁调用转换。
- 禁止为“顺手”引入 SDK、NuGet、网络请求、安装包或第二个源码文件。
- 禁止假设 `dotnet build` 可用。

## GOTCHAS

- 构建环境默认**没有 .NET SDK**（`dotnet --list-sdks` 为空），只有 .NET Framework 4.8 运行时 + 自带 csc；只能用 `build.ps1`。
- 仅 Win10/11 **x64**；`opencc.dll` 是 x64。
- OpenCC 标准 t2s 会把 `軟體` 转成 `软体`（不是 `软件`）；不要用“更自然”的期望值改自检。
- UI 自动化：自绘控件只暴露 `AccessibleName`（方向切换 / 粘贴 / 复制 / 清空），没有 ValuePattern / Invoke；用 `WM_LBUTTONDOWN/UP` 发给其 HWND。文本框用 `WM_GETTEXT` 读；`WM_SETTEXT` 不触发 `TextChanged`。
- 截图需 DPI 感知 + `DWMWA_EXTENDED_FRAME_BOUNDS`，否则边缘会带入其它窗口内容。
- 布局按物理像素写死、字体按 DPI 放大；高缩放下比例会变，改布局时在 100% / 125% 都看一眼。
- `AutoScrollTextBox`：文本 > 20000 字符时不再测量、直接显示滚动条（性能保护）。
- exe 未签名，首次运行可能触发 SmartScreen。
- 新克隆仓库没有 `dist/`（被 `.gitignore` 排除），先构建再运行/验证。
- 默认分支 `master`；远程配置以 `git remote -v` 为准。

## NOTES

- 应用不读取/保存用户配置，每次启动即用。
- 授权：应用代码采用 MIT（根目录 `LICENSE`）；OpenCC 引擎与词典为 Apache-2.0（见 `vendor/opencc/LICENSE`）。
- `README.md` 面向使用者；本文件面向改代码的 agent / 维护者。
