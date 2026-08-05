-- ============================================================
--  ПОЛЮС-11 — ИНТРО (client) v2.6
--  Кинематографичная заставка при входе: чёрный экран, ветер
--  станции, строки лора «печатаются», потом плавный выход.
--  Пропуск — ЛКМ / ESC / ПРОБЕЛ / ENTER. Один раз за сессию.
--  Отключить себе: p11_intro 0 (сохраняется).
-- ============================================================

surface.CreateFont("P11.Intro.Big",   { font = "Roboto", size = 30, weight = 800, extended = true })
surface.CreateFont("P11.Intro.Small", { font = "Roboto", size = 15, weight = 400, extended = true })

local CONVAR = CreateClientConVar("p11_intro", "1", true, false)

local LINES = {
    "АНТАРКТИДА. 1982 ГОД.",
    "Исследовательская станция «ПОЛЮС-11».",
    "Трое суток назад на льду нашли следы того, что не должно двигаться.",
    "Оно поглощает жертву и идеально копирует её: лицо, голос, память, привычки.",
    "Единственная истина — раскалённая проволока и кровь, что ДВИЖЕТСЯ сама.",
    "Доверяй огню. Доверяй тесту. Больше никому.",
    "Смена начинается. Добро пожаловать в гарнизон.",
}

local INTRO = {
    active = false,
    shown  = false, -- один раз за сессию
    t      = 0,     -- старт
    chars  = 0,     -- сколько символов напечатано (плавный счётчик)
    sound  = nil,
}

local ColText = Color(150, 210, 235)
local ColDim  = Color(95, 120, 135)

local function CloseIntro()
    if not INTRO.active then return end
    INTRO.active = false
    if INTRO.sound then INTRO.sound:Stop() INTRO.sound = nil end
    if IsValid(INTRO.frame) then INTRO.frame:Remove() INTRO.frame = nil end
    hook.Remove("Think", "P11.IntroThink")
end

local function OpenIntro()
    if INTRO.active or INTRO.shown then return end
    if CONVAR:GetInt() == 0 then INTRO.shown = true return end
    INTRO.shown = true
    INTRO.active = true
    INTRO.t = CurTime()
    INTRO.chars = 0
    INTRO.total = 0
    for _, line in ipairs(LINES) do INTRO.total = INTRO.total + #line end

    -- эмбиент станции ветром
    local ok, cs = pcall(CreateSound, LocalPlayer(), "ambient/atmosphere/ambience_base.wav")
    if ok and cs then
        INTRO.sound = cs
        cs:PlayEx(0.55, 100)
    end

    local f = vgui.Create("DPanel")
    INTRO.frame = f
    f:SetSize(ScrW(), ScrH())
    f:MakePopup()
    f:SetKeyboardInputEnabled(true)
    f:SetMouseInputEnabled(true)

    f.Paint = function(s, w, h)
        local el = CurTime() - INTRO.t
        INTRO.chars = INTRO.chars + FrameTime() * 26 -- скорость печатной машинки
        local charsLeft = math.floor(INTRO.chars)

        draw.RoundedBox(0, 0, 0, w, h, Color(4, 6, 9, 255))

        -- тонкие морозные линии
        surface.SetDrawColor(40, 70, 90, 90)
        surface.DrawRect(0, h * 0.24, w, 1)
        surface.DrawRect(0, h * 0.76, w, 1)

        local y = h * 0.30
        local allDone = true
        for i, line in ipairs(LINES) do
            if charsLeft <= 0 then allDone = false break end
            local take = math.min(charsLeft, #line)
            local part = string.sub(line, 1, take)
            charsLeft = charsLeft - take
            local font = (i == 1 or i == #LINES) and "P11.Intro.Big" or "P11.Intro.Small"
            local done = take >= #line
            draw.SimpleText(part .. ((not done) and "▌" or ""), font, w / 2, y,
                done and ColText or ColDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            y = y + (i == 1 and 56 or 42)
            if not done then allDone = false break end
        end

        -- вспышка-затухание и авто-конец
        if allDone then
            -- мягкое свечение логотипа в финале
            draw.SimpleText("«ПОЛЮС-11» — ЛЕДЯНАЯ ПАРАНОЙЯ", "P11.Intro.Big",
                w / 2, h * 0.24 + 20, Color(ColText.r, ColText.g, ColText.b,
                    60 + math.sin(CurTime() * 2.5) * 40), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
            if el > (INTRO.total / 26) + 3.5 then
                CloseIntro()
                return
            end
        end

        draw.SimpleText("ПРОПУСК — ЛЮБАЯ КЛАВИША / КЛИК", "P11.Intro.Small",
            w - 22, h - 20, Color(ColDim.r, ColDim.g, ColDim.b, 160), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    -- пропуск
    local skip = function() CloseIntro() end
    f.OnMousePressed = skip
    f.OnKeyCodePressed = function(s, key)
        if key ~= 0 then CloseIntro() end
    end

    -- страховка: если GUI захлебнулось — закрыть по мировым клавишам
    hook.Add("Think", "P11.IntroThink", function()
        if not INTRO.active then hook.Remove("Think", "P11.IntroThink") return end
        if input.IsKeyDown(KEY_ESCAPE) or input.IsKeyDown(KEY_ENTER)
            or input.IsKeyDown(KEY_SPACE) or input.IsMouseDown(MOUSE_LEFT) then
            CloseIntro()
        end
        -- жёсткий таймаут, чтобы не зависнуть навсегда
        if CurTime() - INTRO.t > 60 then CloseIntro() end
    end)
end

net.Receive("P11_IntroShow", function()
    timer.Simple(0.6, OpenIntro)
end)

-- ручной повтор: p11_intro_show
concommand.Add("p11_intro_show", function()
    INTRO.shown = false
    OpenIntro()
end)
