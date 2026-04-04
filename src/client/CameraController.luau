local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CameraController = {}
CameraController.__index = CameraController

function CameraController.new()
	local self = setmetatable({}, CameraController)
	self.camera = workspace.CurrentCamera
	self.trackedBall = nil
	self.state = "DEFAULT" -- DEFAULT | TRACKING | LANDING_FOCUS | RETURNING
	self.landingHoldStart = 0
	self.defaultCF = CFrame.lookAt(Config.CAMERA.DEFAULT_OFFSET, Config.CAMERA.DEFAULT_LOOK_AT)
	self.currentCF = self.defaultCF

	-- 카메라 즉시 고정
	self:_forceScriptable()
	self.camera.CFrame = self.defaultCF

	-- 매 프레임 카메라 제어
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
	-- CameraSubject도 nil로 (캐릭터 추적 방지)
	self.camera.CameraSubject = nil
end

function CameraController:trackBall(ball: Part?)
	self.trackedBall = ball
	if ball then
		-- 발사 직후 기본 뷰 유지 → 0.8초 후 추적 시작
		self.state = "LAUNCH_DELAY"
		self.launchDelayStart = tick()
		self.landingHoldStart = 0
	end
end

function CameraController:_update(dt: number)
	if self.state == "DEFAULT" then
		self.camera.CFrame = self.camera.CFrame:Lerp(self.defaultCF, math.min(dt * 3, 1))
		return
	end

	if self.state == "LAUNCH_DELAY" then
		-- 기본 뷰 유지하면서 공이 날아가는 걸 지켜봄
		self.camera.CFrame = self.camera.CFrame:Lerp(self.defaultCF, math.min(dt * 3, 1))
		if tick() - self.launchDelayStart > 0.5 then
			self.state = "TRACKING"
		end
		return
	end

	if self.state == "TRACKING" then
		self:_updateTracking(dt)
	elseif self.state == "LANDING_FOCUS" then
		self:_updateLandingFocus(dt)
	elseif self.state == "RETURNING" then
		self:_updateReturning(dt)
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

	-- 공이 느려지고 존 근처면 → 착지 포커스
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

	-- 공을 따라가는 카메라: 공 뒤쪽 위에서 바라보기
	local camPos = Vector3.new(
		ballPos.X * 0.4,
		ballPos.Y + 12,
		ballPos.Z - 8
	)
	local targetCF = CFrame.lookAt(camPos, ballPos)

	-- 빠르게 전환 (dt * 8)
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

	-- 클로즈업 앵글
	local camDist = Config.CAMERA.LANDING_DISTANCE
	local camHeight = Config.CAMERA.LANDING_HEIGHT
	local orbitX = math.sin(tick() * 0.4) * 2
	local cameraPos = ballPos + Vector3.new(orbitX, camHeight, -camDist)
	local targetCF = CFrame.lookAt(cameraPos, ballPos)

	self.camera.CFrame = self.camera.CFrame:Lerp(targetCF, math.min(dt * Config.CAMERA.TRANSITION_SPEED, 1))

	-- 공이 멈추면 잠시 홀드 후 복귀
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

function CameraController:_updateReturning(dt: number)
	self.camera.CFrame = self.camera.CFrame:Lerp(self.defaultCF, math.min(dt * Config.CAMERA.RETURN_SPEED, 1))

	local diff = (self.camera.CFrame.Position - self.defaultCF.Position).Magnitude
	if diff < 0.3 then
		self.camera.CFrame = self.defaultCF
		self.state = "DEFAULT"
	end
end

function CameraController:destroy()
	if self.renderConn then
		self.renderConn:Disconnect()
	end
end

return CameraController
