-- ============================================================
--  ПОЛЮС-11 — HUD ЖИЗНИ (client) v3.4
--  Заменяет скрытый стоковый HL2-HUD:
--   • слева внизу — панель ЗДОРОВЬЯ и БРОНИ (плавные бары,
--     пульс при критическом HP, красная виньетка при ранении);
--   • справа внизу — ПАТРОНЫ активного оружия;
--   • значок МУТА над панелью жизни;
--   • большие ТОСТЫ модерации (варн/мут/кик/бан) по центру.
-- ============================================================

surface.CreateFont("P11.Vitals.Big",   { font = "Roboto", size = 26, weight = 800, extended = true })
surface.CreateFont("P11.Vitals.Med",   { font = "Roboto", size = 17, weight = 700, extended = true })
surface.CreateFont("P11.Vitals.Small", { font = "Roboto", size = 13, weight = 600, extended = true })
surface.CreateFont("P11.Vitals.Ammo",  { font = "Roboto", size = 34, weight = 800, extended = true })
surface.CreateFont("P11.Vitals.Toast", { font = "Roboto", size = 21, weight = 800, extended = true })

P11 = P11 or {}

-- ============ ПЛАВНОСТЬ БАРОВ ============

local curHp, curAr = 100, 0
-- v3.8.2 КРИТ-ФИКС: эти счётчики были «голыми» глобалами (local забыт) —
-- curWarm был nil, строка 111 «число + nil» крашилась КАЖДЫЙ КАДР (xБЕСКОНЕЧНО),
-- а до lastHp/dmgFlash/healFlash дело просто не доходило из-за падения выше.
local curWarm, lastHp       = 100, 100
local dmgFlash, healFlash   = 0, 0

local COL = {
    hpOk   = Color(105, 205, 125),
    hpMid  = Color(235, 185, 80),
    hpBad  = Color(240, 85, 75),
    armor  = Color(95, 160, 230),
    bg     = Color(16, 18, 24, 215),
    frame  = Color(8, 9, 12, 255),
    text   = Color(235, 238, 245),
    dim    = Color(150, 155, 170),
    gold   = Color(255, 205, 110),
}

local function HpColor(frac, t)
    local c
    if frac > 0.55 then c = COL.hpOk
    elseif frac > 0.25 then c = COL.hpMid
    else
        c = COL.hpBad
        -- пульс на критическом
        local p = 0.72 + math.sin(t * 7) * 0.28
        return Color(c.r, c.g, c.b, 160 + 95 * p)
    end
    return c
end

