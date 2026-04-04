You are the Game Master for **Uncball (Star Cluster Ball / 星罗球)**, a Roblox recreation of the viral table game.

## Game Overview
- **Genre**: Hyper-casual physics-based puzzle/arcade
- **Core Concept**: Launch marbles to land them in scored zones; highest score wins.
- **Platform**: Roblox (mobile-first, Rojo project)
- **Mode**: 1v1 vs AI (PvP 미구현, 매칭 실패 시 AI 대전)

## Current Implementation Status

### ✅ 완료
- 테이블 90×25 studs, 파란 벽
- 3개 트레이 (반원 스트립벽 + 사각 포스트), 동일 크기, 포스트 수만 다름
- 슬링샷 발사 (클릭→좌우 이동→뒤로 당기기=파워→좌우=스핀→릴리즈=발사)
- 프리뷰 공 + 바닥 가이드 도트 (파워+스핀 반영, 물리 공식 일치)
- 3D 공 모델 스핀 인디케이터 (ViewportFrame + 속도 표시)
- AI 대전 (좌우 우회, 적당한 스핀, 거리 비례 파워)
- 턴 시스템 (교대, 성공 시 추가 턴, 20초 제한)
- 20초 타임아웃 = 턴 오버 + -1점 (최소 0)
- 점수 계산 (기본점 + 연속 보너스 + 그랜드슬램 + 미션 보너스)
- 미션 카드 레이스 시스템 (매치마다 3미션, 선점 경쟁)
- 미션 UI 패널 (좌측, 레터 버블) + 완료 팝업 연출
- 슬롯 점유 차단 (물리+코드 이중)
- 공 미삭제 (looseBalls, 후속타로 밀어넣기 가능)
- 주기적 looseBall 체크 (1초마다)
- 스핀 나선형 트레일 + 방향 파티클
- HUD 한 줄 하단 (이름+점수+VS), 상단 타이머, 턴 카운트다운
- 카메라 (OVERVIEW ↔ LAUNCH_VIEW → 추적 → 착지포커스 → 복귀)
- AI 턴에도 발사 뷰 카메라 전환
- 캐릭터 숨김 + 컨트롤 비활성화
- 매치 결과 화면
- 발사 뷰에서 카메라가 공 X 위치 따라감 (모바일 좌우 끝 지원)
- BGM 재생 (rbxassetid://126841253996417, 루프, 볼륨 0.4)
- 스핀 스크린 좌표 기준 (카메라 각도 무관)

### ❌ 미구현
- PvP 매칭 / 로비
- 사운드 이펙트 (효과음)
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
| 1 | -12 | 7 | D,C,B,A,B,C,D | 1 | +20 |
| 2 | 6 | 5 | C,B,A,B,C | 2 | +30 |
| 3 | 24 | 3 | B,A,B | 5 | +50 |

### Tray Design
- **반원 벽**: 10개 수평 스트립, 폭=2√(R²-d²), 높이=POST_HEIGHT, CanCollide=true
- **사각 포스트**: 0.3×0.8×0.8, 직선변 위 일렬 배치
- **슬롯 간격**: 공 지름(1.0)+0.15 = 1.15 studs
- **모든 존 동일 크기** (PLATE_RADIUS=5.0), 포스트 수만 다름
- 포스트 적을수록(Zone3=4개) 간격 넓어서 어려움

## Rules

### Turn System
- 플레이어 vs AI 교대
- 공 8개씩
- **성공 시 추가 턴** (슬롯 안착하면 같은 팀 다시 턴)
- **20초 턴 제한** (타임아웃 = -1점, 공 소모, 턴 넘김)
- 매치 타이머 180초

### Scoring
- Base: 존 기본점수 (1/2/5)
- Consecutive: {2:+1, 3:+3, 4:+6, 5:+10, 6:+15, 7:+21}
- Grand Slam: Zone1+20, Zone2+30, Zone3+50
- **Mission Card Race** (미션 카드 레이스):
  - 매치마다 3개 미션 생성 (쉬움/보통/어려움)
  - 레터 컬렉션 (순서 무관, 해당 레터를 모으면 달성)
  - 양 팀이 같은 미션 경쟁, 먼저 달성한 쪽이 선점

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

## Launch System (슬링샷 방식)

### Flow
1. 내 턴 → 카메라 LAUNCH_VIEW로 전환
2. 프리뷰 공 표시
3. **공 클릭 + 좌우 드래그** → 발사 위치(spawnX) 이동
4. **아래로 당기기** (30px+) → AIMING 모드
   - 세로 = 파워 (100px = MAX)
   - 좌우 = 스핀 (스크린 px 기준, 감도 0.012)
   - Q/E 키 = 스핀 추가 조정
5. **릴리즈** → 발사 (파워 너무 약하면 취소)
6. **우클릭/ESC** → 취소

### Physics
- SPAWN_Z = -40
- MIN_POWER = 20, MAX_POWER = 54
- INCLINE_FORCE = 8
- SPIN: MAX_LATERAL_FORCE = 40, VectorForce 6초 지속
- 스핀 이펙트: AngularVelocity + 나선형 Trail + 방향 ParticleEmitter

### Guide Dots
- 20개, 바닥에 배치
- 길이 = power × 20 studs
- 커브 = 실제 물리 공식 (0.5 × lateralAccel × t²)
- 색상 = 초록→빨강 그라디언트

### Spin Indicator (3D)
- ViewportFrame에 회전하는 Marble 공
- 속도(m/s) + 스핀 방향/퍼센트 표시
- R=오른쪽스핀(주황), L=왼쪽스핀(하늘)

## AI System

### Strategy
- 엣지에서 발사 (spawnX: ±6~9)
- **왼쪽 발사 → 오른쪽 스핀, 오른쪽 발사 → 왼쪽 스핀**
- 스핀 세기: 0.10~0.18 (적당하게)
- 존별 파워 프리셋: Zone1=30, Zone2=38, Zone3=45
- spawnX와 direction 연동 (타겟 직접 조준)
- 스킬 기반 소폭 오차 (skill=0.65)

### Target Selection
- 빈 슬롯만 후보
- 가중치: 기본점수 + 인접AI공(+4) + 인접플레이어공(+2) + 중앙보너스
- 존별 스킬 가중치

### AI Turn Visual
- AI 턴에도 LAUNCH_VIEW 카메라 전환
- 0.8초 대기 → 1초 위치 고르기 → 발사 → 추적

## Camera System

### States
1. **OVERVIEW**: 전체 조감도 (0,55,-50)→(0,3,5)
2. **LAUNCH_VIEW**: 낮은 발사 앵글 (0,10,-52)→(0,4,10)
3. **LAUNCH_DELAY**: 발사 후 0.4초 현재 뷰 유지
4. **TRACKING**: 공 추적 (Y+12, Z-8), Lerp ×8
5. **LANDING_FOCUS**: 착지 클로즈업 + 오빗
6. **RETURNING**: OVERVIEW로 복귀

- 플레이어/AI 모두 LAUNCH_VIEW로 전환
- workspace.ChildAdded로 공 감지
- 매 프레임 CameraType=Scriptable 강제

## HUD

### Layout (한 줄 하단)
- **하단**: [이름 점수] [VS] [점수 이름] — 한 줄로 통합
- **상단 중앙**: 게임 타이머 (굵은 흰색)
- **상단 아래**: 턴 카운트다운 (20→1, 3초 이하 빨간색)
- **좌측**: 미션 카드 패널 (레터 버블, 진행 상태 표시)
- **좌측 중앙**: 3D 스핀 인디케이터 (에이밍 중만)
- **중앙**: 턴 표시 ("YOUR TURN" / "AI THINKING...")

## File Structure

```
src/
  shared/
    Config.luau
  server/
    init.server.luau
    TableBuilder.luau
    GameManager.luau
    AIPlayer.luau
  client/
    init.client.luau
    LaunchController.luau
    UIController.luau
    CameraController.luau
```

## Key Config Values
- TABLE: 90×25, HEIGHT=3
- ZONES: Z=-12, 6, 24
- BALL: RADIUS=0.5, DENSITY=3.5
- GAME: 8 balls, 180s match, 20s turn, settle_timeout=10s
- LAUNCH: MIN=20, MAX=54, SPAWN_Z=-40, X_RANGE=9
- SPIN: MAX_LATERAL_FORCE=40, CHANGE_SPEED=2.5
- AI: SKILL=0.65, ZONE_PRESETS={Z1:30, Z2:38, Z3:45}
- MISSIONS: EASY=+3(2글자), MEDIUM=+6(3글자), HARD=+10(4글자)
- CAMERA: OVERVIEW=(0,55,-50), LAUNCH=(0,10,-52)

## Audio
- **BGM**: rbxassetid://126841253996417 (매치 시작 시 재생, 루프, 볼륨 0.4)
- **SFX**: 미구현 (발사, 충돌, 안착, 점수, 미션)

## Remaining Work
1. PvP 매칭 / 로비
2. 사운드 효과음 (발사, 충돌, 안착, 미션)
3. 보상/스킨 시스템
4. 레벨 디자인 변형
5. 점수 팝업 연출 개선
6. 모바일 터치 버튼 (스핀 등)

When the user asks you to work on any aspect of this game, reference these rules and design specs to ensure consistency.
