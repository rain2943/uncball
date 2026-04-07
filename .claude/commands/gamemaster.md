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
- 3D 공 모델 스핀 인디케이터 (ViewportFrame + 거리 표시, 화면 28% 위치)
- AI 대전 (벽 근처 직진 발사, 존별 파워 프리셋, 스핀 커브, **랜덤 닉네임 30개**, **바람 보정**)
- 턴 시스템 (교대, 성공 시 보너스 턴, 20초 제한)
- **보너스 턴 = 공 소모 없음** (진정한 보너스, remaining 0이어도 보너스 턴 실행)
- 20초 타임아웃 = 턴 넘김 (보너스 턴이면 공 소모 안 함)
- **PvP 타임아웃**: 즉시 state="BALL_MOVING" 설정 → 타임아웃 직후 발사 요청 차단
- **콤보 점수 시스템** (인접 체인 길이에 따라 점수 증가, "2x Combo!" 팝업)
- **올킬 보너스** (트레이 전체 채움 시 마지막 공 2배, "All Kill!" 팝업)
- 미션 카드 레이스 시스템 (매치마다 3미션, 선점 경쟁, **슬롯 라벨 기반 A/B/C/D**)
- 미션 UI 패널 (PC: 좌측 고정 270px, 모바일: M 토글 240px, ZIndex=8)
- 미션 완료 시 팀 색 카드 + 아바타 헤드샷 표시 (PvP: claimedBy 뒤집어 전송)
- 슬롯 점유 차단 (물리+코드 이중)
- **슬롯 안착 체크**: 속도 **1.2 이하**일 때만 체크 (자연스러운 착지)
- **슬롯 스냅**: 슬롯 중앙 좌표로 정확히 스냅 (클라이언트 간 위치 일치)
- 공 미삭제 (looseBalls, 후속타로 밀어넣기 가능)
- 주기적 looseBall 체크 (1초마다)
- **공 아웃 판정**: Y<1 또는 Z<SPAWN_Z이면 즉시 삭제 + 턴 넘김
- **공 네트워크 소유권**: `SetNetworkOwner(nil)` 서버 고정 (끊김 방지)
- 스핀 나선형 트레일 + 방향 파티클
- **스핀 데드존 UX**: 데드존 내에서 스핀 0으로 리셋하지 않고 기존값 유지
- **로비 시스템** (캐릭터 ViewportFrame, PLAY/SKIN 버튼, 반응형 PC/모바일)
- **로비 랭크 표시** (닉네임 + 금색 점수, PC 우하단 우측정렬, 모바일 중앙)
- **PvP 매칭** (큐 지속, 매칭 팝업, 5초 카운트다운, 취소, 상대 퇴장 시 승리)
- **시뮬레이터 UI 테마** (FredokaOne, UIStroke, 그라데이션 버튼, 흰색 카드)
- **턴 인디케이터** (볼 카운트 도트 8개, 동적 팀색 채움/흰색 미사용, 보너스 턴 표시)
- **보너스 턴 표시** (내 턴 + 상대 턴 모두 "BONUS TURN!" 금색 표시)
- **턴 타이머 양쪽 표시** (내 턴 + 상대 턴 모두 20초 카운트다운, 공 발사 시 숨김)
- 암전 트랜지션 (로비 ↔ 게임)
- **PvP 스코어보드 수정** (서버가 상대에게 player/ai 뒤집어 전송, 내가 항상 왼쪽)
- 스코어보드 하단 (팀색 그라데이션 + VS 뱃지, 내 팀=왼쪽 고정)
- **스코어보드 랭크 표시** (스코어보드 바로 위에 "R 1250" 금색, AI전 상대 랭크 숨김)
- 카메라 (LOBBY ↔ OVERVIEW ↔ LAUNCH_VIEW → 추적 → 착지포커스 → 복귀)
- **카메라 추적**: tableOffset 기준 상대 X 좌표 사용 (멀티 테이블 PvP 정상)
- AI 턴에도 발사 뷰 카메라 전환
- 캐릭터 숨김 + 컨트롤 비활성화 + 리스폰/Shift Lock 비활성화
- **매치 결과 화면** (승패 + 점수 + **랭크 변동 표시**: "1010 ( +10 )", 5초 후 암전→로비)
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
- **아바타 리액션 애니메이션** (Roblox 기본 애니메이션)
  - 득점 시: Wave/Laugh/Cheer 랜덤 재생 (해당 팀 캐릭터)
  - 공 아웃 시: Cry 재생 (1.2초 후 자동 정지)
  - 에이밍 시: Wave 애니메이션 speed=0, 파워(0~1)에 따라 TimePosition 수동 제어 (0~60% 구간)
