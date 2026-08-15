-- ============================================================
--  ПОЛЮС-11 — СПАВНЕР ЭНТИТИ FIXBOOT v5.6.4 (server, autorun)
--  Спавнит невидимую энтити polus_p11_fixboot под картой → её
--  cl_init.lua (все клиентские фиксы) гарантированно уходит
--  клиентам (энтити раздаются всегда, не зависят от sv_allowcslua).
-- ============================================================

local function SpawnFix()
    if ents.FindByClass("polus_p11_fixboot")[1] then return end
    local e = ents.Create("polus_p11_fixboot")
    if IsValid(e) then
        e:SetPos(Vector(0, 0, -20000))
        e:Spawn()
    end
end

hook.Add("InitPostEntity", "P11.FixSpawn564", function()
    timer.Simple(1, SpawnFix)
end)
hook.Add("PostCleanupMap", "P11.FixSpawn564b", function()
    timer.Simple(3, SpawnFix)
end)

print("[POLUS-11] СПАВНЕР FIXBOOT v5.6.4: энтити создана — фиксы дойдут до клиентов")
