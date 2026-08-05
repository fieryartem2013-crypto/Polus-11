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

-- спавн игроков в сохранённой точке (арестованных перебьёт система наказаний позже)
hook.Add("PlayerSpawn", "P11FW.SpawnPoint", function(ply)
    local sp = P11FW.GetPoint("spawn")
    if not sp then return end
    timer.Simple(0.05, function()
        if IsValid(ply) and ply:Alive() then
            ply:SetPos(sp.pos)
            ply:SetEyeAngles(sp.ang)
        end
    end)
end)

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

    if act == 1 or act == 2 or act == 3 then -- арест / рабство / бан
        local idx = net.ReadUInt(8)
        local mins = net.ReadUInt(16)
        local reason = string.sub(net.ReadString(), 1, 120)
        local target = Entity(idx)
        if not IsValid(target) or not target:IsPlayer() then return end
        local ptype = (act == 1 and "arrest") or (act == 2 and "slavery") or "ban"
        if mins < 1 then mins = 5 end
        P11FW.Punish(target, ptype, mins, reason, ply)
        P11FW.Notify(ply, "Применено: " .. target:Nick() .. " → " .. ptype .. " на " .. mins .. " мин.")

    elseif act == 4 then -- освободить
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
        P11FW.Notify(ply, "Точка спавна установлена здесь.")
    elseif act == 8 then  P11FW.ClearPoint("spawn")
        P11FW.Notify(ply, "Точка спавна сброшена (стандартные точки карты).")
    elseif act == 9 then  P11FW.SetPoint("jail", ply:GetPos(), ply:EyeAngles())
        P11FW.Notify(ply, "Камера ареста установлена здесь.")
    elseif act == 10 then P11FW.ClearPoint("jail")
        P11FW.Notify(ply, "Камера ареста сброшена (арест = заморозка на месте).")
    elseif act == 11 then P11FW.CreateNPC(ply)
    elseif act == 12 then P11FW.RemoveNPC(ply)

    elseif act == 13 then -- снять бан
        local sid = net.ReadString()
        P11FW.Unban(sid)
        P11FW.Notify(ply, "Бан снят: " .. sid)
    end

    -- свежие данные в меню
    timer.Simple(0.3, function()
        if IsValid(ply) then
            net.Start("P11FW_AdminMenu") net.Send(ply) -- триггер пере-запроса данных
        end
    end)
end)

-- чат-команды управления точками (паритет с меню)
concommand.Add("polus_fw_setspawn", function(ply) if P11FW.Config.Admin(ply) then P11FW.SetPoint("spawn", ply:GetPos(), ply:EyeAngles()) P11FW.Notify(ply, "Спавн-поинт поставлен.") end end)
concommand.Add("polus_fw_clearspawn", function(ply) if P11FW.Config.Admin(ply) then P11FW.ClearPoint("spawn") P11FW.Notify(ply, "Спавн-поинт сброшен.") end end)
concommand.Add("polus_fw_setjail", function(ply) if P11FW.Config.Admin(ply) then P11FW.SetPoint("jail", ply:GetPos(), ply:EyeAngles()) P11FW.Notify(ply, "Точка ареста поставлена.") end end)
concommand.Add("polus_fw_clearjail", function(ply) if P11FW.Config.Admin(ply) then P11FW.ClearPoint("jail") P11FW.Notify(ply, "Точка ареста сброшена.") end end)

-- открыть админ-меню из чата
hook.Add("PlayerSay", "P11FW.AdminChat", function(ply, text)
    local t = string.lower(string.Trim(text))
    if t ~= "!фвадмин" and t ~= "!fw" and t ~= "!p11" then return end
    if not P11FW.Config.Admin(ply) then
        P11FW.Notify(ply, "Только для администрации.")
        return ""
    end
    net.Start("P11FW_AdminMenu")
    net.Send(ply)
    return ""
end)
