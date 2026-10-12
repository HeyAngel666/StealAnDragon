"""Roda o MapService num ambiente falso (luau) e salva as peças em JSON para a prévia.

Uso: python3 tools/preview/export_map.py <luau> <saida.json>
"""
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
luau, out = sys.argv[1], sys.argv[2]

def read(p):
    return open(os.path.join(ROOT, p), encoding="utf-8").read()

script = read("tools/preview/mock.luau") + "\n"
script += "local MODULES = {}\n"
script += "MODULES.Layout = (function()\n" + read("src/shared/Layout.lua") + "\nend)()\n"
script += """MODULES.DragonBuilder = { Build = function() local m = Instance.new("Model") return m end }
MODULES.Config = {}
require = function(m) return MODULES[m.Name] end
local MapService = (function()
""" + read("src/server/Services/MapService.lua") + """
end)()
MapService:Init()
local function fmt(n) return string.format("%.3f", n) end
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("BasePart") then
		local c, s, R, col = d.CFrame, d.Size, d.CFrame.R, d.Color
		local shape = d.Shape and d.Shape.Name or "Block"
		local mat = d.Material and d.Material.Name or "Plastic"
		print(table.concat({ "P", d.Name, d.ClassName, shape, fmt(s.X), fmt(s.Y), fmt(s.Z), fmt(c.p.X), fmt(c.p.Y), fmt(c.p.Z),
			fmt(R[1][1]), fmt(R[1][2]), fmt(R[1][3]), fmt(R[2][1]), fmt(R[2][2]), fmt(R[2][3]), fmt(R[3][1]), fmt(R[3][2]), fmt(R[3][3]),
			fmt(col.R), fmt(col.G), fmt(col.B), fmt(d.Transparency or 0), mat }, "|"))
	end
end
"""
with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as f:
    f.write(script)
    path = f.name
res = subprocess.run([luau, path], capture_output=True, text=True)
if res.returncode != 0:
    print(res.stdout[-2000:], res.stderr[-4000:])
    sys.exit(1)
parts = []
for line in res.stdout.splitlines():
    if not line.startswith("P|"):
        continue
    f = line.split("|")
    parts.append({
        "name": f[1], "class": f[2], "shape": f[3],
        "size": [float(x) for x in f[4:7]], "pos": [float(x) for x in f[7:10]],
        "rot": [float(x) for x in f[10:19]], "color": [float(x) for x in f[19:22]],
        "transparency": float(f[22]), "material": f[23],
    })
json.dump(parts, open(out, "w"))
print("partes:", len(parts))
