AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — ПОХОДНАЯ БУРЖУЙКА «УГЛИ» (v4.15.0, заявка
--  «добавь больше интерактива, больше механик систем»).
--  E — кинуть топливо ИЗ ИНВЕНТАРЯ (🎒):
--   • «Канистра солярки» (fuel)   → +240 сек огня (запас ≤ 900)
--   • «Спирт технический» (spirit)→ +90 сек
--  Горящая печь греет бойцов в радиусе 520: +3 тепла каждые
--  2 сек (через POLUS11.AddWarmth — система мороза «ПОЛЮСА»).
--  Ставится 📍 «Расставить» (роль hearth) и хранится на карте;
--  рассыпка консолью: p11_lootspawn hearth 4.
-- ============================================================

local BURN_FUEL   = 240 -- сек за канистру
local BURN_SPIRIT = 90  -- сек за бутыль спирта
local STOCK_MAX   = 900 -- потолок запаса огня (сек вперёд)
local RADIUS      = 520

function ENT:Initialize()
    local models = {
        "models/props_c17/oildrum001.mdl",
        "models/props_junk/wood_crate001a.mdl",
    }
    for _, m in ipairs(models) do
        if file.Exists(m, "GAME") then self:SetModel(m) break end
    end

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false) -- очаг не катается по станции
        phys:SetMass(500)
    end

    self:SetBurnUntil(0)
    self.P11_NextCrackle = 0
    self:NextThink(CurTime() + 2)
end

local function BurnLeft(e)
    return math.max(0, (e:GetBurnUntil() or 0) - CurTime())
end

function ENT:Use(activator)
    if not (IsValid(activator) and activator:IsPlayer() and activator:Alive()) then return end
    local ply = activator
    if ply:GetPos():DistToSqr(self:GetPos()) > 160 * 160 then return end
    if not (POLUS11 and POLUS11.InvOf) then return end

    ply.P11_HearthNext = ply.P11_HearthNext or 0
    if CurTime() < ply.P11_HearthNext then return end
    ply.P11_HearthNext = CurTime() + 0.7

    local now = CurTime()
    local base = math.max(self:GetBurnUntil() or 0, now) -- продлеваем огонь, не обнуляем
    local data = POLUS11.InvOf(ply)
    local fuel   = tonumber(data.items["fuel"])   or 0
    local spirit = tonumber(data.items["spirit"]) or 0

    local function Cap(t) return math.min(t, now + STOCK_MAX) end

    if fuel > 0 then
        if Cap(base + BURN_FUEL) <= base then
            POLUS11.Notify(ply, "🔥 Запас огня полный (~" .. math.ceil(base - now) .. " сек вперёд) — подкинешь позже.")
            ply:EmitSound("buttons/button10.wav", 55, 95)
            return
        end
        data.items["fuel"] = fuel - 1
        if data.items["fuel"] <= 0 then data.items["fuel"] = nil end
        self:SetBurnUntil(Cap(base + BURN_FUEL))
        POLUS11.Notify(ply, "🔥 Канистра в огонь: очаг горит ещё ~" .. math.ceil(self:GetBurnUntil() - now) ..
            " сек. Греет радиус " .. math.floor(RADIUS / 52) .. " метров.")
        ply:EmitSound("ambient/fire/gascan_ignite1.wav", 65, 100)
    elseif spirit > 0 then
        data.items["spirit"] = spirit - 1
        if data.items["spirit"] <= 0 then data.items["spirit"] = nil end
        self:SetBurnUntil(Cap(base + BURN_SPIRIT))
        POLUS11.Notify(ply, "🔥 Спирт пошёл в жар: горит ещё ~" .. math.ceil(self:GetBurnUntil() - now) .. " сек.")
        ply:EmitSound("ambient/fire/gascan_ignite1.wav", 60, 110)
    else
        POLUS11.Notify(ply, "Очаг просит жрачки: «Канистра солярки» (+4 мин) или «Спирт» (+1.5 мин) — ларёк/лутницы, 🎒 инвентарь.")
        ply:EmitSound("buttons/button10.wav", 55, 95)
        return
    end
    if POLUS11.InvSaveNow then POLUS11.InvSaveNow() end
    POLUS11.InvSync(ply)
    self:NextThink(now + 0.5)
end

-- жар: каждые 2 сек греем всех рядом; треск — атмосфера
function ENT:Think()
    local now = CurTime()
    if now < (self:GetBurnUntil() or 0) then
        local r2 = RADIUS * RADIUS
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive()
                and ply:GetPos():DistToSqr(self:GetPos()) <= r2 then
                if POLUS11.AddWarmth then POLUS11.AddWarmth(ply, 3) end
                ply.P11_HearthWarmUntil = now + 5 -- метка «греешься у огня» для худов
            end
        end
        if now >= (self.P11_NextCrackle or 0) then
            self.P11_NextCrackle = now + math.Rand(2.5, 5)
            self:EmitSound("ambient/fire/fire_small_loop1.wav", 55, math.random(90, 110))
        end
        self:NextThink(now + 2)
    else
        self:NextThink(now + 5)
    end
    return true
end
