local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local AIPlayer = {}
AIPlayer.__index = AIPlayer

-- 존별 발사 프리셋 (감속 ~17.4 studs/s² 기준 역산)
-- power = sqrt(2 * 17.4 * distance)
-- Zone1: d=28 → 31.2, Zone2: d=46 → 40.0, Zone3: d=64 → 47.2
local ZONE_PRESETS = {
	[1] = { power = 31, powerJitter = 1.5 },
	[2] = { power = 40, powerJitter = 1.5 },
	[3] = { power = 47, powerJitter = 2 },
}

function AIPlayer.new(slotPositions: { [number]: { Vector3 } })
	local self = setmetatable({}, AIPlayer)
	self.slotPositions = slotPositions
	self.skill = Config.AI.SKILL
	return self
end

-- AI가 발사 파라미터를 결정 (방향, 파워, 스핀, 발사X위치)
function AIPlayer:decide(slotOwners: { [number]: { string? } }, wind: { speed: number, angle: number }?): (Vector3, number, number, number)
	local targetZone, targetSlot = self:_pickTarget(slotOwners)

	-- 좌우 끝에서 발사 (플레이어와 동일한 전략)
	local side = math.random() < 0.5 and -1 or 1
	local spawnX = side * (8 + math.random())

	-- 방향: 직진 (플레이어와 동일하게 X=0)
	local direction = Vector3.new(0, 0, 1).Unit

	-- 스핀: 안쪽으로 커브 (오른쪽발사→R스핀=-, 왼쪽발사→L스핀=+)
	local spin = -side * (0.10 + math.random() * 0.06)

	-- 바람 보정: 바람의 X 성분 반대로 스핀 소폭 조정
	if wind and wind.speed > 0 then
		local rad = math.rad(wind.angle)
		local windX = math.cos(rad) * wind.speed
		-- 바람이 오른쪽으로 불면 왼쪽 스핀 추가 (스킬 비례)
		local windCompensation = -windX * 0.008 * self.skill
		spin = spin + windCompensation
	end

	-- 파워: 물리 역산 프리셋
	local preset = ZONE_PRESETS[targetZone]
	local power = preset.power + (math.random() - 0.5) * preset.powerJitter * 2

	-- 소폭 오차 (스킬 기반)
	local errorScale = 1 - self.skill
	power = math.clamp(power + (math.random() - 0.5) * 2 * errorScale, Config.LAUNCH.MIN_POWER, Config.LAUNCH.MAX_POWER)
	spin = math.clamp(spin + (math.random() - 0.5) * 0.02 * errorScale, -1, 1)
	spawnX = math.clamp(spawnX, -Config.LAUNCH.SPAWN_X_RANGE, Config.LAUNCH.SPAWN_X_RANGE)

	return direction, power, spin, spawnX
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
