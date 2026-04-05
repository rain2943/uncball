local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local UIController = {}
UIController.__index = UIController

local RED = Config.BALL.COLORS.RED
local BLUE = Config.BALL.COLORS.BLUE

-- 시뮬레이터 UI 스타일 상수
local FONT_TITLE = Enum.Font.FredokaOne
local FONT_BOLD = Enum.Font.FredokaOne
local FONT_MEDIUM = Enum.Font.GothamBold
local CORNER_RADIUS = 14

local function addStroke(parent: Instance, color: Color3?, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(30, 30, 50)
	stroke.Thickness = thickness or 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = parent
	return stroke
end

local function addCorner(parent: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or CORNER_RADIUS)
	corner.Parent = parent
	return corner
end

function UIController.new()
	local self = setmetatable({}, UIController)
	self.gui = nil
	self.elements = {}
	self:_createUI()
	return self
end

function UIController:_createUI()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "UncballHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	self.gui = gui

	self:_createTopBar(gui)
	self:_createScoreBoard(gui)
	self:_createPowerGauge(gui)
	self:_createBottomBar(gui)
	self:_createTurnIndicator(gui)
	self:_createResultScreen(gui)
	self:_createMissionPanel(gui)
end

-- ===== 상단: 턴 인디케이터 + 볼 카운트 + 턴 타이머 =====
function UIController:_createTopBar(gui)
	self._playerBalls = Config.GAME.BALLS_PER_PLAYER
	self._aiBalls = Config.GAME.BALLS_PER_PLAYER
	self._opponentName = "AI"
	local maxBalls = Config.GAME.BALLS_PER_PLAYER
	local DOT_SIZE = 18
	local DOT_GAP = 5

	-- ===== 1) 턴 패널 (페이드 인/아웃) =====
	local turnPanel = Instance.new("Frame")
	turnPanel.Name = "TurnPanel"
	turnPanel.Size = UDim2.new(0, 300, 0, 80)
	turnPanel.Position = UDim2.new(0.5, -150, 0, 10)
	turnPanel.BackgroundColor3 = Color3.fromRGB(40, 42, 55)
	turnPanel.BackgroundTransparency = 0.08
	turnPanel.BorderSizePixel = 0
	turnPanel.Visible = false
	turnPanel.Parent = gui
	addCorner(turnPanel, 16)
	addStroke(turnPanel, Color3.fromRGB(25, 28, 40), 3)

	-- 턴 텍스트
	local turnText = Instance.new("TextLabel")
	turnText.Name = "TurnText"
	turnText.Size = UDim2.new(1, -16, 0, 30)
	turnText.Position = UDim2.new(0, 8, 0, 6)
	turnText.BackgroundTransparency = 1
	turnText.Text = "YOUR TURN"
	turnText.TextColor3 = Color3.fromRGB(255, 255, 255)
	turnText.Font = FONT_TITLE
	turnText.TextScaled = true
	turnText.ZIndex = 2
	turnText.Parent = turnPanel
	addStroke(turnText, Color3.fromRGB(0, 0, 0), 2)

	-- 볼 도트 컨테이너 (패널 내부 하단, 중앙 정렬)
	local dotsContainer = Instance.new("Frame")
	dotsContainer.Name = "DotsContainer"
	dotsContainer.Size = UDim2.new(1, -20, 0, DOT_SIZE + 4)
	dotsContainer.Position = UDim2.new(0, 10, 0, 40)
	dotsContainer.BackgroundTransparency = 1
	dotsContainer.Parent = turnPanel

	-- 플레이어 볼 도트 (빨강)
	local playerDots = Instance.new("Frame")
	playerDots.Name = "PlayerDots"
	playerDots.Size = UDim2.new(1, 0, 1, 0)
	playerDots.BackgroundTransparency = 1
	playerDots.Parent = dotsContainer

	local pLayout = Instance.new("UIListLayout")
	pLayout.FillDirection = Enum.FillDirection.Horizontal
	pLayout.Padding = UDim.new(0, DOT_GAP)
	pLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	pLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pLayout.Parent = playerDots

	for i = 1, maxBalls do
		local dot = Instance.new("Frame")
		dot.Name = "D" .. i
		dot.LayoutOrder = i
		dot.Size = UDim2.new(0, DOT_SIZE, 0, DOT_SIZE)
		dot.BackgroundColor3 = Config.BALL.COLORS.RED
		dot.BackgroundTransparency = 0
		dot.BorderSizePixel = 0
		dot.ZIndex = 2
		dot.Parent = playerDots
		addCorner(dot, DOT_SIZE / 2)
		addStroke(dot, Color3.fromRGB(160, 30, 40), 2)
	end

	-- AI 볼 도트 (파랑, 같은 컨테이너에 겹침 — 한쪽만 보임)
	local aiDots = Instance.new("Frame")
	aiDots.Name = "AIDots"
	aiDots.Size = UDim2.new(1, 0, 1, 0)
	aiDots.BackgroundTransparency = 1
	aiDots.Visible = false
	aiDots.Parent = dotsContainer

	local aLayout = Instance.new("UIListLayout")
	aLayout.FillDirection = Enum.FillDirection.Horizontal
	aLayout.Padding = UDim.new(0, DOT_GAP)
	aLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	aLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	aLayout.SortOrder = Enum.SortOrder.LayoutOrder
	aLayout.Parent = aiDots

	for i = 1, maxBalls do
		local dot = Instance.new("Frame")
		dot.Name = "D" .. i
		dot.LayoutOrder = i
		dot.Size = UDim2.new(0, DOT_SIZE, 0, DOT_SIZE)
		dot.BackgroundColor3 = Config.BALL.COLORS.BLUE
		dot.BackgroundTransparency = 0
		dot.BorderSizePixel = 0
		dot.ZIndex = 2
		dot.Parent = aiDots
		addCorner(dot, DOT_SIZE / 2)
		addStroke(dot, Color3.fromRGB(30, 55, 160), 2)
	end

	-- 남은 공 카운트 텍스트 (도트 옆)
	local ballCountText = Instance.new("TextLabel")
	ballCountText.Name = "BallCount"
	ballCountText.Size = UDim2.new(1, 0, 0, 16)
	ballCountText.Position = UDim2.new(0, 0, 1, 0)
	ballCountText.BackgroundTransparency = 1
	ballCountText.Text = "10 / 10"
	ballCountText.TextColor3 = Color3.fromRGB(200, 200, 210)
	ballCountText.Font = FONT_BOLD
	ballCountText.TextSize = 12
	ballCountText.ZIndex = 2
	ballCountText.Parent = dotsContainer

	self.elements.turnPanel = turnPanel
	self.elements.turnText = turnText
	self.elements.playerDotRow = playerDots
	self.elements.aiDotRow = aiDots
	self.elements.ballCountText = ballCountText

	-- ===== 2) 턴 타이머 (독립, 상단 중앙 고정) =====
	local turnTimer = Instance.new("TextLabel")
	turnTimer.Name = "TurnTimer"
	turnTimer.Size = UDim2.new(0, 70, 0, 32)
	turnTimer.Position = UDim2.new(0.5, -35, 0, 98)
	turnTimer.BackgroundColor3 = Color3.fromRGB(40, 42, 55)
	turnTimer.BackgroundTransparency = 0.08
	turnTimer.Text = "30"
	turnTimer.TextColor3 = Color3.fromRGB(255, 255, 255)
	turnTimer.TextScaled = true
	turnTimer.Font = FONT_BOLD
	turnTimer.BorderSizePixel = 0
	turnTimer.Visible = false
	turnTimer.ZIndex = 3
	turnTimer.Parent = gui -- gui에 직접 (패널 밖!)
	addCorner(turnTimer, 10)
	addStroke(turnTimer, Color3.fromRGB(25, 28, 40), 2)

	self.elements.turnTimer = turnTimer
end

