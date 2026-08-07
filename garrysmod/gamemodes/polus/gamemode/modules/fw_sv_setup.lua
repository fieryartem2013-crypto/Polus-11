-- ============================================================
--  ПОЛЮС FRAMEWORK — утилиты станции (сервер)
--  Точки: спавн гарнизона, камера ареста. Сохраняются на карту.
--  Здесь же — отдача данных в админ-меню.
-- ============================================================

util.AddNetworkString("P11FW_AdminData")
util.AddNetworkString("P11FW_AdminAction")
util.AddNetworkString("P11FW_AdminMenu")

function P11FW.PointsFile()
    return "polus_framework/points_" .. game.GetMap() .. ".json"
end

P11FW.Points = P11FW.Points or {} -- spawn = {pos=Vector, ang=Angle}, jail = {...}

function P11FW.SavePoints()
    if not file.IsDir("polus_framework", "DATA") then file.CreateDir("polus_framework") end
    local out = {}
    for key, d in pairs(P11FW.Points) do
        out[key] = {
            x = d.pos.x, y = d.pos.y, z = d.pos.z,
            p = d.ang.p, y = d.ang.y,
        }
    end
    file.Write(P11FW.PointsFile(), util.TableToJSON(out, true))
end

function P11FW.LoadPoints()
    P11FW.Points = {}
    local raw = file.Read(P11FW.PointsFile(), "DATA")
    if not raw then return end
    local tbl = util.JSONToTable(raw)
    if not istable(tbl) then return end
    for key, d in pairs(tbl) do
        if istable(d) then
            P11FW.Points[key] = {
                pos = Vector(d.x or 0, d.y or 0, d.z or 0),
                ang = Angle(d.p or 0, d.y or 0, 0),
            }
        end
    end
end

function P11FW.SetPoint(key, pos, ang)
    P11FW.Points[key] = { pos = pos, ang = Angle(0, ang.y, 0) }
    P11FW.SavePoints()
end

function P11FW.GetPoint(key)
    return P11FW.Points[key]
end

function P11FW.ClearPoint(key)
    P11FW.Points[key] = nil
    P11FW.SavePoints()
end

hook.Add("InitPostEntity", "P11FW.PointsLoad", function()
    timer.Simple(0.5, P11FW.LoadPoints)
end)
hook.Add("PostCleanupMap", "P11FW.PointsLoad2", function()
    timer.Simple(0.5, P11FW.LoadPoints)
end)

-- v4.8.7 «ТОЧКА»: спавн игроков ПЕРЕЕХАЛ в ядро спавна
-- (p11_sv_spawncore.lua — GM:PlayerSelectSpawn, точка назначается
-- движком ДО первого кадра). Старый таймерный перенос (0.05с),
-- гонявшийся с системой прибытий (0.09с) — упразднён:
-- именно их гонка и выглядела как «спавны не работают».
-- Точки по-прежнему ставятся этим модулем (act 7/9, setspawn),
-- ЧИТАЕТ их ядро спавна.

-- ============ ДАННЫЕ ДЛЯ АДМИН-МЕНЮ ============

-- Бан-лист хранится в sv_punish.lua: P11FW.Bans

