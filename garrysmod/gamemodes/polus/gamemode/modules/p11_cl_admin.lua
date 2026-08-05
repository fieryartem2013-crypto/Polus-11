-- ============================================================
--  ПОЛЮС-11 — ПУЛЬТ ДЕЖУРНОГО (клиент)
--  Команда: polus11_panel или чат !пульт
-- ============================================================

surface.CreateFont("P11.Adm.Title", {font = "Roboto", size = 24, weight = 700, extended = true})
surface.CreateFont("P11.Adm.Text",  {font = "Roboto", size = 16, weight = 500, extended = true})
surface.CreateFont("P11.Adm.Small", {font = "Roboto", size = 14, weight = 400, extended = true})

local COL_BG   = Color(24, 26, 32, 250)
local COL_TOP  = Color(16, 17, 22, 255)
local COL_ACC  = Color(100, 160, 255)
local COL_RED  = Color(220, 80, 80)
local COL_GRN  = Color(100, 200, 120)
local COL_TEXT = Color(235, 237, 242)
local COL_SUB  = Color(150, 155, 170)

local PANEL_DATA = nil

-- ==================== ОТКРЫТИЕ ====================

local function OpenPanel()
    if IsValid(POLUS11.Panel) then POLUS11.Panel:Remove() end

    -- регистрируем открытие на сервере
    net.Start("P11_PanelAction")
        net.WriteUInt(10, 8)
        net.WriteBool(true)
    net.SendToServer()

    local frame = vgui.Create("DFrame")
    POLUS11.Panel = frame
    frame:SetSize(760, 640)
    frame:Center()
    frame:SetTitle("")
    frame:SetDraggable(true)
    frame:MakePopup()
    frame:SetDeleteOnClose(true)
    frame.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, COL_BG)
        draw.RoundedBox(8, 0, 0, w, 52, COL_TOP)
        draw.SimpleText("ПУЛЬТ ДЕЖУРНОГО — станция «ПОЛЮС-11»", "P11.Adm.Title", 14, 13, COL_TEXT)
    end

    frame.OnClose = function()
        net.Start("P11_PanelAction")
            net.WriteUInt(10, 8)
            net.WriteBool(false)
        net.SendToServer()
    end

    -- заполним когда придут данные
    net.Start("P11_PanelAction") -- пустой запрос → сервер ответит данными
        net.WriteUInt(10, 8)
        net.WriteBool(true)
    net.SendToServer()

    frame.Think = function()
        if PANEL_DATA and not frame.P11_Filled then
            frame.P11_Filled = true
            POLUS11_FillPanel(frame)
        end
    end
end

-- ==================== ЗАПОЛНЕНИЕ ====================

