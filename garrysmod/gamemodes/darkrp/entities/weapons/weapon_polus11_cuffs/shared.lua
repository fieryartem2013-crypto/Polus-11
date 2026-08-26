-- ============================================================
--  ПОЛЮС-11 — НАРУЧНИКИ (shared) v4.22.0 «ОКОВЫ»
--  Особый отдел НКВД и командиры РККА (комиссар/генералы).
--  ЛКМ — защёлкнуть на человеке (<=170 юн): снаряжение цели
--  уходит в сохранку, связанный САМ идёт за конвоиром, клавиши
--  связаны. ПКМ/R — отпустить (снаряга вернётся). Камеру
--  оформляет НАЧАЛЬНИК КАРАУЛА (НПС, 📍 «Расставить»).
-- ============================================================

SWEP.PrintName   = "Наручники"
SWEP.Author      = "POLUS-11"
SWEP.Category    = "ПОЛЮС-11"
SWEP.Spawnable   = false
SWEP.AdminOnly   = false
SWEP.Weight      = 1
SWEP.Instructions = "ЛКМ — защёлкнуть на человеке • ПКМ/R — отпустить"

SWEP.HoldType      = "normal"
SWEP.ViewModel     = ""
SWEP.WorldModel    = ""
SWEP.UseHands      = true
SWEP.DrawAmmo      = false
SWEP.DrawCrosshair = true

SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic   = false
SWEP.Primary.Ammo        = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:ShouldDropOnDie()
    return false
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 1.1)
    if CLIENT then return end
    local ow = self:GetOwner()
    if not IsValid(ow) then return end

    local tr = util.TraceLine({
        start  = ow:GetShootPos(),
        endpos = ow:GetShootPos() + ow:GetAimVector() * 170,
        filter = ow,
    })
    local tar = tr.Entity
    if IsValid(tar) and tar:IsPlayer() and tar:Alive() then
        if POLUS11 and POLUS11.CuffTry then POLUS11.CuffTry(ow, tar) end
    else
        ow:EmitSound("weapons/pistol/pistol_empty.wav", 55, 140)
    end
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.9)
    if CLIENT then return end
    local ow = self:GetOwner()
    if IsValid(ow) and POLUS11 and POLUS11.CuffReleaseBy then
        POLUS11.CuffReleaseBy(ow)
    end
end

function SWEP:Reload()
    if CLIENT then return true end
    local ow = self:GetOwner()
    if IsValid(ow) and (self.P11_NextRel or 0) <= CurTime() then
        self.P11_NextRel = CurTime() + 0.9
        if POLUS11 and POLUS11.CuffReleaseBy then
            POLUS11.CuffReleaseBy(ow)
        end
    end
    return true
end

function SWEP:DrawHUD()
    if not CLIENT then return end
    local ow = LocalPlayer()
    if not IsValid(ow) then return end
    local lead = ow:GetNWString("P11_CuffLead", "")
    if lead ~= "" then
        draw.SimpleText("Ведёте: " .. lead .. " — ПКМ/R отпустить, камера у начальника караула",
            "P11.HUD.Text", ScrW() / 2, ScrH() * 0.74, Color(255, 215, 120, 220),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
        draw.SimpleText("Наведи на человека: ЛКМ — наручники. Оформляет арест начальник караула",
            "P11.HUD.Text", ScrW() / 2, ScrH() * 0.74, Color(200, 210, 225, 170),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end
