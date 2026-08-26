-- ============================================================
--  ПОЛЮС FRAMEWORK — НАКАЗАНИЯ (сервер)
--  Три вида:
--   • АРЕСТ   — камера (телепорт на точку ареста), обездвижен,
--               разоружён. По таймеру — освобождение на место.
--   • РАБСТВО — ходит свободно, но БЕЗ оружия и БЕЗ должности
--               (нельзя брать профы, нельзя поднимать оружие).
--   • БАН     — кик через 4 сек + отказ при входе до конца срока.
--  У наказанного сверху экрана красная плашка со статусом.
--  Всё переживает реконнект и рестарт (data/polus_framework/).
-- ============================================================

local PUNISH_FILE = "polus_framework/punish.json"
local BANS_FILE   = "polus_framework/bans.json"

P11FW.Punished = P11FW.Punished or {} -- sid64 -> {type, until, reason, returnPos}
P11FW.Bans     = P11FW.Bans or {}     -- sid64 -> {until(0=навсегда), reason, by, nick}

-- ============ ФАЙЛЫ ============

local function EnsureDir()
    if not file.IsDir("polus_framework", "DATA") then file.CreateDir("polus_framework") end
end

function P11FW.SavePunishments()
    EnsureDir()
    file.Write(PUNISH_FILE, util.TableToJSON(P11FW.Punished, true))
end

function P11FW.SaveBans()
    EnsureDir()
    file.Write(BANS_FILE, util.TableToJSON(P11FW.Bans, true))
end

function P11FW.LoadPunishments()
    local raw = file.Read(PUNISH_FILE, "DATA")
    P11FW.Punished = (raw and util.JSONToTable(raw)) or {}
    if not istable(P11FW.Punished) then P11FW.Punished = {} end

    local raw2 = file.Read(BANS_FILE, "DATA")
    P11FW.Bans = (raw2 and util.JSONToTable(raw2)) or {}
    if not istable(P11FW.Bans) then P11FW.Bans = {} end
end

P11FW.LoadPunishments()

-- ============ ХЕЛПЕРЫ ============

function P11FW.IsPunished(ply)
    if not IsValid(ply) then return nil end
    local t = ply:GetNWString("P11FW_Punish", "")
    return t ~= "" and t or nil
end

local function SidOf(ply)
    local s = ply:SteamID64()
    return (s and s ~= "0") and s or ply:SteamID()
end

-- ============ ПРИМЕНЕНИЕ ЭФФЕКТОВ ============

function P11FW.ApplyPunishment(ply, entry)
    ply:SetNWString("P11FW_Punish", entry.type)
    ply:SetNWString("P11FW_PunishReason", entry.reason or "")
    ply.P11FW_PunishUntil = entry.Until

    if entry.type == "arrest" then
        ply:StripWeapons()
        ply:StripAmmo()

        -- если только что посадили — запомнить, откуда взяли
        if not entry.returnPos then
            entry.returnPos = { x = ply:GetPos().x, y = ply:GetPos().y, z = ply:GetPos().z }
            P11FW.SavePunishments()
        end

        local jail = P11FW.GetPoint and P11FW.GetPoint("jail") or nil
        if jail then
            ply:SetPos(jail.pos + Vector(0, 0, 4))
            ply:SetEyeAngles(jail.ang)
        end
        ply:Freeze(true)
        ply:EmitSound("doors/door_metal_large_close2.wav", 70, 100)

    elseif entry.type == "slavery" then
        ply:StripWeapons()
        ply:StripAmmo()
        if P11FW.GetJobId(ply) ~= P11FW.Config.DefaultJob then
            P11FW.SetJob(ply, P11FW.Config.DefaultJob, nil, true)
        end
    end
end

function P11FW.RemovePunishEffects(ply, entry)
    ply:Freeze(false)
    ply:SetNWString("P11FW_Punish", "")
    ply:SetNWString("P11FW_PunishReason", "")
    ply:SetNWInt("P11FW_PunishLeft", 0)
    ply.P11FW_PunishUntil = nil

    if entry and entry.type == "arrest" and entry.returnPos then
        ply:SetPos(Vector(entry.returnPos.x, entry.returnPos.y, entry.returnPos.z))
    end

    -- вернуть снаряжение должности (только если НЕ назначено новое наказание)
    timer.Simple(0.2, function()
        if IsValid(ply) and ply:Alive() and not P11FW.IsPunished(ply) then
            P11FW.ApplyLoadout(ply)
        end
    end)
end

-- ============ API ============

