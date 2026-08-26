-- ============================================================
--  ПОЛЮС-11 — HUD МУТАЦИЙ НЕЧТО (client) v4.2
--  Счётчик жертв, прогресс до следующего тира, список баффов.
-- ============================================================

surface.CreateFont("P11.Mut.Big",   { font = "Roboto", size = 22, weight = 800, extended = true })
surface.CreateFont("P11.Mut.Small", { font = "Roboto", size = 14, weight = 600, extended = true })
surface.CreateFont("P11.Mut.Tiny",  { font = "Roboto", size = 12, weight = 500, extended = true })

local MUTS = {
    { need = 3,  name = "РЕГЕНЕРАЦИЯ", desc = "плоть зарастает, бег +8%" },
    { need = 5,  name = "МЯСОГИГАНТ",  desc = "+60 ХП, когти +10" },
    { need = 10, name = "АРАХНА",      desc = "паучья туша: +20% бег, прыжки" },
}

hook.Add("HUDPaint", "P11.MutationHUD", function()
    local me = LocalPlayer()
    if not IsValid(me) or not me:Alive() then return end
    if not me:GetNWBool("P11_Infected", false) then return end
    if P11B and P11B.open then return end -- v4.2.1: TAB v2 вместо vgui-панели

    local kills = me:GetNWInt("P11_MutKills", 0)
    local tier  = me:GetNWInt("P11_MutTier", 0)

    local w, h = 240, 96 + 22 * #MUTS
    local x, y = ScrW() - w - 20, ScrH() - h - 20

    -- панель телесного роста
    draw.RoundedBox(8, x, y, w, h, Color(22, 8, 10, 200))
    surface.SetDrawColor(160, 50, 55, 170)
    surface.DrawOutlinedRect(x, y, w, h, 1)

    -- v4.14.3 «ЗАРЯД»: эмодзи 🩸 шрифт не тянул (□□) и наезжал на «жертв: N» — чистый текст
    draw.SimpleText("МУТАЦИИ ТВАРИ", "P11.Mut.Big", x + 12, y + 10,
        Color(255, 120, 115), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText("жертв: " .. kills, "P11.Mut.Small", x + w - 12, y + 14,
        Color(220, 180, 180), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    -- прогресс до следующего тира
    local nextNeed = nil
    for _, m in ipairs(MUTS) do
        if kills < m.need then nextNeed = m.need break end
    end
    if nextNeed then
        local prev = (nextNeed == 3 and 0) or (nextNeed == 5 and 3) or 5
        local frac = math.Clamp((kills - prev) / (nextNeed - prev), 0, 1)
        draw.RoundedBox(4, x + 12, y + 42, w - 24, 12, Color(50, 22, 24, 230))
        draw.RoundedBox(4, x + 12, y + 42, (w - 24) * frac, 12, Color(200, 60, 60, 230))
        draw.SimpleText("до мутации: " .. kills .. "/" .. nextNeed, "P11.Mut.Tiny",
            x + w / 2, y + 48, Color(240, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
        draw.SimpleText("ПИК ЭВОЛЮЦИИ", "P11.Mut.Small", x + w / 2, y + 44,
            Color(255, 150, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- перечень мутаций
    local unlocked = 0
    for i, m in ipairs(MUTS) do
        local got = kills >= m.need
        if got then unlocked = unlocked + 1 end
        local yy = y + 66 + (i - 1) * 22
        draw.SimpleText((got and "✔ " or "○ ") .. m.name .. " (" .. m.need .. ")",
            "P11.Mut.Small", x + 12, yy,
            got and Color(255, 140, 130) or Color(130, 95, 95), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        if got then
            draw.SimpleText(m.desc, "P11.Mut.Tiny", x + w - 12, yy + 2,
                Color(190, 150, 150), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end
    end

    if tier > 0 then
        draw.SimpleText("тир: " .. tier .. "/3", "P11.Mut.Tiny", x + 12, y + h - 20,
            Color(255, 180, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    -- v4.2.1: чья личина надета (имя + документ жертвы)
    local fake = me:GetNWString("P11_FakeNick", "")
    if fake ~= "" then
        local docc = me:GetNWString("P11_DocCode", "")
        draw.SimpleText("личина: " .. fake .. (docc ~= "" and (" · " .. docc) or ""), "P11.Mut.Tiny",
            x + w - 12, y + h - 20, Color(205, 175, 175), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    end
end)

print("[POLUS-11] HUD мутаций загружен")


-- ============================================================
--  v4.8.3 «ПОГЛОЩЕНИЕ»: МЕНЮ МУТАЦИЙ НА R (реворк Нечто)
--  R без трупа под прицелом → это окно:
--   • прогресс мутаций и список тиров;
--   • кнопки: СНЯТЬ ЛИЧИНУ / МАСКИРОВКА / ПАУЧЬЯ ФОРМА;
--   • смена формы кнопками (раньше — только чатом !форма);
--   • способность ПКМ текущей формы + шпаргалка управления.
-- ============================================================

surface.CreateFont("P11.MutM.Title", { font = "Roboto", size = 22, weight = 800, extended = true })
surface.CreateFont("P11.MutM.Text",  { font = "Roboto", size = 16, weight = 600, extended = true })
surface.CreateFont("P11.MutM.Small", { font = "Roboto", size = 14, weight = 500, extended = true })

local MUTMC = {
    bg    = Color(16, 6, 8, 246),
    panel = Color(30, 12, 14, 255),
    red   = Color(255, 110, 105),
    dim   = Color(190, 150, 150),
    text  = Color(240, 225, 225),
    gold  = Color(255, 190, 110),
    ok    = Color(140, 230, 150),
}

local FORM_INFO = {
    imitator = { name = "Имитатор",    pkm = "ПКМ — тихий укол заражения (90 сек)" },
    brute    = { name = "Поглотитель", pkm = "ПКМ — бросок массы плоти (18 сек)" },
    spore    = { name = "Споровик",    pkm = "ПКМ — облако спор (18 сек)" },
    split    = { name = "Разделённый", pkm = "ПКМ — кислотный плевок (2 сек)" },
}
local FORM_ORDER = { "imitator", "brute", "spore", "split" }

local THING_WEPS = {
    weapon_polus11_thing = true, weapon_polus11_thing_brute = true,
    weapon_polus11_thing_spore = true, weapon_polus11_thing_split = true,
}

local function ThingSend(act, arg)
    net.Start("P11_ThingAct")
        net.WriteString(act)
        if act == "form" then net.WriteString(arg or "") end
    net.SendToServer()
end

function P11.OpenThingMenu()
    local me = LocalPlayer()
    if not IsValid(me) then return end
    P11.ThingMenuAt = P11.ThingMenuAt or 0
    if CurTime() < P11.ThingMenuAt then return end -- анти-дубль (Reload + клавиша)
    P11.ThingMenuAt = CurTime() + 0.25
    if IsValid(P11.ThingMenu) then P11.ThingMenu:Remove() end

    local kills = me:GetNWInt("P11_MutKills", 0)
    local tier  = me:GetNWInt("P11_MutTier", 0)
    local formId = me:GetNWString("P11_ThingForm", "imitator")
    local finfo = FORM_INFO[formId] or FORM_INFO.imitator
    local fake = me:GetNWString("P11_FakeNick", "")
    local masked = me:GetNWBool("P11_Revealed", false) ~= true

    local f = vgui.Create("DFrame")
    P11.ThingMenu = f
    f:SetSize(520, 528)
    f:Center()
    f:SetTitle("")
    f:SetDraggable(true)
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.OnRemove = function() if P11.ThingMenu == f then P11.ThingMenu = nil end end

    -- прогресс до следующего тира
    local nextNeed, prevNeed = nil, 0
    for _, m in ipairs(MUTS) do
        if kills < m.need then nextNeed = m.need break end
        prevNeed = m.need
    end

    f.Paint = function(s, w, h)
        if P11.DrawDim then P11.DrawDim(s, 120) end
        draw.RoundedBox(10, 0, 0, w, h, MUTMC.bg)
        draw.RoundedBoxEx(10, 0, 0, w, 56, MUTMC.panel, true, true, false, false)
        surface.SetDrawColor(170, 45, 50, 180)
        surface.DrawRect(0, 56, w, 1)
        draw.SimpleText("🩸 НЕЧТО — МЕНЮ МУТАЦИЙ", "P11.MutM.Title", 14, 18, MUTMC.red, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("форма: " .. finfo.name .. "  •  жертв: " .. kills .. "  •  тир: " .. tier .. "/3",
            "P11.MutM.Small", 14, 40, MUTMC.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        -- прогресс-бар мутаций
        local bx, by, bw = 14, 66, w - 28
        draw.RoundedBox(5, bx, by, bw, 16, Color(45, 18, 20, 255))
        if nextNeed then
            local frac = math.Clamp((kills - prevNeed) / (nextNeed - prevNeed), 0, 1)
            draw.RoundedBox(5, bx, by, bw * frac, 16, Color(190, 45, 48, 230))
            draw.SimpleText("до следующей мутации: " .. kills .. "/" .. nextNeed, "P11.MutM.Small",
                bx + bw / 2, by + 8, MUTMC.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            draw.RoundedBox(5, bx, by, bw, 16, Color(90, 40, 22, 255))
            draw.SimpleText("ПИК ЭВОЛЮЦИИ — все мутации открыты", "P11.MutM.Small",
                bx + bw / 2, by + 8, MUTMC.gold, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    local xb = vgui.Create("DButton", f)
    xb:SetPos(520 - 34, 8) xb:SetSize(24, 22)
    xb:SetText("")
    xb.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(120, 40, 36) or Color(60, 30, 28))
        draw.SimpleText("✕", "P11.MutM.Small", w / 2, h / 2 - 1, Color(240, 200, 195), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    xb.DoClick = function() surface.PlaySound("buttons/button10.wav") f:Remove() end

    -- ---------- тиры мутаций ----------
    local y = 92
    for i, m in ipairs(MUTS) do
        local got = kills >= m.need
        local card = vgui.Create("DPanel", f)
        card:SetPos(14, y) card:SetSize(492, 40)
        card.Paint = function(s, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(24, 10, 12, 255))
            draw.RoundedBoxEx(6, 0, 0, 4, h, got and Color(170, 45, 50) or Color(70, 32, 36), true, false, true, false)
            draw.SimpleText((got and "✔ " or "○ ") .. m.name .. "  (" .. m.need .. " жертв)",
                "P11.MutM.Text", 12, 11, got and MUTMC.red or MUTMC.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(m.desc, "P11.MutM.Small", 12, 29, got and MUTMC.text or Color(150, 115, 115), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        y = y + 46
    end

    -- ---------- кнопки действий ----------
    local function ABtn(x, yy, w2, name, col, fn, enabled)
        local b = vgui.Create("DButton", f)
        b:SetPos(x, yy) b:SetSize(w2, 32)
        b:SetText("")
        b.On = enabled ~= false
        b.Paint = function(s, w, h)
            local a = s.On and (s:IsHovered() and 70 or 40) or 16
            draw.RoundedBox(6, 0, 0, w, h, Color(col.r, col.g, col.b, a))
            surface.SetDrawColor(col.r, col.g, col.b, s.On and 170 or 60)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(name, "P11.MutM.Small", w / 2, h / 2, s.On and col or MUTMC.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function()
            if not b.On then surface.PlaySound("buttons/button10.wav") return end
            surface.PlaySound("buttons/button9.wav")
            fn()
        end
        return b
    end

    local actY = y + 4
    -- личина
    if fake ~= "" then
        ABtn(14, actY, 246, "👤 СНЯТЬ ЛИЧИНУ («" .. fake .. "»)", MUTMC.gold, function()
            ThingSend("unmask") f:Remove()
        end)
    else
        ABtn(14, actY, 246, "👤 личины нет — съешь труп (когти/R по трупу)", MUTMC.dim, function() end, false)
    end
    -- маскировка (для Разделённого — паучья форма)
    if formId == "split" then
        ABtn(268, actY, 238, "🕷 ПАУЧЬЯ ФОРМА (вкл/выкл)", MUTMC.red, function()
            ThingSend("spider") f:Remove()
        end)
    else
        ABtn(268, actY, 238, masked and "👁 ЯВИТЬ ФОРМУ МОНСТРА" or "🫥 СПРЯТАТЬ ФОРМУ (человек)", MUTMC.red, function()
            ThingSend("mask") f:Remove()
        end)
    end

    -- ---------- формы ----------
    local fY = actY + 44
    local lbl = vgui.Create("DLabel", f)
    lbl:SetPos(14, fY) lbl:SetSize(492, 18)
    lbl:SetFont("P11.MutM.Small") lbl:SetTextColor(MUTMC.gold)
    local cd = math.max(0, me:GetNWFloat("P11_FormCd", 0) - CurTime())
    lbl:SetText("СМЕНА ФОРМЫ" .. (cd > 0 and ("  — перезарядка " .. math.ceil(cd) .. " сек") or ":"))

    fY = fY + 22
    local fw = 119
    for i, fid in ipairs(FORM_ORDER) do
        local fi = FORM_INFO[fid]
        local cur = (fid == formId)
        local b = ABtn(14 + (i - 1) * (fw + 5), fY, fw, (cur and "• " or "") .. fi.name .. (cur and " •" or ""),
            cur and MUTMC.ok or MUTMC.text, function()
                ThingSend("form", fid)
                timer.Simple(0.4, function() if IsValid(f) then f:Remove() end end)
            end, not cur and cd <= 0)
        b:SetTall(36)
    end

    -- ---------- способность ПКМ + шпаргалка ----------
    local hY = fY + 46
    local info = vgui.Create("DLabel", f)
    info:SetPos(14, hY) info:SetSize(492, 66)
    info:SetFont("P11.MutM.Small") info:SetTextColor(MUTMC.text)
    info:SetAutoStretchVertical(true)
    info:SetText("🧬 " .. finfo.pkm .. "\n" ..
        "ЛКМ — когти: убитая цель СЪЕДАЕТСЯ САМА (личина жертвы на тебе).\n" ..
        "R по трупу — доесть вручную • R — это меню • !крик — ужас • !разрыв — споры-разрыв")
    info:SetTextColor(MUTMC.dim)

    f.OnKeyCodePressed = function(s, key)
        if key == KEY_ESCAPE then f:Remove() end
    end
    if P11.AnimateIn then P11.AnimateIn(f) end
    return f
end

-- страховка клавиши R (как у рации): если SWEP:Reload задавлен
-- связкой клиента — ловим саму клавишу. Труп под прицелом →
-- меню НЕ зовём (сработает съедение на сервере).
hook.Add("PlayerButtonDown", "P11.ThingMenuR", function(ply, btn)
    if ply ~= LocalPlayer() or btn ~= KEY_R then return end
    if not ply:GetNWBool("P11_Infected", false)
        or not ply:GetNWBool("P11_InfActive", false) then return end
    local wep = ply:GetActiveWeapon()
    if not (IsValid(wep) and THING_WEPS[wep:GetClass()]) then return end

    -- съедобный труп в прицеле? — отдаём R серверу (съесть)
    local tr = util.TraceHull({
        start  = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * 220,
        mins   = Vector(-28, -28, -10),
        maxs   = Vector(28, 28, 28),
        filter = {ply, wep},
    })
    local e = tr.Entity
    if IsValid(e) and e:GetNWString("P11_CorpseName", "") ~= "" then return end

    P11.OpenThingMenu()
end)

print("[POLUS-11] меню мутаций v4.8.3 «ПОГЛОЩЕНИЕ» загружено (R у Нечто)")
