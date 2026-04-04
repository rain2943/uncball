local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local NUM_GUIDE_DOTS = 20
local GUIDE_DOT_SIZE = 0.22
local PULLBACK_PX_FOR_MAX = 100 -- 조금만 당겨도 MAX (매우 민감)
local SPIN_SENSITIVITY = 0.012 -- 좌우 조금만 움직여도 크게 꺾임

local LaunchController = {}
LaunchController.__index = LaunchController

--[[
	슬링샷 발사:

	IDLE      → 턴 아님
	READY     → 프리뷰 공 표시, 클릭 대기
	POSITION  → 공 클릭됨, 좌우 드래그로 위치 조정
	AIMING    → 뒤로 당기기 시작, 파워+스핀 조정
	           파워: 얼마나 뒤로 당겼나 (화면 아래로)
	           스핀: 좌우로 얼마나 틀었나 + Q/E 키
	           가이드: 공 앞 바닥에 파워+스핀 반영된 궤적선
	(release) → 발사
]]

function LaunchController.new(remotes, uiController)
	local self = setmetatable({}, LaunchController)
	self.remotes = remotes
	self.ui = uiController
	self.cameraController = nil -- init.client에서 설정

	self.state = "IDLE"
	self.power = 0
	self.spin = 0
	self.spawnX = 0
	self.spinKeys = { left = false, right = false }

	-- 드래그 추적
	self.clickScreenPos = nil -- 최초 클릭 위치
	self.aimStartPos = nil -- AIMING 시작 시점 위치 (스핀 기준점)
	self.currentScreenPos = nil

	-- 프리뷰 공 + 가이드
	self.previewBall = nil
	self.guideDots = {}
	self.spawnY = Config.TABLE.HEIGHT + Config.TABLE.THICKNESS / 2 + Config.BALL.RADIUS + 0.2

	self:_createPreview()
	self:_setupInput()
	self:_startUpdateLoop()
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
	self:_hideGuide()
end

function LaunchController:_hideGuide()
	for _, dot in self.guideDots do
		dot.Transparency = 1
	end
end

function LaunchController:_updateGuide()
	if self.power <= 0.02 then
		self:_hideGuide()
		return
	end

	local spawnPos = self:_getSpawnPos()
	local currentPower = Config.LAUNCH.MIN_POWER + (Config.LAUNCH.MAX_POWER - Config.LAUNCH.MIN_POWER) * self.power

	local direction = Vector3.new(0, 0, 1)
	local right = Vector3.new(1, 0, 0)

	-- 실제 물리 파라미터
	local mass = 2
	local lateralAccel = self.spin * Config.SPIN.MAX_LATERAL_FORCE / mass
	local inclineDecel = Config.INCLINE_FORCE -- -Z 방향 감속

	-- 가이드 길이: 파워에 비례하되 짧게 (정밀 조정 가능하게)
	local maxDist = self.power * 20 -- 0~20 studs (MAX에서 20)

	for i, dot in self.guideDots do
		local t_ratio = i / NUM_GUIDE_DOTS
		local dist = maxDist * t_ratio

		-- 시간 = 거리 / 속도 (감속 고려한 근사)
		local avgSpeed = currentPower * (1 - t_ratio * 0.5)
		local time = dist / math.max(avgSpeed, 1)

		-- 스핀 횡변위: 0.5 * a * t²
		local lateralOffset = 0.5 * lateralAccel * time * time

		local pos = spawnPos + direction * dist + right * lateralOffset
		dot.Position = Vector3.new(pos.X, self.spawnY - Config.BALL.RADIUS + 0.1, pos.Z)

		local colorT = t_ratio * self.power
		dot.Color = Color3.fromRGB(
			math.floor(80 + 175 * colorT),
			math.floor(220 - 180 * colorT),
			80
		)
		dot.Transparency = 0.15 + t_ratio * 0.5
	end
end

-- ===== 화면→월드 =====

function LaunchController:_screenToWorldPos(screenX: number, screenY: number): Vector3
	local camera = workspace.CurrentCamera
	local ray = camera:ScreenPointToRay(screenX, screenY)
	if math.abs(ray.Direction.Y) < 0.001 then
		return Vector3.new(0, self.spawnY, Config.LAUNCH.SPAWN_Z)
	end
	local t = (self.spawnY - ray.Origin.Y) / ray.Direction.Y
	local worldX = ray.Origin.X + ray.Direction.X * t
	local worldZ = ray.Origin.Z + ray.Direction.Z * t
	return Vector3.new(worldX, self.spawnY, worldZ)
end

-- ===== 공 클릭 감지 =====

function LaunchController:_isClickOnPreview(screenPos: Vector3): boolean
	if not self.previewBall or self.previewBall.Transparency > 0.9 then
		return false
	end
	local camera = workspace.CurrentCamera
	local ballScreen, onScreen = camera:WorldToViewportPoint(self.previewBall.Position)
	if onScreen then
		local dist = ((screenPos.X - ballScreen.X) ^ 2 + (screenPos.Y - ballScreen.Y) ^ 2) ^ 0.5
		return dist < 80
	end
	return false
end

-- ===== 입력 =====

