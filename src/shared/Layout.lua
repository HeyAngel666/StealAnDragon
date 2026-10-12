-- Posições do mapa usadas pelo servidor e pelo cliente.
-- Mapa: esteira no meio (eixo X), 4 bases ao norte e 4 ao sul, praça no leste.

local Layout = {}

Layout.GroundY = 0 -- topo do chão
Layout.ConveyorStart = Vector3.new(-185, 1, 0)
Layout.ConveyorEnd = Vector3.new(185, 1, 0)
Layout.ConveyorWidth = 18

Layout.BaseSize = 64
Layout.BaseWallHeight = 15
Layout.EntranceWidth = 58 -- frente aberta (laser cobre a frente toda)

Layout.PlazaCenter = Vector3.new(225, 0, 0)

-- Centro de cada base e para onde a entrada aponta (sempre para a esteira).
local BASE_X = { -120, -40, 40, 120 }
local BASE_Z = 72

Layout.Bases = {}
for _, x in ipairs(BASE_X) do
	-- Norte: entrada virada para +Z
	table.insert(Layout.Bases, CFrame.new(x, 0, -BASE_Z))
	-- Sul: girada 180 graus, entrada virada para -Z
	table.insert(Layout.Bases, CFrame.new(x, 0, BASE_Z) * CFrame.Angles(0, math.pi, 0))
end

-- Bases de 2 andares: térreo + andar de cima (escada no meio, ao fundo)
Layout.UpperFloorY = 15 -- altura do piso do 2º andar (acima do piso do térreo)
Layout.StairsWidth = 8

-- Slots dentro da base (coordenadas locais; +Z = lado da entrada)
-- 10 no térreo (2 colunas x 5) + 10 no andar de cima
local COLUMNS = { -22, 22 }
local ROWS = { -22, -11, 0, 11, 22 }
Layout.Slots = {}
for _, floorY in ipairs({ 0, Layout.UpperFloorY }) do
	for _, z in ipairs(ROWS) do
		for _, x in ipairs(COLUMNS) do
			table.insert(Layout.Slots, Vector3.new(x, floorY, z))
		end
	end
end

Layout.LockButton = Vector3.new(0, 0, 24)
Layout.SpawnPoint = Vector3.new(0, 0, 12)

-- Verifica se uma posição do mundo está dentro de uma base.
function Layout.IsInsideBase(baseCFrame: CFrame, position: Vector3): boolean
	local localPos = baseCFrame:PointToObjectSpace(position)
	local half = Layout.BaseSize / 2
	return math.abs(localPos.X) <= half and math.abs(localPos.Z) <= half and localPos.Y < 40 and localPos.Y > -5
end

return Layout
