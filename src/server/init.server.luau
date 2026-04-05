local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GameManager = require(script:WaitForChild("GameManager"))
local TableBuilder = require(script:WaitForChild("TableBuilder"))

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

-- 테이블 빌드 (1회)
TableBuilder.build()

-- === 매칭 시스템 ===
local matchQueue = {} -- { player1, player2, ... }
local playerGMs = {} -- player → GameManager (현재 진행 중인 매치)
local matchTimers = {} -- player → AI 타임아웃 thread
local pendingMatch = nil -- { player1, player2, timer, countdown }

-- 큐에서 플레이어 제거
local function removeFromQueue(player)
	for i, p in matchQueue do
		if p == player then
			table.remove(matchQueue, i)
			return true
		end
	end
	return false
end

-- 큐에 있는지 확인
local function isInQueue(player)
	for _, p in matchQueue do
		if p == player then return true end
	end
	return false
end

-- PvP 매치 시작
local function startPvPMatch(player1, player2)
	print("[Uncball] Starting PvP match:", player1.Name, "vs", player2.Name)

	-- 기존 AI 매치 강제 종료
	if playerGMs[player1] then
		playerGMs[player1]:forceEndMatch()
		playerGMs[player1] = nil
	end
	if playerGMs[player2] then
		playerGMs[player2]:forceEndMatch()
		playerGMs[player2] = nil
	end

	-- 새 PvP 매치
	local gm = GameManager.new()
	gm:init(remoteEvents)
	gm.onMatchEnd = function()
		playerGMs[player1] = nil
		playerGMs[player2] = nil
	end
	gm:startMatch(player1, player2)
	playerGMs[player1] = gm
	playerGMs[player2] = gm
end

-- 매칭 발견 → 5초 카운트다운 시작
local function startMatchCountdown(player1, player2)
	if pendingMatch then return end -- 이미 진행 중

	print("[Uncball] Match found:", player1.Name, "↔", player2.Name)

	-- 양쪽 AI 타이머 취소
	if matchTimers[player1] then task.cancel(matchTimers[player1]); matchTimers[player1] = nil end
	if matchTimers[player2] then task.cancel(matchTimers[player2]); matchTimers[player2] = nil end

	pendingMatch = { player1 = player1, player2 = player2 }

	-- 양쪽에 알림
	remoteEvents.MatchFound:FireClient(player1, {
		opponentName = player2.DisplayName,
		countdown = 5,
	})
	remoteEvents.MatchFound:FireClient(player2, {
		opponentName = player1.DisplayName,
		countdown = 5,
	})

	-- 5초 카운트다운
	pendingMatch.timer = task.delay(5, function()
		if not pendingMatch then return end
		local p1 = pendingMatch.player1
		local p2 = pendingMatch.player2
		pendingMatch = nil

		if p1.Parent and p2.Parent then
			startPvPMatch(p1, p2)
		end
	end)
end

-- 매칭 취소
local function cancelPendingMatch(cancelledBy)
	if not pendingMatch then return end

	local p1 = pendingMatch.player1
	local p2 = pendingMatch.player2

	-- 타이머 취소
	if pendingMatch.timer then
		task.cancel(pendingMatch.timer)
	end
	pendingMatch = nil

	-- 상대에게 취소 알림
	local other = (cancelledBy == p1) and p2 or p1
	if other and other.Parent then
		remoteEvents.MatchCancelled:FireClient(other, {})
		-- 상대는 다시 큐에 등록 (AI 타임아웃 재시작)
		if not isInQueue(other) then
			table.insert(matchQueue, other)
		end
		-- 기존 타이머 취소 후 재설정
		if matchTimers[other] then task.cancel(matchTimers[other]) end
		matchTimers[other] = task.delay(Config.LOBBY.MATCH_TIMEOUT, function()
			removeFromQueue(other)
			matchTimers[other] = nil
			if other.Parent and not playerGMs[other] then
				local gm = GameManager.new()
				gm:init(remoteEvents)
				gm.onMatchEnd = function()
					playerGMs[other] = nil
				end
				gm:startMatch(other)
				playerGMs[other] = gm
			end
		end)
	end

	-- 취소한 쪽: 큐에서 제거 (AI 게임 끝나면 로비로)
	removeFromQueue(cancelledBy)
	if matchTimers[cancelledBy] then
		task.cancel(matchTimers[cancelledBy])
		matchTimers[cancelledBy] = nil
	end
	-- 취소한 쪽에도 알림
	if cancelledBy and cancelledBy.Parent then
		remoteEvents.MatchCancelled:FireClient(cancelledBy, {})
	end
end

-- === 이벤트 핸들러 ===

-- 프리뷰 위치 릴레이 (PvP: 상대에게 공 위치 전달)
remoteEvents.PreviewUpdate.OnServerEvent:Connect(function(player, spawnX)
	if typeof(spawnX) ~= "number" then return end
	local gm = playerGMs[player]
	if not gm then return end
	-- 상대에게 전달
	local target = nil
	if gm.player == player and gm.opponent then
		target = gm.opponent
	elseif gm.opponent == player then
		target = gm.player
	end
	if target and target.Parent then
		remoteEvents.PreviewUpdate:FireClient(target, spawnX)
	end
end)

