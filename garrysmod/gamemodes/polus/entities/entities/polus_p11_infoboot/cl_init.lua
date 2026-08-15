-- ============================================================
--  ПОЛЮС-11 — КНОПКА «О НАС» + ЧАТ ПРИ ВХОДЕ v5.6.8 (client)
--  Владелец:
--    1) Кнопка «Информация о нас» в C-меню → окно с Discord
--       и коллекцией (сборкой) Steam Workshop.
--    2) При заходе на сервер — сообщение в чат: «для удобства
--       скачайте сборку».
--
--  Ссылки:
--    Discord:    https://discord.gg/fDuSGRJRC3
--    Коллекция:  https://steamcommunity.com/sharedfiles/filedetails/?id=3777625029
--
--  Доставка: cl_init энтити (спавнится сервером) — гарантированно
--  уходит клиентам (не зависит от sv_allowcslua). Старые файлы
--  не трогаем — добавляем кнопку ПОВЕРХ C-меню (обёртка OpenCMenu).
-- ============================================================

local DISCORD_URL = "https://discord.gg/fDuSGRJRC3"
local COLLECTION_URL = "https://steamcommunity.com/sharedfiles/filedetails/?id=3777625029"

local function Safe(fn, name)
    local ok, err = pcall(fn)
    if not ok then print("[POLUS-11][О НАС] " .. (name or "?") .. ": " .. tostring(err)) end
end

