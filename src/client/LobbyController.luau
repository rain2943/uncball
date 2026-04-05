local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LobbyController = {}
LobbyController.__index = LobbyController

-- ===== 시뮬레이터 스타일 헬퍼 =====

local FONT_TITLE = Enum.Font.FredokaOne
local FONT_BUTTON = Enum.Font.FredokaOne
local FONT_SUB = Enum.Font.GothamBold

local function addStroke(parent: Instance, color: Color3?, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(30, 30, 50)
	stroke.Thickness = thickness or 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = parent
	return stroke
end

local function addCorner(parent: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = parent
	return corner
end

function LobbyController.new()
	local self = setmetatable({}, LobbyController)
	self.gui = nil
	self.isVisible = false
	self.isMatching = false
	self.onPlayCallback = nil
	self._matchingThread = nil
	self:_createUI()
	return self
end

function LobbyController:_createUI()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "LobbyUI"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 10
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	self.gui = gui

	-- 전체 컨테이너 (배경 그라데이션)
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundColor3 = Color3.fromRGB(170, 215, 255)
	container.BorderSizePixel = 0
	container.Parent = gui

	local bgGrad = Instance.new("UIGradient")
	bgGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 200, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(190, 225, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(235, 245, 255)),
	})
	bgGrad.Rotation = 90
	bgGrad.Parent = container

	self.container = container

	-- 타이틀 (PC: 좌상단, 모바일: 상단 중앙)
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Text = "uncball"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = FONT_TITLE
	title.TextScaled = true
	title.Parent = container
	addStroke(title, Color3.fromRGB(20, 60, 120), 3)
	self.title = title

	-- 서브타이틀
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Star Cluster Ball"
	subtitle.TextColor3 = Color3.fromRGB(200, 220, 255)
	subtitle.Font = FONT_SUB
	subtitle.TextScaled = true
	subtitle.TextTransparency = 0.3
	subtitle.Parent = container
	self.subtitle = subtitle

	-- 캐릭터 뷰포트
	local charFrame = Instance.new("ViewportFrame")
	charFrame.Name = "CharViewport"
	charFrame.BackgroundTransparency = 1
	charFrame.Ambient = Color3.fromRGB(180, 180, 200)
	charFrame.LightColor = Color3.fromRGB(255, 255, 255)
	charFrame.LightDirection = Vector3.new(-1, -1, -1)
	charFrame.Parent = container

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = charFrame

	local vpCam = Instance.new("Camera")
	vpCam.Parent = charFrame
	charFrame.CurrentCamera = vpCam

	self.charViewport = charFrame
	self.worldModel = worldModel
	self.vpCam = vpCam

	-- 메뉴 패널 (카드형)
	local menuPanel = Instance.new("Frame")
	menuPanel.Name = "MenuPanel"
	menuPanel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	menuPanel.BackgroundTransparency = 0.05
	menuPanel.BorderSizePixel = 0
	menuPanel.Parent = container
	addCorner(menuPanel, 20)
	addStroke(menuPanel, Color3.fromRGB(210, 215, 230), 2)
	self.menuPanel = menuPanel

	-- PLAY 버튼
	local playBtn = Instance.new("TextButton")
	playBtn.Name = "PlayBtn"
	playBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
	playBtn.Text = "PLAY"
	playBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	playBtn.Font = FONT_BUTTON
	playBtn.TextScaled = true
	playBtn.BorderSizePixel = 0
	playBtn.AutoButtonColor = true
	playBtn.Parent = menuPanel
	addCorner(playBtn, 14)
	addStroke(playBtn, Color3.fromRGB(0, 140, 190), 3)

	local playGrad = Instance.new("UIGradient")
	playGrad.Color = ColorSequence.new(Color3.fromRGB(0, 220, 255), Color3.fromRGB(0, 170, 235))
	playGrad.Rotation = 90
	playGrad.Parent = playBtn

	-- PLAY 버튼 내 텍스트 패딩
	local playPad = Instance.new("UIPadding")
	playPad.PaddingTop = UDim.new(0.15, 0)
	playPad.PaddingBottom = UDim.new(0.15, 0)
	playPad.Parent = playBtn

	self.playBtn = playBtn

	-- SKIN 버튼
	local skinBtn = Instance.new("TextButton")
	skinBtn.Name = "SkinBtn"
	skinBtn.BackgroundColor3 = Color3.fromRGB(190, 130, 255)
	skinBtn.Text = "SKIN"
	skinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	skinBtn.Font = FONT_BUTTON
	skinBtn.TextScaled = true
	skinBtn.BorderSizePixel = 0
	skinBtn.AutoButtonColor = false
	skinBtn.Parent = menuPanel
	addCorner(skinBtn, 14)
	addStroke(skinBtn, Color3.fromRGB(140, 90, 200), 3)

	local skinGrad = Instance.new("UIGradient")
	skinGrad.Color = ColorSequence.new(Color3.fromRGB(200, 140, 255), Color3.fromRGB(160, 100, 230))
	skinGrad.Rotation = 90
	skinGrad.Parent = skinBtn

	local skinPad = Instance.new("UIPadding")
	skinPad.PaddingTop = UDim.new(0.15, 0)
	skinPad.PaddingBottom = UDim.new(0.15, 0)
	skinPad.Parent = skinBtn

	-- COMING SOON 오버레이
	local soonLabel = Instance.new("TextLabel")
	soonLabel.Name = "ComingSoon"
	soonLabel.BackgroundTransparency = 1
	soonLabel.Text = "COMING SOON"
	soonLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	soonLabel.Font = FONT_SUB
	soonLabel.TextScaled = true
	soonLabel.Parent = menuPanel
	self.soonLabel = soonLabel

	self.skinBtn = skinBtn

	-- PLAY 버튼 클릭
	playBtn.MouseButton1Click:Connect(function()
		if self.isMatching then return end
		self:_startMatching()
	end)

	-- 반응형 레이아웃
	self:_updateLayout()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		self:_updateLayout()
	end)

	-- 캐릭터 로드
	task.spawn(function()
		self:_loadCharacter()
	end)
