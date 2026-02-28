param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CliArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$StoreDir = Join-Path $HOME '.claude/accounts'
$CredFile = Join-Path $HOME '.claude/.credentials.json'
$StateFile = Join-Path $HOME '.claude.json'

if (-not (Test-Path $StoreDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $StoreDir | Out-Null
}

function Write-Info { param([string]$Message) Write-Host ">>> $Message" -ForegroundColor Cyan }
function Write-Ok { param([string]$Message) Write-Host ">>> $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host ">>> $Message" -ForegroundColor Yellow }
function Fail {
    param([string]$Message)
    Write-Host "error: $Message" -ForegroundColor Red
    exit 1
}

function Coalesce {
    param(
        [object]$Value,
        [object]$DefaultValue
    )
    if ($null -eq $Value) {
        return $DefaultValue
    }
    return $Value
}

function Get-Arg {
    param(
        [string[]]$ArgsArray,
        [int]$Index,
        [string]$DefaultValue = ''
    )
    if ($null -eq $ArgsArray) {
        return $DefaultValue
    }
    if ($Index -ge 0 -and $Index -lt $ArgsArray.Count) {
        return [string]$ArgsArray[$Index]
    }
    return $DefaultValue
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path $Path -PathType Leaf)) {
        throw "文件不存在: $Path"
    }
    return Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-PythonInvoker {
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) {
        return [PSCustomObject]@{
            Exe = [string]$python.Source
            Args = @()
        }
    }

    $py = Get-Command py -ErrorAction SilentlyContinue
    if ($py) {
        return [PSCustomObject]@{
            Exe = [string]$py.Source
            Args = @('-3')
        }
    }

    throw '未找到 Python 运行时（python/py）。请先安装 Python，或确保 python 在 PATH 中。'
}

function Invoke-Python {
    param(
        [Parameter(Mandatory = $true)][string]$Code,
        [Parameter()][string[]]$Arguments = @()
    )

    $invoker = Get-PythonInvoker
    $exe = [string]$invoker.Exe
    $baseArgs = @()
    if ($null -ne $invoker.Args) {
        $baseArgs = @($invoker.Args)
    }

    $allArgs = @()
    $allArgs += $baseArgs
    $allArgs += @('-c', $Code)
    if ($Arguments) {
        $allArgs += $Arguments
    }

    $output = & $exe @allArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Python 执行失败 (exit=$LASTEXITCODE)"
    }
    return ($output | Out-String).TrimEnd()
}

function Get-StateOauthField {
    param([Parameter(Mandatory = $true)][string]$Field)

    if (-not (Test-Path $StateFile -PathType Leaf)) {
        return ''
    }

    $code = @'
import json
import sys

state_file = sys.argv[1]
field = sys.argv[2]

try:
    with open(state_file, 'r', encoding='utf-8-sig') as f:
        data = json.load(f)
    oauth = data.get('oauthAccount', {})
    value = oauth.get(field, '')
    if value is None:
        value = ''
    print(value)
except Exception:
    print('')
'@

    return Invoke-Python -Code $code -Arguments @($StateFile, $Field)
}

function Export-StateOauthAccount {
    param([Parameter(Mandatory = $true)][string]$OutputPath)

    $code = @'
import json
import sys

state_file = sys.argv[1]
output_path = sys.argv[2]

with open(state_file, 'r', encoding='utf-8-sig') as f:
    data = json.load(f)

oauth = data.get('oauthAccount', {})
with open(output_path, 'w', encoding='utf-8') as f:
    json.dump(oauth, f, indent=2, ensure_ascii=False)
'@

    Invoke-Python -Code $code -Arguments @($StateFile, $OutputPath) | Out-Null
}

function Set-StateOauthAccountFromFile {
    param([Parameter(Mandatory = $true)][string]$OauthPath)

    $code = @'
import json
import sys

state_file = sys.argv[1]
oauth_file = sys.argv[2]

with open(state_file, 'r', encoding='utf-8-sig') as f:
    state = json.load(f)

with open(oauth_file, 'r', encoding='utf-8-sig') as f:
    oauth = json.load(f)

state['oauthAccount'] = oauth

with open(state_file, 'w', encoding='utf-8') as f:
    json.dump(state, f, indent=2, ensure_ascii=False)
'@

    Invoke-Python -Code $code -Arguments @($StateFile, $OauthPath) | Out-Null
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object]$Data
    )
    $json = $Data | ConvertTo-Json -Depth 100
    Set-Content -Path $Path -Encoding UTF8 -Value $json
}

