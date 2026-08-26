-- ============================================================
--  ПОЛЮС-11 — УТИЛИТ-МЕНЮ ВЫДАЧИ «ПОЛЮС-ФЛЮКСА» (client)
--  v4.10.0 «ГАРАЖ». Заявка: «меню утилит для выдачи этой
--  донат валюты».
--  Открытие: p11_utils (консоль) или F6 → «🛠 УТИЛИТЫ ВЫДАЧИ».
--  Доступ — стафф ранга Administrator (4)+: проверка жёстко на
--  сервере (p11_sv_donate2), попытки выдачи — в журнале станции.
-- ============================================================

surface.CreateFont("P11U.Title", { font = "Roboto", size = 24, weight = 800, extended = true })
surface.CreateFont("P11U.Big",   { font = "Roboto", size = 17, weight = 700, extended = true })
surface.CreateFont("P11U.Text",  { font = "Roboto", size = 15, weight = 500, extended = true })
surface.CreateFont("P11U.Small", { font = "Roboto", size = 13, weight = 500, extended = true })

local C = {
    bg     = Color(9, 12, 18, 247),
    panel  = Color(19, 25, 34, 255),
    card   = Color(25, 32, 43, 255),
    flux   = Color(130, 220, 235),
    gold   = Color(235, 205, 100),
    text   = Color(230, 238, 246),
    dim    = Color(150, 160, 176),
    ok     = Color(130, 235, 150),
    red    = Color(255, 120, 110),
    line   = Color(90, 120, 150, 140),
}

P11U = P11U or { Frame = nil, Roster = {} }

local function CloseUtil()
    if IsValid(P11U.Frame) then P11U.Frame:Remove() P11U.Frame = nil end
end

local function RequestRoster()
    net.Start("P11_FluxRoster")
    net.SendToServer()
end

local function SendDelta(entIdx, delta)
    if not delta or delta == 0 then return end
    net.Start("P11_FluxAdmin")
        net.WriteUInt(entIdx, 8)
        net.WriteInt(delta, 32)
    net.SendToServer()
    surface.PlaySound("buttons/button15.wav")
    -- живой ростер вернём через секунду (сервер уже пересчитал и засинкал)
    timer.Simple(0.6, function()
        if IsValid(P11U.Frame) then RequestRoster() end
    end)
end

