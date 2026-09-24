local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 1. Cria a tela (ScreenGui) automaticamente
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BotaoExplodirGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- 2. Cria o botão automaticamente
local botao = Instance.new("TextButton")
botao.Name = "BotaoExplodir"
botao.Size = UDim2.new(0, 150, 0, 50)
botao.Position = UDim2.new(0.5, -75, 0.85, -25) -- Fica na parte inferior central da tela
botao.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
botao.TextColor3 = Color3.fromRGB(255, 255, 255)
botao.TextSize = 20
botao.Font = Enum.Font.SourceSansBold
botao.Text = "EXPLODIR"
botao.Parent = screenGui

-- Arredonda as bordas do botão (opcional)
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = botao

-- 3. Ação ao clicar no botão
botao.MouseButton1Click:Connect(function()
	local personagem = player.Character
	if personagem and personagem:FindFirstChild("HumanoidRootPart") then
		local hrp = personagem.HumanoidRootPart
		
		-- Cria a explosão na posição do jogador
		local explosao = Instance.new("Explosion")
		explosao.Position = hrp.Position
		explosao.BlastRadius = 15
		explosao.BlastPressure = 50000
		explosao.Parent = workspace
		
		-- Mata o personagem
		local humanoide = personagem:FindFirstChildOfClass("Humanoid")
		if humanoide then
			humanoide.Health = 0
		end
	end
end)