-- ===== 점수판: [블루 점수] VS [레드 점수] =====
function UIController:_createScoreBoard(gui)
	local scoreRow = Instance.new("Frame")
	scoreRow.Name = "ScoreRow"
	scoreRow.Size = UDim2.new(1, -10, 0, 42)
	scoreRow.Position = UDim2.new(0, 5, 1, -47)
	scoreRow.BackgroundTransparency = 1
	scoreRow.Parent = gui

	-- 플레이어(레드) 점수 박스 — 왼쪽
	local redBox = Instance.new("Frame")
	redBox.Name = "RedScoreBox"
	redBox.Size = UDim2.new(0.43, 0, 1, 0)
	redBox.Position = UDim2.new(0, 0, 0, 0)
	redBox.BackgroundColor3 = Color3.fromRGB(220, 55, 65)
	redBox.BorderSizePixel = 0
	redBox.Parent = scoreRow
	addCorner(redBox, CORNER_RADIUS)
	addStroke(redBox, Color3.fromRGB(160, 30, 40), 2)

	local redGrad = Instance.new("UIGradient")
	redGrad.Color = ColorSequence.new(Color3.fromRGB(230, 65, 75), Color3.fromRGB(190, 40, 50))
	redGrad.Rotation = 90
	redGrad.Parent = redBox

	-- 이름
	local redName = Instance.new("TextLabel")
	redName.Name = "RedName"
	redName.Size = UDim2.new(0.55, 0, 1, 0)
	redName.Position = UDim2.new(0.03, 0, 0, 0)
	redName.BackgroundTransparency = 1
	redName.Text = Players.LocalPlayer.DisplayName
	redName.TextColor3 = Color3.fromRGB(255, 255, 255)
	redName.TextScaled = true
	redName.Font = FONT_BOLD
	redName.TextXAlignment = Enum.TextXAlignment.Left
	redName.Parent = redBox
	addStroke(redName, Color3.fromRGB(100, 20, 25), 2)
	self.elements.redName = redName

	-- 점수
	local redScore = Instance.new("TextLabel")
	redScore.Name = "RedScore"
	redScore.Size = UDim2.new(0.35, 0, 1, 0)
	redScore.Position = UDim2.new(0.62, 0, 0, 0)
	redScore.BackgroundTransparency = 1
	redScore.Text = "0"
	redScore.TextColor3 = Color3.fromRGB(255, 255, 255)
	redScore.TextScaled = true
	redScore.Font = FONT_BOLD
	redScore.Parent = redBox
	addStroke(redScore, Color3.fromRGB(100, 20, 25), 2)
	self.elements.redScore = redScore

	-- VS 뱃지 — 중앙 (턴 인디케이터와 동일 스타일)
	local vsBadge = Instance.new("Frame")
	vsBadge.Name = "VSBadge"
	vsBadge.Size = UDim2.new(0, 50, 0, 34)
	vsBadge.Position = UDim2.new(0.5, -25, 0.5, -17)
	vsBadge.BackgroundColor3 = Color3.fromRGB(50, 55, 70)
	vsBadge.BackgroundTransparency = 0.1
	vsBadge.BorderSizePixel = 0
	vsBadge.ZIndex = 2
	vsBadge.Parent = scoreRow
	addCorner(vsBadge, 12)
	addStroke(vsBadge, Color3.fromRGB(30, 35, 50), 3)

	local vsText = Instance.new("TextLabel")
	vsText.Size = UDim2.new(1, 0, 1, 0)
	vsText.BackgroundTransparency = 1
	vsText.Text = "VS"
	vsText.TextColor3 = Color3.fromRGB(255, 255, 255)
	vsText.TextScaled = true
	vsText.Font = FONT_BOLD
	vsText.ZIndex = 2
	vsText.Parent = vsBadge
	addStroke(vsText, Color3.fromRGB(20, 20, 40), 2)

	-- AI(블루) 점수 박스 — 오른쪽
	local blueBox = Instance.new("Frame")
	blueBox.Name = "BlueScoreBox"
	blueBox.Size = UDim2.new(0.43, 0, 1, 0)
	blueBox.Position = UDim2.new(0.57, 0, 0, 0)
	blueBox.BackgroundColor3 = Color3.fromRGB(50, 100, 220)
	blueBox.BorderSizePixel = 0
	blueBox.Parent = scoreRow
	addCorner(blueBox, CORNER_RADIUS)
	addStroke(blueBox, Color3.fromRGB(30, 60, 160), 2)

	local blueGrad = Instance.new("UIGradient")
	blueGrad.Color = ColorSequence.new(Color3.fromRGB(60, 110, 235), Color3.fromRGB(40, 80, 190))
	blueGrad.Rotation = 90
	blueGrad.Parent = blueBox

	-- 점수
	local blueScore = Instance.new("TextLabel")
	blueScore.Name = "BlueScore"
	blueScore.Size = UDim2.new(0.35, 0, 1, 0)
	blueScore.Position = UDim2.new(0.03, 0, 0, 0)
	blueScore.BackgroundTransparency = 1
	blueScore.Text = "0"
	blueScore.TextColor3 = Color3.fromRGB(255, 255, 255)
	blueScore.TextScaled = true
	blueScore.Font = FONT_BOLD
	blueScore.Parent = blueBox
	addStroke(blueScore, Color3.fromRGB(20, 40, 120), 2)

	-- 이름
	local blueName = Instance.new("TextLabel")
	blueName.Name = "BlueName"
	blueName.Size = UDim2.new(0.55, 0, 1, 0)
	blueName.Position = UDim2.new(0.42, 0, 0, 0)
	blueName.BackgroundTransparency = 1
	blueName.Text = "AI"
	blueName.TextColor3 = Color3.fromRGB(255, 255, 255)
	blueName.TextScaled = true
	blueName.Font = FONT_BOLD
	blueName.TextXAlignment = Enum.TextXAlignment.Right
	blueName.Parent = blueBox
	self.elements.blueName = blueName
	addStroke(blueName, Color3.fromRGB(20, 40, 120), 2)
	self.elements.blueScore = blueScore

	-- ===== 캐릭터 상반신 뷰포트 (스코어보드 양쪽 위) =====
	local CHAR_VP_W, CHAR_VP_H = 90, 110

	-- 내 캐릭터 (왼쪽)
	local myCharVP = Instance.new("ViewportFrame")
	myCharVP.Name = "MyCharViewport"
	myCharVP.Size = UDim2.new(0, CHAR_VP_W, 0, CHAR_VP_H)
	myCharVP.Position = UDim2.new(0, 0, 0, -CHAR_VP_H)
	myCharVP.BackgroundTransparency = 1
	myCharVP.Ambient = Color3.fromRGB(180, 180, 200)
	myCharVP.LightColor = Color3.fromRGB(255, 255, 255)
	myCharVP.LightDirection = Vector3.new(-1, -1, -1)
	myCharVP.Parent = scoreRow
	self.elements.myCharViewport = myCharVP

	local myWorldModel = Instance.new("WorldModel")
	myWorldModel.Parent = myCharVP
	self.elements.myCharWorldModel = myWorldModel

	-- 상대 캐릭터 (오른쪽)
	local oppCharVP = Instance.new("ViewportFrame")
	oppCharVP.Name = "OppCharViewport"
	oppCharVP.Size = UDim2.new(0, CHAR_VP_W, 0, CHAR_VP_H)
	oppCharVP.Position = UDim2.new(1, -CHAR_VP_W, 0, -CHAR_VP_H)
	oppCharVP.BackgroundTransparency = 1
	oppCharVP.Ambient = Color3.fromRGB(180, 180, 200)
	oppCharVP.LightColor = Color3.fromRGB(255, 255, 255)
	oppCharVP.LightDirection = Vector3.new(1, -1, -1)
	oppCharVP.Parent = scoreRow
	self.elements.oppCharViewport = oppCharVP

	local oppWorldModel = Instance.new("WorldModel")
	oppWorldModel.Parent = oppCharVP
	self.elements.oppCharWorldModel = oppWorldModel
end

-- ===== 캐릭터 뷰포트 로딩 =====

function UIController:_loadCharIntoViewport(viewport: ViewportFrame, worldModel, userId: number?, facingRight: boolean?)
	-- 기존 클론 정리
	for _, child in worldModel:GetChildren() do
		child:Destroy()
	end
	-- 기존 카메라 정리
	for _, child in viewport:GetChildren() do
		if child:IsA("Camera") then child:Destroy() end
	end

	task.spawn(function()
		local clone = nil

		if userId and userId == Players.LocalPlayer.UserId then
			-- 내 캐릭터: 직접 클론
			local char = Players.LocalPlayer.Character
			if not char then char = Players.LocalPlayer.CharacterAdded:Wait() end
			if not Players.LocalPlayer:HasAppearanceLoaded() then
				Players.LocalPlayer.CharacterAppearanceLoaded:Wait()
			end
			task.wait(0.3)
			local wasArchivable = char.Archivable
			char.Archivable = true
			clone = char:Clone()
			char.Archivable = wasArchivable
		elseif userId then
			-- 상대 캐릭터: UserId로 모델 생성
			local ok, model = pcall(function()
				return Players:CreateHumanoidModelFromUserId(userId)
			end)
			if ok and model then
				clone = model
			end
		end

		if not clone then return end

		-- 스크립트 제거
		for _, v in clone:GetDescendants() do
			if v:IsA("BaseScript") then v:Destroy() end
		end

		-- 위치 + 투명도 리셋
		clone:PivotTo(CFrame.new(0, 0, 0))
		for _, v in clone:GetDescendants() do
			if v:IsA("BasePart") then
				v.Transparency = v.Name == "HumanoidRootPart" and 1 or 0
			elseif v:IsA("Decal") or v:IsA("Texture") then
				v.Transparency = 0
			end
		end

		clone.Parent = worldModel

		-- 카메라 (상반신 클로즈업)
		local xDir = facingRight and -1 or 1
		local cam = Instance.new("Camera")
		cam.FieldOfView = 20
		cam.CFrame = CFrame.lookAt(
			Vector3.new(1.5 * xDir, 1.2, -5),
			Vector3.new(0, 1.0, 0)
		)
		cam.Parent = viewport
		viewport.CurrentCamera = cam

		-- Idle 애니메이션
		local humanoid = clone:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if not animator then
				animator = Instance.new("Animator")
				animator.Parent = humanoid
			end
			pcall(function()
				local idleAnim = Instance.new("Animation")
				idleAnim.AnimationId = "rbxassetid://507766388"
				local track = animator:LoadAnimation(idleAnim)
				track.Looped = true
				track:Play()
			end)
		end
	end)