net.Receive("P11FW_AdminData", function(len, ply)
    if not IsValid(ply) or not P11FW.Config.Admin(ply) then return end

    net.Start("P11FW_AdminData")
        -- настройки
        net.WriteBool(P11FW.GetPoint("spawn") ~= nil)
        net.WriteBool(P11FW.GetPoint("jail") ~= nil)

        -- игроки
        local plys = player.GetAll()
        net.WriteUInt(#plys, 8)
        for _, p in ipairs(plys) do
            net.WriteUInt(p:EntIndex(), 8)
            net.WriteString(p:Nick())
            net.WriteString(P11FW.GetJobId(p))
            local pun = p:GetNWString("P11FW_Punish", "")
            net.WriteString(pun)
            if pun ~= "" then
                local left = math.max(0, (p.P11FW_PunishUntil or os.time()) - os.time())
                net.WriteUInt(math.floor(left / 60), 10) -- минут (грубо, для меню)
            end
            -- v1.6: ранг, варны и мут для вкладки МОДЕРАЦИЯ
            local sid = p:SteamID64()
            if not sid or sid == "0" then sid = p:SteamID() end
            net.WriteString(p:GetNWString("P11FW_Rank", "user"))
            net.WriteUInt(P11FW.WarnCountBySid and P11FW.WarnCountBySid(sid) or 0, 8)
            local muted = P11FW.IsMuted and P11FW.IsMuted(p) or false
            net.WriteBool(muted)
            if muted then
                net.WriteUInt(math.min(P11FW.MuteLeftMin(p), 60000), 16)
            end
            -- v1.6.1: код удостоверения (у Нечто — УКРАДЕННЫЙ из его
            -- документов; админ в списке видит ровно то, что покажет документ)
            net.WriteString(p:GetNWString("P11_DocCode", ""))
        end

        -- баны
        P11FW.Bans = P11FW.Bans or {}
        local bans = {}
        for sid, b in pairs(P11FW.Bans) do
            bans[#bans + 1] = { sid = sid, b = b }
        end
        net.WriteUInt(#bans, 8)
        for _, it in ipairs(bans) do
            net.WriteString(it.sid)
            net.WriteString(it.b.nick or "?")
            net.WriteString(it.b.reason or "")
            net.WriteUInt(it.b.Until or 0, 32)
        end
    net.Send(ply)
end)

-- ============ ДЕЙСТВИЯ АДМИН-МЕНЮ ============

net.Receive("P11FW_AdminAction", function(len, ply)
    if not IsValid(ply) or not P11FW.Config.Admin(ply) then return end

    ply.P11FW_NextAct = ply.P11FW_NextAct or 0
    if CurTime() < ply.P11FW_NextAct then return end
    ply.P11FW_NextAct = CurTime() + 0.5

    local act = net.ReadUInt(5)

    if act == 1 or act == 2 or act == 3 then -- арест / рабство / бан (через ворота рангов)
        local idx = net.ReadUInt(8)
        local mins = net.ReadUInt(16)
        local reason = string.sub(net.ReadString(), 1, 120)
        local target = Entity(idx)
        if not IsValid(target) or not target:IsPlayer() then return end
        local ptype = (act == 1 and "arrest") or (act == 2 and "slavery") or "ban"
        if mins < 1 then mins = 5 end
        local ok, err = P11FW.RequestPunish(ply, target, ptype, mins, reason)
        P11FW.Notify(ply, ok
            and ("Применено: " .. target:Nick() .. " → " .. ptype)
            or ("ОТКАЗ: " .. tostring(err)))

    elseif act == 4 then -- освободить
        if not P11FW.CanMod(ply, "arrest") then P11FW.Notify(ply, "Освобождать может Модератор+.") return end
        local target = Entity(net.ReadUInt(8))
        if IsValid(target) and target:IsPlayer() then
            P11FW.Release(target)
            P11FW.Notify(ply, "Освобождён: " .. target:Nick())
        end

    elseif act == 5 then -- уволить
        local target = Entity(net.ReadUInt(8))
        if IsValid(target) and target:IsPlayer() then
            P11FW.Demote(target, true)
            P11FW.Notify(ply, "Уволен: " .. target:Nick())
        end

    elseif act == 6 then -- выдать должность
        local target = Entity(net.ReadUInt(8))
        local jobId = net.ReadString()
        if IsValid(target) and target:IsPlayer() and P11FW.Jobs[jobId] then
            P11FW.SetJob(target, jobId, nil, true)
            P11FW.Notify(ply, target:Nick() .. " → " .. P11FW.Jobs[jobId].name)
        end

    elseif act == 7 then  P11FW.SetPoint("spawn", ply:GetPos(), ply:EyeAngles())
        P11FW.Notify(ply, "Точка спавна установлена здесь — жёлтый куб покажет её 5 сек.")
        local sp = P11FW.GetPoint("spawn")
        if sp and POLUS11.SpawnMark then POLUS11.SpawnMark(sp.pos, sp.ang, 3, "ОБЩИЙ СПАВН ГАРНИЗОНА", 5) end
    elseif act == 8 then  P11FW.ClearPoint("spawn")
        P11FW.Notify(ply, "Точка спавна сброшена (стандартные точки карты).")
    elseif act == 9 then  P11FW.SetPoint("jail", ply:GetPos(), ply:EyeAngles())
        P11FW.Notify(ply, "Камера ареста установлена здесь — красный куб покажет её 5 сек.")
        local jl = P11FW.GetPoint("jail")
        if jl and POLUS11.SpawnMark then POLUS11.SpawnMark(jl.pos, jl.ang, 4, "КАМЕРА АРЕСТА", 5) end
    elseif act == 10 then P11FW.ClearPoint("jail")
        P11FW.Notify(ply, "Камера ареста сброшена (арест = заморозка на месте).")
    elseif act == 11 then P11FW.CreateNPC(ply)
    elseif act == 12 then P11FW.RemoveNPC(ply)

    elseif act == 13 then -- снять бан (Суперадмин+)
        if not P11FW.CanMod(ply, "unban") then
            P11FW.Notify(ply, "Разбан доступен Суперадмину и выше.")
            return
        end
        local sid = net.ReadString()
        P11FW.Unban(sid)
        if P11FW.ModLog then P11FW.ModLog("unban", ply, sid, nil) end
        P11FW.Notify(ply, "Бан снят: " .. sid)

    -- ============ БЫСТРЫЕ ДЕЙСТВИЯ С ИГРОКОМ (Админ+) ============

    elseif act >= 14 and act <= 19 and not P11FW.CanMod(ply, "heal") then
        P11FW.Notify(ply, "Быстрые действия доступны Админу и выше.")

    elseif act == 14 then -- полное лечение
        local target = Entity(net.ReadUInt(8))
        if IsValid(target) and target:IsPlayer() and target:Alive() then
            target:SetHealth(target:GetMaxHealth())
            P11FW.Notify(ply, "Вылечен: " .. target:Nick())
        end

    elseif act == 15 then -- возродить
        local target = Entity(net.ReadUInt(8))
        if IsValid(target) and target:IsPlayer() and not target:Alive() then
            target:Spawn()
            P11FW.Notify(ply, "Возрождён: " .. target:Nick())
        end

    elseif act == 16 then -- притащить к себе
        local target = Entity(net.ReadUInt(8))
        if IsValid(target) and target:IsPlayer() then
            target:SetPos(ply:GetPos() + ply:GetAimVector() * 60 + Vector(0, 0, 8))
            P11FW.Notify(ply, "Притащили: " .. target:Nick())
        end

    elseif act == 17 then -- телепорт к игроку
        local target = Entity(net.ReadUInt(8))
        if IsValid(target) and target:IsPlayer() then
            ply:SetPos(target:GetPos() + target:GetAimVector() * -60 + Vector(0, 0, 8))
            P11FW.Notify(ply, "Телепорт к " .. target:Nick())
        end

    elseif act == 18 then -- заморозка-переключение
        local target = Entity(net.ReadUInt(8))
        if IsValid(target) and target:IsPlayer() then
            target.P11FW_Frozen = not target.P11FW_Frozen
            target:Freeze(target.P11FW_Frozen)
            P11FW.Notify(ply, (target.P11FW_Frozen and "Заморожен: " or "Разморожен: ") .. target:Nick())
        end

    elseif act == 19 then -- убить
        local target = Entity(net.ReadUInt(8))
        if IsValid(target) and target:IsPlayer() and target:Alive() then
            target:Kill()
            P11FW.Notify(ply, "Убит: " .. target:Nick())
        end

    -- ============ ФРАКЦИИ ============

    elseif act == 20 then -- создать/обновить фракцию
        local ok, rec = pcall(util.JSONToTable, net.ReadString() or "{}")
        if ok then
            local ok2, res = P11FW.UpsertFaction(rec)
            P11FW.Notify(ply, ok2 and ("Фракция сохранена [" .. tostring(res) .. "]") or ("Ошибка: " .. tostring(res)))
        end

    elseif act == 21 then -- удалить фракцию
        local fid = net.ReadString()
        local ok, err = P11FW.DeleteFaction(fid)
        P11FW.Notify(ply, ok and "Фракция удалена." or ("Ошибка: " .. tostring(err)))

    elseif act == 22 then -- выдать ранг (Куратор+)
        local target = Entity(net.ReadUInt(8))
        local rid = net.ReadString()
        if IsValid(target) and target:IsPlayer() then
            local ok, err = P11FW.SetRank(target, rid, ply)
            if not ok then P11FW.Notify(ply, "Ошибка: " .. tostring(err)) end
        end

    elseif act == 23 then -- поставить терминал
        if POLUS11 and POLUS11.SpawnTerminal then
            POLUS11.SpawnTerminal(ply)
        else
            P11FW.Notify(ply, "Модуль терминала не загружен.")
        end

    elseif act == 24 then -- убрать ближайший терминал
        if POLUS11 and POLUS11.RemoveTerminalNear then
            POLUS11.RemoveTerminalNear(ply)
        else
            P11FW.Notify(ply, "Модуль терминала не загружен.")
        end

    -- ============ v1.6: МОДЕРАЦИЯ (варн/мут/кик/бан по рангам) ============

    elseif act == 25 then -- варн (Хелпер+)
        local target = Entity(net.ReadUInt(8))
        local reason = string.sub(net.ReadString(), 1, 120)
        if IsValid(target) and target:IsPlayer() then
            local ok, err = P11FW.Warn(ply, target, reason)
            if not ok then P11FW.Notify(ply, "ОТКАЗ: " .. tostring(err)) end
        end

    elseif act == 26 then -- мут (Хелпер+, лимит по рангу)
        local target = Entity(net.ReadUInt(8))
        local mins = net.ReadUInt(16)
        local reason = string.sub(net.ReadString(), 1, 120)
        if IsValid(target) and target:IsPlayer() then
            local ok, err = P11FW.Mute(ply, target, mins, reason)
            if not ok then P11FW.Notify(ply, "ОТКАЗ: " .. tostring(err)) end
        end

    elseif act == 27 then -- снять мут (Хелпер+)
        local target = Entity(net.ReadUInt(8))
        if IsValid(target) and target:IsPlayer() then
            local ok, err = P11FW.Unmute(ply, target)
            P11FW.Notify(ply, ok and ("Мут снят: " .. target:Nick()) or ("ОТКАЗ: " .. tostring(err)))
        end

    elseif act == 28 then -- кик (Модератор+)
        local target = Entity(net.ReadUInt(8))
        local reason = string.sub(net.ReadString(), 1, 120)
        if IsValid(target) and target:IsPlayer() then
            local ok, err = P11FW.Kick(ply, target, reason)
            if not ok then P11FW.Notify(ply, "ОТКАЗ: " .. tostring(err)) end
        end

    elseif act == 29 then -- расширенный бан: минуты 20 бит (0 = ПЕРМАНЕНТ)
        local target = Entity(net.ReadUInt(8))
        local mins = net.ReadUInt(20)
        local reason = string.sub(net.ReadString(), 1, 120)
        if IsValid(target) and target:IsPlayer() then
            mins = math.min(mins, 525600) -- потолок: один год
            local ok, err = P11FW.RequestPunish(ply, target, "ban", mins, reason)
            P11FW.Notify(ply, ok and "Бан поставлен." or ("ОТКАЗ: " .. tostring(err)))
        end

    elseif act == 30 then -- очистить варны (Хелпер+)
        local target = Entity(net.ReadUInt(8))
        if IsValid(target) and target:IsPlayer() then
            local ok, err = P11FW.ClearWarns(ply, target)
            P11FW.Notify(ply, ok and "Варны очищены." or ("ОТКАЗ: " .. tostring(err)))
        end

    -- ============ v4.5.0: ЗОНА ПРИБЫТИЯ + ГРУЗОВИК ============
    elseif act == 33 then -- поставить зону прибытия для фракции
        local fid = net.ReadString()
        if POLUS11 and POLUS11.ArrivalSet then POLUS11.ArrivalSet(ply, fid) end
    elseif act == 34 then -- убрать зону прибытия фракции
        local fid = net.ReadString()
        if POLUS11 and POLUS11.ArrivalClear then POLUS11.ArrivalClear(ply, fid) end
    elseif act == 35 then -- поставить LVS-грузовик колонны перед собой
        if POLUS11 and POLUS11.ArrivalTruckPut then POLUS11.ArrivalTruckPut(ply) end
    elseif act == 36 then -- убрать грузовик колонны
        if POLUS11 and POLUS11.ArrivalTruckRemove then POLUS11.ArrivalTruckRemove(ply) end

    -- ============ v4.6.1: СПАВН ПРОФЫ + СПИСОК ============
    elseif act == 37 then -- поставить точку спавна для ПРОФЫ
        local jid = net.ReadString()
        if POLUS11 and POLUS11.ArrivalJobSet then POLUS11.ArrivalJobSet(ply, jid) end
    elseif act == 38 then -- убрать точку спавна профы
        local jid = net.ReadString()
        if POLUS11 and POLUS11.ArrivalJobClear then POLUS11.ArrivalJobClear(ply, jid) end
    elseif act == 39 then -- показать, какие спавны расставлены
        if POLUS11 and POLUS11.ArrivalList then POLUS11.ArrivalList(ply) end
    end

    -- свежие данные в меню
    timer.Simple(0.3, function()
        if IsValid(ply) then
            net.Start("P11FW_AdminMenu") net.Send(ply) -- триггер пере-запроса данных
        end
    end)
end)

-- чат-команды управления точками (паритет с меню)
concommand.Add("polus_fw_setspawn", function(ply)
    if not P11FW.Config.Admin(ply) then return end
    P11FW.SetPoint("spawn", ply:GetPos(), ply:EyeAngles())
    P11FW.Notify(ply, "Спавн-поинт поставлен — жёлтый куб покажет его 5 сек.")
    local sp = P11FW.GetPoint("spawn")
    if sp and POLUS11.SpawnMark then POLUS11.SpawnMark(sp.pos, sp.ang, 3, "ОБЩИЙ СПАВН ГАРНИЗОНА", 5) end
end)
concommand.Add("polus_fw_clearspawn", function(ply) if P11FW.Config.Admin(ply) then P11FW.ClearPoint("spawn") P11FW.Notify(ply, "Спавн-поинт сброшен.") end end)
concommand.Add("polus_fw_setjail", function(ply)
    if not P11FW.Config.Admin(ply) then return end
    P11FW.SetPoint("jail", ply:GetPos(), ply:EyeAngles())
    P11FW.Notify(ply, "Точка ареста поставлена — красный куб покажет её 5 сек.")
    local jl = P11FW.GetPoint("jail")
    if jl and POLUS11.SpawnMark then POLUS11.SpawnMark(jl.pos, jl.ang, 4, "КАМЕРА АРЕСТА", 5) end
end)
concommand.Add("polus_fw_clearjail", function(ply) if P11FW.Config.Admin(ply) then P11FW.ClearPoint("jail") P11FW.Notify(ply, "Точка ареста сброшена.") end end)

-- открыть админ-меню из чата: /menu (главная), !menu, !fw, !фвадмин, !p11
hook.Add("PlayerSay", "P11FW.AdminChat", function(ply, text)
    local t = string.lower(string.Trim(text))
    if t ~= "/menu" and t ~= "!menu" and t ~= "!фвадмин" and t ~= "!fw" and t ~= "!p11" then return end
    if not P11FW.Config.Admin(ply) then
        P11FW.Notify(ply, "Только для администрации.")
        return ""
    end
    net.Start("P11FW_AdminMenu")
    net.Send(ply)
    return ""
end)

-- ============================================================
--  v3.8: ВОРКШОП-ПАКИ МОДЕЛЕЙ (починка розовых ERROR у игроков)
--  Впиши ID паков в P11FW.Config.WorkshopAddons (fw_sh_config.lua)
--  — сервер сам разошлёт их клиентам (resource.AddWorkshop).
--  ID — это цифры в конце ссылки пака: steamcommunity.com/sharedfiles/filedetails/?id=XXXXXXX
-- ============================================================
hook.Add("Initialize", "P11FW.WorkshopPacks", function()
    local packs = P11FW.Config and P11FW.Config.WorkshopAddons or {}
    local n = 0
    for _, id in ipairs(packs) do
        local sid = tostring(id)
        if sid ~= "" and sid ~= "0" then
            resource.AddWorkshop(sid)
            n = n + 1
        end
    end
    if n > 0 then
        print("[P11FW] Воркшоп-паков разослано клиентам: " .. n)
    end
end)
