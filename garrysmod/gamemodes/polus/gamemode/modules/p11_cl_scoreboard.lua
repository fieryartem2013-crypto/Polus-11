-- ============================================================
--  ПОЛЮС-11 — ТАБ с подменой ников (Sandbox-режим)
--  В DarkRP отключается автоматически (там работает rpname)
-- ============================================================

surface.CreateFont("P11.SB.Title", {font = "Roboto", size = 26, weight = 700, extended = true})
surface.CreateFont("P11.SB.Text",  {font = "Roboto", size = 17, weight = 500, extended = true})
surface.CreateFont("P11.SB.Small", {font = "Roboto", size = 14, weight = 400, extended = true})

local function DisplayNick(ply)
    local fake = ply:GetNWString("P11_FakeNick", "")
    if fake ~= "" then return fake end
    return ply:Nick()
end

-- одна строка игрока
local function MakeRow(frame, ply, amAdmin)
    local row = vgui.Create("DPanel", frame.Rows)
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, 2)
    row:SetTall(26)

    local alive = ply:Alive()
    row.Paint = function(s, w, h)
        local c = Color(40, 43, 52, 200)
        if not alive then c = Color(50, 34, 36, 200) end
        draw.RoundedBox(4, 0, 0, w, h, c)
        draw.RoundedBoxEx(4, 0, 0, 4, h, team.GetColor(ply:Team()), true, false, true, false)
    end

    -- имя (украденная личность вместо настоящей!)
    local nameLab = vgui.Create("DLabel", row)
    nameLab:SetPos(12, 3)
    nameLab:SetFont("P11.SB.Text")
    nameLab:SetTextColor(alive and Color(238, 238, 242) or Color(150, 130, 130))
    local nick = DisplayNick(ply)
    local extra = ""
    if amAdmin and ply:GetNWBool("P11_Infected", false) then extra = "  ☣ НЕЧТО" end
    if not alive then extra = extra .. "  (мертв)" end
    if ply:GetNWString("P11_Wanted", "") ~= "" then extra = extra .. "  ⚠ РОЗЫСК" end -- v2.9
    nameLab:SetText(nick .. extra)
    nameLab:SizeToContents()

    -- v3.4: значок ранга администрации рядом с ником (от Хелпера и выше)
    if P11FW and P11FW.GetRankLevel and P11FW.GetRankLevel(ply) >= 2 then
        local chip = vgui.Create("DLabel", row)
        chip:SetFont("P11.SB.Small")
        chip:SetText("«" .. P11FW.GetRankName(ply) .. "»")
        chip:SetTextColor(P11FW.GetRankColor(ply))
        chip:SizeToContents()
        chip:SetPos(12 + nameLab:GetWide() + 8, 6)
    end

    -- должность (справа от ника, приглушённо)
    if P11FW and P11FW.GetJobName then
        local jobLab = vgui.Create("DLabel", row)
        jobLab:SetFont("P11.SB.Small")
        jobLab:SetTextColor(Color(140, 145, 160, 200))
        jobLab:SetText(P11FW.GetJobName(ply))
        jobLab:SizeToContents()
        jobLab:SetPos(468, 6)
    end

    -- пинг
    local ping = vgui.Create("DLabel", row)
    ping:SetFont("P11.SB.Text")
    ping:SetTextColor(Color(170, 175, 190))
    ping:SetText(tostring(ply:Ping()))
    ping:SizeToContents()
    ping:SetPos(560 - 8, 3)
    ping:Dock(RIGHT)
    ping:DockMargin(0, 0, 14, 0)
end

