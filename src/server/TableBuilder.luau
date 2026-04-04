local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local TableBuilder = {}

TableBuilder.slotPositions = {}
TableBuilder.dividerParts = {}

-- 트레이 설정
local TRAY_DEPTH = 2.2
local DIVIDER_THICKNESS = 0.3
local DIVIDER_HEIGHT = 1.4
local BACK_WALL_HEIGHT = 1.5
local BACK_WALL_THICKNESS = 0.35
local PLATFORM_COLOR = Color3.fromRGB(60, 55, 90)
local DIVIDER_COLOR = Color3.fromRGB(230, 228, 225)
local WALL_COLOR = Color3.fromRGB(70, 65, 100)

function TableBuilder.build()
	local model = Instance.new("Model")
	model.Name = "GameTable"

	local tableTop = Config.TABLE.HEIGHT + Config.TABLE.THICKNESS / 2

	-- 메인 테이블 표면
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

	-- 벽
	local wallH = Config.TABLE.WALL_HEIGHT
	local wallT = Config.TABLE.WALL_THICKNESS
	local halfW = Config.TABLE.WIDTH / 2
	local halfL = Config.TABLE.LENGTH / 2

	local walls = {
		{ name = "WallLeft", size = Vector3.new(wallT, wallH, Config.TABLE.LENGTH + wallT * 2), pos = Vector3.new(-halfW - wallT / 2, tableTop + wallH / 2, 0) },
		{ name = "WallRight", size = Vector3.new(wallT, wallH, Config.TABLE.LENGTH + wallT * 2), pos = Vector3.new(halfW + wallT / 2, tableTop + wallH / 2, 0) },
		{ name = "WallFar", size = Vector3.new(Config.TABLE.WIDTH + wallT * 2, wallH, wallT), pos = Vector3.new(0, tableTop + wallH / 2, halfL + wallT / 2) },
	}

	for _, w in walls do
		local part = Instance.new("Part")
		part.Name = w.name
		part.Anchored = true
		part.Size = w.size
		part.Position = w.pos
		part.Color = Config.TABLE.WALL_COLOR
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
	end

	TableBuilder._buildZones(model, tableTop)

	model.Parent = workspace
	return model
end

function TableBuilder._buildZones(model, tableTop)
	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = model

	for zoneNum = 1, 3 do
		local zoneConfig = Config.ZONES[zoneNum]
		local zoneFolder = Instance.new("Folder")
		zoneFolder.Name = "Zone" .. zoneNum
		zoneFolder.Parent = zonesFolder

		TableBuilder.slotPositions[zoneNum] = {}
		TableBuilder.dividerParts[zoneNum] = {}

		TableBuilder._buildTray(zoneFolder, zoneNum, zoneConfig, tableTop)
	end
end