local function DrawBar(x, y, w, h, frac, col, bigTxt, smallTxt)
    frac = math.Clamp(frac, 0, 1)
    draw.RoundedBox(4, x - 2, y - 2, w + 4, h + 4, COL.frame)
    draw.RoundedBox(3, x, y, w, h, Color(30, 33, 42, 255))
    if frac > 0.01 then
        draw.RoundedBox(3, x, y, math.max(6, w * frac), h, col)
        -- блик сверху
        surface.SetDrawColor(255, 255, 255, 22)
        surface.DrawRect(x + 1, y + 1, math.max(4, w * frac) - 2, math.floor(h / 2) - 1)
    end
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
    -- v4.2.2: верх панели — точка привязки для «золотого кошелька» (экономика)
    P11.VitalsTop = py - 26

    -- v4.2.2: морозный глянец — тонкая ледяная кромка сверху + шапка-градиент
    local tGlow = 130 + math.sin(t * 1.4) * 30
    surface.SetDrawColor(120, 190, 230, tGlow)
    surface.DrawRect(px - 8, py - 26, pw + 16, 1)
    for i = 0, 3 do
        surface.SetDrawColor(40, 60, 78, 26 - i * 5)
        surface.DrawRect(px - 8, py - 25 + i, pw + 16, 1)
    end
    -- уголок-платка панели (ледяной штрих)
    surface.SetDrawColor(150, 215, 245, 90)
    surface.DrawRect(px - 8, py - 26, 26, 2)
    surface.DrawRect(px - 8, py - 26, 2, 26)

    local label = me:Alive() and "СОСТОЯНИЕ БОЙЦА" or "ВЫ ПОГИБЛИ — ЖДИТЕ РЕСПАВН"
    draw.SimpleText(label, "P11.Vitals.Small", px + 4, py - 16,
        me:Alive() and COL.dim or COL.hpBad)

    if not me:Alive() then
        draw.SimpleText("Респавн вернёт снаряжение должности", "P11.Vitals.Small",
            px + 4, py + 10, COL.dim)
        return
    end

    DrawBar(px, py, pw, 26, curHp / mhp, HpColor(curHp / mhp, t),
        math.Round(hp), "ЗДОРОВЬЕ / " .. mhp)

    DrawBar(px, py + 34, pw, 16, curAr / 100, COL.armor,
        nil, math.Round(ar) > 0 and ("БРОНЯ  " .. math.Round(ar)) or "БРОНИ НЕТ")

    -- ----- v3.7: ТЕПЛО (переохлаждение) -----
    local wm = me:GetNWFloat("P11_Warmth", 100)
    curWarm = curWarm + (wm - curWarm) * ft
    if math.abs(curWarm - wm) < 0.5 then curWarm = wm end
    -- показываем всегда, но бледно, когда тепло полное (для инфы)
    local warmFrac = math.Clamp(curWarm / 100, 0, 1)
    local warmCol
    if warmFrac > 0.6 then warmCol = Color(120, 190, 235)
    elseif warmFrac > 0.3 then warmCol = Color(150, 210, 245)
    else
        local p = 0.7 + math.sin(t * 8) * 0.3
        warmCol = Color(225, 245, 255, 150 + 105 * p) -- тревожное мигание на морозе
    end
    DrawBar(px, py + 56, pw, 12, warmFrac, warmCol,
        nil, "❄ ТЕПЛО  " .. math.Round(curWarm) .. "%")
    if warmFrac <= 0.3 then
        draw.SimpleText("ЗАМЕРЗАЕШЬ — К ГЕНЕРАТОРУ!", "P11.Vitals.Small", px + pw, py + 62,
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
        -- v4.2.2: выше «золотого кошелька» (тот висит над панелью жизни)
        local muteTop = (tonumber(P11.EcoMoneyTop) or (py - 88)) - 30
        draw.RoundedBox(5, px - 6, muteTop, tw + 20, 22, Color(60, 42, 12, 230))
        draw.SimpleText(txt, "P11.Vitals.Small", px + 4, muteTop + 11, COL.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
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
            draw.SimpleText("КРИТИЧЕСКОЕ СОСТОЯНИЕ", "P11.Vitals.Med",
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
            -- v4.2.2: ледяная кромка и уголок, как у панели жизни
            local ag = 130 + math.sin(t * 1.4) * 30
            surface.SetDrawColor(120, 190, 230, ag)
            surface.DrawRect(bx, by, bw, 1)
            surface.SetDrawColor(150, 215, 245, 90)
            surface.DrawRect(bx + bw - 26, by, 26, 2)
            surface.DrawRect(bx + bw - 2, by, 2, 26)
            -- мало патронов — красный пульс по контуру
            if clip >= 0 and clip <= math.max(4, (wep:GetMaxClip1() > 0 and wep:GetMaxClip1() or 30) * 0.2) then
                local pp = 0.5 + math.sin(t * 8) * 0.5
                surface.SetDrawColor(240, 90, 80, 60 + 120 * pp)
                surface.DrawOutlinedRect(bx, by, bw, 88, 1)
            end
            draw.SimpleText(string.upper(name), "P11.Vitals.Small", bx + bw / 2, by + 10, COL.dim,
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

    -- звук по типу
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
            -- появление + затухание
            local aIn  = math.Clamp(el / 0.25, 0, 1)
            local aOut = math.Clamp((t.dur - el) / 0.7, 0, 1)
            local a = math.min(aIn, aOut)
            local c = TOAST_COLORS[t.kind] or TOAST_COLORS.info

            surface.SetFont("P11.Vitals.Toast")
            local tw = surface.GetTextSize(t.text)
            local bw = tw + 46
            local bx = sw / 2 - bw / 2
            local by = y - aIn * 26 - 26

            draw.RoundedBox(8, bx, by, bw, 52, Color(14, 12, 14, 235 * a))
            draw.RoundedBoxEx(8, bx, by, 5, 52, Color(c.r, c.g, c.b, 255 * a), true, false, true, false)
            draw.SimpleText(t.text, "P11.Vitals.Toast", sw / 2 + 12, by + 26,
                Color(c.r, c.g, c.b, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            y = y + 60
        end
    end
end)
