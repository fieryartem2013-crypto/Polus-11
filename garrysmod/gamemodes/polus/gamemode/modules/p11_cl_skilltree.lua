-- ============================================================
--  ПОЛЮС-11 — ДРЕВО СЛУЖБЫ (client) v4.32.0 «ПОДПОЛЬЕ» — + ветвь КРИМИНАЛА, новые узлы РККА
--  (была v4.27.1 «СЕКАТОР» — ветви без наложений, чистые карточки)
--  Окно C-меню → «⭐ ДРЕВО СЛУЖБЫ»: НАСТОЯЩЕЕ ДЕРЕВО — ствол
--  базы снизу, три ветви веером вверх, линии-связи, узлы-кнопки
--  с состояниями (✓ открыто / золотой доступно / замок / ✕ чужой
--  путь). Живое обновление по P11_TreeSync (после клика кадр сам
--  пересобирается — «пункты не выбирались» больше не страшно).
--  Данные: NWInt P11_SkillXP + P11_TreeSync (JSON), действия:
--  P11_TreeAct (9 resync / 1 unlock (fac,nodeId) / 2 reset).
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
                { id = "rk_snab", name = "Снабженец РККА",       lvl = 4 },
                { id = "rk_pul",  name = "Пулемётчик РККА",      lvl = 5 },
                { id = "rk_let",  name = "Лётчик РККА",          lvl = 7 },
                { id = "rk_gpeh", name = "Генерал РККА (Пехота)",lvl = 9 },
            }},
            razved = { name = "ПУТЬ РАЗВЕДКИ", nodes = {
                { id = "rk_raz", name = "Разведчик РККА",   lvl = 3 },
                -- v4.33.0 «ПАТРОН»: Радист РККА ВЫРЕЗАН (заявка владельца «удали связиста РККА»)
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
                { id = "sc_p1", name = "Полевой протокол", lvl = 2, perk = "+25% к опыту за анализы крови" },
                { id = "sc_p2", name = "Стипендия ЦНИИ",   lvl = 4, perk = "разовая выплата 2 500₽" },
            }},
        },
    },
    -- v4.32.0 «ПОДПОЛЬЕ»: КРИМИНАЛ В ДРЕВЕ (витрина; сервер авторитетен)
    crime = {
        name = "КРИМИНАЛ", col = Color(190, 135, 215),
        base = {
            { id = "cr_kur", name = "Курьер контрабанды", lvl = 0 },
        },
        pathOrder = { "kontr", "dno", "verh" },
        paths = {
            kontr = { name = "ПУТЬ КОНТРАБАНДЫ", nodes = {
                { id = "cr_kon", name = "Контрабандист",     lvl = 2 },
                { id = "cr_vzl", name = "Взломщик складов",  lvl = 4 },
            }},
            dno = { name = "ПУТЬ ДНА", nodes = {
                { id = "cr_bych", name = "Бычок",  lvl = 2 },
                { id = "cr_bar",  name = "Барыга", lvl = 4 },
            }},
            verh = { name = "КРЫША", nodes = {
                { id = "cr_sku", name = "Скупщик краденого",        lvl = 5 },
                { id = "cr_gla", name = "Главарь криминала станции", lvl = 7 },
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

-- живое обновление: после любого синка кадр пересобирается сам
net.Receive("P11_TreeSync", function()
    local ok, tbl = pcall(util.JSONToTable, net.ReadString() or "{}")
    if not ok or not istable(tbl) then return end
    P11.Tree.xp    = tonumber(tbl.xp) or 0
    P11.Tree.trees = istable(tbl.trees) and tbl.trees or {}
    P11.Tree.reset = tonumber(tbl.reset) or 100000
    P11.Tree._lastSync = CurTime()
    if IsValid(P11.TreeFrame) then
        P11.OpenSkillTree() -- пересборка (ресинк внутри загашен _lastSync)
    end
end)

-- ============ СОСТОЯНИЕ УЗЛА ============

local function NodeState(fac, pathId, node, branch, myLvl, isBase)
    if branch.nodes and branch.nodes[node.id] then return "done", "" end
    local chosen = tostring(branch.path or "")
    if isBase then
        if myLvl >= (node.lvl or 0) then return "base", "по уровню" end
        return "lock", "нужен ур. " .. (node.lvl or 0)
    end
    if myLvl < (node.lvl or 0) then return "lock", "нужен ур. " .. (node.lvl or 0) end
    if chosen ~= "" and chosen ~= pathId then return "dead", "чужой путь" end
    local pdef = pathId and TR[fac].paths[pathId]
    if pdef then
        for i, n in ipairs(pdef.nodes) do
            if n.id == node.id and i > 1 then
                local prev = pdef.nodes[i - 1]
                if not (branch.nodes and branch.nodes[prev.id]) then
                    return "lock", "сначала узел ниже"
                end
                break
            end
        end
    end
    return "open", ""
end

-- ============ ДЕРЕВО (канва с линиями) ============

local function BuildTreeCanvas(f, fac)
    local def = TR[fac]
    if not def then return end
    local myLvl = LevelOf(tonumber(LocalPlayer():GetNWInt("P11_SkillXP", P11.Tree.xp)) or 0)
    local branch = istable(P11.Tree.trees[fac]) and P11.Tree.trees[fac] or { path = "", nodes = {} }

    local cv = vgui.Create("DScrollPanel", f)
    cv:SetPos(14, 112) cv:SetSize(852, 470)
    cv:GetVBar():SetWide(5)

    local CW, CH = 828, 760
    local paper = vgui.Create("DPanel", cv)
    paper:SetSize(CW, CH)
    paper:SetPaintBackground(false)

    -- раскладка: ствол базы снизу, ветви веером вверх
    local NCX = { ["1"] = CW / 2, ["2"] = CW / 2 - 250, ["3"] = CW / 2 + 250 } -- по индексу пути преобразуем ниже
    local trunkX = CW / 2
    local baseY0 = 660          -- первый узел базы (низ ствола)
    local gapBase = 64
    local junctionGap = 96      -- расстояние от верха ствола до развилки
    local gapPath = 92

    local centers = {} -- [nodeId] = {x,y}
    local lines   = {} -- {fromId, toId}

    -- база
    local baseNodes = def.base or {}
    for i, n in ipairs(baseNodes) do
        centers[n.id] = { x = trunkX, y = baseY0 - (i - 1) * gapBase }
        if i > 1 then lines[#lines + 1] = { baseNodes[i - 1].id, n.id } end
    end
    local topBase = baseNodes[#baseNodes]
    local junctionY = (topBase and centers[topBase.id].y or baseY0) - junctionGap

    -- пути: центры колонок 1..N
    local pids = def.pathOrder or {}
    local pathX = {}
    local total = #pids
    for i, pid in ipairs(pids) do
        if total == 3 then
            pathX[pid] = (i == 1) and (CW / 2 - 250) or (i == 2) and (CW / 2) or (CW / 2 + 250)
        elseif total == 2 then
            pathX[pid] = (i == 1) and (CW / 2 - 180) or (CW / 2 + 180)
        else
            pathX[pid] = CW / 2
        end
    end

    for _, pid in ipairs(pids) do
        local pdef = def.paths[pid]
        if not pdef then break end
        local px = pathX[pid]
        for j, n in ipairs(pdef.nodes) do
            -- v4.27.1: первый узел на 70 ниже развилки, каждый следующий — ещё на gapPath
            -- (раньше 2-й узел садился всего на 22px ниже 1-го — карточки рисовались ВНАХЛЁСТ,
            --  отсюда и «засоренные» дубли строк на высоких узлах)
            centers[n.id] = { x = px, y = junctionY - 70 - (j - 1) * gapPath }
            if j == 1 then
                lines[#lines + 1] = { topBase.id, n.id }
            else
                lines[#lines + 1] = { pdef.nodes[j - 1].id, n.id }
            end
        end
    end

    -- линии рисуются под узлами
    paper.Paint = function(_, w, h)
        -- мягкая развилка-основа
        surface.SetDrawColor(70, 80, 95, 120)
        for _, ln in ipairs(lines) do
            local a, b = centers[ln[1]], centers[ln[2]]
            if a and b then
                local done = branch.nodes and branch.nodes[ln[2]]
                if done then surface.SetDrawColor(TR_OK.r, TR_OK.g, TR_OK.b, 200)
                else surface.SetDrawColor(70, 80, 95, 120) end
                surface.DrawLine(a.x, a.y, b.x, b.y)
                surface.DrawLine(a.x + 1, a.y, b.x + 1, b.y) -- жирнее
            end
        end
    end

    -- заголовки ветвей
    local chosen = tostring(branch.path or "")
    for _, pid in ipairs(pids) do
        local pdef = def.paths[pid]
        if not pdef then break end
        local dead = chosen ~= "" and chosen ~= pid
        local mine = chosen == pid
        local px = pathX[pid]
        local topNode = pdef.nodes[#pdef.nodes]
        local ty = centers[topNode.id] and centers[topNode.id].y or junctionY
        local hd = vgui.Create("DLabel", paper)
        hd:SetPos(px - 110, ty - 86) hd:SetSize(220, 30)
        hd:SetFont("P11.TR.Mid")
        hd:SetTextColor(dead and Color(100, 92, 92) or (mine and TR_GOLD or TR_TEXT))
        hd:SetText(pdef.name .. (mine and " ●" or dead and " ✕" or ""))
        hd:SetContentAlignment(5)
    end

    -- узлы-кнопки
    local function SpawnNode(node, x, y, isBase, pathId)
        local state, note = NodeState(fac, pathId, node, branch, myLvl, isBase)
        local W, H = 196, 54
        local b = vgui.Create("DButton", paper)
        b:SetPos(x - W / 2, y - H / 2) b:SetSize(W, H)
        b:SetText("")
        b.Paint = function(s, w, h)
            local edge, fill = TR_DIM, TR_PANE
            if state == "done" then edge, fill = TR_OK, Color(22, 48, 32)
            elseif state == "open" then edge, fill = TR_GOLD, Color(58, 44, 16)
            elseif state == "base" then edge, fill = TR_ACC, Color(18, 34, 50)
            elseif state == "dead" then edge, fill = Color(80, 60, 60), Color(26, 20, 20) end
            if state == "open" and s:IsHovered() then fill = Color(84, 64, 20) end
            draw.RoundedBox(7, 0, 0, w, h, fill)
            surface.SetDrawColor(edge.r, edge.g, edge.b, (state == "dead" or state == "lock") and 100 or 200)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            local nm = node.name
            if state == "dead" then nm = "✕ " .. nm end
            draw.SimpleText(nm, "P11.TR.Tx", 10, 7,
                state == "done" and TR_OK or (state == "dead" and Color(120, 105, 105) or TR_TEXT))
            -- v4.27.1 «СЕКАТОР»: вторая строка — ОДНА честная пометка,
            -- без дублей «должность · ур. X» поверх «нужен ур. X»
            local sub, subC
            if state == "done" then
                sub  = node.perk and ("ПЕРК: " .. node.perk) or "✓ открыто"
                subC = Color(140, 200, 160)
            elseif state == "open" then
                sub  = node.perk and ("ПЕРК: " .. node.perk)
                    or ((isBase and "база" or "должность") .. " · ур. " .. (node.lvl or 0))
                subC = TR_GOLD
            elseif state == "lock" and note == "сначала узел ниже" then
                sub  = "🔒 сначала узел ниже"
                subC = Color(150, 140, 130)
            elseif state == "lock" then
                sub  = "🔒 нужен ур. " .. (node.lvl or 0) .. " (у тебя " .. myLvl .. ")"
                subC = Color(150, 140, 130)
            elseif state == "dead" then
                sub  = "✕ чужой путь — откатом можно сменить"
                subC = Color(120, 105, 105)
            else
                sub  = "база по уровню"
                subC = TR_DIM
            end
            draw.SimpleText(sub, "P11.TR.Small", 10, 30, subC)
            if state == "done" then
                draw.SimpleText("✓", "P11.TR.Mid", w - 12, 8, TR_OK, TEXT_ALIGN_RIGHT)
            elseif state == "open" then
                draw.SimpleText("ОТКРЫТЬ ▸", "P11.TR.Small", w - 10, h - 20,
                    s:IsHovered() and TR_GOLD or Color(190, 160, 90), TEXT_ALIGN_RIGHT)
            end
        end
        b.DoClick = function()
            if state ~= "open" then
                surface.PlaySound("buttons/button10.wav")
                return
            end
            net.Start("P11_TreeAct")
                net.WriteUInt(1, 4)
                net.WriteString(fac)
                net.WriteString(node.id)
            net.SendToServer()
            surface.PlaySound("buttons/button15.wav")
            -- страховочный ресинк, если серверный синк опоздает
            timer.Simple(0.7, function()
                net.Start("P11_TreeAct")
                    net.WriteUInt(9, 4)
                net.SendToServer()
            end)
        end
    end

    for _, n in ipairs(baseNodes) do
        local c = centers[n.id]
        SpawnNode(n, c.x, c.y, true, nil)
    end
    for _, pid in ipairs(pids) do
        local pdef = def.paths[pid]
        if not pdef then break end
        for _, n in ipairs(pdef.nodes) do
            local c = centers[n.id]
            if c then SpawnNode(n, c.x, c.y, false, pid) end
        end
    end
end

-- ============ ОКНО ============

function P11.OpenSkillTree()
    if IsValid(P11.TreeFrame) then P11.TreeFrame:Remove() end

    -- живой ресинк при открытии (но не чаще раза в секунду — анти-петля)
    if CurTime() - (P11.Tree._lastSync or 0) > 1 then
        net.Start("P11_TreeAct")
            net.WriteUInt(9, 4)
        net.SendToServer()
    end

    local f = vgui.Create("DFrame")
    P11.TreeFrame = f
    f:SetSize(880, 646)
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
        draw.SimpleText("ствол — база по уровню · ветви вверх — три пути · клик по золотому узлу открывает",
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
    local facNames = { rkka = "РККА", science = "УЧЁНЫЕ", crime = "КРИМИНАЛ" }
    local order = { "rkka", "science", "crime" } -- v4.32.0 «ПОДПОЛЬЕ»: криминал в древе
    for i, fac in ipairs(order) do
        local tb = vgui.Create("DButton", f)
        tb:SetPos(16 + (i - 1) * 150, 62) tb:SetSize(140, 40) tb:SetText("")
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
    local soon = vgui.Create("DLabel", f)
    soon:SetPos(470, 68) soon:SetSize(380, 30) -- v4.32.0: сдвинута за третью вкладку
    soon:SetFont("P11.TR.Small") soon:SetTextColor(TR_DIM)
    soon:SetText("НКВД · Красный Орёл · персонал — ветви позже")

    -- тело: настоящее дерево
    local ok, err = pcall(BuildTreeCanvas, f, P11.Tree.fac)
    if not ok then print("[POLUS][ERROR] древо: " .. tostring(err)) end

    -- откат
    local reset = vgui.Create("DButton", f)
    reset:SetPos(14, 590) reset:SetSize(852, 46) reset:SetText("")
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
    end
end

print("[POLUS-11] ДРЕВО СЛУЖБЫ (client) v4.27.1 «СЕКАТОР»: ветви без наложений + чистые карточки узлов")
