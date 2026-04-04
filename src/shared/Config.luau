local Config = {}

-- 테이블 물리적 구조
Config.TABLE = {
	WIDTH = 20,
	LENGTH = 70, -- 55→70 (트레이 간격 확보)
	THICKNESS = 1,
	HEIGHT = 3,
	WALL_HEIGHT = 3,
	WALL_THICKNESS = 0.6,
	COLOR = Color3.fromRGB(235, 232, 228),
	WALL_COLOR = Color3.fromRGB(45, 75, 180),
	MATERIAL = Enum.Material.SmoothPlastic,
}

-- 점수 구역 (간격 넓힘)
Config.ZONES = {
	[1] = {
		SLOTS = 7,
		Z_OFFSET = -8,
		RADIUS = 7,
		BASE_POINTS = 1,
		LABELS = { "D", "C", "B", "A", "B", "C", "D" },
		GRAND_SLAM_BONUS = 20,
		COLOR = Color3.fromRGB(245, 242, 238),
	},
	[2] = {
		SLOTS = 5,
		Z_OFFSET = 6,
		RADIUS = 5.5,
		BASE_POINTS = 2,
		LABELS = { "C", "B", "A", "B", "C" },
		GRAND_SLAM_BONUS = 30,
		COLOR = Color3.fromRGB(245, 242, 238),
	},
	[3] = {
		SLOTS = 3,
		Z_OFFSET = 18,
		RADIUS = 4,
		BASE_POINTS = 5,
		LABELS = { "B", "A", "B" },
		GRAND_SLAM_BONUS = 50,
		COLOR = Color3.fromRGB(245, 242, 238),
	},
}

-- 슬롯
Config.SLOT = {
	DETECT_RADIUS = 1.0,
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
	TURN_TIME = 10, -- 턴 제한시간
	BALL_SETTLE_VELOCITY = 0.4,
	BALL_SETTLE_TIMEOUT = 10,
	BALL_OUT_Y = -5,
	CONSECUTIVE_BONUS = { [2] = 1, [3] = 3, [4] = 6, [5] = 10, [6] = 15, [7] = 21 },
}

-- 발사 시스템
Config.LAUNCH = {
	MIN_POWER = 18,
	MAX_POWER = 75,
	SPAWN_Z = -30, -- 더 뒤로
	SPAWN_Y_OFFSET = 1.5,
	SPAWN_X_RANGE = 7, -- 좌우 이동 범위
}

-- 스핀 시스템
Config.SPIN = {
	MAX_LATERAL_FORCE = 40,
	CHANGE_SPEED = 2.5,
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
	DEFAULT_OFFSET = Vector3.new(0, 50, -48),
	DEFAULT_LOOK_AT = Vector3.new(0, 3, 3),
	LANDING_DISTANCE = 7,
	LANDING_HEIGHT = 5,
	TRANSITION_SPEED = 4,
	RETURN_SPEED = 2.5,
	VELOCITY_THRESHOLD = 4,
	HOLD_TIME = 1.2,
}

-- 콤보 시스템
Config.COMBOS = {
	PAIR = { name = "Pair", bonus = 2, icon = "2x", desc = "Same letter x2 in one zone" },
	CROSS_PAIR = { name = "Cross Pair", bonus = 3, icon = "X2", desc = "Same letter in 2 zones" },
	STRAIGHT = { name = "Straight", bonus = 5, icon = "ABC", desc = "A + B + C across zones" },
	TRIPLE_MATCH = { name = "Triple Match", bonus = 8, icon = "3x", desc = "Same letter in all 3 zones" },
	FULL_STRAIGHT = { name = "Full Straight", bonus = 10, icon = "ABCD", desc = "One of each A, B, C, D" },
	FULL_HOUSE = { name = "Full House", bonus = 15, icon = "FH", desc = "Triple Match + Cross Pair" },
	STAR_CLUSTER = { name = "Star Cluster", bonus = 25, icon = "★", desc = "A in all 3 zones + Grand Slam" },
}

-- 콤보 표시 순서 (UI용)
Config.COMBO_ORDER = { "PAIR", "CROSS_PAIR", "STRAIGHT", "TRIPLE_MATCH", "FULL_STRAIGHT", "FULL_HOUSE", "STAR_CLUSTER" }

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
