-- ============================================================
--  ПОЛЮС-11 — Класс Нечто: «СПОРОВИК» (v2.3, НОВЫЙ)
--  Зональный контроль. Споры висят в воздухе — люди внутри
--  копят заражение. Учёные видят %-спор на HUD.
--  ЛКМ — слабые когти (25) | ПКМ — отплёвывает споровое облако
--  R   — РАЗОРВАТЬСЯ спорами: облако на себе ценой 60 хп
-- ============================================================

SWEP.PrintName    = "НЕЧТО: Споровик"
SWEP.Author       = "POLUS-11"
SWEP.Category     = "ПОЛЮС-11"
SWEP.Instructions = "ЛКМ — когти | ПКМ — споровое облако (18 сек КД) | R — разрыв спорами (стоит 60 хп)"

SWEP.Spawnable      = true
SWEP.AdminSpawnable = true
SWEP.AdminOnly      = true

SWEP.HoldType   = "melee"
SWEP.ViewModel  = ""
SWEP.WorldModel = ""
SWEP.UseHands   = false

SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic   = true
SWEP.Primary.Ammo        = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

SWEP.Weight = 5

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

-- ============ КОГТИ (ЛКМ) ============

function SWEP:PrimaryAttack()
    local ply = self.Owner
    if not IsValid(ply) then return end

    self:SetNextPrimaryFire(CurTime() + 0.5)

    ply:SetAnimation(PLAYER_ATTACK1)
    ply:EmitSound("npc/zombie/claw_miss" .. math.random(1, 2) .. ".wav", 70, 110)

    if CLIENT then return end
    if POLUS11_RevealThing then POLUS11_RevealThing(ply, self) end

    local tr = util.TraceHull({
        start  = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * 105,
        mins   = Vector(-14, -14, -14),
        maxs   = Vector(14, 14, 14),
        filter = { ply, self },
        mask   = MASK_SHOT_HULL,
    })

    local ent = tr.Entity
    if IsValid(ent) then
        local dmg = DamageInfo()
        dmg:SetDamage(25)
        dmg:SetAttacker(ply)
        dmg:SetInflictor(self)
        dmg:SetDamageType(DMG_SLASH)
        dmg:SetDamagePosition(tr.HitPos)
        ent:TakeDamageInfo(dmg)
        ent:EmitSound("physics/flesh/flesh_impact_bullet" .. math.random(1, 5) .. ".wav", 65, 110)

        local ed = EffectData()
        ed:SetOrigin(tr.HitPos)
        util.Effect("BloodImpact", ed, true, true)
    end
end

-- ============ ОБЛАКО СПОР (ПКМ) ============

local function SpitSpore(ply, vel)
    local spit = ents.Create("polus11_sporespit")
    if not IsValid(spit) then return end
    spit:SetPos(ply:GetShootPos() + ply:GetAimVector() * 26)
    spit:SetOwner(ply)
    spit:Spawn()
    local phys = spit:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetVelocity(vel or ply:GetAimVector() * 700 + Vector(0, 0, 120))
    end
end

function SWEP:SecondaryAttack()
    local ply = self.Owner
    if not IsValid(ply) then return end

    self.NextSpore = self.NextSpore or 0
    if CurTime() < self.NextSpore then
        if SERVER then
            POLUS11.Notify(ply, "Споры не готовы (" .. math.ceil(self.NextSpore - CurTime()) .. " сек)")
        end
        self:SetNextSecondaryFire(CurTime() + 1)
        return
    end
    self.NextSpore = CurTime() + 18
    self:SetNextSecondaryFire(CurTime() + 1)

    if CLIENT then return end

    ply:EmitSound("ambient/levels/canals/toxic_slime_gurgle2.wav", 75, 80)
    SpitSpore(ply)
end

-- ============ R — РАЗРЫВ ============

function SWEP:Reload()
    if CLIENT or not IsFirstTimePredicted() then return end
    local ply = self.Owner
    if not IsValid(ply) then return end

    self.NextR = self.NextR or 0
    if CurTime() < self.NextR then return end
    self.NextR = CurTime() + 3

    if ply:Health() <= 70 then
        POLUS11.Notify(ply, "Слишком мало плоти для разрыва (нужно > 70 хп).")
        return
    end

    ply:EmitSound("npc/zombie/zombie_alert" .. math.random(1, 3) .. ".wav", 90, 70)
    ply:SetHealth(ply:Health() - 60)

    -- облако прямо на себе
    local cloud = ents.Create("polus11_sporecloud")
    if IsValid(cloud) then
        cloud:SetPos(ply:GetPos() + Vector(0, 0, 40))
        cloud:SetOwner(ply)
        cloud:Spawn()
    end

    local ed = EffectData()
    ed:SetOrigin(ply:GetPos() + Vector(0, 0, 40))
    util.Effect("BloodImpact", ed, true, true)
    util.Effect("bloodspray", ed, true, true)

    POLUS11.Notify(ply, "Вы РАЗОРВАЛИСЬ облаком спор. Люди рядом заражаются...")
    POLUS11.Log("РАЗРЫВ СПОРОВИКА: " .. ply:Nick())
end
