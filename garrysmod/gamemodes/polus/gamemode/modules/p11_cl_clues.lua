-- ============================================================
--  ПОЛЮС-11 — УЛИКИ «СЛЕД» (client) v4.20.0
--  Планшет-досье следователя НКВД: чат !улики → окно находок
--  и сводного ПРОФИЛЯ Нечто (должности жертв, ~рост, окно
--  атак — БЕЗ имён; инфа только РП-допросами и этой папкой).
--  Данные: P11_ClueSync → { list = {...}, prof = {...}|false }.
-- ============================================================

surface.CreateFont("P11.CLU.Big",   { font = "Roboto", size = 24, weight = 800, extended = true })
surface.CreateFont("P11.CLU.Mid",   { font = "Roboto", size = 17, weight = 700, extended = true })
surface.CreateFont("P11.CLU.Tx",    { font = "Roboto", size = 15, weight = 500, extended = true })
surface.CreateFont("P11.CLU.Small", { font = "Roboto", size = 13, weight = 500, extended = true })

P11.Clues = P11.Clues or { list = {}, prof = false }

local CL_BG   = Color(10, 14, 20, 248)
local CL_PANE = Color(24, 30, 40, 255)
local CL_RED  = Color(255, 110, 100)
local CL_ACC  = Color(120, 185, 255)
local CL_TEXT = Color(232, 238, 245)
local CL_DIM  = Color(150, 158, 172)
local CL_GOLD = Color(255, 205, 100)

net.Receive("P11_ClueSync", function()
    local ok, tbl = pcall(util.JSONToTable, net.ReadString() or "{}")
    if not ok or not istable(tbl) then return end
    P11.Clues.list = istable(tbl.list) and tbl.list or {}
    P11.Clues.prof = istable(tbl.prof) and tbl.prof or false
end)

local function OpenClueWindow()
    if IsValid(P11.ClueFrame) then P11.ClueFrame:Remove() end

    local f = vgui.Create("DFrame")
    P11.ClueFrame = f
    f:SetSize(560, 520)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false) f.btnMaxim:SetVisible(false) f.btnMinim:SetVisible(false)
    f.T0 = SysTime()
    f.Paint = function(s, w, h)
        Derma_DrawBackgroundBlur(s, s.T0)
        draw.RoundedBox(10, 0, 0, w, h, CL_BG)
        draw.RoundedBoxEx(10, 0, 0, w, 56, CL_PANE, true, true, false, false)
        surface.SetDrawColor(CL_RED)
        surface.DrawRect(0, 56, w, 2)
        draw.SimpleText("ОСОБЫЙ ОТДЕЛ — ПЛАНШЕТ УЛИК", "P11.CLU.Big", 16, 6, CL_RED)
        draw.SimpleText("гриф «сов. секретно» · имена улики не дают — только профиль",
            "P11.CLU.Small", 18, 38, CL_DIM)
    end
    f.OnKeyCodePressed = function(s, key)
        if key == KEY_ESCAPE then f:Remove() end
    end

    local x = vgui.Create("DButton", f)
    x:SetPos(560 - 38, 12) x:SetSize(26, 26) x:SetText("")
    x.Paint = function(s, w, h)
        draw.SimpleText("✕", "P11.CLU.Mid", w / 2, h / 2,
            s:IsHovered() and CL_RED or CL_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    x.DoClick = function() f:Remove() end

    -- ===== ПРОФИЛЬ (от 2 улик) =====
    local prof = P11.Clues.prof
    local pp = vgui.Create("DPanel", f)
    pp:SetPos(12, 66) pp:SetSize(536, prof and 118 or 66)
    pp.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(30, 22, 24, 255))
        surface.SetDrawColor(CL_RED.r, CL_RED.g, CL_RED.b, 120)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        if prof then
            draw.SimpleText("ПРОФИЛЬ НЕЧТО  ·  по " .. (prof.n or #P11.Clues.list) .. " уликам",
                "P11.CLU.Mid", 14, 8, CL_RED)
            draw.SimpleText("цели по должностям: " .. tostring(prof.jobs or "—"),
                "P11.CLU.Tx", 14, 34, CL_TEXT)
            draw.SimpleText("срез фракций: " .. tostring(prof.cats or "—") ..
                "   ·   рост ~" .. tostring(prof.havg or 180) .. " см",
                "P11.CLU.Tx", 14, 56, CL_TEXT)
            draw.SimpleText("окно атак: " .. tostring(prof.tmin or "?") .. " — " ..
                tostring(prof.tmax or "?") .. "   ·   круг сужается, имён нет — допросы решат",
                "P11.CLU.Tx", 14, 78, CL_GOLD)
        else
            draw.SimpleText("ПРОФИЛЬ ПОКА НЕ СОБИРАЕТСЯ", "P11.CLU.Mid", 14, 10, CL_DIM)
            draw.SimpleText("Нужно минимум 2 улики. После поглощения остаются следы —",
                "P11.CLU.Tx", 14, 32, CL_DIM)
            draw.SimpleText("ищи красную бирку «УЛИКА» и сдавай клавишей E.",
                "P11.CLU.Tx", 14, 48, CL_DIM)
        end
    end

    -- ===== СПИСОК НАХОДОК =====
    local top = 66 + (prof and 118 or 66) + 8
    local sc = vgui.Create("DScrollPanel", f)
    sc:SetPos(12, top) sc:SetSize(536, 520 - top - 12)
    local bar = sc:GetVBar() bar:SetWide(5)
    bar.Paint = function(_, w, h) draw.RoundedBox(2, 0, 0, w, h, Color(255, 255, 255, 14)) end
    bar.btnGrip.Paint = function(_, w, h) draw.RoundedBox(2, 0, 0, w, h, CL_RED) end

    local list = P11.Clues.list or {}
    if #list == 0 then
        local l = sc:Add("DLabel")
        l:SetFont("P11.CLU.Tx") l:SetTextColor(CL_DIM)
        l:SetText("  Папка пуста. Ещё ни одной находки с мест поглощений.")
        l:SizeToContents()
    end

    for i, r in ipairs(list) do
        local pnl = sc:Add("DPanel")
        pnl:Dock(TOP) pnl:DockMargin(0, 0, 0, 6) pnl:SetTall(56)
        pnl.Paint = function(s, w, h)
            draw.RoundedBox(6, 0, 0, w, h, CL_PANE)
            draw.SimpleText("№" .. i .. "  " .. tostring(r.kind or "улика"),
                "P11.CLU.Mid", 12, 8, CL_ACC)
            draw.SimpleText("жертва: " .. tostring(r.job or "?") ..
                "   ·   рост ~" .. tostring(r.h or "?") .. " см   ·   " .. tostring(r.time or "?:??"),
                "P11.CLU.Tx", 12, 30, CL_DIM)
        end
    end

    surface.PlaySound("buttons/button14.wav")
end

net.Receive("P11_ClueOpen", function()
    local ok, err = pcall(OpenClueWindow)
    if not ok then print("[POLUS][ERROR] планшет улик: " .. tostring(err)) end
end)

print("[POLUS-11] улики «СЛЕД» (client): планшет-досье НКВД по !улики")
