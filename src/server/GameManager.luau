local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local TableBuilder = require(script.Parent:WaitForChild("TableBuilder"))
local AIPlayer = require(script.Parent:WaitForChild("AIPlayer"))

local GameManager = {}
GameManager.__index = GameManager

--[[
	States: IDLE → STARTING → PLAYER_TURN → BALL_MOVING → AI_TURN → BALL_MOVING → ... → MATCH_END
]]

function GameManager.new()
	local self = setmetatable({}, GameManager)
	self.state = "IDLE"
	self.player = nil
	self.remotes = nil
	self.ai = nil

	-- 게임 상태
	self.scores = { player = 0, ai = 0 }
	self.remainingBalls = { player = Config.GAME.BALLS_PER_PLAYER, ai = Config.GAME.BALLS_PER_PLAYER }
	self.currentTurn = "player"
	self.matchTimer = Config.GAME.MATCH_TIME
	self.activeBall = nil

	-- 슬롯 소유권: [zoneNum][slotIdx] = "player" | "ai" | nil
	self.slotOwners = {}
	for zoneNum = 1, 3 do
		self.slotOwners[zoneNum] = {}
	end

	-- 테이블에 안착된 공 파트 목록
	self.settledBalls = {}

	return self
end

function GameManager:init(remotes)
	self.remotes = remotes

	-- 테이블 빌드
	TableBuilder.build()

	-- AI 초기화
	self.ai = AIPlayer.new(TableBuilder.slotPositions)

	-- 타이머 루프
	task.spawn(function()
		while true do
			task.wait(1)
			if self.state ~= "IDLE" and self.state ~= "MATCH_END" then
				self.matchTimer = self.matchTimer - 1
				if self.matchTimer <= 0 then
					self:_endMatch()
				end
				self:_broadcastState()
			end
		end
	end)
end

function GameManager:startMatch(player)
	self.player = player
	self.state = "STARTING"
	self.scores = { player = 0, ai = 0 }
	self.remainingBalls = { player = Config.GAME.BALLS_PER_PLAYER, ai = Config.GAME.BALLS_PER_PLAYER }
	self.matchTimer = Config.GAME.MATCH_TIME
	self.currentTurn = "player"
	self.settledBalls = {}

	for zoneNum = 1, 3 do
		self.slotOwners[zoneNum] = {}
	end

	-- 플레이어 캐릭터를 테이블 끝에 배치
	self:_positionPlayer(player)

	-- 매치 시작 알림
	self.remotes.MatchStart:FireClient(player, {
		ballsPerPlayer = Config.GAME.BALLS_PER_PLAYER,
		matchTime = Config.GAME.MATCH_TIME,
	})

	self.state = "PLAYER_TURN"
	self.remotes.TurnChanged:FireClient(player, true, self.remainingBalls.player)
	self:_broadcastState()
end

function GameManager:handleLaunch(player, direction: Vector3, power: number, spin: number?)
	if self.state ~= "PLAYER_TURN" or player ~= self.player then
		return
	end
	if self.remainingBalls.player <= 0 then
		return
	end

	power = math.clamp(power, Config.LAUNCH.MIN_POWER, Config.LAUNCH.MAX_POWER)
	spin = math.clamp(spin or 0, -1, 1)

	self.remainingBalls.player -= 1
	self.state = "BALL_MOVING"

	-- task.spawn으로 감싸서 yield(task.wait) 문제 방지
	task.spawn(function()
		local ball = self:_createBall("player")
		self:_launchBall(ball, direction, power, spin)
		self.remotes.BallCreated:FireClient(player, ball)
		self:_waitForSettle(ball, "player")
	end)
end

function GameManager:_executeAITurn()
	if self.remainingBalls.ai <= 0 then
		self:_nextTurn()
		return
	end

	self.state = "AI_TURN"
	self.remotes.TurnChanged:FireClient(self.player, false, self.remainingBalls.ai)

	task.spawn(function()
		-- AI 생각 시간
		local thinkTime = self.ai:getThinkTime()
		task.wait(thinkTime)

		-- AI 결정
		local direction, power, spin = self.ai:decide(self.slotOwners)
		self.remainingBalls.ai -= 1

		local ball = self:_createBall("ai")
		self:_launchBall(ball, direction, power, spin)

		self.remotes.BallCreated:FireClient(self.player, ball)

		self:_waitForSettle(ball, "ai")
	end)
