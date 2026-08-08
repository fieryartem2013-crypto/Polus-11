-- ============================================================
--  ПОЛЮС-11 — РАССУДОК: ХОРРОР-СЛОЙ (client) v4.19.4 «ПОЧЁТ»
--  Весь ужас живёт ТОЛЬКО у клиента (из аналитики: «темнота +
--  одиночество + трупы → ложные скрипы/шаги/мимолётные силуэты
--  ТОЛЬКО клиенту» — почти бесплатно для сервера):
--   • индикатор «РАССУДОК» у левого края (виден, если < 95);
--   • <55: виньетка по краям; <40: ложные скрипы/шаги и
--     мимолётный СИЛУЭТ на периферии; <25: глухой стук сердца.
--  Отключить эффекты себе: p11_sanityfx 0 (клиентский конвар).
-- ============================================================

surface.CreateFont("P11.San.Bar",  { font = "Roboto", size = 13, weight = 700, extended = true })
surface.CreateFont("P11.San.Tiny", { font = "Roboto", size = 11, weight = 500, extended = true })

local SAN_FX = CreateClientConVar("p11_sanityfx", "1", true, false)

local COL_BG   = Color(10, 14, 20, 190)
local COL_TEXT = Color(232, 238, 245)
local COL_DIM  = Color(150, 158, 172)

local function MySanity()
    local me = LocalPlayer()
    if not IsValid(me) then return 100 end
    return me:GetNWFloat("P11_Sanity", 100)
end

local function SanityColor(v)
    if v >= 55 then return Color(150, 190, 235) end
    if v >= 25 then return Color(255, 190, 110) end
    return Color(240, 100, 90)
end

-- ============ ИНДИКАТОР ============

