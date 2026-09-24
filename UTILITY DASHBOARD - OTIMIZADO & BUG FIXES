-- =========================================================
-- UTILITY DASHBOARD - OTIMIZADO & BUG FIXES
-- =========================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

-- Variáveis de Estado
local CurrentKeybind = Enum.KeyCode.F
local IsMinimizing = false
local IsBindingKey = false

local States = {
    TPClick = false,
    GodMode = false,
    GroundTracers = false,
    ESPBox = false,
    InfJump = false,
    Noclip = false,
    Fly = false,
    WalkSpeed = 16,
    FlySpeed = 50
}

local Cache = {
    Tracers = {},      -- Linhas de desenho
    PathData = {},     -- Rotas calculadas
    ESPBoxes = {},
    Connections = {}
}

-- =========================================================
-- INTERFACE PRINCIPAL
-- =========================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ModularDashboardGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 480, 0, 400)
MainFrame.Position = UDim2.new(0.3, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local SizeConstraint = Instance.new("UISizeConstraint")
SizeConstraint.MinSize = Vector2.new(360, 280)
SizeConstraint.MaxSize = Vector2.new(800, 650)
SizeConstraint.Parent = MainFrame

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 14)
MainCorner.Parent = MainFrame

-- =========================================================
-- CABEÇALHO (TÍTULO, KEYBIND E MINIMIZAR)
-- =========================================================

local HeaderBar = Instance.new("Frame")
HeaderBar.Size = UDim2.new(1, 0, 0, 40)
HeaderBar.BackgroundTransparency = 1
HeaderBar.Parent = MainFrame

local HeaderTitle = Instance.new("TextLabel")
HeaderTitle.Size = UDim2.new(1, -120, 1, 0)
HeaderTitle.Position = UDim2.new(0, 16, 0, 0)
HeaderTitle.BackgroundTransparency = 1
HeaderTitle.Text = "SYSTEM DASHBOARD"
HeaderTitle.TextColor3 = Color3.fromRGB(150, 150, 160)
HeaderTitle.Font = Enum.Font.GothamBold
HeaderTitle.TextSize = 12
HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
HeaderTitle.Parent = HeaderBar

local KeybindBtn = Instance.new("TextButton")
KeybindBtn.Size = UDim2.new(0, 32, 0, 22)
KeybindBtn.Position = UDim2.new(1, -72, 0.5, -11)
KeybindBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
KeybindBtn.Text = "F"
KeybindBtn.TextColor3 = Color3.fromRGB(0, 255, 170)
KeybindBtn.Font = Enum.Font.GothamBold
KeybindBtn.TextSize = 11
KeybindBtn.AutoButtonColor = false
KeybindBtn.Parent = HeaderBar

local KeybindCorner = Instance.new("UICorner")
KeybindCorner.CornerRadius = UDim.new(0, 6)
KeybindCorner.Parent = KeybindBtn

KeybindBtn.MouseButton1Click:Connect(function()
    IsBindingKey = true
    KeybindBtn.Text = "..."
    KeybindBtn.TextColor3 = Color3.fromRGB(255, 200, 0)
end)

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 28, 0, 22)
MinimizeBtn.Position = UDim2.new(1, -34, 0.5, -11)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
MinimizeBtn.Text = "-"
MinimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 14
MinimizeBtn.AutoButtonColor = false
MinimizeBtn.Parent = HeaderBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinimizeBtn

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, 0, 1, -40)
ContentFrame.Position = UDim2.new(0, 0, 0, 40)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

-- Prevenção de conflito de tamanho ao minimizar
local SavedSize = MainFrame.Size

MinimizeBtn.MouseButton1Click:Connect(function()
    IsMinimizing = not IsMinimizing
    if IsMinimizing then
        SavedSize = MainFrame.Size
        TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0, MainFrame.AbsoluteSize.X, 0, 40)}):Play()
        ContentFrame.Visible = false
        MinimizeBtn.Text = "+"
    else
        ContentFrame.Visible = true
        TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = SavedSize}):Play()
        MinimizeBtn.Text = "-"
    end
end)

-- =========================================================
-- GRID DE CARDS
-- =========================================================

