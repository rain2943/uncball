local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer

-- 기본 Roblox UI 전부 숨기기
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)

-- 리스폰(캐릭터 리셋) 버튼 비활성화
task.spawn(function()
	-- SetCore는 로드 타이밍에 따라 실패할 수 있어서 반복 시도
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", false)
		end)
		if ok then break end
		task.wait(0.5)
	end
end)

-- 기본 캐릭터 컨트롤 비활성화
task.spawn(function()
	local ok, PlayerModule = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if ok and PlayerModule then
		pcall(function()
			PlayerModule:GetControls():Disable()
		end)
	end
end)

-- 모듈 로드
local UIController = require(script:WaitForChild("UIController"))
local LaunchController = require(script:WaitForChild("LaunchController"))
local CameraController = require(script:WaitForChild("CameraController"))
local LobbyController = require(script:WaitForChild("LobbyController"))

-- 리모트 이벤트 대기
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local remoteEvents = {}
for _, name in Config.REMOTES do
	remoteEvents[name] = remotes:WaitForChild(name)
end

-- 컨트롤러 초기화
local ui = UIController.new()
local camera = CameraController.new()
local launch = LaunchController.new(remoteEvents, ui)
launch.cameraController = camera
local lobby = LobbyController.new()

-- === 암전 트랜지션 ===
local fadeGui = Instance.new("ScreenGui")
fadeGui.Name = "FadeScreen"
fadeGui.ResetOnSpawn = false
fadeGui.DisplayOrder = 100
fadeGui.IgnoreGuiInset = true
fadeGui.Parent = player:WaitForChild("PlayerGui")

local fadeFrame = Instance.new("Frame")
fadeFrame.Name = "Fade"
fadeFrame.Size = UDim2.new(1, 0, 1, 0)
fadeFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
fadeFrame.BackgroundTransparency = 1
fadeFrame.BorderSizePixel = 0
fadeFrame.ZIndex = 100
fadeFrame.Parent = fadeGui

local function fadeToBlack(duration: number?)
	duration = duration or 0.5
	fadeFrame.BackgroundTransparency = 1
	local tween = TweenService:Create(fadeFrame, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 0,
	})
	tween:Play()
	tween.Completed:Wait()
end

local function fadeFromBlack(duration: number?)
	duration = duration or 0.5
	fadeFrame.BackgroundTransparency = 0
	local tween = TweenService:Create(fadeFrame, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	})
	tween:Play()
	tween.Completed:Wait()
end

-- 매치 상태 추적
local inMatch = false
local currentTableOffset = Vector3.zero

-- 초기 상태: 로비 보이기, HUD 숨기기
ui:hide()
lobby:show()
camera:enterLobbyView()

-- === SFX ===
local SFX = {
	LAUNCH = "rbxassetid://121730291891328",
	COLLISION = "rbxassetid://9113439845",
	SCORE = "rbxassetid://116574637578954",
	MISSION = "rbxassetid://5711770745",
}

local function playSound(soundId: string, volume: number?, parent: Instance?)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.Parent = parent or workspace
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	return sound
end

-- 공에 충돌 사운드 부착
local function attachCollisionSound(ball: Part)
	local lastHitTime = 0
	ball.Touched:Connect(function(other)
		if other.Name == "TableTop" or other.Name == "TableFloor" then return end
		local now = tick()
		if now - lastHitTime < 0.12 then return end
		local vel = ball.AssemblyLinearVelocity.Magnitude
		if vel < 0.8 then return end
		lastHitTime = now
		local vol = math.clamp(vel / 8, 0.5, 1.5)
		playSound(SFX.COLLISION, vol, ball)
	end)
end

-- === 로비 → 매치 플로우 ===

-- PLAY 버튼 콜백: 서버에 매칭 요청
lobby.onPlayCallback = function()
	remoteEvents.RequestMatch:FireServer()
end

-- === 이벤트 핸들러 ===

remoteEvents.MatchStart.OnClientEvent:Connect(function(data)
	inMatch = true

	-- 테이블 오프셋 설정
	if data.tableOffset then
		currentTableOffset = Vector3.new(data.tableOffset[1], data.tableOffset[2], data.tableOffset[3])
	else
		currentTableOffset = Vector3.zero
	end
	camera:setTableOffset(currentTableOffset)
	launch:setTableOffset(currentTableOffset)

	-- 매칭 팝업 닫기 (PvP 매치일 경우)
	ui:hideMatchFoundPopup()

	-- 팀 색상 설정
	local myColor = data.teamColor == "blue" and Config.BALL.COLORS.BLUE or Config.BALL.COLORS.RED
	launch:setTeamColor(myColor)

	-- HUD 즉시 초기화 (로비 UI가 위에 덮고 있으므로 안 보임)
	ui:show()
	ui:hideResult()
	ui:updateScores(0, 0)
	ui:updateRemainingBalls(data.ballsPerPlayer, data.ballsPerPlayer)
	ui._opponentName = data.opponentName or "AI"
	ui._opponentId = data.opponentId
	ui:setupScoreboard(data.teamColor or "red", data.opponentName or "AI")

	if data.missions then
		ui:initMissions(data.missions)
	end

	-- BGM 재생
	if not workspace:FindFirstChild("BGM") then
		local bgm = Instance.new("Sound")
		bgm.Name = "BGM"
		bgm.SoundId = "rbxassetid://126841253996417"
		bgm.Volume = 0.4
		bgm.Looped = true
		bgm.Parent = workspace
		bgm:Play()
	end

	-- 암전 트랜지션 (UI 전환은 이미 완료, 암전 중 로비만 숨김)
	task.spawn(function()
		fadeToBlack(0.4)
		lobby:hide()
		task.wait(0.15)
		fadeFromBlack(0.6)
	end)
end)

