local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local UIController = {}
UIController.__index = UIController

local RED = Config.BALL.COLORS.RED
local BLUE = Config.BALL.COLORS.BLUE

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
end

-- ===== 상단: 타이틀 + 버튼 =====
function UIController:_createTopBar(gui)
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 36)
	topBar.Position = UDim2.new(0, 0, 0, 4)
	topBar.BackgroundTransparency = 1
	topBar.Parent = gui

	-- 타이틀
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.4, 0, 1, 0)
	title.Position = UDim2.new(0.3, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "uncball"
	title.TextColor3 = Color3.fromRGB(50, 80, 180)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBlack
	title.Parent = topBar

	-- 타이머 (타이틀 아래)
	local timer = Instance.new("TextLabel")
	timer.Name = "Timer"
	timer.Size = UDim2.new(0.15, 0, 0, 22)
	timer.Position = UDim2.new(0.425, 0, 0, 38)
	timer.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	timer.BackgroundTransparency = 0.4
	timer.Text = "03:00"
	timer.TextColor3 = Color3.fromRGB(220, 220, 220)
	timer.TextScaled = true
	timer.Font = Enum.Font.GothamMedium
	timer.BorderSizePixel = 0
	timer.Parent = gui

	local timerCorner = Instance.new("UICorner")
	timerCorner.CornerRadius = UDim.new(0, 6)
	timerCorner.Parent = timer

	self.elements.timer = timer
end

-- ===== 점수판: [블루 점수] VS [레드 점수] =====
function UIController:_createScoreBoard(gui)
	local scoreRow = Instance.new("Frame")
	scoreRow.Name = "ScoreRow"
	scoreRow.Size = UDim2.new(0.85, 0, 0, 60)
	scoreRow.Position = UDim2.new(0.075, 0, 0, 42)
	scoreRow.BackgroundTransparency = 1
	scoreRow.Parent = gui

	-- 플레이어(레드) 점수 박스 — 왼쪽
	local redBox = Instance.new("Frame")
	redBox.Name = "RedScoreBox"
	redBox.Size = UDim2.new(0.38, 0, 1, 0)
	redBox.Position = UDim2.new(0, 0, 0, 0)
	redBox.BackgroundColor3 = Color3.fromRGB(160, 35, 45)
	redBox.BorderSizePixel = 0
	redBox.Parent = scoreRow

	local redCorner = Instance.new("UICorner")
	redCorner.CornerRadius = UDim.new(0, 10)
	redCorner.Parent = redBox

	local redScore = Instance.new("TextLabel")
	redScore.Name = "RedScore"
	redScore.Size = UDim2.new(1, 0, 1, 0)
	redScore.BackgroundTransparency = 1
	redScore.Text = "0"
	redScore.TextColor3 = Color3.fromRGB(255, 255, 255)
	redScore.TextScaled = true
	redScore.Font = Enum.Font.GothamBlack
	redScore.Parent = redBox
	self.elements.redScore = redScore

	-- VS 뱃지 — 중앙
	local vsBadge = Instance.new("Frame")
	vsBadge.Name = "VSBadge"
	vsBadge.Size = UDim2.new(0.18, 0, 0.7, 0)
	vsBadge.Position = UDim2.new(0.41, 0, 0.15, 0)
	vsBadge.BackgroundColor3 = Color3.fromRGB(50, 55, 65)
	vsBadge.BorderSizePixel = 0
	vsBadge.ZIndex = 2
	vsBadge.Parent = scoreRow

	local vsCorner = Instance.new("UICorner")
	vsCorner.CornerRadius = UDim.new(0, 8)
	vsCorner.Parent = vsBadge

	local vsText = Instance.new("TextLabel")
	vsText.Size = UDim2.new(1, 0, 1, 0)
	vsText.BackgroundTransparency = 1
	vsText.Text = "VS"
	vsText.TextColor3 = Color3.fromRGB(255, 255, 255)
	vsText.TextScaled = true
	vsText.Font = Enum.Font.GothamBlack
	vsText.ZIndex = 2
	vsText.Parent = vsBadge

	-- AI(블루) 점수 박스 — 오른쪽
	local blueBox = Instance.new("Frame")
	blueBox.Name = "BlueScoreBox"
	blueBox.Size = UDim2.new(0.38, 0, 1, 0)
	blueBox.Position = UDim2.new(0.62, 0, 0, 0)
	blueBox.BackgroundColor3 = Color3.fromRGB(40, 70, 180)
	blueBox.BorderSizePixel = 0
	blueBox.Parent = scoreRow

	local blueCorner = Instance.new("UICorner")
	blueCorner.CornerRadius = UDim.new(0, 10)
	blueCorner.Parent = blueBox

	local blueScore = Instance.new("TextLabel")
	blueScore.Name = "BlueScore"
	blueScore.Size = UDim2.new(1, 0, 1, 0)
	blueScore.BackgroundTransparency = 1
	blueScore.Text = "0"
	blueScore.TextColor3 = Color3.fromRGB(255, 255, 255)
	blueScore.TextScaled = true
	blueScore.Font = Enum.Font.GothamBlack
	blueScore.Parent = blueBox
	self.elements.blueScore = blueScore
end

-- ===== 파워 게이지 (우측) =====
function UIController:_createPowerGauge(gui)
	local gaugeFrame = Instance.new("Frame")
	gaugeFrame.Name = "PowerGauge"
	gaugeFrame.Size = UDim2.new(0, 28, 0.35, 0)
	gaugeFrame.Position = UDim2.new(1, -46, 0.32, 0)
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
	bottomFrame.Size = UDim2.new(1, 0, 0, 75)
	bottomFrame.Position = UDim2.new(0, 0, 1, -75)
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

-- ===== 턴 인디케이터 =====
function UIController:_createTurnIndicator(gui)
	local turnLabel = Instance.new("TextLabel")
	turnLabel.Name = "TurnLabel"
	turnLabel.Size = UDim2.new(0.55, 0, 0, 30)
	turnLabel.Position = UDim2.new(0.225, 0, 0, 108)
	turnLabel.BackgroundColor3 = Color3.fromRGB(160, 35, 45)
	turnLabel.BackgroundTransparency = 0.15
	turnLabel.Text = "YOUR TURN - TAP TO SHOOT"
	turnLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	turnLabel.TextScaled = true
	turnLabel.Font = Enum.Font.GothamBold
	turnLabel.BorderSizePixel = 0
	turnLabel.Visible = false
	turnLabel.Parent = gui

	local turnCorner = Instance.new("UICorner")
	turnCorner.CornerRadius = UDim.new(0, 8)
	turnCorner.Parent = turnLabel

	self.elements.turnLabel = turnLabel
end

-- ===== 매치 결과 화면 =====
function UIController:_createResultScreen(gui)
	local resultFrame = Instance.new("Frame")
	resultFrame.Name = "ResultFrame"
	resultFrame.Size = UDim2.new(0.7, 0, 0.25, 0)
	resultFrame.Position = UDim2.new(0.15, 0, 0.38, 0)
	resultFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	resultFrame.BackgroundTransparency = 0.1
	resultFrame.BorderSizePixel = 0
	resultFrame.Visible = false
	resultFrame.Parent = gui

	local resultCorner = Instance.new("UICorner")
	resultCorner.CornerRadius = UDim.new(0, 16)
	resultCorner.Parent = resultFrame

	local resultText = Instance.new("TextLabel")
	resultText.Name = "ResultText"
	resultText.Size = UDim2.new(0.9, 0, 0.55, 0)
	resultText.Position = UDim2.new(0.05, 0, 0.08, 0)
	resultText.BackgroundTransparency = 1
	resultText.Text = ""
	resultText.TextColor3 = Color3.fromRGB(255, 255, 255)
	resultText.TextScaled = true
	resultText.Font = Enum.Font.GothamBlack
	resultText.Parent = resultFrame

	local resultScore = Instance.new("TextLabel")
	resultScore.Name = "ResultScore"
	resultScore.Size = UDim2.new(0.9, 0, 0.3, 0)
	resultScore.Position = UDim2.new(0.05, 0, 0.63, 0)
	resultScore.BackgroundTransparency = 1
	resultScore.Text = ""
	resultScore.TextColor3 = Color3.fromRGB(180, 180, 180)
	resultScore.TextScaled = true
	resultScore.Font = Enum.Font.GothamMedium
	resultScore.Parent = resultFrame

	self.elements.resultFrame = resultFrame
	self.elements.resultText = resultText
	self.elements.resultScore = resultScore
end

-- ===== Public API =====

function UIController:updateScores(playerScore: number, aiScore: number)
	self.elements.redScore.Text = tostring(playerScore)
	self.elements.blueScore.Text = tostring(aiScore)
end

function UIController:updateTimer(seconds: number)
	local min = math.floor(seconds / 60)
	local sec = seconds % 60
	self.elements.timer.Text = string.format("%02d:%02d", min, sec)
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

function UIController:updateSpinIndicator(spin: number)
	-- 스핀 인디케이터가 없으면 생성
	if not self.elements.spinLabel then
		local spinLabel = Instance.new("TextLabel")
		spinLabel.Name = "SpinLabel"
		spinLabel.Size = UDim2.new(0, 80, 0, 28)
		spinLabel.Position = UDim2.new(0, 12, 0.5, 0)
		spinLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
		spinLabel.BackgroundTransparency = 0.3
		spinLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		spinLabel.TextScaled = true
		spinLabel.Font = Enum.Font.GothamBold
		spinLabel.BorderSizePixel = 0
		spinLabel.Text = "SPIN"
		spinLabel.Parent = self.gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = spinLabel

		self.elements.spinLabel = spinLabel
	end

	local label = self.elements.spinLabel
	if math.abs(spin) < 0.1 then
		label.Transparency = 1
		label.BackgroundTransparency = 1
		label.TextTransparency = 1
	else
		label.Transparency = 0
		label.BackgroundTransparency = 0.3
		label.TextTransparency = 0
		if spin < 0 then
			label.Text = string.rep("<", math.ceil(math.abs(spin) * 3)) .. " SPIN"
		else
			label.Text = "SPIN " .. string.rep(">", math.ceil(spin * 3))
		end
	end
end

function UIController:setTurn(isPlayerTurn: boolean)
	local label = self.elements.turnLabel
	label.Visible = true

	if isPlayerTurn then
		label.Text = "YOUR TURN - TAP TO SHOOT"
		label.BackgroundColor3 = Color3.fromRGB(160, 35, 45)
		self.elements.gaugeFrame.Visible = false
	else
		label.Text = "AI THINKING..."
		label.BackgroundColor3 = Color3.fromRGB(40, 70, 180)
		self.elements.gaugeFrame.Visible = false
	end

	-- 페이드 인
	label.TextTransparency = 1
	label.BackgroundTransparency = 1
	TweenService:Create(label, TweenInfo.new(0.3), {
		TextTransparency = 0,
		BackgroundTransparency = 0.15,
	}):Play()

	-- 3초 후 페이드 아웃
	task.delay(2.5, function()
		if label.Visible then
			TweenService:Create(label, TweenInfo.new(0.5), {
				TextTransparency = 1,
				BackgroundTransparency = 1,
			}):Play()
		end
	end)
end

function UIController:updateRemainingBalls(playerBalls: number, aiBalls: number)
	for _, child in self.elements.redBallRow:GetChildren() do
		if child:IsA("Frame") then
			local idx = tonumber(child.Name:match("%d+"))
			if idx then
				child.BackgroundTransparency = idx <= playerBalls and 0 or 0.75
			end
		end
	end

	for _, child in self.elements.blueBallRow:GetChildren() do
		if child:IsA("Frame") then
			local idx = tonumber(child.Name:match("%d+"))
			if idx then
				child.BackgroundTransparency = idx <= aiBalls and 0 or 0.75
			end
		end
	end
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
	popup.Font = Enum.Font.GothamBlack
	popup.TextStrokeTransparency = 0.4
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

function UIController:showMatchResult(winner: string, scores)
	self.elements.resultFrame.Visible = true

	if winner == "player" then
		self.elements.resultText.Text = "YOU WIN!"
		self.elements.resultText.TextColor3 = Color3.fromRGB(255, 215, 50)
	elseif winner == "ai" then
		self.elements.resultText.Text = "YOU LOSE"
		self.elements.resultText.TextColor3 = Color3.fromRGB(180, 60, 60)
	else
		self.elements.resultText.Text = "DRAW"
		self.elements.resultText.TextColor3 = Color3.fromRGB(200, 200, 200)
	end

	self.elements.resultScore.Text = string.format("%d - %d", scores.player, scores.ai)
end

return UIController
