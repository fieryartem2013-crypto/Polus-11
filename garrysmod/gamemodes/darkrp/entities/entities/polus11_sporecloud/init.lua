-- ============================================================
--  ПОЛЮС-11 — СПОРОВОЕ ОБЛАКО
--  Висит, шипит. ЛЮДИ внутри копят «споры в лёгких»
--  (NWFloat P11_Exposure). На 100 — заражение (тихое).
--  CloudTime секунд — и рассеивается. Нечто споры лечат чуть.
-- ============================================================

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/hunter/misc/sphere075.mdl")
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    self:SetNoDraw(true) -- видимая часть рисуется спрайтами в cl_init

    self.DieAt = CurTime() + (POLUS11.Config.SporeCloudTime or 15)
    self.NextPulse = 0

    -- шипение
    self.SoundLoop = CreateSound(self, "ambient/gas/cannister_loop.wav")
    if self.SoundLoop then self.SoundLoop:PlayEx(0.6, 100) end
end

function ENT:OnRemove()
    if self.SoundLoop then self.SoundLoop:Stop() end
end

function ENT:Think()
    if CurTime() > self.DieAt then
        self:Remove()
        return
    end

    if CurTime() >= self.NextPulse then
        self.NextPulse = CurTime() + 1

        local radius = POLUS11.Config.SporeRadius or 130
        for _, ply in ipairs(player.GetAll()) do
            if ply:Alive() and ply:GetPos():DistToSqr(self:GetPos()) <= radius * radius then
                local infected = ply:GetNWBool("P11_Infected", false)

                if infected then
                    -- нечто: споры приятны
                    local maxhp = ply:GetMaxHealth() > 0 and ply:GetMaxHealth() or 100
                    ply:SetHealth(math.min(maxhp, ply:Health() + 1))
                else
                    local cur = ply:GetNWFloat("P11_Exposure", 0) + 12
                    ply:SetNWFloat("P11_Exposure", cur)

                    if cur >= (POLUS11.Config.SporeInfectAt or 100) then
                        ply:SetNWFloat("P11_Exposure", 0)
                        POLUS11.Infect(ply, "споры из облака", true)
                        POLUS11.Notify(ply, "Воздух был... неправильным. Горло саднит.")
                    end
                end
            end
        end
    end

    self:NextThink(CurTime() + 0.25)
    return true
end
