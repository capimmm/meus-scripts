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
local isAuthenticated = false

local noclipConnection = nil
local regenConnection = nil
local hideToastTask = nil

-- Atalhos individuais para cada poder
local keybinds = {
	Noclip = Enum.KeyCode.N,
	Regen = Enum.KeyCode.R,
	Menu = Enum.KeyCode.M
}

local listeningTarget = nil -- Qual tecla está sendo reconfigurada no momento

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
-- ANIMAÇÕES SUAVES
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

local function unloadScript()
	if noclipConnection then noclipConnection:Disconnect() end
	if regenConnection then regenConnection:Disconnect() end
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
-- INTERFACE GRÁFICA
---------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ZynkMenuGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = PlayerGui

local BG_COLOR = Color3.fromRGB(20, 20, 23)
local CARD_COLOR = Color3.fromRGB(28, 28, 32)
local STROKE_COLOR = Color3.fromRGB(50, 50, 58)
local PRIMARY_PILL = Color3.fromRGB(235, 235, 240)
local PRIMARY_TEXT = Color3.fromRGB(18, 18, 22)
local SECONDARY_PILL = Color3.fromRGB(38, 38, 44)
local SECONDARY_TEXT = Color3.fromRGB(200, 200, 210)
local GREEN_ACCENT = Color3.fromRGB(46, 204, 113)
local RED_ACCENT = Color3.fromRGB(231, 76, 60)

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
-- TOAST DE NOTIFICAÇÃO
---------------------------------------------------------
local toast = Instance.new("Frame")
toast.Name = "ToastNotification"
toast.Size = UDim2.new(0, 260, 0, 44)
toast.Position = UDim2.new(0, -290, 1, -64) 
toast.BackgroundColor3 = BG_COLOR
toast.BorderSizePixel = 0
toast.Parent = screenGui

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
toastLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
toastLabel.Font = Enum.Font.SourceSansBold
toastLabel.TextSize = 13
toastLabel.TextXAlignment = Enum.TextXAlignment.Left
toastLabel.Text = "Zynk menu Ativo"
toastLabel.Parent = toast

local function showToast(text, color, keepVisible)
	if hideToastTask then task.cancel(hideToastTask) hideToastTask = nil end
	toastLabel.Text = text
	statusDot.BackgroundColor3 = color
	tween(toast, 0.4, {Position = UDim2.new(0, 20, 1, -64)})

	if not keepVisible then
		hideToastTask = task.delay(3.5, function()
			tween(toast, 0.4, {Position = UDim2.new(0, -290, 1, -64)})
			hideToastTask = nil
		end)
	end
end

---------------------------------------------------------
-- TELA DE KEY COM PEDIDO DO DISCORD NO CARD DO ROBLOX
---------------------------------------------------------
local keyFrame = Instance.new("Frame")
keyFrame.Name = "KeyFrame"
keyFrame.Size = UDim2.new(0, 320, 0, 250)
keyFrame.Position = UDim2.new(0.5, -160, 0.35, -125)
keyFrame.BackgroundColor3 = BG_COLOR
keyFrame.BorderSizePixel = 0
keyFrame.Parent = screenGui

local keyCorner = Instance.new("UICorner")
keyCorner.CornerRadius = UDim.new(0, 16)
keyCorner.Parent = keyFrame

local keyStroke = Instance.new("UIStroke")
keyStroke.Color = STROKE_COLOR
keyStroke.Thickness = 1.2
keyStroke.Parent = keyFrame

makeDraggable(keyFrame)

local keyTitle = Instance.new("TextLabel")
keyTitle.Size = UDim2.new(1, -30, 0, 35)
keyTitle.Position = UDim2.new(0, 15, 0, 10)
keyTitle.BackgroundTransparency = 1
keyTitle.TextColor3 = Color3.fromRGB(240, 240, 245)
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

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 10)
cardCorner.Parent = discordPromptCard

local promptText = Instance.new("TextLabel")
promptText.Size = UDim2.new(1, -20, 0, 32)
promptText.Position = UDim2.new(0, 10, 0, 4)
promptText.BackgroundTransparency = 1
promptText.TextColor3 = Color3.fromRGB(190, 190, 200)
promptText.Font = Enum.Font.SourceSans
promptText.TextSize = 12
promptText.TextWrapped = true
promptText.Text = "Entre no nosso servidor do Discord para resgatar seu código de acesso!"
promptText.Parent = discordPromptCard

