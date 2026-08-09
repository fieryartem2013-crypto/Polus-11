-- ============================================================
--  ПОЛЮС-11 — ДРЕВО СЛУЖБЫ (client) v4.21.0 «ДРЕВО»
--  Окно C-меню → «⭐ ДРЕВО СЛУЖБЫ»: шкала уровня, фракции
--  (РККА / УЧЁНЫЕ — остальные «позже»), база + три пути,
--  открытие узлов, откат ветки за 100 000₽ (опыт цел).
--  Данные: NWInt P11_SkillXP + P11_TreeSync (JSON: xp, trees,
--  reset). Действия: P11_TreeAct (9 resync / 1 unlock / 2 reset).
-- ============================================================

surface.CreateFont("P11.TR.Big",   { font = "Roboto", size = 24, weight = 800, extended = true })
surface.CreateFont("P11.TR.Mid",   { font = "Roboto", size = 16, weight = 700, extended = true })
surface.CreateFont("P11.TR.Tx",    { font = "Roboto", size = 14, weight = 500, extended = true })
surface.CreateFont("P11.TR.Small", { font = "Roboto", size = 12, weight = 500, extended = true })

-- зеркало серверного дерева (сервер авторитетен — тут витрина)
local TR_XP = { 0, 150, 400, 800, 1400, 2200, 3200, 4500, 6000, 8000 }
local TR = {
    rkka = {
        name = "РККА", col = Color(215, 110, 100),
        base = {
            { id = "rk_nov",  name = "Новобранец РККА", lvl = 0 },
            { id = "rk_post", name = "Постовой РККА",   lvl = 1 },
            { id = "rk_sold", name = "Солдат РККА",     lvl = 2 },
        },
        pathOrder = { "shturm", "razved", "med" },
        paths = {
            shturm = { name = "ПУТЬ ШТУРМА", nodes = {
                { id = "rk_sht",  name = "Штурмовик РККА",       lvl = 3 },
                { id = "rk_pul",  name = "Пулемётчик РККА",      lvl = 5 },
                { id = "rk_let",  name = "Лётчик РККА",          lvl = 7 },
                { id = "rk_gpeh", name = "Генерал РККА (Пехота)",lvl = 9 },
            }},
            razved = { name = "ПУТЬ РАЗВЕДКИ", nodes = {
                { id = "rk_raz", name = "Разведчик РККА",   lvl = 3 },
                { id = "rk_kom", name = "Комиссар РККА",    lvl = 6 },
                { id = "rk_gen", name = "Генерал РККА",     lvl = 9 },
            }},
            med = { name = "ПУТЬ МЕДСЛУЖБЫ", nodes = {
                { id = "rk_ms", name = "Медсестра РККА",        lvl = 3 },
                { id = "rk_mg", name = "Главная Медсестра РККА",lvl = 6 },
            }},
        },
    },
    science = {
        name = "УЧЁНЫЕ", col = Color(140, 200, 240),
        base = {
            { id = "sc_lab", name = "Лаборант (ЦНИИ)", lvl = 0 },
            { id = "sc_uch", name = "Учёный",          lvl = 1 },
        },
        pathOrder = { "bio", "upr", "pole" },
        paths = {
            bio = { name = "ПУТЬ БИОХИМИИ", nodes = {
                { id = "sc_bio", name = "Био-химик",                 lvl = 2 },
                { id = "sc_soz", name = "Создатель Научн. Комплекса",lvl = 6 },
            }},
            upr = { name = "ПУТЬ РУКОВОДСТВА", nodes = {
                { id = "sc_ved", name = "Ведущий Учёный",        lvl = 3 },
                { id = "sc_men", name = "Менеджер Научн. Отдела",lvl = 5 },
            }},
            pole = { name = "ПОЛЕВОЙ ПРОТОКОЛ", nodes = {
                { id = "sc_p1", name = "Полевой протокол", lvl = 2, perk = "+25% к опыту за научные дела" },
                { id = "sc_p2", name = "Стипендия ЦНИИ",   lvl = 4, perk = "разовая выплата 2 500₽" },
            }},
        },
    },
}

P11.Tree = P11.Tree or { xp = 0, trees = {}, reset = 100000, fac = "rkka" }

