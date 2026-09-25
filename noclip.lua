local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

---------------------------------------------------------
-- 0. CLEANUP & ANTI-DUPLICAÇÃO
---------------------------------------------------------
if _G.NoclipCleanup then
	_G.NoclipCleanup()
end

local oldGui = PlayerGui:FindFirstChild("NoclipModernGUI")
if oldGui then
	oldGui:Destroy()
end

---------------------------------------------------------
-- ESTADO E VARIÁVEIS GLOBAIS
---------------------------------------------------------
local isNoclipping = false
local noclipConnection = nil
local hideToastTask = nil
local currentKeybind = Enum.KeyCode.N -- Tecla padrão: N
local isListeningForKey = false

local modifiedParts = {}
local RADIUS = 7

---------------------------------------------------------
-- FUNÇÕES AUXILIARES DE ANIMAÇÃO (MOTION)
---------------------------------------------------------
local function tween(object, duration, properties, easingStyle, easingDirection)
	easingStyle = easingStyle or Enum.EasingStyle.Quart
	easingDirection = easingDirection or Enum.EasingDirection.Out
	local tweenInfo = TweenInfo.new(duration, easingStyle, easingDirection)
	local t = TweenService:Create(object, tweenInfo, properties)
	t:Play()
	return t
end

local function restoreParts()
	for part, originalState in pairs(modifiedParts) do
		if part and part.Parent then
			part.CanCollide = originalState
		end
	end
	table.clear(modifiedParts)
end

-- Função de Desinstalação / Remoção do Script
local function unloadScript()
	if noclipConnection then
		noclipConnection:Disconnect()
		noclipConnection = nil
	end
	restoreParts()
	
	local character = LocalPlayer.Character
	if character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = true
			end
		end
	end
	
	local gui = PlayerGui:FindFirstChild("NoclipModernGUI")
	if gui then gui:Destroy() end
	_G.NoclipCleanup = nil
end

_G.NoclipCleanup = unloadScript

---------------------------------------------------------
-- 1. INTERFACE GRÁFICA (TEMA DARK / SLATE)
---------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NoclipModernGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = PlayerGui

-- PALETA DE CORES
local BG_COLOR = Color3.fromRGB(20, 20, 23)
local CARD_COLOR = Color3.fromRGB(28, 28, 32)
local STROKE_COLOR = Color3.fromRGB(45, 45, 52)
local PRIMARY_PILL = Color3.fromRGB(235, 235, 240)
local PRIMARY_TEXT = Color3.fromRGB(18, 18, 22)
local SECONDARY_PILL = Color3.fromRGB(38, 38, 44)
local SECONDARY_TEXT = Color3.fromRGB(200, 200, 210)
local GREEN_ACCENT = Color3.fromRGB(46, 204, 113)
local RED_ACCENT = Color3.fromRGB(231, 76, 60)

---------------------------------------------------------
-- TELA DE LOADER
---------------------------------------------------------
local loaderCard = Instance.new("Frame")
loaderCard.Name = "LoaderCard"
loaderCard.Size = UDim2.new(0, 310, 0, 100)
loaderCard.Position = UDim2.new(0.5, -155, 0.45, 0)
loaderCard.BackgroundColor3 = BG_COLOR
loaderCard.BorderSizePixel = 0
loaderCard.BackgroundTransparency = 1
loaderCard.Parent = screenGui

local loaderCorner = Instance.new("UICorner")
loaderCorner.CornerRadius = UDim.new(0, 18)
loaderCorner.Parent = loaderCard

local loaderStroke = Instance.new("UIStroke")
loaderStroke.Color = STROKE_COLOR
loaderStroke.Thickness = 1.2
loaderStroke.Transparency = 1
loaderStroke.Parent = loaderCard

local loaderStatus = Instance.new("TextLabel")
loaderStatus.Size = UDim2.new(1, -40, 0, 28)
loaderStatus.Position = UDim2.new(0, 20, 0, 20)
loaderStatus.BackgroundTransparency = 1
loaderStatus.TextColor3 = Color3.fromRGB(240, 240, 245)
loaderStatus.Font = Enum.Font.SourceSansBold
loaderStatus.TextSize = 16
loaderStatus.TextXAlignment = Enum.TextXAlignment.Left
loaderStatus.Text = "Carregando Noclip Pro..."
loaderStatus.TextTransparency = 1
loaderStatus.Parent = loaderCard

