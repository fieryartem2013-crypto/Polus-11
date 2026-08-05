AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    local models = {
        "models/props_wasteland/controlroom_desk001a.mdl",
        "models/props_combine/breendesk.mdl",
        "models/props_c17/FurnitureTable001a.mdl",
    }
    for _, m in ipairs(models) do
        if file.Exists(m, "GAME") then
            self:SetModel(m)
            break
        end
    end

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(300)
    end

    self:SetTesting(false)
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if self:GetTesting() then
        POLUS11.Notify(activator, "Тест уже идёт!")
        return
    end

    if not POLUS11.IsScientist(activator) then
        POLUS11.Notify(activator, "Тестом умеет пользоваться только научный персонал!")
        return
    end

    -- ищем колбу, которую несёт игрок
    local vial = nil
    for _, e in ipairs(ents.FindByClass("polus11_vial")) do
        if e:GetParent() == activator then
            vial = e
            break
        end
    end

    if not IsValid(vial) then
        POLUS11.Notify(activator, "Положите колбу с кровью (возьмите её в руки кнопкой E).")
        return
    end

    -- запускаем тест: колба ставится на стол
    vial:SetParent(nil)
    vial:SetMoveType(MOVETYPE_NONE)
    vial:SetSolid(SOLID_NONE)
    vial:SetPos(self:GetPos() + self:GetUp() * 30 + self:GetForward() * 10)
    vial:SetAngles(Angle(0, 0, 0))

    POLUS11.StartBloodTest(self, vial, activator)
end
