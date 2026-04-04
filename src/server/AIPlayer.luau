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

	-- 발사 위치에서 타겟까지
	local launchPos = Vector3.new(0, Config.TABLE.HEIGHT + Config.LAUNCH.SPAWN_Y_OFFSET, Config.LAUNCH.SPAWN_Z)
	local toTarget = targetPos - launchPos
	local horizontalDist = Vector3.new(toTarget.X, 0, toTarget.Z).Magnitude

	-- 파워 계산
	local powerRatio = horizontalDist / (Config.TABLE.LENGTH * 0.65)
	local basePower = Config.LAUNCH.MIN_POWER + (Config.LAUNCH.MAX_POWER - Config.LAUNCH.MIN_POWER) * math.clamp(powerRatio, 0, 1)

	-- 스킬 기반 오차
	local errorScale = 1 - self.skill
	local aimError = (math.random() - 0.5) * 2 * Config.AI.AIM_ERROR_MAX * errorScale
	local powerError = (math.random() - 0.5) * 2 * Config.AI.POWER_ERROR_MAX * errorScale
	local finalPower = math.clamp(basePower + powerError, Config.LAUNCH.MIN_POWER, Config.LAUNCH.MAX_POWER)

	-- 방향
	local direction = Vector3.new(toTarget.X + aimError, 0, toTarget.Z).Unit

	-- 스핀 결정: 타겟이 좌우에 있으면 스핀으로 커브
	local spin = 0
	if targetPos.X > 2 then
		-- 오른쪽 타겟 → 오른쪽 스핀
		spin = math.random() * 0.6 * self.skill
	elseif targetPos.X < -2 then
		-- 왼쪽 타겟 → 왼쪽 스핀
		spin = -math.random() * 0.6 * self.skill
	else
		-- 중앙 타겟 → 가끔 약한 스핀
		spin = (math.random() - 0.5) * 0.3
	end

	-- 스킬 높으면 가끔 강한 스핀으로 트릭샷 시도
	if self.skill > 0.5 and math.random() < 0.2 then
		spin = (math.random() - 0.5) * 1.5
	end

	return direction, finalPower, math.clamp(spin, -1, 1)
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