local GridContainer = Instance.new("ScrollingFrame")
GridContainer.Size = UDim2.new(1, -24, 1, -55)
GridContainer.Position = UDim2.new(0, 12, 0, 5)
GridContainer.BackgroundTransparency = 1
GridContainer.BorderSizePixel = 0
GridContainer.ScrollBarThickness = 2
GridContainer.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 90)
GridContainer.Parent = ContentFrame

local UIGridLayout = Instance.new("UIGridLayout")
UIGridLayout.CellSize = UDim2.new(0.485, 0, 0, 80)
UIGridLayout.CellPadding = UDim2.new(0.03, 0, 0, 10)
UIGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIGridLayout.Parent = GridContainer

local function CreateDashboardCard(titleText, subText, tagColor, defaultState, callback)
    local Card = Instance.new("TextButton")
    Card.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
    Card.Text = ""
    Card.AutoButtonColor = false
    Card.Parent = GridContainer

    local CardCorner = Instance.new("UICorner")
    CardCorner.CornerRadius = UDim.new(0, 10)
    CardCorner.Parent = Card

    local Tag = Instance.new("Frame")
    Tag.Size = UDim2.new(0, 3, 0, 12)
    Tag.Position = UDim2.new(0, 10, 0, 12)
    Tag.BackgroundColor3 = tagColor
    Tag.BorderSizePixel = 0
    Tag.Parent = Card

    local TagCorner = Instance.new("UICorner")
    TagCorner.CornerRadius = UDim.new(1, 0)
    TagCorner.Parent = Tag

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -30, 0, 12)
    Title.Position = UDim2.new(0, 18, 0, 12)
    Title.BackgroundTransparency = 1
    Title.Text = string.upper(titleText)
    Title.TextColor3 = Color3.fromRGB(180, 180, 190)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 10
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Card

    local SubLabel = Instance.new("TextLabel")
    SubLabel.Size = UDim2.new(1, -20, 0, 26)
    SubLabel.Position = UDim2.new(0, 10, 0, 34)
    SubLabel.BackgroundTransparency = 1
    SubLabel.Text = subText
    SubLabel.TextColor3 = defaultState and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(110, 110, 120)
    SubLabel.Font = Enum.Font.GothamMedium
    SubLabel.TextSize = 12
    SubLabel.TextXAlignment = Enum.TextXAlignment.Left
    SubLabel.Parent = Card

    local state = defaultState

    Card.MouseEnter:Connect(function()
        TweenService:Create(Card, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(35, 35, 40)}):Play()
    end)
    Card.MouseLeave:Connect(function()
        TweenService:Create(Card, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(28, 28, 32)}):Play()
    end)

    Card.MouseButton1Click:Connect(function()
        state = not state
        if state then
            TweenService:Create(SubLabel, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
            TweenService:Create(Tag, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 255, 170)}):Play()
        else
            TweenService:Create(SubLabel, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(110, 110, 120)}):Play()
            TweenService:Create(Tag, TweenInfo.new(0.2), {BackgroundColor3 = tagColor}):Play()
        end
        callback(state)
    end)
end

-- =========================================================
-- INSTANCIANDO MÓDULOS
-- =========================================================
CreateDashboardCard("TP CLICK", "Ctrl + Clique Teleport", Color3.fromRGB(0, 170, 255), States.TPClick, function(v) States.TPClick = v end)
CreateDashboardCard("NOCLIP", "Atravessar Paredes", Color3.fromRGB(255, 170, 0), States.Noclip, function(v) States.Noclip = v end)
CreateDashboardCard("FLY MODE", "Voo Livre (WASDQE)", Color3.fromRGB(170, 0, 255), States.Fly, function(v) States.Fly = v end)

CreateDashboardCard("GROUND PATH", "Trilha pelo Chão", Color3.fromRGB(0, 255, 170), States.GroundTracers, function(v)
    States.GroundTracers = v
    if not v then
        for _, lines in pairs(Cache.Tracers) do
            for _, line in pairs(lines) do line.Visible = false end
        end
    end
end)

CreateDashboardCard("ESP BOX 2D", "Caixas nos Alvos", Color3.fromRGB(255, 0, 120), States.ESPBox, function(v)
    States.ESPBox = v
    if not v then
        for _, box in pairs(Cache.ESPBoxes) do box.Visible = false end
    end
end)

