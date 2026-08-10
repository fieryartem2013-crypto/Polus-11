-- ============================================================
--  ПОЛЮС-11 — HUD ЖИЗНИ (client) v4.33.0 «ПАТРОН»
--  Полный редизайн по заявке владельца «обнови полностью UI
--  худа»: строгий «советский» стиль станции — тёмная панель
--  с красной звездой и золотой каймой, плавные бары с бликом,
--  аккуратная панель патронов, вспышки урона/лечения, тосты
--  модерации. Сетевой контракт и привязки (P11.VitalsTop,
--  P11.EcoMoneyTop) не тронуты — экономика и мут висят как раньше.
-- ============================================================

surface.CreateFont("P11.Vitals.Big",   { font = "Roboto", size = 26, weight = 800, extended = true })
surface.CreateFont("P11.Vitals.Med",   { font = "Roboto", size = 17, weight = 700, extended = true })
surface.CreateFont("P11.Vitals.Tiny",  { font = "Roboto", size = 12, weight = 600, extended = true })
surface.CreateFont("P11.Vitals.Small", { font = "Roboto", size = 13, weight = 600, extended = true })
surface.CreateFont("P11.Vitals.Ammo",  { font = "Roboto", size = 34, weight = 800, extended = true })
surface.CreateFont("P11.Vitals.Toast", { font = "Roboto", size = 21, weight = 800, extended = true })

P11 = P11 or {}

-- ============ ПЛАВНОСТЬ БАРОВ ============

local curHp, curAr = 100, 0
local curWarm, lastHp       = 100, 100
local dmgFlash, healFlash   = 0, 0

local COL = {
    hpOk   = Color(105, 205, 125),
    hpMid  = Color(235, 185, 80),
    hpBad  = Color(240, 85, 75),
    armor  = Color(95, 160, 230),
    bg     = Color(13, 15, 20, 224),   -- глубже и строже
    bg2    = Color(18, 21, 28, 255),   -- внутренние подложки
    frame  = Color(6, 7, 9, 255),
    text   = Color(238, 240, 246),
    dim    = Color(152, 157, 172),
    gold   = Color(255, 205, 110),
    red    = Color(205, 60, 52),       -- знамя
    redHi  = Color(235, 80, 70),
}

local function HpColor(frac, t)
    local c
    if frac > 0.55 then c = COL.hpOk
    elseif frac > 0.25 then c = COL.hpMid
    else
        c = COL.hpBad
        local p = 0.72 + math.sin(t * 7) * 0.28
        return Color(c.r, c.g, c.b, 160 + 95 * p)
    end
    return c
end

-- плавное смешение цветов (для перехода «ок → плохо» без скачка)
local function MixCol(a, b, k)
    return Color(
        math.floor(a.r + (b.r - a.r) * k),
        math.floor(a.g + (b.g - a.g) * k),
        math.floor(a.b + (b.b - a.b) * k),
        math.floor(a.a + (b.a - a.a) * k))
end

-- бегущий блик по бару (светлый штрих, едет слева направо)
local function BarShine(x, y, w, h, frac, t, speed)
    local ph = (t * (speed or 1.4)) % 1.6 - 0.3
    if ph > -0.2 and ph < 1 then
        local sx = x + ph * w
        surface.SetDrawColor(255, 255, 255, 26)
        surface.DrawRect(sx, y, 10, h)
    end
end

