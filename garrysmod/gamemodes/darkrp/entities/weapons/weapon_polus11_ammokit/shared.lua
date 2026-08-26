-- ============================================================
--  ПОЛЮС-11 — ПАТРОН КИТ (v4.33.0 «ПАТРОН»)
--  Заявка владельца: «добавь свеп Патрон Кит, который восполняет
--  патроны ТОГО типа, какое оружие в руках того, кому патроны
--  даёшь, например arc9_eft_sks. Дай снабженцу».
--
--  Выдаётся СНАБЖЕНЦУ РККА (seed_rkka_snabzhenets).
--   ЛКМ — пополнить бойца в упор: патроны льются ПОД СТВОЛ
--         в его руках (ARC9 EFT в т.ч. arc9_eft_sks — резерв
--         пополняется автоматически, два магазина к стволу);
--   ПКМ — пополнить себе (тот же расчёт по своему оружию).
--   Зарядов: 3 на спавн (новый кит — со свежим снаряжением
--   должности). Кулдаун 2.5 сек. Чужой кит (не снабженец,
--   не админ) не сработает — честный отказ.
-- ============================================================

SWEP.PrintName    = "Патрон Кит"
SWEP.Author       = "POLUS-11"
SWEP.Category     = "ПОЛЮС-11"
SWEP.Instructions = "ЛКМ — пополнить бойца в упор (патроны под его ствол) • ПКМ — пополнить себя"

SWEP.Spawnable      = false  -- только через должность Снабженца РККА
SWEP.AdminSpawnable = false

SWEP.HoldType   = "slam"
SWEP.ViewModel  = ""
SWEP.WorldModel = "models/Items/BoxMRounds.mdl" -- ящик патронов
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

local USES_MAX = 3   -- зарядов кита на спавн
local CD_TIME  = 2.5 -- сек между применениями
local RANGE    = 110 -- юнитов «в упор» (как медкейс)

-- только Снабженец РККА (админ — для проверки)
local function KitAllowed(ply)
    if not IsValid(ply) then return false end
    if P11FW and P11FW.Config and P11FW.Config.Admin and P11FW.Config.Admin(ply) then return true end
    local id = P11FW and P11FW.GetJobId and P11FW.GetJobId(ply) or nil
    return id == "seed_rkka_snabzhenets"
end

-- сколько патронов дать: два магазина к стволу цели (минимум 24, максимум 120)
local function AmmoAmount(wep)
    local mag = wep.GetMaxClip1 and wep:GetMaxClip1() or 0
    if mag and mag > 0 then
        return math.Clamp(math.floor(mag) * 2, 24, 120)
    end
    return 45
end

-- пополнить бойца под оружие в его руках; возвращает строку-итог или nil+причину
local function Refill(ply, target)
    if not (IsValid(target) and target:IsPlayer() and target:Alive()) then
        return nil, "перед тобой нет живого бойца (подойди вплотную, до ~1.5 метров)"
    end

    local wep = target:GetActiveWeapon()
    if not IsValid(wep) then
        return nil, target:Nick() .. " сейчас без оружия"
    end

    local at = wep:GetPrimaryAmmoType()
    if not at or at <= 0 then
        return nil, "у " .. target:Nick() .. " в руках не огнестрел ("
            .. tostring(wep.PrintName or wep:GetClass()) .. ")"
    end

    local amt = AmmoAmount(wep)
    local gave = target:GiveAmmo(amt, at)
    if not gave then
        return nil, "не удалось пополнить — незнакомый тип патронов"
    end

    local aname = game.GetAmmoName and game.GetAmmoName(at) or tostring(at)
    local wname = wep.PrintName or wep:GetClass()
    return string.format("%s: +%d «%s» для %s", target:Nick(), amt, aname, wname), nil
end

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
    if SERVER then
        self.P11_KitUses = USES_MAX
    end
end

function SWEP:Deploy()
    return true
end

