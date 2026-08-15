-- ============================================================
--  ПОЛЮС-11 — СПАВНЕР ЭНТИТИ INFOBOOT v5.6.8 (server, autorun)
--  Спавнит невидимую энтити polus_p11_infoboot под картой → её
--  cl_init (кнопка «О НАС» + чат при входе) уходит клиентам.
-- ============================================================

local function SpawnInfo()
    if ents.FindByClass("polus_p11_infoboot")[1] then return end
    local e = ents.Create("polus_p11_infoboot")
    if IsValid(e) then
        e:SetPos(Vector(0, 0, -20000))
        e:Spawn()
    end
end

hook.Add("InitPostEntity", "P11.InfoSpawn568", function()
    timer.Simple(1, SpawnInfo)
end)
hook.Add("PostCleanupMap", "P11.InfoSpawn568b", function()
    timer.Simple(3, SpawnInfo)
end)

print("[POLUS-11] СПАВНЕР INFOBOOT v5.6.8: кнопка «О НАС» + чат при входе дойдут до клиентов")