local function UtilBtn(row, x, y, w, h, lbl, col, fn)
    local b = vgui.Create("DButton", row)
    b:SetPos(x, y) b:SetSize(w, h) b:SetText("")
    b.Paint = function(s2, ww, hh)
        draw.RoundedBox(6, 0, 0, ww, hh, s2:IsHovered() and Color(col.r, col.g, col.b, 85) or Color(col.r, col.g, col.b, 32))
        surface.SetDrawColor(col)
        surface.DrawOutlinedRect(0, 0, ww, hh, 1)
        draw.SimpleText(lbl, "P11U.Small", ww / 2, hh / 2, s2:IsHovered() and Color(255, 255, 240) or col,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    b.DoClick = fn
    return b
end

local function OpenUtility()
    CloseUtil()

    local W = 720
    local H = math.min(ScrH() - 60, 140 + 52 * math.max(1, #P11U.Roster) + 44)

    local f = vgui.Create("DFrame")
    P11U.Frame = f
    f:SetSize(W, H)
    f:Center()
    f:SetTitle("")
    f:SetDraggable(true)
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false)
    f.btnMaxim:SetVisible(false)
    f.btnMinim:SetVisible(false)
    f.OnRemove = function() if P11U.Frame == f then P11U.Frame = nil end end
    f.OnKeyCodePressed = function(_, key) if key == KEY_ESCAPE then f:Remove() end end

    f.Paint = function(s2, w, h)
        Derma_DrawBackgroundBlur(s2, SysTime())
        draw.RoundedBox(12, 0, 0, w, h, C.bg)
        draw.RoundedBoxEx(12, 0, 0, w, 62, C.panel, true, true, false, false)
        surface.SetDrawColor(C.line) surface.DrawRect(0, 62, w, 1)
        draw.SimpleText("🛠 УТИЛИТЫ ВЫДАЧИ · ПОЛЮС-ФЛЮКС", "P11U.Title", 16, 14, C.flux)
        draw.SimpleText("кнопки — мгновенное начисление/списание; оффлайн-игроку — серверная консоль: p11_fluxgive <SteamID64> <n>",
            "P11U.Small", 16, 42, C.dim)
    end

    local xb = vgui.Create("DButton", f)
    xb:SetPos(W - 40, 13) xb:SetSize(26, 24) xb:SetText("")
    xb.Paint = function(s2, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s2:IsHovered() and Color(120, 44, 40) or Color(50, 34, 32))
        draw.SimpleText("✕", "P11U.Small", w / 2, h / 2 - 1, Color(240, 210, 205), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    xb.DoClick = function() f:Remove() end

    UtilBtn(f, W - 40 - 118, 13, 108, 24, "↻ ОБНОВИТЬ", C.dim, function() RequestRoster() end)

    local sc = vgui.Create("DScrollPanel", f)
    sc:SetPos(14, 72) sc:SetSize(W - 28, H - 84)
    sc:GetVBar():SetWide(5)

    if #P11U.Roster == 0 then
        local l = sc:Add("DLabel")
        l:Dock(TOP) l:DockMargin(6, 14, 0, 0)
        l:SetFont("P11U.Text") l:SetTextColor(C.dim)
        l:SetText("Ростер пуст или сервер не ответил (нужен ранг Administrator+). Жми «↻ ОБНОВИТЬ».")
        l:SetTall(28)
    end

    for _, p in ipairs(P11U.Roster) do
        local row = sc:Add("DPanel")
        row:Dock(TOP) row:DockMargin(0, 0, 0, 6) row:SetTall(48)
        local custom = ""
        row.Paint = function(s2, w, h)
            draw.RoundedBox(7, 0, 0, w, h, C.card)
            draw.SimpleText(p.name .. "   ▸ " .. (p.rank or "User"), "P11U.Big", 12, 6, C.text)
            draw.SimpleText(p.sid .. " · баланс: " .. tostring(p.flux or 0) .. " ПФ", "P11U.Small", 12, 27, C.dim)
        end

        local entry = vgui.Create("DTextEntry", row)
        entry:SetNumeric(true)
        entry:SetFont("P11U.Small")
        entry:SetTextColor(C.text)
        entry:SetPlaceholderText("сумма")
        entry:SetPaintBackground(false)
        entry.Paint = function(s2, w, h)
            draw.RoundedBox(5, 0, 0, w, h, Color(10, 14, 20))
            surface.SetDrawColor(C.flux)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            s2:DrawTextEntryText(C.text, Color(90, 100, 115), C.text)
        end
        entry:SetSize(76, 24)

        local bGive  = UtilBtn(row, 0, 0, 74, 24, "+100",  C.ok,  function() SendDelta(p.e, 100) end)
        local bGive2 = UtilBtn(row, 0, 0, 74, 24, "+500",  C.gold, function() SendDelta(p.e, 500) end)
        local bTake  = UtilBtn(row, 0, 0, 74, 24, "−100",  C.red,  function() SendDelta(p.e, -100) end)
        local bCustom= UtilBtn(row, 0, 0, 88, 24, "ВЫДАТЬ", C.flux, function()
            local n = math.floor(tonumber(entry:GetValue()) or 0)
            if n == 0 then
                surface.PlaySound("buttons/button10.wav")
                chat.AddText(Color(255, 120, 110), "[УТИЛИТЫ] ", Color(230, 230, 230),
                    "Впиши сумму в поле (можно с минусом — списать).")
                return
            end
            SendDelta(p.e, n)
            entry:SetText("")
        end)

        row.PerformLayout = function(s2, w, h)
            local y = 12
            local x = w - 12
            bCustom:SetPos(x - 88, y)  x = x - 88 - 8
            entry:SetPos(x - 76, y)    x = x - 76 - 14
            bGive2:SetPos(x - 74, y)   x = x - 74 - 6
            bGive:SetPos(x - 74, y)    x = x - 74 - 6
            bTake:SetPos(x - 74, y)
        end
    end

    surface.PlaySound("ui/buttonclick.wav")
    return f
end

-- ростер приехал — (пере)открыть/обновить окно
net.Receive("P11_FluxRoster", function()
    local rows = util.JSONToTable(net.ReadString() or "") or {}
    P11U.Roster = rows
    if IsValid(P11U.Frame) then
        OpenUtility() -- мягкий редрав с новыми данными
    else
        OpenUtility()
    end
end)

concommand.Add("p11_utils", function()
    -- серверный гейт: ростер придёт только при ранге ≥ 4; без ранга окно скажет причину
    P11U.Roster = {}
    OpenUtility()
    RequestRoster()
end)

print("[P11UTILS] v4.10.0 OK — утилит-меню выдачи ПОЛЮС-ФЛЮКСА (p11_utils, rank 4+)")
