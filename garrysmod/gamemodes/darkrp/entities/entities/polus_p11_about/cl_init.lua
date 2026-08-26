-- ============================================================
--  ПОЛЮС-11 — О НАС / ПРОЕКТ АРЧИ v5.8.7 (КЛИЕНТ, энтити about)
--  1) ОКНО «ОБЩЕСТВО „ПРОЕКТ АРЧИ“»: мы — начинающее общество,
--     которое делает и развивает сервер «ПОЛЮС-11». Кнопки:
--     Discord (https://discord.gg/fDuSGRJRC3) и коллекция
--     (https://steamcommunity.com/sharedfiles/filedetails/?id=3777625029).
--  2) КНОПКА «ℹ О НАС» в С-меню ВПИСАНА ПРЯМО В ЛЕЙАУТ
--     (p11_cl_cmenu.lua v5.8.7, баннер внизу) — не перекрывает
--     другие кнопки. Здесь кнопку больше НЕ вешаем (обёртка была,
--     перекрывала — убрана).
--  3) АВТОПОКАЗ новичку при первом входе (один раз) — как часть
--     инструкции для новичка.
--  4) Команда !о нас / !проект / !об обществе — открыть окно.
--
--  ДОСТАВКА: cl_init энтити раздаётся клиентам ВСЕГДА
--  (не зависит от sv_allowcslua). Старые файлы не трогаем.
-- ============================================================

if not P11 then P11 = {} end

local DISCORD   = "https://discord.gg/fDuSGRJRC3"
local COLLECTION = "https://steamcommunity.com/sharedfiles/filedetails/?id=3777625029"

local ABOUT_DONE = "polus11/about_done.txt"

surface.CreateFont("P11.AB.Title", { font = "Roboto", size = 26, weight = 900, extended = true })
surface.CreateFont("P11.AB.Sub",   { font = "Roboto", size = 15, weight = 600, extended = true })
surface.CreateFont("P11.AB.Text",  { font = "Roboto", size = 15, weight = 500, extended = true })
surface.CreateFont("P11.AB.Small", { font = "Roboto", size = 13, weight = 500, extended = true })
surface.CreateFont("P11.AB.Btn",   { font = "Roboto", size = 17, weight = 800, extended = true })

local C = {
    bg    = Color(10, 14, 20, 250),
    panel = Color(20, 27, 40, 255),
    cyan  = Color(120, 185, 255),
    gold  = Color(255, 205, 110),
    text  = Color(228, 236, 245),
    dim   = Color(150, 165, 180),
    faint = Color(95, 110, 130),
    ds    = Color(114, 137, 218),  -- дискорд
    hover = Color(34, 46, 66, 255),
}

-- пятиконечная звезда (полигоном)
local function Star(cx, cy, r, col)
    local pts = {}
    for i = 1, 10 do
        local a = -math.pi / 2 + math.pi * (i - 1) / 5
        local rr = (i % 2 == 1) and r or r * 0.42
        pts[i] = { x = cx + math.cos(a) * rr, y = cy + math.sin(a) * rr }
    end
    draw.NoTexture()
    surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
    surface.DrawPoly(pts)
end

