-- ============================================================
--  ПОЛЮС FRAMEWORK — АДМИН-МЕНЮ (клиент) v4.4.0
--  Вкладки: ИГРОКИ • МОДЕРАЦИЯ • ДЕЙСТВИЯ • ДОЛЖНОСТИ
--  (редактор проф + галочка ВАЙТЛИСТ) • ФРАКЦИИ • УТИЛИТЫ •
--  АДМИНКИ (все 19 рангов проекта плиткой, выдача в 1 клик) •
--  ВАЙТЛИСТ (допуски на whitelist-должности — доступен также
--  рангам Faction Officer/Leader БЕЗ админки).
--  Открыть: p11fw_admin в консоль, чат !фвадмин / !fw / /menu,
--  кнопка в C-меню или F4.
-- ============================================================

surface.CreateFont("P11FW.Adm.Tab", { font = "Roboto", size = 15, weight = 700, extended = true }) -- v4.6.1: 9 вкладок — чуть компактнее

local AC = {
    -- v4.2: единый фирменный фундамент P11UI (акцент админки — красный, как положено)
    bg     = Color(10, 14, 20, 245),
    panel  = Color(20, 26, 36, 255),
    panel2 = Color(27, 34, 47, 255),
    accent = Color(235, 120, 110),
    text   = Color(230, 232, 240),
    dim    = Color(155, 160, 175),
    ok     = Color(110, 210, 130),
    bad    = Color(235, 95, 85),
    gold   = Color(255, 205, 110),
}

-- ============ NET-ПОМОЩНИКИ ============

local function RequestAdminData()
    net.Start("P11FW_AdminData")
    net.SendToServer()
end
P11FW.RequestAdminData = RequestAdminData

local function SendAction(act, writer)
    net.Start("P11FW_AdminAction")
        net.WriteUInt(act, 5)
        if writer then writer() end
    net.SendToServer()
end

local function SendJobEdit(act, rec)
    net.Start("P11FW_JobEdit")
        net.WriteUInt(act, 3)
        net.WriteString(util.TableToJSON(rec) or "{}")
    net.SendToServer()
end

-- ============ ПРИЁМ ДАННЫХ ============