local TR_BG   = Color(10, 14, 20, 248)
local TR_PANE = Color(24, 30, 40, 255)
local TR_TEXT = Color(232, 238, 245)
local TR_DIM  = Color(150, 158, 172)
local TR_GOLD = Color(255, 205, 100)
local TR_OK   = Color(110, 215, 140)
local TR_BAD  = Color(240, 100, 90)
local TR_ACC  = Color(120, 185, 255)

local function LevelOf(xp)
    local lvl = 0
    for i = 1, 10 do
        if xp >= TR_XP[i] then lvl = i else break end
    end
    return lvl
end

net.Receive("P11_TreeSync", function()
    local ok, tbl = pcall(util.JSONToTable, net.ReadString() or "{}")
    if not ok or not istable(tbl) then return end
    P11.Tree.xp    = tonumber(tbl.xp) or 0
    P11.Tree.trees = istable(tbl.trees) and tbl.trees or {}
    P11.Tree.reset = tonumber(tbl.reset) or 100000
end)

-- ============ ОКНО ============

local function NodeCard(parent, fac, pathId, node, branchState, myLvl, isBase)
    local opened = branchState.nodes and branchState.nodes[node.id]
    local pathChosen = tostring(branchState.path or "")

    local card = vgui.Create("DPanel", parent)
    card:Dock(TOP) card:DockMargin(0, 0, 0, 6) card:SetTall(node.perk and 66 or 52)

    -- состояние
    local state, note = "lock", ""
    if opened then
        state = "done"
    elseif isBase then
        if myLvl >= (node.lvl or 0) then state, note = "base", "по уровню" else note = "нужен ур. " .. (node.lvl or 0) end
    elseif myLvl < (node.lvl or 0) then
        note = "нужен ур. " .. (node.lvl or 0)
    elseif pathChosen ~= "" and pathChosen ~= pathId then
        state, note = "dead", "чужой путь"
    elseif pathId and TR[fac].paths[pathId] then
        -- лесенка: предыдущий узел ветки должен быть открыт
        local nodes = TR[fac].paths[pathId].nodes
        for i, n in ipairs(nodes) do
            if n.id == node.id and i > 1 then
                local prev = nodes[i - 1]
                if not (branchState.nodes and branchState.nodes[prev.id]) then
                    note = "сначала узел выше"
                end
                break
            end
        end
        if note == "" then state = "open" end
    end

    card.Paint = function(s, w, h)
        local edge = TR_DIM
        if state == "done" then edge = TR_OK
        elseif state == "open" then edge = TR_GOLD
        elseif state == "base" then edge = TR_ACC
        elseif state == "dead" then edge = Color(80, 60, 60) end
        draw.RoundedBox(6, 0, 0, w, h, TR_PANE)
        surface.SetDrawColor(edge.r, edge.g, edge.b, state == "dead" and 90 or 160)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        local nm = node.name
        if state == "dead" then nm = "✕ " .. nm end
        draw.SimpleText(nm, "P11.TR.Mid", 10, 8,
            state == "done" and TR_OK or (state == "dead" and Color(110, 100, 100) or TR_TEXT))
        if node.perk then
            draw.SimpleText("ПЕРК: " .. node.perk, "P11.TR.Small", 10, 30, TR_DIM)
            draw.SimpleText("ур. " .. (node.lvl or 0), "P11.TR.Small", w - 10, 8, TR_ACC, TEXT_ALIGN_RIGHT)
        else
            draw.SimpleText((isBase and "база" or "должность") .. " · ур. " .. (node.lvl or 0),
                "P11.TR.Small", 10, 30, TR_DIM)
        end
        if state == "done" then
            draw.SimpleText("✓ ОТКРЫТО", "P11.TR.Small", w - 10, h - 22, TR_OK, TEXT_ALIGN_RIGHT)
        elseif note ~= "" then
            draw.SimpleText(note, "P11.TR.Small", w - 10, h - 22, TR_DIM, TEXT_ALIGN_RIGHT)
        end
    end

    if state == "open" then
        local b = vgui.Create("DButton", card)
        b:SetPos(140, 0) b:SetSize(90, 52) b:SetText("")
        b.Paint = function(s, w, h)
            draw.RoundedBox(6, w - 90, 6, 84, h - 12,
                s:IsHovered() and Color(255, 205, 100, 240) or Color(150, 120, 55, 220))
            draw.SimpleText("ОТКРЫТЬ", "P11.TR.Mid", w - 48, h / 2, Color(20, 22, 26),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function()
            net.Start("P11_TreeAct")
                net.WriteUInt(1, 4)
                net.WriteString(fac)
                net.WriteString(node.id)
            net.SendToServer()
            surface.PlaySound("buttons/button15.wav")
            timer.Simple(0.45, function()
                if IsValid(P11.TreeFrame) then P11.TreeFrame:Remove() end
                P11.OpenSkillTree()
            end)
        end
        -- кнопку в правый край карточки
        card.PerformLayout = function(s, w, h)
            b:SetPos(w - 96, 0) b:SetSize(92, h)
        end
    end
end

local function BuildTreeBody(f, fac)
    local def = TR[fac]
    if not def then return end
    local myLvl = LevelOf(tonumber(LocalPlayer():GetNWInt("P11_SkillXP", P11.Tree.xp)) or 0)
    local branch = istable(P11.Tree.trees[fac]) and P11.Tree.trees[fac] or { path = "", nodes = {} }

    -- БАЗА
    local bl = vgui.Create("DLabel", f)
    bl:SetPos(16, 118) bl:SetSize(200, 18)
    bl:SetFont("P11.TR.Mid") bl:SetTextColor(def.col)
    bl:SetText("БАЗА (без пути):")
    local bx = vgui.Create("DPanel", f)
    bx:SetPos(16, 140) bx:SetSize(200, 380)
    bx.Paint = function() end
    for _, n in ipairs(def.base) do
        NodeCard(bx, fac, nil, n, branch, myLvl, true)
    end

    -- ТРИ ПУТИ
    local chosen = tostring(branch.path or "")
    for i, pid in ipairs(def.pathOrder or {}) do
        local pdef = def.paths[pid]
        local x = 232 + (i - 1) * 216
        local dead = chosen ~= "" and chosen ~= pid
        local mine = chosen == pid

        local pl = vgui.Create("DLabel", f)
        pl:SetPos(x, 118) pl:SetSize(200, 18)
        pl:SetFont("P11.TR.Mid")
        pl:SetTextColor(dead and Color(100, 92, 92) or (mine and TR_GOLD or TR_TEXT))
        pl:SetText(pdef.name .. (mine and " ●" or dead and " ✕" or ""))
        local hint = vgui.Create("DLabel", f)
        hint:SetPos(x, 150 - 14) hint:SetSize(200, 14)
        hint:SetFont("P11.TR.Small") hint:SetTextColor(TR_DIM)
        hint:SetText(dead and "закрыт выбором пути" or mine and "твой путь" or "первый узел выберет путь")

        local col = vgui.Create("DPanel", f)
        col:SetPos(x, 160) col:SetSize(200, 360)
        col.Paint = function() end
        for _, n in ipairs(pdef.nodes) do
            NodeCard(col, fac, pid, n, branch, myLvl, false)
        end
    end
end

function P11.OpenSkillTree()
    if IsValid(P11.TreeFrame) then P11.TreeFrame:Remove() end

    -- живой ресинк при открытии
    net.Start("P11_TreeAct")
        net.WriteUInt(9, 4)
    net.SendToServer()

    local f = vgui.Create("DFrame")
    P11.TreeFrame = f
    f:SetSize(880, 600)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false) f.btnMaxim:SetVisible(false) f.btnMinim:SetVisible(false)
    f.T0 = SysTime()
    f.Paint = function(s, w, h)
        Derma_DrawBackgroundBlur(s, s.T0)
        draw.RoundedBox(10, 0, 0, w, h, TR_BG)
        draw.RoundedBoxEx(10, 0, 0, w, 56, TR_PANE, true, true, false, false)
        surface.SetDrawColor(TR_GOLD)
        surface.DrawRect(0, 56, w, 2)
        draw.SimpleText("⭐ ДРЕВО СЛУЖБЫ", "P11.TR.Big", 16, 6, TR_GOLD)
        -- шкала уровня
        local xp = tonumber(LocalPlayer():GetNWInt("P11_SkillXP", P11.Tree.xp)) or 0
        local lvl = LevelOf(xp)
        local nxt = (lvl < 10) and TR_XP[lvl + 1] or TR_XP[10]
        local base = (lvl > 0) and TR_XP[lvl] or 0
        local frac = (lvl >= 10) and 1 or math.Clamp((xp - base) / math.max(1, nxt - base), 0, 1)
        local bw = 300
        draw.RoundedBox(4, w - 16 - bw, 10, bw, 18, Color(0, 0, 0, 140))
        if frac > 0 then
            draw.RoundedBox(4, w - 14 - bw, 12, (bw - 4) * frac, 14, TR_GOLD)
        end
        draw.SimpleText("УРОВЕНЬ " .. lvl .. (lvl >= 10 and " (МАКС)" or "") ..
            " · " .. math.floor(xp) .. (lvl < 10 and ("/" .. nxt) or "") .. " опыта",
            "P11.TR.Small", w - 16 - bw / 2, 19, Color(22, 22, 24), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("опыт — за дела смены/наряды/анализы/груз · ранг Staff Leader+ вне древа",
            "P11.TR.Small", 18, 38, TR_DIM)
    end
    f.OnKeyCodePressed = function(s, key)
        if key == KEY_ESCAPE then f:Remove() end
    end

    local x = vgui.Create("DButton", f)
    x:SetPos(880 - 38, 12) x:SetSize(26, 26) x:SetText("")
    x.Paint = function(s, w, h)
        draw.SimpleText("✕", "P11.TR.Mid", w / 2, h / 2,
            s:IsHovered() and TR_BAD or TR_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    x.DoClick = function() f:Remove() end

    -- вкладки фракций
    local facNames = { rkka = "РККА", science = "УЧЁНЫЕ" }
    local order = { "rkka", "science" }
    for i, fac in ipairs(order) do
        local tb = vgui.Create("DButton", f)
        tb:SetPos(16 + (i - 1) * 150, 58 + 4) tb:SetSize(140, 40) tb:SetText("")
        tb.Paint = function(s, w, h)
            local sel = P11.Tree.fac == fac
            draw.RoundedBox(6, 0, 0, w, h, sel and TR[fac].col or TR_PANE)
            draw.SimpleText(facNames[fac], "P11.TR.Mid", w / 2, h / 2,
                sel and Color(20, 22, 26) or TR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        tb.DoClick = function()
            P11.Tree.fac = fac
            f:Remove()
            P11.OpenSkillTree()
        end
    end
    -- заглушки будущих фракций
    local soon = vgui.Create("DLabel", f)
    soon:SetPos(330, 62) soon:SetSize(300, 34)
    soon:SetFont("P11.TR.Small") soon:SetTextColor(TR_DIM)
    soon:SetText("НКВД · Красный Орёл · персонал — ветви позже")

    -- тело дерева
    local ok, err = pcall(BuildTreeBody, f, P11.Tree.fac)
    if not ok then print("[POLUS][ERROR] древо: " .. tostring(err)) end

    -- откат
    local reset = vgui.Create("DButton", f)
    reset:SetPos(232, 536) reset:SetSize(632, 46) reset:SetText("")
    reset.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(90, 30, 28) or Color(60, 26, 24))
        draw.SimpleText("ОТКАТИТЬ ВЕТКИ «" .. (TR[P11.Tree.fac] and TR[P11.Tree.fac].name or "") ..
            "» — " .. (tonumber(P11.Tree.reset) or 100000) .. "₽",
            "P11.TR.Mid", 14, 12, TR_BAD)
        draw.SimpleText("путь и узлы стираются · ОПЫТ И УРОВЕНЬ СОХРАНЯЮТСЯ — протестишь другую ветку",
            "P11.TR.Small", 14, 30, TR_DIM)
    end
    reset.DoClick = function()
        net.Start("P11_TreeAct")
            net.WriteUInt(2, 4)
            net.WriteString(P11.Tree.fac)
        net.SendToServer()
        surface.PlaySound("ambient/alarms/warningbell1.wav")
        timer.Simple(0.5, function()
            if IsValid(P11.TreeFrame) then P11.TreeFrame:Remove() end
            P11.OpenSkillTree()
        end)
    end

    surface.PlaySound("buttons/button14.wav")
end

print("[POLUS-11] ДРЕВО СЛУЖБЫ (client): окно C-меню «⭐ ДРЕВО СЛУЖБЫ» — уровень, 3 пути, откат")