end

function UIController:loadMatchCharacters(opponentId: number?)
	-- 내 캐릭터 (왼쪽, 오른쪽을 바라봄)
	self:_loadCharIntoViewport(
		self.elements.myCharViewport,
		self.elements.myCharWorldModel,
		Players.LocalPlayer.UserId,
		true -- facing right
	)

	-- 상대 캐릭터 (오른쪽, 왼쪽을 바라봄)
	if opponentId then
		self.elements.oppCharViewport.Visible = true
		self:_loadCharIntoViewport(
			self.elements.oppCharViewport,
			self.elements.oppCharWorldModel,
			opponentId,
			false -- facing left
		)
	else
		-- AI 대전: 상대 뷰포트 숨김
		self.elements.oppCharViewport.Visible = false
	end
end

function UIController:clearMatchCharacters()
	for _, wm in { self.elements.myCharWorldModel, self.elements.oppCharWorldModel } do
		if wm then
			for _, child in wm:GetChildren() do
				child:Destroy()
			end
		end
	end
end

-- ===== 파워 게이지 (우측) =====
function UIController:_createPowerGauge(gui)
	local gaugeFrame = Instance.new("Frame")
	gaugeFrame.Name = "PowerGauge"
	gaugeFrame.Size = UDim2.new(0, 28, 0.35, 0)
	gaugeFrame.Position = UDim2.new(1, -46, 0.32, 0)
	gaugeFrame.Visible = false -- 플릭 방식에서는 게이지 불필요
	gaugeFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
	gaugeFrame.BackgroundTransparency = 0.2
	gaugeFrame.BorderSizePixel = 0
	gaugeFrame.Visible = false
	gaugeFrame.Parent = gui

	local gaugeCorner = Instance.new("UICorner")
	gaugeCorner.CornerRadius = UDim.new(0, 8)
	gaugeCorner.Parent = gaugeFrame

	local gaugeFill = Instance.new("Frame")
	gaugeFill.Name = "Fill"
	gaugeFill.Size = UDim2.new(1, -6, 0, 0)
	gaugeFill.Position = UDim2.new(0, 3, 1, -3)
	gaugeFill.AnchorPoint = Vector2.new(0, 1)
	gaugeFill.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
	gaugeFill.BorderSizePixel = 0

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 5)
	fillCorner.Parent = gaugeFill

	gaugeFill.Parent = gaugeFrame

	self.elements.gaugeFrame = gaugeFrame
	self.elements.gaugeFill = gaugeFill
end

-- ===== 하단: 플레이어 정보 + 남은 공 =====
function UIController:_createBottomBar(gui)
	local bottomFrame = Instance.new("Frame")
	bottomFrame.Name = "BottomBar"
	bottomFrame.Size = UDim2.new(1, 0, 0, 0)
	bottomFrame.Position = UDim2.new(0, 0, 1, 0)
	bottomFrame.Visible = false
	bottomFrame.BackgroundTransparency = 1
	bottomFrame.Parent = gui

	-- 레드(플레이어) 남은 공 인디케이터
	local redBallRow = Instance.new("Frame")
	redBallRow.Name = "RedBallRow"
	redBallRow.Size = UDim2.new(0.45, 0, 0, 20)
	redBallRow.Position = UDim2.new(0.02, 0, 0, 0)
	redBallRow.BackgroundTransparency = 1
	redBallRow.Parent = bottomFrame

	local redLayout = Instance.new("UIListLayout")
	redLayout.FillDirection = Enum.FillDirection.Horizontal
	redLayout.Padding = UDim.new(0, 4)
	redLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	redLayout.Parent = redBallRow

	self.elements.redBallRow = redBallRow
	self:_createBallDots(redBallRow, Config.GAME.BALLS_PER_PLAYER, RED)

	-- 블루(AI) 남은 공 인디케이터
	local blueBallRow = Instance.new("Frame")
	blueBallRow.Name = "BlueBallRow"
	blueBallRow.Size = UDim2.new(0.45, 0, 0, 20)
	blueBallRow.Position = UDim2.new(0.53, 0, 0, 0)
	blueBallRow.BackgroundTransparency = 1
	blueBallRow.Parent = bottomFrame

	local blueLayout = Instance.new("UIListLayout")
	blueLayout.FillDirection = Enum.FillDirection.Horizontal
	blueLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	blueLayout.Padding = UDim.new(0, 4)
	blueLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	blueLayout.Parent = blueBallRow

	self.elements.blueBallRow = blueBallRow
	self:_createBallDots(blueBallRow, Config.GAME.BALLS_PER_PLAYER, BLUE)

	-- 플레이어 이름 바 (레드)
	local redNameBar = Instance.new("Frame")
	redNameBar.Size = UDim2.new(0.48, 0, 0, 38)
	redNameBar.Position = UDim2.new(0.01, 0, 0, 28)
	redNameBar.BackgroundColor3 = Color3.fromRGB(160, 35, 45)
	redNameBar.BorderSizePixel = 0
	redNameBar.Parent = bottomFrame

	local redNameCorner = Instance.new("UICorner")
	redNameCorner.CornerRadius = UDim.new(0, 8)
	redNameCorner.Parent = redNameBar

	local redName = Instance.new("TextLabel")
	redName.Size = UDim2.new(0.85, 0, 1, 0)
	redName.Position = UDim2.new(0.08, 0, 0, 0)
	redName.BackgroundTransparency = 1
	redName.Text = Players.LocalPlayer.DisplayName
	redName.TextColor3 = Color3.fromRGB(255, 255, 255)
	redName.TextScaled = true
	redName.Font = Enum.Font.GothamBold
	redName.TextXAlignment = Enum.TextXAlignment.Left
	redName.Parent = redNameBar

	-- AI 이름 바 (블루)
	local blueNameBar = Instance.new("Frame")
	blueNameBar.Size = UDim2.new(0.48, 0, 0, 38)
	blueNameBar.Position = UDim2.new(0.51, 0, 0, 28)
	blueNameBar.BackgroundColor3 = Color3.fromRGB(40, 70, 180)
	blueNameBar.BorderSizePixel = 0
	blueNameBar.Parent = bottomFrame

	local blueNameCorner = Instance.new("UICorner")
	blueNameCorner.CornerRadius = UDim.new(0, 8)
	blueNameCorner.Parent = blueNameBar

	local blueName = Instance.new("TextLabel")
	blueName.Size = UDim2.new(0.85, 0, 1, 0)
	blueName.Position = UDim2.new(0.07, 0, 0, 0)
	blueName.BackgroundTransparency = 1
	blueName.Text = "AI"
	blueName.TextColor3 = Color3.fromRGB(255, 255, 255)
	blueName.TextScaled = true
	blueName.Font = Enum.Font.GothamBold
	blueName.TextXAlignment = Enum.TextXAlignment.Right
	blueName.Parent = blueNameBar
end

function UIController:_createBallDots(parent, count, color)
	for i = 1, count do
		local dot = Instance.new("Frame")
		dot.Name = "Dot" .. i
		dot.Size = UDim2.new(0, 16, 0, 16)
		dot.BackgroundColor3 = color
		dot.BorderSizePixel = 0

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = dot

		dot.Parent = parent
	end
end

-- ===== 턴 인디케이터 (TopBar에 통합됨) =====
function UIController:_createTurnIndicator(_gui)
	-- 턴 인디케이터는 _createTopBar에서 생성
end

-- ===== 매치 결과 화면 =====
function UIController:_createResultScreen(gui)
	local resultFrame = Instance.new("Frame")
	resultFrame.Name = "ResultFrame"
	resultFrame.Size = UDim2.new(0, 350, 0, 160)
	resultFrame.Position = UDim2.new(0.5, -175, 0.5, -80)
	resultFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	resultFrame.BackgroundTransparency = 0.03
	resultFrame.BorderSizePixel = 0
	resultFrame.Visible = false
	resultFrame.ZIndex = 20
	resultFrame.Parent = gui
	addCorner(resultFrame, 20)
	addStroke(resultFrame, Color3.fromRGB(200, 205, 220), 3)

	local resultText = Instance.new("TextLabel")
	resultText.Name = "ResultText"
	resultText.Size = UDim2.new(0.9, 0, 0.5, 0)
	resultText.Position = UDim2.new(0.05, 0, 0.05, 0)
	resultText.BackgroundTransparency = 1
	resultText.Text = ""
	resultText.TextColor3 = Color3.fromRGB(255, 200, 40)
	resultText.TextScaled = true
	resultText.Font = FONT_TITLE
	resultText.ZIndex = 21
	resultText.Parent = resultFrame
	addStroke(resultText, Color3.fromRGB(180, 100, 0), 3)

	local resultScore = Instance.new("TextLabel")
	resultScore.Name = "ResultScore"
	resultScore.Size = UDim2.new(0.9, 0, 0.3, 0)
	resultScore.Position = UDim2.new(0.05, 0, 0.58, 0)
	resultScore.BackgroundTransparency = 1
	resultScore.Text = ""
	resultScore.TextColor3 = Color3.fromRGB(80, 80, 100)
	resultScore.TextScaled = true
	resultScore.Font = FONT_BOLD
	resultScore.ZIndex = 21
	resultScore.Parent = resultFrame

	self.elements.resultFrame = resultFrame
	self.elements.resultText = resultText
	self.elements.resultScore = resultScore
