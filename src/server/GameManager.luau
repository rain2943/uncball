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
	self.opponent = nil -- PvP 상대 (nil이면 AI 대전)
	self.remotes = nil
	self.ai = nil
	self.onMatchEnd = nil -- 매치 종료 콜백

	-- 게임 상태
	self.scores = { player = 0, ai = 0 }
	self.remainingBalls = { player = Config.GAME.BALLS_PER_PLAYER, ai = Config.GAME.BALLS_PER_PLAYER }
	self.currentTurn = "player"
	self.activeBall = nil

	-- 슬롯 소유권: [zoneNum][slotIdx] = "player" | "ai" | nil
	self.slotOwners = {}
	for zoneNum = 1, 3 do
		self.slotOwners[zoneNum] = {}
	end

	-- 테이블에 안착된 공 파트 목록
	self.settledBalls = {}
	-- 슬롯에 안 들어간 공 (테이블 위에 남아있음, 후속타로 밀어넣기 가능)
	self.looseBalls = {} -- { {ball=Part, team=string}, ... }

	-- 미션 카드 시스템
	self.missions = {} -- { {letters={...}, bonus=N, claimedBy=nil|"player"|"ai", difficulty=1|2|3}, ... }
	self.missionLetters = { player = {}, ai = {} } -- 각 팀이 모은 레터 카운트

	return self
end

function GameManager:init(remotes)
	self.remotes = remotes

	-- AI 초기화 (테이블은 서버에서 이미 빌드됨)
	self.ai = AIPlayer.new(TableBuilder.slotPositions)

	-- 타이머 + looseBall 체크 루프
	task.spawn(function()
		while true do
			task.wait(1)
			-- 주기적으로 미안착 공 체크
			if #self.looseBalls > 0 then
				self:_checkLooseBalls()
			end
			if self.state ~= "IDLE" and self.state ~= "MATCH_END" then
				self:_broadcastState()
			end
		end
	end)
end

function GameManager:startMatch(player, opponent)
	self.player = player
	self.opponent = opponent -- nil이면 AI, Player면 PvP
	self.state = "STARTING"
	self.scores = { player = 0, ai = 0 }
	self.remainingBalls = { player = Config.GAME.BALLS_PER_PLAYER, ai = Config.GAME.BALLS_PER_PLAYER }
	-- 선턴: PvP면 랜덤, AI면 플레이어 선턴
	self.currentTurn = opponent and (math.random() < 0.5 and "player" or "ai") or "player"
	self.settledBalls = {}
	self.looseBalls = {}
	self._lastTurn = false

	for zoneNum = 1, 3 do
		self.slotOwners[zoneNum] = {}
	end
	self.missions = {}
	self.missionLetters = { player = {}, ai = {} }

	-- 미션 카드 생성
	self:_generateMissions()

	-- 플레이어 캐릭터 배치
	self:_positionPlayer(player)
	if self.opponent then
		self:_positionPlayer(self.opponent)
	end

	-- 매치 시작 알림
	local matchData = {
		ballsPerPlayer = Config.GAME.BALLS_PER_PLAYER,
		missions = self.missions,
		opponentName = self.opponent and self.opponent.DisplayName or "AI",
		opponentId = self.opponent and self.opponent.UserId or nil,
	}

	self.remotes.MatchStart:FireClient(player, matchData)
	if self.opponent then
		local oppData = {
			ballsPerPlayer = Config.GAME.BALLS_PER_PLAYER,
			missions = self.missions,
			opponentName = player.DisplayName,
			opponentId = player.UserId,
		}
		self.remotes.MatchStart:FireClient(self.opponent, oppData)
	end

	-- 선턴에 따라 시작
	if self.currentTurn == "player" then
		self:_startPlayerTurn()
	else
		self:_executeAITurn()
	end
end

function GameManager:_startPlayerTurn(isBonus: boolean?)
	self.state = "PLAYER_TURN"
	self:_fireClient("TurnChanged", self.player, true, self.remainingBalls.player, isBonus or false)
	if self.opponent then
		self:_fireClient("TurnChanged", self.opponent, false, self.remainingBalls.player, false)
	end
	self:_broadcastState()

	-- 턴 제한시간 (타임아웃 = 공 소모 + 턴 넘김)
	self.turnTimer = task.delay(Config.GAME.TURN_TIME, function()
		if self.state == "PLAYER_TURN" then
			self.remainingBalls.player -= 1
			self:_broadcastState()

			self:_fireAll("BallLanded", {
				zone = nil, slot = nil, team = "player",
				points = 0, position = nil,
				scores = self.scores, missions = self.missions, newMissions = {},
			})

			task.wait(0.5)
			self:_nextTurn()
		end
	end)
