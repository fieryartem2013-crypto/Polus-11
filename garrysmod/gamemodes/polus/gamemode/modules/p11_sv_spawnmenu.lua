-- ============================================================
--  ПОЛЮС-11 — ЭКРАН ВЕРБОВКИ (server) v4.6.0 «ВЕРБОВКА»
--  Игрок САМ выбирает ФРАКЦИЮ и ПРОФЕССИЮ при спавне:
--   • через ~11 сек после первого захода (после анкеты и заставки
--     колонны) открывается полноэкранное меню выбора — клиентская
--     часть p11_cl_spawnmenu.lua;
--   • открыть снова: чат !смена / !выбор / !вербовка, консоль
--     p11_spawnmenu;
--   • пока меню открыто — боец заморожен (не бегает: «проверка
--     документов»). Разморозка: закрыл меню (Done) или занял
--     должность (JobChanged) — последнее и есть «прибыл».
--   • выбор идёт через штатный P11FW_TakeJob, поэтому ВСЕ гейты
--     работают: 🔒 вайтлист, ⏳ время игры, занятые места. Отказ
--     придёт обычным уведомлением — выбери другую должность.
--  Верх файла — две настройки автопоказа.
-- ============================================================

local AUTOJOIN_DELAY = 11   -- секунд до автопоказа после первого захода
local FREEZE_TIMEOUT = 90   -- страховка: сам отпустит бойца, если клиент молчит

util.AddNetworkString("P11_SpawnMenu_Open")
util.AddNetworkString("P11_SpawnMenu_Done")

local function ThawTimerName(ply) return "P11.SpawnMenuThaw." .. ply:UserID() end

-- отпустить бойца (идемпотентно)
local function CloseMenu(ply)
    ply.P11_InSpawnMenu = nil
    timer.Remove(ThawTimerName(ply))
    if IsValid(ply) then ply:Freeze(false) end
end

local function OpenMenu(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not ply:Alive() then return end
    ply.P11_InSpawnMenu = CurTime()
    ply:Freeze(true)
    net.Start("P11_SpawnMenu_Open")
    net.Send(ply)
    P11FW.Log("ВЕРБОВКА: меню выбора показано " .. ply:Nick())
    timer.Create(ThawTimerName(ply), FREEZE_TIMEOUT, 1, function()
        if IsValid(ply) and ply.P11_InSpawnMenu then CloseMenu(ply) end
    end)
end

-- клиент закрыл меню (крестик / «остаться новобранцем»)
net.Receive("P11_SpawnMenu_Done", function(_, ply)
    CloseMenu(ply)
end)

-- занял должность (в т.ч. из этого меню) — свободен
hook.Add("P11FW.JobChanged", "P11.SpawnMenuJob", function(ply)
    if ply.P11_InSpawnMenu then CloseMenu(ply) end
end)

-- автопоказ после первого входа: анкета идёт на ~6с, заставка на ~7с
hook.Add("PlayerInitialSpawn", "P11.SpawnMenuJoin", function(ply)
    timer.Simple(AUTOJOIN_DELAY, function()
        if IsValid(ply) and ply:Alive() then OpenMenu(ply) end
    end)
end)

hook.Add("PlayerDisconnected", "P11.SpawnMenuBye", function(ply)
    timer.Remove(ThawTimerName(ply))
end)

-- ручное открытие: консоль
concommand.Add("p11_spawnmenu", function(ply)
    if IsValid(ply) then OpenMenu(ply) end
end)

-- ручное открытие: чат
hook.Add("PlayerSay", "P11.SpawnMenuSay", function(ply, text)
    local t = string.lower(string.Trim(text or ""))
    if t == "!смена" or t == "!выбор" or t == "!вербовка" then
        OpenMenu(ply)
        return ""
    end
end)

print("[POLUS-11] экран вербовки (выбор фракции/профы при спавне) загружен")