CreateDashboardCard("GOD MODE", "Regeneração de Vida", Color3.fromRGB(255, 50, 50), States.GodMode, function(v) States.GodMode = v end)
CreateDashboardCard("INF JUMP", "Pulo Infinito no Ar", Color3.fromRGB(255, 220, 0), States.InfJump, function(v) States.InfJump = v end)

CreateDashboardCard("SPEED BOOST", "Aumentar Velocidade", Color3.fromRGB(0, 220, 255), false, function(v)
    States.WalkSpeed = v and 55 or 16
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = States.WalkSpeed
    end
end)

local FooterCard = Instance.new("TextButton")
FooterCard.Size = UDim2.new(1, -24, 0, 36)
FooterCard.Position = UDim2.new(0, 12, 1, -44)
FooterCard.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
FooterCard.Text = "Deletar Script & Limpar Memória"
FooterCard.TextColor3 = Color3.fromRGB(220, 80, 80)
FooterCard.Font = Enum.Font.GothamMedium
FooterCard.TextSize = 11
FooterCard.AutoButtonColor = false
FooterCard.Parent = ContentFrame

local FooterCorner = Instance.new("UICorner")
FooterCorner.CornerRadius = UDim.new(0, 8)
FooterCorner.Parent = FooterCard

-- =========================================================
-- PEGA DE REDIMENSIONAMENTO MANUAL (BUGFIX DE OFFSET/SCALE)
-- =========================================================
local ResizeGrip = Instance.new("Frame")
ResizeGrip.Size = UDim2.new(0, 14, 0, 14)
ResizeGrip.Position = UDim2.new(1, -14, 1, -14)
ResizeGrip.BackgroundTransparency = 1
ResizeGrip.Active = true
ResizeGrip.Parent = MainFrame

local ResizeIcon = Instance.new("TextLabel")
ResizeIcon.Size = UDim2.new(1, 0, 1, 0)
ResizeIcon.BackgroundTransparency = 1
ResizeIcon.Text = "◢"
ResizeIcon.TextColor3 = Color3.fromRGB(80, 80, 90)
ResizeIcon.Font = Enum.Font.GothamBold
ResizeIcon.TextSize = 12
ResizeIcon.Parent = ResizeGrip

local IsResizing = false
local StartAbsSize, StartMouse

ResizeGrip.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and not IsMinimizing then
        IsResizing = true
        StartAbsSize = MainFrame.AbsoluteSize
        StartMouse = UserInputService:GetMouseLocation()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        IsResizing = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if IsResizing and input.UserInputType == Enum.UserInputType.MouseMovement then
        local MouseLoc = UserInputService:GetMouseLocation()
        local Delta = MouseLoc - StartMouse
        MainFrame.Size = UDim2.new(0, math.clamp(StartAbsSize.X + Delta.X, 360, 800), 0, math.clamp(StartAbsSize.Y + Delta.Y, 280, 650))
    end
end)

-- =========================================================
-- LÓGICA DO PATHFINDING E ESP (OTIMIZADO)
-- =========================================================

local function GetGroundPosition(position)
    local raycastParams = RaycastParams.new()
    local success = pcall(function() raycastParams.FilterType = Enum.RaycastFilterType.Exclude end)
    if not success then pcall(function() raycastParams.FilterType = Enum.RaycastFilterType.Blacklist end) end

    if LocalPlayer.Character then
        raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    end

    local rayResult = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -100, 0), raycastParams)
    return rayResult and (rayResult.Position + Vector3.new(0, 0.2, 0)) or position
end

-- Thread paralela apenas para calcular rotas, salva a sua CPU/FPS (Bugfix 1)
task.spawn(function()
    while task.wait(0.5) do
        if not States.GroundTracers then continue end
        local myChar = LocalPlayer.Character
        if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then continue end
        local myPos = myChar.HumanoidRootPart.Position

        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = false})
                pcall(function()
                    path:ComputeAsync(GetGroundPosition(myPos), GetGroundPosition(plr.Character.HumanoidRootPart.Position))
                    Cache.PathData[plr.Name] = path:GetWaypoints()
                end)
            end
        end
    end
end)

-- =========================================================
-- EVENTOS DE TECLADO & LOOP PRINCIPAL
-- =========================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if IsBindingKey and input.UserInputType == Enum.UserInputType.Keyboard then
        CurrentKeybind = input.KeyCode
        KeybindBtn.Text = string.upper(input.KeyCode.Name)
        KeybindBtn.TextColor3 = Color3.fromRGB(0, 255, 170)
        IsBindingKey = false
        return
    end
    if not gameProcessed and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == CurrentKeybind then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

