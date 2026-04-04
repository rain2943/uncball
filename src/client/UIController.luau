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
	self:_createMissionPanel(gui)
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

	-- 게임 타이머 (상단 중앙, 크게)
	local timer = Instance.new("TextLabel")
	timer.Name = "Timer"
	timer.Size = UDim2.new(0.2, 0, 0, 32)
	timer.Position = UDim2.new(0.4, 0, 0, 38)
	timer.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	timer.BackgroundTransparency = 0.2
	timer.Text = "03:00"
	timer.TextColor3 = Color3.fromRGB(255, 255, 255)
	timer.TextScaled = true
	timer.Font = Enum.Font.GothamBold
	timer.BorderSizePixel = 0
	timer.Parent = gui

	local timerCorner = Instance.new("UICorner")
	timerCorner.CornerRadius = UDim.new(0, 8)
	timerCorner.Parent = timer

	self.elements.timer = timer

	-- 턴 타이머 (게임 타이머 아래)
	local turnTimer = Instance.new("TextLabel")
	turnTimer.Name = "TurnTimer"
	turnTimer.Size = UDim2.new(0.12, 0, 0, 22)
	turnTimer.Position = UDim2.new(0.44, 0, 0, 72)
	turnTimer.BackgroundColor3 = Color3.fromRGB(200, 60, 50)
	turnTimer.BackgroundTransparency = 0.2
	turnTimer.Text = "10"
	turnTimer.TextColor3 = Color3.fromRGB(255, 255, 255)
	turnTimer.TextScaled = true
	turnTimer.Font = Enum.Font.GothamBlack
	turnTimer.BorderSizePixel = 0
	turnTimer.Visible = false
	turnTimer.Parent = gui

	local turnCorner = Instance.new("UICorner")
	turnCorner.CornerRadius = UDim.new(0, 6)
	turnCorner.Parent = turnTimer

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
	redBox.Size = UDim2.new(0.44, 0, 1, 0)
	redBox.Position = UDim2.new(0, 0, 0, 0)
	redBox.BackgroundColor3 = Color3.fromRGB(160, 35, 45)
	redBox.BorderSizePixel = 0
	redBox.Parent = scoreRow

	local redCorner = Instance.new("UICorner")
	redCorner.CornerRadius = UDim.new(0, 10)
	redCorner.Parent = redBox

	-- 이름
	local redName = Instance.new("TextLabel")
	redName.Size = UDim2.new(0.55, 0, 1, 0)
	redName.Position = UDim2.new(0.03, 0, 0, 0)
	redName.BackgroundTransparency = 1
	redName.Text = Players.LocalPlayer.DisplayName
	redName.TextColor3 = Color3.fromRGB(255, 255, 255)
	redName.TextScaled = true
	redName.Font = Enum.Font.GothamBold
	redName.TextXAlignment = Enum.TextXAlignment.Left
	redName.Parent = redBox

	-- 점수
	local redScore = Instance.new("TextLabel")
	redScore.Name = "RedScore"
	redScore.Size = UDim2.new(0.35, 0, 1, 0)
	redScore.Position = UDim2.new(0.62, 0, 0, 0)
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
	vsBadge.Size = UDim2.new(0.1, 0, 0.7, 0)
	vsBadge.Position = UDim2.new(0.45, 0, 0.15, 0)
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
	blueBox.Size = UDim2.new(0.44, 0, 1, 0)
	blueBox.Position = UDim2.new(0.56, 0, 0, 0)
	blueBox.BackgroundColor3 = Color3.fromRGB(40, 70, 180)
	blueBox.BorderSizePixel = 0
	blueBox.Parent = scoreRow

	local blueCorner = Instance.new("UICorner")
	blueCorner.CornerRadius = UDim.new(0, 10)
	blueCorner.Parent = blueBox

	-- 점수
	local blueScore = Instance.new("TextLabel")
	blueScore.Name = "BlueScore"
	blueScore.Size = UDim2.new(0.35, 0, 1, 0)
	blueScore.Position = UDim2.new(0.03, 0, 0, 0)
	blueScore.BackgroundTransparency = 1
	blueScore.Text = "0"
	blueScore.TextColor3 = Color3.fromRGB(255, 255, 255)
	blueScore.TextScaled = true
	blueScore.Font = Enum.Font.GothamBlack
	blueScore.Parent = blueBox

	-- 이름
	local blueName = Instance.new("TextLabel")
	blueName.Size = UDim2.new(0.55, 0, 1, 0)
	blueName.Position = UDim2.new(0.42, 0, 0, 0)
	blueName.BackgroundTransparency = 1
	blueName.Text = "AI"
	blueName.TextColor3 = Color3.fromRGB(255, 255, 255)
	blueName.TextScaled = true
	blueName.Font = Enum.Font.GothamBold
	blueName.TextXAlignment = Enum.TextXAlignment.Right
	blueName.Parent = blueBox
	self.elements.blueScore = blueScore
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
	panel.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
	panel.BackgroundTransparency = 0.4
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.Parent = gui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 10)
	panelCorner.Parent = panel

	-- 미션 카드 3개
	self.elements.missionCards = {}
	local yOffset = PAD

	for i = 1, 3 do
		local card = Instance.new("Frame")
		card.Name = "Mission_" .. i
		card.Size = UDim2.new(1, -PAD * 2, 0, CARD_H)
		card.Position = UDim2.new(0, PAD, 0, yOffset)
		card.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
		card.BackgroundTransparency = 0.15
		card.BorderSizePixel = 0
		card.ClipsDescendants = true
		card.Parent = panel

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 8)
		cardCorner.Parent = card

		-- 보너스 (좌측, 크게)
		local bonusLabel = Instance.new("TextLabel")
		bonusLabel.Name = "Bonus"
		bonusLabel.Size = UDim2.new(0, 38, 1, 0)
		bonusLabel.Position = UDim2.new(0, 6, 0, 0)
		bonusLabel.BackgroundTransparency = 1
		bonusLabel.Text = ""
		bonusLabel.TextColor3 = Color3.fromRGB(255, 210, 50)
		bonusLabel.Font = Enum.Font.GothamBlack
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
		statusLabel.Font = Enum.Font.GothamBlack
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
			bubble.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
			bubble.BorderSizePixel = 0

			local bubbleCorner = Instance.new("UICorner")
			bubbleCorner.CornerRadius = UDim.new(0, 6)
			bubbleCorner.Parent = bubble

			local letterLabel = Instance.new("TextLabel")
			letterLabel.Name = "Text"
			letterLabel.Size = UDim2.new(1, 0, 1, 0)
			letterLabel.BackgroundTransparency = 1
			letterLabel.Text = letter
			letterLabel.TextColor3 = Color3.fromRGB(120, 120, 135)
			letterLabel.Font = Enum.Font.GothamBlack
			letterLabel.TextSize = 15
			letterLabel.Parent = bubble

			bubble.Parent = cardData.letterContainer
			table.insert(cardData.letterBubbles, bubble)
		end

		-- 상태 리셋
		cardData.statusLabel.Visible = false
		cardData.card.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
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
			-- 선점된 미션
			if mission.claimedBy == "player" then
				cardData.card.BackgroundColor3 = Color3.fromRGB(30, 80, 40)
				cardData.statusLabel.Text = "CLEAR!"
				cardData.statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
				cardData.bonusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
			else
				cardData.card.BackgroundColor3 = Color3.fromRGB(50, 40, 40)
				cardData.statusLabel.Text = "TAKEN"
				cardData.statusLabel.TextColor3 = Color3.fromRGB(150, 80, 80)
				cardData.bonusLabel.TextColor3 = Color3.fromRGB(80, 80, 85)
				-- 레터 어둡게
				for _, bubble in cardData.letterBubbles do
					bubble.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
					local txt = bubble:FindFirstChild("Text")
					if txt then txt.TextColor3 = Color3.fromRGB(70, 70, 75) end
				end
			end
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
						bubble.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
						if txt then txt.TextColor3 = Color3.fromRGB(255, 255, 255) end
					else
						-- 미보유 → 어둡게
						bubble.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
						if txt then txt.TextColor3 = Color3.fromRGB(120, 120, 135) end
					end
				end
			end
		end
	end
