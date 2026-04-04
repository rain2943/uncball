local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local AIPlayer = {}
AIPlayer.__index = AIPlayer

function AIPlayer.new(slotPositions: { [number]: { Vector3 } })
	local self = setmetatable({}, AIPlayer)
	self.slotPositions = slotPositions
	self.skill = Config.AI.SKILL
	return self
end

-- AI가 발사 파라미터를 결정 (방향, 파워, 스핀)
function AIPlayer:decide(slotOwners: { [number]: { string? } }): (Vector3, number, number)
	local targetZone, targetSlot = self:_pickTarget(slotOwners)
	local targetPos = self.slotPositions[targetZone][targetSlot]

	local launchPos = Vector3.new(0, Config.TABLE.HEIGHT + Config.LAUNCH.SPAWN_Y_OFFSET, Config.LAUNCH.SPAWN_Z)
	local toTarget = targetPos - launchPos
	local horizontalDist = Vector3.new(toTarget.X, 0, toTarget.Z).Magnitude

	local errorScale = 1 - self.skill

	-- === 전략 선택: 직선 vs 좌우 우회 vs 스핀 커브 ===
	local strategy = math.random()
	local aimX, spin, basePower

	if strategy < 0.5 then
		-- 전략1: 좌측에서 크게 우회 진입
		aimX = -6 - math.random() * 4 -- 왼쪽으로 크게
		spin = 0.6 + math.random() * 0.4 -- 강한 오른쪽 스핀
		basePower = 0.5 + math.random() * 0.3

	else
		-- 전략2: 우측에서 크게 우회 진입
		aimX = 6 + math.random() * 4 -- 오른쪽으로 크게
		spin = -(0.6 + math.random() * 0.4) -- 강한 왼쪽 스핀
		basePower = 0.5 + math.random() * 0.3
	end

	-- 파워 계산
	local power = Config.LAUNCH.MIN_POWER + (Config.LAUNCH.MAX_POWER - Config.LAUNCH.MIN_POWER) * math.clamp(basePower, 0.2, 0.85)
	local powerError = (math.random() - 0.5) * Config.AI.POWER_ERROR_MAX * errorScale
	power = math.clamp(power + powerError, Config.LAUNCH.MIN_POWER, Config.LAUNCH.MAX_POWER)

	-- 에임 오차
	local aimError = (math.random() - 0.5) * Config.AI.AIM_ERROR_MAX * errorScale
	local direction = Vector3.new(aimX + aimError, 0, toTarget.Z).Unit

	-- 스핀 오차
	spin = math.clamp(spin + (math.random() - 0.5) * 0.2 * errorScale, -1, 1)

	return direction, power, spin
end

function AIPlayer:_pickTarget(slotOwners)
	local candidates = {}

	for zoneNum = 1, 3 do
		local zoneConfig = Config.ZONES[zoneNum]
		for slotIdx = 1, zoneConfig.SLOTS do
			if not slotOwners[zoneNum][slotIdx] then
				local weight = zoneConfig.BASE_POINTS

				-- 인접 AI 공 → 연속 보너스 노림 (가중치 UP)
				local adjacentCount = 0
				if slotIdx > 1 and slotOwners[zoneNum][slotIdx - 1] == "ai" then
					adjacentCount += 1
				end
				if slotIdx < zoneConfig.SLOTS and slotOwners[zoneNum][slotIdx + 1] == "ai" then
					adjacentCount += 1
				end
				weight = weight + adjacentCount * 4

				-- 인접 플레이어 공 → 방해 차단 (가중치 UP)
				if slotIdx > 1 and slotOwners[zoneNum][slotIdx - 1] == "player" then
					weight = weight + 2
				end
				if slotIdx < zoneConfig.SLOTS and slotOwners[zoneNum][slotIdx + 1] == "player" then
					weight = weight + 2
				end

				-- 중앙 슬롯 선호 (A 슬롯)
				local center = math.ceil(zoneConfig.SLOTS / 2)
				local distFromCenter = math.abs(slotIdx - center)
				weight = weight + math.max(0, 3 - distFromCenter)

				-- 높은 존에 도전 (스킬에 비례)
				if zoneNum == 3 then
					weight = weight * (0.5 + self.skill * 0.8)
				elseif zoneNum == 2 then
					weight = weight * (0.7 + self.skill * 0.4)
				end

				table.insert(candidates, { zone = zoneNum, slot = slotIdx, weight = weight })
			end
		end
	end

	if #candidates == 0 then
		return 1, math.ceil(Config.ZONES[1].SLOTS / 2)
	end

	-- 가중치 기반 랜덤 선택
	local totalWeight = 0
	for _, c in ipairs(candidates) do
		totalWeight = totalWeight + c.weight
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for _, c in ipairs(candidates) do
		cumulative = cumulative + c.weight
		if roll <= cumulative then
			return c.zone, c.slot
		end
	end

	return candidates[#candidates].zone, candidates[#candidates].slot
end

function AIPlayer:getThinkTime(): number
	return Config.AI.THINK_TIME_MIN + math.random() * (Config.AI.THINK_TIME_MAX - Config.AI.THINK_TIME_MIN)
end

return AIPlayer
