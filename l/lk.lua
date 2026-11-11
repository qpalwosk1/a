local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local ACTION_NAME = "SandevistanToggle"
local TOGGLE_KEY = Enum.KeyCode.F
local NORMAL_SPEED = 16
local BOOSTED_SPEED = 80
local NORMAL_JUMP_POWER = 50
local BOOSTED_JUMP_POWER = 70
local SANDEVISTAN_DURATION = 30
local CLONE_INTERVAL = 0.4
local CLONE_FADE_TIME = 0.05
local MAX_CLONES = 40

local isActive = false
local activeClones = {}
local flashGui = nil
local currentShakeConnection = nil
local character, humanoid
local cloneSpawning = false
local activeSeat = nil
local activeWeld = nil

local timeSpeed = Instance.new("NumberValue")
timeSpeed.Name = "TimeSpeed"
timeSpeed.Value = 1
timeSpeed.Parent = Workspace

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

local function cameraShake(duration, magnitude)
	if currentShakeConnection then
		currentShakeConnection:Disconnect()
	end
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

local function createClone()
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	if #activeClones >= MAX_CLONES then
		local oldest = table.remove(activeClones, 1)
		if oldest then
			if oldest.highlight and oldest.highlight.Parent then
				oldest.highlight:Destroy()
			end
			if oldest.clone and oldest.clone.Parent then
				oldest.clone:Destroy()
			end
		end
	end

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
	local duration = 0.5
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
	table.insert(activeClones, { clone = clone, highlight = highlight })
end

local function cleanupClones(immediate)
	for _, data in ipairs(activeClones) do
		local
