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
	-- 슬롯에 안 들어간 공 (테이블 위에 남아있음, 후속타로 밀어넣기 가능)
	self.looseBalls = {} -- { {ball=Part, team=string}, ... }

	-- 미션 카드 시스템
	self.missions = {} -- { {letters={...}, bonus=N, claimedBy=nil|"player"|"ai", difficulty=1|2|3}, ... }
	self.missionLetters = { player = {}, ai = {} } -- 각 팀이 모은 레터 카운트

	return self
end

function GameManager:init(remotes)
	self.remotes = remotes

	-- 테이블 빌드
	TableBuilder.build()

	-- AI 초기화
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
	self.looseBalls = {}

	for zoneNum = 1, 3 do
		self.slotOwners[zoneNum] = {}
	end
	self.missions = {}
	self.missionLetters = { player = {}, ai = {} }

	-- 미션 카드 생성
	self:_generateMissions()

	-- 플레이어 캐릭터를 테이블 끝에 배치
	self:_positionPlayer(player)

	-- 매치 시작 알림
	self.remotes.MatchStart:FireClient(player, {
		ballsPerPlayer = Config.GAME.BALLS_PER_PLAYER,
		matchTime = Config.GAME.MATCH_TIME,
		missions = self.missions,
	})

	self:_startPlayerTurn()
end

function GameManager:_startPlayerTurn()
	self.state = "PLAYER_TURN"
	self.remotes.TurnChanged:FireClient(self.player, true, self.remainingBalls.player)
	self:_broadcastState()

	-- 턴 제한시간 (10초 후 턴 오버 + -1점)
	self.turnTimer = task.delay(Config.GAME.TURN_TIME, function()
		if self.state == "PLAYER_TURN" then
			-- 시간 초과: -1점 (최소 0점)
			self.scores.player = math.max(self.scores.player - 1, 0)
			self.remainingBalls.player -= 1
			self:_broadcastState()

			if self.player then
				self.remotes.BallLanded:FireClient(self.player, {
					zone = nil, slot = nil, team = "player",
					points = -1, position = nil,
					scores = self.scores, missions = self.missions, newMissions = {},
				})
			end

			task.wait(0.5)
			self:_nextTurn()
		end
	end)
end

function GameManager:handleLaunch(player, direction: Vector3, power: number, spin: number?, spawnX: number?)
	if self.state ~= "PLAYER_TURN" or player ~= self.player then
		return
	end
	if self.remainingBalls.player <= 0 then
		return
	end

	-- 턴 타이머 취소
	if self.turnTimer then
		task.cancel(self.turnTimer)
		self.turnTimer = nil
	end

	power = math.clamp(power, Config.LAUNCH.MIN_POWER, Config.LAUNCH.MAX_POWER)
	spin = math.clamp(spin or 0, -1, 1)
	spawnX = math.clamp(spawnX or 0, -Config.LAUNCH.SPAWN_X_RANGE, Config.LAUNCH.SPAWN_X_RANGE)

	self.remainingBalls.player -= 1
	self.state = "BALL_MOVING"

	task.spawn(function()
		local ball = self:_createBall("player", spawnX)
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
		-- AI 결정 (spawnX도 함께 반환)
		local direction, power, spin, aiSpawnX = self.ai:decide(self.slotOwners)

		-- AI "생각" 시간 — 카메라가 발사 뷰로 전환하는 시간
		task.wait(0.8)

		-- AI 공 미리보기 위치 알림 (클라이언트에서 카메라 이동용)
		if self.player then
			self.remotes.TurnChanged:FireClient(self.player, false, self.remainingBalls.ai)
		end

		-- AI가 위치 고르는 연출 (잠시 대기)
		task.wait(1.0)

		self.remainingBalls.ai -= 1
		local ball = self:_createBall("ai", aiSpawnX)
		self:_launchBall(ball, direction, power, spin)

		self.remotes.BallCreated:FireClient(self.player, ball)

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

		if not ball or not ball.Parent then
			self:_checkLooseBalls() -- 다른 공도 체크
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

		if vel < 0.6 then
			-- 0.8초 대기 후 재확인 (경사로 다시 미끄러질 수 있음)
			task.wait(0.8)
			if not ball or not ball.Parent then
				self:_checkLooseBalls()
				self:_onBallResult(nil, nil, team, nil)
				return
			end

			-- 대기 후에도 여전히 움직이면 아직 settle 아님 → 루프 계속
			local velAfter = ball.AssemblyLinearVelocity.Magnitude
			if velAfter >= 0.6 then
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
				if self.player then
					self.remotes.BallLanded:FireClient(self.player, {
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
				end
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
	-- 점수 재계산
	self:_recalculateScores()

	-- 미션 체크
	local newMissions = self:_checkMissions(team)

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
			missions = self.missions,
			newMissions = newMissions,
			playerLetters = self:_collectLetters("player"),
		})
	end

	self:_broadcastState()

	-- 슬롯 안착 성공 → 추가 턴!
	task.wait(1)
	if zoneNum and team == self.currentTurn then
		-- 같은 팀 추가 턴 (공이 남아있으면)
		local remaining = team == "player" and self.remainingBalls.player or self.remainingBalls.ai
		if remaining > 0 then
			if team == "player" then
				self:_startPlayerTurn()
			else
				self:_executeAITurn()
			end
			return
		end
	end
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
			self:_startPlayerTurn()
		end
	else
		self.currentTurn = "player"
		if self.remainingBalls.player > 0 then
			self:_startPlayerTurn()
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
		missions = self.missions,
		playerLetters = self:_collectLetters("player"),
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
