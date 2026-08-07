-- ============================================================
--  ПОЛЮС-11 — ТАБ v2 «СОСТАВ СТАНЦИИ» (v4.2.1, написан с нуля)
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

    local cy = y + ROW_H / 2

    -- имя (+суффиксы) — v4.8.0: с усечением под колонку РАНГ;
    -- чип ранга рядом с ником убран: теперь у ранга СВОЯ колонка
    local nx = x + 12
    local nameCol = d.alive and COL_TXT or COL_DEAD
    local niceName = FitText(d.name, "P11B.Text", X_RANK - 26)
    draw.SimpleText(niceName, "P11B.Text", nx, cy, nameCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    surface.SetFont("P11B.Text")
    local wN = surface.GetTextSize(niceName) or 0
    local marked = tostring(niceName)
    local marks = ""
    if not d.alive then marks = marks .. " †" end
    if d.muted then marks = marks .. " 🔇" end
    if P11B.amAdmin and d.disguised then marks = marks .. "  (наст.: " .. d.real .. ")" end
    if P11B.amAdmin and d.infected then marks = marks .. " ☣" end
    if marks ~= "" then
        draw.SimpleText(marks, "P11B.Tiny", nx + wN + 6, cy, Color(150, 160, 175, 190), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
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
    local yy = topY - (P11B.scroll or 0)
    for _, g in ipairs(P11B.groups) do
        -- шапка фракции
        if yy > topY - CAT_H - 8 and yy < topY + viewH then
            local c = g.color or COL_GREY
            draw.RoundedBox(3, x, yy, W, CAT_H, Color(c.r, c.g, c.b, 28))
            draw.RoundedBoxEx(3, x, yy, W, 2, Color(c.r, c.g, c.b, 185), true, true, false, false)
            draw.SimpleText(tostring(g.name), "P11B.Small", x + 8, yy + CAT_H / 2 + 1, FaceColorOf(c), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
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

    -- шапка
    draw.SimpleText("СТАНЦИЯ «ПОЛЮС-11»", "P11B.Title", x + 16, y + 10, COL_TXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText("MILITARY HORROR RP · 1982 · v" .. tostring(POLUS_BUILD or "?"), "P11B.Tiny", x + 18, y + 40, Color(120, 160, 190, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText(tostring(P11B.online or ""), "P11B.Small", x + W - 16, y + 14, Color(170, 178, 195), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    draw.SimpleText(os.date("%H:%M") .. "  ·  " .. game.GetMap(), "P11B.Tiny", x + W - 16, y + 40, COL_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    -- v4.6.6: наигрыш службы — время открывает профы
    local me2 = LocalPlayer()
    if IsValid(me2) then
        draw.SimpleText("⏱ служба: " .. me2:GetNWInt("P11_PlayMin", 0) .. " мин — время открывает профы",
            "P11B.Tiny", x + 18, y + 56, Color(150, 200, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    -- статус станции
    local status = "Фаза: " .. GetGlobalString("P11_Phase", "?")
    local shift = GetGlobalString("P11_Shift", "")
    if shift ~= "" then status = status .. "    ☾ " .. shift end
    if GetGlobalBool("P11_Blackout", false) then status = status .. "    ⚠ АВАРИЯ ЭНЕРГОСИСТЕМЫ" end
    if GetGlobalBool("P11_Storm", false) then status = status .. "    ❄ МАГНИТНАЯ БУРЯ" end
    draw.SimpleText(status, "P11B.Small", x + 16, y + 62, Color(255, 190, 90), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

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
    draw.SimpleText("F1 — памятка · F4 — должности · F6 — поддержка · /досье — НКВД · C (удерж.) — действия", "P11B.Tiny",
        x + W - 12, y + H - footH / 2, COL_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

-- ================= ХУКИ =================

hook.Add("ScoreboardShow", "P11.Board", function()
    if DarkRP then return end
    if POLUS11 and POLUS11.Config and POLUS11.Config.CustomScoreboard == false then return end
    P11B.open   = true
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

print("[POLUS-11] TAB v2.1 загружен (колонка РАНГ для всех — v4.8.0)")
