local DataStoreService = game:GetService("DataStoreService")

local RankManager = {}

local STORE_NAME = "UncballRanks_v1"
local DEFAULT_RANK = 1000
local MIN_RANK = 0

-- ELO 설정
local PVP_K = 40
local AI_WIN = 10
local AI_DRAW = 3

-- 메모리 캐시
local ranks = {} -- [userId] = number

local dataStore = nil
pcall(function()
	dataStore = DataStoreService:GetDataStore(STORE_NAME)
end)

function RankManager.load(player)
	local userId = player.UserId
	local rank = DEFAULT_RANK

	if dataStore then
		local ok, val = pcall(function()
			return dataStore:GetAsync("rank_" .. userId)
		end)
		if ok and val then
			rank = val
		end
	end

	ranks[userId] = rank
	print("[Uncball] Rank loaded:", player.Name, rank)
	return rank
end

function RankManager.save(player)
	local userId = player.UserId
	local rank = ranks[userId]
	if not rank or not dataStore then return end

	pcall(function()
		dataStore:SetAsync("rank_" .. userId, rank)
	end)
	print("[Uncball] Rank saved:", player.Name, rank)
end

function RankManager.getRank(player): number
	if not player then return DEFAULT_RANK end
	return ranks[player.UserId] or DEFAULT_RANK
end

-- ELO 기대 승률 계산
local function expectedScore(myRank: number, oppRank: number): number
	return 1 / (1 + 10 ^ ((oppRank - myRank) / 400))
end

-- 매치 결과 반영 (PvP)
-- winner: "player"/"ai"/"draw" (서버 내부 기준)
-- returns: playerChange, opponentChange
function RankManager.applyPvPResult(player, opponent, winner: string): (number, number)
	local pRank = RankManager.getRank(player)
	local oRank = RankManager.getRank(opponent)

	local pExpected = expectedScore(pRank, oRank)
	local oExpected = expectedScore(oRank, pRank)

	local pActual, oActual
	if winner == "player" then
		pActual, oActual = 1, 0
	elseif winner == "ai" then -- 상대 승리 (내부적으로 ai = opponent)
		pActual, oActual = 0, 1
	else
		pActual, oActual = 0.5, 0.5
	end

	local pChange = math.round(PVP_K * (pActual - pExpected))
	local oChange = math.round(PVP_K * (oActual - oExpected))

	ranks[player.UserId] = math.max(MIN_RANK, pRank + pChange)
	ranks[opponent.UserId] = math.max(MIN_RANK, oRank + oChange)

	RankManager.save(player)
	RankManager.save(opponent)

	return pChange, oChange
end

-- AI 매치 결과 반영
-- returns: rankChange
function RankManager.applyAIResult(player, winner: string): number
	local rank = RankManager.getRank(player)
	local change = 0

	if winner == "player" then
		change = AI_WIN
	elseif winner == "draw" then
		change = AI_DRAW
	end
	-- AI 패배 = 0 변동

	ranks[player.UserId] = math.max(MIN_RANK, rank + change)
	RankManager.save(player)

	return change
end

-- 플레이어 퇴장 시 캐시 정리
function RankManager.unload(player)
	ranks[player.UserId] = nil
end

return RankManager
