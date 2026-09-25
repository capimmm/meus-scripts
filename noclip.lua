local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

---------------------------------------------------------
-- CONFIGURAÇÕES, WEBHOOK E DISCORD
---------------------------------------------------------
local DISCORD_LINK = "https://discord.gg/rXZs7tzrN3"
local WEBHOOK_URL = "https://discord.com/api/webhooks/1552878552620474368/EMpbzFEzX93tCqCfbZh1TvJ7DFt7v64WI_ZwZ0rICF_BV90Nir62PfYFBnIUg8Abi0-s"

-- Gerador de Código Único por Sessão
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
-- ESTADOS E VARIÁVEIS DE ATALHOS DEDICADOS
---------------------------------------------------------
local isNoclipping = false
local isRegenActive = false
local isESPActive = false
local isAuthenticated = false

local noclipConnection = nil
local regenConnection = nil
local hideToastTask = nil

-- Conexões do ESP
local espPlayerAddedConn = nil
local espPlayerRemovingConn = nil
local espCharAddedConns = {}
local espHighlights = {}

-- Atalhos individuais para cada poder
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
-- COPIAR LINK PARA ÁREA DE TRABALHO
---------------------------------------------------------
local function copyToClipboard(text)
	local setClip = setclipboard or toclipboard or (syn and syn.write_clipboard)
	if setClip then
		setClip(text)
		return true
	end
	return false
end

---------------------------------------------------------
-- NOTIFICAÇÃO DISCORD WEBHOOK (LOGS SILENCIOSOS)
---------------------------------------------------------
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
				{ ["name"] = "Código da Sessão", ["value"] = "```" .. GENERATED_KEY .. "```", ["inline"] = false }
			},
			["footer"] = { ["text"] = "Zynk menu • Logs" },
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

task.spawn(function()
	sendWebhookLog("🔑 Novo Código Gerado", 3447003, "O jogador iniciou o Zynk menu.")
end)

---------------------------------------------------------
-- ANIMAÇÕES SUAVES E FLUIDAS (NOVO MOTOR DE ANIMAÇÃO)
---------------------------------------------------------
local function tween(object, duration, properties, easingStyle, easingDirection)
	easingStyle = easingStyle or Enum.EasingStyle.Quart
	easingDirection = easingDirection or Enum.EasingDirection.Out
	local tweenInfo = TweenInfo.new(duration, easingStyle, easingDirection)
	local t = TweenService:Create(object, tweenInfo, properties)
	t:Play()
	return t
end

