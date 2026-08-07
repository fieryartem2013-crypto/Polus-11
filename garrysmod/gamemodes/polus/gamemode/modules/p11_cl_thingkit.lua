-- ============================================================
--  ПОЛЮС-11 — НЕЧТО «ЛИЧИНА 3.0»: ПУЛЬТ ТЕЛА (client)
--  v4.10.0 «ГАРАЖ». Меню мутаций переписано начисто (заявка
--  «нечто не может маскироваться… меню мутаций»).
--  Открывается клавишей R у когтей любой формы: функция
--  P11.OpenThingMenu ПОДМЕНЕНА этой (старое меню выключено),
--  а R по трупу по-прежнему ЕСТ труп (сервер сам решит).
--  Канал кнопок: P11_TKit (маскировка/личина/форма/паучья/диаг).
-- ============================================================

surface.CreateFont("P11TK.Title", { font = "Roboto", size = 22, weight = 800, extended = true })
surface.CreateFont("P11TK.Text",  { font = "Roboto", size = 16, weight = 600, extended = true })
surface.CreateFont("P11TK.Small", { font = "Roboto", size = 13, weight = 500, extended = true })

local C = {
    bg    = Color(16, 6, 8, 246),
    panel = Color(30, 12, 14, 255),
    red   = Color(255, 110, 105),
    dim   = Color(190, 150, 150),
    text  = Color(240, 225, 225),
    gold  = Color(255, 190, 110),
    ok    = Color(140, 230, 150),
    line  = Color(170, 45, 50),
}

P11TK = P11TK or { Frame = nil }

local FORM_INFO = {
    imitator = { name = "Имитатор",    pkm = "ПКМ — тихий укол заражения (90 сек)" },
    brute    = { name = "Поглотитель", pkm = "ПКМ — бросок массы плоти (18 сек)" },
    spore    = { name = "Споровик",    pkm = "ПКМ — облако спор (18 сек)" },
    split    = { name = "Разделённый", pkm = "ПКМ — кислотный плевок (2 сек)" },
}
local FORM_ORDER = { "imitator", "brute", "spore", "split" }

local MUTS = {
    { need = 3,  name = "РЕГЕНЕРАЦИЯ" },
    { need = 5,  name = "МЯСОГИГАНТ" },
    { need = 10, name = "АРАХНА" },
}

local function Send(act, arg)
    net.Start("P11_TKit")
        net.WriteString(act)
        if act == "form" then net.WriteString(arg or "") end
    net.SendToServer()
end

