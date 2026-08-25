<#
  03_토성_깃허브_연결.ps1

  바탕화면 토성 폴더를 GitHub 저장소(silro742/BIM)와 연결합니다.
  연결되면 로컬 Claude 세션 하나가 "로컬 파일"과 "깃허브" 양쪽을 동시에 다룹니다.

  안전성
    - 작업 파일을 덮어쓰거나 삭제하지 않습니다 (git reset 은 인덱스만 조정)
    - 자동으로 커밋하거나 푸시하지 않습니다
    - 이미 깃 저장소인 경우 아무것도 바꾸지 않고 현황만 보고합니다
    - 리눅스에서 동일 시퀀스로 비파괴 동작을 검증했습니다

  실행 방법
    powershell -ExecutionPolicy Bypass -File .\03_토성_깃허브_연결.ps1

  다른 폴더에 적용하려면
    powershell -ExecutionPolicy Bypass -File .\03_토성_깃허브_연결.ps1 -TargetDir "D:\작업\내폴더"
#>

[CmdletBinding()]
param(
    [string]$TargetDir = (Join-Path $env:USERPROFILE 'Desktop\토성'),
    [string]$RemoteUrl = 'https://github.com/silro742/BIM.git',
    [string]$Branch    = 'main'
)

$ErrorActionPreference = 'Stop'

function Write-Step { param([string]$T) ; Write-Host '' ; Write-Host ('== ' + $T) -ForegroundColor Cyan }
function Write-Ok   { param([string]$T) ; Write-Host ('   [OK] ' + $T) -ForegroundColor Green }
function Write-Warn2{ param([string]$T) ; Write-Host ('   [!]  ' + $T) -ForegroundColor Yellow }
function Write-Bad  { param([string]$T) ; Write-Host ('   [X]  ' + $T) -ForegroundColor Red }

Write-Host '================================================================'
Write-Host ' 토성 폴더 <-> GitHub 연결'
Write-Host '================================================================'

# ---------------------------------------------------------------- 1
Write-Step '1/4  사전 확인'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Bad 'git 이 설치되어 있지 않습니다.'
    Write-Bad '설치: https://git-scm.com/downloads/win'
    exit 1
}
Write-Ok ('git : ' + ((& git --version) -join ' '))

if (-not (Test-Path $TargetDir)) {
    Write-Bad ('폴더가 없습니다 : ' + $TargetDir)
    Write-Bad '-TargetDir 로 올바른 경로를 지정하세요.'
    exit 1
}
Write-Ok ('대상 폴더 : ' + $TargetDir)

$fileCount = @(Get-ChildItem $TargetDir -Recurse -File -Force).Count
Write-Ok ('폴더 안 파일 수 : ' + $fileCount)

Set-Location $TargetDir

if (Test-Path (Join-Path $TargetDir '.git')) {
    Write-Warn2 '이미 깃 저장소입니다. 아무것도 변경하지 않고 현황만 보고합니다.'
    Write-Host ''
    Write-Host '--- 원격 ---'      ; & git remote -v
    Write-Host '--- 브랜치 ---'    ; & git branch -vv
    Write-Host '--- 상태 ---'      ; & git status --short
    exit 0
}

# ---------------------------------------------------------------- 2
Write-Step '2/4  저장소 초기화 및 원격 연결'

& git init -q -b $Branch
Write-Ok ('git init (' + $Branch + ')')

& git remote add origin $RemoteUrl
Write-Ok ('원격 등록 : ' + $RemoteUrl)

Write-Host '   원격 이력을 가져오는 중... (인증 창이 뜨면 GitHub 계정으로 로그인하세요)'
& git fetch origin $Branch
if ($LASTEXITCODE -ne 0) {
    Write-Bad '원격 가져오기에 실패했습니다. 인증이나 네트워크를 확인하세요.'
    Write-Bad '되돌리려면 이 폴더의 .git 폴더를 삭제하면 원래 상태입니다.'
    exit 1
}
Write-Ok '원격 이력 수신 완료'

# ---------------------------------------------------------------- 3
Write-Step '3/4  작업 파일을 건드리지 않고 인덱스만 정렬'

$upstream = 'origin/' + $Branch
& git reset -q $upstream
& git branch ('--set-upstream-to=' + $upstream) $Branch | Out-Null
Write-Ok '연결 완료 (작업 파일은 그대로)'

$after = @(Get-ChildItem $TargetDir -Recurse -File -Force |
           Where-Object { $_.FullName -notlike '*\.git\*' }).Count
if ($after -eq $fileCount) {
    Write-Ok ('파일 수 검증 : ' + $after + ' 개 - 변동 없음')
} else {
    Write-Warn2 ('파일 수가 ' + $fileCount + ' -> ' + $after + ' 로 바뀌었습니다. 확인이 필요합니다.')
}

# ---------------------------------------------------------------- 4
Write-Step '4/4  현재 상태'

Write-Host ''
Write-Host '--- 원격 ---'
& git remote -v
Write-Host ''
Write-Host '--- 저장소와의 차이 ---'
Write-Host '  M  = 저장소에도 있고 로컬에서 수정된 파일'
Write-Host '  ?? = 로컬에만 있는 파일 (아직 깃허브에 없음)'
Write-Host ''
& git status --short

Write-Host ''
Write-Host '================================================================'
Write-Host ' 완료' -ForegroundColor Green
Write-Host '================================================================'
Write-Host ''
Write-Host '이제 이 폴더에서 Claude 를 실행하면 로컬과 깃허브를 동시에 다룹니다.'
Write-Host ''
Write-Host ('  cd "' + $TargetDir + '"')
Write-Host '  claude'
Write-Host ''
Write-Host '세션 안에서 이렇게 말하면 됩니다:'
Write-Host '  "토성 폴더의 06, 07 앱을 저장소에 커밋하고 푸시해줘"'
Write-Host '  "깃허브 main 브랜치의 최신 내용을 받아와줘"'
Write-Host ''
Write-Host '주의: 위 ?? 목록의 파일은 아직 깃허브에 없습니다.'
Write-Host '      커밋해야 클라우드 세션에서도 보입니다.'
Write-Host ''
Write-Host '되돌리려면: 이 폴더의 .git 폴더만 삭제하면 연결 전 상태입니다.'
Write-Host ''