end

-- ===== 반응형 레이아웃 =====
function LobbyController:_updateLayout()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local vpSize = cam.ViewportSize
	local isPortrait = vpSize.Y > vpSize.X

	if isPortrait then
		self:_applyPortraitLayout()
	else
		self:_applyLandscapeLayout()
	end
end

-- 모바일 세로 레이아웃
function LobbyController:_applyPortraitLayout()
	-- 타이틀: 상단 중앙
	self.title.Size = UDim2.new(0.5, 0, 0, 50)
	self.title.Position = UDim2.new(0.25, 0, 0, 30)
	self.title.TextXAlignment = Enum.TextXAlignment.Center

	-- 서브타이틀: 타이틀 아래
	self.subtitle.Size = UDim2.new(0.4, 0, 0, 20)
	self.subtitle.Position = UDim2.new(0.3, 0, 0, 82)
	self.subtitle.TextXAlignment = Enum.TextXAlignment.Center

	-- 캐릭터: 중앙, 전신
	self.charViewport.Size = UDim2.new(0.85, 0, 0.48, 0)
	self.charViewport.Position = UDim2.new(0.075, 0, 0.22, 0)

	-- 메뉴 패널: 하단 (캐릭터 발 바로 위 영역과 겹치는 느낌)
	self.menuPanel.Size = UDim2.new(0.88, 0, 0, 190)
	self.menuPanel.Position = UDim2.new(0.06, 0, 1, -210)

	-- 버튼들 (패널 내)
	self.playBtn.Size = UDim2.new(0.85, 0, 0, 56)
	self.playBtn.Position = UDim2.new(0.075, 0, 0, 20)

	self.skinBtn.Size = UDim2.new(0.85, 0, 0, 56)
	self.skinBtn.Position = UDim2.new(0.075, 0, 0, 90)

	self.soonLabel.Size = UDim2.new(0.4, 0, 0, 14)
	self.soonLabel.Position = UDim2.new(0.3, 0, 0, 152)
end

-- PC 가로 레이아웃
function LobbyController:_applyLandscapeLayout()
	-- 캐릭터: 왼쪽
	self.charViewport.Size = UDim2.new(0.6, 0, 1.1, 0)
	self.charViewport.Position = UDim2.new(-0.08, 0, 0.05, 0)

	-- 우측 영역 기준
	local panelW = 300
	local rightMargin = 70
	local rightEdge = rightMargin + panelW -- 우측 끝에서 이만큼

	-- 타이틀: 크게, 중간 높이, 우측 정렬 (패널과 끝점 맞춤)
	self.title.Size = UDim2.new(0, panelW, 0, 120)
	self.title.Position = UDim2.new(1, -rightEdge, 0.5, -250)
	self.title.TextXAlignment = Enum.TextXAlignment.Right

	-- 서브타이틀: 타이틀 바로 아래, 우측 정렬
	self.subtitle.Size = UDim2.new(0, panelW, 0, 22)
	self.subtitle.Position = UDim2.new(1, -rightEdge, 0.5, -138)
	self.subtitle.TextXAlignment = Enum.TextXAlignment.Right

	-- 메뉴 패널: 서브타이틀 아래
	self.menuPanel.Size = UDim2.new(0, panelW, 0, 240)
	self.menuPanel.Position = UDim2.new(1, -rightEdge, 0.5, -90)

	-- 버튼들
	self.playBtn.Size = UDim2.new(0.85, 0, 0, 64)
	self.playBtn.Position = UDim2.new(0.075, 0, 0, 28)

	self.skinBtn.Size = UDim2.new(0.85, 0, 0, 64)
	self.skinBtn.Position = UDim2.new(0.075, 0, 0, 110)

	self.soonLabel.Size = UDim2.new(0.5, 0, 0, 14)
	self.soonLabel.Position = UDim2.new(0.25, 0, 0, 184)
