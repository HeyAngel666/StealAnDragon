-- Ambiente falso do Roblox só para rodar o MapService e exportar as peças (prévia no Blender).
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3mt) end
Vector3mt = {}
Vector3mt.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Unit" then local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z); if m == 0 then return vec() end return vec(v.X / m, v.Y / m, v.Z / m) end
	if k == "Lerp" then return function(a, b, t) return a + (b - a) * t end end
	if k == "Dot" then return function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end end
	if k == "Cross" then return function(a, b) return vec(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end end
	return nil
end
Vector3mt.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vector3mt.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3mt.__unm = function(a) return vec(-a.X, -a.Y, -a.Z) end
Vector3mt.__mul = function(a, b)
	if type(a) == "number" then return vec(b.X * a, b.Y * a, b.Z * a) end
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3mt.__div = function(a, b) return vec(a.X / b, a.Y / b, a.Z / b) end
Vector3 = { new = vec, zero = vec(0, 0, 0), yAxis = vec(0, 1, 0), xAxis = vec(1, 0, 0), zAxis = vec(0, 0, 1) }

-- CFrame: posição p e matriz R (linhas)
CFmt = {}
local function cf(p, R) return setmetatable({ p = p, R = R }, CFmt) end
local I = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }
local function mm(A, B)
	local C = {}
	for i = 1, 3 do C[i] = {} for j = 1, 3 do C[i][j] = A[i][1] * B[1][j] + A[i][2] * B[2][j] + A[i][3] * B[3][j] end end
	return C
end
local function mv(A, v) return vec(A[1][1] * v.X + A[1][2] * v.Y + A[1][3] * v.Z, A[2][1] * v.X + A[2][2] * v.Y + A[2][3] * v.Z, A[3][1] * v.X + A[3][2] * v.Y + A[3][3] * v.Z) end
local function tr(A) return { { A[1][1], A[2][1], A[3][1] }, { A[1][2], A[2][2], A[3][2] }, { A[1][3], A[2][3], A[3][3] } } end
CFmt.__index = function(c, k)
	if k == "Position" then return c.p end
	if k == "Rotation" then return cf(vec(), c.R) end
	if k == "LookVector" then return vec(-c.R[1][3], -c.R[2][3], -c.R[3][3]) end
	if k == "UpVector" then return vec(c.R[1][2], c.R[2][2], c.R[3][2]) end
	if k == "RightVector" then return vec(c.R[1][1], c.R[2][1], c.R[3][1]) end
	if k == "X" then return c.p.X end
	if k == "Y" then return c.p.Y end
	if k == "Z" then return c.p.Z end
	if k == "Inverse" then return function(s) local Rt = tr(s.R) return cf(-mv(Rt, s.p), Rt) end end
	if k == "PointToObjectSpace" then return function(s, v) return mv(tr(s.R), v - s.p) end end
	if k == "VectorToWorldSpace" then return function(s, v) return mv(s.R, v) end end
	if k == "VectorToObjectSpace" then return function(s, v) return mv(tr(s.R), v) end end
	if k == "ToObjectSpace" then return function(s, o) return s:Inverse() * o end end
	return nil
end
CFmt.__mul = function(a, b)
	if getmetatable(b) == CFmt then return cf(a.p + mv(a.R, b.p), mm(a.R, b.R)) end
	return a.p + mv(a.R, b)
end
CFmt.__add = function(a, v) return cf(a.p + v, a.R) end
CFmt.__sub = function(a, v) return cf(a.p - v, a.R) end
local function rx(t) local c, s = math.cos(t), math.sin(t) return { { 1, 0, 0 }, { 0, c, -s }, { 0, s, c } } end
local function ry(t) local c, s = math.cos(t), math.sin(t) return { { c, 0, s }, { 0, 1, 0 }, { -s, 0, c } } end
local function rz(t) local c, s = math.cos(t), math.sin(t) return { { c, -s, 0 }, { s, c, 0 }, { 0, 0, 1 } } end
CFrame = {
	new = function(x, y, z)
		if x == nil then return cf(vec(), I) end
		if type(x) == "table" then return cf(x, I) end
		return cf(vec(x, y, z), I)
	end,
	Angles = function(a, b, c) return cf(vec(), mm(mm(rx(a), ry(b)), rz(c))) end,
	lookAt = function(at, target, up)
		up = up or vec(0, 1, 0)
		local f = (target - at).Unit
		local r = f:Cross(up).Unit
		local u = r:Cross(f)
		return cf(at, { { r.X, u.X, -f.X }, { r.Y, u.Y, -f.Y }, { r.Z, u.Z, -f.Z } })
	end,
}