local function OpenThingKit()
    local me = LocalPlayer()
    if not IsValid(me) then return end
    P11TK.AntiDup = P11TK.AntiDup or 0
    if CurTime() < P11TK.AntiDup then return end
    P11TK.AntiDup = CurTime() + 0.25

    if IsValid(P11TK.Frame) then P11TK.Frame:Remove() end

    local isInf = me:GetNWBool("P11_Infected", false)
    local isAct = me:GetNWBool("P11_InfActive", false)
    local kills = me:GetNWInt("P11_MutKills", 0)
    local tier  = me:GetNWInt("P11_MutTier", 0)
    local formId = me:GetNWString("P11_ThingForm", "imitator")
    local finfo = FORM_INFO[formId] or FORM_INFO.imitator
    local fake = me:GetNWString("P11_FakeNick", "")
    local revealed = me:GetNWBool("P11_Revealed", false)
    local formCd = math.max(0, me:GetNWFloat("P11_FormCd", 0) - CurTime())

    local W, H = 540, 560
    local f = vgui.Create("DFrame")
    P11TK.Frame = f
    f:SetSize(W, H)
    f:Center()
    f:SetTitle("")
    f:SetDraggable(true)
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false)
    f.OnRemove = function() if P11TK.Frame == f then P11TK.Frame = nil end end
    f.OnKeyCodePressed = function(_, key) if key == KEY_ESCAPE then f:Remove() end end

    f.Paint = function(s2, w, h)
        if P11.DrawDim then P11.DrawDim(s2, 120) else Derma_DrawBackgroundBlur(s2, SysTime()) end
        draw.RoundedBox(10, 0, 0, w, h, C.bg)
        draw.RoundedBoxEx(10, 0, 0, w, 58, C.panel, true, true, false, false)
        surface.SetDrawColor(C.line.r, C.line.g, C.line.b, 180)
        surface.DrawRect(0, 58, w, 1)
        draw.SimpleText("🩸 ПУЛЬТ ТЕЛА НЕЧТО — «ЛИЧИНА 3.0»", "P11TK.Title", 16, 18, C.red, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if isAct then
            draw.SimpleText("форма: " .. finfo.name .. " • жертв: " .. kills .. " • тир: " .. tier .. "/3 • " ..
                (revealed and "МОНСТР ЯВЛЕН" or "вид: человек"), "P11TK.Small", 16, 42, C.dim)
        else
            draw.SimpleText(isInf and "инкубация ещё идёт — дыши ровно…" or "ты не Нечто (вакансия у кадровика / укол твари)",
                "P11TK.Small", 16, 42, C.dim)
        end
    end

    local xb = vgui.Create("DButton", f)
    xb:SetPos(W - 36, 10) xb:SetSize(24, 22) xb:SetText("")
    xb.Paint = function(s2, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s2:IsHovered() and Color(120, 40, 36) or Color(60, 30, 28))
        draw.SimpleText("✕", "P11TK.Small", w / 2, h / 2 - 1, Color(240, 200, 195), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    xb.DoClick = function() surface.PlaySound("buttons/button10.wav") f:Remove() end

    local function ABtn(x, y, w, h, txt, col, fn, enabled)
        local b = vgui.Create("DButton", f)
        b:SetPos(x, y) b:SetSize(w, h) b:SetText("")
        b.On = enabled ~= false
        b.Paint = function(s2, ww, hh)
            local a = s2.On and (s2:IsHovered() and 75 or 40) or 14
            draw.RoundedBox(6, 0, 0, ww, hh, Color(col.r, col.g, col.b, a))
            surface.SetDrawColor(col.r, col.g, col.b, s2.On and 180 or 60)
            surface.DrawOutlinedRect(0, 0, ww, hh, 1)
            draw.SimpleText(txt, "P11TK.Small", ww / 2, hh / 2, s2.On and col or C.dim,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function()
            if not b.On then surface.PlaySound("buttons/button10.wav") return end
            surface.PlaySound("buttons/button9.wav")
            fn()
        end
        return b
    end

    local y = 70
    if not isAct then
        local card = vgui.Create("DPanel", f)
        card:SetPos(14, y) card:SetSize(W - 28, 148)
        card.Paint = function(s2, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(24, 10, 12, 255))
            draw.SimpleText("Пульт пока молчит.", "P11TK.Text", 14, 12, C.red)
            draw.SimpleText("Как стать Нечто: красная ОСОБАЯ ВАКАНСИЯ у кадровика", "P11TK.Small", 14, 38, C.text)
            draw.SimpleText("(плашка + объявление в чат) или укол уже проснувшейся твари.", "P11TK.Small", 14, 58, C.text)
            draw.SimpleText("Когда проснётся: ЛКМ — когти (убийство САМО съедает труп", "P11TK.Small", 14, 84, C.dim)
            draw.SimpleText("и надевает личину жертвы), R — этот пульт.", "P11TK.Small", 14, 104, C.dim)
        end
        ABtn(14, y + 158, 246, 34, "🧪 ДИАГНОСТИКА (чат/консоль)", C.gold, function()
            Send("test") f:Remove()
        end)
        ABtn(268, y + 158, W - 28 - 254, 34, "ЗАКРЫТЬ", C.dim, function() f:Remove() end)
        return f
    end

    -- ---------- тиры мутаций ----------
    local nextNeed = nil
    for _, m in ipairs(MUTS) do
        if kills < m.need then nextNeed = m.need break end
    end
    local progress = vgui.Create("DPanel", f)
    progress:SetPos(14, y) progress:SetSize(W - 28, 40)
    progress.Paint = function(s2, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(45, 18, 20, 255))
        if nextNeed then
            local prev = (nextNeed == 3 and 0) or (nextNeed == 5 and 3) or 5
            local frac = math.Clamp((kills - prev) / (nextNeed - prev), 0, 1)
            draw.RoundedBox(6, 0, 0, w * frac, h, Color(190, 45, 48, 230))
            draw.SimpleText("до следующей мутации: " .. kills .. "/" .. nextNeed, "P11TK.Text",
                w / 2, h / 2, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText("ПИК ЭВОЛЮЦИИ — все мутации открыты", "P11TK.Text",
                w / 2, h / 2, C.gold, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
    y = y + 50

    -- tир-строки
    for i, m in ipairs(MUTS) do
        local got = kills >= m.need
        local row = vgui.Create("DPanel", f)
        row:SetPos(14, y) row:SetSize(W - 28, 26)
        row.Paint = function(s2, w, h)
            draw.SimpleText((got and "✔ " or "○ ") .. m.name .. " (" .. m.need .. " жертв)",
                "P11TK.Small", 10, h / 2, got and C.red or Color(150, 110, 110), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        y = y + 30
    end
    y = y + 8

    -- ---------- маскировка / личина ----------
    if fake ~= "" then
        ABtn(14, y, 250, 36, "🎭 СНЯТЬ ЛИЧИНУ («" .. fake .. "»)", C.gold, function()
            Send("unmask") f:Remove()
        end)
    else
        ABtn(14, y, 250, 36, "🎭 личины нет — убей когтями (R по трупу)", C.dim, function() end, false)
    end
    ABtn(272, y, W - 28 - 258, 36, revealed and "🫥 СПРЯТАТЬ МОНСТРА (человек)" or "👁 ЯВИТЬ ФОРМУ МОНСТРА",
        C.red, function()
            Send("mask") f:Remove()
        end)
    y = y + 46

    -- ---------- формы ----------
    local lbl = vgui.Create("DPanel", f)
    lbl:SetPos(14, y) lbl:SetSize(W - 28, 22)
    lbl.Paint = function(s2, w, h)
        draw.SimpleText("СМЕНА ФОРМЫ" .. (formCd > 0 and (" — перезарядка " .. math.ceil(formCd) .. " сек") or ":"),
            "P11TK.Small", 2, h / 2, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    y = y + 26
    local fw = (W - 28 - 3 * 6) / 4
    for i, fid in ipairs(FORM_ORDER) do
        local fi = FORM_INFO[fid]
        local cur = (fid == formId)
        ABtn(14 + (i - 1) * (fw + 6), y, fw, 40,
            (cur and "• " or "") .. fi.name .. (cur and " •" or ""), cur and C.ok or C.text,
            function()
                Send("form", fid) f:Remove()
            end, (not cur) and formCd <= 0)
    end
    y = y + 48

    if formId == "split" then
        ABtn(14, y, W - 28, 34, "🕷 ПАУЧЬЯ ТУША (вкл/выкл)", C.red, function()
            Send("spider") f:Remove()
        end)
        y = y + 42
    end

    -- ---------- диагностика + шпаргалка ----------
    ABtn(14, y, 250, 32, "🧪 ДИАГНОСТИКА «не работает?»", C.gold, function()
        Send("test") f:Remove()
    end)
    y = y + 40

    local help = vgui.Create("DPanel", f)
    help:SetPos(14, y) help:SetSize(W - 28, H - y - 14)
    help.Paint = function(s2, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(22, 9, 11, 255))
        draw.SimpleText("🧬 " .. finfo.pkm, "P11TK.Small", 10, 8, C.text)
        draw.SimpleText("ЛКМ — когти: убийство САМО съедает труп → личина жертвы на тебе", "P11TK.Small", 10, 28, C.dim)
        draw.SimpleText("(облик + позывной + должность + документ — видят TAB, чат, допрос).", "P11TK.Small", 10, 46, C.dim)
        draw.SimpleText("R по трупу — доесть вручную • !крик — ужас • !разрыв — споры", "P11TK.Small", 10, 64, C.dim)
        draw.SimpleText("консоль: p11_thingtest — та же кнопка-диагностика в любой момент", "P11TK.Small", 10, 82, C.dim)
    end

    if P11.AnimateIn then P11.AnimateIn(f) end
    surface.PlaySound("ui/buttonclick.wav")
    return f
end

P11.OpenThingKit = OpenThingKit
-- ПОДМЕНА старого меню (p11_cl_mutations больше не открывает окно):
-- все R-двери (4 свепа + клавишная страховка) теперь ведут СЮДА.
P11.OpenThingMenu = OpenThingKit

-- запасная команда: пульт тела из консоли в любой момент
concommand.Add("p11_tkit", function()
    OpenThingKit()
end)

print("[POLUS-11] пульт тела «ЛИЧИНА 3.0» загружен (R у когтей; консоль: p11_tkit / p11_thingtest)")
