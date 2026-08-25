<#
  01_진단_벼리팀찾기.ps1

  벼리팀 / 앱성팀의 흔적을 로컬 PC 전체에서 찾아 바탕화면에 보고서로 저장합니다.
  읽기 전용입니다. 어떤 파일도 수정하거나 삭제하지 않습니다.

  실행 방법
    1) 이 파일이 있는 폴더에서 Shift + 마우스 우클릭 -> "여기에 PowerShell 창 열기"
    2) 아래 명령 붙여넣기
       powershell -ExecutionPolicy Bypass -File .\01_진단_벼리팀찾기.ps1
#>

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference    = 'SilentlyContinue'

$Pattern   = '벼리|앱성'
$ClaudeDir = Join-Path $env:USERPROFILE '.claude'
$DesktopDir= Join-Path $env:USERPROFILE 'Desktop'
$ToseongDir= Join-Path $DesktopDir '토성'
$Report    = Join-Path $DesktopDir ('벼리팀_진단결과_{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$Lines     = New-Object System.Collections.Generic.List[string]

function Add-Line {
    param([Parameter(ValueFromPipeline=$true)][AllowNull()][string]$Text = '')
    process { if ($null -eq $Text) { $Text = '' } ; $Lines.Add($Text) ; Write-Host $Text }
}
function Add-Head {
    param([string]$Text)
    Add-Line ''
    Add-Line ('=' * 64)
    Add-Line $Text
    Add-Line ('=' * 64)
}

Add-Line '벼리팀 / 앱성팀 진단 보고서'
Add-Line ('생성 시각 : {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
Add-Line ('사용자    : {0}' -f $env:USERPROFILE)

# ------------------------------------------------------------------ 1
Add-Head '[1] 실행 환경'
Add-Line ('PowerShell : {0}' -f $PSVersionTable.PSVersion)
$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if ($claudeCmd) {
    Add-Line ('claude 경로 : {0}' -f $claudeCmd.Source)
    Add-Line ('claude 버전 : {0}' -f ((& claude --version 2>&1) -join ' '))
} else {
    Add-Line 'claude      : 설치되어 있지 않음  ->  02_로컬복귀_설치.ps1 을 먼저 실행하세요'
}
Add-Line ('팀 플래그(현재 셸) : [{0}]' -f $env:CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS)

# ------------------------------------------------------------------ 2
Add-Head '[2] 설정 파일 - 팀 기능이 켜져 있는가'
foreach ($p in @((Join-Path $ClaudeDir 'settings.json'), (Join-Path $env:USERPROFILE '.claude.json'))) {
    if (Test-Path $p) {
        Add-Line ('--- {0}' -f $p)
        $item = Get-Item $p
        if ($item.Length -lt 20000) {
            Add-Line (Get-Content $p -Raw -Encoding UTF8)
        } else {
            Add-Line ('  (파일 {0:N0} bytes - AGENT_TEAMS 관련 줄만 표시)' -f $item.Length)
            $hit = Select-String -Path $p -Pattern 'AGENT_TEAMS'
            if ($hit) { $hit | ForEach-Object { Add-Line ('  ' + $_.Line.Trim()) } }
            else      { Add-Line '  AGENT_TEAMS 설정 없음' }
        }
    } else {
        Add-Line ('--- {0}   ->  없음' -f $p)
    }
}

# ------------------------------------------------------------------ 3
Add-Head '[3] 팀원 역할 정의  ~\.claude\agents   *** 가장 중요 ***'
$agentsDir = Join-Path $ClaudeDir 'agents'
if (Test-Path $agentsDir) {
    $defs = @(Get-ChildItem $agentsDir -Recurse -File)
    Add-Line ('파일 {0} 개' -f $defs.Count)
    foreach ($d in $defs) {
        Add-Line ('  {0,-45} {1,8} bytes  {2}' -f $d.Name, $d.Length, $d.LastWriteTime)
    }
    $match = @($defs | Where-Object { $_.Name -match $Pattern })
    if ($match.Count -gt 0) {
        Add-Line ''
        Add-Line '>>> 벼리/앱성 이름의 정의 파일 발견 - 아래 내용을 그대로 복사해 주세요 <<<'
        foreach ($m in $match) {
            Add-Line ''
            Add-Line ('----- {0} -----' -f $m.FullName)
            Add-Line (Get-Content $m.FullName -Raw -Encoding UTF8)
        }
    } else {
        Add-Line '벼리/앱성 이름의 정의 파일은 없음'
    }
} else {
    Add-Line '폴더 없음  ->  로컬에서 커스텀 에이전트를 쓰신 적이 없거나 경로가 다릅니다'
}

# ------------------------------------------------------------------ 4
Add-Head '[4] 팀 설정  ~\.claude\teams   (세션 종료 시 삭제되므로 보통 비어 있음)'
$teamsDir = Join-Path $ClaudeDir 'teams'
if (Test-Path $teamsDir) {
    $tf = @(Get-ChildItem $teamsDir -Recurse)
    if ($tf.Count -eq 0) { Add-Line '폴더는 있으나 비어 있음' }
    else { foreach ($f in $tf) { Add-Line ('  {0}   {1}' -f $f.FullName, $f.LastWriteTime) } }
} else {
    Add-Line '폴더 없음 (정상 - 문서상 세션 종료 시 삭제됩니다)'
}

# ------------------------------------------------------------------ 5
Add-Head '[5] 작업 목록  ~\.claude\tasks   *** 세션이 끝나도 남는 핵심 단서 ***'
$tasksDir = Join-Path $ClaudeDir 'tasks'
if (Test-Path $tasksDir) {
    $teams = @(Get-ChildItem $tasksDir -Directory | Sort-Object LastWriteTime)
    Add-Line ('팀 폴더 {0} 개' -f $teams.Count)
    foreach ($t in $teams) {
        $cnt = @(Get-ChildItem $t.FullName -Recurse -File).Count
        Add-Line ('  {0,-30} 최종수정 {1}   파일 {2}' -f $t.Name, $t.LastWriteTime, $cnt)
    }
    $june = @($teams | Where-Object {
        $_.LastWriteTime -ge (Get-Date '2026-06-01') -and $_.LastWriteTime -lt (Get-Date '2026-07-01') })
    if ($june.Count -gt 0) {
        Add-Line ''
        Add-Line '>>> 2026년 6월 작업 목록 발견 - 벼리팀/앱성팀의 작업일 가능성이 높습니다 <<<'
        foreach ($t in $june) {
            Add-Line ('----- {0} -----' -f $t.FullName)
            $files = @(Get-ChildItem $t.FullName -Recurse -File | Select-Object -First 40)
            foreach ($f in $files) {
                Add-Line ('  · {0}   ({1:N0} bytes)' -f $f.Name, $f.Length)
                if ($f.Length -lt 4000) { Add-Line (Get-Content $f.FullName -Raw -Encoding UTF8) }
            }
        }
    } else {
        Add-Line '2026년 6월 날짜의 폴더는 없음'
    }
} else {
    Add-Line '폴더 없음'
}

# ------------------------------------------------------------------ 6
Add-Head '[6] 대화 기록  ~\.claude\projects   - 벼리/앱성 언급 검색'
$projDir = Join-Path $ClaudeDir 'projects'
if (Test-Path $projDir) {
    $logs = @(Get-ChildItem $projDir -Recurse -Filter *.jsonl)
    Add-Line ('전사 파일 {0} 개 검색 중...' -f $logs.Count)
    $hits = @($logs | Select-String -Pattern $Pattern -Encoding UTF8 -List)
    if ($hits.Count -gt 0) {
        Add-Line ''
        Add-Line '>>> 벼리/앱성이 언급된 대화 기록 <<<'
        foreach ($h in $hits) {
            $f = Get-Item $h.Path
            Add-Line ('  {0}' -f $f.FullName)
            Add-Line ('      최종수정 {0}   크기 {1:N0} bytes' -f $f.LastWriteTime, $f.Length)
        }
        Add-Line ''
        Add-Line '실제 문장을 보려면 (경로는 위에서 골라 바꾸세요):'
        Add-Line '  Select-String -Path "경로\파일.jsonl" -Pattern "벼리|앱성" -Encoding UTF8 | Select-Object -First 30'
    } else {
        Add-Line '언급 없음'
    }
} else {
    Add-Line '폴더 없음'
}

# ------------------------------------------------------------------ 7
Add-Head '[7] 바탕화면 토성 폴더'
if (Test-Path $ToseongDir) {
    Add-Line ('경로 : {0}' -f $ToseongDir)
    Add-Line '--- 최상위 항목'
    foreach ($i in Get-ChildItem $ToseongDir) {
        $kind = if ($i.PSIsContainer) { '[폴더]' } else { '[파일]' }
        Add-Line ('  {0,-50} {1}  {2}' -f $i.Name, $kind, $i.LastWriteTime)
    }
    Add-Line '--- 이름에 벼리/앱성이 들어간 항목'
    $n1 = @(Get-ChildItem $ToseongDir -Recurse -Force | Where-Object { $_.Name -match $Pattern })
    if ($n1.Count -gt 0) { foreach ($x in $n1) { Add-Line ('  {0}' -f $x.FullName) } } else { Add-Line '  없음' }
    Add-Line '--- 내용에 벼리/앱성이 들어간 파일'
    $n2 = @(Get-ChildItem $ToseongDir -Recurse -File -Force |
            Where-Object { $_.Length -lt 20MB } |
            Select-String -Pattern $Pattern -Encoding UTF8 -List)
    if ($n2.Count -gt 0) {
        foreach ($x in $n2) { Add-Line ('  {0}' -f $x.Path) ; Add-Line ('      {0}' -f $x.Line.Trim()) }
    } else { Add-Line '  없음' }
} else {
    Add-Line ('폴더 없음 : {0}' -f $ToseongDir)
}

# ------------------------------------------------------------------ 8
Add-Head '[8] 바탕화면 전체 - 이름에 벼리/앱성'
$n3 = @(Get-ChildItem $DesktopDir -Recurse -Force | Where-Object { $_.Name -match $Pattern })
if ($n3.Count -gt 0) { foreach ($x in $n3) { Add-Line ('  {0}' -f $x.FullName) } } else { Add-Line '  없음' }

# ------------------------------------------------------------------ 끝
Add-Head '요약 - 결과별 다음 조치'
Add-Line '[3] 에 정의 파일이 나왔다면   ->  그 내용을 그대로 복사해 Claude 에게 전달'
Add-Line '[5] 에 6월 폴더가 나왔다면    ->  벼리팀의 실제 작업 내용이 거기 있음'
Add-Line '[6] 에 대화 기록이 나왔다면   ->  파일 경로를 Claude 에게 알려주기'
Add-Line '모두 없음 이라면              ->  팀은 세션과 함께 소멸. 역할을 새로 정의해 복원'

$Lines -join "`r`n" | Set-Content -Path $Report -Encoding UTF8
Write-Host ''
Write-Host ('보고서를 저장했습니다: {0}' -f $Report) -ForegroundColor Green
Write-Host '이 파일을 열어 내용을 Claude 에게 붙여넣어 주세요.' -ForegroundColor Green
