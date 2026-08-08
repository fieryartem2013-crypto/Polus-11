-- ============================================================
--  ПОЛЮС-11 — «ГЛАЗ»: ПУЛЬТ ДИСПЕТЧЕРА (client) v4.19.0
--  Вид: камеры сети «ГЛАЗ» и игроки ОТ ТРЕТЬЕГО ЛИЦА (CalcView).
--  Справа — меню-пульт: камеры/люди, выдача ХП/брони/стволов
--  EFT, маяк цели, сигнал орлам, двери (ЛКМ откр/закр,
--  ПКМ — блок/разблок). Калечить поле ввода нечему:
--  вся клава идёт через PlayerButtonDown (тот же контур,
--  что спас чат «СВЯЗЬ»).
-- ============================================================

P11DSP = P11DSP or {}
local D = P11DSP
D.active   = D.active   or false
D.mode     = D.mode     or "cam"  -- "cam" | "ply"
D.sel      = D.sel      or 1
D.doors    = D.doors    or {}
D.cams     = {}
D.camListT = 0
D.pcount   = 0

-- зеркало каталога сервера (p11_sv_dispatch CATALOG — тот же порядок!)
D.weapons = { "MP5A3", "UMP-45", "M4A1", "M1A", "SA-58", "M700", "Rem 870", "M1911A1" }

local cvDbg = CreateConVar("p11_dspdebug", "0", FCVAR_ARCHIVE) -- v4.19.2 «ШЛЮЗ»: HUD-датчик сеанса/клавы

surface.CreateFont("P11.Dsp.Title", { font = "Roboto", size = 19, weight = 800, extended = true })
surface.CreateFont("P11.Dsp.Row",   { font = "Roboto", size = 15, weight = 600, extended = true })
surface.CreateFont("P11.Dsp.Small", { font = "Roboto", size = 13, weight = 600, extended = true })
surface.CreateFont("P11.Dsp.Feed",  { font = "Arial",  size = 34, weight = 900, extended = true })

-- ============ СПИСКИ ============

function D.Cams()
    if CurTime() < D.camListT then return D.cams end
    local t = ents.FindByClass("polus11_seccam")
    table.sort(t, function(a, b) return a:EntIndex() < b:EntIndex() end)
    D.cams = t
    D.camListT = CurTime() + 2
    return t
end

