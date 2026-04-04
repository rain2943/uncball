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

-- AI가 발사 파라미터를 결정
function AIPlayer:decide(slotOwners: { [number]: { string? } }): (Vector3, number)
	-- 1) 타겟 존/슬롯 선택
	local targetZone, targetSlot = self:_pickTarget(slotOwners)

	-- 2) 타겟 슬롯의 월드 좌표
	local targetPos = self.slotPositions[targetZone][targetSlot]

	-- 3) 발사 위치에서 타겟까지의 방향 및 거리 계산
	local launchPos = Vector3.new(0, Config.TABLE.HEIGHT + Config.LAUNCH.SPAWN_Y_OFFSET, Config.LAUNCH.SPAWN_Z)
	local toTarget = targetPos - launchPos
	local horizontalDist = Vector3.new(toTarget.X, 0, toTarget.Z).Magnitude

	-- 4) 파워 계산 (거리 비례 + 경사 보정)
	local powerRatio = horizontalDist / (Config.TABLE.LENGTH * 0.7)
	local basePower = Config.LAUNCH.MIN_POWER + (Config.LAUNCH.MAX_POWER - Config.LAUNCH.MIN_POWER) * math.clamp(powerRatio, 0, 1)

	-- 5) 스킬 기반 오차 적용
	local errorScale = 1 - self.skill
	local aimError = (math.random() - 0.5) * 2 * Config.AI.AIM_ERROR_MAX * errorScale
	local powerError = (math.random() - 0.5) * 2 * Config.AI.POWER_ERROR_MAX * errorScale

	local finalPower = math.clamp(basePower + powerError, Config.LAUNCH.MIN_POWER, Config.LAUNCH.MAX_POWER)

	-- 6) 방향 벡터 (X에 에임 오차 적용)
	local direction = Vector3.new(toTarget.X + aimError, 0, toTarget.Z).Unit

	return direction, finalPower
end

-- 빈 슬롯 중에서 전략적으로 타겟 선택
function AIPlayer:_pickTarget(slotOwners)
	local candidates = {}

	for zoneNum = 1, 3 do
		local zoneConfig = Config.ZONES[zoneNum]
		for slotIdx = 1, zoneConfig.SLOTS do
			if not slotOwners[zoneNum][slotIdx] then
				-- 가중치: 높은 점수 존 + 인접한 AI 공이 있으면 보너스
				local weight = zoneConfig.BASE_POINTS
				-- 인접 슬롯에 AI 공이 있으면 연속 보너스 노림
				if slotIdx > 1 and slotOwners[zoneNum][slotIdx - 1] == "ai" then
					weight = weight + 3
				end
				if slotIdx < zoneConfig.SLOTS and slotOwners[zoneNum][slotIdx + 1] == "ai" then
					weight = weight + 3
				end
				-- 스킬에 따라 먼 존 도전 확률 조절
				if zoneNum == 3 then
					weight = weight * self.skill
				end
				table.insert(candidates, { zone = zoneNum, slot = slotIdx, weight = weight })
			end
		end
	end

	-- 빈 슬롯이 없으면 기본값 (상대 공 밀어내기 시도)
	if #candidates == 0 then
		return 1, math.ceil(Config.ZONES[1].SLOTS / 2)
	end

	-- 가중치 기반 랜덤 선택
	local totalWeight = 0
	for _, c in candidates do
		totalWeight = totalWeight + c.weight
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for _, c in candidates do
		cumulative = cumulative + c.weight
		if roll <= cumulative then
			return c.zone, c.slot
		end
	end

	local last = candidates[#candidates]
	return last.zone, last.slot
end

function AIPlayer:getThinkTime(): number
	return Config.AI.THINK_TIME_MIN + math.random() * (Config.AI.THINK_TIME_MAX - Config.AI.THINK_TIME_MIN)
end

return AIPlayer