local loaderSub = Instance.new("TextLabel")
loaderSub.Size = UDim2.new(1, -40, 0, 20)
loaderSub.Position = UDim2.new(0, 20, 0, 48)
loaderSub.BackgroundTransparency = 1
loaderSub.TextColor3 = Color3.fromRGB(140, 140, 150)
loaderSub.Font = Enum.Font.SourceSans
loaderSub.TextSize = 13
loaderSub.TextXAlignment = Enum.TextXAlignment.Left
loaderSub.Text = "Configurando interface e atalhos..."
loaderSub.TextTransparency = 1
loaderSub.Parent = loaderCard

-- Animação do Loader
task.spawn(function()
	tween(loaderCard, 0.4, {BackgroundTransparency = 0, Position = UDim2.new(0.5, -155, 0.4, 0)})
	tween(loaderStroke, 0.4, {Transparency = 0})
	tween(loaderStatus, 0.4, {TextTransparency = 0})
	tween(loaderSub, 0.4, {TextTransparency = 0})
	
	task.wait(0.6)
	loaderStatus.Text = "Pronto!"
	loaderSub.Text = "Interface carregada com sucesso."
	
	task.wait(0.5)
	tween(loaderCard, 0.3, {BackgroundTransparency = 1, Position = UDim2.new(0.5, -155, 0.38, 0)})
	tween(loaderStroke, 0.3, {Transparency = 1})
	tween(loaderStatus, 0.3, {TextTransparency = 1})
	tween(loaderSub, 0.3, {TextTransparency = 1})
	
	task.wait(0.3)
	loaderCard:Destroy()
end)

---------------------------------------------------------
-- NOTIFICAÇÃO DE STATUS (CANTO INFERIOR ESQUERDO)
---------------------------------------------------------
local toast = Instance.new("Frame")
toast.Name = "ToastNotification"
toast.Size = UDim2.new(0, 220, 0, 46)
toast.Position = UDim2.new(0, -250, 1, -66) 
toast.BackgroundColor3 = BG_COLOR
toast.BorderSizePixel = 0
toast.Parent = screenGui

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 14)
toastCorner.Parent = toast

local toastStroke = Instance.new("UIStroke")
toastStroke.Color = STROKE_COLOR
toastStroke.Thickness = 1.2
toastStroke.Parent = toast

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(0, 16, 0.5, -4)
statusDot.BackgroundColor3 = GREEN_ACCENT
statusDot.BorderSizePixel = 0
statusDot.Parent = toast

local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = statusDot

local toastLabel = Instance.new("TextLabel")
toastLabel.Size = UDim2.new(1, -40, 1, 0)
toastLabel.Position = UDim2.new(0, 32, 0, 0)
toastLabel.BackgroundTransparency = 1
toastLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
toastLabel.Font = Enum.Font.SourceSansBold
toastLabel.TextSize = 14
toastLabel.TextXAlignment = Enum.TextXAlignment.Left
toastLabel.Text = "Noclip Ativado"
toastLabel.Parent = toast

