-- ============================================================
--  ПОЛЮС-11 — СКАЛЬПЕЛЬ (вскрытие трупов)
--  ЛКМ по трупу — вскрытие (не двигаться!). Через ~5 сек
--  точный ответ: человек это был или НЕЧТО (по состоянию
--  заражения НА МОМЕНТ СМЕРТИ — в отличие от теста крови,
--  труп не обновляется).
--  R — вкл/выкл ПОДДЕЛКУ (только у заражённого вирусолога):
--  результат всегда будет «чисто».
-- ============================================================

SWEP.PrintName    = "Скальпель патологоанатома"
SWEP.Author       = "POLUS-11"
SWEP.Category     = "ПОЛЮС-11"
SWEP.Instructions = "ЛКМ по трупу — вскрытие (5 сек, не двигаться) | R (заражённый учёный) — подделать результат"

SWEP.Spawnable      = true
SWEP.AdminSpawnable = false

SWEP.HoldType   = "knife"
SWEP.ViewModel  = "models/weapons/c_knife_t.mdl"
SWEP.WorldModel = "models/weapons/w_knife_t.mdl"
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

local function FindCorpse(ply)
    local tr = util.TraceHull({
        start  = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * 130,
        mins   = Vector(-18, -18, -18),
        maxs   = Vector(18, 18, 18),
        filter = ply,
    })
    local e = tr.Entity
    if IsValid(e) and e:GetClass() == "prop_ragdoll" and istable(e.P11_Identity) then
        return e
    end
    return nil
end

function SWEP:PrimaryAttack()
    local ply = self.Owner
    if not IsValid(ply) then return end
    self:SetNextPrimaryFire(CurTime() + 1)

    if self.Autopsy then return end -- уже режем
    if CLIENT then return end

    if not POLUS11.IsScientist(ply) then
        POLUS11.Notify(ply, "Вскрытие умеет делать только научный персонал!")
        return
    end

    local corpse = FindCorpse(ply)
    if not IsValid(corpse) then
        POLUS11.Notify(ply, "Подойди к трупу человека (под прицелом).")
        return
    end
    if corpse.P11_Autopsied then
        POLUS11.Notify(ply, "Тело уже вскрыто — ткани испорчены.")
        return
    end

    self.Autopsy = {
        corpse  = corpse,
        endsAt  = CurTime() + (POLUS11.Config.AutopsyTime or 5),
        startPos = ply:GetPos(),
    }
    ply:EmitSound("physics/flesh/flesh_impact_hard" .. math.random(1, 4) .. ".wav", 55, 95)
    POLUS11.Notify(ply, "Вскрытие «" .. (corpse.P11_Identity.nick or "?") .. "»... Не двигайтесь.")
end

-- подделка результата (R) — для заражённого вирусолога
function SWEP:Reload()
    if CLIENT or not IsFirstTimePredicted() then return end
    local ply = self.Owner
    if not IsValid(ply) then return end

    self.NextR = self.NextR or 0
    if CurTime() < self.NextR then return end
    self.NextR = CurTime() + 1

    local isThing = ply:GetNWBool("P11_Infected", false) and ply:GetNWBool("P11_InfActive", false)
    if not isThing then
        POLUS11.Notify(ply, "R — подделка вскрытия (доступна лишь «своему» вирусологу...) ")
        return
    end

    self.FakeResult = not self.FakeResult
    POLUS11.Notify(ply, self.FakeResult
        and "ПОДДЕЛКА ВКЛ: любое вскрытие покажет «человек»."
        or  "Подделка выкл: вскрытия будут честными.")
end

function SWEP:Think()
    if CLIENT then return end
    local a = self.Autopsy
    if not a then return end

    local ply = self.Owner
    local bad = (not IsValid(ply)) or (not ply:Alive())
        or (not IsValid(a.corpse))
        or (ply:GetPos():DistToSqr(a.startPos) > 40 * 40)
        or (ply:GetPos():DistToSqr(a.corpse:GetPos()) > 160 * 160)

    if bad then
        self.Autopsy = nil
        if IsValid(ply) then POLUS11.Notify(ply, "Вскрытие прервано.") end
        return
    end

    if CurTime() >= a.endsAt then
        local corpse = a.corpse
        self.Autopsy = nil
        corpse.P11_Autopsied = true

        local id = corpse.P11_Identity or {}
        local thing = id.infected == true
        if self.FakeResult then thing = false end

        -- эффекты
        local ed = EffectData()
        ed:SetOrigin(corpse:GetPos() + Vector(0, 0, 20))
        util.Effect("BloodImpact", ed, true, true)
        ply:EmitSound("physics/flesh/flesh_squishy_impact_hard" .. math.random(1, 4) .. ".wav", 60, 90)

        if thing then
            POLUS11.Notify(ply, "ВСКРЫТИЕ [" .. (id.nick or "?") .. "]: В ТКАНЯХ ЧУЖАЯ МАССА. ЭТО БЫЛО НЕЧТО!")
            PrintMessage(HUD_PRINTTALK, "[Лаборатория] Вскрытие " .. (id.nick or "?") .. ": ОБНАРУЖЕНА ЧУЖДАЯ ТКАНЬ — ЭТО БЫЛО НЕЧТО.")
            corpse:EmitSound("npc/zombie_poison/pz_alert1.wav", 90, 90)
        else
            POLUS11.Notify(ply, "ВСКРЫТИЕ [" .. (id.nick or "?") .. "]: ткани человеческие. Чист.")
            PrintMessage(HUD_PRINTTALK, "[Лаборатория] Вскрытие " .. (id.nick or "?") .. ": человек.")
        end

        if POLUS11.TaskEvent then POLUS11.TaskEvent(ply, "autopsy") end
        POLUS11.Log("ВСКРЫТИЕ [" .. (id.nick or "?") .. "]: " .. (thing and "НЕЧТО" or "чист")
            .. (self.FakeResult and " (ПОДДЕЛАНО!)" or "") .. " | резал " .. ply:Nick())
    end
end

function SWEP:Holster()
    if SERVER and self.Autopsy then
        self.Autopsy = nil
        if IsValid(self.Owner) then
            POLUS11.Notify(self.Owner, "Вскрытие прервано.")
        end
    end
    return true
end

function SWEP:SecondaryAttack() end

if CLIENT then
    function SWEP:DrawHUD()
        -- подсказка по трупу
        local ply = self.Owner
        if not IsValid(ply) then return end
        local tr = ply:GetEyeTrace()
        local e = tr.Entity
        if IsValid(e) and e:GetNWString("P11_CorpseName", "") ~= "" then
            draw.SimpleText("[ЛКМ] — ВСКРЫТИЕ: " .. e:GetNWString("P11_CorpseName", ""),
                "P11.HUD.Text", ScrW() / 2, ScrH() * 0.58, Color(150, 220, 255),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end
