-- ============================================================
--  ПОЛЮС-11 — ПОЛЕВОЙ МЕДИЦИНСКИЙ КЕЙС (ванильный медкит) v4.8.8
--  Выдаётся ВСЕМ медикам: Полевой медик, Медсестра РККА,
--  Главная Медсестра РККА. Модель и звуки — стоковый HL2
--  (vanilla): латать раненых лицом к лицу.
--   ЛКМ — обработать раненого перед собой (+12 ХП, 1.3 сек)
--   ПКМ — перевязать себя (+8 ХП, 4 сек)
--  Над головой раненого медик видит подсказку; аура перегрева
--  не лечит: не залатать мясорубку — медик поддержка, не батарея.
-- ============================================================

SWEP.PrintName    = "Полевой медицинский кейс"
SWEP.Author       = "POLUS-11"
SWEP.Category     = "ПОЛЮС-11"
SWEP.Instructions = "ЛКМ — обработать раненого (+12 ХП, в упор) • ПКМ — перевязать себя (+8 ХП)"

SWEP.Spawnable      = true
SWEP.AdminSpawnable = true

SWEP.HoldType   = "slam"
SWEP.ViewModel  = ""
SWEP.WorldModel = "models/Items/HealthKit.mdl" -- стоковый HL2-медкит (ваниль)
SWEP.UseHands   = false

SWEP.DrawAmmo       = false
SWEP.DrawCrosshair  = true

SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic   = false
SWEP.Primary.Ammo        = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

SWEP.Weight = 1

local HEAL_OTHER = 12
local HEAL_SELF  = 8
local CD_OTHER   = 1.3
local CD_SELF    = 4.0

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

local function MaxHPOf(ply)
    local m = ply:GetMaxHealth() or 0
    return m > 0 and m or 100
end

-- ЛКМ: лечим раненого в упор
function SWEP:PrimaryAttack()
    if not IsFirstTimePredicted() then return end
    self:SetNextPrimaryFire(CurTime() + CD_OTHER)
    self:SetNextSecondaryFire(CurTime() + 0.8)
    if CLIENT then return end

    local ply = self.Owner
    if not IsValid(ply) then return end
    ply:SetAnimation(PLAYER_ATTACK1)

    local tr = util.TraceHull({
        start  = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * 110,
        mins   = Vector(-12, -12, -12),
        maxs   = Vector(12, 12, 12),
        filter = ply,
    })
    local t = tr.Entity

    -- запас: ближайший раненый в полутора метрах по взгляду
    if not (IsValid(t) and t:IsPlayer() and t:Alive()) then
        local fwd = ply:GetAimVector()
        for _, c in ipairs(player.GetAll()) do
            if c ~= ply and c:Alive() then
                local to = (c:EyePos() - ply:EyePos())
                if to:Length() < 130 and to:GetNormalized():Dot(fwd) > 0.5 then
                    t = c break
                end
            end
        end
    end

    if not (IsValid(t) and t:IsPlayer() and t:Alive()) then
        POLUS11.Notify(ply, "Перед тобой нет пациента (подойди вплотную, до ~1.5 метров).")
        self:SetNextPrimaryFire(CurTime() + 0.4)
        return
    end

    local maxhp = MaxHPOf(t)
    if t:Health() >= maxhp then
        POLUS11.Notify(ply, t:Nick() .. " здоров — лечить нечего.")
        self:SetNextPrimaryFire(CurTime() + 0.4)
        return
    end

    t:SetHealth(math.min(maxhp, t:Health() + HEAL_OTHER))
    t:EmitSound("items/medshot4.wav", 65, 100)
    ply:EmitSound("items/smallmedkit1.wav", 60, 105)

    local ed = EffectData()
    ed:SetOrigin(t:GetPos() + Vector(0, 0, 45))
    util.Effect("HelicopterMegaBomb", ed, true, true) -- лёгкий белый пых повязки

    POLUS11.Notify(ply, "🩹 Обработан: " .. t:Nick() .. " (" ..
        math.min(maxhp, t:Health()) .. "/" .. maxhp .. " ХП).")
end

-- ПКМ: перевязать себя
function SWEP:SecondaryAttack()
    if not IsFirstTimePredicted() then return end
    self:SetNextSecondaryFire(CurTime() + CD_SELF)
    self:SetNextPrimaryFire(CurTime() + 0.8)
    if CLIENT then return end

    local ply = self.Owner
    if not IsValid(ply) then return end

    local maxhp = MaxHPOf(ply)
    if ply:Health() >= maxhp then
        POLUS11.Notify(ply, "Ты цел — бинты расходовать не на что.")
        self:SetNextSecondaryFire(CurTime() + 0.4)
        return
    end
    ply:SetHealth(math.min(maxhp, ply:Health() + HEAL_SELF))
    ply:EmitSound("items/smallmedkit1.wav", 60, 100)
end

-- клиент: подсказка над раненым рядом + статусный штрих
if CLIENT then
    function SWEP:DrawHUD()
        local ply = self.Owner
        if not IsValid(ply) then return end
        local w, h = ScrW(), ScrH()
        draw.SimpleText("МЕДКЕЙС | ЛКМ — лечить раненого · ПКМ — себя",
            "Trebuchet18", w * 0.5, h - 70, Color(150, 230, 190),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local tr = util.TraceHull({
            start  = ply:GetShootPos(),
            endpos = ply:GetShootPos() + ply:GetAimVector() * 110,
            mins   = Vector(-12, -12, -12),
            maxs   = Vector(12, 12, 12),
            filter = ply,
        })
        local t = tr.Entity
        if IsValid(t) and t:IsPlayer() and t:Alive() then
            local maxhp = t:GetMaxHealth() > 0 and t:GetMaxHealth() or 100
            local hurt = t:Health() < maxhp
            draw.SimpleText(hurt and ("🩹 " .. t:Nick() .. ": " .. t:Health() .. "/" .. maxhp .. " ХП — можно обработать [ЛКМ]")
                or (t:Nick() .. " здоров"),
                "Trebuchet18", w * 0.5, h * 0.58,
                hurt and Color(120, 255, 160) or Color(170, 180, 190),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end