function Get-CurrentEmail {
    try {
        $email = Get-StateOauthField -Field 'emailAddress'
        if ([string]::IsNullOrWhiteSpace($email)) {
            return 'unknown'
        }
        return [string]$email
    }
    catch {
        return 'unknown'
    }
}

function Get-CurrentDisplay {
    try {
        $name = Get-StateOauthField -Field 'displayName'
        $email = Get-StateOauthField -Field 'emailAddress'
        if ([string]::IsNullOrWhiteSpace($name)) { $name = '?' }
        if ([string]::IsNullOrWhiteSpace($email)) { $email = '?' }
        return "$name <$email>"
    }
    catch {
        return 'unknown'
    }
}

function Get-AccountInfo {
    param([Parameter(Mandatory = $true)][string]$OauthPath)
    try {
        $oauth = Read-JsonFile -Path $OauthPath
        return [PSCustomObject]@{
            Email = [string](Coalesce $oauth.emailAddress 'unknown')
            Display = [string](Coalesce $oauth.displayName '')
            Billing = [string](Coalesce $oauth.billingType '')
        }
    }
    catch {
        return [PSCustomObject]@{ Email = 'unknown'; Display = ''; Billing = '' }
    }
}

function Get-CredInfo {
    param([Parameter(Mandatory = $true)][string]$CredPath)
    try {
        $cred = Read-JsonFile -Path $CredPath
        $oauth = $cred.claudeAiOauth
        $expiresAt = $oauth.expiresAt
        $expStr = '?'
        if ($expiresAt) {
            $expStr = [DateTimeOffset]::FromUnixTimeMilliseconds([int64]$expiresAt).ToLocalTime().ToString('MM-dd HH:mm')
        }
        return [PSCustomObject]@{
            Subscription = [string](Coalesce $oauth.subscriptionType '?')
            Tier = [string](Coalesce $oauth.rateLimitTier '')
            Expires = $expStr
            AccessToken = [string](Coalesce $oauth.accessToken '')
        }
    }
    catch {
        return [PSCustomObject]@{ Subscription = '?'; Tier = ''; Expires = '?'; AccessToken = '' }
    }
}

function Set-ActiveAccountFromDir {
    param([Parameter(Mandatory = $true)][string]$AccountDir)

    $credSrc = Join-Path $AccountDir 'credentials.json'
    $oauthSrc = Join-Path $AccountDir 'oauth_account.json'
    if (-not (Test-Path $credSrc -PathType Leaf)) { throw "缺少 $credSrc" }
    if (-not (Test-Path $oauthSrc -PathType Leaf)) { throw "缺少 $oauthSrc" }
    if (-not (Test-Path $StateFile -PathType Leaf)) { throw "缺少 $StateFile，请先完成 claude 登录" }

    Copy-Item -Force -Path $credSrc -Destination $CredFile
    Set-StateOauthAccountFromFile -OauthPath $oauthSrc
}

