-- ============================================================
--  ПОЛЮС-11 — Класс Нечто: «ИМИТАТОР»
--  ЛКМ — когти (атака выдаёт тварь: облик монстра на 20 сек)
--  ПКМ — тихий укол заражения (цель не узнаёт сразу)
--  R по трупу — СЪЕСТЬ ТРУП: полное поглощение личности
--    (модель, скин, бодигруппы, цвет, ник, DarkRP-имя)
--  R без трупа — вернуть свой облик / раскрыть форму Нечто
-- ============================================================

SWEP.PrintName    = "НЕЧТО: Имитатор"
SWEP.Author       = "POLUS-11"
SWEP.Category     = "ПОЛЮС-11"
SWEP.Instructions = "ЛКМ — поглощение | ПКМ — тихий укол | R по трупу — съесть и стать им | R — вернуть свой облик"

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

    -- модель монстра по ТЕКУЩЕЙ форме (v2.6: у каждой формы своё тело)
    local mdl = POLUS11.MonsterModels.brute
    local forms = POLUS11.ThingForms or {}
    local form = forms[ply.P11_ThingForm or ""]
    if form and isstring(form.model) then mdl = form.model end
    -- v4.2: мутация Т3 «АРАХНА» — паучья туша
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

        -- поглощение: убитый когтями может сразу заразиться (если настраивает админ)
        -- здесь: просто тяжёлый удар
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

    local tr = util.TraceLine({
        start = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * 110,
        filter = ply,
    })

    local target = tr.Entity
    if not IsValid(target) or not target:IsPlayer() or not target:Alive() then
        POLUS11.Notify(ply, "Рядом нет цели для укола.")
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

-- ==================== ПОГЛОЩЕНИЕ ЛИЧНОСТИ ТРУПА ====================

local function SaveTrueIdentity(ply)
    if ply.P11_TrueIdentity then return end

    local bg = {}
    for i = 0, ply:GetNumBodyGroups() - 1 do
        bg[i] = ply:GetBodygroup(i)
    end

    ply.P11_TrueIdentity = {
        model  = ply:GetModel(),
        skin   = ply:GetSkin(),
        color  = ply:GetColor(),
        pcolor = ply:GetPlayerColor(),
        wcolor = ply:GetWeaponColor(),
        bodygroups = bg,
    }
    if DarkRP and ply.getDarkRPVar then
        ply.P11_TrueIdentity.rpname = ply:getDarkRPVar("rpname") or ply:Nick()
    end
end

local function RestoreTrueIdentity(ply)
    local a = ply.P11_FakeRestore or ply.P11_TrueIdentity
    if not a then return end

    if a.model and file.Exists(a.model, "GAME") then ply:SetModel(a.model) end
    ply:SetSkin(a.skin or 0)
    ply:SetColor(a.color or Color(255, 255, 255, 255))
    ply:SetPlayerColor(a.pcolor or Vector(1, 1, 1))
    ply:SetWeaponColor(a.wcolor or Vector(0, 0.1, 0.6))
    local maxBg = ply:GetNumBodyGroups()
    for k, v in pairs(a.bodygroups or {}) do
        if isnumber(k) and k < maxBg then ply:SetBodygroup(k, v) end
    end

    if DarkRP and ply.setDarkRPVar and a.rpname then
        pcall(function() ply:setDarkRPVar("rpname", a.rpname) end)
    end

    ply.P11_FakeNick = nil
    ply.P11_FakeRestore = nil
    ply.P11_Revealed = false
    ply.P11_RevealedAt = 0
    ply:SetNWString("P11_FakeNick", "")
end
POLUS11_RestoreTrueIdentity = RestoreTrueIdentity