end

function GameManager:_createBall(team: string): Part
	local ball = Instance.new("Part")
	ball.Name = team == "player" and "PlayerBall" or "AIBall"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * Config.BALL.RADIUS * 2
	ball.Color = team == "player" and Config.BALL.COLORS.RED or Config.BALL.COLORS.BLUE
	ball.Material = Enum.Material.SmoothPlastic
	ball.TopSurface = Enum.SurfaceType.Smooth
	ball.BottomSurface = Enum.SurfaceType.Smooth
	ball.CustomPhysicalProperties = PhysicalProperties.new(
		Config.BALL.DENSITY,
		Config.BALL.FRICTION,
		Config.BALL.ELASTICITY,
		1,
		1
	)

	-- 발사 위치
	local spawnY = Config.TABLE.HEIGHT + Config.TABLE.THICKNESS / 2 + Config.BALL.RADIUS + 0.2
	ball.Position = Vector3.new(0, spawnY, Config.LAUNCH.SPAWN_Z)

	-- 먼저 workspace에 넣기 (물리 활성화)
	ball.Parent = workspace

	-- 1프레임 대기 후 물리 적용 (mass 계산 보장)
	task.wait()

	-- 경사 시뮬레이션
	local attachment = Instance.new("Attachment")
	attachment.Parent = ball

	local mass = ball.AssemblyMass
	if mass <= 0 then mass = 2 end -- 안전 폴백

	local pullForce = Instance.new("VectorForce")
	pullForce.Name = "InclineForce"
	pullForce.Attachment0 = attachment
	pullForce.Force = Vector3.new(0, 0, -Config.INCLINE_FORCE * mass)
	pullForce.RelativeTo = Enum.ActuatorRelativeTo.World
	pullForce.Parent = ball

	print("[Uncball] Ball created:", team, "mass:", mass, "pos:", ball.Position)
	return ball
end

function GameManager:_launchBall(ball: Part, direction: Vector3, power: number, spin: number?)
	spin = spin or 0
	local dir3 = Vector3.new(direction.X, 0, math.abs(direction.Z)).Unit
	local velocity = dir3 * power + Vector3.new(0, 3, 0)

	local mass = ball.AssemblyMass
	if mass <= 0 then mass = 2 end

	-- 메인 임펄스
	ball:ApplyImpulse(velocity * mass)

	-- 스핀: 횡방향 힘 (시간에 따라 커브)
	if math.abs(spin) > 0.05 then
		local rightDir = Vector3.new(dir3.Z, 0, -dir3.X) -- 직교 방향
		local lateralForce = rightDir * spin * Config.SPIN.MAX_LATERAL_FORCE

		local attachment = ball:FindFirstChildWhichIsA("Attachment")
		if attachment then
			local spinForce = Instance.new("VectorForce")
			spinForce.Name = "SpinForce"
			spinForce.Attachment0 = attachment
			spinForce.Force = lateralForce
			spinForce.RelativeTo = Enum.ActuatorRelativeTo.World
			spinForce.Parent = ball

			-- 3초 후 스핀 힘 제거
			task.delay(3, function()
				if spinForce and spinForce.Parent then
					spinForce:Destroy()
				end
			end)
		end
	end
end