end

-- ===== 미션 완료 팝업 (화면 중앙) =====
function UIController:_showMissionPopup(mission)
	local popup = Instance.new("Frame")
	popup.Name = "MissionPopup"
	popup.Size = UDim2.new(0, 0, 0, 0)
	popup.Position = UDim2.new(0.5, 0, 0.4, 0)
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.BackgroundColor3 = Color3.fromRGB(25, 40, 60)
	popup.BackgroundTransparency = 0.1
	popup.BorderSizePixel = 0
	popup.ZIndex = 10
	popup.Parent = self.gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = popup

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 200, 255)
	stroke.Thickness = 2
	stroke.Transparency = 0
	stroke.Parent = popup

	-- "MISSION COMPLETE!"
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -16, 0.45, 0)
	titleLabel.Position = UDim2.new(0, 8, 0, 4)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "MISSION COMPLETE!"
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.ZIndex = 11
	titleLabel.Parent = popup

	-- 레터 + 보너스 행
	local detailLabel = Instance.new("TextLabel")
	detailLabel.Name = "Detail"
	detailLabel.Size = UDim2.new(1, -16, 0.4, 0)
	detailLabel.Position = UDim2.new(0, 8, 0.5, 2)
	detailLabel.BackgroundTransparency = 1
	detailLabel.Text = table.concat(mission.letters, "-") .. "  +" .. mission.bonus
	detailLabel.TextColor3 = Color3.fromRGB(100, 220, 255)
	detailLabel.TextScaled = true
	detailLabel.Font = Enum.Font.GothamBold
	detailLabel.ZIndex = 11
	detailLabel.Parent = popup

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
	self.elements.redScore.Text = tostring(playerScore)
	self.elements.blueScore.Text = tostring(aiScore)
