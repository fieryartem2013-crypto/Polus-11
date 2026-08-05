-- ============================================================
--  ПОЛЮС-11 — Армейская рация
--  R — переключить канал (Гарнизон / Лаборатория / Общий)
--  Текст в эфир: /r сообщение
--  Голос: в эфире слышат все на вашем канале.
-- ============================================================

SWEP.PrintName    = "Рация"
SWEP.Author       = "POLUS-11"
SWEP.Category     = "ПОЛЮС-11"
SWEP.Instructions = "R — канал | /r текст в эфир | Голос идёт в канал автоматически"

SWEP.Spawnable      = true
SWEP.AdminSpawnable = true

SWEP.HoldType   = "slam"
SWEP.ViewModel  = ""
SWEP.WorldModel = "models/props_lab/reciever01a.mdl"
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

local ORDER = {"garrison", "lab", "all"}

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:Deploy()
    if SERVER then
        local cur = self.Owner:GetNWString("P11_RadioCh", "")
        if cur == "" then
            self.Owner:SetNWString("P11_RadioCh", "garrison")
        end
    end
    return true
end

function SWEP:PrimaryAttack() end
function SWEP:SecondaryAttack() end

function SWEP:Reload()
    if not IsFirstTimePredicted() then return end
    local ply = self.Owner
    if not IsValid(ply) then return end

    self.NextReload = self.NextReload or 0
    if CurTime() < self.NextReload then return end
    self.NextReload = CurTime() + 0.8

    local cur = ply:GetNWString("P11_RadioCh", "garrison")
    local next = 1
    for i, ch in ipairs(ORDER) do
        if ch == cur then
            next = (i % #ORDER) + 1
            break
        end
    end

    local newCh = ORDER[next]
    if SERVER then
        ply:SetNWString("P11_RadioCh", newCh)
        POLUS11.Notify(ply, "Канал: " .. (POLUS11.RadioChannels[newCh] or newCh))
    end
end

-- ==================== HUD: канал ====================

if CLIENT then
    function SWEP:DrawHUD()
        local ply = self.Owner
        if not IsValid(ply) then return end

        local ch = ply:GetNWString("P11_RadioCh", "garrison")
        local name = (POLUS11.RadioChannels and POLUS11.RadioChannels[ch]) or ch

        local w, h = ScrW(), ScrH()
        -- v3.8: сдвинуто ВПРАВО от панели состояния (та занимает x 8..296)
        -- и чуть ниже — больше не перекрывает чужой HUD
        draw.RoundedBox(6, 306, h - 110, 250, 36, Color(8, 12, 18, 170))

        local col = Color(120, 220, 120)
        local prefix = "РАЦИЯ: "
        if GetGlobalBool("P11_Storm", false) then
            col = Color(255, 120, 100)
            prefix = "БУРЯ! "
        end

        draw.SimpleText("📻", "DermaDefaultBold", 318, h - 100, Color(170, 190, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(prefix .. name, "DermaDefaultBold", 340, h - 100, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
end
