-- ============================================================
--  ПОЛЮС-11 — Шприц для забора крови
-- ============================================================

SWEP.PrintName    = "Шприц (забор крови)"
SWEP.Author       = "POLUS-11"
SWEP.Category     = "ПОЛЮС-11"
SWEP.Instructions = "ЛКМ в упор по игроку — взять кровь в колбу | R — выбросить колбу"

SWEP.Spawnable      = true
SWEP.AdminSpawnable = true

SWEP.HoldType   = "pistol"
SWEP.ViewModel  = ""
SWEP.WorldModel = "models/weapons/w_pistol.mdl"
SWEP.UseHands   = false

SWEP.DrawAmmo = false

SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic   = false
SWEP.Primary.Ammo        = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

SWEP.Weight = 1

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

local function CarriedVial(ply)
    for _, e in ipairs(ents.FindByClass("polus11_vial")) do
        if e:GetParent() == ply then return e end
    end
    return nil
end

function SWEP:PrimaryAttack()
    local ply = self.Owner
    if not IsValid(ply) then return end

    self:SetNextPrimaryFire(CurTime() + POLUS11.Config.SyringeCooldown)
    ply:SetAnimation(PLAYER_ATTACK1)

    if CLIENT then return end

    if not POLUS11.IsScientist(ply) then
        POLUS11.Notify(ply, "Забор крови делают только учёные!")
        return
    end

    if CarriedVial(ply) then
        POLUS11.Notify(ply, "У вас уже есть колба! Отнесите её к лабораторному столу (R — выбросить).")
        return
    end

    local tr = util.TraceLine({
        start = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * 100,
        filter = ply,
    })

    local target = tr.Entity
    if not IsValid(target) or not target:IsPlayer() or not target:Alive() then
        ply:EmitSound("weapons/pistol/pistol_empty.wav", 60, 110)
        return
    end

    -- кулдаун на одного донора
    target.P11_LastBled = target.P11_LastBled or 0
    if CurTime() - target.P11_LastBled < POLUS11.Config.BloodPerTargetCooldown then
        POLUS11.Notify(ply, "У этого игрока недавно брали кровь. Подождите.")
        return
    end
    target.P11_LastBled = CurTime()

    -- эффект укола
    target:EmitSound("npc/headcrab/attack1.wav", 60, 110)
    target:ViewPunch(Angle(3, math.random(-2, 2), 0))
    local ed = EffectData()
    ed:SetOrigin(tr.HitPos)
    ed:SetNormal(tr.HitNormal)
    util.Effect("BloodImpact", ed, true, true)
    POLUS11.Notify(target, ply:Nick() .. " взял у вас кровь для анализа!")

    -- спавним колбу: кровь запоминает состояние донора НА МОМЕНТ ЗАБОРА
    local vial = ents.Create("polus11_vial")
    if not IsValid(vial) then return end
    vial:SetPos(ply:GetPos() + Vector(0, 0, 30))
    vial:Spawn()
    vial:SetDonorName(target:Nick())
    vial.DonorInfected = POLUS11.IsInfected(target) -- скрыто от всех
    vial:PickUp(ply)

    POLUS11.Log("Взята кровь у " .. target:Nick() .. " (берёт: " .. ply:Nick() .. ")")
    if POLUS11.TaskEvent then POLUS11.TaskEvent(ply, "blood_draw") end -- задача учёных
end

function SWEP:SecondaryAttack() end

-- R: выбросить колбу
function SWEP:Reload()
    if CLIENT or not IsFirstTimePredicted() then return end
    local ply = self.Owner
    local vial = CarriedVial(ply)
    if IsValid(vial) then
        vial:Drop(ply:GetPos() + ply:GetForward() * 20)
        POLUS11.Notify(ply, "Колба снята с руки.")
    end
end
