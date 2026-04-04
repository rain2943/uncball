local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local TableBuilder = {}
TableBuilder.slotPositions = {}

local BALL_DIAM = Config.BALL.RADIUS * 2
local SLOT_GAP = BALL_DIAM + 0.15

-- 사각 포스트(칸막이)
local POST_WIDTH = 0.3
local POST_HEIGHT = 1.6
local POST_DEPTH = 0.8
local POST_COLOR = Color3.fromRGB(200, 195, 188)

-- 반원 장식판
local PLATE_THICKNESS = 0.2
local PLATE_COLOR = Color3.fromRGB(242, 238, 232)
local PLATE_RADIUS = 5.0 -- 모든 존 동일

function TableBuilder.build()
	local model = Instance.new("Model")
	model.Name = "GameTable"
	local tableTop = Config.TABLE.HEIGHT + Config.TABLE.THICKNESS / 2

	local surface = Instance.new("Part")
	surface.Name = "Surface"
	surface.Anchored = true
	surface.Size = Vector3.new(Config.TABLE.WIDTH, Config.TABLE.THICKNESS, Config.TABLE.LENGTH)
	surface.Position = Vector3.new(0, Config.TABLE.HEIGHT, 0)
	surface.Color = Config.TABLE.COLOR
	surface.Material = Config.TABLE.MATERIAL
	surface.TopSurface = Enum.SurfaceType.Smooth
	surface.BottomSurface = Enum.SurfaceType.Smooth
	surface.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.2, 0.05, 1, 1)
	surface.Parent = model

	local wH, wT = Config.TABLE.WALL_HEIGHT, Config.TABLE.WALL_THICKNESS
	local hW, hL = Config.TABLE.WIDTH / 2, Config.TABLE.LENGTH / 2
	for _, w in ipairs({
		{ "WallL", Vector3.new(wT, wH, Config.TABLE.LENGTH + wT * 2), Vector3.new(-hW - wT / 2, tableTop + wH / 2, 0) },
		{ "WallR", Vector3.new(wT, wH, Config.TABLE.LENGTH + wT * 2), Vector3.new(hW + wT / 2, tableTop + wH / 2, 0) },
		{ "WallF", Vector3.new(Config.TABLE.WIDTH + wT * 2, wH, wT), Vector3.new(0, tableTop + wH / 2, hL + wT / 2) },
	}) do
		local p = Instance.new("Part")
		p.Name = w[1]; p.Anchored = true; p.Size = w[2]; p.Position = w[3]
		p.Color = Config.TABLE.WALL_COLOR; p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = model
	for zoneNum = 1, 3 do
		local zc = Config.ZONES[zoneNum]
		local folder = Instance.new("Folder")
		folder.Name = "Zone" .. zoneNum
		folder.Parent = zonesFolder
		TableBuilder.slotPositions[zoneNum] = {}
		TableBuilder._buildTray(folder, zoneNum, zc, tableTop)
	end

	model.Parent = workspace
	return model
end

