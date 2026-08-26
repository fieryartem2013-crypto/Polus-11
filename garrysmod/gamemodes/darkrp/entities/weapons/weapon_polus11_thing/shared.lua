-- ============================================================
--  ПОЛЮС-11 — Класс Нечто: «ИМИТАТОР» (v4.8.8 «ЛИЧИНА»)
--  ЛКМ — когти (атака выдаёт тварь: облик монстра на 20 сек);
--        убийство когтями САМО жрёт труп жертвы и надевает ЛИЧИНУ
--        (ядро «ЛИЧИНА 2.0»: p11_sv_thingcore, без трупо-гонок).
--  ПКМ — тихий укол заражения (цель не узнаёт сразу)
--  R по трупу — СЪЕСТЬ ТРУП вручную (личность целиком: облик,
--        позывной, должность, код документа)
--  R без трупа — МЕНЮ МУТАЦИЙ (личина/форма/маскировка)
--  Личина/снятие/хранение личности — только через ядро
--  (POLUS11.ThingApplyIdentity / ThingRestoreIdentity /
--   ThingDevourCorpse): дубли-код прошлых версий вырезан.
-- ============================================================

SWEP.PrintName    = "НЕЧТО: Имитатор"
SWEP.Author       = "POLUS-11"
SWEP.Category     = "ПОЛЮС-11"
SWEP.Instructions = "ЛКМ — когти: убийство САМО съедает труп и надевает личину | ПКМ — тихий укол | R — МЕНЮ МУТАЦИЙ (личина/форма/маскировка) | R по трупу — съесть"

SWEP.Spawnable      = true
SWEP.AdminSpawnable = true
SWEP.AdminOnly      = true

SWEP.HoldType   = "melee"
SWEP.ViewModel  = ""
SWEP.WorldModel = ""
SWEP.UseHands   = false

SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic   = true
SWEP.Primary.Ammo        = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

SWEP.Weight = 5

local REVEAL_TIME = 20

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

local function SaveModel(ply)
    if not ply.P11_SavedModel then
        ply.P11_SavedModel = ply:GetModel()
    end
end

function POLUS11_RevealThing(ply, wep)
    if ply.P11_Revealed then return end
    SaveModel(ply)

    ply.P11_Revealed = true
    ply.P11_RevealedAt = CurTime()
    ply:SetNWBool("P11_Revealed", true)

    -- модель монстра по ТЕКУЩЕЙ форме (у каждой формы своё тело)
    local mdl = POLUS11.MonsterModels.brute
    local forms = POLUS11.ThingForms or {}
    local form = forms[ply.P11_ThingForm or ""]
    if form and isstring(form.model) then mdl = form.model end
    -- мутация Т3 «АРАХНА» — паучья туша поверх любой формы
    if (ply:GetNWInt("P11_MutTier", 0) or 0) >= 3 then
        mdl = "models/zombie/fast.mdl"
    end
    ply:SetModel(mdl)

    -- форма «Поглотитель»: тяжёлое тело возвращается вместе с явлением
    if (ply.P11_ThingForm == "brute") and ply:HasWeapon("weapon_polus11_thing_brute") and P11_BruteApply then
        P11_BruteApply(ply)
    end

    ply:EmitSound("npc/zombie_poison/pz_alert2.wav", 90, 90)

    -- кровавый всплеск трансформации
    local ed = EffectData()
    ed:SetOrigin(ply:GetPos() + Vector(0, 0, 40))
    util.Effect("BloodImpact", ed, true, true)
    util.Effect("bloodspray", ed, true, true)

    POLUS11.Log("РАСКРЫЛСЯ: " .. ply:Nick())

    timer.Simple(REVEAL_TIME, function()
        if IsValid(ply) and ply.P11_Revealed then
            POLUS11_HideThing(ply)
        end
    end)
end

function POLUS11_HideThing(ply)
    if not ply.P11_Revealed then return end
    ply.P11_Revealed = false
    ply:SetNWBool("P11_Revealed", false)

    -- замаскированный Поглотитель теряет тяжёлое тело (полная маскировка)
    if (ply.P11_ThingForm == "brute") and P11_BruteRemove then
        P11_BruteRemove(ply)
    end

    if ply.P11_SavedModel then
        ply:SetModel(ply.P11_SavedModel)
        ply.P11_SavedModel = nil
    end