local copyDiscordBtn = Instance.new("TextButton")
copyDiscordBtn.Size = UDim2.new(1, -20, 0, 24)
copyDiscordBtn.Position = UDim2.new(0, 10, 0, 38)
copyDiscordBtn.BackgroundColor3 = SECONDARY_PILL
copyDiscordBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
copyDiscordBtn.Font = Enum.Font.SourceSansBold
copyDiscordBtn.TextSize = 12
copyDiscordBtn.Text = "📋 Copiar Link do Discord"
copyDiscordBtn.AutoButtonColor = false
copyDiscordBtn.Parent = discordPromptCard

local copyCorner = Instance.new("UICorner")
copyCorner.CornerRadius = UDim.new(0, 6)
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
keyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
keyInput.PlaceholderText = "Insira a Key aqui..."
keyInput.PlaceholderColor3 = Color3.fromRGB(110, 110, 120)
keyInput.Font = Enum.Font.SourceSans
keyInput.TextSize = 14
keyInput.Text = ""
keyInput.Parent = keyFrame

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 10)
inputCorner.Parent = keyInput

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

local verifyCorner = Instance.new("UICorner")
verifyCorner.CornerRadius = UDim.new(0, 10)
verifyCorner.Parent = verifyBtn

---------------------------------------------------------
-- MENU PRINCIPAL (DESIGN CONFORME SEU DESENHO)
---------------------------------------------------------
local menu = Instance.new("Frame")
menu.Name = "MainMenu"
menu.Size = UDim2.new(0, 320, 0, 205)
menu.Position = UDim2.new(0, 20, 0.2, 0)
menu.BackgroundColor3 = BG_COLOR
menu.BorderSizePixel = 0
menu.Visible = false
menu.Parent = screenGui

local menuCorner = Instance.new("UICorner")
menuCorner.CornerRadius = UDim.new(0, 16)
menuCorner.Parent = menu

local menuStroke = Instance.new("UIStroke")
menuStroke.Color = STROKE_COLOR
menuStroke.Thickness = 1.2
menuStroke.Parent = menu

makeDraggable(menu)

---------------------------------------------------------
-- CABEÇALHO COM DIVISÃO CONFORME O DESENHO
---------------------------------------------------------
local menuTitle = Instance.new("TextLabel")
menuTitle.Size = UDim2.new(0, 150, 0, 40)
menuTitle.Position = UDim2.new(0, 16, 0, 0)
menuTitle.BackgroundTransparency = 1
menuTitle.TextColor3 = Color3.fromRGB(240, 240, 245)
menuTitle.Font = Enum.Font.SourceSansBold
menuTitle.TextSize = 18
menuTitle.TextXAlignment = Enum.TextXAlignment.Left
menuTitle.Text = "ZYNK"
menuTitle.Parent = menu

-- Caixinha Superior Direita com X e -
local actionPod = Instance.new("Frame")
actionPod.Name = "ActionPod"
actionPod.Size = UDim2.new(0, 70, 0, 28)
actionPod.Position = UDim2.new(1, -82, 0, 6)
actionPod.BackgroundColor3 = Color3.fromRGB(14, 14, 17)
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
deleteBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
deleteBtn.TextColor3 = RED_ACCENT
deleteBtn.Font = Enum.Font.SourceSansBold
deleteBtn.TextSize = 13
deleteBtn.Text = "X"
deleteBtn.AutoButtonColor = false
deleteBtn.Parent = actionPod

local delCorner = Instance.new("UICorner")
delCorner.CornerRadius = UDim.new(0, 6)
delCorner.Parent = deleteBtn

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name = "MinimizeBtn"
minimizeBtn.Size = UDim2.new(0, 24, 0, 22)
minimizeBtn.Position = UDim2.new(1, -27, 0.5, -11)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
minimizeBtn.Font = Enum.Font.SourceSansBold
minimizeBtn.TextSize = 15
minimizeBtn.Text = "—"
minimizeBtn.AutoButtonColor = false
minimizeBtn.Parent = actionPod

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 6)
minCorner.Parent = minimizeBtn

---------------------------------------------------------
-- LINHAS DO MENU (PODER NA ESQUERDA | TECLA NA DIREITA)
---------------------------------------------------------