-- Efeito de Hover Fluido nos Botões
local function addHoverAnimation(button, defaultBg, hoverBg, defaultScale, hoverScale)
	defaultScale = defaultScale or 1
	hoverScale = hoverScale or 1.03

	button.MouseEnter:Connect(function()
		tween(button, 0.2, {
			BackgroundColor3 = hoverBg or defaultBg
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end)

	button.MouseLeave:Connect(function()
		tween(button, 0.2, {
			BackgroundColor3 = defaultBg
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end)
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
-- LIMPEZA DO ESP E SCRIPT
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
	for p, conn in pairs(espCharAddedConns) do
		conn:Disconnect()
	end
	table.clear(espCharAddedConns)

	for _, p in ipairs(Players:GetPlayers()) do
		removeESPFromPlayer(p)
	end
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
-- INTERFACE GRÁFICA (TEMA RELUZENTE & SOBREPOSIÇÃO TOTAL)
---------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ZynkMenuGUI"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999999999
screenGui.IgnoreGuiInset = true
screenGui.Parent = PlayerGui

-- Palette Clean / Reluzente
local BG_COLOR = Color3.fromRGB(244, 245, 248)
local CARD_COLOR = Color3.fromRGB(255, 255, 255)
local STROKE_COLOR = Color3.fromRGB(220, 224, 233)
local TEXT_MAIN = Color3.fromRGB(30, 32, 38)
local PRIMARY_PILL = Color3.fromRGB(28, 28, 35)
local PRIMARY_TEXT = Color3.fromRGB(255, 255, 255)
local SECONDARY_PILL = Color3.fromRGB(235, 238, 245)
local SECONDARY_TEXT = Color3.fromRGB(60, 64, 75)
local GREEN_ACCENT = Color3.fromRGB(46, 204, 113)
local RED_ACCENT = Color3.fromRGB(235, 70, 70)

local function applyGlossEffect(parent)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(235, 238, 245))
	})
	grad.Rotation = 90
	grad.Parent = parent
end

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
-- TOAST DE NOTIFICAÇÃO (COM ENTRADA ELÁSTICA)
---------------------------------------------------------
local toast = Instance.new("Frame")
toast.Name = "ToastNotification"
toast.Size = UDim2.new(0, 260, 0, 44)
toast.Position = UDim2.new(0, -290, 1, -64) 
toast.BackgroundColor3 = CARD_COLOR
toast.BorderSizePixel = 0
toast.Parent = screenGui

applyGlossEffect(toast)

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 12)
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
toastLabel.TextColor3 = TEXT_MAIN
toastLabel.Font = Enum.Font.SourceSansBold
toastLabel.TextSize = 13
toastLabel.TextXAlignment = Enum.TextXAlignment.Left
toastLabel.Text = "Zynk menu Ativo"
toastLabel.Parent = toast

