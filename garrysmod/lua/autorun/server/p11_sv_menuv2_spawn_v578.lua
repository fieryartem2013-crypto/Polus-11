-- ============================================================
--  ПОЛЮС-11 — СПАВНЕР ЭНТИТИ MENUV2 v5.7.8 (server, autorun)
--  Спавнит невидимую энтити polus_p11_menuv2 под картой → её
--  cl_init.lua (мини-интро, меню персонажа, полировка С-меню)
--  гарантированно уходит клиентам (энтити раздаются всегда,
--  не зависят от sv_allowcslua).
-- ============================================================

local function SpawnMV()
    if ents.FindByClass("polus_p11_menuv2")[1] then return end
    local e = ents.Create("polus_p11_menuv2")
    if IsValid(e) then
        e:SetPos(Vector(0, 0, -20000))
        e:Spawn()
    end
end

hook.Add("InitPostEntity", "P11.MV.Spawn578", function()
    timer.Simple(1, SpawnMV)
end)
hook.Add("PostCleanupMap", "P11.MV.Spawn578b", function()
    timer.Simple(3, SpawnMV)
end)

print("[POLUS-11] СПАВНЕР MENUV2 v5.7.8: энтити создана — красота меню дойдёт до клиентов")
