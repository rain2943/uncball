local Config = {}

-- 멀티 테이블
Config.TABLE_SPACING = 100 -- 동시 매치 시 테이블 간 X 간격 (studs)

-- 테이블
Config.TABLE = {
	WIDTH = 25,
	LENGTH = 90,
	THICKNESS = 1,
	HEIGHT = 3,
	WALL_HEIGHT = 3,
	WALL_THICKNESS = 0.6,
	COLOR = Color3.fromRGB(235, 232, 228),
	WALL_COLOR = Color3.fromRGB(45, 75, 180),
	MATERIAL = Enum.Material.SmoothPlastic,
}

-- 점수 구역
Config.ZONES = {
	[1] = {
		SLOTS = 7,
		Z_OFFSET = -12,
		RADIUS = 7,
		BASE_POINTS = 1,
		LABELS = { "D", "C", "B", "A", "B", "C", "D" },
		GRAND_SLAM_BONUS = 3,
		COLOR = Color3.fromRGB(245, 242, 238),
	},
	[2] = {
		SLOTS = 5,
		Z_OFFSET = 6,
		RADIUS = 5.5,
		BASE_POINTS = 2,
		LABELS = { "C", "B", "A", "B", "C" },
		GRAND_SLAM_BONUS = 5,
		COLOR = Color3.fromRGB(245, 242, 238),
	},
	[3] = {
		SLOTS = 3,
		Z_OFFSET = 24,
		RADIUS = 4,
		BASE_POINTS = 5,
		LABELS = { "B", "A", "B" },
		GRAND_SLAM_BONUS = 9,
		COLOR = Color3.fromRGB(245, 242, 238),
	},
}

-- 슬롯
Config.SLOT = {
	DETECT_RADIUS = 0.65,
}

-- 공
Config.BALL = {
	RADIUS = 0.5,
	DENSITY = 3.5,
	FRICTION = 0.35,
	ELASTICITY = 0.12,
	COLORS = {
		RED = Color3.fromRGB(210, 45, 55),
		BLUE = Color3.fromRGB(50, 85, 210),
	},
}

-- 게임 규칙
Config.GAME = {
	BALLS_PER_PLAYER = 10,
	TURN_TIME = 30,
	BALL_SETTLE_VELOCITY = 0.3,
	BALL_SETTLE_TIMEOUT = 12,
	BALL_OUT_Y = 1,
	CONSECUTIVE_BONUS = { [2] = 1, [3] = 3, [4] = 6, [5] = 10, [6] = 15, [7] = 21 },
}

-- 발사 (플릭 방식)
Config.LAUNCH = {
	MIN_POWER = 20,
	MAX_POWER = 54,
	SPAWN_Z = -40,
	SPAWN_Y_OFFSET = 1.5,
	SPAWN_X_RANGE = 11,
	FLICK_MIN_SPEED = 80, -- 최소 마우스 속도 (px/s) — 이하면 취소
	FLICK_MAX_SPEED = 1200, -- 이 속도에서 MAX_POWER
	VELOCITY_SAMPLES = 10, -- 속도 계산용 샘플 수 (많을수록 안정적)
}

-- 스핀
Config.SPIN = {
	MAX_LATERAL_FORCE = 20,
	CHANGE_SPEED = 2.5,
}

-- 경사
Config.INCLINE_FORCE = 8

-- AI
Config.AI = {
	SKILL = 0.65,
	THINK_TIME_MIN = 1.2,
	THINK_TIME_MAX = 2.8,
	AIM_ERROR_MAX = 3.0,
	POWER_ERROR_MAX = 10,
	NAMES = {
		"xBlazeKing", "SkyDrift", "NoobMaster99", "ItzVortex",
		"DarkWolf_X", "CoolBreezy", "ProGamer2k", "ShadowFury",
		"PixelDude", "EpicNinja77", "LunarFox", "TurboMax",
		"StarBlitz", "IceStorm", "MightyDuck", "RocketBoy",
		"ZappyZ", "CrystalGem", "BoltStrike", "GhostRider",
		"NeonSpark", "SwiftEdge", "FlameHawk", "OceanWave",
		"ThunderX", "CosmicRay", "FrostyBear", "JetPilot",
		"ViperKing", "SilverFang",
	},
}

-- 카메라
Config.CAMERA = {
	-- 전체 조감도 (AI 턴, 턴 사이)
	OVERVIEW_OFFSET = Vector3.new(0, 55, -50),
	OVERVIEW_LOOK_AT = Vector3.new(0, 3, 5),
	-- 발사 뷰 (플레이어 턴, 낮은 각도)
	LAUNCH_OFFSET = Vector3.new(0, 10, -52),
	LAUNCH_LOOK_AT = Vector3.new(0, 4, 10),
	LAUNCH_TRANSITION_SPEED = 3,
	-- 공 추적
	LANDING_DISTANCE = 7,
	LANDING_HEIGHT = 5,
	TRANSITION_SPEED = 4,
	RETURN_SPEED = 2.5,
	VELOCITY_THRESHOLD = 4,
	HOLD_TIME = 1.2,
}

-- 미션 카드 시스템
Config.MISSIONS = {
	EASY_BONUS = 3,
	MEDIUM_BONUS = 6,
	HARD_BONUS = 10,
	EASY_POOL = {
		{ "A", "B", "C" },
		{ "B", "C", "D" },
		{ "A", "C", "D" },
		{ "A", "B", "D" },
		{ "B", "B", "C" },
		{ "A", "B", "B" },
	},
	MEDIUM_POOL = {
		{ "A", "B", "C", "D" },
		{ "A", "A", "B", "C" },
		{ "B", "B", "C", "D" },
		{ "A", "B", "B", "C" },
		{ "B", "C", "C", "D" },
		{ "A", "B", "C", "C" },
	},
	HARD_POOL = {
		{ "A", "A", "B", "C", "D" },
		{ "A", "B", "B", "C", "D" },
		{ "B", "B", "C", "C", "A" },
		{ "A", "A", "B", "B", "C" },
		{ "A", "B", "C", "C", "D" },
		{ "B", "B", "B", "C", "A" },
	},
}

-- 로비
Config.LOBBY = {
	MATCH_TIMEOUT = 5, -- 매칭 대기 시간 (초)
	-- 로비 카메라: 빈 하늘을 보도록 (UI가 덮으므로 상관없음)
	CAMERA_POS = Vector3.new(0, 100, -200),
	CAMERA_LOOK = Vector3.new(0, 100, 0),
}

-- RemoteEvent
Config.REMOTES = {
	"RequestLaunch",
	"GameStateUpdate",
	"BallLanded",
	"TurnChanged",
	"MatchStart",
	"MatchEnd",
	"BallCreated",
	"RequestMatch",
	"MatchFound",
	"CancelMatchmaking",
	"MatchCancelled",
	"PreviewUpdate",
	"TimingGrade",
	"SendEmoji",
}

return Config
