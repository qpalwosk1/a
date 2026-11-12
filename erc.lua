--[[
	纯特效终极版（彻底解决开启瞬间本人被固定卡死的问题）
	只提取模型外观做残影，不对本体物理产生任何干扰。
]]
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- 设置参数 (降低了生成频率，保护性能)
local ACTION_NAME = "SandevistanToggle"
local TOGGLE_KEY = Enum.KeyCode.F
local CLONE_INTERVAL = 0.08  -- 稍微降低频率，肉眼依然连贯，但彻底告别卡顿
local CLONE_LIFETIME = 0.6   
local CLONE_FADE_TIME = 0.3  
local MAX_CLONES = 15        -- 限制最大数量

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

-- 【核心重写：绝不卡顿的残影生成法】
local function createClone()
	if not character then return end
	
	-- 1. 限制最大数量，超出则删最旧的
	if #activeClones >= MAX_CLONES then
		local oldest = table.remove(activeClones, 1)
		if oldest and oldest.clone and oldest.clone.Parent then
			oldest.clone:Destroy()
		end
	end

	-- 2. 建一个空文件夹装残影零件
	local cloneFolder = Instance.new("Folder")
	cloneFolder.Name = "SandevistanClone"

	-- 3. 遍历你身上的所有可见部件（跳过原始根部件，防止出Bug）
	for _, obj in ipairs(character:GetDescendants()) do
		if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then
			local newPart = obj:Clone()
			newPart.Anchored = true
			newPart.CanCollide = false
			newPart.CFrame = obj.CFrame -- 【关键】直接抓取当前动作的绝对坐标
			
			-- 清理新部件上的关节，防止物理散架
			for _, child in ipairs(newPart:GetChildren()) do
				if child:IsA("JointInstance") or child:IsA("Motor6D") or child:IsA("Script") then
					child:Destroy()
				end
			end
			
			newPart.Parent = cloneFolder
		end
	end

	cloneFolder.Parent = workspace

	-- 高亮特效
	local highlight = Instance.new("Highlight")
	highlight.FillColor = colorSequence[1]
	highlight.OutlineColor = colorSequence[1]
	highlight.FillTransparency = 0.3
	highlight.OutlineTransparency = 0.6
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = cloneFolder

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
		if cloneFolder.Parent then cycleColor() end
	end
	task.spawn(cycleColor)

	local cloneData = { clone = cloneFolder, highlight = highlight }
	table.insert(activeClones, cloneData)

	-- 自动消亡逻辑
	task.spawn(function()
		task.wait(CLONE_LIFETIME)
		if cloneFolder and cloneFolder.Parent then
			TweenService:Create(highlight, TweenInfo.new(CLONE_FADE_TIME), {
				FillTransparency = 1,
				OutlineTransparency = 1
			}):Play()
			
			for _, part in ipairs(cloneFolder:GetDescendants()) do
				if part:IsA("BasePart") or part:IsA("Decal") then
					TweenService:Create(part, TweenInfo.new(CLONE_FADE_TIME), { Transparency = 1 }):Play()
				end
			end
			
			task.wait(CLONE_FADE_TIME)
			if cloneFolder and cloneFolder.Parent then cloneFolder:Destroy() end
			
			for i, v in ipairs(activeClones) do
				if v.clone == cloneFolder then
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
