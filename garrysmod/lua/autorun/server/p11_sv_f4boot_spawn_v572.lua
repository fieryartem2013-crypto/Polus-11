-- ============================================================
--  ПОЛЮС-11 — СПАВНЕР ЭНТИТИ F4BOOT v5.7.2 (server, autorun)
--  Спавнит невидимую энтити polus_p11_f4boot под картой → её
--  cl_init (F4 с блокировкой древа) уходит клиентам.
-- ============================================================
local function SpawnF4()
    if ents.FindByClass("polus_p11_f4boot")[1] then return end
    local e = ents.Create("polus_p11_f4boot")
    if IsValid(e) then e:SetPos(Vector(0, 0, -20000)) e:Spawn() end
end
hook.Add("InitPostEntity", "P11.F4Spawn572", function() timer.Simple(1, SpawnF4) end)
hook.Add("PostCleanupMap", "P11.F4Spawn572b", function() timer.Simple(3, SpawnF4) end)
print("[POLUS-11] СПАВНЕР F4BOOT v5.7.2: F4 с «закрыто древо» дойдёт до клиентов")