Mouse.Button1Down:Connect(function()
    if States.TPClick and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and Mouse.Hit then
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0, 3, 0))
        end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if States.InfJump and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- Limpeza de Memória para evitar ESP Fantasma (Bugfix 3)
Players.PlayerRemoving:Connect(function(plr)
    if Cache.Tracers[plr.Name] then
        for _, line in pairs(Cache.Tracers[plr.Name]) do line:Remove() end
        Cache.Tracers[plr.Name] = nil
    end
    if Cache.ESPBoxes[plr.Name] then
        Cache.ESPBoxes[plr.Name]:Remove()
        Cache.ESPBoxes[plr.Name] = nil
    end
    Cache.PathData[plr.Name] = nil
end)

Cache.Connections.Render = RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    if States.GodMode and char:FindFirstChildOfClass("Humanoid") then
        char:FindFirstChildOfClass("Humanoid").Health = char:FindFirstChildOfClass("Humanoid").MaxHealth
    end
    if States.Noclip then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
    if States.Fly then
        local hrp = char.HumanoidRootPart
        local moveDir = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) then moveDir = moveDir - Vector3.new(0, 1, 0) end
        hrp.Velocity = moveDir * States.FlySpeed
    end

    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local validTarget = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            
            -- Renderização do ESP Box
            if States.ESPBox and validTarget then
                local screenPos, onScreen = Camera:WorldToViewportPoint(plr.Character.HumanoidRootPart.Position)
                local box = Cache.ESPBoxes[plr.Name] or Drawing.new("Square")
                Cache.ESPBoxes[plr.Name] = box

                if onScreen then
                    local sizeX = 1000 / screenPos.Z
                    local sizeY = 1400 / screenPos.Z
                    box.Size = Vector2.new(sizeX, sizeY)
                    box.Position = Vector2.new(screenPos.X - sizeX / 2, screenPos.Y - sizeY / 2)
                    box.Color = Color3.fromRGB(255, 0, 120)
                    box.Thickness = 1.5
                    box.Filled = false
                    box.Visible = true
                else
                    box.Visible = false
                end
            elseif Cache.ESPBoxes[plr.Name] then
                Cache.ESPBoxes[plr.Name].Visible = false
            end

            -- Renderização do Ground Pathing
            if States.GroundTracers and validTarget and Cache.PathData[plr.Name] then
                Cache.Tracers[plr.Name] = Cache.Tracers[plr.Name] or {}
                local lines = Cache.Tracers[plr.Name]
                local waypoints = Cache.PathData[plr.Name]

                for i = #waypoints, #lines do if lines[i] then lines[i].Visible = false end end

                for i = 1, #waypoints - 1 do
                    local p1, onScreen1 = Camera:WorldToViewportPoint(waypoints[i].Position + Vector3.new(0, 0.1, 0))
                    local p2, onScreen2 = Camera:WorldToViewportPoint(waypoints[i+1].Position + Vector3.new(0, 0.1, 0))
                    
                    lines[i] = lines[i] or Drawing.new("Line")
                    local line = lines[i]

                    if onScreen1 or onScreen2 then
                        line.From = Vector2.new(p1.X, p1.Y)
                        line.To = Vector2.new(p2.X, p2.Y)
                        line.Color = Color3.fromRGB(0, 255, 170)
                        line.Thickness = 1.8
                        line.Transparency = 0.85
                        line.Visible = true
                    else
                        line.Visible = false
                    end
                end
            elseif Cache.Tracers[plr.Name] then
                for _, line in pairs(Cache.Tracers[plr.Name]) do line.Visible = false end
            end
        end
    end
end)

-- =========================================================
-- FINALIZAR E LIMPAR MEMÓRIA COMPLETA
-- =========================================================
FooterCard.MouseButton1Click:Connect(function()
    for _, conn in pairs(Cache.Connections) do conn:Disconnect() end
    for _, lines in pairs(Cache.Tracers) do for _, line in pairs(lines) do line:Remove() end end
    for _, box in pairs(Cache.ESPBoxes) do box:Remove() end

    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = 16
    end
    ScreenGui:Destroy()
end)