end

-- ===== 미션 카드 패널 (좌측) =====
function UIController:_createMissionPanel(gui)
	local PAD = 8
	local CARD_H = 42
	local GAP = 5
	local panelH = PAD + 3 * CARD_H + 2 * GAP + PAD

	local panel = Instance.new("Frame")
	panel.Name = "MissionPanel"
	panel.Size = UDim2.new(0, 210, 0, panelH)
	panel.Position = UDim2.new(0, 6, 0.22, 0)
	panel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.Parent = gui
	addCorner(panel, 16)
	addStroke(panel, Color3.fromRGB(200, 205, 220), 2)

	-- 미션 카드 3개
	self.elements.missionCards = {}
	local yOffset = PAD

	for i = 1, 3 do
		local card = Instance.new("Frame")
		card.Name = "Mission_" .. i
		card.Size = UDim2.new(1, -PAD * 2, 0, CARD_H)
		card.Position = UDim2.new(0, PAD, 0, yOffset)
		card.BackgroundColor3 = Color3.fromRGB(240, 242, 248)
		card.BackgroundTransparency = 0
		card.BorderSizePixel = 0
		card.ClipsDescendants = true
		card.Parent = panel
		addCorner(card, 10)
		addStroke(card, Color3.fromRGB(210, 215, 225), 1)

		-- 보너스 (좌측, 크게)
		local bonusLabel = Instance.new("TextLabel")
		bonusLabel.Name = "Bonus"
		bonusLabel.Size = UDim2.new(0, 38, 1, 0)
		bonusLabel.Position = UDim2.new(0, 6, 0, 0)
		bonusLabel.BackgroundTransparency = 1
		bonusLabel.Text = ""
		bonusLabel.TextColor3 = Color3.fromRGB(255, 180, 30)
		bonusLabel.Font = FONT_BOLD
		bonusLabel.TextSize = 18
		bonusLabel.TextXAlignment = Enum.TextXAlignment.Center
		bonusLabel.Parent = card

		-- 레터 버블 컨테이너 (보너스 오른쪽, 넉넉한 여백)
		local letterContainer = Instance.new("Frame")
		letterContainer.Name = "Letters"
		letterContainer.Size = UDim2.new(1, -56, 1, -8)
		letterContainer.Position = UDim2.new(0, 48, 0, 4)
		letterContainer.BackgroundTransparency = 1
		letterContainer.ClipsDescendants = true
		letterContainer.Parent = card

		local letterLayout = Instance.new("UIListLayout")
		letterLayout.FillDirection = Enum.FillDirection.Horizontal
		letterLayout.Padding = UDim.new(0, 4)
		letterLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		letterLayout.Parent = letterContainer

		-- 상태 오버레이 (CLEAR / TAKEN)
		local statusLabel = Instance.new("TextLabel")
		statusLabel.Name = "Status"
		statusLabel.Size = UDim2.new(1, 0, 1, 0)
		statusLabel.BackgroundTransparency = 1
		statusLabel.Text = ""
		statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		statusLabel.Font = FONT_BOLD
		statusLabel.TextSize = 16
		statusLabel.ZIndex = 3
		statusLabel.Visible = false
		statusLabel.Parent = card

		self.elements.missionCards[i] = {
			card = card,
			letterContainer = letterContainer,
			bonusLabel = bonusLabel,
			statusLabel = statusLabel,
			letterBubbles = {},
		}

		yOffset = yOffset + CARD_H + GAP
	end

	self.elements.missionPanel = panel

	-- ===== 미션 토글 버튼 (모바일용, 좌하단) =====
	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Name = "MissionToggle"
	toggleBtn.Size = UDim2.new(0, 46, 0, 46)
	toggleBtn.Position = UDim2.new(0, 10, 1, -105)
	toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
	toggleBtn.BackgroundTransparency = 0
	toggleBtn.Text = "M"
	toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggleBtn.Font = FONT_BOLD
	toggleBtn.TextScaled = true
	toggleBtn.BorderSizePixel = 0
	toggleBtn.ZIndex = 5
	toggleBtn.Visible = false
	toggleBtn.Parent = gui
	addCorner(toggleBtn, 14)
	addStroke(toggleBtn, Color3.fromRGB(0, 140, 190), 3)

	local toggleGrad = Instance.new("UIGradient")
	toggleGrad.Color = ColorSequence.new(Color3.fromRGB(0, 220, 255), Color3.fromRGB(0, 170, 235))
	toggleGrad.Rotation = 90
	toggleGrad.Parent = toggleBtn

	local togglePad = Instance.new("UIPadding")
	togglePad.PaddingTop = UDim.new(0.15, 0)
	togglePad.PaddingBottom = UDim.new(0.15, 0)
	togglePad.Parent = toggleBtn

	-- 느낌표 뱃지
	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.Size = UDim2.new(0, 18, 0, 18)
	badge.Position = UDim2.new(1, -6, 0, -6)
	badge.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
	badge.BorderSizePixel = 0
	badge.ZIndex = 6
	badge.Visible = false
	badge.Parent = toggleBtn
	addCorner(badge, 9)

	local badgeText = Instance.new("TextLabel")
	badgeText.Size = UDim2.new(1, 0, 1, 0)
	badgeText.BackgroundTransparency = 1
	badgeText.Text = "!"
	badgeText.TextColor3 = Color3.fromRGB(255, 255, 255)
	badgeText.Font = FONT_BOLD
	badgeText.TextScaled = true
	badgeText.ZIndex = 7
	badgeText.Parent = badge

	self.elements.missionToggle = toggleBtn
	self.elements.missionBadge = badge
	self._missionOpen = false

	-- 토글 클릭
	toggleBtn.MouseButton1Click:Connect(function()
		self._missionOpen = not self._missionOpen
		if self._missionOpen then
			-- 패널을 버튼 위에 펼치기
			panel.Visible = true
			panel.Position = UDim2.new(0, 6, 1, -100 - panelH - 8)
			TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = UDim2.new(0, 6, 1, -100 - panelH - 8),
			}):Play()
			toggleBtn.Text = "X"
		else
			-- 패널 접기
			TweenService:Create(panel, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0, 6, 1, -100),
			}):Play()
			task.delay(0.15, function()
				if not self._missionOpen then
					panel.Visible = false
				end
			end)
			toggleBtn.Text = "M"
		end
	end)

	-- 화면 크기 감지 → 모바일이면 토글 모드
	self:_updateMissionLayout()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		self:_updateMissionLayout()
	end)
end

function UIController:_updateMissionLayout()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local vpSize = cam.ViewportSize
	local isMobile = vpSize.X < 800 or vpSize.Y > vpSize.X

	local panel = self.elements.missionPanel
	local toggle = self.elements.missionToggle

	if isMobile then
		-- 모바일: 패널 숨기고 토글 버튼 보이기
		toggle.Visible = true
		if not self._missionOpen then
			panel.Visible = false
		end
	else
		-- PC: 패널 항상 보이기, 토글 숨기기
		toggle.Visible = false
		panel.Visible = true
		panel.Position = UDim2.new(0, 6, 0.22, 0)
		self._missionOpen = false
	end
end