function SWEP:EatCorpse(ply, corpse)
    local id = corpse.P11_Identity
    if not id then return end

    -- КРИТИЧНО: снять форму монстра, чтобы авто-таймер не сорвал украденную личность
    ply.P11_Revealed = false
    ply.P11_RevealedAt = 0
    ply.P11_SavedModel = nil

    -- своя личность запоминается ОДИН раз
    SaveTrueIdentity(ply)

    -- съедаем личность трупа
    if id.model and file.Exists(id.model, "GAME") then ply:SetModel(id.model) end
    ply:SetSkin(id.skin or 0)
    ply:SetColor(id.color or Color(255, 255, 255, 255))
    ply:SetPlayerColor(id.pcolor or Vector(1, 1, 1))
    ply:SetWeaponColor(id.wcolor or Vector(0, 0.1, 0.6))
    local maxBg = ply:GetNumBodyGroups()
    for k, v in pairs(id.bodygroups or {}) do
        if isnumber(k) and k < maxBg then ply:SetBodygroup(k, v) end
    end

    ply.P11_FakeNick = id.nick
    ply.P11_IdentityTakenAt = CurTime()
    ply:SetNWString("P11_FakeNick", id.nick)

    -- DarkRP: полное имя в чате/табе/над головой
    if DarkRP and ply.setDarkRPVar then
        pcall(function() ply:setDarkRPVar("rpname", id.rpname or id.nick) end)
    end

    -- эффекты поглощения
    ply:EmitSound("npc/barnacle/barnacle_digesting1.wav", 75, 90)
    ply:EmitSound("npc/zombie/zo_attack" .. math.random(1, 2) .. ".wav", 70, 85)
    local ed = EffectData()
    ed:SetOrigin(corpse:GetPos() + Vector(0, 0, 20))
    util.Effect("BloodImpact", ed, true, true)
    util.Effect("bloodspray", ed, true, true)

    -- останки исчезают
    timer.Simple(0.2, function()
        if IsValid(corpse) then corpse:Remove() end
    end)

    -- лечение за поглощение
    local maxhp = ply:GetMaxHealth()
    if maxhp <= 0 then maxhp = 100 end
    ply:SetHealth(math.min(maxhp, ply:Health() + 25))

    POLUS11.Notify(ply, "Личность поглощена. Теперь вы — «" .. id.nick .. "». R — вернуть себя.")
    POLUS11.Log("ПОГЛОЩЕНИЕ ЛИЧНОСТИ: " .. ply:Nick() .. " съел труп «" .. id.nick .. "»")
end

-- поиск съедобного трупа под прицелом
local function TraceCorpse(ply)
    local tr = util.TraceHull({
        start  = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * 140,
        mins   = Vector(-20, -20, -20),
        maxs   = Vector(20, 20, 20),
        filter = ply,
    })
    local e = tr.Entity
    if IsValid(e) and e:GetClass() == "prop_ragdoll" and istable(e.P11_Identity) then
        return e
    end
    return nil
end

-- ==================== R ====================

function SWEP:Reload()
    if CLIENT or not IsFirstTimePredicted() then return end
    local ply = self.Owner

    self.NextReload = self.NextReload or 0
    if CurTime() < self.NextReload then return end
    self.NextReload = CurTime() + 1

    -- 1) труп под прицелом → СЪЕСТЬ ЛИЧНОСТЬ
    local corpse = TraceCorpse(ply)
    if IsValid(corpse) then
        self:EatCorpse(ply, corpse)
        return
    end

    -- 2) если мы в чужом облике → вернуть свой
    if ply.P11_FakeNick then
        if CurTime() - (ply.P11_IdentityTakenAt or 0) < 5 then
            POLUS11.Notify(ply, "Нечто ещё переваривает… подождите " .. math.ceil(5 - (CurTime() - ply.P11_IdentityTakenAt)) .. " сек")
            return
        end
        RestoreTrueIdentity(ply)
        ply:EmitSound("npc/zombie/zombie_voice_idle2.wav", 60, 90)
        POLUS11.Notify(ply, "Вы сбросили чужую личность.")
        return
    end

    -- 3) иначе — обычное раскрытие формы монстра
    if ply.P11_Revealed then
        if CurTime() - (ply.P11_RevealedAt or 0) < 5 then
            POLUS11.Notify(ply, "Нечто слишком разгорячён — подождите пару секунд.")
            return
        end
        POLUS11_HideThing(ply)
        POLUS11.Notify(ply, "Вы снова выглядите как человек.")
    else
        POLUS11_RevealThing(ply, self)
    end
end

-- ==================== КЛИЕНТ: подсказка над трупом ====================

if CLIENT then
    function SWEP:DrawHUD()
        local ply = self.Owner
        if not IsValid(ply) then return end

        -- рядом съедобный труп?
        local tr = util.TraceHull({
            start  = ply:GetShootPos(),
            endpos = ply:GetShootPos() + ply:GetAimVector() * 140,
            mins   = Vector(-20, -20, -20),
            maxs   = Vector(20, 20, 20),
            filter = {ply, self},
        })
        local e = tr.Entity
        if IsValid(e) and e:GetNWString("P11_CorpseName", "") ~= "" then
            local w, h = ScrW(), ScrH()
            draw.SimpleText("[R] — СЪЕСТЬ ТРУП: " .. e:GetNWString("P11_CorpseName", ""), "P11.HUD.Mid", w / 2, h * 0.58, Color(255, 90, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("поглощение личности: модель, имя, цвет", "P11.HUD.Text", w / 2, h * 0.58 + 30, Color(230, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- мой текущий статус
        local me = LocalPlayer()
        local fake = me:GetNWString("P11_FakeNick", "")
        if fake ~= "" then
            draw.SimpleText("ЛИЧНОСТЬ: " .. fake .. "  |  R — вернуть себя", "P11.HUD.Text", 18, ScrH() - 120, Color(255, 150, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end
end
