-- ============================================================
--  ПОЛЮС-11 — ДЕЛА ВТОРОЙ ВОЛНЫ (client) v4.2
--  • маркер + линия пути заявки снабжения (для грузчика);
--  • окно ДОСЬЕ НКВД (лента инцидентов).
-- ============================================================

surface.CreateFont("P11.D2.Mid",   { font = "Roboto", size = 20, weight = 700, extended = true })
surface.CreateFont("P11.D2.Small", { font = "Roboto", size = 15, weight = 500, extended = true })

P11 = P11 or {}
P11.Porter = nil            -- { text, nick, x,y,z }
P11.DossierRows = nil

-- ============ ЗАЯВКА ГРУЗЧИКУ ============

net.Receive("P11_PorterSync", function()
    local ok, data = pcall(util.JSONToTable, net.ReadString() or "{}")
    if ok and istable(data) and data.text then
        P11.Porter = data
    else
        P11.Porter = nil
    end
end)

local function IsPorter()
    if P11FW and P11FW.GetJobId then
        return P11FW.GetJobId(LocalPlayer()) == "porter"
    end
    return false
end

hook.Add("HUDPaint", "P11.PorterHUD", function()
    local r = P11.Porter
    if not r then return end
    local me = LocalPlayer()
    if not IsValid(me) or not me:Alive() then return end

    local pos = Vector(r.x or 0, r.y or 0, r.z or 0)

    -- заявителю: мягкий статус «ждём»
    if me:Nick() == r.nick then
        draw.RoundedBox(6, ScrW() / 2 - 190, 68, 380, 40, Color(8, 12, 18, 190))
        draw.SimpleText("📦 Заявка «" .. (r.text or "") .. "» отправлена грузчикам",
            "P11.D2.Small", ScrW() / 2, 88, Color(230, 210, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        return
    end

    if not IsPorter() then return end

    -- маркер цели в мире
    local scr = (pos + Vector(0, 0, 70)):ToScreen()
    if scr.visible then
        local dist = math.floor(me:GetPos():Distance(pos))
        draw.RoundedBox(6, scr.x - 88, scr.y - 38, 176, 56, Color(20, 14, 6, 210))
        surface.SetDrawColor(255, 200, 100, 170)
        surface.DrawOutlinedRect(scr.x - 88, scr.y - 38, 176, 56, 1)
        draw.SimpleText("📦 «" .. (r.text or "") .. "»", "P11.D2.Small", scr.x, scr.y - 26,
            Color(255, 215, 130), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(r.nick .. " · " .. dist .. " м", "P11.D2.Small", scr.x, scr.y - 6,
            Color(200, 200, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- ЛИНИЯ ПУТИ: пунктир по земле от грузчика к заявителю
    local from = me:GetPos() + Vector(0, 0, 4)
    local delta = pos - from
    local dist = delta:Length()
    if dist > 60 then
        local steps = math.Clamp(math.floor(dist / 34), 2, 70)
        for i = 0, steps - 1 do
            if i % 2 == 0 then
                local p1 = from + delta * (i / steps)
                local p2 = from + delta * ((i + 0.6) / steps)
                local s1, s2 = p1:ToScreen(), p2:ToScreen()
                if s1.visible and s2.visible then
                    surface.SetDrawColor(255, 200, 100, 150)
                    surface.DrawLine(s1.x, s1.y, s2.x, s2.y)
                end
            end
        end
    end
end)

-- ============ ДОСЬЕ НКВД ============

net.Receive("P11_Dossier", function()
    local ok, rows = pcall(util.JSONToTable, net.ReadString() or "[]")
    if ok and istable(rows) then P11.DossierRows = rows end
    if IsValid(P11.DossierFrame) then P11.DossierFrame:Remove() P11.DossierFrame = nil end
    -- авто-раскрытие при ручном запросе
    if P11.DossierWantsOpen then
        P11.DossierWantsOpen = false
        OpenDossierUI()
    end
end)

function OpenDossierUI()
    if not (P11UI and P11UI.Frame) then return end
    if not P11.DossierRows then
        chat.AddText(Color(200, 170, 120), "[ПОЛЮС-11] Досье грузится… либо допуска нет (особый отдел/командование).")
        return
    end

    local f = P11UI.Frame("ОСОБЫЙ ОТДЕЛ — ДОСЬЕ СМЕНЫ", "тесты · аресты · розыски · подмены", 620, 520, Color(140, 170, 220))
    P11.DossierFrame = f

    local scroll = P11UI.Scroll(f, 12, 64, 596, 444)

    if #P11.DossierRows == 0 then
        P11UI.Body(scroll, "Инцидентов за смену не зафиксировано. Лента чиста — подозрительно чиста.", 560)
        return
    end

    for i = #P11.DossierRows, 1, -1 do
        local r = P11.DossierRows[i]
        local card = scroll:Add("DPanel")
        card:Dock(TOP) card:DockMargin(4, 4, 4, 0) card:SetTall(44)
        local kindCol = Color(200, 200, 210)
        local k = string.upper(r.kind or "")
        if string.find(k, "НЕЧТО") or string.find(k, "ПОДМЕНА") then kindCol = Color(255, 110, 100)
        elseif string.find(k, "РОЗЫСК") then kindCol = Color(255, 190, 100)
        elseif string.find(k, "ТЕСТ") then kindCol = Color(140, 210, 255)
        elseif string.find(k, "ARREST") or string.find(k, "АРЕСТ") then kindCol = Color(255, 150, 90) end
        card.Paint = function(s, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(20, 26, 36, 235))
            surface.SetDrawColor(kindCol)
            surface.DrawRect(0, 0, 3, h)
            draw.SimpleText((r.t or "--:--") .. "  " .. k, "P11.D2.Small", 12, 8,
                kindCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(r.text or "", "P11.D2.Small", 12, 24,
                Color(225, 229, 236), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText("— " .. (r.by or "—"), "P11.D2.Small", w - 10, h - 18,
                Color(140, 148, 162), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end
    end
end

concommand.Add("p11_dossier_ui", function()
    P11.DossierWantsOpen = true
    net.Start("P11_DossierReq") -- просим свежую ленту у сервера
    net.SendToServer()
    if P11.DossierRows then OpenDossierUI() end
end)

-- чат-вызов: /досье
hook.Add("OnPlayerChat", "P11.DossierChat", function(ply, text)
    if ply ~= LocalPlayer() then return end
    local t = string.lower(text or "")
    if t == "/досье" or t == "/досье нквд" or t == "/dossier" then
        RunConsoleCommand("p11_dossier_ui")
        return true
    end
end)

print("[POLUS-11] клиент дел-2 загружен (грузчик-маркер/досье)")
