-- ============================================================
--  ПОЛЮС-11 — ВИД И КУРСОР (client) v3.8
--  • F2 — вид от ТРЕТЬЕГО ЛИЦА / назад от первого (мягкий,
--    с пролётом сквозь стены до препятствия, как у выживалок);
--  • F3 — СВОБОДНЫЙ КУРСОР: мышь отцепляется от вида (удобно
--    тыкать в экраны/записки), повторное нажатие — назад;
--  • ГОЛОСОВЫЕ ПАНЕЛЬКИ («громкоговорители» движка): базовый
--    GMod вешает их справа-сверху поверх правой части HUD —
--    теперь они живут СЛЕВА СНИЗУ, над панелью состояния,
--    в стиле станции (ник — украденный! — и цвет должности).
-- ============================================================

P11 = P11 or {}

surface.CreateFont("P11.View.Hint", { font = "Roboto", size = 15, weight = 600, extended = true })

-- ============================================================
--  F2 — ТРЕТЬЕ ЛИЦО
-- ============================================================

P11.ThirdPerson = false
P11.TPPos = nil

local TP_DIST, TP_SIDE, TP_UP = 118, 20, 8

hook.Add("CalcView", "P11.ThirdPerson", function(ply, pos, ang, fov)
    if ply ~= LocalPlayer() then return end
    if not P11.ThirdPerson then
        P11.TPPos = nil
        return
    end
    if not ply:Alive() or ply:GetViewEntity() ~= ply then return end
    if P11.IntroOpen then return end

    -- целевая точка за спиной
    local back = pos - ang:Forward() * TP_DIST
                 + ang:Right() * TP_SIDE
                 + ang:Up() * TP_UP

    -- не даём камере уйти в стены/пол (халл-трейс назад)
    local tr = util.TraceHull({
        start  = pos,
        endpos = back,
        mins   = Vector(-9, -9, -9),
        maxs   = Vector(9, 9, 9),
        filter = ply,
        mask   = MASK_SHOT_HULL,
    })
    local target = tr.HitPos + tr.HitNormal * 4 + ang:Forward() * 4

    -- плавность: камера догоняет, а не прыгает
    if not P11.TPPos then P11.TPPos = target end
    P11.TPPos = LerpVector(math.min(1, FrameTime() * 14), P11.TPPos, target)

    return {
        origin     = P11.TPPos,
        angles     = ang,
        fov        = fov,
        drawviewer = true,
    }
end)

hook.Add("ShouldDrawLocalPlayer", "P11.ThirdPersonDraw", function(ply)
    if P11.ThirdPerson and not P11.IntroOpen then return true end
end)

-- ============================================================
--  F3 — СВОБОДНЫЙ КУРСОР
-- ============================================================

P11.FreeCursor = false

local function SetFreeCursor(on)
    P11.FreeCursor = on and true or false
    gui.EnableScreenClicker(P11.FreeCursor)
    surface.PlaySound(P11.FreeCursor and "buttons/button9.wav" or "buttons/button10.wav")
end

hook.Add("HUDPaint", "P11.ViewHints", function()
    if P11.IntroOpen then return end

    if P11.FreeCursor then
        local w, h = ScrW(), ScrH()
        draw.RoundedBox(6, w / 2 - 150, h - 46, 300, 30, Color(10, 14, 20, 200))
        draw.SimpleText("🖱 курсор свободен — F3 вернуть прицел", "P11.View.Hint",
            w / 2, h - 31, Color(150, 210, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)

-- ============================================================
--  КЛАВИШИ F2 / F3
-- ============================================================

hook.Add("PlayerBindPress", "P11.ViewKeys", function(ply, bind, pressed)
    if not pressed then return end
    if ply ~= LocalPlayer() then return end

    if string.find(bind, "gm_showteam") then -- F2
        P11.ThirdPerson = not P11.ThirdPerson
        surface.PlaySound(P11.ThirdPerson and "buttons/button15.wav" or "buttons/button17.wav")
        chat.AddText(Color(150, 210, 240), "[ПОЛЮС-11] ",
            Color(220, 228, 240),
            P11.ThirdPerson and "вид от ТРЕТЬЕГО лица (F2 — вернуться от первого)"
                              or "вид от ПЕРВОГО лица")
        return true
    end

    if string.find(bind, "gm_showspare1") then -- F3
        SetFreeCursor(not P11.FreeCursor)
        return true
    end
end)

-- ============================================================
--  ГОЛОСОВЫЕ ПАНЕЛЬКИ — вниз и в стиле станции
--  (базовые рисуются справа-сверху, закрывая HUD «Должность/патроны»)
-- ============================================================

local function PlaceVoiceList()
    if not (g_VoicePanelList and IsValid(g_VoicePanelList)) then return false end
    -- лево-низ, НАД панелью состояния (та 144 px от низа) — «чуть ниже»
    -- и дальше от права, где у нас канал рации, патроны и значки фазы
    local h = ScrH()
    g_VoicePanelList:SetPos(16, h - 176 - 320)
    g_VoicePanelList:SetSize(250, 320)
    return true
end

hook.Add("InitPostEntity", "P11.VoicePlace", function()
    -- базовая CreateVoiceVGUI отрабатывает на этом же хуке, но раньше
    -- (она из BaseClass) — нам достаточно передвинуть после неё
    if not PlaceVoiceList() then
        timer.Simple(0.05, PlaceVoiceList)
        timer.Simple(1, PlaceVoiceList)
    end
end)

hook.Add("OnScreenSizeChanged", "P11.VoicePlaceResize", function()
    PlaceVoiceList()
end)

-- рестайл самих панелек: станционная тема, украденное имя, цвет профы
timer.Simple(1, function()
    local VT = vgui.GetControlTable and vgui.GetControlTable("VoiceNotify")
    if not VT or VT.P11Styled then return end
    VT.P11Styled = true

    VT.Paint = function(self, w, h)
        if not IsValid(self.ply) then return end
        local vol = math.Clamp(self.ply:VoiceVolume(), 0, 1)
        draw.RoundedBox(6, 0, 0, w, h, Color(12, 16, 22, 232))
        -- шкала громкости — морозная полоса снизу
        draw.RoundedBox(3, 4, h - 7, math.max(6, (w - 8) * (0.15 + vol * 0.85)), 3,
            Color(120, 200, 240, 90 + vol * 160))
        -- левая кромка динамика
        draw.RoundedBoxEx(6, 0, 0, 3, h, Color(120, 200, 240),
            true, false, true, false)
    end

    local oldSetup = VT.Setup
    VT.Setup = function(self, ply)
        oldSetup(self, ply)
        if not IsValid(ply) then return end
        -- v4.8.2: в плашке говорящего — ПОЗЫВНОЙ, а не steam-ник.
        -- Порядок как у POLUS11.DisplayName: личина Нечто (вообще
        -- скрывает тебя под жертвой) > позывной из дела бойца > ник.
        local name = ply:GetNWString("P11_FakeNick", "")
        if name == "" then name = ply:GetNWString("P11_CharName", "") end
        if name == "" then name = ply:Nick() end
        self.LabelName:SetText("🔊 " .. name)
        local tc = team.GetColor(ply:Team())
        if tc then
            self.LabelName:SetTextColor(Color(
                math.min(255, tc.r + 40), math.min(255, tc.g + 40),
                math.min(255, tc.b + 40)))
        end
    end
end)