function POLUS11_FillPanel(frame)
    local d = PANEL_DATA

    -- ---- Выбор игрока + заразить
    local combo = vgui.Create("DComboBox", frame)
    combo:SetPos(14, 64)
    combo:SetSize(300, 32)
    combo:SetValue("Выберите игрока...")
    combo.Choices = {}
    for _, p in ipairs(d.players) do
        local mark = p.infected and " [НЕЧТО]" or ""
        combo.Choices[#combo.Choices + 1] = combo:AddChoice(p.name .. mark, p.idx)
    end
    combo.OnSelect = function(s, i, val, data)
        s.P11_Target = data
    end

    local infectBtn = vgui.Create("DButton", frame)
    infectBtn:SetPos(322, 64)
    infectBtn:SetSize(140, 32)
    infectBtn:SetText("")
    infectBtn.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(240, 100, 100) or COL_RED)
        draw.SimpleText("ЗАРАЗИТЬ", "P11.Adm.Text", w / 2, h / 2, Color(20, 14, 16), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    infectBtn.DoClick = function()
        if not combo.P11_Target then return end
        net.Start("P11_PanelAction")
            net.WriteUInt(1, 8)
            net.WriteUInt(combo.P11_Target, 8)
        net.SendToServer()
    end

    local zeroBtn = vgui.Create("DButton", frame)
    zeroBtn:SetPos(470, 64)
    zeroBtn:SetSize(180, 32)
    zeroBtn:SetText("")
    zeroBtn.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(130, 220, 150) or COL_GRN)
        draw.SimpleText("Случайный ноль", "P11.Adm.Text", w / 2, h / 2, Color(20, 22, 24), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    zeroBtn.DoClick = function()
        net.Start("P11_PanelAction") net.WriteUInt(2, 8) net.SendToServer()
    end

    -- ---- Фазы
    local phLbl = vgui.Create("DLabel", frame)
    phLbl:SetText("Фаза смены: " .. d.phase)
    phLbl:SetFont("P11.Adm.Text")
    phLbl:SetTextColor(COL_TEXT)
    phLbl:SetPos(14, 106)
    phLbl:SizeToContents()

    local phases = POLUS11.Config.Phases
    for i, ph in ipairs(phases) do
        local b = vgui.Create("DButton", frame)
        b:SetPos(14 + (i - 1) * 186, 132)
        b:SetSize(178, 30)
        b:SetText("")
        local cur = (d.phase == ph)
        b.Paint = function(s, w, h)
            draw.RoundedBox(6, 0, 0, w, h, cur and COL_ACC or Color(56, 60, 72))
            draw.SimpleText(ph, "P11.Adm.Text", w / 2, h / 2, cur and Color(16, 18, 22) or COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function()
            net.Start("P11_PanelAction")
                net.WriteUInt(3, 8)
                net.WriteUInt(i, 4)
            net.SendToServer()
        end
    end

    -- ---- Кнопки ивентов
    local events = {
        {id = 12, name = "СИРЕНА: общее построение"},
        {id = 4,  name = "Авария генератора (2 мин)"},
        {id = 5,  name = "Магнитная буря (90 сек)"},
        {id = 6,  name = "Крики из вентиляции"},
        {id = 7,  name = "СПАВН ТВАРИ (куда смотрю)"},
        {id = 9,  name = "Вернуть свет"},
        {id = 11, name = "Долить топлива"},
        {id = 8,  name = "Вылечить всех (рестарт)"},
    }
    for i, ev in ipairs(events) do
        local row = math.ceil(i / 2)
        local colm = ((i - 1) % 2)
        local b = vgui.Create("DButton", frame)
        b:SetPos(14 + colm * 372, 172 + (row - 1) * 40)
        b:SetSize(364, 34)
        b:SetText("")
        b.Paint = function(s, w, h)
            local c = Color(46, 50, 62)
            if s:IsHovered() then c = Color(66, 72, 90) end
            draw.RoundedBox(6, 0, 0, w, h, c)
            draw.SimpleText(ev.name, "P11.Adm.Text", w / 2, h / 2, COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function()
            surface.PlaySound("buttons/button9.wav")
            net.Start("P11_PanelAction") net.WriteUInt(ev.id, 8) net.SendToServer()
        end
    end

    frame:SetSize(760, 680)
    frame:Center()

    -- ---- Заражённые
    local infLbl = vgui.Create("DLabel", frame)
    infLbl:SetText("ЗАРАЖЁННЫЕ (секретно):")
    infLbl:SetFont("P11.Adm.Text")
    infLbl:SetTextColor(Color(255, 130, 130))
    infLbl:SetPos(14, 382)
    infLbl:SizeToContents()

    local infPanel = vgui.Create("DScrollPanel", frame)
    infPanel:SetPos(10, 408)
    infPanel:SetSize(360, 178)
    for _, p in ipairs(d.players) do
        if p.infected then
            local l = vgui.Create("DLabel", infPanel)
            l:Dock(TOP)
            l:DockMargin(8, 3, 6, 3)
            l:SetTall(22)
            l:SetFont("P11.Adm.Text")
            l:SetTextColor(Color(255, 100, 100))
            l:SetText("☣ " .. p.name .. (p.active and "  (Нечто проснулось)" or "  (инкубация...)"))
        end
    end

    -- ---- Статус станции
    local statText = "Свет: " .. (d.blackout and "ОТКЛЮЧЁН!" or "есть")
        .. "   Буря: " .. (d.storm and "ДА" or "нет")
        .. "   Генераторы: "
    for _, g in ipairs(d.gens) do
        statText = statText .. "[" .. (g.damaged and "АВАРИЯ" or g.fuel .. "с") .. "] "
    end
    if #d.gens == 0 then statText = statText .. "не установлены!" end

    local stat = vgui.Create("DLabel", frame)
    stat:SetText(statText)
    stat:SetFont("P11.Adm.Small")
    stat:SetTextColor(COL_SUB)
    stat:SetPos(14, 594)
    stat:SetWide(730)
    stat:SetTall(18)

    -- ---- Лог
    local logPanel = vgui.Create("DScrollPanel", frame)
    logPanel:SetPos(382, 408)
    logPanel:SetSize(368, 178)

    local logLbl = vgui.Create("DLabel", frame)
    logLbl:SetText("ЛОГ СТАНЦИИ:")
    logLbl:SetFont("P11.Adm.Text")
    logLbl:SetTextColor(COL_TEXT)
    logLbl:SetPos(382, 382)
    logLbl:SizeToContents()

    for _, line in ipairs(d.log) do
        local l = vgui.Create("DLabel", logPanel)
        l:Dock(TOP)
        l:DockMargin(6, 2, 6, 2)
        l:SetTall(18)
        l:SetFont("P11.Adm.Small")
        l:SetTextColor(Color(190, 220, 190))
        l:SetText(line)
    end
end

-- ==================== ПРИЁМ ДАННЫХ ====================

net.Receive("P11_PanelData", function()
    local d = {players = {}, gens = {}, log = {}}

    local np = net.ReadUInt(8)
    for i = 1, np do
        d.players[#d.players + 1] = {
            name = net.ReadString(),
            idx = net.ReadUInt(8),
            infected = net.ReadBool(),
            active = net.ReadBool(),
        }
    end

    d.phase = net.ReadString()
    d.blackout = net.ReadBool()
    d.storm = net.ReadBool()

    local ng = net.ReadUInt(8)
    for i = 1, ng do
        d.gens[#d.gens + 1] = {
            fuel = net.ReadUInt(16),
            damaged = net.ReadBool(),
        }
    end

    local nl = net.ReadUInt(8)
    for i = 1, nl do
        d.log[#d.log + 1] = net.ReadString()
    end

    PANEL_DATA = d

    -- переполнить, если пульт открыт
    if IsValid(POLUS11.Panel) then
        POLUS11.Panel:Clear()
        POLUS11.Panel.P11_Filled = false
    end
end)

concommand.Add("polus11_panel", function()
    OpenPanel()
end)

hook.Add("OnPlayerChat", "P11_PanelChat", function(ply, text)
    if ply ~= LocalPlayer() then return end
    text = string.lower(string.Trim(text))
    if text == "!пульт" or text == "!pult" or text == "!panel" then
        OpenPanel()
        return true
    end
end)