function Get-UsageSummary {
    param([Parameter(Mandatory = $true)][string]$AccessToken)

    if ([string]::IsNullOrWhiteSpace($AccessToken)) {
        throw 'accessToken 为空'
    }

    $headers = @{
        Authorization = "Bearer $AccessToken"
        'anthropic-beta' = 'oauth-2025-04-20'
        'User-Agent' = 'claude-switch/1.0'
    }

    $data = Invoke-RestMethod -Method Get -Uri 'https://api.anthropic.com/api/oauth/usage' -Headers $headers

    $sessionStr = '?'
    $weeklyStr = '?'
    $extraInfo = ''
    $extraPercent = -1

    if ($null -ne $data.five_hour -and $null -ne $data.five_hour.utilization) {
        $sessionStr = "{0}%" -f [int][Math]::Round([double]$data.five_hour.utilization)
    }

    if ($null -ne $data.seven_day -and $null -ne $data.seven_day.utilization) {
        $weeklyStr = "{0}%" -f [int][Math]::Round([double]$data.seven_day.utilization)
    }

    if ($null -ne $data.extra_usage -and $data.extra_usage.is_enabled -and $null -ne $data.extra_usage.used_credits -and $null -ne $data.extra_usage.monthly_limit) {
        $used = [double]$data.extra_usage.used_credits
        $limit = [double]$data.extra_usage.monthly_limit
        if ($limit -gt 0) {
            $extraPercent = [int][Math]::Round(($used / $limit) * 100)
            $extraInfo = "Extra: `${0:N0} / `${1:N0} ({2}%)" -f $used, $limit, $extraPercent
        }
    }

    return [PSCustomObject]@{
        Session = $sessionStr
        Weekly = $weeklyStr
        ExtraInfo = $extraInfo
        ExtraPercent = $extraPercent
    }
}

function Get-UsagePercentValue {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -eq '?') {
        return -1
    }

    $normalized = $Value.Trim().TrimEnd('%')
    $number = 0
    if ([int]::TryParse($normalized, [ref]$number)) {
        return $number
    }
    return -1
}

function Get-AccountUsageSnapshot {
    param([Parameter(Mandatory = $true)][string]$AccountDir)

    try {
        Set-ActiveAccountFromDir -AccountDir $AccountDir
        $cred = Get-CredInfo -CredPath $CredFile
        $usage = Get-UsageSummary -AccessToken $cred.AccessToken

        $sessionInt = Get-UsagePercentValue -Value $usage.Session
        $weeklyInt = Get-UsagePercentValue -Value $usage.Weekly
        $extraInt = [int](Coalesce $usage.ExtraPercent -1)

        $formatted = "{0}/{1}" -f $usage.Session, $usage.Weekly
        if ($extraInt -ge 0) {
            $formatted = "$formatted +$extraInt%"
        }

        return [PSCustomObject]@{
            SessionInt = $sessionInt
            WeeklyInt = $weeklyInt
            ExtraInt = $extraInt
            Formatted = $formatted
        }
    }
    catch {
        return [PSCustomObject]@{
            SessionInt = -1
            WeeklyInt = -1
            ExtraInt = -1
            Formatted = '?'
        }
    }
}

function Invoke-Probe {
    $output = & claude -p 'ok' --output-format json --max-turns 1 --model haiku 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -and [string]::IsNullOrWhiteSpace($output)) {
        return 'FAILED'
    }

    try {
        $obj = $output | ConvertFrom-Json
        if ($obj.is_error) {
            $msg = [string](Coalesce $obj.result '')
            if ($msg.ToLowerInvariant().Contains('rate') -or $msg.ToLowerInvariant().Contains('limit') -or $msg.ToLowerInvariant().Contains('overloaded')) {
                return 'RATE_LIMITED'
            }
            if ($msg.Length -gt 80) { $msg = $msg.Substring(0, 80) }
            return "ERROR:$msg"
        }
        $cost = [double](Coalesce $obj.total_cost_usd 0)
        return ('OK:{0:F4}' -f $cost)
    }
    catch {
        return 'PARSE_ERROR'
    }
}

function Invoke-WithAccountRestore {
    param([Parameter(Mandatory = $true)][scriptblock]$Action)

    $credBackup = if (Test-Path $CredFile -PathType Leaf) { Get-Content -Path $CredFile -Raw -Encoding UTF8 } else { $null }
    $stateBackup = if (Test-Path $StateFile -PathType Leaf) { Get-Content -Path $StateFile -Raw -Encoding UTF8 } else { $null }

    try {
        & $Action
    }
    finally {
        if ($null -ne $credBackup) {
            Set-Content -Path $CredFile -Encoding UTF8 -Value $credBackup
        }
        if ($null -ne $stateBackup) {
            Set-Content -Path $StateFile -Encoding UTF8 -Value $stateBackup
        }
    }
}