local function showToast(text, color, keepVisible)
	if hideToastTask then
		task.cancel(hideToastTask)
		hideToastTask = nil
	end

	toastLabel.Text = text
	statusDot.BackgroundColor3 = color
	
	tween(toast, 0.4, {Position = UDim2.new(0, 20, 1, -66)}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

	if not keepVisible then
		hideToastTask = task.delay(5, function()
			tween(toast, 0.4, {Position = UDim2.new(0, -250, 1, -66)}, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
			hideToastTask = nil
		end)
	end
end

---------------------------------------------------------
-- MENU PRINCIPAL E BOTOEIRA (ESTILO IMAGEM 2)
---------------------------------------------------------
local menu = Instance.new("Frame")
menu.Name = "MainMenu"
menu.Size = UDim2.new(0, 270, 0, 150)
menu.Position = UDim2.new(0, 20, 0.2, 0)
menu.BackgroundColor3 = BG_COLOR
menu.BorderSizePixel = 0
menu.Parent = screenGui

local menuCorner = Instance.new("UICorner")
menuCorner.CornerRadius = UDim.new(0, 18)
menuCorner.Parent = menu

local menuStroke = Instance.new("UIStroke")
menuStroke.Color = STROKE_COLOR
menuStroke.Thickness = 1.2
menuStroke.Parent = menu

-- Título
local menuTitle = Instance.new("TextLabel")
menuTitle.Size = UDim2.new(0, 120, 0, 42)
menuTitle.Position = UDim2.new(0, 16, 0, 0)
menuTitle.BackgroundTransparency = 1
menuTitle.TextColor3 = Color3.fromRGB(240, 240, 245)
menuTitle.Font = Enum.Font.SourceSansBold
menuTitle.TextSize = 15
menuTitle.TextXAlignment = Enum.TextXAlignment.Left
menuTitle.Text = "Noclip Control"
menuTitle.Parent = menu

-- BOTOEIRA DIREITA (Inspirada no design enviado)
local actionPod = Instance.new("Frame")
actionPod.Name = "ActionPod"
actionPod.Size = UDim2.new(0, 80, 0, 32)
actionPod.Position = UDim2.new(1, -92, 0, 7)
actionPod.BackgroundColor3 = Color3.fromRGB(14, 14, 17)
actionPod.BorderSizePixel = 0
actionPod.Parent = menu

local podCorner = Instance.new("UICorner")
podCorner.CornerRadius = UDim.new(0, 12)
podCorner.Parent = actionPod

local podStroke = Instance.new("UIStroke")
podStroke.Color = STROKE_COLOR
podStroke.Thickness = 1
podStroke.Parent = actionPod

-- Botão de Excluir Script (Ícone de Lixeira/Fechar)
local deleteBtn = Instance.new("TextButton")
deleteBtn.Name = "DeleteBtn"
deleteBtn.Size = UDim2.new(0, 26, 0, 26)
deleteBtn.Position = UDim2.new(0, 3, 0.5, -13)
deleteBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
deleteBtn.TextColor3 = RED_ACCENT
deleteBtn.Font = Enum.Font.SourceSansBold
deleteBtn.TextSize = 14
deleteBtn.Text = "✕"
deleteBtn.AutoButtonColor = false
deleteBtn.Parent = actionPod

local delCorner = Instance.new("UICorner")
delCorner.CornerRadius = UDim.new(1, 0)
delCorner.Parent = deleteBtn

-- Botão de Minimizar (-)
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name = "MinimizeBtn"
minimizeBtn.Size = UDim2.new(0, 26, 0, 26)
minimizeBtn.Position = UDim2.new(1, -29, 0.5, -13)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
minimizeBtn.Font = Enum.Font.SourceSansBold
minimizeBtn.TextSize = 16
minimizeBtn.Text = "-"
minimizeBtn.AutoButtonColor = false
minimizeBtn.Parent = actionPod

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(1, 0)
minCorner.Parent = minimizeBtn

-- Conteúdo Central
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "ToggleBtn"
toggleBtn.Size = UDim2.new(1, -30, 0, 38)
toggleBtn.Position = UDim2.new(0, 15, 0, 48)
toggleBtn.BackgroundColor3 = SECONDARY_PILL
toggleBtn.TextColor3 = SECONDARY_TEXT
toggleBtn.Font = Enum.Font.SourceSansBold
toggleBtn.TextSize = 14
toggleBtn.Text = "Status: DESATIVADO"
toggleBtn.AutoButtonColor = false
toggleBtn.Parent = menu

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 12)
toggleCorner.Parent = toggleBtn

local keybindBtn = Instance.new("TextButton")
keybindBtn.Name = "KeybindBtn"
keybindBtn.Size = UDim2.new(1, -30, 0, 38)
keybindBtn.Position = UDim2.new(0, 15, 0, 94)
keybindBtn.BackgroundColor3 = CARD_COLOR
keybindBtn.TextColor3 = Color3.fromRGB(170, 170, 180)
keybindBtn.Font = Enum.Font.SourceSans
keybindBtn.TextSize = 13
keybindBtn.Text = "Atalho: [ N ]"
keybindBtn.AutoButtonColor = false
keybindBtn.Parent = menu

local keybindCorner = Instance.new("UICorner")
keybindCorner.CornerRadius = UDim.new(0, 12)
keybindCorner.Parent = keybindBtn

---------------------------------------------------------
-- WIDGET FLUTUANTE DE MINIMIZADO (COM ATALHO)
---------------------------------------------------------
local minWidget = Instance.new("TextButton")
minWidget.Name = "MinimizedWidget"
minWidget.Size = UDim2.new(0, 210, 0, 40)
minWidget.Position = UDim2.new(0, 20, 0.2, 0)
minWidget.BackgroundColor3 = BG_COLOR
minWidget.TextColor3 = Color3.fromRGB(220, 220, 230)
minWidget.Font = Enum.Font.SourceSansBold
minWidget.TextSize = 13
minWidget.Text = "Pressione [ N ] para abrir"
minWidget.AutoButtonColor = false
minWidget.Visible = false
minWidget.Parent = screenGui

local minWidgetCorner = Instance.new("UICorner")
minWidgetCorner.CornerRadius = UDim.new(0, 12)
minWidgetCorner.Parent = minWidget

local minWidgetStroke = Instance.new("UIStroke")
minWidgetStroke.Color = STROKE_COLOR
minWidgetStroke.Thickness = 1.2
minWidgetStroke.Parent = minWidget

---------------------------------------------------------
-- SISTEMA PARA ARRASTAR A INTERFACE (DRAG)
---------------------------------------------------------
local function makeDraggable(frame)
	local dragging, dragInput, dragStart, startPos
	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
		end
	end)

	frame.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			tween(frame, 0.05, {Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)})
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

