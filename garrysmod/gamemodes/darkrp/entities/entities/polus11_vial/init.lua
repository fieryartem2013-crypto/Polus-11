AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/healthvial.mdl")
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_NONE)
    self:SetUseType(SIMPLE_USE)
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    self:SetDonorName("?")
end

-- E по чужой колбе: даёт поднять, если она лежит; по своей в руке — ничего
function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    local parent = self:GetParent()
    if IsValid(parent) then return end -- уже кто-то несёт

    -- нельзя поднимать больше одной колбы
    for _, e in ipairs(ents.FindByClass("polus11_vial")) do
        if e:GetParent() == activator then
            POLUS11.Notify(activator, "Вы уже несёте колбу! Отнесите её к лабораторному столу.")
            return
        end
    end

    self:PickUp(activator)
end

function ENT:PickUp(ply)
    self:SetParent(ply)
    self:Fire("SetParentAttachment", "anim_attachment_RH", 0)
    self:SetLocalPos(Vector(0, 0, 0))
    self:SetLocalAngles(Angle(0, 0, 0))
    POLUS11.Notify(ply, "Вы взяли колбу с кровью: " .. self:GetDonorName())
end

function ENT:Drop(pos)
    self:SetParent(nil)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetPos(pos or self:GetPos())
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end
end