end

function GameManager:handleLaunch(player, direction: Vector3, power: number, spin: number?, spawnX: number?)
	local team = nil

	if self.state == "PLAYER_TURN" and player == self.player then
		team = "player"
	elseif self.state == "OPPONENT_TURN" and player == self.opponent then
		team = "ai" -- 상대방은 내부적으로 "ai" 팀
	else
		return
	end

	local remaining = team == "player" and self.remainingBalls.player or self.remainingBalls.ai
	if remaining <= 0 then return end

	-- 턴 타이머 취소
	if self.turnTimer then
		task.cancel(self.turnTimer)
		self.turnTimer = nil
	end

	power = math.clamp(power, Config.LAUNCH.MIN_POWER, Config.LAUNCH.MAX_POWER)
	spin = math.clamp(spin or 0, -1, 1)
	spawnX = math.clamp(spawnX or 0, -Config.LAUNCH.SPAWN_X_RANGE, Config.LAUNCH.SPAWN_X_RANGE)

	if team == "player" then
		self.remainingBalls.player -= 1
	else
		self.remainingBalls.ai -= 1
	end
	self.state = "BALL_MOVING"

	task.spawn(function()
		local ball = self:_createBall(team, spawnX)
		self:_launchBall(ball, direction, power, spin)
		self:_fireAll("BallCreated", ball)
		self:_waitForSettle(ball, team)
	end)
end

function GameManager:_executeAITurn(isBonus: boolean?)
	if self.remainingBalls.ai <= 0 then
		self:_nextTurn()
		return
	end

	-- PvP: 상대방 턴
	if self.opponent then
		self.state = "OPPONENT_TURN"
		self:_fireClient("TurnChanged", self.player, false, self.remainingBalls.ai, isBonus or false)
		self:_fireClient("TurnChanged", self.opponent, true, self.remainingBalls.ai, isBonus or false)
		self:_broadcastState()

		-- 턴 제한시간
		self.turnTimer = task.delay(Config.GAME.TURN_TIME, function()
			if self.state == "OPPONENT_TURN" then
				self.remainingBalls.ai -= 1
				self:_broadcastState()
				self:_fireAll("BallLanded", {
					zone = nil, slot = nil, team = "ai",
					points = 0, position = nil,
					scores = self.scores, missions = self.missions, newMissions = {},
				})
				task.wait(0.5)
				self:_nextTurn()
			end
		end)
		return
	end

	-- AI 대전
	self.state = "AI_TURN"
	self:_fireClient("TurnChanged", self.player, false, self.remainingBalls.ai, isBonus or false)

	task.spawn(function()
		local direction, power, spin, aiSpawnX = self.ai:decide(self.slotOwners)
		task.wait(0.8)
		self:_fireClient("TurnChanged", self.player, false, self.remainingBalls.ai)
		task.wait(1.0)

		self.remainingBalls.ai -= 1
		local ball = self:_createBall("ai", aiSpawnX)
		self:_launchBall(ball, direction, power, spin)

		self:_fireAll("BallCreated", ball)
		self:_waitForSettle(ball, "ai")
	end)
end

