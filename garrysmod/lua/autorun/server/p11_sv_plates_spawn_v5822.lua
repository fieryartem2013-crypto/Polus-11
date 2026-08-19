-- ============================================================
--  ПОЛЮС-11 — СПАВНЕР PLATES v5.8.22 (server, autorun)
--  Спавнит невидимую энтити polus_p11_plates под картой → её
--  cl_init.lua (патч двусторонних 3D2D-плашек: видны сквозь
--  геометрию и с обеих сторон) уходит клиентам.
-- ============================================================

local function SpawnPlates()
    if ents.FindByClass("polus_p11_plates")[1] then return end
    local e = ents.Create("polus_p11_plates")
    if IsValid(e) then
        e:SetPos(Vector(0, 0, -20000))
        e:Spawn()
    end
end

hook.Add("InitPostEntity", "P11.Plates.Spawn5822", function()
    timer.Simple(1, SpawnPlates)
end)
hook.Add("PostCleanupMap", "P11.Plates.Spawn5822b", function()
    timer.Simple(3, SpawnPlates)
end)

print("[POLUS-11] СПАВНЕР PLATES v5.8.22: плашки будут видны всегда")