function Cmd-Save {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) {
        Fail '用法: claude-switch save <名称>'
    }
    if (-not (Test-Path $CredFile -PathType Leaf)) {
        Fail "未找到 $CredFile，请先登录"
    }
    if (-not (Test-Path $StateFile -PathType Leaf)) {
        Fail "未找到 $StateFile，请先登录"
    }

    $dir = Join-Path $StoreDir $Name
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Copy-Item -Force -Path $CredFile -Destination (Join-Path $dir 'credentials.json')

    Export-StateOauthAccount -OutputPath (Join-Path $dir 'oauth_account.json')

    Write-Ok "已保存账号 $Name ($(Get-CurrentEmail))"
}

function Cmd-Switch {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) {
        Fail '用法: claude-switch <名称>'
    }
    $dir = Join-Path $StoreDir $Name
    if (-not (Test-Path $dir -PathType Container)) {
        Fail "账号 '$Name' 不存在。用 claude-switch ls 查看已保存账号"
    }

    $oldEmail = Get-CurrentEmail
    Set-ActiveAccountFromDir -AccountDir $dir
    $newEmail = Get-CurrentEmail
    Write-Ok "已切换: $oldEmail -> $newEmail"
}

function Cmd-Ls {
    $currentEmail = Get-CurrentEmail
    Write-Host '已保存的账号:'
    Write-Host ''

    $dirs = Get-ChildItem -Path $StoreDir -Directory -ErrorAction SilentlyContinue
    if (-not $dirs) {
        Write-Warn '(空) 用 claude-switch save <名称> 保存当前账号'
        return
    }

    foreach ($dir in $dirs) {
        $name = $dir.Name
        $acct = Get-AccountInfo -OauthPath (Join-Path $dir.FullName 'oauth_account.json')
        $cred = Get-CredInfo -CredPath (Join-Path $dir.FullName 'credentials.json')
        $currentMark = if ($acct.Email -eq $currentEmail) { ' ← current' } else { '' }
        $tier = if ([string]::IsNullOrWhiteSpace($cred.Tier) -or $cred.Tier -eq 'default_claude_ai') { '' } else { " ($($cred.Tier))" }
        if ($acct.Email -eq $currentEmail) {
            Write-Host ("  * {0}  {1}  [{2}]{3}  exp:{4}{5}" -f $name, $acct.Email, $cred.Subscription, $tier, $cred.Expires, $currentMark) -ForegroundColor Green
        }
        else {
            Write-Host ("    {0}  {1}  [{2}]{3}  exp:{4}{5}" -f $name, $acct.Email, $cred.Subscription, $tier, $cred.Expires, $currentMark)
        }
    }
}

function Cmd-Check {
    $currentEmail = Get-CurrentEmail

    Invoke-WithAccountRestore {
        Write-Host '检测各账号可用性...'
        Write-Host ''

        $dirs = Get-ChildItem -Path $StoreDir -Directory -ErrorAction SilentlyContinue
        foreach ($dir in $dirs) {
            $name = $dir.Name
            $acct = Get-AccountInfo -OauthPath (Join-Path $dir.FullName 'oauth_account.json')

            try {
                Set-ActiveAccountFromDir -AccountDir $dir.FullName
                $probe = Invoke-Probe
            }
            catch {
                $probe = "ERROR:$($_.Exception.Message)"
            }

            Write-Host -NoNewline ("  {0}  ({1})  " -f $name, $acct.Email)

            switch -Wildcard ($probe) {
                'OK:*' {
                    $cost = $probe.Substring(3)
                    Write-Host -NoNewline 'OK' -ForegroundColor Green
                    Write-Host ("  (probe cost: `${0})" -f $cost) -ForegroundColor DarkGray
                }
                'RATE_LIMITED' {
                    Write-Host 'RATE LIMITED' -ForegroundColor Red
                }
                'ERROR:*' {
                    $detail = $probe.Substring(6)
                    Write-Host -NoNewline 'ERROR' -ForegroundColor Yellow
                    Write-Host ("  {0}" -f $detail) -ForegroundColor DarkGray
                }
                'FAILED' {
                    Write-Host -NoNewline 'FAILED' -ForegroundColor Yellow
                    Write-Host '  (无法解析响应)' -ForegroundColor DarkGray
                }
                default {
                    Write-Host -NoNewline '???' -ForegroundColor Yellow
                    Write-Host ("  {0}" -f $probe) -ForegroundColor DarkGray
                }
            }
        }

        Write-Host ''
    }

    Write-Ok "已恢复到原账号 ($currentEmail)"
}

