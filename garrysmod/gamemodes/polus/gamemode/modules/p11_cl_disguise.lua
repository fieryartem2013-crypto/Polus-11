-- ============================================================
--  ПОЛЮС-11 — МАСКИРОВКА «ЛЕГАТ» (client) v4.8.7 «ТОЧКА»
--  ОКНО ПЕРЕРИСОВАНО С НУЛЯ по репорту владельца:
--   ● «текст залезает на друг друга» → лейаут теперь собран
--     КУРСОРОМ: у каждой метки/поля/кнопки своя строка с
--     честными отступами, пересечься им негде; длинные строки
--     переносятся по ширине окна (WrapLines), а не вылетают
--     за край, как раньше (одна строка на всю ширину экрана);
--   ● «меню маскировки не закрывается» → ЧЕТЫРЕ способа
--     закрыть: большой крестик ✕ сверху справа, кнопка
--     «СВЕРНУТЬ КЕЙС» внизу, клавиша ESC, повторный ЛКМ/R
--     по кейсу (тоггл). Плюс авто-сворачивание через ~1.2 сек
--     после УСПЕШНОГО наложения/снятия.
--  Всё тяжёлое — на сервере (p11_sv_disguise): он же решает,
--  валидна ли легенда.
-- ============================================================

P11 = P11 or {}

surface.CreateFont("P11.DsgTitle", { font = "Tahoma", size = 20, weight = 800, antialias = true })
surface.CreateFont("P11.Dsg",      { font = "Tahoma", size = 16, weight = 600, antialias = true })
surface.CreateFont("P11.DsgSm",    { font = "Tahoma", size = 14, weight = 500, antialias = true })

local APPLY_FALLBACK = 3.0
local FRAME_W, FRAME_H = 560, 640

P11.DsgState = P11.DsgState or {
    active = false, name = "", job = 0, cd = 0, applyT = APPLY_FALLBACK,
    suits = nil, pending = false,
}

