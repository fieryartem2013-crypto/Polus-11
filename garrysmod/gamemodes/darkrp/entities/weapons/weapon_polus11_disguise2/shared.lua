-- ============================================================
--  ПОЛЮС-11 — КЕЙС ЛЕГЕНДЫ «ОБСЛУГА» (v4.17.0 «КОНТРАБАНДА»,
--  заявка: «криминалу контрабандистам — кейс с маскировкой
--  только под персонал, как отдельный свеп делаешь»).
--  Отличие от «ЛЕГАТА» (Орёл → РККА): этот кейс маскирует
--  ТОЛЬКО под обслугу станции (уборщик/повар/грузчик/техник/
--  медик/инженер/водитель, стоковые модели HL2) и работает
--  МГНОВЕННО, без меню: щелчок — авто-легенда (позывной/документ
--  липовые сами), повторный — маска сорвана.
--  v4.33.1 «МЕДАЛЬ»: должности легенды собираются СЕРВЕРОМ
--  динамически из всех проф категории "personnel" (включая
--  Водителя и кастомные). Сервер: p11_sv_disguise.lua, op 6.
-- ============================================================

SWEP.PrintName    = "Кейс легенды «ОБСЛУГА»"
SWEP.Author       = "POLUS-11"
SWEP.Category     = "ПОЛЮС-11"
SWEP.Instructions = "ЛКМ / R / ПКМ — мгновенно: надеть липовую легенду ПЕРСОНАЛА (облик обслуги + позывной + должность + документ) или сорвать маску • Только персонал, только криминал станции"

SWEP.Spawnable      = true
SWEP.AdminSpawnable = true

SWEP.HoldType   = "slam"
SWEP.ViewModel  = ""
SWEP.WorldModel = "models/props_c17/Briefcase001a.mdl"
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

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:Deploy()
    return true
end

local function SendToggle()
    if CLIENT then
        net.Start("P11_Disguise")
            net.WriteUInt(6, 3) -- v4.17.0: авто-легенда персонала (сервер решит: надеть/сорвать)
        net.SendToServer()
    end
end

-- ЛКМ: надеть/сорвать мгновенную легенду обслуги
function SWEP:PrimaryAttack()
    if not IsFirstTimePredicted() then return end
    self:SetNextPrimaryFire(CurTime() + 1.2)
    SendToggle()
end

-- ПКМ: то же самое (кейс «по требованию», меню у него нет)
function SWEP:SecondaryAttack()
    if not IsFirstTimePredicted() then return end
    self:SetNextSecondaryFire(CurTime() + 1.2)
    SendToggle()
end

-- R: тоже надеть/сорвать (клиентский щелчок, дебаунс своим таймером)
function SWEP:Reload()
    if not CLIENT then return end
    self.P11_NextReload = self.P11_NextReload or 0
    if CurTime() < self.P11_NextReload then return end
    self.P11_NextReload = CurTime() + 1.2
    SendToggle()
end

-- Статус-строка на экране (без эмодзи — родной шрифт их не тянет)
local made = 0
function SWEP:DrawHUD()
    if made == 0 then
        made = 1
        surface.CreateFont("P11.CaseHint", { font = "Roboto", size = 16, weight = 600, extended = true })
    end
    local own = LocalPlayer()
    if not IsValid(own) then return end
    local fake = own:GetNWString("P11_FakeNick", "")
    local on = fake ~= ""
    draw.RoundedBox(6, ScrW() / 2 - 190, ScrH() - 92, 380, 26, Color(12, 16, 22, 185))
    draw.SimpleText(
        on and ("МАСКА НАДЕТА: " .. fake .. " • ЛКМ — сорвать")
            or "КЕЙС «ОБСЛУГА»: ЛКМ — легенда персонала (мгновенно)",
        "P11.CaseHint", ScrW() / 2, ScrH() - 79,
        on and Color(150, 220, 150) or Color(215, 205, 170),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end