Color3 = {
	new = function(r, g, b) return { R = r, G = g, B = b, Lerp = function(a, o, t) return Color3.new(a.R + (o.R - a.R) * t, a.G + (o.G - a.G) * t, a.B + (o.B - a.B) * t) end } end,
}
Color3.fromRGB = function(r, g, b) return Color3.new(r / 255, g / 255, b / 255) end
Color3.fromHSV = function(h, s, v)
	local i = math.floor(h * 6); local f = h * 6 - i; local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i = i % 6
	local r, g, b
	if i == 0 then r, g, b = v, t, p elseif i == 1 then r, g, b = q, v, p elseif i == 2 then r, g, b = p, v, t elseif i == 3 then r, g, b = p, q, v elseif i == 4 then r, g, b = t, p, v else r, g, b = v, p, q end
	return Color3.new(r, g, b)
end

local function stubType() return setmetatable({}, { __index = function(t, k) return function(...) return {} end end }) end
UDim2 = stubType(); UDim = stubType(); ColorSequence = stubType(); ColorSequenceKeypoint = stubType(); NumberSequence = stubType(); NumberSequenceKeypoint = stubType(); NumberRange = stubType(); Vector2 = stubType()
Enum = setmetatable({}, { __index = function(_, cat) return setmetatable({}, { __index = function(_, item) return { Name = item, EnumType = cat } end }) end })

Random = { new = function(seed)
	local s = seed or 1
	local function nxt() s = (s * 1103515245 + 12345) % 2147483648 return s / 2147483648 end
	return { NextNumber = function(_, a, b) a = a or 0; b = b or 1 return a + (b - a) * nxt() end, NextInteger = function(_, a, b) return a + math.floor(nxt() * (b - a + 1)) end }
end }

-- Instâncias
local Inst = {}
Inst.__index = function(o, k)
	local raw = rawget(o, "_props")[k]
	if raw ~= nil then return raw end
	if Inst[k] then return Inst[k] end
	for _, c in ipairs(rawget(o, "_children")) do if c.Name == k then return c end end
	return nil
end
Inst.__newindex = function(o, k, v)
	if k == "Parent" then
		local old = rawget(o, "_props").Parent
		if old then for i, c in ipairs(rawget(old, "_children")) do if c == o then table.remove(rawget(old, "_children"), i) break end end end
		if v then table.insert(rawget(v, "_children"), o) end
	end
	if k == "Position" then rawget(o, "_props").CFrame = cf(v, (rawget(o, "_props").CFrame or CFrame.new()).R) end
	rawget(o, "_props")[k] = v
end
function Inst.FindFirstChild(o, n) for _, c in ipairs(rawget(o, "_children")) do if c.Name == n then return c end end return nil end
Inst.WaitForChild = Inst.FindFirstChild
function Inst.FindFirstChildOfClass(o, n) for _, c in ipairs(rawget(o, "_children")) do if c.ClassName == n then return c end end return nil end
function Inst.GetChildren(o) return { table.unpack(rawget(o, "_children")) } end
function Inst.GetDescendants(o)
	local out = {}
	local function walk(x) for _, c in ipairs(rawget(x, "_children")) do table.insert(out, c) walk(c) end end
	walk(o) return out
end
function Inst.SetAttribute(o, k, v) end
function Inst.GetAttribute(o, k) return nil end
function Inst.Destroy(o) o.Parent = nil end
function Inst.Clear(o) end
function Inst.FillBlock(o) end
function Inst.FillBall(o) end
function Inst.PivotTo(o) end
function Inst.IsA(o, c) return o.ClassName == c or (c == "BasePart" and (o.ClassName == "Part" or o.ClassName == "WedgePart" or o.ClassName == "SpawnLocation")) end
local function newInst(className)
	local o = setmetatable({ _props = { ClassName = className, Name = className, Transparency = 0, Color = Color3.new(0.64, 0.64, 0.64) }, _children = {} }, Inst)
	if className == "Part" or className == "WedgePart" or className == "SpawnLocation" then o.Size = vec(4, 1, 2); o.CFrame = CFrame.new() end
	return o
end
Instance = { new = newInst }

workspace = newInst("Workspace")
local terrain = newInst("Terrain"); terrain.Name = "Terrain"; terrain.Parent = workspace
local services = {}
game = { GetService = function(_, n) if n == "Workspace" then return workspace end services[n] = services[n] or newInst(n) return services[n] end }
local RS = game:GetService("ReplicatedStorage")
local shared = newInst("Folder"); shared.Name = "Shared"; shared.Parent = RS
for _, n in ipairs({ "Layout", "DragonBuilder", "Config" }) do local m = newInst("ModuleScript"); m.Name = n; m.Parent = shared end
