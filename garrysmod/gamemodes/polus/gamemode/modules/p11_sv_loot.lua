-- ============================================================
--  ПОЛЮС-11 — ЛУТ «КУЗНЯ» (server) v4.11.0
--  Заявка владельца: «ящики и другие лутабельные энтити, которые
--  можно лутать и получать скрап — и стол крафтов, где всё
--  крафтится». Три лутабельные энтити + верстак как ТЕЛО мастерской:
--   • ЯЩИК ЛОМА (polus11_lootcrate)  — металлолом/брезент/тушёнка,
--     иногда паёк/запчасти/рубли. Обычный, восполняется 4 мин.
--   • ТОПЛИВНАЯ БОЧКА (polus11_lootbarrel) — соляра/спирт, иногда
--     лом/химсвет/рубли. Обычная, восполняется 4 мин.
--   • ТАЙНИК СНАБЖЕНЦА (polus11_lootcache) — рубли+запчасти; редко
--     ампула/УКОЛ-С/рация; очень редко +5 ПФ ФЛЮКСА. Редкий, 10 мин.
--   • КУСТАРНЫЙ ВЕРСТАК (polus11_crafttable) — E: окно мастерской
--     со ВСЕМИ рецептами станции (рецепты — p11_sv_craft.lua).
--  Пустеет на таймере (темнеет, маяк POI гаснет до пополнения).
--  Расстановка: 📍 «Расставить» или консоль-рассыпка:
--   p11_lootspawn crate 12  /  barrel 6  /  cache 4  /  table 1
--   p11_lootclear crate (или all) — собрать и вычистить сохранение.
--  Тела энтити сами следят за восполнением (Think), здесь — роллы
--  лута, открытие верстака, KeyPress-страховка и команды.
-- ============================================================

local LOOT = {
    polus11_lootcrate = {
        name = "ЯЩИК ЛОМА",
        respawn = 240,
        snd = "physics/wood/wood_crate_impact_soft1.wav",
        items = {
            { id = "scrap",  min = 1, max = 2, ch = 0.95 },
            { id = "cloth",  min = 1, max = 2, ch = 0.70 },
            { id = "cons",   min = 1, max = 1, ch = 0.55 },
            { id = "spirit", min = 1, max = 1, ch = 0.30 },
            { id = "parts",  min = 1, max = 1, ch = 0.15 },
            { id = "ration", min = 1, max = 1, ch = 0.12 },
        },
        money = { min = 60, max = 240, ch = 0.25 },
    },
    polus11_lootbarrel = {
        name = "ТОПЛИВНАЯ БОЧКА",
        respawn = 240,
        snd = "physics/metal/metal_barrel_impact_soft1.wav",
        items = {
            { id = "fuel",      min = 1, max = 2, ch = 0.95 },
            { id = "spirit",    min = 1, max = 1, ch = 0.50 },
            { id = "scrap",     min = 1, max = 1, ch = 0.45 },
            { id = "chemlight", min = 1, max = 1, ch = 0.15 },
        },
        money = { min = 40, max = 150, ch = 0.15 },
    },
    polus11_lootcache = {
        name = "ТАЙНИК СНАБЖЕНЦА",
        respawn = 600,
        snd = "items/suitchargeok1.wav",
        items = {
            { id = "parts",   min = 1, max = 2, ch = 0.90 },
            { id = "spirit",  min = 1, max = 1, ch = 0.45 },
            { id = "ampoule", min = 1, max = 1, ch = 0.30 },
            { id = "ukol",    min = 1, max = 1, ch = 0.15 },
            { id = "radio",   min = 1, max = 1, ch = 0.06 },
        },
        money = { min = 200, max = 700, ch = 1.0 },
        flux  = { n = 5, ch = 0.04 },
    },
}

local CLS_TABLE = "polus11_crafttable"

-- ============ ОБЫСК ЛУТ-ЭНТИТИ ============

