-- ============================================================
--  ПОЛЮС-11 — ТАБ v3 «СОСТАВ СТАНЦИИ» → v5.2.3 КОПИЯ-Новый файл
--  Отличие от оригинала: дежурство в колонке должности (v4.26.0 «СИЯНИЕ», написан с нуля)
--  Старый модуль p11_cl_scoreboard.lua УДАЛЁН полностью.
--
--  Почему он больше НЕ МОЖЕТ уронить клиент:
--   • НОЛЬ vgui-панелей. Табло рисуется напрямую draw/surface из
--     HUDPaint — некому протекать, нечему умирать в Paint-замыканиях,
--     нет сотен создаваемых/удаляемых панелей каждую секунду.
--   • Данные об игроках снимаются СНИМКОМ раз в 0.4 с; каждый игрок
--     — в собственном pcall: «гнилой» игрок просто пропускается,
--     остальной список рисуется.
--   • Вся отрисовка — одна pcall с авто-гасителем: после 3 сбоев
--     табло тихо закрывается. Игра не падает НИКОГДА.
--   • Страж зависания: отпустил TAB — табло само закроется, даже если
--     событие ScoreboardHide потерялось.
--  Показывает: фракции и должности, ★звания смены, коды документов,
--  розыск, мут, статус станции; украденные Нечто личности видны
--  всем как НАСТОЯЩИЕ (имя/должность/код документа жертвы), а
--  админам дополнительно подписывается настоящий ник — как и было.
-- ============================================================

surface.CreateFont("P11B.Title", { font = "Roboto", size = 26, weight = 800, extended = true })
surface.CreateFont("P11B.Mid",   { font = "Roboto", size = 16, weight = 700, extended = true })
surface.CreateFont("P11B.Text",  { font = "Roboto", size = 16, weight = 500, extended = true })
surface.CreateFont("P11B.Small", { font = "Roboto", size = 14, weight = 500, extended = true })
surface.CreateFont("P11B.Tiny",  { font = "Roboto", size = 12, weight = 500, extended = true })

P11B = P11B or {
    open = false, fails = 0, t = 0,
    groups = {}, scroll = 0, openT = 0,
    online = "…", amAdmin = false, fakeN = nil, fakeT = 0,
}

local COL_TXT  = Color(236, 239, 245)
local COL_GREY = Color(150, 156, 172)
local COL_DIM  = Color(106, 113, 128)
local COL_DEAD = Color(170, 136, 136)
local COL_GOLD = Color(255, 205, 100)

local BG    = Color(12, 15, 20, 238)
local HEAD  = Color(24, 29, 38, 255)
local ROW_A = Color(38, 43, 54, 208)
local ROW_M = Color(52, 60, 74, 230) -- моя строка
local ROW_D = Color(56, 34, 38, 214) -- мёртвый

local ROW_H, CAT_H = 26, 24

local function CloseBoard()
    if not P11B.open then return end
    P11B.open = false
    gui.EnableScreenClicker(false)
end

-- ================= СНИМОК ДАННЫХ (раз в 0.4 с) =================

local function RowOf(ply) -- вызывается под pcall: сбой = игрок пропущен
    if not IsValid(ply) or not ply.Team then return nil end

    local d = {}
    d.me    = (ply == LocalPlayer())
    d.alive = ply:Alive() and true or false

    local real = tostring(ply:Nick() or "?")
    local name = ply:GetNWString("P11_FakeNick", "")
    if name == "" then name = ply:GetNWString("P11_CharName", "") end -- v4.3.0: позывной
    if name == "" then name = real end
    d.name      = tostring(name)
    d.lname     = string.lower(d.name)
    d.real      = real
    d.disguised = (ply:GetNWString("P11_FakeNick", "") ~= "")

    d.wanted   = ply:GetNWString("P11_Wanted", "")
    d.muted    = ply:GetNWBool("P11FW_Muted", false)
    d.infected = ply:GetNWBool("P11_Infected", false)
    d.title    = ply:GetNWString("P11_Title", "")
    d.doc      = ply:GetNWString("P11_DocCode", "") -- у нечто здесь УКРАДЕННЫЙ код
    d.ping     = tonumber(ply:Ping()) or 0

    -- v4.8.0: ранг нужен в колонке РАНГ ВСЕМ — «User» серым, «VIP» золотом,
    -- «Moderator» и выше — родными цветами с переливом (раньше рисовался
    -- только с level 2 чипом рядом с ником, а обычные не видели свой User).
    d.ply = ply
    d.rank, d.rankName, d.rankCol, d.rankFx = 0, "User", COL_GREY, false
    if P11FW and P11FW.GetRankLevel then
        d.rank = tonumber(P11FW.GetRankLevel(ply)) or 0
        if P11FW.GetRankName then d.rankName = tostring(P11FW.GetRankName(ply) or "User") end
        local rc = P11FW.GetRankColor and P11FW.GetRankColor(ply)
        if istable(rc) then d.rankCol = rc end
        d.rankFx = (P11FW.RankHasFx and P11FW.RankHasFx(ply)) and true or false
    end

    -- должность: у нечто в чужой шкуре — УКРАДЕННАЯ (P11_FakeJob)
    local jobTab = nil
    local fj = ply:GetNWInt("P11_FakeJob", 0)
    if fj > 0 and P11FW and P11FW.TeamJobs then
        local jid = P11FW.TeamJobs[fj]
        if jid then jobTab = P11FW.Jobs[jid] end
    end
    if not jobTab and P11FW and P11FW.GetJob then jobTab = P11FW.GetJob(ply) end
    d.job  = (jobTab and jobTab.name) or ""
    d.fact = (jobTab and (jobTab.faction or jobTab.category)) or "misc"

    -- цвет левой кромки: должность (украденная при маскировке), иначе команда
    local c2 = (jobTab and jobTab.color) or nil
    if not istable(c2) then
        local tm = team.GetAllTeams()[ply:Team() or 0]
        c2 = (tm and tm.Color) or COL_GREY
    end
    d.col = Color(c2.r, c2.g, c2.b) -- свежий объект цвета — сюрпризы исключены

    return d