function P11FW.Punish(ply, ptype, minutes, reason, by)
    if not IsValid(ply) then return end
    reason = (reason and reason ~= "") and reason or "без причины"
    local sid = SidOf(ply)

    -- снять прошлое наказание (и стереть его запись!)
    if P11FW.IsPunished(ply) or P11FW.Punished[sid] then
        P11FW.RemovePunishEffects(ply, P11FW.Punished[sid])
        P11FW.Punished[sid] = nil
        P11FW.SavePunishments()
    end

    if ptype == "ban" then
        P11FW.Bans[sid] = {
            Until  = minutes > 0 and (os.time() + minutes * 60) or 0, -- 0 = навсегда
            reason = reason,
            by     = IsValid(by) and by:Nick() or "console",
            nick   = ply:Nick(),
        }
        P11FW.SaveBans()

        hook.Run("P11FW.Punished", ply, "ban", by)

        ply:SetNWString("P11FW_Punish", "ban")
        ply:SetNWString("P11FW_PunishReason", reason)
        ply.P11FW_PunishUntil = os.time() + 4 -- окно красной плашки

        P11FW.Log("БАН: " .. ply:Nick() .. " (" .. sid .. ") на " .. (minutes > 0 and (minutes .. " мин") or "НАВСЕГДА") .. " — " .. reason)

        timer.Simple(4, function()
            if IsValid(ply) then
                local msg = "[P11FW] ВЫ ЗАБАНЕНЫ\nПричина: " .. reason ..
                    "\nСрок: " .. (minutes > 0 and (minutes .. " мин (до " .. os.date("%d.%m %H:%M", P11FW.Bans[sid].Until) .. ")") or "НАВСЕГДА")
                ply:Kick(msg)
            end
        end)
        return
    end

    if minutes < 1 then minutes = 5 end
    local entry = {
        type   = ptype,
        Until  = os.time() + minutes * 60,
        reason = reason,
    }
    P11FW.Punished[sid] = entry
    P11FW.SavePunishments()
    P11FW.ApplyPunishment(ply, entry)

    -- сигнал наружу (задачи смены polus11 и др.)
    hook.Run("P11FW.Punished", ply, ptype, by)

    P11FW.Log(string.upper(ptype) .. ": " .. ply:Nick() .. " на " .. minutes .. " мин — " .. reason)
    P11FW.Notify(ply, ptype == "arrest"
        and ("ВЫ АРЕСТОВАНЫ на " .. minutes .. " мин. Причина: " .. reason)
        or  ("ВЫ ОТПРАВЛЕНЫ В РАБСТВО на " .. minutes .. " мин. Причина: " .. reason))
end

function P11FW.Release(ply, silent)
    if not IsValid(ply) then return end
    local sid = SidOf(ply)
    local entry = P11FW.Punished[sid]

    P11FW.Punished[sid] = nil
    P11FW.SavePunishments()
    P11FW.RemovePunishEffects(ply, entry)

    if not silent then
        P11FW.Notify(ply, "Вы освобождены. Снаряжение возвращено.")
        P11FW.Log("Освобождён: " .. ply:Nick())
    end
end

function P11FW.Unban(sid)
    if P11FW.Bans[sid] then
        P11FW.Bans[sid] = nil
        P11FW.SaveBans()
        P11FW.Log("Разбанен: " .. sid)
    end
end

-- ============ ТИКЕР (обновление счётчика + авто-освобождение) ============

timer.Create("P11FW.PunishTick", 1, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        local pun = ply:GetNWString("P11FW_Punish", "")
        if pun ~= "" then
            local left = (ply.P11FW_PunishUntil or os.time()) - os.time()
            ply:SetNWInt("P11FW_PunishLeft", math.max(0, math.floor(left)))

            if pun ~= "ban" and left <= 0 then
                P11FW.Release(ply)
            end
        end
    end
end)

-- ============ РЕАППЛАЙ ПРИ ВХОДЕ / РЕСПАВНЕ ============

local function Reapply(ply, delay)
    timer.Simple(delay, function()
        if not IsValid(ply) then return end
        local sid = SidOf(ply)
        local entry = P11FW.Punished[sid]
        if not entry then return end

        if (entry.Until - os.time()) <= 0 then
            P11FW.Punished[sid] = nil
            P11FW.SavePunishments()
            return
        end

        -- смерть снимает freeze/оружие — вернуть как было
        ply:Freeze(false)
        P11FW.ApplyPunishment(ply, entry)
    end)
end

