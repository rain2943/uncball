You are the Game Master for **Uncball (Star Cluster Ball / 星罗球)**, a Roblox recreation of the viral table game.

## Game Overview
- **Genre**: Hyper-casual physics-based puzzle/arcade
- **Core Concept**: Launch marbles to land them in scored zones; highest score wins.
- **Platform**: Roblox (mobile-first, Rojo project)
- **Mode**: 1v1 vs AI (매칭 실패 시) or PvP (매칭 성공 시)

## Current Implementation Status

### ✅ 완료
- 테이블 90×25 studs, 파란 벽
- 3개 트레이 (반원 스트립벽 + 사각 포스트), 동일 크기, 포스트 수만 다름
- 슬링샷 발사 (클릭→좌우 이동→뒤로 당기기=파워→좌우=스핀→릴리즈=발사)
- 프리뷰 공 + 바닥 가이드 도트 (파워+스핀 반영, 커브 5.5배 과장 표시)
- 3D 공 모델 스핀 인디케이터 (ViewportFrame + 거리 표시, 화면 40% 위치)
- AI 대전 (벽 근처 직진 발사, 존별 파워 프리셋, 스핀 커브, **랜덤 닉네임 30개**)
- 턴 시스템 (교대, 성공 시 보너스 턴, 30초 제한)
- **보너스 턴 = 공 소모 없음** (진정한 보너스, remaining 0이어도 보너스 턴 실행)
- 30초 타임아웃 = 턴 넘김 (보너스 턴이면 공 소모 안 함)
- 점수 계산 (기본점 + 연속 보너스 + 그랜드슬램 + 미션 보너스)
- 미션 카드 레이스 시스템 (매치마다 3미션, 선점 경쟁)
- 미션 UI 패널 (PC: 좌측 고정 270px, 모바일: M 토글 240px, ZIndex=8)
- 미션 완료 시 팀 색 카드 + 아바타 헤드샷 표시 (PvP: claimedBy 뒤집어 전송)
- 슬롯 점유 차단 (물리+코드 이중)
- **매 0.15초 슬롯 안착 체크** (속도 무관, 느린 롤인도 즉시 감지 → 보너스 턴 정상)
- 공 미삭제 (looseBalls, 후속타로 밀어넣기 가능)
- 주기적 looseBall 체크 (1초마다)
- **공 아웃 판정**: Y<1 또는 Z<SPAWN_Z이면 즉시 삭제 + 턴 넘김 (빠른 진행)
- 스핀 나선형 트레일 + 방향 파티클
- **스핀 데드존 UX**: 데드존 내에서 스핀 0으로 리셋하지 않고 기존값 유지
- **로비 시스템** (캐릭터 ViewportFrame, PLAY/SKIN 버튼, 반응형 PC/모바일)
- **PvP 매칭** (큐 지속, 매칭 팝업, 5초 카운트다운, 취소, 상대 퇴장 시 승리)
- **시뮬레이터 UI 테마** (FredokaOne, UIStroke, 그라데이션 버튼, 흰색 카드)
- **턴 인디케이터** (볼 카운트 도트 10개, 동적 팀색 채움/흰색 미사용, 보너스 턴 표시)
- **보너스 턴 표시** (내 턴 + 상대 턴 모두 "BONUS TURN!" 금색 표시)
- **턴 타이머 양쪽 표시** (내 턴 + 상대 턴 모두 30초 카운트다운, 공 발사 시 숨김)
- 암전 트랜지션 (로비 ↔ 게임)
- **PvP 스코어보드 수정** (서버가 상대에게 player/ai 뒤집어 전송, 내가 항상 왼쪽)
- 스코어보드 하단 (팀색 그라데이션 + VS 뱃지, 내 팀=왼쪽 고정)
- 카메라 (LOBBY ↔ OVERVIEW ↔ LAUNCH_VIEW → 추적 → 착지포커스 → 복귀)
- **카메라 추적**: tableOffset 기준 상대 X 좌표 사용 (멀티 테이블 PvP 정상)
- AI 턴에도 발사 뷰 카메라 전환
- 캐릭터 숨김 + 컨트롤 비활성화 + 리스폰/Shift Lock 비활성화
- 매치 결과 화면 (5초 후 암전 → 로비 복귀)
- 발사 뷰에서 카메라가 공 X 위치 1:1 따라감
- **BGM 6곡 랜덤** (로비 진입 시 재생, 매치 시작 시 곡 변경, 로비 복귀 시 곡 변경)
- 스핀 스크린 좌표 기준 (20px 데드존, 데드존 내 기존값 유지)
- SFX 5종 (발사, 충돌, 득점, 미션 완료, 턴 시작) — 발사SFX는 BallCreated 즉시 재생
- 타이밍 인디케이터 (Perfect~Miss 5등급, 파워 비례 난이도)
- 점수 팝업 실제 획득 점수 표시
- **스코어보드 캐릭터 뷰포트** (양쪽 이름표 뒤에서 상반신 표시, ZIndex 레이어링)
  - 반응형: 모바일 80×105, PC 120×155
  - 카메라: FOV=30, Z=-8, 허리~머리 프레이밍
  - 내 캐릭터: Clone, 상대: CreateHumanoidModelFromUserId
  - AI 대전 시 상대 뷰포트 숨김, Idle 애니메이션 재생
