# Claude Code 로컬 PC 설치 가이드 Windows 11

## 설치 전 확인
### 시스템 요건
  - Windows 10 1809 이상 또는 Windows 11
  - 64비트 프로세서 32비트 미지원
  - 관리자 권한 불필요
### 계정 요건
  - Claude Pro Max Team Enterprise 구독 중 하나
  - 무료 플랜은 Claude Code 사용 불가
  - Console API 키 계정도 사용 가능
### 권장 사전 설치
  - Git for Windows 설치 시 Bash 도구 사용 가능
  - 미설치 시 PowerShell로 대체 동작
  - Node.js는 네이티브 설치에 불필요
### 이 세션의 한계
  - 현재 세션은 클라우드 컨테이너이므로 사용자 PC에 직접 설치 불가
  - 아래 절차를 사용자가 PC에서 직접 실행해야 함

## 설치 방법 선택
### 방법 1 네이티브 설치 권장
  - PowerShell 실행
  - 명령 입력 irm https://claude.ai/install.ps1 | iex
  - 설치 후 자동 업데이트 지원
### 방법 2 CMD 설치
  - 명령 입력 curl -fsSL https://claude.ai/install.cmd -o install.cmd && install.cmd && del install.cmd
### 방법 3 WinGet 설치
  - 명령 입력 winget install Anthropic.ClaudeCode
  - 자동 업데이트 없음 수동 업그레이드 필요
### 방법 4 npm 설치 대안
  - Node.js 22 이상 필요
  - 명령 입력 npm install -g @anthropic-ai/claude-code
### 방법 5 데스크톱 앱
  - https://claude.com/download 에서 Windows용 다운로드
  - CLI 없이 그래픽 화면으로 사용
  - 여러 세션 병렬 실행과 diff 검토 지원
### 방법 6 VS Code 확장
  - VS Code 1.94 이상 필요
  - 마켓플레이스에서 Claude Code 검색 후 설치
  - CLI와 동일 계정으로 로그인

## 설치 후 첫 실행
### 로그인
  - 터미널에서 claude 입력
  - 브라우저가 열리면 Claude 계정으로 로그인
  - 로그인 상태 변경은 세션 내 /login 입력
### 설치 확인
  - claude --version 으로 버전 확인
  - claude doctor 로 환경 진단
### 업데이트
  - 네이티브 설치는 백그라운드 자동 업데이트
  - 수동 업데이트는 claude update 입력
  - WinGet은 winget upgrade Anthropic.ClaudeCode 입력

## BIM 프로젝트 작업 환경 구성
### 작업 폴더 준비
  - 한글 경로와 OneDrive 폴더는 피하고 영문 로컬 폴더 사용 권장
  - 예시 C:\Work\BIM 폴더 생성
  - GitHub 저장소 silro742/BIM 을 해당 폴더에 clone
### 교재 파일 준비
  - OneDrive 건축 폴더의 교재를 C:\Work\BIM\textbooks 로 복사
  - 원본은 OneDrive에 그대로 보관
  - 복사본만 에이전트가 읽도록 하여 동기화 충돌 방지
### 세션 시작
  - PowerShell에서 cd C:\Work\BIM 입력
  - claude 입력하여 세션 시작
  - 첫 세션에서 /init 입력하면 CLAUDE.md 프로젝트 설명 파일 생성
### Git 연동
  - Git for Windows 설치 후 사용자 이름과 이메일 설정
  - Claude Code가 커밋과 푸시를 대신 수행 가능

## 권한 및 안전 설정
### 설정 파일 위치
  - 사용자 전역 %USERPROFILE%\.claude\settings.json
  - 프로젝트 공유 .claude\settings.json 저장소에 커밋
  - 프로젝트 개인 .claude\settings.local.json 커밋 제외
### 권한 모드
  - 수동 모드 파일 수정과 명령 실행 전 매번 확인
  - 편집 자동 승인 모드 파일 수정은 자동 명령은 확인
  - 자동 모드 위험 작업만 분류기가 차단
  - 확인 없음 모드는 사용 비권장
### 폴더 접근 제한
  - permissions 항목의 allow 와 deny 규칙으로 읽기 쓰기 범위 지정
  - 작업 폴더 C:\Work\BIM 만 쓰기 허용 권장
  - 시스템 폴더와 OneDrive 원본 폴더는 deny 지정
### 훅 활용
  - 파일 저장 후 자동 검증 스크립트 실행 가능
  - 세션 시작 시 환경 점검 스크립트 실행 가능

## Windows 문제 해결
### claude 명령을 찾을 수 없음
  - %USERPROFILE%\.local\bin 을 사용자 PATH에 추가
  - 터미널 재시작
### PowerShell 스크립트 실행 차단
  - Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser 실행
### TLS 오류
  - 설치 전 [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 실행
### Git Bash 인식 안 됨
  - settings.json 에 CLAUDE_CODE_GIT_BASH_PATH 값으로 bash.exe 경로 지정
### 중복 설치 충돌
  - where.exe claude 로 설치 위치 확인
  - 네이티브 설치본만 남기고 나머지 제거
### 한글 경로 문제
  - 영문 경로 사용으로 회피
  - 불가피하면 PowerShell 인코딩을 UTF-8로 설정

## 설치 완료 후 다음 단계
### 1단계
  - C:\Work\BIM 에서 claude 실행 후 저장소 구조 확인
### 2단계
  - textbooks 폴더 파일 목록과 형식 조사 요청
### 3단계
  - 검토 보고서의 세분화 앱 후보 중 우선순위 결정
### 4단계
  - 규칙 추출 스크립트와 첫 세분화 앱 생성 착수

## 참고 문서
### 공식 문서
  - 설치 https://code.claude.com/docs/en/setup
  - 설치 문제 해결 https://code.claude.com/docs/en/troubleshoot-install
  - 데스크톱 앱 https://code.claude.com/docs/en/desktop-quickstart
  - VS Code 확장 https://code.claude.com/docs/en/vs-code
