--[[
	纯特效版：赛博斯安威斯坦（修复 R15 拖尾动作 Bug）
	完美保留 R15 / R6 的动作姿态
]]
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- 设置参数
local ACTION_NAME = "SandevistanToggle"
local TOGGLE_KEY = Enum.KeyCode.F
local CLONE_INTERVAL = 0.03  
local CLONE_LIFETIME = 0.6   
local CLONE_FADE_TIME = 0.3  

-- 状态
local isActive = false
local activeClones = {}
local flashGui = nil
local currentShakeConnection = nil
local character
local cloneSpawning = false

-- 特效对象
local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Name = "SandevistanEffect"
colorCorrection.Parent = Lighting

local sound = Instance.new("Sound")
sound.Name = "SandevistanSound"
sound.SoundId = "rbxassetid://130840290979991"
sound.Volume = 1
sound.Looped = false
sound.Parent = Workspace

local colorSequence = {
	Color3.fromRGB(75, 255, 33),
	Color3.fromRGB(0, 240, 255),
	Color3.fromRGB(244, 213, 253),
	Color3.fromRGB(119, 34, 137),
	Color3.fromRGB(248, 230, 2)
}

local effectColors = {
	Active = { Contrast = 0.5, Saturation = 0.25, TintColor = Color3.fromRGB(85, 255, 127) },
	Inactive = { Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }
}

-- 屏幕闪白
local function flashScreen()
	if flashGui then flashGui:Destroy() end
	flashGui = Instance.new("ScreenGui")
	flashGui.Name = "SandevistanFlashGui"
	flashGui.IgnoreGuiInset = true
	flashGui.ResetOnSpawn = false
	flashGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	flashGui.Parent = player:WaitForChild("PlayerGui")

	local flash = Instance.new("Frame")
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.Position = UDim2.new(0, 0, 0, 0)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BorderSizePixel = 0
	flash.BackgroundTransparency = 1
	flash.ZIndex = 999
	flash.Parent = flashGui

	local tweenIn = TweenService:Create(flash, TweenInfo.new(0.05), { BackgroundTransparency = 0 })
	tweenIn:Play()
	tweenIn.Completed:Wait()

	local tweenOut = TweenService:Create(flash, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
	tweenOut:Play()
	tweenOut.Completed:Wait()

	flashGui:Destroy()
end

-- 镜头震动
local function cameraShake(duration, magnitude)
	if currentShakeConnection then currentShakeConnection:Disconnect() end
	local startTime = tick()
	currentShakeConnection = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		if elapsed > duration then
			currentShakeConnection:Disconnect()
			currentShakeConnection = nil
			return
		end
		local offset = CFrame.new(
			(math.random() - 0.5) * 2 * magnitude,
			(math.random() - 0.5) * 2 * magnitude,
			(math.random() - 0.5) * 2 * magnitude
		)
		camera.CFrame = camera.CFrame * offset
	end)
end

