--[[
	纯特效终极置顶版：赛博斯安威斯坦
	✅ 绝对安全：无任何速度、跳跃力等物理修改。
	✅ 极限置顶：全屏闪白和 Sandy 按钮绝对不会被任何游戏 UI 遮挡。
	✅ 精准定位：按钮固定在右下角红点位置。
	✅ 完美残影：自动生成、自动消亡，不卡顿本体。
]]
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- 设置参数
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

-- 屏幕闪白（极限置顶UI）
local function flashScreen()
	if flashGui then flashGui:Destroy() end
	flashGui = Instance.new("ScreenGui")
	flashGui.Name = "SandevistanFlashGui"
	flashGui.IgnoreGuiInset = true
	flashGui.ResetOnSpawn = false
	flashGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	flashGui.DisplayOrder = 2147483647 
	flashGui.Parent = player:WaitForChild("PlayerGui")

	local flash = Instance.new("Frame")
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.Position = UDim2.new(0, 0, 0, 0)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BorderSizePixel = 0
	flash.BackgroundTransparency = 1
	flash.ZIndex = 2147483647
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

-- 生成残影
local function createClone()
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	character.Archivable = true

	local clone = character:Clone()
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	clone.Name = "SandevistanClone"
	clone.Parent = workspace
	clone:SetPrimaryPartCFrame(root.CFrame * CFrame.new(0, 1.5, 0))

	local humanoidClone = clone:FindFirstChildOfClass("Humanoid")
	if humanoidClone then humanoidClone:Destroy() end

	for _, obj in ipairs(clone:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = true
			obj.CanCollide = false
			obj.Transparency = 0
		elseif obj:IsA("Decal") then
			obj.Transparency = 0
		end
	end

	local highlight = Instance.new("Highlight")
	highlight.FillColor = colorSequence[1]
	highlight.OutlineColor = colorSequence[1]
	highlight.FillTransparency = 0.3
	highlight.OutlineTransparency = 0.6
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = clone

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
		if clone.Parent then cycleColor() end
	end
	task.spawn(cycleColor)

	local cloneData = { clone = clone, highlight = highlight }
	table.insert(activeClones, cloneData)

	-- 残影自动消亡
	task.spawn(function()
		task.wait(CLONE_LIFETIME)
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
			
			task.wait(CLONE_FADE_TIME)
			
			if clone and clone.Parent then clone:Destroy() end
			
			for i, v in ipairs(activeClones) do
				if v.clone == clone then
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

-- 核心开关（纯特效，无物理修改）
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

-- 键盘监听
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == TOGGLE_KEY then
		toggleSandevistan()
	end
end)

-- 【极限置顶UI】：独立 Sandy 按钮
local buttonGui = Instance.new("ScreenGui")
buttonGui.Name = "SandyButtonGui"
buttonGui.ResetOnSpawn = false
buttonGui.IgnoreGuiInset = true
buttonGui.DisplayOrder = 2147483647 
buttonGui.Parent = player:WaitForChild("PlayerGui")

local sandyButton = Instance.new("TextButton")
sandyButton.Size = UDim2.new(0, 60, 0, 60)

-- 【红点定位】：相对右下角的精确偏移
sandyButton.Position = UDim2.new(1, -110, 1, -100) 

sandyButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
sandyButton.BackgroundTransparency = 0.5
sandyButton.BorderSizePixel = 0
sandyButton.Text = "Sandy"
sandyButton.TextColor3 = Color3.fromRGB(248, 230, 2)
sandyButton.TextSize = 16
sandyButton.Font = Enum.Font.GothamBold
sandyButton.ZIndex = 2147483647
sandyButton.Parent = buttonGui

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(1, 0)
buttonCorner.Parent = sandyButton

sandyButton.MouseButton1Click:Connect(function()
	toggleSandevistan()
end)
