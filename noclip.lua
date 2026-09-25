local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

---------------------------------------------------------
-- CONFIGURAÇÕES, WEBHOOK E DISCORD
---------------------------------------------------------
local DISCORD_LINK = "https://discord.gg/rXZs7tzrN3"
local WEBHOOK_URL = "https://discord.com/api/webhooks/1552878552620474368/EMpbzFEzX93tCqCfbZh1TvJ7DFt7v64WI_ZwZ0rICF_BV90Nir62PfYFBnIUg8Abi0-s"
local KEY_FILE_PATH = "zynk_auth_session.json"
local KEY_DURATION_HOURS = 12

math.randomseed(os.time() + tick())
local function generateKey()
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	local key = "ZYNK-"
	for i = 1, 6 do
		local rand = math.random(1, #chars)
		key = key .. string.sub(chars, rand, rand)
	end
	return key
end

local GENERATED_KEY = generateKey()

---------------------------------------------------------
-- ÍCONES PERSONALIZADOS
---------------------------------------------------------
local ICONS = {
	Principal = "rbxassetid://18979524646",
	Server = "rbxassetid://95498291180289",
	Status = "rbxassetid://116037492872893"
}

---------------------------------------------------------
-- CLEANUP & ANTI-DUPLICAÇÃO
---------------------------------------------------------
if _G.ZynkCleanup then
	_G.ZynkCleanup()
end

local oldGui = PlayerGui:FindFirstChild("ZynkMenuGUI")
if oldGui then
	oldGui:Destroy()
end

---------------------------------------------------------
-- ESTADOS E VARIÁVEIS GLOBAL
---------------------------------------------------------
local isNoclipping = false
local isRegenActive = false
local isESPActive = false
local isAuthenticated = false

local noclipConnection = nil
local regenConnection = nil
local hideToastTask = nil

local espPlayerAddedConn = nil
local espPlayerRemovingConn = nil
local espCharAddedConns = {}
local espHighlights = {}

local keybinds = {
	Noclip = Enum.KeyCode.N,
	Regen = Enum.KeyCode.R,
	ESP = Enum.KeyCode.E,
	Menu = Enum.KeyCode.M
}

local listeningTarget = nil 
local modifiedParts = {}
local RADIUS = 7

---------------------------------------------------------
-- SISTEMA DE ANTI-VISÃO (AUTOCONTRASTE)
---------------------------------------------------------
local function getLuminance(color)
	return (0.2126 * color.R) + (0.7152 * color.G) + (0.0722 * color.B)
end

local function getContrastRatio(c1, c2)
	local l1 = getLuminance(c1)
	local l2 = getLuminance(c2)
	if l1 < l2 then l1, l2 = l2, l1 end
	return (l1 + 0.05) / (l2 + 0.05)
end

local function getReadableTextColor(bgColor, preferredColor)
	preferredColor = preferredColor or Color3.fromRGB(30, 32, 38)
	local ratio = getContrastRatio(bgColor, preferredColor)
	if ratio < 3 then
		if getLuminance(bgColor) < 0.5 then
			return Color3.fromRGB(255, 255, 255)
		else
			return Color3.fromRGB(20, 20, 25)
		end
	end
	return preferredColor
end

---------------------------------------------------------
-- SISTEMA DE PERSISTÊNCIA DA KEY (12 HORAS)
---------------------------------------------------------
local function saveKeyLocally(key)
	if writefile then
		pcall(function()
			local data = {
				key = key,
				expiresAt = os.time() + (KEY_DURATION_HOURS * 3600)
			}
			writefile(KEY_FILE_PATH, HttpService:JSONEncode(data))
		end)
	end
end

local function loadKeyLocally()
	if readfile and isfile and isfile(KEY_FILE_PATH) then
		local success, result = pcall(function()
			local content = readfile(KEY_FILE_PATH)
			return HttpService:JSONDecode(content)
		end)
		if success and result and result.expiresAt then
			if os.time() < result.expiresAt then
				return result
			end
		end
	end
	return nil
end

---------------------------------------------------------
-- MOTOR DE ANIMAÇÕES SUAVES E INTERAÇÕES
---------------------------------------------------------
local function tween(object, duration, properties, easingStyle, easingDirection)
	easingStyle = easingStyle or Enum.EasingStyle.Quart
	easingDirection = easingDirection or Enum.EasingDirection.Out
	local tweenInfo = TweenInfo.new(duration, easingStyle, easingDirection)
	local t = TweenService:Create(object, tweenInfo, properties)
	t:Play()
	return t
end

local function addInteractiveAnimations(button, defaultBg, hoverBg)
	local uiScale = button:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = button
	end

	button.MouseEnter:Connect(function()
		tween(button, 0.2, {BackgroundColor3 = hoverBg or defaultBg})
		tween(uiScale, 0.2, {Scale = 1.04}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end)

	button.MouseLeave:Connect(function()
		tween(button, 0.2, {BackgroundColor3 = defaultBg})
		tween(uiScale, 0.2, {Scale = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end)

	button.MouseButton1Down:Connect(function()
		tween(uiScale, 0.1, {Scale = 0.94}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end)

	button.MouseButton1Up:Connect(function()
		tween(uiScale, 0.15, {Scale = 1.04}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	end)
end

---------------------------------------------------------
-- FUNÇÕES AUXILIARES
---------------------------------------------------------
local function copyToClipboard(text)
	local setClip = setclipboard or toclipboard or (syn and syn.write_clipboard)
	if setClip then
		setClip(text)
		return true
	end
	return false
end

local function sendWebhookLog(statusTitle, statusColor, desc)
	local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request
	
	local payload = {
		["embeds"] = {{
			["title"] = statusTitle,
			["color"] = statusColor,
			["description"] = desc,
			["fields"] = {
				{ ["name"] = "Jogador", ["value"] = LocalPlayer.Name .. " (@" .. LocalPlayer.DisplayName .. ")", ["inline"] = true },
				{ ["name"] = "User ID", ["value"] = tostring(LocalPlayer.UserId), ["inline"] = true },
				{ ["name"] = "Código de Acesso", ["value"] = "```" .. GENERATED_KEY .. "```", ["inline"] = false }
			},
			["footer"] = { ["text"] = "Zynk Menu • Status" },
			["timestamp"] = DateTime.now():ToIsoDate()
		}}
	}

	local jsonData = HttpService:JSONEncode(payload)

	if requestFunc then
		pcall(function()
			requestFunc({
				Url = WEBHOOK_URL,
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = jsonData
			})
		end)
	else
		pcall(function()
			HttpService:PostAsync(WEBHOOK_URL, jsonData, Enum.HttpContentType.ApplicationJson)
		end)
	end
end

local function restoreParts()
	for part, originalState in pairs(modifiedParts) do
		if part and part.Parent then
			part.CanCollide = originalState
		end
	end
	table.clear(modifiedParts)
end

---------------------------------------------------------
-- DESCARREGAMENTO (UNLOAD)
---------------------------------------------------------
local function removeESPFromPlayer(player)
	if espHighlights[player] then
		espHighlights[player]:Destroy()
		espHighlights[player] = nil
	end
	if player.Character then
		local hl = player.Character:FindFirstChild("ZynkESP_HL")
		if hl then hl:Destroy() end
		local bb = player.Character:FindFirstChild("ZynkESP_Tag")
		if bb then bb:Destroy() end
	end
end

local function clearAllESP()
	if espPlayerAddedConn then espPlayerAddedConn:Disconnect() espPlayerAddedConn = nil end
	if espPlayerRemovingConn then espPlayerRemovingConn:Disconnect() espPlayerRemovingConn = nil end
	for p, conn in pairs(espCharAddedConns) do conn:Disconnect() end
	table.clear(espCharAddedConns)
	for _, p in ipairs(Players:GetPlayers()) do removeESPFromPlayer(p) end
end

local function unloadScript()
	if noclipConnection then noclipConnection:Disconnect() end
	if regenConnection then regenConnection:Disconnect() end
	clearAllESP()
	restoreParts()
	
	local character = LocalPlayer.Character
	if character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then part.CanCollide = true end
		end
	end
	
	local gui = PlayerGui:FindFirstChild("ZynkMenuGUI")
	if gui then gui:Destroy() end
	_G.ZynkCleanup = nil
end

_G.ZynkCleanup = unloadScript

---------------------------------------------------------
-- INTERFACE GRÁFICA & PALETA NEUTRA
---------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ZynkMenuGUI"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999999999
screenGui.IgnoreGuiInset = true
screenGui.Parent = PlayerGui

local BG_COLOR = Color3.fromRGB(242, 243, 246)
local CARD_COLOR = Color3.fromRGB(255, 255, 255)
local STROKE_COLOR = Color3.fromRGB(220, 223, 230)
local TEXT_MAIN = Color3.fromRGB(30, 32, 38)
local PRIMARY_PILL = Color3.fromRGB(25, 25, 30)
local PRIMARY_TEXT = Color3.fromRGB(255, 255, 255)
local SECONDARY_PILL = Color3.fromRGB(232, 235, 242)
local SECONDARY_TEXT = Color3.fromRGB(60, 64, 75)
local GREEN_ACCENT = Color3.fromRGB(46, 204, 113)
local RED_ACCENT = Color3.fromRGB(235, 70, 70)

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

---------------------------------------------------------
-- NOTIFICAÇÕES (TOASTS)
---------------------------------------------------------
local toast = Instance.new("Frame")
toast.Name = "ToastNotification"
toast.Size = UDim2.new(0, 270, 0, 44)
toast.Position = UDim2.new(0, -300, 1, -64) 
toast.BackgroundColor3 = CARD_COLOR
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
statusDot.Position = UDim2.new(0, 14, 0.5, -4)
statusDot.BackgroundColor3 = GREEN_ACCENT
statusDot.BorderSizePixel = 0
statusDot.Parent = toast

local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = statusDot

local toastLabel = Instance.new("TextLabel")
toastLabel.Size = UDim2.new(1, -36, 1, 0)
toastLabel.Position = UDim2.new(0, 28, 0, 0)
toastLabel.BackgroundTransparency = 1
toastLabel.TextColor3 = getReadableTextColor(CARD_COLOR, TEXT_MAIN)
toastLabel.Font = Enum.Font.SourceSansBold
toastLabel.TextSize = 13
toastLabel.TextXAlignment = Enum.TextXAlignment.Left
toastLabel.Text = "Zynk Menu Carregado"
toastLabel.Parent = toast

local function showToast(text, color, keepVisible)
	if hideToastTask then task.cancel(hideToastTask) hideToastTask = nil end
	toastLabel.Text = text
	statusDot.BackgroundColor3 = color
	
	tween(toast, 0.45, {Position = UDim2.new(0, 20, 1, -64)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	if not keepVisible then
		hideToastTask = task.delay(3.5, function()
			tween(toast, 0.35, {Position = UDim2.new(0, -300, 1, -64)}, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
			hideToastTask = nil
		end)
	end
end

---------------------------------------------------------
-- TELA DE KEY (COM POP-IN ANIMAÇÃO)
---------------------------------------------------------
local keyFrame = Instance.new("Frame")
keyFrame.Name = "KeyFrame"
keyFrame.Size = UDim2.new(0, 320, 0, 250)
keyFrame.Position = UDim2.new(0.5, -160, 0.35, -125)
keyFrame.BackgroundColor3 = BG_COLOR
keyFrame.BorderSizePixel = 0
keyFrame.Parent = screenGui

local keyCorner = Instance.new("UICorner")
keyCorner.CornerRadius = UDim.new(0, 18)
keyCorner.Parent = keyFrame

local keyStroke = Instance.new("UIStroke")
keyStroke.Color = STROKE_COLOR
keyStroke.Thickness = 1.2
keyStroke.Parent = keyFrame

local keyScale = Instance.new("UIScale")
keyScale.Scale = 0
keyScale.Parent = keyFrame

makeDraggable(keyFrame)

local keyTitle = Instance.new("TextLabel")
keyTitle.Size = UDim2.new(1, -30, 0, 35)
keyTitle.Position = UDim2.new(0, 15, 0, 10)
keyTitle.BackgroundTransparency = 1
keyTitle.TextColor3 = getReadableTextColor(BG_COLOR, TEXT_MAIN)
keyTitle.Font = Enum.Font.SourceSansBold
keyTitle.TextSize = 16
keyTitle.Text = "ZYNK MENU - AUTENTICAÇÃO"
keyTitle.Parent = keyFrame

local discordPromptCard = Instance.new("Frame")
discordPromptCard.Size = UDim2.new(1, -30, 0, 70)
discordPromptCard.Position = UDim2.new(0, 15, 0, 48)
discordPromptCard.BackgroundColor3 = CARD_COLOR
discordPromptCard.BorderSizePixel = 0
discordPromptCard.Parent = keyFrame

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 12)
cardCorner.Parent = discordPromptCard

local promptText = Instance.new("TextLabel")
promptText.Size = UDim2.new(1, -20, 0, 32)
promptText.Position = UDim2.new(0, 10, 0, 4)
promptText.BackgroundTransparency = 1
promptText.TextColor3 = Color3.fromRGB(110, 115, 130)
promptText.Font = Enum.Font.SourceSans
promptText.TextSize = 12
promptText.TextWrapped = true
promptText.Text = "Sua Key é válida por 12 HORAS! Copie o link abaixo para pegar o código no Discord."
promptText.Parent = discordPromptCard

local copyDiscordBtn = Instance.new("TextButton")
copyDiscordBtn.Size = UDim2.new(1, -20, 0, 24)
copyDiscordBtn.Position = UDim2.new(0, 10, 0, 38)
copyDiscordBtn.BackgroundColor3 = SECONDARY_PILL
copyDiscordBtn.TextColor3 = getReadableTextColor(SECONDARY_PILL, TEXT_MAIN)
copyDiscordBtn.Font = Enum.Font.SourceSansBold
copyDiscordBtn.TextSize = 12
copyDiscordBtn.Text = "📋 Copiar Link do Discord"
copyDiscordBtn.AutoButtonColor = false
copyDiscordBtn.Parent = discordPromptCard

addInteractiveAnimations(copyDiscordBtn, SECONDARY_PILL, Color3.fromRGB(220, 225, 235))

local copyCorner = Instance.new("UICorner")
copyCorner.CornerRadius = UDim.new(0, 8)
copyCorner.Parent = copyDiscordBtn

copyDiscordBtn.MouseButton1Click:Connect(function()
	if copyToClipboard(DISCORD_LINK) then
		showToast("Link copiado para a área de transferência!", GREEN_ACCENT, false)
	end
end)

local keyInput = Instance.new("TextBox")
keyInput.Name = "KeyInput"
keyInput.Size = UDim2.new(1, -30, 0, 38)
keyInput.Position = UDim2.new(0, 15, 0, 130)
keyInput.BackgroundColor3 = CARD_COLOR
keyInput.TextColor3 = getReadableTextColor(CARD_COLOR, TEXT_MAIN)
keyInput.PlaceholderText = "Cole sua Key aqui (ou pressione [K])..."
keyInput.PlaceholderColor3 = Color3.fromRGB(150, 155, 170)
keyInput.Font = Enum.Font.SourceSans
keyInput.TextSize = 13
keyInput.Text = ""
keyInput.Parent = keyFrame

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 10)
inputCorner.Parent = keyInput

local inputStroke = Instance.new("UIStroke")
inputStroke.Color = STROKE_COLOR
inputStroke.Thickness = 1
inputStroke.Parent = keyInput

local verifyBtn = Instance.new("TextButton")
verifyBtn.Size = UDim2.new(1, -30, 0, 38)
verifyBtn.Position = UDim2.new(0, 15, 0, 180)
verifyBtn.BackgroundColor3 = PRIMARY_PILL
verifyBtn.TextColor3 = getReadableTextColor(PRIMARY_PILL, PRIMARY_TEXT)
verifyBtn.Font = Enum.Font.SourceSansBold
verifyBtn.TextSize = 14
verifyBtn.Text = "Verificar e Salvar por 12h"
verifyBtn.AutoButtonColor = false
verifyBtn.Parent = keyFrame

addInteractiveAnimations(verifyBtn, PRIMARY_PILL, Color3.fromRGB(45, 45, 55))

local verifyCorner = Instance.new("UICorner")
verifyCorner.CornerRadius = UDim.new(0, 10)
verifyCorner.Parent = verifyBtn

---------------------------------------------------------
-- MENU PRINCIPAL E HOTBAR FLUTUANTE
---------------------------------------------------------
local menu = Instance.new("Frame")
menu.Name = "MainMenu"
menu.Size = UDim2.new(0, 330, 0, 250)
menu.Position = UDim2.new(0, 20, 0.2, 0)
menu.BackgroundColor3 = BG_COLOR
menu.BorderSizePixel = 0
menu.Visible = false
menu.Parent = screenGui

local menuCorner = Instance.new("UICorner")
menuCorner.CornerRadius = UDim.new(0, 18)
menuCorner.Parent = menu

local menuStroke = Instance.new("UIStroke")
menuStroke.Color = STROKE_COLOR
menuStroke.Thickness = 1.2
menuStroke.Parent = menu

local menuScale = Instance.new("UIScale")
menuScale.Scale = 1
menuScale.Parent = menu

makeDraggable(menu)

-- Header
local menuTitle = Instance.new("TextLabel")
menuTitle.Size = UDim2.new(0, 150, 0, 36)
menuTitle.Position = UDim2.new(0, 16, 0, 4)
menuTitle.BackgroundTransparency = 1
menuTitle.TextColor3 = getReadableTextColor(BG_COLOR, TEXT_MAIN)
menuTitle.Font = Enum.Font.SourceSansBold
menuTitle.TextSize = 18
menuTitle.TextXAlignment = Enum.TextXAlignment.Left
menuTitle.Text = "ZYNK MENU"
menuTitle.Parent = menu

local actionPod = Instance.new("Frame")
actionPod.Size = UDim2.new(0, 68, 0, 26)
actionPod.Position = UDim2.new(1, -80, 0, 8)
actionPod.BackgroundColor3 = CARD_COLOR
actionPod.BorderSizePixel = 0
actionPod.Parent = menu

local podCorner = Instance.new("UICorner")
podCorner.CornerRadius = UDim.new(0, 8)
podCorner.Parent = actionPod

local podStroke = Instance.new("UIStroke")
podStroke.Color = STROKE_COLOR
podStroke.Thickness = 1
podStroke.Parent = actionPod

local deleteBtn = Instance.new("TextButton")
deleteBtn.Size = UDim2.new(0, 24, 0, 20)
deleteBtn.Position = UDim2.new(0, 3, 0.5, -10)
deleteBtn.BackgroundColor3 = SECONDARY_PILL
deleteBtn.TextColor3 = RED_ACCENT
deleteBtn.Font = Enum.Font.SourceSansBold
deleteBtn.TextSize = 12
deleteBtn.Text = "X"
deleteBtn.AutoButtonColor = false
deleteBtn.Parent = actionPod

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 24, 0, 20)
minimizeBtn.Position = UDim2.new(1, -27, 0.5, -10)
minimizeBtn.BackgroundColor3 = SECONDARY_PILL
minimizeBtn.TextColor3 = getReadableTextColor(SECONDARY_PILL, TEXT_MAIN)
minimizeBtn.Font = Enum.Font.SourceSansBold
minimizeBtn.TextSize = 14
minimizeBtn.Text = "—"
minimizeBtn.AutoButtonColor = false
minimizeBtn.Parent = actionPod

addInteractiveAnimations(deleteBtn, SECONDARY_PILL, Color3.fromRGB(255, 220, 220))
addInteractiveAnimations(minimizeBtn, SECONDARY_PILL, Color3.fromRGB(220, 225, 235))

---------------------------------------------------------
-- CONTAINER DE PÁGINAS COM CANVASGROUP (FADE & SLIDE)
---------------------------------------------------------
local pagesContainer = Instance.new("Frame")
pagesContainer.Size = UDim2.new(1, -20, 0, 190)
pagesContainer.Position = UDim2.new(0, 10, 0, 42)
pagesContainer.BackgroundTransparency = 1
pagesContainer.Parent = menu

local pagePrincipal = Instance.new("CanvasGroup")
pagePrincipal.Name = "PagePrincipal"
pagePrincipal.Size = UDim2.new(1, 0, 1, 0)
pagePrincipal.BackgroundTransparency = 1
pagePrincipal.GroupTransparency = 0
pagePrincipal.Visible = true
pagePrincipal.Parent = pagesContainer

local pageServer = Instance.new("CanvasGroup")
pageServer.Name = "PageServer"
pageServer.Size = UDim2.new(1, 0, 1, 0)
pageServer.BackgroundTransparency = 1
pageServer.GroupTransparency = 1
pageServer.Visible = false
pageServer.Parent = pagesContainer

local pageStatus = Instance.new("CanvasGroup")
pageStatus.Name = "PageStatus"
pageStatus.Size = UDim2.new(1, 0, 1, 0)
pageStatus.BackgroundTransparency = 1
pageStatus.GroupTransparency = 1
pageStatus.Visible = false
pageStatus.Parent = pagesContainer

---------------------------------------------------------
-- CONTEÚDO: PÁGINA PRINCIPAL
---------------------------------------------------------
local function createToggleRow(posY, defaultText, keyText, callback, keyCallback)
	local card = Instance.new("TextButton")
	card.Size = UDim2.new(0, 210, 0, 38)
	card.Position = UDim2.new(0, 0, 0, posY)
	card.BackgroundColor3 = CARD_COLOR
	card.TextColor3 = getReadableTextColor(CARD_COLOR, SECONDARY_TEXT)
	card.Font = Enum.Font.SourceSansBold
	card.TextSize = 13
	card.Text = defaultText
	card.AutoButtonColor = false
	card.Parent = pagePrincipal

	local ncCorner = Instance.new("UICorner")
	ncCorner.CornerRadius = UDim.new(0, 10)
	ncCorner.Parent = card

	local ncStroke = Instance.new("UIStroke")
	ncStroke.Color = STROKE_COLOR
	ncStroke.Thickness = 1
	ncStroke.Parent = card

	addInteractiveAnimations(card, CARD_COLOR, SECONDARY_PILL)

	local keyBtn = Instance.new("TextButton")
	keyBtn.Size = UDim2.new(0, 80, 0, 38)
	keyBtn.Position = UDim2.new(0, 220, 0, posY)
	keyBtn.BackgroundColor3 = SECONDARY_PILL
	keyBtn.TextColor3 = getReadableTextColor(SECONDARY_PILL, TEXT_MAIN)
	keyBtn.Font = Enum.Font.SourceSansBold
	keyBtn.TextSize = 12
	keyBtn.Text = keyText
	keyBtn.AutoButtonColor = false
	keyBtn.Parent = pagePrincipal

	local nckCorner = Instance.new("UICorner")
	nckCorner.CornerRadius = UDim.new(0, 10)
	nckCorner.Parent = keyBtn

	addInteractiveAnimations(keyBtn, SECONDARY_PILL, Color3.fromRGB(220, 225, 235))

	card.MouseButton1Click:Connect(callback)
	keyBtn.MouseButton1Click:Connect(keyCallback)

	return card, keyBtn
end

local noclipCard, noclipKeyBtn
local regenCard, regenKeyBtn
local espCard, espKeyBtn

noclipCard, noclipKeyBtn = createToggleRow(5, "Noclip: DESATIVADO", "[ N ]", function() toggleNoclip() end, function() startListening("Noclip", noclipKeyBtn) end)
regenCard, regenKeyBtn = createToggleRow(50, "Regen Vida: DESATIVADO", "[ R ]", function() toggleRegen() end, function() startListening("Regen", regenKeyBtn) end)
espCard, espKeyBtn = createToggleRow(95, "ESP: DESATIVADO", "[ E ]", function() toggleESP() end, function() startListening("ESP", espKeyBtn) end)

local discordCard = Instance.new("TextButton")
discordCard.Size = UDim2.new(0, 210, 0, 38)
discordCard.Position = UDim2.new(0, 0, 0, 140)
discordCard.BackgroundColor3 = CARD_COLOR
discordCard.TextColor3 = getReadableTextColor(CARD_COLOR, SECONDARY_TEXT)
discordCard.Font = Enum.Font.SourceSansBold
discordCard.TextSize = 12
discordCard.Text = "📋 Copiar Discord"
discordCard.AutoButtonColor = false
discordCard.Parent = pagePrincipal

local dcCorner = Instance.new("UICorner")
dcCorner.CornerRadius = UDim.new(0, 10)
dcCorner.Parent = discordCard

local dcStroke = Instance.new("UIStroke")
dcStroke.Color = STROKE_COLOR
dcStroke.Thickness = 1
dcStroke.Parent = discordCard

addInteractiveAnimations(discordCard, CARD_COLOR, SECONDARY_PILL)

local menuKeyBtn = Instance.new("TextButton")
menuKeyBtn.Size = UDim2.new(0, 80, 0, 38)
menuKeyBtn.Position = UDim2.new(0, 220, 0, 140)
menuKeyBtn.BackgroundColor3 = SECONDARY_PILL
menuKeyBtn.TextColor3 = getReadableTextColor(SECONDARY_PILL, TEXT_MAIN)
menuKeyBtn.Font = Enum.Font.SourceSansBold
menuKeyBtn.TextSize = 12
menuKeyBtn.Text = "[ M ]"
menuKeyBtn.AutoButtonColor = false
menuKeyBtn.Parent = pagePrincipal

local mkCorner = Instance.new("UICorner")
mkCorner.CornerRadius = UDim.new(0, 10)
mkCorner.Parent = menuKeyBtn

addInteractiveAnimations(menuKeyBtn, SECONDARY_PILL, Color3.fromRGB(220, 225, 235))
menuKeyBtn.MouseButton1Click:Connect(function() startListening("Menu", menuKeyBtn) end)

---------------------------------------------------------
-- CONTEÚDO: PÁGINA SERVER
---------------------------------------------------------
local function createServerBtn(posY, text, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 42)
	btn.Position = UDim2.new(0, 0, 0, posY)
	btn.BackgroundColor3 = CARD_COLOR
	btn.TextColor3 = getReadableTextColor(CARD_COLOR, TEXT_MAIN)
	btn.Font = Enum.Font.SourceSansBold
	btn.TextSize = 13
	btn.Text = text
	btn.AutoButtonColor = false
	btn.Parent = pageServer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = STROKE_COLOR
	stroke.Thickness = 1
	stroke.Parent = btn

	addInteractiveAnimations(btn, CARD_COLOR, SECONDARY_PILL)
	btn.MouseButton1Click:Connect(callback)
	return btn
end

createServerBtn(10, "🔄 Reentrar no Servidor (Rejoin)", function()
	showToast("Reconectando...", GREEN_ACCENT, true)
	TeleportService:Teleport(game.PlaceId, LocalPlayer)
end)

createServerBtn(60, "🔀 Trocar de Servidor (Server Hop)", function()
	showToast("Buscando novo servidor...", GREEN_ACCENT, true)
	pcall(function()
		local sfUrl = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
		local req = HttpService:JSONDecode(game:HttpGet(sfUrl))
		for _, v in ipairs(req.data) do
			if v.playing < v.maxPlayers and v.id ~= game.JobId then
				TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id, LocalPlayer)
				break
			end
		end
	end)
end)

createServerBtn(110, "📋 Copiar Job ID do Servidor", function()
	if copyToClipboard(game.JobId) then
		showToast("Job ID copiado!", GREEN_ACCENT, false)
	end
end)

---------------------------------------------------------
-- CONTEÚDO: PÁGINA STATUS
---------------------------------------------------------
local statusGrid = Instance.new("Frame")
statusGrid.Size = UDim2.new(1, 0, 1, -10)
statusGrid.Position = UDim2.new(0, 0, 0, 5)
statusGrid.BackgroundTransparency = 1
statusGrid.Parent = pageStatus

local function createStatusCard(posX, posY, width, height, titleText, valueDefault)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(width, 0, height, 0)
	card.Position = UDim2.new(posX, 0, posY, 0)
	card.BackgroundColor3 = CARD_COLOR
	card.BorderSizePixel = 0
	card.Parent = statusGrid

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = STROKE_COLOR
	stroke.Thickness = 1
	stroke.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 18)
	title.Position = UDim2.new(0, 0, 0, 8)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(130, 135, 150)
	title.Font = Enum.Font.SourceSansBold
	title.TextSize = 11
	title.Text = titleText
	title.Parent = card

	local val = Instance.new("TextLabel")
	val.Size = UDim2.new(1, 0, 0, 26)
	val.Position = UDim2.new(0, 0, 0, 26)
	val.BackgroundTransparency = 1
	val.TextColor3 = getReadableTextColor(CARD_COLOR, TEXT_MAIN)
	val.Font = Enum.Font.SourceSansBold
	val.TextSize = 16
	val.Text = valueDefault
	val.Parent = card

	return val
end

local fpsValueLabel = createStatusCard(0, 5, 0.48, 0.42, "TAXA DE QUADROS", "60 FPS")
local pingValueLabel = createStatusCard(0.52, 5, 0.48, 0.42, "LATÊNCIA (PING)", "0 ms")
local memoryValueLabel = createStatusCard(0, 95, 0.48, 0.42, "USO DE MEMÓRIA", "0 MB")
local uptimeValueLabel = createStatusCard(0.52, 95, 0.48, 0.42, "TEMPO SERVIDOR", "0m")

-- Loop de Status
local frameCount = 0
local lastCheck = tick()

RunService.RenderStepped:Connect(function()
	frameCount = frameCount + 1
	local now = tick()
	if now - lastCheck >= 1 then
		local fps = math.floor(frameCount / (now - lastCheck))
		fpsValueLabel.Text = tostring(fps) .. " FPS"
		frameCount = 0
		lastCheck = now

		local ping = 0
		pcall(function()
			ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
		end)
		pingValueLabel.Text = tostring(ping) .. " ms"

		local mem = math.floor(Stats:GetTotalMemoryUsageMb())
		memoryValueLabel.Text = tostring(mem) .. " MB"

		local uptimeSec = math.floor(workspace.DistributedGameTime)
		local mins = math.floor(uptimeSec / 60)
		uptimeValueLabel.Text = tostring(mins) .. " min"
	end
end)

---------------------------------------------------------
-- DESIGN DA HOTBAR FLUTUANTE (COM ÍCONES PERSONALIZADOS)
---------------------------------------------------------
local hotbar = Instance.new("Frame")
hotbar.Name = "HotbarNav"
hotbar.Size = UDim2.new(0, 330, 0, 52)
hotbar.Position = UDim2.new(0, 20, 0.2, 260) -- Flutuando logo abaixo do menu
hotbar.BackgroundColor3 = CARD_COLOR
hotbar.BorderSizePixel = 0
hotbar.Visible = false
hotbar.Parent = screenGui

local hbCorner = Instance.new("UICorner")
hbCorner.CornerRadius = UDim.new(0, 18)
hbCorner.Parent = hotbar

local hbStroke = Instance.new("UIStroke")
hbStroke.Color = STROKE_COLOR
hbStroke.Thickness = 1.2
hbStroke.Parent = hotbar

local hotbarScale = Instance.new("UIScale")
hotbarScale.Scale = 1
hotbarScale.Parent = hotbar

makeDraggable(hotbar)

local function createTabButton(posX, width, titleText, iconId)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(width, 0, 1, -12)
	btn.Position = UDim2.new(posX, 0, 0.5, -20)
	btn.BackgroundColor3 = SECONDARY_PILL
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Parent = hotbar

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = btn

	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(0, 18, 0, 18)
	icon.Position = UDim2.new(0, 10, 0.5, -9)
	icon.BackgroundTransparency = 1
	icon.Image = iconId
	icon.ImageColor3 = getReadableTextColor(SECONDARY_PILL, SECONDARY_TEXT)
	icon.Parent = btn

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -34, 1, 0)
	lbl.Position = UDim2.new(0, 30, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = getReadableTextColor(SECONDARY_PILL, SECONDARY_TEXT)
	lbl.Font = Enum.Font.SourceSansBold
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = titleText
	lbl.Parent = btn

	addInteractiveAnimations(btn, SECONDARY_PILL, Color3.fromRGB(220, 225, 235))

	return btn, icon, lbl
end

local btnPrincipal, iconPrincipal, lblPrincipal = createTabButton(0.03, 0.3, "Principal", ICONS.Principal)
local btnServer, iconServer, lblServer = createTabButton(0.35, 0.3, "Server", ICONS.Server)
local btnStatus, iconStatus, lblStatus = createTabButton(0.67, 0.3, "Status", ICONS.Status)

local activeTab = "Principal"

local function switchTab(selected)
	if activeTab == selected then return end

	local currentGroup = (activeTab == "Principal" and pagePrincipal) or (activeTab == "Server" and pageServer) or pageStatus
	local nextGroup = (selected == "Principal" and pagePrincipal) or (selected == "Server" and pageServer) or pageStatus

	activeTab = selected

	tween(currentGroup, 0.2, {GroupTransparency = 1}).Completed:Connect(function()
		currentGroup.Visible = false
		nextGroup.Visible = true
		tween(nextGroup, 0.25, {GroupTransparency = 0})
	end)

	local tabs = {
		Principal = {btn = btnPrincipal, icon = iconPrincipal, lbl = lblPrincipal},
		Server = {btn = btnServer, icon = iconServer, lbl = lblServer},
		Status = {btn = btnStatus, icon = iconStatus, lbl = lblStatus}
	}

	for key, data in pairs(tabs) do
		local isActive = (key == selected)
		local targetBg = isActive and PRIMARY_PILL or SECONDARY_PILL
		local targetFg = isActive and getReadableTextColor(PRIMARY_PILL, PRIMARY_TEXT) or getReadableTextColor(SECONDARY_PILL, SECONDARY_TEXT)

		tween(data.btn, 0.2, {BackgroundColor3 = targetBg})
		tween(data.lbl, 0.2, {TextColor3 = targetFg})
		tween(data.icon, 0.2, {ImageColor3 = targetFg})
	end
end

btnPrincipal.MouseButton1Click:Connect(function() switchTab("Principal") end)
btnServer.MouseButton1Click:Connect(function() switchTab("Server") end)
btnStatus.MouseButton1Click:Connect(function() switchTab("Status") end)

switchTab("Principal")

---------------------------------------------------------
-- INICIALIZAÇÃO DE TELA E VALIDAÇÃO DE KEY
---------------------------------------------------------
local function openMainMenu()
	isAuthenticated = true
	menu.Visible = true
	hotbar.Visible = true

	menuScale.Scale = 0
	hotbarScale.Scale = 0

	tween(menuScale, 0.45, {Scale = 1}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	tween(hotbarScale, 0.45, {Scale = 1}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

local function verifyKey(customCode)
	if isAuthenticated then return end

	local rawCode = customCode or keyInput.Text
	local codeEntered = string.match(rawCode, "^%s*(.-)%s*$") or ""

	if codeEntered == GENERATED_KEY then
		saveKeyLocally(codeEntered)
		sendWebhookLog("✅ Acesso Liberado (12h)", 3066993, "O jogador ativou a key com sucesso.")
		showToast("Key Válida por 12 Horas!", GREEN_ACCENT, false)

		tween(keyScale, 0.35, {Scale = 0}, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Connect(function()
			keyFrame.Visible = false
		end)

		task.wait(0.1)
		openMainMenu()
	else
		if not customCode then
			sendWebhookLog("❌ Key Incorreta", 15158332, "Tentativa incorreta: " .. codeEntered)
			showToast("Código Incorreto!", RED_ACCENT, false)
			keyInput.Text = ""
		end
	end
end

verifyBtn.MouseButton1Click:Connect(function() verifyKey() end)
keyInput.FocusLost:Connect(function(enterPressed)
	if enterPressed then verifyKey() end
end)

LocalPlayer.Chatted:Connect(function(msg)
	if not isAuthenticated then
		local cleanMsg = string.match(msg, "^%s*(.-)%s*$") or ""
		if cleanMsg == GENERATED_KEY then verifyKey(cleanMsg) end
	end
end)

-- VERIFICAÇÃO AUTOMÁTICA DA KEY SALVA (12 HORAS)
local savedData = loadKeyLocally()
if savedData then
	local remainingSec = savedData.expiresAt - os.time()
	local remainingHours = math.floor(remainingSec / 3600)
	keyFrame.Visible = false
	openMainMenu()
	showToast("Key Carregada! (" .. tostring(remainingHours) .. "h restantes)", GREEN_ACCENT, false)
else
	keyFrame.Visible = true
	tween(keyScale, 0.4, {Scale = 1}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

---------------------------------------------------------
-- CONTROLES DE VISIBILIDADE / UNLOAD
---------------------------------------------------------
function toggleMenuVisibility()
	if not isAuthenticated then return end

	if menu.Visible then
		tween(menuScale, 0.3, {Scale = 0}, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		tween(hotbarScale, 0.3, {Scale = 0}, Enum.EasingStyle.Quart, Enum.EasingDirection.In).Completed:Connect(function()
			menu.Visible = false
			hotbar.Visible = false
		end)
		showToast("Menu Oculto", Color3.fromRGB(150, 150, 160), false)
	else
		menu.Visible = true
		hotbar.Visible = true
		tween(menuScale, 0.4, {Scale = 1}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		tween(hotbarScale, 0.4, {Scale = 1}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	end
end

minimizeBtn.MouseButton1Click:Connect(toggleMenuVisibility)
deleteBtn.MouseButton1Click:Connect(function()
	showToast("Script Excluído!", RED_ACCENT, false)
	task.wait(0.3)
	unloadScript()
end)

discordCard.MouseButton1Click:Connect(function()
	if copyToClipboard(DISCORD_LINK) then
		showToast("Link do Discord copiado!", GREEN_ACCENT, false)
	end
end)

---------------------------------------------------------
-- ESP LÓGICA
---------------------------------------------------------
local function applyESPToCharacter(player, character)
	if player == LocalPlayer or not character then return end
	removeESPFromPlayer(player)

	local highlight = Instance.new("Highlight")
	highlight.Name = "ZynkESP_HL"
	highlight.Adornee = character
	highlight.FillColor = Color3.fromRGB(100, 130, 255)
	highlight.FillTransparency = 0.5
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineTransparency = 0.1
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character

	local head = character:WaitForChild("Head", 3)
	if head then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "ZynkESP_Tag"
		billboard.Adornee = head
		billboard.Size = UDim2.new(0, 160, 0, 35)
		billboard.StudsOffset = Vector3.new(0, 2.5, 0)
		billboard.AlwaysOnTop = true

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, 0, 0, 18)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextStrokeTransparency = 0.2
		nameLabel.Font = Enum.Font.SourceSansBold
		nameLabel.TextSize = 13
		nameLabel.Text = player.DisplayName .. " (@" .. player.Name .. ")"
		nameLabel.Parent = billboard

		local hum = character:FindFirstChildOfClass("Humanoid")
		if hum then
			local hpLabel = Instance.new("TextLabel")
			hpLabel.Size = UDim2.new(1, 0, 0, 14)
			hpLabel.Position = UDim2.new(0, 0, 0, 18)
			hpLabel.BackgroundTransparency = 1
			hpLabel.TextColor3 = Color3.fromRGB(120, 255, 150)
			hpLabel.TextStrokeTransparency = 0.3
			hpLabel.Font = Enum.Font.SourceSans
			hpLabel.TextSize = 11
			hpLabel.Text = "HP: " .. math.floor(hum.Health) .. " / " .. math.floor(hum.MaxHealth)
			hpLabel.Parent = billboard

			hum.HealthChanged:Connect(function(newHp)
				if hpLabel and hpLabel.Parent then
					hpLabel.Text = "HP: " .. math.floor(newHp) .. " / " .. math.floor(hum.MaxHealth)
				end
			end)
		end
		billboard.Parent = character
	end
	espHighlights[player] = highlight
end

function toggleESP()
	isESPActive = not isESPActive
	if isESPActive then
		tween(espCard, 0.2, {BackgroundColor3 = PRIMARY_PILL, TextColor3 = PRIMARY_TEXT})
		espCard.Text = "ESP: ATIVADO"
		showToast("ESP Ativado", GREEN_ACCENT, false)

		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer then
				if p.Character then applyESPToCharacter(p, p.Character) end
				espCharAddedConns[p] = p.CharacterAdded:Connect(function(char)
					if isESPActive then applyESPToCharacter(p, char) end
				end)
			end
		end

		espPlayerAddedConn = Players.PlayerAdded:Connect(function(p)
			espCharAddedConns[p] = p.CharacterAdded:Connect(function(char)
				if isESPActive then applyESPToCharacter(p, char) end
			end)
		end)

		espPlayerRemovingConn = Players.PlayerRemoving:Connect(function(p)
			removeESPFromPlayer(p)
		end)
	else
		tween(espCard, 0.2, {BackgroundColor3 = CARD_COLOR, TextColor3 = SECONDARY_TEXT})
		espCard.Text = "ESP: DESATIVADO"
		showToast("ESP Desativado", RED_ACCENT, false)
		clearAllESP()
	end
end

---------------------------------------------------------
-- REGEN DE VIDA LÓGICA
---------------------------------------------------------
function toggleRegen()
	isRegenActive = not isRegenActive
	if isRegenActive then
		tween(regenCard, 0.2, {BackgroundColor3 = PRIMARY_PILL, TextColor3 = PRIMARY_TEXT})
		regenCard.Text = "Regen Vida: ATIVADO"
		showToast("Regen Ativado", GREEN_ACCENT, false)

		regenConnection = RunService.Heartbeat:Connect(function(dt)
			local character = LocalPlayer.Character
			if character then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
					humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + (35 * dt))
				end
			end
		end)
	else
		tween(regenCard, 0.2, {BackgroundColor3 = CARD_COLOR, TextColor3 = SECONDARY_TEXT})
		regenCard.Text = "Regen Vida: DESATIVADO"
		showToast("Regen Desativado", RED_ACCENT, false)

		if regenConnection then regenConnection:Disconnect() regenConnection = nil end
	end
end

---------------------------------------------------------
-- NOCLIP LÓGICA
---------------------------------------------------------
local function isGround(part, character, rootPart)
	if not part or not rootPart then return true end
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {character}

	local rayResult = Workspace:Raycast(rootPart.Position, Vector3.new(0, -6, 0), raycastParams)
	if rayResult and rayResult.Instance == part then return true end

	local feetY = rootPart.Position.Y - 2.8
	local partTopY = part.Position.Y + (part.Size.Y / 2)
	if partTopY <= feetY + 0.5 then return true end

	return false
end

function toggleNoclip()
	isNoclipping = not isNoclipping
	if isNoclipping then
		tween(noclipCard, 0.2, {BackgroundColor3 = PRIMARY_PILL, TextColor3 = PRIMARY_TEXT})
		noclipCard.Text = "Noclip: ATIVADO"
		showToast("Noclip Ativado", GREEN_ACCENT, true)

		noclipConnection = RunService.Stepped:Connect(function()
			local character = LocalPlayer.Character
			if not character then return end
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if not rootPart then return end

			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide = false end
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
						if modifiedParts[part] == nil then modifiedParts[part] = part.CanCollide end
						part.CanCollide = false
					end
				end
			end

			for part, originalState in pairs(modifiedParts) do
				if not currentNearby[part] then
					if part and part.Parent then part.CanCollide = originalState end
					modifiedParts[part] = nil
				end
			end
		end)
	else
		tween(noclipCard, 0.2, {BackgroundColor3 = CARD_COLOR, TextColor3 = SECONDARY_TEXT})
		noclipCard.Text = "Noclip: DESATIVADO"
		if noclipConnection then noclipConnection:Disconnect() noclipConnection = nil end
		restoreParts()
		local character = LocalPlayer.Character
		if character then
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide = true end
			end
		end
		showToast("Noclip Desativado", RED_ACCENT, false)
	end
end

---------------------------------------------------------
-- BINDING DE TECLAS
---------------------------------------------------------
function startListening(target, button)
	listeningTarget = target
	button.Text = "[ ... ]"
	tween(button, 0.2, {BackgroundColor3 = PRIMARY_PILL, TextColor3 = PRIMARY_TEXT})
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and not isAuthenticated then
		if input.KeyCode == Enum.KeyCode.K then
			task.defer(function() keyInput:CaptureFocus() end)
			return
		end
	end

	if listeningTarget then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local btn = (listeningTarget == "Noclip" and noclipKeyBtn) 
				or (listeningTarget == "Regen" and regenKeyBtn) 
				or (listeningTarget == "ESP" and espKeyBtn) 
				or menuKeyBtn
			
			if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Escape then
				keybinds[listeningTarget] = nil
				btn.Text = "[ OFF ]"
			else
				keybinds[listeningTarget] = input.KeyCode
				btn.Text = "[ " .. input.KeyCode.Name .. " ]"
			end
			listeningTarget = nil
			tween(btn, 0.2, {BackgroundColor3 = SECONDARY_PILL, TextColor3 = TEXT_MAIN})
		end
		return
	end

	if not gameProcessed and isAuthenticated then
		if keybinds.Noclip and input.KeyCode == keybinds.Noclip then
			toggleNoclip()
		elseif keybinds.Regen and input.KeyCode == keybinds.Regen then
			toggleRegen()
		elseif keybinds.ESP and input.KeyCode == keybinds.ESP then
			toggleESP()
		elseif keybinds.Menu and input.KeyCode == keybinds.Menu then
			toggleMenuVisibility()
		end
	end
end)
