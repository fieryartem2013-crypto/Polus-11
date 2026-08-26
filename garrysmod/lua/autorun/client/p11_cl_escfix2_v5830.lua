-- ============================================================
--  ПОЛЮС-11 — ЗАДАЧА 2 ИЗ ТЗ: ESC И E-МЕНЮ, ВОЗВРАТ УПРАВЛЕНИЯ
--  v5.8.30 (НОВЫЙ ФАЙЛ, autorun/client)
-- ============================================================
--  ТЗ: Esc в E-меню закрывает меню и ПОЛНОСТЬЮ возвращает управление
--  (движение, инвентарь, другие меню, взаимодействие с миром).
--  Состояния «интерфейс завис, работает только Alt+F4» быть не должно.
--
--  КОРЕНЬ: E-меню (entities/polus_p11_emenu/cl_init.lua) делает
--      p:MakePopup()               -- курсор + перехват клавиатуры
--      ...
--      CloseMenu(): MENU.panel:Remove()
--  MakePopup включает экранный курсор, а Remove() его НЕ выключает.
--  В итоге панель исчезла, а курсор и перехват ввода остались: WASD не
--  идёт, другие меню не открываются, выход — только Alt+F4.
--
--  ЧТО ДЕЛАЕМ (файл E-меню не трогаем):
--    1) СТОРОЖ: запоминаем полноэкранный не-DFrame слой (это и есть
--       подложка E-меню). Как только он пропал — принудительно
--       возвращаем ввод: курсор off, фокус снят, залипшие кнопки отпущены.
--    2) Если курсор виден, а живых панелей нет — отпускаем его же.
--    3) Убираем хук v5.8.28 «OnPauseMenuShow -> false»: он блокировал
--       меню паузы, из-за чего Alt+F4 и оставался единственным выходом.
--       Наш хук меню паузы НЕ блокирует.
--    4) Esc обрабатывается и «в лоб»: пока слой живой, вешаем на него
--       свой OnKeyCodePressed поверх штатного — закрыл меню, сразу вернули ввод.
--    5) Диагностика: p11_escdiag (состояние ввода), p11_escfix 0 (выключить сторожа).
--
--  Откат: удалить файл или p11_escfix 0.
-- ============================================================

local cvOn = CreateClientConVar("p11_escfix", "1", true, false,
    "POLUS-11 v5.8.30: сторож возврата ввода после Esc/E-меню (0 = выключить)")

local LastOverlay = nil
local LastAt = 0
local UnlockCount = 0

-- ============ СОСТОЯНИЕ ВВОДА ============
local function CursorOn()
    return vgui and vgui.CursorVisible and vgui.CursorVisible() or false
end

local function GameUIOn()
    return gui and gui.IsGameUIVisible and gui.IsGameUIVisible() or false
end

local function ConsoleOn()
    return gui and gui.IsConsoleVisible and gui.IsConsoleVisible() or false
end

local function AnyLivePanel()
    -- есть ли хоть одна видимая панель, которой нужна мышь
    local world = vgui.GetWorldPanel and vgui.GetWorldPanel()
    if not IsValid(world) then return false end
    local kids = world.GetChildren and world:GetChildren() or {}
    for _, ch in ipairs(kids) do
        if IsValid(ch) and ch.IsVisible and ch:IsVisible()
            and ch.IsMouseInputEnabled and ch:IsMouseInputEnabled() then
            return true
        end
    end
    return false
end

--- Полный возврат управления игроку.
local function UnlockInput(reason)
    UnlockCount = UnlockCount + 1
    if gui and gui.EnableScreenClicker then gui.EnableScreenClicker(false) end

    local focus = vgui.GetKeyboardFocus and vgui.GetKeyboardFocus()
    if IsValid(focus) and focus ~= vgui.GetWorldPanel() then
        pcall(function() focus:SetKeyboardInputEnabled(false) end)
    end

    -- меню паузы НЕ глушим: по ТЗ оно должно оставаться доступным выходом
    if not GameUIOn() and gui and gui.HideGameUI then
        -- ничего не делаем: HideGameUI нужен только если пауза залипла без панелей
    end

    local me = LocalPlayer()
    if IsValid(me) and me.ConCommand then
        -- отпустить залипшие кнопки (курсор съедал keyup)
        me:ConCommand("-attack")
        me:ConCommand("-attack2")
        me:ConCommand("-use")
        me:ConCommand("-speed")
    end

    if reason and (CurTime() - LastAt) > 1 then
        LastAt = CurTime()
        chat.AddText(Color(120, 200, 255), "[ПОЛЮС-11] ",
            Color(215, 225, 235), "Управление восстановлено (" .. tostring(reason) .. ").")
    end
end

-- ============ ПОИСК ПОДЛОЖКИ E-МЕНЮ ============
local function FindOverlay()
    local world = vgui.GetWorldPanel and vgui.GetWorldPanel()
    if not IsValid(world) then return nil end
    local kids = world.GetChildren and world:GetChildren() or {}
    local sw, sh = ScrW(), ScrH()
    for _, ch in ipairs(kids) do
        if IsValid(ch) and ch:IsVisible() then
            local w, h = 0, 0
            if ch.GetSize then w, h = ch:GetSize() end
            -- полноэкранный слой, но НЕ DFrame (админку/F4/донат не трогаем)
            if w >= sw - 4 and h >= sh - 4 and ch.SetTitle == nil then
                return ch
            end
        end
    end
    return nil
