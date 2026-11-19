--[[
	车辆悬浮加速器 (移动端防误触·锁定版)
	功能：
	1. 按住按钮/Shift 加速，松开停止。
	2. 悬浮窗带【锁定位置】开关，锁定后防误触拖动。
	3. 可自定义最大速度。
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui") -- 如果报错，改成 player:WaitForChild("PlayerGui")

local player = Players.LocalPlayer

-- ================= 配置区 =================
local DEFAULT_MAX_SPEED = 300
local currentSpeed = 0
local isBoosting = false
local isLocked = false -- 默认不锁定
local boostPart = nil
local currentSeat = nil
local bindKey = Enum.KeyCode.LeftShift

-- ================= UI 界面 =================
local gui = Instance.new("ScreenGui")
gui.Name = "VehicleBoostGUI"
gui.ResetOnSpawn = false
gui.Parent = CoreGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 200, 0, 150)
mainFrame.Position = UDim2.new(0.5, -100, 0.5, -75)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
mainFrame.BackgroundTransparency = 0.2
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true -- 允许拖动
mainFrame.Parent = gui

local corner = Instance.new("UICorner", mainFrame)
corner.CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 25)
title.BackgroundTransparency = 1
title.Text = "🚗 车辆加速器"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Parent = mainFrame

-- 速度设置部分
local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(0.5, -10, 0, 25)
speedLabel.Position = UDim2.new(0, 10, 0, 30)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "最大速度:"
speedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
speedLabel.Font = Enum.Font.Gotham
speedLabel.TextSize = 13
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.Parent = mainFrame

local speedInput = Instance.new("TextBox")
speedInput.Size = UDim2.new(0.4, 0, 0, 25)
speedInput.Position = UDim2.new(0.55, 0, 0, 30)
speedInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
speedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
speedInput.Font = Enum.Font.Gotham
speedInput.TextSize = 13
speedInput.Text = tostring(DEFAULT_MAX_SPEED)
speedInput.Parent = mainFrame
local inputCorner = Instance.new("UICorner", speedInput)
inputCorner.CornerRadius = UDim.new(0, 4)

-- 锁定按钮
local lockBtn = Instance.new("TextButton")
lockBtn.Size = UDim2.new(1, -20, 0, 25)
lockBtn.Position = UDim2.new(0, 10, 0, 65)
lockBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
lockBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
lockBtn.Font = Enum.Font.GothamBold
lockBtn.TextSize = 13
lockBtn.Text = "🔓 当前位置: 未锁定 (可拖动)"
lockBtn.Parent = mainFrame
local lockCorner = Instance.new("UICorner", lockBtn)
lockCorner.CornerRadius = UDim.new(0, 6)

-- 加速按钮 (按住生效)
local boostBtn = Instance.new("TextButton")
boostBtn.Size = UDim2.new(1, -20, 0, 35)
boostBtn.Position = UDim2.new(0, 10, 1, -45)
boostBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
boostBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
boostBtn.Font = Enum.Font.GothamBold
boostBtn.TextSize = 15
boostBtn.Text = "按住加速 (Shift)"
boostBtn.Parent = mainFrame
local btnCorner = Instance.new("UICorner", boostBtn)
btnCorner.CornerRadius = UDim.new(0, 6)

-- ================= 锁定位置逻辑 =================
lockBtn.MouseButton1Click:Connect(function()
    isLocked = not isLocked
    if isLocked then
        mainFrame.Draggable = false
        lockBtn.Text = "🔒 当前位置: 已锁定 (防误触)"
        lockBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
    else
        mainFrame.Draggable = true
        lockBtn.Text = "🔓 当前位置: 未锁定 (可拖动)"
        lockBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end
end)

-- ================= 核心物理逻辑 =================
local function startBoost()
    if isBoosting then return end
    
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    currentSeat = humanoid and humanoid.SeatPart
    
    -- 检查是否坐在车里
    if currentSeat and (currentSeat:IsA("VehicleSeat") or currentSeat.Name:lower():find("seat")) then
        isBoosting = true
        
        -- 生成幽灵透明方块
        boostPart = Instance.new("Part")
        boostPart.Name = "MagicBooster"
        boostPart.Size = Vector3.new(2, 2, 2)
        boostPart.Transparency = 1
        boostPart.CanCollide = false
        boostPart.Massless = true
        boostPart.CFrame = currentSeat.CFrame
        boostPart.Parent = currentSeat
        
        -- 焊死
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = currentSeat
        weld.Part1 = boostPart
        weld.Parent = boostPart
    end
end

local function stopBoost()
    isBoosting = false
    if boostPart then
        boostPart:Destroy()
        boostPart = nil
    end
    currentSpeed = 0
    -- 恢复按钮颜色
    boostBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
end

-- 每帧加速逻辑
RunService.Heartbeat:Connect(function()
    if isBoosting and boostPart and boostPart.Parent then
        -- 如果玩家跳车了，自动停止
        local char = player.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if not currentSeat or not humanoid or humanoid.SeatPart ~= currentSeat then
            stopBoost()
            return
        end
        
        local maxSpd = tonumber(speedInput.Text) or DEFAULT_MAX_SPEED
        local look = currentSeat.CFrame.LookVector
        
        -- 平滑加速
        currentSpeed = math.min(currentSpeed + (maxSpd * 0.1), maxSpd)
        boostPart.AssemblyLinearVelocity = look * currentSpeed
    end
end)

-- ================= 输入监听 =================
-- 1. 电脑端 Shift 监听
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == bindKey then
        boostBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        startBoost()
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.KeyCode == bindKey then
        stopBoost()
    end
end)

-- 2. 移动端/鼠标按住按钮监听
boostBtn.MouseButton1Down:Connect(function()
    boostBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    startBoost()
end)

boostBtn.MouseButton1Up:Connect(function()
    stopBoost()
end)

-- 防止手指滑出按钮导致一直加速
boostBtn.MouseLeave:Connect(function()
    stopBoost()
end)
