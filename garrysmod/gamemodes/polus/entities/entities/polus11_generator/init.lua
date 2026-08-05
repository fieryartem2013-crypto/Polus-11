AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    -- v3.7: новая модель + цепочка фолбэков (если пака lt_c нет на сервере)
    local models = {
        "models/lt_c/sci_fi/generator_portable.mdl",
        "models/props_vehicles/generatortrailer01.mdl",
        "models/props_combine/combine_generator01.mdl",
        "models/props_c17/consolebox03a.mdl",
    }
    for _, m in ipairs(models) do
        if file.Exists(m, "GAME") then
            self:SetModel(m)
            break
        end
    end
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(400)
    end

    self:SetFuel(POLUS11.Config.FuelPerBarrel) -- стартует с одной заправкой
    self:SetDamaged(false)
    self:SetWear(0)
    self:SetFault("")
    self:SetReserve(false)
    self:SetHealth(600)
    self:SetMaxHealth(600)

    self.SoundLoop = CreateSound(self, "ambient/machines/diesel_engine_idle1.wav")
    self.SoundLoop:PlayEx(0.5, 95)

    self.NextTick = 0
    self.NextFaultRoll = CurTime() + 20
end

function ENT:OnRemove()
    if self.SoundLoop then self.SoundLoop:Stop() end
end

-- свет сейчас горит? (для режима РЕЗЕРВ: не жжём топливо впустую)
local function NetworkPowered(selfGen)
    for _, e in ipairs(ents.FindByClass("polus11_generator")) do
        if e ~= selfGen and IsValid(e) and not e:GetDamaged()
            and e:GetFuel() > 0 and not e:GetReserve() then
            return true
        end
    end
    return false
end

-- есть ли ещё работающий генератор (любой: резервный в блэкаут тоже тянет свет)
function POLUS11.AnyGeneratorOnline(except)
    for _, e in ipairs(ents.FindByClass("polus11_generator")) do
        if e ~= except and IsValid(e) and not e:GetDamaged() and e:GetFuel() > 0 then
            return true
        end
    end
    return false
end

