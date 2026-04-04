local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CameraController = {}
CameraController.__index = CameraController

--[[
	카메라 상태:
	OVERVIEW     → 전체 조감도 (AI 턴, 턴 사이)
	LAUNCH_VIEW  → 낮은 각도 발사 뷰 (플레이어 턴)
	LAUNCH_DELAY → 발사 직후 잠시 현재 뷰 유지
	TRACKING     → 공 추적
	LANDING_FOCUS → 착지 클로즈업
	RETURNING    → OVERVIEW로 복귀 중
]]

function CameraController.new()
	local self = setmetatable({}, CameraController)
	self.camera = workspace.CurrentCamera
	self.trackedBall = nil
	self.state = "OVERVIEW"
	self.landingHoldStart = 0
	self.launchDelayStart = 0

	self.overviewCF = CFrame.lookAt(Config.CAMERA.OVERVIEW_OFFSET, Config.CAMERA.OVERVIEW_LOOK_AT)
	self.launchCF = CFrame.lookAt(Config.CAMERA.LAUNCH_OFFSET, Config.CAMERA.LAUNCH_LOOK_AT)

	self:_forceScriptable()
	self.camera.CFrame = self.overviewCF

	self.renderConn = RunService.RenderStepped:Connect(function(dt)
		self:_forceScriptable()
		self:_update(dt)
	end)

	return self
end

function CameraController:_forceScriptable()
	if self.camera.CameraType ~= Enum.CameraType.Scriptable then
		self.camera.CameraType = Enum.CameraType.Scriptable
	end
	self.camera.CameraSubject = nil
end

-- 플레이어 턴: 발사 뷰로 전환
function CameraController:enterLaunchView()
	-- 어떤 상태에서든 발사 뷰로 전환 가능
	self.state = "LAUNCH_VIEW"
	self.trackedBall = nil
end

-- AI 턴 또는 추적 끝: 조감도로 복귀
function CameraController:returnToOverview()
	self.state = "RETURNING"
	self.trackedBall = nil
end

-- 공 발사됨: 추적 시작 (딜레이 후)
function CameraController:trackBall(ball: Part?)
	self.trackedBall = ball
	if ball then
		self.state = "LAUNCH_DELAY"
		self.launchDelayStart = tick()
		self.landingHoldStart = 0
	end
end

function CameraController:_update(dt: number)
	if self.state == "OVERVIEW" then
		self.camera.CFrame = self.camera.CFrame:Lerp(self.overviewCF, math.min(dt * 3, 1))

	elseif self.state == "LAUNCH_VIEW" then
		self.camera.CFrame = self.camera.CFrame:Lerp(self.launchCF, math.min(dt * Config.CAMERA.LAUNCH_TRANSITION_SPEED, 1))

	elseif self.state == "LAUNCH_DELAY" then
		-- 발사 직후 현재 뷰 잠시 유지
		if tick() - self.launchDelayStart > 0.4 then
			self.state = "TRACKING"
		end

	elseif self.state == "TRACKING" then
		self:_updateTracking(dt)

	elseif self.state == "LANDING_FOCUS" then
		self:_updateLandingFocus(dt)

	elseif self.state == "RETURNING" then
		self.camera.CFrame = self.camera.CFrame:Lerp(self.overviewCF, math.min(dt * Config.CAMERA.RETURN_SPEED, 1))
		local diff = (self.camera.CFrame.Position - self.overviewCF.Position).Magnitude
		if diff < 0.5 then
			self.camera.CFrame = self.overviewCF
			self.state = "OVERVIEW"
		end
	end
end

function CameraController:_updateTracking(dt: number)
	local ball = self.trackedBall
	if not ball or not ball.Parent then
		self.state = "RETURNING"
		self.trackedBall = nil
		return
	end

	local ballPos = ball.Position
	local speed = ball.AssemblyLinearVelocity.Magnitude

	if speed < Config.CAMERA.VELOCITY_THRESHOLD then
		for zoneNum = 1, 3 do
			local zoneZ = Config.ZONES[zoneNum].Z_OFFSET
			local zoneR = Config.ZONES[zoneNum].RADIUS
			if math.abs(ballPos.Z - zoneZ) < zoneR * 1.5 then
				self.state = "LANDING_FOCUS"
				self.landingHoldStart = 0
				return
			end
		end
	end

	local camPos = Vector3.new(ballPos.X * 0.4, ballPos.Y + 12, ballPos.Z - 8)
	local targetCF = CFrame.lookAt(camPos, ballPos)
	self.camera.CFrame = self.camera.CFrame:Lerp(targetCF, math.min(dt * 8, 1))
end

function CameraController:_updateLandingFocus(dt: number)
	local ball = self.trackedBall
	if not ball or not ball.Parent then
		self.state = "RETURNING"
		self.trackedBall = nil
		return
	end

	local ballPos = ball.Position
	local speed = ball.AssemblyLinearVelocity.Magnitude

	local camDist = Config.CAMERA.LANDING_DISTANCE
	local camHeight = Config.CAMERA.LANDING_HEIGHT
	local orbitX = math.sin(tick() * 0.4) * 2
	local cameraPos = ballPos + Vector3.new(orbitX, camHeight, -camDist)
	local targetCF = CFrame.lookAt(cameraPos, ballPos)

	self.camera.CFrame = self.camera.CFrame:Lerp(targetCF, math.min(dt * Config.CAMERA.TRANSITION_SPEED, 1))

	if speed < Config.GAME.BALL_SETTLE_VELOCITY or ball.Anchored then
		if self.landingHoldStart == 0 then
			self.landingHoldStart = tick()
		end
		if tick() - self.landingHoldStart > Config.CAMERA.HOLD_TIME then
			self.state = "RETURNING"
			self.trackedBall = nil
		end
	end
end

function CameraController:destroy()
	if self.renderConn then
		self.renderConn:Disconnect()
	end
end

return CameraController