function GameManager:_waitForSettle(ball: Part, team: string)
	local startTime = tick()
	print("[Uncball] _waitForSettle start, team:", team)

	while tick() - startTime < Config.GAME.BALL_SETTLE_TIMEOUT do
		task.wait(0.15)

		if not ball or not ball.Parent then
			print("[Uncball] Ball gone (destroyed/fell)")
			self:_onBallResult(nil, nil, team, nil)
			return
		end

		if ball.Position.Y < Config.GAME.BALL_OUT_Y then
			print("[Uncball] Ball fell off table")
			ball:Destroy()
			self:_onBallResult(nil, nil, team, nil)
			return
		end

		local vel = ball.AssemblyLinearVelocity.Magnitude

		-- 공이 거의 멈추면 (vel < 0.6) 잠시 더 기다린 후 최종 판정
		if vel < 0.6 then
			-- 완전 정지 대기 (0.8초)
			task.wait(0.8)
			if not ball or not ball.Parent then
				self:_onBallResult(nil, nil, team, nil)
				return
			end

			local finalVel = ball.AssemblyLinearVelocity.Magnitude
			local zoneNum, slotIdx = self:_checkSlotLanding(ball)
			print("[Uncball] Final settle - vel:", string.format("%.2f", finalVel), "zone:", tostring(zoneNum), "slot:", tostring(slotIdx), "pos:", ball.Position)

			if zoneNum and self:_snapBallToSlot(ball, zoneNum, slotIdx, team) ~= false then
				self:_onBallResult(zoneNum, slotIdx, team, ball)
			else
				-- 재시도
				task.wait(1)
				if ball and ball.Parent then
					zoneNum, slotIdx = self:_checkSlotLanding(ball)
					if zoneNum and self:_snapBallToSlot(ball, zoneNum, slotIdx, team) ~= false then
						self:_onBallResult(zoneNum, slotIdx, team, ball)
					else
						ball:Destroy()
						self:_onBallResult(nil, nil, team, nil)
					end
				else
					self:_onBallResult(nil, nil, team, nil)
				end
			end
			return
		end
	end

	-- 타임아웃
	print("[Uncball] Settle TIMEOUT")
	if ball and ball.Parent then
		local zoneNum, slotIdx = self:_checkSlotLanding(ball)
		if zoneNum and self:_snapBallToSlot(ball, zoneNum, slotIdx, team) ~= false then
			self:_onBallResult(zoneNum, slotIdx, team, ball)
		else
			ball:Destroy()
			self:_onBallResult(nil, nil, team, nil)
		end
	else
		self:_onBallResult(nil, nil, team, nil)
	end
end

function GameManager:_checkSlotLanding(ball: Part): (number?, number?)
	local ballPos = ball.Position
	local bestDist = Config.SLOT.DETECT_RADIUS
	local bestZone, bestSlot = nil, nil

	for zoneNum = 1, 3 do
		for slotIdx, slotPos in TableBuilder.slotPositions[zoneNum] do
			-- 이미 점유된 슬롯은 건너뛰기
			if self.slotOwners[zoneNum][slotIdx] then
				continue
			end

			local dist = (Vector3.new(ballPos.X, 0, ballPos.Z) - Vector3.new(slotPos.X, 0, slotPos.Z)).Magnitude
			if dist < bestDist then
				bestDist = dist
				bestZone = zoneNum
				bestSlot = slotIdx
			end
		end
	end

	return bestZone, bestSlot
end

function GameManager:_snapBallToSlot(ball: Part, zoneNum: number, slotIdx: number, team: string)
	-- 이미 점유된 슬롯이면 진입 불가 (false 반환)
	if self.slotOwners[zoneNum][slotIdx] then
		print("[Uncball] Slot already occupied! zone:", zoneNum, "slot:", slotIdx)
		return false
	end

	-- 슬롯 소유권 설정
	self.slotOwners[zoneNum][slotIdx] = team
	print("[Uncball] Slot claimed! zone:", zoneNum, "slot:", slotIdx, "team:", team)

	-- 물리적으로 멈춘 위치 그대로 고정 (스냅 없음 = 자연스러운 위치)
	ball.AssemblyLinearVelocity = Vector3.zero
	ball.AssemblyAngularVelocity = Vector3.zero
	ball.Anchored = true
	ball.CanCollide = true

	-- 힘 제거
	for _, child in ball:GetChildren() do
		if child:IsA("VectorForce") or child:IsA("Attachment") then
			child:Destroy()
		end
	end

	local key = zoneNum .. "_" .. slotIdx
	self.settledBalls[key] = ball
end

function GameManager:_onBallResult(zoneNum, slotIdx, team, ball)
	-- 점수 재계산
	self:_recalculateScores()

	-- 클라이언트에 결과 알림
	if self.player then
		local points = 0
		if zoneNum then
			points = Config.ZONES[zoneNum].BASE_POINTS
		end
		self.remotes.BallLanded:FireClient(self.player, {
			zone = zoneNum,
			slot = slotIdx,
			team = team,
			points = points,
			position = ball and ball.Position or nil,
			scores = self.scores,
		})
	end

	self:_broadcastState()

	-- 다음 턴
	task.wait(1)
	self:_nextTurn()
end

