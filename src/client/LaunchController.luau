local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local NUM_GUIDE_DOTS = 10
local GUIDE_DOT_SPACING = 2.5
local GUIDE_DOT_SIZE = 0.25

local LaunchController = {}
LaunchController.__index = LaunchController

--[[
	발사 플로우:
	1) 턴 시작 → 프리뷰 공 표시
	2) 프리뷰 공 좌클릭 → 즉시 게이지바 시작
	   - 홀드한 채 좌우 드래그 → 발사 위치(spawnX) 이동
	3) 좌클릭 릴리즈 → 발사
	4) 우클릭 → 취소
	5) Q/E → 스핀 조절
]]

function LaunchController.new(remotes, uiController)
	local self = setmetatable({}, LaunchController)
	self.remotes = remotes
	self.ui = uiController

	self.enabled = false
	self.charging = false
	self.power = 0
	self.aimAngle = 0
	self.spin = 0
	self.spinKeys = { left = false, right = false }
	self.chargeStartTime = 0
	self.chargeSpeed = 1.8
	self.spawnX = 0
	self.dragStartX = 0 -- 드래그 시작 시 마우스 X

	self.previewBall = nil
	self.guideDots = {}
	self.spawnY = Config.TABLE.HEIGHT + Config.TABLE.THICKNESS / 2 + Config.BALL.RADIUS + 0.2

	self:_createPreview()
	self:_setupInput()
	return self
end

function LaunchController:_getSpawnPos(): Vector3
	return Vector3.new(self.spawnX, self.spawnY, Config.LAUNCH.SPAWN_Z)
end

-- ===== 프리뷰 + 가이드 =====

function LaunchController:_createPreview()
	local preview = Instance.new("Part")
	preview.Name = "PreviewBall"
	preview.Shape = Enum.PartType.Ball
	preview.Size = Vector3.one * Config.BALL.RADIUS * 2
	preview.Color = Config.BALL.COLORS.RED
	preview.Material = Enum.Material.Marble
	preview.Transparency = 1
	preview.Anchored = true
	preview.CanCollide = false
	preview.CanQuery = true
	preview.CanTouch = false
	preview.Position = self:_getSpawnPos()
	preview.Parent = workspace
	self.previewBall = preview

	for i = 1, NUM_GUIDE_DOTS do
		local dot = Instance.new("Part")
		dot.Name = "GuideDot" .. i
		dot.Shape = Enum.PartType.Ball
		dot.Size = Vector3.one * GUIDE_DOT_SIZE
		dot.Color = Color3.fromRGB(255, 255, 255)
		dot.Material = Enum.Material.Neon
		dot.Transparency = 1
		dot.Anchored = true
		dot.CanCollide = false
		dot.CanQuery = false
		dot.CanTouch = false
		dot.Parent = workspace
		self.guideDots[i] = dot
	end
end

function LaunchController:_showPreview(visible: boolean)
	if self.previewBall then
		self.previewBall.Position = self:_getSpawnPos()
		self.previewBall.Transparency = visible and 0.35 or 1
	end
	if visible then
		self:_updateGuide()
	else
		for _, dot in self.guideDots do
			dot.Transparency = 1
		end
	end
end

function LaunchController:_updateGuide()
	local spawnPos = self:_getSpawnPos()
	local direction = Vector3.new(0, 0, 1).Unit
	local right = Vector3.new(1, 0, 0)

	-- 실제 물리와 일치하는 커브 계산
	-- 횡가속도 = spin * MAX_LATERAL_FORCE / mass
	-- 변위 = 0.5 * a * t², t = dist / speed
	local currentSpeed = Config.LAUNCH.MIN_POWER
		+ (Config.LAUNCH.MAX_POWER - Config.LAUNCH.MIN_POWER) * math.max(self.power, 0.1)
	local lateralAccel = self.spin * Config.SPIN.MAX_LATERAL_FORCE / 2 -- mass ≈ 2

	for i, dot in self.guideDots do
		local dist = GUIDE_DOT_SPACING * i
		local t = dist / currentSpeed
		local lateralOffset = 0.5 * lateralAccel * t * t
		local offset = direction * dist + right * lateralOffset
		dot.Position = spawnPos + offset
		dot.Transparency = 0.3 + (i / NUM_GUIDE_DOTS) * 0.5
	end
end

-- ===== 공 클릭 감지 =====

function LaunchController:_isClickOnPreview(screenPos: Vector3): boolean
	if not self.previewBall or self.previewBall.Transparency > 0.9 then
		return false
	end
	local camera = workspace.CurrentCamera
	-- 화면상 공 위치와 클릭 위치 비교
	local ballScreen, onScreen = camera:WorldToViewportPoint(self.previewBall.Position)
	if onScreen then
		local dist = ((screenPos.X - ballScreen.X) ^ 2 + (screenPos.Y - ballScreen.Y) ^ 2) ^ 0.5
		return dist < 80 -- 80px 이내 = 공 클릭으로 인정 (넉넉하게)
	end
	return false
