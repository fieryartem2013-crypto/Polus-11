-- ============================================================
--  ПОЛЮС-11 — «ГЛАЗ»: ПУЛЬТ ДИСПЕТЧЕРА (client) v4.21.0 «КОПИЯ»
--  Заявка владельца: «сделай всё в точь-в-точь, прям копию, полная
--  копия по кадрам». Эталон снят с 67 кадров видео по пикселям:
--   • КРЕСТОВИНА камер: чипы 36×36 (A: cx−42..cx−6, D: cx+6..cx+42,
--     строка y≈0.68H), W/S в колонне A на ±104, имена на тёмных
--     плашках 36px вплотную к чипам, имя текущей камеры — бар-центр
--     над W («Нет камеры» — тускло); нажатое направление мигает
--     тёмным чипом (в кадрах эталона видно нажатие D)
--   • РЕЖИМ ЛЮДЕЙ: крестовины нет — строка «Предыдущая цель [A][D]
--     Следующая цель» на тех же чиповых местах (y≈0.735H)
--   • ЛЕВАЯ ПАНЕЛЬ x≈104: карточка (НАСТОЯЩИЙ Steam-аватар цели
--     через AvatarImage + меняется при смене цели; силуэт — запаска),
--     позывной, фракция/звание синим, ♥/щит цифрами; ряды 1–9:
--     белый чип 22×22 с чёрной цифрой, подпись, «молния+цена» синим
--     справа; «Сменить вид» под рядами по центру
--   • БИНОКЛЬ (клавиша из p11_dspkey_iris, дефолт G): круг r≈0.46H
--     стенсилом + зум, тёмное поле вокруг
--   • ШУМ: плотное зерно через 3 рендер-таргета 256² (4px зерно),
--     на весь экран, UI хром поверх — как в кадрах (#3/#22/#29)
--   • БАР снизу: батарея 200×52 (x=cx−299), чипы ALT+1/ALT+2 72×56
--     (активный режим — белый чип с чёрным глифом, пассив — тёмный),
--     подпись режима 24px под чипами, красный «Выйти» 127×36,
--     подсказка «🖱 — показать курсор» по центру
--   • ТОСТЫ справа над баром: тёмный бокс, оранжевый «i», оранжевая
--     полоса справа («Вы выдали оружие ВСС Винторез») — вешаются на
--     ответы ЦЕНТРА (op3) и локальные отказы
--   • белые иконки людей в мире + тусклый позывной над ними
--   • рамка-бордюр и «■ REC» УБРАНЫ — в эталоне их нет
--  Сохранено железо: READY-пожатие op9, pcall-броня, ESC через
--  OnPauseMenuShow, E/чат/p11_dspxit/p11_dspdebug, средняя кнопка —
--  курсор и сайд-пульт (двери/маяк/эфир — НАШИ допы заявки, у
--  эталона их нет, они за средней кнопкой).
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
D.toasts   = D.toasts   or {}  -- { { msg = "…", till = n } }
D.flashDir = nil               -- нажатое направление крестовины
D.flashTill = 0

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
    { name = "Подлечить +25 ХП",   cost = 50, op = 2 },
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

local function Short(t, n)
    t = tostring(t or "")
    if #t <= n then return t end
    return string.sub(t, 1, n - 1) .. "…"
end

-- v4.20.2 «БРОНЯ»: общий глушитель для pcall-обёрток хуков —
-- ошибка печатается раз в 5 сек, хук НЕ умирает молча
local lastGuiErr = 0
local function GuiFail(tag, err)
    if CurTime() < lastGuiErr then return end
    lastGuiErr = CurTime() + 5
    print("[ГЛАЗ][" .. tag .. "] " .. tostring(err))
    chat.AddText(Color(255, 120, 110), "[ГЛАЗ] ошибка " .. tag .. " — модуль жив, пришли строку из консоли:",
        Color(255, 255, 255), " " .. Short(tostring(err), 140))
end

-- ============ ШРИФТЫ (мерки эталона на 1080p) ============

surface.CreateFont("P11.Dsp.Chip",     { font = "Roboto", size = 22, weight = 800, extended = true }) -- буквы W/A/S/D в чипах
surface.CreateFont("P11.Dsp.Name",     { font = "Roboto", size = 20, weight = 700, extended = true }) -- имена камер на плашках
surface.CreateFont("P11.Dsp.Act",      { font = "Roboto", size = 16, weight = 600, extended = true }) -- ряды действий/подсказки
surface.CreateFont("P11.Dsp.Price",    { font = "Roboto", size = 15, weight = 800, extended = true })
surface.CreateFont("P11.Dsp.CardName", { font = "Roboto", size = 20, weight = 700, extended = true })
surface.CreateFont("P11.Dsp.CardFact", { font = "Roboto", size = 15, weight = 600, extended = true })
surface.CreateFont("P11.Dsp.Stat",     { font = "Roboto", size = 20, weight = 800, extended = true }) -- цифры ХП/брони
surface.CreateFont("P11.Dsp.Label",    { font = "Roboto", size = 24, weight = 800, extended = true }) -- «Камеры»/«Игроки»
surface.CreateFont("P11.Dsp.Batt",     { font = "Roboto", size = 26, weight = 800, extended = true }) -- «100%»
surface.CreateFont("P11.Dsp.ChipCap",  { font = "Roboto", size = 13, weight = 700, extended = true }) -- «ALT+1»
surface.CreateFont("P11.Dsp.Hint",     { font = "Roboto", size = 13, weight = 600, extended = true })
surface.CreateFont("P11.Dsp.Toast",    { font = "Roboto", size = 16, weight = 700, extended = true })
surface.CreateFont("P11.Dsp.Nick",     { font = "Roboto", size = 13, weight = 600, extended = true }) -- тусклый позывной над иконкой
-- наследие сайд-пульта и маяка орлов
surface.CreateFont("P11.Dsp.Title",    { font = "Roboto", size = 19, weight = 800, extended = true })
surface.CreateFont("P11.Dsp.Row",      { font = "Roboto", size = 15, weight = 600, extended = true })
surface.CreateFont("P11.Dsp.Small",    { font = "Roboto", size = 13, weight = 600, extended = true })

-- ============ ГЛИФЫ-ПОЛИГОНЫ (эмодзи в кастомных шрифтах не рисуем) ============

local function PolyCircle(x, y, r, seg)
    local pts = {}
    for i = 0, seg - 1 do
        local a = i / seg * math.pi * 2
        pts[#pts + 1] = { x = x + math.cos(a) * r, y = y + math.sin(a) * r }
    end
    return pts
end

-- белая иконка человека: голова-круг + плечи (как в кадрах мира)
local function DrawPerson(x, y, s, a, col)
    s = s or 1 a = a or 220
    col = col or Color(255, 255, 255, a)
    surface.SetDrawColor(col)
    draw.NoTexture()
    surface.DrawPoly(PolyCircle(x, y - 11 * s, 4.5 * s, 12))
    surface.DrawPoly({
        { x = x - 6 * s, y = y - 5 * s },
        { x = x + 6 * s, y = y - 5 * s },
        { x = x + 9 * s, y = y + 10 * s },
        { x = x - 9 * s, y = y + 10 * s },
    })
end

-- молния ⚡ (батарея и цены)
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

-- глиф видеокамеры (CCTV) для чипа ALT+1
local function DrawCamGlyph(x, y, s, col)
    surface.SetDrawColor(col)
    draw.NoTexture()
    surface.DrawRect(x, y + s * 0.28, s * 0.62, s * 0.42)           -- корпус
    surface.DrawPoly({                                                  -- объектив
        { x = x + s * 0.62, y = y + s * 0.34 },
        { x = x + s * 0.88, y = y + s * 0.24 },
        { x = x + s * 0.88, y = y + s * 0.74 },
        { x = x + s * 0.62, y = y + s * 0.64 },
    })
    surface.DrawRect(x + s * 0.10, y + s * 0.70, s * 0.08, s * 0.22)  -- ножка
    surface.DrawRect(x + s * 0.04, y + s * 0.90, s * 0.28, s * 0.07)
end

-- глиф выхода: дверь + стрелка (для красного чипа)
local function DrawExitGlyph(x, y, s, col)
    surface.SetDrawColor(col)
    draw.NoTexture()
    surface.DrawRect(x, y, s * 0.42, s)                               -- дверь
    surface.DrawPoly({                                                  -- стрелка
        { x = x + s * 1.00, y = y + s * 0.50 },
        { x = x + s * 0.62, y = y + s * 0.28 },
        { x = x + s * 0.62, y = y + s * 0.42 },
        { x = x + s * 0.30, y = y + s * 0.42 },
        { x = x + s * 0.30, y = y + s * 0.58 },
        { x = x + s * 0.62, y = y + s * 0.58 },
        { x = x + s * 0.62, y = y + s * 0.72 },
    })
end

-- сердце (карточка ХП)
local function DrawHeart(x, y, s, col)
    surface.SetDrawColor(col)
    draw.NoTexture()
    surface.DrawPoly({
        { x = x, y = y + s },
        { x = x - s, y = y + s * 0.25 },
        { x = x - s, y = y - s * 0.35 },
        { x = x - s * 0.5, y = y - s * 0.7 },
        { x = x, y = y - s * 0.25 },
        { x = x + s * 0.5, y = y - s * 0.7 },
        { x = x + s, y = y - s * 0.35 },
        { x = x + s, y = y + s * 0.25 },
    })
end

-- щит (карточка брони)
local function DrawShield(x, y, s, col)
    surface.SetDrawColor(col)
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

-- глиф мыши (подсказка курсора)
local function DrawMouseGlyph(x, y, s, col)
    surface.SetDrawColor(col)
    draw.NoTexture()
    surface.DrawOutlinedRect(x - s * 0.45, y - s * 0.7, s * 0.9, s * 1.4, 2)
    surface.DrawRect(x - s * 0.15, y - s * 0.6, s * 0.3, s * 0.45) -- средняя
end

-- тёмная плашка имени камеры (эталон): текст белым на темноте
local function NameBar(x, y, h, txt, alignR, dim)
    surface.SetFont("P11.Dsp.Name")
    local tw = surface.GetTextSize(txt)
    local w = tw + 24
    local bx = alignR and (x - w) or x
    draw.RoundedBox(3, bx, y, w, h, Color(10, 12, 16, 190))
    draw.SimpleText(txt, "P11.Dsp.Name", bx + w / 2, y + h / 2,
        dim and Color(150, 158, 170, 210) or Color(238, 242, 248),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- буквенный чип 36×36 (нажатый — тёмный с серой буквой, как в эталоне)
local function KeyChip(x, y, size, letter, pressed)
    if pressed then
        draw.RoundedBox(3, x, y, size, size, Color(24, 27, 32, 232))
        draw.SimpleText(letter, "P11.Dsp.Chip", x + size / 2, y + size / 2,
            Color(170, 176, 186), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
        draw.RoundedBox(3, x, y, size, size, Color(245, 246, 248, 240))
        draw.SimpleText(letter, "P11.Dsp.Chip", x + size / 2, y + size / 2,
            Color(18, 21, 26), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

-- ============ СТАТИК-ШУМ ЧЕРЕЗ РЕНДЕР-ТАРГЕТЫ (плотное зерно эталона) ============

local noiseRT, noiseMat = {}, {}
local function NoiseEnsure()
    for k = 1, 3 do
        if not noiseRT[k] then
            noiseRT[k] = GetRenderTarget("P11DspNoiseRT" .. k, 256, 256)
        end
        if not noiseMat[k] then
            noiseMat[k] = CreateMaterial("P11DspNoiseM" .. k, "UnlitGeneric", {
                ["$basetexture"] = noiseRT[k]:GetName(),
                ["$vertexalpha"] = "1",
                ["$vertexcolor"] = "1",
            })
        end
    end
end

local function NoiseRegen() -- дергаем на каждый Zap (переключение)
    NoiseEnsure()
    for k = 1, 3 do
        render.PushRenderTarget(noiseRT[k])
        render.Clear(0, 0, 0, 255)
        cam.Start2D()
        for y = 0, 252, 4 do
            for x = 0, 252, 4 do
                local g = math.random(30, 225)
                surface.SetDrawColor(g, g, g, 255)
                surface.DrawRect(x, y, 4, 4)
            end
        end
        cam.End2D()
        render.PopRenderTarget()
    end
end

local function NoiseDraw(w, h)
    NoiseEnsure()
    local m = noiseMat[1 + (FrameNumber() % 3)]
    surface.SetMaterial(m)
    surface.SetDrawColor(255, 255, 255, 245)
    for ty = 0, h - 1, 256 do
        for tx = 0, w - 1, 256 do
            surface.DrawTexturedRect(tx, ty, 256, 256)
        end
    end
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

-- ============ ТОСТЫ УВЕДОМЛЕНИЙ (эталон: справа над баром) ============

function D.Notify(msg)
    D.toasts[#D.toasts + 1] = { msg = tostring(msg), till = CurTime() + 4 }
    if #D.toasts > 4 then table.remove(D.toasts, 1) end
    surface.PlaySound("buttons/button17.wav")
end

local function ToastsDraw(w, h)
    local k = h / 1080
    local y0 = 905 * k
    local now = CurTime()
    for i = #D.toasts, 1, -1 do
        local t = D.toasts[i]
        if now > t.till then
            table.remove(D.toasts, i)
        else
            local row = #D.toasts - i -- 0 = нижний (новый)
            surface.SetFont("P11.Dsp.Toast")
            local tw = surface.GetTextSize(t.msg)
            local bw = tw + 74 * k
            local x = (w - 170 * k) - bw
            local y = y0 - row * 40 * k
            local a = 235
            local left = t.till - now
            if left < 0.5 then a = math.floor(235 * (left / 0.5)) end
            draw.RoundedBox(4, x, y, bw, 34 * k, Color(12, 13, 17, math.min(a, 215)))
            -- оранжевый «i» кружок слева
            surface.SetDrawColor(255, 150, 40, a)
            draw.NoTexture()
            surface.DrawPoly(PolyCircle(x + 20 * k, y + 17 * k, 11 * k, 16))
            draw.SimpleText("i", "P11.Dsp.Toast", x + 20 * k, y + 17 * k,
                Color(20, 14, 8, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(t.msg, "P11.Dsp.Toast", x + 40 * k, y + 17 * k,
                Color(240, 244, 250, a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            -- оранжевая полоса справа
            surface.SetDrawColor(255, 150, 40, a)
            surface.DrawRect(x + bw - 4, y + 6 * k, 4, 34 * k - 12 * k)
        end
    end
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
        D.Notify(msg) -- v4.21.0 «КОПИЯ»: тост как в эталоне («Вы выдали оружие …»)
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
        D.Notify("Нет цели — действие отменено.")
        return
    end
    if (D.energy or 100) < a.cost then
        surface.PlaySound("buttons/button10.wav")
        D.Notify("Мало энергии: нужно " .. a.cost .. "⚡.")
        return
    end
    if a.op == 4 then SendW(4, t, a.wi) else SendT(a.op, t) end
    surface.PlaySound("buttons/button15.wav")
end

-- ============ ШУМ / РЕЖИМЫ / ШАГИ ============

function D.Zap() -- статик-шум на каждое переключение (эталон)
    D.noise = CurTime() + 0.5
    NoiseRegen() -- свежее зерно
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
    D.flashDir = (d == -1 and "A") or (d == 1 and "D") or (d == -3 and "W") or (d == 3 and "S") or nil
    D.flashTill = CurTime() + 0.18 -- нажатый чип мигает тёмным, как в эталоне
    D.Zap() -- v4.20.2 «БРОНЯ»: шипит и у края — нажатие ВСЕГДА видно/слышно
    if D.sel ~= old and D.RebuildPanel and D.cursor then D.RebuildPanel() end
end

-- ============ КЛАВА (железный контур чата) ============

local nextKey = 0
local function DspKeysBody(ply, key)
    if not D.active then return end
    if ply ~= LocalPlayer() then return end
    if CurTime() < nextKey then return end

    if key == KEY_E then -- ESC накрыт отдельным крюком OnPauseMenuShow ниже
        nextKey = CurTime() + 0.3
        if cvDbg:GetBool() then print("[ГЛАЗ→] выход: клавиша E") end
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
end

hook.Add("PlayerButtonDown", "P11.DspKeys", function(ply, key)
    local ok, err = pcall(DspKeysBody, ply, key)
    if not ok then GuiFail("клава", err) end
end)

-- v4.20.2 «БРОНЯ»: ESC закрывает СЕАНС, а не меню игры — раньше нажатие
-- глоталось движком ещё до PlayerButtonDown («на эскейп нельзя выйти»)
hook.Add("OnPauseMenuShow", "P11.DspEsc", function()
    if not D.active then return end
    if CurTime() < nextKey then return false end -- антидребезг
    nextKey = CurTime() + 0.5
    if cvDbg:GetBool() then print("[ГЛАЗ→] выход: ESC (меню игры накрыто)") end
    Send0(1)
    D.Close()
    return false -- меню не открываем: сначала — выход из пульта
end)

-- ============ САЙД-ПУЛЬТ (НАШ доп: двери/маяк/эфир — за средней кнопкой) ============

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
    f:SetMouseInputEnabled(false)    -- пульт СКРЫТ, пока не нажали среднюю
    f:SetKeyboardInputEnabled(false) -- кнопку (в эталоне курсор — отдельно)
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
                function() if affordMark then SendT(5, tt) else D.Notify("Мало энергии: нужно 20⚡.") end end,
                affordMark and COL.gold or COL.dim)
            Row("👁 СМЕНИТЬ ВИД — бинокль (" .. IrisKeyName() .. ")", function() D.SetIris(not D.iris) end,
                D.iris and COL.gold or COL.txt)
        end
    end

    -- ===== ЭФИР =====
    Head("ЭФИР:")
    local affordSig = (D.energy or 100) >= 10
    Row("📡 СИГНАЛ ВСЕМ ОРЛАМ  (−10 эн.)",
        function() if affordSig then Send0(6) else D.Notify("Мало энергии: нужно 10⚡.") end end,
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

-- ============ АВАТАР ЦЕЛИ (НАСТОЯЩИЙ Steam-аватар, как в эталоне) ============

function D.BuildAvatar()
    if IsValid(D.avRoot) then D.avRoot:Remove() end
    local root = vgui.Create("DPanel")
    root:SetSize(ScrW(), ScrH())
    root:SetPos(0, 0)
    root:SetMouseInputEnabled(false)
    root:SetKeyboardInputEnabled(false)
    root.Paint = function() end
    local av = vgui.Create("AvatarImage", root)
    av:SetSize(64, 64)
    av:SetMouseInputEnabled(false)
    av:SetVisible(false)
    D.avRoot = root
    D.avCard = av
    D._avT = nil
end

-- ============ ОТКРЫТИЕ / ЗАКРЫТИЕ ============

function D.Open()
    D.active = true
    D.mode = "cam"
    D.sel = 1
    D.iris = false
    D.cursor = false
    D.energy = 100 -- до первого op10; сервер шлёт сразу после OPEN
    D.toasts = {}
    if P11 and P11.ThirdPerson ~= nil then P11.ThirdPerson = false end -- вид пульта важнее F2
    D.BuildPanel()
    D.BuildAvatar()
    D.since = CurTime() -- первые 10 сек подсказка про среднюю кнопку мигает
    D.Zap() -- вход в эфир — со статик-шумом (эталон)
    surface.PlaySound("ambient/energy/zap9.wav")
    chat.AddText(Color(150, 190, 255), "[ГЛАЗ] A/D — переключение • SPACE — камеры/люди • цифры 1–9 — действия • "
        .. IrisKeyName() .. " — бинокль • СРЕДНЯЯ КНОПКА МЫШИ — курсор и пульт дверей • E/ESC — выход")
end

function D.Close()
    D.active = false
    D.cursor = false
    D.toasts = {}
    gui.EnableScreenClicker(false) -- средняя кнопка могла оставить курсор
    if IsValid(D.frame) then D.frame:Remove() end
    D.frame = nil
    D.scroll = nil
    if IsValid(D.avRoot) then D.avRoot:Remove() end
    D.avRoot = nil
    D.avCard = nil
    D._avT = nil
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

local function DspViewBody(ply, pos, ang, fov)
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
end

hook.Add("CalcView", "P11.DspView", function(ply, pos, ang, fov)
    local ok, v = pcall(DspViewBody, ply, pos, ang, fov)
    if ok then return v end
    GuiFail("вид", v)
end)

hook.Add("PreDrawViewModel", "P11.DspNoVM", function()
    if D.active then return true end
end)
hook.Add("PreDrawPlayerHands", "P11.DspNoHands", function()
    if D.active then return true end
end)

-- ============ HUD: КАДР ЭФИРА — ПОКАДРОВАЯ КОПИЯ ЭТАЛОНА ============

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

local function IrisMask(w, h) -- круг-бинокль r≈0.46H, тёмное поле вокруг
    local r = h * 0.46
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
    surface.DrawPoly(PolyCircle(w / 2, h / 2, r, 72))
    render.SetStencilCompareFunction(STENCIL_NOTEQUAL)
    render.SetStencilPassOperation(STENCIL_KEEP)
    surface.SetDrawColor(0, 0, 0, 250)
    surface.DrawRect(0, 0, w, h)
    render.SetStencilEnable(false)
    -- тонкое тёмное кольцо по краю
    surface.SetDrawColor(0, 0, 0, 255)
    draw.NoTexture()
    local segs = 72
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

local function DspHUDBody()
    local me = LocalPlayer()

    -- 📍 маяк цели: горит у орлов (поверх маскировки) — НАШЕ, не эталон
    local marked = {}
    if MarkerForMe() then
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and p:Alive() and p ~= me then
                local till = p:GetNWFloat("P11_DspMark", 0)
                if till > (p.P11_DspPrevMark or 0) then
                    p.P11_DspPrevMark = till
                    p.P11_DspSeenAt   = CurTime()
                end
                if till > 0 and (CurTime() - (p.P11_DspSeenAt or 0)) < 62 then
                    marked[#marked + 1] = p
                end
            end
        end
    end

    if not D.active then
        -- маяк рисуем и вне сеанса (орлы ходят по станции)
        for _, p in ipairs(marked) do
            local pos = (p:GetPos() + Vector(0, 0, 86)):ToScreen()
            if pos.visible then
                draw.SimpleText("🦅 ЦЕЛЬ ЦЕНТРА", "P11.Dsp.Row", pos.x, pos.y,
                    Color(130, 175, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText(math.max(0, math.ceil(60 - (CurTime() - (p.P11_DspSeenAt or 0)))) .. "с",
                    "P11.Dsp.Small", pos.x, pos.y + 18,
                    Color(130, 175, 255, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
        return
    end

    local w, h = ScrW(), ScrH()
    local k = h / 1080 -- весь эталон снят на 1080p — масштабируем мерки
    local cx = w / 2
    local cur = SelEntity()

    -- ===== 0. мирские иконки людей + тусклые позывные (под шумом и ирисом) =====
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:Alive() and p ~= me and p ~= cur then
            local pos = (p:GetPos() + Vector(0, 0, 52)):ToScreen()
            if pos.visible then
                DrawPerson(pos.x, pos.y, 0.9, 200)
                draw.SimpleText(Short(p:Nick(), 20), "P11.Dsp.Nick", pos.x, pos.y - 30 * k,
                    Color(220, 226, 235, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end

    -- ===== 1. бинокль-ирис (мир + иконки придавлены тёмным полем) =====
    if D.mode == "ply" and D.iris then
        IrisMask(w, h)
    end

    -- ===== 2. статик-шум поверх мира (хром UI рисуется ПОВЕРХ) =====
    if CurTime() < D.noise then
        NoiseDraw(w, h)
    end

    -- ===== 3. крестовина камер ИЛИ строка целей (эталон) =====
    local rowY = 730 * k          -- строка чипов A/D
    local chipS = 36 * k
    local aX = cx - 42 * k        -- чип A: cx−42..cx−6
    local dX = cx + 6 * k         -- чип D: cx+6..cx+42
    local stepY = 96 * k          -- шаг рядов: S упирается ровно в бар (858k)

    if D.mode == "cam" then
        -- текущая камера — баррель над W, по центру
        local curName = SlotName(D.sel)
        local curDim = (curName == "Нет камеры")
        surface.SetFont("P11.Dsp.Name")
        local cw = surface.GetTextSize(curName) + 28 * k
        draw.RoundedBox(3, cx - cw / 2, rowY - 2 * stepY, cw, chipS, Color(10, 12, 16, 190))
        draw.SimpleText(curName, "P11.Dsp.Name", cx, rowY - 2 * stepY + chipS / 2,
            curDim and Color(150, 158, 170, 210) or Color(238, 242, 248),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if SelCount() <= 0 then
            draw.SimpleText("расставь 📍 «Камеру «ГЛАЗ»» (роль cam)", "P11.Dsp.Hint",
                cx, rowY - 2 * stepY + chipS + 14 * k,
                Color(255, 150, 140, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- W: чип в колонне A, имя справа
        local nW = SlotName(D.sel - 3)
        KeyChip(aX, rowY - stepY, chipS, "W", D.flashDir == "W" and CurTime() < D.flashTill)
        NameBar(aX + chipS + 6 * k, rowY - stepY, chipS, nW, false, nW == "Нет камеры")
        -- A: имя слева (выровнено вправо к чипу)
        local nA = SlotName(D.sel - 1)
        NameBar(aX - 6 * k, rowY, chipS, nA, true, nA == "Нет камеры")
        KeyChip(aX, rowY, chipS, "A", D.flashDir == "A" and CurTime() < D.flashTill)
        -- D: чип, имя справа
        local nD = SlotName(D.sel + 1)
        KeyChip(dX, rowY, chipS, "D", D.flashDir == "D" and CurTime() < D.flashTill)
        NameBar(dX + chipS + 6 * k, rowY, chipS, nD, false, nD == "Нет камеры")
        -- S: чип в колонне A, имя справа
        local nS = SlotName(D.sel + 3)
        KeyChip(aX, rowY + stepY, chipS, "S", D.flashDir == "S" and CurTime() < D.flashTill)
        NameBar(aX + chipS + 6 * k, rowY + stepY, chipS, nS, false, nS == "Нет камеры")
    else
        -- режим ЛЮДЕЙ: «Предыдущая цель [A][D] Следующая цель» (y≈794)
        local hy = 794 * k
        draw.SimpleText("Предыдущая цель", "P11.Dsp.Act", aX - 10 * k, hy + chipS / 2,
            Color(238, 242, 248, 235), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        KeyChip(aX, hy, chipS, "A", D.flashDir == "A" and CurTime() < D.flashTill)
        KeyChip(dX, hy, chipS, "D", D.flashDir == "D" and CurTime() < D.flashTill)
        draw.SimpleText("Следующая цель", "P11.Dsp.Act", dX + chipS + 10 * k, hy + chipS / 2,
            Color(238, 242, 248, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- ===== 4. левая панель действий (только режим людей) =====
    if D.mode == "ply" then
        local lx = 104 * k
        local pw = 373 * k
        local ly = 321 * k
        local t = SelEntity()

        -- карточка цели: аватар + позывной + фракция + ХП/броня
        draw.RoundedBox(4, lx, ly, pw, 120 * k, Color(8, 10, 14, 185))
        local avX, avY, avW, avH = lx + 8 * k, ly + 10 * k, 66 * k, 80 * k
        surface.SetDrawColor(225, 232, 240, 235)
        surface.DrawRect(avX, avY, avW, avH) -- белая рамка аватара
        DrawPerson(avX + avW / 2, avY + avH * 0.62, 2.0 * k, 120, Color(90, 98, 112, 160)) -- запаска под аватаром
        if IsValid(D.avCard) then
            if IsValid(t) then
                if D._avT ~= t then
                    D._avT = t
                    D.avCard:SetPlayer(t, 64) -- НАСТОЯЩИЙ Steam-аватар цели
                end
                D.avCard:SetSize(avW - 4, avH - 4)
                D.avCard:SetPos(avX + 2, avY + 2)
                D.avCard:SetVisible(true)
            else
                D.avCard:SetVisible(false)
                D._avT = nil
            end
        end
        if IsValid(t) then
            draw.SimpleText(Short(t:Nick(), 16), "P11.Dsp.CardName", lx + 86 * k, ly + 12 * k,
                Color(242, 246, 252), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            local jn = (P11FW and P11FW.GetJobName and P11FW.GetJobName(t)) or "—"
            draw.SimpleText("ЦЕНТР ✦ " .. Short(jn, 14), "P11.Dsp.CardFact", lx + 86 * k, ly + 38 * k,
                Color(110, 135, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            DrawHeart(lx + 96 * k, ly + 92 * k, 11 * k, Color(240, 245, 250, 230))
            draw.SimpleText(tostring(t:Health()), "P11.Dsp.Stat", lx + 112 * k, ly + 82 * k,
                Color(240, 245, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            DrawShield(lx + 190 * k, ly + 92 * k, 11 * k, Color(240, 245, 250, 230))
            draw.SimpleText(tostring(t:Armor()), "P11.Dsp.Stat", lx + 206 * k, ly + 82 * k,
                Color(240, 245, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        else
            draw.SimpleText("ЦЕЛИ НЕТ", "P11.Dsp.CardName", lx + 86 * k, ly + 46 * k,
                Color(255, 150, 140), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        ly = ly + 132 * k

        -- ряды действий 1..9: чип-цифра, подпись, молния+цена (эталон)
        for ni, act in ipairs(D.Acts) do
            local afford = (D.energy or 100) >= act.cost
            draw.RoundedBox(3, lx, ly, pw, 22 * k, Color(8, 10, 14, afford and 185 or 110))
            surface.SetDrawColor(afford and Color(240, 244, 250, 240) or Color(120, 128, 140, 160))
            surface.DrawRect(lx + 6 * k, ly + 3 * k, 18 * k, 16 * k)
            draw.SimpleText(tostring(ni), "P11.Dsp.Price", lx + 15 * k, ly + 11 * k,
                Color(16, 20, 26), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(act.name, "P11.Dsp.Act", lx + 34 * k, ly + 11 * k,
                afford and Color(236, 240, 246) or Color(120, 130, 145),
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            DrawBolt(lx + pw - 46 * k, ly + 4 * k, 10 * k, 14 * k,
                afford and Color(120, 165, 255) or Color(90, 100, 120, 160))
            draw.SimpleText(tostring(act.cost), "P11.Dsp.Price", lx + pw - 8 * k, ly + 11 * k,
                afford and Color(120, 165, 255) or Color(90, 100, 120, 160),
                TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            ly = ly + 27 * k
        end
        draw.SimpleText("Сменить вид (" .. IrisKeyName() .. ")" .. (D.iris and " — вкл" or ""),
            "P11.Dsp.Act", lx + pw / 2, ly + 4 * k,
            D.iris and Color(235, 205, 120) or Color(238, 242, 248, 235),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    -- ===== 5. нижний бар эталона =====
    -- батарея: 200×52, x = cx−299
    local bX, bY, bW, bH = cx - 299 * k, 886 * k, 200 * k, 52 * k
    draw.RoundedBox(6, bX, bY, bW, bH, Color(28, 100, 215, 240))
    DrawBolt(bX + 18 * k, bY + 12 * k, 20 * k, 28 * k, Color(255, 255, 255, 245))
    draw.SimpleText(math.floor(D.energy or 100) .. "%", "P11.Dsp.Batt",
        bX + bW / 2 + 14 * k, bY + bH / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- чипы режимов: ALT+1 (72×56) + ALT+2, активный — белый
    local chW, chH, chY = 72 * k, 56 * k, 858 * k
    local function ModeChip(x, num, glyph, active)
        if active then
            draw.RoundedBox(4, x, chY, chW, chH, Color(245, 246, 248, 240))
        else
            draw.RoundedBox(4, x, chY, chW, chH, Color(24, 26, 30, 225))
        end
        local col = active and Color(18, 21, 26) or Color(215, 220, 230)
        if glyph == "cam" then
            DrawCamGlyph(x + chW / 2 - 13 * k, chY + 5 * k, 26 * k, col)
        else
            DrawPerson(x + chW / 2, chY + 24 * k, 0.9 * k, 235, col)
        end
        draw.SimpleText("ALT+" .. num, "P11.Dsp.ChipCap", x + chW / 2, chY + chH - 10 * k,
            col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    ModeChip(cx - 77 * k, 1, "cam", D.mode == "cam")
    ModeChip(cx + 3 * k, 2, "ply", D.mode == "ply")
    draw.SimpleText(D.mode == "cam" and "Камеры" or "Игроки", "P11.Dsp.Label",
        cx, 937 * k, Color(245, 248, 252), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- красный «Выйти»: 127×36, x = cx+103
    local eX, eY, eW, eH = cx + 103 * k, 896 * k, 127 * k, 36 * k
    draw.RoundedBox(4, eX, eY, eW, eH, Color(208, 46, 38, 235))
    DrawExitGlyph(eX + 12 * k, eY + 8 * k, 20 * k, Color(255, 255, 255, 240))
    draw.SimpleText("Выйти", "P11.Dsp.Act", eX + 40 * k, eY + eH / 2,
        Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- подсказка курсора (первые 10 сек сеанса — пульсом)
    local hintA = 200
    if (D.since or 0) > 0 and CurTime() - D.since < 10 then
        hintA = 110 + math.abs(math.sin(CurTime() * 6)) * 145
    end
    DrawMouseGlyph(cx - 118 * k, 973 * k, 12 * k, Color(200, 208, 220, hintA))
    draw.SimpleText(" — " .. (D.cursor and "скрыть" or "показать") .. " курсор  (средняя кнопка)",
        "P11.Dsp.Hint", cx - 104 * k, 973 * k,
        Color(200, 208, 220, hintA), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- ===== 6. тосты уведомлений (эталон: справа над баром) =====
    ToastsDraw(w, h)

    -- ===== 7. маяк цели орлов (поверх всего — как было) =====
    for _, p in ipairs(marked) do
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

hook.Add("HUDPaint", "P11.DspHUD", function()
    local ok, err = pcall(DspHUDBody)
    if not ok then GuiFail("кадр", err) end
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

print("[POLUS-11] «ГЛАЗ»: пульт диспетчера v4.21.0 «КОПИЯ» OK")
