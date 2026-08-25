<#
  04_로컬을_깃허브에_반영.ps1

  로컬 토성 폴더의 내용으로 GitHub 저장소를 전부 덮어씁니다.
  실행이 끝나면 저장소의 내용 = 토성 폴더의 내용 (완전히 동일) 이 됩니다.

  방식
    - 일반 커밋으로 교체합니다. force push 를 쓰지 않습니다.
    - 결과물은 "로컬 내용만" 으로 동일하며, 지난 커밋은 이력에만 남아
      만약의 경우 되돌릴 수 있습니다. 잃는 것은 없고 안전망만 생깁니다.
    - 저장소에만 있고 로컬에 없는 파일은 삭제로 기록됩니다.
      커밋 전에 삭제 예정 목록을 전부 보여주고 확인을 받습니다.

  실행 방법
    powershell -ExecutionPolicy Bypass -File .\04_로컬을_깃허브에_반영.ps1

  옵션
    -Yes             확인 없이 바로 진행
    -Branch main     대상 브랜치 (기본 main)
    -PureOverwrite   .claude\settings.json 자동 생성을 끄고 로컬 그대로만 반영
#>

[CmdletBinding()]
param(
    [string]$TargetDir = (Join-Path $env:USERPROFILE 'Desktop\토성'),
    [string]$RemoteUrl = 'https://github.com/silro742/BIM.git',
    [string]$Branch    = 'main',
    [switch]$Yes,
    [switch]$PureOverwrite
)

$ErrorActionPreference = 'Stop'

function Write-Step { param([string]$T) ; Write-Host '' ; Write-Host ('== ' + $T) -ForegroundColor Cyan }
function Write-Ok   { param([string]$T) ; Write-Host ('   [OK] ' + $T) -ForegroundColor Green }
function Write-Warn2{ param([string]$T) ; Write-Host ('   [!]  ' + $T) -ForegroundColor Yellow }
function Write-Bad  { param([string]$T) ; Write-Host ('   [X]  ' + $T) -ForegroundColor Red }

Write-Host '================================================================'
Write-Host ' 로컬 토성 -> GitHub 전체 반영'
Write-Host '================================================================'

# ---------------------------------------------------------------- 1
Write-Step '1/6  사전 확인'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Bad 'git 이 없습니다. https://git-scm.com/downloads/win'
    exit 1
}
if (-not (Test-Path $TargetDir)) {
    Write-Bad ('폴더가 없습니다 : ' + $TargetDir)
    exit 1
}
Set-Location $TargetDir
Write-Ok ('대상 폴더 : ' + $TargetDir)

# 한글 파일명이 8진수로 깨져 보이지 않게
& git config core.quotepath false

if (-not (Test-Path (Join-Path $TargetDir '.git'))) {
    Write-Warn2 '아직 저장소에 연결되어 있지 않습니다. 지금 연결합니다.'
    & git init -q -b $Branch
    & git remote add origin $RemoteUrl
    & git fetch origin $Branch
    if ($LASTEXITCODE -ne 0) { Write-Bad '원격 가져오기 실패. 인증/네트워크를 확인하세요.' ; exit 1 }
    $up = 'origin/' + $Branch
    & git reset -q $up
    & git branch ('--set-upstream-to=' + $up) $Branch | Out-Null
    Write-Ok '연결 완료 (작업 파일은 건드리지 않음)'
} else {
    Write-Ok '이미 저장소에 연결됨'
    & git fetch origin $Branch
    if ($LASTEXITCODE -ne 0) { Write-Bad '원격 가져오기 실패.' ; exit 1 }
}

# 커밋 작성자 정보
$uname = (& git config user.name)
if (-not $uname) {
    & git config user.name  'silro742'
    & git config user.email 'silro742@gmail.com'
    Write-Ok '커밋 작성자 정보를 이 저장소에 설정했습니다.'
}

# ---------------------------------------------------------------- 2
Write-Step '2/6  대용량 파일 검사 (GitHub 은 100MB 초과 파일을 거부)'

$big = @(Get-ChildItem $TargetDir -Recurse -File -Force |
         Where-Object { $_.FullName -notlike '*\.git\*' -and $_.Length -gt 45MB } |
         Sort-Object Length -Descending)
$blocked = @($big | Where-Object { $_.Length -gt 95MB })

if ($blocked.Count -gt 0) {
    Write-Bad '100MB 에 가까운 파일이 있어 푸시가 거부됩니다:'
    foreach ($f in $blocked) { Write-Bad ('  {0:N0} MB  {1}' -f ($f.Length/1MB), $f.FullName) }
    Write-Bad '해당 파일을 폴더 밖으로 옮기거나 .gitignore 에 추가한 뒤 다시 실행하세요.'
    exit 1
}
if ($big.Count -gt 0) {
    Write-Warn2 '큰 파일이 있습니다 (푸시는 되지만 느립니다):'
    foreach ($f in $big) { Write-Warn2 ('  {0:N0} MB  {1}' -f ($f.Length/1MB), $f.Name) }
} else {
    Write-Ok '45MB 초과 파일 없음'
}

# ---------------------------------------------------------------- 3
Write-Step '3/6  팀 기능 설정 확인'