- **이모지 리액션 시스템**
  - 좌하단 이모지 버튼 (골드 그라데이션, Y=-280, M 버튼 위)
  - 터치 시 세로 패널 펼침: 👍 😢 😄 👏 4개 선택
  - PvP: SendEmoji 리모트로 양쪽 모두에게 표시
- **멀티 테이블 동시 매치** (매치마다 독립 테이블 동적 생성, X축 100 studs 간격)
- 테이블 슬롯 할당/해제 (최대 10개 동시 매치)
- pendingMatches 다중 카운트다운 지원
- **랭크 시스템** (DataStore 영속, ELO PvP K=40, AI 승리 +10)
- **바람 시스템** (턴마다 랜덤 바람, 공 물리에 VectorForce 적용)
- **바람 UI 인디케이터** (좌하단, 길쭉한 ▲ 화살표 + 세기 텍스트)
- **바람 시각 이펙트** (Trail 기반, 테이블 전체에 바람 방향 줄무늬)
- **TurnChanged에서 상대 프리뷰/가이드 도트 정리** (타임아웃 시 잔류 방지)

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

| Zone | Z_OFFSET | Slots | Labels | Base Pts |
|------|----------|-------|--------|----------|
| 1 | -12 | 7 | D,C,B,A,B,C,D | 1 |
| 2 | 6 | 5 | C,B,A,B,C | 2 |
| 3 | 24 | 3 | B,A,B | 5 |

### Slot Labels Count (미션용)
- A×3 (Zone1×1, Zone2×1, Zone3×1)
- B×6 (Zone1×2, Zone2×2, Zone3×2)
- C×4 (Zone1×2, Zone2×2)
- D×2 (Zone1×2)

### Tray Design
- **반원 벽**: 10개 수평 스트립, 폭=2√(R²-d²), 높이=POST_HEIGHT, CanCollide=true
- **사각 포스트**: 0.3×0.8×0.8, 직선변 위 일렬 배치
- **슬롯 간격**: 공 지름(1.0)+0.15 = 1.15 studs
- **모든 존 동일 크기** (PLATE_RADIUS=5.0), 포스트 수만 다름

## Rules

### Turn System
- 플레이어 vs AI/상대 교대
- 공 **8개**씩
- **게임 타이머 없음** — 양쪽 공 다 쓰면 종료
- **성공 시 보너스 턴** (슬롯 안착 → 같은 팀 다시 턴, **공 소모 없음**, "BONUS TURN!" 표시)
- **20초 턴 제한** (타임아웃 = 턴 넘김, 보너스 턴이면 공 소모 안 함)
- **선턴**: AI전=플레이어 선턴, PvP=랜덤
- **턴 균형**: 한쪽 공 소진 시 상대에게 마지막 1턴 부여 후 종료

### Scoring (콤보 시스템)
- **콤보 점수**: 트레이 내 인접한 내 공 체인 길이에 따라 점수 증가
  - 첫 공: base_pts (1/2/5)
  - 옆에 이어 넣으면: base_pts + 1
  - 또 옆에: base_pts + 2, ...
  - 체인 길이 ≥ 2일 때 **"Nx Combo!"** 화면 중앙 팝업
- **올킬 (All Kill)**: 트레이 전체를 내 공으로 채우면 마지막 공 **2배** 점수
  - **"All Kill!"** 빨간색 팝업
- **미션 카드 레이스**:
  - 매치마다 3개 미션 생성 (쉬움/보통/어려움)
  - 슬롯 라벨(A/B/C/D) 수집, 모든 트레이 합산
  - 양 팀이 같은 미션 경쟁, 먼저 달성한 쪽이 선점

| Difficulty | Letters | Bonus | Examples |
|-----------|---------|-------|---------|
| Easy (1) | 3개 | +3 | A-B-C, B-C-D |
| Medium (2) | 4개 | +6 | A-B-C-D, A-A-B-C |
| Hard (3) | 5개 | +10 | A-A-B-C-D, B-B-C-C-A |

### Ball Persistence
- 슬롯 밖에서 멈춘 공 = **삭제 안 됨** (looseBalls)
- 후속타로 밀어넣으면 점수 인정
- **Y<1** 또는 **Z<SPAWN_Z** 이면 즉시 삭제