end

local function SortRows(t)
    table.sort(t, function(a, b)
        if a.rank ~= b.rank then return a.rank > b.rank end
        return a.lname < b.lname
    end)
end

local function Rebuild()
    local rows = {}
    for _, p in ipairs(player.GetAll()) do
        local ok, d = pcall(RowOf, p)
        if ok and d then rows[#rows + 1] = d end
    end

    -- группы по фракциям, порядок из P11FW.CategoryList
    local byId, groups = {}, {}
    local cats = (P11FW and P11FW.CategoryList) or nil
    if istable(cats) then
        for _, cat in ipairs(cats) do
            local g = {
                name  = tostring(cat.name or "—"),
                color = (istable(cat.color) and cat.color) or COL_GREY,
                rows  = {},
            }
            byId[cat.id] = g
            groups[#groups + 1] = g
        end
    end
    local misc = { name = "ПРОЧИЕ", color = COL_GREY, rows = {} }

    for _, d in ipairs(rows) do
        local g = byId[d.fact] or misc
        g.rows[#g.rows + 1] = d
    end

    local out = {}
    for _, g in ipairs(groups) do
        if #g.rows > 0 then SortRows(g.rows); out[#out + 1] = g end
    end
    if #misc.rows > 0 then SortRows(misc.rows); out[#out + 1] = misc end

    -- запасной вариант: фреймворк не отдал фракции — плоский список
    if #out == 0 and #rows > 0 then
        SortRows(rows)
        out = { { name = "СОСТАВ СТАНЦИИ", color = COL_GREY, rows = rows } }
    end

    P11B.groups = out
    P11B.t = CurTime()

    -- я — админ? (видеть настоящие ники и заражённых)
    local me = LocalPlayer()
    local amAdmin = IsValid(me) and (me:IsAdmin() or me:IsSuperAdmin())
    if not amAdmin and IsValid(me) and P11FW and P11FW.GetRankLevel then
        amAdmin = (tonumber(P11FW.GetRankLevel(me)) or 0) >= 2
    end
    if not amAdmin and IsValid(me) and POLUS11 and POLUS11.Config and POLUS11.Config.Admin then
        local ok, r = pcall(POLUS11.Config.Admin, me)
        if ok and r then amAdmin = true end
    end
    P11B.amAdmin = amAdmin and true or false

    -- счётчик онлайна (для рядовых — атмосферный «±»)
    local real = #rows
    local precise = P11B.amAdmin or (POLUS11 and POLUS11.Config and POLUS11.Config.FakeOnline == false)
    if precise then
        P11B.online = real .. " чел. на станции"
    else
        if P11B.fakeN == nil or CurTime() > (P11B.fakeT or 0) then
            P11B.fakeT = CurTime() + math.Rand(6, 13)
            P11B.fakeN = math.Clamp(real + math.random(-3, 3), math.max(1, real - 4), real + 5)
        end
        P11B.online = "~" .. P11B.fakeN .. " чел. на станции (±)"
    end
end

-- ================= ОТРИСОВКА =================

-- v4.8.0: табло шире (720), заведена отдельная колонка РАНГ
local X_NAME, X_RANK, X_JOB, X_DOC = 14, 252, 400, 572

local function FaceColorOf(c)
    return Color(c.r, c.g, c.b, 255)
end

-- v4.26.0 «СИЯНИЕ»: пятиконечная звезда полигоном (эмблема шапки табло)
local function P11BStar(cx, cy, r, col)
    local pts = {}
    for i = 1, 10 do
        local a = -math.pi / 2 + math.pi * (i - 1) / 5
        local rr = (i % 2 == 1) and r or r * 0.42
        pts[i] = { x = cx + math.cos(a) * rr, y = cy + math.sin(a) * rr }
    end
    draw.NoTexture()
    surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
    surface.DrawPoly(pts)
end

-- усечь строку под ширину с многоточием (имена не залезают на колонки)
local function FitText(txt, font, maxW)
    surface.SetFont(font)
    local w = surface.GetTextSize(txt) or 0
    if w <= maxW then return txt end
    txt = tostring(txt)
    local t = txt
    while #t > 1 do
        t = string.sub(t, 1, #t - 1)
        surface.SetFont(font)
        if (surface.GetTextSize(t .. "…") or 0) <= maxW then return t .. "…" end
    end
    return t .. "…"
end

local function DrawRow(d, x, y, W)
    local base = ROW_A
    if not d.alive then base = ROW_D elseif d.me then base = ROW_M end
    draw.RoundedBox(4, x, y, W, ROW_H, base)
    draw.RoundedBoxEx(4, x, y, 4, ROW_H, FaceColorOf(d.col), true, false, true, false)
    surface.SetDrawColor(255, 255, 255, 6)
    surface.DrawRect(x + 4, y, W - 4, 1)
    -- v4.26.0: курсор подсвечивает строку, СВОЯ строка — морозная рамка
    local mx, my = gui.MouseX(), gui.MouseY()
    if mx >= x and mx <= x + W and my >= y and my <= y + ROW_H then
        draw.RoundedBox(4, x, y, W, ROW_H, Color(255, 255, 255, 13))
    end
    if d.me then
        surface.SetDrawColor(150, 210, 250, 62 + 40 * math.sin(CurTime() * 2.8))
        surface.DrawOutlinedRect(x, y, W, ROW_H, 1)
    end

    local cy = y + ROW_H / 2

    -- имя (+суффиксы) — v4.8.0: с усечением под колонку РАНГ;
    -- чип ранга рядом с ником убран: теперь у ранга СВОЯ колонка
    local nx = x + 12
    local nameCol = d.alive and COL_TXT or COL_DEAD
    -- v4.27.0 «ОРДЕН»: лента медалей фишками — считаем ДО имени (имя под неё ужмём)
    local mCells, mTotal, mRibbonW = nil, 0, 0
    if IsValid(d.ply) and P11 and P11.MedalCells then
        local okM, cells, total = pcall(P11.MedalCells, d.ply, 4)
        if okM and cells and #cells > 0 then
            mCells, mTotal = cells, total
            local nch = #cells + ((total > #cells) and 1 or 0)
            mRibbonW = nch * 20 - 2
        end
    end
    local niceName = FitText(d.name, "P11B.Text",
        X_RANK - 26 - (mRibbonW > 0 and (mRibbonW + 8) or 0))
    draw.SimpleText(niceName, "P11B.Text", nx, cy, nameCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    surface.SetFont("P11B.Text")
    local wN = surface.GetTextSize(niceName) or 0
    local marked = tostring(niceName)
    local marks = ""
    if not d.alive then marks = marks .. " †" end
    if d.muted then marks = marks .. " 🔇" end
    -- v4.18.1 «ГРИМ» (заявка с фото «(наст.: …) в табе»): суффикс настоящего
    -- ника при маскировке ВЫРЕЗАН из табло — легенда «ЛЕГАТ»/«ОБСЛУГА»/
    -- личина больше не палится прямо в TAB ни у кого. Шпионское зеркало
    -- осталось только в консольном p11_spies (Глава, ранг 16) — по запросу,
    -- а не на всеобщем обозрении.
    if P11B.amAdmin and d.infected then marks = marks .. " ☣" end
    local mx = nx + wN + 6
    if marks ~= "" then
        draw.SimpleText(marks, "P11B.Tiny", mx, cy, Color(150, 160, 175, 190), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetFont("P11B.Tiny")
        mx = mx + (surface.GetTextSize(marks) or 0) + 5
    end
    -- v4.27.0 «ОРДЕН»: ЛЕНТА МЕДАЛЕЙ — цветные фишки у края колонки ИГРОК,
    -- наведение на строку показывает тултип «наградная колодка»
    if mCells then
        local rx = x + X_RANK - 8
        local nch = #mCells + ((mTotal > #mCells) and 1 or 0)
        local lx = rx - (nch * 20 - 2)
        for i, c in ipairs(mCells) do
            local bx = lx + (i - 1) * 20
            draw.RoundedBox(4, bx, cy - 8, 18, 16, Color(c.col.r, c.col.g, c.col.b, 34))
            draw.RoundedBoxEx(4, bx, cy - 8, 18, 2, Color(c.col.r, c.col.g, c.col.b, 200), true, true, false, false)
            surface.SetDrawColor(c.col.r, c.col.g, c.col.b, 110 + 35 * math.sin(CurTime() * 2.6 + i * 1.3))
            surface.DrawOutlinedRect(bx, cy - 8, 18, 16, 1)
            draw.SimpleText(c.g, "P11B.Tiny", bx + 9, cy + 1, c.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        if mTotal > #mCells then
            local bx = lx + #mCells * 20
            draw.RoundedBox(4, bx, cy - 8, 18, 16, Color(255, 205, 100, 26))
            draw.SimpleText("+" .. (mTotal - #mCells), "P11B.Tiny", bx + 9, cy + 1,
                Color(255, 205, 100, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        -- курсор на этой строке → тултип нарисуем после списка
        if mx >= x and mx <= x + W and my >= y and my <= y + ROW_H then
            P11B.tip = { cells = mCells, total = mTotal }
        end
    end

    -- колонка РАНГ (v4.8.0): от User до Главы, цвет ранга + перелив у высших
    local rc = d.rankCol
    if d.rankFx and IsValid(d.ply) and P11FW and P11FW.RankFxColor then
        local okFx, cfx = pcall(P11FW.RankFxColor, d.ply)
        if okFx and istable(cfx) then rc = cfx end
    elseif d.rankFx then
        local p2 = 0.55 + math.sin(CurTime() * 2.6) * 0.45
        rc = Color(
            math.min(255, d.rankCol.r + math.floor(70 * p2)),
            math.min(255, d.rankCol.g + math.floor(70 * p2)),
            math.min(255, d.rankCol.b + math.floor(70 * p2)))
    end
    draw.SimpleText(FitText(d.rankName, "P11B.Small", X_JOB - X_RANK - 12), "P11B.Small",
        x + X_RANK, cy, rc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- должность + ★звание смены
    local jobStr = d.job
    local jobCol = Color(152, 158, 172, 215)
    if d.title ~= "" then
        jobStr = "★" .. d.title .. " · " .. jobStr
        jobCol = COL_GOLD
    end
    -- v5.2.3 «ДЕЖУРСТВО»: пост в колонке должности (золотая 🛡-плашка)
    if IsValid(d.ply) then
        local dutyId = d.ply:GetNWString("P11_DutyLoc", "")
        if dutyId ~= "" and P11 and P11.DutyName then
            local dn = P11.DutyName(dutyId)
            jobStr = "🛡 " .. dn .. (jobStr ~= "" and (" · " .. jobStr) or "")
            jobCol = Color(255, 200, 120, 235)
        end
    end
    if jobStr ~= "" then
        draw.SimpleText(jobStr, "P11B.Small", x + X_JOB, cy, jobCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- код документа (украденный — у нечто)
    if d.doc ~= "" then
        draw.SimpleText(d.doc, "P11B.Tiny", x + X_DOC, cy, Color(196, 186, 150, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- розыск мигает
    if d.wanted ~= "" then
        local blink = 0.5 + math.sin(CurTime() * 6) * 0.5
        draw.SimpleText("⚠ РОЗЫСК", "P11B.Tiny", x + W - 58, cy,
            Color(255, 90, 80, 140 + 115 * blink), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    -- пинг
    local pc = COL_GREY
    if d.ping > 150 then pc = Color(235, 120, 110) elseif d.ping > 80 then pc = Color(235, 190, 110) else pc = Color(150, 200, 150) end
    draw.SimpleText(tostring(d.ping), "P11B.Small", x + W - 14, cy, pc, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

local function DrawRowsClip(x, topY, W, viewH)
    P11B.hit = {} -- v4.17.0: кликабельные прямоугольники строк (мини-меню игрока)
    local yy = topY - (P11B.scroll or 0)
    for _, g in ipairs(P11B.groups) do
        -- шапка фракции
        if yy > topY - CAT_H - 8 and yy < topY + viewH then
            local c = g.color or COL_GREY
            draw.RoundedBox(3, x, yy, W, CAT_H, Color(c.r, c.g, c.b, 28))
            draw.RoundedBoxEx(3, x, yy, W, 2, Color(c.r, c.g, c.b, 185), true, true, false, false)
            draw.SimpleText("▾ " .. tostring(g.name), "P11B.Small", x + 8, yy + CAT_H / 2 + 1, FaceColorOf(c), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(#g.rows .. " чел.", "P11B.Tiny", x + W - 8, yy + CAT_H / 2 + 1, COL_GREY, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        yy = yy + CAT_H + 4

        for _, d in ipairs(g.rows) do
            if yy > topY - ROW_H and yy < topY + viewH then
                local ok, err = pcall(DrawRow, d, x, yy, W)
                if not ok then
                    -- одна «битая» строка — серый пропуск, табло живёт дальше
                    draw.RoundedBox(4, x, yy, W, ROW_H, Color(40, 42, 50, 150))
                end
                if IsValid(d.ply) then -- v4.17.0: строка кликается → мини-меню
                    P11B.hit[#P11B.hit + 1] = { x = x, y = yy, w = W, h = ROW_H, d = d }
                end
            end
            yy = yy + ROW_H + 2
        end
        yy = yy + 6
    end
    return yy -- нижняя граница контента (для скролла)
end

local function DrawBoard()
    -- снимок не чаще 2.5 раз в секунду; сбой снимка НЕ ломает табло
    if CurTime() - (P11B.t or 0) > 0.4 then
        local ok, err = pcall(Rebuild)
        if not ok then print("[POLUS][WARN] TAB v2 снимок: " .. tostring(err)) end
    end

    local W = math.min(720, ScrW() - 40) -- v4.8.0: шире под колонку РАНГ
    local H = math.floor(ScrH() * 0.85)
    local x = math.floor((ScrW() - W) / 2)
    local y = math.floor((ScrH() - H) / 2) - 26
    if y < 8 then y = 8 end

    -- затемнение сцены — список читается на любом фоне
    surface.SetDrawColor(5, 7, 10, 130)
    surface.DrawRect(0, 0, ScrW(), ScrH())

    -- корпус
    draw.RoundedBox(10, x, y, W, H, BG)
    draw.RoundedBoxEx(10, x, y, W, 58, HEAD, true, true, false, false)

    -- морозная линия шапки
    local glow = 120 + math.sin(CurTime() * 1.6) * 40
    surface.SetDrawColor(120, 190, 230, glow)
    surface.DrawRect(x, y + 57, W, 1)

    -- шапка: v4.26.0 — эмблема кольца радара + красная звезда
    local ex, ey = x + 30, y + 25
    surface.DrawCircle(ex, ey, 16, 120, 190, 230, 145)
    local ra2 = CurTime() * 1.6
    surface.SetDrawColor(120, 190, 230, 95)
    surface.DrawLine(ex, ey, ex + math.cos(ra2) * 15, ey + math.sin(ra2) * 15)
    P11BStar(ex, ey, 6.5, Color(238, 108, 92))
    draw.SimpleText("СТАНЦИЯ «ПОЛЮС-11»", "P11B.Title", x + 56, y + 10, COL_TXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText("MILITARY HORROR RP · 1982 · v" .. tostring(POLUS_BUILD or "?"), "P11B.Tiny", x + 58, y + 40, Color(120, 160, 190, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText(tostring(P11B.online or ""), "P11B.Small", x + W - 16, y + 14, Color(170, 178, 195), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    draw.SimpleText(os.date("%H:%M") .. "  ·  " .. game.GetMap(), "P11B.Tiny", x + W - 16, y + 40, COL_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    -- v4.19.4 «ПОЧЁТ»: ДОСКА ПОЧЁТА — топ-3 по медалям прямо в шапке ТАБа
    if P11 and P11.MedalTop then
        local okT, top = pcall(P11.MedalTop, 3)
        if okT and top and #top > 0 then
            local parts = {}
            for i, t in ipairs(top) do
                parts[#parts + 1] = "★" .. t.name .. " ×" .. t.n
            end
            draw.SimpleText("ДОСКА ПОЧЁТА: " .. table.concat(parts, "  ·  "), "P11B.Tiny",
                x + W - 16, y + 56, COL_GOLD, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end
    end
    -- v4.6.6: наигрыш службы — время открывает профы
    local me2 = LocalPlayer()
    if IsValid(me2) then
        draw.SimpleText("⏱ служба: " .. me2:GetNWInt("P11_PlayMin", 0) .. " мин — время открывает профы",
            "P11B.Tiny", x + 18, y + 56, Color(150, 200, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    -- статус станции: v4.26.0 — ЧИПЫ состояний (авария мигает)
    local chips = {}
    chips[#chips + 1] = { t = "ФАЗА: " .. GetGlobalString("P11_Phase", "?"), col = Color(255, 190, 90), blink = false }
    local shift = GetGlobalString("P11_Shift", "")
    if shift ~= "" then chips[#chips + 1] = { t = "☾ " .. shift, col = Color(150, 200, 255), blink = false } end
    if GetGlobalBool("P11_Blackout", false) then chips[#chips + 1] = { t = "⚠ АВАРИЯ ЭНЕРГОСИСТЕМЫ", col = Color(255, 95, 85), blink = true } end
    if GetGlobalBool("P11_Storm", false) then chips[#chips + 1] = { t = "❄ МАГНИТНАЯ БУРЯ", col = Color(160, 210, 255), blink = false } end
    local cx2 = x + 16
    for _, ch in ipairs(chips) do
        surface.SetFont("P11B.Small")
        local tw2 = surface.GetTextSize(ch.t)
        local ka = ch.blink and (0.55 + math.sin(CurTime() * 5) * 0.45) or 1
        draw.RoundedBox(10, cx2, y + 60, tw2 + 20, 20, Color(ch.col.r, ch.col.g, ch.col.b, 26 * ka))
        surface.SetDrawColor(ch.col.r, ch.col.g, ch.col.b, 120 * ka)
        surface.DrawOutlinedRect(cx2, y + 60, tw2 + 20, 20, 1)
        draw.SimpleText(ch.t, "P11B.Small", cx2 + 10, y + 70,
            Color(ch.col.r, ch.col.g, ch.col.b, 160 + 95 * ka), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        cx2 = cx2 + tw2 + 28
    end

    -- заголовок колонок
    local colY = y + 84
    draw.SimpleText("ИГРОК", "P11B.Tiny", x + X_NAME + 2, colY, COL_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText("РАНГ", "P11B.Tiny", x + X_RANK, colY, COL_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP) -- v4.8.0
    draw.SimpleText("ДОЛЖНОСТЬ / ЗВАНИЕ СМЕНЫ", "P11B.Tiny", x + X_JOB, colY, COL_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText("ДОКУМЕНТ", "P11B.Tiny", x + X_DOC, colY, COL_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText("ПИНГ", "P11B.Tiny", x + W - 14, colY, COL_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    -- область списка (со скроллом колесом)
    local topY  = colY + 18
    local footH = 30
    local viewH = H - (topY - y) - footH

    render.SetScissorRect(x, topY, x + W, topY + viewH, true)
    local ok2, yy2 = pcall(DrawRowsClip, x + 4, topY + 2, W - 8, viewH)
    render.SetScissorRect(0, 0, 0, 0, false)

    -- v4.27.0 «ОРДЕН»: ТУЛТИП медалей под курсором (список знаков с расшифровкой)
    if P11B.tip then
        local tip = P11B.tip
        P11B.tip = nil
        local rows = {}
        for i = 1, math.min(#tip.cells, 6) do rows[#rows + 1] = tip.cells[i] end
        local tw = 236
        local th = 30 + #rows * 30 + ((tip.total > #rows) and 16 or 0) + 6
        local tx = math.Clamp(gui.MouseX() + 16, 4, ScrW() - tw - 4)
        local ty = math.Clamp(gui.MouseY() + 14, 4, ScrH() - th - 4)
        draw.RoundedBox(8, tx, ty, tw, th, Color(10, 14, 20, 248))
        surface.SetDrawColor(255, 205, 100, 150)
        surface.DrawOutlinedRect(tx, ty, tw, th, 1)
        draw.SimpleText("★ НАГРАДНАЯ КОЛОДКА", "P11B.Tiny", tx + 10, ty + 7,
            Color(255, 205, 100, 230), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        local tyy = ty + 22
        for _, c in ipairs(rows) do
            draw.RoundedBox(4, tx + 8, tyy, 20, 20, Color(c.col.r, c.col.g, c.col.b, 40))
            surface.SetDrawColor(c.col.r, c.col.g, c.col.b, 145)
            surface.DrawOutlinedRect(tx + 8, tyy, 20, 20, 1)
            draw.SimpleText(c.g, "P11B.Small", tx + 18, tyy + 10, c.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(FitText(c.name, "P11B.Small", tw - 62), "P11B.Small",
                tx + 36, tyy + 3, Color(235, 240, 248), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            if c.desc ~= "" then
                draw.SimpleText(FitText(c.desc, "P11B.Tiny", tw - 62), "P11B.Tiny",
                    tx + 36, tyy + 17, Color(150, 160, 175), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
            tyy = tyy + 30
        end
        if tip.total > #rows then
            draw.SimpleText("+ ещё " .. (tip.total - #rows), "P11B.Tiny", tx + 36, tyy + 2,
                Color(255, 205, 100, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end

    -- границы скролла + подсказка
    if ok2 and yy2 then
        local contentH = (yy2 - topY)
        local maxScroll = math.max(0, contentH - viewH)
        P11B.scroll = math.Clamp(P11B.scroll or 0, 0, maxScroll)
        if maxScroll > 0 then
            draw.SimpleText("▼ колесо — листать ▼", "P11B.Tiny", x + W / 2, topY + viewH - 2,
                Color(120, 160, 190, 130), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        end
    end

    -- футер
    draw.RoundedBoxEx(10, x, y + H - footH, W, footH, HEAD, false, false, true, true)
    local me = LocalPlayer()
    local myName = IsValid(me) and tostring(me:Nick() or "?") or "?"
    local myJob = ""
    if IsValid(me) and P11FW and P11FW.GetJobName then
        local okJ, jn = pcall(P11FW.GetJobName, me)
        if okJ and isstring(jn) then myJob = jn end
    end
    draw.SimpleText(myName .. (myJob ~= "" and (" · " .. myJob) or ""), "P11B.Tiny", x + 12, y + H - footH / 2, COL_GREY, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    -- v4.26.0: сводка состава по центру футера
    local totalP, totalG = 0, #P11B.groups
    for _, g in ipairs(P11B.groups) do totalP = totalP + #g.rows end
    draw.SimpleText("фракций: " .. totalG .. "  ·  бойцов: " .. totalP, "P11B.Tiny",
        x + W / 2, y + H - footH / 2, COL_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText("F1 — памятка · F4 — должности · F6 — поддержка · /досье — НКВД · C (удерж.) — действия", "P11B.Tiny",
        x + W - 12, y + H - footH / 2, COL_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

-- ================= ХУКИ =================

hook.Add("ScoreboardShow", "P11.Board", function()
    if DarkRP then return end
    if POLUS11 and POLUS11.Config and POLUS11.Config.CustomScoreboard == false then return end
    P11B.open   = true
    -- v4.31.0 «КРЫЛО»: пересинк медалей при каждом открытии TAB (act 9 —
    -- сервер шлёт свежий реестр; страховка от пустых лент/планки)
    net.Start("P11_MedalAct")
        net.WriteUInt(9, 4)
    net.SendToServer()
    P11B.fails  = 0
    P11B.scroll = 0
    P11B.openT  = CurTime()
    P11B.t      = 0 -- форсировать снимок на первом же кадре
    POLUS11.Scoreboard = nil -- v4.2.1: vgui-панели больше нет
    gui.EnableScreenClicker(true)
    surface.PlaySound("ui/buttonclickrelease.wav")
end)

hook.Add("ScoreboardHide", "P11.Board", function()
    CloseBoard()
end)

hook.Add("HUDPaint", "P11.Board", function()
    if not P11B.open then return end

    -- страж зависания: TAB отпущен, а ScoreboardHide не дошёл — закрыть самим
    if CurTime() - (P11B.openT or 0) > 0.7 and not input.IsKeyDown(KEY_TAB) then
        CloseBoard()
        return
    end

    if (P11B.fails or 0) >= 3 then return end
    local ok, err = pcall(DrawBoard)
    if not ok then
        P11B.fails = (P11B.fails or 0) + 1
        print("[POLUS][ERROR] TAB v2 отрисовка (x" .. P11B.fails .. "): " .. tostring(err))
        if P11B.fails >= 3 then CloseBoard() end
    end
end)

-- колесо мыши — скролл, пока таб открыт
hook.Add("PlayerBindPress", "P11.BoardWheel", function(ply, bind, pressed)
    if not P11B.open then return end
    if not pressed then return end
    if bind == "invnext" then
        P11B.scroll = (P11B.scroll or 0) + (ROW_H + 2) * 3
        return true
    elseif bind == "invprev" then
        P11B.scroll = math.max(0, (P11B.scroll or 0) - (ROW_H + 2) * 3)
        return true
    end
end)

-- килл-лента палит настоящие ники — прячем, если так настроено
hook.Add("DrawDeathNotice", "P11.BoardFeed", function()
    if POLUS11 and POLUS11.Config and POLUS11.Config.HideKillFeed then
        return true
    end
end)

-- ================= ЧАТ: НЕЧТО ГОВОРИТ ГОЛОСОМ ЖЕРТВЫ =================
-- (перенесено из p11_cl_hud: старая версия могла упасть на nil-цвете
--  команды; здесь всё под pcall и цвет — от УКРАДЕННОЙ должности)

hook.Add("OnPlayerChat", "P11.BoardChat", function(ply, text)
    if DarkRP then return end -- в DarkRP имя подменяется через rpname
    if not IsValid(ply) then return end

    local fake = ply:GetNWString("P11_FakeNick", "")
    if fake == "" then return end

    local col = Color(210, 190, 190)
    pcall(function()
        local jobTab = nil
        local fj = ply:GetNWInt("P11_FakeJob", 0)
        if fj > 0 and P11FW and P11FW.TeamJobs then
            local jid = P11FW.TeamJobs[fj]
            if jid then jobTab = P11FW.Jobs[jid] end
        end
        if not jobTab and P11FW and P11FW.GetJob then jobTab = P11FW.GetJob(ply) end
        if jobTab and istable(jobTab.color) then
            col = jobTab.color
        else
            local tc = team.GetColor(ply:Team())
            if istable(tc) then col = tc end
        end
    end)

    chat.AddText(col, fake, Color(255, 255, 255), ": " .. tostring(text or ""))
    return true
end)

print("[POLUS-11] TAB v3 «СИЯНИЕ» загружен (эмблема, статус-чипы, ховер строк — v4.26.0)")

-- ============================================================
--  v4.17.0 «КОНТРАБАНДА» — МИНИ-МЕНЮ ИГРОКА В ТАБе
--  (заявка: «при нажатии на игрока в ТАБ открывалась мини-менюшка:
--  открыть стим-профиль, скопировать SteamID, ник и стим-ник»).
--  Курсор у табло уже есть (кликер включён при открытии), поэтому
--  работаем ручным хит-тестом по запомненным строкам — vgui-строкам
--  в нулевом табло взяться неоткуда.
-- ============================================================

surface.CreateFont("P11B.MiniT", { font = "Roboto", size = 18, weight = 800, extended = true })
surface.CreateFont("P11B.Mini",  { font = "Roboto", size = 15, weight = 600, extended = true })

local function CloseMini()
    if IsValid(P11B.mini) then P11B.mini:Remove() end
    P11B.mini = nil
end

local function MiniBtn(f, y, label, col, fn)
    local b = vgui.Create("DButton", f)
    b:SetPos(10, y) b:SetSize(260, 30)
    b:SetText("")
    b.Paint = function(s2, w, h)
        draw.RoundedBox(6, 0, 0, w, h,
            s2:IsHovered() and Color(col.r, col.g, col.b, 245) or Color(24, 32, 44, 235))
        surface.SetDrawColor(col.r, col.g, col.b, 160)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(label, "P11B.Mini", w / 2, h / 2 - 1, Color(228, 236, 245),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    b.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        fn()
    end
    return b
end

local function MiniNote(txt)
    chat.AddText(Color(120, 185, 255), "[TAB] ", Color(232, 238, 245), txt)
end

local function OpenPlayerMini(d)
    if not (d and IsValid(d.ply)) then return end
    local ply = d.ply
    CloseMini()

    -- v4.31.0 «КРЫЛО»: НАГРАДНАЯ КАРТОЧКА ПОД БОЙЦОМ — считаем медали
    -- ЗАРАНЕЕ: от их числа растёт высота окна (фишки-знаки + каждая
    -- медаль строкой «знак · название — за что»)
    local mCells, mTotal = {}, 0
    if P11 and P11.MedalCells then
        local okM, cells, total = pcall(P11.MedalCells, ply, 10)
        if okM and cells then mCells, mTotal = cells, total end
    end
    local medOff = 0
    if #mCells > 0 then
        medOff = (82 + #mCells * 15 + 10) - 94 -- низ списка − старая первая кнопка
    end
    local fH = 292 + math.max(0, medOff)

    local f = vgui.Create("DFrame")
    P11B.mini = f
    f:SetSize(280, fH)
    local mx, my = gui.MouseX(), gui.MouseY()
    f:SetPos(math.Clamp(mx + 10, 4, ScrW() - 292), math.Clamp(my + 10, 4, ScrH() - fH - 8))
    f:SetTitle("")
    f:ShowCloseButton(false)
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.OnRemove = function() if P11B.mini == f then P11B.mini = nil end end
    f.Think = function() -- табло ушло/игрок вышел — меню за ним
        if not P11B.open or not IsValid(ply) then f:Remove() end
    end
    f.Paint = function(s2, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(10, 14, 20, 248))
        surface.SetDrawColor(120, 185, 255, 170)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(FitText and FitText(d.name, "P11B.MiniT", 240) or d.name,
            "P11B.MiniT", 14, 12, Color(235, 240, 248), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText((d.job ~= "" and d.job or "без должности") .. " · " .. (IsValid(ply) and ply:SteamID() or "?"),
            "P11B.Mini", 14, 34, Color(150, 165, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        -- v4.31.0 «КРЫЛО»: НАГРАДНАЯ КОЛОДКА — фишки + полный список
        -- «знак · имя — за что» (до 10 знаков, счётчик медалей в заголовке)
        if #mCells > 0 then
            for i, c in ipairs(mCells) do
                local bx = 14 + (i - 1) * 22
                if bx > 250 then break end
                draw.RoundedBox(4, bx, 42, 20, 20, Color(c.col.r, c.col.g, c.col.b, 36))
                draw.RoundedBoxEx(4, bx, 42, 20, 3, Color(c.col.r, c.col.g, c.col.b, 190), true, true, false, false)
                surface.SetDrawColor(c.col.r, c.col.g, c.col.b, 150)
                surface.DrawOutlinedRect(bx, 42, 20, 20, 1)
                draw.SimpleText(c.g, "P11B.Mini", bx + 10, 52, c.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            draw.SimpleText("★ НАГРАДНАЯ КОЛОДКА · медалей: " .. mTotal, "P11B.Mini", 14, 66,
                Color(255, 205, 100, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            for i, c in ipairs(mCells) do
                local line = c.g .. " " .. c.name .. (c.desc ~= "" and (" — " .. c.desc) or "")
                draw.SimpleText(FitText and FitText(line, "P11B.Mini", 248) or line,
                    "P11B.Mini", 14, 82 + (i - 1) * 15,
                    Color(c.col.r, c.col.g, c.col.b, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
        else
            draw.SimpleText("медалей пока нет — грудь ждёт первую звезду", "P11B.Mini", 14, 66,
                Color(150, 160, 175, 190), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end

    MiniBtn(f, 94 + medOff, "Открыть Steam-профиль", Color(70, 120, 180), function()
        local id64 = ply:SteamID64()
        if isstring(id64) and id64 ~= "" and id64 ~= "0" then
            gui.OpenURL("https://steamcommunity.com/profiles/" .. id64)
            MiniNote("Открываю профиль: " .. d.real)
        else
            MiniNote("SteamID64 неизвестен (стим/бот) — профиль не открыть.")
        end
    end)
    MiniBtn(f, 130 + medOff, "Копировать SteamID", Color(90, 140, 200), function()
        SetClipboardText(tostring(ply:SteamID() or "?"))
        MiniNote("SteamID скопирован: " .. tostring(ply:SteamID()))
    end)
    MiniBtn(f, 166 + medOff, "Копировать ник (позывной)", Color(120, 165, 210), function()
        SetClipboardText(tostring(d.name))
        MiniNote("Ник скопирован: " .. tostring(d.name))
    end)
    MiniBtn(f, 202 + medOff, "Копировать Steam-ник", Color(150, 190, 220), function()
        SetClipboardText(tostring(d.real))
        MiniNote("Steam-ник скопирован: " .. tostring(d.real))
    end)
    -- v4.19.4 «ПОЧЁТ»: награда — если у меня есть право вручать
    local meL = LocalPlayer()
    local scopeL = (P11 and P11.MedalScopeLocal) and P11.MedalScopeLocal() or nil
    if scopeL == "full" or (scopeL == "dept" and IsValid(meL) and meL ~= ply) then
        MiniBtn(f, 238 + medOff, "★ Вручить медаль (ПОЧЁТ)", Color(190, 150, 55), function()
            if P11 and P11.MedalAwardMenu then
                P11.MedalAwardMenu(ply)
            end
        end)
    end
    MiniBtn(f, 256 + medOff, "Закрыть", Color(130, 60, 55), function()
        f:Remove()
    end)

    surface.PlaySound("buttons/button14.wav")
end

-- клик ЛКМ по строке табло → мини-меню (ручной хит-тест; клик по самой
-- менюшке строки не считаем — иначе она пересоздавалась бы на свои кнопки)
hook.Add("PlayerButtonDown", "P11.BoardClick", function(ply, btn)
    if btn ~= MOUSE_LEFT then return end
    if ply ~= LocalPlayer() then return end
    if not P11B.open then return end
    local mx, my = gui.MouseX(), gui.MouseY()
    if IsValid(P11B.mini) then
        local fx, fy = P11B.mini:GetPos()
        local fw, fh = P11B.mini:GetSize()
        if mx >= fx and mx <= fx + fw and my >= fy and my <= fy + fh then return end
    end
    for _, h in ipairs(P11B.hit or {}) do
        if mx >= h.x and mx <= h.x + h.w and my >= h.y and my <= h.y + h.h then
            OpenPlayerMini(h.d)
            return
        end
    end
end)