remoteEvents.TurnChanged.OnClientEvent:Connect(function(isPlayerTurn, _remainingBalls, isBonus)
	if not inMatch then return end
	ui:setTurn(isPlayerTurn, isBonus)
	launch:setEnabled(isPlayerTurn)
	camera:enterLaunchView()
	if isPlayerTurn then
		playSound("rbxassetid://127421479045055", 0.5)
		-- 온보딩 가이드 표시 (공 터치하면 사라짐)
		ui:showLaunchGuide()
	else
		ui:hideLaunchGuide()
	end
end)

remoteEvents.GameStateUpdate.OnClientEvent:Connect(function(data)
	ui:updateScores(data.scores.player, data.scores.ai)
	ui:updateRemainingBalls(data.remainingBalls.player, data.remainingBalls.ai)
	if data.missions then
		ui:updateMissions(data.missions, data.playerLetters)
	end
end)

remoteEvents.BallCreated.OnClientEvent:Connect(function(ball)
	-- 공 발사됨 → 턴 타이머 즉시 숨기기 (ball 복제 전이라도)
	ui:hideTurnTimer()
	-- 상대 가이드 도트 숨기기
	hideOppGuideDots()
	-- 발사 SFX (내 공이든 상대 공이든 즉시 재생)
	playSound(SFX.LAUNCH, 1.0)

	if ball and ball.Parent then
		camera:trackBall(ball)
		attachCollisionSound(ball)
	end
end)

workspace.ChildAdded:Connect(function(child)
	if child:IsA("Part") and child.Shape == Enum.PartType.Ball
		and (child.Name == "PlayerBall" or child.Name == "AIBall") then
		-- 내 테이블 근처 공만 추적 (다른 매치 공 무시)
		if math.abs(child.Position.X - currentTableOffset.X) > 50 then return end
		task.wait(0.1)
		camera:trackBall(child)
		attachCollisionSound(child)
	end
end)

remoteEvents.BallLanded.OnClientEvent:Connect(function(data)
	if data.zone and data.points > 0 then
		ui:showScorePopup(data.position, data.points, data.team)
		playSound(SFX.SCORE, 0.5)
	end
	if data.missions then
		ui:updateMissions(data.missions, data.playerLetters)
	end
	if data.newMissions and #data.newMissions > 0 then
		playSound(SFX.MISSION, 0.6)
	end
end)

remoteEvents.MatchEnd.OnClientEvent:Connect(function(data)
	inMatch = false
	launch:setEnabled(false)
	destroyOppGuideDots()
	ui:hideTurnTimer()
	ui:hideLaunchGuide()
	currentTableOffset = Vector3.zero
	camera:setTableOffset(Vector3.zero)
	launch:setTableOffset(Vector3.zero)

	-- 강제 종료 (PvP 전환 등) → 결과 화면 없이 즉시 정리
	if data.forced then
		ui:hide()
		return
	end

	-- 상대 퇴장 시 "Leave!" 표시
	if data.disconnected then
		ui:setOpponentName("Leave!")
	end
	ui:showMatchResult(data.winner, data.scores)

	-- 5초 후 암전 → 로비 복귀
	task.delay(4.5, function()
		fadeToBlack(0.5)

		ui:hide()
		lobby:show()
		camera:enterLobbyView()

		-- BGM 정지
		local bgm = workspace:FindFirstChild("BGM")
		if bgm then bgm:Destroy() end

		task.wait(0.2)
		fadeFromBlack(0.6)
	end)
end)

-- === 매칭 팝업 ===

-- 매칭 발견 → 팝업 (게임 중이든 로비든)
remoteEvents.MatchFound.OnClientEvent:Connect(function(data)
	ui:showMatchFoundPopup(data.opponentName, data.countdown or 5, function()
		-- 취소 버튼 콜백
		remoteEvents.CancelMatchmaking:FireServer()
	end)
end)

-- 매칭 취소됨 (상대가 취소 또는 내가 취소)
remoteEvents.MatchCancelled.OnClientEvent:Connect(function()
	ui:hideMatchFoundPopup()
end)

-- === PvP 타이밍 등급 수신 ===
remoteEvents.TimingGrade.OnClientEvent:Connect(function(gradeName, colorArr)
	if not inMatch then return end
	if typeof(colorArr) == "table" and #colorArr >= 3 then
		local color = Color3.new(colorArr[1], colorArr[2], colorArr[3])
		ui:showTimingGrade(gradeName, color)
	end
end)

