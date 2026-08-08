-- ============================================================
--  ПОЛЮС-11 — «ГЛАЗ»: ПУЛЬТ ДИСПЕТЧЕРА (client) v4.20.1 «КЛАВИША»
--  Полный реворк по эталону владельца (кадры видео URF-полиции):
--   • статик-шум при каждом переключении
--   • крестовина W/A/S/D с именами каналов («Нет камеры» за краем)
--   • режим ЛЮДИ — круглый «бинокль» (iris-виньетка, клавиша V)
--   • белые иконки людей в мире
--   • слева карточка цели + действия 1–9 с ценами в ⚡ энергии
--   • нижний бар: батарея ⚡ (DrawBolt-полигон), чипы ALT+1/ALT+2,
--     красная «Выйти», подсказка про среднюю кнопку мыши
--   • средняя кнопка мыши — курсор и сайд-пульт (двери/маяк/эфир)
--  Клава — PlayerButtonDown (тот же контур, что спас чат «СВЯЗЬ»).
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
D.energy   = D.energy   or 100 -- батарея пульта (синк op10 от сервера)
D.noise    = 0                 -- статик-шум до этого CurTime
D.iris     = false             -- круглый «бинокль» в режиме людей
D.cursor   = false             -- средняя кнопка: курсор + сайд-пульт

-- зеркало CATALOG сервера (p11_sv_dispatch — тот же порядок 1..7!)
D.weapons = {
    { name = "M1911A1", cost = 15 },
    { name = "MP5A3",   cost = 20 },
    { name = "UMP-45",  cost = 25 },
    { name = "Rem 870", cost = 35 },
    { name = "M4A1",    cost = 45 },
    { name = "M1A",     cost = 55 },
    { name = "M700",    cost = 80 },
}

