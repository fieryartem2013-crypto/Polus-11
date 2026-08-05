-- ============================================================
--  POLUS-11 RP — ГЕЙММОД (client bootstrap)
-- ============================================================

include("shared.lua")

local cl = {
    "modules/fw_cl_f4.lua",        -- F4-меню профессий
    "modules/fw_cl_punish.lua",    -- красный плакат наказания
    "modules/fw_cl_admin.lua",     -- админ-меню P11FW
    "modules/p11_cl_hud.lua",      -- HUD станции (фазы, улей, тест крови)
    "modules/p11_cl_vitals.lua",   -- HUD жизни: HP / броня / патроны / тосты
    "modules/p11_cl_admin.lua",    -- пульт Нечто (клиент)
    "modules/p11_cl_scoreboard.lua", -- TAB-табло
    "modules/p11_cl_nametags.lua", -- ники/должности над головами
    "modules/p11_cl_tasks.lua",    -- виджет задач
    "modules/p11_cl_panic.lua",    -- эффекты паники
    "modules/p11_cl_propmenu.lua", -- только вкладка «Пропы» не-админам
    "modules/p11_cl_thinghud.lua", -- HUD Нечто (форма/маскировка/кулдауны)
    "modules/p11_cl_intro.lua",    -- интро-заставка станции
    "modules/p11_cl_terminal.lua", -- меню сменного терминала
    "modules/p11_cl_help.lua",     -- F1-справка новичка
    "modules/p11_cl_alerts.lua",   -- приказ-баннер / метель / розыск / распорядок
}

local loaded = 0
for _, f in ipairs(cl) do
    local ok, err = pcall(include, f)
    if ok then
        loaded = loaded + 1
    else
        print("[POLUS][ERROR] " .. f .. " -> " .. tostring(err))
    end
end

-- скрываем стандартный HL2-HUD (у станции свой HUD)
local hidden = {
    CHudHealth = true,
    CHudBattery = true,
    CHudAmmo = true,
    CHudSecondaryAmmo = true,
    CHudDamageIndicator = true,
    CHudSuitPower = true,
}
hook.Add("HUDShouldDraw", "P11GM.HideDefaultHUD", function(name)
    if hidden[name] then return false end
end)

print("[POLUS-11 RP v" .. tostring(POLUS_BUILD) .. "] Клиент: "
    .. loaded .. "/" .. #cl .. " модулей. F4 — должности, TAB — состав.")
