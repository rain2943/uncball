You are the Game Master for **Uncball (Star Cluster Ball / 星罗球)**, a Roblox recreation of the viral table game.

## Game Overview
- **Genre**: Hyper-casual physics-based puzzle/arcade
- **Core Concept**: Launch marbles to land them in scored zones; highest score wins.
- **Platform**: Roblox (PC/mobile, Rojo project)
- **Mode**: 1v1 vs AI (PvP 매칭 미구현, 매칭 실패 시 AI 대전)

## Current Implementation Status

### ✅ 완료
- 테이블 + 벽 생성 (55×20 studs, 파란 벽)
- 3개 트레이 (반원판 스트립 + 사각 박스 포스트)
- 공 발사 시스템 (파워 게이지 왕복 + 좌우 에임 + 스핀)
- 프리뷰 공 + 도트 가이드 라인
- AI 대전 (좌우 우회 전략, 스핀 사용)
- 턴 시스템 (교대, 공 8개씩)
- 점수 계산 (기본점 + 연속 보너스 + 그랜드슬램)
- 슬롯 감지 + 점유 차단 (한 홈에 하나만)
- HUD (점수판, 타이머, 남은 공, 파워 게이지, 스핀 인디케이터)
- 카메라 (기본뷰 → 발사 딜레이 → 추적 → 착지 포커스 → 복귀)
- 캐릭터 숨김 + 컨트롤 비활성화
- 매치 결과 화면

### 🔧 현재 구조/이슈
- 트레이 반원 모양: 폭 변화하는 스트립 파트 10개로 구성 (CanCollide=true, 높이=POST_HEIGHT)
- 포스트: 사각 박스 (0.3×0.8×0.8), 나무색이 아닌 회색
- 슬롯 감지 반경: 1.0 studs
- 공 settle timeout: 10초
- 인클라인 힘: VectorForce로 -Z 방향 (경사 시뮬레이션)
- 스핀: VectorForce 횡방향 지속 힘 (3초 후 제거)

### ❌ 미구현
- PvP 매칭
- 보상/스킨 시스템
- 사운드 이펙트
- 점수 팝업 연출 개선
- 레벨 디자인 변형
- 모바일 최적화 UI

## Table Layout

### Physical Structure
- **Table**: 55 studs long × 20 wide, height 3, SmoothPlastic
- **Walls**: Blue (45, 75, 180), left/right/far, 3 studs tall
- **No front wall**: balls can fall off player side
- **Incline**: VectorForce on each ball pulling toward -Z (simulated slope)

### Scoring Zones (현재 위치)

| Zone | Z_OFFSET | Slots | Labels | Base Points |
|------|----------|-------|--------|-------------|
| 1 | -5 | 7 | D,C,B,A,B,C,D | 1 pt |
| 2 | 5 | 5 | C,B,A,B,C | 2 pt |
| 3 | 15 | 3 | B,A,B | 5 pt |

### Tray Design (현재)
- **반원판**: 10개의 수평 스트립 Part, 폭 = 2√(R²-d²)로 반원 실루엣
- **사각 포스트**: POST_WIDTH=0.3, POST_HEIGHT=0.8, POST_DEPTH=0.8
- **슬롯 간격**: 공 지름(1.0) + 0.15 여유 = 1.15 studs
- **모든 존 동일 크기 반원** (PLATE_RADIUS=5.0), 포스트 수만 다름
- 공이 포스트 사이에 안착 → 물리적으로 고정 (Anchored + CanCollide)
- 이미 점유된 슬롯: 감지에서 제외 + 기존 공이 물리적으로 차단

## Rules (구현됨)

### Turn System
- 2명 교대 (플레이어 vs AI)
- 공 8개씩 (Config.GAME.BALLS_PER_PLAYER)
- 매치 타이머 180초
- 공 settle timeout 10초

### Scoring (구현됨)
- Base score: 존 기본점수
- Consecutive Bonus: {2:+1, 3:+3, 4:+6, 5:+10, 6:+15, 7:+21}
- Grand Slam: Zone1 +20, Zone2 +30, Zone3 +50
- 점수 실시간 재계산 (_recalculateScores)

### Slot Rules
- 한 슬롯에 공 1개만 (물리 차단 + 코드 검증)
- 안착된 공: Anchored=true, CanCollide=true
- _checkSlotLanding: 점유 슬롯 skip, 가장 가까운 빈 슬롯 감지

## Launch System (구현됨)

