-- ============================================================
--  ПОЛЮС-11 — Класс Нечто: «ПОГЛОТИТЕЛЬ» (v2.3, НОВЫЙ)
--  Тяжёлый охотник. В форме: больше здоровья, чуть медленнее.
--  ЛКМ — тяжёлая махина (80 урона, раскрытие)
--  ПКМ — бросок массы: цель путается (4 сек почти не бежит)
--  R   — показать/скрыть форму монстра
-- ============================================================

SWEP.PrintName    = "НЕЧТО: Поглотитель"
SWEP.Author       = "POLUS-11"
SWEP.Category     = "ПОЛЮС-11"
SWEP.Instructions = "ЛКМ — тяжёлый удар | ПКМ — смоляной пут | R — форма монстра"

SWEP.Spawnable      = false -- v4.2.3: внутренняя форма (!форма), в спавн-меню не нужна
SWEP.AdminSpawnable = false
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

SWEP.Weight = 8

local BRUTE_HP    = 170
local BRUTE_SPEED = 0.9

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

-- ============ ТЯЖЁЛОЕ ТЕЛО (пока оружие у тебя) ============

function P11_BruteApply(ply)
    if ply.P11_BruteSaved then return end
    ply.P11_BruteSaved = {
        hp   = ply:GetMaxHealth(),
        walk = ply:GetWalkSpeed(),
        run  = ply:GetRunSpeed(),
    }
    local oldMax = ply.P11_BruteSaved.hp > 0 and ply.P11_BruteSaved.hp or 100
    ply:SetMaxHealth(BRUTE_HP)
    ply:SetHealth(math.min(BRUTE_HP, ply:Health() + (BRUTE_HP - oldMax)))
    ply:SetWalkSpeed(ply.P11_BruteSaved.walk * BRUTE_SPEED)
    ply:SetRunSpeed(ply.P11_BruteSaved.run * BRUTE_SPEED)
end

function P11_BruteRemove(ply)
    local s = ply.P11_BruteSaved
    if not s then return end
    ply:SetMaxHealth(s.hp > 0 and s.hp or 100)
    if ply:Health() > ply:GetMaxHealth() then ply:SetHealth(ply:GetMaxHealth()) end
    ply:SetWalkSpeed(s.walk)
    ply:SetRunSpeed(s.run)
    ply.P11_BruteSaved = nil
end

function SWEP:Deploy()
    self:SetHoldType(self.HoldType)
    -- тяжёлое тело накидывается/снимается системой маскировки (явление формы),
    -- но если игрок уже явлен — вернуть тело при взятии оружия в руки
    if SERVER and IsValid(self.Owner) and self.Owner.P11_Revealed then P11_BruteApply(self.Owner) end
    return true
end

function SWEP:Holster()
    if SERVER and IsValid(self.Owner) then P11_BruteRemove(self.Owner) end
    return true
end

function SWEP:OnRemove()
    if SERVER and IsValid(self.Owner) then P11_BruteRemove(self.Owner) end
    return true
end

-- ============ ТЯЖЁЛАЯ МАХИНА (ЛКМ) ============

function SWEP:PrimaryAttack()
    local ply = self.Owner
    if not IsValid(ply) then return end

    self:SetNextPrimaryFire(CurTime() + 1.15)
    self:SetNextSecondaryFire(CurTime() + 0.6)

    ply:SetAnimation(PLAYER_ATTACK1)
    ply:EmitSound("npc/zombie/claw_miss" .. math.random(1, 2) .. ".wav", 85, 80)

    if CLIENT then return end
    if POLUS11_RevealThing then POLUS11_RevealThing(ply, self) end

    local tr = util.TraceHull({
        start  = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * 130,
        mins   = Vector(-20, -20, -20),
        maxs   = Vector(20, 20, 20),
        filter = { ply, self },
        mask   = MASK_SHOT_HULL,
    })

    local ent = tr.Entity
    if IsValid(ent) then
        local dmg = DamageInfo()
        dmg:SetDamage(80 + ply:GetNWInt("P11_MutDmg", 0)) -- + бафф мутацией
        dmg:SetAttacker(ply)
        dmg:SetInflictor(self)
        dmg:SetDamageType(DMG_SLASH)
        dmg:SetDamagePosition(tr.HitPos)
        dmg:SetDamageForce(ply:GetAimVector() * 600 + Vector(0, 0, 260))
        ent:TakeDamageInfo(dmg)

        ent:EmitSound("physics/flesh/flesh_impact_hard" .. math.random(1, 4) .. ".wav", 80, 80)

        local ed = EffectData()
        ed:SetOrigin(tr.HitPos)
        util.Effect("BloodImpact", ed, true, true)
        util.Effect("bloodspray", ed, true, true)
    elseif tr.Hit then
        ply:EmitSound("npc/zombie/claw_strike" .. math.random(1, 3) .. ".wav", 75, 80)
    end
end

-- ============ СМОЛЯНОЙ ПУТ (ПКМ) ============

function SWEP:SecondaryAttack()
    local ply = self.Owner
    if not IsValid(ply) then return end

    self.NextMass = self.NextMass or 0
    if CurTime() < self.NextMass then
        if SERVER then
            POLUS11.Notify(ply, "Масса ещё копится (" .. math.ceil(self.NextMass - CurTime()) .. " сек)")
        end
        self:SetNextSecondaryFire(CurTime() + 1)
        return
    end
    self.NextMass = CurTime() + 18
    self:SetNextSecondaryFire(CurTime() + 1)

    if CLIENT then return end

    ply:EmitSound("npc/zombie_poison/pz_throw2.wav", 85, 85)

    local mass = ents.Create("polus11_mass")
    if not IsValid(mass) then return end
    mass:SetPos(ply:GetShootPos() + ply:GetAimVector() * 30)
    mass:SetOwner(ply)
    mass:Spawn()

    local phys = mass:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetVelocity(ply:GetAimVector() * 800 + Vector(0, 0, 80))
    end
end

-- ============ R — ФОРМА ============

function SWEP:Reload()
    if CLIENT or not IsFirstTimePredicted() then return end
    local ply = self.Owner
    if not IsValid(ply) then return end

    self.NextReload = self.NextReload or 0
    if CurTime() < self.NextReload then return end
    self.NextReload = CurTime() + 1

    if ply.P11_Revealed then
        if POLUS11_HideThing then
            POLUS11_HideThing(ply)
            POLUS11.Notify(ply, "Спрятали форму — ты снова «человек».")
        end
    else
        if POLUS11_RevealThing then
            POLUS11_RevealThing(ply, self)
            POLUS11.Notify(ply, "ПОГЛОТИТЕЛЬ ЯВЛЕН. Люди глухо кричат.")
        end
    end
end
