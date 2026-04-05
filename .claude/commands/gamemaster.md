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
- 프리뷰 공 + 바닥 가이드 도트 (파워+스핀 반영, 커브 2.5배 과장 표시)
- 3D 공 모델 스핀 인디케이터 (ViewportFrame + 속도 표시)
- AI 대전 (벽 근처 직진 발사, 존별 파워 프리셋, 스핀 커브)
- 턴 시스템 (교대, 성공 시 보너스 턴, 30초 제한)
- 30초 타임아웃 = 공 소모 + 턴 넘김 (감점 없음)
- 점수 계산 (기본점 + 연속 보너스 + 그랜드슬램 + 미션 보너스)
- 미션 카드 레이스 시스템 (매치마다 3미션, 선점 경쟁)
- 미션 UI 패널 (PC: 좌측 고정, 모바일: M 토글 버튼)
- 미션 완료 시 팀 색 카드 + 아바타 헤드샷 표시
- 슬롯 점유 차단 (물리+코드 이중)
- 공 미삭제 (looseBalls, 후속타로 밀어넣기 가능)
- 주기적 looseBall 체크 (1초마다)
- 스핀 나선형 트레일 + 방향 파티클
- **로비 시스템** (캐릭터 ViewportFrame, PLAY/SKIN 버튼, 반응형 PC/모바일)
- **PvP 매칭** (큐 지속, 매칭 팝업, 5초 카운트다운, 취소, 상대 퇴장 시 승리)
- **시뮬레이터 UI 테마** (FredokaOne, UIStroke, 그라데이션 버튼, 흰색 카드)
- **턴 인디케이터** (볼 카운트 도트 10개, 팀색 채움/흰색 미사용, 보너스 턴 표시)
- 암전 트랜지션 (로비 ↔ 게임)
- 스코어보드 하단 (빨강/파랑 그라데이션 + VS 뱃지)
- 카메라 (LOBBY ↔ OVERVIEW ↔ LAUNCH_VIEW → 추적 → 착지포커스 → 복귀)
- AI 턴에도 발사 뷰 카메라 전환
- 캐릭터 숨김 + 컨트롤 비활성화 + 리스폰/Shift Lock 비활성화
- 매치 결과 화면 (5초 후 암전 → 로비 복귀)
- 발사 뷰에서 카메라가 공 X 위치 1:1 따라감
- BGM 재생 (매치 시작 시, 로비 복귀 시 정지)
- 스핀 스크린 좌표 기준 (20px 데드존)
- SFX 5종 (발사, 충돌, 득점, 미션 완료, 턴 시작)
- 타이밍 인디케이터 (Perfect~Miss 5등급, 파워 비례 난이도)
- 점수 팝업 실제 획득 점수 표시

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
- **성공 시 보너스 턴** (슬롯 안착하면 같은 팀 다시 턴, 공은 소모됨, "BONUS TURN!" 표시)
- **30초 턴 제한** (타임아웃 = 공 소모, 턴 넘김, 감점 없음)
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
| Easy (1) | 2개 | +3 | A-B, B-C, C-D |
| Medium (2) | 3개 | +6 | A-B-C, B-B-A |
| Hard (3) | 4개 | +10 | A-B-C-D, B-B-C-A |

### Ball Persistence
- 슬롯 밖에서 멈춘 공 = **삭제 안 됨** (looseBalls)
- 후속타로 밀어넣으면 점수 인정
- 매 1초 주기적 looseBall 체크
- 테이블 밖(Y<-5) 떨어진 경우만 삭제

## Lobby System

### Flow
1. 입장 → 로비 화면 (연파랑 그라데이션 배경)
2. PC: 좌측 캐릭터 ViewportFrame + 우측 타이틀/메뉴
3. 모바일: 상단 타이틀 + 중앙 캐릭터 + 하단 버튼
4. PLAY 클릭 → "MATCHING..." → 5초 대기 → AI 매치 (큐 유지)
5. 다른 플레이어 매칭 시 → 팝업 (5초 카운트다운 + CANCEL)
6. 매치 종료 → 결과 5초 → 암전 → 로비 복귀

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
   - Q/E 키 = 스핀 추가 조정
5. **릴리즈** → 발사 (파워 너무 약하면 취소)
6. **우클릭/ESC** → 취소

### Physics
- SPAWN_Z = -40
- MIN_POWER = 20, MAX_POWER = 54
- INCLINE_FORCE = 8
- SPIN: MAX_LATERAL_FORCE = 40, VectorForce 6초 지속
- 스핀 이펙트: AngularVelocity + 나선형 Trail + 방향 ParticleEmitter

