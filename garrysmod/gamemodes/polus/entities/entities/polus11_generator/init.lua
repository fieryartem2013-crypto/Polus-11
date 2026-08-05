AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    -- модель с фолбэком, если EP2-контента нет
    local models = {
        "models/props_vehicles/generatortrailer01.mdl",
        "models/props_combine/combine_generator01.mdl",
        "models/props_c17/consolebox03a.mdl",
        "models/props_c17/TrapPropeller_Engine.mdl",
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
    self:SetHealth(600)
    self:SetMaxHealth(600)

    self.SoundLoop = CreateSound(self, "ambient/machines/diesel_engine_idle1.wav")
    self.SoundLoop:PlayEx(0.5, 95)

    self.NextTick = 0
end

function ENT:OnRemove()
    if self.SoundLoop then self.SoundLoop:Stop() end
end

-- расход топлива и мерцание
function ENT:Think()
    if self.NextTick > CurTime() then self:NextThink(CurTime() + 0.5) return true end
    self.NextTick = CurTime() + 1

    if self:GetDamaged() then
        self:NextThink(CurTime() + 0.5)
        return true
    end

    local fuel = self:GetFuel()
    if fuel > 0 then
        fuel = fuel - 1
        self:SetFuel(fuel)

        -- мерцание при низком остатке
        if fuel <= POLUS11.Config.FlickerAt and fuel > 0 and math.random() < 0.05 then
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

-- есть ли ещё работающий генератор
function POLUS11.AnyGeneratorOnline(except)
    for _, e in ipairs(ents.FindByClass("polus11_generator")) do
        if e ~= except and IsValid(e) and not e:GetDamaged() and e:GetFuel() > 0 then
            return true
        end
    end
    return false
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

-- ===================== ИСПОЛЬЗОВАНИЕ (E) =====================

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if activator:GetPos():DistToSqr(self:GetPos()) > 200 * 200 then return end

    -- НЕЧТО: саботаж (долгое удержание)
    if activator:GetNWBool("P11_Infected", false) and activator:GetNWBool("P11_InfActive", false) then
        self:StartAction(activator, "sabotage", POLUS11.Config.SabotageTime)
        return
    end

    -- ремонт сломанного
    if self:GetDamaged() then
        self:StartAction(activator, "repair", POLUS11.Config.RepairTime)
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
            POLUS11.Notify(activator, "Огнемёт заправлен (+" .. taken .. "). В генераторе осталось: " .. math.floor(self:GetFuel()) .. " сек")
            self:EmitSound("ambient/levels/canals/toxic_slime_gurgle2.wav", 70, 85)
            if POLUS11.TaskEvent then POLUS11.TaskEvent(activator, "refill_ft") end -- задача инженера
        else
            POLUS11.Notify(activator, "Огнемёт полон или в генераторе нет топлива!")
        end
        return
    end

    -- обычное E: показать статус
    local fuel = math.floor(self:GetFuel())
    POLUS11.Notify(activator, "Генератор: топлива на " .. fuel .. " сек. Принесите бочку и нажмите E по ней у генератора.")
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
                        if ent.SoundLoop and ent:GetFuel() > 0 then ent.SoundLoop:PlayEx(0.5, 95) end
                        POLUS11.Notify(ply, "Генератор отремонтирован!")
                        POLUS11.Log(ply:Nick() .. " отремонтировал генератор")
                        if POLUS11.TaskEvent then POLUS11.TaskEvent(ply, "repair_gen") end -- задача инженера
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
