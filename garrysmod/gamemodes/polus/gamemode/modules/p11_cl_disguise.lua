-- ============================================================
--  ПОЛЮС-11 — МАСКИРОВКА «ЛЕГАТ» (client) v4.8.5 «КРАСНЫЙ ОРЁЛ»
--  Окно кейса маскировки: сбор легенды (липовой позывной +
--  облик + должность), прогресс наложения 3 сек, статус
--  текущей маскировки. Всё тяжёлое — на сервере
--  (p11_sv_disguise): он же решает, валидна ли легенда.
-- ============================================================

P11 = P11 or {}

surface.CreateFont("P11.DsgTitle", { font = "Tahoma", size = 20, weight = 800, antialias = true })
surface.CreateFont("P11.Dsg",      { font = "Tahoma", size = 16, weight = 600, antialias = true })
surface.CreateFont("P11.DsgSm",    { font = "Tahoma", size = 14, weight = 500, antialias = true })

local APPLY_FALLBACK = 3.0

P11.DsgState = P11.DsgState or {
    active = false, name = "", job = 0, cd = 0, applyT = APPLY_FALLBACK,
    suits = nil, pending = false,
}

-- ============================================================
--  СЕТЬ
-- ============================================================

net.Receive("P11_Disguise", function()
    local op = net.ReadUInt(3)
    local st = P11.DsgState

    if op == 1 then -- список легенд + статус
        st.active = net.ReadBool()
        st.name = net.ReadString()
        st.job = net.ReadUInt(16)
        st.cd = net.ReadFloat()
        st.cdAt = CurTime()
        st.applyT = net.ReadFloat()
        local n = net.ReadUInt(8)
        local suits = {}
        for i = 1, n do
            local sid  = net.ReadString()
            local name = net.ReadString()
            local desc = net.ReadString()
            local nj = net.ReadUInt(8)
            local jobs = {}
            for k = 1, nj do
                jobs[#jobs + 1] = { team = net.ReadUInt(16), name = net.ReadString() }
            end
            suits[#suits + 1] = { id = sid, name = name, desc = desc, jobs = jobs }
        end
        st.suits = suits
        if IsValid(P11.DsgFrame) then
            P11.DsgFrame:FillData()
        else
            P11.BuildDisguiseMenu()
        end

    elseif op == 2 then -- результат операции
        local ok = net.ReadBool()
        local msg = net.ReadString()
        local f = P11.DsgFrame
        if ok and st.pending then
            -- сервер принял старт: запускаем визуальный прогресс
            st.progressStart = CurTime()
            if IsValid(f) then f:SetStatus(msg, Color(120, 255, 140)) end
            timer.Simple(st.applyT or APPLY_FALLBACK, function()
                if not st.pending then return end
                st.pending = false
                net.Start("P11_Disguise")
                    net.WriteUInt(2, 3) -- commit
                net.SendToServer()
            end)
            return
        end
        st.pending = false
        if IsValid(f) then
            f:SetStatus(msg, ok and Color(120, 255, 140) or Color(255, 120, 100))
            -- обновим состояние (активность/кулдаун)
            timer.Simple(0.2, function()
                net.Start("P11_Disguise") net.WriteUInt(1, 3) net.SendToServer()
            end)
        else
            -- окна нет: выведем в чат (ПКМ-режим)
            chat.AddText(ok and Color(120, 255, 140) or Color(255, 120, 100),
                "[ЛЕГАТ] ", Color(230, 235, 242), msg)
        end

    elseif op == 6 then -- сервер просит открыть меню (ПКМ без легенды)
        chat.AddText(Color(120, 180, 255), "[ЛЕГАТ] ",
            Color(230, 235, 242), "сначала собери легенду в кейсе.")
        P11.OpenDisguiseMenu()
    end
end)

-- ============================================================
--  ОКНО КЕЙСА
-- ============================================================

local PANEL = {}

function PANEL:Init()
    self:SetSize(560, 520)
    self:Center()
    self:SetTitle("")
    self:SetDraggable(true)
    self:MakePopup()
    self:SetDeleteOnClose(false)
    self:SetVisible(false)
    self.SelectedSuit = nil
    self.StatusCol = Color(160, 168, 180)

    -- позывной
    self.NameEntry = vgui.Create("DTextEntry", self)
    self.NameEntry:SetFont("P11.Dsg")
    self.NameEntry:SetAllowNonAsciiCharacters(true)
    pcall(function()
        self.NameEntry:SetPlaceholderText("Липовой позывной… (пусто — сочинит кейс)")
        self.NameEntry:SetPlaceholderColor(Color(120, 128, 142, 170))
    end)
    self.NameEntry.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(16, 20, 28, 235))
        s:DrawTextEntryText(s:GetTextColor(), Color(80, 170, 255), s:GetCursorColor())
    end
    self.NameEntry:SetTextColor(Color(240, 244, 250))

    -- облик
    self.SuitBox = vgui.Create("DComboBox", self)
    self.SuitBox:SetFont("P11.Dsg")
    local me = self
    self.SuitBox.OnSelect = function(s, idx, txt, data)
        me.SelectedSuit = data
        me:RefreshJobs()
    end

    -- липовая должность
    self.JobBox = vgui.Create("DComboBox", self)
    self.JobBox:SetFont("P11.Dsg")

    -- кнопки
    self.ApplyBtn = vgui.Create("DButton", self)
    self.ApplyBtn:SetFont("P11.Dsg")
    self.ApplyBtn:SetText("НАЛОЖИТЬ МАСКИРОВКУ (3 сек, не двигаясь)")
    self.ApplyBtn.DoClick = function() me:DoApply() end

    self.RemoveBtn = vgui.Create("DButton", self)
    self.RemoveBtn:SetFont("P11.Dsg")
    self.RemoveBtn:SetText("СНЯТЬ МАСКИРОВКУ")
    self.RemoveBtn.DoClick = function() me:DoRemove() end

    -- прогресс
    self.Progress = vgui.Create("DProgress", self)
    self.Progress:SetFraction(0)
end

function PANEL:PerformLayout()
    local w = self:GetWide()
    self.NameEntry:SetPos(20, 96)
    self.NameEntry:SetSize(w - 40, 30)
    self.SuitBox:SetPos(20, 140)
    self.SuitBox:SetSize(w - 40, 30)
    self.JobBox:SetPos(20, 182)
    self.JobBox:SetSize(w - 40, 30)
    self.ApplyBtn:SetPos(20, 296)
    self.ApplyBtn:SetSize(w - 40, 40)
    self.RemoveBtn:SetPos(20, 344)
    self.RemoveBtn:SetSize(w - 40, 30)
    self.Progress:SetPos(20, 384)
    self.Progress:SetSize(w - 40, 14)
end

function PANEL:Paint(w, h)
    draw.RoundedBox(8, 0, 0, w, h, Color(10, 13, 19, 244))
    draw.RoundedBoxEx(8, 0, 0, w, 46, Color(24, 20, 36, 255), true, true, false, false)
    draw.SimpleText("💼 КЕЙС МАСКИРОВКИ «ЛЕГАТ»", "P11.DsgTitle", 16, 23,
        Color(255, 205, 110), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText("отряд «Красный Орёл» · собственность ЦРУ · не открывать при враге",
        "P11.DsgSm", w - 14, 24, Color(120, 128, 150), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    -- статус
    local st = P11.DsgState
    if st.active then
        draw.SimpleText("ЛЕГЕНДА АКТИВНА: ты — «" .. st.name .. "»", "P11.Dsg",
            20, 62, Color(255, 100, 90), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    else
        local cdLeft = math.max(0, (st.cd or 0) - (CurTime() - (st.cdAt or 0)))
        draw.SimpleText(cdLeft > 0.3
            and ("Грим сохнет… готовность через " .. math.ceil(cdLeft) .. " сек")
            or "Легенда не надета — собери облик ниже.",
            "P11.Dsg", 20, 62,
            cdLeft > 0.3 and Color(255, 205, 110) or Color(140, 200, 160),
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    draw.SimpleText("ПОЗЫВНОЙ ЛЕГЕНДЫ", "P11.DsgSm", 20, 88, Color(140, 148, 165))
    draw.SimpleText("ОБЛИК", "P11.DsgSm", 20, 132, Color(140, 148, 165))
    draw.SimpleText("ДОЛЖНОСТЬ ЛЕГЕНДЫ", "P11.DsgSm", 20, 174, Color(140, 148, 165))

    -- описание выбранного костюма
    local suit = self.SelectedSuit and self:FindSuit(self.SelectedSuit)
    if suit then
        draw.SimpleText("• " .. suit.desc, "P11.DsgSm", 20, 224,
            Color(180, 190, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("внешность и код документа подставятся сами; позывной вводится",
            "P11.DsgSm", 20, 244, Color(140, 148, 165), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("выше, либо кейс сочинит советскую фамилию сам.",
            "P11.DsgSm", 20, 262, Color(140, 148, 165), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- статус-строка снизу
    if self.StatusText and self.StatusText ~= "" then
        draw.SimpleText(self.StatusText, "P11.DsgSm", 20, 408,
            self.StatusCol or Color(160, 168, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    draw.SimpleText("ПКМ по кейсу — мгновенно надеть/снять по ПОСЛЕДНЕЙ легенде · стационарно смотри p11_spies (админ)",
        "P11.DsgSm", w * 0.5, h - 18, Color(110, 118, 140), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function PANEL:Think()
    -- прогресс-бар наложения
    local st = P11.DsgState
    if st.progressStart then
        local t = (CurTime() - st.progressStart) / (st.applyT or APPLY_FALLBACK)
        if t >= 1 then
            st.progressStart = nil
            self.Progress:SetFraction(0)
        else
            self.Progress:SetFraction(t)
        end
    end
end

function PANEL:FindSuit(id)
    for _, s in ipairs(P11.DsgState.suits or {}) do
        if s.id == id then return s end
    end
    return nil
end

function PANEL:FillData()
    local st = P11.DsgState
    self.SuitBox:Clear()
    self.JobBox:Clear()
    self.SuitBox:SetValue("— выбери облик легенды —")
    self.JobBox:SetValue("— сначала облик —")
    for _, s in ipairs(st.suits or {}) do
        self.SuitBox:AddChoice(s.name, s.id)
    end
    -- вернуть выбор если был
    if self.SelectedSuit and self:FindSuit(self.SelectedSuit) then
        for i, s in ipairs(st.suits or {}) do
            if s.id == self.SelectedSuit then
                self.SuitBox:ChooseOptionID(i)
                break
            end
        end
    end
    self:RefreshJobs()
    self:SetVisible(true)
    if not self:IsPopup() then self:MakePopup() end
end

function PANEL:RefreshJobs()
    local suit = self.SelectedSuit and self:FindSuit(self.SelectedSuit)
    self.JobBox:Clear()
    if not suit then
        self.JobBox:SetValue("— сначала облик —")
        return
    end
    for i, j in ipairs(suit.jobs) do
        self.JobBox:AddChoice(j.name, j.team)
        if i == 1 then self.JobBox:ChooseOptionID(1) end
    end
end

function PANEL:SetStatus(txt, col)
    self.StatusText = txt
    self.StatusCol = col or Color(160, 168, 180)
end

function PANEL:DoApply()
    local st = P11.DsgState
    if st.active then
        self:SetStatus("Маскировка уже надета — сначала сними старую.", Color(255, 120, 100))
        return
    end
    if st.pending or st.progressStart then return end
    if not self.SelectedSuit then
        self:SetStatus("Выбери облик легенды.", Color(255, 120, 100))
        return
    end
    local idx, jobTeam = self.JobBox:GetSelected()
    if not jobTeam then
        self:SetStatus("Выбери липовую должность.", Color(255, 120, 100))
        return
    end
    st.pending = true
    self:SetStatus("Шлю легенду в кейс…", Color(255, 205, 110))
    net.Start("P11_Disguise")
        net.WriteUInt(5, 3)
        net.WriteString(self.SelectedSuit)
        net.WriteUInt(tonumber(jobTeam) or 0, 16)
        net.WriteString(self.NameEntry:GetText() or "")
    net.SendToServer()
end

function PANEL:DoRemove()
    net.Start("P11_Disguise")
        net.WriteUInt(3, 3)
    net.SendToServer()
end

vgui.Register("P11DisguiseMenu", PANEL, "DFrame")

-- ============================================================
--  ОТКРЫТИЕ
-- ============================================================

function P11.BuildDisguiseMenu()
    if not IsValid(P11.DsgFrame) then
        P11.DsgFrame = vgui.Create("P11DisguiseMenu")
    end
    return P11.DsgFrame
end

function P11.OpenDisguiseMenu()
    -- со свежего нажатия сверимся: кейс должен быть в руках/снаряге
    local ply = LocalPlayer()
    if not (IsValid(ply) and ply:Alive()) then return end
    if not ply:HasWeapon("weapon_polus11_disguise") then
        chat.AddText(Color(255, 120, 100), "[ЛЕГАТ] ",
            Color(230, 235, 242), "кейса маскировки в снаряге нет.")
        return
    end
    net.Start("P11_Disguise")
        net.WriteUInt(1, 3) -- дай список/статус → по ответу окно заполнится
    net.SendToServer()
end

print("[P11-DISGUISE] клиент кейса «ЛЕГАТ» v4.8.5 «КРАСНЫЙ ОРЁЛ» загружен (ЛКМ/R по кейсу — сбор легенды)")