end

-- ==================== КОГТИ ====================

function SWEP:PrimaryAttack()
    local ply = self.Owner
    if not IsValid(ply) then return end

    self:SetNextPrimaryFire(CurTime() + 0.8)
    self:SetNextSecondaryFire(CurTime() + 0.4)

    ply:SetAnimation(PLAYER_ATTACK1)
    ply:EmitSound("npc/zombie/claw_miss" .. math.random(1, 2) .. ".wav", 75, 100 + math.random(-8, 8))

    if CLIENT then return end

    -- атака обнажает Нечто
    POLUS11_RevealThing(ply, self)

    local tr = util.TraceHull({
        start  = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * 110,
        mins   = Vector(-16, -16, -16),
        maxs   = Vector(16, 16, 16),
        filter = {ply, self},
        mask   = MASK_SHOT_HULL,
    })

    local ent = tr.Entity
    if IsValid(ent) then
        local dmg = DamageInfo()
        dmg:SetDamage((ply.P11_Revealed and 55 or 40) + ply:GetNWInt("P11_MutDmg", 0)) -- раскрытие + бафф мутацией
        dmg:SetAttacker(ply)
        dmg:SetInflictor(self)
        dmg:SetDamageType(DMG_SLASH)
        dmg:SetDamagePosition(tr.HitPos)
        dmg:SetDamageForce(ply:GetAimVector() * 300 + Vector(0, 0, 100))
        ent:TakeDamageInfo(dmg)

        ent:EmitSound("physics/flesh/flesh_impact_bullet" .. math.random(1, 5) .. ".wav", 70, math.random(90, 110))

        local ed = EffectData()
        ed:SetOrigin(tr.HitPos)
        ed:SetNormal(tr.HitNormal)
        util.Effect("BloodImpact", ed, true, true)

        -- убийство этим ударом перехватит ядро «ЛИЧИНА 2.0»:
        -- труп жертвы съеден, её личина надета автоматически.
    elseif tr.Hit then
        ply:EmitSound("npc/zombie/claw_strike" .. math.random(1, 3) .. ".wav", 70, 100)
        util.Decal("ManhackCut", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal)
    end
end

-- ==================== ТИХИЙ УКОЛ (ПКМ) ====================

function SWEP:SecondaryAttack()
    local ply = self.Owner
    if not IsValid(ply) then return end

    self.NextNeedle = self.NextNeedle or 0
    if CurTime() < self.NextNeedle then
        if SERVER then
            POLUS11.Notify(ply, "Игла ещё не восстановилась (" .. math.ceil(self.NextNeedle - CurTime()) .. " сек)")
        end
        self:SetNextSecondaryFire(CurTime() + 0.5)
        return
    end
    self:SetNextSecondaryFire(CurTime() + 1)

    if CLIENT then return end

    -- гуманный захват цели — толстый след + конус поиска
    local target = nil
    local tr = util.TraceHull({
        start  = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * 150,
        mins   = Vector(-14, -14, -14),
        maxs   = Vector(14, 14, 14),
        filter = ply,
    })
    local e0 = tr.Entity
    if IsValid(e0) and e0:IsPlayer() and e0:Alive() then target = e0 end
    if not IsValid(target) then
        local eye, fwd = ply:EyePos(), ply:GetAimVector()
        local bestDist = 165
        for _, t in ipairs(player.GetAll()) do
            if t ~= ply and IsValid(t) and t:Alive() then
                local toT = (t:EyePos() - eye)
                local d = toT:Length()
                if d < bestDist then
                    toT:Normalize()
                    if toT:Dot(fwd) > 0.55 then
                        target, bestDist = t, d
                    end
                end
            end
        end
    end
    if not IsValid(target) then
        POLUS11.Notify(ply, "Рядом нет цели для укола (нужен человек в упор — до полутора метров).")
        return
    end

    if POLUS11.IsInfected(target) then
        POLUS11.Notify(ply, "Он уже наш.")
        return
    end

    self.NextNeedle = CurTime() + 90

    -- тихий укол: жертва НЕ получает страшных сообщений
    POLUS11.Infect(target, "укол от " .. ply:Nick(), false)
    target:EmitSound("npc/headcrab/attack1.wav", 45, 125)
    target:ViewPunch(Angle(2, math.random(-1, 1), 0))

    POLUS11.Notify(ply, "Укол сделан. Жертва: " .. target:Nick() .. ". Инкубация пошла...")
    ply:EmitSound("items/smallmedkit1.wav", 55, 90)
