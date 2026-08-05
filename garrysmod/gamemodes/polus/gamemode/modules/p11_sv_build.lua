-- ============================================================
--  ПОЛЮС-11 — СТРОИТЕЛЬСТВО / ПРИЗРАЧНАЯ УСТАНОВКА ПРОПОВ (server)
--  v2.5. Не-админ спавнит проп из вайтлиста -> он ПРИЗРАК:
--  полупрозрачный, без коллизий с игроками (нельзя убить/зажать).
--  E по своему призраку — поднять, ещё E — поставить.
--  Призрак «окаменевает» (становится обычным физичным пропом),
--  только когда в радиусе SolidifyRadius НЕТ игроков
--  хотя бы SolidityTime секунд. Проповедь против гриферства.
-- ============================================================

P11 = P11 or {}
P11.Build = P11.Build or {}
local Build = P11.Build

Build.Carried = Build.Carried or {} -- ent -> ply (кто несёт)
Build.Ghosts  = Build.Ghosts or {}  -- ent -> true (призраки под наблюдением)

local function Cfg()
    return POLUS11.Config and POLUS11.Config.Building or nil
end

local function IsAdmin(ply)
    return IsValid(ply) and P11FW and P11FW.Config and P11FW.Config.Admin(ply)
end

-- ============ ПРИЗРАК / ОКАМЕНЕНИЕ ============

function Build.Ghostify(ent, owner)
    local b = Cfg()
    ent.P11_Ghost     = true
    ent.P11_GhostOwner = owner
    ent.P11_ClearSince = nil

    ent:SetRenderMode(RENDERMODE_TRANSCOLOR)
    ent:SetColor(Color(255, 255, 255, (b and b.GhostAlpha) or 120))
    ent:DrawShadow(false)
    ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS) -- летит/лежит, но игроков не задевает

    Build.Ghosts[ent] = true
end

function Build.Solidify(ent)
    if not IsValid(ent) then return end
    ent.P11_Ghost = false
    ent.P11_ClearSince = nil

    ent:SetRenderMode(RENDERMODE_NORMAL)
    ent:SetColor(Color(255, 255, 255, 255))
    ent:DrawShadow(true)
    ent:SetCollisionGroup(COLLISION_GROUP_NONE)

    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end

    ent:EmitSound("physics/cardboard/cardboard_box_impact_soft1.wav", 60, 100)

    local owner = ent.P11_GhostOwner
    if IsValid(owner) then
        owner:ChatPrint("[Склад] Предмет закреплён — теперь он физичен.")
    end

    Build.Ghosts[ent] = nil
    Build.Carried[ent] = nil

    hook.Run("P11.PropSolidified", ent, owner) -- точка расширения (статистика и т.п.)
end

-- ============ СПАВН ПРОПА ИГРОКОМ -> АВТО-ПРИЗРАК ============

hook.Add("PlayerSpawnedProp", "P11.BuildGhostify", function(ply, model, ent)
    if not (IsValid(ply) and IsValid(ent)) then return end
    local b = Cfg()
    if not (b and b.Enabled) then return end
    if IsAdmin(ply) then return end -- админы ставят сразу-тёплыми (у них физган)

    timer.Simple(0, function()
        if not (IsValid(ent) and IsValid(ply)) then return end
        if not ent.P11_Ghost then
            Build.Ghostify(ent, ply)
            ply:ChatPrint("[Склад] Призрачный предмет: E — взять/поставить. "
                .. "Станет физичным, когда рядом не будет людей.")
        end
    end)
end)

-- ============ ПЕРЕНОСКА (E) ============

local function Dropping(ply, ent)
    if Build.Carried[ent] ~= ply then return end
    Build.Carried[ent] = nil
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(true)
        phys:Wake()
    end
    ent.P11_ClearSince = nil
end

hook.Add("PlayerUse", "P11.BuildCarry", function(ply, ent)
    if not (IsValid(ply) and IsValid(ent)) then return end
    if ent:GetClass() ~= "prop_physics" then return end
    if not ent.P11_Ghost then return end
    if not (ent.P11_GhostOwner == ply or IsAdmin(ply)) then
        ply:ChatPrint("[Склад] Этот призрак принадлежит другому игроку.")
        return false
    end

    -- поставить, если несём этот
    if Build.Carried[ent] == ply then
        Dropping(ply, ent)
        return false
    end

    -- нельзя нести два сразу
    for e, p in pairs(Build.Carried) do
        if p == ply and IsValid(e) then
            ply:ChatPrint("[Склад] Вы уже несёте предмет — сначала поставьте его (E).")
            return false
        end
    end

    Build.Carried[ent] = ply
    ply:ChatPrint("[Склад] Несёте предмет. E — поставить. Отойдите подальше, чтобы он окаменел.")
    ply:EmitSound("buttons/lever1.wav", 55, 110)
    return false
end)

-- ============ ФИЗИКА ПЕРЕНОСКИ + СЧЁТЧИК ОКАМЕНЕНИЯ ============

hook.Add("Think", "P11.BuildThink", function()
    local b = Cfg()
    if not (b and b.Enabled) then return end
    local dist = b.CarryDistance or 90

    -- переноска: держим перед лицом
    for ent, ply in pairs(Build.Carried) do
        if not (IsValid(ent) and IsValid(ply) and ply:Alive() and ent.P11_Ghost) then
            Build.Carried[ent] = nil
        else
            local target = ply:EyePos() + ply:EyeAngles():Forward() * dist
            target.z = target.z - 8
            ent:SetPos(target)
            local phys = ent:GetPhysicsObject()
            if IsValid(phys) then
                phys:EnableMotion(false)
                phys:Sleep()
            end
        end
    end

    -- окаменение: чистая зона (никого ближе радиуса) подряд SolidityTime
    local radius  = b.SolidifyRadius or 130
    local needSec = b.SolidityTime or 2

    for ent in pairs(Build.Ghosts) do
        if not (IsValid(ent) and ent.P11_Ghost) then
            Build.Ghosts[ent] = nil
        elseif Build.Carried[ent] then
            ent.P11_ClearSince = nil -- в руках — не считаем
        else
            local clear = true
            for _, e in ipairs(ents.FindInSphere(ent:GetPos(), radius)) do
                if e:IsPlayer() and e:Alive() then
                    clear = false
                    break
                end
            end

            if clear then
                if not ent.P11_ClearSince then
                    ent.P11_ClearSince = CurTime()
                elseif CurTime() - ent.P11_ClearSince >= needSec then
                    Build.Solidify(ent)
                end
            else
                ent.P11_ClearSince = nil
            end
        end
    end
end)

-- ============ УБОРКА ОСТАТОКОВ ============

hook.Add("PlayerDeath", "P11.BuildDropDeath", function(ply)
    for ent, p in pairs(Build.Carried) do
        if p == ply and IsValid(ent) then
            Dropping(ply, ent)
        end
    end
end)

hook.Add("PlayerDisconnected", "P11.BuildDropDisc", function(ply)
    for ent, p in pairs(Build.Carried) do
        if p == ply and IsValid(ent) then
            Build.Carried[ent] = nil
            if IsValid(ent:GetPhysicsObject()) then
                ent:GetPhysicsObject():EnableMotion(true)
            end
        end
    end
end)
