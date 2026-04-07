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

-- BGM 목록
local BGM_LIST = {
	"rbxassetid://135010856476032",
	"rbxassetid://85272223742549",
	"rbxassetid://108671257023205",
	"rbxassetid://138690886215230",
	"rbxassetid://114347048378804",
	"rbxassetid://126841253996417",
}

local function playBGM()
	local old = workspace:FindFirstChild("BGM")
	if old then old:Destroy() end
	local bgm = Instance.new("Sound")
	bgm.Name = "BGM"
	bgm.SoundId = BGM_LIST[math.random(1, #BGM_LIST)]
	bgm.Volume = 0.4
	bgm.Looped = true
	bgm.Parent = workspace
	bgm:Play()
end

local function stopBGM()
	local bgm = workspace:FindFirstChild("BGM")
	if bgm then bgm:Destroy() end
end

-- 매치 상태 추적
local inMatch = false
local currentTableOffset = Vector3.zero
local localRank = 1000
local pendingRankChange = nil
local pendingNewRank = nil

-- 바람 시각 이펙트 (Trail 기반 — 공 스핀 트레일과 같은 스타일)
local windTrails = {} -- { part, trail, att0, att1 }
local windLoopThread = nil
local currentWindSpeed = 0
local currentWindAngle = 0

local function spawnWindTrail()
	local rad = math.rad(currentWindAngle)
	local dir = Vector3.new(math.cos(rad), 0, math.sin(rad))
	local right = Vector3.new(-dir.Z, 0, dir.X)

	-- 테이블 전체 영역에 고르게 분포
	local y = 4.0 + math.random() * 3.0
	local spread = (math.random() - 0.5) * 30
	local along = (math.random() - 0.5) * 60
	local startPos = currentTableOffset + Vector3.new(0, y, 0) + dir * along + right * spread

	local part = Instance.new("Part")
	part.Name = "WindTrailPart"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.CFrame = CFrame.new(startPos)
	part.Parent = workspace

	local att0 = Instance.new("Attachment")
	att0.Position = Vector3.new(0, 0.08, 0)
	att0.Parent = part

	local att1 = Instance.new("Attachment")
	att1.Position = Vector3.new(0, -0.08, 0)
	att1.Parent = part

	local trail = Instance.new("Trail")
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Lifetime = 0.8
	trail.MinLength = 0.02
	trail.FaceCamera = true
	trail.LightEmission = 0.4
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Color = ColorSequence.new(Color3.fromRGB(160, 200, 255), Color3.fromRGB(100, 150, 230))
	trail.Parent = part

	table.insert(windTrails, {
		part = part,
		dir = dir,
		speed = currentWindSpeed * (1.6 + math.random() * 0.8),
		life = 0,
		maxLife = 1.8 + math.random() * 0.8,
	})
end

local function cleanupWindStreaks()
	for _, s in windTrails do
		if s.part and s.part.Parent then s.part:Destroy() end
	end
	windTrails = {}
	if windLoopThread then
		task.cancel(windLoopThread)
		windLoopThread = nil
	end
end

local function startWindLoop()
	if windLoopThread then return end
	windLoopThread = task.spawn(function()
		local spawnTimer = 0
		while true do
			local dt = task.wait()
			if not inMatch then break end

			local spawnRate = math.clamp(currentWindSpeed * 0.8, 2, 10)
			spawnTimer = spawnTimer + dt * spawnRate
			while spawnTimer >= 1 do
				spawnTimer = spawnTimer - 1
				spawnWindTrail()
			end

			local alive = {}
			for _, s in windTrails do
				s.life = s.life + dt
				if s.life >= s.maxLife then
					if s.part and s.part.Parent then s.part:Destroy() end
				else
					s.part.CFrame = s.part.CFrame + s.dir * s.speed * dt
					table.insert(alive, s)
				end
			end
			windTrails = alive
		end
	end)
end

local function createWindParticle()
	startWindLoop()
end

local function destroyWindParticle()
	cleanupWindStreaks()
end

local function updateWindParticle(speed, angle)
	currentWindSpeed = speed
	currentWindAngle = angle
end

-- 초기 상태: 로비 보이기, HUD 숨기기
ui:hide()
lobby:show()
camera:enterLobbyView()
playBGM() -- 로비 BGM

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

-- === PvP 상대 프리뷰 (함수 정의) ===
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
	local lateralAccel = spin * Config.SPIN.MAX_LATERAL_FORCE / mass * 5.5
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

	-- 랭크 표시
	ui:setRanks(data.myRank or localRank, data.opponentRank or 0)

	-- 바람 파티클 생성
	createWindParticle()

	-- BGM 변경 (매치용 랜덤 곡)
	playBGM()

	-- 암전 트랜지션 (UI 전환은 이미 완료, 암전 중 로비만 숨김)
	task.spawn(function()
		fadeToBlack(0.4)
		lobby:hide()
		task.wait(0.15)
		fadeFromBlack(0.6)
	end)
end)

remoteEvents.TurnChanged.OnClientEvent:Connect(function(isPlayerTurn, _remainingBalls, isBonus, windData)
	if not inMatch then return end
	-- 턴 전환 시 상대 프리뷰/가이드 도트 정리 (타임아웃 시 BallCreated 안 오므로 여기서 처리)
	if opponentPreview and opponentPreview.Parent then
		opponentPreview:Destroy()
		opponentPreview = nil
	end
	hideOppGuideDots()
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
	-- 바람 업데이트
	if windData and windData.speed then
		ui:updateWind(windData.speed, windData.angle)
		updateWindParticle(windData.speed, windData.angle)
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
		-- 득점 시 해당 팀 캐릭터 세레브 애니메이션
		ui:playCelebrateAnim(data.team)
	elseif not data.zone and data.team then
		-- 공 아웃 (슬롯 미안착) → 해당 팀 슬퍼하는 애니메이션
		ui:playSadAnim(data.team)
	end
	-- 콤보/올킬 연출
	if data.isAllKill then
		ui:showComboPopup(0, true, data.team)
	elseif data.comboCount and data.comboCount >= 2 then
		ui:showComboPopup(data.comboCount, false, data.team)
	end
	if data.missions then
		ui:updateMissions(data.missions, data.playerLetters)
	end
	if data.newMissions and #data.newMissions > 0 then
		playSound(SFX.MISSION, 0.6)
	end
end)

-- 이모지 리액션 수신
remoteEvents.SendEmoji.OnClientEvent:Connect(function(side, emojiId)
	if not inMatch then return end
	ui:showEmojiReaction(side, emojiId)
end)

remoteEvents.MatchEnd.OnClientEvent:Connect(function(data)
	inMatch = false
	launch:setEnabled(false)
	destroyOppGuideDots()
	destroyWindParticle()
	ui:hideTurnTimer()
	ui:hideLaunchGuide()
	ui:hideWind()

	-- 강제 종료 (PvP 전환 등) → 결과 화면 없이 즉시 정리
	if data.forced then
		ui:hide()
		currentTableOffset = Vector3.zero
		camera:setTableOffset(Vector3.zero)
		launch:setTableOffset(Vector3.zero)
		return
	end

	-- 상대 퇴장 시 "Leave!" 표시
	if data.disconnected then
		ui:setOpponentName("Leave!")
	end
	-- 랭크 변동 저장 (로비 복귀 시 갱신)
	if data.newRank then
		localRank = data.newRank
	end

	-- 카메라를 OVERVIEW에 유지한 채 결과 화면 표시
	camera:returnToOverview()
	ui:showMatchResult(data.winner, data.scores, data.rankChange, data.newRank)

	-- 5초 후 암전 → 로비 복귀
	task.delay(4.5, function()
		fadeToBlack(0.5)

		ui:hide()
		lobby:show()
		-- 로비 전환 시점에 오프셋 리셋
		currentTableOffset = Vector3.zero
		camera:setTableOffset(Vector3.zero)
		launch:setTableOffset(Vector3.zero)
		camera:enterLobbyView()

		-- BGM 변경 (로비용 랜덤 곡)
		playBGM()

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
		opponentPreview.Material = Enum.Material.SmoothPlastic
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

-- 랭크 업데이트 수신
remoteEvents.RankUpdate.OnClientEvent:Connect(function(newRank, change)
	localRank = newRank
	lobby:updateRank(newRank)
end)

print("[Uncball] Client initialized - lobby mode")
