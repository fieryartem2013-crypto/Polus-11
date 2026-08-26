-- ============================================================
--  ПОЛЮС-11 — ШВАБРА УБОРЩИКА (v5.3.4, НОВЫЙ СВЕП)
--  Владелец: «добавь швабру с миниигрой для уборщика для заработка».
--  Выдаётся УБОРЩИКУ автоматически (p11_sv_mop_v534_autorun).
--  ЛКМ по грязи (polus_p11_dirt) — миниигра «УБОРКА ШВАБРОЙ»:
--  успех → грязь убрана + деньги (CleanPay×2) + жетон (если включено).
--  ЛКМ без грязи — «машет шваброй» (для атмосферы, кулдаун).
--  Старые файлы не трогаем.
-- ============================================================

SWEP.PrintName    = "Швабра уборщика"
SWEP.Author       = "POLUS-11"
SWEP.Category     = "ПОЛЮС-11"
SWEP.Instructions = "ЛКМ по грязи — прибрать (миниигра) · просто ЛКМ — помахать"

SWEP.Spawnable      = false
SWEP.AdminSpawnable = false

SWEP.HoldType   = "melee"
SWEP.ViewModel  = ""
SWEP.WorldModel = "models/props_c17/mop.mdl"
SWEP.UseHands   = false

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

SWEP.Weight = 1

local CD = 1.2 -- сек между «взмахами»

-- выдаётся только уборщику
local function Allowed(ply)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() or ply:IsAdmin() then return true end
    if P11FW and P11FW.GetJobId then
        return P11FW.GetJobId(ply) == "janitor"
    end
    return false
end

function SWEP:Deploy()
    self:SetNextPrimaryFire(CurTime() + 0.4)
    return true
end

function SWEP:PrimaryAttack()
    if not Allowed(self.Owner) then
        if IsValid(self.Owner) and POLUS11 and POLUS11.Notify then
            POLUS11.Notify(self.Owner, "Швабра — только для УБОРЩИКА.")
        end
        self:SetNextPrimaryFire(CurTime() + CD)
        return
    end
    self:SetNextPrimaryFire(CurTime() + CD)

    local ply = self.Owner
    if not IsValid(ply) then return end

    -- ищем грязь под прицелом
    local tr = ply:GetEyeTrace()
    local ent = tr and tr.Entity
    if IsValid(ent) and ent:GetClass() == "polus_p11_dirt" then
        if POLUS11 and POLUS11.MopClean then
            POLUS11.MopClean(ply, ent)
        else
            if POLUS11 and POLUS11.Notify then
                POLUS11.Notify(ply, "Модуль швабры не проснулся — смотри [POLUS][ERROR] в консоли.")
            end
        end
        return
    end

    -- просто взмах (атмосфера)
    if IsValid(ply) then
        ply:EmitSound("physics/flesh/flesh_impact_hard1.wav", 55, 110)
    end
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + CD)
    if IsValid(self.Owner) then
        self.Owner:EmitSound("physics/flesh/flesh_impact_hard2.wav", 55, 100)
    end
end

function SWEP:Holster()
    return true
end

function SWEP:OnDrop()
    return false
end