-- 미션 초기화 (매치 시작 시 서버에서 받은 미션 데이터로)
function UIController:initMissions(missions)
	if not missions then return end

	for idx, mission in missions do
		local cardData = self.elements.missionCards[idx]
		if not cardData then continue end

		-- 보너스 텍스트 (크게)
		cardData.bonusLabel.Text = "+" .. mission.bonus
		cardData.bonusLabel.TextColor3 = Color3.fromRGB(255, 210, 50)

		-- 기존 레터 버블 삭제
		for _, bubble in cardData.letterBubbles do
			bubble:Destroy()
		end
		cardData.letterBubbles = {}

		-- 레터 버블 생성 (모바일 터치 고려)
		for i, letter in mission.letters do
			local bubble = Instance.new("Frame")
			bubble.Name = "Letter_" .. i
			bubble.Size = UDim2.new(0, 28, 0, 28)
			bubble.BackgroundColor3 = Color3.fromRGB(220, 225, 235)
			bubble.BorderSizePixel = 0
			addCorner(bubble, 8)

			local letterLabel = Instance.new("TextLabel")
			letterLabel.Name = "Text"
			letterLabel.Size = UDim2.new(1, 0, 1, 0)
			letterLabel.BackgroundTransparency = 1
			letterLabel.Text = letter
			letterLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
			letterLabel.Font = FONT_BOLD
			letterLabel.TextSize = 15
			letterLabel.Parent = bubble

			bubble.Parent = cardData.letterContainer
			table.insert(cardData.letterBubbles, bubble)
		end

		-- 상태 리셋
		cardData.statusLabel.Visible = false
		cardData.card.BackgroundColor3 = Color3.fromRGB(240, 242, 248)
		if cardData.avatarIcon then
			cardData.avatarIcon.Visible = false
		end
	end
end

-- ===== 미션 상태 업데이트 (매 턴) =====
function UIController:updateMissions(missions, playerLetters)
	if not missions then return end

	-- 플레이어 보유 레터 카운트 (playerLetters가 없으면 missions에서 추론 불가하므로 패스)
	for idx, mission in missions do
		local cardData = self.elements.missionCards[idx]
		if not cardData then continue end

		if mission.claimedBy then
			-- 팀 색 + 아바타 헤드샷
			local isMe = mission.claimedBy == "player"
			local teamColor, teamColorLight, statusText
			if isMe then
				teamColor = Color3.fromRGB(210, 50, 60)
				teamColorLight = Color3.fromRGB(240, 120, 130)
				statusText = "CLEAR!"
			else
				teamColor = Color3.fromRGB(50, 85, 210)
				teamColorLight = Color3.fromRGB(120, 150, 240)
				statusText = "TAKEN"
			end

			cardData.card.BackgroundColor3 = teamColor
			cardData.statusLabel.Text = statusText
			cardData.statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			cardData.statusLabel.Font = FONT_TITLE
			cardData.statusLabel.TextSize = 16
			cardData.bonusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)

			for _, bubble in cardData.letterBubbles do
				bubble.BackgroundColor3 = teamColorLight
				local txt = bubble:FindFirstChild("Text")
				if txt then txt.TextColor3 = Color3.fromRGB(255, 255, 255) end
			end

			-- 아바타 헤드샷 (카드 우측 끝)
			if not cardData.avatarIcon then
				local icon = Instance.new("ImageLabel")
				icon.Name = "Avatar"
				icon.Size = UDim2.new(0, 30, 0, 30)
				icon.Position = UDim2.new(1, -36, 0.5, -15)
				icon.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				icon.BackgroundTransparency = 0
				icon.ZIndex = 4
				icon.ScaleType = Enum.ScaleType.Crop
				icon.Parent = cardData.card
				addCorner(icon, 15)
				addStroke(icon, Color3.fromRGB(255, 255, 255), 2)
				cardData.avatarIcon = icon
			end

			-- 헤드샷 이미지 설정
			local userId
			if isMe then
				userId = Players.LocalPlayer.UserId
			else
				userId = self._opponentId
			end

			if userId then
				cardData.avatarIcon.Image = "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=150&h=150"
			else
				-- AI면 아이콘 숨김
				cardData.avatarIcon.Image = ""
				cardData.avatarIcon.BackgroundColor3 = teamColorLight
			end
			cardData.avatarIcon.Visible = true

			cardData.statusLabel.Visible = true
		elseif playerLetters then
			-- 미선점 → 보유 레터에 따라 버블 하이라이트
			local required = {}
			for _, letter in mission.letters do
				required[letter] = (required[letter] or 0) + 1
			end
			local used = {}
			for i, letter in mission.letters do
				used[letter] = (used[letter] or 0) + 1
				local have = playerLetters[letter] or 0
				local bubble = cardData.letterBubbles[i]
				if bubble then
					local txt = bubble:FindFirstChild("Text")
					if have >= used[letter] then
						-- 보유함 → 밝게
						bubble.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
						if txt then txt.TextColor3 = Color3.fromRGB(255, 255, 255) end
					else
						-- 미보유 → 밝은 회색
						bubble.BackgroundColor3 = Color3.fromRGB(220, 225, 235)
						if txt then txt.TextColor3 = Color3.fromRGB(100, 100, 120) end
					end
				end
			end
		end
	end

	-- 느낌표 뱃지 비활성화
	if self.elements.missionBadge then
		self.elements.missionBadge.Visible = false
	end
end

