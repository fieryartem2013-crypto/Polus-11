-- ============================================================
--  ПОЛЮС-11 — Кустарный огнемёт
--  Единственное надёжное оружие против Нечто.
--  Заправляется прямо от дизель-генератора (делят топливо!).
-- ============================================================

SWEP.PrintName    = "Кустарный огнемёт"
SWEP.Author       = "POLUS-11"
SWEP.Category     = "ПОЛЮС-11"
SWEP.Instructions = "ЛКМ — струя огня (топливо ограничено!) | Заправка: E по генератору с огнемётом в руках"

SWEP.Spawnable      = true
SWEP.AdminSpawnable = true

SWEP.HoldType   = "ar2"
SWEP.ViewModel  = "models/weapons/c_irifle.mdl"
SWEP.WorldModel = "models/weapons/w_irifle.mdl"
SWEP.UseHands   = true
SWEP.ViewModelFOV = 55

SWEP.DrawAmmo = true

SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic   = true
SWEP.Primary.Ammo        = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

SWEP.Weight = 6

function SWEP:SetupDataTables()
    self:NetworkVar("Float", 0, "Fuel")
    self:NetworkVar("Bool", 0, "Firing")
end

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
    if SERVER then
        self:SetFuel(POLUS11.Config.FT_MaxFuel * 0.5) -- спавнится полупустым
    end
end

function SWEP:Deploy()
    self:SetFiring(false)
    return true
end

function SWEP:Holster()
    self:SetFiring(false)
    if CLIENT and self.P11_Emitter then
        self.P11_Emitter:Finish()
        self.P11_Emitter = nil
    end
    return true
end

function SWEP:OnRemove()
    if CLIENT and self.P11_Emitter then
        self.P11_Emitter:Finish()
        self.P11_Emitter = nil
    end
    return true
end

function SWEP:Think()
    local ply = self.Owner
    if not IsValid(ply) then return end

    local wantFire = ply:KeyDown(IN_ATTACK) and self:GetFuel() > 0
    if wantFire ~= self:GetFiring() then
        self:SetFiring(wantFire)
        if wantFire and SERVER then
            self:EmitSound("ambient/fire/mtov_flame2.wav", 75, 90)
        end
    end

    if SERVER then
        self.NextBurn = self.NextBurn or 0
        self.NextFuelDrain = self.NextFuelDrain or 0
        if self:GetFiring() then
            -- расход по времени: 10 ед/сек (полный бак = 20 сек струи)
            if CurTime() >= self.NextFuelDrain then
                self.NextFuelDrain = CurTime() + 0.1
                self:SetFuel(math.max(0, self:GetFuel() - 1))
            end

            if CurTime() >= self.NextBurn then
                self.NextBurn = CurTime() + 0.18
                self:BurnCone()
            end

            if self:GetFuel() <= 0 then
                self:SetFiring(false)
            end
        end
    end
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.08)
end

function SWEP:SecondaryAttack() end

-- урон конусом + поджог
function SWEP:BurnCone()
    local ply = self.Owner
    if not IsValid(ply) then return end

    local start = ply:GetShootPos()
    local dir = ply:GetAimVector()
    local range = POLUS11.Config.FT_Range

    for _, ent in ipairs(ents.FindInCone(start, dir, range, 0.6)) do
        if IsValid(ent) and ent ~= ply and (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()) then
            -- поджог (метод Ignite есть у игроков, NPC и некстботов)
            ent:Ignite(POLUS11.Config.FT_IgniteTime, 32)

            local dmg = DamageInfo()
            dmg:SetDamage(POLUS11.Config.FT_DPS * 0.18)
            dmg:SetAttacker(ply)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_BURN)
            dmg:SetDamagePosition(ent:GetPos() + Vector(0, 0, 30))
            dmg:SetDamageForce(dir * 120)
            ent:TakeDamageInfo(dmg)
        end
    end

    -- визуал струи рисует клиент (EmitFlame), здесь только урон и поджог