function GameManager:_nextTurn()
	-- 매치 종료 조건
	if self.remainingBalls.player <= 0 and self.remainingBalls.ai <= 0 then
		self:_endMatch()
		return
	end

	-- 턴 교대
	if self.currentTurn == "player" then
		self.currentTurn = "ai"
		if self.remainingBalls.ai > 0 then
			self:_executeAITurn()
		else
			self.currentTurn = "player"
			self.state = "PLAYER_TURN"
			self.remotes.TurnChanged:FireClient(self.player, true, self.remainingBalls.player)
		end
	else
		self.currentTurn = "player"
		if self.remainingBalls.player > 0 then
			self.state = "PLAYER_TURN"
			self.remotes.TurnChanged:FireClient(self.player, true, self.remainingBalls.player)
		else
			self.currentTurn = "ai"
			if self.remainingBalls.ai > 0 then
				self:_executeAITurn()
			else
				self:_endMatch()
			end
		end
	end
end

function GameManager:_recalculateScores()
	self.scores.player = 0
	self.scores.ai = 0

	for _, team in ipairs({ "player", "ai" }) do
		local total = 0
		for zoneNum = 1, 3 do
			local zoneConfig = Config.ZONES[zoneNum]
			local slots = self.slotOwners[zoneNum]

			-- 기본 점수
			local consecutive = 0
			local allMine = true

			for i = 1, zoneConfig.SLOTS do
				if slots[i] == team then
					total = total + zoneConfig.BASE_POINTS
					consecutive = consecutive + 1
				else
					-- 연속 보너스 정산
					if consecutive >= 2 then
						total = total + (Config.GAME.CONSECUTIVE_BONUS[consecutive] or 0)
					end
					consecutive = 0
					allMine = false
				end
			end

			-- 마지막 연속 그룹 정산
			if consecutive >= 2 then
				total = total + (Config.GAME.CONSECUTIVE_BONUS[consecutive] or 0)
			end

			-- 그랜드 슬램 체크
			if allMine and slots[1] == team then
				total = total + zoneConfig.GRAND_SLAM_BONUS
			end
		end

		self.scores[team] = total
	end
	print("[Uncball] Scores recalculated:", "player:", self.scores.player, "ai:", self.scores.ai)
end

function GameManager:_endMatch()
	self.state = "MATCH_END"

	local winner
	if self.scores.player > self.scores.ai then
		winner = "player"
	elseif self.scores.ai > self.scores.player then
		winner = "ai"
	else
		winner = "draw"
	end

	if self.player then
		self.remotes.MatchEnd:FireClient(self.player, {
			winner = winner,
			scores = self.scores,
		})
	end
end

function GameManager:_broadcastState()
	if not self.player then
		return
	end

	self.remotes.GameStateUpdate:FireClient(self.player, {
		scores = self.scores,
		remainingBalls = self.remainingBalls,
		currentTurn = self.currentTurn,
		timer = self.matchTimer,
		state = self.state,
	})
end

function GameManager:_positionPlayer(player)
	local char = player.Character or player.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart")
	local humanoid = char:WaitForChild("Humanoid")

	-- 이동 비활성화 (먼저!)
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0

	-- 테이블 옆 안전한 높이에 배치 (void kill 방지)
	hrp.Anchored = true
	hrp.CFrame = CFrame.new(0, Config.TABLE.HEIGHT + 10, Config.LAUNCH.SPAWN_Z - 5)

	-- 캐릭터 투명 + 충돌 제거
	local function hideDescendants()
		for _, obj in char:GetDescendants() do
			if obj:IsA("BasePart") then
				obj.Transparency = 1
				obj.CanCollide = false
				obj.CanQuery = false
				obj.CanTouch = false
			elseif obj:IsA("Decal") or obj:IsA("Texture") then
				obj.Transparency = 1
			elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
				obj.Enabled = false
			end
		end
	end

	hideDescendants()
	-- 이후 추가되는 파트도 숨기기 (액세서리 등 늦게 로드)
	char.DescendantAdded:Connect(function(obj)
		task.defer(function()
			if obj:IsA("BasePart") then
				obj.Transparency = 1
				obj.CanCollide = false
				obj.CanQuery = false
				obj.CanTouch = false
			elseif obj:IsA("Decal") or obj:IsA("Texture") then
				obj.Transparency = 1
			elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
				obj.Enabled = false
			end
		end)
	end)
end

return GameManager
