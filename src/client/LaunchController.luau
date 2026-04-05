local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local NUM_GUIDE_DOTS = 20
local GUIDE_DOT_SIZE = 0.22
local PULLBACK_PX_FOR_MAX = 100 -- 조금만 당겨도 MAX (매우 민감)
local SPIN_SENSITIVITY = 0.006 -- 정밀 스핀 컨트롤
local TIMING_SPEED_MIN = 12 -- 파워 0%일 때 속도
local TIMING_SPEED_MAX = 45 -- 파워 100%일 때 속도

-- 타이밍 등급 기본값 (파워 100%일 때)
local TIMING_GRADES_BASE = {
	{ maxDist = 1.0, name = "Perfect!", color = Color3.fromRGB(0, 255, 80), powerMult = 1.0, aimError = 0 },
	{ maxDist = 3.0, name = "Great!", color = Color3.fromRGB(80, 220, 60), powerMult = 1.0, aimError = 0.2 },
	{ maxDist = 5.5, name = "Good", color = Color3.fromRGB(255, 220, 40), powerMult = 0.97, aimError = 1.5 },
	{ maxDist = 7.5, name = "Bad", color = Color3.fromRGB(255, 140, 30), powerMult = 0.92, aimError = 3.0 },
	{ maxDist = 10, name = "Miss", color = Color3.fromRGB(255, 50, 40), powerMult = 0.8, aimError = 5.0 },
}

-- 파워에 따라 구간 확대 배율 계산 (낮을수록 초록 넓어짐)
local function getTimingScale(power: number): number
	-- power 0 → 2.5배 넓은 구간, power 1 → 1배 (기본)
	return 1 + (1 - power) * 1.5
end

-- 도트별 색상 (파워 반영, 낮을수록 초록 구간 넓음)
local function getTimingDotColor(dotIndex: number, power: number): Color3
	local dist = math.abs(dotIndex - 10.5)
	local scale = getTimingScale(power)
	if dist <= 1.0 * scale then
		return Color3.fromRGB(0, 255, 80) -- 정중앙 초록
	elseif dist <= 3.0 * scale then
		return Color3.fromRGB(80, 220, 60) -- 초록
	elseif dist <= 5.5 * scale then
		return Color3.fromRGB(255, 220, 40) -- 노랑
	elseif dist <= 7.5 * scale then
		return Color3.fromRGB(255, 140, 30) -- 주황
	else
		return Color3.fromRGB(255, 50, 40) -- 빨강
	end
end

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

	-- PvP 프리뷰 전송 쓰로틀
	self._lastPreviewSend = 0
	self._lastSentX = nil

	-- 타이밍 커서
	self.timingPos = 0 -- 0~(NUM_GUIDE_DOTS*2) 왕복 위치
	self.timingDirection = 1 -- 1=전진, -1=후진
	self.timingCursor = nil

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
	preview.Color = self.teamColor or Config.BALL.COLORS.RED
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

	-- 타이밍 커서 (하얀 빛나는 도트, 약간 큼)
	local cursor = Instance.new("Part")
	cursor.Name = "TimingCursor"
	cursor.Shape = Enum.PartType.Ball
	cursor.Size = Vector3.one * (GUIDE_DOT_SIZE * 2.2)
	cursor.Material = Enum.Material.Neon
	cursor.Color = Color3.fromRGB(255, 255, 255)
	cursor.Transparency = 1
	cursor.Anchored = true
	cursor.CanCollide = false
	cursor.CanQuery = false
	cursor.CanTouch = false
	cursor.Parent = workspace
	self.timingCursor = cursor
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
	if self.timingCursor then
		self.timingCursor.Transparency = 1
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
	local lateralAccel = self.spin * Config.SPIN.MAX_LATERAL_FORCE / mass * 2.5 -- 가이드 커브 과장 (실제 물리보다 크게 보여줌)
	local inclineDecel = Config.INCLINE_FORCE -- -Z 방향 감속

	-- 가이드 길이: 파워에 비례하되 짧게 (정밀 조정 가능하게)
	local maxDist = self.power * 20 -- 0~20 studs (MAX에서 20)

	local dotPositions = {}

	for i, dot in self.guideDots do
		local t_ratio = i / NUM_GUIDE_DOTS
		local dist = maxDist * t_ratio

		-- 시간 = 거리 / 속도 (감속 고려한 근사)
		local avgSpeed = currentPower * (1 - t_ratio * 0.5)
		local time = dist / math.max(avgSpeed, 1)

		-- 스핀 횡변위: 0.5 * a * t²
		local lateralOffset = 0.5 * lateralAccel * time * time

		local pos = spawnPos + direction * dist + right * lateralOffset
		local dotPos = Vector3.new(pos.X, self.spawnY - Config.BALL.RADIUS + 0.1, pos.Z)
		dot.Position = dotPos
		dotPositions[i] = dotPos

		-- 타이밍 구간 색상 (중심=초록, 양끝=빨강)
		dot.Color = getTimingDotColor(i, self.power)
		dot.Transparency = 0.25
	end

	-- 타이밍 커서 위치 업데이트
	if self.timingCursor and #dotPositions > 0 then
		local cursorIdx = math.clamp(math.floor(self.timingPos + 0.5), 1, NUM_GUIDE_DOTS)
		self.timingCursor.Position = dotPositions[cursorIdx] + Vector3.new(0, 0.15, 0)
		self.timingCursor.Transparency = 0

		-- 커서가 올라탄 도트를 강조 (약간 키우기)
		for i, dot in self.guideDots do
			if i == cursorIdx then
				dot.Size = Vector3.one * (GUIDE_DOT_SIZE * 1.5)
				dot.Transparency = 0
			else
				dot.Size = Vector3.one * GUIDE_DOT_SIZE
			end
		end
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

