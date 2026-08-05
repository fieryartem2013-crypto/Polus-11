AddCSLuaFile("shared.lua")
include("shared.lua")

local ROOT_TIME = 4

function ENT:Initialize()
    self:SetModel("models/hunter/misc/sphere075.mdl")
    self:SetMaterial("models/debug/debugwhite")
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:SetColor(Color(60, 40, 50, 220))
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionBounds(Vector(-5, -5, -5), Vector(5, 5, 5))
    self:SetTrigger(true)
    self:PhysicsInitSphere(5)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end

    self.DieAt = CurTime() + 5
end

-- путание жертвы: скорость в пол
local function Root(ply)
    if ply.P11_RootSaved then return end -- уже в путах
    ply.P11_RootSaved = { walk = ply:GetWalkSpeed(), run = ply:GetRunSpeed() }
    ply:SetWalkSpeed(50)
    ply:SetRunSpeed(50)
    ply:EmitSound("npc/zombie/zombie_hit.wav", 70, 70)

    timer.Simple(ROOT_TIME, function()
        if IsValid(ply) and ply.P11_RootSaved then
            ply:SetWalkSpeed(ply.P11_RootSaved.walk)
            ply:SetRunSpeed(ply.P11_RootSaved.run)
            ply.P11_RootSaved = nil
            POLUS11.Notify(ply, "Путы отвалились — ты снова бежишь.")
        end
    end)
end

function ENT:Touch(hit)
    if self.Done then return end
    local owner = self:GetOwner()
    if hit == owner then return end

    -- по человеку → путаем
    if IsValid(hit) and hit:IsPlayer() and hit:Alive() then
        self.Done = true
        Root(hit)
        POLUS11.Notify(hit, "СМОЛЯНАЯ МАССА СКОВЫВАЕТ ТЕБЯ (" .. ROOT_TIME .. " сек)!")
        if IsValid(owner) then
            POLUS11.Notify(owner, "Пут зацепил: " .. hit:Nick())
        end
        self:ExplodeFX()
        return
    end

    -- в стену/пол: шарик остаётся лежать как ловушка до DieAt,
    -- задетый игрок всё равно спутывается (см. Touch)
end

function ENT:ExplodeFX()
    local pos = self:GetPos()
    local ed = EffectData()
    ed:SetOrigin(pos)
    util.Effect("BloodImpact", ed, true, true)
    self:EmitSound("physics/flesh/flesh_squishy_impact_hard" .. math.random(1, 4) .. ".wav", 80, 90)
    self:Remove()
end

function ENT:Think()
    if CurTime() > self.DieAt then
        self:Remove()
        return
    end
    self:NextThink(CurTime() + 0.5)
    return true
end