-- ===== 미션 완료 팝업 (화면 중앙) =====
function UIController:_showMissionPopup(mission)
	local popup = Instance.new("Frame")
	popup.Name = "MissionPopup"
	popup.Size = UDim2.new(0, 0, 0, 0)
	popup.Position = UDim2.new(0.5, 0, 0.4, 0)
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	popup.BackgroundTransparency = 0.03
	popup.BorderSizePixel = 0
	popup.ZIndex = 10
	popup.Parent = self.gui
	addCorner(popup, 16)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 200, 255)
	stroke.Thickness = 3
	stroke.Transparency = 0
	stroke.Parent = popup

	-- "MISSION COMPLETE!"
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -16, 0.45, 0)
	titleLabel.Position = UDim2.new(0, 8, 0, 4)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "MISSION COMPLETE!"
	titleLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
	titleLabel.TextScaled = true
	titleLabel.Font = FONT_TITLE
	titleLabel.ZIndex = 11
	titleLabel.Parent = popup
	addStroke(titleLabel, Color3.fromRGB(0, 100, 160), 2)

	-- 레터 + 보너스 행
	local detailLabel = Instance.new("TextLabel")
	detailLabel.Name = "Detail"
	detailLabel.Size = UDim2.new(1, -16, 0.4, 0)
	detailLabel.Position = UDim2.new(0, 8, 0.5, 2)
	detailLabel.BackgroundTransparency = 1
	detailLabel.Text = table.concat(mission.letters, "-") .. "  +" .. mission.bonus
	detailLabel.TextColor3 = Color3.fromRGB(255, 180, 40)
	detailLabel.TextScaled = true
	detailLabel.Font = FONT_BOLD
	detailLabel.ZIndex = 11
	detailLabel.Parent = popup
	addStroke(detailLabel, Color3.fromRGB(160, 100, 0), 2)

	-- 스케일 업
	TweenService:Create(popup, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 240, 0, 60),
	}):Play()

	-- 글로우 펄스
	task.spawn(function()
		for _ = 1, 3 do
			TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 0.6 }):Play()
			task.wait(0.3)
			TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 0 }):Play()
			task.wait(0.3)
		end
	end)

	-- 페이드 아웃
	task.delay(1.8, function()
		local fadeOut = TweenService:Create(popup, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 240, 0, 0),
			BackgroundTransparency = 1,
		})
		TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		TweenService:Create(titleLabel, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		TweenService:Create(detailLabel, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		fadeOut:Play()
		fadeOut.Completed:Wait()
		popup:Destroy()
	end)
end

-- ===== 새 미션 완료 팝업 처리 =====
function UIController:showNewMissions(newMissions)
	if not newMissions or #newMissions == 0 then return end

	for i, mission in newMissions do
		task.delay((i - 1) * 0.5, function()
			self:_showMissionPopup(mission)
		end)
	end
end

-- ===== Public API =====

function UIController:updateScores(playerScore: number, aiScore: number)
	-- 왼쪽=항상 나(player), 오른쪽=항상 상대(ai)
	self.elements.redScore.Text = tostring(playerScore)
	self.elements.blueScore.Text = tostring(aiScore)
end

function UIController:updateTimer(_seconds: number)
	-- 게임 타이머 제거됨 (공 10개 다 쓰면 종료)
end

-- 스코어보드 이름 설정 (내가 항상 왼쪽)
function UIController:setupScoreboard(myTeam: string, opponentName: string)
	local myName = Players.LocalPlayer.DisplayName
	self._myTeam = myTeam

	-- 왼쪽 박스 = 항상 나, 오른쪽 박스 = 항상 상대
	self.elements.redName.Text = myName
	self.elements.blueName.Text = opponentName

	local redBox = self.elements.redScore.Parent
	local blueBox = self.elements.blueName.Parent

	if myTeam == "blue" then
		-- 왼쪽 박스를 파란색으로, 오른쪽 박스를 빨간색으로
		redBox.BackgroundColor3 = Color3.fromRGB(50, 100, 220)
		local redGrad = redBox:FindFirstChildOfClass("UIGradient")
		if redGrad then
			redGrad.Color = ColorSequence.new(Color3.fromRGB(60, 110, 235), Color3.fromRGB(40, 80, 190))
		end
		local redStroke = redBox:FindFirstChildOfClass("UIStroke")
		if redStroke then redStroke.Color = Color3.fromRGB(30, 60, 160) end
		for _, label in redBox:GetChildren() do
			if label:IsA("TextLabel") then
				local ls = label:FindFirstChildOfClass("UIStroke")
				if ls then ls.Color = Color3.fromRGB(20, 40, 120) end
			end
		end

		blueBox.BackgroundColor3 = Color3.fromRGB(220, 55, 65)
		local blueGrad = blueBox:FindFirstChildOfClass("UIGradient")
		if blueGrad then
			blueGrad.Color = ColorSequence.new(Color3.fromRGB(230, 65, 75), Color3.fromRGB(190, 40, 50))
		end
		local blueStroke = blueBox:FindFirstChildOfClass("UIStroke")
		if blueStroke then blueStroke.Color = Color3.fromRGB(160, 30, 40) end
		for _, label in blueBox:GetChildren() do
			if label:IsA("TextLabel") then
				local ls = label:FindFirstChildOfClass("UIStroke")
				if ls then ls.Color = Color3.fromRGB(100, 20, 25) end
			end
		end
		-- 볼 도트 색상도 교체 (playerDots=파랑, aiDots=빨강)
		for _, dot in self.elements.playerDotRow:GetChildren() do
			if dot:IsA("Frame") then
				dot.BackgroundColor3 = Config.BALL.COLORS.BLUE
				local s = dot:FindFirstChildOfClass("UIStroke")
				if s then s.Color = Color3.fromRGB(30, 55, 160) end
			end
		end
		for _, dot in self.elements.aiDotRow:GetChildren() do
			if dot:IsA("Frame") then
				dot.BackgroundColor3 = Config.BALL.COLORS.RED
				local s = dot:FindFirstChildOfClass("UIStroke")
				if s then s.Color = Color3.fromRGB(160, 30, 40) end
			end
		end
	end
	-- myTeam == "red"이면 기본 색상 그대로 (왼쪽=빨강, 오른쪽=파랑)

	self._scoreFlipped = false -- 항상 왼쪽=player, 오른쪽=ai (서버가 뒤집어서 보내줌)

	-- 캐릭터 상반신 모델 로딩
	self:loadMatchCharacters(self._opponentId)
end

-- 상대 이름 변경 (퇴장 시)
function UIController:setOpponentName(name: string)
	self.elements.blueName.Text = name
end

function UIController:hideTurnTimer()
	if self._turnTimerThread then
		task.cancel(self._turnTimerThread)
		self._turnTimerThread = nil
	end
	if self.elements.turnTimer then
		self.elements.turnTimer.Visible = false
	end
end

function UIController:updatePowerGauge(ratio: number)
	ratio = math.clamp(ratio, 0, 1)
	local fill = self.elements.gaugeFill
	local gauge = self.elements.gaugeFrame
	local maxH = gauge.AbsoluteSize.Y - 6

	fill.Size = UDim2.new(1, -6, 0, math.max(1, maxH * ratio))

	-- 색상: 초록 → 노랑 → 빨강
	if ratio < 0.5 then
		local t = ratio / 0.5
		fill.BackgroundColor3 = Color3.fromRGB(80 + 175 * t, 220 - 50 * t, 80)
	else
		local t = (ratio - 0.5) / 0.5
		fill.BackgroundColor3 = Color3.fromRGB(255, 170 - 170 * t, 80 - 60 * t)
	end

	-- 차징 중이면 게이지 표시
	gauge.Visible = ratio > 0
end

function UIController:updateAimIndicator(_aimAngle: number)
end

function UIController:updateSpinIndicator(spin: number, power: number?)
	power = power or 0

	-- 3D 공 모델 + 속도 텍스트 인디케이터 생성
	if not self.elements.spinFrame then
		-- 컨테이너 프레임
		local frame = Instance.new("Frame")
		frame.Name = "SpinFrame"
		frame.Size = UDim2.new(0, 90, 0, 110)
		frame.Position = UDim2.new(0, 10, 0.45, 0)
		frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		frame.BackgroundTransparency = 0.08
		frame.BorderSizePixel = 0
		frame.Visible = false
		frame.Parent = self.gui

		addCorner(frame, 14)
		addStroke(frame, Color3.fromRGB(200, 205, 220), 2)

		-- ViewportFrame: 3D 공 렌더링
		local viewport = Instance.new("ViewportFrame")
		viewport.Name = "BallViewport"
		viewport.Size = UDim2.new(1, -10, 0, 65)
		viewport.Position = UDim2.new(0, 5, 0, 5)
		viewport.BackgroundTransparency = 1
		viewport.Parent = frame

		-- 공 모델
		local ballModel = Instance.new("Part")
		ballModel.Name = "SpinBall"
		ballModel.Shape = Enum.PartType.Ball
		ballModel.Size = Vector3.one * 2
		ballModel.Color = Config.BALL.COLORS.RED
		ballModel.Material = Enum.Material.Marble
		ballModel.Anchored = true
		ballModel.Position = Vector3.new(0, 0, 0)
		ballModel.Parent = viewport

		-- 뷰포트 카메라
		local vpCam = Instance.new("Camera")
		vpCam.CFrame = CFrame.lookAt(Vector3.new(0, 0.5, 3.5), Vector3.zero)
		vpCam.Parent = viewport
		viewport.CurrentCamera = vpCam

		-- 속도 텍스트
		local speedText = Instance.new("TextLabel")
		speedText.Name = "SpeedText"
		speedText.Size = UDim2.new(1, -10, 0, 16)
		speedText.Position = UDim2.new(0, 5, 1, -38)
		speedText.BackgroundTransparency = 1
		speedText.TextColor3 = Color3.fromRGB(100, 100, 120)
		speedText.TextScaled = true
		speedText.Font = FONT_MEDIUM
		speedText.Text = "0.0 m/s"
		speedText.Parent = frame

		-- 스핀 값 텍스트
		local spinText = Instance.new("TextLabel")
		spinText.Name = "SpinText"
		spinText.Size = UDim2.new(1, -10, 0, 18)
		spinText.Position = UDim2.new(0, 5, 1, -20)
		spinText.BackgroundTransparency = 1
		spinText.TextColor3 = Color3.fromRGB(255, 255, 255)
		spinText.TextScaled = true
		spinText.Font = FONT_BOLD
		spinText.Text = "SPIN 0"
		spinText.Parent = frame

		self.elements.spinFrame = frame
		self.elements.spinBall = ballModel
		self.elements.speedText = speedText
		self.elements.spinText = spinText
	end

	local frame = self.elements.spinFrame
	local ballModel = self.elements.spinBall

	if math.abs(spin) < 0.05 and power < 0.05 then
		frame.Visible = false
		return
	end

	frame.Visible = true

	-- 3D 공 회전 (스핀에 따라 Y축 회전)
	local rotSpeed = spin * 5 -- 회전 각속도
	local currentRot = (tick() * rotSpeed) % (2 * math.pi)
	ballModel.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, currentRot, 0)

	-- 속도 텍스트
	local currentPower = Config.LAUNCH.MIN_POWER + (Config.LAUNCH.MAX_POWER - Config.LAUNCH.MIN_POWER) * power
	local speedMs = currentPower * 0.15 -- 대략적인 m/s 변환
	self.elements.speedText.Text = string.format("%.1f m/s", speedMs)

	-- 스핀 텍스트 + 색상
	if math.abs(spin) < 0.05 then
		self.elements.spinText.Text = "NO SPIN"
		self.elements.spinText.TextColor3 = Color3.fromRGB(180, 180, 180)
	elseif spin < 0 then
		self.elements.spinText.Text = string.format("R %.0f%%", math.abs(spin) * 100)
		self.elements.spinText.TextColor3 = Color3.fromRGB(255, 160, 50)
	else
		self.elements.spinText.Text = string.format("L %.0f%%", spin * 100)
		self.elements.spinText.TextColor3 = Color3.fromRGB(100, 200, 255)
	end
end

