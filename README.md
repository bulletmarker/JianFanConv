# 简繁转换（JianFanConverter）

一个本地离线的简体 ↔ 繁体中文转换小工具。左侧粘贴/输入原文，右侧实时显示转换结果，基于 OpenCC 引擎，全程本地运行，无任何网络请求。

**自带 OpenCC 引擎**：运行和构建都只依赖本目录内的文件，完全离线，可独立分发或迁移。

## 独立性

| 场景 | 依赖 |
| --- | --- |
| 运行 `dist\JianFanConverter.exe` | `dist\` 内的 9 个文件；.NET Framework 4.8（Win10/11 自带）；win-x64 |
| 重新构建 `build.ps1` | `src\Program.cs` + `vendor\opencc\` 内的引擎文件 + 系统自带 `csc.exe` |

- `dist\` 整个目录可以直接拷到任意位置（或另一台 Win10/11 x64 电脑）运行。
- `vendor\opencc\` 是项目自带的 OpenCC 引擎副本（`opencc.dll` + 词典 + 许可），`build.ps1` 只从这里复制，**不读取任何外部安装目录，也不访问网络**。
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

要求：Windows 10/11 **x64**，.NET Framework 4.8 运行时（Win10/11 自带）。`opencc.dll`、`s2t.json`、`t2s.json` 及 4 个 `.ocd2` 词典文件必须与 exe 同目录（`dist\` 内已随构建一并复制）。若缺少这些文件，程序启动时会用中文弹窗指明缺失的文件名。

> 从仓库克隆的代码不包含 `dist\`（构建产物不入库），请先按下一节构建。

首次启动 Windows SmartScreen 可能提示未知发布者（exe 没有代码签名），点「更多信息 → 仍要运行」即可。

## 构建

无需安装任何 SDK / NuGet，使用系统自带的 .NET Framework 编译器：

```powershell
powershell -ExecutionPolicy Bypass -File build.ps1
```

脚本会：清理并重建 `dist\` → **从项目内的 `vendor\opencc\` 复制 7 个 OpenCC 运行时文件** → 用 System.Drawing 生成应用图标 `dist\app.ico`（失败则跳过，不阻塞构建）→ 调用系统自带的 `%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe` 编译（`/target:winexe /platform:x64 /codepage:65001`）。

## 修改指南

源码只有一个文件 `src\Program.cs`（约 990 行），按顺序分成四块：

| 区域 | 内容 |
| --- | --- |
| `OpenCC` / `OpenCCEngine` | P/Invoke 互操作、实例缓存、线程锁、启动文件检查 |
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
├── build.ps1                    构建脚本（从 vendor 复制运行时、生成图标、编译）
├── README.md                    本文档
├── LICENSE                      应用代码 MIT 许可
├── AGENTS.md                    维护者 / AI agent 约定
├── .gitignore                   忽略 dist/ 与临时文件
├── src\
│   └── Program.cs               全部源码（WinForms UI + OpenCC P/Invoke）
├── vendor\
│   └── opencc\                  项目自带的 OpenCC 引擎（构建素材，不会被修改）
│       ├── opencc.dll           OpenCC C API 原生库（Windows x64）
│       ├── s2t.json / t2s.json  转换配置
│       ├── STPhrases.ocd2 / STCharacters.ocd2
│       ├── TSPhrases.ocd2 / TSCharacters.ocd2
│       ├── LICENSE              Apache License 2.0
│       └── NOTICE.txt           来源与授权说明
└── dist\                        编译产物，不入库（可直接分发）
    ├── JianFanConverter.exe     x64 主程序
    ├── app.ico                  构建时生成的图标
    └── （其余 7 个文件从 vendor 复制）
```

## 技术说明

- 通过 P/Invoke 调用 `opencc.dll`（`opencc_open_w` / `opencc_convert_utf8` / `opencc_convert_utf8_free` 等），每个方向缓存一个 OpenCC 实例并加锁（C API 非线程安全），退出时释放句柄
- 启动时调用 `SetDllDirectory(exe 所在目录)`，保证原生 DLL 始终从程序目录解析；配置用绝对路径传给 `opencc_open_w`，因此程序可从任意工作目录启动
- 转换在后台线程执行，防抖 + 版本号丢弃过期结果，界面不卡顿
- 未处理异常会写入 `%TEMP%\JianFanConverter-error.log` 并弹窗提示

## 版权与致谢

- 转换引擎 [OpenCC](https://github.com/BYVoid/OpenCC)（`opencc.dll` 及词典）采用 **Apache License 2.0**，许可原文见 `vendor\opencc\LICENSE`，来源说明见 `NOTICE.txt`。这些文件随本程序一并分发。
- 本程序的界面与互操作代码为原创实现，项目中不含任何 GPL 代码；OpenCC 资产按 Apache-2.0 分发。
- 仅支持 win-x64。

## 许可证

- 本程序代码：[MIT License](LICENSE)
- `vendor/opencc/` 内的 OpenCC 引擎与词典：[Apache License 2.0](vendor/opencc/LICENSE)