function Cmd-Rm {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) {
        Fail '用法: claude-switch rm <名称>'
    }
    $dir = Join-Path $StoreDir $Name
    if (-not (Test-Path $dir -PathType Container)) {
        Fail "账号 '$Name' 不存在"
    }
    Remove-Item -Recurse -Force -Path $dir
    Write-Ok "已删除账号 $Name"
}

function Cmd-Current {
    Write-Host ("当前账号: {0}" -f (Get-CurrentDisplay))
}

function Cmd-Usage {
    Write-Host '获取使用情况...'
    $cred = Get-CredInfo -CredPath $CredFile
    Write-Host '正在查询 API...'
    $usage = Get-UsageSummary -AccessToken $cred.AccessToken
    Write-Host ''
    Write-Host '使用情况:'
    Write-Host ("  Session (5小时): {0}" -f $usage.Session)
    Write-Host ("  Weekly (7天): {0}" -f $usage.Weekly)
    if (-not [string]::IsNullOrWhiteSpace($usage.ExtraInfo)) {
        Write-Host ("  {0}" -f $usage.ExtraInfo)
    }
    Write-Host ''
    Cmd-Current
}

function Cmd-UsageAll {
    $currentEmail = Get-CurrentEmail

    Invoke-WithAccountRestore {
        Write-Host '获取各账号使用情况...'
        Write-Host ''

        $dirs = Get-ChildItem -Path $StoreDir -Directory -ErrorAction SilentlyContinue
        foreach ($dir in $dirs) {
            $name = $dir.Name
            $acct = Get-AccountInfo -OauthPath (Join-Path $dir.FullName 'oauth_account.json')

            try {
                $snapshot = Get-AccountUsageSnapshot -AccountDir $dir.FullName

                $color = 'Green'
                if ($name -eq 'main') {
                    $color = 'DarkGray'
                }
                elseif ($snapshot.SessionInt -eq -1 -or $snapshot.WeeklyInt -eq -1) {
                    $color = 'Yellow'
                }
                elseif ($snapshot.SessionInt -ge 100 -or $snapshot.WeeklyInt -ge 100) {
                    $color = 'Red'
                }

                $currentMark = if ($acct.Email -eq $currentEmail) { ' ← current' } else { '' }
                Write-Host ("  {0} ({1})  {2}{3}" -f $name, $acct.Email, $snapshot.Formatted, $currentMark) -ForegroundColor $color
            }
            catch {
                Write-Host ("  {0} ({1})  ERROR" -f $name, $acct.Email) -ForegroundColor Yellow
            }
        }
    }

    Write-Ok "已恢复到原账号 ($(Get-CurrentEmail))"
}

function Cmd-Login {
    param([string]$Name)
    Write-Info '正在启动 Claude 登录...'
    & claude auth login
    if ($LASTEXITCODE -ne 0) {
        Fail "登录失败 (exit code: $LASTEXITCODE)"
    }

    Write-Ok ("登录成功: {0}" -f (Get-CurrentDisplay))

    if (-not [string]::IsNullOrWhiteSpace($Name)) {
        Cmd-Save -Name $Name
        return
    }

    $inputName = Read-Host '>>> 保存为哪个名称? (留空跳过)'
    if (-not [string]::IsNullOrWhiteSpace($inputName)) {
        Cmd-Save -Name $inputName
    }
}