function TableBuilder._buildTray(parent, zoneNum, zoneConfig, tableTop)
	local numSlots = zoneConfig.SLOTS
	local numDividers = numSlots + 1
	local arcRadius = zoneConfig.RADIUS * 0.72
	local centerZ = zoneConfig.Z_OFFSET
	local floorY = tableTop

	--[[
		트레이 = 그릇 모양 (U자형)
		- 아크: π→2π (아래쪽 반원, -Z로 볼록) = 뒷벽/바닥 곡선
		- 칸막이가 아크에서 +Z(위쪽/멀리) 방향으로 돌출
		- 공이 +Z에서 넘어오다가 칸막이 사이로 내려와 그릇에 안착
	]]

	-- ===== 1) 아크 위 디바이더 위치 계산 =====
	local dividerAngles = {}
	local dividerArcPositions = {}
	for i = 0, numDividers - 1 do
		local t = i / (numDividers - 1)
		local angle = math.pi + t * math.pi -- π → 2π (아래쪽 반원)
		dividerAngles[i + 1] = angle

		local x = arcRadius * math.cos(angle)
		local z = centerZ + arcRadius * math.sin(angle)
		dividerArcPositions[i + 1] = Vector3.new(x, floorY, z)
	end

	-- ===== 2) 칸막이 생성 =====
	-- 아크에서 +Z(위쪽) 방향으로 TRAY_DEPTH만큼 돌출
	for i = 1, numDividers do
		local angle = dividerAngles[i]
		local arcPos = dividerArcPositions[i]

		local wallCenter = Vector3.new(
			arcPos.X,
			floorY + DIVIDER_HEIGHT / 2,
			arcPos.Z + TRAY_DEPTH / 2  -- +Z 방향으로 돌출
		)

		-- 칸막이 방향: Z축 정렬 (앞뒤 방향)
		local divider = Instance.new("Part")
		divider.Name = "Divider_" .. zoneNum .. "_" .. i
		divider.Anchored = true
		divider.Size = Vector3.new(DIVIDER_THICKNESS, DIVIDER_HEIGHT, TRAY_DEPTH)
		divider.CFrame = CFrame.new(wallCenter)
		divider.Color = DIVIDER_COLOR
		divider.Material = Enum.Material.SmoothPlastic
		divider.CanCollide = true
		divider.TopSurface = Enum.SurfaceType.Smooth
		divider.BottomSurface = Enum.SurfaceType.Smooth
		divider.Parent = parent

		TableBuilder.dividerParts[zoneNum][i] = divider
	end

	-- ===== 3) 뒷벽 + 바닥 + 슬롯 위치 =====
	for i = 1, numSlots do
		local leftArc = dividerArcPositions[i]
		local rightArc = dividerArcPositions[i + 1]
		local midAngle = (dividerAngles[i] + dividerAngles[i + 1]) / 2

		-- 뒷벽: 아크 위치 (그릇 바닥 = -Z쪽 곡선)
		local backCenterX = (leftArc.X + rightArc.X) / 2
		local backCenterZ = (leftArc.Z + rightArc.Z) / 2
		local backPos = Vector3.new(backCenterX, floorY + BACK_WALL_HEIGHT / 2, backCenterZ)

		-- 뒷벽 너비 + 방향
		local backWidth = (Vector3.new(leftArc.X, 0, leftArc.Z) - Vector3.new(rightArc.X, 0, rightArc.Z)).Magnitude + DIVIDER_THICKNESS
		local wallDir = (Vector3.new(rightArc.X, 0, rightArc.Z) - Vector3.new(leftArc.X, 0, leftArc.Z)).Unit

		local backWall = Instance.new("Part")
		backWall.Name = "BackWall_" .. zoneNum .. "_" .. i
		backWall.Anchored = true
		backWall.Size = Vector3.new(backWidth, BACK_WALL_HEIGHT, BACK_WALL_THICKNESS)
		backWall.CFrame = CFrame.fromMatrix(backPos, wallDir, Vector3.new(0, 1, 0))
		backWall.Color = WALL_COLOR
		backWall.Material = Enum.Material.SmoothPlastic
		backWall.CanCollide = true
		backWall.TopSurface = Enum.SurfaceType.Smooth
		backWall.BottomSurface = Enum.SurfaceType.Smooth
		backWall.Parent = parent

		-- 슬롯 중심 (칸막이 사이, 아크에서 +Z 방향으로)
		local slotX = backCenterX
		local slotZ = backCenterZ + TRAY_DEPTH * 0.4
		TableBuilder.slotPositions[zoneNum][i] = Vector3.new(slotX, floorY, slotZ)

		-- 슬롯 바닥
		local floorCenterZ = backCenterZ + TRAY_DEPTH / 2
		local slotFloor = Instance.new("Part")
		slotFloor.Name = "SlotFloor_" .. zoneNum .. "_" .. i
		slotFloor.Anchored = true
		slotFloor.Size = Vector3.new(backWidth - DIVIDER_THICKNESS, 0.15, TRAY_DEPTH - BACK_WALL_THICKNESS)
		slotFloor.CFrame = CFrame.fromMatrix(
			Vector3.new(backCenterX, floorY + 0.08, floorCenterZ),
			wallDir,
			Vector3.new(0, 1, 0)
		)
		slotFloor.Color = PLATFORM_COLOR
		slotFloor.Material = Enum.Material.SmoothPlastic
		slotFloor.CanCollide = true
		slotFloor.TopSurface = Enum.SurfaceType.Smooth
		slotFloor.BottomSurface = Enum.SurfaceType.Smooth
		slotFloor.Parent = parent

		-- 슬롯 라벨
		local lbl = Instance.new("Part")
		lbl.Name = "Label_" .. zoneNum .. "_" .. i
		lbl.Anchored = true
		lbl.Size = Vector3.new(0.1, 0.1, 0.1)
		lbl.Transparency = 1
		lbl.CanCollide = false
		lbl.Position = Vector3.new(slotX, floorY + 0.5, slotZ)
		lbl.Parent = parent

		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(0, 18, 0, 18)
		bb.StudsOffset = Vector3.new(0, 1.5, 0)
		bb.AlwaysOnTop = false
		bb.Parent = lbl

		local txt = Instance.new("TextLabel")
		txt.Size = UDim2.new(1, 0, 1, 0)
		txt.BackgroundTransparency = 1
		txt.Text = zoneConfig.LABELS[i]
		txt.TextColor3 = Color3.fromRGB(220, 215, 210)
		txt.TextScaled = true
		txt.Font = Enum.Font.GothamBold
		txt.Parent = bb
	end

	-- ===== 4) 존 번호 라벨 =====
	local zl = Instance.new("Part")
	zl.Anchored = true
	zl.Size = Vector3.new(0.1, 0.1, 0.1)
	zl.Transparency = 1
	zl.CanCollide = false
	zl.Position = Vector3.new(0, floorY + 1, centerZ)
	zl.Parent = parent

	local zbb = Instance.new("BillboardGui")
	zbb.Size = UDim2.new(0, 60, 0, 60)
	zbb.StudsOffset = Vector3.new(0, 0.5, 0)
	zbb.AlwaysOnTop = false
	zbb.Parent = zl

	local numLabel = Instance.new("TextLabel")
	numLabel.Size = UDim2.new(1, 0, 1, 0)
	numLabel.BackgroundTransparency = 1
	numLabel.Text = tostring(zoneNum)
	numLabel.TextColor3 = Color3.fromRGB(220, 80, 60)
	numLabel.TextScaled = true
	numLabel.Font = Enum.Font.GothamBlack
	numLabel.Parent = zbb
end

return TableBuilder
