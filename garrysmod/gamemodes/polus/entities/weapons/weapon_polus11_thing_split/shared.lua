-- ============================================================
--  ПОЛЮС-11 — Класс Нечто: «РАЗДЕЛЁННЫЙ»
--  ЛКМ — быстрые когти | ПКМ — кислотный плевок
--  R — паучья форма (стены/потолки, скорость). В форме нельзя
--  притворяться человеком.
-- ============================================================

SWEP.PrintName    = "НЕЧТО: Разделённый"
SWEP.Author       = "POLUS-11"
SWEP.Category     = "ПОЛЮС-11"
SWEP.Instructions = "ЛКМ — когти (быстро) | ПКМ — кислота | R — паучья форма | В форме: прыжок у стены — лазание"

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

SWEP.Weight = 4

local SPIDER_SPEED = 1.6
local SPIDER_JUMP  = 300
local FORM_MIN_TIME = 10 -- минимум секунд в паучьей форме

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

local function IsSpider(ply)
    return ply.P11_Spider == true
end

local function SetSpider(ply, on)
    if on == IsSpider(ply) then return end

    if on then
        ply.P11_SavedForm = {
            model = ply:GetModel(),
            walk = ply:GetWalkSpeed(),
            run = ply:GetRunSpeed(),
            jump = ply:GetJumpPower(),
        }
        ply.P11_Spider = true
        ply.P11_SpiderAt = CurTime()
        ply:SetModel(POLUS11.MonsterModels.spider)
        ply:SetWalkSpeed(ply.P11_SavedForm.walk * SPIDER_SPEED)
        ply:SetRunSpeed(ply.P11_SavedForm.run * SPIDER_SPEED)
        ply:SetJumpPower(SPIDER_JUMP)
        ply:EmitSound("npc/fast_zombie/leap1.wav", 90, 100)

        local ed = EffectData()
        ed:SetOrigin(ply:GetPos() + Vector(0, 0, 30))
        util.Effect("bloodspray", ed, true, true)

        POLUS11.Log("РАЗДЕЛЁННЫЙ принял форму: " .. ply:Nick())
    else
        if not ply.P11_SavedForm then return end
        ply.P11_Spider = false
        ply:SetModel(ply.P11_SavedForm.model)
        ply:SetWalkSpeed(ply.P11_SavedForm.walk)
        ply:SetRunSpeed(ply.P11_SavedForm.run)
        ply:SetJumpPower(ply.P11_SavedForm.jump)
        ply.P11_SavedForm = nil
        ply:EmitSound("npc/zombie/zombie_voice_idle" .. math.random(1, 5) .. ".wav", 70, 90)
    end
end

-- ==================== БЫСТРЫЕ КОГТИ ====================

function SWEP:PrimaryAttack()
    local ply = self.Owner
    if not IsValid(ply) then return end

    self:SetNextPrimaryFire(CurTime() + 0.28)
    self:SetNextSecondaryFire(CurTime() + 0.3)

    ply:SetAnimation(PLAYER_ATTACK1)
    ply:EmitSound("npc/zombie/claw_miss" .. math.random(1, 2) .. ".wav", 70, 110 + math.random(-8, 8))

    if CLIENT then return end

    local tr = util.TraceHull({
        start  = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * 100,
        mins   = Vector(-14, -14, -14),
        maxs   = Vector(14, 14, 14),
        filter = {ply, self},
        mask   = MASK_SHOT_HULL,
    })

    local ent = tr.Entity
    if IsValid(ent) then
        local dmg = DamageInfo()
        dmg:SetDamage(18)
        dmg:SetAttacker(ply)
        dmg:SetInflictor(self)
        dmg:SetDamageType(DMG_SLASH)
        dmg:SetDamagePosition(tr.HitPos)
        ent:TakeDamageInfo(dmg)

        ent:EmitSound("physics/flesh/flesh_impact_bullet" .. math.random(1, 5) .. ".wav", 65, math.random(95, 115))

        local ed = EffectData()
        ed:SetOrigin(tr.HitPos)
        ed:SetNormal(tr.HitNormal)
        util.Effect("BloodImpact", ed, true, true)
    end
end

-- ==================== КИСЛОТНЫЙ ПЛЕВОК ====================

function SWEP:SecondaryAttack()
    local ply = self.Owner
    if not IsValid(ply) then return end
    self:SetNextSecondaryFire(CurTime() + 2.2)

    if CLIENT then return end

    ply:SetAnimation(PLAYER_ATTACK1)
    ply:EmitSound("npc/barnacle/barnacle_gulp2.wav", 70, 120)

    local spit = ents.Create("polus11_acidspit")
    if not IsValid(spit) then return end
    spit:SetPos(ply:GetShootPos() + ply:GetAimVector() * 30)
    spit:SetOwner(ply)
    spit:Spawn()

    local phys = spit:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetVelocity(ply:GetAimVector() * 900 + Vector(0, 0, 60))
    end
end

-- ==================== R — ПАУЧЬЯ ФОРМА ====================

function SWEP:Reload()
    if CLIENT or not IsFirstTimePredicted() then return end
    local ply = self.Owner

    self.NextReload = self.NextReload or 0
    if CurTime() < self.NextReload then return end
    self.NextReload = CurTime() + 1

    if IsSpider(ply) then
        if CurTime() - (ply.P11_SpiderAt or 0) < FORM_MIN_TIME then
            POLUS11.Notify(ply, "Нельзя вернуться в человека ещё " .. math.ceil(FORM_MIN_TIME - (CurTime() - ply.P11_SpiderAt)) .. " сек")
            return
        end
        SetSpider(ply, false)
        POLUS11.Notify(ply, "Вы снова человек.")
    else
        SetSpider(ply, true)
        POLUS11.Notify(ply, "ПАУЧЬЯ ФОРМА! Прыгайте у стен — полезете наверх.")
    end
end

-- ==================== ЛАЗАНИЕ ПО СТЕНАМ ====================

function SWEP:Think()
    if CLIENT then return end
    local ply = self.Owner
    if not IsValid(ply) then return end
    if not IsSpider(ply) then return end

    -- прыжок в стену толкает вверх (с антиспамом)
    if ply:KeyDown(IN_JUMP) then
        self.NextClimb = self.NextClimb or 0
        if CurTime() >= self.NextClimb then
            local tr = util.TraceLine({
                start = ply:GetShootPos(),
                endpos = ply:GetShootPos() + ply:GetAimVector() * 60,
                filter = ply,
            })
            if tr.Hit and math.abs(tr.HitNormal.z) < 0.6 then
                ply:SetVelocity(Vector(tr.HitNormal.x, tr.HitNormal.y, 0) * 80 + Vector(0, 0, 260))
                ply:EmitSound("npc/zombie/claw_strike1.wav", 40, math.random(110, 135))
                self.NextClimb = CurTime() + 0.35
            end
        end
    end
end

-- паук не может спрятать оружие как человек (форма паука всегда с когтями)
function SWEP:Holster()
    return true
end

hook.Add("PlayerSpawn", "P11_SpiderReset", function(ply)
    -- вернуть скорость/прыжок, если умер в паучьей форме
    -- (GMod не всегда сбрасывает их сам при респавне)
    if ply.P11_SavedForm then
        ply:SetWalkSpeed(ply.P11_SavedForm.walk or 400)
        ply:SetRunSpeed(ply.P11_SavedForm.run or 600)
        ply:SetJumpPower(ply.P11_SavedForm.jump or 200)
    end
    ply.P11_Spider = false
    ply.P11_SavedForm = nil
end)
