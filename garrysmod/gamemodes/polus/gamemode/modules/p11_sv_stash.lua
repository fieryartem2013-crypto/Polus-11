-- ============================================================
--  ПОЛЮС-11 — КРИМИНАЛ: КЛАДМЕН (сервер) v4.24.0 «РУБЕЖ»
--  У НПС «СВЯЗНОЙ» (📍 «Расставить» → 🔻) бойцuм можно КУПИТЬ
--  закладку за 1000₽: прилетает СЛУЧАЙНАЯ точка на карте (маяк
--  «► ЗАКЛАДКА» только у кладмена). В зоне точки жмёшь E —
--  миниигра «спрячь без шума» (4 шага). Успех: +2200₽ сбросом
--  от связного. Провал: партия сгорела (−1000₽ как уплачено).
--  Срок на закладку 20 мин; кд: 10 мин после удачи, 5 после
--  провала. Арест/наручники НКВД с активной закладкой — партия
--  конфискуется. Одна закладка в руках.
-- ============================================================

local COST      = 1000
local PAY       = 2200
local CD_OK     = 600
local CD_FAIL   = 300
local DEADLINE  = 20 * 60
local ZONE      = 240

POLUS11.Stash        = POLUS11.Stash or {}        -- [ply] = { pos = Vector, till = CurTime }
local StashNext      = {}                          -- [sid] = CurTime (кулдаун)

local function StashSid(ply)
    local s = ply:SteamID64()
    return (s and s ~= "0") and s or ply:SteamID()
end

local function StashClear(ply)
    if IsValid(ply) then
        ply:SetNWVector("P11_StashPos", Vector(0, 0, -99999))
        ply:SetNWFloat("P11_StashTill", 0)
    end
end

-- ============ СЛУЧАЙНАЯ ТОЧКА ============

local ANCHOR_CLASSES = {
    "polus_p11_shopnpc", "polus_p11_contractnpc", "polus_p11_jailnpc",
    "polus11_hearth", "polus_p11_kitchen", "polus11_terminal",
    "polus11_labtable", "polus11_bloodlab", "polus11_avtosalon",
    "polus_p11_storage", "polus11_crafttable", "polus_fw_jobnpc",
    "polus11_lootcrate", "polus11_lootcache", "polus11_loottech",
}