end

-- заправка от генератора (вызывается из Use генератора)
function SWEP:RefillFrom(gen)
    local need = POLUS11.Config.FT_MaxFuel - self:GetFuel()
    if need <= 0 then return 0 end

    local costPerUnit = POLUS11.Config.FT_RefillCost
    local canAfford = math.floor(gen:GetFuel() / costPerUnit)
    local take = math.min(need, canAfford)
    if take <= 0 then return 0 end

    gen:SetFuel(gen:GetFuel() - take * costPerUnit)
    self:SetFuel(self:GetFuel() + take)
    return take
end

-- ==================== КЛИЕНТ: струя огня ====================

if CLIENT then
    function SWEP:DrawHUD()
        local fuel = math.floor(self:GetFuel())
        local max = POLUS11.Config.FT_MaxFuel
        local frac = math.Clamp(fuel / max, 0, 1)

        local w, h = ScrW(), ScrH()
        draw.RoundedBox(6, w - 264, h - 66, 250, 52, Color(0, 0, 0, 150))
        draw.RoundedBox(4, w - 254, h - 56, 230, 20, Color(40, 40, 46, 220))
        draw.RoundedBox(4, w - 254, h - 56, 230 * frac, 20, frac > 0.25 and Color(255, 160, 60) or Color(220, 60, 50))
        draw.SimpleText("ТОПЛИВО: " .. fuel, "DermaDefaultBold", w - 139, h - 54, Color(245, 240, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

        if fuel <= 0 then
            draw.SimpleText("НЕТ ТОПЛИВА — ЗАПРАВЬТЕСЬ У ГЕНЕРАТОРА", "DermaDefaultBold", w / 2, h * 0.62, Color(255, 80, 60), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- частицы пламени
    function SWEP:ViewModelDrawn(vm)
        if not self:GetFiring() then return end
        self:EmitFlame()
    end

    function SWEP:DrawWorldModel()
        self:DrawModel()
        if self:GetFiring() then
            self:EmitFlame(true)
        end
    end

    function SWEP:EmitFlame(world)
        local ply = self.Owner
        if not IsValid(ply) then return end

        self.P11_Emitter = self.P11_Emitter or ParticleEmitter(Vector(0, 0, 0))

        local start, dir
        local att = self:LookupAttachment("muzzle")
        local attData = self:GetAttachment(att)
        if attData then
            start = attData.Pos
            dir = ply:GetAimVector()
        else
            start = ply:GetShootPos()
            dir = ply:GetAimVector()
        end

        for i = 1, 3 do
            local p = self.P11_Emitter:Add("effects/fire_cloud1", start + dir * 10)
            if p then
                p:SetVelocity(dir * math.random(500, 750) * (POLUS11.Config.FT_Range / 320) + VectorRand() * 60)
                p:SetDieTime(math.Rand(0.18, 0.4))
                p:SetStartAlpha(230)
                p:SetEndAlpha(0)
                p:SetStartSize(math.random(8, 14))
                p:SetEndSize(math.random(24, 40))
                p:SetRoll(math.Rand(0, 360))
                p:SetColor(255, 200, 120)
            end

            local p2 = self.P11_Emitter:Add("sprites/light_glow02_add", start + dir * 20)
            if p2 then
                p2:SetVelocity(dir * 600)
                p2:SetDieTime(0.1)
                p2:SetStartAlpha(255)
                p2:SetEndAlpha(0)
                p2:SetStartSize(26)
                p2:SetEndSize(60)
                p2:SetColor(255, 160, 60)
            end
        end

        -- динамический свет
        local dl = DynamicLight(self:EntIndex())
        if dl then
            dl.pos = start + dir * 40
            dl.r = 255 dl.g = 140 dl.b = 60
            dl.brightness = 4
            dl.size = 320
            dl.decay = 1000
            dl.dietime = CurTime() + 0.15
        end
    end
end