function LaunchController:setTeamColor(color: Color3)
	self.teamColor = color
	if self.previewBall then
		self.previewBall.Color = color
	end
end

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
				-- 타이밍 커서 시작
				self.timingPos = 1
				self.timingDirection = 1
			end
			-- 세로: 파워 (스크린 Y 기준, 아래로 당길수록 강하게)
			local pullback = math.max(dy - 30, 0)
			self.power = math.clamp(pullback / PULLBACK_PX_FOR_MAX, 0, 1)
			-- 가로: 스핀 (스크린 X 기준, AIMING 시작점 대비)
			-- 데드존 20px: 좌우 미세 흔들림 무시
			local screenDx = input.Position.X - self.aimStartPos.X
			local deadzone = 20
			if math.abs(screenDx) < deadzone then
				screenDx = 0
			else
				screenDx = screenDx - (screenDx > 0 and deadzone or -deadzone)
			end
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
			-- PvP: 상대에게 위치 전송 (0.1초 쓰로틀)
			local now = tick()
			if now - self._lastPreviewSend > 0.1 and self._lastSentX ~= self.spawnX then
				self._lastPreviewSend = now
				self._lastSentX = self.spawnX
				self.remotes.PreviewUpdate:FireServer(self.spawnX)
			end
		end
	end)
end

-- ===== 발사 =====

function LaunchController:_evaluateTiming(): (string, Color3, number, number)
	local cursorIdx = math.clamp(math.floor(self.timingPos + 0.5), 1, NUM_GUIDE_DOTS)
	local dist = math.abs(cursorIdx - 10.5)
	local scale = getTimingScale(self.power)
	for _, grade in TIMING_GRADES_BASE do
		if dist <= grade.maxDist * scale then
			return grade.name, grade.color, grade.powerMult, grade.aimError
		end
	end
	local last = TIMING_GRADES_BASE[#TIMING_GRADES_BASE]
	return last.name, last.color, last.powerMult, last.aimError
end

function LaunchController:_launch()
	-- 타이밍 판정
	local gradeName, gradeColor, powerMult, aimError = self:_evaluateTiming()

	local finalPower = Config.LAUNCH.MIN_POWER + (Config.LAUNCH.MAX_POWER - Config.LAUNCH.MIN_POWER) * self.power
	finalPower = finalPower * powerMult

	-- 타이밍에 따른 방향 오차
	local dirX = 0
	if aimError > 0 then
		dirX = (math.random() - 0.5) * aimError
	end
	local direction = Vector3.new(dirX, 0, 1).Unit
	local spawnX = self.spawnX

	self:_showPreview(false)
	self:_hideGuide()
	self.state = "IDLE"

	-- 턴 타이머 즉시 숨기기
	if self.ui and self.ui.hideTurnTimer then
		self.ui:hideTurnTimer()
	end

	-- 타이밍 커서 리셋
	self.timingPos = 1
	self.timingDirection = 1

	self.remotes.RequestLaunch:FireServer(direction, finalPower, self.spin, spawnX)

	-- 발사 SFX (즉시 재생)
	local launchSfx = Instance.new("Sound")
	launchSfx.SoundId = "rbxassetid://121730291891328"
	launchSfx.Volume = 0.5
	launchSfx.Parent = workspace
	launchSfx:Play()
	launchSfx.Ended:Once(function() launchSfx:Destroy() end)

	-- 타이밍 등급 팝업
	if self.ui then
		self.ui:showTimingGrade(gradeName, gradeColor)
	end

	self.power = 0
	self.spin = 0
	self.spawnX = 0
	if self.ui then
		self.ui:updateSpinIndicator(0)
	end
end

-- ===== 매 프레임 업데이트 =====

function LaunchController:_startUpdateLoop()
	RunService.RenderStepped:Connect(function(dt)
		-- 에이밍 중: Q/E 스핀 + 가이드 + 타이밍 커서 업데이트
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

			-- 타이밍 커서 왕복 이동 (파워 비례 속도)
			local timingSpeed = TIMING_SPEED_MIN + (TIMING_SPEED_MAX - TIMING_SPEED_MIN) * self.power
			self.timingPos = self.timingPos + self.timingDirection * timingSpeed * dt
			if self.timingPos >= NUM_GUIDE_DOTS then
				self.timingPos = NUM_GUIDE_DOTS
				self.timingDirection = -1
			elseif self.timingPos <= 1 then
				self.timingPos = 1
				self.timingDirection = 1
			end

			self:_updateGuide()
		end
	end)
end

return LaunchController
