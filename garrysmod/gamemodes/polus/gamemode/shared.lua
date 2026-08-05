-- ============================================================
--  POLUS-11 RP — ГЕЙММОД (shared)
--  Единая сборка: ПОЛЮС FRAMEWORK v1.3 (профессии, F4, админка,
--  наказания) + ПОЛЮС-11 v2.4 (Нечто, заражение, энергия, рация,
--  анализ крови, задачи, паника).
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
P11FW.Version = "1.3.0"

POLUS11 = POLUS11 or {}
POLUS11.Version = "2.4"

POLUS_BUILD = "3.0" -- версия сборки-гейммода

-- ============ ОБЩИЕ МОДУЛИ (shared) ============

local sh = {
    "modules/fw_sh_config.lua",   -- конфиг фреймворка
    "modules/fw_sh_jobs.lua",     -- профессии / команды
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

--- Спавн пропов/энтити/оружия из меню — только админам.
--- (Станционные предметы НЕ страдают: они создаются сервером
--- через ents.Create в командах, а не через этот хук.)
local adminOnlyHooks = {
    "PlayerSpawnProp", "PlayerSpawnRagdoll", "PlayerSpawnEffect",
    "PlayerSpawnVehicle", "PlayerSpawnNPC", "PlayerSpawnObject",
    "PlayerSpawnSENT", "PlayerSpawnSWEP", "PlayerGiveSWEP",
    "CanTool", "CanProperty", "CanEditVariable", "CanDrive",
}
for _, hookName in ipairs(adminOnlyHooks) do
    GM[hookName] = function(self, ply)
        return IsPolusAdmin(ply)
    end
end

--- Q-меню и C-меню — только админам (там инструменты настройки карты).
function GM:SpawnMenuOpen(ply)   return IsPolusAdmin(ply) end
function GM:ContextMenuOpen(ply) return IsPolusAdmin(ply) end

--- Ноуклип — только админам.
function GM:PlayerNoClip(ply, on)
    return IsPolusAdmin(ply)
end

--- Физган (выдаётся только админам): чужих игроков таскает только суперадмин.
function GM:PhysgunPickup(ply, ent)
    if not IsPolusAdmin(ply) then return false end
    if IsValid(ent) and ent:IsPlayer() then
        return ply:IsSuperAdmin()
    end
    return true
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