end

--- Вешаем свой обработчик Esc поверх штатного (не ломая его).
local function GuardEsc(p)
    if not IsValid(p) then return end
    if rawget(p, "P11_EscGuard") then return end
    local orig = p.OnKeyCodePressed
    p.OnKeyCodePressed = function(s, key)
        if orig then pcall(orig, s, key) end
        if key == KEY_ESCAPE then
            -- меню уже закрыто штатным обработчиком — возвращаем ввод СРАЗУ
            UnlockInput("Esc")
        end
    end
    rawset(p, "P11_EscGuard", true)
end

-- ============ СТОРОЖ ============
hook.Add("Think", "P11.EscFix2.Watchdog.v5830", function()
    if cvOn:GetInt() == 0 then return end

    local cur = FindOverlay()

    -- слой только что исчез (Esc / клик / действие) — вот тут и залипал курсор.
    -- AnyLivePanel() — защита от регрессии: если открыта админка/F4/донат
    -- (DFrame), курсор трогать нельзя, иначе меню станет некликабельным.
    if LastOverlay and not IsValid(LastOverlay) and not cur and not AnyLivePanel() then
        UnlockInput("закрыто E-меню")
    end
    if cur then GuardEsc(cur) end
    LastOverlay = cur

    -- страховка: курсор виден, а живых панелей нет и паузы нет
    if not cur and CursorOn() and not GameUIOn() and not ConsoleOn() and not AnyLivePanel() then
        UnlockInput("залипший курсор")
    end
end)

-- ============ МЕНЮ ПАУЗЫ ДОЛЖНО ОТКРЫВАТЬСЯ ============
-- v5.8.28 возвращал из OnPauseMenuShow false и глушил меню паузы —
-- именно поэтому выходом оставался Alt+F4. Снимаем тот хук и ставим свой,
-- который ввод восстанавливает, но меню паузы НЕ блокирует.
local function DropOldPauseHook()
    if hook.GetTable and hook.GetTable().OnPauseMenuShow
        and hook.GetTable().OnPauseMenuShow["P11.EscFix.v5828"] then
        hook.Remove("OnPauseMenuShow", "P11.EscFix.v5828")
        print("[POLUS-11] v5.8.30: снят блокиратор меню паузы от v5.8.28")
    end
end

hook.Add("OnPauseMenuShow", "P11.EscFix2.Pause.v5830", function()
    DropOldPauseHook()
    local overlay = FindOverlay()
    if IsValid(overlay) then
        overlay:Remove()          -- Esc закрывает E-меню
        UnlockInput("Esc -> меню паузы")
    elseif CursorOn() and not AnyLivePanel() then
        UnlockInput("залипший курсор")
    end
    -- возвращаем nil: меню паузы открывается штатно
end)

hook.Add("PostGamemodeLoaded", "P11.EscFix2.v5830", function()
    timer.Simple(0, DropOldPauseHook)
    timer.Simple(2, DropOldPauseHook)
end)
hook.Add("InitPostEntity", "P11.EscFix2.v5830", function()
    timer.Simple(1, DropOldPauseHook)
    timer.Simple(6, DropOldPauseHook)
end)

-- ============ ДИАГНОСТИКА ============
concommand.Add("p11_escdiag", function()
    local overlay = FindOverlay()
    local lines = {
        "[ESC-DIAG] v5.8.30",
        "  курсор виден ........... " .. tostring(CursorOn()),
        "  меню паузы движка ...... " .. tostring(GameUIOn()),
        "  консоль ............... " .. tostring(ConsoleOn()),
        "  живых панелей с мышью .. " .. tostring(AnyLivePanel()),
        "  подложка E-меню ....... " .. tostring(IsValid(overlay)),
        "  сторож включён ........ " .. tostring(cvOn:GetInt() ~= 0),
        "  возвратов ввода всего . " .. tostring(UnlockCount),
    }
    local focus = vgui.GetKeyboardFocus and vgui.GetKeyboardFocus()
    lines[#lines + 1] = "  фокус клавиатуры ...... " ..
        (IsValid(focus) and tostring(focus.ClassName or focus:GetName() or "panel") or "нет")
    local txt = table.concat(lines, "\n")
    chat.AddText(Color(120, 200, 255), txt)
    print(txt)
end)

-- принудительно вернуть управление руками (если что-то всё же залипло)
concommand.Add("p11_escunlock", function()
    UnlockInput("по команде p11_escunlock")
    chat.AddText(Color(120, 200, 255), "[ПОЛЮС-11] ", Color(215, 225, 235),
        "Ввод разблокирован вручную. Диагностика: p11_escdiag")
end)

print("[POLUS-11] v5.8.30: ЗАДАЧА 2 ТЗ — Esc/E-меню возвращает управление, "
    .. "меню паузы больше не блокируется (p11_escdiag / p11_escunlock)")
