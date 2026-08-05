-- ============================================================
--  ПОЛЮС-11 — ТАБ «СОСТАВ СТАНЦИИ» v3.4 (Sandbox-режим)
--  Полный редизайн:
--   • стеклянная рама (блюр фона), акцентная полоса фракций;
--   • КРАСИВАЯ СОРТИРОВКА: внутри каждой секции админ-состав
--     идёт первым (по рангу по убыванию), дальше — по имени;
--     ранги Куратор+ переливаются «живым» цветом;
--   • «плавающий» онлайн для обычных (±), точный — для админов;
--   • метки: ☣ НЕЧТО (админу), мертв, ⚠ РОЗЫСК, 🔇 мут;
--   • обновление раз в секунду без рывков скролла.
-- ============================================================

surface.CreateFont("P11.SB.Title", {font = "Roboto", size = 26, weight = 700, extended = true})
surface.CreateFont("P11.SB.Text",  {font = "Roboto", size = 17, weight = 500, extended = true})
surface.CreateFont("P11.SB.Small", {font = "Roboto", size = 14, weight = 400, extended = true})
surface.CreateFont("P11.SB.Tiny",  {font = "Roboto", size = 12, weight = 500, extended = true})

local function DisplayNick(ply)
    if not IsValid(ply) then return "?" end -- v3.8.1: защита сортировки/строк
    local fake = ply:GetNWString("P11_FakeNick", "")
    if fake ~= "" then return fake end
    return ply:Nick()
end

-- ============ «ПЛАВАЮЩИЙ» ОНЛАЙН ============
-- Обычный игрок НЕ должен точно знать, сколько людей на станции
-- (иначе по TAB можно вычислить пропавших). Aдмины видят точно.
local FAKE = { n = nil, nextT = 0 }