function GameManager:_createBall(team: string, spawnX: number?): Part
	local ball = Instance.new("Part")
	ball.Name = team == "player" and "PlayerBall" or "AIBall"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * Config.BALL.RADIUS * 2
	ball.Color = team == "player" and Config.BALL.COLORS.RED or Config.BALL.COLORS.BLUE
	ball.Material = Enum.Material.Marble
	ball.TopSurface = Enum.SurfaceType.Smooth
	ball.BottomSurface = Enum.SurfaceType.Smooth
	ball.CustomPhysicalProperties = PhysicalProperties.new(
		Config.BALL.DENSITY,
		Config.BALL.FRICTION,
		Config.BALL.ELASTICITY,
		1,
		1
	)

	-- 발사 위치 (spawnX로 좌우 위치 조정)
	local spawnY = Config.TABLE.HEIGHT + Config.TABLE.THICKNESS / 2 + Config.BALL.RADIUS + 0.2
	ball.Position = Vector3.new(spawnX or 0, spawnY, Config.LAUNCH.SPAWN_Z)

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

	-- 스핀 이펙트: 공 회전 + 나선형 트레일
	if math.abs(spin) > 0.05 then
		-- 1) 공에 직접 회전 부여 (제약 없이, 이동 방해 안 함)
		ball.AssemblyAngularVelocity = Vector3.new(0, spin * 25, 0)

		-- 2) 공 표면에 오프셋 어태치 → 회전하면서 나선형 궤적
		local r = Config.BALL.RADIUS * 0.7
		local trailAtt0 = Instance.new("Attachment")
		trailAtt0.Position = Vector3.new(r, 0, 0)
		trailAtt0.Parent = ball

		local trailAtt1 = Instance.new("Attachment")
		trailAtt1.Position = Vector3.new(-r, 0, 0)
		trailAtt1.Parent = ball

		-- 3) 트레일 (회전 + 이동 = 나선형 리본)
		local trail = Instance.new("Trail")
		trail.Attachment0 = trailAtt0
		trail.Attachment1 = trailAtt1
		trail.Lifetime = 0.5
		trail.MinLength = 0.05
		trail.LightEmission = 0.5
		trail.FaceCamera = true
		trail.WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.6),
			NumberSequenceKeypoint.new(1, 0),
		})
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.5, 0.4),
			NumberSequenceKeypoint.new(1, 1),
		})

		if spin > 0 then
			trail.Color = ColorSequence.new(Color3.fromRGB(255, 150, 40), Color3.fromRGB(255, 60, 20))
		else
			trail.Color = ColorSequence.new(Color3.fromRGB(80, 200, 255), Color3.fromRGB(30, 100, 255))
		end

		trail.Parent = ball

		-- 4) 스핀 방향 파티클 (좌/우로 튀어나감)
		local particleAtt = Instance.new("Attachment")
		particleAtt.Parent = ball

		local emitter = Instance.new("ParticleEmitter")
		emitter.Rate = 30
		emitter.Lifetime = NumberRange.new(0.3, 0.5)
		emitter.Speed = NumberRange.new(3, 5)
		emitter.SpreadAngle = Vector2.new(10, 10)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.LightEmission = 0.8

		if spin > 0 then
			emitter.Color = ColorSequence.new(Color3.fromRGB(255, 180, 60))
			particleAtt.CFrame = CFrame.lookAt(Vector3.zero, Vector3.new(1, 0.3, 0))
		else
			emitter.Color = ColorSequence.new(Color3.fromRGB(100, 200, 255))
			particleAtt.CFrame = CFrame.lookAt(Vector3.zero, Vector3.new(-1, 0.3, 0))
		end

		emitter.Parent = particleAtt

		-- 5) 6초 후 정리
		task.delay(6, function()
			if trail and trail.Parent then trail.Enabled = false end
			task.wait(0.5)
			for _, obj in ipairs({ trail, trailAtt0, trailAtt1, emitter, particleAtt }) do
				if obj and obj.Parent then obj:Destroy() end
			end
		end)
	end

	-- 스핀: 횡방향 지속 힘 (커브 궤적)
	if math.abs(spin) > 0.05 then
		local rightDir = Vector3.new(dir3.Z, 0, -dir3.X)
		local lateralForce = rightDir * spin * Config.SPIN.MAX_LATERAL_FORCE

		local spinAttachment = Instance.new("Attachment")
		spinAttachment.Parent = ball

		local spinForce = Instance.new("VectorForce")
		spinForce.Name = "SpinForce"
		spinForce.Attachment0 = spinAttachment
		spinForce.Force = lateralForce
		spinForce.RelativeTo = Enum.ActuatorRelativeTo.World
		spinForce.Parent = ball

		task.delay(6, function()
			if spinForce and spinForce.Parent then
				spinForce:Destroy()
			end
			if spinAttachment and spinAttachment.Parent then
				spinAttachment:Destroy()
			end
		end)
	end
end