-- LINHA 1: NOCLIP
local noclipCard = Instance.new("TextButton")
noclipCard.Size = UDim2.new(0, 200, 0, 38)
noclipCard.Position = UDim2.new(0, 15, 0, 48)
noclipCard.BackgroundColor3 = SECONDARY_PILL
noclipCard.TextColor3 = SECONDARY_TEXT
noclipCard.Font = Enum.Font.SourceSansBold
noclipCard.TextSize = 13
noclipCard.Text = "Noclip: DESATIVADO"
noclipCard.AutoButtonColor = false
noclipCard.Parent = menu

local ncCorner = Instance.new("UICorner")
ncCorner.CornerRadius = UDim.new(0, 10)
ncCorner.Parent = noclipCard

local noclipKeyBtn = Instance.new("TextButton")
noclipKeyBtn.Size = UDim2.new(0, 75, 0, 38)
noclipKeyBtn.Position = UDim2.new(0, 225, 0, 48)
noclipKeyBtn.BackgroundColor3 = CARD_COLOR
noclipKeyBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
noclipKeyBtn.Font = Enum.Font.SourceSansBold
noclipKeyBtn.TextSize = 12
noclipKeyBtn.Text = "[ N ]"
noclipKeyBtn.AutoButtonColor = false
noclipKeyBtn.Parent = menu

local nckCorner = Instance.new("UICorner")
nckCorner.CornerRadius = UDim.new(0, 10)
nckCorner.Parent = noclipKeyBtn

-- LINHA 2: REGEN DE VIDA
local regenCard = Instance.new("TextButton")
regenCard.Size = UDim2.new(0, 200, 0, 38)
regenCard.Position = UDim2.new(0, 15, 0, 96)
regenCard.BackgroundColor3 = SECONDARY_PILL
regenCard.TextColor3 = SECONDARY_TEXT
regenCard.Font = Enum.Font.SourceSansBold
regenCard.TextSize = 13
regenCard.Text = "Regen Vida: DESATIVADO"
regenCard.AutoButtonColor = false
regenCard.Parent = menu

local rgCorner = Instance.new("UICorner")
rgCorner.CornerRadius = UDim.new(0, 10)
rgCorner.Parent = regenCard

local regenKeyBtn = Instance.new("TextButton")
regenKeyBtn.Size = UDim2.new(0, 75, 0, 38)
regenKeyBtn.Position = UDim2.new(0, 225, 0, 96)
regenKeyBtn.BackgroundColor3 = CARD_COLOR
regenKeyBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
regenKeyBtn.Font = Enum.Font.SourceSansBold
regenKeyBtn.TextSize = 12
regenKeyBtn.Text = "[ R ]"
regenKeyBtn.AutoButtonColor = false
regenKeyBtn.Parent = menu

local rgkCorner = Instance.new("UICorner")
rgkCorner.CornerRadius = UDim.new(0, 10)
rgkCorner.Parent = regenKeyBtn

-- LINHA 3: LINK DISCORD & ATALHO MENU
local discordCard = Instance.new("TextButton")
discordCard.Size = UDim2.new(0, 200, 0, 38)
discordCard.Position = UDim2.new(0, 15, 0, 144)
discordCard.BackgroundColor3 = CARD_COLOR
discordCard.TextColor3 = Color3.fromRGB(180, 180, 190)
discordCard.Font = Enum.Font.SourceSans
discordCard.TextSize = 12
discordCard.Text = "📋 Copiar Discord"
discordCard.AutoButtonColor = false
discordCard.Parent = menu

local dcCorner = Instance.new("UICorner")
dcCorner.CornerRadius = UDim.new(0, 10)
dcCorner.Parent = discordCard

local menuKeyBtn = Instance.new("TextButton")
menuKeyBtn.Size = UDim2.new(0, 75, 0, 38)
menuKeyBtn.Position = UDim2.new(0, 225, 0, 144)
menuKeyBtn.BackgroundColor3 = CARD_COLOR
menuKeyBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
menuKeyBtn.Font = Enum.Font.SourceSansBold
menuKeyBtn.TextSize = 12
menuKeyBtn.Text = "[ M ]"
menuKeyBtn.AutoButtonColor = false
menuKeyBtn.Parent = menu

local mkCorner = Instance.new("UICorner")
mkCorner.CornerRadius = UDim.new(0, 10)
mkCorner.Parent = menuKeyBtn