## Rank System

### 규칙
- **시작점**: 1,000, **최소**: 0
- **DataStore 영속** (UncballRanks_v1, key: rank_{userId})
- **AI전**: 승리 +10, 무승부 +3, 패배 0
- **PvP**: ELO (K=40)
  - 기대 승률 = 1 / (1 + 10^((상대-내) / 400))
  - 승리: +K×(1-기대승률) ≈ +20~40
  - 패배: -K×기대승률 ≈ -20~40
  - 상대 퇴장 = 내 승리 처리

### UI
- **로비**: 닉네임 (흰색 FredokaOne) + 금색 점수 (FredokaOne, 스트로크 3)
  - PC: 우하단 우측 정렬, 모바일: 메뉴 패널 위 중앙 정렬
- **인게임**: 스코어보드 바로 위 "R 1250" (금색, GothamBold, AI전 상대 숨김)
- **결과 화면**: "1010 ( +10 )" — 증가=금색, 감소=적색, 무변동=회색

### 데이터 흐름
- PlayerAdded → RankManager.load() → RankUpdate 전송
- MatchStart → myRank, opponentRank 포함
- _endMatch → 랭크 계산 → MatchEnd에 rankChange/newRank 포함
- PlayerRemoving → RankManager.save() + unload

## Wind System

### 규칙
- **턴마다 새로 생성** (양쪽 동일 바람)
- **세기 분포** (가중 랜덤):
  - 3~5 m/s: 70% (미미)
  - 6~8 m/s: 20% (체감)
  - 9~12 m/s: 10% (강풍)
- **방향**: 0~360도 랜덤 (X-Z 평면)
- **물리**: VectorForce, Force = direction × speed × mass × 0.15, 8초 지속
- **AI 보정**: 바람 X성분 반대로 스핀 소폭 조정 (skill 비례)

### UI
- **인디케이터**: 좌하단 (이모지 버튼 위, Y=-340)
  - 길쭉한 ▲ (14×46, TextScaled, Rotation=angle-90)
  - 세기 텍스트 "5m/s" (GothamBold, 11px)
  - 강풍(8+) 시 빨간색, 보통 연파랑
- **시각 이펙트**: Trail 기반 줄무늬 (스핀 트레일과 같은 스타일)
  - 투명 Part + Attachment 2개 + Trail
  - 연파랑 (160,200,255→100,150,230) 그라데이션
  - 바람 방향으로 날아가며 꼬리 남김
  - 테이블 전체 영역에 고르게 분포
  - TurnChanged에서 windData 수신 → 방향/Rate 갱신

### TurnChanged 확장
- `TurnChanged(isPlayerTurn, remainingBalls, isBonus, windData)`
- windData = {speed, angle}

## Lobby System

### Flow
1. 입장 → 로비 화면 (연파랑 그라데이션 배경) + **BGM 랜덤 재생**
2. PC: 좌측 캐릭터 ViewportFrame + 우측 타이틀/메뉴 + **우하단 랭크**
3. 모바일: 상단 타이틀 + 중앙 캐릭터 + **중앙 랭크** + 하단 버튼
4. PLAY 클릭 → "MATCHING..." → 5초 대기 → AI 매치 (큐 유지)
5. 매치 종료 → 결과 5초 (랭크 변동 표시) → 암전 → 로비 복귀 + **랭크 갱신**

## Launch System (슬링샷 방식)

### Physics
- SPAWN_Z = -40
- MIN_POWER = 20, MAX_POWER = 54
- INCLINE_FORCE = 8
- SPIN: MAX_LATERAL_FORCE = **20**, VectorForce 6초 지속
- **WIND**: VectorForce, FORCE_SCALE=**0.22**, 8초 지속
- 스핀 이펙트: AngularVelocity + 나선형 Trail + 방향 ParticleEmitter

## AI System

### Strategy
- 벽 바로 옆에서 발사 (spawnX: ±8~9)
- **완전 직진 발사** direction=(0,0,1)
- **스핀으로만 커브**: -side × (**0.10~0.16**)
- 존별 파워 프리셋: Zone1=31, Zone2=40, Zone3=47
- 소폭 오차: power ±0.7, spin ±0.007 (skill=0.65)
- **바람 보정**: windX × -0.008 × skill 만큼 스핀 보정
- **랜덤 닉네임**: 30개 로블록스 스타일 이름 풀

