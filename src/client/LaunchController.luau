local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local NUM_GUIDE_DOTS = 10
local GUIDE_DOT_SPACING = 2.5
local GUIDE_DOT_SIZE = 0.25

local LaunchController = {}
LaunchController.__index = LaunchController

function LaunchController.new(remotes, uiController)
	local self = setmetatable({}, LaunchController)
	self.remotes = remotes
	self.ui = uiController
	self.enabled = false
	self.charging = false
	self.power = 0
	self.aimAngle = 0
	self.spin = 0 -- -1(왼쪽 스핀) ~ 1(오른쪽 스핀)
	self.spinKeys = { left = false, right = false }
	self.chargeStartTime = 0
	self.chargeSpeed = 1.8

	-- 프리뷰 공 + 방향 가이드
	self.previewBall = nil
	self.guideDots = {}
	self.spawnPos = nil

	self:_createPreview()
	self:_setupInput()
	return self
end

-- ===== 프리뷰 공 + 궤적 가이드 생성 =====

function LaunchController:_createPreview()
	local spawnY = Config.TABLE.HEIGHT + Config.TABLE.THICKNESS / 2 + Config.BALL.RADIUS + 0.2
	self.spawnPos = Vector3.new(0, spawnY, Config.LAUNCH.SPAWN_Z)

	-- 프리뷰 공 (반투명 빨간 공)
	local preview = Instance.new("Part")
	preview.Name = "PreviewBall"
	preview.Shape = Enum.PartType.Ball
	preview.Size = Vector3.one * Config.BALL.RADIUS * 2
	preview.Color = Config.BALL.COLORS.RED
	preview.Material = Enum.Material.SmoothPlastic
	preview.Transparency = 0.4
	preview.Anchored = true
	preview.CanCollide = false
	preview.CanQuery = false
	preview.CanTouch = false
	preview.Position = self.spawnPos
	preview.Transparency = 1
	preview.Parent = workspace
	self.previewBall = preview

	-- 방향 가이드 도트들
	for i = 1, NUM_GUIDE_DOTS do
		local dot = Instance.new("Part")
		dot.Name = "GuideDot" .. i
		dot.Shape = Enum.PartType.Ball
		dot.Size = Vector3.one * GUIDE_DOT_SIZE
		dot.Color = Color3.fromRGB(255, 255, 255)
		dot.Material = Enum.Material.Neon
		dot.Transparency = 0.3 + (i / NUM_GUIDE_DOTS) * 0.5 -- 멀수록 연해짐
		dot.Anchored = true
		dot.CanCollide = false
		dot.CanQuery = false
		dot.CanTouch = false
		dot.Transparency = 1
		dot.Parent = workspace
		self.guideDots[i] = dot
	end
end

function LaunchController:_showPreview(visible: boolean)
	if self.previewBall then
		self.previewBall.Position = self.spawnPos
		-- Part에는 Visible이 없으므로 Transparency로 제어
		self.previewBall.Transparency = visible and 0.4 or 1
	end
	for _, dot in self.guideDots do
		dot.Transparency = visible and 0.3 or 1
	end
end

function LaunchController:_updateGuide()
	if not self.spawnPos then return end

	-- 현재 에임 방향 계산
	local angle = self.aimAngle * math.rad(40)
	local direction = Vector3.new(math.sin(angle), 0, math.cos(angle)).Unit

	-- 도트를 발사 방향 + 스핀 커브를 따라 배치
	for i, dot in self.guideDots do
		local dist = GUIDE_DOT_SPACING * i
		-- 스핀에 따라 횡방향 오프셋 (포물선 커브)
		local lateralOffset = self.spin * (dist * dist) * 0.02
		local right = Vector3.new(direction.Z, 0, -direction.X) -- 직교 방향
		local offset = direction * dist + right * lateralOffset
		dot.Position = self.spawnPos + offset
		dot.Transparency = 0.3 + (i / NUM_GUIDE_DOTS) * 0.5
	end
end

-- ===== 입력 처리 =====

function LaunchController:setEnabled(enabled: boolean)
	self.enabled = enabled
	if enabled then
		-- 턴 시작: 프리뷰 공 + 가이드 표시
		self.aimAngle = 0
		self:_showPreview(true)
		self:_updateGuide()
	else
		-- 턴 끝: 숨기기
		self.charging = false
		self.power = 0
		self:_showPreview(false)
		if self.ui then
			self.ui:updatePowerGauge(0)
		end
	end
end

function LaunchController:_setupInput()
	-- 마우스/터치: 차징 시작
	UserInputService.InputBegan:Connect(function(input, _gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			if not self.enabled then return end
			self:_startCharge(input.Position)
		end

		-- A/D 또는 ←/→ 키로 스핀 조절
		if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
			self.spinKeys.left = true
		elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
			self.spinKeys.right = true
		end
	end)

	-- 스핀 키 해제
	UserInputService.InputEnded:Connect(function(input, _gameProcessed)
		if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
			self.spinKeys.left = false
		elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
			self.spinKeys.right = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input, _gameProcessed)
		if not self.charging then return end

		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			self:_updateAim(input.Position)
		end
	end)

	UserInputService.InputEnded:Connect(function(input, _gameProcessed)
		if not self.charging then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			self:_release()
		end
	end)
end

function LaunchController:_startCharge(screenPos: Vector3)
	self.charging = true
	self.chargeStartTime = tick()
	self.startScreenPos = screenPos
	self.aimAngle = 0

	-- 차징 중 프리뷰 공을 약간 밝게
	if self.previewBall then
		self.previewBall.Transparency = 0.15
	end

	task.spawn(function()
		while self.charging do
			local elapsed = tick() - self.chargeStartTime
			local raw = (elapsed * self.chargeSpeed) % 2
			if raw > 1 then
				raw = 2 - raw
			end
			self.power = raw

			if self.ui then
				self.ui:updatePowerGauge(raw)
			end

			-- 스핀 업데이트 (A/D 키)
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

	-- 프리뷰 + 가이드 숨기기
	self:_showPreview(false)

	-- 서버에 발사 요청 (스핀 포함)
	self.remotes.RequestLaunch:FireServer(direction, finalPower, self.spin)

	-- 리셋
	self.power = 0
	self.aimAngle = 0
	self.spin = 0
	if self.ui then
		self.ui:updatePowerGauge(0)
	end

	self.enabled = false
end

return LaunchController
