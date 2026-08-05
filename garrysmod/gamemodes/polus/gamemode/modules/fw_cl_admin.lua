-- ============================================================
--  ПОЛЮС FRAMEWORK — АДМИН-МЕНЮ (клиент)
--  Вкладки: ИГРОКИ (арест/рабство/бан/освободить/уволить/
--  выдать должность) • ДОЛЖНОСТИ (создание своих профессий:
--  имя, модели, оружие, лимит — сохраняются навсегда) •
--  УТИЛИТЫ (спавн-поинт, камера ареста, кадровик, бан-лист).
--  Открыть: p11fw_admin в консоль, чат !фвадмин / !fw,
--  кнопка «АДМИНКА» в F4.
-- ============================================================

surface.CreateFont("P11FW.Adm.Tab", { font = "Roboto", size = 18, weight = 700, extended = true })

local AC = {
    bg     = Color(16, 18, 24, 240),
    panel  = Color(26, 30, 40, 255),
    panel2 = Color(32, 38, 50, 255),
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

function P11FW.OpenAdminMenu()
    if not IsValid(LocalPlayer()) then return end
    if not P11FW.Config.Admin(LocalPlayer()) then
        chat.AddText(AC.bad, "[P11FW] Только для администрации.")
        return
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

    f.ActiveTab = "players"

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

    local tabs = {
        { id = "players",  name = "ИГРОКИ" },
        { id = "acts",     name = "ДЕЙСТВИЯ" },
        { id = "jobs",     name = "ДОЛЖНОСТИ" },
        { id = "factions", name = "ФРАКЦИИ" },
        { id = "utils",    name = "УТИЛИТЫ" },
    }
    f.TabPanels = {}
    f.TabButtons = {}

    for i, t in ipairs(tabs) do
        local tb = vgui.Create("DButton", f)
        tb:SetPos(12 + (i - 1) * 137, 58)
        tb:SetSize(131, 32)
        tb:SetText("")
        tb.TabId = t.id
        tb.Paint = function(s, w, h)
            local on = f.ActiveTab == s.TabId
            draw.RoundedBox(5, 0, 0, w, h, on and Color(AC.accent.r, AC.accent.g, AC.accent.b, 55) or Color(255, 255, 255, 8))
            draw.SimpleText(t.name, "P11FW.Adm.Tab", w / 2, h / 2, on and AC.accent or AC.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        tb.DoClick = function()
            f.ActiveTab = t.id
            for id, p in pairs(f.TabPanels) do p:SetVisible(id == t.id) end
            if t.id == "players" or t.id == "utils" or t.id == "acts" then RequestAdminData() end
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
        lv:AddColumn("Ник"):SetFixedWidth(190)
        lv:AddColumn("Должность"):SetFixedWidth(160)
        lv:AddColumn("Статус"):SetFixedWidth(90)
        lv:AddColumn("Осталось")

        f.PlayersList = lv

        function f:RefreshPlayers()
            lv:Clear()
            for _, pl in ipairs((self.AdminData and self.AdminData.players) or {}) do
                local job = P11FW.Jobs[pl.jobId]
                local status = pl.pun == "arrest" and "АРЕСТ" or pl.pun == "slavery" and "РАБСТВО" or pl.pun == "ban" and "БАН" or "—"
                local line = lv:AddLine(pl.nick, job and job.name or pl.jobId, status, pl.pun ~= "" and (pl.left .. " мин") or "")
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
                local line = lv:AddLine(job.name, catName, (job.max or 0) > 0 and job.max or "∞",
                    job.custom and "КАСТОМ" or "встроенная")
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

        Lbl("Цвет (R/G/B):", 100, 58)
        local colors = {}
        for i, cname in ipairs({ "R", "G", "B" }) do
            local s = vgui.Create("DNumSlider", form)
            s:SetPos(100 + (i - 1) * 120, 66) s:SetSize(110, 22)
            s:SetText(cname) s:SetMin(0) s:SetMax(255) s:SetDecimals(0)
            s:SetValue(i == 1 and 210 or i == 2 and 170 or 120)
            colors[i] = s
        end

        Lbl("Модели (по одной через запятую):", 10, 108)
        local modelsE = vgui.Create("DTextEntry", form)
        modelsE:SetPos(10, 126) modelsE:SetSize(360, 52)
        modelsE:SetMultiline(true)
        modelsE:SetPlaceholderText("models/player/kleiner.mdl, models/player/eli.mdl")

        local addMyModel = MakeBtn(form, "+ МОЯ МОДЕЛЬ", AC.accent, function()
            local m = LocalPlayer():GetModel()
            local cur = string.Trim(modelsE:GetValue())
            modelsE:SetValue(cur == "" and m or (cur .. ", " .. m))
        end)
        addMyModel:SetPos(376, 126) addMyModel:SetSize(80, 24)

        Lbl("Оружие (классы через запятую):", 10, 186)
        local wepsE = vgui.Create("DTextEntry", form)
        wepsE:SetPos(10, 204) wepsE:SetSize(360, 52)
        wepsE:SetMultiline(true)
        wepsE:SetPlaceholderText("weapon_polus11_radio, weapon_pistol")

        local addMyWep = MakeBtn(form, "+ ОРУЖИЕ В РУКАХ", AC.accent, function()
            local w = LocalPlayer():GetActiveWeapon()
            if not IsValid(w) then return end
            local cls = w:GetClass()
            local cur = string.Trim(wepsE:GetValue())
            wepsE:SetValue(cur == "" and cls or (cur .. ", " .. cls))
        end)
        addMyWep:SetPos(376, 204) addMyWep:SetSize(80, 24)

        Lbl("Описание (видно в F4):", 10, 262)
        local descE = vgui.Create("DTextEntry", form)
        descE:SetPos(10, 280) descE:SetSize(446, 74)
        descE:SetMultiline(true)
        descE:SetPlaceholderText("Что делает эта должность на станции...")

        -- выбранная строка списка → заполнить форму
        local editingId = nil
        local status = vgui.Create("DLabel", form)
        status:SetPos(10, 360) status:SetSize(446, 18)
        status:SetFont("P11FW.Small") status:SetTextColor(AC.gold)
        status:SetText("Новая должность (или выбери КАСТОМ из списка для правки)")

        local function CollectForm()
            local _, catId = catC:GetSelected()
            return {
                name     = nameE:GetValue(),
                category = catId or "misc",
                desc     = descE:GetValue(),
                max      = maxW:GetValue(),
                color    = { r = colors[1]:GetValue(), g = colors[2]:GetValue(), b = colors[3]:GetValue() },
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
                colors[1]:SetValue(job.color.r) colors[2]:SetValue(job.color.g) colors[3]:SetValue(job.color.b)
            end
            editingId = job.custom and jobId or nil
            status:SetText(job.custom and ("Правим КАСТОМНУЮ: " .. job.name) or "ВСТРОЕННАЯ — можно только скопировать в новую")
        end

        local btnCreate = MakeBtn(form, "СОЗДАТЬ НОВУЮ", AC.ok, function()
            local rec = CollectForm()
            if string.Trim(rec.name) == "" then status:SetText("⚠ впиши название!") surface.PlaySound("buttons/button10.wav") return end
            SendJobEdit(1, rec)
            status:SetText("Отправлено на сервер...")
        end)
        btnCreate:SetPos(10, 384) btnCreate:SetSize(146, 40)

        local btnUpdate = MakeBtn(form, "СОХРАНИТЬ ПРАВКУ", AC.accent, function()
            if not editingId then status:SetText("⚠ это встроенная или не выбрана кастомная!") surface.PlaySound("buttons/button10.wav") return end
            local rec = CollectForm()
            rec.id = editingId
            SendJobEdit(2, rec)
        end)
        btnUpdate:SetPos(162, 384) btnUpdate:SetSize(146, 40)

        local btnDelete = MakeBtn(form, "УДАЛИТЬ", AC.bad, function()
            if not editingId then status:SetText("⚠ удалить можно только кастомную!") surface.PlaySound("buttons/button10.wav") return end
            SendJobEdit(3, { id = editingId })
            editingId = nil
        end)
        btnDelete:SetPos(314, 384) btnDelete:SetSize(142, 40)

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
        lv:AddColumn("Ник"):SetFixedWidth(180)
        lv:AddColumn("Должность"):SetFixedWidth(160)
        lv:AddColumn("Статус")

        function f:RefreshActs()
            lv:Clear()
            for _, pl in ipairs((self.AdminData and self.AdminData.players) or {}) do
                local job = P11FW.Jobs[pl.jobId]
                local status = pl.pun == "arrest" and "АРЕСТ" or pl.pun == "slavery" and "РАБСТВО" or pl.pun == "ban" and "БАН" or "—"
                local line = lv:AddLine(pl.nick, job and job.name or pl.jobId, status)
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

        local function ActBtn(name, actId, col)
            local b = MakeBtn(grid, name, col, function()
                local idx = Sel()
                if not idx then surface.PlaySound("buttons/button10.wav") return end
                SendAction(actId, function() net.WriteUInt(idx, 8) end)
            end)
            b:SetSize(180, 44)
        end

        ActBtn("ЛЕЧИТЬ ПОЛНОСТЬЮ", 14, AC.ok)
        ActBtn("ВОЗРОДИТЬ",       15, Color(230, 200, 120))
        ActBtn("ПРИТАЩИТЬ К СЕБЕ",16, Color(150, 190, 240))
        ActBtn("ТЕЛЕПОРТ К НЕМУ", 17, Color(150, 190, 240))
        ActBtn("ЗАМОРОЗИТЬ/РАЗМ.",18, Color(170, 175, 190))
        ActBtn("УБИТЬ",           19, AC.bad)

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
                local line = lv:AddLine(cat.name, jobs, cat.custom and "КАСТОМ" or "встроенная")
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

        local idLbl = vgui.Create("DLabel", form)
        idLbl:SetPos(368, 26) idLbl:SetSize(70, 26)
        idLbl:SetFont("P11FW.Small") idLbl:SetTextColor(AC.dim)
        idLbl:SetText("новая")

        Lbl("Цвет (R/G/B):", 10, 58)
        local colors = {}
        for i, cname in ipairs({ "R", "G", "B" }) do
            local s = vgui.Create("DNumSlider", form)
            s:SetPos(10 + (i - 1) * 146, 66) s:SetSize(138, 22)
            s:SetText(cname) s:SetMin(0) s:SetMax(255) s:SetDecimals(0)
            s:SetValue(i == 1 and 200 or i == 2 and 160 or 110)
            colors[i] = s
        end

        Lbl("Описание (для админов):", 10, 108)
        local descE = vgui.Create("DTextEntry", form)
        descE:SetPos(10, 126) descE:SetSize(426, 70)
        descE:SetMultiline(true)
        descE:SetPlaceholderText("Кто входит во фракцию и чем занимается...")

        lv.OnRowSelected = function(s, id, line)
            f.SelFactionId = line.CatData.custom and line.CatId or nil
            nameE:SetValue(line.CatData.name or "")
            descE:SetValue(line.CatData.desc or "")
            orderW:SetValue(line.CatData.order or 50)
            colors[1]:SetValue(line.CatData.color.r)
            colors[2]:SetValue(line.CatData.color.g)
            colors[3]:SetValue(line.CatData.color.b)
            idLbl:SetText(line.CatData.custom and line.CatId or "встроенная")
        end

        local newB = MakeBtn(form, "НОВАЯ ФОРМА", AC.dim, function()
            f.SelFactionId = nil
            nameE:SetValue("") descE:SetValue("") orderW:SetValue(50)
            idLbl:SetText("новая")
        end)
        newB:SetPos(10, 210) newB:SetSize(206, 30)

        local function Collect()
            return {
                id    = f.SelFactionId,
                name  = string.Trim(nameE:GetValue()),
                desc  = descE:GetValue(),
                order = orderW:GetValue(),
                color = { r = colors[1]:GetValue(), g = colors[2]:GetValue(), b = colors[3]:GetValue() },
            }
        end

        local saveB = MakeBtn(form, "СОЗДАТЬ / СОХРАНИТЬ", AC.ok, function()
            SendAction(20, function() net.WriteString(util.TableToJSON(Collect()) or "{}") end)
        end)
        saveB:SetPos(226, 210) saveB:SetSize(210, 30)

        local delB = MakeBtn(form, "УДАЛИТЬ (только кастом)", AC.bad, function()
            if not f.SelFactionId then surface.PlaySound("buttons/button10.wav") return end
            SendAction(21, function() net.WriteString(f.SelFactionId) end)
        end)
        delB:SetPos(10, 250) delB:SetSize(426, 30)

        local note = vgui.Create("DLabel", form)
        note:SetPos(10, 292) note:SetSize(426, 120)
        note:SetFont("P11FW.Small") note:SetTextColor(AC.dim)
        note:SetAutoStretchVertical(true)
        note:SetText("Фракция — это группа должностей.\n" ..
            "После создания она появится в редакторе ДОЛЖНОСТЕЙ\n" ..
            "(поле «Фракция»), в F4 и в табе вопросов (TAB)\n" ..
            "как цветная секция. Сохраняется навсегда:")
        local note2 = vgui.Create("DLabel", form)
        note2:SetPos(10, 372) note2:SetSize(426, 20)
        note2:SetFont("P11FW.Small") note2:SetTextColor(AC.gold)
        note2:SetText("data/polus_framework/factions.json")
    end

    -- ==================================================
    --  ВКЛАДКА 3: УТИЛИТЫ СТАНЦИИ
    -- ==================================================
    do
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

        f.UtilLabels.jail = UtilRow(72, "Камера ареста", "арестованных телепортирует сюда (без точки — заморозка на месте)",
            "ПОСТАВИТЬ ЗДЕСЬ", function() SendAction(9) end,
            "УБРАТЬ", function() SendAction(10) end)

        f.UtilLabels.npc = UtilRow(130, "Кадровик", "NPC выдачи профессий — создать перед собой / убрать ближайшего",
            "СОЗДАТЬ", function() SendAction(11) end,
            "УДАЛИТЬ БЛИЖ.", function() SendAction(12) end)

        -- бан-лист
        local banLbl = vgui.Create("DLabel", p)
        banLbl:SetPos(10, 192) banLbl:SetSize(400, 22)
        banLbl:SetFont("P11FW.Big") banLbl:SetTextColor(AC.text)
        banLbl:SetText("БАН-ЛИСТ СТАНЦИИ")

        local bans = vgui.Create("DListView", p)
        bans:SetPos(10, 218) bans:SetSize(626, 200)
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

    -- первая загрузка данных
    RequestAdminData()
end

concommand.Add("p11fw_admin", function()
    P11FW.OpenAdminMenu()
end)