local function OnlineCountText()
    local real = 0
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then real = real + 1 end
    end
    if real <= 0 then real = 1 end

    local me = LocalPlayer()
    local precise = IsValid(me) and (
        (P11FW and P11FW.GetRankLevel and P11FW.GetRankLevel(me) >= 2)
        or me:IsAdmin() or me:IsSuperAdmin()
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
end

-- ============ СОРТИРОВКА: админы первыми, потом по имени ============

local function RankOf(ply)
    if P11FW and P11FW.GetRankLevel then return P11FW.GetRankLevel(ply) end
    return 0
end

local function SortMembers(members)
    table.sort(members, function(a, b)
        local ra, rb = RankOf(a), RankOf(b)
        if ra ~= rb then return ra > rb end
        return string.lower(DisplayNick(a)) < string.lower(DisplayNick(b))
    end)
end

-- ============ СТРОКА ИГРОКА ============

local function MakeRow(frame, ply, amAdmin)
    local row = vgui.Create("DPanel", frame.Rows)
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, 2)
    row:SetTall(27)

    local alive = ply:Alive()
    local tc = team.GetColor(ply:Team())
    local hovered = false

    row.Paint = function(s, w, h)
        if not IsValid(ply) then return end -- v3.8.1: игрок вышел — строка не падает
        local t = CurTime()
        local base = alive and Color(38, 41, 50, 205) or Color(52, 34, 36, 205)
        draw.RoundedBox(4, 0, 0, w, h, base)
        draw.RoundedBoxEx(4, 0, 0, 4, h, tc, true, false, true, false)
        if s:IsHovered() then
            draw.RoundedBox(4, 4, 0, w - 4, h, Color(255, 255, 255, 10))
        end
        -- тонкий блик сверху
        surface.SetDrawColor(255, 255, 255, 6)
        surface.DrawRect(4, 0, w - 4, 1)

        -- ⚠ РОЗЫСК мигает у правого края
        if ply:GetNWString("P11_Wanted", "") ~= "" then
            local blink = 0.5 + math.sin(t * 6) * 0.5
            draw.SimpleText("⚠ РОЗЫСК", "P11.SB.Tiny", w - 118, h / 2,
                Color(255, 90, 80, 140 + 115 * blink), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end

    -- имя (украденная личность вместо настоящей!)
    local nameLab = vgui.Create("DLabel", row)
    nameLab:SetPos(12, 4)
    nameLab:SetFont("P11.SB.Text")
    nameLab:SetTextColor(alive and Color(238, 238, 242) or Color(150, 130, 130))
    local nick = DisplayNick(ply)
    local extra = ""
    if amAdmin and ply:GetNWBool("P11_Infected", false) then extra = "  ☣" end
    if not alive then extra = extra .. "  †" end
    if ply:GetNWBool("P11FW_Muted", false) then extra = extra .. "  🔇" end
    nameLab:SetText(nick .. extra)
    nameLab:SizeToContents()

    -- чип ранга администрации (от Хелпера), Куратор+ переливается
    if P11FW and P11FW.GetRankLevel and P11FW.GetRankLevel(ply) >= 2 then
        local chip = vgui.Create("DLabel", row)
        chip:SetFont("P11.SB.Small")
        chip:SetText("«" .. P11FW.GetRankName(ply) .. "»")
        chip:SizeToContents()
        chip:SetPos(14 + nameLab:GetWide() + 8, 6)
        if P11FW.RankHasFx and P11FW.RankHasFx(ply) then
            chip.Think = function(s)
                if not IsValid(ply) then return end -- v3.8.1
                s:SetTextColor(P11FW.RankFxColor(ply))
            end
        else
            chip:SetTextColor(P11FW.GetRankColor(ply))
        end
    end

    -- должность
    if P11FW and P11FW.GetJobName then
        local jobLab = vgui.Create("DLabel", row)
        jobLab:SetFont("P11.SB.Small")
        jobLab:SetTextColor(Color(150, 155, 170, 215))
        jobLab:SetText(P11FW.GetJobName(ply))
        jobLab:SizeToContents()
        jobLab:SetPos(430, 7)
    end

    -- пинг
    local ping = vgui.Create("DLabel", row)
    ping:SetFont("P11.SB.Small")
    local pv = ply:Ping()
    ping:SetTextColor(pv > 150 and Color(235, 120, 110) or pv > 80 and Color(235, 190, 110) or Color(150, 200, 150))
    ping:SetText(tostring(pv))
    ping:SizeToContents()
    ping:Dock(RIGHT)
    ping:DockMargin(0, 0, 12, 0)
    ping:SetContentAlignment(6)
end

-- ============ СБОРКА СПИСКА ============

local function BuildList(frame)
    -- запомним позицию скролла, чтобы не дёргалась при ребилде
    local vbar = frame.Rows and frame.Rows.GetVBar and frame.Rows:GetVBar()
    local keepScroll = IsValid(vbar) and vbar:GetScroll() or 0

    for _, pnl in ipairs(frame.Rows:GetChildren()) do pnl:Remove() end

    local me = LocalPlayer()
    local amAdmin = POLUS11.Config.Admin(me)
        or (P11FW and P11FW.GetRankLevel and P11FW.GetRankLevel(me) >= 2)

    -- секции по ФРАКЦИЯМ
    if P11FW and P11FW.CategoryList and P11FW.GetJob then
        for _, cat in ipairs(P11FW.CategoryList) do
            local members = {}
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) then
                    local job = P11FW.GetJob(ply)
                    local cid = job and (job.faction or job.category) or "misc"
                    if cid == cat.id then members[#members + 1] = ply end
                end
            end

            if #members > 0 then
                SortMembers(members)

                local head = vgui.Create("DPanel", frame.Rows)
                head:Dock(TOP)
                head:SetTall(25)
                head:DockMargin(0, 7, 0, 2)
                head.Paint = function(s, w, h)
                    -- градиентная полоса фракции
                    draw.RoundedBox(3, 0, 0, w, h, Color(cat.color.r, cat.color.g, cat.color.b, 30))
                    draw.RoundedBoxEx(3, 0, 0, w, 2, Color(cat.color.r, cat.color.g, cat.color.b, 190), true, true, false, false)
                    draw.SimpleText(cat.name, "P11.SB.Small", 8, h / 2 + 1, cat.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText(#members .. " чел.", "P11.SB.Tiny", w - 8, h / 2 + 1,
                        Color(150, 155, 170), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end

                for _, ply in ipairs(members) do
                    MakeRow(frame, ply, amAdmin)
                end
            end
        end
    else
        -- фолбэк: плоский список
        local plys = {}
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) then plys[#plys + 1] = p end
        end
        SortMembers(plys)
        for _, ply in ipairs(plys) do
            MakeRow(frame, ply, amAdmin)
        end
    end

    if IsValid(vbar) then
        vbar:SetScroll(math.min(keepScroll, math.max(keepScroll, 0)))
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

    local me = LocalPlayer()

    frame.Paint = function(s, ww, hh)
        Derma_DrawBackgroundBlur(s, s.OpenT or SysTime())

        draw.RoundedBox(10, 0, 0, ww, hh, Color(14, 16, 21, 230))

        -- верхняя панель
        draw.RoundedBoxEx(10, 0, 0, ww, 56, Color(26, 29, 37, 255), true, true, false, false)
        -- «ледяная» кромка
        local t = CurTime()
        local glow = 140 + math.sin(t * 1.6) * 40
        surface.SetDrawColor(120, 190, 230, glow)
        surface.DrawRect(0, 55, ww, 1)

        draw.SimpleText("СТАНЦИЯ «ПОЛЮС-11»", "P11.SB.Title", 16, 14, Color(235, 240, 248))
        draw.SimpleText("MILITARY HORROR RP · 1982", "P11.SB.Tiny", 18, 42, Color(120, 160, 190, 220))

        -- онлайн (справа)
        draw.SimpleText(OnlineCountText(), "P11.SB.Small", ww - 16, 16,
            Color(170, 178, 195), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

        -- статус-строка
        local status = "Фаза: " .. GetGlobalString("P11_Phase", "?")
        local shift = GetGlobalString("P11_Shift", "")
        if shift ~= "" then
            status = status .. "    ☾ " .. shift
        end
        if GetGlobalBool("P11_Blackout", false) then
            status = status .. "    ⚠ АВАРИЯ ЭНЕРГОСИСТЕМЫ"
        end
        if GetGlobalBool("P11_Storm", false) then
            status = status .. "    ❄ МАГНИТНАЯ БУРЯ"
        end
        draw.SimpleText(status, "P11.SB.Small", 16, 66, Color(255, 190, 90))

        -- подвал: моя должность + мой ранг
        local myJob = (P11FW and P11FW.GetJobName) and P11FW.GetJobName(me) or ""
        local foot = " · " .. myJob
        if P11FW and P11FW.GetRankLevel and P11FW.GetRankLevel(me) >= 2 then
            foot = foot .. "   ◆ " .. P11FW.GetRankName(me)
        end
        draw.RoundedBoxEx(10, 0, hh - 26, ww, 26, Color(26, 29, 37, 255), false, false, true, true)
        local meNick = IsValid(me) and me:Nick() or "?"
        draw.SimpleText(meNick .. foot, "P11.SB.Tiny", 12, hh - 13, Color(140, 150, 168), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("F1 — памятка · F2 — вид · F3 — курсор · C (удерж.) — действия · F4 — должности", "P11.SB.Tiny",
            ww - 12, hh - 13, Color(105, 112, 128), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    frame.Rows = vgui.Create("DScrollPanel", frame)
    frame.Rows:DockMargin(10, 86, 10, 34)
    frame.Rows:Dock(FILL)
    local sbar = frame.Rows:GetVBar()
    sbar:SetWide(4)
    sbar:SetHideButtons(true)

    BuildList(frame)

    frame.Think = function(s)
        s.NextRefresh = s.NextRefresh or 0
        if CurTime() >= s.NextRefresh then
            -- красивая периодичность: раз в секунду мягкий ребилд
            local n = player.GetCount()
            s.NextRefresh = CurTime() + (n > 24 and 2 or 1)
            BuildList(s)
        end
    end

    gui.EnableScreenClicker(true)
    surface.PlaySound("ui/buttonclickrelease.wav")
end

local function CloseSB()
    if IsValid(POLUS11.Scoreboard) then POLUS11.Scoreboard:Remove() end
    gui.EnableScreenClicker(false)
end

-- аварийное компакт-табло: если красивое дважды упало — показываем
-- простое, но состав всегда виден (v3.8.1, авто-страховка от «краша TAB»)
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
            local jn = (P11FW and P11FW.GetJobName) and P11FW.GetJobName(p) or ""
            lv:AddLine(DisplayNick(p), jn, p:Ping())
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
