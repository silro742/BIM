<#
  02_로컬복귀_설치.ps1

  로컬 PC 에서 Claude Code 를 다시 쓸 수 있게 준비합니다.
    1) Claude Code 설치 여부 확인, 없으면 설치
    2) ~\.claude\settings.json 을 백업한 뒤 Agent Teams 플래그를 병합
    3) 설치 상태 검증

  기존 settings.json 은 덮어쓰지 않고 항목만 추가하며,
  변경 전 원본을 .bak-날짜시각 으로 백업합니다.

  실행 방법
    powershell -ExecutionPolicy Bypass -File .\02_로컬복귀_설치.ps1
    확인 없이 진행하려면  -Yes  를 붙이세요.
#>

[CmdletBinding()]
param([switch]$Yes)

$ErrorActionPreference = 'Stop'

function Write-Step { param([string]$T) ; Write-Host '' ; Write-Host ('== ' + $T) -ForegroundColor Cyan }
function Write-Ok   { param([string]$T) ; Write-Host ('   [OK] ' + $T) -ForegroundColor Green }
function Write-Warn2{ param([string]$T) ; Write-Host ('   [!]  ' + $T) -ForegroundColor Yellow }

function Update-PathFromRegistry {
    $machine = [System.Environment]::GetEnvironmentVariable('Path','Machine')
    $user    = [System.Environment]::GetEnvironmentVariable('Path','User')
    $env:Path = (@($machine, $user, $env:Path) | Where-Object { $_ }) -join ';'
}

Write-Host '================================================================'
Write-Host ' Claude Code 로컬 복귀 설치'
Write-Host '================================================================'

# ---------------------------------------------------------------- 1
Write-Step '1/3  Claude Code 설치 확인'

Update-PathFromRegistry
$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue

if ($claudeCmd) {
    Write-Ok ('이미 설치됨 : ' + $claudeCmd.Source)
    Write-Ok ('버전        : ' + ((& claude --version 2>&1) -join ' '))
} else {
    Write-Warn2 'Claude Code 가 설치되어 있지 않습니다.'
    Write-Host  '   공식 설치 스크립트를 내려받아 실행합니다:'
    Write-Host  '     https://claude.ai/install.ps1'
    if (-not $Yes) {
        $ans = Read-Host '   진행할까요? (Y/N)'
        if ($ans -notmatch '^[Yy]') { Write-Host '취소했습니다.' ; exit 1 }
    }
    try {
        $installer = Invoke-RestMethod -Uri 'https://claude.ai/install.ps1' -UseBasicParsing
        & ([scriptblock]::Create($installer))
    } catch {
        Write-Host ''
        Write-Host ('설치 실패: ' + $_.Exception.Message) -ForegroundColor Red
        Write-Host 'PowerShell 에서 아래를 직접 실행해 보세요:' -ForegroundColor Red
        Write-Host '  irm https://claude.ai/install.ps1 | iex' -ForegroundColor Red
        exit 1
    }
    Update-PathFromRegistry
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($claudeCmd) {
        Write-Ok ('설치 완료 : ' + $claudeCmd.Source)
    } else {
        Write-Warn2 '설치는 끝났지만 현재 창에서 claude 를 찾지 못했습니다.'
        Write-Warn2 'PowerShell 창을 닫았다 다시 열고 이 스크립트를 한 번 더 실행하세요.'
    }
}

# ---------------------------------------------------------------- 2
Write-Step '2/3  Agent Teams 활성화 (settings.json)'

$claudeDir    = Join-Path $env:USERPROFILE '.claude'
$settingsPath = Join-Path $claudeDir 'settings.json'

if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null
    Write-Ok ('폴더 생성 : ' + $claudeDir)
}

$settings = $null
if (Test-Path $settingsPath) {
    $backup = $settingsPath + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
    Copy-Item $settingsPath $backup -Force
    Write-Ok ('원본 백업 : ' + $backup)
    try {
        $raw = Get-Content $settingsPath -Raw -Encoding UTF8
        if ($raw.Trim()) { $settings = $raw | ConvertFrom-Json }
    } catch {
        Write-Warn2 'settings.json 을 해석하지 못했습니다. 백업은 남아 있습니다.'
        Write-Warn2 ('사유: ' + $_.Exception.Message)
        Write-Warn2 '파일을 직접 고친 뒤 다시 실행하세요. 중단합니다.'
        exit 1
    }
}
if ($null -eq $settings) { $settings = New-Object PSObject }

if (-not $settings.PSObject.Properties['env']) {
    $settings | Add-Member -NotePropertyName 'env' -NotePropertyValue (New-Object PSObject)
}
if ($settings.env.PSObject.Properties['CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS']) {
    $settings.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = '1'
} else {
    $settings.env | Add-Member -NotePropertyName 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' -NotePropertyValue '1'
}

$json = $settings | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($settingsPath, $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Ok ('기록 완료 : ' + $settingsPath)
Write-Host ''
Write-Host $json

# ---------------------------------------------------------------- 3
Write-Step '3/3  검증'

$verify = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($verify.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS -eq '1') {
    Write-Ok '팀 기능 플래그가 정상으로 기록되었습니다.'
} else {
    Write-Warn2 '플래그 확인에 실패했습니다. settings.json 을 직접 확인하세요.'
}

$gitBash = 'C:\Program Files\Git\bin\bash.exe'
if (Test-Path $gitBash) {
    Write-Ok 'Git for Windows 감지됨 - Bash 도구를 사용할 수 있습니다.'
} else {
    Write-Warn2 'Git for Windows 가 없습니다. 없어도 동작하지만 PowerShell 로만 명령이 실행됩니다.'
    Write-Warn2 '권장 설치: https://git-scm.com/downloads/win'
}

Write-Host ''
Write-Host '================================================================'
Write-Host ' 완료. 다음 순서로 사용하세요.' -ForegroundColor Green
Write-Host '================================================================'
Write-Host ''
Write-Host '  1) PowerShell 창을 새로 엽니다 (PATH 반영)'
Write-Host '  2) cd "$env:USERPROFILE\Desktop\토성"'
Write-Host '  3) claude'
Write-Host ''
Write-Host '  이제 토성 폴더 전체를 직접 읽고 쓸 수 있습니다.'
Write-Host '  팀을 만들 때는 이렇게 말하세요:'
Write-Host '     "팀원 3명을 띄워서 06 표준횡단 앱을 각각 다른 관점으로 검토해줘"'
Write-Host ''
Write-Host '  휴대폰이나 웹에서 진행 상황을 보려면 세션 안에서:  /remote-control'
Write-Host ''