makeDraggable(menu)
makeDraggable(minWidget)

---------------------------------------------------------
-- LÓGICA DE MINIMIZAR / EXPANDIR / EXCLUIR
---------------------------------------------------------
local function updateMinWidgetText()
	if currentKeybind then
		minWidget.Text = "Pressione [ " .. currentKeybind.Name .. " ] para abrir"
	else
		minWidget.Text = "Clique para abrir o menu"
	end
end

local function toggleMinimize()
	if menu.Visible then
		updateMinWidgetText()
		minWidget.Position = menu.Position
		
		tween(menu, 0.25, {Size = UDim2.new(0, 270, 0, 0), BackgroundTransparency = 1}).Completed:Connect(function()
			menu.Visible = false
			menu.Size = UDim2.new(0, 270, 0, 150)
			menu.BackgroundTransparency = 0
		end)
		
		minWidget.Visible = true
		tween(minWidget, 0.25, {BackgroundTransparency = 0})
	else
		menu.Position = minWidget.Position
		menu.Visible = true
		minWidget.Visible = false
		tween(menu, 0.25, {Size = UDim2.new(0, 270, 0, 150)})
	end
end

minimizeBtn.MouseButton1Click:Connect(toggleMinimize)
minWidget.MouseButton1Click:Connect(toggleMinimize)

deleteBtn.MouseButton1Click:Connect(function()
	showToast("Script Excluído!", RED_ACCENT, false)
	task.wait(0.3)
	unloadScript()
end)

---------------------------------------------------------
-- FILTRO DE CHÃO (ANTI-QUEDA)
---------------------------------------------------------
local function isGround(part, character, rootPart)
	if not part or not rootPart then return true end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {character}

	local rayResult = Workspace:Raycast(rootPart.Position, Vector3.new(0, -6, 0), raycastParams)
	if rayResult and rayResult.Instance == part then
		return true
	end

	local feetY = rootPart.Position.Y - 2.8
	local partTopY = part.Position.Y + (part.Size.Y / 2)

	if partTopY <= feetY + 0.5 then
		return true
	end

	return false
end

