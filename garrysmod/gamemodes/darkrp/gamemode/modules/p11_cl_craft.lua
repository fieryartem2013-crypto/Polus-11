-- ============================================================
--  ПОЛЮС-11 — КУСТАРНАЯ МАСТЕРСКАЯ (client) v4.11.0 «КУЗНЯ»
--  Окно крафта: кнопка «🛠 МАСТЕРСКАЯ» в 🎒 инвентаре,
--  чат !крафт, консоль p11_craft, живой ВЕРСТАК на станции (E).
--  Состав своих материалов читаем из общего кэша P11.Eco (его
--  ведёт p11_cl_economy по серверному InvSync — живые цифры).
--  РЕЦЕПТЫ тут — зеркало серверного списка (p11_sv_craft):
--  при правке рецепта меняй и там, и тут (сервер — истина).
-- ============================================================

surface.CreateFont("P11C.Title", { font = "Roboto", size = 24, weight = 800, extended = true })
surface.CreateFont("P11C.Big",   { font = "Roboto", size = 18, weight = 700, extended = true })
surface.CreateFont("P11C.Text",  { font = "Roboto", size = 15, weight = 500, extended = true })
surface.CreateFont("P11C.Small", { font = "Roboto", size = 13, weight = 500, extended = true })

local C = {
    bg    = Color(12, 12, 16, 246),
    panel = Color(22, 24, 30, 255),
    card  = Color(29, 32, 40, 255),
    gold  = Color(255, 200, 100),
    text  = Color(232, 238, 246),
    dim   = Color(152, 160, 176),
    ok    = Color(140, 235, 150),
    red   = Color(255, 120, 110),
    line  = Color(100, 110, 130, 140),
}

-- зеркало серверных рецептов (p11_sv_craft) — держать в паре!
local RECIPES = {
    { id = "ration",    name = "Горячий паёк",       needs = { cons = 1, fuel = 1 },
        desc = "Тушёнку разогреть на соляре — и вот уже полярный обед." },
    { id = "chemlight", name = "Химсвет (пачка)",    needs = { spirit = 1, cloth = 1 },
        desc = "Метка света в белой мгле: спирт + брезентовый фитиль." },
    { id = "syringe",   name = "Полевой шприц",      needs = { spirit = 1, parts = 1 },
        desc = "Шприц-тюбик из запчастей; спирт — за стерильность." },
    { id = "radio",     name = "Рация (самосбор)",   needs = { parts = 1, scrap = 1 },
        desc = "Приёмник из лома и запчастей. Центр услышит." },
    { id = "medkit",    name = "Полевой медкейс",    needs = { cloth = 2, spirit = 1 },
        desc = "Бинт, спирт, упаковка. Медики одобряют самодеятельность." },
    { id = "flamer",    name = "Кустарный огнемёт",  needs = { fuel = 2, parts = 2, scrap = 2 },
        desc = "ГЛАВНЫЙ рецепт войны с Нечто: соляра + запчасти + лом." },
    -- v4.11.0 «КУЗНЯ»: верстак — новые рецепты (боеприпасы и инструмент)
    { id = "ammo9",     name = "Самокрут 9×18 (x60)", needs = { scrap = 1, parts = 1 },
        desc = "Гильзы из лома, капсюли из запчастей. К пистолетам станции." },
    { id = "ammosmg",   name = "ПП-патроны самосбор (x90)", needs = { scrap = 1, parts = 1, spirit = 1 },
        desc = "Для АКС/ППШ: спирт-смазка — не клинит на морозе." },
    { id = "ammoar",    name = "Винтовочно-автоматные (x60)", needs = { scrap = 2, parts = 1 },
        desc = "Полный рожок к АК-74 и РПД из станочных остатков." },
    { id = "ammobuck",  name = "Картечь 12-го самосбор (x16)", needs = { scrap = 1, cloth = 1, spirit = 1 },
        desc = "Гвозди из лома, пыж из брезента — двустволка скажет спасибо." },
    { id = "scalpel",   name = "Скальпель", needs = { scrap = 1, parts = 1 },
        desc = "Обмолоток лома, заточка о наждак — режет честно." },
    { id = "ukol",      name = "Инъектор «УКОЛ-С»", needs = { parts = 2, spirit = 2 },
        desc = "Шприц-тюбики + стерильный спирт: два заряда живучести." },
}

P11C = P11C or { Frame = nil }

local function MatName(mid)
    local it = (P11.Eco and P11.Eco.catalog) and P11.Eco.catalog[mid]
    return (it and it.name) or mid
end

local function HaveOf(mid)
    return tonumber((P11.Eco and P11.Eco.items) and P11.Eco.items[mid]) or 0
end

