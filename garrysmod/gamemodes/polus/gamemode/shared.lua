-- ============================================================
--  POLUS-11 RP — ГЕЙММОД (shared) — сборка 3.4 (ЗАТ)
--  Единая сборка: ПОЛЮС FRAMEWORK v1.6 (профессии, F4, админка
--  с МОДЕРАЦИЕЙ по рангам, наказания, варны/мут/кик/бан,
--  журнал действий) + ПОЛЮС-11 v2.8 (Нечто, заражение, энергия,
--  рация, анализ крови, задачи, паника, HUD жизни, кино-интро).
--  Держится ТОЛЬКО на стоковом контенте HL2/GMod — воркшоп не нужен.
--  Ошибки загрузки смотри в консоли: [POLUS][ERROR]
-- ============================================================

GM.Name    = "POLUS-11 RP"
GM.Author  = "POLUS-11 Dev"
GM.Email   = ""
GM.Website = "https://github.com/fieryartem2013-crypto/polus-11"

DeriveGamemode("sandbox")

-- версии (в аддон-версии лежали в autorun-загрузчиках)
P11FW = P11FW or {}
P11FW.Version = "1.6.0"

POLUS11 = POLUS11 or {}
POLUS11.Version = "2.9"

POLUS_BUILD = "3.5" -- версия сборки-гейммода

-- ============ ОБЩИЕ МОДУЛИ (shared) ============

local sh = {
    "modules/fw_sh_config.lua",   -- конфиг фреймворка
    "modules/fw_sh_jobs.lua",     -- профессии / команды
    "modules/fw_sh_factions.lua",  -- фракции (расширенные категории)
    "modules/fw_sh_ranks.lua",     -- ранги администрации (User..Глава Полюса-11)
    "modules/p11_sh_config.lua",  -- конфиг ПОЛЮС-11
    "modules/p11_sh_core.lua",    -- общая логика Нечто/заражения
}
for _, f in ipairs(sh) do
    local ok, err = pcall(include, f)
    if not ok then
        print("[POLUS][ERROR] " .. f .. " -> " .. tostring(err))
    end
end

-- ============ ПОВЕДЕНИЕ ПЕСОЧНИЦЫ -> RP ============

local function IsPolusAdmin(ply)
    if not (P11FW and P11FW.Config and P11FW.Config.Admin) then return false end
    if not IsValid(ply) then return false end
    return P11FW.Config.Admin(ply) and true or false
end

--- Модель игрока = модель должности (не из Q-меню).
function GM:PlayerSetModel(ply)
    if P11FW.GetJob and P11FW.ValidModels then
        local job = P11FW.GetJob(ply)
        local models = job and P11FW.ValidModels(job) or nil
        local m = models and models[1]
        if m then
            util.PrecacheModel(m)
            ply:SetModel(m)
            return
        end
    end
    self.BaseClass:PlayerSetModel(ply)
end

--- Лоадаут: фреймворк раздаёт всё сам (P11FW.ApplyLoadout
--- по хуку PlayerSpawn с задержкой 0.1 c — профессия + админ-инструменты).
function GM:PlayerLoadout(ply)
    ply:RemoveAllAmmo()
    return true
end

--- Спавн энтити/оружия/NPC и инструменты из меню — только админам.
--- (Пропы обрабатываются ОТДЕЛЬНО ниже — игрокам разрешён вайтлист;
--- станционные предметы не страдают: они создаются сервером через
--- ents.Create в командах, а не через эти хуки.)
local adminOnlyHooks = {
    "PlayerSpawnRagdoll", "PlayerSpawnEffect",
    "PlayerSpawnVehicle", "PlayerSpawnNPC",
    "PlayerSpawnSENT", "PlayerSpawnSWEP", "PlayerGiveSWEP",
    "CanTool", "CanProperty", "CanEditVariable", "CanDrive",
}
for _, hookName in ipairs(adminOnlyHooks) do
    GM[hookName] = function(self, ply)
        return IsPolusAdmin(ply)
    end
end

--- ПРОПЫ для всех: не-админам — только модели из вайтлиста
--- (POLUS11.Config.Building.AllowedProps). Дальше их призраками
--- занимается модуль p11_sv_build.lua.
function GM:PlayerSpawnProp(ply, model)
    if IsPolusAdmin(ply) then return true end
    local b = POLUS11.Config and POLUS11.Config.Building
    if not (b and b.Enabled and b.AllowedProps) then return false end
    model = string.lower(tostring(model or ""))
    if b.AllowedProps[model] then return true end
    if IsValid(ply) then
        ply:ChatPrint("[Склад] Этот предмет недоступен обычному персоналу.")
    end
    return false
end

--- Лимиты спавна: админам — без потолка, игрокам — только пропы
--- и не больше MaxPerPlayer (остальное всегда «limit reached»).
function GM:PlayerCheckLimit(ply, name, current, defaultMax)
    if IsPolusAdmin(ply) then return true end
    if name == "props" then
        local b = POLUS11.Config and POLUS11.Config.Building
        local max = (b and b.MaxPerPlayer) or 8
        if current >= max then return false end
        return true
    end
    return false
end

--- Q-меню открыто всем (игрокам нужна вкладка «Пропы» для строительства;
--- лишние вкладки прячет клиентский модуль p11_cl_propmenu.lua,
--- а сервер сам режет запрещённые спавны).
function GM:SpawnMenuOpen(ply)   return true end
--- C-меню (инструменты/контекст) — только админам.
function GM:ContextMenuOpen(ply) return IsPolusAdmin(ply) end

--- Ноуклип — только админам.
function GM:PlayerNoClip(ply, on)
    return IsPolusAdmin(ply)
end

--- Физган есть у всех (v2.7), но не-админ может поднимать ТОЛЬКО свои
--- призрачные пропы — чужие твёрдые, мировые и игроков нельзя.
--- Игроков вообще таскает только суперадмин.
function GM:PhysgunPickup(ply, ent)
    if not IsValid(ent) then return false end
    if IsPolusAdmin(ply) then
        if ent:IsPlayer() then return ply:IsSuperAdmin() end
        return true
    end
    if ent.P11_Ghost and ent.P11_GhostOwner == ply then return true end
    return false
end

--- Фонарик разрешён всем — на тёмной станции это базовая потребность.
function GM:PlayerSwitchFlashlight(ply, on)
    if not IsValid(ply) then return false end
    return true
end

--- Суицид запрещён арестованным/рабам (обход наказания).
function GM:CanPlayerSuicide(ply)
    if not IsValid(ply) then return false end
    local pun = ply:GetNWString("P11FW_Punish", "")
    if pun == "arrest" or pun == "slavery" then return false end
    return true
end
