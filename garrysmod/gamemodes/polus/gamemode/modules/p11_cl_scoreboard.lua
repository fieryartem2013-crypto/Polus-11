-- ============================================================
--  ПОЛЮС-11 — ТАБ «СОСТАВ СТАНЦИИ» v3.5 HOTFIX (Sandbox-режим)
--  v3.5: устранение «краша при взгляде в TAB».
--   Ошибки в Paint/Think-замыканиях раньше летели МИМО pcall
--   открытия окна — одна плохая строка (например, игрок ещё не
--   принял команду при коннекте, team.GetColor = nil) роняла
--   рендер каждый кадр. Теперь:
--   • все цвета/тексты получаются через безопасные хелперы;
--   • каждый Paint/Think обёрнут в pcall с kill-switch'ом:
--     первая же ошибка → панель переходит в «аварийную» отрисовку,
--     клиент не падает НИКОГДА; в консоль — один чистый лог.
-- ============================================================

surface.CreateFont("P11.SB.Title", {font = "Roboto", size = 26, weight = 700, extended = true})
surface.CreateFont("P11.SB.Text",  {font = "Roboto", size = 17, weight = 500, extended = true})
surface.CreateFont("P11.SB.Small", {font = "Roboto", size = 14, weight = 400, extended = true})
surface.CreateFont("P11.SB.Tiny",  {font = "Roboto", size = 12, weight = 500, extended = true})

local C_GREY  = Color(150, 155, 170)
local C_TEXT  = Color(238, 238, 242)
local C_DEAD  = Color(150, 130, 130)

-- ============ БЕЗОПАСНЫЕ ХЕЛПЕРЫ (v3.5) ============

local function Safe(f, fallback)
    local ok, res = pcall(f)
    if ok and res ~= nil then return res end
    return fallback
end

local function DisplayNick(ply)
    return Safe(function()
        if not IsValid(ply) then return "?" end
        local fake = ply:GetNWString("P11_FakeNick", "")
        if fake ~= "" then return fake end
        return ply:Nick() or "?"
    end, "?")
end

-- цвет команды игрока: НИКОГДА не nil, НИКОГДА не падает
-- (team.GetColor без записи/в момент коннекта бывал источником краша)
local function TeamColorOf(ply)
    return Safe(function()
        local idx = ply:Team()
        local tm = team.GetAllTeams()[idx]
        if tm and istable(tm.Color) then return tm.Color end
        return C_GREY
    end, C_GREY)
end

local function RankLevelOf(ply)
    return Safe(function()
        if P11FW and P11FW.GetRankLevel then
            return P11FW.GetRankLevel(ply) or 0
        end
        return 0
    end, 0)
end

local function RankNameOf(ply)
    return Safe(function()
        if P11FW and P11FW.GetRankName then return P11FW.GetRankName(ply) end
        return ""
    end, "")
end

local function RankColorOf(ply)
    return Safe(function()
        if P11FW and P11FW.GetRankColor then return P11FW.GetRankColor(ply) end
        return C_GREY
    end, C_GREY)
end

local function JobNameOf(ply)
    return Safe(function()
        if P11FW and P11FW.GetJobName then return P11FW.GetJobName(ply) or "" end
        return ""
    end, "")
end

local function CatColorOf(cat)
    return Safe(function()
        local c = cat and cat.color
        if istable(c) then return c end
        return C_GREY
    end, C_GREY)
end

-- kill-switch: чинит замыкание после первой ошибки (v3.5)
local function GuardedPanel(pnl, tag, paintFn)
    pnl.P11_Ok = true
    pnl.Paint = function(s, w, h)
        if not s.P11_Ok then
            draw.RoundedBox(4, 0, 0, w, h, Color(38, 41, 50, 140))
            return
        end
        local ok, err = pcall(paintFn, s, w, h)
        if not ok then
            s.P11_Ok = false
            print("[POLUS][ERROR] TAB paint[" .. tag .. "]: " .. tostring(err))
        end
    end
end

-- ============ «ПЛАВАЮЩИЙ» ОНЛАЙН ============
local FAKE = { n = nil, nextT = 0 }

