-- ============================================================
--  ПОЛЮС FRAMEWORK — NPC-кадровик (сервер)
--  Стоит в казарме, по E открывает меню должностей.
--  Сохраняется на карту: переживает рестарт сервера.
-- ============================================================

local NPC_CLASS = "polus_fw_jobnpc"

local function NpcFile()
    return "polus_framework/npc_" .. game.GetMap() .. ".json"
end

-- ============ СОХРАНЕНИЕ / ЗАГРУЗКА ============

function P11FW.SaveNPCs()
    if not P11FW.Config.NPCPersist then return end
    if not file.IsDir("polus_framework", "DATA") then file.CreateDir("polus_framework") end

    local out = {}
    for _, e in ipairs(ents.FindByClass(NPC_CLASS)) do
        if IsValid(e) then
            out[#out + 1] = {
                pos = { x = e:GetPos().x, y = e:GetPos().y, z = e:GetPos().z },
                ang = { y = e:GetAngles().y },
            }
        end
    end
    file.Write(NpcFile(), util.TableToJSON(out))
end

function P11FW.LoadNPCs()
    if not P11FW.Config.NPCPersist then return end

    -- v4.4.0: во время собственной загрузки НЕ реагируем на EntityRemoved
    P11FW.NpcSaveMute = true

    -- убрать возможные дубли
    for _, e in ipairs(ents.FindByClass(NPC_CLASS)) do e:Remove() end

    local raw = file.Read(NpcFile(), "DATA")
    if not raw then return end
    local tbl = util.JSONToTable(raw)
    if not istable(tbl) then return end

    for _, d in ipairs(tbl) do
        if istable(d) and istable(d.pos) then
            local e = ents.Create(NPC_CLASS)
            if IsValid(e) then
                e:SetPos(Vector(d.pos.x or 0, d.pos.y or 0, d.pos.z or 0))
                e:SetAngles(Angle(0, (d.ang and d.ang.y) or 0, 0))
                e:Spawn()
                e:Activate()
            end
        end
    end
    P11FW.Log("Загружено кадровиков: " .. #tbl)

    -- загрузка кончилась — опять следим за удалениями
    timer.Simple(1, function() P11FW.NpcSaveMute = false end)
end

hook.Add("InitPostEntity", "P11FW.NpcLoad", function()
    timer.Simple(1, P11FW.LoadNPCs)
end)
hook.Add("PostCleanupMap", "P11FW.NpcLoadAfterCleanup", function()
    timer.Simple(1, P11FW.LoadNPCs)
end)

-- авто-сейв, если кадровика создали любым способом (в т.ч. из Q-меню)
hook.Add("OnEntityCreated", "P11FW.NpcAutosave", function(ent)
    if ent:GetClass() ~= NPC_CLASS then return end
    timer.Simple(2, function()
        if IsValid(ent) then P11FW.SaveNPCs() end
    end)
end)

-- ============ v4.4.0: УДАЛИЛ — УДАЛЕНО НАВСЕГДА ============
-- Раньше кадровик воскресал после рестарта, если его снесли НЕ
-- официальной кнопкой (кнопка Z, контекстное меню, remover-тула):
-- файл сейва его помнил. Теперь ЛЮБОЕ удаление сущности через
-- EntityRemoved вычёркивает её из сейва карты. Ложных срабатываний
-- нет: на чистке карты/рестарте проставляется NpcSaveMute.

P11FW.NpcSaveMute = P11FW.NpcSaveMute or false

hook.Add("EntityRemoved", "P11FW.NpcGoneForever", function(ent)
    if ent:GetClass() ~= NPC_CLASS then return end
    if P11FW.NpcSaveMute then return end
    if not (P11FW.Config and P11FW.Config.NPCPersist) then return end
    timer.Simple(0.4, function()
        if P11FW.NpcSaveMute then return end
        P11FW.SaveNPCs()
        P11FW.Log("Кадровик удалён с карты — вычеркнут из сейва (после рестарта НЕ воскреснет).")
    end)
end)

-- на чистке карты все энтити сносятся — это НЕ удаление админом
hook.Add("PreCleanupMap", "P11FW.NpcCleanupMute", function()
    P11FW.NpcSaveMute = true
end)

-- при выключении сервера тоже не пересохраняем (там всё равно таймер не доедет)
hook.Add("ShutDown", "P11FW.NpcShutdownMute", function()
    P11FW.NpcSaveMute = true
end)

-- ============ СОЗДАНИЕ / УДАЛЕНИЕ ============

function P11FW.CreateNPC(ply)
    local tr = ply:GetEyeTrace()
    local ang = (ply:GetPos() - tr.HitPos):Angle()
    ang.p, ang.r = 0, 0

    local e = ents.Create(NPC_CLASS)
    if not IsValid(e) then return end
    e:SetPos(tr.HitPos + Vector(0, 0, 2))
    e:SetAngles(ang + Angle(0, 180, 0)) -- лицом к админу
    e:Spawn()
    e:Activate()

    P11FW.SaveNPCs()
    P11FW.Notify(ply, "Кадровик установлен и сохранён на карте.")
    P11FW.Log(ply:Nick() .. " создал кадровика")
end

function P11FW.RemoveNPC(ply)
    local best, dist
    for _, e in ipairs(ents.FindByClass(NPC_CLASS)) do
        local d = ply:GetPos():DistToSqr(e:GetPos())
        if not dist or d < dist then best, dist = e, d end
    end

    if IsValid(best) and dist < 300 * 300 then
        best:Remove()
        P11FW.SaveNPCs()
        P11FW.Notify(ply, "Ближайший кадровик удалён.")
    else
        P11FW.Notify(ply, "Рядом нет кадровика (300 юнитов).")
    end
end

concommand.Add("polus_fw_npc_create", function(ply)
    if not IsValid(ply) or not P11FW.Config.Admin(ply) then return end
    P11FW.CreateNPC(ply)
end)

concommand.Add("polus_fw_npc_remove", function(ply)
    if not IsValid(ply) or not P11FW.Config.Admin(ply) then return end
    P11FW.RemoveNPC(ply)
end)

hook.Add("PlayerSay", "P11FW.NpcChat", function(ply, text)
    local t = string.lower(string.Trim(text))
    if t ~= "!нпс" and t ~= "!npc" and t ~= "!нпс убрать" and t ~= "!npc remove" then return end
    if not P11FW.Config.Admin(ply) then
        P11FW.Notify(ply, "Только для администрации.")
        return ""
    end

    if t == "!нпс убрать" or t == "!npc remove" then
        P11FW.RemoveNPC(ply)
    else
        P11FW.CreateNPC(ply)
    end
    return ""
end)