function GameManager:_waitForSettle(ball: Part, team: string)
	local startTime = tick()

	while tick() - startTime < Config.GAME.BALL_SETTLE_TIMEOUT do
		task.wait(0.15)

		-- 매치 종료 시 즉시 탈출
		if self.state == "IDLE" or self.state == "MATCH_END" then return end

		if not ball or not ball.Parent then
			self:_checkLooseBalls()
			self:_onBallResult(nil, nil, team, nil)
			return
		end

		-- 테이블 아래로 떨어진 경우만 삭제
		if ball.Position.Y < Config.GAME.BALL_OUT_Y then
			ball:Destroy()
			self:_checkLooseBalls()
			self:_onBallResult(nil, nil, team, nil)
			return
		end

		local vel = ball.AssemblyLinearVelocity.Magnitude

		if vel < 0.8 then
			-- 1.2초 대기 후 재확인 (턱/포스트에 걸렸다 굴러갈 수 있음)
			task.wait(1.2)
			if not ball or not ball.Parent then
				self:_checkLooseBalls()
				self:_onBallResult(nil, nil, team, nil)
				return
			end

			-- 대기 후에도 여전히 움직이면 아직 settle 아님 → 루프 계속
			local velAfter = ball.AssemblyLinearVelocity.Magnitude
			if velAfter >= 0.5 then
				continue
			end

			-- 슬롯 안착 체크
			local zoneNum, slotIdx = self:_checkSlotLanding(ball)
			if zoneNum and self:_snapBallToSlot(ball, zoneNum, slotIdx, team) ~= false then
				self:_checkLooseBalls() -- 충돌로 밀려난 다른 공도 체크
				self:_onBallResult(zoneNum, slotIdx, team, ball)
			else
				-- 슬롯에 안 들어갔지만 삭제하지 않음! 테이블에 남겨둠
				table.insert(self.looseBalls, { ball = ball, team = team })
				self:_checkLooseBalls()
				self:_onBallResult(nil, nil, team, nil)
			end
			return
		end
	end

	-- 타임아웃: 슬롯 체크 후 남겨둠
	if ball and ball.Parent then
		local zoneNum, slotIdx = self:_checkSlotLanding(ball)
		if zoneNum and self:_snapBallToSlot(ball, zoneNum, slotIdx, team) ~= false then
			self:_checkLooseBalls()
			self:_onBallResult(zoneNum, slotIdx, team, ball)
		else
			table.insert(self.looseBalls, { ball = ball, team = team })
			self:_checkLooseBalls()
			self:_onBallResult(nil, nil, team, nil)
		end
	else
		self:_checkLooseBalls()
		self:_onBallResult(nil, nil, team, nil)
	end
end

-- 테이블 위의 미안착 공들을 체크: 충돌로 슬롯에 들어갔을 수 있음
function GameManager:_checkLooseBalls()
	local remaining = {}

	for _, entry in ipairs(self.looseBalls) do
		local ball = entry.ball
		local team = entry.team

		if not ball or not ball.Parent then
			continue -- 이미 사라진 공
		end

		-- 테이블 밖으로 떨어졌으면 삭제
		if ball.Position.Y < Config.GAME.BALL_OUT_Y then
			ball:Destroy()
			continue
		end

		-- 멈춰있고 슬롯 근처면 안착 시도
		local vel = ball.AssemblyLinearVelocity.Magnitude
		if vel < 1.0 then
			local zoneNum, slotIdx = self:_checkSlotLanding(ball)
			if zoneNum and self:_snapBallToSlot(ball, zoneNum, slotIdx, team) ~= false then
				-- 후속타로 슬롯에 들어감! 점수 재계산
				print("[Uncball] Loose ball scored! team:", team, "zone:", zoneNum, "slot:", slotIdx)
				self:_recalculateScores()
				local newMissions = self:_checkMissions(team)
				self:_broadcastState()

				-- 점수 팝업
				self:_fireAll("BallLanded", {
					zone = zoneNum,
					slot = slotIdx,
					team = team,
					points = Config.ZONES[zoneNum].BASE_POINTS,
					position = ball.Position,
					scores = self.scores,
					missions = self.missions,
					newMissions = newMissions,
					playerLetters = self:_collectLetters("player"),
				})
				continue -- 이 공은 안착됨, looseBalls에서 제거
			end
		end

		-- 아직 슬롯 밖 → 남겨둠
		table.insert(remaining, entry)
	end

	self.looseBalls = remaining
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
	-- 점수 차이 계산 (연속 보너스 + 그랜드슬램 포함)
	local scoreBefore = self.scores[team] or 0
	self:_recalculateScores()
	local scoreAfter = self.scores[team] or 0
	local pointsGained = scoreAfter - scoreBefore

	-- 미션 체크
	local newMissions = self:_checkMissions(team)
	-- 미션 보너스는 별도 팝업이므로 pointsGained에서 제외
	local missionBonus = 0
	for _, m in newMissions do
		missionBonus = missionBonus + m.bonus
	end
	pointsGained = pointsGained - missionBonus

	-- 클라이언트에 결과 알림
	local landedData = {
		zone = zoneNum,
		slot = slotIdx,
		team = team,
		points = math.max(pointsGained, 0),
		position = ball and ball.Position or nil,
		scores = self.scores,
		missions = self.missions,
		newMissions = newMissions,
		playerLetters = self:_collectLetters("player"),
	}
	self:_fireClient("BallLanded", self.player, landedData)
	if self.opponent then
		local oppLandedData = {
			zone = zoneNum,
			slot = slotIdx,
			team = team,
			points = math.max(pointsGained, 0),
			position = ball and ball.Position or nil,
			scores = self.scores,
			missions = self.missions,
			newMissions = newMissions,
			playerLetters = self:_collectLetters("ai"),
		}
		self:_fireClient("BallLanded", self.opponent, oppLandedData)
	end

	self:_broadcastState()

	task.wait(1)

	-- 슬롯 안착 성공 → 보너스 턴!
	if zoneNum and team == self.currentTurn then
		local remaining = team == "player" and self.remainingBalls.player or self.remainingBalls.ai
		if remaining > 0 then
			if team == "player" then
				self:_startPlayerTurn(true) -- 보너스 턴
			else
				self:_executeAITurn(true) -- AI 보너스 턴
			end
			return
		end
	end
	self:_nextTurn()