-- расход топлива, износ и поломки
function ENT:Think()
    if self.NextTick > CurTime() then self:NextThink(CurTime() + 0.5) return true end
    self.NextTick = CurTime() + 1

    if self:GetDamaged() then
        self:NextThink(CurTime() + 0.5)
        return true
    end

    local fuel = self:GetFuel()
    local fault = self:GetFault()
    local storm = GetGlobalBool("P11_Storm", false)

    -- РЕЗЕРВ: молчит, пока сеть запитана основными
    local idling = self:GetReserve() and NetworkPowered(self)
    if self.SoundLoop then
        local want = idling and 0.12 or 0.5
        if math.abs((self.LastVol or 0.5) - want) > 0.01 then
            self.SoundLoop:ChangeVolume(want, 1.5)
            self.LastVol = want
        end
    end

    if fuel > 0 then
        if not idling then
            local drain = (fault ~= "") and 1.6 or 1 -- поломка ест соляру
            fuel = math.max(0, fuel - drain)
            self:SetFuel(fuel)

            -- ИЗНОС: ≈40 минут работы до 100%; буря и поломка гоняют вдвое
            local wearRate = 100 / 2400
            if storm then wearRate = wearRate * 2 end
            if fault ~= "" then wearRate = wearRate * 1.5 end
            local wear = math.min(100, self:GetWear() + wearRate)
            self:SetWear(wear)

            -- новая ПОЛОМКА по износу
            if CurTime() >= (self.NextFaultRoll or 0) then
                self.NextFaultRoll = CurTime() + 12
                if fault == "" and wear > 50 then
                    local chance = (wear - 50) / 50 * 0.30
                    if storm then chance = chance * 1.5 end
                    if math.random() < chance then
                        local keys = { "overheat", "leak", "starter", "voltage" }
                        local f = keys[math.random(#keys)]
                        self:SetFault(f)
                        local ed = EffectData()
                        ed:SetOrigin(self:GetPos() + self:GetUp() * 40)
                        util.Effect("sparks", ed, true, true)
                        self:EmitSound("ambient/energy/spark" .. math.random(1, 6) .. ".wav", 70, 110)
                        POLUS11.Log("ГЕНЕРАТОР: поломка «" .. (POLUS11_GEN_FAULTS[f] and POLUS11_GEN_FAULTS[f].name or f) .. "» — нужен техосмотр!")
                    end
                end
            end

            -- ПЕРЕГРЕВ, доведённый до 100% — АВАРИЯ
            if fault == "overheat" and wear >= 100 then
                self:SetDamaged(true)
                if self.SoundLoop then self.SoundLoop:Stop() end
                local ed = EffectData()
                ed:SetOrigin(self:GetPos() + self:GetUp() * 40)
                util.Effect("sparks", ed, true, true)
                self:EmitSound("ambient/explosions/explode_4.wav", 80, 80)
                if not POLUS11.AnyGeneratorOnline(self) then
                    POLUS11.SetBlackout(true)
                end
                POLUS11.Log("ГЕНЕРАТОР СГОРЕЛ ОТ ПЕРЕГРЕВА!")
            end
        else
            -- резерв в простое дышит, но не изнашивается
            local wear = math.max(0, self:GetWear() - (100 / 9600)) -- потихоньку остывает/обслуживается дежурным
            self:SetWear(wear)
        end

        -- мерцание при низком остатке топлива
        if fuel <= POLUS11.Config.FlickerAt and fuel > 0 and math.random() < 0.05 and not idling then
            local ed = EffectData()
            ed:SetOrigin(self:GetPos() + self:GetUp() * 40)
            util.Effect("sparks", ed, true, true)
            self:EmitSound("ambient/energy/spark" .. math.random(1, 6) .. ".wav", 60, 120)
        end

        if fuel <= 0 then
            -- генератор заглох: блэкаут, если нет других работающих генераторов
            if self.SoundLoop then self.SoundLoop:Stop() end
            if not POLUS11.AnyGeneratorOnline(self) then
                POLUS11.SetBlackout(true)
            end
            POLUS11.Log("Генератор заглох — нет топлива!")
        end
    end

    self:NextThink(CurTime() + 0.5)
    return true
end

-- заправка бочкой
function ENT:AddFuelBarrel(mult)
    local add = POLUS11.Config.FuelPerBarrel * (mult or 1)
    self:SetFuel(math.min(POLUS11.Config.GeneratorMaxFuel, self:GetFuel() + add))
    self:SetDamaged(false)

    if self.SoundLoop and not self.SoundLoop:IsPlaying() then
        self.SoundLoop:PlayEx(0.5, 95)
    end

    -- энергия вернулась
    if GetGlobalBool("P11_Blackout", false) then
        POLUS11.SetBlackout(false)
    end

    POLUS11.Log("Генератор заправлен. Остаток: " .. math.floor(self:GetFuel()) .. " сек")
end

-- техсостав? (инженер/техник — быстрые руки)
local function IsTech(ply)
    if POLUS11.IsEngineer and POLUS11.IsEngineer(ply) then return true end
    if P11FW and P11FW.GetJobId then
        local id = P11FW.GetJobId(ply)
        if id == "tech" then return true end
    end
    return false
end

-- ===================== ИСПОЛЬЗОВАНИЕ (E) =====================

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if activator:GetPos():DistToSqr(self:GetPos()) > 200 * 200 then return end

    -- НЕЧТО: саботаж (долгое удержание)
    if activator:GetNWBool("P11_Infected", false) and activator:GetNWBool("P11_InfActive", false) then
        self:StartAction(activator, "sabotage", POLUS11.Config.SabotageTime)
        return
    end

    -- ПРИСЕЛ + E: переключить режим ОСНОВНОЙ ⇄ РЕЗЕРВ (техсостав/командный/админ)
    if activator:Crouching() then
        local job = P11FW and P11FW.GetJob and P11FW.GetJob(activator)
        local can = IsTech(activator) or (job and job.command) or POLUS11.Config.Admin(activator)
        if not can then
            POLUS11.Notify(activator, "Режим генератора переключают техсостав и командир.")
            return
        end
        local nowReserve = not self:GetReserve()
        self:SetReserve(nowReserve)
        POLUS11.Notify(activator, "Генератор: режим «" .. (nowReserve and "РЕЗЕРВ (работает только в аварии)" or "ОСНОВНОЙ") .. "».")
        self:EmitSound("buttons/lever7.wav", 65, nowReserve and 90 or 110)
        if nowReserve and self.SoundLoop then self.SoundLoop:ChangeVolume(0.12, 1) end
        return
    end

    -- ремонт сломанного (авария)
    if self:GetDamaged() then
        self:StartAction(activator, "repair", IsTech(activator) and 4 or POLUS11.Config.RepairTime)
        return
    end

    -- ПОЛОМКА: технический осмотр (держим E)
    local fault = self:GetFault()
    if fault ~= "" then
        local f = POLUS11_GEN_FAULTS[fault]
        local t = IsTech(activator) and 3.5 or 7
        self:StartAction(activator, "service", t)
        POLUS11.Notify(activator, "Диагностика: " .. (f and f.name or fault) .. ". Не отпускайте E!")
        return
    end

    -- заправка огнемёта от генератора
    local wep = activator:GetActiveWeapon()
    if IsValid(wep) and wep:GetClass() == "weapon_polus11_flamethrower" then
        if not POLUS11.IsEngineer(activator) and not POLUS11.IsScientist(activator) then
            POLUS11.Notify(activator, "Заправлять огнемёт умеют только инженер или учёный!")
            return
        end
        local taken = wep:RefillFrom(self)
        if taken > 0 then
            POLUS11.Notify(activator, "Огнемёт заправлен (+ " .. taken .. "). В генераторе осталось: " .. math.floor(self:GetFuel()) .. " сек")
            self:EmitSound("ambient/levels/canals/toxic_slime_gurgle2.wav", 70, 85)
            if POLUS11.TaskEvent then POLUS11.TaskEvent(activator, "refill_ft") end
        else
            POLUS11.Notify(activator, "Огнемёт полон или в генераторе нет топлива!")
        end
        return
    end

    -- ИЗНОС > 40: можно сделать короткий техосмотр (держим E) — снимает нагар
    if self:GetWear() >= 40 then
        local t = IsTech(activator) and 4 or 6
        self:StartAction(activator, "service", t)
        POLUS11.Notify(activator, "Техосмотр: чистим нагар и тянем контакты. Не отпускайте E!")
        return
    end

    -- обычное E: показать статус
    local fuel = math.floor(self:GetFuel())
    local wear = math.floor(self:GetWear())
    POLUS11.Notify(activator, "Генератор: топлива на " .. fuel .. " сек, износ " .. wear
        .. "%" .. (self:GetReserve() and ", режим РЕЗЕРВ" or "")
        .. ". Присядьте+E — режим. Приносите бочки!")
end

function ENT:StartAction(ply, action, time)
    if self.BusyBy and IsValid(self.BusyBy) then return end
    self.BusyBy = ply
    ply.P11_GenAction = {
        ent = self,
        action = action,
        startPos = ply:GetPos(),
        endsAt = CurTime() + time,
        total = time,
    }
    self:SetUseAction(action)

    if action == "sabotage" then
        ply:EmitSound("ambient/energy/spark1.wav", 70, 80)
    elseif action == "service" then
        ply:EmitSound("items/ammo_pickup.wav", 60, 130)
    else
        ply:EmitSound("items/ammo_pickup.wav", 60, 100)
    end
end

-- тик прогресса действий
timer.Create("P11_GenActions", 0.2, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        local a = ply.P11_GenAction
        if a then
            local ent = a.ent
            local dead = (not IsValid(ent)) or (not IsValid(ply)) or (not ply:Alive())
            local moved = (not dead)
                and (ply:GetPos():DistToSqr(a.startPos) > 40 * 40
                or not ply:KeyDown(IN_USE)
                or ply:GetPos():DistToSqr(ent:GetPos()) > 230 * 230)

            if dead or moved then
                if IsValid(ent) then
                    ent.BusyBy = nil
                    ent:SetUseAction("")
                    ent:SetUseProgress(0)
                end
                ply.P11_GenAction = nil
                if moved and IsValid(ply) then
                    POLUS11.Notify(ply, "Действие прервано.")
                end
            else
                local frac = math.Clamp(1 - (a.endsAt - CurTime()) / a.total, 0, 1)
                ent:SetUseProgress(frac)

                if CurTime() >= a.endsAt then
                    if a.action == "repair" then
                        ent:SetDamaged(false)
                        ent:SetWear(math.max(0, ent:GetWear() - 30))
                        ent:SetFault("")
                        if ent.SoundLoop and ent:GetFuel() > 0 then
                            ent.SoundLoop:PlayEx(0.5, 95)
                        end
                        POLUS11.Notify(ply, "Генератор отремонтирован!")
                        POLUS11.Log(ply:Nick() .. " отремонтировал генератор")
                        if POLUS11.TaskEvent then POLUS11.TaskEvent(ply, "repair_gen") end

                    elseif a.action == "service" then
                        local hadFault = ent:GetFault() ~= ""
                        ent:SetFault("")
                        ent:SetWear(0)
                        POLUS11.Notify(ply, hadFault and "Поломка устранена, генератор в норме!"
                            or "Техосмотр завершён: износ снят.")
                        ent:EmitSound("buttons/button9.wav", 65, 110)
                        POLUS11.Log(ply:Nick() .. " обслужил генератор" .. (hadFault and " (поломка устранена)" or ""))
                        if POLUS11.TaskEvent then POLUS11.TaskEvent(ply, "gen_service") end

                    elseif a.action == "sabotage" then
                        ent:SetDamaged(true)
                        ent:SetFuel(0)
                        if ent.SoundLoop then ent.SoundLoop:Stop() end
                        local ed = EffectData()
                        ed:SetOrigin(ent:GetPos() + ent:GetUp() * 40)
                        util.Effect("sparks", ed, true, true)
                        ent:EmitSound("ambient/explosions/explode_4.wav", 90, 90)
                        if not POLUS11.AnyGeneratorOnline(ent) then
                            POLUS11.SetBlackout(true)
                        end
                        POLUS11.Log("САБОТАЖ генератора: " .. ply:Nick())
                    end

                    ent.BusyBy = nil
                    ent:SetUseAction("")
                    ent:SetUseProgress(0)
                    ply.P11_GenAction = nil
                end
            end
        end
    end
end)

-- урон генератору (пули) — ломается
function ENT:OnTakeDamage(dmg)
    if self:GetDamaged() then return end
    self:SetHealth(self:Health() - dmg:GetDamage())
    if self:Health() <= 0 then
        self:SetDamaged(true)
        if self.SoundLoop then self.SoundLoop:Stop() end
        local ed = EffectData()
        ed:SetOrigin(self:GetPos() + self:GetUp() * 40)
        util.Effect("sparks", ed, true, true)
        if not POLUS11.AnyGeneratorOnline(self) then
            POLUS11.SetBlackout(true)
        end
        POLUS11.Log("Генератор уничтожен огнём!")
    end
end
