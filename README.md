# Claude Switch Tool

A tool to switch between Claude Pro accounts while preserving chat history.

## Files

- `claude-switch` - Main script
- `claude-switch.ps1` - Native Windows main script
- `install-claude-switch.sh` - Installation script
- `install-claude-switch.ps1` - Windows installation script
- `install-claude-switch.cmd` - Windows one-click installer entry
- `pack-claude-switch.sh` - Linux/macOS packing script
- `pack-claude-switch.ps1` - Windows packing script

## Installation
# Claude Switch Tool

A tool to switch between Claude Pro accounts while preserving chat history.

## Files

- `claude-switch` - Linux/macOS main script
- `claude-switch.ps1` - Native Windows main script
- `install-claude-switch.sh` - Linux/macOS installer
- `install-claude-switch.ps1` - Windows installer
- `install-claude-switch.cmd` - Windows one-click installer entry
- `pack-claude-switch.sh` - Linux/macOS packing script
- `pack-claude-switch.ps1` - Windows packing script

## Installation

### Linux/macOS

System-wide install:

```bash
sudo ./install-claude-switch.sh
```

User install:

```bash
./install-claude-switch.sh
```

### Windows

After extracting the package, run one of:

```powershell
.\install-claude-switch.cmd
# or
powershell -ExecutionPolicy Bypass -File .\install-claude-switch.ps1
```

Custom install dir:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-claude-switch.ps1 -InstallDir "D:\tools\claude-switch\bin"
```

Installer behavior:

- Installs wrappers in `%LOCALAPPDATA%\Programs\claude-switch\bin`
- Adds install dir to user `PATH`
- Adds compatibility wrappers to `%USERPROFILE%\.local\bin`
- Provides `claude-switch` and `cs`

## Packaging

### Windows

Default output dir (`./dist`):

```powershell
powershell -ExecutionPolicy Bypass -File .\pack-claude-switch.ps1
```

Custom output dir:

```powershell
powershell -ExecutionPolicy Bypass -File .\pack-claude-switch.ps1 -OutputDir "D:\release"
```

Outputs:

- `dist/claude-switch-tool/`
- `dist/claude-switch-tool.zip`

### Linux/macOS

Default output dir (`./dist`):

```bash
./pack-claude-switch.sh
```

Custom output dir:

```bash
./pack-claude-switch.sh /tmp/release
```

Outputs:

- `dist/claude-switch-tool/`
- `dist/claude-switch-tool.tar.gz`
- `dist/claude-switch-tool.zip` (if `zip` exists)

## Command Usage

You can use either `cs` or `claude-switch`.

```bash
cs                          # 交互式选择账号
cs interactive              # 交互式选择账号
cs login [name]             # 登录新账号；有 name 时自动保存
cs save <name>              # 保存当前账号
cs <name>                   # 一键切换到指定账号
cs ls                       # 列出所有账号（含订阅/过期）
cs list                     # ls 别名
cs check                    # 探测账号可用性
cs usage                    # 当前账号使用情况
cs usage-all                # 所有账号使用情况
cs current                  # 当前账号显示名+邮箱
cs rm <name>                # 删除已保存账号
cs help                     # 帮助
cs -h
cs --help
```

## Typical Workflow

```bash
cs login main
cs login work
cs ls
cs usage-all
cs
```

## Features

- Switch between multiple Claude Pro accounts
- Preserve chat history across all accounts
- Check usage (5-hour, 7-day, extra credits)
- Interactive selection with color-coded usage
- Account availability checking
- Auto-save after login

## How It Works

The tool swaps authentication files and keeps other Claude Code files intact:

- `~/.claude/.credentials.json` - OAuth tokens
- `~/.claude.json` (`oauthAccount` field) - account info

Chat history (`~/.claude/history.jsonl`, `~/.claude/projects/`, etc.) remains shared.

## Notes

- Requires `claude` CLI and at least one successful login
- Uses Anthropic OAuth usage API (same source as Claude Code `/usage`)
- Linux verified; Windows has native PowerShell/CMD support

## Troubleshooting

- If `cs` is not found after install, reopen terminal first.
- Verify PATH contains `%LOCALAPPDATA%\Programs\claude-switch\bin`.
- Temporary PATH injection for current PowerShell session:

```powershell
$env:Path = "$env:LOCALAPPDATA\Programs\claude-switch\bin;$env:Path"
```
