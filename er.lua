--[[
	WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk!
	MODIFIED: 改为手动开关，取消4.2秒限制，增加残影自动消亡机制防止卡顿。
]]
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- Settings
local ACTION_NAME = "SandevistanToggle"
local TOGGLE_KEY = Enum.KeyCode.F
local NORMAL_SPEED = 16
local BOOSTED_SPEED = 80
local NORMAL_JUMP_POWER = 50
local BOOSTED_JUMP_POWER = 70
local CLONE_INTERVAL = 0.03  -- 生成残影的间隔（越小越密集）
local CLONE_LIFETIME = 0.6   -- 【新增】残影存活时间（0.6秒后自动消失）
local CLONE_FADE_TIME = 0.3  -- 【新增】残影消失时的渐变时间

-- State
local isActive = false
local activeClones = {}
local flashGui = nil
local currentShakeConnection = nil
local character, humanoid
local cloneSpawning = false
local activeSeat = nil
local activeWeld = nil

-- Time scale
local timeSpeed = Instance.new("NumberValue")
timeSpeed.Name = "TimeSpeed"
timeSpeed.Value = 1
timeSpeed.Parent = Workspace

-- Effects
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

-- GUI flash
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

-- Camera shake
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

-- Clone
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

	-- 存入表格
	local cloneData = { clone = clone, highlight = highlight }
	table.insert(activeClones, cloneData)

	-- 【新增：残影自动消亡逻辑】
	task.spawn(function()
		task.wait(CLONE_LIFETIME) -- 存活时间到了之后
		if clone and clone.Parent then
			-- 开始渐隐
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
			
			-- 彻底销毁
			if clone and clone.Parent then clone:Destroy() end
			
			-- 从数组中移除自身，防止内存泄漏（很重要）
			for i, v in ipairs(activeClones) do
				if v.clone == clone then
					table.remove(activeClones, i)
					break
				end
			end
		end
	end)
end

-- Cleanup (按下F关闭时的总清理)
local function cleanupClones(immediate)
	for _, data in ipairs(activeClones) do
		local clone, highlight = data.clone, data.highlight
		if clone and clone.Parent then
			if immediate then
				clone:Destroy()
			else
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
	end
	activeClones = {}
end

-- Visuals / Time
local function setVisuals(active)
	TweenService:Create(colorCorrection, TweenInfo.new(0.4), effectColors[active and "Active" or "Inactive"]):Play()
end

local function setTimeScale(scale)
	TweenService:Create(timeSpeed, TweenInfo.new(0.4), { Value = scale }):Play()
end

-- Freeze other players
local function freezeOthers(freeze)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character then
			for _, part in ipairs(p.Character:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = freeze
				end
			end
		end
	end
end

-- Lag switch
local function activateLagSwitch()
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	if not hrp or not torso then return end

	local seat = Instance.new("Seat")
	seat.Name = "invischair"
	seat.Transparency = 1
	seat.Anchored = false
	seat.CanCollide = false
	seat.Position = hrp.Position
	seat.Parent = workspace
	activeSeat = seat

	local weld = Instance.new("Weld")
	weld.Part0 = seat
	weld.Part1 = torso
	weld.Parent = seat
	activeWeld = weld

	task.wait()
	seat.CFrame = hrp.CFrame
end

local function deactivateLagSwitch()
	if activeWeld then activeWeld:Destroy() activeWeld = nil end
	if activeSeat then activeSeat:Destroy() activeSeat = nil end
end

-- Clone spawning
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

-- Main toggle functions
local function activate()
	if isActive then return end
	isActive = true
	humanoid.WalkSpeed = BOOSTED_SPEED
	humanoid.JumpPower = BOOSTED_JUMP_POWER
	setVisuals(true)
	setTimeScale(0.1)
	freezeOthers(true)
	sound:Play()
	activateLagSwitch()

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

	humanoid.WalkSpeed = NORMAL_SPEED
	humanoid.JumpPower = NORMAL_JUMP_POWER
	setVisuals(false)
	setTimeScale(1)
	freezeOthers(false)
	deactivateLagSwitch()

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

	cleanupClones(false)
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
	humanoid = character:WaitForChild("Humanoid")
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