## HUD (시뮬레이터 UI 테마)

### Layout
- **상단**: 턴 인디케이터 패널 (턴 시작 시 2초간 표시 후 페이드)
  - "YOUR TURN" / "BONUS TURN!" / 상대 이름
  - 볼 카운트 도트 8개 (팀색 채움 = 사용, 흰색 = 미사용)
- **상단 고정**: 턴 타이머 (20초 카운트다운, 내 턴+상대 턴 모두 표시)
- **하단**: 스코어보드 [내이름 점수] [VS] [점수 상대이름]
  - 스코어보드 바로 위: 양쪽 랭크 라벨 ("R 1250", 금색)
- **좌측**: 미션 카드 패널 (PC 고정 270px, 모바일 토글 240px, ZIndex=8)
- **좌측 중앙**: 3D 스핀 인디케이터 (에이밍 중만, 화면 28% 위치)
- **좌하단**: 바람 인디케이터 (Y=-340, ▲ 회전 + 세기)
- **좌하단**: 이모지 버튼 (골드 그라데이션, Y=-280)
- **좌하단**: M 버튼 (모바일 미션 토글, 시안 그라데이션, Y=-225)

## File Structure

```
src/
  shared/
    Config.luau
  server/
    init.server.luau      (매칭 + 리모트 + 랭크 로드/저장)
    TableBuilder.luau
    GameManager.luau       (PvP, 콤보, 올킬, 바람, 랭크 계산)
    AIPlayer.luau          (바람 보정 포함)
    RankManager.luau       (DataStore 랭크 관리, ELO 계산)
  client/
    init.client.luau       (이벤트 + 암전 + BGM + 바람 Trail 이펙트)
    LobbyController.luau   (로비 UI + 캐릭터 뷰포트 + 랭크 표시)
    LaunchController.luau
    UIController.luau      (HUD + 이모지 + 바람 인디케이터 + 콤보 팝업 + 랭크)
    CameraController.luau  (LOBBY 상태 포함, tableOffset 추적)
```

## Key Config Values
- TABLE: 90×25, HEIGHT=3
- ZONES: Z=-12, 6, 24
- BALL: RADIUS=0.5, DENSITY=3.5
- GAME: **8 balls**, 20s turn, settle_timeout=**12s**, BALL_OUT_Y=**1**, ALL_KILL_MULTIPLIER=**2**
- SLOT: DETECT_RADIUS=**0.65**, 안착 속도 임계값=**1.2**
- LAUNCH: MIN=20, MAX=54, SPAWN_Z=-40, X_RANGE=**11**
- SPIN: MAX_LATERAL_FORCE=**20**, SENSITIVITY=**0.006**, DEADZONE=**20px**
- WIND: FORCE_SCALE=**0.22**, DURATION=**8s**
- AI: SKILL=0.65, ZONE_PRESETS={Z1:31, Z2:40, Z3:47}, SPIN=0.10~0.16, **30 NAMES**
- MISSIONS: EASY=+3(**3글자**), MEDIUM=+6(**4글자**), HARD=+10(**5글자**)
- RANK: DEFAULT=**1000**, PVP_K=**40**, AI_WIN=**+10**, AI_DRAW=**+3**
- CAMERA: LOBBY=(0,100,-200), OVERVIEW=(0,55,-50), LAUNCH=(0,10,-52)
- LOBBY: MATCH_TIMEOUT=**5s**
- TABLE_SPACING=**100**

## Remotes
RequestLaunch, GameStateUpdate, BallLanded, TurnChanged, MatchStart, MatchEnd, BallCreated, RequestMatch, MatchFound, CancelMatchmaking, MatchCancelled, PreviewUpdate, TimingGrade, SendEmoji, **RankUpdate**, **WindUpdate**

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

## Ball Settle Guard
- 턴 넘기기 전 모든 공 정지 2단계 확인 (vel<0.4 → 1초 대기 → 재확인)
- **속도 1.2 이하일 때만 슬롯 안착 체크** (빠르게 지나가는 공 스냅 방지)
- **슬롯 중앙으로 정확히 스냅** (클라이언트 간 위치 동기화)
- 최대 12초 대기 후 강제 진행

## Remaining Work
1. 보상/스킨 시스템
2. 레벨 디자인 변형

When the user asks you to work on any aspect of this game, reference these rules and design specs to ensure consistency.
