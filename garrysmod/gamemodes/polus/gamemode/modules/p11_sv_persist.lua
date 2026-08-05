-- ============================================================
--  ПОЛЮС-11 — сохранение станции на карту
--  (генераторы, бочки, лабораторные столы переживают рестарт)
-- ============================================================

local DATA_DIR = "polus11"

local CLASSES = {
    polus11_generator = true,
    polus11_fuelbarrel = true,
    polus11_labtable = true,
    polus11_terminal = true, -- v4.0: ставленные терминалы тоже переживают рестарт
}

local function MapFile()
    return DATA_DIR .. "/station_" .. game.GetMap() .. ".json"
end

function POLUS11.SaveStation()
    if not POLUS11.Config.StationPersist then return end
    if not file.IsDir(DATA_DIR, "DATA") then file.CreateDir(DATA_DIR) end

    local out = {}
    for cls, _ in pairs(CLASSES) do
        for _, e in ipairs(ents.FindByClass(cls)) do
            if IsValid(e) then
                local d = {
                    class = cls,
                    pos = {x = e:GetPos().x, y = e:GetPos().y, z = e:GetPos().z},
                    ang = {p = e:GetAngles().p, y = e:GetAngles().y, r = e:GetAngles().r},
                }
                -- для генератора сохраняем топливо, поломку, износ и режим (v3.7)
                if cls == "polus11_generator" then
                    d.fuel = e.GetFuel and e:GetFuel() or 0
                    d.damaged = e.GetDamaged and e:GetDamaged() or false
                    d.wear = e.GetWear and e:GetWear() or 0
                    d.reserve = e.GetReserve and e:GetReserve() or false
                end
                out[#out + 1] = d
            end
        end
    end

    file.Write(MapFile(), util.TableToJSON(out, true))
end

function POLUS11.LoadStation()
    if not POLUS11.Config.StationPersist then return end

    -- не плодить дубликаты
    for cls, _ in pairs(CLASSES) do
        for _, e in ipairs(ents.FindByClass(cls)) do
            e:Remove()
        end
    end

    local raw = file.Read(MapFile(), "DATA")
    if not raw then return end

    local tbl = util.JSONToTable(raw)
    if not istable(tbl) then return end

    for _, d in ipairs(tbl) do
        if istable(d) and CLASSES[d.class] and istable(d.pos) and istable(d.ang) then
            local e = ents.Create(d.class)
            if IsValid(e) then
                e:SetPos(Vector(d.pos.x or 0, d.pos.y or 0, d.pos.z or 0))
                e:SetAngles(Angle(d.ang.p or 0, d.ang.y or 0, d.ang.r or 0))
                e:Spawn()
                e:Activate()

                if d.class == "polus11_generator" then
                    timer.Simple(0.1, function()
                        if IsValid(e) then
                            e:SetFuel(d.fuel or POLUS11.Config.FuelPerBarrel)
                            e:SetDamaged(d.damaged == true)
                            if d.damaged and e.SoundLoop then e.SoundLoop:Stop() end
                            -- v3.7: износ и режим РЕЗЕРВ переживают рестарт
                            if e.SetWear then e:SetWear(tonumber(d.wear) or 0) end
                            if e.SetReserve then e:SetReserve(d.reserve == true) end
                        end
                    end)
                end
            end
        end
    end

    print("[POLUS-11] Станция загружена с сохранения: " .. #tbl .. " объектов")
end

-- автосохранение: спавн/удаление объектов + каждую минуту
local pending = false
local function DebounceSave()
    if pending then return end
    pending = true
    timer.Simple(2, function()
        pending = false
        POLUS11.SaveStation()
    end)
end

hook.Add("OnEntityCreated", "P11_PersistSave", function(ent)
    if CLASSES[ent:GetClass()] then DebounceSave() end
end)

hook.Add("EntityRemoved", "P11_PersistSave", function(ent)
    if CLASSES[ent:GetClass()] then DebounceSave() end
end)

timer.Create("P11_PersistAutosave", 60, 0, POLUS11.SaveStation)

hook.Add("InitPostEntity", "P11_PersistLoad", function()
    timer.Simple(3, POLUS11.LoadStation)
end)

hook.Add("PostCleanupMap", "P11_PersistLoad", function()
    timer.Simple(1, POLUS11.LoadStation)
end)
