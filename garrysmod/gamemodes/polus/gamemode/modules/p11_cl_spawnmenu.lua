-- ============================================================
--  ПОЛЮС-11 — ЭКРАН ВЕРБОВКИ (client) v4.6.0 «ВЕРБОВКА»
--  Полноэкранный выбор ФРАКЦИИ и ПРОФЕССИИ при спавне:
--   • слева — колонка фракций (с цветами и числом должностей),
--     справа — карточки должностей выбранной фракции;
--   • на карточках честные замки: 🔒 вайтлист, ⏳ время игры,
--     «МЕСТ НЕТ» — но последнее слово всегда за сервером
--     (штатный P11FW_TakeJob со всеми гейтами);
--   • занял должность — меню закрывается само, боец разморожен
--     («прибыл к месту службы»; дальше его встречает зона
--     прибытия своей фракции — v4.5.0);
--   • открыть снова: !смена / !выбор / !вербовка, p11_spawnmenu.
-- ============================================================

P11 = P11 or {}

surface.CreateFont("P11.SM.Job",  { font = "Roboto", size = 16, weight = 800, extended = true })
surface.CreateFont("P11.SM.Small",{ font = "Roboto", size = 13, weight = 600, extended = true })

local SM = {}
P11.SpawnMenu = SM

local function Groups()
    -- фракция -> список должностей (по порядку job.order)
    local byFac, order = {}, {}
    for id, job in pairs(P11FW.Jobs or {}) do
        local facId = job.faction or job.category or "misc"
        byFac[facId] = byFac[facId] or {}
        table.insert(byFac[facId], { id = id, job = job })
    end
    for facId, list in pairs(byFac) do
        table.sort(list, function(a, b)
            return (a.job.order or 99) < (b.job.order or 99)
        end)
    end
    -- порядок фракций по каталогу CategoryList
    local facs = {}
    for _, c in ipairs(P11FW.CategoryList or {}) do
        if byFac[c.id] then
            facs[#facs + 1] = { id = c.id, name = c.name, color = c.color or Color(200, 170, 120), n = #byFac[c.id] }
        end
    end
    -- фракции, которых нет в каталоге (страховка)
    for facId, list in pairs(byFac) do
        local found = false
        for _, f2 in ipairs(facs) do if f2.id == facId then found = true break end end
        if not found then facs[#facs + 1] = { id = facId, name = facId, color = Color(200, 170, 120), n = #list } end
    end
    return facs, byFac
end

-- состояние замка карточки для ТЕКУЩЕГО игрока (визуал; сервер перепроверит)
local function LockState(job, jobId)
    local me = LocalPlayer()
    if not IsValid(me) then return nil end
    local rank = (P11FW.GetRankLevel and P11FW.GetRankLevel(me)) or 0
    if job.whitelist and rank < 16 and not (P11FW.Config.Admin and P11FW.Config.Admin(me)) then
        local has = P11FW.HasWhitelist and P11FW.HasWhitelist(me, jobId)
        if not has then return "wl" end
    end
    if (job.time or 0) > 0 and rank < 6 then
        local my = me:GetNWInt("P11_PlayMin", 0)
        if my < job.time then return "time", job.time, my end
    end
    return nil
end

local function SlotInfo(jobId, job)
    if (job.max or 0) <= 0 then return nil end
    local t = P11FW.JobTeams and P11FW.JobTeams[jobId]
    local n = t and team.NumPlayers(t) or 0
    return n, job.max
end

function SM.Close(sendDone)
    if IsValid(SM.Frame) then
        SM.Frame.P11_NoDone = not sendDone
        SM.Frame:Remove()
    end
    SM.Frame = nil
    if sendDone then
        net.Start("P11_SpawnMenu_Done")
        net.SendToServer()
    end
end

function SM.Open()
    if IsValid(SM.Frame) then SM.Frame:Remove() end
    local C = P11UI.C

    local f = P11UI.Frame("ПУНКТ ВЕРБОВКИ — ВЫБОР СЛУЖБЫ",
        "выбери фракцию слева, должность справа — и прибудь к месту службы",
        math.min(1050, ScrW() - 60), math.min(680, ScrH() - 60), C.gold)
    SM.Frame = f
    SM.OpenTeam = LocalPlayer():Team()
    SM.Selected = nil

    -- самозакрытие, когда должность ПОЛУЧЕНА (сервер сменил team)
    f.Think = function(s)
        if not IsValid(LocalPlayer()) then return end
        if LocalPlayer():Team() ~= s.P11Team then
            s.P11Team = LocalPlayer():Team()
            if s.P11Team ~= SM.OpenTeam then
                timer.Simple(0.35, function() SM.Close(true) end)
            end
        end
    end
    f.P11Team = LocalPlayer():Team()

    f.OnRemove = function(s)
        if not s.P11_NoDone then
            net.Start("P11_SpawnMenu_Done")
            net.SendToServer()
        end
        if SM.Frame == s then SM.Frame = nil end
    end

    local fw, fh = f:GetSize()

    -- ============ ЛЕВО: ФРАКЦИИ ============
    local facs, byFac = Groups()
    local facScroll = P11UI.Scroll(f, 14, 64, 264, fh - 150)

    local function PaintList()
        facScroll:Clear()
        for _, fac in ipairs(facs) do
            local b = facScroll:Add("DButton")
            b:Dock(TOP) b:DockMargin(2, 3, 4, 3) b:SetTall(52)
            b:SetText("")
            b.fac = fac
            b.Paint = function(s, w, h)
                local sel = SM.Faction == s.fac.id
                draw.RoundedBox(7, 0, 0, w, h, sel and Color(s.fac.color.r, s.fac.color.g, s.fac.color.b, 46)
                    or (s:IsHovered() and Color(255, 255, 255, 12) or Color(255, 255, 255, 5)))
                draw.RoundedBoxEx(7, 0, 0, 5, h, s.fac.color, true, false, true, false)
                if sel then
                    surface.SetDrawColor(s.fac.color)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                end
                draw.SimpleText(s.fac.name, "P11.SM.Job", 14, 15, sel and s.fac.color or C.text)
                draw.SimpleText("должностей: " .. s.fac.n, "P11.SM.Small", 14, 35, C.dim)
            end
            b.DoClick = function(s)
                SM.Faction = s.fac.id
                SM.Selected = nil
                surface.PlaySound("buttons/button9.wav")
                PaintJobs()
                PaintBottom()
            end
        end
    end

    -- ============ ПРАВО: ДОЛЖНОСТИ ФРАКЦИИ ============
    local jobScroll = P11UI.Scroll(f, 290, 64, fw - 304, fh - 150)

    function PaintJobs()
        jobScroll:Clear()
        local list = byFac[SM.Faction] or {}
        if #list == 0 then
            P11UI.Head(jobScroll, "в этой фракции пока нет должностей", C.dim)
            return
        end
        for _, rec in ipairs(list) do
            local job, jobId = rec.job, rec.id
            local card = jobScroll:Add("DButton")
            card:Dock(TOP) card:DockMargin(2, 4, 6, 4) card:SetTall(58)
            card:SetText("")
            local lock, need, my = LockState(job, jobId)
            local n, mx = SlotInfo(jobId, job)
            local full = (mx ~= nil) and (n >= mx)
            local jc = job.color or Color(200, 200, 200)

            card.Paint = function(s, w, h)
                local sel = SM.Selected == jobId
                draw.RoundedBox(7, 0, 0, w, h, sel and Color(jc.r, jc.g, jc.b, 42)
                    or (s:IsHovered() and Color(255, 255, 255, 12) or Color(255, 255, 255, 5)))
                draw.RoundedBoxEx(7, 0, 0, 5, h, jc, true, false, true, false)
                if sel then
                    surface.SetDrawColor(jc)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                end
                local nameCol = full and Color(jc.r, jc.g, jc.b, 130) or jc
                draw.SimpleText(job.name, "P11.SM.Job", 14, 15, nameCol)

                -- подпись состояния
                local sub, subCol = "", C.dim
                if lock == "wl" then
                    sub, subCol = "🔒 ВАЙТЛИСТ — нужен допуск", Color(255, 190, 120)
                elseif lock == "time" then
                    sub, subCol = "⏳ с " .. need .. " мин. игры (у тебя " .. my .. ")", Color(150, 200, 255)
                elseif full then
                    sub, subCol = "МЕСТ НЕТ (" .. n .. "/" .. mx .. ")", C.bad
                elseif mx then
                    sub = "мест: " .. n .. "/" .. mx
                else
                    sub = "мест без ограничений"
                end
                draw.SimpleText(sub, "P11.SM.Small", 14, 37, subCol)

                if sel then
                    draw.SimpleText("ВЫБРАНО ▸", "P11.SM.Small", w - 14, h / 2, jc, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
            end
            card.DoClick = function()
                SM.Selected = jobId
                surface.PlaySound("buttons/button9.wav")
                jobScroll:InvalidateLayout(true)
                -- перерисовать выделение
                for _, ch in ipairs(jobScroll:GetCanvas():GetChildren()) do ch:InvalidateLayout() end
                PaintJobs()
                PaintBottom()
            end
        end
    end

    -- ============ НИЗ: ПОДТВЕРЖДЕНИЕ ============
    local bottom = vgui.Create("DPanel", f)
    bottom:SetPos(14, fh - 74) bottom:SetSize(fw - 28, 60)
    function PaintBottom() bottom:Clear() BuildBottom() end
    function BuildBottom()
        local w2, h2 = bottom:GetSize()
        bottom.Paint = function(s, w, h)
            draw.RoundedBox(8, 0, 0, w, h, C.panel)
            if not SM.Selected then
                draw.SimpleText("— выбери должность справа —", "P11.SM.Small", 16, h / 2, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            else
                local job = P11FW.Jobs[SM.Selected]
                local jc = job and job.color or C.text
                draw.SimpleText("Кандидатура: " .. (job and job.name or "?"), "P11.SM.Job", 16, h / 2, jc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end

        local take = vgui.Create("DButton", bottom)
        take:Dock(RIGHT) take:SetWide(300) take:DockMargin(8, 8, 8, 8)
        take:SetText("")
        take.Paint = function(s, w, h)
            local can = SM.Selected ~= nil
            local job = SM.Selected and P11FW.Jobs[SM.Selected]
            local jc = (can and job) and job.color or C.dim
            draw.RoundedBox(7, 0, 0, w, h, can and (s:IsHovered() and Color(jc.r, jc.g, jc.b, 70) or Color(jc.r, jc.g, jc.b, 44)) or Color(255, 255, 255, 6))
            surface.SetDrawColor(jc)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(can and ("ПРИБЫТЬ: " .. job.name) or "ПРИБЫТЬ", "P11.SM.Job", w / 2, h / 2,
                can and jc or C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        take.DoClick = function()
            if not SM.Selected then surface.PlaySound("buttons/button10.wav") return end
            net.Start("P11FW_TakeJob")
                net.WriteString(SM.Selected)
                net.WriteUInt(0, 5)
            net.SendToServer()
            surface.PlaySound("buttons/button9.wav")
        end
    end

    -- «остаться новобранцем»
    local stay = vgui.Create("DButton", f)
    stay:SetPos(14, fh - 32) stay:SetSize(300, 20)
    stay:SetText("")
    stay.Paint = function(s, w, h)
        draw.SimpleText("× остаться новобранцем (выбрать можно позже: F4 или !смена)",
            "P11.SM.Small", 0, h / 2, s:IsHovered() and C.text or C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    stay.DoClick = function() SM.Close(true) end

    -- стартовое состояние: первая фракция
    SM.Faction = facs[1] and facs[1].id or nil
    PaintList()
    PaintJobs()
    PaintBottom()

    surface.PlaySound("ambient/alarms/warningbell1.wav")
end

-- сервер просит показать (заход / !смена / p11_spawnmenu)
net.Receive("P11_SpawnMenu_Open", function()
    -- если анкета/другое окно занимает экран — мы выше всё равно откроемся
    SM.Open()
end)

print("[POLUS-11] экран вербовки загружен (!смена — открыть выбор фракции/профы)")