-- ЛКМ: пополнить бойца перед собой
function SWEP:PrimaryAttack()
    if not IsFirstTimePredicted() then return end
    self:SetNextPrimaryFire(CurTime() + CD_TIME)
    self:SetNextSecondaryFire(CurTime() + 0.8)
    if CLIENT then return end

    local ply = self.Owner
    if not IsValid(ply) then return end
    if not KitAllowed(ply) then
        POLUS11.Notify(ply, "Патрон-кит не для твоей должности — он в снаряжении СНАБЖЕНЦА РККА.")
        return
    end
    if (self.P11_KitUses or 0) <= 0 then
        POLUS11.Notify(ply, "Патрон-кит пуст — новый выдадут со свежим снаряжением должности.")
        self:SetNextPrimaryFire(CurTime() + 0.4)
        return
    end

    ply:SetAnimation(PLAYER_ATTACK1)

    local tr = util.TraceHull({
        start  = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * RANGE,
        mins   = Vector(-12, -12, -12),
        maxs   = Vector(12, 12, 12),
        filter = ply,
    })
    local t = tr.Entity

    -- запас: ближайший боец в полутора метрах по взгляду
    if not (IsValid(t) and t:IsPlayer() and t:Alive()) then
        local fwd = ply:GetAimVector()
        for _, c in ipairs(player.GetAll()) do
            if c ~= ply and c:Alive() then
                local to = (c:EyePos() - ply:EyePos())
                if to:Length() < RANGE + 20 and to:GetNormalized():Dot(fwd) > 0.5 then
                    t = c break
                end
            end
        end
    end

    local ok, why = Refill(ply, t)
    if not ok then
        POLUS11.Notify(ply, why)
        self:SetNextPrimaryFire(CurTime() + 0.4)
        return
    end

    self.P11_KitUses = self.P11_KitUses - 1
    ply:EmitSound("items/ammo_pickup2.wav", 65, 100)
    t:EmitSound("items/ammo_pickup2.wav", 60, 105)
    local ed = EffectData()
    ed:SetOrigin(t:GetPos() + Vector(0, 0, 45))
    util.Effect("HelicopterMegaBomb", ed, true, true)

    POLUS11.Notify(ply, "📦 " .. ok .. " (зарядов кита: " .. self.P11_KitUses .. ")")
end

-- ПКМ: пополнить себя
function SWEP:SecondaryAttack()
    if not IsFirstTimePredicted() then return end
    self:SetNextSecondaryFire(CurTime() + CD_TIME)
    self:SetNextPrimaryFire(CurTime() + 0.8)
    if CLIENT then return end

    local ply = self.Owner
    if not IsValid(ply) then return end
    if not KitAllowed(ply) then
        POLUS11.Notify(ply, "Патрон-кит не для твоей должности — он в снаряжении СНАБЖЕНЦА РККА.")
        return
    end
    if (self.P11_KitUses or 0) <= 0 then
        POLUS11.Notify(ply, "Патрон-кит пуст — новый выдадут со свежим снаряжением должности.")
        self:SetNextSecondaryFire(CurTime() + 0.4)
        return
    end

    local ok, why = Refill(ply, ply)
    if not ok then
        POLUS11.Notify(ply, why)
        self:SetNextSecondaryFire(CurTime() + 0.4)
        return
    end

    self.P11_KitUses = self.P11_KitUses - 1
    ply:EmitSound("items/ammo_pickup2.wav", 60, 100)
    POLUS11.Notify(ply, "📦 " .. ok .. " (зарядов кита: " .. self.P11_KitUses .. ")")
end

-- клиент: подсказка + инфо о стволе цели
if CLIENT then
    function SWEP:DrawHUD()
        local ply = self.Owner
        if not IsValid(ply) then return end
        local w, h = ScrW(), ScrH()
        draw.SimpleText("ПАТРОН КИТ | ЛКМ — пополнить бойца · ПКМ — себе",
            "Trebuchet18", w * 0.5, h - 70, Color(240, 205, 110),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local tr = util.TraceHull({
            start  = ply:GetShootPos(),
            endpos = ply:GetShootPos() + ply:GetAimVector() * RANGE,
            mins   = Vector(-12, -12, -12),
            maxs   = Vector(12, 12, 12),
            filter = ply,
        })
        local t = tr.Entity
        if IsValid(t) and t:IsPlayer() and t:Alive() and t ~= ply then
            local wep = t:GetActiveWeapon()
            local line
            if IsValid(wep) then
                local at = wep:GetPrimaryAmmoType()
                if at and at > 0 then
                    local aname = game.GetAmmoName and game.GetAmmoName(at) or "патроны"
                    line = "📦 " .. t:Nick() .. ": " .. tostring(wep.PrintName or wep:GetClass())
                        .. " («" .. aname .. "») — пополнить [ЛКМ]"
                else
                    line = t:Nick() .. " держит не огнестрел — пополнить нечего"
                end
            else
                line = t:Nick() .. " сейчас без оружия"
            end
            draw.SimpleText(line, "Trebuchet18", w * 0.5, h * 0.58,
                Color(240, 205, 110), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end