local function StashSpots()
    local out, seen = {}, {}
    for _, cls in ipairs(ANCHOR_CLASSES) do
        for _, e in ipairs(ents.FindByClass(cls)) do
            if IsValid(e) then
                local p = e:GetPos()
                local k = math.floor(p.x / 128) .. "_" .. math.floor(p.y / 128)
                if not seen[k] then
                    seen[k] = true
                    out[#out + 1] = Vector(p.x, p.y, p.z + 2)
                end
            end
        end
    end
    return out
end

local function StashPick(fromPos)
    local pool = StashSpots()
    local far = {}
    for _, p in ipairs(pool) do
        local d = p:DistToSqr(fromPos)
        if d >= 1500 * 1500 and d <= 9000 * 9000 then far[#far + 1] = p end
    end
    if #far > 0 then return far[math.random(#far)] end
    if #pool > 0 then return pool[math.random(#pool)] end
    return Vector(fromPos.x + 800, fromPos.y + 800, fromPos.z + 4)
end

-- ============ ВЗЯТЬ ЗАКЛАДКУ (E по связному) ============

function POLUS11.StashNPCUse(npc, ply)
    if not (IsValid(ply) and ply:Alive()) then return end

    if POLUS11.Stash[ply] then
        local st = POLUS11.Stash[ply]
        POLUS11.Notify(ply, "Закладка уже при тебе: маячит «► ЗАКЛАКА». Срок — " ..
            math.max(1, math.ceil((st.till - CurTime()) / 60)) .. " мин, спеши.")
        return
    end

    local sid = StashSid(ply)
    local cd = StashNext[sid] or 0
    if CurTime() < cd then
        POLUS11.Notify(ply, "Связной молчит: канал горяч. Новая закладка через " ..
            math.ceil((cd - CurTime()) / 60) .. " мин.")
        ply:EmitSound("buttons/button10.wav", 55, 100)
        return
    end

    if POLUS11.GetMoney(ply) < COST then
        POLUS11.Notify(ply, "Закладка стоит " .. COST .. "₽ задатка — у тебя " ..
            math.floor(POLUS11.GetMoney(ply)) .. "₽. Приходи с деньгами.")
        ply:EmitSound("buttons/button10.wav", 55, 100)
        return
    end

    if not POLUS11.TakeMoney(ply, COST, "Куплена закладка (криминал: кладмен)") then
        POLUS11.Notify(ply, "Не вышло взять задаток.")
        return
    end

    local pos = StashPick(npc:GetPos())
    POLUS11.Stash[ply] = { pos = pos, till = CurTime() + DEADLINE }
    ply:SetNWVector("P11_StashPos", pos)
    ply:SetNWFloat("P11_StashTill", CurTime() + DEADLINE)
    ply:EmitSound("ambient/levels/labs/coinslot1.wav", 60, 110)

    local d = math.floor(ply:GetPos():Distance(pos))
    POLUS11.Notify(ply, "ЗАКЛАДКА У ТЕБЯ (" .. d .. " юн).В зоне жми E и спрячь тихо: миниигра. Срок 20 мин, иначе всё сгорит.")
    POLUS11.Log("КЛАДМЕН: " .. ply:Nick() .. " купил закладку " .. COST .. "₽, точка @ " .. tostring(pos))
end

-- ============ МИНИИГРА НА ТОЧКЕ ============

hook.Add("KeyPress", "P11.StashE", function(ply, key)
    if key ~= IN_USE then return end
    local st = POLUS11.Stash[ply]
    if not st then return end
    if ply:GetPos():DistToSqr(st.pos) > ZONE * ZONE then return end
    if POLUS11.MiniSessions and POLUS11.MiniSessions[ply] then return end
    if POLUS11.MiniSessions == nil or POLUS11.MiniStart == nil then return end

    POLUS11.Notify(ply, "ПРЯЧЕМ: жми клавишу в такт [R/F/T/G] — без шума!")
    POLUS11.MiniStart(ply, ply, {
        steps = 4, window = 1.8, title = "ЗАКЛАДКА: ТИШЕ ВОДЫ",
        cb = function(p, _, ok)
            POLUS11.StashFinish(p, ok)
        end,
    })
end)

function POLUS11.StashFinish(ply, ok)
    local st = POLUS11.Stash[ply]
    if not st then return end
    POLUS11.Stash[ply] = nil
    StashClear(ply)
    local sid = StashSid(ply)

    if ok then
        StashNext[sid] = CurTime() + CD_OK
        if POLUS11.AddMoney then
            POLUS11.AddMoney(ply, PAY, "Кладмен: закладка доставлена")
        end
        ply:EmitSound("buttons/button15.wav", 70, 110)
        POLUS11.Notify(ply, "Закладка легла чисто. Сброс от связного: +" .. PAY .. "₽.")
        POLUS11.Log("КЛАДМЕН: " .. ply:Nick() .. " доставил закладку, +" .. PAY .. "₽")
    else
        StashNext[sid] = CurTime() + CD_FAIL
        ply:EmitSound("ambient/alarms/warningbell1.wav", 55, 140)
        POLUS11.Notify(ply, "Шум при подходе — закладка СПАЛИЛАСЬ. Партия потеряна (задаток " .. COST .. "₽ не вернут).")
        POLUS11.Log("КЛАДМЕН: " .. ply:Nick() .. " сорвал закладку, −" .. COST .. "₽")
    end
end

-- ============ ТИК: срок вышел / дисконнект / арест ============

timer.Create("P11.StashTick", 5, 0, function()
    for ply, st in pairs(POLUS11.Stash) do
        if not IsValid(ply) then
            POLUS11.Stash[ply] = nil
        elseif CurTime() > st.till then
            POLUS11.Stash[ply] = nil
            StashClear(ply)
            StashNext[StashSid(ply)] = CurTime() + CD_FAIL
            POLUS11.Notify(ply, "Срок вышел — связной сжёг закладку. Задаток сгорел.")
            POLUS11.Log("КЛАДМЕН: " .. ply:Nick() .. " просрочил закладку")
        end
    end
end)

hook.Add("PlayerDisconnected", "P11.StashBye", function(ply)
    if POLUS11.Stash[ply] then POLUS11.Stash[ply] = nil end
end)

-- НКВД сцапал с закладкой — конфискат
hook.Add("P11FW.Punished", "P11.StashBusted", function(target)
    if IsValid(target) and POLUS11.Stash[target] and P11FW.IsPunished and P11FW.IsPunished(target) then
        POLUS11.Stash[target] = nil
        StashClear(target)
        StashNext[StashSid(target)] = CurTime() + CD_FAIL
        POLUS11.Notify(target, "При обыске нашли закладку — партия КОНФИСКОВАНА особым отделом.")
        POLUS11.Log("КЛАДМЕН: у " .. target:Nick() .. " конфисковали закладку при наказании")
    end
end)

print("[POLUS-11] КРИМИНАЛ-КЛАДМЕН v4.24.0 «РУБЕЖ»: связной " .. COST .. "₽ → точка → миниигра → +" .. PAY .. "₽")
