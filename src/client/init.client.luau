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

-- === 이벤트 핸들러 ===

remoteEvents.MatchStart.OnClientEvent:Connect(function(data)
	ui:updateRemainingBalls(data.ballsPerPlayer, data.ballsPerPlayer)
	ui:updateTimer(data.matchTime)
end)

remoteEvents.TurnChanged.OnClientEvent:Connect(function(isPlayerTurn, _remainingBalls)
	ui:setTurn(isPlayerTurn)
	launch:setEnabled(isPlayerTurn)
end)

remoteEvents.GameStateUpdate.OnClientEvent:Connect(function(data)
	ui:updateScores(data.scores.player, data.scores.ai)
	ui:updateTimer(data.timer)
	ui:updateRemainingBalls(data.remainingBalls.player, data.remainingBalls.ai)
end)

-- BallCreated 이벤트 (백업)
remoteEvents.BallCreated.OnClientEvent:Connect(function(ball)
	if ball and ball.Parent then
		camera:trackBall(ball)
	end
end)

-- workspace에 공이 추가되면 직접 감지 (이벤트 실패 대비)
workspace.ChildAdded:Connect(function(child)
	if child:IsA("Part") and child.Shape == Enum.PartType.Ball
		and (child.Name == "PlayerBall" or child.Name == "AIBall") then
		task.wait(0.1) -- 물리 안정화
		camera:trackBall(child)
	end
end)

remoteEvents.BallLanded.OnClientEvent:Connect(function(data)
	if data.zone and data.points > 0 then
		ui:showScorePopup(data.position, data.points, data.team)
	end
end)

remoteEvents.MatchEnd.OnClientEvent:Connect(function(data)
	launch:setEnabled(false)
	ui:showMatchResult(data.winner, data.scores)
end)

print("[Uncball] Client initialized")
