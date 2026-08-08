AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — ТОЧКА ЗАХВАТА «ФЛАГ» (v4.16.0 «ЗАХВАТ», заявка
--  «добавь систему захвата точек — и её могут захватывать
--  РККА и Американцы»).
--  Боец фракции встал в круг (360 юн) → шкала его фракции жмётся
--  к 100% (60 сек в одиночку). Дошла — точка переходит фракции:
--  объявление всей станции. В круге обе стороны — «БОЙ ЗА ТОЧКУ»,
--  шкала заморожена. Пустой круг — шкала тает.
--  Владеющая фракция получает оклад: 35₽ каждые 90 сек за
--  удержание. Имя ставится само: «А», «Б», «В»…
--  Ставится 📍 «Расставить» (роль flag), хранится на карте;
--  снести все — p11_flagclear.
-- ============================================================

local RADIUS   = 360  -- круг захвата (юн)
local CAP_TIME = 60   -- сек в одиночку от 0% до 100%
local READ     = 0.5  -- шаг Think
local PAY_GAP  = 90   -- сек между окладами удержания
local PAY_SUM  = 35   -- ₽ за удержание
local LETTERS  = { "А", "Б", "В", "Г", "Д", "Е", "Ж" }

local FACT = {
    rkka  = { name = "РККА" },
    eagle = { name = "ОТРЯД «КРАСНЫЙ ОРЁЛ»" },
}

-- фракция игрока для захвата — из должности (category/faction сида)
local function FactOf(ply)
    if not (P11FW and P11FW.GetJob) then return nil end
    local job = P11FW.GetJob(ply)
    local id = istable(job) and (job.faction or job.category) or nil
    if id == "rkka" or id == "eagle" then return id end
    return nil
end

local function Broadcast(msg)
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and POLUS11 and POLUS11.Notify then
            POLUS11.Notify(p, msg)
        end
    end
end

function ENT:Initialize()
    local models = {
        "models/props_c17/signpole001.mdl",
        "models/props_docks/dock_brokenpole01a.mdl",
        "models/props_c17/oildrum001.mdl",
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
        phys:EnableMotion(false) -- флагшток не катается
        phys:SetMass(400)
    end

    -- имя: по счёту «А», «Б», «В»… (self уже в списке → n >= 1)
    if (self:GetPointName() or "") == "" then
        local n = #ents.FindByClass("polus11_cappoint")
        self:SetPointName(LETTERS[n] or ("Т-" .. n))
    end
    if self:GetOwnerFact() == nil then self:SetOwnerFact("") end
    if self:GetCapFact() == nil then self:SetCapFact("") end
    self:SetCapFrac(0)

    self:NextThink(CurTime() + READ)
end

-- точка взята: объявляем всей станции
function ENT:Captured(f)
    local fn = (FACT[f] and FACT[f].name) or f
    local nm = self:GetPointName() or "?"
    Broadcast("🚩 " .. fn .. " ВЗЯЛА ТОЧКУ «" .. nm .. "»! Удержание: +" ..
        PAY_SUM .. "₽ каждые " .. PAY_GAP .. " сек — держите круг.")
    self:EmitSound("ambient/alarms/warningbell1.wav", 72, 100)
    if POLUS11 and POLUS11.Log then
        POLUS11.Log("ЗАХВАТ: " .. fn .. " взяла точку «" .. nm .. "» @ " .. tostring(self:GetPos()))
    end
end

function ENT:Think()
    local now = CurTime()
    local pos = self:GetPos()
    local r2 = RADIUS * RADIUS

    local rkka, eagle = 0, 0
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() and ply:GetPos():DistToSqr(pos) <= r2 then
            local f = FactOf(ply)
            if f == "rkka" then rkka = rkka + 1
            elseif f == "eagle" then eagle = eagle + 1 end
        end
    end

    local owner = self:GetOwnerFact() or ""
    local cap   = self:GetCapFact() or ""
    local frac  = tonumber(self:GetCapFrac()) or 0
    local step  = READ / CAP_TIME

    local present = nil
    if rkka > 0 then present = "rkka" end
    if eagle > 0 then present = "eagle" end

    if rkka > 0 and eagle > 0 then
        -- БОЙ ЗА ТОЧКУ: шкала заморожена, ничего не двигаем
    elseif present then
        if present == owner then
            -- свои: начатый чужой захват откатываем
            if frac > 0 then
                frac = math.max(0, frac - step * 2)
                self:SetCapFrac(frac)
            end
            if cap ~= "" then self:SetCapFact("") end
        else
            -- жмём точку своей фракцией
            if cap ~= present then cap = present frac = 0 end
            frac = frac + step
            if frac >= 1 then
                self:SetOwnerFact(present)
                self:SetCapFact("")
                self:SetCapFrac(0)
                self:Captured(present)
            else
                self:SetCapFact(cap)
                self:SetCapFrac(frac)
            end
        end
    else
        -- круг пустой: шкала тает
        if frac > 0 then
            frac = math.max(0, frac - step * 0.5)
            self:SetCapFrac(frac)
            if frac <= 0 then self:SetCapFact("") end
        end
    end

    -- оклад за удержание: бойцам владеющей фракции (в любом месте карты)
    owner = self:GetOwnerFact() or ""
    if owner ~= "" then
        self.P11_NextPay = self.P11_NextPay or (now + PAY_GAP)
        if now >= self.P11_NextPay then
            self.P11_NextPay = now + PAY_GAP
            local nm = self:GetPointName() or "?"
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and ply:Alive() and FactOf(ply) == owner then
                    if POLUS11 and POLUS11.AddMoney then
                        POLUS11.AddMoney(ply, PAY_SUM, "удержание точки «" .. nm .. "»")
                    end
                end
            end
        end
    else
        self.P11_NextPay = nil
    end

    self:NextThink(now + READ)
    return true
end

-- ============ ЗАГРУЗКА С КАРТЫ / СНЕСТИ ВСЕ ============

hook.Add("InitPostEntity", "P11.CapPointLoad", function()
    timer.Simple(2, function()
        if POLUS11 and POLUS11.PlaceLoad then POLUS11.PlaceLoad("flag") end
    end)
end)

hook.Add("PostCleanupMap", "P11.CapPointLoad2", function()
    timer.Simple(1, function()
        if POLUS11 and POLUS11.PlaceLoad then POLUS11.PlaceLoad("flag") end
    end)
end)

concommand.Add("p11_flagclear", function(ply)
    if IsValid(ply) and not (P11FW and P11FW.Config and P11FW.Config.Admin(ply)) then
        return
    end
    local n = 0
    for _, e in ipairs(ents.FindByClass("polus11_cappoint")) do
        if IsValid(e) then e:Remove() n = n + 1 end
    end
    if POLUS11 and POLUS11.PlaceSave then POLUS11.PlaceSave("flag") end
    local msg = "[ЗАХВАТ] Точек снесено: " .. n .. ". Сейв карты очищен."
    if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg)
        if POLUS11 and POLUS11.Notify then POLUS11.Notify(ply, "🚩 Точек захвата снесено: " .. n) end
    else print(msg) end
end)

print("[POLUS-11] точка захвата «ФЛАГ» v4.16.0: РККА ↔ Орёл · круг 360 · шкала 60 сек · оклад " ..
    PAY_SUM .. "₽/" .. PAY_GAP .. " сек · 📍 роль flag · снести p11_flagclear")