-- 【核心修复：快照法生成残影】
local function createClone()
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- 创建一个空的模型来存放残影部件
	local cloneModel = Instance.new("Model")
	cloneModel.Name = "SandevistanClone"

	-- 弄一个隐形的中心点，方便定位和高亮
	local dummyRoot = Instance.new("Part")
	dummyRoot.Name = "HumanoidRootPart"
	dummyRoot.Transparency = 1
	dummyRoot.Anchored = true
	dummyRoot.CanCollide = false
	dummyRoot.CFrame = root.CFrame * CFrame.new(0, 1.5, 0)
	dummyRoot.Parent = cloneModel
	cloneModel.PrimaryPart = dummyRoot

	-- 遍历你身上的所有部件（包含衣服、帽子等）
	for _, obj in ipairs(character:GetDescendants()) do
		if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then
			local newPart = obj:Clone()
			newPart.Anchored = true
			newPart.CanCollide = false
			-- 【关键】：直接抓取当前世界坐标中的 CFrame，记录下这一刻的姿势
			newPart.CFrame = obj.CFrame
			
			-- 移除原来的马达关节，防止物理拉扯导致姿势变形
			for _, child in ipairs(newPart:GetChildren()) do
				if child:IsA("JointInstance") or child:IsA("Motor6D") then
					child:Destroy()
				end
			end
			newPart.Parent = cloneModel
		end
	end

	cloneModel.Parent = workspace

	-- 高亮效果
	local highlight = Instance.new("Highlight")
	highlight.FillColor = colorSequence[1]
	highlight.OutlineColor = colorSequence[1]
	highlight.FillTransparency = 0.3
	highlight.OutlineTransparency = 0.6
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = cloneModel

	-- 颜色循环
	local index = 1
	local duration = 0.2
	local function cycleColor()
		index = index % #colorSequence + 1
		local tween = TweenService:Create(highlight, TweenInfo.new(duration), {
			FillColor = colorSequence[index],
			OutlineColor = colorSequence[index]
		})
		tween:Play()
		tween.Completed:Wait()
		if cloneModel.Parent then cycleColor() end
	end
	task.spawn(cycleColor)

	local cloneData = { clone = cloneModel, highlight = highlight }
	table.insert(activeClones, cloneData)

	-- 自动消亡逻辑
	task.spawn(function()
		task.wait(CLONE_LIFETIME)
		if cloneModel and cloneModel.Parent then
			TweenService:Create(highlight, TweenInfo.new(CLONE_FADE_TIME), {
				FillTransparency = 1,
				OutlineTransparency = 1
			}):Play()
			
			for _, part in ipairs(cloneModel:GetDescendants()) do
				if part:IsA("BasePart") or part:IsA("Decal") then
					TweenService:Create(part, TweenInfo.new(CLONE_FADE_TIME), { Transparency = 1 }):Play()
				end
			end
			
			task.wait(CLONE_FADE_TIME)
			
			if cloneModel and cloneModel.Parent then cloneModel:Destroy() end
			
			for i, v in ipairs(activeClones) do
				if v.clone == cloneModel then
					table.remove(activeClones, i)
					break
				end
			end
		end
	end)
end

-- 总清理
local function cleanupClones()
	for _, data in ipairs(activeClones) do
		local clone, highlight = data.clone, data.highlight
		if clone and clone.Parent then
			TweenService:Create(highlight, TweenInfo.new(CLONE_FADE_TIME), {
				FillTransparency = 1,
				OutlineTransparency = 1
			}):Play()
			for _, part in ipairs(clone:GetDescendants()) do
				if part:IsA("BasePart") or part:IsA("Decal") then
					TweenService:Create(part, TweenInfo.new(CLONE_FADE_TIME), { Transparency = 1 }):Play()
				end
			end
			task.delay(CLONE_FADE_TIME, function()
				if clone and clone.Parent then clone:Destroy() end
			end)
		end
	end
	activeClones = {}
end

local function setVisuals(active)
	TweenService:Create(colorCorrection, TweenInfo.new(0.4), effectColors[active and "Active" or "Inactive"]):Play()
end

local function startCloneSpawning()
	cloneSpawning = true
	coroutine.wrap(function()
		while cloneSpawning do
			createClone()
			task.wait(CLONE_INTERVAL)
		end
	end)()
end

local function stopCloneSpawning()
	cloneSpawning = false
end

local function activate()
	if isActive then return end
	isActive = true
	setVisuals(true)
	sound:Play()
	task.spawn(function()
		flashScreen()
		cameraShake(0.25, 0.2)
	end)
	startCloneSpawning()
end

function deactivate()
	if not isActive then return end
	isActive = false
	stopCloneSpawning()
	task.wait(CLONE_INTERVAL * 1.1)
	setVisuals(false)
	if sound.IsPlaying then
		local tween = TweenService:Create(sound, TweenInfo.new(0.4), { Volume = 0 })
		tween:Play()
		tween.Completed:Connect(function()
			sound:Stop()
			sound.Volume = 1
		end)
	end
	task.spawn(function()
		flashScreen()
		cameraShake(0.25, 0.2)
	end)
	cleanupClones()
end

local function toggleSandevistan()
	if isActive then
		deactivate()
	else
		activate()
	end
end

local function bindCharacter(char)
	character = char
end

player.CharacterAdded:Connect(bindCharacter)
if player.Character then
	bindCharacter(player.Character)
end

local function handleAction(actionName, inputState, inputObject)
	if inputState == Enum.UserInputState.Begin then
		toggleSandevistan()
	end
end

ContextActionService:BindAction(ACTION_NAME, handleAction, true, TOGGLE_KEY)

local mobileButton = ContextActionService:GetButton(ACTION_NAME)
if mobileButton then
	mobileButton.Size = UDim2.new(0, 60, 0, 60)
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "Sandy"
	textLabel.TextColor3 = Color3.fromRGB(248, 230, 2)
	textLabel.TextSize = 16
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Parent = mobileButton
end