function POLUS11.LootUse(e, ply)
    if not (IsValid(e) and IsValid(ply) and ply:IsPlayer()) then return end
    if not ply:Alive() then return end
    if ply:GetPos():DistToSqr(e:GetPos()) > 150 * 150 then return end

    ply.P11_LootNext = ply.P11_LootNext or 0
    if CurTime() < ply.P11_LootNext then return end
    ply.P11_LootNext = CurTime() + 0.9

    local def = LOOT[e:GetClass()]
    if not def then return end

    if e.LootReady == false then
        local left = math.max(0, math.ceil((e:GetLootReadyAt() or 0) - CurTime()))
        POLUS11.Notify(ply, "Пусто. Пополнение через ~" .. left .. " сек — загляни позже.")
        ply:EmitSound("buttons/button10.wav", 55, 95)
        return
    end

    -- роллы: всё падает в ИНВЕНТАРЬ (🎒 C-меню), рубли — в кошелёк
    local data = POLUS11.InvOf(ply)
    local got = {}
    for _, r in ipairs(def.items) do
        if math.random() < r.ch then
            local n = math.random(r.min, r.max)
            if POLUS11.Items[r.id] then
                data.items[r.id] = (tonumber(data.items[r.id]) or 0) + n
                local nm = POLUS11.Items[r.id].name or r.id
                got[#got + 1] = nm .. (n > 1 and (" ×" .. n) or "")
            end
        end
    end
    if def.money and math.random() < def.money.ch then
        local m = math.random(def.money.min, def.money.max)
        if POLUS11.AddMoney then
            POLUS11.AddMoney(ply, m, "добыча: " .. def.name)
            got[#got + 1] = m .. "₽"
        end
    end
    if def.flux and math.random() < def.flux.ch and POLUS11.FluxAdd then
        POLUS11.FluxAdd(ply, def.flux.n, "находка в тайнике.")
        got[#got + 1] = "+" .. def.flux.n .. " ПФ"
    end
    if #got == 0 then -- крошка-гарант: пустым обыск не бывает
        data.items["scrap"] = (tonumber(data.items["scrap"]) or 0) + 1
        got[#got + 1] = "Металлолом ×1"
    end
    if POLUS11.InvSaveNow then POLUS11.InvSaveNow() end
    POLUS11.InvSync(ply)

    -- тара пустеет: темнеет и молчит до таймера (Think энтити вернёт свет)
    e.LootReady = false
    e:SetLootReadyAt(CurTime() + def.respawn)
    e:SetColor(Color(105, 105, 105, 255))
    e:EmitSound(def.snd, 65, 100)

    POLUS11.Notify(ply, "🔍 " .. def.name .. ": " .. table.concat(got, ", ") .. " — в инвентаре (🎒).")
    ply:ChatPrint("[ЛУТ] " .. def.name .. " → " .. table.concat(got, ", "))
    POLUS11.Log("ЛУТ: " .. ply:Nick() .. " обыскал «" .. def.name .. "»: " .. table.concat(got, ", "))
end

-- ============ ВЕРСТАК → ОКНО МАСТЕРСКОЙ ============

function POLUS11.CraftTableUse(e, ply)
    if not (IsValid(e) and IsValid(ply) and ply:IsPlayer()) then return end
    if not ply:Alive() then return end
    if ply:GetPos():DistToSqr(e:GetPos()) > 170 * 170 then return end

    ply.P11_VerstakNext = ply.P11_VerstakNext or 0
    if CurTime() < ply.P11_VerstakNext then return end
    ply.P11_VerstakNext = CurTime() + 0.9

    POLUS11.InvSync(ply) -- свежие материалы — и сразу окно
    net.Start("P11_CraftOpen")
    net.Send(ply)
    ply:EmitSound("buttons/button9.wav", 60, 110)
end

-- KeyPress-страховка (Use иногда глотают сидящие модели/прицел):
hook.Add("KeyPress", "P11.LootE", function(ply, key)
    if key ~= IN_USE then return end
    local e = ply:GetEyeTrace().Entity
    if not IsValid(e) then return end
    local cls = e:GetClass()
    if LOOT[cls] then
        if ply:GetPos():DistToSqr(e:GetPos()) <= 150 * 150 then
            POLUS11.LootUse(e, ply)
        end
    elseif cls == CLS_TABLE then
        if ply:GetPos():DistToSqr(e:GetPos()) <= 170 * 170 then
            POLUS11.CraftTableUse(e, ply)
        end
    end
end)

-- ============ КОНСОЛЬ: РАССЫПКА И УБОРКА ============

local function CanManage(ply)
    if not IsValid(ply) then return true end -- серверная консоль
    if P11FW and P11FW.Config and P11FW.Config.Admin and P11FW.Config.Admin(ply) then return true end
    if P11FW and P11FW.GetRankLevel and P11FW.GetRankLevel(ply) >= 16 then return true end
    return false
end

-- роль -> класс (берём из расстановки склада, с запасной картой)
local function RoleClass(role)
    if POLUS11.PLACEABLE and POLUS11.PLACEABLE[role] then return POLUS11.PLACEABLE[role] end
    local backup = {
        crate = "polus11_lootcrate", barrel = "polus11_lootbarrel",
        cache = "polus11_lootcache", crafttable = "polus11_crafttable",
    }
    return backup[role]
end

-- «ящик»/«бочка»/«тайник»/«верстак»/«стол» → роль расстановки
local function ResolveRole(a)
    a = string.lower(tostring(a or ""))
    if a == "crate" or a == "ящик" or a == "Ящик" or a == "ящики" then return "crate" end
    if a == "barrel" or a == "бочка" or a == "Бочка" or a == "бочки" then return "barrel" end
    if a == "cache" or a == "тайник" or a == "Тайник" then return "cache" end
    if a == "table" or a == "craft" or a == "crafttable" or a == "верстак" or a == "Верстак"
        or a == "стол" or a == "Стол" then return "crafttable" end
    return nil
end

local ALL_ROLES = { "crate", "barrel", "cache", "crafttable" }

-- место на земле рядом с игроком: угол/радиус → луч сверху, прямую видимость,
-- свободный хулл и отсутствие соседей-лутниц ближе 130 юнитов
local function FindGroundSpot(ply, rmin, rmax)
    local center = ply:GetPos()
    for _ = 1, 16 do
        local ang = math.random() * math.pi * 2
        local r = rmin + math.random() * (rmax - rmin)
        local p = center + Vector(math.cos(ang) * r, math.sin(ang) * r, 0)
        if util.IsInWorld(p) then
            local down = util.TraceLine({
                start  = p + Vector(0, 0, 260),
                endpos = p - Vector(0, 0, 900),
                mask   = MASK_SOLID_BRUSHONLY,
            })
            if down.Hit and not down.StartSolid and not down.HitSky then
                local cand = down.HitPos
                local los = util.TraceLine({
                    start  = ply:EyePos(),
                    endpos = cand + Vector(0, 0, 18),
                    mask   = MASK_SOLID_BRUSHONLY,
                })
                local clear = not los.Hit
                if clear then -- не вплотную к другим лутницам/верстакам
                    for _, role in ipairs(ALL_ROLES) do
                        local cls = RoleClass(role)
                        if cls then
                            for _, o in ipairs(ents.FindByClass(cls)) do
                                if IsValid(o) and o:GetPos():DistToSqr(cand) < 130 * 130 then
                                    clear = false
                                    break
                                end
                            end
                        end
                        if not clear then break end
                    end
                end
                if clear then
                    local hull = util.TraceHull({
                        start  = cand + Vector(0, 0, 4),
                        endpos = cand + Vector(0, 0, 4),
                        mins   = Vector(-18, -18, 0),
                        maxs   = Vector(18, 18, 40),
                        mask   = MASK_SOLID_BRUSHONLY,
                    })
                    if not hull.Hit then return cand end
                end
            end
        end
    end
    return nil
end

concommand.Add("p11_lootspawn", function(ply, cmd, args)
    if not CanManage(ply) then
        if POLUS11.Notify then POLUS11.Notify(ply, "Рассыпка лута — только админам станции.") end
        return
    end
    if not IsValid(ply) then
        print("[P11LOOT] p11_lootspawn <crate|barrel|cache|table> [N] — зайди в игру админом и повтори от себя.")
        return
    end
    local role = ResolveRole(args and args[1])
    if not role then
        POLUS11.Notify(ply, "Кого сыпем? p11_lootspawn crate 12 | barrel 6 | cache 4 | table 1")
        ply:ChatPrint("[ЛУТ] Роли: crate (ящик), barrel (бочка), cache (тайник), table (верстак).")
        return
    end
    local cls = RoleClass(role)
    local n = math.Clamp(tonumber(args and args[2]) or 1, 1, 60)
    local made, failed = 0, 0
    for _ = 1, n do
        local pos = FindGroundSpot(ply, 220, 1500)
        if pos then
            local e = ents.Create(cls)
            if IsValid(e) then
                e:SetPos(pos + Vector(0, 0, 2))
                e:SetAngles(Angle(0, math.random(0, 359), 0))
                e:Spawn()
                e:Activate()
                made = made + 1
            else
                failed = failed + 1
            end
        else
            failed = failed + 1
        end
    end
    if POLUS11.PlaceSave then POLUS11.PlaceSave(role) end
    local msg = "Рассыпано «" .. role .. "»: +" .. made .. " шт" ..
        (failed > 0 and (" (места не хватило: " .. failed .. ")") or "") ..
        ". Сохранено на карте."
    POLUS11.Notify(ply, msg)
    ply:ChatPrint("[ЛУТ] " .. msg)
    print("[P11LOOT] " .. ply:Nick() .. ": " .. msg)
    if POLUS11.Log then POLUS11.Log("ЛУТ: " .. ply:Nick() .. " рассыпал " .. role .. " ×" .. made) end
end)

concommand.Add("p11_lootclear", function(ply, cmd, args)
    if not CanManage(ply) then
        if POLUS11.Notify then POLUS11.Notify(ply, "Уборка лута — только админам станции.") end
        return
    end
    local a = string.lower(tostring(args and args[1] or ""))
    local roles = {}
    if a == "all" or a == "всё" or a == "Всё" or a == "все" or a == "" then
        roles = ALL_ROLES
    else
        local role = ResolveRole(a)
        if not role then
            if POLUS11.Notify then
                POLUS11.Notify(ply, "p11_lootclear crate | barrel | cache | table | all")
            end
            return
        end
        roles = { role }
    end
    local removed = 0
    for _, role in ipairs(roles) do
        local cls = RoleClass(role)
        if cls then
            for _, e in ipairs(ents.FindByClass(cls)) do
                if IsValid(e) then e:Remove() removed = removed + 1 end
            end
        end
        if POLUS11.PlaceSave then POLUS11.PlaceSave(role) end -- пустой список в файл
    end
    local msg = "Убрано лутниц/верстаков: " .. removed .. " (сохранение вычищено)."
    if IsValid(ply) then
        POLUS11.Notify(ply, msg)
        ply:ChatPrint("[ЛУТ] " .. msg)
    end
    print("[P11LOOT] " .. (IsValid(ply) and ply:Nick() or "console") .. ": " .. msg)
    if POLUS11.Log then POLUS11.Log("ЛУТ: уборка " .. table.concat(roles, ",") .. " — " .. removed .. " шт") end
end)

print("[POLUS-11] ЛУТ «КУЗНЯ» v4.11.0: ящик/бочка/тайник — обыск за E и самовосполнение; верстак — окно мастерской; p11_lootspawn crate 12")