function TableBuilder._buildTray(parent, zoneNum, zoneConfig, tableTop)
	local numSlots = zoneConfig.SLOTS
	local numPosts = numSlots + 1
	local centerZ = zoneConfig.Z_OFFSET
	local postLineZ = centerZ

	-- ===== 1) 반원판 (스트립 조합, 가림판 없음) =====
	-- 직선변 = 포스트 라인 (Z = postLineZ)
	-- 곡선 = -Z 방향 (플레이어 쪽)
	local R = PLATE_RADIUS
	local NUM_STRIPS = 10
	local stripDepth = R / NUM_STRIPS

	for s = 0, NUM_STRIPS - 1 do
		local d = (s + 0.5) * stripDepth -- 직선변에서의 거리
		local halfW = math.sqrt(math.max(R * R - d * d, 0))
		if halfW < 0.2 then continue end

		local strip = Instance.new("Part")
		strip.Name = "Plate_" .. zoneNum .. "_" .. s
		strip.Anchored = true
		strip.Size = Vector3.new(halfW * 2, POST_HEIGHT, stripDepth + 0.02)
		strip.Position = Vector3.new(0, tableTop + POST_HEIGHT / 2, postLineZ - d)
		strip.Color = PLATE_COLOR
		strip.Material = Enum.Material.SmoothPlastic
		strip.CanCollide = true
		strip.TopSurface = Enum.SurfaceType.Smooth
		strip.BottomSurface = Enum.SurfaceType.Smooth
		strip.Parent = parent
	end

	-- ===== 2) 사각 박스 포스트 (직선변 위에 일렬) =====
	local postSpacing = SLOT_GAP + POST_WIDTH
	local totalPostWidth = numSlots * SLOT_GAP + numPosts * POST_WIDTH
	local startX = -totalPostWidth / 2
	local postY = tableTop + PLATE_THICKNESS + POST_HEIGHT / 2

	local postPositions = {}
	for i = 1, numPosts do
		local x = startX + (i - 1) * postSpacing + POST_WIDTH / 2

		local post = Instance.new("Part")
		post.Name = "Post_" .. zoneNum .. "_" .. i
		post.Anchored = true
		post.Size = Vector3.new(POST_WIDTH, POST_HEIGHT, POST_DEPTH)
		post.Position = Vector3.new(x, postY, postLineZ)
		post.Color = POST_COLOR
		post.Material = Enum.Material.SmoothPlastic
		post.CanCollide = true
		post.TopSurface = Enum.SurfaceType.Smooth
		post.BottomSurface = Enum.SurfaceType.Smooth
		post.Parent = parent

		postPositions[i] = Vector3.new(x, tableTop + PLATE_THICKNESS, postLineZ)
	end

	-- ===== 3) 슬롯 위치 + 라벨 =====
	for i = 1, numSlots do
		local slotX = (postPositions[i].X + postPositions[i + 1].X) / 2
		TableBuilder.slotPositions[zoneNum][i] = Vector3.new(slotX, tableTop + PLATE_THICKNESS, postLineZ)

		local lbl = Instance.new("Part")
		lbl.Anchored = true; lbl.Transparency = 1; lbl.CanCollide = false
		lbl.Size = Vector3.new(0.1, 0.1, 0.1)
		lbl.Position = Vector3.new(slotX, tableTop + 0.3, postLineZ - 1)
		lbl.Parent = parent

		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(0, 22, 0, 22)
		bb.StudsOffset = Vector3.new(0, 0.3, 0)
		bb.AlwaysOnTop = false
		bb.Parent = lbl

		local txt = Instance.new("TextLabel")
		txt.Size = UDim2.new(1, 0, 1, 0)
		txt.BackgroundTransparency = 1
		txt.Text = zoneConfig.LABELS[i]
		txt.TextColor3 = Color3.fromRGB(40, 40, 40)
		txt.TextScaled = true
		txt.Font = Enum.Font.GothamBlack
		txt.Parent = bb
	end

	-- ===== 4) 존 번호 =====
	local nl = Instance.new("Part")
	nl.Anchored = true; nl.Transparency = 1; nl.CanCollide = false
	nl.Size = Vector3.new(0.1, 0.1, 0.1)
	nl.Position = Vector3.new(0, tableTop + 0.3, postLineZ - PLATE_RADIUS * 0.5)
	nl.Parent = parent

	local nbb = Instance.new("BillboardGui")
	nbb.Size = UDim2.new(0, 55, 0, 55)
	nbb.StudsOffset = Vector3.new(0, 0.3, 0)
	nbb.AlwaysOnTop = false
	nbb.Parent = nl

	local nt = Instance.new("TextLabel")
	nt.Size = UDim2.new(1, 0, 1, 0)
	nt.BackgroundTransparency = 1
	nt.Text = tostring(zoneNum)
	nt.TextColor3 = Color3.fromRGB(200, 60, 50)
	nt.TextScaled = true
	nt.Font = Enum.Font.GothamBlack
	nt.Parent = nbb
end

return TableBuilder