end

-- ===== 매칭 =====
function LobbyController:_startMatching()
	self.isMatching = true

	-- 버튼 스타일 변경
	local grad = self.playBtn:FindFirstChildOfClass("UIGradient")
	if grad then
		grad.Color = ColorSequence.new(Color3.fromRGB(255, 200, 50), Color3.fromRGB(255, 150, 20))
	end
	local stroke = self.playBtn:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Color3.fromRGB(200, 130, 0)
	end
	self.playBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 40)

	-- 점 애니메이션
	self._matchingThread = task.spawn(function()
		local dots = 0
		while self.isMatching do
			dots = (dots % 3) + 1
			self.playBtn.Text = "MATCHING" .. string.rep(".", dots)
			task.wait(0.4)
		end
	end)

	if self.onPlayCallback then
		self.onPlayCallback()
	end
end

function LobbyController:_resetPlayButton()
	self.isMatching = false
	if self._matchingThread then
		task.cancel(self._matchingThread)
		self._matchingThread = nil
	end
	self.playBtn.Text = "PLAY"
	self.playBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 255)

	local grad = self.playBtn:FindFirstChildOfClass("UIGradient")
	if grad then
		grad.Color = ColorSequence.new(Color3.fromRGB(0, 220, 255), Color3.fromRGB(0, 170, 235))
	end
	local stroke = self.playBtn:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Color3.fromRGB(0, 140, 190)
	end
end

-- ===== 보이기/숨기기 =====
function LobbyController:show()
	self.isVisible = true
	self.gui.Enabled = true
	self:_resetPlayButton()
	task.spawn(function()
		self:_loadCharacter()
	end)
end

function LobbyController:hide()
	self.isVisible = false
	self.isMatching = false
	if self._matchingThread then
		task.cancel(self._matchingThread)
		self._matchingThread = nil
	end
	self.gui.Enabled = false
end

-- ===== 캐릭터 뷰포트 =====
function LobbyController:_loadCharacter()
	local player = Players.LocalPlayer
	local char = player.Character
	if not char then
		char = player.CharacterAdded:Wait()
	end

	-- 외형 로드 대기
	if not player:HasAppearanceLoaded() then
		player.CharacterAppearanceLoaded:Wait()
	end
	-- 추가 대기 (액세서리/옷 로드)
	task.wait(0.5)

	-- 대기 중 캐릭터가 바뀌었을 수 있음
	char = player.Character
	if not char then return end

	-- 기존 모델 제거
	self.worldModel:ClearAllChildren()

	-- Archivable 활성화 후 클론
	local wasArchivable = char.Archivable
	char.Archivable = true
	local clone = char:Clone()
	char.Archivable = wasArchivable

	if not clone then return end

	for _, v in clone:GetDescendants() do
		if v:IsA("BaseScript") then
			v:Destroy()
		end
	end

	-- 모델 원점
	clone:PivotTo(CFrame.new(0, 0, 0))

	-- HumanoidRootPart 외에는 투명도 복원 (이미 숨겨졌을 수 있음)
	for _, v in clone:GetDescendants() do
		if v:IsA("BasePart") then
			if v.Name == "HumanoidRootPart" then
				v.Transparency = 1 -- HRP는 원래 안 보임
			else
				v.Transparency = 0
			end
		elseif v:IsA("Decal") or v:IsA("Texture") then
			v.Transparency = 0
		end
	end

	clone.Parent = self.worldModel

	-- 카메라 새로 생성 (ViewportFrame 카메라 갱신 보장)
	if self.vpCam then self.vpCam:Destroy() end
	local newCam = Instance.new("Camera")
	-- PC/모바일 공용: 전신 풀샷
	-- lookAt을 살짝 위로 → 머리 위 여유 확보 + 전신 보임
	newCam.FieldOfView = 22
	newCam.CFrame = CFrame.lookAt(
		Vector3.new(0.15, 0.3, -16),
		Vector3.new(0, 0.3, 0)
	)
	newCam.Parent = self.charViewport
	self.charViewport.CurrentCamera = newCam
	self.vpCam = newCam
	print("[Lobby] Character loaded, new camera created")

	-- 아이들 애니메이션
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		pcall(function()
			local idleAnim = Instance.new("Animation")
			idleAnim.AnimationId = "rbxassetid://507766388"
			local track = animator:LoadAnimation(idleAnim)
			track.Looped = true
			track:Play()
		end)
	end
end

return LobbyController
