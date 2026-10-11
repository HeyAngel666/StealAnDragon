-- Posições do mapa usadas pelo servidor e pelo cliente.
-- Mapa: esteira no meio (eixo X), 4 bases ao norte e 4 ao sul, praça no leste.

local Layout = {}

Layout.GroundY = 0 -- topo do chão
Layout.ConveyorStart = Vector3.new(-185, 1, 0)
Layout.ConveyorEnd = Vector3.new(185, 1, 0)
Layout.ConveyorWidth = 12

Layout.BaseSize = 64
Layout.BaseWallHeight = 18
Layout.EntranceWidth = 18

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

-- Slots dentro da base (coordenadas locais; +Z = lado da entrada)
-- 4 colunas x 5 linhas = 20 slots
local COLUMNS = { -24, -11, 11, 24 }
local ROWS = { -24, -14, -4, 6, 16 }
Layout.Slots = {}
for _, z in ipairs(ROWS) do
	for _, x in ipairs(COLUMNS) do
		table.insert(Layout.Slots, Vector3.new(x, 0, z))
	end
end

Layout.LockButton = Vector3.new(0, 0, 22)
Layout.SpawnPoint = Vector3.new(0, 0, -6)

-- Verifica se uma posição do mundo está dentro de uma base.
function Layout.IsInsideBase(baseCFrame: CFrame, position: Vector3): boolean
	local localPos = baseCFrame:PointToObjectSpace(position)
	local half = Layout.BaseSize / 2
	return math.abs(localPos.X) <= half and math.abs(localPos.Z) <= half and localPos.Y < 40 and localPos.Y > -5
end

return Layout
