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
	1) 턴 시작 → 프리뷰 공 표시 (위치 이동 가능)
	2) 프리뷰 공 좌클릭 → 게이지바 시작, 좌우 드래그로 에임
	3) 좌클릭 릴리즈 → 발사
	4) 우클릭 → 취소, 프리뷰 상태로 복귀
	5) 턴 제한시간 10초 (서버에서 관리)
]]

function LaunchController.new(remotes, uiController)
	local self = setmetatable({}, LaunchController)
	self.remotes = remotes
	self.ui = uiController

	-- 상태
	self.enabled = false -- 턴 활성화
	self.aiming = false -- 프리뷰 공 위치 조정 중
	self.charging = false -- 게이지 차징 중
	self.power = 0
	self.aimAngle = 0
	self.spin = 0
	self.spinKeys = { left = false, right = false }
	self.chargeStartTime = 0
	self.chargeSpeed = 1.8
	self.spawnX = 0 -- 발사 X 위치 (좌우 이동)

	-- 프리뷰 공 + 가이드
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
	preview.CanQuery = true -- 클릭 감지용
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
	local angle = self.aimAngle * math.rad(40)
	local direction = Vector3.new(math.sin(angle), 0, math.cos(angle)).Unit
	local right = Vector3.new(direction.Z, 0, -direction.X)

	for i, dot in self.guideDots do
		local dist = GUIDE_DOT_SPACING * i
		local lateralOffset = self.spin * (dist * dist) * 0.06
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
	local ray = camera:ViewportPointToRay(screenPos.X, screenPos.Y)
	local raycast = workspace:Raycast(ray.Origin, ray.Direction * 200)
	if raycast and raycast.Instance == self.previewBall then
		return true
	end
	-- 폴백: 화면 거리 체크
	local ballScreen, onScreen = camera:WorldToViewportPoint(self.previewBall.Position)
	if onScreen then
		local dist = ((screenPos.X - ballScreen.X) ^ 2 + (screenPos.Y - ballScreen.Y) ^ 2) ^ 0.5
		return dist < 60 -- 60px 이내 클릭
	end
	return false
end

-- ===== 입력 =====

function LaunchController:setEnabled(enabled: boolean)
	self.enabled = enabled
	self.aiming = false
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
	-- 좌클릭
	UserInputService.InputBegan:Connect(function(input, _gp)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			if not self.enabled then return end

			if not self.charging then
				-- 공을 클릭했는지 확인
				if self:_isClickOnPreview(input.Position) then
					self:_startCharge(input.Position)
				end
			end
		end

		-- 우클릭 = 취소
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			if self.charging then
				self:_cancelCharge()
			end
		end

		-- 스핀 키
		if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
			self.spinKeys.left = true
		elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
			self.spinKeys.right = true
		end

		-- Q/E로 발사 위치 좌우 이동 (프리뷰 상태에서)
		if self.enabled and not self.charging then
			local xRange = Config.LAUNCH.SPAWN_X_RANGE
			if input.KeyCode == Enum.KeyCode.Q then
				self.spawnX = math.clamp(self.spawnX - 1.5, -xRange, xRange)
				self:_showPreview(true)
			elseif input.KeyCode == Enum.KeyCode.E then
				self.spawnX = math.clamp(self.spawnX + 1.5, -xRange, xRange)
				self:_showPreview(true)
			end
		end
	end)

	-- 스핀 키 해제
	UserInputService.InputEnded:Connect(function(input, _gp)
		if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
			self.spinKeys.left = false
		elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
			self.spinKeys.right = false
		end
	end)

	-- 마우스 이동 (차징 중 에임)
	UserInputService.InputChanged:Connect(function(input, _gp)
		if not self.charging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			self:_updateAim(input.Position)
		end
	end)

	-- 좌클릭 릴리즈 → 발사
	UserInputService.InputEnded:Connect(function(input, _gp)
		if not self.charging then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			self:_release()
		end
	end)
end

-- ===== 차징 =====

function LaunchController:_startCharge(screenPos: Vector3)
	self.charging = true
	self.chargeStartTime = tick()
	self.startScreenPos = screenPos
	self.aimAngle = 0

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

			-- 스핀
			local spinDelta = 0
			if self.spinKeys.left then spinDelta -= Config.SPIN.CHANGE_SPEED * 0.016 end
			if self.spinKeys.right then spinDelta += Config.SPIN.CHANGE_SPEED * 0.016 end
			self.spin = math.clamp(self.spin + spinDelta, -1, 1)
			if self.ui then
				self.ui:updateSpinIndicator(self.spin)
			end

			self:_updateGuide()
			task.wait()
		end
	end)
end

function LaunchController:_cancelCharge()
	self.charging = false
	self.power = 0
	self.aimAngle = 0

	-- 프리뷰 상태로 복귀
	self:_showPreview(true)
	if self.ui then
		self.ui:updatePowerGauge(0)
	end
end

function LaunchController:_updateAim(screenPos: Vector3)
	if not self.startScreenPos then return end
	local screenWidth = workspace.CurrentCamera.ViewportSize.X
	local deltaX = (screenPos.X - self.startScreenPos.X) / screenWidth
	self.aimAngle = math.clamp(deltaX * 8, -1, 1)
end

function LaunchController:_release()
	if not self.charging then return end
	self.charging = false

	local finalPower = Config.LAUNCH.MIN_POWER
		+ (Config.LAUNCH.MAX_POWER - Config.LAUNCH.MIN_POWER) * self.power

	local angle = self.aimAngle * math.rad(40)
	local direction = Vector3.new(math.sin(angle), 0, math.cos(angle)).Unit

	self:_showPreview(false)

	-- 서버에 발사 요청 (방향, 파워, 스핀, 발사 X위치)
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