-- 발사 요청 → 해당 플레이어의 GM에 전달
remoteEvents.RequestLaunch.OnServerEvent:Connect(function(player, direction, power, spin, spawnX)
	local gm = playerGMs[player]
	if not gm then return end
	if typeof(direction) ~= "Vector3" then return end
	if typeof(power) ~= "number" then return end
	if spin ~= nil and typeof(spin) ~= "number" then spin = 0 end
	if spawnX ~= nil and typeof(spawnX) ~= "number" then spawnX = 0 end
	gm:handleLaunch(player, direction, power, spin, spawnX)
end)

-- 매칭 요청
remoteEvents.RequestMatch.OnServerEvent:Connect(function(player)
	-- 이미 큐에 있거나 pendingMatch 중이면 무시
	if isInQueue(player) then return end
	if pendingMatch and (pendingMatch.player1 == player or pendingMatch.player2 == player) then return end

	print("[Uncball] Player queued:", player.Name)
	table.insert(matchQueue, player)

	-- 큐에 다른 사람이 있는지 확인
	local matchedWith = nil
	for _, p in matchQueue do
		if p ~= player and p.Parent then
			matchedWith = p
			break
		end
	end

	if matchedWith then
		-- 매칭 성공! 큐에서 둘 다 제거
		removeFromQueue(player)
		removeFromQueue(matchedWith)
		-- AI 타임아웃 취소
		if matchTimers[player] then task.cancel(matchTimers[player]); matchTimers[player] = nil end
		if matchTimers[matchedWith] then task.cancel(matchTimers[matchedWith]); matchTimers[matchedWith] = nil end
		-- 카운트다운 시작
		startMatchCountdown(matchedWith, player)
	else
		-- 매칭 안 됨 → 10초 후 AI (큐에는 남아있음)
		matchTimers[player] = task.delay(Config.LOBBY.MATCH_TIMEOUT, function()
			matchTimers[player] = nil
			-- 아직 큐에 있으면 AI 매치 시작 (큐에는 유지!)
			if isInQueue(player) and player.Parent and not playerGMs[player] then
				print("[Uncball] AI match for", player.Name, "(still in queue)")
				local gm = GameManager.new()
				gm:init(remoteEvents)
				gm.onMatchEnd = function()
					playerGMs[player] = nil
					-- 매치 끝나면 큐에서도 제거
					removeFromQueue(player)
				end
				gm:startMatch(player)
				playerGMs[player] = gm
			end
		end)
	end
end)

-- 매칭 취소
remoteEvents.CancelMatchmaking.OnServerEvent:Connect(function(player)
	if pendingMatch and (pendingMatch.player1 == player or pendingMatch.player2 == player) then
		cancelPendingMatch(player)
	end
end)

-- 플레이어 퇴장
Players.PlayerRemoving:Connect(function(player)
	-- 큐 제거
	removeFromQueue(player)
	if matchTimers[player] then
		task.cancel(matchTimers[player])
		matchTimers[player] = nil
	end

	-- 진행 중 매치 정리
	local gm = playerGMs[player]
	if gm then
		-- PvP 매치에서 상대가 나가면 → 남은 플레이어 승리 처리
		local remaining = nil
		if gm.opponent == player then
			remaining = gm.player
		elseif gm.player == player then
			remaining = gm.opponent
		end

		if remaining and remaining.Parent then
			-- 남은 플레이어에게 승리 알림
			remoteEvents.MatchEnd:FireClient(remaining, {
				winner = "player",
				scores = gm.scores,
				disconnected = true,
			})
		end

		gm:forceEndMatch()
		playerGMs[player] = nil
		if remaining then
			playerGMs[remaining] = nil
		end
	end

	-- 대기 중 매치 취소
	if pendingMatch and (pendingMatch.player1 == player or pendingMatch.player2 == player) then
		cancelPendingMatch(player)
	end
end)

-- 새 플레이어 접속 시 캐릭터를 경기장 밖에 숨기기
local function hidePlayerCharacter(player)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.Anchored = true
		hrp.CFrame = CFrame.new(0, 500, 0) -- 경기장 한참 위
	end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	end
	for _, obj in char:GetDescendants() do
		if obj:IsA("BasePart") then
			obj.Transparency = 1
			obj.CanCollide = false
			obj.CanQuery = false
			obj.CanTouch = false
		elseif obj:IsA("Decal") or obj:IsA("Texture") then
			obj.Transparency = 1
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		-- 캐릭터 로드 후 즉시 숨기기
		task.wait(0.1)
		if not playerGMs[player] then
			hidePlayerCharacter(player)
		end
	end)
	-- 이미 캐릭터가 있으면 바로 숨기기
	if player.Character then
		hidePlayerCharacter(player)
	end
end)

-- 이미 접속한 플레이어 처리 (Studio)
for _, player in Players:GetPlayers() do
	if player.Character then
		hidePlayerCharacter(player)
	end
	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		if not playerGMs[player] then
			hidePlayerCharacter(player)
		end
	end)
end

print("[Uncball] Server initialized - lobby mode")
