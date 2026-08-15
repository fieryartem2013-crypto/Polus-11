-- ============================================================
--  ПОЛЮС-11 — БОДИГРУППЫ v5.7.7 (server, autorun)
--  Управление бодигруппами из С-меню (кнопка «🎭 Внешность»).
--  Клиент шлёт P11_BGSet {bg, val}; сервер применяет бодигруппу
--  (видят ВСЕ игроки) и сохраняет по SteamID64 (data/bodygroups.json).
--  При спавне/заходе внешность восстанавливается.
--  Также спавнит энтити polus_p11_bgmenu — курьер клиентской части.
-- ============================================================

util.AddNetworkString("P11_BGSet")

P11BG = P11BG or {}
local saved = P11BG
local stateDirty = false
local FILE = "bodygroups.json"

-- загрузка из файла
local function Load()
    local raw = file.Read(FILE, "DATA")
    if raw then
        local ok, tbl = pcall(util.JSONToTable, raw)
        if ok and istable(tbl) then saved = tbl; P11BG = tbl end
    end
end

-- сохранение (только если менялось)
local function Save()
    if not stateDirty then return end
    stateDirty = false
    file.Write(FILE, util.TableToJSON(saved, true) or "{}")
end

-- применить сохранённую внешность игроку (с защитой от чужой модели)
local function ApplyTo(ply)
    if not IsValid(ply) then return end
    local t = saved[ply:SteamID64()]
    if not t then return end
    for bg, val in pairs(t) do
        local bgn = tonumber(bg) or bg
        if type(bgn) == "number" and bgn >= 0 and bgn < ply:GetNumBodyGroups() then
            local cnt = ply:GetBodygroupCount(bgn)
            if cnt > 0 and val >= 0 and val < cnt then
                ply:SetBodygroup(bgn, val)
            end
        end
    end
end

-- клиент меняет бодигруппу (bg = -1 → сбросить все)
net.Receive("P11_BGSet", function(_, ply)
    if not IsValid(ply) then return end
    local bg = net.ReadInt(8)
    local val = net.ReadUInt(8)
    local sid = ply:SteamID64()

    if bg < 0 then
        -- сброс всей внешности
        for i = 0, ply:GetNumBodyGroups() - 1 do
            ply:SetBodygroup(i, 0)
        end
        saved[sid] = {}
    else
        if bg >= ply:GetNumBodyGroups() then return end
        local cnt = ply:GetBodygroupCount(bg)
        if cnt <= 0 or val < 0 or val >= cnt then return end
        ply:SetBodygroup(bg, val)
        saved[sid] = saved[sid] or {}
        saved[sid][bg] = val
    end
    stateDirty = true
    timer.Simple(1, Save) -- запись с дебаунсом
end)

-- восстановление внешности при спавне и заходе
hook.Add("PlayerSpawn", "P11.BG.Apply", function(ply)
    timer.Simple(0.5, function()
        if IsValid(ply) then ApplyTo(ply) end
    end)
end)
hook.Add("PlayerInitialSpawn", "P11.BG.ApplyInit", function(ply)
    timer.Simple(3, function()
        if IsValid(ply) then ApplyTo(ply) end
    end)
end)
hook.Add("PlayerDisconnected", "P11.BG.Bye", function()
    Save()
end)

-- ================= Спавн энтити-«курьера» (клиентская часть) =================
local function SpawnCarrier()
    if ents.FindByClass("polus_p11_bgmenu")[1] then return end
    local e = ents.Create("polus_p11_bgmenu")
    if IsValid(e) then
        e:SetPos(Vector(0, 0, -20000)) -- под картой, невидимая
        e:Spawn()
    end
end

hook.Add("InitPostEntity", "P11.BG.Start", function()
    timer.Simple(0.5, function()
        Load()
        SpawnCarrier()
    end)
end)
hook.Add("PostCleanupMap", "P11.BG.Reload", function()
    timer.Simple(3, SpawnCarrier)
end)

print("[POLUS-11] БОДИГРУППЫ v5.7.7: кнопка «Внешность» в С-меню, сохранение в data/bodygroups.json")