end

-- ===== 입력 =====

function LaunchController:setEnabled(enabled: boolean)
	self.enabled = enabled
	self.charging = false
	self.power = 0
	self.aimAngle = 0
	self.spin = 0
	self.spawnX = 0

	if enabled then
		self:_showPreview(true)
	else
		self:_showPreview(false)
		if self.ui then
			self.ui:updatePowerGauge(0)
			self.ui:updateSpinIndicator(0)
		end
	end
end

function LaunchController:_setupInput()
	-- 좌클릭 = 공 클릭 → 즉시 차징 시작
	UserInputService.InputBegan:Connect(function(input, _gp)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			if not self.enabled or self.charging then return end

			if self:_isClickOnPreview(input.Position) then
				self.dragStartX = input.Position.X
				self:_startCharge()
			end
		end

		-- 우클릭 = 취소
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			if self.charging then
				self:_cancelCharge()
			end
		end

		-- Q/E = 스핀
		if input.KeyCode == Enum.KeyCode.Q then
			self.spinKeys.right = true
		elseif input.KeyCode == Enum.KeyCode.E then
			self.spinKeys.left = true
		end
	end)

	-- 스핀 키 해제
	UserInputService.InputEnded:Connect(function(input, _gp)
		if input.KeyCode == Enum.KeyCode.Q then
			self.spinKeys.right = false
		elseif input.KeyCode == Enum.KeyCode.E then
			self.spinKeys.left = false
		end
	end)

	-- 마우스 이동: 차징 중 → 좌우 드래그로 spawnX 이동
	UserInputService.InputChanged:Connect(function(input, _gp)
		if not self.charging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			self:_updateDrag(input.Position)
		end
	end)

	-- 좌클릭 릴리즈 = 발사
	UserInputService.InputEnded:Connect(function(input, _gp)
		if not self.charging then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			self:_release()
		end
	end)
end

-- ===== 차징 =====

function LaunchController:_startCharge()
	self.charging = true
	self.chargeStartTime = tick()

	if self.previewBall then
		self.previewBall.Transparency = 0.1
	end

	task.spawn(function()
		while self.charging do
			-- 파워 왕복
			local elapsed = tick() - self.chargeStartTime
			local raw = (elapsed * self.chargeSpeed) % 2
			if raw > 1 then raw = 2 - raw end
			self.power = raw

			if self.ui then
				self.ui:updatePowerGauge(raw)
			end

			-- 스핀 (Q/E)
			local spinDelta = 0
			if self.spinKeys.left then spinDelta -= Config.SPIN.CHANGE_SPEED * 0.016 end
			if self.spinKeys.right then spinDelta += Config.SPIN.CHANGE_SPEED * 0.016 end
			self.spin = math.clamp(self.spin + spinDelta, -1, 1)
			if self.ui then
				self.ui:updateSpinIndicator(self.spin)
			end

			-- 프리뷰 + 가이드 업데이트
			if self.previewBall then
				self.previewBall.Position = self:_getSpawnPos()
			end
			self:_updateGuide()

			task.wait()
		end
	end)
end

function LaunchController:_updateDrag(screenPos: Vector3)
	-- 좌우 드래그 → 발사 위치(spawnX) 이동
	local screenWidth = workspace.CurrentCamera.ViewportSize.X
	-- 마우스 화면 X → 월드 X 직접 매핑 (커서와 공이 같이 움직임)
	local camera = workspace.CurrentCamera
	local ray = camera:ViewportPointToRay(screenPos.X, screenPos.Y)
	-- 공 높이(spawnY)에서의 X 좌표 계산
	if ray.Direction.Y ~= 0 then
		local t = (self.spawnY - ray.Origin.Y) / ray.Direction.Y
		local worldX = ray.Origin.X + ray.Direction.X * t
		local xRange = Config.LAUNCH.SPAWN_X_RANGE
		self.spawnX = math.clamp(worldX, -xRange, xRange)
	end
end

function LaunchController:_cancelCharge()
	self.charging = false
	self.power = 0
	self.spawnX = 0
	self:_showPreview(true)
	if self.ui then
		self.ui:updatePowerGauge(0)
	end
end

function LaunchController:_release()
	if not self.charging then return end
	self.charging = false

	local finalPower = Config.LAUNCH.MIN_POWER
		+ (Config.LAUNCH.MAX_POWER - Config.LAUNCH.MIN_POWER) * self.power

	-- 방향: 직진 (에임 각도는 spawnX로 대체)
	local direction = Vector3.new(0, 0, 1).Unit

	self:_showPreview(false)

	self.remotes.RequestLaunch:FireServer(direction, finalPower, self.spin, self.spawnX)

	self.power = 0
	self.aimAngle = 0
	self.spin = 0
	self.spawnX = 0
	if self.ui then
		self.ui:updatePowerGauge(0)
		self.ui:updateSpinIndicator(0)
	end

	self.enabled = false
end

return LaunchController
