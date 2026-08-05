-- ============================================================
--  POLUS-11 RP — ГЕЙММОД (shared) — сборка 3.9 (ЗАТ, «КАДРЫ СТАНЦИИ»)
--  Единая сборка: ПОЛЮС FRAMEWORK v1.9 + ПОЛЮС-11 v3.2
--  (Нечто, заражение, энергия, рация, кровь, задачи, холод,
--  профессии, F4, модерация по рангам v1.9, C-меню, 3-е лицо F2,
--  авто-сид пресетов РККА/НКВД/Наука/Нечто).
--  Стоковый контент HL2/GMod — воркшоп необязателен
--  (паки моделей подключаются через P11FW.Config.WorkshopAddons).
--  Ошибки загрузки смотри в консоли: [POLUS][ERROR]
-- ============================================================

GM.Name    = "POLUS-11 RP"
GM.Author  = "POLUS-11 Dev"
GM.Email   = ""
GM.Website = "https://github.com/fieryartem2013-crypto/polus-11"

DeriveGamemode("sandbox")

-- версии (в аддон-версии лежали в autorun-загрузчиках)
P11FW = P11FW or {}
P11FW.Version = "1.9.0"

POLUS11 = POLUS11 or {}
POLUS11.Version = "3.2"

POLUS_BUILD = "3.9.0" -- версия сборки-гейммода (v3.9: кадры, модели-фикс, вакансия Нечто, С-меню для всех)

-- ============ ОБЩИЕ МОДУЛИ (shared) ============

local sh = {
    "modules/fw_sh_config.lua",   -- конфиг фреймворка
    "modules/fw_sh_jobs.lua",     -- профессии / команды
    "modules/fw_sh_factions.lua",  -- фракции (расширенные категории)
    "modules/fw_sh_ranks.lua",     -- ранги администрации (User..Глава Проекта, v1.9)
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
--- C-меню песочницы ЗАМЕНЕНО (v3.0): на C — станционное меню
--- жестов/действий (p11_cl_cmenu.lua). v3.8: хук ContextMenuOpen
--- больше НЕ блокирует: раньше из-за return false движок рубил ВСЮ
--- цепочку +menu_context на корню и наше меню не открывалось у части
--- билдов. Теперь ванильное окно глушится перекрытием клиентского
--- GM:OnContextMenuOpen (сам дёргает наше меню), а этот шлюз — открыт,
--- чтобы нативный путь C гарантированно доезжал до нашего меню.
--- Инструменты песочницы по-прежнему живут в Q-меню.
function GM:ContextMenuOpen(ply) return true end

--- v3.7: стандартный ТАБ песочницы ПОЛНОСТЬЮ отключён —
--- своё табло живёт в modules/p11_cl_scoreboard.lua и само
--- реагирует на +showscores. Если только цепляться хуком,
--- sandbox-скорборд рисуется ПОВЕРХ нашего (баг «ваниль поверх»).
function GM:ScoreboardShow() return true end
function GM:ScoreboardHide() return true end

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

-- ============================================================
--  v3.8.1: ТЕМП СТАНЦИИ И АНТИ-БАННИХОП (shared для предсказания)
--  Ходьба медленнее, разбег скромнее, прыжок ниже, а набранный по
--  бхоп-цепочке импульс гасится при приземлении (скорость в полёте
--  > разбега → обрезается до разбега ×1.1). Величины — в
--  POLUS11.Config.Movement (модули их же используют).
-- ============================================================

local function MoveCfg()
    local m = POLUS11.Config and POLUS11.Config.Movement or nil
    return (m and m.walk) or 170, (m and m.run) or 330,
           (m and m.jump) or 120, (m and m.antiBhop ~= false)
end

function POLUS11.ApplyMoveSpeeds(ply)
    if not IsValid(ply) then return end
    local w, r, j = MoveCfg()
    ply:SetWalkSpeed(w)
    ply:SetRunSpeed(r)
    ply:SetJumpPower(j)
end

hook.Add("PlayerSpawn", "P11.MoveSpeeds", function(ply)
    -- после фреймворковского лоадаута, чтобы поверх не перетёрли
    timer.Simple(0.15, function()
        if IsValid(ply) and ply:Alive() then POLUS11.ApplyMoveSpeeds(ply) end
    end)
end)

hook.Add("OnPlayerHitGround", "P11.AntiBhop", function(ply, inWater, onFloater)
    if inWater or onFloater then return end
    local _, r, _, allow = MoveCfg()
    if not allow then return end
    local v = ply:GetVelocity()
    local h = math.sqrt(v.x * v.x + v.y * v.y)
    local cap = r * 1.1
    if h > cap then
        -- обрезка горизонтали до разбега (цепочка прыжков «честная»)
        local k = cap / h
        ply:SetVelocity(Vector(-v.x * (1 - k), -v.y * (1 - k), 0))
    end
end)
