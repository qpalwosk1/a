--[[
	车辆悬浮加速器 (双向加速版)
	新增：反向加速功能 (Ctrl 或 点击后退按钮)。
	UI：底部拆分为前进和后退双按钮，完美适配移动端。
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui") -- 如果报错，改成 player:WaitForChild("PlayerGui")

local player = Players.LocalPlayer

-- ================= 配置区 =================
local DEFAULT_MAX_SPEED = 300
local DEFAULT_ACCELERATION = 10
local currentSpeed = 0
local isBoosting = false
local boostDirection = 1 -- 1 代表前进，-1 代表后退
local isLocked = false
local boostPart = nil
local currentSeat = nil

-- 按键绑定
local bindKeyForward = Enum.KeyCode.LeftShift
local bindKeyBackward = Enum.KeyCode.LeftControl

-- ================= UI 界面 =================
local gui = Instance.new("ScreenGui")
gui.Name = "VehicleBoostGUI"
gui.ResetOnSpawn = false
gui.Parent = CoreGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 200, 0, 185) 
mainFrame.Position = UDim2.new(0.5, -100, 0.5, -90)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
mainFrame.BackgroundTransparency = 0.2
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = gui

local corner = Instance.new("UICorner", mainFrame)
corner.CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 25)
title.BackgroundTransparency = 1
title.Text = "🚗 车辆双向加速器"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Parent = mainFrame

-- 1. 最大速度设置
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

-- 2. 每帧加速度设置
local accelLabel = Instance.new("TextLabel")
accelLabel.Size = UDim2.new(0.5, -10, 0, 25)
accelLabel.Position = UDim2.new(0, 10, 0, 65)
accelLabel.BackgroundTransparency = 1
accelLabel.Text = "每帧加速:"
accelLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
accelLabel.Font = Enum.Font.Gotham
accelLabel.TextSize = 13
accelLabel.TextXAlignment = Enum.TextXAlignment.Left
accelLabel.Parent = mainFrame

local accelInput = Instance.new("TextBox")
accelInput.Size = UDim2.new(0.4, 0, 0, 25)
accelInput.Position = UDim2.new(0.55, 0, 0, 65)
accelInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
accelInput.TextColor3 = Color3.fromRGB(255, 255, 255)
accelInput.Font = Enum.Font.Gotham
accelInput.TextSize = 13
accelInput.Text = tostring(DEFAULT_ACCELERATION)
accelInput.Parent = mainFrame
local accelCorner = Instance.new("UICorner", accelInput)
accelCorner.CornerRadius = UDim.new(0, 4)

-- 3. 锁定按钮
local lockBtn = Instance.new("TextButton")
lockBtn.Size = UDim2.new(1, -20, 0, 25)
lockBtn.Position = UDim2.new(0, 10, 0, 100)
lockBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
lockBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
lockBtn.Font = Enum.Font.GothamBold
lockBtn.TextSize = 13
lockBtn.Text = "🔓 当前位置: 未锁定 (可拖动)"
lockBtn.Parent = mainFrame
local lockCorner = Instance.new("UICorner", lockBtn)
lockCorner.CornerRadius = UDim.new(0, 6)

-- 4. 后退按钮 (左侧)
local backBtn = Instance.new("TextButton")
backBtn.Size = UDim2.new(0.5, -15, 0, 35)
backBtn.Position = UDim2.new(0, 10, 1, -45)
backBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 40)
backBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
backBtn.Font = Enum.Font.GothamBold
backBtn.TextSize = 14
backBtn.Text = "后退 (Ctrl)"
backBtn.Parent = mainFrame
local btnCornerBack = Instance.new("UICorner", backBtn)
btnCornerBack.CornerRadius = UDim.new(0, 6)

-- 5. 前进按钮 (右侧)
local forwardBtn = Instance.new("TextButton")
forwardBtn.Size = UDim2.new(0.5, -15, 0, 35)
forwardBtn.Position = UDim2.new(0.5, 5, 1, -45)
forwardBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
forwardBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
forwardBtn.Font = Enum.Font.GothamBold
forwardBtn.TextSize = 14
forwardBtn.Text = "前进 (Shift)"
forwardBtn.Parent = mainFrame
local btnCornerFwd = Instance.new("UICorner", forwardBtn)
btnCornerFwd.CornerRadius = UDim.new(0, 6)

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
local function startBoost(direction)
    if isBoosting then return end
    
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    currentSeat = humanoid and humanoid.SeatPart
    
    if currentSeat and (currentSeat:IsA("VehicleSeat") or currentSeat.Name:lower():find("seat")) then
        isBoosting = true
        boostDirection = direction -- 记录当前方向 (1 前进, -1 后退)
        
        boostPart = Instance.new("Part")
        boostPart.Name = "MagicBooster"
        boostPart.Size = Vector3.new(2, 2, 2)
        boostPart.Transparency = 1
        boostPart.CanCollide = false
        boostPart.Massless = true
        boostPart.CFrame = currentSeat.CFrame
        boostPart.Parent = currentSeat
        
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
    forwardBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
    backBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 40)
end

-- 每帧加速逻辑
RunService.Heartbeat:Connect(function()
    if isBoosting and boostPart and boostPart.Parent then
        local char = player.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if not currentSeat or not humanoid or humanoid.SeatPart ~= currentSeat then
            stopBoost()
            return
        end
        
        local maxSpd = tonumber(speedInput.Text) or DEFAULT_MAX_SPEED
        local frameAccel = tonumber(accelInput.Text) or DEFAULT_ACCELERATION
        
        if frameAccel < 0.1 then frameAccel = 0.1 end
        
        -- 获取车头朝向，并根据方向系数 (1 或 -1) 计算最终的加速向量
        local look = currentSeat.CFrame.LookVector * boostDirection
        
        -- 平滑加速
        currentSpeed = math.min(currentSpeed + frameAccel, maxSpd)
        
        -- 施加推力
        boostPart.AssemblyLinearVelocity = look * currentSpeed
    end
end)

-- ================= 输入监听 =================
-- 电脑端按键
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == bindKeyForward then
        forwardBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        startBoost(1)
    elseif input.KeyCode == bindKeyBackward then
        backBtn.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
        startBoost(-1)
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.KeyCode == bindKeyForward or input.KeyCode == bindKeyBackward then
        stopBoost()
    end
end)

-- 前进按钮监听
forwardBtn.MouseButton1Down:Connect(function()
    forwardBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    startBoost(1)
end)
forwardBtn.MouseButton1Up:Connect(function() stopBoost() end)
forwardBtn.MouseLeave:Connect(function() stopBoost() end)

-- 后退按钮监听
backBtn.MouseButton1Down:Connect(function()
    backBtn.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
    startBoost(-1)
end)
backBtn.MouseButton1Up:Connect(function() stopBoost() end)
backBtn.MouseLeave:Connect(function() stopBoost() end)