function UIController:setTurn(isPlayerTurn: boolean, isBonus: boolean?)
	local panel = self.elements.turnPanel
	local turnText = self.elements.turnText
	local turnTimer = self.elements.turnTimer

	-- 이전 타이머 정리
	if self._turnTimerThread then
		task.cancel(self._turnTimerThread)
		self._turnTimerThread = nil
	end
	if self._turnFadeTimer then
		task.cancel(self._turnFadeTimer)
		self._turnFadeTimer = nil
	end

	-- 볼 도트: 내 턴엔 내 볼만, 상대 턴엔 상대 볼만
	self._isBonus = isBonus or false
	self.elements.playerDotRow.Visible = isPlayerTurn
	self.elements.aiDotRow.Visible = not isPlayerTurn
	self:_updateTurnDots()

	-- 볼 카운트 텍스트
	local total = Config.GAME.BALLS_PER_PLAYER
	local remaining = isPlayerTurn and self._playerBalls or self._aiBalls
	local thrown = total - remaining
	if not isBonus then
		thrown = thrown + 1 -- 지금 던질 공 포함 (보너스 턴은 소모 없음)
	end
	self.elements.ballCountText.Text = math.min(thrown, total) .. " / " .. total

	-- 턴 텍스트 + 색상
	local panelStroke = panel:FindFirstChildOfClass("UIStroke")
	local myColor = self._myTeam == "blue" and Color3.fromRGB(50, 90, 210) or Color3.fromRGB(220, 50, 60)
	if isPlayerTurn then
		if isBonus then
			turnText.Text = "BONUS TURN!"
			turnText.TextColor3 = Color3.fromRGB(255, 180, 30)
			panel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			if panelStroke then panelStroke.Color = Color3.fromRGB(255, 180, 30) end
		else
			turnText.Text = "YOUR TURN"
			turnText.TextColor3 = myColor
			panel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			if panelStroke then panelStroke.Color = myColor end
		end
	else
		-- 상대 턴
		local oppColor = self._myTeam == "blue" and Color3.fromRGB(220, 50, 60) or Color3.fromRGB(50, 90, 210)
		if isBonus then
			turnText.Text = "BONUS TURN!"
			turnText.TextColor3 = Color3.fromRGB(255, 180, 30)
			panel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			if panelStroke then panelStroke.Color = Color3.fromRGB(255, 180, 30) end
		else
			turnText.Text = self._opponentName or "AI"
			turnText.TextColor3 = oppColor
			panel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			if panelStroke then panelStroke.Color = oppColor end
		end
	end

	-- ===== 턴 타이머 (내 턴 + 상대 턴 모두 표시) =====
	turnTimer.Visible = true
	self._turnTimerThread = task.spawn(function()
		for sec = Config.GAME.TURN_TIME, 1, -1 do
			turnTimer.Text = tostring(sec)
			if sec <= 5 then
				turnTimer.BackgroundColor3 = Color3.fromRGB(220, 40, 30)
				local ts = turnTimer:FindFirstChildOfClass("UIStroke")
				if ts then ts.Color = Color3.fromRGB(160, 25, 20) end
			else
				turnTimer.BackgroundColor3 = Color3.fromRGB(40, 42, 55)
				local ts = turnTimer:FindFirstChildOfClass("UIStroke")
				if ts then ts.Color = Color3.fromRGB(25, 28, 40) end
			end
			task.wait(1)
		end
		turnTimer.Visible = false
	end)

	-- ===== 패널 페이드 인 =====
	panel.Visible = true
	panel.BackgroundTransparency = 1

	-- 도트(D1~D10)는 페이드 대상 제외 — 즉시 표시
	for _, child in panel:GetDescendants() do
		local isDot = child:IsA("Frame") and child.Name:match("^D%d")
		if isDot then
			-- 도트는 _updateTurnDots에서 이미 설정됨, 건드리지 않음
		elseif child:IsA("TextLabel") then
			child.TextTransparency = 1
		elseif child:IsA("UIStroke") then
			child.Transparency = 1
		elseif child:IsA("Frame") then
			child.BackgroundTransparency = 1
		end
	end

	TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0,
	}):Play()
	for _, child in panel:GetDescendants() do
		local isDot = child:IsA("Frame") and child.Name:match("^D%d")
		if isDot then
			-- 도트는 이미 보임
		elseif child:IsA("TextLabel") then
			TweenService:Create(child, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
		elseif child:IsA("UIStroke") then
			TweenService:Create(child, TweenInfo.new(0.3), { Transparency = 0 }):Play()
		end
	end

	-- 2초 후 패널만 페이드 아웃 (타이머는 유지!)
	self._turnFadeTimer = task.delay(2, function()
		if not panel.Visible then return end

		TweenService:Create(panel, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		}):Play()
		for _, child in panel:GetDescendants() do
			if child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			end
			if child:IsA("UIStroke") then
				TweenService:Create(child, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			end
			if child:IsA("Frame") then
				TweenService:Create(child, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			end
		end

		task.delay(0.6, function()
			panel.Visible = false
			self._turnFadeTimer = nil
		end)
	end)
end

-- 볼 도트 업데이트: 쓴공=팀색(왼쪽부터 채움), 안쓴공=흰색
function UIController:_updateTurnDots()
	local maxBalls = Config.GAME.BALLS_PER_PLAYER
	-- 보너스 턴이면 현재 턴 플레이어의 도트만 +1 안 함
	local playerOffset = (self._isBonus and self.elements.playerDotRow.Visible) and 0 or 1
	local aiOffset = (self._isBonus and self.elements.aiDotRow.Visible) and 0 or 1
	local usedPlayer = math.min(maxBalls - self._playerBalls + playerOffset, maxBalls)
	local usedAI = math.min(maxBalls - self._aiBalls + aiOffset, maxBalls)

	-- 팀 색상 결정
	local myBallColor, myStrokeColor, oppBallColor, oppStrokeColor
	if self._myTeam == "blue" then
		myBallColor = Config.BALL.COLORS.BLUE
		myStrokeColor = Color3.fromRGB(30, 55, 160)
		oppBallColor = Config.BALL.COLORS.RED
		oppStrokeColor = Color3.fromRGB(160, 30, 40)
	else
		myBallColor = Config.BALL.COLORS.RED
		myStrokeColor = Color3.fromRGB(160, 30, 40)
		oppBallColor = Config.BALL.COLORS.BLUE
		oppStrokeColor = Color3.fromRGB(30, 55, 160)
	end

	-- 플레이어 도트: 왼쪽부터 쓴 만큼 팀색, 나머지 흰색
	for _, dot in self.elements.playerDotRow:GetChildren() do
		if dot:IsA("Frame") then
			local idx = tonumber(dot.Name:match("%d+"))
			if idx then
				local stroke = dot:FindFirstChildOfClass("UIStroke")
				if idx <= usedPlayer then
					dot.BackgroundColor3 = myBallColor
					dot.BackgroundTransparency = 0
					if stroke then stroke.Color = myStrokeColor end
				else
					dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					dot.BackgroundTransparency = 0
					if stroke then stroke.Color = Color3.fromRGB(200, 200, 210) end
				end
			end
		end
	end

	-- AI 도트: 왼쪽부터 쓴 만큼 상대색, 나머지 흰색
	for _, dot in self.elements.aiDotRow:GetChildren() do
		if dot:IsA("Frame") then
			local idx = tonumber(dot.Name:match("%d+"))
			if idx then
				local stroke = dot:FindFirstChildOfClass("UIStroke")
				if idx <= usedAI then
					dot.BackgroundColor3 = oppBallColor
					dot.BackgroundTransparency = 0
					if stroke then stroke.Color = oppStrokeColor end
				else
					dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					dot.BackgroundTransparency = 0
					if stroke then stroke.Color = Color3.fromRGB(200, 200, 210) end
				end
			end
		end
	end
end

function UIController:updateRemainingBalls(playerBalls: number, aiBalls: number)
	self._playerBalls = playerBalls
	self._aiBalls = aiBalls
end

function UIController:showScorePopup(position: Vector3, points: number, team: string)
	if not position or points == 0 then return end

	local camera = workspace.CurrentCamera
	local screenPos, onScreen = camera:WorldToScreenPoint(position)
	if not onScreen then return end

	local popup = Instance.new("TextLabel")
	popup.Size = UDim2.new(0, 90, 0, 45)
	popup.Position = UDim2.new(0, screenPos.X - 45, 0, screenPos.Y - 25)
	popup.BackgroundTransparency = 1
	popup.Text = "+" .. points
	popup.TextColor3 = team == "player" and RED or BLUE
	popup.TextScaled = true
	popup.Font = FONT_TITLE
	popup.TextStrokeTransparency = 0.2
	popup.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	popup.Parent = self.gui

	TweenService:Create(popup, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, screenPos.X - 45, 0, screenPos.Y - 90),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()

	task.delay(1.3, function()
		popup:Destroy()
	end)
end

-- ===== 타이밍 등급 팝업 (화면 중앙) =====
function UIController:showTimingGrade(gradeName: string, gradeColor: Color3)
	local label = Instance.new("TextLabel")
	label.Name = "TimingGrade"
	label.Size = UDim2.new(0, 0, 0, 0)
	label.Position = UDim2.new(0.5, 0, 0.35, 0)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Text = gradeName
	label.TextColor3 = gradeColor
	label.Font = FONT_TITLE
	label.TextSize = 44
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextTransparency = 0
	label.ZIndex = 15
	label.Parent = self.gui

	-- 팝 애니메이션: 작은→큰 + 위로 떠오름
	label.Size = UDim2.new(0, 300, 0, 60)
	label.TextSize = 0

	TweenService:Create(label, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextSize = 40,
	}):Play()

	-- 위로 떠오르며 페이드
	task.delay(0.6, function()
		TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0.3, 0),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		task.delay(0.5, function()
			label:Destroy()
		end)
	end)
end

function UIController:show()
	self.gui.Enabled = true
end

function UIController:hide()
	self.gui.Enabled = false
end

function UIController:hideResult()
	self.elements.resultFrame.Visible = false
	self:clearMatchCharacters()
end

