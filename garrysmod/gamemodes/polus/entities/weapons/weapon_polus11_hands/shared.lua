-- ============================================================
--  ПОЛЮС-11 — ПУСТЫЕ РУКИ (shared) v3.0
--  Абсолютно пустые руки. Никакого урона — это знак мира:
--  «я без оружия». Классика ролеплея. Выдаётся ВСЕМ
--  через BaseLoadout (рядом с кулаками и физганом).
-- ============================================================

SWEP.PrintName   = "Пустые руки"
SWEP.Author      = "POLUS-11"
SWEP.Category    = "ПОЛЮС-11"
SWEP.Spawnable   = false
SWEP.AdminOnly   = false
SWEP.Weight      = 0

SWEP.HoldType        = "normal"
SWEP.ViewModel       = ""
SWEP.WorldModel      = ""
SWEP.UseHands        = true
SWEP.DrawAmmo        = false
SWEP.DrawCrosshair   = false

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

function SWEP:PrimaryAttack() end
function SWEP:SecondaryAttack() end

function SWEP:Reload()
    return true
end

function SWEP:DrawHUD()
    if not IsValid(self.Owner) or not self.Owner:Alive() then return end
    if (CurTime() % 5) > 3.5 then return end
    draw.SimpleText("Пустые руки — знак мира. Ударные: «Кулаки».",
        "P11.HUD.Text", ScrW() / 2, ScrH() * 0.74, Color(200, 210, 225, 180),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end