end

function GameManager:_nextTurn()
	-- 양쪽 다 0 → 즉시 종료
	if self.remainingBalls.player <= 0 and self.remainingBalls.ai <= 0 then
		self:_endMatch()
		return
	end

	-- 현재 턴 팀의 공이 0이면 → 상대에게 마지막 1턴 후 종료
	-- (선턴 불이익 보정: 내가 선턴이고 공 다 쓰면 상대도 1번 더 던지고 끝)
	if self.currentTurn == "player" and self.remainingBalls.player <= 0 then
		if self.remainingBalls.ai > 0 then
			self.currentTurn = "ai"
			self._lastTurn = true
			self:_executeAITurn()
		else
			self:_endMatch()
		end
		return
	elseif self.currentTurn == "ai" and self.remainingBalls.ai <= 0 then
		if self.remainingBalls.player > 0 then
			self.currentTurn = "player"
			self._lastTurn = true
			self:_startPlayerTurn()
		else
			self:_endMatch()
		end
		return
	end

	-- 이전에 마지막 턴이 주어졌으면 → 종료
	if self._lastTurn then
		self:_endMatch()
		return
	end

	-- 일반 턴 교대
	if self.currentTurn == "player" then
		self.currentTurn = "ai"
		self:_executeAITurn()
	else
		self.currentTurn = "player"
		self:_startPlayerTurn()
	end
end