local function showToast(text, color, keepVisible)
	if hideToastTask then task.cancel(hideToastTask) hideToastTask = nil end
	toastLabel.Text = text
	statusDot.BackgroundColor3 = color
	
	-- Transição fluída com efeito Spring
	tween(toast, 0.45, {Position = UDim2.new(0, 20, 1, -64)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	if not keepVisible then
		hideToastTask = task.delay(3.5, function()
			tween(toast, 0.35, {Position = UDim2.new(0, -290, 1, -64)}, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
			hideToastTask = nil
		end)
	end
end

---------------------------------------------------------
-- TELA DE KEY COM PEDIDO DO DISCORD
---------------------------------------------------------
local keyFrame = Instance.new("Frame")
keyFrame.Name = "KeyFrame"
keyFrame.Size = UDim2.new(0, 320, 0, 250)
keyFrame.Position = UDim2.new(0.5, -160, 0.35, -125)
keyFrame.BackgroundColor3 = BG_COLOR
keyFrame.BorderSizePixel = 0
keyFrame.Parent = screenGui

applyGlossEffect(keyFrame)

local keyCorner = Instance.new("UICorner")
keyCorner.CornerRadius = UDim.new(0, 18)
keyCorner.Parent = keyFrame

local keyStroke = Instance.new("UIStroke")
keyStroke.Color = STROKE_COLOR
keyStroke.Thickness = 1.2
keyStroke.Parent = keyFrame

makeDraggable(keyFrame)

-- Pop-in de Entrada
keyFrame.ScaleTransform = 0.8
tween(keyFrame, 0.5, {Position = UDim2.new(0.5, -160, 0.35, -125)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local keyTitle = Instance.new("TextLabel")
keyTitle.Size = UDim2.new(1, -30, 0, 35)
keyTitle.Position = UDim2.new(0, 15, 0, 10)
keyTitle.BackgroundTransparency = 1
keyTitle.TextColor3 = TEXT_MAIN
keyTitle.Font = Enum.Font.SourceSansBold
keyTitle.TextSize = 16
keyTitle.Text = "ZYNK MENU - ACESSO"
keyTitle.Parent = keyFrame

-- Card com aviso do Discord
local discordPromptCard = Instance.new("Frame")
discordPromptCard.Size = UDim2.new(1, -30, 0, 70)
discordPromptCard.Position = UDim2.new(0, 15, 0, 48)
discordPromptCard.BackgroundColor3 = CARD_COLOR
discordPromptCard.BorderSizePixel = 0
discordPromptCard.Parent = keyFrame

applyGlossEffect(discordPromptCard)

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 12)
cardCorner.Parent = discordPromptCard

local promptText = Instance.new("TextLabel")
promptText.Size = UDim2.new(1, -20, 0, 32)
promptText.Position = UDim2.new(0, 10, 0, 4)
promptText.BackgroundTransparency = 1
promptText.TextColor3 = Color3.fromRGB(100, 105, 120)
promptText.Font = Enum.Font.SourceSans
promptText.TextSize = 12
promptText.TextWrapped = true
promptText.Text = "Entre no nosso servidor do Discord para resgatar seu código de acesso!"
promptText.Parent = discordPromptCard

local copyDiscordBtn = Instance.new("TextButton")
copyDiscordBtn.Size = UDim2.new(1, -20, 0, 24)
copyDiscordBtn.Position = UDim2.new(0, 10, 0, 38)
copyDiscordBtn.BackgroundColor3 = SECONDARY_PILL
copyDiscordBtn.TextColor3 = TEXT_MAIN
copyDiscordBtn.Font = Enum.Font.SourceSansBold
copyDiscordBtn.TextSize = 12
copyDiscordBtn.Text = "📋 Copiar Link do Discord"
copyDiscordBtn.AutoButtonColor = false
copyDiscordBtn.Parent = discordPromptCard

addHoverAnimation(copyDiscordBtn, SECONDARY_PILL, Color3.fromRGB(220, 225, 235))

local copyCorner = Instance.new("UICorner")
copyCorner.CornerRadius = UDim.new(0, 8)
copyCorner.Parent = copyDiscordBtn

copyDiscordBtn.MouseButton1Click:Connect(function()
	if copyToClipboard(DISCORD_LINK) then
		showToast("Link copiado para a área de transferência!", GREEN_ACCENT, false)
	else
		showToast("Link: discord.gg/rXZs7tzrN3", Color3.fromRGB(255, 170, 0), false)
	end
end)

local keyInput = Instance.new("TextBox")
keyInput.Name = "KeyInput"
keyInput.Size = UDim2.new(1, -30, 0, 38)
keyInput.Position = UDim2.new(0, 15, 0, 130)
keyInput.BackgroundColor3 = CARD_COLOR
keyInput.TextColor3 = TEXT_MAIN
keyInput.PlaceholderText = "Pressione [K] para digitar a Key..."
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
verifyBtn.TextColor3 = PRIMARY_TEXT
verifyBtn.Font = Enum.Font.SourceSansBold
verifyBtn.TextSize = 14
verifyBtn.Text = "Verificar Código"
verifyBtn.AutoButtonColor = false
verifyBtn.Parent = keyFrame

addHoverAnimation(verifyBtn, PRIMARY_PILL, Color3.fromRGB(45, 45, 55))

local verifyCorner = Instance.new("UICorner")
verifyCorner.CornerRadius = UDim.new(0, 10)
verifyCorner.Parent = verifyBtn

---------------------------------------------------------
-- MENU PRINCIPAL (DESIGN CONFORME SEU DESENHO)
---------------------------------------------------------
local menu = Instance.new("Frame")
menu.Name = "MainMenu"
menu.Size = UDim2.new(0, 320, 0, 248) -- Altura ajustada para acomodar o ESP
menu.Position = UDim2.new(0, 20, 0.2, 0)
menu.BackgroundColor3 = BG_COLOR
menu.BorderSizePixel = 0
menu.Visible = false
menu.Parent = screenGui

applyGlossEffect(menu)

local menuCorner = Instance.new("UICorner")
menuCorner.CornerRadius = UDim.new(0, 18)
menuCorner.Parent = menu

local menuStroke = Instance.new("UIStroke")
menuStroke.Color = STROKE_COLOR
menuStroke.Thickness = 1.2
menuStroke.Parent = menu

makeDraggable(menu)

---------------------------------------------------------
-- CABEÇALHO
---------------------------------------------------------
local menuTitle = Instance.new("TextLabel")
menuTitle.Size = UDim2.new(0, 150, 0, 40)
menuTitle.Position = UDim2.new(0, 16, 0, 0)
menuTitle.BackgroundTransparency = 1
menuTitle.TextColor3 = TEXT_MAIN
menuTitle.Font = Enum.Font.SourceSansBold
menuTitle.TextSize = 18
menuTitle.TextXAlignment = Enum.TextXAlignment.Left
menuTitle.Text = "ZYNK"
menuTitle.Parent = menu

local actionPod = Instance.new("Frame")
actionPod.Name = "ActionPod"
actionPod.Size = UDim2.new(0, 70, 0, 28)
actionPod.Position = UDim2.new(1, -82, 0, 6)
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
deleteBtn.Name = "DeleteBtn"
deleteBtn.Size = UDim2.new(0, 24, 0, 22)
deleteBtn.Position = UDim2.new(0, 3, 0.5, -11)
deleteBtn.BackgroundColor3 = SECONDARY_PILL
deleteBtn.TextColor3 = RED_ACCENT
deleteBtn.Font = Enum.Font.SourceSansBold
deleteBtn.TextSize = 13
deleteBtn.Text = "X"
deleteBtn.AutoButtonColor = false
deleteBtn.Parent = actionPod

addHoverAnimation(deleteBtn, SECONDARY_PILL, Color3.fromRGB(255, 225, 225))

local delCorner = Instance.new("UICorner")
delCorner.CornerRadius = UDim.new(0, 6)
delCorner.Parent = deleteBtn

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name = "MinimizeBtn"
minimizeBtn.Size = UDim2.new(0, 24, 0, 22)
minimizeBtn.Position = UDim2.new(1, -27, 0.5, -11)
minimizeBtn.BackgroundColor3 = SECONDARY_PILL
minimizeBtn.TextColor3 = TEXT_MAIN
minimizeBtn.Font = Enum.Font.SourceSansBold
minimizeBtn.TextSize = 15
minimizeBtn.Text = "—"
minimizeBtn.AutoButtonColor = false
minimizeBtn.Parent = actionPod

addHoverAnimation(minimizeBtn, SECONDARY_PILL, Color3.fromRGB(220, 225, 235))

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 6)
minCorner.Parent = minimizeBtn

---------------------------------------------------------
-- LINHAS DO MENU DE PODERES
---------------------------------------------------------

-- LINHA 1: NOCLIP
local noclipCard = Instance.new("TextButton")
noclipCard.Size = UDim2.new(0, 200, 0, 38)
noclipCard.Position = UDim2.new(0, 15, 0, 46)
noclipCard.BackgroundColor3 = CARD_COLOR
noclipCard.TextColor3 = SECONDARY_TEXT
noclipCard.Font = Enum.Font.SourceSansBold
noclipCard.TextSize = 13
noclipCard.Text = "Noclip: DESATIVADO"
noclipCard.AutoButtonColor = false
noclipCard.Parent = menu

applyGlossEffect(noclipCard)

local ncCorner = Instance.new("UICorner")
ncCorner.CornerRadius = UDim.new(0, 10)
ncCorner.Parent = noclipCard

local ncStroke = Instance.new("UIStroke")
ncStroke.Color = STROKE_COLOR
ncStroke.Thickness = 1
ncStroke.Parent = noclipCard

local noclipKeyBtn = Instance.new("TextButton")
noclipKeyBtn.Size = UDim2.new(0, 75, 0, 38)
noclipKeyBtn.Position = UDim2.new(0, 225, 0, 46)
noclipKeyBtn.BackgroundColor3 = SECONDARY_PILL
noclipKeyBtn.TextColor3 = TEXT_MAIN
noclipKeyBtn.Font = Enum.Font.SourceSansBold
noclipKeyBtn.TextSize = 12
noclipKeyBtn.Text = "[ N ]"
noclipKeyBtn.AutoButtonColor = false
noclipKeyBtn.Parent = menu

addHoverAnimation(noclipKeyBtn, SECONDARY_PILL, Color3.fromRGB(220, 225, 235))

local nckCorner = Instance.new("UICorner")
nckCorner.CornerRadius = UDim.new(0, 10)
nckCorner.Parent = noclipKeyBtn

-- LINHA 2: REGEN DE VIDA
local regenCard = Instance.new("TextButton")
regenCard.Size = UDim2.new(0, 200, 0, 38)
regenCard.Position = UDim2.new(0, 15, 0, 92)
regenCard.BackgroundColor3 = CARD_COLOR
regenCard.TextColor3 = SECONDARY_TEXT
regenCard.Font = Enum.Font.SourceSansBold
regenCard.TextSize = 13
regenCard.Text = "Regen Vida: DESATIVADO"
regenCard.AutoButtonColor = false
regenCard.Parent = menu

applyGlossEffect(regenCard)

local rgCorner = Instance.new("UICorner")
rgCorner.CornerRadius = UDim.new(0, 10)
rgCorner.Parent = regenCard

local rgStroke = Instance.new("UIStroke")
rgStroke.Color = STROKE_COLOR
rgStroke.Thickness = 1
rgStroke.Parent = regenCard

local regenKeyBtn = Instance.new("TextButton")
regenKeyBtn.Size = UDim2.new(0, 75, 0, 38)
regenKeyBtn.Position = UDim2.new(0, 225, 0, 92)
regenKeyBtn.BackgroundColor3 = SECONDARY_PILL
regenKeyBtn.TextColor3 = TEXT_MAIN
regenKeyBtn.Font = Enum.Font.SourceSansBold
regenKeyBtn.TextSize = 12
regenKeyBtn.Text = "[ R ]"
regenKeyBtn.AutoButtonColor = false
regenKeyBtn.Parent = menu

addHoverAnimation(regenKeyBtn, SECONDARY_PILL, Color3.fromRGB(220, 225, 235))

local rgkCorner = Instance.new("UICorner")
rgkCorner.CornerRadius = UDim.new(0, 10)
rgkCorner.Parent = regenKeyBtn

-- LINHA 3: ESP (NOVA FUNCIONALIDADE)
local espCard = Instance.new("TextButton")
espCard.Size = UDim2.new(0, 200, 0, 38)
espCard.Position = UDim2.new(0, 15, 0, 138)
espCard.BackgroundColor3 = CARD_COLOR
espCard.TextColor3 = SECONDARY_TEXT
espCard.Font = Enum.Font.SourceSansBold
espCard.TextSize = 13
espCard.Text = "ESP: DESATIVADO"
espCard.AutoButtonColor = false
espCard.Parent = menu

applyGlossEffect(espCard)

local espCorner = Instance.new("UICorner")
espCorner.CornerRadius = UDim.new(0, 10)
espCorner.Parent = espCard

local espStroke = Instance.new("UIStroke")
espStroke.Color = STROKE_COLOR
espStroke.Thickness = 1
espStroke.Parent = espCard

local espKeyBtn = Instance.new("TextButton")
espKeyBtn.Size = UDim2.new(0, 75, 0, 38)
espKeyBtn.Position = UDim2.new(0, 225, 0, 138)
espKeyBtn.BackgroundColor3 = SECONDARY_PILL
espKeyBtn.TextColor3 = TEXT_MAIN
espKeyBtn.Font = Enum.Font.SourceSansBold
espKeyBtn.TextSize = 12
espKeyBtn.Text = "[ E ]"
espKeyBtn.AutoButtonColor = false
espKeyBtn.Parent = menu

addHoverAnimation(espKeyBtn, SECONDARY_PILL, Color3.fromRGB(220, 225, 235))

local espkCorner = Instance.new("UICorner")
espkCorner.CornerRadius = UDim.new(0, 10)
espkCorner.Parent = espKeyBtn

-- LINHA 4: LINK DISCORD & ATALHO MENU
local discordCard = Instance.new("TextButton")
discordCard.Size = UDim2.new(0, 200, 0, 38)
discordCard.Position = UDim2.new(0, 15, 0, 184)
discordCard.BackgroundColor3 = CARD_COLOR
discordCard.TextColor3 = SECONDARY_TEXT
discordCard.Font = Enum.Font.SourceSansBold
discordCard.TextSize = 12
discordCard.Text = "📋 Copiar Discord"
discordCard.AutoButtonColor = false
discordCard.Parent = menu

applyGlossEffect(discordCard)

local dcCorner = Instance.new("UICorner")
dcCorner.CornerRadius = UDim.new(0, 10)
dcCorner.Parent = discordCard

local dcStroke = Instance.new("UIStroke")
dcStroke.Color = STROKE_COLOR
dcStroke.Thickness = 1
dcStroke.Parent = discordCard

local menuKeyBtn = Instance.new("TextButton")
menuKeyBtn.Size = UDim2.new(0, 75, 0, 38)
menuKeyBtn.Position = UDim2.new(0, 225, 0, 184)
menuKeyBtn.BackgroundColor3 = SECONDARY_PILL
menuKeyBtn.TextColor3 = TEXT_MAIN
menuKeyBtn.Font = Enum.Font.SourceSansBold
menuKeyBtn.TextSize = 12
menuKeyBtn.Text = "[ M ]"
menuKeyBtn.AutoButtonColor = false
menuKeyBtn.Parent = menu

addHoverAnimation(menuKeyBtn, SECONDARY_PILL, Color3.fromRGB(220, 225, 235))

local mkCorner = Instance.new("UICorner")
mkCorner.CornerRadius = UDim.new(0, 10)
mkCorner.Parent = menuKeyBtn

---------------------------------------------------------
-- LÓGICA DE VALIDAÇÃO DA KEY
---------------------------------------------------------
local function verifyKey(customCode)
	if isAuthenticated then return end

	local rawCode = customCode or keyInput.Text
	local codeEntered = string.match(rawCode, "^%s*(.-)%s*$") or ""

	if codeEntered == GENERATED_KEY then
		isAuthenticated = true
		sendWebhookLog("✅ Acesso Liberado", 3066993, "O jogador validou o código com sucesso! (Via: " .. (customCode and "Chat" or "Interface") .. ")")
		showToast("Acesso Liberado!", GREEN_ACCENT, false)

		-- Animação de saída suave da caixa de key
		tween(keyFrame, 0.35, {Position = UDim2.new(0.5, -160, 0.25, -125)}, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Connect(function()
			keyFrame.Visible = false
		end)

		task.wait(0.2)
		menu.Visible = true
		menu.Position = UDim2.new(0, 20, 0.15, 0)
		tween(menu, 0.45, {Position = UDim2.new(0, 20, 0.2, 0)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	else
		if not customCode then
			sendWebhookLog("❌ Falha na Key", 15158332, "Tentativa com código incorreto: " .. codeEntered)
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
		if cleanMsg == GENERATED_KEY then
			verifyKey(cleanMsg)
		end
	end
end)

---------------------------------------------------------
-- MINIMIZAR / EXCLUIR
---------------------------------------------------------
local function toggleMenuVisibility()
	if not isAuthenticated then return end

	if menu.Visible then
		local t = tween(menu, 0.25, {Position = UDim2.new(0, 20, 0.15, 0)}, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		t.Completed:Connect(function() menu.Visible = false end)
		local menuKeyName = keybinds.Menu and keybinds.Menu.Name or "Nenhum"
		showToast("Menu Oculto (Pressione " .. menuKeyName .. ")", Color3.fromRGB(150, 150, 160), false)
	else
		menu.Visible = true
		menu.Position = UDim2.new(0, 20, 0.15, 0)
		tween(menu, 0.35, {Position = UDim2.new(0, 20, 0.2, 0)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
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
	else
		showToast("Link: discord.gg/rXZs7tzrN3", Color3.fromRGB(255, 170, 0), false)
	end
end)

---------------------------------------------------------
-- FUNCIONALIDADE DO ESP (WALLHACK & TAG)
---------------------------------------------------------
local function applyESPToCharacter(player, character)
	if player == LocalPlayer or not character then return end

	removeESPFromPlayer(player)

	-- Highlight através das paredes
	local highlight = Instance.new("Highlight")
	highlight.Name = "ZynkESP_HL"
	highlight.Adornee = character
	highlight.FillColor = Color3.fromRGB(100, 130, 255)
	highlight.FillTransparency = 0.5
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineTransparency = 0.1
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character

	-- Tag de Nome e Vida na Cabeça
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

local function toggleESP()
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
			if espCharAddedConns[p] then
				espCharAddedConns[p]:Disconnect()
				espCharAddedConns[p] = nil
			end
		end)
	else
		tween(espCard, 0.2, {BackgroundColor3 = CARD_COLOR, TextColor3 = SECONDARY_TEXT})
		espCard.Text = "ESP: DESATIVADO"
		showToast("ESP Desativado", RED_ACCENT, false)

		clearAllESP()
	end
end

espCard.MouseButton1Click:Connect(toggleESP)

---------------------------------------------------------
-- REGENERAÇÃO DE VIDA
---------------------------------------------------------
local function toggleRegen()
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

		if regenConnection then
			regenConnection:Disconnect()
			regenConnection = nil
		end
	end
end

regenCard.MouseButton1Click:Connect(toggleRegen)

---------------------------------------------------------
-- FILTRO ANTI-QUEDA
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

---------------------------------------------------------
-- NOCLIP PRINCIPAL
---------------------------------------------------------
local function toggleNoclip()
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
		tween(noclipCard, 0.2, {BackgroundColor3 = CARD_COLOR, TextColor3 = SECONDARY_TEXT})
		noclipCard.Text = "Noclip: DESATIVADO"

		if noclipConnection then
			noclipConnection:Disconnect()
			noclipConnection = nil
		end

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

noclipCard.MouseButton1Click:Connect(toggleNoclip)

---------------------------------------------------------
-- SISTEMA DE ATALHOS & FOCO AUTOMÁTICO NA TECLA [K]
---------------------------------------------------------
local function startListening(target, button)
	listeningTarget = target
	button.Text = "[ ... ]"
	tween(button, 0.2, {BackgroundColor3 = PRIMARY_PILL, TextColor3 = PRIMARY_TEXT})
end

noclipKeyBtn.MouseButton1Click:Connect(function() startListening("Noclip", noclipKeyBtn) end)
regenKeyBtn.MouseButton1Click:Connect(function() startListening("Regen", regenKeyBtn) end)
espKeyBtn.MouseButton1Click:Connect(function() startListening("ESP", espKeyBtn) end)
menuKeyBtn.MouseButton1Click:Connect(function() startListening("Menu", menuKeyBtn) end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- Atalho 'K' para focar na caixa de texto da Key sem clicar
	if not gameProcessed and not isAuthenticated then
		if input.KeyCode == Enum.KeyCode.K then
			task.defer(function()
				keyInput:CaptureFocus()
			end)
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
				showToast("Atalho " .. listeningTarget .. " removido", RED_ACCENT, false)
			else
				keybinds[listeningTarget] = input.KeyCode
				btn.Text = "[ " .. input.KeyCode.Name .. " ]"
				showToast("Atalho " .. listeningTarget .. ": " .. input.KeyCode.Name, GREEN_ACCENT, false)
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
