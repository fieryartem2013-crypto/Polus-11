-- ============================================================
--  ПОЛЮС-11 — КАЗНА СТАНЦИИ (client) v4.14.2 «КАЗНА»
--  Окно-ростер выдачи ТРЁХ валют онлайн-бойцам:
--   💠 ПФ (flux) · ₽ ДЕНЬГИ (money) · ⏱ СТАЖ (time, минуты)
--  Открытие: консоль `p11_kazna` или вкладка 💠 ПОТОК (F4-админ).
--  Доступ решат на сервере (ранг 4+); оффлайн-выдача — формы
--  в 💠 ПОТОК / консоль p11_kaznagive <вид> <цель> <сумма>.
-- ============================================================

surface.CreateFont("P11K.Title", { font = "Roboto", size = 24, weight = 800, extended = true })
surface.CreateFont("P11K.Big",   { font = "Roboto", size = 17, weight = 700, extended = true })
surface.CreateFont("P11K.Text",  { font = "Roboto", size = 15, weight = 500, extended = true })
surface.CreateFont("P11K.Small", { font = "Roboto", size = 13, weight = 500, extended = true })

local C = {
    bg    = Color(9, 12, 18, 247),
    panel = Color(19, 25, 34, 255),
    flux  = Color(130, 220, 235),
    money = Color(235, 205, 100),
    time  = Color(150, 230, 150),
    text  = Color(230, 238, 246),
    dim   = Color(150, 160, 176),
    ok    = Color(130, 235, 150),
    red   = Color(255, 120, 110),
}

local KINDS = {
    { id = "flux",  name = "💠 ПФ",     col = C.flux  },
    { id = "money", name = "₽ ДЕНЬГИ",  col = C.money },
    { id = "time",  name = "⏱ СТАЖ",    col = C.time  },
}
local KINDID = { flux = 0, money = 1, time = 2 }

P11K = P11K or { Frame = nil, Roster = {}, Sel = nil }

local function CloseKazna()
    if IsValid(P11K.Frame) then P11K.Frame:Remove() P11K.Frame = nil end
end

local function RequestRoster()
    net.Start("P11_KaznaRoster")
    net.SendToServer()
end

local function SendDo(kind, idx, amount)
    if not KINDID[kind] or not idx or not amount or amount == 0 then return end
    net.Start("P11_KaznaDo")
        net.WriteUInt(KINDID[kind], 2)
        net.WriteUInt(idx, 16)
        net.WriteInt(amount, 32)
    net.SendToServer()
end

