-- ============================================================
--  ПОЛЮС-11 — ПАЁК КАМБУЗА (повар / снабженец)
--  ЛКМ по человеку в упор — выдать паёк (+здоровье, RP-момент).
--  Для задач повара: накормить разных людей.
-- ============================================================

SWEP.PrintName    = "Паёк (НРП)"
SWEP.Author       = "POLUS-11"
SWEP.Category     = "ПОЛЮС-11"
SWEP.Instructions = "ЛКМ по человеку — выдать паёк (+15 здоровья ему) | R — инструкция"

SWEP.Spawnable      = true
SWEP.AdminSpawnable = false

SWEP.HoldType   = "normal"
SWEP.ViewModel  = "models/weapons/c_hands.mdl"
SWEP.WorldModel = "models/props_junk/garbage_bag001a.mdl"
SWEP.UseHands   = true

SWEP.DrawAmmo = false

SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic   = false
SWEP.Primary.Ammo        = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

SWEP.Weight = 2

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
    local ply = self.Owner
    if not IsValid(ply) then return end

    self.NextFeed = self.NextFeed or 0
    self:SetNextPrimaryFire(CurTime() + 0.5)
    if CurTime() < self.NextFeed then
        if SERVER then
            POLUS11.Notify(ply, "Паёк фасуется... (" .. math.ceil(self.NextFeed - CurTime()) .. " сек)")
        end
        return
    end
    self.NextFeed = CurTime() + (POLUS11.Config.RationCooldown or 12)

    if CLIENT then return end

    local tr = util.TraceLine({
        start = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * 100,
        filter = ply,
    })
    local target = tr.Entity
    if not IsValid(target) or not target:IsPlayer() or not target:Alive() then
        POLUS11.Notify(ply, "Подойди вплотную к человеку и выдай паёк.")
        return
    end
    if target == ply then
        POLUS11.Notify(ply, "Себе выдавать не положено — паёк для экипажа!")
        return
    end

    local maxhp = target:GetMaxHealth() > 0 and target:GetMaxHealth() or 100
    target:SetHealth(math.min(maxhp, target:Health() + (POLUS11.Config.RationHeal or 15)))
    target:EmitSound("npc/barnacle/barnacle_gulp1.wav", 60, 110)
    ply:EmitSound("items/smallmedkit1.wav", 55, 105)

    POLUS11.Notify(target, "Вы получили паёк от " .. ply:Nick() .. ". Камбуз работает!")
    POLUS11.Notify(ply, "Паёк выдан: " .. target:Nick())

    -- задача повара: уникальные накормленные
    ply.P11_Fed = ply.P11_Fed or {}
    local sid = target:SteamID64() or target:SteamID()
    if not ply.P11_Fed[sid] then
        ply.P11_Fed[sid] = true
        if POLUS11.TaskEvent then POLUS11.TaskEvent(ply, "fed") end
    else
        POLUS11.Notify(ply, "Этот уже получал паёк — для нормы нужны РАЗНЫЕ люди.")
    end

    POLUS11.Log("Паёк: " .. ply:Nick() .. " -> " .. target:Nick())
end

function SWEP:SecondaryAttack() end

function SWEP:Reload()
    if SERVER and IsValid(self.Owner) then
        POLUS11.Notify(self.Owner, "ЛКМ вплотную к человеку — выдать паёк. Норма: накормить разных членов экипажа.")
    end
end
