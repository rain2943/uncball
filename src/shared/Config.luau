local Config = {}

-- 테이블 물리적 구조
Config.TABLE = {
	WIDTH = 20,
	LENGTH = 55,
	THICKNESS = 1,
	HEIGHT = 3,
	WALL_HEIGHT = 3,
	WALL_THICKNESS = 0.6,
	COLOR = Color3.fromRGB(235, 232, 228),
	WALL_COLOR = Color3.fromRGB(45, 75, 180), -- 파란 벽 (레퍼런스)
	MATERIAL = Enum.Material.SmoothPlastic,
}

-- 핀/기둥 설정
Config.PIN = {
	DIAMETER = 0.4,
	HEIGHT = 1.6,
	COLOR = Color3.fromRGB(200, 195, 185),
	MATERIAL = Enum.Material.SmoothPlastic,
}

-- 점수 구역 (반원형 섬)
Config.ZONES = {
	[1] = {
		SLOTS = 7,
		Z_OFFSET = 2,
		RADIUS = 7,
		BASE_POINTS = 1,
		LABELS = { "D", "C", "B", "A", "B", "C", "D" },
		GRAND_SLAM_BONUS = 20,
		COLOR = Color3.fromRGB(245, 242, 238),
	},
	[2] = {
		SLOTS = 5,
		Z_OFFSET = 13,
		RADIUS = 5.5,
		BASE_POINTS = 2,
		LABELS = { "C", "B", "A", "B", "C" },
		GRAND_SLAM_BONUS = 30,
		COLOR = Color3.fromRGB(245, 242, 238),
	},
	[3] = {
		SLOTS = 3,
		Z_OFFSET = 22,
		RADIUS = 4,
		BASE_POINTS = 5,
		LABELS = { "B", "A", "B" },
		GRAND_SLAM_BONUS = 50,
		COLOR = Color3.fromRGB(245, 242, 238),
	},
}

-- 슬롯 (핀 사이 간격 — 공이 안착하는 곳)
Config.SLOT = {
	DETECT_RADIUS = 2.0,
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
	BALLS_PER_PLAYER = 8,
	MATCH_TIME = 180,
	BALL_SETTLE_VELOCITY = 0.4,
	BALL_SETTLE_TIMEOUT = 5,
	BALL_OUT_Y = 0,
	CONSECUTIVE_BONUS = { [2] = 1, [3] = 3, [4] = 6, [5] = 10, [6] = 15, [7] = 21 },
}

-- 발사 시스템
Config.LAUNCH = {
	MIN_POWER = 18,
	MAX_POWER = 75,
	SPAWN_Z = -24,
	SPAWN_Y_OFFSET = 1.5,
}

-- 스핀 시스템
Config.SPIN = {
	MAX_LATERAL_FORCE = 12, -- 최대 횡방향 임펄스
	CHANGE_SPEED = 2.5, -- 초당 스핀 변화량
}

-- 경사 시뮬레이션
Config.INCLINE_FORCE = 8

-- AI 설정
Config.AI = {
	SKILL = 0.65,
	THINK_TIME_MIN = 1.2,
	THINK_TIME_MAX = 2.8,
	AIM_ERROR_MAX = 2.5,
	POWER_ERROR_MAX = 8,
}

-- 카메라
Config.CAMERA = {
	DEFAULT_OFFSET = Vector3.new(0, 45, -40),
	DEFAULT_LOOK_AT = Vector3.new(0, 3, 3),
	LANDING_DISTANCE = 7,
	LANDING_HEIGHT = 5,
	TRANSITION_SPEED = 4,
	RETURN_SPEED = 2.5,
	VELOCITY_THRESHOLD = 4,
	HOLD_TIME = 1.2,
}

-- RemoteEvent 이름
Config.REMOTES = {
	"RequestLaunch",
	"GameStateUpdate",
	"BallLanded",
	"TurnChanged",
	"MatchStart",
	"MatchEnd",
	"BallCreated",
}

return Config