function Cmd-Interactive {
    $dirs = Get-ChildItem -Path $StoreDir -Directory -ErrorAction SilentlyContinue
    if (-not $dirs) {
        Write-Warn '(没有保存的账号)'
        Write-Host '使用 claude-switch save <名称> 或 claude-switch login [名称]'
        exit 1
    }

    $currentEmail = Get-CurrentEmail
    Write-Host '选择要切换的账号:'
    Write-Host ''

    $indexMap = @{}
    $i = 1

    Invoke-WithAccountRestore {
        foreach ($dir in $dirs) {
            $name = $dir.Name
            $acct = Get-AccountInfo -OauthPath (Join-Path $dir.FullName 'oauth_account.json')
            $usage = Get-AccountUsageSnapshot -AccountDir $dir.FullName

            $color = 'Green'
            if ($name -eq 'main') {
                $color = 'DarkGray'
            }
            elseif ($usage.SessionInt -eq -1 -or $usage.WeeklyInt -eq -1) {
                $color = 'Yellow'
            }
            elseif ($usage.SessionInt -ge 100 -or $usage.WeeklyInt -ge 100) {
                $color = 'Red'
            }

            $currentMark = if ($acct.Email -eq $currentEmail) { ' ← 当前' } else { '' }
            Write-Host ("  {0}. {1}  {2}  {3}{4}" -f $i, $name, $acct.Email, $usage.Formatted, $currentMark) -ForegroundColor $color

            $indexMap[$i] = $name
            $i++
        }
    }

    Write-Host ''
    Write-Host '  0. 取消'
    Write-Host ''
    $choiceRaw = Read-Host ">>> 选择账号 (0-$($dirs.Count))"
    $choice = 0
    if (-not [int]::TryParse($choiceRaw, [ref]$choice)) {
        Fail '请输入数字'
    }
    if ($choice -eq 0) {
        Write-Ok '已取消'
        return
    }
    if (-not $indexMap.ContainsKey($choice)) {
        Fail '无效的选择'
    }
    Cmd-Switch -Name $indexMap[$choice]
}

function Show-Help {
    Write-Host 'claude-switch: 一键切换 Claude Code 账号'
    Write-Host ''
    Write-Host '用法:'
    Write-Host '  claude-switch login [名称]   登录新账号并保存'
    Write-Host '  claude-switch save <名称>    保存当前登录的账号'
    Write-Host '  claude-switch <名称>         切换到指定账号'
    Write-Host '  claude-switch ls             列出所有账号 (含订阅类型)'
    Write-Host '  claude-switch check          检测各账号可用性 (发探测请求)'
    Write-Host '  claude-switch usage          显示当前账号使用情况'
    Write-Host '  claude-switch usage-all      显示所有账号使用情况'
    Write-Host '  claude-switch interactive    交互式选择账号'
    Write-Host '  claude-switch rm <名称>      删除已保存账号'
    Write-Host '  claude-switch current        显示当前账号'
    Write-Host ''
    Write-Host '示例:'
    Write-Host '  claude-switch                # 交互式选择账号 (显示额度)'
    Write-Host '  claude-switch login acc2     # 登录新账号并保存为 acc2'
    Write-Host '  claude-switch login          # 登录新账号，交互式输入名称'
    Write-Host '  claude-switch acc1           # 一键切换到 acc1'
    Write-Host '  claude-switch check          # 检测哪些账号还有额度'
    Write-Host '  claude-switch usage-all      # 显示所有账号额度'
}

try {
    $cmd = if ($null -ne $CliArgs -and $CliArgs.Count -gt 0) { $CliArgs[0] } else { '' }
    switch ($cmd) {
        '' { Cmd-Interactive }
        'save' { Cmd-Save -Name (Get-Arg -ArgsArray $CliArgs -Index 1) }
        'login' { Cmd-Login -Name (Get-Arg -ArgsArray $CliArgs -Index 1) }
        'ls' { Cmd-Ls }
        'list' { Cmd-Ls }
        'check' { Cmd-Check }
        'rm' { Cmd-Rm -Name (Get-Arg -ArgsArray $CliArgs -Index 1) }
        'current' { Cmd-Current }
        'usage' { Cmd-Usage }
        'usage-all' { Cmd-UsageAll }
        'interactive' { Cmd-Interactive }
        '-h' { Show-Help }
        '--help' { Show-Help }
        'help' { Show-Help }
        default { Cmd-Switch -Name $cmd }
    }
}
catch {
    Fail $_.Exception.Message
}