hook.Add("HUDPaint", "P11.SanityBar", function()
    if P11B and P11B.open then return end
    local me = LocalPlayer()
    if not IsValid(me) or not me:Alive() then return end
    local s = MySanity()
    if s >= 95 then return end -- здоровым чистый HUD

    local x, y = 14, math.floor(ScrH() * 0.52)
    local w, h = 132, 30
    draw.RoundedBox(6, x, y, w, h, COL_BG)
    local col = SanityColor(s)
    surface.SetDrawColor(col.r, col.g, col.b, 170)
    surface.DrawOutlinedRect(x, y, w, h, 1)
    draw.SimpleText("РАССУДОК", "P11.San.Tiny", x + 8, y + 7, COL_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    local bw = math.floor((w - 16) * math.Clamp(s / 100, 0, 1))
    if bw > 0 then
        draw.RoundedBox(3, x + 8, y + 15, bw, 9, col)
    end
    draw.SimpleText(math.floor(s) .. "", "P11.San.Bar", x + w - 8, y + 19, col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end)

-- ============ ВИНЬЕТКА (темнеют края мира) ============

hook.Add("HUDPaint", "P11.SanityVignette", function()
    if not SAN_FX:GetBool() then return end
    local me = LocalPlayer()
    if not IsValid(me) or not me:Alive() then return end
    local s = MySanity()
    if s >= 55 then return end

    local depth = (55 - s) / 55 -- 0..1
    local pulse = 0.85 + math.sin(CurTime() * 2.2) * 0.15
    local a = math.floor(120 * depth * pulse)
    if a <= 0 then return end
    local wScr, hScr = ScrW(), ScrH()
    local side = math.floor(wScr * 0.16)
    for i = 0, 5 do
        local aa = a * (1 - i / 6)
        surface.SetDrawColor(0, 0, 0, aa)
        surface.DrawRect(0, 0, side - i * (side / 6), hScr)
        surface.DrawRect(wScr - side + i * (side / 6), 0, side - i * (side / 6), hScr)
        surface.DrawRect(0, 0, wScr, side / 2 - i * (side / 12))
        surface.DrawRect(0, hScr - side / 2 + i * (side / 12), wScr, side / 2 - i * (side / 12))
    end
end)

-- ============ ЛОЖНЫЕ ЗВУКИ (скрипы / шаги / стоны — только мне) ============

local CREAKS = {
    "doors/door_squeek1.wav",
    "doors/door_squeek9.wav",
    "ambient/creatures/town_moan1.wav",
    "ambient/creatures/town_zombie_call1.wav",
}
local STEPS = {
    "npc/footsteps/hardboot_generic1.wav",
    "npc/footsteps/hardboot_generic2.wav",
    "npc/footsteps/hardboot_generic4.wav",
}

timer.Create("P11.SanitySounds", 3, 0, function()
    if not SAN_FX:GetBool() then return end
    local me = LocalPlayer()
    if not IsValid(me) or not me:Alive() then return end
    local s = MySanity()
    if s >= 40 then return end

    me.P11_SanNextSnd = me.P11_SanNextSnd or (CurTime() + math.Rand(14, 40))
    if CurTime() < me.P11_SanNextSnd then return end
    me.P11_SanNextSnd = CurTime() + math.Rand(18, 46)

    local roll = math.random()
    if roll < 0.45 then
        -- шаги: короткая дорожка «за спиной» (3-5 шагов)
        local n = math.random(3, 5)
        for i = 0, n - 1 do
            timer.Simple(i * 0.42, function()
                if IsValid(me) then
                    surface.PlaySound(STEPS[math.random(#STEPS)])
                end
            end)
        end
    else
        surface.PlaySound(CREAKS[math.random(#CREAKS)])
    end
end)

-- ============ МИМОЛЁТНЫЙ СИЛУЭТ (клиентский фантом, живёт <1 сек) ============

local phantom = nil

local function SpawnPhantom()
    local me = LocalPlayer()
    if not IsValid(me) then return end
    local fwd = me:GetAimVector():Angle()
    -- на периферии: 70..140 градусов от взгляда
    fwd:RotateAroundAxis(Vector(0, 0, 1), math.random(0, 1) == 0 and math.random(70, 140) or -math.random(70, 140))
    local dir = fwd:Forward()
    local dist = math.Rand(650, 1050)
    local pos = me:GetPos() + dir * dist
    local tr = util.TraceLine({
        start  = pos + Vector(0, 0, 90),
        endpos = pos - Vector(0, 0, 250),
        filter = me,
    })
    if not tr.Hit then return end -- пустота под ногами — фантом не встаёт
    pos = tr.HitPos

    local mdl = (math.random(0, 1) == 0)
        and "models/humans/group01/male_02.mdl"
        or "models/humans/group01/female_01.mdl"
    local m = ClientsideModel(mdl, RENDERGROUP_OPAQUE)
    if not IsValid(m) then return end
    m:SetPos(pos)
    m:SetAngles(Angle(0, (me:GetPos() - pos):Angle().y, 0))
    m:SetColor(Color(8, 8, 12, 235))
    m:Spawn()
    phantom = { ent = m, die = CurTime() + math.Rand(0.35, 0.8) }
end

timer.Create("P11.SanityPhantom", 2.5, 0, function()
    -- фантома пора забрать?
    if phantom then
        if not IsValid(phantom.ent) or CurTime() > phantom.die then
            if IsValid(phantom.ent) then phantom.ent:Remove() end
            phantom = nil
        end
    end

    if not SAN_FX:GetBool() then return end
    local me = LocalPlayer()
    if not IsValid(me) or not me:Alive() then return end
    local s = MySanity()
    if s >= 40 then return end
    if phantom then return end

    me.P11_SanNextPh = me.P11_SanNextPh or (CurTime() + math.Rand(40, 90))
    if CurTime() < me.P11_SanNextPh then return end
    me.P11_SanNextPh = CurTime() + math.Rand(45, 110)

    local ok = pcall(SpawnPhantom)
    if not ok and phantom then phantom = nil end
end)

-- при чистке мира фантом тоже уходит
hook.Add("PreCleanupMap", "P11.SanityPhantomOff", function()
    if phantom and IsValid(phantom.ent) then phantom.ent:Remove() end
    phantom = nil
end)

-- ============ СТУК СЕРДЦА (<25) ============

timer.Create("P11.SanityHeart", 1.05, 0, function()
    if not SAN_FX:GetBool() then return end
    local me = LocalPlayer()
    if not IsValid(me) or not me:Alive() then return end
    if MySanity() >= 25 then return end
    me:EmitSound("physics/flesh/flesh_impact_hard1.wav", 70, 62)
end)

print("[POLUS-11] рассудок (client): индикатор, виньетка, ложные звуки, фантом, сердце; p11_sanityfx 0 выкл")