---------------------------------------------------------
-- LÓGICA PRINCIPAL DO NOCLIP
---------------------------------------------------------
local function toggleNoclip()
	isNoclipping = not isNoclipping

	if isNoclipping then
		-- ATIVADO
		tween(toggleBtn, 0.2, {BackgroundColor3 = PRIMARY_PILL, TextColor3 = PRIMARY_TEXT})
		toggleBtn.Text = "Status: ATIVADO"

		showToast("Noclip Ativado", GREEN_ACCENT, true)

		noclipConnection = RunService.Stepped:Connect(function()
			local character = LocalPlayer.Character
			if not character then return end

			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if not rootPart then return end

			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end

			local overlapParams = OverlapParams.new()
			overlapParams.FilterType = Enum.RaycastFilterType.Exclude
			overlapParams.FilterDescendantsInstances = {character}

			local nearbyParts = Workspace:GetPartBoundsInRadius(rootPart.Position, RADIUS, overlapParams)
			local currentNearby = {}

			for _, part in ipairs(nearbyParts) do
				if part:IsA("BasePart") and part.Anchored then
					if not isGround(part, character, rootPart) then
						currentNearby[part] = true
						if modifiedParts[part] == nil then
							modifiedParts[part] = part.CanCollide
						end
						part.CanCollide = false
					end
				end
			end

			for part, originalState in pairs(modifiedParts) do
				if not currentNearby[part] then
					if part and part.Parent then
						part.CanCollide = originalState
					end
					modifiedParts[part] = nil
				end
			end
		end)
	else
		-- DESATIVADO
		tween(toggleBtn, 0.2, {BackgroundColor3 = SECONDARY_PILL, TextColor3 = SECONDARY_TEXT})
		toggleBtn.Text = "Status: DESATIVADO"

		if noclipConnection then
			noclipConnection:Disconnect()
			noclipConnection = nil
		end

		restoreParts()

		local character = LocalPlayer.Character
		if character then
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = true
				end
			end
		end

		showToast("Noclip Desativado", RED_ACCENT, false)
	end
end

---------------------------------------------------------
-- GERENCIADOR DE ATALHO (KEYBIND SYSTEM)
---------------------------------------------------------
toggleBtn.MouseButton1Click:Connect(toggleNoclip)

keybindBtn.MouseButton1Click:Connect(function()
	isListeningForKey = true
	keybindBtn.Text = "Pressione uma tecla..."
	tween(keybindBtn, 0.2, {BackgroundColor3 = SECONDARY_PILL, TextColor3 = Color3.fromRGB(255, 255, 255)})
end)

-- Clique com Botão Direito = Remover Atalho
keybindBtn.MouseButton2Click:Connect(function()
	currentKeybind = nil
	isListeningForKey = false
	keybindBtn.Text = "Atalho: [ Nenhum ]"
	updateMinWidgetText()
	tween(keybindBtn, 0.2, {BackgroundColor3 = CARD_COLOR, TextColor3 = Color3.fromRGB(170, 170, 180)})
	showToast("Atalho removido", RED_ACCENT, false)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if isListeningForKey then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Escape then
				currentKeybind = nil
				keybindBtn.Text = "Atalho: [ Nenhum ]"
				showToast("Atalho removido", RED_ACCENT, false)
			else
				currentKeybind = input.KeyCode
				keybindBtn.Text = "Atalho: [ " .. currentKeybind.Name .. " ]"
				showToast("Atalho salvo: " .. currentKeybind.Name, GREEN_ACCENT, false)
			end
			
			updateMinWidgetText()
			isListeningForKey = false
			tween(keybindBtn, 0.2, {BackgroundColor3 = CARD_COLOR, TextColor3 = Color3.fromRGB(170, 170, 180)})
		end
		return
	end

	if not gameProcessed and currentKeybind and input.KeyCode == currentKeybind then
		if not menu.Visible and minWidget.Visible then
			toggleMinimize() -- Se estiver minimizado, expande a janela ao pressionar
		else
			toggleNoclip() -- Caso contrário, alterna o Noclip
		end
	end
end)
