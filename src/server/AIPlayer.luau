local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local AIPlayer = {}
AIPlayer.__index = AIPlayer

-- 존별 발사 프리셋 (경험적 최적값)
local ZONE_PRESETS = {
	[1] = { power = 30, powerJitter = 2 },  -- Zone1: Z=-12, 거리 28 studs
	[2] = { power = 38, powerJitter = 2 },  -- Zone2: Z=6, 거리 46 studs
	[3] = { power = 45, powerJitter = 3 },  -- Zone3: Z=24, 거리 64 studs
}

function AIPlayer.new(slotPositions: { [number]: { Vector3 } })
	local self = setmetatable({}, AIPlayer)
	self.slotPositions = slotPositions
	self.skill = Config.AI.SKILL
	return self
end

-- AI가 발사 파라미터를 결정 (방향, 파워, 스핀, 발사X위치)
function AIPlayer:decide(slotOwners: { [number]: { string? } }): (Vector3, number, number, number)
	local targetZone, targetSlot = self:_pickTarget(slotOwners)
	local targetPos = self.slotPositions[targetZone][targetSlot]

	-- 좌우 중 하나 선택
	local side = math.random() < 0.5 and -1 or 1

	-- 발사 위치: 엣지 근처 (6~9)
	local spawnX = side * (6 + math.random() * 3)

	-- 스핀: 발사 반대 방향으로 커브 (0.10~0.18)
	local spin = -side * (0.10 + math.random() * 0.08)

	-- 파워: 존별 프리셋
	local preset = ZONE_PRESETS[targetZone]
	local power = preset.power + (math.random() - 0.5) * preset.powerJitter * 2

	-- 방향: spawnX에서 타겟을 향해
	local dx = targetPos.X - spawnX
	local dz = targetPos.Z - Config.LAUNCH.SPAWN_Z

	-- 스킬 기반 소폭 오차
	local errorScale = 1 - self.skill
	local aimError = (math.random() - 0.5) * 1.0 * errorScale
	local direction = Vector3.new(dx + aimError, 0, dz).Unit

	-- 파워/스핀 소폭 오차
	power = math.clamp(power + (math.random() - 0.5) * 4 * errorScale, Config.LAUNCH.MIN_POWER, Config.LAUNCH.MAX_POWER)
	spin = math.clamp(spin + (math.random() - 0.5) * 0.06 * errorScale, -1, 1)
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