### Guide Dots + Timing Indicator
- 20개, 바닥에 배치
- 길이 = power × 20 studs
- 커브 = 실제 물리 × 2.5배 과장 (시각 피드백 강화)
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
- **스핀으로만 커브**: -side × (0.05~0.08)
- 존별 파워 프리셋: Zone1=31, Zone2=40, Zone3=47
- 소폭 오차: power ±0.7, spin ±0.007 (skill=0.65)

### Target Selection
- 빈 슬롯만 후보
- 가중치: 기본점수 + 인접AI공(+4) + 인접플레이어공(+2) + 중앙보너스

## Camera System

### States
1. **LOBBY**: 로비 화면 (빈 하늘, UI가 덮음)
2. **OVERVIEW**: 전체 조감도 (0,55,-50)→(0,3,5)
3. **LAUNCH_VIEW**: 낮은 발사 앵글, 공 X 위치 1:1 따라감
4. **LAUNCH_DELAY**: 발사 후 0.4초 현재 뷰 유지
5. **TRACKING**: 공 추적 (Y+12, Z-8), Lerp ×8
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
- **상단 고정**: 턴 타이머 (30초 카운트다운, 공 발사 시 숨김)
- **하단**: 스코어보드 [이름 점수] [VS] [점수 이름]
- **좌측**: 미션 카드 패널 (PC 고정, 모바일 토글)
- **좌측 중앙**: 3D 스핀 인디케이터 (에이밍 중만)
- **좌하단**: M 버튼 (모바일 미션 토글, 시안 그라데이션)

## File Structure

```
src/
  shared/
    Config.luau
  server/
    init.server.luau      (매칭 시스템 + 리모트 설정)
    TableBuilder.luau
    GameManager.luau       (PvP 지원, forceEndMatch)
    AIPlayer.luau
  client/
    init.client.luau       (이벤트 핸들러 + 암전 트랜지션)
    LobbyController.luau   (로비 UI + 캐릭터 뷰포트)
    LaunchController.luau
    UIController.luau      (시뮬레이터 테마 HUD)
    CameraController.luau  (LOBBY 상태 포함)
```

## Key Config Values
- TABLE: 90×25, HEIGHT=3
- ZONES: Z=-12, 6, 24
- BALL: RADIUS=0.5, DENSITY=3.5
- GAME: **10 balls**, 30s turn, settle_timeout=**15s**
- LAUNCH: MIN=20, MAX=54, SPAWN_Z=-40, X_RANGE=**11**
- SPIN: MAX_LATERAL_FORCE=40, SENSITIVITY=**0.006**, DEADZONE=**20px**
- AI: SKILL=0.65, ZONE_PRESETS={Z1:31, Z2:40, Z3:47}
- MISSIONS: EASY=+3(2글자), MEDIUM=+6(3글자), HARD=+10(4글자)
- CAMERA: LOBBY=(0,100,-200), OVERVIEW=(0,55,-50), LAUNCH=(0,10,-52)
- LOBBY: MATCH_TIMEOUT=**5s**

## PvP Preview System
- 상대 턴 시 상대의 공 위치 조정이 실시간으로 보임 (0.1초 쓰로틀)
- 상대 팀 색 반투명 프리뷰 공 표시 + 카메라 따라감
- 가이드 도트/타이밍/스핀 인디케이터는 상대에게 안 보임
- 발사 시 프리뷰 자동 정리

## Remotes
RequestLaunch, GameStateUpdate, BallLanded, TurnChanged, MatchStart, MatchEnd, BallCreated, RequestMatch, MatchFound, CancelMatchmaking, MatchCancelled, PreviewUpdate

## Audio
- **BGM**: rbxassetid://126841253996417 (매치 시작 시 재생, 로비 복귀 시 정지)
- **SFX**:
  - 발사: rbxassetid://121730291891328
  - 충돌: rbxassetid://9113439845 (vel>0.8, 속도 비례 볼륨)
  - 득점: rbxassetid://116574637578954
  - 미션: rbxassetid://5711770745
  - 턴 시작: rbxassetid://127421479045055

## Remaining Work
1. 보상/스킨 시스템
2. 레벨 디자인 변형
3. PvP 매칭 실전 테스트 + 버그 수정

When the user asks you to work on any aspect of this game, reference these rules and design specs to ensure consistency.