---------------------------------------------------------
-- LÓGICA DE VALIDAÇÃO DA KEY
---------------------------------------------------------
local function verifyKey()
	local codeEntered = keyInput.Text

	if codeEntered == GENERATED_KEY then
		isAuthenticated = true
		sendWebhookLog("✅ Acesso Liberado", 3066993, "O jogador validou o código com sucesso!")
		showToast("Acesso Liberado!", GREEN_ACCENT, false)

		tween(keyFrame, 0.25, {BackgroundTransparency = 1, Position = UDim2.new(0.5, -160, 0.3, -125)}).Completed:Connect(function()
			keyFrame.Visible = false
		end)

		task.wait(0.2)
		menu.Visible = true
		tween(menu, 0.3, {BackgroundTransparency = 0})
	else
		sendWebhookLog("❌ Falha na Key", 15158332, "Tentativa com código incorreto: " .. codeEntered)
		showToast("Código Incorreto!", RED_ACCENT, false)
		keyInput.Text = ""
	end
end

verifyBtn.MouseButton1Click:Connect(verifyKey)
keyInput.FocusLost:Connect(function(enterPressed)
	if enterPressed then verifyKey() end
end)

---------------------------------------------------------
-- MINIMIZAR / EXCLUIR
---------------------------------------------------------
local function toggleMenuVisibility()
	if not isAuthenticated then return end

	if menu.Visible then
		local t = tween(menu, 0.2, {BackgroundTransparency = 1})
		for _, child in ipairs(menu:GetDescendants()) do
			if child:IsA("TextLabel") or child:IsA("TextButton") then
				tween(child, 0.2, {TextTransparency = 1, BackgroundTransparency = 1})
			elseif child:IsA("Frame") then
				tween(child, 0.2, {BackgroundTransparency = 1})
			elseif child:IsA("UIStroke") then
				tween(child, 0.2, {Transparency = 1})
			end
		end
		
		t.Completed:Connect(function() menu.Visible = false end)
		local menuKeyName = keybinds.Menu and keybinds.Menu.Name or "Nenhum"
		showToast("Menu Oculto (Pressione " .. menuKeyName .. ")", Color3.fromRGB(150, 150, 160), false)
	else
		menu.Visible = true
		tween(menu, 0.25, {BackgroundTransparency = 0})
		for _, child in ipairs(menu:GetDescendants()) do
			if child:IsA("UIStroke") then
				tween(child, 0.25, {Transparency = 0})
			elseif child:IsA("Frame") and child.Name == "ActionPod" then
				tween(child, 0.25, {BackgroundTransparency = 0})
			elseif child:IsA("TextLabel") then
				tween(child, 0.25, {TextTransparency = 0})
			elseif child:IsA("TextButton") then
				tween(child, 0.25, {TextTransparency = 0, BackgroundTransparency = 0})
			end
		end
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
		tween(regenCard, 0.2, {BackgroundColor3 = SECONDARY_PILL, TextColor3 = SECONDARY_TEXT})
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
		tween(noclipCard, 0.2, {BackgroundColor3 = SECONDARY_PILL, TextColor3 = SECONDARY_TEXT})
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
-- SISTEMA DE ATALHOS PERSONALIZADOS POR PODER
---------------------------------------------------------
local function startListening(target, button)
	listeningTarget = target
	button.Text = "[ ... ]"
	tween(button, 0.2, {BackgroundColor3 = SECONDARY_PILL, TextColor3 = Color3.fromRGB(255, 255, 255)})
end

noclipKeyBtn.MouseButton1Click:Connect(function() startListening("Noclip", noclipKeyBtn) end)
regenKeyBtn.MouseButton1Click:Connect(function() startListening("Regen", regenKeyBtn) end)
menuKeyBtn.MouseButton1Click:Connect(function() startListening("Menu", menuKeyBtn) end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if listeningTarget then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local btn = (listeningTarget == "Noclip" and noclipKeyBtn) or (listeningTarget == "Regen" and regenKeyBtn) or menuKeyBtn
			
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
			tween(btn, 0.2, {BackgroundColor3 = CARD_COLOR, TextColor3 = Color3.fromRGB(180, 180, 190)})
		end
		return
	end

	if not gameProcessed and isAuthenticated then
		if keybinds.Noclip and input.KeyCode == keybinds.Noclip then
			toggleNoclip()
		elseif keybinds.Regen and input.KeyCode == keybinds.Regen then
			toggleRegen()
		elseif keybinds.Menu and input.KeyCode == keybinds.Menu then
			toggleMenuVisibility()
		end
	end
end)