local function PList()
    local t = {}
    for _, p in ipairs(player.GetAll()) do
        if p ~= LocalPlayer() and IsValid(p) then t[#t + 1] = p end
    end
    table.sort(t, function(a, b) return a:Nick() < b:Nick() end)
    return t
end

local function SelEntity()
    if D.mode == "cam" then
        local cams = D.Cams()
        if #cams == 0 then return nil end
        D.sel = math.Clamp(D.sel, 1, #cams)
        return cams[D.sel]
    else
        local pls = PList()
        if #pls == 0 then return nil end
        D.sel = math.Clamp(D.sel, 1, #pls)
        return pls[D.sel]
    end
end

-- ============ ОТПРАВКА ============

local function Send0(op)
    net.Start("P11_Dsp") net.WriteUInt(op, 4) net.SendToServer()
end
local function SendT(op, ent) -- op + цель-игрок
    if not IsValid(ent) then return end
    net.Start("P11_Dsp")
        net.WriteUInt(op, 4)
        net.WriteUInt(ent:EntIndex(), 16)
    net.SendToServer()
end
local function SendW(op, ent, wi)
    if not IsValid(ent) then return end
    net.Start("P11_Dsp")
        net.WriteUInt(op, 4)
        net.WriteUInt(ent:EntIndex(), 16)
        net.WriteUInt(wi, 8)
    net.SendToServer()
end
local function SendD(op, di)
    net.Start("P11_Dsp")
        net.WriteUInt(op, 4)
        net.WriteUInt(di, 16)
    net.SendToServer()
end

-- ============ ПРИЁМ ============

net.Receive("P11_Dsp", function()
    local op = net.ReadUInt(4)
    if op == 1 then
        -- v4.19.2 «ШЛЮЗ»: подъём под pcall — тихая ошибка больше НЕ
        -- висит скрытно с мороженым телом: рвём сеанс обратно
        local ok, err = pcall(D.Open)
        if not ok then
            print("[ГЛАЗ][ERROR] пульт не поднялся: " .. tostring(err))
            chat.AddText(Color(255, 120, 110), "[ГЛАЗ] пульт дал ошибку — сеанс сорван (смотри клиентскую консоль).")
            Send0(1)
        else
            Send0(9) -- READY-рукопожатие: пульт жив
        end
    elseif op == 2 then
        local why = net.ReadString()
        D.Close()
        if why and why ~= "" then
            chat.AddText(Color(150, 190, 255), "[ГЛАЗ] " .. why)
        end
    elseif op == 3 then
        local msg = net.ReadString()
        chat.AddText(Color(150, 190, 255), "[ГЛАЗ] " .. msg)
        surface.PlaySound("buttons/button17.wav")
    elseif op == 4 then
        local n = net.ReadUInt(16)
        local list = {}
        for i = 1, n do
            local nm  = net.ReadString()
            local lck = net.ReadBool()
            local opn = net.ReadBool()
            list[i] = { name = nm, locked = lck, open = opn }
        end
        D.doors = list
        if D.RebuildPanel then D.RebuildPanel() end
    end
end)

-- ============ ВИД (камеры / 3-е лицо за игроком) ============

hook.Add("CalcView", "P11.DspView", function(ply, pos, ang, fov)
    if not D.active then return end
    if D.mode == "cam" then
        local c = SelEntity()
        if IsValid(c) then
            local ca = c:GetAngles()
            return {
                origin = c:GetPos() + ca:Forward() * 2,
                angles = ca,
                fov = fov,
                drawviewer = true,
            }
        end
    else
        local t = SelEntity()
        if IsValid(t) then
            local tang = t:EyeAngles()
            local head = t:EyePos()
            local back = head - tang:Forward() * 110 + Vector(0, 0, 16)
            local tr = util.TraceLine({
                start  = head,
                endpos = back,
                filter = t,
                mask   = MASK_SOLID_BRUSHONLY,
            })
            return {
                origin = tr.HitPos,
                angles = tang,
                fov = fov,
                drawviewer = true,
            }
        end
    end
end)

hook.Add("PreDrawViewModel", "P11.DspNoVM", function()
    if D.active then return true end
end)
hook.Add("PreDrawPlayerHands", "P11.DspNoHands", function()
    if D.active then return true end
end)

-- ============ КЛАВА (тот же железный контур, что и чат) ============

local nextKey = 0
hook.Add("PlayerButtonDown", "P11.DspKeys", function(ply, key)
    if not D.active then return end
    if ply ~= LocalPlayer() then return end
    if CurTime() < nextKey then return end

    if key == KEY_E or key == KEY_ESCAPE then -- v4.19.2 «ШЛЮЗ»: ESC тоже выводит из пульта
        nextKey = CurTime() + 0.3
        if cvDbg:GetBool() then print("[ГЛАЗ→] выход: клавиша " .. key) end
        Send0(1)
        D.Close()
    elseif key == KEY_SPACE then
        nextKey = CurTime() + 0.25
        D.mode = (D.mode == "cam") and "ply" or "cam"
        D.sel = 1
        surface.PlaySound("buttons/blip1.wav")
        if D.RebuildPanel then D.RebuildPanel() end
    elseif key == KEY_A or key == KEY_LEFT then
        nextKey = CurTime() + 0.18
        local n = (D.mode == "cam") and #D.Cams() or #PList()
        if n > 0 then
            D.sel = ((D.sel - 2) % n) + 1
            surface.PlaySound("buttons/button9.wav")
            if D.RebuildPanel then D.RebuildPanel() end
        end
    elseif key == KEY_D or key == KEY_RIGHT then
        nextKey = CurTime() + 0.18
        local n = (D.mode == "cam") and #D.Cams() or #PList()
        if n > 0 then
            D.sel = (D.sel % n) + 1
            surface.PlaySound("buttons/button9.wav")
            if D.RebuildPanel then D.RebuildPanel() end
        end
    end
end)

-- ============ МЕНЮ-ПУЛЬТ (справа) ============

local COL = {
    bg    = Color(12, 16, 22, 235),
    edge  = Color(120, 165, 235),
    head  = Color(140, 175, 230),
    row   = Color(26, 34, 46, 200),
    rowHi = Color(52, 72, 100, 220),
    cur   = Color(75, 110, 160, 230),
    txt   = Color(200, 215, 240),
    dim   = Color(120, 135, 160),
    good  = Color(140, 225, 150),
    bad   = Color(255, 120, 110),
    gold  = Color(235, 205, 120),
}

function D.BuildPanel()
    if IsValid(D.frame) then D.frame:Remove() end

    local w, h = 360, math.min(ScrH() - 120, 700)
    local f = vgui.Create("DFrame")
    f:SetSize(w, h)
    f:SetPos(ScrW() - w - 40, (ScrH() - h) / 2)
    f:SetTitle("")
    f:SetDraggable(true)
    f:ShowCloseButton(false)
    f:SetDeleteOnClose(true)
    f:SetSizable(false)
    f:MakePopup()
    f:SetKeyboardInputEnabled(false) -- клава — игре (A/D/SPACE/E доходят всегда)

    f.Paint = function(s, pw, ph)
        draw.RoundedBox(4, 0, 0, pw, ph, COL.bg)
        surface.SetDrawColor(COL.edge)
        surface.DrawOutlinedRect(0, 0, pw, ph, 1)
        draw.SimpleText("ПУЛЬТ ДИСПЕТЧЕРА «ГЛАЗ»", "P11.Dsp.Title",
            pw / 2, 16, Color(160, 195, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("КАНАЛ ЦЕНТРА • НЕ ДЛЯ ГАРНИЗОНА", "P11.Dsp.Small",
            pw / 2, 36, COL.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local sc = vgui.Create("DScrollPanel", f)
    sc:SetPos(6, 48)
    sc:SetSize(w - 12, h - 54)
    sc:GetVBar():SetWide(5)
    D.scroll = sc
end

function D.RebuildPanel()
    if not D.active then return end
    if not IsValid(D.scroll) then return end
    local cv = D.scroll
    cv:Clear()

    local function Head(txt)
        local l = cv:Add("DPanel")
        l:Dock(TOP) l:SetTall(22) l:DockMargin(2, 8, 2, 0)
        l.Paint = function(s, pw, ph)
            draw.SimpleText(txt, "P11.Dsp.Row", 6, ph / 2, COL.head, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    local function Row(txt, fn, col, rc)
        local b = cv:Add("DButton")
        b:Dock(TOP) b:SetTall(30) b:DockMargin(2, 2, 2, 0)
        b:SetText("")
        b.Paint = function(s, pw, ph)
            draw.RoundedBox(3, 0, 0, pw, ph, s:IsHovered() and COL.rowHi or COL.row)
            draw.SimpleText(txt, "P11.Dsp.Row", 8, ph / 2, col or COL.txt, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function()
            surface.PlaySound("buttons/lightswitch2.wav")
            fn()
        end
        if rc then
            b.DoRightClick = function()
                surface.PlaySound("buttons/button9.wav")
                rc()
            end
        end
        return b
    end

    -- ===== РЕЖИМ =====
    Head("РЕЖИМ (SPACE — переключить, A/D — по списку):")
    Row((D.mode == "cam" and "▶ " or "   ") .. "📷 КАМЕРЫ СЕТИ «ГЛАЗ» (" .. #D.Cams() .. ")",
        function() D.mode = "cam" D.sel = 1 D.RebuildPanel() end,
        D.mode == "cam" and COL.gold or COL.txt)
    Row((D.mode == "ply" and "▶ " or "   ") .. "👁 ЛЮДИ СТАНЦИИ — вид от 3-го лица (" .. #PList() .. ")",
        function() D.mode = "ply" D.sel = 1 D.RebuildPanel() end,
        D.mode == "ply" and COL.gold or COL.txt)

    -- ===== СПИСОК КАНАЛОВ =====
    if D.mode == "cam" then
        Head("КАМЕРЫ:")
        local cams = D.Cams()
        if #cams == 0 then
            Row("СЕТЬ ПУСТА — расставь 📍 «Камеру «ГЛАЗ»»", function() end, COL.dim)
        end
        for i, c in ipairs(cams) do
            local d = IsValid(c) and math.floor(c:GetPos():Distance(LocalPlayer():GetPos())) or 0
            local me = (i == D.sel)
            Row((me and "▶ " or "   ") .. "ГЛАЗ #" .. i .. "  (" .. d .. "u)",
                function() D.sel = i D.RebuildPanel() end,
                me and COL.gold or COL.txt)
        end
    else
        Head("ЛЮДИ:")
        local pls = PList()
        if #pls == 0 then Row("НИКОГО В ПОЛЕ ЗРЕНИЯ", function() end, COL.dim) end
        for i, p in ipairs(pls) do
            if IsValid(p) then
                local jn = (P11FW and P11FW.GetJobName and P11FW.GetJobName(p)) or ""
                local me = (i == D.sel)
                Row((me and "▶ " or "   ") .. p:Nick() .. "  —  " .. jn ..
                    "  [" .. p:Health() .. "➕/" .. p:Armor() .. "🛡]",
                    function() D.sel = i D.RebuildPanel() end,
                    me and COL.gold or COL.txt)
            end
        end
    end

    -- ===== ПОДДЕРЖКА ЦЕЛИ (только в режиме людей) =====
    if D.mode == "ply" then
        local t = SelEntity()
        Head("ПОДДЕРЖКА ЦЕНТРА — «" .. (IsValid(t) and t:Nick() or "нет цели") .. "»:")
        if IsValid(t) then
            local tt = t
            Row("➕ +25 ХП  (кд 30с)",           function() SendT(2, tt) end, COL.good)
            Row("🛡 +50 БРОНИ  (кд 30с)",        function() SendT(3, tt) end, COL.good)
            Head("АРСЕНАЛ ЦЕНТРА (EFT, кд 60с):")
            for wi, wn in ipairs(D.weapons) do
                Row("🔫 " .. wn, function() SendW(4, tt, wi) end)
            end
            Head("ПОЛЕВЫЕ ПРИКОЛЫ:")
            Row("📍 МАЯК ЦЕЛИ — 60 сек, видят орлы", function() SendT(5, tt) end, COL.gold)
        end
    end

    -- ===== ЭФИР =====
    Head("ЭФИР:")
    Row("📡 СИГНАЛ ВСЕМ ОРЛАМ  (кд 20с)", function() Send0(6) end, COL.gold)

    -- ===== ДВЕРИ =====
    Head("ДВЕРИ СТАНЦИИ (" .. #D.doors .. ") — ЛКМ: откр/закр • ПКМ: БЛОК:")
    for i, dr in ipairs(D.doors) do
        local st = (dr.locked and "🔒 БЛОК" or "🔓 свободна") .. " • " .. (dr.open and "открыта" or "закрыта")
        Row((dr.name or ("ДВЕРЬ #" .. i)) .. "   [" .. st .. "]",
            function() SendD(8, i) end,
            dr.locked and COL.bad or COL.txt,
            function() SendD(7, i) end)
    end

    -- ===== ВЫХОД =====
    Head("")
    Row("✕ ВЫЙТИ ИЗ ТЕРМИНАЛА  (или клавиша E)", function()
        Send0(1)
        D.Close()
    end, COL.bad)
end

-- ============ ОТКРЫТИЕ / ЗАКРЫТИЕ ============

function D.Open()
    D.active = true
    D.mode = "cam"
    D.sel = 1
    if P11 and P11.ThirdPerson ~= nil then P11.ThirdPerson = false end -- вид пульта важнее F2
    D.BuildPanel()
    D.RebuildPanel()
    surface.PlaySound("ambient/energy/zap9.wav")
end

function D.Close()
    D.active = false
    if IsValid(D.frame) then D.frame:Remove() end
    D.frame = nil
    D.scroll = nil
end

-- живой показ списка людей: если состав поменялся — мягкий ребилд
timer.Create("P11.DspPanelLive", 3, 0, function()
    if not D.active then return end
    local n = #PList()
    if n ~= D.pcount then
        D.pcount = n
        D.RebuildPanel()
    end
end)

-- ============ HUD КАДРА ЭФИРА + МАЯК ЦЕЛИ ============

local function MarkerForMe()
    local me = LocalPlayer()
    if not IsValid(me) then return false end
    if P11FW and P11FW.GetJob then
        local j = P11FW.GetJob(me)
        local f = istable(j) and (j.faction or j.category) or nil
        if f == "eagle" then return true end
    end
    return P11FW and P11FW.GetRankLevel and P11FW.GetRankLevel(me) >= 4
end

hook.Add("HUDPaint", "P11.DspHUD", function()
    if D.active then
        local w = ScrW()

        -- рамка эфира
        surface.SetDrawColor(120, 165, 235, 130)
        surface.DrawOutlinedRect(6, 6, w - 12, ScrH() - 12, 1)

        local title, sub
        if D.mode == "cam" then
            local n = #D.Cams()
            if n > 0 then
                title = "ГЛАЗ #" .. D.sel .. "   (" .. D.sel .. "/" .. n .. ")"
                sub   = "[A/D] переключение камер    [SPACE] — люди    [E] — выход    пульт — справа"
            else
                title = "СЕТЬ КАМЕР ПУСТА"
                sub   = "расставь 📍 «Камера «ГЛАЗ»» (роль cam)    [SPACE] — люди    [E] — выход"
            end
        else
            local t = SelEntity()
            if IsValid(t) then
                local jn = (P11FW and P11FW.GetJobName and P11FW.GetJobName(t)) or ""
                title = "👁 " .. t:Nick() .. "   —   " .. jn
                sub   = "ХП " .. t:Health() .. "   БРОНЯ " .. t:Armor() ..
                        "    [A/D] — следующий    [SPACE] — камеры    [E] — выход"
            else
                title = "НИКОГО В ПОЛЕ ЗРЕНИЯ"
                sub   = "[SPACE] — камеры    [E] — выход"
            end
        end

        draw.SimpleText(title, "P11.Dsp.Feed", 42, 58, Color(150, 195, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(sub, "P11.Dsp.Row", 44, 58 + 42, Color(170, 185, 205), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        local a = 120 + math.abs(math.sin(CurTime() * 3)) * 135
        draw.SimpleText("■ REC • ЦЕНТР", "P11.Dsp.Row", w - 30, 24,
            Color(255, 90, 80, a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    -- 📍 маяк цели: горит у орлов (и у админа) поверх любой маскировки.
    -- Отсчёт секунд — от ЛОКАЛЬНОГО засечки (серверный/клиентский
    -- CurTime могут расходиться), само окно — 60 сек реального времени.
    if MarkerForMe() then
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and p:Alive() and p ~= LocalPlayer() then
                local till = p:GetNWFloat("P11_DspMark", 0)
                if till > (p.P11_DspPrevMark or 0) then
                    p.P11_DspPrevMark = till
                    p.P11_DspSeenAt   = CurTime()  -- впервые увидели ЭТУ метку
                end
                if till > 0 and (CurTime() - (p.P11_DspSeenAt or 0)) < 62 then
                    local pos = (p:GetPos() + Vector(0, 0, 86)):ToScreen()
                    if pos.visible then
                        draw.SimpleText("🦅 ЦЕЛЬ ЦЕНТРА", "P11.Dsp.Row", pos.x, pos.y,
                            Color(130, 175, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                        draw.SimpleText(math.max(0, math.ceil(60 - (CurTime() - (p.P11_DspSeenAt or 0)))) .. "с",
                            "P11.Dsp.Small", pos.x, pos.y + 18,
                            Color(130, 175, 255, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                end
            end
        end
    end
end)

-- HUD-датчик сеанса (p11_dspdebug 1): видно, жив ли пульт и что шлём
hook.Add("HUDPaint", "P11.DspDebug", function()
    if not cvDbg:GetBool() then return end
    draw.SimpleText("ГЛАЗ-DEBUG: active=" .. tostring(D.active)
        .. " mode=" .. tostring(D.mode)
        .. " sel=" .. tostring(D.sel)
        .. " cams=" .. #D.Cams()
        .. " doors=" .. #D.doors,
        "P11.Dsp.Small", ScrW() / 2, ScrH() - 150,
        Color(140, 255, 160), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

print("[POLUS-11] «ГЛАЗ»: пульт диспетчера v4.19.2 «ШЛЮЗ» OK")