-- 미션 카드 생성 (매치 시작 시 호출)
function GameManager:_generateMissions()
	local missions = Config.MISSIONS
	self.missions = {}

	-- 각 풀에서 랜덤 1개씩 선택
	local easyIdx = math.random(1, #missions.EASY_POOL)
	local medIdx = math.random(1, #missions.MEDIUM_POOL)
	local hardIdx = math.random(1, #missions.HARD_POOL)

	table.insert(self.missions, {
		letters = missions.EASY_POOL[easyIdx],
		bonus = missions.EASY_BONUS,
		difficulty = 1,
		claimedBy = nil,
	})
	table.insert(self.missions, {
		letters = missions.MEDIUM_POOL[medIdx],
		bonus = missions.MEDIUM_BONUS,
		difficulty = 2,
		claimedBy = nil,
	})
	table.insert(self.missions, {
		letters = missions.HARD_POOL[hardIdx],
		bonus = missions.HARD_BONUS,
		difficulty = 3,
		claimedBy = nil,
	})

	print("[Uncball] Missions generated:", #self.missions)
end

-- 팀의 보유 레터 수집
function GameManager:_collectLetters(team: string): { [string]: number }
	local letters = {}
	for zoneNum = 1, 3 do
		local zoneConfig = Config.ZONES[zoneNum]
		for i = 1, zoneConfig.SLOTS do
			if self.slotOwners[zoneNum][i] == team then
				local letter = zoneConfig.LABELS[i]
				letters[letter] = (letters[letter] or 0) + 1
			end
		end
	end
	return letters
end

-- 미션 달성 체크 (공 안착 후 호출, 새로 달성한 미션 배열 반환)
function GameManager:_checkMissions(team: string): { { idx: number, letters: { string }, bonus: number, difficulty: number } }
	local teamLetters = self:_collectLetters(team)
	local newMissions = {}

	for idx, mission in self.missions do
		if mission.claimedBy then continue end -- 이미 선점됨

		-- 미션에 필요한 레터 카운트
		local required = {}
		for _, letter in mission.letters do
			required[letter] = (required[letter] or 0) + 1
		end

		-- 보유 레터로 충족 가능한지 체크
		local satisfied = true
		for letter, count in required do
			if (teamLetters[letter] or 0) < count then
				satisfied = false
				break
			end
		end

		if satisfied then
			mission.claimedBy = team
			table.insert(newMissions, {
				idx = idx,
				letters = mission.letters,
				bonus = mission.bonus,
				difficulty = mission.difficulty,
			})
			print("[Uncball] Mission claimed! idx:", idx, "team:", team, "bonus:", mission.bonus)
		end
	end

	-- 미션 보너스를 점수에 반영
	if #newMissions > 0 then
		self:_recalculateScores()
	end

	return newMissions
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

		-- 미션 보너스 계산
		for _, mission in self.missions do
			if mission.claimedBy == team then
				total = total + mission.bonus
			end
		end

		self.scores[team] = total
	end
	print("[Uncball] Scores recalculated:", "player:", self.scores.player, "ai:", self.scores.ai)
end

function GameManager:_endMatch()
	self.state = "MATCH_END"
	self:_broadcastState()

	local winner
	if self.scores.player > self.scores.ai then
		winner = "player"
	elseif self.scores.ai > self.scores.player then
		winner = "ai"
	else
		winner = "draw"
	end

	self:_fireAll("MatchEnd", {
		winner = winner,
		scores = self.scores,
	})

	-- 5초 후 정리 (클라이언트에서 로비로 복귀)
	task.delay(5, function()
		self:_cleanupBalls()
		self.state = "IDLE"
		if self.onMatchEnd then
			self.onMatchEnd()
		end
	end)
end

function GameManager:forceEndMatch()
	if self.state == "IDLE" or self.state == "MATCH_END" then return end

	-- 턴 타이머 취소
	if self.turnTimer then
		task.cancel(self.turnTimer)
		self.turnTimer = nil
	end

	self.state = "MATCH_END"
	self:_cleanupBalls()
	self.state = "IDLE"

	if self.onMatchEnd then
		self.onMatchEnd()
	end
end

function GameManager:_cleanupBalls()
	-- 안착된 공 제거
	for _, ball in self.settledBalls do
		if ball and ball.Parent then
			ball:Destroy()
		end
	end
	self.settledBalls = {}

	-- 미안착 공 제거
	for _, entry in self.looseBalls do
		if entry.ball and entry.ball.Parent then
			entry.ball:Destroy()
		end
	end
	self.looseBalls = {}

	-- workspace에 남은 공 정리
	for _, child in workspace:GetChildren() do
		if child:IsA("Part") and child.Shape == Enum.PartType.Ball
			and (child.Name == "PlayerBall" or child.Name == "AIBall") then
			child:Destroy()
		end
	end
end

-- 양쪽 클라이언트에 이벤트 발신 헬퍼
function GameManager:_fireClient(remoteName, player, ...)
	if player and player.Parent then
		self.remotes[remoteName]:FireClient(player, ...)
	end
end

function GameManager:_fireAll(remoteName, ...)
	self:_fireClient(remoteName, self.player, ...)
	if self.opponent then
		self:_fireClient(remoteName, self.opponent, ...)
	end
end

function GameManager:_broadcastState()
	if not self.player then return end

	local data = {
		scores = self.scores,
		remainingBalls = self.remainingBalls,
		currentTurn = self.currentTurn,
		state = self.state,
		missions = self.missions,
		playerLetters = self:_collectLetters("player"),
	}

	self:_fireClient("GameStateUpdate", self.player, data)
	if self.opponent then
		-- 상대에게도 같은 데이터 (상대의 레터 진행도 포함)
		local oppData = {
			scores = self.scores,
			remainingBalls = self.remainingBalls,
			currentTurn = self.currentTurn,
			state = self.state,
			missions = self.missions,
			playerLetters = self:_collectLetters("ai"),
		}
		self:_fireClient("GameStateUpdate", self.opponent, oppData)
	end
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