-- === PvP 상대 프리뷰 ===
local opponentPreview = nil
local opponentTeamColor = Config.BALL.COLORS.BLUE
local OPP_GUIDE_DOT_COUNT = 20
local OPP_GUIDE_DOT_SIZE = 0.22
local oppGuideDots = {}

local function createOppGuideDots()
	for i = 1, OPP_GUIDE_DOT_COUNT do
		local dot = Instance.new("Part")
		dot.Name = "OppGuideDot" .. i
		dot.Shape = Enum.PartType.Ball
		dot.Size = Vector3.one * OPP_GUIDE_DOT_SIZE
		dot.Material = Enum.Material.Neon
		dot.Color = opponentTeamColor
		dot.Transparency = 0.5
		dot.Anchored = true
		dot.CanCollide = false
		dot.CanQuery = false
		dot.CanTouch = false
		dot.Parent = workspace
		oppGuideDots[i] = dot
	end
end

local function hideOppGuideDots()
	for _, dot in oppGuideDots do
		dot.Transparency = 1
	end
end

local function destroyOppGuideDots()
	for _, dot in oppGuideDots do
		if dot.Parent then dot:Destroy() end
	end
	oppGuideDots = {}
end

local function updateOppGuide(spawnX: number, power: number, spin: number)
	if #oppGuideDots == 0 then
		createOppGuideDots()
	end

	local spawnY = Config.TABLE.HEIGHT + Config.TABLE.THICKNESS / 2 + Config.BALL.RADIUS + 0.2
	local spawnPos = Vector3.new(spawnX, spawnY, Config.LAUNCH.SPAWN_Z) + currentTableOffset
	local currentPower = Config.LAUNCH.MIN_POWER + (Config.LAUNCH.MAX_POWER - Config.LAUNCH.MIN_POWER) * power

	local mass = 2
	local lateralAccel = spin * Config.SPIN.MAX_LATERAL_FORCE / mass * 2.5
	local maxDist = power * 20

	for i, dot in oppGuideDots do
		local t_ratio = i / OPP_GUIDE_DOT_COUNT
		local dist = maxDist * t_ratio
		local avgSpeed = currentPower * (1 - t_ratio * 0.5)
		local time = dist / math.max(avgSpeed, 1)
		local lateralOffset = 0.5 * lateralAccel * time * time

		local pos = spawnPos + Vector3.new(0, 0, 1) * dist + Vector3.new(1, 0, 0) * lateralOffset
		dot.Position = Vector3.new(pos.X, spawnY - Config.BALL.RADIUS + 0.1, pos.Z)
		dot.Color = opponentTeamColor
		dot.Transparency = 0.5
	end
end

-- 상대 프리뷰 공 생성/이동
remoteEvents.PreviewUpdate.OnClientEvent:Connect(function(spawnX, power, spin)
	if not inMatch then return end

	local spawnY = Config.TABLE.HEIGHT + Config.TABLE.THICKNESS / 2 + Config.BALL.RADIUS + 0.2

	if not opponentPreview or not opponentPreview.Parent then
		opponentPreview = Instance.new("Part")
		opponentPreview.Name = "OpponentPreview"
		opponentPreview.Shape = Enum.PartType.Ball
		opponentPreview.Size = Vector3.one * Config.BALL.RADIUS * 2
		opponentPreview.Color = opponentTeamColor
		opponentPreview.Material = Enum.Material.Marble
		opponentPreview.Transparency = 0.4
		opponentPreview.Anchored = true
		opponentPreview.CanCollide = false
		opponentPreview.CanQuery = false
		opponentPreview.CanTouch = false
		opponentPreview.Parent = workspace
	end

	opponentPreview.Position = Vector3.new(spawnX, spawnY, Config.LAUNCH.SPAWN_Z) + currentTableOffset
	-- 카메라도 따라감
	camera:setLaunchFollowX(spawnX)

	-- 가이드 도트 표시
	if power and power > 0.02 then
		updateOppGuide(spawnX, power, spin or 0)
	else
		hideOppGuideDots()
	end
end)

-- 상대 공 발사되면 프리뷰 숨기기
remoteEvents.BallCreated.OnClientEvent:Connect(function()
	if opponentPreview and opponentPreview.Parent then
		opponentPreview:Destroy()
		opponentPreview = nil
	end
	hideOppGuideDots()
end)

-- MatchStart에서 상대 팀 색상 저장
remoteEvents.MatchStart.OnClientEvent:Connect(function(data)
	if data.teamColor == "blue" then
		opponentTeamColor = Config.BALL.COLORS.RED
	else
		opponentTeamColor = Config.BALL.COLORS.BLUE
	end
end)

-- 매치 종료 시 프리뷰 정리
remoteEvents.MatchEnd.OnClientEvent:Connect(function()
	if opponentPreview and opponentPreview.Parent then
		opponentPreview:Destroy()
		opponentPreview = nil
	end
end)

print("[Uncball] Client initialized - lobby mode")