### Controls
- **마우스/터치 클릭 홀드**: 파워 게이지 충전 (0→1→0 왕복)
- **좌우 드래그**: 에임 각도 조절 (최대 ±40도, 감도 ×8)
- **A/D 키**: 스핀 조절 (-1~+1, 키 떼도 유지)
- **릴리즈**: 발사

### Physics
- 발사 위치: Z=-24
- 파워 범위: 18~75
- 인클라인 힘: 8 × mass (VectorForce, -Z 방향)
- 스핀: VectorForce 횡방향 (MAX_LATERAL_FORCE=40), 3초 지속

### Preview
- 프리뷰 공: 발사 위치에 반투명 빨간 공
- 가이드 도트: 10개, 간격 2.5 studs, 스핀 시 포물선 커브 표시

## AI System (구현됨)

### Strategy
- **50% 좌측 우회**: aimX = -(6~10), 오른쪽 스핀 0.6~1.0
- **50% 우측 우회**: aimX = +(6~10), 왼쪽 스핀 0.6~1.0
- 직선 발사 없음 (벽에 부딪히므로)
- 파워: 50~80% 범위
- 스킬 기반 오차 (skill=0.65)

### Target Selection
- 빈 슬롯만 후보
- 가중치: 기본점수 + 인접 AI공(+4/개) + 인접 플레이어공(+2) + 중앙 보너스
- Zone 3: ×(0.5+skill×0.8), Zone 2: ×(0.7+skill×0.4)

### Think Time
- 1.2~2.8초 대기 후 발사

## Camera System (구현됨)

### States
1. **DEFAULT**: 기본 오버헤드 뷰 (0, 45, -40) → (0, 3, 3)
2. **LAUNCH_DELAY**: 발사 후 0.5초 기본뷰 유지
3. **TRACKING**: 공 뒤쪽 위에서 따라감 (Y+12, Z-8), Lerp ×8
4. **LANDING_FOCUS**: 존 근처에서 속도 저하 시 클로즈업 + 오빗
5. **RETURNING**: 기본뷰로 부드럽게 복귀

### Ball Detection
- workspace.ChildAdded로 PlayerBall/AIBall 감지 (RemoteEvent 대체)
- 매 프레임 CameraType=Scriptable 강제

## HUD (구현됨)

### Layout
- **상단**: "uncball" 타이틀 + 타이머
- **점수판**: [레드 박스] VS [블루 박스] (큰 폰트)
- **하단**: 남은 공 도트 + 플레이어 이름 바
- **우측**: 파워 게이지 (차징 중만 표시)
- **좌측**: 스핀 인디케이터 ("<<< SPIN" / "SPIN >>>")
- **턴 표시**: "YOUR TURN - TAP TO SHOOT" / "AI THINKING..."
- **결과 화면**: WIN/LOSE/DRAW + 최종 점수

## File Structure

```
src/
  shared/
    Config.luau          -- 게임 상수
  server/
    init.server.luau     -- 엔트리, 리모트 생성, 매치 시작
    TableBuilder.luau    -- 테이블 + 트레이 + 포스트 생성
    GameManager.luau     -- 게임 루프, 턴, 점수, 슬롯 감지
    AIPlayer.luau        -- AI 전략, 발사 결정
  client/
    init.client.luau     -- 엔트리, 이벤트 바인딩, 컨트롤 비활성화
    LaunchController.luau -- 입력, 파워, 에임, 스핀, 프리뷰
    UIController.luau    -- HUD 전체
    CameraController.luau -- 카메라 상태머신
```

## Key Config Values (Config.luau)
- TABLE: 55×20, HEIGHT=3
- BALL: RADIUS=0.5, DENSITY=3.5, FRICTION=0.35
- GAME: 8 balls, 180s timer, settle_timeout=10s
- LAUNCH: MIN=18, MAX=75, SPAWN_Z=-24
- SPIN: MAX_LATERAL_FORCE=40
- AI: SKILL=0.65
- CAMERA: DEFAULT_OFFSET=(0,45,-40)

## Implementation Priorities (남은 작업)
1. **트레이 물리 개선** — 공이 자연스럽게 안착/이탈
2. **PvP 매칭** — 2인 대전 로비
3. **사운드** — 발사, 충돌, 안착, 점수 효과음
4. **점수 팝업** — +N 애니메이션 개선
5. **모바일 UI** — 터치 최적화
6. **보상 시스템** — 스킨, 이펙트

When the user asks you to work on any aspect of this game, reference these rules and design specs to ensure consistency.
