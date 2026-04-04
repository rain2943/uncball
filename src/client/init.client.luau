local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer

-- 기본 Roblox UI 전부 숨기기
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)

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
		-- 바닥(테이블) 접촉은 무시 — 벽/공/포스트만
		if other.Name == "TableTop" or other.Name == "TableFloor" then return end
		-- 디바운스: 0.12초 간격
		local now = tick()
		if now - lastHitTime < 0.12 then return end
		-- 충분한 충격일 때만
		local vel = ball.AssemblyLinearVelocity.Magnitude
		if vel < 0.8 then return end
		lastHitTime = now
		local vol = math.clamp(vel / 15, 0.2, 1.0)
		playSound(SFX.COLLISION, vol, ball)
	end)
end

-- === 이벤트 핸들러 ===

remoteEvents.MatchStart.OnClientEvent:Connect(function(data)
	-- 이전 매치 결과 화면 숨기기
	ui:hideResult()
	ui:updateScores(0, 0)
	ui:updateRemainingBalls(data.ballsPerPlayer, data.ballsPerPlayer)
	ui:updateTimer(data.matchTime)

	-- 미션 카드 초기화
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
end)

remoteEvents.TurnChanged.OnClientEvent:Connect(function(isPlayerTurn, _remainingBalls)
	ui:setTurn(isPlayerTurn)
	launch:setEnabled(isPlayerTurn)
	-- 플레이어/AI 모두 발사 뷰로 전환 (공 나가는 걸 볼 수 있게)
	camera:enterLaunchView()
	if isPlayerTurn then
		playSound("rbxassetid://127421479045055", 0.5)
	end
end)

remoteEvents.GameStateUpdate.OnClientEvent:Connect(function(data)
	ui:updateScores(data.scores.player, data.scores.ai)
	ui:updateTimer(data.timer)
	ui:updateRemainingBalls(data.remainingBalls.player, data.remainingBalls.ai)
	if data.missions then
		ui:updateMissions(data.missions, data.playerLetters)
	end
end)

-- BallCreated 이벤트
remoteEvents.BallCreated.OnClientEvent:Connect(function(ball)
	if ball and ball.Parent then
		camera:trackBall(ball)
		attachCollisionSound(ball)
		-- AI 공 발사음 (플레이어 공은 LaunchController에서 즉시 재생)
		if ball.Name == "AIBall" then
			playSound(SFX.LAUNCH, 0.5)
		end
	end
end)

-- workspace에 공이 추가되면 직접 감지 (이벤트 실패 대비)
workspace.ChildAdded:Connect(function(child)
	if child:IsA("Part") and child.Shape == Enum.PartType.Ball
		and (child.Name == "PlayerBall" or child.Name == "AIBall") then
		task.wait(0.1) -- 물리 안정화
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
	if data.newMissions and #data.newMissions > 0 and data.team == "player" then
		ui:showNewMissions(data.newMissions)
		playSound(SFX.MISSION, 0.6)
	end
end)

remoteEvents.MatchEnd.OnClientEvent:Connect(function(data)
	launch:setEnabled(false)
	ui:showMatchResult(data.winner, data.scores)
end)

print("[Uncball] Client initialized")
