# 简繁转换（JianFanConverter）

一个本地离线的简体 ↔ 繁体中文转换小工具。左侧粘贴/输入原文，右侧实时显示转换结果，基于 OpenCC 引擎，全程本地运行，无任何网络请求。

**自带 OpenCC 引擎**：运行和构建都只依赖本目录内的文件，完全离线，可独立分发或迁移。运行时资产在编译时内嵌进 exe，分发只需要一个文件。

## 独立性

| 场景 | 依赖 |
| --- | --- |
| 运行 `dist\JianFanConverter.exe` | 只有这 **1 个 exe**；.NET Framework 4.8（Win10/11 自带）；win-x64 |
| 重新构建 `build.ps1` | `src\Program.cs` + `vendor\opencc\` 内的引擎文件 + 系统自带 `csc.exe` |

- 单个 `dist\JianFanConverter.exe` 可以直接拷到任意位置（或另一台 Win10/11 x64 电脑）运行，不需要附带其它文件。
- `vendor\opencc\` 是项目自带的 OpenCC 引擎副本（`opencc.dll` + 词典 + 许可），`build.ps1` 只从这里读取并作为资源嵌入，**不读取任何外部安装目录，也不访问网络**。
- OpenCC 运行时资产的来源与授权见 `vendor\opencc\NOTICE.txt`；项目内不含任何 GPL 代码。

## 功能

- 双向转换：`简 → 繁`、`繁 → 简`，点击顶部分段开关切换
- 左侧输入实时转换（200 ms 防抖），右侧结果可编辑、可部分复制
- `粘贴`：用剪贴板文本替换左侧内容；`复制`：复制右侧结果；`清空`：清空两侧
- 实时字数统计、转换耗时状态提示
- 内容不满一屏时自动隐藏垂直滚动条，超出才显示
- 输入为空时显示占位提示；切换方向时保留原文并立即重新转换

## 运行

直接双击：

```
dist\JianFanConverter.exe
```

要求：Windows 10/11 **x64**，.NET Framework 4.8 运行时（Win10/11 自带）。只需这一个 exe：`opencc.dll`、`s2t.json`、`t2s.json` 及 4 个 `.ocd2` 词典文件已经在编译时内嵌进程序里，**不需要**放在 exe 旁边。

首次运行时程序会把内置的 OpenCC 运行时释放到 `%LOCALAPPDATA%\JianFanConv\runtime-r1\`（该目录不可写时退到 `%TEMP%\JianFanConv\runtime-r1\`），之后的启动直接复用已释放的文件。若释放失败或文件不可用，程序会用中文弹窗说明原因。

> 从仓库克隆的代码不包含 `dist\`（构建产物不入库），请先按下一节构建。

首次启动 Windows SmartScreen 可能提示未知发布者（exe 没有代码签名），点「更多信息 → 仍要运行」即可。

## 构建

无需安装任何 SDK / NuGet，使用系统自带的 .NET Framework 编译器：

```powershell
powershell -ExecutionPolicy Bypass -File build.ps1
```

脚本会：清理并重建 `dist\` → 校验项目内 `vendor\opencc\` 的 7 个 OpenCC 运行时文件并**以 `/resource` 编译为内嵌资源**（`JianFanConverter.Runtime.<文件名>`）→ 用 System.Drawing 生成临时图标 `dist\app.ico` 供 `/win32icon` 使用（失败则跳过，不阻塞构建；编译后删除）→ 调用系统自带的 `%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe` 编译（`/target:winexe /platform:x64 /codepage:65001`）。

构建完成后 `dist\` 里只有 `JianFanConverter.exe` 一个文件。

## 修改指南

源码只有一个文件 `src\Program.cs`（约 1130 行），按顺序分成四块：

| 区域 | 内容 |
| --- | --- |
| `RuntimeAssets` / `OpenCC` / `OpenCCEngine` | 内嵌运行时释放与缓存、P/Invoke 互操作、实例缓存、线程锁、启动文件检查 |
| `Theme` | 全部颜色（`#F3F4F6` 背景、`#2563EB` 主色…）与字体，改外观先改这里 |
| 自绘控件 | `SegmentedControl`（方向切换）、`FlatButton`、`LinkButton`、`RoundedCard`、`HeaderPanel` |
| `MainForm` | 布局、防抖、转换、粘贴/复制/清空等交互 |

常见修改点：

- **转换方向**：`MainForm._s2t`（`true` = 简→繁）
- **实时转换延迟**：`_debounce.Interval`（默认 200 ms）
- **配色 / 字号**：`Theme` 类
- **窗口默认大小**：`MainForm` 构造函数里的 `ClientSize`
- 改完运行 `build.ps1` 重新编译即可。

维护者 / AI agent 的开发约定见 [AGENTS.md](AGENTS.md)。

## 文件结构

```
JianFanConv\
├── build.ps1                    构建脚本（校验并内嵌运行时、生成图标、编译）
├── README.md                    本文档
├── LICENSE                      应用代码 MIT 许可
├── AGENTS.md                    维护者 / AI agent 约定
├── .gitignore                   忽略 dist/ 与临时文件
├── src\
│   └── Program.cs               全部源码（WinForms UI + OpenCC P/Invoke + 运行时释放）
├── vendor\
│   └── opencc\                  项目自带的 OpenCC 引擎（构建期素材，编译时嵌入 exe）
│       ├── opencc.dll           OpenCC C API 原生库（Windows x64）
│       ├── s2t.json / t2s.json  转换配置
│       ├── STPhrases.ocd2 / STCharacters.ocd2
│       ├── TSPhrases.ocd2 / TSCharacters.ocd2
│       ├── LICENSE              Apache License 2.0
│       └── NOTICE.txt           来源与授权说明
└── dist\                        编译产物，不入库（可直接分发）
    └── JianFanConverter.exe     x64 主程序（唯一文件，7 个运行时资产已内嵌）
```

## 技术说明

- 通过 P/Invoke 调用 `opencc.dll`（`opencc_open_w` / `opencc_convert_utf8` / `opencc_convert_utf8_free` 等），每个方向缓存一个 OpenCC 实例并加锁（C API 非线程安全），退出时释放句柄
- 启动时把内嵌的 7 个 OpenCC 运行时资产释放到 `%LOCALAPPDATA%\JianFanConv\runtime-r1\`（不可写时退到 `%TEMP%`），随后调用 `SetDllDirectory(缓存目录)` 保证原生 DLL 从缓存目录解析；配置用绝对路径传给 `opencc_open_w`，因此 exe 和程序工作目录都可以任意放置
- 缓存按 `runtime-<tag>` 命名：只用已存在且长度与内嵌资源一致的文件，缺失或长度不符才重新释放；旧 tag 目录不清理（可能是另一个仍在运行的实例）
- 转换在后台线程执行，防抖 + 版本号丢弃过期结果，界面不卡顿
- 未处理异常会写入 `%TEMP%\JianFanConverter-error.log` 并弹窗提示

## 版权与致谢

- 转换引擎 [OpenCC](https://github.com/BYVoid/OpenCC)（`opencc.dll` 及词典）采用 **Apache License 2.0**，许可原文见 `vendor\opencc\LICENSE`，来源说明见 `NOTICE.txt`。这些文件随本程序一并分发。
- 本程序的界面与互操作代码为原创实现，项目中不含任何 GPL 代码；OpenCC 资产按 Apache-2.0 分发。
- 仅支持 win-x64。

## 许可证

- 本程序代码：[MIT License](LICENSE)
- `vendor/opencc/` 内的 OpenCC 引擎与词典：[Apache License 2.0](vendor/opencc/LICENSE)