hook.Add("PlayerInitialSpawn", "P11FW.PunishJoin", function(ply)
    Reapply(ply, 2)
end)
hook.Add("PlayerSpawn", "P11FW.PunishRespawn", function(ply)
    Reapply(ply, 0.4) -- после выдачи лоадаута (0.1) и точки спавна (0.05)
end)

-- ============ ОГРАНИЧЕНИЯ ============

-- раб: не поднимает оружие; арестант: тоже
hook.Add("PlayerCanPickupWeapon", "P11FW.HoldPickup", function(ply, wep)
    if P11FW.IsPunished(ply) then return false end
end)

hook.Add("PlayerSwitchWeapon", "P11FW.HoldSwitch", function(ply, old, new)
    if P11FW.IsPunished(ply) then return true end
end)

-- арестованный не может суициднуться, чтобы сбежать из камеры
hook.Add("CanPlayerSuicide", "P11FW.HoldSuicide", function(ply)
    if P11FW.IsPunished(ply) == "arrest" then return false end
end)

-- ============ ПРОВЕРКА БАНА ПРИ ВХОДЕ ============

P11FW.BansCacheAt = P11FW.BansCacheAt or 0

hook.Add("CheckPassword", "P11FW.BanGate", function(steamID64, ip, svPass, clPass, name)
    -- обновляем файл раз в 30 сек (вдруг правили снаружи)
    if os.time() - P11FW.BansCacheAt > 30 then
        P11FW.BansCacheAt = os.time()
        P11FW.LoadPunishments()
    end

    local b = P11FW.Bans[steamID64]
    if not b then return end

    if (b.Until or 0) > 0 and os.time() >= b.Until then
        P11FW.Bans[steamID64] = nil
        P11FW.SaveBans()
        return -- срок вышел
    end

    local left = (b.Until or 0) == 0 and "НАВСЕГДА" or os.date("%d.%m.%Y %H:%M", b.Until)
    return false, "[P11FW] Вы забанены на этой станции.\nПричина: " .. (b.reason or "?") ..
        "\nДо: " .. left .. "\nАдмин: " .. (b.by or "?")
end)

-- ============ КОНСОЛЬНЫЕ КОМАНДЫ (паритет с меню) ============

local function FindPlayer(arg)
    if not arg or arg == "" then return nil end
    local byId = player.GetByID(tonumber(arg) or -1)
    if IsValid(byId) then return byId end
    local low = string.lower(arg)
    for _, p in ipairs(player.GetAll()) do
        if string.find(string.lower(p:Nick()), low, 1, true) then return p end
    end
    return nil
end

local function PunishCmd(ptype)
    return function(ply, cmd, args)
        if IsValid(ply) and not P11FW.Config.Admin(ply) then return end
        local t = FindPlayer(args[1])
        if not IsValid(t) then print("[P11FW] игрок не найден: " .. tostring(args[1])) return end
        local mins = tonumber(args[2]) or 5
        local reason = table.concat(args, " ", 3)
        -- v1.6: через ворота рангов (проверка прав и лимитов срока)
        if P11FW.RequestPunish then
            local ok, err = P11FW.RequestPunish(IsValid(ply) and ply or nil, t, ptype, mins, reason)
            if IsValid(ply) and not ok then P11FW.Notify(ply, "ОТКАЗ: " .. tostring(err)) end
        else
            P11FW.Punish(t, ptype, mins, reason, ply)
        end
    end
end

concommand.Add("polus_fw_arrest",  PunishCmd("arrest"))
concommand.Add("polus_fw_slavery", PunishCmd("slavery"))
concommand.Add("polus_fw_ban",     PunishCmd("ban"))

concommand.Add("polus_fw_free", function(ply, cmd, args)
    if IsValid(ply) and not P11FW.CanMod(ply, "arrest") then
        P11FW.Notify(ply, "Освобождать может Модератор+.")
        return
    end
    local t = FindPlayer(args[1])
    if IsValid(t) then P11FW.Release(t) P11FW.Notify(t, "Вы освобождены.") end
end)

concommand.Add("polus_fw_unban", function(ply, cmd, args)
    if IsValid(ply) and not P11FW.CanMod(ply, "unban") then
        P11FW.Notify(ply, "Разбан доступен Суперадмину и выше.")
        return
    end
    if args[1] then
        P11FW.Unban(args[1])
        if P11FW.ModLog then P11FW.ModLog("unban", ply, args[1], nil) end
        print("[P11FW] Разбанен: " .. args[1])
        if IsValid(ply) then P11FW.Notify(ply, "Разбанен: " .. args[1]) end
    end
end)
