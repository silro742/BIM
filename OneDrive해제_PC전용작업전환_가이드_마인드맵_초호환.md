# OneDrive 해제 및 PC 전용 작업 전환 가이드

## 전환 개요
### 목표
  - OneDrive 동기화를 끊고 모든 파일을 로컬 디스크에서만 관리
  - 프로젝트 백업은 GitHub 저장소로 대체
### 현재 상태 추정
  - 바탕화면 경로가 C:\Users\silro\OneDrive\Desktop 이므로 바탕화면 백업 기능이 켜져 있음
  - 건축 교재 폴더도 OneDrive 안에 위치
### 주의 원칙
  - 파일 복사와 확인이 끝나기 전에는 절대 삭제하지 않음
  - 순서를 지키지 않으면 클라우드 전용 파일이 빈 껍데기로 남을 수 있음

## 1단계 파일을 완전히 로컬로 내려받기
### 파일 온디맨드 해제
  - 탐색기에서 OneDrive 폴더 우클릭
  - 이 장치에 항상 유지 선택
  - 모든 파일 아이콘이 초록 체크로 바뀔 때까지 대기
### 확인 방법
  - 구름 아이콘이 남아 있으면 아직 클라우드 전용 파일
  - 대용량 교재는 내려받기에 시간이 걸릴 수 있음

## 2단계 작업 폴더로 복사
### 로컬 폴더 생성
  - C:\Work 폴더 생성
  - C:\Work\BIM 은 GitHub 저장소 clone 위치
  - C:\Work\Textbooks 에 건축 교재 복사
### 복사 명령 예시
  - PowerShell에서 robocopy "C:\Users\silro\OneDrive\Desktop\건축" "C:\Work\Textbooks\건축" /E /COPY:DAT
  - robocopy는 복사만 하고 원본은 건드리지 않음
### 복사 검증
  - 원본과 복사본의 파일 개수와 용량 비교
  - 탐색기 폴더 속성에서 파일 수 확인
### 바탕화면과 문서 정리
  - OneDrive\Desktop 과 OneDrive\Documents 의 필요한 파일도 함께 복사

## 3단계 폴더 백업 기능 끄기
### 위치
  - 작업 표시줄 OneDrive 구름 아이콘 클릭
  - 설정 톱니 클릭 후 설정 선택
  - 동기화 및 백업 탭에서 백업 관리 선택
### 작업
  - 바탕화면 문서 사진 항목의 백업을 모두 끔
  - 끄면 해당 폴더가 C:\Users\silro 아래 원래 위치로 돌아옴
### 확인
  - 탐색기에서 바탕화면 우클릭 속성 위치 탭이 C:\Users\silro\Desktop 인지 확인

## 4단계 PC 연결 해제
### 위치
  - OneDrive 설정의 계정 탭
### 작업
  - 이 PC 연결 해제 선택
  - 연결 해제 후 동기화가 완전히 중단됨
### 결과
  - C:\Users\silro\OneDrive 폴더는 일반 로컬 폴더로 남음
  - 클라우드의 파일은 그대로 유지되므로 추가 안전망 역할

## 5단계 OneDrive 제거
### 방법 1 설정 앱
  - 설정 앱 실행
  - 앱 메뉴의 설치된 앱 선택
  - Microsoft OneDrive 항목의 제거 선택
### 방법 2 명령
  - PowerShell에서 winget uninstall Microsoft.OneDrive 실행
### 재설치 방지
  - Windows Pro는 로컬 그룹 정책 편집기에서 OneDrive 파일 저장 사용 방지 정책 사용
  - Office 재설치 시 OneDrive가 함께 설치될 수 있으니 확인
### 시작 프로그램 확인
  - 작업 관리자 시작 앱 탭에서 OneDrive 항목이 없는지 확인

## 6단계 남은 폴더 정리
### 삭제 전 확인
  - C:\Work\Textbooks 와 원본 개수 재비교
  - 며칠간 실제 작업으로 문제 없는지 확인
### 삭제
  - 확인 후 C:\Users\silro\OneDrive 폴더 삭제
  - 휴지통을 바로 비우지 않고 일정 기간 보관
### 클라우드 정리
  - onedrive.live.com 에서 필요 시 파일 삭제 또는 보관
  - 계정 자체는 유지해도 무방

## 7단계 PC 전용 백업 체계
### 프로젝트 파일
  - C:\Work\BIM 은 Git 커밋과 GitHub 푸시로 백업
  - Claude Code가 커밋과 푸시를 대신 수행 가능
### 교재 파일
  - GitHub에 올리지 않으려면 .gitignore 에 Textbooks 폴더 제외
  - 외장 디스크나 USB에 주기적 복사
  - Windows 파일 히스토리 기능으로 자동 백업 가능
### 복구 시나리오
  - PC 고장 시 GitHub clone 으로 프로젝트 복구
  - 교재는 외장 디스크 사본으로 복구

## Claude Code 작업 경로 정리
### 작업 시작
  - PowerShell에서 cd C:\Work\BIM 입력 후 claude 실행
### 교재 참조
  - 세션에서 C:\Work\Textbooks 경로를 읽기 허용 폴더로 지정
  - 쓰기는 C:\Work\BIM 만 허용
### 결과 저장
  - 생성된 앱과 문서는 C:\Work\BIM 에 저장 후 GitHub 푸시

## 주의 사항
### 데이터 손실 방지
  - 1단계 내려받기 없이 연결 해제하면 클라우드 전용 파일이 열리지 않음
  - 백업 기능을 끄지 않고 제거하면 바탕화면 경로가 꼬일 수 있음
### 다른 기기
  - 스마트폰이나 다른 PC에서 같은 파일을 쓰고 있었다면 접근 경로 재설정 필요
### Office 연동
  - Word Excel 자동 저장 기능은 OneDrive 없이는 동작하지 않음
  - 로컬 저장 시 수동 저장 습관 필요