local function DrawBar(x, y, w, h, frac, col, bigTxt, smallTxt, t)
    frac = math.Clamp(frac, 0, 1)
    -- тень-рамка
    draw.RoundedBox(4, x - 2, y - 2, w + 4, h + 4, COL.frame)
    draw.RoundedBox(3, x, y, w, h, COL.bg2)
    if frac > 0.01 then
        local fw = math.max(6, w * frac)
        draw.RoundedBox(3, x, y, fw, h, col)
        -- верхний блик
        surface.SetDrawColor(255, 255, 255, 26)
        surface.DrawRect(x + 1, y + 1, fw - 2, math.floor(h / 2) - 1)
        if t then BarShine(x, y, fw, h, frac, t) end
    end
    -- тонкая золотая насечка по краю бара
    surface.SetDrawColor(COL.gold.r, COL.gold.g, COL.gold.b, 40)
    surface.DrawOutlinedRect(x, y, w, h, 1)
    if bigTxt then
        draw.SimpleTextOutlined(bigTxt, "P11.Vitals.Big", x + 10, y + h / 2, COL.text,
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 180))
    end
    if smallTxt then
        draw.SimpleText(smallTxt, "P11.Vitals.Small", x + w - 8, y + h / 2, Color(240, 242, 248, 220),
            TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
end

-- ============ ГЛАВНАЯ ОТРИСОВКА ============

hook.Add("HUDPaint", "P11.Vitals", function()
    local me = LocalPlayer()
    if not IsValid(me) then return end
    if P11.IntroOpen then return end                       -- во время интро — чистый экран
    if P11B and P11B.open then return end -- под TAB не лезем (v4.2.1: TAB v2)

    local t = CurTime()
    local sw, sh = ScrW(), ScrH()

    local hp  = math.max(0, me:Alive() and me:Health() or 0)
    local mhp = math.max(1, me:GetMaxHealth())
    local ar  = me:Alive() and math.max(0, me:Armor()) or 0

    local ft = math.min(FrameTime() * 6, 1)
    curHp = curHp + (hp - curHp) * ft
    curAr = curAr + (ar - curAr) * ft
    if math.abs(curHp - hp) < 0.4 then curHp = hp end
    if math.abs(curAr - ar) < 0.4 then curAr = ar end

    -- ----- панель слева внизу -----
    local px, py, pw = 16, sh - 118, 272
    draw.RoundedBox(8, px - 8, py - 26, pw + 16, 118, COL.bg)
    P11.VitalsTop = py - 26

    -- v4.33.0: КРАСНОЕ ЗНАМЯ — левая кромка панели
    draw.RoundedBoxEx(8, px - 8, py - 26, 5, 118, COL.red, true, false, true, false)
    -- золотая кайма сверху
    surface.SetDrawColor(COL.gold.r, COL.gold.g, COL.gold.b, 120 + math.sin(t * 1.4) * 30)
    surface.DrawRect(px - 3, py - 26, pw + 11, 1)
    -- тонкая тень под каймой
    for i = 0, 2 do
        surface.SetDrawColor(40, 42, 50, 22 - i * 6)
        surface.DrawRect(px - 3, py - 25 + i, pw + 11, 1)
    end
    -- уголок-плашка знамени
    surface.SetDrawColor(COL.redHi.r, COL.redHi.g, COL.redHi.b, 150)
    surface.DrawRect(px - 8, py - 26, 26, 2)
    surface.DrawRect(px - 8, py - 26, 2, 26)

    local label = me:Alive() and "СОСТОЯНИЕ БОЙЦА" or "ВЫ ПОГИБЛИ — ЖДИТЕ РЕСПАВН"
    local lblCol = me:Alive() and COL.dim or COL.hpBad
    -- звезда у заголовка
    draw.SimpleText("★", "P11.Vitals.Small", px + 2, py - 15, COL.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(label, "P11.Vitals.Small", px + 16, py - 15, lblCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    if not me:Alive() then
        draw.SimpleText("Респавн вернёт снаряжение должности", "P11.Vitals.Small",
            px + 4, py + 10, COL.dim)
        return
    end

    local hpFrac = curHp / mhp
    -- плавная смена цвета здоровья
    local hpCol = HpColor(hpFrac, t)
    if hpFrac > 0.55 and hpFrac < 0.75 then
        hpCol = MixCol(COL.hpMid, COL.hpOk, (hpFrac - 0.55) / 0.2)
    elseif hpFrac > 0.25 and hpFrac < 0.55 then
        hpCol = MixCol(COL.hpBad, COL.hpMid, (hpFrac - 0.25) / 0.3)
    end
    DrawBar(px, py, pw, 26, hpFrac, hpCol,
        math.Round(hp), "ЗДОРОВЬЕ / " .. mhp, t)

    DrawBar(px, py + 34, pw, 16, curAr / 100, COL.armor,
        nil, math.Round(ar) > 0 and ("БРОНЯ  " .. math.Round(ar)) or "БРОНИ НЕТ", t)

    -- ----- v3.7: ТЕПЛО (переохлаждение) -----
    local wm = me:GetNWFloat("P11_Warmth", 100)
    curWarm = curWarm + (wm - curWarm) * ft
    if math.abs(curWarm - wm) < 0.5 then curWarm = wm end
    local warmFrac = math.Clamp(curWarm / 100, 0, 1)
    local warmCol
    if warmFrac > 0.6 then warmCol = Color(120, 190, 235)
    elseif warmFrac > 0.3 then warmCol = Color(150, 210, 245)
    else
        local p = 0.7 + math.sin(t * 8) * 0.3
        warmCol = Color(225, 245, 255, 150 + 105 * p) -- тревожное мигание на морозе
    end
    DrawBar(px, py + 56, pw, 12, warmFrac, warmCol,
        nil, "❄ ТЕПЛО  " .. math.Round(curWarm) .. "%", t)
    if warmFrac <= 0.3 then
        local coldTxt = "ЗАМЕРЗАЕШЬ — К ГЕНЕРАТОРУ!"
        local coldFont = "P11.Vitals.Small"
        surface.SetFont(coldFont)
        if (surface.GetTextSize(coldTxt) or 0) > pw then
            coldFont = "P11.Vitals.Tiny"
        end
        draw.SimpleText(coldTxt, coldFont, px + pw, py + 82,
            Color(235, 245, 255, 200 + 55 * math.sin(t * 8)), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    -- ----- вспышка урона/лечения (красная/зелёная молния слева) -----
    if hp < lastHp - 1 then
        dmgFlash = math.min(1, dmgFlash + (lastHp - hp) / 18)
    elseif hp > lastHp + 2 then
        healFlash = 0.7
    end
    lastHp = hp
    if dmgFlash > 0.003 then
        draw.RoundedBoxEx(8, px - 12, py - 26, 4, 118, Color(240, 70, 60, 230 * dmgFlash), true, false, true, false)
        surface.SetDrawColor(200, 30, 30, 90 * dmgFlash)
        surface.DrawRect(0, 0, sw, 34)
        surface.DrawRect(0, sh - 34, sw, 34)
        dmgFlash = dmgFlash * math.max(0, 1 - FrameTime() * 3.2)
    end
    if healFlash > 0.003 then
        draw.RoundedBoxEx(8, px - 12, py - 26, 4, 118, Color(120, 230, 140, 200 * healFlash), true, false, true, false)
        healFlash = healFlash * math.max(0, 1 - FrameTime() * 3.2)
    end

    -- ----- значок МУТА -----
    if me:GetNWBool("P11FW_Muted", false) then
        local left = me:GetNWInt("P11FW_MuteLeftMin", 0)
        local rs = me:GetNWString("P11FW_MuteReason", "")
        local txt = "МУТ" .. (left > 0 and (" " .. left .. " мин") or "")
            .. (rs ~= "" and (" — " .. rs) or "")
        surface.SetFont("P11.Vitals.Small")
        local tw = surface.GetTextSize(txt)
        local muteTop = (tonumber(P11.EcoMoneyTop) or (py - 88)) - 30
        draw.RoundedBox(5, px - 6, muteTop, tw + 20, 22, Color(60, 42, 12, 230))
        draw.RoundedBoxEx(5, px - 6, muteTop, 4, 22, COL.gold, true, false, true, false)
        draw.SimpleText("🔇 " .. txt, "P11.Vitals.Small", px + 4, muteTop + 11, COL.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- ----- красная виньетка при критическом HP -----
    if hp > 0 and hp <= 25 then
        local k = (1 - hp / 25) * (0.45 + math.sin(t * 5) * 0.18)
        surface.SetDrawColor(200, 30, 30, 130 * k)
        surface.DrawRect(0, 0, sw, 46)
        surface.DrawRect(0, sh - 46, sw, 46)
        surface.DrawRect(0, 0, 46, sh)
        surface.DrawRect(sw - 46, 0, 46, sh)
        if (t % 0.6) < 0.3 then
            draw.SimpleText("★ КРИТИЧЕСКОЕ СОСТОЯНИЕ ★", "P11.Vitals.Med",
                sw / 2, sh * 0.8, Color(255, 90, 80, 180 + 60 * math.sin(t * 6)),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- ----- патроны справа внизу -----
    local wep = me:GetActiveWeapon()
    if IsValid(wep) then
        local clip = wep:Clip1()
        local res = -1
        local atype = wep:GetPrimaryAmmoType()
        if atype and atype > 0 then res = me:GetAmmoCount(atype) end

        if clip >= 0 or res > 0 then
            local name = wep.PrintName or wep:GetClass() or "оружие"
            local bx, by, bw = sw - 236, sh - 96, 220
            draw.RoundedBox(8, bx, by, bw, 88, COL.bg)
            -- знамя: красная кромка справа + золотая кайма
            draw.RoundedBoxEx(8, bx + bw - 5, by, 5, 88, COL.red, false, true, false, true)
            local ag = 130 + math.sin(t * 1.4) * 30
            surface.SetDrawColor(COL.gold.r, COL.gold.g, COL.gold.b, ag)
            surface.DrawRect(bx, by, bw, 1)
            -- мало патронов — красный пульс по контуру
            if clip >= 0 and clip <= math.max(4, (wep:GetMaxClip1() > 0 and wep:GetMaxClip1() or 30) * 0.2) then
                local pp = 0.5 + math.sin(t * 8) * 0.5
                surface.SetDrawColor(240, 90, 80, 60 + 120 * pp)
                surface.DrawOutlinedRect(bx, by, bw, 88, 1)
            end
            draw.SimpleText("★ " .. string.upper(name), "P11.Vitals.Small", bx + bw / 2, by + 10, COL.dim,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            if clip >= 0 then
                draw.SimpleText(tostring(clip), "P11.Vitals.Ammo", bx + bw / 2 - 8, by + 40, COL.text,
                    TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                if res >= 0 then
                    draw.SimpleText("/ " .. res, "P11.Vitals.Med", bx + bw / 2 + 26, by + 44, COL.dim,
                        TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
            elseif res > 0 then
                draw.SimpleText(tostring(res), "P11.Vitals.Ammo", bx + bw / 2, by + 42, COL.text,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            draw.SimpleText("ПАТРОНЫ", "P11.Vitals.Small", bx + bw / 2, by + 74, COL.dim,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end)

-- ============ ТОСТЫ МОДЕРАЦИИ (варн/мут/кик/бан) ============

local TOASTS = {} -- { text=..., kind=..., t0=..., dur=6 }

local TOAST_COLORS = {
    warn = Color(255, 205, 110),
    mute = Color(235, 145, 90),
    kick = Color(240, 105, 95),
    ban  = Color(235, 70, 60),
    info = Color(150, 210, 235),
}

net.Receive("P11FW_ModToast", function()
    local text = net.ReadString()
    local kind = net.ReadString()
    if not TOAST_COLORS[kind] then kind = "info" end
    TOASTS[#TOASTS + 1] = { text = text, kind = kind, t0 = SysTime(), dur = 6.5 }
    if #TOASTS > 3 then table.remove(TOASTS, 1) end

    if kind == "warn" then
        surface.PlaySound("ambient/alarms/warningbell1.wav")
    elseif kind == "kick" or kind == "ban" then
        surface.PlaySound("doors/door_latch3.wav")
    elseif kind == "mute" then
        surface.PlaySound("buttons/button10.wav")
    else
        surface.PlaySound("buttons/button9.wav")
    end
end)

hook.Add("HUDPaint", "P11.Vitals.Toasts", function()
    if #TOASTS == 0 then return end
    local now = SysTime()
    local sw = ScrW()
    local y = ScrH() * 0.30

    for i = #TOASTS, 1, -1 do
        local t = TOASTS[i]
        local el = now - t.t0
        if el >= t.dur then
            table.remove(TOASTS, i)
        else
            local aIn  = math.Clamp(el / 0.25, 0, 1)
            local aOut = math.Clamp((t.dur - el) / 0.7, 0, 1)
            local a = math.min(aIn, aOut)
            local c = TOAST_COLORS[t.kind] or TOAST_COLORS.info

            surface.SetFont("P11.Vitals.Toast")
            local tw = surface.GetTextSize(t.text)
            local bw = tw + 56
            local bx = sw / 2 - bw / 2
            local by = y - aIn * 26 - 26

            draw.RoundedBox(8, bx, by, bw, 52, Color(14, 12, 14, 235 * a))
            -- золотая кайма + цветной корешок
            draw.RoundedBoxEx(8, bx, by, 5, 52, Color(c.r, c.g, c.b, 255 * a), true, false, true, false)
            surface.SetDrawColor(COL.gold.r, COL.gold.g, COL.gold.b, 70 * a)
            surface.DrawOutlinedRect(bx, by, bw, 52, 1)
            draw.SimpleText("★", "P11.Vitals.Small", bx + 14, by + 26, Color(c.r, c.g, c.b, 255 * a),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(t.text, "P11.Vitals.Toast", sw / 2 + 14, by + 26,
                Color(c.r, c.g, c.b, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            y = y + 60
        end
    end
end)