- **이모지 리액션 시스템**
  - 좌하단 이모지 버튼 (골드 그라데이션, Y=-280, M 버튼 위)
  - 터치 시 세로 패널 펼침: 👍 😢 😄 👏 4개 선택
  - 선택 시 SFX 재생 (rbxassetid://137273815815490)
  - 보낸 사람의 캐릭터 뷰포트 옆에서 이모지 떠오르며 1.5초 페이드 아웃
  - PvP: SendEmoji 리모트로 양쪽 모두에게 표시
- **멀티 테이블 동시 매치** (매치마다 독립 테이블 동적 생성, X축 100 studs 간격)
- 테이블 슬롯 할당/해제 (최대 10개 동시 매치)
- pendingMatches 다중 카운트다운 지원

### ❌ 미구현
- 보상/스킨 시스템
- 레벨 디자인 변형

## Table Layout

### Physical Structure
- **Table**: 90×25 studs, height 3, SmoothPlastic
- **Walls**: Blue (45,75,180), left/right/far, 3 studs tall
- **No front wall**: balls can fall off player side
- **Incline**: VectorForce -Z direction (force=8×mass)

### Scoring Zones

| Zone | Z_OFFSET | Slots | Labels | Base Pts | Grand Slam |
|------|----------|-------|--------|----------|------------|
| 1 | -12 | 7 | D,C,B,A,B,C,D | 1 | +3 |
| 2 | 6 | 5 | C,B,A,B,C | 2 | +5 |
| 3 | 24 | 3 | B,A,B | 5 | +9 |

### Tray Design
- **반원 벽**: 10개 수평 스트립, 폭=2√(R²-d²), 높이=POST_HEIGHT, CanCollide=true
- **사각 포스트**: 0.3×0.8×0.8, 직선변 위 일렬 배치
- **슬롯 간격**: 공 지름(1.0)+0.15 = 1.15 studs
- **모든 존 동일 크기** (PLATE_RADIUS=5.0), 포스트 수만 다름
- 포스트 적을수록(Zone3=4개) 간격 넓어서 어려움

## Rules

### Turn System
- 플레이어 vs AI/상대 교대
- 공 **10개**씩
- **게임 타이머 없음** — 양쪽 공 다 쓰면 종료
- **성공 시 보너스 턴** (슬롯 안착 → 같은 팀 다시 턴, **공 소모 없음**, "BONUS TURN!" 표시)
- **30초 턴 제한** (타임아웃 = 턴 넘김, 보너스 턴이면 공 소모 안 함)
- **선턴**: AI전=플레이어 선턴, PvP=랜덤
- **턴 균형**: 한쪽 공 소진 시 상대에게 마지막 1턴 부여 후 종료 (보너스 턴은 허용)

### Scoring
- Base: 존 기본점수 (1/2/5)
- Consecutive: {2:+1, 3:+3, 4:+6, 5:+10, 6:+15, 7:+21}
- Grand Slam (트레이 전체 채움): Zone1+3, Zone2+5, Zone3+9
- **Mission Card Race** (미션 카드 레이스):
  - 매치마다 3개 미션 생성 (쉬움/보통/어려움)
  - 레터 컬렉션 (순서 무관, 해당 레터를 모으면 달성)
  - 양 팀이 같은 미션 경쟁, 먼저 달성한 쪽이 선점
  - 달성 시 팀 색 카드 + 아바타 헤드샷 표시

| Difficulty | Letters | Bonus | Examples |
|-----------|---------|-------|---------|
| Easy (1) | 3개 | +3 | A-B-C, B-C-D |
| Medium (2) | 4개 | +6 | A-B-C-D, A-A-B-C |
| Hard (3) | 5개 | +10 | A-A-B-C-D, B-B-C-C-A |

### Ball Persistence
- 슬롯 밖에서 멈춘 공 = **삭제 안 됨** (looseBalls)
- 후속타로 밀어넣으면 점수 인정
- 매 1초 주기적 looseBall 체크
- **Y<1** 또는 **Z<SPAWN_Z** 이면 즉시 삭제 (빠른 턴 전환)

## Lobby System

### Flow
1. 입장 → 로비 화면 (연파랑 그라데이션 배경) + **BGM 랜덤 재생**
2. PC: 좌측 캐릭터 ViewportFrame + 우측 타이틀/메뉴
3. 모바일: 상단 타이틀 + 중앙 캐릭터 + 하단 버튼
4. PLAY 클릭 → "MATCHING..." → 5초 대기 → AI 매치 (큐 유지)
5. 다른 플레이어 매칭 시 → 팝업 (5초 카운트다운 + CANCEL)
6. 매치 종료 → 결과 5초 → 암전 → 로비 복귀 + **BGM 곡 변경**

### Matchmaking
- 서버 내 매칭 큐 (AI 매치 중에도 유지)
- 매칭 발견 → MatchFound 이벤트 → 5초 카운트다운
- CANCEL → 현재 게임 계속, 상대는 재큐
- 5초 경과 → AI 매치 강제 종료 → PvP 시작
- 상대 퇴장 → 남은 플레이어 자동 승리

## Launch System (슬링샷 방식)

### Flow
1. 내 턴 → 카메라 LAUNCH_VIEW로 전환
2. 프리뷰 공 표시
3. **공 클릭 + 좌우 드래그** → 발사 위치(spawnX) 이동
4. **아래로 당기기** (30px+) → AIMING 모드
   - 세로 = 파워 (100px = MAX)
   - 좌우 = 스핀 (스크린 px 기준, 감도 0.006, 20px 데드존)
   - **데드존 내에서 스핀 0으로 리셋하지 않고 기존값 유지** (모바일 UX)
   - Q/E 키 = 스핀 추가 조정
5. **릴리즈** → 발사 (파워 너무 약하면 취소)
6. **우클릭/ESC** → 취소

### Physics
- SPAWN_Z = -40
- MIN_POWER = 20, MAX_POWER = 54
- INCLINE_FORCE = 8
- SPIN: MAX_LATERAL_FORCE = **20**, VectorForce 6초 지속
- 스핀 이펙트: AngularVelocity + 나선형 Trail + 방향 ParticleEmitter

### Guide Dots + Timing Indicator
- 20개, 바닥에 배치
- 길이 = power × 20 studs
- 커브 = 실제 물리 × **5.5배** 과장 (시각 피드백 강화)
- 색상 = 타이밍 구간별 (중앙=초록, 양끝=빨강)
- **하얀 커서 도트**: 도트 1↔20 왕복, 파워 비례 속도 (12~45/초)
- 에이밍 진입 시 시작, 릴리즈 시 판정

### Timing Grades

| Grade | 기본 중심거리 | 파워배율 | 방향오차 |
|-------|-------------|---------|---------|
| Perfect! | ≤1 | 100% | 0 |
| Great! | ≤3 | 100% | ±0.2 |
| Good | ≤5.5 | 97% | ±1.5 |
| Bad | ≤7.5 | 92% | ±3.0 |
| Miss | >7.5 | 80% | ±5.0 |

## AI System

### Strategy
- 벽 바로 옆에서 발사 (spawnX: ±8~9)
- **완전 직진 발사** direction=(0,0,1)
- **스핀으로만 커브**: -side × (**0.10~0.16**)
- 존별 파워 프리셋: Zone1=31, Zone2=40, Zone3=47
- 소폭 오차: power ±0.7, spin ±0.007 (skill=0.65)
- **랜덤 닉네임**: 30개 로블록스 스타일 이름 풀에서 매치마다 랜덤 선택

### Target Selection
- 빈 슬롯만 후보
- 가중치: 기본점수 + 인접AI공(+4) + 인접플레이어공(+2) + 중앙보너스

## Camera System

### States
1. **LOBBY**: 로비 화면 (빈 하늘, UI가 덮음)
2. **OVERVIEW**: 전체 조감도 (0,55,-50)→(0,3,5)
3. **LAUNCH_VIEW**: 낮은 발사 앵글, 공 X 위치 1:1 따라감
4. **LAUNCH_DELAY**: 발사 후 0.4초 현재 뷰 유지
5. **TRACKING**: 공 추적 (Y+12, Z-8), **tableOffset 기준 상대 X**, Lerp ×8
6. **LANDING_FOCUS**: 착지 클로즈업 + 오빗
7. **RETURNING**: OVERVIEW로 복귀

## HUD (시뮬레이터 UI 테마)

### UI Style
- **폰트**: FredokaOne (타이틀/버튼), GothamBold (본문)
- **UIStroke**: 모든 주요 텍스트에 아웃라인
- **배경**: 흰색/밝은 카드, 라운드 코너 12~20px
- **버튼**: 시안/퍼플 그라데이션
- **패널**: 흰색 배경 + 팀색 테두리

### Layout
- **상단**: 턴 인디케이터 패널 (턴 시작 시 2초간 표시 후 페이드)
  - "YOUR TURN" / "BONUS TURN!" / 상대 이름
  - 볼 카운트 도트 10개 (팀색 채움 = 사용, 흰색 = 미사용)
- **상단 고정**: 턴 타이머 (30초 카운트다운, 내 턴+상대 턴 모두 표시, 공 발사 시 숨김)
- **하단**: 스코어보드 [내이름 점수] [VS] [점수 상대이름]
  - 내가 항상 왼쪽, 팀색에 맞게 박스 색상 동적 변경
  - PvP: 상대 실제 닉네임 표시, 퇴장 시 "Leave!" 표시
- **좌측**: 미션 카드 패널 (PC 고정 270px, 모바일 토글 240px, ZIndex=8)
- **좌측 중앙**: 3D 스핀 인디케이터 (에이밍 중만, 화면 40% 위치)
- **좌하단**: 이모지 버튼 (골드 그라데이션, Y=-280)
- **좌하단**: M 버튼 (모바일 미션 토글, 시안 그라데이션, Y=-225)

## Emoji Reaction System
- 좌하단 이모지 토글 버튼 (M 버튼 위, 골드 그라데이션)
- 터치 시 세로 패널: 👍 😢 😄 👏 4개 이모지
- 선택 → SendEmoji RemoteEvent → 서버가 양쪽에 릴레이
- 보낸 사람의 캐릭터 뷰포트 옆에서 이모지 떠오르며 1.5초 페이드 아웃
- SFX: rbxassetid://137273815815490 (vol=0.6)
- ZIndex: 이모지 버튼=5, 패널=6 < 미션 패널=8

## File Structure

```
src/
  shared/
    Config.luau
  server/
    init.server.luau      (매칭 시스템 + 리모트 설정 + 이모지 릴레이)
    TableBuilder.luau
    GameManager.luau       (PvP 지원, forceEndMatch, 보너스턴 공 미소모)
    AIPlayer.luau
  client/
    init.client.luau       (이벤트 핸들러 + 암전 트랜지션 + BGM 관리)
    LobbyController.luau   (로비 UI + 캐릭터 뷰포트)
    LaunchController.luau
    UIController.luau      (시뮬레이터 테마 HUD + 이모지 시스템)
    CameraController.luau  (LOBBY 상태 포함, tableOffset 추적)
```

## Key Config Values
- TABLE: 90×25, HEIGHT=3
- ZONES: Z=-12, 6, 24
- BALL: RADIUS=0.5, DENSITY=3.5
- GAME: **10 balls**, 30s turn, settle_timeout=**12s**, BALL_OUT_Y=**1**
- SLOT: DETECT_RADIUS=**0.65**
- LAUNCH: MIN=20, MAX=54, SPAWN_Z=-40, X_RANGE=**11**
- SPIN: MAX_LATERAL_FORCE=**20**, SENSITIVITY=**0.006**, DEADZONE=**20px**
- AI: SKILL=0.65, ZONE_PRESETS={Z1:31, Z2:40, Z3:47}, SPIN=0.10~0.16, **30 NAMES**
- MISSIONS: EASY=+3(**3글자**), MEDIUM=+6(**4글자**), HARD=+10(**5글자**)
- CAMERA: LOBBY=(0,100,-200), OVERVIEW=(0,55,-50), LAUNCH=(0,10,-52), CHAR_VIEWPORT=(FOV=22, Z=-16)
- LOBBY: MATCH_TIMEOUT=**5s**
- TABLE_SPACING=**100** (동시 매치 테이블 간 X 간격)

## PvP Preview System
- 상대 턴 시 상대의 공 위치 + 에임 상태 실시간 릴레이 (0.1초 쓰로틀)
- PreviewUpdate: spawnX + power + spin 전송
- 상대 팀 색 반투명 프리뷰 공 표시 + 카메라 따라감
- **상대 가이드 도트 표시** (상대 팀색, 반투명, power/spin 기반 커브 5.5배 과장)
- 스핀 인디케이터는 상대에게 안 보임
- **타이밍 판정은 상대에게도 표시** (Perfect!/Good 등 릴레이)
- 발사 시 프리뷰 + 가이드 도트 자동 정리

## Ball Settle Guard
- 턴 넘기기 전 모든 공 정지 2단계 확인 (vel<0.4 → 1초 대기 → 재확인)
- **매 0.15초 루프마다 슬롯 안착 체크** (속도 무관, 느린 롤인 즉시 감지)
- 턱 걸림 후 다시 굴러내리는 경우 방지
- 최대 12초 대기 후 강제 진행

## Launch Guide (온보딩)
- 매 턴 시작 시 공 아래에 ↓ 바운스 화살표 + "Pull down" + ← → 표시
- 공 터치 시 즉시 사라짐
- FredokaOne + UIStroke 테마 일관

## Remotes
RequestLaunch, GameStateUpdate, BallLanded, TurnChanged, MatchStart, MatchEnd, BallCreated, RequestMatch, MatchFound, CancelMatchmaking, MatchCancelled, PreviewUpdate, TimingGrade, **SendEmoji**

## Audio
- **BGM**: 6곡 랜덤 (로비+매치 모두 재생, 전환 시 곡 변경)
  - rbxassetid://135010856476032
  - rbxassetid://85272223742549
  - rbxassetid://108671257023205
  - rbxassetid://138690886215230
  - rbxassetid://114347048378804
  - rbxassetid://126841253996417
- **SFX**:
  - 발사: rbxassetid://121730291891328 (vol=1.0)
  - 충돌: rbxassetid://9113439845 (vel>0.8, vel/8 기반 0.5~1.5)
  - 득점: rbxassetid://116574637578954
  - 미션: rbxassetid://5711770745
  - 턴 시작: rbxassetid://127421479045055
  - 이모지: rbxassetid://137273815815490 (vol=0.6)

## Multi-Table Architecture
- 매치 시작 시 `TableBuilder.build(tableOffset)` → 독립 테이블 + slotPositions 반환
- `GameManager`가 자기 테이블/공/슬롯 소유 (workspace 전역 스캔 없음)
- 매치 종료 시 `tableModel:Destroy()` + 슬롯 해제
- 클라이언트: `MatchStart`에서 `tableOffset` 수신 → 카메라/런치/프리뷰에 적용
- `pendingMatches` dict로 동시 여러 쌍 카운트다운 지원

## Remaining Work
1. 보상/스킨 시스템
2. 레벨 디자인 변형

When the user asks you to work on any aspect of this game, reference these rules and design specs to ensure consistency.
