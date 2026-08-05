-- ============================================================
--  POLUS-11 RP — ГЕЙММОД (server bootstrap)
-- ============================================================

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

-- клиенту нужны общие + клиентские модули
local send = {
    "modules/fw_sh_config.lua",
    "modules/fw_sh_jobs.lua",
    "modules/p11_sh_config.lua",
    "modules/p11_sh_core.lua",
    "modules/fw_sh_factions.lua",
    "modules/fw_sh_ranks.lua",
    "modules/fw_cl_f4.lua",
    "modules/fw_cl_punish.lua",
    "modules/fw_cl_admin.lua",
    "modules/p11_cl_hud.lua",
    "modules/p11_cl_vitals.lua",
    "modules/p11_cl_admin.lua",
    "modules/p11_cl_scoreboard.lua",
    "modules/p11_cl_nametags.lua",
    "modules/p11_cl_tasks.lua",
    "modules/p11_cl_panic.lua",
    "modules/p11_cl_propmenu.lua",
    "modules/p11_cl_thinghud.lua",
    "modules/p11_cl_intro.lua",
    "modules/p11_cl_terminal.lua",
    "modules/p11_cl_help.lua",
    "modules/p11_cl_alerts.lua",
    "modules/p11_cl_view.lua",
    "modules/p11_cl_cmenu.lua",
}
for _, f in ipairs(send) do
    AddCSLuaFile(f)
end

include("shared.lua")

util.AddNetworkString("P11_IntroShow")

-- интро при ПЕРВОМ входе за сессию
local introShown = {}
hook.Add("PlayerInitialSpawn", "P11_IntroTrigger", function(ply)
    local sid = ply:SteamID()
    if introShown[sid] then return end
    introShown[sid] = true
    timer.Simple(4, function()
        if IsValid(ply) then
            net.Start("P11_IntroShow")
            net.Send(ply)
        end
    end)
end)

-- ============ СЕРВЕРНЫЕ МОДУЛИ ============

local sv = {
    "modules/fw_sv_jobs.lua",        -- логика профессий
    "modules/fw_sv_factions.lua",    -- фракции из админки (data/*.json)
    "modules/fw_sv_customjobs.lua",  -- профессии из админки (data/*.json)
    "modules/fw_sv_seed_rkka.lua",   -- v3.8.2: авто-сид пресетов РККА/Наука/Нечто
    "modules/fw_sv_npc.lua",         -- NPC-кадровик
    "modules/fw_sv_setup.lua",       -- точки спавна/ареста
    "modules/fw_sv_punish.lua",      -- арест / рабство / бан
    "modules/fw_sv_mod.lua",         -- варны / мут / кик + ворота прав рангов + журнал
    "modules/fw_sv_ranks.lua",       -- ранги + секретный ключ основателя
    "modules/fw_sv_emotes.lua",      -- жесты C-меню + меню моделей админов
    "modules/p11_sv_infection.lua",  -- заражение Нечто
    "modules/p11_sv_power.lua",      -- генератор / топливо / блэкаут
    "modules/p11_sv_bloodtest.lua",  -- анализ крови
    "modules/p11_sv_tasks.lua",      -- сменные задачи
    "modules/p11_sv_admin.lua",      -- админ-пульт Нечто
    "modules/p11_sv_radio.lua",      -- рация
    "modules/p11_sv_persist.lua",    -- сохранение станции
    "modules/p11_sv_nechto.lua",     -- Нечто: классы, крик, формы
    "modules/p11_sv_build.lua",      -- строительство: призрачные пропы
    "modules/p11_sv_terminal.lua",   -- сменный терминал + доп-задачи
    "modules/p11_sv_shadowtasks.lua",-- ложные задачи маскировки Нечто
    "modules/p11_sv_command.lua",    -- приказы командира / розыск / репорты
    "modules/p11_sv_shift.lua",      -- распорядок смены + авто-буря
    "modules/p11_sv_cold.lua",       -- переохлаждение: тепло как ресурс (v3.7)
}

local function Safe(f)
    local ok, err = pcall(include, f)
    if not ok then
        print("[POLUS][ERROR] " .. f .. " -> " .. tostring(err))
    end
    return ok
end

local loaded = 0
for _, f in ipairs(sv) do
    if Safe(f) then loaded = loaded + 1 end
end

-- ============ ИНИЦИАЛИЗАЦИЯ ============

function GM:Initialize()
    self.BaseClass:Initialize()
    print("============================================================")
    print("  POLUS-11 RP | сборка " .. tostring(POLUS_BUILD)
        .. " | P11FW v" .. tostring(P11FW.Version)
        .. " | POLUS11 v" .. tostring(POLUS11.Version))
    print("  Серверные модули: " .. loaded .. "/" .. #sv
        .. " | профессий: " .. (#(P11FW.JobIds or {})))
    print("============================================================")
end

-- баннер при входе игрока
hook.Add("PlayerInitialSpawn", "P11_Banner", function(ply)
    timer.Simple(8, function()
        if IsValid(ply) then
            ply:ChatPrint("[POLUS-11 v" .. tostring(POLUS11.Version) .. "] Станция активна. Админ: !пульт | /r — рация | F4 — должности")
        end
    end)
end)

-- статус-диагностика: polus_status (или старое polus11_status) в консоль
local function PrintStatus(ply)
    local out = {}
    out[#out + 1] = "== POLUS-11 RP | сборка " .. tostring(POLUS_BUILD) .. " =="
    out[#out + 1] = "  P11FW v" .. tostring(P11FW.Version) .. " / POLUS11 v" .. tostring(POLUS11.Version)
    out[#out + 1] = "  карта: " .. game.GetMap() .. " | игроков: " .. player.GetCount()
    for cls in pairs({
        polus11_generator = true, polus11_fuelbarrel = true,
        polus11_labtable = true, polus11_vial = true, polus11_acidspit = true,
        polus_fw_jobnpc = true, polus11_terminal = true,
    }) do
        out[#out + 1] = "  энтити " .. cls .. ": " .. #ents.FindByClass(cls)
    end
    for _, p in ipairs(player.GetAll()) do
        out[#out + 1] = "  • " .. p:Nick()
            .. " [" .. (P11FW.GetJobName and P11FW.GetJobName(p) or "?") .. "]"
            .. (p:GetNWBool("P11_Infected", false)
                and " [НЕЧТО" .. (p:GetNWBool("P11_InfActive", false) and "+актив" or ", инкубация") .. "]"
                or "")
    end
    local text = table.concat(out, "\n")
    if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, text) else print(text) end
end

concommand.Add("polus_status", function(ply) PrintStatus(ply) end)
concommand.Add("polus11_status", function(ply) PrintStatus(ply) end) -- совместимость
