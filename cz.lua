--[[
	车辆悬浮加速器 (帧加速控制版)
	新增：可以自定义每帧增加的速度（控制推背感）。
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui") -- 如果报错，改成 player:WaitForChild("PlayerGui")

local player = Players.LocalPlayer

-- ================= 配置区 =================
local DEFAULT_MAX_SPEED = 300
local DEFAULT_ACCELERATION = 10 -- 默认每帧增加10速度
local currentSpeed = 0
local isBoosting = false
local isLocked = false
local boostPart = nil
local currentSeat = nil
local bindKey = Enum.KeyCode.LeftShift

-- ================= UI 界面 =================
local gui = Instance.new("ScreenGui")
gui.Name = "VehicleBoostGUI"
gui.ResetOnSpawn = false
gui.Parent = CoreGui

local mainFrame = Instance.new("Frame")
-- 高度从 150 增加到 180，为了放下新的输入框
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
title.Text = "🚗 车辆加速器"
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

-- 2. 【新增】每帧加速度设置
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

-- 4. 加速按钮
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
    
    if currentSeat and (currentSeat:IsA("VehicleSeat") or currentSeat.Name:lower():find("seat")) then
        isBoosting = true
        
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
    boostBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
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
        
        -- 读取UI里的参数
        local maxSpd = tonumber(speedInput.Text) or DEFAULT_MAX_SPEED
        local frameAccel = tonumber(accelInput.Text) or DEFAULT_ACCELERATION
        
        -- 防止输入负数或0导致不加速
        if frameAccel < 0.1 then frameAccel = 0.1 end
        
        local look = currentSeat.CFrame.LookVector
        
        -- 【核心修改】：每帧增加自定义的加速度
        currentSpeed = math.min(currentSpeed + frameAccel, maxSpd)
        
        boostPart.AssemblyLinearVelocity = look * currentSpeed
    end
end)

-- ================= 输入监听 =================
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

boostBtn.MouseButton1Down:Connect(function()
    boostBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    startBoost()
end)

boostBtn.MouseButton1Up:Connect(function()
    stopBoost()
end)

boostBtn.MouseLeave:Connect(function()
    stopBoost()
end)
