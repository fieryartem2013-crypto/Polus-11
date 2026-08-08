-- ============================================================
--  ПОЛЮС-11 — КОНТРАКТНИК «НАРЯДНИК» (client) v4.19.4
--  Окно контрактов часа (E по интенданту) + HUD-виджет
--  взятых нарядов (справа сверху). Данные — P11_ContractSync
--  от сервера: { list = { {id,name,desc,need,pay,p,got,done} },
--  endsAt = unix конца набора }.
-- ============================================================

surface.CreateFont("P11.CTR.Big",   { font = "Roboto", size = 26, weight = 800, extended = true })
surface.CreateFont("P11.CTR.Mid",   { font = "Roboto", size = 17, weight = 700, extended = true })
surface.CreateFont("P11.CTR.Tx",    { font = "Roboto", size = 15, weight = 500, extended = true })
surface.CreateFont("P11.CTR.Small", { font = "Roboto", size = 13, weight = 500, extended = true })

P11.Contr = P11.Contr or { list = {}, endsAt = 0 }

local CTR_BG   = Color(10, 14, 20, 248)
local CTR_PANE = Color(24, 30, 40, 255)
local CTR_GOLD = Color(255, 205, 100)
local CTR_ACC  = Color(120, 185, 255)
local CTR_TEXT = Color(232, 238, 245)
local CTR_DIM  = Color(150, 158, 172)
local CTR_OK   = Color(110, 215, 140)
local CTR_BAD  = Color(240, 100, 90)

net.Receive("P11_ContractSync", function()
    local ok, tbl = pcall(util.JSONToTable, net.ReadString() or "{}")
    if not ok or not istable(tbl) then return end
    P11.Contr.list   = istable(tbl.list) and tbl.list or {}
    P11.Contr.endsAt = tonumber(tbl.endsAt) or 0
end)

local function TimeLeft()
    local l = (P11.Contr.endsAt or 0) - os.time()
    if l <= 0 then return "скоро смена" end
    return string.format("%02d:%02d", math.floor(l / 60), l % 60)
end

-- ============ ОКНО ============

