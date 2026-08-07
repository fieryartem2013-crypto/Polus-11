-- ============================================================
--  ПОЛЮС-11 — КЕЙС МАСКИРОВКИ «ЛЕГАТ» (v4.8.5 «КРАСНЫЙ ОРЁЛ»)
--  Дипломат-чемоданчик диверсионно-разведывательного отряда.
--  Внутри: театральный грим, липовое удостоверение гарнизона,
--  сложенная гимнастёрка. Наложил маскировку — для станции ты
--  боец РККА: чужая модель, липовой позывной, липовая
--  должность и код документа (та же механика, что у личин
--  Нечто — TAB, ники над головами и голос видят легенду).
--
--  ЛКМ — раскрыть кейс (меню легенды: позывной + облик +
--        должность, наложение 3 сек, срывается движением).
--  ПКМ — мгновенно: надеть/снять по ПОСЛЕДНЕЙ легенде.
--  R   — тоже меню кейса.
--  Активному Нечто кейс не нужен (оно само лицо меняет).
-- ============================================================

SWEP.PrintName    = "Кейс маскировки «ЛЕГАТ»"
SWEP.Author       = "POLUS-11"
SWEP.Category     = "ПОЛЮС-11"
SWEP.Instructions = "ЛКМ/R — раскрыть кейс (легенда: имя + облик РККА + должность) • ПКМ — быстро надеть/снять по последней легенде • Маскировка: чужая внешность, позывной, должность, код документа"

SWEP.Spawnable      = true
SWEP.AdminSpawnable = true

SWEP.HoldType   = "slam"
SWEP.ViewModel  = ""
SWEP.WorldModel = "models/props_c17/Briefcase001a.mdl" -- HL2-чемоданчик
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
    if CLIENT and IsValid(self.Owner) then
        -- клиентская плашка-статус сама дорисуется в DrawHUD
    end
    return true
end

-- ЛКМ: раскрыть кейс (меню)
function SWEP:PrimaryAttack()
    if not IsFirstTimePredicted() then return end
    self:SetNextPrimaryFire(CurTime() + 1.0)
    if CLIENT then
        if P11 and P11.OpenDisguiseMenu then
            P11.OpenDisguiseMenu()
        end
    end
end

-- ПКМ: быстрое надевание/снятие по последней легенде
function SWEP:SecondaryAttack()
    if not IsFirstTimePredicted() then return end
    self:SetNextSecondaryFire(CurTime() + 1.0)
    if CLIENT then
        net.Start("P11_Disguise")
            net.WriteUInt(4, 3) -- quick: сервер решит надеть или снять
        net.SendToServer()
    end
end

-- R: тоже раскрыть кейс
function SWEP:Reload()
    if not IsFirstTimePredicted() then return end
    local ply = self.Owner
    if not IsValid(ply) then return end
    ply.P11_CaseNextR = ply.P11_CaseNextR or 0
    if CurTime() < ply.P11_CaseNextR then return end
    ply.P11_CaseNextR = CurTime() + 1.0
    if CLIENT then
        if P11 and P11.OpenDisguiseMenu then
            P11.OpenDisguiseMenu()
        end
    end
end

-- ============ HUD-ПЛАШКА СТАТУСА ============

function SWEP:DrawHUD()
    local ply = self.Owner
    if not IsValid(ply) or not ply:Alive() then return end

    local w, h = ScrW(), ScrH()
    local fake = ply:GetNWString("P11_FakeNick", "")
    local bx, by = w * 0.5, h - 116
    draw.RoundedBox(6, bx - 190, by - 26, 380, 52, Color(9, 12, 18, 185))

    if fake ~= "" then
        draw.SimpleText("ЛЕГЕНДА АКТИВНА", "DermaDefaultBold", bx, by - 12,
            Color(255, 100, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("ты — «" .. fake .. "» (ПКМ — сорвать маску)",
            "DermaDefault", bx, by + 8, Color(235, 240, 246),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
        draw.SimpleText("КЕЙС «ЛЕГАТ»", "DermaDefaultBold", bx, by - 12,
            Color(120, 180, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("ЛКМ/R — меню легенды · ПКМ — надеть/снять",
            "DermaDefault", bx, by + 8, Color(200, 208, 220),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end