-- ===== 온보딩 가이드 (매 턴, 공 아래 화살표 + Pull down) =====
function UIController:showLaunchGuide()
	self:hideLaunchGuide()

	local guide = Instance.new("Frame")
	guide.Name = "LaunchGuide"
	guide.Size = UDim2.new(0, 160, 0, 100)
	guide.Position = UDim2.new(0.5, -80, 0.72, 0)
	guide.BackgroundTransparency = 1
	guide.ZIndex = 8
	guide.Parent = self.gui

	-- 아래 화살표 ↓
	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.Size = UDim2.new(1, 0, 0, 36)
	arrow.Position = UDim2.new(0, 0, 0, 0)
	arrow.BackgroundTransparency = 1
	arrow.Text = "↓"
	arrow.TextColor3 = Color3.fromRGB(255, 255, 255)
	arrow.Font = FONT_TITLE
	arrow.TextSize = 36
	arrow.ZIndex = 9
	arrow.Parent = guide
	addStroke(arrow, Color3.fromRGB(0, 0, 0), 2)

	-- "Pull down" 텍스트
	local pullText = Instance.new("TextLabel")
	pullText.Name = "PullText"
	pullText.Size = UDim2.new(1, 0, 0, 22)
	pullText.Position = UDim2.new(0, 0, 0, 38)
	pullText.BackgroundTransparency = 1
	pullText.Text = "Pull down"
	pullText.TextColor3 = Color3.fromRGB(255, 255, 255)
	pullText.Font = FONT_BOLD
	pullText.TextScaled = true
	pullText.ZIndex = 9
	pullText.Parent = guide
	addStroke(pullText, Color3.fromRGB(0, 0, 0), 2)

	-- 좌우 화살표 ← →
	local lrRow = Instance.new("Frame")
	lrRow.Size = UDim2.new(1, 0, 0, 24)
	lrRow.Position = UDim2.new(0, 0, 0, 66)
	lrRow.BackgroundTransparency = 1
	lrRow.ZIndex = 8
	lrRow.Parent = guide

	local leftArrow = Instance.new("TextLabel")
	leftArrow.Size = UDim2.new(0, 30, 1, 0)
	leftArrow.Position = UDim2.new(0.15, 0, 0, 0)
	leftArrow.BackgroundTransparency = 1
	leftArrow.Text = "←"
	leftArrow.TextColor3 = Color3.fromRGB(200, 220, 255)
	leftArrow.Font = FONT_BOLD
	leftArrow.TextSize = 22
	leftArrow.ZIndex = 9
	leftArrow.Parent = lrRow
	addStroke(leftArrow, Color3.fromRGB(0, 0, 0), 1.5)

	local rightArrow = Instance.new("TextLabel")
	rightArrow.Size = UDim2.new(0, 30, 1, 0)
	rightArrow.Position = UDim2.new(0.7, 0, 0, 0)
	rightArrow.BackgroundTransparency = 1
	rightArrow.Text = "→"
	rightArrow.TextColor3 = Color3.fromRGB(200, 220, 255)
	rightArrow.Font = FONT_BOLD
	rightArrow.TextSize = 22
	rightArrow.ZIndex = 9
	rightArrow.Parent = lrRow
	addStroke(rightArrow, Color3.fromRGB(0, 0, 0), 1.5)

	self.elements.launchGuide = guide

	-- 아래 화살표 위아래 바운스 애니메이션
	task.spawn(function()
		while guide and guide.Parent do
			TweenService:Create(arrow, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Position = UDim2.new(0, 0, 0, 10),
			}):Play()
			task.wait(0.5)
			if not guide or not guide.Parent then break end
			TweenService:Create(arrow, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Position = UDim2.new(0, 0, 0, 0),
			}):Play()
			task.wait(0.5)
		end
	end)
end

function UIController:hideLaunchGuide()
	if self.elements.launchGuide then
		self.elements.launchGuide:Destroy()
		self.elements.launchGuide = nil
	end
end

function UIController:showMatchResult(winner: string, scores)
	self.elements.resultFrame.Visible = true

	local rt = self.elements.resultText
	local rtStroke = rt:FindFirstChildOfClass("UIStroke")

	if winner == "player" then
		rt.Text = "YOU WIN!"
		rt.TextColor3 = Color3.fromRGB(255, 220, 50)
		if rtStroke then rtStroke.Color = Color3.fromRGB(180, 120, 0) end
	elseif winner == "ai" then
		rt.Text = "YOU LOSE"
		rt.TextColor3 = Color3.fromRGB(220, 70, 70)
		if rtStroke then rtStroke.Color = Color3.fromRGB(140, 30, 30) end
	else
		rt.Text = "DRAW"
		rt.TextColor3 = Color3.fromRGB(150, 150, 170)
		if rtStroke then rtStroke.Color = Color3.fromRGB(80, 80, 100) end
	end

	self.elements.resultScore.Text = string.format("%d - %d", scores.player, scores.ai)
end

-- ===== 매칭 발견 팝업 =====
function UIController:showMatchFoundPopup(opponentName: string, countdown: number, onCancel: () -> ())
	-- 기존 팝업 제거
	self:hideMatchFoundPopup()

	local popup = Instance.new("Frame")
	popup.Name = "MatchFoundPopup"
	popup.Size = UDim2.new(0, 340, 0, 200)
	popup.Position = UDim2.new(0.5, -170, 0.5, -100)
	popup.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	popup.BackgroundTransparency = 0.02
	popup.BorderSizePixel = 0
	popup.ZIndex = 50
	popup.Parent = self.gui
	addCorner(popup, 20)
	addStroke(popup, Color3.fromRGB(0, 200, 255), 3)

	-- "MATCH FOUND!"
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.9, 0, 0, 36)
	title.Position = UDim2.new(0.05, 0, 0, 16)
	title.BackgroundTransparency = 1
	title.Text = "MATCH FOUND!"
	title.TextColor3 = Color3.fromRGB(0, 180, 240)
	title.Font = FONT_TITLE
	title.TextScaled = true
	title.ZIndex = 51
	title.Parent = popup
	addStroke(title, Color3.fromRGB(0, 100, 160), 2)

	-- "vs 상대이름"
	local vsLabel = Instance.new("TextLabel")
	vsLabel.Size = UDim2.new(0.9, 0, 0, 28)
	vsLabel.Position = UDim2.new(0.05, 0, 0, 56)
	vsLabel.BackgroundTransparency = 1
	vsLabel.Text = "vs  " .. opponentName
	vsLabel.TextColor3 = Color3.fromRGB(80, 80, 100)
	vsLabel.Font = FONT_BOLD
	vsLabel.TextScaled = true
	vsLabel.ZIndex = 51
	vsLabel.Parent = popup

	-- 카운트다운 숫자
	local countLabel = Instance.new("TextLabel")
	countLabel.Size = UDim2.new(0.4, 0, 0, 50)
	countLabel.Position = UDim2.new(0.3, 0, 0, 88)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = tostring(countdown)
	countLabel.TextColor3 = Color3.fromRGB(255, 180, 40)
	countLabel.Font = FONT_TITLE
	countLabel.TextScaled = true
	countLabel.ZIndex = 51
	countLabel.Parent = popup
	addStroke(countLabel, Color3.fromRGB(180, 100, 0), 3)

	-- 취소 버튼
	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Size = UDim2.new(0.5, 0, 0, 38)
	cancelBtn.Position = UDim2.new(0.25, 0, 1, -52)
	cancelBtn.BackgroundColor3 = Color3.fromRGB(220, 70, 70)
	cancelBtn.Text = "CANCEL"
	cancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	cancelBtn.Font = FONT_BOLD
	cancelBtn.TextScaled = true
	cancelBtn.BorderSizePixel = 0
	cancelBtn.ZIndex = 51
	cancelBtn.Parent = popup
	addCorner(cancelBtn, 10)
	addStroke(cancelBtn, Color3.fromRGB(160, 40, 40), 2)

	local cancelPad = Instance.new("UIPadding")
	cancelPad.PaddingTop = UDim.new(0.15, 0)
	cancelPad.PaddingBottom = UDim.new(0.15, 0)
	cancelPad.Parent = cancelBtn

	cancelBtn.MouseButton1Click:Connect(function()
		if onCancel then onCancel() end
		self:hideMatchFoundPopup()
	end)

	self.elements.matchFoundPopup = popup

	-- 카운트다운 애니메이션
	task.spawn(function()
		for i = countdown, 1, -1 do
			if not popup or not popup.Parent then return end
			countLabel.Text = tostring(i)
			-- 펄스 애니메이션
			countLabel.TextScaled = false
			countLabel.TextSize = 30
			TweenService:Create(countLabel, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				TextSize = 44,
			}):Play()
			task.wait(1)
		end
	end)
end

function UIController:hideMatchFoundPopup()
	if self.elements.matchFoundPopup then
		self.elements.matchFoundPopup:Destroy()
		self.elements.matchFoundPopup = nil
	end
end

return UIController