net.Receive("P11FW_AdminData", function()
    if not IsValid(P11FW.AdminFrame) then return end
    local f = P11FW.AdminFrame

    local d = { players = {}, bans = {} }
    d.spawnSet = net.ReadBool()
    d.jailSet  = net.ReadBool()

    local n = net.ReadUInt(8)
    for i = 1, n do
        local p = {
            idx   = net.ReadUInt(8),
            nick  = net.ReadString(),
            jobId = net.ReadString(),
            pun   = net.ReadString(),
            left  = 0,
        }
        if p.pun ~= "" then p.left = net.ReadUInt(10) end
        -- v1.6: ранг / варны / мут для вкладки МОДЕРАЦИЯ
        p.rank     = net.ReadString()
        p.warns    = net.ReadUInt(8)
        p.muted    = net.ReadBool()
        p.muteLeft = p.muted and net.ReadUInt(16) or 0
        p.doc      = net.ReadString() -- v1.6.1: код удостоверения
        d.players[#d.players + 1] = p
    end

    local nb = net.ReadUInt(8)
    for i = 1, nb do
        d.bans[#d.bans + 1] = {
            sid    = net.ReadString(),
            nick   = net.ReadString(),
            reason = net.ReadString(),
            until_ = net.ReadUInt(32),
        }
    end

    f.AdminData = d
    if f.RefreshPlayers  then f:RefreshPlayers() end
    if f.RefreshActs     then f:RefreshActs() end
    if f.RefreshMod      then f:RefreshMod() end
    if f.RefreshFactions then f:RefreshFactions() end
    if f.RefreshUtils    then f:RefreshUtils() end
end)

-- сервер просит открыть меню/обновить данные
net.Receive("P11FW_AdminMenu", function()
    if IsValid(P11FW.AdminFrame) then
        RequestAdminData()
    else
        P11FW.OpenAdminMenu()
    end
end)

-- ============ ОБЩИЕ UI-ХЕЛПЕРЫ ============

local function MakeBtn(parent, text, col, onClick)
    local b = vgui.Create("DButton", parent)
    b:SetText("")
    b.PText = text
    b.PColor = col or AC.text
    b.Paint = function(s, w, h)
        draw.RoundedBox(5, 0, 0, w, h, s:IsHovered() and Color(255, 255, 255, 30) or Color(255, 255, 255, 14))
        draw.SimpleText(s.PText, "P11FW.Text", w / 2, h / 2, s.PColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    b.DoClick = function() surface.PlaySound("buttons/button9.wav") onClick() end
    return b
end

local function ParseListEntry(str)
    -- список через запятую/перенос строки → массив непустых строк
    local out = {}
    str = string.gsub(str or "", "\n", ",")
    for part in string.gmatch(str, "([^,]+)") do
        part = string.Trim(part)
        if part ~= "" then out[#out + 1] = part end
    end
    return out
end

-- ============================================================
--  ГЛАВНОЕ АДМИН-МЕНЮ
-- ============================================================

function P11FW.OpenAdminMenu(forceTab)
    if not IsValid(LocalPlayer()) then return end
    -- v4.4.0: ранги ВАЙТЛИСТА (Faction Officer/Leader) тоже пускаем —
    -- им доступна ОДНА вкладка «ВАЙТЛИСТ», остальное под замком.
    if not P11FW.Config.Admin(LocalPlayer()) then
        if P11FW.CanWhitelist and P11FW.CanWhitelist(LocalPlayer()) then
            forceTab = "whitelist"
        else
            chat.AddText(AC.bad, "[P11FW] Только для администрации.")
            return
        end
    end

    if IsValid(P11FW.AdminFrame) then P11FW.AdminFrame:Remove() end

    local f = vgui.Create("DFrame")
    P11FW.AdminFrame = f
    f.P11FW_Start = SysTime()
    f:SetSize(880, 580)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false)
    f.btnMaxim:SetVisible(false)
    f.btnMinim:SetVisible(false)

    f.ActiveTab = forceTab or "players"

    function f:Paint(w, h)
        Derma_DrawBackgroundBlur(f, f.P11FW_Start or 0)
        draw.RoundedBox(8, 0, 0, w, h, AC.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 50, AC.panel2, true, true, false, false)
        surface.SetDrawColor(AC.accent)
        surface.DrawRect(0, 50, w, 2)
        draw.SimpleText("ПОЛЮС-11 — ПАНЕЛЬ АДМИНИСТРАЦИИ", "P11FW.Title", 16, 12, AC.text)
        draw.SimpleText("P11FW v" .. P11FW.Version, "P11FW.Small", w - 18, 28, AC.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    function f:OnKeyCodePressed(key)
        if key == KEY_ESCAPE then f:Remove() end
    end

    local xBtn = vgui.Create("DButton", f)
    xBtn:SetPos(880 - 38, 10)
    xBtn:SetSize(26, 26)
    xBtn:SetText("✕")
    xBtn:SetFont("P11FW.Big")
    xBtn:SetTextColor(AC.dim)
    xBtn.Paint = function() end
    xBtn.DoClick = function() f:Remove() end

    -- ============ ВКЛАДКИ ============

    local myLevel = P11FW.GetRankLevel(LocalPlayer())
    -- v4.0 (по регламенту владельца): «лишь с ранга Staff Leader — ВСЕ
    -- вкладки; у админов ниже — только банька-телепорты». Уровни:
    --   2 Helper+      → МОДЕРАЦИЯ (варны/муты/баны)
    --   4 Admin+       → ДЕЙСТВИЯ (телепорты/лечки/заморозки)
    --  10 DepStaff+    → ИГРОКИ (выдача рангов, Config.RankManageLevel)
    --  14 StaffLeader+ → ДОЛЖНОСТИ / ФРАКЦИИ / УТИЛИТЫ (всё остальное)
    local canWlTab = P11FW.CanWhitelist and P11FW.CanWhitelist(LocalPlayer())
    -- v4.4.0: +АДМИНКИ (ранги плиткой, 10+) и +ВАЙТЛИСТ (wl-ранги/админы)
    local tabs = {
        { id = "players",   name = "ИГРОКИ",    minLevel = (P11FW.Config and P11FW.Config.RankManageLevel) or 10 },
        { id = "mod",       name = "МОДЕРАЦИЯ", perm = "warn", badge = "!" },
        { id = "acts",      name = "ДЕЙСТВИЯ",  minLevel = 4 },
        { id = "jobs",      name = "ДОЛЖНОСТИ", minLevel = 14 },
        { id = "factions",  name = "ФРАКЦИИ",   minLevel = 14 },
        { id = "utils",     name = "УТИЛИТЫ",   minLevel = 14 },
        { id = "spawns",    name = "СПАВНЫ",    minLevel = 14 }, -- v4.6.1
        { id = "admranks",  name = "АДМИНКИ",   minLevel = (P11FW.Config and P11FW.Config.RankManageLevel) or 10 },
        { id = "whitelist", name = "ВАЙТЛИСТ",  wl = true },
    }

    -- имя ранга по уровню (для красивых отказов)
    local function RankNameByLevel(lvl)
        for _, r in ipairs(P11FW.Ranks or {}) do
            if r.level == lvl then return r.name end
        end
        return "ранг " .. tostring(lvl)
    end
    f.TabPanels = {}
    f.TabButtons = {}

    surface.SetFont("P11FW.Adm.Tab")
    for i, t in ipairs(tabs) do
        local tb = vgui.Create("DButton", f)
        tb:SetPos(12 + (i - 1) * 96, 58) -- v4.6.1: 9 вкладок
        tb:SetSize(92, 32)
        tb:SetText("")
        tb.TabId = t.id
        tb.Paint = function(s, w, h)
            local on = f.ActiveTab == s.TabId
            draw.RoundedBox(5, 0, 0, w, h, on and Color(AC.accent.r, AC.accent.g, AC.accent.b, 55) or Color(255, 255, 255, 8))
            if on then
                surface.SetDrawColor(AC.accent)
                surface.DrawRect(10, h - 2, w - 20, 2)
            end
            -- вкладки под права/ранг — без них текст серый
            local col = on and AC.accent or AC.dim
            if (t.perm and not P11FW.CanMod(LocalPlayer(), t.perm))
               or (t.minLevel and myLevel < t.minLevel)
               or (t.wl and not canWlTab) then
                col = Color(90, 95, 105)
            end
            draw.SimpleText(t.name, "P11FW.Adm.Tab", w / 2 - (t.badge and 8 or 0), h / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            if t.badge then
                draw.SimpleText(t.badge, "P11FW.Small", w - 14, 4,
                    P11FW.CanMod(LocalPlayer(), t.perm) and AC.gold or Color(90, 95, 105))
            end
        end
        tb.DoClick = function()
            if t.perm and not P11FW.CanMod(LocalPlayer(), t.perm) then
                surface.PlaySound("buttons/button10.wav") -- недоступно рангу
                chat.AddText(AC.gold, "[P11FW] Вкладка «" .. t.name .. "» доступна с ранга Helper (2).")
                return
            end
            if t.minLevel and myLevel < t.minLevel then
                surface.PlaySound("buttons/button10.wav")
                chat.AddText(AC.gold, "[P11FW] Вкладка «" .. t.name .. "» — с ранга " .. RankNameByLevel(t.minLevel) .. ".")
                return
            end
            if t.wl and not canWlTab then
                surface.PlaySound("buttons/button10.wav")
                chat.AddText(AC.gold, "[P11FW] Вкладка «" .. t.name .. "» — администрации и рангам Faction Officer/Leader.")
                return
            end
            f.ActiveTab = t.id
            for id, p in pairs(f.TabPanels) do p:SetVisible(id == t.id) end
            if t.id == "players" or t.id == "utils" or t.id == "acts" or t.id == "mod" then RequestAdminData() end
            if t.id == "admranks" and f.RefreshAdmRanks then f:RefreshAdmRanks() end
            if t.id == "whitelist" and f.RefreshWhitelistTab then f:RefreshWhitelistTab() end
            surface.PlaySound("buttons/button15.wav")
        end
        f.TabButtons[t.id] = tb
    end

    -- контейнер вкладок
    local function NewTab(id)
        local p = vgui.Create("DPanel", f)
        p:SetPos(12, 98)
        p:SetSize(856, 470)
        p.Paint = function(s, w, h) draw.RoundedBox(6, 0, 0, w, h, AC.panel) end
        p:SetVisible(id == f.ActiveTab)
        f.TabPanels[id] = p
        return p
    end

    -- ==================================================
    --  ВКЛАДКА 1: ИГРОКИ
    -- ==================================================
    do
        local p = NewTab("players")

        local lv = vgui.Create("DListView", p)
        lv:SetPos(10, 10)
        lv:SetSize(520, 450)
        lv:SetMultiSelect(false)
        lv:AddColumn("Ник"):SetFixedWidth(170)
        lv:AddColumn("КОД"):SetFixedWidth(105)
        lv:AddColumn("Должность"):SetFixedWidth(130)
        lv:AddColumn("Статус"):SetFixedWidth(70)
        lv:AddColumn("Осталось")

        f.PlayersList = lv

        function f:RefreshPlayers()
            lv:Clear()
            for _, pl in ipairs((self.AdminData and self.AdminData.players) or {}) do
                local job = P11FW.Jobs[pl.jobId]
                local status = pl.pun == "arrest" and "АРЕСТ" or pl.pun == "slavery" and "РАБСТВО" or pl.pun == "ban" and "БАН" or "—"
                local line = lv:AddLine(pl.nick, pl.doc ~= "" and pl.doc or "—", job and job.name or pl.jobId,
                    status, pl.pun ~= "" and (pl.left .. " мин") or "")
                line.PlayerIdx = pl.idx
            end
        end

        -- панель действий
        local act = vgui.Create("DPanel", p)
        act:SetPos(540, 10)
        act:SetSize(306, 450)
        act.Paint = function(s, w, h) draw.RoundedBox(6, 0, 0, w, h, AC.panel2) end

        local title = vgui.Create("DLabel", act)
        title:SetPos(10, 8)
        title:SetSize(286, 22)
        title:SetFont("P11FW.Big")
        title:SetTextColor(AC.text)
        title:SetText("Выбери игрока слева")

        lv.OnRowSelected = function(s, id, line)
            title:SetText("Цель: " .. (line:GetValue(1) or "?"))
        end

        local function SelectedIdx()
            local id = lv:GetSelectedLine()
            if not id then return nil end
            local line = lv:GetLine(id)
            return line and line.PlayerIdx or nil
        end

        -- минуты и причина
        local minsLbl = vgui.Create("DLabel", act)
        minsLbl:SetPos(10, 36) minsLbl:SetSize(150, 18)
        minsLbl:SetFont("P11FW.Small") minsLbl:SetTextColor(AC.dim)
        minsLbl:SetText("Срок (минут):")

        local mins = vgui.Create("DNumberWang", act)
        mins:SetPos(10, 56) mins:SetSize(90, 26)
        mins:SetMinMax(1, 10080) mins:SetValue(5)

        local rsLbl = vgui.Create("DLabel", act)
        rsLbl:SetPos(112, 36) rsLbl:SetSize(180, 18)
        rsLbl:SetFont("P11FW.Small") rsLbl:SetTextColor(AC.dim)
        rsLbl:SetText("Причина:")

        local reason = vgui.Create("DTextEntry", act)
        reason:SetPos(112, 56) reason:SetSize(184, 26)
        reason:SetPlaceholderText("нарушение порядка...")

        -- кнопки наказаний
        local grid = vgui.Create("DIconLayout", act)
        grid:SetPos(10, 92)
        grid:SetSize(286, 200)
        grid:SetSpaceX(6) grid:SetSpaceY(6)

        local function PunishBtn(name, actId, col)
            local b = MakeBtn(grid, name, col, function()
                local idx = SelectedIdx()
                if not idx then surface.PlaySound("buttons/button10.wav") return end
                SendAction(actId, function()
                    net.WriteUInt(idx, 8)
                    net.WriteUInt(math.max(1, mins:GetValue()), 16)
                    net.WriteString(reason:GetValue())
                end)
            end)
            b:SetSize(138, 36)
            -- v1.6: спрятать то, чего не позволяет ранг
            local need = (actId == 3) and "ban" or "arrest"
            if not P11FW.CanMod(LocalPlayer(), need) then
                b.PColor = AC.dim
                b:SetEnabled(false)
            end
        end

        PunishBtn("АРЕСТ", 1, Color(255, 130, 110))
        PunishBtn("РАБСТВО", 2, Color(255, 160, 95))
        PunishBtn("БАН", 3, AC.bad)
        PunishBtn("ОСВОБОДИТЬ", 4, AC.ok)

        local dem = MakeBtn(act, "УВОЛИТЬ С ДОЛЖНОСТИ", AC.gold, function()
            local idx = SelectedIdx()
            if not idx then surface.PlaySound("buttons/button10.wav") return end
            SendAction(5, function() net.WriteUInt(idx, 8) end)
        end)
        dem:SetPos(10, 252) dem:SetSize(286, 32)

        -- выдать должность
        local comboLbl = vgui.Create("DLabel", act)
        comboLbl:SetPos(10, 296) comboLbl:SetSize(286, 18)
        comboLbl:SetFont("P11FW.Small") comboLbl:SetTextColor(AC.dim)
        comboLbl:SetText("Выдать должность насильно:")

        local combo = vgui.Create("DComboBox", act)
        combo:SetPos(10, 316) combo:SetSize(286, 28)
        combo:SetValue("— выбери должность —")
        combo.JobIds = {}
        for _, jobId in ipairs(P11FW.JobIds) do
            combo:AddChoice(P11FW.Jobs[jobId].name, jobId)
        end

        local give = MakeBtn(act, "ПРИМЕНИТЬ ДОЛЖНОСТЬ", AC.ok, function()
            local idx = SelectedIdx()
            local _, jobId = combo:GetSelected()
            if not idx or not jobId then surface.PlaySound("buttons/button10.wav") return end
            SendAction(6, function()
                net.WriteUInt(idx, 8)
                net.WriteString(jobId)
            end)
        end)
        give:SetPos(10, 352) give:SetSize(286, 34)

        local refr = MakeBtn(act, "ОБНОВИТЬ СПИСОК", AC.dim, function() RequestAdminData() end)
        refr:SetPos(10, 396) refr:SetSize(286, 30)
    end

    -- ==================================================
    --  ВКЛАДКА: МОДЕРАЦИЯ (варн/мут/кик/бан — права по рангам)
    -- ==================================================
    do
        local p = NewTab("mod")
        local me = LocalPlayer()
        local function Can(perm) return P11FW.CanMod(me, perm) end

        local lv = vgui.Create("DListView", p)
        lv:SetPos(10, 10)
        lv:SetSize(396, 450)
        lv:SetMultiSelect(false)
        lv:AddColumn("Ник"):SetFixedWidth(160)
        lv:AddColumn("Ранг"):SetFixedWidth(112)
        lv:AddColumn("Варны"):SetFixedWidth(55)
        lv:AddColumn("Мут")

        function f:RefreshMod()
            lv:Clear()
            for _, pl in ipairs((self.AdminData and self.AdminData.players) or {}) do
                local r = P11FW.RankById and P11FW.RankById[pl.rank or "user"]
                local rname = r and r.name or (pl.rank or "user")
                local muteTxt = pl.muted and (pl.muteLeft .. " мин") or "—"
                local line = lv:AddLine(pl.nick, rname, pl.warns or 0, muteTxt)
                if r and r.color then line.Columns[2]:SetTextColor(r.color) end
                if (pl.warns or 0) > 0 then line.Columns[3]:SetTextColor(AC.gold) end
                if pl.muted then line.Columns[4]:SetTextColor(Color(235, 145, 90)) end
                line.PlayerIdx = pl.idx
            end
        end

        local ap = vgui.Create("DPanel", p)
        ap:SetPos(416, 10)
        ap:SetSize(430, 450)
        ap.Paint = function(s, w, h) draw.RoundedBox(6, 0, 0, w, h, AC.panel2) end

        local ttl = vgui.Create("DLabel", ap)
        ttl:SetPos(10, 8) ttl:SetSize(410, 22)
        ttl:SetFont("P11FW.Big") ttl:SetTextColor(AC.text)
        ttl:SetText("Цель: — выбери игрока слева")

        lv.OnRowSelected = function(s, id, line)
            ttl:SetText("Цель: " .. (line:GetValue(1) or "?"))
        end

        local function Sel()
            local id = lv:GetSelectedLine()
            if not id then return nil end
            local line = lv:GetLine(id)
            return line and line.PlayerIdx or nil
        end

        local rsLbl = vgui.Create("DLabel", ap)
        rsLbl:SetPos(10, 32) rsLbl:SetSize(410, 16)
        rsLbl:SetFont("P11FW.Small") rsLbl:SetTextColor(AC.dim)
        rsLbl:SetText("Причина (общая для всех кнопок ниже):")

        local reason = vgui.Create("DTextEntry", ap)
        reason:SetPos(10, 50) reason:SetSize(410, 26)
        reason:SetPlaceholderText("например: стрельба по своим / флуд в чат...")

        local mutLbl = vgui.Create("DLabel", ap)
        mutLbl:SetPos(10, 84) mutLbl:SetSize(140, 16)
        mutLbl:SetFont("P11FW.Small") mutLbl:SetTextColor(AC.dim)
        mutLbl:SetText("Минут для МУТА:")

        local mutW = vgui.Create("DNumberWang", ap)
        mutW:SetPos(120, 80) mutW:SetSize(90, 24)
        local mutLim = P11FW.PunishLimit(me, "mute")
        mutW:SetMinMax(1, mutLim and (mutLim > 0 and mutLim or 20160) or 1)
        mutW:SetValue(10)

        -- ---- кнопки простых действий ----
        local function Guarded(col, fn)
            return function()
                local idx = Sel()
                if not idx then surface.PlaySound("buttons/button10.wav") return end
                fn(idx)
            end
        end

        local bWarn = MakeBtn(ap, "ВЫДАТЬ ВАРН", AC.gold, Guarded(AC.gold, function(idx)
            SendAction(25, function()
                net.WriteUInt(idx, 8)
                net.WriteString(reason:GetValue())
            end)
        end))
        bWarn:SetPos(10, 112) bWarn:SetSize(202, 32)

        local bMute = MakeBtn(ap, "ЗАМУТИТЬ", Color(235, 145, 90), Guarded(nil, function(idx)
            SendAction(26, function()
                net.WriteUInt(idx, 8)
                net.WriteUInt(math.max(1, mutW:GetValue()), 16)
                net.WriteString(reason:GetValue())
            end)
        end))
        bMute:SetPos(218, 112) bMute:SetSize(202, 32)

        local bUnmute = MakeBtn(ap, "СНЯТЬ МУТ", AC.ok, Guarded(nil, function(idx)
            SendAction(27, function() net.WriteUInt(idx, 8) end)
        end))
        bUnmute:SetPos(10, 148) bUnmute:SetSize(202, 32)

        local bKick = MakeBtn(ap, "КИКНУТЬ", Color(240, 105, 95), Guarded(nil, function(idx)
            SendAction(28, function()
                net.WriteUInt(idx, 8)
                net.WriteString(reason:GetValue())
            end)
        end))
        bKick:SetPos(218, 148) bKick:SetSize(202, 32)

        local bUnwarn = MakeBtn(ap, "ОЧИСТИТЬ ВАРНЫ", Color(170, 195, 140), Guarded(nil, function(idx)
            SendAction(30, function() net.WriteUInt(idx, 8) end)
        end))
        bUnwarn:SetPos(10, 184) bUnwarn:SetSize(202, 32)

        -- ---- секция БАНА ----
        local banHead = vgui.Create("DLabel", ap)
        banHead:SetPos(10, 226) banHead:SetSize(410, 20)
        banHead:SetFont("P11FW.Big") banHead:SetTextColor(AC.bad)
        banHead:SetText("— БАН —")

        local banSub = vgui.Create("DLabel", ap)
        banSub:SetPos(10, 248) banSub:SetSize(410, 14)
        banSub:SetFont("P11FW.Small") banSub:SetTextColor(AC.dim)
        banSub:SetText("Срок: дни / часы / минуты (или галочка навсегда):")

        local banD = vgui.Create("DNumberWang", ap)
        banD:SetPos(50, 268) banD:SetSize(60, 24)
        banD:SetMinMax(0, 365) banD:SetValue(0)
        local dl = vgui.Create("DLabel", ap)
        dl:SetPos(10, 272) dl:SetSize(40, 16)
        dl:SetFont("P11FW.Small") dl:SetTextColor(AC.text) dl:SetText("Дни:")

        local banH = vgui.Create("DNumberWang", ap)
        banH:SetPos(156, 268) banH:SetSize(54, 24)
        banH:SetMinMax(0, 23) banH:SetValue(0)
        local hl = vgui.Create("DLabel", ap)
        hl:SetPos(116, 272) hl:SetSize(40, 16)
        hl:SetFont("P11FW.Small") hl:SetTextColor(AC.text) hl:SetText("Часы:")

        local banM = vgui.Create("DNumberWang", ap)
        banM:SetPos(256, 268) banM:SetSize(54, 24)
        banM:SetMinMax(0, 59) banM:SetValue(30)
        local ml = vgui.Create("DLabel", ap)
        ml:SetPos(216, 272) ml:SetSize(40, 16)
        ml:SetFont("P11FW.Small") ml:SetTextColor(AC.text) ml:SetText("Мин.:")

        local permC = vgui.Create("DCheckBoxLabel", ap)
        permC:SetPos(318, 272) permC:SetSize(102, 16)
        permC:SetFont("P11FW.Small") permC:SetTextColor(AC.bad)
        permC:SetText("НАВСЕГДА")
        permC:SetChecked(false)

        local lim = P11FW.PunishLimit(me, "ban")
        local limLbl = vgui.Create("DLabel", ap)
        limLbl:SetPos(10, 298) limLbl:SetSize(410, 16)
        limLbl:SetFont("P11FW.Small") limLbl:SetTextColor(AC.gold)
        if lim == nil then
            limLbl:SetText("БАН недоступен — нужен ранг Админ (4) и выше.")
        elseif lim == 0 then
            limLbl:SetText("Твой лимит: БЕЗЛИМИТ (можно навсегда).")
        else
            limLbl:SetText("Твой лимит: до " .. P11FW.FmtMinutes(lim) .. " — перманент только у Главы.")
        end

        local bBan = MakeBtn(ap, "ЗАБАНИТЬ", AC.bad, Guarded(nil, function(idx)
            local total = math.floor(banD:GetValue()) * 1440
                + math.floor(banH:GetValue()) * 60
                + math.floor(banM:GetValue())
            if permC:GetChecked() then total = 0 end
            if not permC:GetChecked() and total < 1 then
                surface.PlaySound("buttons/button10.wav")
                return
            end
            SendAction(29, function()
                net.WriteUInt(idx, 8)
                net.WriteUInt(total, 20)
                net.WriteString(reason:GetValue())
            end)
        end))
        bBan:SetPos(10, 318) bBan:SetSize(410, 34)

        -- памятка лестницы прав
        local info = vgui.Create("DLabel", ap)
        info:SetPos(10, 360) info:SetSize(410, 60)
        info:SetFont("P11FW.Small") info:SetTextColor(AC.dim)
        info:SetAutoStretchVertical(true)
        info:SetText("Лестница прав: Хелпер — варн + мут до 30 мин.;\n" ..
            "Модератор — кик, арест до 1 ч., мут до 4 ч.;\n" ..
            "Админ — бан до 3 сут.; Куратор — 7 сут.;\n" ..
            "Суперадмин — 30 сут. + разбан; Глава — навсегда.")

        -- серые кнопки по правам
        local function Gate(btn, perm)
            if not Can(perm) then
                btn.PColor = AC.dim
                btn:SetEnabled(false)
            end
        end
        Gate(bWarn, "warn")   Gate(bMute, "mute")  Gate(bUnmute, "mute")
        Gate(bUnwarn, "warn") Gate(bKick, "kick")  Gate(bBan, "ban")
        if not Can("mute") then mutW:SetEnabled(false) end
        if not Can("ban") then
            banD:SetEnabled(false) banH:SetEnabled(false) banM:SetEnabled(false)
        end
        if lim ~= 0 then permC:SetEnabled(false) end

        local refr = MakeBtn(ap, "ОБНОВИТЬ СПИСОК", AC.dim, function() RequestAdminData() end)
        refr:SetPos(10, 418) refr:SetSize(410, 26)
    end

    -- ==================================================
    --  ВКЛАДКА 2: ДОЛЖНОСТИ (редактор профессий)
    -- ==================================================
    do
        local p = NewTab("jobs")

        local lv = vgui.Create("DListView", p)
        lv:SetPos(10, 10) lv:SetSize(360, 450)
        lv:SetMultiSelect(false)
        lv:AddColumn("Должность"):SetFixedWidth(150)
        lv:AddColumn("Фракция"):SetFixedWidth(110)
        lv:AddColumn("Мест"):SetFixedWidth(45)
        lv:AddColumn("Тип")
        f.JobsList = lv

        function f:RefreshJobsTab()
            lv:Clear()
            for _, jobId in ipairs(P11FW.JobIds) do
                local job = P11FW.Jobs[jobId]
                local catName = job.category
                for _, c in ipairs(P11FW.CategoryList) do
                    if c.id == job.category then catName = c.name end
                end
                local line = lv:AddLine((job.whitelist and "🔒 " or "") .. job.name, catName, (job.max or 0) > 0 and job.max or "∞",
                    (job.whitelist and "🔒 " or "") .. (job.custom and "КАСТОМ" or job.overridden and "ПРАВКА" or "встроенная"))
                line.JobId = jobId
            end
        end
        f:RefreshJobsTab()

        -- форма
        local form = vgui.Create("DPanel", p)
        form:SetPos(380, 10) form:SetSize(466, 450)
        form.Paint = function(s, w, h) draw.RoundedBox(6, 0, 0, w, h, AC.panel2) end

        local function Lbl(txt, x, y)
            local l = vgui.Create("DLabel", form)
            l:SetPos(x, y) l:SetSize(300, 16)
            l:SetFont("P11FW.Small") l:SetTextColor(AC.dim)
            l:SetText(txt)
            return l
        end

        Lbl("Название должности:", 10, 8)
        local nameE = vgui.Create("DTextEntry", form)
        nameE:SetPos(10, 26) nameE:SetSize(280, 26)
        nameE:SetPlaceholderText("Киномеханик")

        Lbl("Фракция:", 300, 8)
        local catC = vgui.Create("DComboBox", form)
        catC:SetPos(300, 26) catC:SetSize(156, 26)
        for _, c in ipairs(P11FW.CategoryList) do
            catC:AddChoice(c.name, c.id)
        end
        catC:SetValue(P11FW.CategoryList[3] and P11FW.CategoryList[3].name or "misc")

        Lbl("Мест (0 = без лимита):", 10, 58)
        local maxW = vgui.Create("DNumberWang", form)
        maxW:SetPos(10, 76) maxW:SetSize(80, 26)
        maxW:SetMinMax(0, 32) maxW:SetValue(0)

        -- v4.5.0: ВРЕМЯ ИГРЫ для входа на профу (минут, 0 = без требования;
        -- Super Admin+ обходит). Галочка 🔒 ВАЙТЛИСТ — правее.
        Lbl("Время (мин):", 96, 58)
        local timeW = vgui.Create("DNumberWang", form)
        timeW:SetPos(96, 76) timeW:SetSize(80, 26)
        timeW:SetMinMax(0, 50000) timeW:SetValue(0)
        timeW:SetTooltip("сколько минут игры нужно для этой должности (0 = нет)")

        Lbl("Цвет должности:", 190, 58)

        -- v3.8: вместо трёх ползунков R/G/B — УДОБНАЯ ПАЛИТРА:
        -- быстрые квадратики станционных цветов + точный подбор
        -- через DColorMixer (клик по превью). Всё в одном месте и
        -- больше не залезает на поле «Название должности».
        local jobCol = Color(210, 170, 120)

        local colPrev = vgui.Create("DButton", form)
        colPrev:SetPos(190, 76) colPrev:SetSize(52, 30)
        colPrev:SetText("")
        colPrev:SetTooltip("клик — точная палитра (цветовое колесо и числа RGB)")
        colPrev.Paint = function(s, w, h)
            draw.RoundedBox(5, 0, 0, w, h, jobCol)
            surface.SetDrawColor(255, 255, 255, 110)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            if s:IsHovered() then
                draw.RoundedBox(5, 0, 0, w, h, Color(255, 255, 255, 20))
            end
        end
        colPrev.DoClick = function()
            surface.PlaySound("buttons/button15.wav")
            if IsValid(P11FW.JobColorMixer) then
                P11FW.JobColorMixer:Remove()
                P11FW.JobColorMixer = nil
                return
            end
            local mx = vgui.Create("DFrame")
            P11FW.JobColorMixer = mx
            mx:SetSize(300, 324)
            local fx, fy = 60, 110
            if IsValid(P11FW.AdminFrame) then fx, fy = P11FW.AdminFrame:GetPos() end
            mx:SetPos(fx + 420, fy + 84)
            mx:SetTitle("")
            mx:MakePopup()
            mx:SetDeleteOnClose(true)
            mx.btnMaxim:SetVisible(false) mx.btnMinim:SetVisible(false)
            mx.Paint = function(s, w, h)
                Derma_DrawBackgroundBlur(s, s.T0 or SysTime())
                draw.RoundedBox(8, 0, 0, w, h, Color(16, 18, 24, 248))
                draw.RoundedBoxEx(8, 0, 0, w, 30, Color(26, 30, 40), true, true, false, false)
                draw.SimpleText("ПАЛИТРА ЦВЕТА ДОЛЖНОСТИ", "P11FW.Small", 10, 15,
                    AC.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            mx.T0 = SysTime()
            mx.OnRemove = function() P11FW.JobColorMixer = nil end
            local mixer = vgui.Create("DColorMixer", mx)
            mixer:Dock(FILL)
            mixer:DockMargin(8, 36, 8, 8)
            mixer:SetPalette(true)
            mixer:SetAlphaBar(false)
            mixer:SetWangs(true)
            mixer:SetColor(jobCol)
            mixer.ValueChanged = function(s, col)
                jobCol = Color(col.r, col.g, col.b)
            end
            -- самоликвидация, когда админ-окно закрыли
            mx.Think = function()
                if not IsValid(P11FW.AdminFrame) and IsValid(mx) then mx:Remove() end
            end
        end

        local PRESETS = {
            Color(120, 190, 235),  Color(150, 230, 190),  Color(100, 210, 130),  Color(90, 150, 110),
            Color(255, 205, 110),  Color(230, 160, 90),   Color(185, 160, 110),  Color(140, 220, 240),
            Color(235, 120, 110),  Color(220, 190, 90),   Color(130, 170, 230),  Color(200, 120, 235),
            Color(220, 220, 230),  Color(160, 170, 180),  Color(120, 120, 145),  Color(235, 90, 85),
        }
        for i, pc in ipairs(PRESETS) do
            local pcx, prow = (i - 1) % 8, math.floor((i - 1) / 8)
            local sw = vgui.Create("DButton", form)
            sw:SetPos(190 + pcx * 30, 112 + prow * 30)
            sw:SetSize(26, 26)
            sw:SetText("")
            sw:SetTooltip(string.format("RGB %d/%d/%d", pc.r, pc.g, pc.b))
            sw.Paint = function(s, w, h)
                draw.RoundedBox(4, 0, 0, w, h, pc)
                local sel = pc.r == jobCol.r and pc.g == jobCol.g and pc.b == jobCol.b
                surface.SetDrawColor(255, 255, 255, sel and 235 or (s:IsHovered() and 130 or 50))
                surface.DrawOutlinedRect(0, 0, w, h, sel and 2 or 1)
            end
            sw.DoClick = function()
                jobCol = Color(pc.r, pc.g, pc.b)
                surface.PlaySound("buttons/button9.wav")
                if IsValid(P11FW.JobColorMixer) then P11FW.JobColorMixer:Remove() end
            end
        end

        Lbl("Модели (по одной через запятую):", 10, 174)
        local modelsE = vgui.Create("DTextEntry", form)
        modelsE:SetPos(10, 192) modelsE:SetSize(360, 46)
        modelsE:SetMultiline(true)
        modelsE:SetPlaceholderText("models/player/kleiner.mdl, models/player/eli.mdl")

        local addMyModel = MakeBtn(form, "+ МОЯ МОДЕЛЬ", AC.accent, function()
            local m = LocalPlayer():GetModel()
            local cur = string.Trim(modelsE:GetValue())
            modelsE:SetValue(cur == "" and m or (cur .. ", " .. m))
        end)
        addMyModel:SetPos(376, 192) addMyModel:SetSize(80, 24)

        Lbl("Оружие (классы через запятую):", 10, 248)
        local wepsE = vgui.Create("DTextEntry", form)
        wepsE:SetPos(10, 266) wepsE:SetSize(360, 46)
        wepsE:SetMultiline(true)
        wepsE:SetPlaceholderText("weapon_polus11_radio, weapon_pistol")

        local addMyWep = MakeBtn(form, "+ ОРУЖИЕ В РУКАХ", AC.accent, function()
            local w = LocalPlayer():GetActiveWeapon()
            if not IsValid(w) then return end
            local cls = w:GetClass()
            local cur = string.Trim(wepsE:GetValue())
            wepsE:SetValue(cur == "" and cls or (cur .. ", " .. cls))
        end)
        addMyWep:SetPos(376, 266) addMyWep:SetSize(80, 24)

        Lbl("Описание (видно в F4):", 10, 322)
        local descE = vgui.Create("DTextEntry", form)
        descE:SetPos(10, 340) descE:SetSize(446, 46)
        descE:SetMultiline(true)
        descE:SetPlaceholderText("Что делает эта должность на станции...")

        -- v1.5: допуск к сменному терминалу
        local termC = vgui.Create("DCheckBoxLabel", form)
        termC:SetPos(10, 390) termC:SetSize(440, 16)
        termC:SetFont("P11FW.Small") termC:SetTextColor(Color(120, 210, 240))
        termC:SetText("Допуск к СМЕННОМУ ТЕРМИНАЛУ (выдача доп-задач экипажу)")
        termC:SetChecked(false)

        -- v4.4.0: ВАЙТЛИСТ-галочка — вход на должность только с допуском
        local wlC = vgui.Create("DCheckBoxLabel", form)
        wlC:SetPos(300, 76) wlC:SetSize(156, 26)
        wlC:SetFont("P11FW.Small") wlC:SetTextColor(Color(255, 180, 110))
        wlC:SetText("🔒 ВАЙТЛИСТ")
        wlC:SetTooltip("вход на должность ТОЛЬКО с допуском\n(его выдают во вкладке ВАЙТЛИСТ)")
        wlC:SetChecked(false)

        -- выбранная строка списка → заполнить форму
        local editingId = nil
        local editingKind = nil -- "custom" | "override" | "builtin" (v3.8.1)
        local status = vgui.Create("DLabel", form)
        status:SetPos(10, 406) status:SetSize(446, 14)
        status:SetFont("P11FW.Small") status:SetTextColor(AC.gold)
        status:SetText("Новая должность (или выбери КАСТОМ из списка для правки)")

        local function CollectForm()
            local _, catId = catC:GetSelected()
            return {
                name     = nameE:GetValue(),
                category = catId or "misc",
                desc     = descE:GetValue(),
                max      = maxW:GetValue(),
                terminal = termC:GetChecked(),
                whitelist = wlC:GetChecked(), -- v4.4.0
                time     = timeW:GetValue(), -- v4.5.0
                color    = { r = jobCol.r, g = jobCol.g, b = jobCol.b },
                models   = ParseListEntry(modelsE:GetValue()),
                weapons  = ParseListEntry(wepsE:GetValue()),
            }
        end

        lv.OnRowSelected = function(s, id, line)
            local jobId = line.JobId
            local job = P11FW.Jobs[jobId]
            if not job then return end
            nameE:SetValue(job.name)
            descE:SetValue(job.desc or "")
            maxW:SetValue(job.max or 0)
            modelsE:SetValue(table.concat(job.models or {}, ", "))
            wepsE:SetValue(table.concat(job.weapons or {}, ", "))
            for _, c in ipairs(P11FW.CategoryList) do
                if c.id == job.category then catC:SetValue(c.name) end
            end
            if job.color then
                jobCol = Color(job.color.r, job.color.g, job.color.b)
            end
            termC:SetChecked(job.terminal == true)
            wlC:SetChecked(job.whitelist == true) -- v4.4.0
            timeW:SetValue(job.time or 0) -- v4.5.0
            editingId = jobId -- v3.8.1: встроенные ТОЖЕ редактируются (переопределением)
            editingKind = job.custom and "custom" or job.overridden and "override" or "builtin"
            status:SetText(job.custom and ("Правим КАСТОМНУЮ: " .. job.name)
                or job.overridden and ("Правим ПРАВКУ: " .. job.name)
                or ("Встроенная: «" .. job.name .. "» → сохранит как ПРАВКУ"))
        end

        local btnCreate = MakeBtn(form, "СОЗДАТЬ НОВУЮ", AC.ok, function()
            local rec = CollectForm()
            if string.Trim(rec.name) == "" then status:SetText("⚠ впиши название!") surface.PlaySound("buttons/button10.wav") return end
            SendJobEdit(1, rec)
            status:SetText("Отправлено на сервер...")
        end)
        btnCreate:SetPos(10, 424) btnCreate:SetSize(146, 24)

        local btnUpdate = MakeBtn(form, "СОХРАНИТЬ ПРАВКУ", AC.accent, function()
            if not editingId then status:SetText("⚠ сначала выбери должность из списка!") surface.PlaySound("buttons/button10.wav") return end
            local rec = CollectForm()
            rec.id = editingId
            SendJobEdit(2, rec)
            editingKind = "override"
            status:SetText("Сохранено (" .. (editingKind == "builtin" and "создана ПРАВКА" or "правка") .. "). Синк на сервер...")
        end)
        btnUpdate:SetPos(162, 424) btnUpdate:SetSize(146, 24)

        local btnDelete = MakeBtn(form, "УДАЛИТЬ/СНЯТЬ", AC.bad, function()
            if not editingId then status:SetText("⚠ сначала выбери должность!") surface.PlaySound("buttons/button10.wav") return end
            if editingKind == "builtin" then status:SetText("⚠ заводскую без правки удалять нельзя!") surface.PlaySound("buttons/button10.wav") return end
            SendJobEdit(3, { id = editingId })
            editingId = nil editingKind = nil
            status:SetText("Удалено/правка снята.")
        end)
        btnDelete:SetPos(314, 424) btnDelete:SetSize(142, 24)

        -- авто-обновление списка при синке с сервера
        f.JobsTabStatus = status
    end

    -- ==================================================
    --  ВКЛАДКА: ДЕЙСТВИЯ С ИГРОКОМ (лечить/возродить/тп/заморозить)
    -- ==================================================
    do
        local p = NewTab("acts")

        local lv = vgui.Create("DListView", p)
        lv:SetPos(10, 10) lv:SetSize(430, 450)
        lv:SetMultiSelect(false)
        lv:AddColumn("Ник"):SetFixedWidth(150)
        lv:AddColumn("Должность"):SetFixedWidth(110)
        lv:AddColumn("Фракция"):SetFixedWidth(95) -- v3.8: сразу видно, чья профа и толпа
        lv:AddColumn("Статус")

        local function FactionNameOf(job)
            local cid = job and (job.faction or job.category) or nil
            for _, c in ipairs(P11FW.CategoryList or {}) do
                if c.id == cid then return c.name, c.color end
            end
            return "—", nil
        end

        function f:RefreshActs()
            lv:Clear()
            for _, pl in ipairs((self.AdminData and self.AdminData.players) or {}) do
                local job = P11FW.Jobs[pl.jobId]
                local facName, facColor = FactionNameOf(job)
                local status = pl.pun == "arrest" and "АРЕСТ" or pl.pun == "slavery" and "РАБСТВО" or pl.pun == "ban" and "БАН" or "—"
                local line = lv:AddLine(pl.nick, job and job.name or pl.jobId, facName, status)
                -- цветные столбики для читаемости (v3.8)
                if facColor then line.Columns[3]:SetTextColor(facColor) end
                if status ~= "—" then line.Columns[4]:SetTextColor(AC.bad) end
                line.PlayerIdx = pl.idx
            end
        end

        local ap = vgui.Create("DPanel", p)
        ap:SetPos(450, 10) ap:SetSize(396, 450)
        ap.Paint = function(s, w, h) draw.RoundedBox(6, 0, 0, w, h, AC.panel2) end

        local ttl = vgui.Create("DLabel", ap)
        ttl:SetPos(12, 8) ttl:SetSize(370, 22)
        ttl:SetFont("P11FW.Big") ttl:SetTextColor(AC.text)
        ttl:SetText("Цель: —")

        lv.OnRowSelected = function(s, id, line)
            ttl:SetText("Цель: " .. (line:GetValue(1) or "?"))
        end

        local function Sel()
            local id = lv:GetSelectedLine()
            if not id then return nil end
            local line = lv:GetLine(id)
            return line and line.PlayerIdx or nil
        end

        local hint = vgui.Create("DLabel", ap)
        hint:SetPos(12, 32) hint:SetSize(370, 34)
        hint:SetFont("P11FW.Small") hint:SetTextColor(AC.dim)
        hint:SetText("Быстрые рабочие действия. Выбери игрока слева,\nпотом жми кнопку. Никаких сроков и записей.")

        local grid = vgui.Create("DIconLayout", ap)
        grid:SetPos(12, 76) grid:SetSize(372, 340)
        grid:SetSpaceX(6) grid:SetSpaceY(6)

        local canHeal = P11FW.CanMod(LocalPlayer(), "heal")

        local function ActBtn(name, actId, col)
            local b = MakeBtn(grid, name, col, function()
                local idx = Sel()
                if not idx then surface.PlaySound("buttons/button10.wav") return end
                SendAction(actId, function() net.WriteUInt(idx, 8) end)
            end)
            b:SetSize(180, 44)
            if not canHeal then -- v1.6: быстрые действия — с ранга Админ (4)
                b.PColor = AC.dim
                b:SetEnabled(false)
            end
        end

        ActBtn("ЛЕЧИТЬ ПОЛНОСТЬЮ", 14, AC.ok)
        ActBtn("ВОЗРОДИТЬ",       15, Color(230, 200, 120))
        ActBtn("ПРИТАЩИТЬ К СЕБЕ",16, Color(150, 190, 240))
        ActBtn("ТЕЛЕПОРТ К НЕМУ", 17, Color(150, 190, 240))
        ActBtn("ЗАМОРОЗИТЬ/РАЗМ.",18, Color(170, 175, 190))
        ActBtn("УБИТЬ",           19, AC.bad)

        -- v1.5: выдача рангов (сервер пустит только Куратор+)
        local rankLbl = vgui.Create("DLabel", ap)
        rankLbl:SetPos(12, 246) rankLbl:SetSize(372, 16)
        rankLbl:SetFont("P11FW.Small") rankLbl:SetTextColor(AC.gold)
        rankLbl:SetText("РАНГ АДМИНИСТРАЦИИ (User→VIP→Хелпер→…→Глава Полюса-11):")

        local rankC = vgui.Create("DComboBox", ap)
        rankC:SetPos(12, 264) rankC:SetSize(372, 26)
        rankC:SetValue("— выбери ранг —")
        for _, r in ipairs(P11FW.Ranks or {}) do
            local function paintChoice(self2, w, h) end
            rankC:AddChoice(r.name .. "  [" .. r.level .. "]", r.id, false, "")
        end

        local rankBtn = MakeBtn(ap, "ВЫДАТЬ РАНГ ВЫБРАННОМУ", AC.gold, function()
            local idx = Sel()
            local _, rid = rankC:GetSelected()
            if not idx or not rid then surface.PlaySound("buttons/button10.wav") return end
            SendAction(22, function()
                net.WriteUInt(idx, 8)
                net.WriteString(rid)
            end)
        end)
        rankBtn:SetPos(12, 298) rankBtn:SetSize(372, 30)
        if not (P11FW.CanManageRank and P11FW.CanManageRank(LocalPlayer(), nil)) then
            rankBtn.PColor = AC.dim
            rankBtn:SetEnabled(false)
        end

        local rankNote = vgui.Create("DLabel", ap)
        rankNote:SetPos(12, 334) rankNote:SetSize(372, 60)
        rankNote:SetFont("P11FW.Small") rankNote:SetTextColor(AC.dim)
        rankNote:SetText("Выдать может Куратор+ (ниже своего ранга).\n" ..
            "Секрет основателя: p11_access <ключ> в консоли\n(ключ меняется в fw_sh_config.lua).")
        rankNote:SetAutoStretchVertical(true)

        local refr = MakeBtn(ap, "ОБНОВИТЬ СПИСОК", AC.dim, function() RequestAdminData() end)
        refr:SetPos(12, 408) refr:SetSize(372, 30)
    end

    -- ==================================================
    --  ВКЛАДКА: ФРАКЦИИ (создание своих групп персонала)
    -- ==================================================
    do
        local p = NewTab("factions")

        local lv = vgui.Create("DListView", p)
        lv:SetPos(10, 10) lv:SetSize(380, 450)
        lv:SetMultiSelect(false)
        lv:AddColumn("Фракция"):SetFixedWidth(150)
        lv:AddColumn("Должностей"):SetFixedWidth(80)
        lv:AddColumn("Тип")

        function f:RefreshFactions()
            lv:Clear()
            for _, cat in ipairs(P11FW.CategoryList or {}) do
                local jobs = 0
                for _, jid in ipairs(P11FW.JobIds or {}) do
                    local jb = P11FW.Jobs[jid]
                    if jb and (jb.faction or jb.category) == cat.id then jobs = jobs + 1 end
                end
                local line = lv:AddLine(cat.name, jobs,
                    cat.custom and "КАСТОМ" or cat.overridden and "ПРАВКА" or "встроенная")
                line.CatId   = cat.id
                line.CatData = cat
            end
        end
        f:RefreshFactions()

        local form = vgui.Create("DPanel", p)
        form:SetPos(400, 10) form:SetSize(446, 450)
        form.Paint = function(s, w, h) draw.RoundedBox(6, 0, 0, w, h, AC.panel2) end

        local function Lbl(txt, x, y)
            local l = vgui.Create("DLabel", form)
            l:SetPos(x, y) l:SetSize(300, 16)
            l:SetFont("P11FW.Small") l:SetTextColor(AC.dim)
            l:SetText(txt)
            return l
        end

        f.SelFactionId = nil

        Lbl("Название фракции:", 10, 8)
        local nameE = vgui.Create("DTextEntry", form)
        nameE:SetPos(10, 26) nameE:SetSize(280, 26)
        nameE:SetPlaceholderText("МЕДИКИ / ЛЁТНЫЙ СОСТАВ / КОНВОЙ...")

        Lbl("Порядок в меню:", 300, 8)
        local orderW = vgui.Create("DNumberWang", form)
        orderW:SetPos(300, 26) orderW:SetSize(60, 26)
        orderW:SetMinMax(1, 999) orderW:SetValue(50)

        Lbl("Цвет фракции:", 10, 58)

        -- v3.8: палитра как у должностей — быстрые квадратики +
        -- точный подбор через DColorMixer (клик по квадрату справа)
        local facCol = Color(200, 160, 110)

        local fPrevBtn = vgui.Create("DButton", form)
        fPrevBtn:SetPos(132, 54) fPrevBtn:SetSize(44, 22)
        fPrevBtn:SetText("")
        fPrevBtn:SetTooltip("клик — точная палитра (цветовое колесо и RGB)")
        fPrevBtn.Paint = function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, facCol)
            surface.SetDrawColor(255, 255, 255, 110)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        fPrevBtn.DoClick = function()
            surface.PlaySound("buttons/button15.wav")
            if IsValid(P11FW.FacColorMixer) then
                P11FW.FacColorMixer:Remove()
                P11FW.FacColorMixer = nil
                return
            end
            local mx = vgui.Create("DFrame")
            P11FW.FacColorMixer = mx
            mx:SetSize(300, 324)
            local fx, fy = 60, 110
            if IsValid(P11FW.AdminFrame) then fx, fy = P11FW.AdminFrame:GetPos() end
            mx:SetPos(fx + 420, fy + 84)
            mx:SetTitle("")
            mx:MakePopup()
            mx:SetDeleteOnClose(true)
            mx.btnMaxim:SetVisible(false) mx.btnMinim:SetVisible(false)
            mx.T0 = SysTime()
            mx.Paint = function(s, w, h)
                Derma_DrawBackgroundBlur(s, s.T0 or SysTime())
                draw.RoundedBox(8, 0, 0, w, h, Color(16, 18, 24, 248))
                draw.RoundedBoxEx(8, 0, 0, w, 30, Color(26, 30, 40), true, true, false, false)
                draw.SimpleText("ПАЛИТРА ЦВЕТА ФРАКЦИИ", "P11FW.Small", 10, 15,
                    AC.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            mx.OnRemove = function() P11FW.FacColorMixer = nil end
            local mixer = vgui.Create("DColorMixer", mx)
            mixer:Dock(FILL)
            mixer:DockMargin(8, 36, 8, 8)
            mixer:SetPalette(true)
            mixer:SetAlphaBar(false)
            mixer:SetWangs(true)
            mixer:SetColor(facCol)
            mixer.ValueChanged = function(s, col)
                facCol = Color(col.r, col.g, col.b)
            end
            mx.Think = function()
                if not IsValid(P11FW.AdminFrame) and IsValid(mx) then mx:Remove() end
            end
        end

        local F_PRESETS = {
            Color(120, 190, 235),  Color(150, 230, 190),  Color(100, 210, 130),  Color(90, 150, 110),
            Color(255, 205, 110),  Color(230, 160, 90),   Color(185, 160, 110),  Color(140, 220, 240),
            Color(235, 120, 110),  Color(220, 190, 90),   Color(130, 170, 230),  Color(200, 120, 235),
            Color(220, 220, 230),  Color(160, 170, 180),  Color(120, 120, 145),  Color(235, 90, 85),
        }
        for i, pc in ipairs(F_PRESETS) do
            local pcx, prow = (i - 1) % 8, math.floor((i - 1) / 8)
            local sw = vgui.Create("DButton", form)
            sw:SetPos(10 + pcx * 30, 80 + prow * 30)
            sw:SetSize(26, 26)
            sw:SetText("")
            sw:SetTooltip(string.format("RGB %d/%d/%d", pc.r, pc.g, pc.b))
            sw.Paint = function(s, w, h)
                draw.RoundedBox(4, 0, 0, w, h, pc)
                local sel = pc.r == facCol.r and pc.g == facCol.g and pc.b == facCol.b
                surface.SetDrawColor(255, 255, 255, sel and 235 or (s:IsHovered() and 130 or 50))
                surface.DrawOutlinedRect(0, 0, w, h, sel and 2 or 1)
            end
            sw.DoClick = function()
                facCol = Color(pc.r, pc.g, pc.b)
                surface.PlaySound("buttons/button9.wav")
                if IsValid(P11FW.FacColorMixer) then P11FW.FacColorMixer:Remove() end
            end
        end

        -- v1.7: живой превью-чип (цвет + id) — как будет выглядеть секция
        local prev = vgui.Create("DPanel", form)
        prev:SetPos(368, 58) prev:SetSize(88, 44)
        prev.SelText = "новая"
        prev.Paint = function(s, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(facCol.r, facCol.g, facCol.b, 42))
            draw.RoundedBoxEx(6, 0, 0, 3, h, Color(facCol.r, facCol.g, facCol.b), true, false, true, false)
            draw.SimpleText(s.SelText, "P11FW.Small", w / 2 + 1, h / 2 - 8,
                Color(facCol.r, facCol.g, facCol.b), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("превью", "P11FW.Small", w / 2 + 1, h / 2 + 9,
                Color(facCol.r, facCol.g, facCol.b, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        Lbl("Описание (для админов):", 10, 148)
        local descE = vgui.Create("DTextEntry", form)
        descE:SetPos(10, 166) descE:SetSize(426, 60)
        descE:SetMultiline(true)
        descE:SetPlaceholderText("Кто входит во фракцию и чем занимается...")

        lv.OnRowSelected = function(s, id, line)
            f.SelFactionId = line.CatId -- v3.8.1: встроенные правятся как переопределение
            nameE:SetValue(line.CatData.name or "")
            descE:SetValue(line.CatData.desc or "")
            orderW:SetValue(line.CatData.order or 50)
            facCol = Color(line.CatData.color.r, line.CatData.color.g, line.CatData.color.b)
            prev.SelText = line.CatData.custom and line.CatId
                or line.CatData.overridden and ("правка " .. line.CatId) or "встроенная (→правка)"
        end

        local newB = MakeBtn(form, "НОВАЯ ФОРМА", AC.dim, function()
            f.SelFactionId = nil
            nameE:SetValue("") descE:SetValue("") orderW:SetValue(50)
            prev.SelText = "новая"
        end)
        newB:SetPos(10, 238) newB:SetSize(206, 30)

        local function Collect()
            return {
                id    = f.SelFactionId,
                name  = string.Trim(nameE:GetValue()),
                desc  = descE:GetValue(),
                order = orderW:GetValue(),
                color = { r = facCol.r, g = facCol.g, b = facCol.b },
            }
        end

        local saveB = MakeBtn(form, "СОЗДАТЬ / СОХРАНИТЬ", AC.ok, function()
            SendAction(20, function() net.WriteString(util.TableToJSON(Collect()) or "{}") end)
        end)
        saveB:SetPos(226, 238) saveB:SetSize(210, 30)

        local delB = MakeBtn(form, "УДАЛИТЬ/СНЯТЬ ПРАВКУ", AC.bad, function()
            if not f.SelFactionId then surface.PlaySound("buttons/button10.wav") return end
            SendAction(21, function() net.WriteString(f.SelFactionId) end)
        end)
        delB:SetPos(10, 276) delB:SetSize(426, 30)

        local note = vgui.Create("DLabel", form)
        note:SetPos(10, 318) note:SetSize(426, 118)
        note:SetFont("P11FW.Small") note:SetTextColor(AC.dim)
        note:SetAutoStretchVertical(true)
        note:SetText("Фракция — это группа должностей.\n" ..
            "Встроенные фракции тоже правятся — сохранятся как\n" ..
            "переопределение (правка). После создания появится в\n" ..
            "редакторе ДОЛЖНОСТЕЙ\n" ..
            "(поле «Фракция»), в F4 и в табе вопросов (TAB)\n" ..
            "как цветная секция. Сохраняется навсегда:")
        local note2 = vgui.Create("DLabel", form)
        note2:SetPos(10, 400) note2:SetSize(426, 20)
        note2:SetFont("P11FW.Small") note2:SetTextColor(AC.gold)
        note2:SetText("data/polus_framework/factions.json")
    end

    -- ==================================================
    --  ВКЛАДКА 3: УТИЛИТЫ СТАНЦИИ
    -- ==================================================
    do
        -- ============ v4.6.1: «СПАВНЫ» — разные точки для фракций и проф ============
        do
            local p = NewTab("spawns")

            local ttl = vgui.Create("DLabel", p)
            ttl:SetPos(10, 6) ttl:SetSize(830, 24)
            ttl:SetFont("P11FW.Big") ttl:SetTextColor(AC.gold)
            ttl:SetText("СПАВНЫ СТАНЦИИ — где кто появляется")

            local hint = vgui.Create("DLabel", p)
            hint:SetPos(10, 32) hint:SetSize(830, 32)
            hint:SetFont("P11FW.Small") hint:SetTextColor(AC.dim)
            hint:SetText("Встань на нужное место и жми «ПОСТАВИТЬ». Приоритет: ПРОФА > ФРАКЦИЯ > общая точка > карта. Переживает рестарт.")

            local function SRow(y, name, desc, b1, cb1, b2, cb2)
                local l = vgui.Create("DLabel", p)
                l:SetPos(10, y) l:SetSize(320, 24)
                l:SetFont("P11FW.Big") l:SetTextColor(AC.text) l:SetText(name)
                local d = vgui.Create("DLabel", p)
                d:SetPos(10, y + 24) d:SetSize(420, 16)
                d:SetFont("P11FW.Small") d:SetTextColor(AC.dim) d:SetText(desc)
                local bb1 = MakeBtn(p, b1, AC.ok, cb1)
                bb1:SetPos(440, y + 6) bb1:SetSize(200, 30)
                local bb2 = MakeBtn(p, b2, AC.bad, cb2)
                bb2:SetPos(648, y + 6) bb2:SetSize(198, 30)
            end

            SRow(70, "Общая точка гарнизона", "тут появляются все, у кого нет СВОЕЙ зоны (вайтлист/время тут ни при чём)",
                "ПОСТАВИТЬ ЗДЕСЬ", function() SendAction(7) end,
                "УБРАТЬ", function() SendAction(8) end)

            SRow(120, "Камера ареста", "арестованных телепортирует сюда",
                "ПОСТАВИТЬ ЗДЕСЬ", function() SendAction(9) end,
                "УБРАТЬ", function() SendAction(10) end)

            SRow(170, "Кадровик", "NPC выдачи профессий — создать перед собой / убрать ближайшего",
                "СОЗДАТЬ", function() SendAction(11) end,
                "УДАЛИТЬ БЛИЖ.", function() SendAction(12) end)

            -- === СПАВН ФРАКЦИИ ===
            local fl = vgui.Create("DLabel", p)
            fl:SetPos(10, 222) fl:SetSize(300, 24)
            fl:SetFont("P11FW.Big") fl:SetTextColor(Color(255, 205, 100)) fl:SetText("СПАВН ФРАКЦИИ")
            local fd = vgui.Create("DLabel", p)
            fd:SetPos(10, 246) fd:SetSize(420, 16)
            fd:SetFont("P11FW.Small") fd:SetTextColor(AC.dim)
            fd:SetText("вся фракция появляется тут (напр. казармы РККА, особый отдел НКВД)")
            local facC = vgui.Create("DComboBox", p)
            facC:SetPos(10, 266) facC:SetSize(250, 26)
            for _, c in ipairs(P11FW.CategoryList or {}) do facC:AddChoice(c.name, c.id) end
            f.SpawnFac = P11FW.CategoryList and P11FW.CategoryList[1] and P11FW.CategoryList[1].id or "misc"
            facC:SetValue(P11FW.CategoryList and P11FW.CategoryList[1] and P11FW.CategoryList[1].name or "misc")
            facC.OnSelect = function(_, _, _, data) f.SpawnFac = data end
            local fs1 = MakeBtn(p, "ПОСТАВИТЬ ЗДЕСЬ", AC.ok, function()
                SendAction(33, function() net.WriteString(f.SpawnFac or "misc") end)
            end)
            fs1:SetPos(440, 264) fs1:SetSize(200, 30)
            local fs2 = MakeBtn(p, "УБРАТЬ ТОЧКУ", AC.bad, function()
                SendAction(34, function() net.WriteString(f.SpawnFac or "misc") end)
            end)
            fs2:SetPos(648, 264) fs2:SetSize(198, 30)

            -- === СПАВН ПРОФЫ ===
            local jl = vgui.Create("DLabel", p)
            jl:SetPos(10, 306) jl:SetSize(300, 24)
            jl:SetFont("P11FW.Big") jl:SetTextColor(Color(150, 220, 255)) jl:SetText("СПАВН ПРОФЫ")
            local jd = vgui.Create("DLabel", p)
            jd:SetPos(10, 330) jd:SetSize(420, 16)
            jd:SetFont("P11FW.Small") jd:SetTextColor(AC.dim)
            jd:SetText("конкретная должность появляется тут (сильнее зоны фракции)")
            local jobs = {}
            for id, jb in pairs(P11FW.Jobs or {}) do jobs[#jobs + 1] = { id = id, name = jb.name, ord = jb.order or 99 } end
            table.sort(jobs, function(a, b) if a.ord ~= b.ord then return a.ord < b.ord end return a.name < b.name end)
            local jobC = vgui.Create("DComboBox", p)
            jobC:SetPos(10, 350) jobC:SetSize(250, 26)
            for _, j in ipairs(jobs) do jobC:AddChoice(j.name, j.id) end
            f.SpawnJob = jobs[1] and jobs[1].id or ""
            jobC:SetValue(jobs[1] and jobs[1].name or "")
            jobC.OnSelect = function(_, _, _, data) f.SpawnJob = data end
            local js1 = MakeBtn(p, "ПОСТАВИТЬ ЗДЕСЬ", AC.ok, function()
                if (f.SpawnJob or "") ~= "" then SendAction(37, function() net.WriteString(f.SpawnJob) end) end
            end)
            js1:SetPos(440, 348) js1:SetSize(200, 30)
            local js2 = MakeBtn(p, "УБРАТЬ ТОЧКУ", AC.bad, function()
                if (f.SpawnJob or "") ~= "" then SendAction(38, function() net.WriteString(f.SpawnJob) end) end
            end)
            js2:SetPos(648, 348) js2:SetSize(198, 30)

            -- === ГРУЗОВИК КОЛОННЫ ===
            SRow(390, "Грузовик колонны (LVS)", "советский грузовик у зоны прибытия; в кабине тепло (нет пака — зона работает без него)",
                "ЗАСПАВНИТЬ", function() SendAction(35) end,
                "УБРАТЬ", function() SendAction(36) end)

            local listBtn = MakeBtn(p, "ЧТО УЖЕ РАССТАВЛЕНО? (список в чат)", AC.gold, function() SendAction(39) end)
            listBtn:SetPos(440, 436) listBtn:SetSize(406, 30)
        end

        local p = NewTab("utils")

        local function UtilRow(y, name, desc, btn1, cb1, btn2, cb2)
            local rowState = vgui.Create("DLabel", p)
            rowState:SetPos(10, y) rowState:SetSize(320, 26)
            rowState:SetFont("P11FW.Big") rowState:SetTextColor(AC.text)

            local d = vgui.Create("DLabel", p)
            d:SetPos(10, y + 26) d:SetSize(420, 16)
            d:SetFont("P11FW.Small") d:SetTextColor(AC.dim)
            d:SetText(desc)

            local b1 = MakeBtn(p, btn1, AC.ok, cb1)
            b1:SetPos(440, y + 8) b1:SetSize(200, 34)
            local b2 = MakeBtn(p, btn2, AC.bad, cb2)
            b2:SetPos(648, y + 8) b2:SetSize(198, 34)
            return rowState
        end

        f.UtilLabels = {}

        f.UtilLabels.spawn = UtilRow(14, "Точка спавна гарнизона", "все игроки появляются в этой точке (с сохранением на карту)",
            "ПОСТАВИТЬ ЗДЕСЬ", function() SendAction(7) end,
            "УБРАТЬ", function() SendAction(8) end)

        f.UtilLabels.jail = UtilRow(66, "Камера ареста", "арестованных телепортирует сюда (без точки — заморозка на месте)",
            "ПОСТАВИТЬ ЗДЕСЬ", function() SendAction(9) end,
            "УБРАТЬ", function() SendAction(10) end)

        f.UtilLabels.npc = UtilRow(118, "Кадровик", "NPC выдачи профессий — создать перед собой / убрать ближайшего",
            "СОЗДАТЬ", function() SendAction(11) end,
            "УДАЛИТЬ БЛИЖ.", function() SendAction(12) end)

        f.UtilLabels.term = UtilRow(170, "Сменный терминал", "консоль выдачи ДОП-ЗАДАЧ экипажу (persist на карту), поставить перед собой",
            "ПОСТАВИТЬ", function() SendAction(23) end,
            "УБРАТЬ БЛИЖ.", function() SendAction(24) end)

        -- ============ v4.5.0: ЗОНА ПРИБЫТИЯ ФРАКЦИИ + ГРУЗОВИК LVS ============
        local arLbl = vgui.Create("DLabel", p)
        arLbl:SetPos(10, 224) arLbl:SetSize(410, 18)
        arLbl:SetFont("P11FW.Big") arLbl:SetTextColor(AC.text)
        arLbl:SetText("Зона прибытия фракции")

        local arDesc = vgui.Create("DLabel", p)
        arDesc:SetPos(10, 242) arDesc:SetSize(420, 16)
        arDesc:SetFont("P11FW.Small") arDesc:SetTextColor(AC.dim)
        arDesc:SetText("игроки ЭТОЙ фракции спавнятся у точки (спавн колонной; переживает рестарт)")

        local facC = vgui.Create("DComboBox", p)
        facC:SetPos(10, 262) facC:SetSize(250, 26)
        for _, c in ipairs(P11FW.CategoryList or {}) do
            facC:AddChoice(c.name, c.id)
        end
        facC:SetValue(P11FW.CategoryList and P11FW.CategoryList[3] and P11FW.CategoryList[3].name or "misc")
        f.ArrivalFaction = P11FW.CategoryList and P11FW.CategoryList[3] and P11FW.CategoryList[3].id or "misc"
        facC.OnSelect = function(s2, idx, val, data)
            f.ArrivalFaction = data
        end
        facC:SetTooltip("какой фракции назначить точку спавна")

        local arSet = MakeBtn(p, "ПОСТАВИТЬ ЗДЕСЬ", AC.ok, function()
            SendAction(33, function() net.WriteString(f.ArrivalFaction or "misc") end)
        end)
        arSet:SetPos(440, 240) arSet:SetSize(200, 26)
        local arClr = MakeBtn(p, "УБРАТЬ", AC.bad, function()
            SendAction(34, function() net.WriteString(f.ArrivalFaction or "misc") end)
        end)
        arClr:SetPos(648, 240) arClr:SetSize(198, 26)

        local trLbl = vgui.Create("DLabel", p)
        trLbl:SetPos(10, 292) trLbl:SetSize(410, 18)
        trLbl:SetFont("P11FW.Big") trLbl:SetTextColor(AC.text)
        trLbl:SetText("Грузовик колонны")

        local trDesc = vgui.Create("DLabel", p)
        trDesc:SetPos(10, 310) trDesc:SetSize(420, 16)
        trDesc:SetFont("P11FW.Small") trDesc:SetTextColor(AC.dim)
        trDesc:SetText("LVS Soviet Pack: ставится перед тобой, сохраняется; в транспорте не морознет")

        local trPut = MakeBtn(p, "ЗАСПАВНИТЬ ПЕРЕД СОБОЙ", AC.ok, function() SendAction(35) end)
        trPut:SetPos(440, 296) trPut:SetSize(200, 26)
        local trRem = MakeBtn(p, "УБРАТЬ ГРУЗОВИК", AC.bad, function() SendAction(36) end)
        trRem:SetPos(648, 296) trRem:SetSize(198, 26)

        -- бан-лист
        local banLbl = vgui.Create("DLabel", p)
        banLbl:SetPos(10, 334) banLbl:SetSize(400, 22)
        banLbl:SetFont("P11FW.Big") banLbl:SetTextColor(AC.text)
        banLbl:SetText("БАН-ЛИСТ СТАНЦИИ")

        local bans = vgui.Create("DListView", p)
        bans:SetPos(10, 358) bans:SetSize(626, 96)
        bans:SetMultiSelect(false)
        bans:AddColumn("SteamID64"):SetFixedWidth(160)
        bans:AddColumn("Ник"):SetFixedWidth(140)
        bans:AddColumn("До"):SetFixedWidth(110)
        bans:AddColumn("Причина")
        f.BansList = bans

        local unban = MakeBtn(p, "СНЯТЬ БАН ВЫБРАННОМУ", AC.ok, function()
            local id = bans:GetSelectedLine()
            if not id then surface.PlaySound("buttons/button10.wav") return end
            local line = bans:GetLine(id)
            if line and line.SID then
                SendAction(13, function() net.WriteString(line.SID) end)
            end
        end)
        unban:SetPos(10, 424) unban:SetSize(300, 34)
        if not P11FW.CanMod(LocalPlayer(), "unban") then
            unban.PColor = AC.dim
            unban:SetEnabled(false)
        end

        local refr = MakeBtn(p, "ОБНОВИТЬ", AC.dim, function() RequestAdminData() end)
        refr:SetPos(648, 424) refr:SetSize(198, 34)

        function f:RefreshUtils()
            local d = self.AdminData
            if not d then return end
            f.UtilLabels.spawn:SetText("Точка спавна гарнизона: " .. (d.spawnSet and "УСТАНОВЛЕНА" or "не задана"))
            f.UtilLabels.jail:SetText("Камера ареста: " .. (d.jailSet and "УСТАНОВЛЕНА" or "не задана (заморозка на месте)"))
            f.UtilLabels.spawn:SetTextColor(d.spawnSet and AC.ok or AC.text)
            f.UtilLabels.jail:SetTextColor(d.jailSet and AC.ok or AC.text)

            bans:Clear()
            for _, b in ipairs(d.bans) do
                local untilTxt = (b.until_ or 0) == 0 and "НАВСЕГДА" or os.date("%d.%m %H:%M", b.until_)
                local line = bans:AddLine(b.sid, b.nick, untilTxt, b.reason)
                line.SID = b.sid
            end
        end
    end


    -- ==================================================
    --  ВКЛАДКА: АДМИНКИ (v4.4.0) — все ранги проекта плиткой.
    --  Доступ: Deputy Staff Leader+ (Config.RankManageLevel).
    -- ==================================================
    do
        local p = NewTab("admranks")

        local h1 = vgui.Create("DLabel", p)
        h1:SetPos(10, 8) h1:SetSize(300, 18)
        h1:SetFont("P11FW.Big") h1:SetTextColor(AC.text)
        h1:SetText("ИГРОКИ ОНЛАЙН")

        local lv = vgui.Create("DListView", p)
        lv:SetPos(10, 34) lv:SetSize(300, 366)
        lv:SetMultiSelect(false)
        lv:AddColumn("Ник"):SetFixedWidth(140)
        lv:AddColumn("Ранг")

        function f:RefreshAdmRanks()
            lv:Clear()
            local list = {}
            for _, pl in ipairs(player.GetAll()) do list[#list + 1] = pl end
            table.sort(list, function(a, b)
                local la, lb = P11FW.GetRankLevel(a), P11FW.GetRankLevel(b)
                if la ~= lb then return la > lb end
                return string.lower(a:Nick()) < string.lower(b:Nick())
            end)
            for _, pl in ipairs(list) do
                local r = P11FW.GetRank(pl)
                local line = lv:AddLine(pl:Nick(), (r and r.name or "?") .. "  [" .. (r and r.level or 0) .. "]")
                line.PSid = pl:SteamID() -- по SteamID: ник с пробелами ломает аргументы консоли
                if r and r.color then line.Columns[2]:SetTextColor(r.color) end
            end
        end

        lv.OnRowSelected = function(s2, id, line)
            if f.AdmRankTarget then
                f.AdmRankTarget:SetText("Цель: " .. (line:GetValue(1) or "?") .. "  •  " .. tostring(line.PSid))
            end
        end

        local refr = MakeBtn(p, "🔄 ОБНОВИТЬ СПИСОК", AC.dim, function() f:RefreshAdmRanks() end)
        refr:SetPos(10, 406) refr:SetSize(300, 40)

        local h2 = vgui.Create("DLabel", p)
        h2:SetPos(326, 8) h2:SetSize(520, 18)
        h2:SetFont("P11FW.Big") h2:SetTextColor(AC.gold)
        h2:SetText("ВСЕ РАНГИ ПРОЕКТА — клик выдаёт выбранному слева")

        local scp = vgui.Create("DScrollPanel", p)
        scp:SetPos(326, 34) scp:SetSize(520, 384)
        local sb2 = scp:GetVBar() sb2:SetWide(5)

        local lay = vgui.Create("DIconLayout", scp)
        lay:Dock(FILL) lay:SetSpaceX(6) lay:SetSpaceY(6)

        for _, r in ipairs(P11FW.Ranks or {}) do
            local r2 = r
            local b = vgui.Create("DButton", lay)
            b:SetSize(254, 46)
            b:SetText("")
            b.Paint = function(s2, w, h)
                draw.RoundedBox(6, 0, 0, w, h, s2:IsHovered() and Color(255, 255, 255, 26) or Color(255, 255, 255, 10))
                draw.RoundedBoxEx(6, 0, 0, 5, h, r2.color or AC.text, true, false, true, false)
                local nm = r2.name
                if (r2.level or 0) == 0 then nm = "СНЯТЬ АДМИНКУ — " .. nm end
                draw.SimpleText(nm, "P11FW.Text", 14, h / 2 - 9, r2.color or AC.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText("id: " .. r2.id .. "  •  ур. " .. (r2.level or 0) .. (r2.wl and "  🔒вайтлист" or ""),
                    "P11FW.Small", 14, h / 2 + 11, AC.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            b.DoClick = function()
                local id = lv:GetSelectedLine()
                if not id then
                    surface.PlaySound("buttons/button10.wav")
                    chat.AddText(AC.bad, "[P11FW] Сначала ВЫБЕРИ ИГРОКА в списке слева!")
                    return
                end
                local line = lv:GetLine(id)
                if not (line and line.PSid) then return end
                surface.PlaySound("buttons/button9.wav")
                RunConsoleCommand("p11_rank", line.PSid, r2.id)
                chat.AddText(AC.gold, "[P11FW] Отправлено: " .. line.PSid .. " → " .. r2.name)
                timer.Simple(1.4, function()
                    if IsValid(f) and f.RefreshAdmRanks then f:RefreshAdmRanks() end
                end)
            end
        end

        f.AdmRankTarget = vgui.Create("DLabel", p)
        f.AdmRankTarget:SetPos(326, 424) f.AdmRankTarget:SetSize(520, 18)
        f.AdmRankTarget:SetFont("P11FW.Small") f.AdmRankTarget:SetTextColor(AC.gold)
        f.AdmRankTarget:SetText("Цель: —  (выбери игрока слева)")

        local note = vgui.Create("DLabel", p)
        note:SetPos(326, 446) note:SetSize(520, 18)
        note:SetFont("P11FW.Small") note:SetTextColor(AC.dim)
        note:SetText("Выдать можно ранг НИЖЕ своего. Консоль: p11_rank <SteamID> <id> • секрет основателя: p11_access <ключ>")

        f:RefreshAdmRanks()
    end

    -- ==================================================
    --  ВКЛАДКА: ВАЙТЛИСТ — допуски на whitelist-должности.
    --  v4.6.9 ПОЧИНЕН ВЫБОР ДОЛЖНОСТИ: раньше клик по строке
    --  дёргал ПОЛНЫЙ рефреш (Clear() списка) и выделение
    --  стиралось в тот же кадр → вечное «Сначала выбери
    --  ДОЛЖНОСТЬ слева!». Теперь выбор — «липкий»: живёт в
    --  selJobId и восстанавливается после любого рефреша.
    -- ==================================================
    do
        local p = NewTab("whitelist")

        local h1 = vgui.Create("DLabel", p)
        h1:SetPos(10, 8) h1:SetSize(264, 18)
        h1:SetFont("P11FW.Big") h1:SetTextColor(AC.text)
        h1:SetText("🔒 ДОЛЖНОСТИ С ВАЙТЛИСТОМ")

        local jobLv = vgui.Create("DListView", p)
        jobLv:SetPos(10, 34) jobLv:SetSize(264, 364)
        jobLv:SetMultiSelect(false)
        jobLv:AddColumn("Должность"):SetFixedWidth(185)
        jobLv:AddColumn("Допусков")

        -- «липкая» подсказка выбранной должности
        local selLab = vgui.Create("DLabel", p)
        selLab:SetPos(10, 404) selLab:SetSize(264, 26)
        selLab:SetFont("P11FW.Small") selLab:SetTextColor(AC.dim)

        local h2 = vgui.Create("DLabel", p)
        h2:SetPos(286, 8) h2:SetSize(280, 18)
        h2:SetFont("P11FW.Big") h2:SetTextColor(AC.text)
        h2:SetText("ИГРОКИ ОНЛАЙН")

        local plLv = vgui.Create("DListView", p)
        plLv:SetPos(286, 34) plLv:SetSize(280, 398)
        plLv:SetMultiSelect(false)
        plLv:AddColumn("Ник"):SetFixedWidth(180)
        plLv:AddColumn("Допуск")

        local h3 = vgui.Create("DLabel", p)
        h3:SetPos(578, 8) h3:SetSize(268, 18)
        h3:SetFont("P11FW.Big") h3:SetTextColor(AC.text)
        h3:SetText("У КОГО ЕСТЬ ДОПУСК")

        local memLv = vgui.Create("DListView", p)
        memLv:SetPos(578, 34) memLv:SetSize(268, 240)
        memLv:SetMultiSelect(false)
        memLv:AddColumn("Игрок • SteamID")

        local sidE = vgui.Create("DTextEntry", p)
        sidE:SetPos(578, 282) sidE:SetSize(268, 26)
        sidE:SetPlaceholderText("или SteamID вручную: STEAM_0:1:... / 7656...")

        -- ВЫБРАННАЯ должность переживает любые рефреши (v4.6.9)
        local selJobId = nil

        local function PaintSel()
            if selJobId and P11FW.Jobs[selJobId] then
                selLab:SetText("✔ Выбрано: " .. P11FW.Jobs[selJobId].name)
                selLab:SetTextColor(AC.gold)
            else
                selLab:SetText("← кликни должность из списка выше")
                selLab:SetTextColor(AC.dim)
            end
        end

        -- ПРАВЫЕ списки: игроки онлайн + обладатели допуска
        local function FillSides()
            local me = LocalPlayer()
            plLv:Clear()
            for _, pl in ipairs(player.GetAll()) do
                local has = selJobId and P11FW.HasWhitelist and P11FW.HasWhitelist(pl, selJobId)
                local line = plLv:AddLine(pl:Nick() .. (pl == me and " (ты)" or ""), has and "есть ✔" or "—")
                line.PSid = pl:SteamID()
                if has then line.Columns[2]:SetTextColor(AC.ok) end
            end

            memLv:Clear()
            if selJobId and P11FW.Whitelist then
                local t = P11FW.Whitelist[selJobId]
                if t then
                    for sid in pairs(t) do
                        local nick = nil
                        for _, pl in ipairs(player.GetAll()) do
                            if pl:SteamID() == sid or pl:SteamID64() == sid then nick = pl:Nick() break end
                        end
                        local line = memLv:AddLine((nick and (nick .. " • ") or "") .. sid)
                        line.PSid = sid
                    end
                end
            end
            PaintSel()
        end

        -- ЛЕВЫЙ список: перестраивается БЕРЕЖНО — после Clear()
        -- возвращаем выделение на ту же должность
        local function FillJobs()
            jobLv:Clear()
            local reselectLine = nil
            for _, jobId in ipairs(P11FW.JobIds or {}) do
                local job = P11FW.Jobs[jobId]
                if job and job.whitelist then
                    local line = jobLv:AddLine(job.name,
                        P11FW.WhitelistCount and P11FW.WhitelistCount(jobId) or 0)
                    line.JobId = jobId
                    if jobId == selJobId then reselectLine = line end
                end
            end
            if reselectLine then
                jobLv:SelectItem(reselectLine)
            end
            PaintSel()
        end

        -- цель: выбранный игрок → выбранный член допуска → поле ввода
        local function SelectedSid()
            local pid = plLv:GetSelectedLine()
            if pid then
                local line = plLv:GetLine(pid)
                if line and line.PSid then return line.PSid end
            end
            local mid = memLv:GetSelectedLine()
            if mid then
                local line = memLv:GetLine(mid)
                if line and line.PSid then return line.PSid end
            end
            return P11FW.NormalizeSteamID and P11FW.NormalizeSteamID(sidE:GetValue()) or nil
        end

        local function SendWlSet(allow)
            if not selJobId then
                surface.PlaySound("buttons/button10.wav")
                chat.AddText(AC.bad, "[P11FW] Сначала выбери ДОЛЖНОСТЬ слева!")
                return
            end
            local sid = SelectedSid()
            if not sid then
                surface.PlaySound("buttons/button10.wav")
                chat.AddText(AC.bad, "[P11FW] Выбери ИГРОКА (или впиши SteamID: STEAM_0:x:y / 7656...).")
                return
            end
            net.Start("P11FW_WL_SET")
                net.WriteString(selJobId)
                net.WriteString(sid)
                net.WriteBool(allow)
            net.SendToServer()
            surface.PlaySound("buttons/button9.wav")
            sidE:SetValue("")
        end

        local grantB = MakeBtn(p, "✔ ВЫДАТЬ ДОПУСК", AC.ok, function() SendWlSet(true) end)
        grantB:SetPos(578, 316) grantB:SetSize(130, 40)
        local denyB = MakeBtn(p, "✖ СНЯТЬ ДОПУСК", AC.bad, function() SendWlSet(false) end)
        denyB:SetPos(716, 316) denyB:SetSize(130, 40)

        local refrB = MakeBtn(p, "🔄 ОБНОВИТЬ", AC.dim, function()
            net.Start("P11FW_WL_REQ") net.SendToServer()
            f:RefreshWhitelistTab()
        end)
        refrB:SetPos(578, 362) refrB:SetSize(268, 30)

        local note = vgui.Create("DLabel", p)
        note:SetPos(578, 398) note:SetSize(268, 64)
        note:SetFont("P11FW.Small") note:SetTextColor(AC.dim)
        note:SetWrap(true) note:SetAutoStretchVertical(true)
        note:SetText("Снятие допуска у игрока НА этой должности увольняет его в новобранцы.\nГалочка «🔒 ВАЙТЛИСТ» ставится у профы во вкладке ДОЛЖНОСТИ.")

        -- клик по должности: ТОЛЬКО запомнить выбор и перерисовать
        -- правые колонки. Левый список НЕ трогаем — в этом был баг.
        jobLv.OnRowSelected = function(_, lineId, line)
            selJobId = (line and line.JobId) or selJobId
            FillSides()
        end

        function f:RefreshWhitelistTab()
            FillJobs()
            FillSides()
        end

        -- на входе данных могло не быть — запросим свежий синк
        net.Start("P11FW_WL_REQ") net.SendToServer()
        f:RefreshWhitelistTab()
    end

    -- первая загрузка данных
    RequestAdminData()
end

concommand.Add("p11fw_admin", function()
    P11FW.OpenAdminMenu()
end)


-- v4.0: сетевая команда «открыть меню выдачи рангов» (/ранги, ранг 10+)
-- v4.4.0: ведёт сразу на вкладку АДМИНКИ (все ранги плиткой)
net.Receive("P11FW_OpenAdminRanks", function()
    P11FW.OpenAdminMenu("admranks")
end)