-- ============ ПЕРЕНОС СТРОК ПО ШИРИНЕ ============
local function WrapLines(text, font, maxW, maxLines)
    surface.SetFont(font)
    local lines, cur = {}, ""
    for word in string.gmatch(tostring(text or ""), "%S+") do
        local probe = (cur == "") and word or (cur .. " " .. word)
        if surface.GetTextSize(probe) > maxW and cur ~= "" then
            lines[#lines + 1] = cur
            cur = word
            if maxLines and #lines >= maxLines then
                -- не влезло: последняя строка с многоточием
                local last = lines[#lines]
                while surface.GetTextSize(last .. "…") > maxW and #last > 1 do
                    last = string.sub(last, 1, #last - 1)
                end
                lines[#lines] = last .. "…"
                return lines
            end
        else
            cur = probe
        end
    end
    if cur ~= "" then lines[#lines + 1] = cur end
    if maxLines and #lines > maxLines then
        while #lines > maxLines do table.remove(lines) end
    end
    return lines
end

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
            -- v4.8.7: после УСПЕХА кейс сам сворачивается (заявка
            -- «меню не закрывается»); ошибка — окно остаётся, чинить легенду
            if ok then
                timer.Simple(1.2, function()
                    if IsValid(P11.DsgFrame) and P11.DsgFrame:IsVisible() then
                        P11.DsgFrame:Close()
                    end
                end)
            end
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
--  ОКНО КЕЙСА (лейаут курсором — без наложений)
-- ============================================================

local PANEL = {}

function PANEL:Init()
    self:SetSize(FRAME_W, FRAME_H)
    self:Center()
    self:SetTitle("")
    self:ShowCloseButton(false)
    self:SetDraggable(true)
    self:MakePopup()
    self:SetDeleteOnClose(false)
    self:SetVisible(false)
    self:SetKeyboardInputEnabled(true)
    self.SelectedSuit = nil
    self.StatusCol = Color(160, 168, 180)
    self.EscArmed = false

    -- штатные кнопки DFrame прячем полностью: свой крестик ниже
    pcall(function()
        if IsValid(self.btnClose) then self.btnClose:SetVisible(false) end
        if IsValid(self.btnMinim) then self.btnMinim:SetVisible(false) end
        if IsValid(self.btnMaxim) then self.btnMaxim:SetVisible(false) end
    end)

    -- БОЛЬШОЙ крестик ✕ (заявка «меню не закрывается»)
    self.XBtn = vgui.Create("DButton", self)
    self.XBtn:SetText("")
    self.XBtn:SetTooltip("Закрыть кейс (ESC / повторный ЛКМ по кейсу — тоже)")
    self.XBtn.Paint = function(s, w, h)
        local hot = s:IsHovered()
        draw.RoundedBox(6, 0, 0, w, h, hot and Color(150, 50, 50, 235) or Color(60, 30, 34, 215))
        draw.SimpleText("✕", "P11.Dsg", w * 0.5, h * 0.5,
            hot and Color(255, 235, 235) or Color(255, 170, 160),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    self.XBtn.DoClick = function()
        surface.PlaySound("buttons/button14.wav")
        self:Close()
    end

    local me = self

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
    self.SuitBox.OnSelect = function(s, idx, txt, data)
        me.SelectedSuit = data
        me:RefreshJobs()
    end

    -- липовая должность
    self.JobBox = vgui.Create("DComboBox", self)
    self.JobBox:SetFont("P11.Dsg")

    -- кнопки
    local function BigBtn(text, cb)
        local b = vgui.Create("DButton", self)
        b:SetFont("P11.Dsg")
        b:SetText(text)
        b.DoClick = cb
        return b
    end
    self.ApplyBtn  = BigBtn("НАЛОЖИТЬ МАСКИРОВКУ (3 сек, не двигаясь)", function() me:DoApply() end)
    self.RemoveBtn = BigBtn("СНЯТЬ МАСКИРОВКУ", function() me:DoRemove() end)
    self.CloseBtn  = BigBtn("✕ СВЕРНУТЬ КЕЙС (закрыть окно · ESC)", function()
        surface.PlaySound("buttons/button14.wav")
        me:Close()
    end)

    -- прогресс
    self.Progress = vgui.Create("DProgress", self)
    self.Progress:SetFraction(0)
end

-- Аккуратный лейаут КУРСОРОМ: считаем Y один раз здесь и в Paint
-- используем ТЕ ЖЕ константы — метки не могут залезть на поля.
local L = {
    statusY   = 60,   -- строка статуса легенды
    lab1Y     = 88,   field1Y = 106, fieldH = 30,   -- позывной
    lab2Y     = 148,  field2Y = 166,                  -- облик
    lab3Y     = 208,  field3Y = 226,                  -- должность
    descY     = 268,  info1Y  = 320, info2Y = 336,    -- описание облика
    applyY    = 362,  applyH  = 38,
    removeY   = 406,  removeH = 32,
    closeY    = 444,  closeH  = 28,
    progY     = 480,  progH   = 12,
    status2Y  = 504,  -- статус-строка (перенос, до 2 строк)
}

function PANEL:PerformLayout(w, h)
    w = self:GetWide()
    self.XBtn:SetPos(w - 40, 8)
    self.XBtn:SetSize(32, 32)

    self.NameEntry:SetPos(20, L.field1Y)
    self.NameEntry:SetSize(w - 40, L.fieldH)
    self.SuitBox:SetPos(20, L.field2Y)
    self.SuitBox:SetSize(w - 40, L.fieldH)
    self.JobBox:SetPos(20, L.field3Y)
    self.JobBox:SetSize(w - 40, L.fieldH)

    self.ApplyBtn:SetPos(20, L.applyY)
    self.ApplyBtn:SetSize(w - 40, L.applyH)
    self.RemoveBtn:SetPos(20, L.removeY)
    self.RemoveBtn:SetSize(w - 40, L.removeH)
    self.CloseBtn:SetPos(20, L.closeY)
    self.CloseBtn:SetSize(w - 40, L.closeH)

    self.Progress:SetPos(20, L.progY)
    self.Progress:SetSize(w - 40, L.progH)
end

function PANEL:Paint(w, h)
    draw.RoundedBox(8, 0, 0, w, h, Color(10, 13, 19, 244))
    draw.RoundedBoxEx(8, 0, 0, w, 50, Color(24, 20, 36, 255), true, true, false, false)

    -- заголовок ДВЕ строки, слева; место под крестик справа не трогаем
    draw.SimpleText("💼 КЕЙС МАСКИРОВКИ «ЛЕГАТ»", "P11.DsgTitle", 16, 6,
        Color(255, 205, 110))
    draw.SimpleText("отряд «Красный Орёл» · собственность ЦРУ · не открывать при враге",
        "P11.DsgSm", 16, 32, Color(120, 128, 150))

    -- статус легенды
    local st = P11.DsgState
    if st.active then
        draw.SimpleText("ЛЕГЕНДА АКТИВНА: ты — «" .. st.name .. "»", "P11.Dsg",
            20, L.statusY, Color(255, 100, 90))
    else
        local cdLeft = math.max(0, (st.cd or 0) - (CurTime() - (st.cdAt or 0)))
        draw.SimpleText(cdLeft > 0.3
            and ("Грим сохнет… готовность через " .. math.ceil(cdLeft) .. " сек")
            or "Легенда не надета — собери облик ниже.",
            "P11.Dsg", 20, L.statusY,
            cdLeft > 0.3 and Color(255, 205, 110) or Color(140, 200, 160))
    end

    -- метки полей (каждая НАД своим полем, своя строка)
    draw.SimpleText("ПОЗЫВНОЙ ЛЕГЕНДЫ", "P11.DsgSm", 20, L.lab1Y, Color(140, 148, 165))
    draw.SimpleText("ОБЛИК ЛЕГЕНДЫ", "P11.DsgSm", 20, L.lab2Y, Color(140, 148, 165))
    draw.SimpleText("ДОЛЖНОСТЬ ЛЕГЕНДЫ", "P11.DsgSm", 20, L.lab3Y, Color(140, 148, 165))

    -- описание выбранного облика (перенос по ширине, до 3 строк)
    local suit = self.SelectedSuit and self:FindSuit(self.SelectedSuit)
    if suit then
        local yy = L.descY
        for _, ln in ipairs(WrapLines("• " .. suit.desc, "P11.DsgSm", w - 40, 3)) do
            draw.SimpleText(ln, "P11.DsgSm", 20, yy, Color(180, 190, 210))
            yy = yy + 17
        end
        draw.SimpleText("внешность и код документа подставятся сами; позывной вводится выше,",
            "P11.DsgSm", 20, L.info1Y, Color(140, 148, 165))
        draw.SimpleText("либо кейс сочинит советскую фамилию сам.",
            "P11.DsgSm", 20, L.info2Y, Color(140, 148, 165))
    end

    -- статус-строка снизу (перенос, до 2 строк)
    if self.StatusText and self.StatusText ~= "" then
        local yy = L.status2Y
        for _, ln in ipairs(WrapLines(self.StatusText, "P11.DsgSm", w - 40, 2)) do
            draw.SimpleText(ln, "P11.DsgSm", 20, yy, self.StatusCol or Color(160, 168, 180))
            yy = yy + 17
        end
    end

    -- подвал: две КОРОТКИЕ строки по центру, ничего не вылетает за край
    draw.SimpleText("ПКМ по кейсу — мгновенно надеть/снять по последней легенде",
        "P11.DsgSm", w * 0.5, h - 34, Color(110, 118, 140), TEXT_ALIGN_CENTER)
    draw.SimpleText("закрыть: ✕ сверху справа · кнопка выше · ESC · повторный ЛКМ по кейсу · стационарно: p11_spies (админ)",
        "P11.DsgSm", w * 0.5, h - 18, Color(110, 118, 140), TEXT_ALIGN_CENTER)
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

    -- ESC закрывает кейс (edge-detect, чтобы не съесть ESC главного меню)
    if self:IsVisible() then
        if self.EscArmed and input.IsKeyDown(KEY_ESCAPE) then
            self.EscArmed = false
            self:Close()
            return
        end
        if not input.IsKeyDown(KEY_ESCAPE) then
            self.EscArmed = true
        end
    end
end

function PANEL:Close()
    -- DeleteOnClose=false: просто прячем; курсор вернётся сам,
    -- но подстрахуем каждое закрытие гашением скрин-кликера
    if self.OnClosed then pcall(self.OnClosed, self) end
    self:SetVisible(false)
    if gui and gui.EnableScreenClicker then pcall(gui.EnableScreenClicker, false) end
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
    self:MakePopup()
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
--  ОТКРЫТИЕ / ТОГГЛ
-- ============================================================

function P11.BuildDisguiseMenu()
    if not IsValid(P11.DsgFrame) then
        P11.DsgFrame = vgui.Create("P11DisguiseMenu")
    end
    P11.DsgFrame:FillData()
    return P11.DsgFrame
end

function P11.OpenDisguiseMenu()
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

-- ТОГГЛ для оружия: окно открыто → свернуть; закрыто → открыть.
-- (заявка «меню не закрывается»: ЛКМ/R по кейсу закрывает тоже)
function P11.ToggleDisguiseMenu()
    if IsValid(P11.DsgFrame) and P11.DsgFrame:IsVisible() then
        P11.DsgFrame:Close()
        surface.PlaySound("buttons/button14.wav")
    else
        P11.OpenDisguiseMenu()
    end
end

print("[P11-DISGUISE] клиент кейса «ЛЕГАТ» v4.8.7 «ТОЧКА»: лейаут без наложений, 4 способа закрыть (✕/кнопка/ESC/ЛКМ по кейсу), авто-сворачивание после успеха")