-- =================== КНОПКИ-ССЫЛКИ ===================
local function LinkButton(f, y, txt, sub, col, url)
    local b = vgui.Create("DButton", f)
    b:SetPos(30, y) b:SetSize(500, 64)
    b:SetText("")
    b.Paint = function(s, ww, hh)
        local hov = s:IsHovered()
        draw.RoundedBox(8, 0, 0, ww, hh, hov and C.hover or C.panel)
        draw.RoundedBoxEx(8, 0, 0, ww, math.floor(hh / 2), Color(255, 255, 255, 5), true, true, false, false)
        if hov then
            surface.SetDrawColor(col.r, col.g, col.b, 160)
            surface.DrawOutlinedRect(0, 0, ww, hh, 2)
            s:SetCursor("hand")
        else
            surface.SetDrawColor(col.r, col.g, col.b, 90)
            surface.DrawOutlinedRect(0, 0, ww, hh, 1)
        end
        -- иконка-квадрат слева
        draw.RoundedBox(6, 12, 12, 40, 40, Color(col.r, col.g, col.b, 60))
        draw.SimpleText(txt:sub(1, 1), "P11.AB.Btn", 32, 32, Color(240, 248, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(txt, "P11.AB.Btn", 64, hh / 2 - 12, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(sub, "P11.AB.Small", 64, hh / 2 + 12, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    b.DoClick = function()
        surface.PlaySound("ui/buttonclickrelease.wav")
        gui.OpenURL(url)
    end
    return b
end

-- =================== СБОРКА ОКНА (кнопки добавляем после Paint) ===================
-- делаем так: функция рисует фон, кнопки — vgui-элементы поверх
P11.OpenAbout = function()
    if IsValid(P11.AboutFrame) then P11.AboutFrame:Remove() end

    local f = vgui.Create("DFrame")
    P11.AboutFrame = f
    f:SetSize(560, 460)
    f:Center()
    f:MakePopup()
    f:SetSizable(false)
    f:SetDeleteOnClose(true)
    f:SetTitle("")
    f.OnKeyCodePressed = function(s, key)
        if key == KEY_ESCAPE then s:Remove() end
    end

    f.Paint = function(s, w, h)
        Derma_DrawBackgroundBlur(s, 0)
        draw.RoundedBox(10, 0, 0, w, h, C.bg)
        draw.RoundedBoxEx(10, 0, 0, w, 64, C.panel, true, true, false, false)
        draw.SimpleText("ОБЩЕСТВО «ПРОЕКТ АРЧИ»", "P11.AB.Title", 78, 20, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("мы делаем сервер «ПОЛЮС-11»", "P11.AB.Sub", 78, 48, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.DrawCircle(34, 32, 18, C.cyan.r, C.cyan.g, C.cyan.b, 60)
        surface.SetDrawColor(C.cyan.r, C.cyan.g, C.cyan.b, 130)
        surface.DrawCircle(34, 32, 18, C.cyan.r, C.cyan.g, C.cyan.b, 130)
        local ra = CurTime() * 1.6
        surface.DrawLine(34, 32, 34 + math.cos(ra) * 16, 32 + math.sin(ra) * 16)
        Star(34, 32, 8, C.gold)
        surface.SetDrawColor(C.cyan)
        surface.DrawRect(0, 64, w, 2)
    end

    -- текст (DLabel, чтобы был поверх фона)
    local body = vgui.Create("DLabel", f)
    body:SetPos(30, 78) body:SetSize(500, 110)
    body:SetFont("P11.AB.Text")
    body:SetTextColor(C.text)
    body:SetWrap(true)
    body:SetText("Мы — начинающее общество «Проект Арчи».\nНаша цель — создавать и развивать сервер «ПОЛЮС-11»: военный хоррор-RP по мотивам «Нечто» в Антарктиде.\n\nПрисоединяйся к нам: играй, помогай советами, предлагай идеи — вместе построим лучшую станцию!")

    local hint = vgui.Create("DLabel", f)
    hint:SetPos(30, 192) hint:SetSize(500, 16)
    hint:SetFont("P11.AB.Small") hint:SetTextColor(C.faint)
    hint:SetText("клик по кнопке откроет ссылку в браузере")

    LinkButton(f, 216, "💬 НАШ DISCORD", "заходи, общайся, узнавай новости", C.ds, DISCORD)
    LinkButton(f, 292, "📦 НАША КОЛЛЕКЦИЯ", "желательно скачать — красивые модели станции", C.gold, COLLECTION)

    local foot = vgui.Create("DLabel", f)
    foot:SetPos(30, 378) foot:SetSize(500, 60)
    foot:SetFont("P11.AB.Small") foot:SetTextColor(C.dim)
    foot:SetWrap(true)
    foot:SetText("Коллекция Steam — контент-пак с моделями: без него сервер работает, но с ним игроки видят всех в полном облике. Скачай заранее (кнопка «Подписаться»).")

    local close = vgui.Create("DButton", f)
    close:SetPos(30, 404) close:SetSize(120, 36)
    close:SetText("")
    close.Paint = function(s, ww, hh)
        local hov = s:IsHovered()
        draw.RoundedBox(8, 0, 0, ww, hh, hov and Color(38, 48, 62, 255) or Color(22, 29, 40, 255))
        surface.SetDrawColor(110, 125, 145, 90)
        surface.DrawOutlinedRect(0, 0, ww, hh, 1)
        draw.SimpleText("ЗАКРЫТЬ", "P11.AB.Small", ww / 2, hh / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    close.DoClick = function() f:Remove() end
end

-- =================== КОМАНДА !о нас ===================
hook.Add("OnPlayerChat", "P11.About.Chat", function(ply, text, teamOnly, dead)
    local low = string.lower(string.Trim(text or ""))
    if low == "!о нас" or low == "!проект" or low == "!проект арчи" or low == "!об обществе" then
        P11.OpenAbout()
        return true
    end
end)

-- =================== АВТОПОКАЗ НОВИЧКУ (один раз) ===================
local function ShowNewbie()
    if file.Exists(ABOUT_DONE, "DATA") then return end
    -- ждём, пока не закончится гайд новичка / интро
    timer.Simple(14, function()
        if P11.IntroOpen then return end
        P11.OpenAbout()
        file.Write(ABOUT_DONE, "1")
    end)
end

hook.Add("InitPostEntity", "P11.About.Newbie", ShowNewbie)

print("[POLUS-11] О НАС v5.8.7: кнопка в С-меню, окно «Проект Арчи», Discord + коллекция, !о нас")