-- ================= 1) ОКНО «О НАС» =================
local function OpenAbout()
    if IsValid(P11.AboutFrame) then P11.AboutFrame:Remove() end

    local W, H = 540, 380
    local f = vgui.Create("DFrame")
    P11.AboutFrame = f
    f:SetSize(W, H)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false) f.btnMaxim:SetVisible(false) f.btnMinim:SetVisible(false)
    f.T0 = SysTime()
    f.Paint = function(s, w, h)
        Derma_DrawBackgroundBlur(s, s.T0)
        draw.RoundedBox(8, 0, 0, w, h, Color(10, 14, 20, 248))
        draw.RoundedBoxEx(8, 0, 0, w, 56, Color(30, 36, 46, 255), true, true, false, false)
        surface.SetDrawColor(210, 60, 50)
        surface.DrawRect(0, 56, w, 3)
        surface.SetDrawColor(238, 202, 108)
        surface.DrawRect(0, 59, w, 1)
        draw.SimpleText("ПОЛЮС-11 — О НАС", "DermaDefaultBold", 16, 18, Color(255, 205, 100))
        draw.SimpleText("закрытая полярная станция · 1982 · The Thing RP", "DermaDefault", 16, 38, Color(150, 158, 172))
    end
    f.OnKeyCodePressed = function(s, key)
        if key == KEY_ESCAPE then s:Remove() end
    end

    local xb = vgui.Create("DButton", f)
    xb:SetPos(W - 38, 12) xb:SetSize(26, 26) xb:SetText("X")
    xb:SetTextColor(Color(150, 158, 172))
    xb.Paint = function() end
    xb.DoClick = function() f:Remove() end

    -- описание
    local desc = vgui.Create("DLabel", f)
    desc:SetPos(20, 70) desc:SetSize(W - 40, 90)
    desc:SetTextColor(Color(220, 226, 235))
    desc:SetWrap(true)
    desc:SetText("Среди нас — НЕЧТО. Оно ест людей и копирует их лица, голоса, имена. Кто-то уже не тот, за кого себя выдаёт. Тест крови, допросы НКВД, холод и тьма. Доверяй только огню.")

    -- кнопки
    local bDc = vgui.Create("DButton", f)
    bDc:SetPos(20, 180) bDc:SetSize(W - 40, 52) bDc:SetText("")
    bDc.Paint = function(s, w, h)
        local hv = s:IsHovered()
        draw.RoundedBox(6, 0, 0, w, h, hv and Color(88, 101, 242, 235) or Color(58, 68, 160, 235))
        surface.SetDrawColor(150, 160, 250, 160)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("DISCORD — НАШ ЧАТ", "DermaDefaultBold", w / 2, h / 2 - 7, Color(240, 242, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("новости, ивенты, идеи, баги", "DermaDefault", w / 2, h / 2 + 12, Color(190, 200, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    bDc.DoClick = function()
        gui.OpenURL(DISCORD_URL)
        surface.PlaySound("buttons/button15.wav")
    end

    local bCol = vgui.Create("DButton", f)
    bCol:SetPos(20, 240) bCol:SetSize(W - 40, 52) bCol:SetText("")
    bCol.Paint = function(s, w, h)
        local hv = s:IsHovered()
        draw.RoundedBox(6, 0, 0, w, h, hv and Color(102, 178, 92, 235) or Color(66, 120, 60, 235))
        surface.SetDrawColor(150, 220, 140, 160)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("КОЛЛЕКЦИЯ (СБОРКА) — СКАЧАТЬ", "DermaDefaultBold", w / 2, h / 2 - 7, Color(240, 255, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("подпишись, чтобы всё грузилось удобно", "DermaDefault", w / 2, h / 2 + 12, Color(190, 230, 185), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    bCol.DoClick = function()
        gui.OpenURL(COLLECTION_URL)
        surface.PlaySound("buttons/button15.wav")
    end

    local bClose = vgui.Create("DButton", f)
    bClose:SetPos(20, 306) bClose:SetSize(W - 40, 40) bClose:SetText("ЗАКРЫТЬ")
    bClose.SetTextColor(bClose, Color(220, 226, 235))
    bClose.DoClick = function() f:Remove() end
end

-- ================= 2) КНОПКА В C-МЕНЮ =================
local function AddCMenuButton()
    if not P11 then return end
    local origOpen = P11.OpenCMenu
    P11.OpenCMenu = function(...)
        if origOpen then origOpen(...) end
        -- после открытия добавляем кнопку «О НАС» ПОВЕРХ меню (низ, тонкая строка)
        local f = P11.CMenu
        if not IsValid(f) then return end
        local W = f:GetWide()
        local H = f:GetTall()
        local btn = vgui.Create("DButton", f)
        btn:SetPos(14, H - 12) btn:SetSize(W - 28, 11) btn:SetText("")
        btn.Paint = function(s, w, h)
            local hv = s:IsHovered()
            surface.SetDrawColor(238, 202, 108, hv and 120 or 50)
            surface.DrawRect(0, 0, w, h)
            draw.SimpleText("ℹ ИНФОРМАЦИЯ О НАС — DISCORD · КОЛЛЕКЦИЯ", "DermaDefault",
                w / 2, h / 2, hv and Color(255, 220, 140) or Color(190, 200, 215),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            surface.PlaySound("buttons/button14.wav")
            OpenAbout()
        end
    end
end

-- ================= 3) ЧАТ-СООБЩЕНИЕ ПРИ ЗАХОДЕ (раз за сессию) =================
local welcomeShown = false

local function WelcomeMsg()
    if welcomeShown then return end
    welcomeShown = true
    local me = LocalPlayer()
    if not IsValid(me) then return end
    chat.AddText(Color(255, 205, 100), "[ПОЛЮС-11] ", Color(232, 238, 245),
        "Добро пожаловать на станцию! Для удобства скачай СБОРКУ: ",
        Color(150, 210, 255), "steamcommunity.com/sharedfiles/filedetails/?id=3777625029",
        Color(232, 238, 245), " · Наш Discord: ", Color(150, 210, 255), "discord.gg/fDuSGRJRC3")
    chat.AddText(Color(232, 238, 245),
        "Кнопка «ИНФОРМАЦИЯ О НАС» — в C-меню (клавиша C). Приятной вахты!")
end

-- ================= 4) ПРИМЕНЕНИЕ ПОСЛЕ ГЕЙММОДА =================
local function ApplyAll()
    Safe(AddCMenuButton, "кнопка в C-меню")
end

hook.Add("PostGamemodeLoaded", "P11.Info568", function()
    timer.Simple(0, ApplyAll)
    timer.Simple(1, ApplyAll)
    timer.Simple(2, ApplyAll)
end)
hook.Add("InitPostEntity", "P11.Info568b", function()
    timer.Simple(1, ApplyAll)
    -- чат-приветствие с задержкой (после загрузки)
    timer.Simple(12, WelcomeMsg)
    timer.Simple(25, WelcomeMsg) -- страховка (если загрузка долгая)
end)
timer.Simple(0, ApplyAll)
timer.Simple(1, ApplyAll)
timer.Simple(2, ApplyAll)

print("[POLUS-11] О НАС v5.6.8 активен: кнопка в C-меню + чат при входе (Discord + сборка)")
