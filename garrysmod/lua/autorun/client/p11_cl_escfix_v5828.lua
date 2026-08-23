-- ============================================================
--  ПОЛЮС-11 — ESC / E-МЕНЮ: РАЗБЛОКИРОВКА ВВОДА v5.8.28
--  (НОВЫЙ ФАЙЛ, autorun/client)
--  Проблема: Esc закрывает E-меню (MakePopup на весь экран),
--  но курсор/фокус остаются — двигаться нельзя, только Alt+F4.
--  Лечим: гасим паузу движка, снимаем clicker, убиваем
--  осиротевшие полноэкранные DPanel.
-- ============================================================

local function UnlockInput()
    if gui.EnableScreenClicker then gui.EnableScreenClicker(false) end
    if gui.HideGameUI then gui.HideGameUI() end
    local me = LocalPlayer()
    if IsValid(me) then
        -- на всякий: вернуть управление WASD
        me:ConCommand("-attack")
    end
end

local function KillOrphanPopups()
    local world = vgui.GetWorldPanel and vgui.GetWorldPanel()
    if not IsValid(world) then return false end
    local sw, sh = ScrW(), ScrH()
    local killed = false
    for _, ch in ipairs(world:GetChildren()) do
        if IsValid(ch) and ch:IsVisible() then
            local w, h = ch:GetWide(), ch:GetTall()
            -- полноэкранный прозрачный слой E-меню (DPanel + MakePopup)
            local cls = ch.ClassName or ch:GetName() or ""
            if w >= sw - 4 and h >= sh - 4 then
                local isFrame = ch.SetTitle ~= nil -- DFrame (админка / F4) — не трогаем здесь
                if not isFrame then
                    ch:Remove()
                    killed = true
                end
            end
        end
    end
    return killed
end

-- Esc по E-меню не должен оставлять игрока в «паузе без выхода»
hook.Add("OnPauseMenuShow", "P11.EscFix.v5828", function()
    local killed = KillOrphanPopups()
    -- если только что закрыли попап — не пускать в меню паузы в этот кадр
    if killed then
        UnlockInput()
        return false
    end
end)

-- страховка: после любого Esc снимаем залипший курсор
hook.Add("Think", "P11.EscFix.Unlock.v5828", function()
    if not input or not input.IsKeyDown then return end
    if not input.IsKeyDown(KEY_ESCAPE) then return end
    -- не орём каждый кадр удержания
    local now = CurTime()
    if (P11_EscFixNext or 0) > now then return end
    P11_EscFixNext = now + 0.15
    KillOrphanPopups()
    UnlockInput()
end)

-- залипший курсор без фокуса (классика MakePopup)
hook.Add("Think", "P11.EscFix.Clicker.v5828", function()
    if not vgui or not vgui.CursorVisible then return end
    if not vgui.CursorVisible() then return end
    if gui.IsGameUIVisible and gui.IsGameUIVisible() then return end
    if gui.IsConsoleVisible and gui.IsConsoleVisible() then return end
    local focus = vgui.GetKeyboardFocus and vgui.GetKeyboardFocus()
    if IsValid(focus) then return end
    -- курсор виден, фокуса нет, паузы нет — отпускаем
    if gui.EnableScreenClicker then gui.EnableScreenClicker(false) end
end)

print("[POLUS-11] v5.8.28: Esc E-меню — ввод восстанавливается")