-- действия на цифрах 1..9 (шт. = цена в ⚡): 1–2 поддержка, 3–9 арсенал
D.Acts = {
    { name = "Подлечить +25 ХП",  cost = 50, op = 2 },
    { name = "Починить броню +50", cost = 60, op = 3 },
}
for wi, w in ipairs(D.weapons) do
    D.Acts[#D.Acts + 1] = { name = "Выдать " .. w.name, cost = w.cost, op = 4, wi = wi }
end

local cvDbg = CreateConVar("p11_dspdebug", "0", FCVAR_ARCHIVE) -- v4.19.2 «ШЛЮЗ»: HUD-датчик сеанса/клавы

-- v4.20.1 «КЛАВИША»: бинокль уехал с V (дефолтный ноклип!) на G (выбор
-- владельца); живой перебинд без новой версии: p11_dspkey_iris b / n / h …
local cvIrisKey = CreateClientConVar("p11_dspkey_iris", "g", true, false)

local function IrisKeyName() -- одна ПЕЧАТНАЯ буква, иначе дефолт G
    local k = string.upper(tostring(cvIrisKey:GetString() or "g"))
    k = string.gsub(k, "%s", "")
    if #k ~= 1 then k = "G" end
    return k
end
local function IrisKeyCode()
    local kc = input.GetKeyCode(IrisKeyName())
    if not kc or kc < 0 then return KEY_G end
    return kc
end

surface.CreateFont("P11.Dsp.Title", { font = "Roboto", size = 19, weight = 800, extended = true })
surface.CreateFont("P11.Dsp.Row",   { font = "Roboto", size = 15, weight = 600, extended = true })
surface.CreateFont("P11.Dsp.Small", { font = "Roboto", size = 13, weight = 600, extended = true })
surface.CreateFont("P11.Dsp.Mid",   { font = "Roboto", size = 17, weight = 700, extended = true })
surface.CreateFont("P11.Dsp.Big",   { font = "Roboto", size = 24, weight = 800, extended = true })
surface.CreateFont("P11.Dsp.Num",   { font = "Roboto", size = 15, weight = 900, extended = true })
surface.CreateFont("P11.Dsp.Feed",  { font = "Arial",  size = 34, weight = 900, extended = true })

-- ============ ПОМОЩНИКИ РИСОВАНИЯ ============

-- заполненный круг-полигон (для иконок людей и трафарета)
local function PolyCircle(x, y, r, seg)
    local pts = {}
    for i = 0, seg - 1 do
        local a = i / seg * math.pi * 2
        pts[#pts + 1] = { x = x + math.cos(a) * r, y = y + math.sin(a) * r }
    end
    return pts
end

-- белая иконка человека: голова-круг + тельце-трапеция
local function DrawPerson(x, y, s, a)
    s = s or 1 a = a or 220
    surface.SetDrawColor(255, 255, 255, a)
    draw.NoTexture()
    surface.DrawPoly(PolyCircle(x, y - 11 * s, 4.5 * s, 12))
    surface.DrawPoly({
        { x = x - 6 * s, y = y - 5 * s },
        { x = x + 6 * s, y = y - 5 * s },
        { x = x + 9 * s, y = y + 10 * s },
        { x = x - 9 * s, y = y + 10 * s },
    })
end

-- молния ⚡ полигоном (в кастомных шрифтах эмодзи не рисуем — правило проекта)
local function DrawBolt(x, y, w, h, col)
    surface.SetDrawColor(col or Color(255, 235, 120))
    draw.NoTexture()
    surface.DrawPoly({
        { x = x + w * 0.62, y = y },
        { x = x + w * 0.10, y = y + h * 0.58 },
        { x = x + w * 0.42, y = y + h * 0.58 },
        { x = x + w * 0.30, y = y + h },
        { x = x + w * 0.90, y = y + h * 0.38 },
        { x = x + w * 0.56, y = y + h * 0.38 },
    })
end

-- медкрест (белый) для карточки ХП
local function DrawCross(x, y, s, col)
    surface.SetDrawColor(col or Color(255, 255, 255, 230))
    surface.DrawRect(x - s * 0.3, y - s, s * 0.6, s * 2)
    surface.DrawRect(x - s, y - s * 0.3, s * 2, s * 0.6)
end

-- щит (полигон) для карточки брони
local function DrawShield(x, y, s, col)
    surface.SetDrawColor(col or Color(200, 220, 245, 230))
    draw.NoTexture()
    surface.DrawPoly({
        { x = x,      y = y - s },
        { x = x + s,  y = y - s * 0.55 },
        { x = x + s * 0.8, y = y + s * 0.45 },
        { x = x,      y = y + s },
        { x = x - s * 0.8, y = y + s * 0.45 },
        { x = x - s,  y = y - s * 0.55 },
    })
end

local function Short(t, n)
    t = tostring(t or "")
    if #t <= n then return t end
    return string.sub(t, 1, n - 1) .. "…"
end

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

local function SelCount()
    if D.mode == "cam" then return #D.Cams() end
    return #PList()
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

-- имя слота крестовины (за краем: камеры — «Нет камеры», люди — «—»)
local function SlotName(i)
    if D.mode == "cam" then
        local cams = D.Cams()
        if i >= 1 and i <= #cams and IsValid(cams[i]) then return "ГЛАЗ #" .. i end
        return "Нет камеры"
    else
        local pls = PList()
        if i >= 1 and i <= #pls and IsValid(pls[i]) then return Short(pls[i]:Nick(), 18) end
        return "—"
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
        if D.RebuildPanel and D.cursor then D.RebuildPanel() end
    elseif op == 10 then -- v4.20.0 «ПОСТ»: синк батареи ⚡
        D.energy = net.ReadUInt(8) or 100
        if D.RebuildPanel and D.cursor then D.RebuildPanel() end
    end
end)

-- ============ ДЕЙСТВИЯ (цифры 1..9) ============

local function DoAction(n)
    if D.mode ~= "ply" then return end
    local a = D.Acts[n]
    if not a then return end
    local t = SelEntity()
    if not IsValid(t) then
        surface.PlaySound("buttons/button10.wav")
        return
    end
    if (D.energy or 100) < a.cost then
        surface.PlaySound("buttons/button10.wav") -- мало ⚡: сервер тоже страхует
        return
    end
    if a.op == 4 then SendW(4, t, a.wi) else SendT(a.op, t) end
    surface.PlaySound("buttons/button15.wav")
end

-- ============ ШУМ / РЕЖИМЫ / ШАГИ ============

function D.Zap() -- статик-шум на каждое переключение (эталон)
    D.noise = CurTime() + 0.5
    surface.PlaySound("buttons/blip1.wav")
end

function D.SetMode(m)
    if D.mode == m then return end
    D.mode = m
    D.sel = 1
    D.Zap()
    if D.RebuildPanel and D.cursor then D.RebuildPanel() end
end

function D.SetIris(on)
    on = on and true or false
    if D.iris == on then return end
    D.iris = on
    D.Zap()
end

function D.Step(d)
    local n = SelCount()
    local old = D.sel
    if n <= 0 then
        D.sel = 1
    else
        D.sel = math.Clamp(D.sel + d, 1, n) -- НЕ wrap: за краем слот «Нет камеры»
    end
    if D.sel ~= old or n <= 0 then
        D.Zap()
        if D.RebuildPanel and D.cursor then D.RebuildPanel() end
    end
end

-- ============ КЛАВА (железный контур чата) ============

local nextKey = 0
hook.Add("PlayerButtonDown", "P11.DspKeys", function(ply, key)
    if not D.active then return end
    if ply ~= LocalPlayer() then return end
    if CurTime() < nextKey then return end

    if key == KEY_E or key == KEY_ESCAPE then -- v4.19.2 «ШЛЮЗ»: ESC тоже выводит
        nextKey = CurTime() + 0.3
        if cvDbg:GetBool() then print("[ГЛАЗ→] выход: клавиша " .. key) end
        Send0(1)
        D.Close()
    elseif key == KEY_SPACE then
        nextKey = CurTime() + 0.25
        D.SetMode(D.mode == "cam" and "ply" or "cam")
    elseif key == IrisKeyCode() then -- «Сменить вид»: бинокль вкл/выкл (v4.20.1: G, был V = ноклип)
        nextKey = CurTime() + 0.2
        D.SetIris(not D.iris)
    elseif key == MOUSE_MIDDLE then -- курсор + сайд-пульт (текстовых полей нет — безопасно)
        nextKey = CurTime() + 0.2
        D.SetCursor(not D.cursor)
    elseif key == KEY_A or key == KEY_LEFT then
        nextKey = CurTime() + 0.15
        D.Step(-1)
    elseif key == KEY_D or key == KEY_RIGHT then
        nextKey = CurTime() + 0.15
        D.Step(1)
    elseif key == KEY_W or key == KEY_UP then
        nextKey = CurTime() + 0.15
        D.Step(-3)
    elseif key == KEY_S or key == KEY_DOWN then
        nextKey = CurTime() + 0.15
        D.Step(3)
    elseif key >= KEY_1 and key <= KEY_9 then
        local n = key - 1 -- KEY_1=2 … KEY_9=10 → n=1..9
        if input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT) then
            nextKey = CurTime() + 0.2
            if n == 1 then D.SetMode("cam")
            elseif n == 2 then D.SetMode("ply") end
        else
            nextKey = CurTime() + 0.25
            DoAction(n)
        end
    end
end)