end

-- ==================== ПОИСК СЪЕДОБНОГО ТРУПА ====================

local function TraceCorpse(ply)
    local tr = util.TraceHull({
        start  = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * 220,
        mins   = Vector(-28, -28, -10),
        maxs   = Vector(28, 28, 28),
        filter = ply,
    })
    local e = tr.Entity
    if IsValid(e) and e:GetClass() == "prop_ragdoll" and istable(e.P11_Identity) then
        return e
    end
    -- запас: ближайший труп с личностью в полутора метрах
    local best, bd = nil, 170 * 170
    for _, c in ipairs(ents.FindInSphere(ply:GetPos(), 170)) do
        if IsValid(c) and c:GetClass() == "prop_ragdoll" and istable(c.P11_Identity) then
            local d = c:GetPos():DistToSqr(ply:GetPos())
            if d < bd then best, bd = c, d end
        end
    end
    return best
end

-- ==================== R: съесть труп / меню мутаций ====================

function SWEP:Reload()
    if not IsFirstTimePredicted() then return end
    local ply = self.Owner
    if not IsValid(ply) then return end

    if CLIENT then
        -- труп рядом — меню НЕ открываем: R остаётся «съесть»
        if not IsValid(TraceCorpse(ply)) and P11 and P11.OpenThingMenu then
            P11.OpenThingMenu()
        end
        return
    end

    self.NextReload = self.NextReload or 0
    if CurTime() < self.NextReload then return end
    self.NextReload = CurTime() + 1

    local corpse = TraceCorpse(ply)
    if IsValid(corpse) then
        -- серверное съедение через ядро «ЛИЧИНА 2.0»
        if POLUS11 and POLUS11.ThingDevourCorpse then
            POLUS11.ThingDevourCorpse(ply, corpse)
        end
    end
end

-- ==================== КЛИЕНТ: подсказка над трупом + статус личины ====================

if CLIENT then
    function SWEP:DrawHUD()
        local ply = self.Owner
        if not IsValid(ply) then return end

        -- рядом съедобный труп?
        local tr = util.TraceHull({
            start  = ply:GetShootPos(),
            endpos = ply:GetShootPos() + ply:GetAimVector() * 220,
            mins   = Vector(-28, -28, -10),
            maxs   = Vector(28, 28, 28),
            filter = {ply, self},
        })
        local e = tr.Entity
        if IsValid(e) and e:GetNWString("P11_CorpseName", "") ~= "" then
            local w, h = ScrW(), ScrH()
            draw.SimpleText("[R] — СЪЕСТЬ ТРУП: " .. e:GetNWString("P11_CorpseName", ""), "P11.HUD.Mid", w / 2, h * 0.58, Color(255, 90, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("поглощение личности: облик, имя, должность, код документа", "P11.HUD.Text", w / 2, h * 0.58 + 30, Color(230, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- мой текущий статус: чья я личина (должность + документ видны мне)
        local me = LocalPlayer()
        local fake = me:GetNWString("P11_FakeNick", "")
        if fake ~= "" then
            local jobN = ""
            local fj = me:GetNWInt("P11_FakeJob", 0)
            if fj > 0 and P11FW and P11FW.TeamJobs then
                local jid = P11FW.TeamJobs[fj]
                local jt = jid and P11FW.Jobs and P11FW.Jobs[jid]
                if jt and jt.name then jobN = " · " .. jt.name end
            end
            local docc = me:GetNWString("P11_DocCode", "")
            local docLine = (docc ~= "") and (" · док. " .. docc) or ""
            draw.SimpleText("ЛИЧНОСТЬ: " .. fake .. jobN .. docLine .. "  |  R — меню (снять личину там)", "P11.HUD.Text", 18, ScrH() - 120, Color(255, 150, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end
end
