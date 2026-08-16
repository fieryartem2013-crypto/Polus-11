-- ============================================================
--  ПОЛЮС-11 — СПАВНЕР ЭНТИТИ ABOUT v5.8.7 (server, autorun)
--  Спавнит невидимую энтити polus_p11_about под картой → её
--  cl_init.lua (кнопка «О НАС» в С-меню, окно «Проект Арчи»,
--  Discord + коллекция) гарантированно уходит клиентам
--  (энтити раздаются всегда, не зависят от sv_allowcslua).
-- ============================================================

local function SpawnAbout()
    if ents.FindByClass("polus_p11_about")[1] then return end
    local e = ents.Create("polus_p11_about")
    if IsValid(e) then
        e:SetPos(Vector(0, 0, -20000))
        e:Spawn()
    end
end

hook.Add("InitPostEntity", "P11.About.Spawn587", function()
    timer.Simple(1, SpawnAbout)
end)
hook.Add("PostCleanupMap", "P11.About.Spawn587b", function()
    timer.Simple(3, SpawnAbout)
end)

print("[POLUS-11] СПАВНЕР ABOUT v5.8.7: энтити создана — «О НАС» дойдёт до клиентов")