local function BuildList(frame)
    for _, pnl in ipairs(frame.Rows:GetChildren()) do pnl:Remove() end

    local me = LocalPlayer()
    local amAdmin = POLUS11.Config.Admin(me)

    local byNick = function(a, b)
        return string.lower(DisplayNick(a)) < string.lower(DisplayNick(b))
    end

    -- v2.6: секции по ФРАКЦИЯМ (если фреймворк жив)
    if P11FW and P11FW.CategoryList and P11FW.GetJob then
        for _, cat in ipairs(P11FW.CategoryList) do
            local members = {}
            for _, ply in ipairs(player.GetAll()) do
                local job = P11FW.GetJob(ply)
                local cid = job and (job.faction or job.category) or "misc"
                if cid == cat.id then members[#members + 1] = ply end
            end

            if #members > 0 then
                table.sort(members, byNick)

                local head = vgui.Create("DPanel", frame.Rows)
                head:Dock(TOP)
                head:SetTall(24)
                head:DockMargin(0, 6, 0, 2)
                head.Paint = function(s, w, h)
                    draw.RoundedBox(3, 0, 0, w, h, Color(cat.color.r, cat.color.g, cat.color.b, 36))
                    draw.SimpleText(cat.name, "P11.SB.Text", 8, h / 2, cat.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText(#members .. " чел.", "P11.SB.Small", w - 8, h / 2,
                        Color(150, 155, 170), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end

                for _, ply in ipairs(members) do
                    MakeRow(frame, ply, amAdmin)
                end
            end
        end
    else
        -- фолбэк: плоский список
        local plys = player.GetAll()
        table.sort(plys, byNick)
        for _, ply in ipairs(plys) do
            MakeRow(frame, ply, amAdmin)
        end
    end
end

local function OpenSB()
    if IsValid(POLUS11.Scoreboard) then POLUS11.Scoreboard:Remove() end

    local w, h = 600, ScrH() * 0.85
    local frame = vgui.Create("DPanel")
    POLUS11.Scoreboard = frame
    frame:SetSize(w, h)
    frame:SetPos((ScrW() - w) / 2, (ScrH() - h) / 2 - 40)
    frame.Paint = function(s, ww, hh)
        draw.RoundedBox(10, 0, 0, ww, hh, Color(20, 22, 28, 235))
        draw.RoundedBoxEx(10, 0, 0, ww, 56, Color(30, 33, 42, 255), true, true, false, false)
        draw.SimpleText("СТАНЦИЯ «ПОЛЮС-11»", "P11.SB.Title", 16, 14, Color(235, 238, 245))

        local status = "Фаза: " .. GetGlobalString("P11_Phase", "?")
        local shift = GetGlobalString("P11_Shift", "")
        if shift ~= "" then
            status = status .. "   |   ☾ " .. shift
        end
        if GetGlobalBool("P11_Blackout", false) then
            status = status .. "   |   ⚠ АВАРИЯ ЭНЕРГОСИСТЕМЫ"
        end
        if GetGlobalBool("P11_Storm", false) then
            status = status .. "   |   МАГНИТНАЯ БУРЯ"
        end
        draw.SimpleText(status, "P11.SB.Small", 16, 62, Color(255, 190, 90))
        draw.SimpleText(#player.GetAll() .. " чел. на станции", "P11.SB.Small", ww - 16, 14, Color(170, 175, 190), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    end

    frame.Rows = vgui.Create("DScrollPanel", frame)
    frame.Rows:Dock(FILL)
    frame.Rows:DockMargin(10, 84, 10, 10)
    local sbar = frame.Rows:GetVBar()
    sbar:SetWide(4)

    BuildList(frame)

    frame.Think = function(s)
        s.NextRefresh = s.NextRefresh or 0
        if CurTime() >= s.NextRefresh then
            -- v3.4: адаптивный ребилд — чем больше народу, тем реже
            -- (полная перестройка каждые 0.5с давала микрофризы на 20+)
            local n = player.GetCount()
            s.NextRefresh = CurTime() + (n > 16 and 3 or n > 8 and 2 or 1.2)
            BuildList(s)
        end
    end

    gui.EnableScreenClicker(true)
end

local function CloseSB()
    if IsValid(POLUS11.Scoreboard) then POLUS11.Scoreboard:Remove() end
    gui.EnableScreenClicker(false)
end

hook.Add("ScoreboardShow", "P11.Scoreboard", function()
    if DarkRP then return end
    if not POLUS11.Config.CustomScoreboard then return end
    OpenSB()
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