local function CloseCraft()
    if IsValid(P11C.Frame) then P11C.Frame:Remove() P11C.Frame = nil end
end

function P11.OpenCraft()
    CloseCraft()

    local W, H = 640, 150 + 92 * #RECIPES
    if H > ScrH() - 60 then H = ScrH() - 60 end

    local f = vgui.Create("DFrame")
    P11C.Frame = f
    f:SetSize(W, H)
    f:Center()
    f:SetTitle("")
    f:SetDraggable(true)
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false)
    f.btnMaxim:SetVisible(false)
    f.btnMinim:SetVisible(false)
    f.OnRemove = function() if P11C.Frame == f then P11C.Frame = nil end end
    f.OnKeyCodePressed = function(_, key) if key == KEY_ESCAPE then f:Remove() end end

    f.Paint = function(s, w, h)
        Derma_DrawBackgroundBlur(s, SysTime())
        draw.RoundedBox(12, 0, 0, w, h, C.bg)
        draw.RoundedBoxEx(12, 0, 0, w, 66, C.panel, true, true, false, false)
        surface.SetDrawColor(C.line) surface.DrawRect(0, 66, w, 1)
        draw.SimpleText("🛠 КУСТАРНАЯ МАСТЕРСКАЯ", "P11C.Title", 16, 20, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("материалы из ларька и ящиков → готовые вещи в 🎒 инвентарь · стол станции: ВЕРСТАК", "P11C.Small", 16, 46, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local xb = vgui.Create("DButton", f)
    xb:SetPos(W - 38, 14) xb:SetSize(26, 24) xb:SetText("")
    xb.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(120, 44, 40) or Color(50, 34, 32))
        draw.SimpleText("✕", "P11C.Small", w / 2, h / 2 - 1, Color(240, 210, 205), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    xb.DoClick = function() f:Remove() end

    local sc = vgui.Create("DScrollPanel", f)
    sc:SetPos(14, 76) sc:SetSize(W - 28, H - 88)
    sc:GetVBar():SetWide(5)

    for _, rc in ipairs(RECIPES) do
        local card = sc:Add("DPanel")
        card:Dock(TOP) card:DockMargin(0, 0, 0, 8) card:SetTall(84)

        local function CanNow()
            for mid, n in pairs(rc.needs) do
                if HaveOf(mid) < n then return false end
            end
            return true
        end

        local b = vgui.Create("DButton", card)
        b:SetSize(130, 32) b:SetText("")
        b.DoClick = function()
            net.Start("P11_CraftDo")
                net.WriteString(rc.id)
            net.SendToServer()
            surface.PlaySound("buttons/button15.wav")
            -- пересчёт кнопки придёт с InvSync (живые цифры из кэша P11.Eco)
        end

        b.Paint = function(s, w, h)
            local can = CanNow()
            local a = can and (s:IsHovered() and 80 or 46) or 16
            draw.RoundedBox(7, 0, 0, w, h, Color(C.gold.r, C.gold.g, C.gold.b, a))
            surface.SetDrawColor(C.gold.r, C.gold.g, C.gold.b, can and 200 or 60)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(can and "СОБРАТЬ" or "НЕ ХВАТАЕТ", "P11C.Small", w / 2, h / 2,
                can and C.gold or C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        card.PerformLayout = function(s, w, h)
            b:SetPos(w - 142, (h - 32) / 2)
        end
        card.Paint = function(s, w, h)
            draw.RoundedBox(8, 0, 0, w, h, C.card)
            draw.SimpleText(rc.name, "P11C.Big", 14, 10, CanNow() and C.text or C.dim, TEXT_ALIGN_LEFT)
            draw.SimpleText(rc.desc, "P11C.Small", 14, 34, C.dim, TEXT_ALIGN_LEFT)
            -- строка расходников: «Брезент 2/2 ✔»
            surface.SetFont("P11C.Small")
            local x = 14
            for mid, n in pairs(rc.needs) do
                local have = HaveOf(mid)
                local lbl = MatName(mid) .. " " .. have .. "/" .. n
                local col = (have >= n) and C.ok or C.red
                draw.SimpleText(lbl, "P11C.Small", x, 60, col, TEXT_ALIGN_LEFT)
                x = x + surface.GetTextSize(lbl) + 26
            end
        end
    end

    surface.PlaySound("ui/buttonclick.wav")
    return f
end

-- сервер попросил окно (чат !крафт)
net.Receive("P11_CraftOpen", function()
    P11.OpenCraft()
end)

-- консольная дверь
concommand.Add("p11_craft", function()
    P11.OpenCraft()
end)

print("[P11CRAFT] v4.11.0 «КУЗНЯ» OK — мастерская 12 рецептов (🎒 инвентарь / !крафт / p11_craft / ВЕРСТАК на станции)")
