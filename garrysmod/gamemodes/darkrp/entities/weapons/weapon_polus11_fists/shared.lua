-- ============================================================
--  ПОЛЮС-11 — КУЛАКИ (shared) v2.7
--  Просто руки. ЛКМ — удар (8-14 урона, лёгкий отброс).
--  Попадание кидает хук P11.FistHit (задача «спарринг»).
--  Выдаётся ВСЕМ через BaseLoadout фреймворка.
-- ============================================================

SWEP.PrintName   = "Кулаки"
SWEP.Author      = "POLUS-11"
SWEP.Category    = "ПОЛЮС-11"
SWEP.Spawnable   = false
SWEP.AdminOnly   = false
SWEP.Weight      = 1

SWEP.HoldType        = "fist"
SWEP.ViewModel       = ""
SWEP.WorldModel      = ""
SWEP.UseHands        = true
SWEP.DrawAmmo        = false
SWEP.DrawCrosshair   = true

SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic   = true
SWEP.Primary.Ammo        = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
    local ply = self.Owner
    if not IsValid(ply) then return end

    self:SetNextPrimaryFire(CurTime() + 0.55)
    ply:SetAnimation(PLAYER_ATTACK1)
    ply:EmitSound("npc/zombie/claw_miss" .. math.random(1, 2) .. ".wav",
        60, 100 + math.random(-10, 10), 0.55)

    if CLIENT then return end

    local tr = util.TraceHull({
        start  = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * 62,
        mins   = Vector(-10, -10, -10),
        maxs   = Vector(10, 10, 10),
        filter = {ply, self},
        mask   = MASK_SHOT_HULL,
    })

    local ent = tr.Entity
    if IsValid(ent) then
        local dmg = DamageInfo()
        dmg:SetDamage(8 + math.random(0, 6))
        dmg:SetAttacker(ply)
        dmg:SetInflictor(self)
        dmg:SetDamageType(DMG_CLUB)
        dmg:SetDamagePosition(tr.HitPos)
        dmg:SetDamageForce(ply:GetAimVector() * 900 + Vector(0, 0, 220))
        ent:TakeDamageInfo(dmg)

        if ent:IsPlayer() then
            ent:ViewPunch(Angle(math.random(-5, 5), math.random(-5, 5), 0))
        end

        ply:EmitSound("physics/flesh/flesh_impact_hard" .. math.random(1, 3) .. ".wav",
            65, 100 + math.random(-8, 8), 0.7)

        -- событие для задачи «спарринг: 10 ударов кулаками»
        hook.Run("P11.FistHit", ply, ent)
    end
end

function SWEP:SecondaryAttack()
    -- ничего: кулаки честные
end

function SWEP:DrawWorldModel() end