-- ============ САЙД-ПУЛЬТ (по средней кнопке; по умолчанию скрыт) ============

local COL = {
    bg    = Color(12, 16, 22, 235),
    edge  = Color(120, 165, 235),
    head  = Color(140, 175, 230),
    row   = Color(26, 34, 46, 200),
    rowHi = Color(52, 72, 100, 220),
    txt   = Color(200, 215, 240),
    dim   = Color(120, 135, 160),
    good  = Color(140, 225, 150),
    bad   = Color(255, 120, 110),
    gold  = Color(235, 205, 120),
}

function D.SetCursor(on)
    on = on and true or false
    D.cursor = on
    if IsValid(D.frame) then
        if on then
            D.frame:SetVisible(true)
            D.frame:MakePopup()
            D.frame:SetKeyboardInputEnabled(false) -- клава остаётся игре
            D.RebuildPanel()
        else
            D.frame:SetVisible(false)
            D.frame:SetMouseInputEnabled(false)
            D.frame:SetKeyboardInputEnabled(false)
        end
    end
    gui.EnableScreenClicker(on)
end

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
    f:SetMouseInputEnabled(false)    -- v4.20.0 «ПОСТ»: пульт СКРЫТ,
    f:SetKeyboardInputEnabled(false) -- пока не нажали среднюю кнопку
    f:SetVisible(false)

    f.Paint = function(s, pw, ph)
        draw.RoundedBox(4, 0, 0, pw, ph, COL.bg)
        surface.SetDrawColor(COL.edge)
        surface.DrawOutlinedRect(0, 0, pw, ph, 1)
        draw.SimpleText("ПУЛЬТ ДИСПЕТЧЕРА «ГЛАЗ»", "P11.Dsp.Title",
            pw / 2, 16, Color(160, 195, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("КАНАЛ ЦЕНТРА • БАТАРЕЯ " .. math.floor(D.energy or 100) .. "% • скрыть/показать — средняя кнопка", "P11.Dsp.Small",
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
    Head("РЕЖИМ (SPACE или чипы ALT+1/ALT+2):")
    Row((D.mode == "cam" and "▶ " or "   ") .. "📷 КАМЕРЫ СЕТИ «ГЛАЗ» (" .. #D.Cams() .. ")",
        function() D.SetMode("cam") end,
        D.mode == "cam" and COL.gold or COL.txt)
    Row((D.mode == "ply" and "▶ " or "   ") .. "👁 ЛЮДИ СТАНЦИИ — вид от 3-го лица (" .. #PList() .. ")",
        function() D.SetMode("ply") end,
        D.mode == "ply" and COL.gold or COL.txt)

    -- ===== СПИСОК КАНАЛОВ =====
    if D.mode == "cam" then
        Head("КАМЕРЫ (A/D шаг, W/S прыжок ×3):")
        local cams = D.Cams()
        if #cams == 0 then
            Row("СЕТЬ ПУСТА — расставь 📍 «Камеру «ГЛАЗ»»", function() end, COL.dim)
        end
        for i, c in ipairs(cams) do
            local me = (i == D.sel)
            Row((me and "▶ " or "   ") .. "ГЛАЗ #" .. i,
                function() D.sel = i D.Zap() D.RebuildPanel() end,
                me and COL.gold or COL.txt)
        end
    else
        Head("ЛЮДИ (A/D шаг, W/S прыжок ×3, " .. IrisKeyName() .. " — бинокль):")
        local pls = PList()
        if #pls == 0 then Row("НИКОГО В ПОЛЕ ЗРЕНИЯ", function() end, COL.dim) end
        for i, p in ipairs(pls) do
            if IsValid(p) then
                local jn = (P11FW and P11FW.GetJobName and P11FW.GetJobName(p)) or ""
                local me = (i == D.sel)
                Row((me and "▶ " or "   ") .. p:Nick() .. "  —  " .. jn ..
                    "  [" .. p:Health() .. "/" .. p:Armor() .. "]",
                    function() D.sel = i D.Zap() D.RebuildPanel() end,
                    me and COL.gold or COL.txt)
            end
        end
    end

    -- ===== ДЕЙСТВИЯ (цифры 1..9, цены в ⚡ энергии) =====
    if D.mode == "ply" then
        local t = SelEntity()
        Head("ДЕЙСТВИЯ 1–9 — цель «" .. (IsValid(t) and t:Nick() or "нет") .. "», батарея " .. math.floor(D.energy or 100) .. "%:")
        if IsValid(t) then
            local tt = t
            for n, a in ipairs(D.Acts) do
                local afford = (D.energy or 100) >= a.cost
                Row("  " .. n .. ".  " .. a.name .. "   (−" .. a.cost .. " эн.)",
                    function() DoAction(n) end,
                    afford and (n <= 2 and COL.good or COL.txt) or COL.dim)
            end
            Head("ПОЛЕВЫЕ ПРИКОЛЫ:")
            local affordMark = (D.energy or 100) >= 20
            Row("📍 МАЯК ЦЕЛИ — 60 сек, видят орлы  (−20 эн.)",
                function() if affordMark then SendT(5, tt) else surface.PlaySound("buttons/button10.wav") end end,
                affordMark and COL.gold or COL.dim)
            Row("👁 СМЕНИТЬ ВИД — бинокль (" .. IrisKeyName() .. ")", function() D.SetIris(not D.iris) end,
                D.iris and COL.gold or COL.txt)
        end
    end

    -- ===== ЭФИР =====
    Head("ЭФИР:")
    local affordSig = (D.energy or 100) >= 10
    Row("📡 СИГНАЛ ВСЕМ ОРЛАМ  (−10 эн.)",
        function() if affordSig then Send0(6) else surface.PlaySound("buttons/button10.wav") end end,
        affordSig and COL.gold or COL.dim)

    -- ===== ДВЕРИ =====
    Head("ДВЕРИ СТАНЦИИ (" .. #D.doors .. ") — ЛКМ: откр/закр • ПКМ: БЛОК (бесплатно):")
    for i, dr in ipairs(D.doors) do
        local st = (dr.locked and "🔒 БЛОК" or "🔓 свободна") .. " • " .. (dr.open and "открыта" or "закрыта")
        Row((dr.name or ("ДВЕРЬ #" .. i)) .. "   [" .. st .. "]",
            function() SendD(8, i) end,
            dr.locked and COL.bad or COL.txt,
            function() SendD(7, i) end)
    end

    -- ===== ВЫХОД =====
    Head("")
    Row("✕ ВЫЙТИ ИЗ ТЕРМИНАЛА  (или E / ESC)", function()
        Send0(1)
        D.Close()
    end, COL.bad)
end

-- ============ ОТКРЫТИЕ / ЗАКРЫТИЕ ============

function D.Open()
    D.active = true
    D.mode = "cam"
    D.sel = 1
    D.iris = false
    D.cursor = false
    D.energy = 100 -- до первого op10; сервер шлёт сразу после OPEN
    if P11 and P11.ThirdPerson ~= nil then P11.ThirdPerson = false end -- вид пульта важнее F2
    D.BuildPanel()
    D.Zap() -- вход в эфир — со статик-шумом (эталон)
    surface.PlaySound("ambient/energy/zap9.wav")
end

function D.Close()
    D.active = false
    D.cursor = false
    gui.EnableScreenClicker(false) -- средняя кнопка могла оставить курсор
    if IsValid(D.frame) then D.frame:Remove() end
    D.frame = nil
    D.scroll = nil
end

-- живой показ списка людей в сайд-пульте (только когда он открыт)
timer.Create("P11.DspPanelLive", 3, 0, function()
    if not D.active or not D.cursor then return end
    local n = #PList()
    if n ~= D.pcount then
        D.pcount = n
        D.RebuildPanel()
    end
end)

-- ============ ВИД (камеры / 3-е лицо; бинокль = fov 28) ============

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
                fov = D.iris and 28 or fov, -- бинокль Центра
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

-- ============ HUD: КАДР ЭФИРА (эталон владельца) ============

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

local staticSeed = 0

hook.Add("HUDPaint", "P11.DspHUD", function()
    local me = LocalPlayer()

    if D.active then
        local w, h = ScrW(), ScrH()
        local cx = w / 2
        local cy = h * 0.66

        -- бинокль: трафарет-круг, вокруг — тьма
        if D.mode == "ply" and D.iris then
            local r = math.min(w, h) * 0.42
            render.ClearStencil()
            render.SetStencilEnable(true)
            render.SetStencilWriteMask(255)
            render.SetStencilTestMask(255)
            render.SetStencilReferenceValue(1)
            render.SetStencilCompareFunction(STENCIL_ALWAYS)
            render.SetStencilPassOperation(STENCIL_REPLACE)
            render.SetStencilFailOperation(STENCIL_KEEP)
            render.SetStencilZFailOperation(STENCIL_KEEP)
            surface.SetDrawColor(255, 255, 255, 255)
            draw.NoTexture()
            surface.DrawPoly(PolyCircle(w / 2, h / 2, r, 64))
            render.SetStencilCompareFunction(STENCIL_NOTEQUAL)
            render.SetStencilPassOperation(STENCIL_KEEP)
            surface.SetDrawColor(0, 0, 0, 238)
            surface.DrawRect(0, 0, w, h)
            render.SetStencilEnable(false)
            -- кольцо-обводка
            surface.SetDrawColor(0, 0, 0, 255)
            draw.NoTexture()
            local segs = 64
            for i = 0, segs - 1 do
                local a1 = i / segs * math.pi * 2
                local a2 = (i + 1) / segs * math.pi * 2
                surface.DrawPoly({
                    { x = w / 2 + math.cos(a1) * (r + 3), y = h / 2 + math.sin(a1) * (r + 3) },
                    { x = w / 2 + math.cos(a1) * r,       y = h / 2 + math.sin(a1) * r },
                    { x = w / 2 + math.cos(a2) * r,       y = h / 2 + math.sin(a2) * r },
                    { x = w / 2 + math.cos(a2) * (r + 3), y = h / 2 + math.sin(a2) * (r + 3) },
                })
            end
        end

        -- рамка эфира
        surface.SetDrawColor(120, 165, 235, 130)
        surface.DrawOutlinedRect(6, 6, w - 12, h - 12, 1)

        local a = 120 + math.abs(math.sin(CurTime() * 3)) * 135
        draw.SimpleText("■ REC • ЦЕНТР", "P11.Dsp.Row", w - 30, 24,
            Color(255, 90, 80, a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

        -- статик-шум при переключении (~400 случайных чёрточек)
        if CurTime() < D.noise then
            staticSeed = staticSeed + 1
            math.randomseed(staticSeed * 7919)
            for i = 1, 400 do
                local nx = math.random(0, w)
                local ny = math.random(0, h)
                local g = math.random(70, 200)
                surface.SetDrawColor(g, g, g, math.random(40, 130))
                surface.DrawRect(nx, ny, 2, 2)
            end
        end

        -- белые иконки людей в мире (кроме себя и текущей цели)
        local cur = SelEntity()
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and p:Alive() and p ~= me and p ~= cur then
                local pos = (p:GetPos() + Vector(0, 0, 52)):ToScreen()
                if pos.visible then
                    DrawPerson(pos.x, pos.y, 0.9, 200)
                end
            end
        end

        -- крестовина W/A/S/D с именами каналов
        local n = SelCount()
        draw.SimpleText(SlotName(D.sel), "P11.Dsp.Big", cx, cy - 58,
            Color(235, 205, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        -- центр-крестик
        surface.SetDrawColor(235, 205, 120, 220)
        surface.DrawRect(cx - 8, cy - 1, 16, 2)
        surface.DrawRect(cx - 1, cy - 8, 2, 16)
        local function Dir(dx, dy, key, slot)
            local nm = SlotName(slot)
            local bad = (D.mode == "cam" and nm == "Нет камеры") or (D.mode == "ply" and nm == "—")
            draw.SimpleText(key, "P11.Dsp.Num", cx + dx, cy + dy - 14,
                bad and Color(130, 140, 155, 160) or Color(255, 255, 255, 220),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(nm, "P11.Dsp.Small", cx + dx, cy + dy + 6,
                bad and Color(130, 140, 155, 150) or Color(210, 225, 245, 220),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        Dir(0,   -108, "W", D.sel - 3)
        Dir(-260, 0,   "A", D.sel - 1)
        Dir(260,  0,   "D", D.sel + 1)
        Dir(0,    88,  "S", D.sel + 3)

        -- пустая сеть / пустое поле
        if n <= 0 then
            draw.SimpleText(D.mode == "cam" and "СЕТЬ КАМЕР ПУСТА — расставь 📍 «Камеру «ГЛАЗ»»"
                or "НИКОГО В ПОЛЕ ЗРЕНИЯ", "P11.Dsp.Mid", cx, cy - 90,
                Color(255, 150, 140), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- ===== ЛЕВАЯ ПАНЕЛЬ (только режим людей) =====
        if D.mode == "ply" then
            local lx, ly = 20, math.floor(h * 0.22)
            local t = SelEntity()
            -- карточка цели
            draw.RoundedBox(4, lx, ly, 250, 86, Color(10, 14, 20, 190))
            -- аватар-заглушка: белый квадрат + силуэт
            surface.SetDrawColor(225, 232, 240, 235)
            surface.DrawRect(lx + 8, ly + 10, 64, 66)
            DrawPerson(lx + 40, ly + 48, 2.2, 160)
            if IsValid(t) then
                draw.SimpleText(Short(t:Nick(), 16), "P11.Dsp.Mid", lx + 82, ly + 12,
                    Color(240, 245, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                local jn = (P11FW and P11FW.GetJobName and P11FW.GetJobName(t)) or "—"
                draw.SimpleText("ЦЕНТР ✦ " .. Short(jn, 14), "P11.Dsp.Small", lx + 82, ly + 34,
                    Color(140, 165, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                DrawCross(lx + 92, ly + 64, 7)
                draw.SimpleText(tostring(t:Health()), "P11.Dsp.Mid", lx + 104, ly + 56,
                    Color(150, 235, 160), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                DrawShield(lx + 152, ly + 64, 8)
                draw.SimpleText(tostring(t:Armor()), "P11.Dsp.Mid", lx + 164, ly + 56,
                    Color(170, 200, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            else
                draw.SimpleText("ЦЕЛИ НЕТ", "P11.Dsp.Mid", lx + 82, ly + 30,
                    Color(255, 150, 140), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            ly = ly + 96

            -- действия 1..9 с ценами ⚡ (скобки-ряды эталона)
            for ni, act in ipairs(D.Acts) do
                local afford = (D.energy or 100) >= act.cost
                local rowA  = afford and 200 or 90
                draw.RoundedBox(3, lx, ly, 250, 24, Color(10, 14, 20, rowA))
                -- цифра в белом квадрате
                surface.SetDrawColor(afford and Color(235, 240, 245, 235) or Color(120, 128, 140, 160))
                surface.DrawRect(lx + 4, ly + 3, 18, 18)
                draw.SimpleText(tostring(ni), "P11.Dsp.Num", lx + 13, ly + 12,
                    Color(20, 26, 34), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText(act.name, "P11.Dsp.Row", lx + 30, ly + 12,
                    afford and Color(230, 238, 246) or Color(120, 130, 145),
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                DrawBolt(lx + 218, ly + 5, 10, 14,
                    afford and Color(130, 180, 255) or Color(90, 100, 120, 160))
                draw.SimpleText(tostring(act.cost), "P11.Dsp.Num", lx + 244, ly + 12,
                    afford and Color(130, 180, 255) or Color(90, 100, 120, 160),
                    TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                ly = ly + 27
            end
            draw.SimpleText("Сменить вид (" .. IrisKeyName() .. ")" .. (D.iris and "  —  БИНОКЛЬ ВКЛ" or ""),
                "P11.Dsp.Row", lx + 125, ly + 8,
                D.iris and Color(235, 205, 120) or Color(200, 215, 240),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            -- подсказка перебора цели
            draw.SimpleText("Предыдущая цель   [A]              [D]   Следующая цель",
                "P11.Dsp.Small", cx, h - 132,
                Color(190, 205, 225, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- ===== НИЖНИЙ БАР (батарея ⚡ / чипы / выход / курсор) =====
        local by = h - 86
        -- батарея (синяя)
        draw.RoundedBox(4, cx - 330, by, 150, 34, Color(30, 95, 200, 225))
        DrawBolt(cx - 320, by + 6, 16, 22, Color(255, 255, 255, 240))
        draw.SimpleText(math.floor(D.energy or 100) .. "%", "P11.Dsp.Big", cx - 192, by + 17,
            Color(255, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        -- чипы режимов ALT+1 / ALT+2
        local function Chip(x, hot, act2)
            local on = (hot == (D.mode == "cam" and 1 or 2))
            draw.RoundedBox(4, x, by, 62, 30,
                on and Color(225, 232, 240, 235) or Color(18, 24, 32, 210))
            draw.SimpleText("ALT+" .. hot, "P11.Dsp.Num", x + 31, by + 15,
                on and Color(20, 26, 34) or Color(190, 205, 225),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        Chip(cx - 150, 1)
        Chip(cx - 80, 2)
        draw.SimpleText(D.mode == "cam" and "Камеры" or "Игроки", "P11.Dsp.Mid",
            cx - 84, by + 44, Color(235, 205, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        -- выход (красная)
        draw.RoundedBox(4, cx + 30, by, 130, 34, Color(200, 45, 38, 225))
        draw.SimpleText("ВЫЙТИ  [E]", "P11.Dsp.Mid", cx + 95, by + 17,
            Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        -- подсказка курсора
        draw.SimpleText("[средняя кнопка] — " .. (D.cursor and "скрыть" or "показать") .. " курсор / пульт дверей",
            "P11.Dsp.Small", cx + 240, by + 17,
            Color(190, 205, 225, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- 📍 маяк цели: горит у орлов (и у админа) поверх любой маскировки.
    -- Отсчёт секунд — от ЛОКАЛЬНОГО засечки (серверный/клиентский
    -- CurTime могут расходиться), само окно — 60 сек реального времени.
    if MarkerForMe() then
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and p:Alive() and p ~= me then
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
        .. " doors=" .. #D.doors
        .. " energy=" .. tostring(D.energy)
        .. " iris=" .. tostring(D.iris)
        .. " cursor=" .. tostring(D.cursor),
        "P11.Dsp.Small", ScrW() / 2, ScrH() - 150,
        Color(140, 255, 160), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

print("[POLUS-11] «ГЛАЗ»: пульт диспетчера v4.20.1 «КЛАВИША» OK")