-- ============ ОКНО ============
local function OpenKazna()
    if IsValid(P11K.Frame) then P11K.Frame:Remove() end
    P11K.Sel = nil

    local W, H = 940, 620
    local f = vgui.Create("DFrame")
    f:SetSize(W, H)
    f:Center()
    f:SetTitle("")
    f:SetDraggable(true)
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.OnClose = function() P11K.Frame = nil P11K.Sel = nil end
    P11K.Frame = f

    f.Paint = function(s, w, h)
        draw.RoundedBox(10, 0, 0, w, h, C.bg)
        draw.RoundedBoxEx(10, 0, 0, w, 46, C.panel, true, true, false, false)
        draw.SimpleText("🏛 КАЗНА СТАНЦИИ", "P11K.Title", 16, 23, C.money, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("ростер онлайна · ранг 4+ · оффлайн — формы в 💠 ПОТОК (p11_kaznagive)",
            "P11K.Small", W - 46, 23, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local xb = vgui.Create("DButton", f)
    xb:SetPos(W - 34, 10) xb:SetSize(24, 26) xb:SetText("")
    xb.Paint = function(s, w, h)
        draw.SimpleText("✕", "P11K.Big", w / 2, h / 2, s:IsHovered() and C.red or C.dim,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    xb.DoClick = function() f:Remove() end

    -- ---------- шапка таблицы ----------
    local head = vgui.Create("DPanel", f)
    head:SetPos(14, 56) head:SetSize(W - 28, 30)
    head.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(15, 20, 28, 255))
        draw.SimpleText("БОЕЦ", "P11K.Big", 12, h / 2, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("💠 ПФ", "P11K.Big", 390, h / 2, C.flux, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("₽ ДЕНЬГИ", "P11K.Big", 570, h / 2, C.money, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("⏱ СТАЖ (мин)", "P11K.Big", 750, h / 2, C.time, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- ---------- строки ростера ----------
    local list = vgui.Create("DScrollPanel", f)
    list:SetPos(14, 90) list:SetSize(W - 28, H - 90 - 132)
    local sb = list:GetVBar()
    sb:SetWide(8)

    local function RebuildRows()
        list:Clear()
        if #P11K.Roster == 0 then
            local empty = vgui.Create("DPanel", list)
            empty:Dock(TOP) empty:SetTall(50)
            empty.Paint = function(s, w, h)
                draw.SimpleText("…жду ответ казначейства (или ты не ранг 4+)…", "P11K.Text",
                    w / 2, h / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            return
        end
        for _, row in ipairs(P11K.Roster) do
            local pnl = vgui.Create("DPanel", list)
            pnl:Dock(TOP) pnl:DockMargin(0, 0, 0, 4) pnl:SetTall(36)
            local idx, nick = row.idx, row.nick
            pnl.Paint = function(s, w, h)
                local sel = P11K.Sel and P11K.Sel.idx == idx
                draw.RoundedBox(6, 0, 0, w, h, sel and Color(30, 38, 50, 255) or Color(17, 22, 30, 255))
                draw.SimpleText(nick, "P11K.Text", 12, h / 2,
                    sel and C.text or Color(210, 218, 228), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            -- три кликабельные ячейки-валюты
            local cells = {
                { id = "flux",  val = row.flux,  col = C.flux,  x = 330, w = 120 },
                { id = "money", val = row.money, col = C.money, x = 510, w = 120 },
                { id = "time",  val = row.time,  col = C.time,  x = 690, w = 120 },
            }
            for _, cell in ipairs(cells) do
                local b = vgui.Create("DButton", pnl)
                b:SetPos(cell.x, 3) b:SetSize(cell.w, 30) b:SetText("")
                b.Paint = function(s, w, h)
                    local sel = P11K.Sel and P11K.Sel.idx == idx and P11K.Sel.kind == cell.id
                    local a = sel and 70 or (s:IsHovered() and 40 or 18)
                    draw.RoundedBox(5, 0, 0, w, h, Color(cell.col.r, cell.col.g, cell.col.b, a))
                    if sel then
                        surface.SetDrawColor(cell.col.r, cell.col.g, cell.col.b, 220)
                        surface.DrawOutlinedRect(0, 0, w, h, 1)
                    end
                    draw.SimpleText(tostring(cell.val), "P11K.Big", w / 2, h / 2, cell.col,
                        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                b.DoClick = function()
                    P11K.Sel = { idx = idx, kind = cell.id, nick = nick }
                    surface.PlaySound("ui/buttonclick.wav")
                end
            end
        end
    end
    P11K.RebuildRows = RebuildRows
    RebuildRows()

    -- ---------- нижняя панель выдачи ----------
    local botY = H - 124
    local bot = vgui.Create("DPanel", f)
    bot:SetPos(14, botY) bot:SetSize(W - 28, 110)
    bot.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, C.panel)
        local sel = P11K.Sel
        local kinfo = sel and KINDS[(KINDID[sel.kind] or 0) + 1]
        draw.SimpleText(
            sel and ("ЦЕЛЬ: «" .. sel.nick .. "» — " .. kinfo.name) or "ЦЕЛЬ: кликни валюту бойца в ростере",
            "P11K.Big", 14, 20, sel and (kinfo.col) or C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("минус = СПИСАТЬ · всё пишется в журнал «КАЗНА: …»",
            "P11K.Small", 14, h - 12, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
    end

    local function BBtn(x, y, w, h, txt, col, fn)
        local b = vgui.Create("DButton", f)
        b:SetPos(x, y) b:SetSize(w, h) b:SetText("")
        b.Paint = function(s, ww, hh)
            local a = s:IsHovered() and 70 or 36
            draw.RoundedBox(6, 0, 0, ww, hh, Color(col.r, col.g, col.b, a))
            surface.SetDrawColor(col.r, col.g, col.b, 170)
            surface.DrawOutlinedRect(0, 0, ww, hh, 1)
            draw.SimpleText(txt, "P11K.Text", ww / 2, hh / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function() surface.PlaySound("buttons/button9.wav") fn() end
        return b
    end

    local amt = vgui.Create("DTextEntry", f)
    amt:SetPos(14 + 4 * 96 + 10, botY + 40) amt:SetSize(150, 34)
    amt:SetFont("P11K.Big") amt:SetPlaceholderText("своя сумма")
    amt:SetNumeric(false)

    local py = botY + 40
    BBtn(14,  py, 90, 34, "+100",  C.ok,  function() amt:SetText("100")  end)
    BBtn(110, py, 90, 34, "+500",  C.ok,  function() amt:SetText("500")  end)
    BBtn(206, py, 90, 34, "+1000", C.ok,  function() amt:SetText("1000") end)
    BBtn(302, py, 90, 34, "−100",  C.red, function() amt:SetText("-100") end)

    local function DoGive(delta)
        if not P11K.Sel then
            LocalPlayer():ChatPrint("[КАЗНА] Сначала кликни валюту бойца в ростере.")
            return
        end
        SendDo(P11K.Sel.kind, P11K.Sel.idx, math.floor(delta))
    end

    BBtn(576, py, 150, 34, "ВЫДАТЬ ✔", C.money, function()
        local n = tonumber(amt:GetText() or "")
        if not n then
            LocalPlayer():ChatPrint("[КАЗНА] Сумма не число.")
            return
        end
        DoGive(n)
    end)
    BBtn(732, py, 170, 34, "↻ ОБНОВИТЬ РОСТЕР", C.flux, function() RequestRoster() end)

    RequestRoster()
    if P11 and P11.AnimateIn then P11.AnimateIn(f) end
end

net.Receive("P11_KaznaRoster", function()
    local n = net.ReadUInt(8)
    local rows = {}
    for i = 1, n do
        rows[#rows + 1] = {
            idx   = net.ReadUInt(16),
            nick  = net.ReadString(),
            flux  = net.ReadInt(32),
            money = net.ReadInt(32),
            time  = net.ReadUInt(32),
        }
    end
    P11K.Roster = rows
    if IsValid(P11K.Frame) and P11K.RebuildRows then P11K.RebuildRows() end
end)

concommand.Add("p11_kazna", function()
    if IsValid(P11K.Frame) then CloseKazna() return end
    OpenKazna()
end)

print("[POLUS-11] КАЗНА КЛИЕНТ v4.14.2: ростер трёх валют — окно p11_kazna (или кнопка во вкладке 💠 ПОТОК)")