end

function UIController:updateTimer(seconds: number)
	seconds = math.max(seconds, 0)
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

function UIController:updateSpinIndicator(spin: number, power: number?)
	power = power or 0

	-- 3D 공 모델 + 속도 텍스트 인디케이터 생성
	if not self.elements.spinFrame then
		-- 컨테이너 프레임
		local frame = Instance.new("Frame")
		frame.Name = "SpinFrame"
		frame.Size = UDim2.new(0, 90, 0, 110)
		frame.Position = UDim2.new(0, 10, 0.45, 0)
		frame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
		frame.BackgroundTransparency = 0.25
		frame.BorderSizePixel = 0
		frame.Visible = false
		frame.Parent = self.gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = frame

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
		speedText.TextColor3 = Color3.fromRGB(180, 180, 180)
		speedText.TextScaled = true
		speedText.Font = Enum.Font.GothamMedium
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
		spinText.Font = Enum.Font.GothamBold
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

function UIController:setTurn(isPlayerTurn: boolean)
	local label = self.elements.turnLabel
	label.Visible = true

	-- 턴 타이머 초기화
	if self._turnTimerThread then
		task.cancel(self._turnTimerThread)
		self._turnTimerThread = nil
	end

	if isPlayerTurn then
		label.Text = "YOUR TURN"
		label.BackgroundColor3 = Color3.fromRGB(160, 35, 45)

		-- 턴 카운트다운 시작
		local turnTimer = self.elements.turnTimer
		if turnTimer then
			turnTimer.Visible = true
			self._turnTimerThread = task.spawn(function()
				for sec = Config.GAME.TURN_TIME, 1, -1 do
					turnTimer.Text = tostring(sec)
					-- 3초 이하면 빨간색 강조
					if sec <= 3 then
						turnTimer.BackgroundColor3 = Color3.fromRGB(220, 40, 30)
					else
						turnTimer.BackgroundColor3 = Color3.fromRGB(200, 60, 50)
					end
					task.wait(1)
				end
				turnTimer.Visible = false
			end)
		end
	else
		label.Text = "AI THINKING..."
		label.BackgroundColor3 = Color3.fromRGB(40, 70, 180)
		if self.elements.turnTimer then
			self.elements.turnTimer.Visible = false
		end
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
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 40
	label.TextStrokeTransparency = 0.3
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

function UIController:hideResult()
	self.elements.resultFrame.Visible = false
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
