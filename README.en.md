# JianFanConverter

A portable, fully offline Windows app for Simplified ↔ Traditional Chinese conversion, powered by [OpenCC](https://github.com/BYVoid/OpenCC).

[中文说明](README.md) | **English**

- **Single file**: one `JianFanConverter.exe` (~1.5 MB). No installer, no DLLs to keep together.
- **Fully offline**: OpenCC is embedded into the exe at compile time. The app makes no network requests.
- **No config, no leftovers**: nothing is written to the registry; the only disk write is a runtime cache you can delete at any time.

![JianFanConverter](docs/screenshot.png)

## Download

Get the latest `JianFanConverter-v*-win-x64.zip` from [GitHub Releases](https://github.com/bulletmarker/JianFanConv/releases/latest) (mirror: [Gitee Releases](https://gitee.com/machangsheng/jian-fan-conv/releases)).

Unzip anywhere and run `JianFanConverter.exe`. The archive contains three files: the exe plus `LICENSE.txt` and `THIRD-PARTY-NOTICES.txt`. The two license files are not needed to run, but should be kept if you redistribute the app.

Each release page lists the SHA256 of both the zip and the exe.

## Requirements

- Windows 10 or 11, **x64**
- .NET Framework 4.8 (included with Windows 10/11 — nothing to install)

## Note: the UI is in Chinese

This is a Simplified ↔ Traditional Chinese conversion tool, so the interface is in Chinese: `原文` source, `结果` result, `粘贴` paste, `复制` copy, `清空` clear. There are only a few labels — two text panes, a direction switch, a region selector and a phrases toggle.

## Features

- Two-way conversion: `简 → 繁` (Simplified to Traditional) and `繁 → 简`, switched with the segmented control in the toolbar
- Target variant: `标准` (OpenCC standard), `台湾` (Taiwan) or `香港` (Hong Kong), plus an optional 地区用词 toggle for local wording (Taiwan: 软件 → 軟體; Hong Kong: 打印机 → 打印機)
- Live conversion while typing (200 ms debounce); the result pane is editable and partially copyable
- Paste into the source pane, copy the result, clear both with one click
- Live character count and conversion time in the status bar
- The vertical scrollbar appears only when the text actually overflows
- Switching direction keeps the source text and re-converts immediately

## First run

On first launch the app extracts its embedded OpenCC runtime to `%LOCALAPPDATA%\JianFanConv\runtime-r2\` (~1.5 MB) and reuses it afterwards. If that folder is not writable it falls back to `%TEMP%\JianFanConv\runtime-r2\`. The cache can be deleted at any time; it is rebuilt on the next launch.

The exe is not code-signed, so Windows SmartScreen may warn on first run: choose **More info → Run anyway**.

## Known behavior

In the default Taiwan + phrases mode, `軟體` converts back to `软件`. The OpenCC standard mode turns `軟體` into `软体`, which is the upstream dictionary's intended output, not a bug.

## Build from source

No SDK, no NuGet, no project files — the build uses the C# compiler that ships with .NET Framework:

```powershell
powershell -ExecutionPolicy Bypass -File build.ps1
```

`dist\` then contains exactly one file, `JianFanConverter.exe`. The build embeds the 30 OpenCC assets from `vendor\opencc\` as resources; that folder is never modified.

## License

- Application code: [MIT](LICENSE)
- OpenCC engine and dictionaries (`opencc.dll` and the `.ocd2` files): Apache License 2.0 — see `vendor/opencc/LICENSE` and `vendor/opencc/NOTICE.txt`
- Windows x64 only

For full details, see the [Chinese README](README.md).
