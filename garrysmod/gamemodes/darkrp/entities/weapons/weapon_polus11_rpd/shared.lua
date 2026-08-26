-- ============================================================
--  ПОЛЮС-11 — РПД (ручной пулемёт Дегтярёва) — v4.9.1 «ИГЛА»
--  Заявка владельца: «новая профа пулемётчик с РПД».
--  Скриптовый, САМОДОСТАТОЧНЫЙ (никаких паков не просит): модель —
--  встроенная штурмовая винтовка HL2 как «барабанный ручник»,
--  диск на 75 патронов, тяжёлый и громкий — как положено РПД.
--  Пулемёт отпугивает Нечто громкостью: длинные очереди — его стихия.
-- ============================================================

SWEP.PrintName    = "РПД (ручной пулемёт)"
SWEP.Author       = "POLUS-11"
SWEP.Category     = "ПОЛЮС-11"
SWEP.Instructions = "Огневая точка гарнизона. Диск 75 патронов. Подавляющий огонь: бей короткими очередями 4-6, сидя — точнее."

SWEP.Spawnable      = true
SWEP.AdminSpawnable = false

SWEP.HoldType   = "ar2"
SWEP.ViewModel  = "models/weapons/v_irifle.mdl"
SWEP.WorldModel = "models/weapons/w_irifle.mdl"
SWEP.UseHands   = false

SWEP.Weight   = 7
SWEP.AutoSwitchTo   = true
SWEP.AutoSwitchFrom = false

SWEP.Primary.ClipSize    = 75
SWEP.Primary.DefaultClip = 150
SWEP.Primary.Automatic   = true
SWEP.Primary.Ammo        = "ar2"
SWEP.Primary.Delay       = 60 / 620   -- ~620 выстр/мин, как у РПД
SWEP.Primary.Damage      = 26
SWEP.Primary.Tracer      = 1

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end

    local ply = self.Owner
    if not IsValid(ply) then return end

    self:TakePrimaryAmmo(1)
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    -- РПД тяжёлый: на ходу ползёт, стоя/сидя — прилично
    local moving = ply:GetVelocity():Length2D() > 130
    local crouch = ply:Crouching()
    local spread = Vector(0.045, 0.045, 0)
    if moving then spread = Vector(0.09, 0.09, 0)
    elseif crouch then spread = Vector(0.02, 0.02, 0) end

    ply:FireBullets({
        Src      = ply:GetShootPos(),
        Dir      = ply:GetAimVector(),
        Spread   = spread,
        Num      = 1,
        Damage   = self.Primary.Damage,
        Tracer   = self.Primary.Tracer,
        TracerName = "Tracer",
        Force    = 4,
    })

    self:EmitSound("weapons/ar2/fire1.wav", 95, 96) -- громко и грозно — Нечто слышит
    ply:ViewPunch(Angle(-1.4, math.Rand(-0.4, 0.4), 0))

    if self.Owner:IsPlayer() then
        self.Owner:SetAnimation(PLAYER_ATTACK1)
    end
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
end

function SWEP:Reload()
    self:DefaultReload(ACT_VM_RELOAD)
    self.Owner:EmitSound("weapons/smg1/smg1_reload.wav", 75, 90)
end

function SWEP:SecondaryAttack() end

function SWEP:GetViewModelPosition(pos, ang)
    -- чуть ниже и ближе: барабанный ручник держат у корпуса
    return pos + ang:Forward() * -2 + ang:Up() * -3, ang
end
