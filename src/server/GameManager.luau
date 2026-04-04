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

	-- 콤보 상태
	self.combos = { player = {}, ai = {} }
	self.prevCombos = { player = {}, ai = {} }

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
	self.combos = { player = {}, ai = {} }
	self.prevCombos = { player = {}, ai = {} }

	-- 플레이어 캐릭터를 테이블 끝에 배치
	self:_positionPlayer(player)

	-- 매치 시작 알림
	self.remotes.MatchStart:FireClient(player, {
		ballsPerPlayer = Config.GAME.BALLS_PER_PLAYER,
		matchTime = Config.GAME.MATCH_TIME,
	})

	self:_startPlayerTurn()
end

function GameManager:_startPlayerTurn()
	self.state = "PLAYER_TURN"
	self.remotes.TurnChanged:FireClient(self.player, true, self.remainingBalls.player)
	self:_broadcastState()

	-- 턴 제한시간 (10초 후 자동 발사)
	self.turnTimer = task.delay(Config.GAME.TURN_TIME, function()
		if self.state == "PLAYER_TURN" then
			-- 시간 초과: 랜덤 발사
			local dir = Vector3.new((math.random() - 0.5) * 0.5, 0, 1).Unit
			local power = Config.LAUNCH.MIN_POWER + math.random() * 20
			self:handleLaunch(self.player, dir, power, 0, 0)
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

	-- 새로 달성한 콤보 감지
	local newCombos = {}
	local prevKeys = {}
	for _, c in (self.prevCombos[team] or {}) do
		prevKeys[c.key] = true
	end
	for _, c in (self.combos[team] or {}) do
		if not prevKeys[c.key] then
			table.insert(newCombos, c)
		end
	end

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
			combos = self.combos,
			newCombos = newCombos,
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

function GameManager:_calculateCombos(team: string): { { key: string, name: string, bonus: number, icon: string } }
	-- Collect letters per zone and across all zones
	local lettersPerZone: { [number]: { [string]: number } } = {}
	local lettersAcrossZones: { [string]: { [number]: boolean } } = {}

	for zoneNum = 1, 3 do
		lettersPerZone[zoneNum] = {}
		local zoneConfig = Config.ZONES[zoneNum]
		local slots = self.slotOwners[zoneNum]
		for i = 1, zoneConfig.SLOTS do
			if slots[i] == team then
				local letter = zoneConfig.LABELS[i]
				lettersPerZone[zoneNum][letter] = (lettersPerZone[zoneNum][letter] or 0) + 1
				if not lettersAcrossZones[letter] then
					lettersAcrossZones[letter] = {}
				end
				lettersAcrossZones[letter][zoneNum] = true
			end
		end
	end

	-- Count zones per letter
	local zonesPerLetter: { [string]: number } = {}
	for letter, zones in lettersAcrossZones do
		local count = 0
		for _ in zones do count += 1 end
		zonesPerLetter[letter] = count
	end

	-- Check for grand slams (needed for Star Cluster)
	local hasGrandSlam = false
	for zoneNum = 1, 3 do
		local zoneConfig = Config.ZONES[zoneNum]
		local allMine = true
		for i = 1, zoneConfig.SLOTS do
			if self.slotOwners[zoneNum][i] ~= team then
				allMine = false
				break
			end
		end
		if allMine and self.slotOwners[zoneNum][1] == team then
			hasGrandSlam = true
			break
		end
	end

	local achieved = {}
	local hasTripleMatch = {} -- letters with triple match
	local hasCrossPair = {} -- letters with cross pair

	-- PAIR: same letter x2+ in one zone
	for zoneNum = 1, 3 do
		for letter, count in lettersPerZone[zoneNum] do
			if count >= 2 then
				local key = "PAIR_" .. letter .. "_Z" .. zoneNum
				table.insert(achieved, {
					key = key,
					comboKey = "PAIR",
					name = Config.COMBOS.PAIR.name,
					bonus = Config.COMBOS.PAIR.bonus,
					icon = Config.COMBOS.PAIR.icon,
					detail = letter .. " x2 Z" .. zoneNum,
				})
			end
		end
	end

	-- CROSS PAIR: same letter in 2+ different zones
	for letter, zoneCount in zonesPerLetter do
		if zoneCount >= 2 then
			local key = "CROSS_PAIR_" .. letter
			table.insert(achieved, {
				key = key,
				comboKey = "CROSS_PAIR",
				name = Config.COMBOS.CROSS_PAIR.name,
				bonus = Config.COMBOS.CROSS_PAIR.bonus,
				icon = Config.COMBOS.CROSS_PAIR.icon,
				detail = letter .. " x" .. zoneCount .. " zones",
			})
			hasCrossPair[letter] = true
		end
	end

	-- TRIPLE MATCH: same letter in all 3 zones
	for letter, zoneCount in zonesPerLetter do
		if zoneCount >= 3 then
			local key = "TRIPLE_MATCH_" .. letter
			table.insert(achieved, {
				key = key,
				comboKey = "TRIPLE_MATCH",
				name = Config.COMBOS.TRIPLE_MATCH.name,
				bonus = Config.COMBOS.TRIPLE_MATCH.bonus,
				icon = Config.COMBOS.TRIPLE_MATCH.icon,
				detail = letter .. " in all zones",
			})
			hasTripleMatch[letter] = true
		end
	end

	-- STRAIGHT: A + B + C
	local hasA = zonesPerLetter["A"] and zonesPerLetter["A"] > 0
	local hasB = zonesPerLetter["B"] and zonesPerLetter["B"] > 0
	local hasC = zonesPerLetter["C"] and zonesPerLetter["C"] > 0
	local hasD = zonesPerLetter["D"] and zonesPerLetter["D"] > 0

	if hasA and hasB and hasC then
		table.insert(achieved, {
			key = "STRAIGHT",
			comboKey = "STRAIGHT",
			name = Config.COMBOS.STRAIGHT.name,
			bonus = Config.COMBOS.STRAIGHT.bonus,
			icon = Config.COMBOS.STRAIGHT.icon,
			detail = "A-B-C",
		})
	end

	-- FULL STRAIGHT: A + B + C + D
	if hasA and hasB and hasC and hasD then
		table.insert(achieved, {
			key = "FULL_STRAIGHT",
			comboKey = "FULL_STRAIGHT",
			name = Config.COMBOS.FULL_STRAIGHT.name,
			bonus = Config.COMBOS.FULL_STRAIGHT.bonus,
			icon = Config.COMBOS.FULL_STRAIGHT.icon,
			detail = "A-B-C-D",
		})
	end

	-- FULL HOUSE: Triple Match + Cross Pair of different letter
	local tripleLetters = {}
	for letter in hasTripleMatch do
		table.insert(tripleLetters, letter)
	end
	local crossPairLetters = {}
	for letter in hasCrossPair do
		table.insert(crossPairLetters, letter)
	end

	for _, tLetter in tripleLetters do
		for _, cpLetter in crossPairLetters do
			if cpLetter ~= tLetter then
				table.insert(achieved, {
					key = "FULL_HOUSE_" .. tLetter .. "_" .. cpLetter,
					comboKey = "FULL_HOUSE",
					name = Config.COMBOS.FULL_HOUSE.name,
					bonus = Config.COMBOS.FULL_HOUSE.bonus,
					icon = Config.COMBOS.FULL_HOUSE.icon,
					detail = tLetter .. "x3 + " .. cpLetter .. "x2",
				})
				-- Only one Full House per triple letter
				break
			end
		end
	end

	-- STAR CLUSTER: A in all 3 zones + any Grand Slam
	if hasGrandSlam and zonesPerLetter["A"] and zonesPerLetter["A"] >= 3 then
		table.insert(achieved, {
			key = "STAR_CLUSTER",
			comboKey = "STAR_CLUSTER",
			name = Config.COMBOS.STAR_CLUSTER.name,
			bonus = Config.COMBOS.STAR_CLUSTER.bonus,
			icon = Config.COMBOS.STAR_CLUSTER.icon,
			detail = "A x3 zones + GS",
		})
	end

	return achieved
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

		-- 콤보 보너스 계산
		local combos = self:_calculateCombos(team)
		for _, combo in combos do
			total = total + combo.bonus
		end

		-- 이전 콤보 저장 (새 콤보 감지용)
		self.prevCombos[team] = self.combos[team]
		self.combos[team] = combos
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
		combos = self.combos,
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