local function OnlineCountText()
    return Safe(function()
        local real = 0
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) then real = real + 1 end
        end
        if real <= 0 then real = 1 end

        local me = LocalPlayer()
        local precise = IsValid(me) and (
            RankLevelOf(me) >= 2 or me:IsAdmin() or me:IsSuperAdmin()
        )
        if precise or POLUS11.Config.FakeOnline == false then
            return real .. " чел. на станции"
        end

        if FAKE.n == nil or CurTime() > FAKE.nextT then
            FAKE.nextT = CurTime() + math.Rand(6, 13)
            FAKE.n = math.max(1, real + math.random(-3, 3))
        end
        FAKE.n = math.Clamp(FAKE.n, math.max(1, real - 4), real + 5)
        return "~" .. FAKE.n .. " чел. на станции (±)"
    end, "… чел. на станции")
end

-- ============ СОРТИРОВКА: админы первыми, потом по имени ============

local function SortMembers(members)
    table.sort(members, function(a, b)
        local ra, rb = RankLevelOf(a), RankLevelOf(b)
        if ra ~= rb then return ra > rb end
        return string.lower(DisplayNick(a)) < string.lower(DisplayNick(b))
    end)
end

-- ============ СТРОКА ИГРОКА ============

local function MakeRow(frame, ply, amAdmin)
    -- всё, что может гнить, снимаем сразу и один раз (v3.5)
    local alive  = Safe(function() return ply:Alive() end, true)
    local tc     = TeamColorOf(ply)
    local nick   = DisplayNick(ply)
    local pingV  = Safe(function() return ply:Ping() end, 0)
    local wanted = Safe(function() return ply:GetNWString("P11_Wanted", "") or "" end, "")
    local extra  = ""
    if amAdmin and Safe(function() return ply:GetNWBool("P11_Infected", false) end, false) then extra = "  ☣" end
    if not alive then extra = extra .. "  †" end
    if Safe(function() return ply:GetNWBool("P11FW_Muted", false) end, false) then extra = extra .. "  🔇" end

    local row = vgui.Create("DPanel", frame.Rows)
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, 2)
    row:SetTall(27)

    GuardedPanel(row, "row", function(s, w, h)
        local base = alive and Color(38, 41, 50, 205) or Color(52, 34, 36, 205)
        draw.RoundedBox(4, 0, 0, w, h, base)
        draw.RoundedBoxEx(4, 0, 0, 4, h, tc, true, false, true, false)
        if s:IsHovered() then
            draw.RoundedBox(4, 4, 0, w - 4, h, Color(255, 255, 255, 10))
        end
        surface.SetDrawColor(255, 255, 255, 6)
        surface.DrawRect(4, 0, w - 4, 1)

        if wanted ~= "" then
            local blink = 0.5 + math.sin(CurTime() * 6) * 0.5
            draw.SimpleText("⚠ РОЗЫСК", "P11.SB.Tiny", w - 118, h / 2,
                Color(255, 90, 80, 140 + 115 * blink), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end)

    -- имя (украденная личность вместо настоящей!)
    local nameLab = vgui.Create("DLabel", row)
    nameLab:SetPos(12, 4)
    nameLab:SetFont("P11.SB.Text")
    nameLab:SetTextColor(alive and C_TEXT or C_DEAD)
    nameLab:SetText(nick .. extra)
    nameLab:SizeToContents()

    -- чип ранга администрации (от Хелпера), Куратор+ переливается
    if RankLevelOf(ply) >= 2 then
        local chip = vgui.Create("DLabel", row)
        chip:SetFont("P11.SB.Small")
        chip:SetText("«" .. RankNameOf(ply) .. "»")
        chip:SizeToContents()
        chip:SetPos(14 + nameLab:GetWide() + 8, 6)
        local hasFx = Safe(function() return P11FW.RankHasFx and P11FW.RankHasFx(ply) end, false)
        if hasFx then
            chip.Think = function(s)
                s:SetTextColor(Safe(function() return P11FW.RankFxColor(ply) end, RankColorOf(ply)))
            end
        else
            chip:SetTextColor(RankColorOf(ply))
        end
    end

    -- должность
    local jobStr = JobNameOf(ply)
    if jobStr ~= "" then
        local jobLab = vgui.Create("DLabel", row)
        jobLab:SetFont("P11.SB.Small")
        jobLab:SetTextColor(Color(150, 155, 170, 215))
        jobLab:SetText(jobStr)
        jobLab:SizeToContents()
        jobLab:SetPos(430, 7)
    end

    -- пинг
    local ping = vgui.Create("DLabel", row)
    ping:SetFont("P11.SB.Small")
    ping:SetTextColor(pingV > 150 and Color(235, 120, 110) or pingV > 80 and Color(235, 190, 110) or Color(150, 200, 150))
    ping:SetText(tostring(pingV))
    ping:SizeToContents()
    ping:Dock(RIGHT)
    ping:DockMargin(0, 0, 12, 0)
    ping:SetContentAlignment(6)
end

-- ============ СБОРКА СПИСКА ============

local function BuildList(frame)
    if not IsValid(frame) or not IsValid(frame.Rows) then return end

    local vbar = frame.Rows.GetVBar and frame.Rows:GetVBar()
    local keepScroll = IsValid(vbar) and vbar:GetScroll() or 0

    for _, pnl in ipairs(frame.Rows:GetChildren()) do pnl:Remove() end

    local me = LocalPlayer()
    local amAdmin = Safe(function()
        return POLUS11.Config.Admin(me)
    end, false) or (IsValid(me) and RankLevelOf(me) >= 2)

    local plys = {}
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p.Team then plys[#plys + 1] = p end
    end

    local cats = (P11FW and P11FW.CategoryList) or nil
    if istable(cats) and #cats > 0 and P11FW and P11FW.GetJob then
        for _, cat in ipairs(cats) do
            local members = {}
            for _, ply in ipairs(plys) do
                local job = Safe(function() return P11FW.GetJob(ply) end, nil)
                local cid = (istable(job) and (job.faction or job.category)) or "misc"
                if cid == cat.id then members[#members + 1] = ply end
            end

            if #members > 0 then
                SortMembers(members)

                local catCol  = CatColorOf(cat)
                local catName = (istable(cat) and isstring(cat.name)) and cat.name or "—"

                local head = vgui.Create("DPanel", frame.Rows)
                head:Dock(TOP)
                head:SetTall(25)
                head:DockMargin(0, 7, 0, 2)
                GuardedPanel(head, "head", function(s, w, h)
                    draw.RoundedBox(3, 0, 0, w, h, Color(catCol.r, catCol.g, catCol.b, 30))
                    draw.RoundedBoxEx(3, 0, 0, w, 2, Color(catCol.r, catCol.g, catCol.b, 190), true, true, false, false)
                    draw.SimpleText(catName, "P11.SB.Small", 8, h / 2 + 1, catCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText(#members .. " чел.", "P11.SB.Tiny", w - 8, h / 2 + 1,
                        C_GREY, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end)

                for _, ply in ipairs(members) do
                    MakeRow(frame, ply, amAdmin)
                end
            end
        end
    else
        SortMembers(plys)
        for _, ply in ipairs(plys) do
            MakeRow(frame, ply, amAdmin)
        end
    end

    if IsValid(vbar) then vbar:SetScroll(math.max(keepScroll, 0)) end
end

-- безопасная сборка: упал кусок — вместо краша один лог (v3.5)
local function SafeBuildList(frame)
    local ok, err = pcall(BuildList, frame)
    if not ok then
        print("[POLUS][ERROR] TAB build: " .. tostring(err))
    end
end

-- ============ ОКНО ============

local function OpenSB()
    if IsValid(POLUS11.Scoreboard) then POLUS11.Scoreboard:Remove() end

    local w, h = 620, ScrH() * 0.85
    local frame = vgui.Create("DPanel")
    POLUS11.Scoreboard = frame
    frame.OpenT = SysTime()
    frame:SetSize(w, h)
    frame:SetPos((ScrW() - w) / 2, (ScrH() - h) / 2 - 40)

    GuardedPanel(frame, "frame", function(s, ww, hh)
        Derma_DrawBackgroundBlur(s, s.OpenT or SysTime())

        draw.RoundedBox(10, 0, 0, ww, hh, Color(14, 16, 21, 230))
        draw.RoundedBoxEx(10, 0, 0, ww, 56, Color(26, 29, 37, 255), true, true, false, false)

        local t = CurTime()
        local glow = 140 + math.sin(t * 1.6) * 40
        surface.SetDrawColor(120, 190, 230, glow)
        surface.DrawRect(0, 55, ww, 1)

        draw.SimpleText("СТАНЦИЯ «ПОЛЮС-11»", "P11.SB.Title", 16, 14, Color(235, 240, 248))
        draw.SimpleText("MILITARY HORROR RP · 1982", "P11.SB.Tiny", 18, 42, Color(120, 160, 190, 220))

        draw.SimpleText(OnlineCountText(), "P11.SB.Small", ww - 16, 16,
            Color(170, 178, 195), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

        local status = "Фаза: " .. GetGlobalString("P11_Phase", "?")
        local shift = GetGlobalString("P11_Shift", "")
        if shift ~= "" then status = status .. "    ☾ " .. shift end
        if GetGlobalBool("P11_Blackout", false) then status = status .. "    ⚠ АВАРИЯ ЭНЕРГОСИСТЕМЫ" end
        if GetGlobalBool("P11_Storm", false) then status = status .. "    ❄ МАГНИТНАЯ БУРЯ" end
        draw.SimpleText(status, "P11.SB.Small", 16, 66, Color(255, 190, 90))

        local me = LocalPlayer()
        local myJob = JobNameOf(me)
        local foot = " · " .. myJob
        if IsValid(me) and RankLevelOf(me) >= 2 then
            foot = foot .. "   ◆ " .. RankNameOf(me)
        end
        draw.RoundedBoxEx(10, 0, hh - 26, ww, 26, Color(26, 29, 37, 255), false, false, true, true)
        draw.SimpleText(DisplayNick(me) .. foot, "P11.SB.Tiny", 12, hh - 13, C_GREY, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("F1 — памятка · F2 — вид · F3 — курсор · C (удерж.) — действия · F4 — должности", "P11.SB.Tiny",
            ww - 12, hh - 13, Color(105, 112, 128), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end)

    frame.Rows = vgui.Create("DScrollPanel", frame)
    frame.Rows:DockMargin(10, 86, 10, 34)
    frame.Rows:Dock(FILL)
    local sbar = frame.Rows:GetVBar()
    sbar:SetWide(4)
    sbar:SetHideButtons(true)

    SafeBuildList(frame)

    frame.Think = function(s)
        s.NextRefresh = s.NextRefresh or 0
        if CurTime() >= s.NextRefresh then
            local n = player.GetCount()
            s.NextRefresh = CurTime() + (n > 24 and 2 or 1)
            SafeBuildList(s)
        end
    end

    gui.EnableScreenClicker(true)
    surface.PlaySound("ui/buttonclickrelease.wav")
end

local function CloseSB()
    if IsValid(POLUS11.Scoreboard) then POLUS11.Scoreboard:Remove() end
    gui.EnableScreenClicker(false)
end

-- аварийное компакт-табло (без украшательств — но состав виден)
local function OpenSafeSB()
    if IsValid(POLUS11.Scoreboard) then POLUS11.Scoreboard:Remove() end

    local f = vgui.Create("DPanel")
    POLUS11.Scoreboard = f
    f:SetSize(360, math.min(ScrH() * 0.8, 560))
    f:Center()
    f.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(14, 16, 21, 235))
        draw.SimpleText("СОСТАВ СТАНЦИИ (аварийный режим)", "P11.SB.Small", 10, 8,
            Color(235, 190, 110))
    end

    local lv = vgui.Create("DListView", f)
    lv:SetPos(8, 30) lv:SetSize(344, f:GetTall() - 38)
    lv:SetMultiSelect(false)
    lv:AddColumn("Игрок"):SetFixedWidth(170)
    lv:AddColumn("Должность"):SetFixedWidth(110)
    lv:AddColumn("Пинг")
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then
            lv:AddLine(DisplayNick(p), JobNameOf(p), Safe(function() return p:Ping() end, 0))
        end
    end
    gui.EnableScreenClicker(true)
end

P11.SBFails = 0

hook.Add("ScoreboardShow", "P11.Scoreboard", function()
    if DarkRP then return end
    if not POLUS11.Config.CustomScoreboard then return end
    local ok, err = pcall(OpenSB)
    if not ok then
        P11.SBFails = P11.SBFails + 1
        print("[POLUS][ERROR] TAB open (x" .. P11.SBFails .. "): " .. tostring(err))
        if P11.SBFails >= 2 then
            pcall(OpenSafeSB)
        end
    else
        P11.SBFails = 0
    end
end)

hook.Add("ScoreboardHide", "P11.Scoreboard", function()
    CloseSB()
end)

-- опционально: скрыть килл-ленту (она палит настоящие ники)
if POLUS11.Config.HideKillFeed then
    hook.Add("DrawDeathNotice", "P11.HideFeed", function()
        return true
    end)
end
