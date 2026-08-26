-- ============================================================
--  ПОЛЮС-11 — ХИМСВЕТ (аварийный свет станции)
--  ЛКМ — сломать и бросить: светится ~10 минут. Спасает
--  в блэкаут: у Нечто бафф в темноте, у людей — химсвет.
-- ============================================================

SWEP.PrintName    = "Химсвет"
SWEP.Author       = "POLUS-11"
SWEP.Category     = "ПОЛЮС-11"
SWEP.Instructions = "ЛКМ — активировать и бросить (светит ~10 мин) | R — проверить запас"

SWEP.Spawnable      = true
SWEP.AdminSpawnable = false

SWEP.HoldType   = "slam"
SWEP.ViewModel  = "models/weapons/c_stunstick.mdl"
SWEP.WorldModel = "models/props_junk/flare.mdl"
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

SWEP.Weight = 1

function SWEP:SetupDataTables()
    self:NetworkVar("Int", 0, "Charges")
end

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
    if SERVER and self:GetCharges() <= 0 then
        self:SetCharges(POLUS11.Config.ChemlightGive or 2)
    end
end

function SWEP:PrimaryAttack()
    local ply = self.Owner
    if not IsValid(ply) then return end
    self:SetNextPrimaryFire(CurTime() + 0.6)

    if SERVER then
        if self:GetCharges() <= 0 then
            POLUS11.Notify(ply, "Химсветы кончились.")
            self:EmitSound("weapons/pistol/pistol_empty.wav", 55, 100)
            return
        end
        self:SetCharges(self:GetCharges() - 1)

        local stick = ents.Create("polus11_chemlight")
        if not IsValid(stick) then return end
        stick:SetPos(ply:GetShootPos() + ply:GetAimVector() * 24)
        stick:SetOwner(ply)
        stick:Spawn()

        local phys = stick:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetVelocity(ply:GetAimVector() * 420 + Vector(0, 0, 90))
        end

        ply:EmitSound("ambient/energy/zap1.wav", 55, 130)
        if self:GetCharges() <= 0 then
            timer.Simple(0.4, function()
                if IsValid(self) and IsValid(ply) then self:Remove() end
            end)
        end
    end
end

function SWEP:SecondaryAttack() end

function SWEP:Reload()
    if SERVER and IsValid(self.Owner) then
        POLUS11.Notify(self.Owner, "Осталось химсветов: " .. self:GetCharges())
    end
end

if CLIENT then
    function SWEP:DrawWeaponSelection() end
    function SWEP:DrawHUD()
        draw.SimpleText("ХИМСВЕТОВ: " .. self:GetCharges(), "DermaDefaultBold",
            ScrW() - 24, ScrH() - 60, Color(150, 255, 170), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
end
