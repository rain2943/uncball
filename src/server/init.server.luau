local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GameManager = require(script:WaitForChild("GameManager"))

-- RemoteEvent 생성
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local remoteEvents = {}
for _, name in Config.REMOTES do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	remoteEvents[name] = remote
end

-- GameManager 초기화
local gm = GameManager.new()
gm:init(remoteEvents)

-- 발사 요청 처리
remoteEvents.RequestLaunch.OnServerEvent:Connect(function(player, direction, power, spin, spawnX)
	if typeof(direction) ~= "Vector3" then return end
	if typeof(power) ~= "number" then return end
	if spin ~= nil and typeof(spin) ~= "number" then spin = 0 end
	if spawnX ~= nil and typeof(spawnX) ~= "number" then spawnX = 0 end
	gm:handleLaunch(player, direction, power, spin, spawnX)
end)

-- 플레이어 입장 시 매치 시작
Players.PlayerAdded:Connect(function(player)
	-- 캐릭터 로드 대기
	player.CharacterAdded:Wait()
	task.wait(1)

	print("[Uncball] Starting match for " .. player.Name .. " vs AI")
	gm:startMatch(player)
end)

-- 이미 접속한 플레이어 처리 (Studio 테스트용)
for _, player in Players:GetPlayers() do
	task.spawn(function()
		if not player.Character then
			player.CharacterAdded:Wait()
		end
		task.wait(1)
		print("[Uncball] Starting match for " .. player.Name .. " vs AI")
		gm:startMatch(player)
	end)
end

print("[Uncball] Server initialized")