local function OpenContractWindow()
    if IsValid(P11.ContrFrame) then P11.ContrFrame:Remove() end

    local f = vgui.Create("DFrame")
    P11.ContrFrame = f
    f:SetSize(640, 452)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false) f.btnMaxim:SetVisible(false) f.btnMinim:SetVisible(false)
    f.T0 = SysTime()
    f.Paint = function(s, w, h)
        Derma_DrawBackgroundBlur(s, s.T0)
        draw.RoundedBox(10, 0, 0, w, h, CTR_BG)
        draw.RoundedBoxEx(10, 0, 0, w, 58, CTR_PANE, true, true, false, false)
        surface.SetDrawColor(CTR_GOLD)
        surface.DrawRect(0, 58, w, 2)
        draw.SimpleText("ИНТЕНДАНТ — НАРЯДЫ ЧАСА", "P11.CTR.Big", 16, 10, CTR_GOLD)
        draw.SimpleText("сложная работа — большие деньги · новый набор через " .. TimeLeft(),
            "P11.CTR.Tx", 18, 40, CTR_DIM)
    end
    f.OnKeyCodePressed = function(s, key)
        if key == KEY_ESCAPE then f:Remove() end
    end

    local x = vgui.Create("DButton", f)
    x:SetPos(640 - 38, 12) x:SetSize(26, 26) x:SetText("")
    x.Paint = function(s, w, h)
        draw.SimpleText("✕", "P11.CTR.Mid", w / 2, h / 2,
            s:IsHovered() and CTR_BAD or CTR_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    x.DoClick = function() f:Remove() end

    local sc = vgui.Create("DScrollPanel", f)
    sc:SetPos(12, 68) sc:SetSize(616, 372)
    local bar = sc:GetVBar() bar:SetWide(5)
    bar.Paint = function(_, w, h) draw.RoundedBox(2, 0, 0, w, h, Color(255, 255, 255, 14)) end
    bar.btnGrip.Paint = function(_, w, h) draw.RoundedBox(2, 0, 0, w, h, CTR_GOLD) end

    local list = P11.Contr.list or {}
    if #list == 0 then
        local l = sc:Add("DLabel")
        l:SetFont("P11.CTR.Tx") l:SetTextColor(CTR_DIM)
        l:SetText("  Набор нарядов собирается — загляни через пару секунд.")
        l:SizeToContents()
    end

    for _, c in ipairs(list) do
        local pnl = sc:Add("DPanel")
        pnl:Dock(TOP) pnl:DockMargin(0, 0, 0, 8) pnl:SetTall(96)
        pnl.Paint = function(s, w, h)
            draw.RoundedBox(8, 0, 0, w, h, CTR_PANE)
            if c.done then
                surface.SetDrawColor(CTR_OK.r, CTR_OK.g, CTR_OK.b, 120)
            elseif c.got then
                surface.SetDrawColor(CTR_ACC.r, CTR_ACC.g, CTR_ACC.b, 110)
            else
                surface.SetDrawColor(255, 255, 255, 26)
            end
            surface.DrawOutlinedRect(0, 0, w, h, 1)

            draw.SimpleText(c.name, "P11.CTR.Mid", 14, 10, c.done and CTR_OK or CTR_TEXT)
            draw.SimpleText(c.desc, "P11.CTR.Tx", 14, 34, CTR_DIM)
            draw.SimpleText(c.pay .. "₽", "P11.CTR.Mid", w - 14, 12, CTR_GOLD, TEXT_ALIGN_RIGHT)

            -- шкала прогресса по низу карточки
            local frac = math.Clamp((tonumber(c.p) or 0) / math.max(1, tonumber(c.need) or 1), 0, 1)
            draw.RoundedBox(4, 14, h - 26, w - 28, 14, Color(0, 0, 0, 120))
            if frac > 0 then
                draw.RoundedBox(4, 16, h - 24, (w - 32) * frac, 10,
                    c.done and CTR_OK or CTR_ACC)
            end
            draw.SimpleText(math.floor(tonumber(c.p) or 0) .. "/" .. (tonumber(c.need) or 1),
                "P11.CTR.Small", w / 2, h - 19, CTR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        local b = vgui.Create("DButton", pnl)
        b:SetPos(640 - 12 - 16 - 118, 12) b:SetSize(110, 30) b:SetText("")
        b.Paint = function(s, w, h)
            local col = CTR_DIM
            local label = "ВЗЯТЬ НАРЯД"
            if c.done then
                label, col = "✓ СДАНО", CTR_OK
            elseif c.got then
                label, col = "В РАБОТЕ", CTR_ACC
            end
            if not c.got and not c.done then
                col = s:IsHovered() and Color(255, 205, 100, 240) or Color(150, 120, 55, 220)
            else
                col = Color(50, 56, 66, 220)
            end
            draw.RoundedBox(6, 0, 0, w, h, col)
            draw.SimpleText(label, "P11.CTR.Tx", w / 2, h / 2 - 1,
                (c.got or c.done) and CTR_DIM or Color(20, 22, 26),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function()
            if c.got or c.done then
                surface.PlaySound("buttons/button10.wav")
                return
            end
            net.Start("P11_ContractAct")
                net.WriteUInt(1, 4)
                net.WriteString(c.id)
            net.SendToServer()
            surface.PlaySound("buttons/button15.wav")
            timer.Simple(0.5, function()
                if IsValid(f) then f:Remove() end
                OpenContractWindow()
            end)
        end
    end

    surface.PlaySound("buttons/button14.wav")
end

net.Receive("P11_ContractOpen", function()
    local ok, err = pcall(OpenContractWindow)
    if not ok then print("[POLUS][ERROR] окно нарядника: " .. tostring(err)) end
end)

-- ============ HUD-ВИДЖЕТ ВЗЯТЫХ НАРЯДОВ ============

hook.Add("HUDPaint", "P11.ContractHUD", function()
    if P11B and P11B.open then return end -- под ТАБом не лезем
    local me = LocalPlayer()
    if not IsValid(me) or not me:Alive() then return end

    local rows = {}
    for _, c in ipairs(P11.Contr.list or {}) do
        if c.got and not c.done then
            rows[#rows + 1] = "▸ " .. c.name .. "  " ..
                math.floor(tonumber(c.p) or 0) .. "/" .. (tonumber(c.need) or 1)
        end
    end
    if #rows == 0 then return end

    local x, y = ScrW() - 320, 100
    draw.RoundedBox(6, x, y, 296, 26 + #rows * 18 + 8, Color(8, 12, 18, 190))
    surface.SetDrawColor(CTR_GOLD.r, CTR_GOLD.g, CTR_GOLD.b, 150)
    surface.DrawOutlinedRect(x, y, 296, 26 + #rows * 18 + 8, 1)
    draw.SimpleText("НАРЯДЫ (смена через " .. TimeLeft() .. ")", "P11.CTR.Small",
        x + 10, y + 13, CTR_GOLD, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    for i, r in ipairs(rows) do
        draw.SimpleText(r, "P11.CTR.Tx", x + 12, y + 24 + i * 18, CTR_TEXT,
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end)

print("[POLUS-11] контракты «НАРЯДНИК» (client): окно интенданта + HUD-виджет")