if (-not $PureOverwrite) {
    $cfgDir  = Join-Path $TargetDir '.claude'
    $cfgFile = Join-Path $cfgDir 'settings.json'
    if (-not (Test-Path $cfgFile)) {
        New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
        $body = @'
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
'@
        [System.IO.File]::WriteAllText($cfgFile, $body, (New-Object System.Text.UTF8Encoding($false)))
        Write-Ok '.claude\settings.json 생성 (Agent Teams 활성화)'
        Write-Ok '이 파일이 있어야 벼리팀 같은 팀 기능이 동작합니다.'
    } else {
        Write-Ok '.claude\settings.json 이미 있음 - 그대로 둡니다'
    }
} else {
    Write-Warn2 '-PureOverwrite : 로컬 내용만 그대로 반영합니다'
}

# ---------------------------------------------------------------- 4
Write-Step '4/6  변경 내용 산출'

& git add -A

$added    = @(& git diff --cached --diff-filter=A --name-only)
$modified = @(& git diff --cached --diff-filter=M --name-only)
$deleted  = @(& git diff --cached --diff-filter=D --name-only)

Write-Host ''
Write-Host ('  추가 : {0} 개' -f $added.Count)    -ForegroundColor Green
Write-Host ('  수정 : {0} 개' -f $modified.Count) -ForegroundColor Yellow
Write-Host ('  삭제 : {0} 개' -f $deleted.Count)  -ForegroundColor Red

if (($added.Count + $modified.Count + $deleted.Count) -eq 0) {
    Write-Host ''
    Write-Ok '저장소가 이미 로컬과 동일합니다. 할 일이 없습니다.'
    exit 0
}

if ($deleted.Count -gt 0) {
    Write-Host ''
    Write-Host '  --- 저장소에서 삭제될 파일 (로컬에 없는 것) ---' -ForegroundColor Red
    foreach ($f in $deleted) { Write-Host ('    - ' + $f) -ForegroundColor Red }
    Write-Host ''
    Write-Host '  이 파일들은 커밋 이력에는 남으므로 나중에 복구할 수 있습니다.' -ForegroundColor DarkGray
}

if ($added.Count -gt 0) {
    Write-Host ''
    Write-Host '  --- 새로 올라갈 파일 (최대 30개 표시) ---' -ForegroundColor Green
    foreach ($f in ($added | Select-Object -First 30)) { Write-Host ('    + ' + $f) }
    if ($added.Count -gt 30) { Write-Host ('    ... 외 {0} 개' -f ($added.Count - 30)) }
}

# ---------------------------------------------------------------- 5
Write-Step '5/6  확인'

if (-not $Yes) {
    Write-Host ''
    Write-Host ('  브랜치 {0} 의 내용을 위와 같이 로컬과 동일하게 만듭니다.' -f $Branch)
    $ans = Read-Host '  진행할까요? (Y/N)'
    if ($ans -notmatch '^[Yy]') {
        & git reset -q
        Write-Host '취소했습니다. 스테이징을 되돌렸습니다. 파일은 그대로입니다.'
        exit 1
    }
} else {
    Write-Ok '-Yes 지정됨 - 확인 생략'
}

# ---------------------------------------------------------------- 6
Write-Step '6/6  커밋 및 푸시'

$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
$msg   = @"
로컬 토성 폴더 전체 반영 ($stamp)

로컬 작업본을 저장소의 기준으로 삼는다.
추가 $($added.Count) / 수정 $($modified.Count) / 삭제 $($deleted.Count)

이 커밋 이후 저장소 내용은 로컬 토성 폴더와 동일하다.
"@

& git commit -q -m $msg
if ($LASTEXITCODE -ne 0) { Write-Bad '커밋 실패' ; exit 1 }
Write-Ok ('커밋 완료 : ' + ((& git log -1 --format='%h %s') -join ' '))

Write-Host '   푸시 중... (인증 창이 뜨면 GitHub 계정으로 로그인하세요)'
$pushed = $false
foreach ($delay in @(0, 2, 4, 8, 16)) {
    if ($delay -gt 0) {
        Write-Warn2 ('재시도 대기 ' + $delay + '초...')
        Start-Sleep -Seconds $delay
    }
    & git push -u origin $Branch
    if ($LASTEXITCODE -eq 0) { $pushed = $true ; break }
}

if (-not $pushed) {
    Write-Bad '푸시에 실패했습니다.'
    Write-Bad '커밋은 로컬에 남아 있습니다. 네트워크/인증 확인 후 아래를 실행하세요:'
    Write-Bad ('  git push -u origin ' + $Branch)
    exit 1
}

Write-Host ''
Write-Host '================================================================'
Write-Host ' 완료' -ForegroundColor Green
Write-Host '================================================================'
Write-Host ''
Write-Host ('  저장소 {0} 의 내용이 이제 로컬 토성 폴더와 동일합니다.' -f $Branch)
Write-Host ''
Write-Host '  확인 : https://github.com/silro742/BIM'
Write-Host ''
Write-Host '  앞으로는 이 폴더에서 claude 를 실행하면 됩니다:'
Write-Host ('    cd "' + $TargetDir + '"')
Write-Host '    claude'
Write-Host ''
Write-Host '  작업이 끝날 때마다 "커밋하고 푸시해줘" 라고 하시면 됩니다.'
Write-Host ''