function LaunchController:setEnabled(enabled: boolean)
	if enabled then
		self.state = "READY"
		self.power = 0
		self.spin = 0
		self.spawnX = 0
		self:_showPreview(true)
	else
		self.state = "IDLE"
		self.power = 0
		self.spin = 0
		self:_showPreview(false)
		if self.ui then
			self.ui:updateSpinIndicator(0)
		end
	end
end

function LaunchController:_setupInput()
	UserInputService.InputBegan:Connect(function(input, _gp)
		-- 좌클릭/터치: 공 클릭
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			if self.state == "READY" and self:_isClickOnPreview(input.Position) then
				self.state = "POSITION"
				self.clickScreenPos = input.Position
				self.currentScreenPos = input.Position
				if self.previewBall then
					self.previewBall.Transparency = 0.1
				end
			end
		end

		-- 우클릭/ESC: 취소
		if input.UserInputType == Enum.UserInputType.MouseButton2
			or input.KeyCode == Enum.KeyCode.Escape then
			if self.state == "POSITION" or self.state == "AIMING" then
				self.state = "READY"
				self.power = 0
				self.spin = 0
				self:_showPreview(true)
				if self.ui then self.ui:updateSpinIndicator(0) end
			end
		end

		-- Q/E: 스핀 (에이밍 중)
		if input.KeyCode == Enum.KeyCode.Q then
			self.spinKeys.left = true
		elseif input.KeyCode == Enum.KeyCode.E then
			self.spinKeys.right = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input, _gp)
		if input.KeyCode == Enum.KeyCode.Q then
			self.spinKeys.left = false
		elseif input.KeyCode == Enum.KeyCode.E then
			self.spinKeys.right = false
		end

		-- 좌클릭 릴리즈 = 발사
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			if self.state == "AIMING" and self.power > 0.05 then
				self:_launch()
			elseif self.state == "POSITION" or self.state == "AIMING" then
				-- 파워 없이 놓으면 취소
				self.state = "READY"
				self.power = 0
				self.spin = 0
				self:_showPreview(true)
			end
		end
	end)

	UserInputService.InputChanged:Connect(function(input, _gp)
		if self.state ~= "POSITION" and self.state ~= "AIMING" then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then return end

		self.currentScreenPos = input.Position

		if not self.clickScreenPos then return end

		local dx = input.Position.X - self.clickScreenPos.X
		local dy = input.Position.Y - self.clickScreenPos.Y

		-- 세로(dy)로 모드 판단: 30px 이상 당기면 AIMING, 아니면 POSITION
		if dy > 30 then
			if self.state ~= "AIMING" then
				self.state = "AIMING"
				-- AIMING 진입 시 현재 위치를 스핀 기준점으로 저장
				self.aimStartPos = input.Position
			end
			-- 세로: 파워 (스크린 Y 기준, 아래로 당길수록 강하게)
			local pullback = math.max(dy - 30, 0)
			self.power = math.clamp(pullback / PULLBACK_PX_FOR_MAX, 0, 1)
			-- 가로: 스핀 (스크린 X 기준, AIMING 시작점 대비)
			local screenDx = input.Position.X - self.aimStartPos.X
			self.spin = math.clamp(-screenDx * SPIN_SENSITIVITY, -1, 1)
		else
			-- 당기지 않은 상태 → 위치 조정 모드
			self.state = "POSITION"
			self.power = 0
			self.spin = 0
			self.aimStartPos = nil
			self:_hideGuide()

			local worldPos = self:_screenToWorldPos(input.Position.X, input.Position.Y)
			local xRange = Config.LAUNCH.SPAWN_X_RANGE
			self.spawnX = math.clamp(worldPos.X, -xRange, xRange)
			if self.previewBall then
				self.previewBall.Position = self:_getSpawnPos()
			end
			-- 카메라도 따라감
			if self.cameraController then
				self.cameraController:setLaunchFollowX(self.spawnX)
			end
		end
	end)
end

-- ===== 발사 =====

function LaunchController:_launch()
	local finalPower = Config.LAUNCH.MIN_POWER + (Config.LAUNCH.MAX_POWER - Config.LAUNCH.MIN_POWER) * self.power
	local direction = Vector3.new(0, 0, 1).Unit
	local spawnX = self.spawnX

	self:_showPreview(false)
	self:_hideGuide()
	self.state = "IDLE"

	self.remotes.RequestLaunch:FireServer(direction, finalPower, self.spin, spawnX)

	self.power = 0
	self.spin = 0
	self.spawnX = 0
	if self.ui then
		self.ui:updateSpinIndicator(0)
	end
end

-- ===== 매 프레임 업데이트 =====

function LaunchController:_startUpdateLoop()
	RunService.RenderStepped:Connect(function(_dt)
		-- 에이밍 중: Q/E 스핀 + 가이드 업데이트
		if self.state == "AIMING" then
			local spinDelta = 0
			if self.spinKeys.left then spinDelta -= Config.SPIN.CHANGE_SPEED * 0.016 end
			if self.spinKeys.right then spinDelta += Config.SPIN.CHANGE_SPEED * 0.016 end
			if spinDelta ~= 0 then
				self.spin = math.clamp(self.spin + spinDelta, -1, 1)
			end

			if self.ui then
				self.ui:updateSpinIndicator(self.spin, self.power)
			end

			self:_updateGuide()
		end
	end)
end

return LaunchController
