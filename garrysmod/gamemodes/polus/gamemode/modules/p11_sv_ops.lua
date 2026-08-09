-- ============================================================
--  ПОЛЮС-11 — ОПЕРАЦИИ «РУБЕЖ» (сервер) v4.24.0
--  Админский ивент (реворк «ЛЕДОКОЛА», заявка владельца):
--  админ жмёт «НАЧАТЬ» у себя во вкладке ОПЕРАЦИИ (C-меню) →
--  у ВСЕХ бойцов профы слетают на новобранца → окно выбора
--  фракции «СССР / АМЕРИКА» → выбравшие автоматом становятся
--  солдатами своей стороны → на карте СЛУЧАЙНО встают точки
--  захвата (энтити «ФЛАГ») → 30 минут РДМ-ивента: удержать
--  ВСЕ точки 5 минут подряд — досрочная победа. Финал —
--  лидерборд и деньги: победителям 5000₽, проигравшим 1000₽
--  (ничья — по 2500₽), только участникам онлайн.
-- ============================================================

util.AddNetworkString("P11_OpUI")    -- сервер→клиент: зов (recruit/battle) / статус
util.AddNetworkString("P11_OpPick")  -- клиент→сервер: выбор фракции / админ-команды
util.AddNetworkString("P11_OpBoard") -- сервер→клиент: лидерборд (JSON)

local RECRUIT_T = 45          -- запись сторон
local BATTLE_T  = 30 * 60     -- бой
local HOLD_WIN  = 5 * 60      -- держать ВСЕ точки столько подряд
local POINTS_N  = 4           -- точек на карте
local WIN_PAY, LOSE_PAY, DRAW_PAY = 5000, 1000, 2500

POLUS11.Op = POLUS11.Op or {}
local Op = POLUS11.Op

local function OpResetAll()
    Op.phase  = "idle"
    Op.side   = {}   -- [ply] = "rkka"|"eagle"
    Op.hold   = { rkka = 0, eagle = 0 }
    Op.kills  = { rkka = 0, eagle = 0 }
    Op.pkills = {}   -- [ply] = { name, fac, k }
    Op.points = {}
    Op.endT   = 0
    Op.recruitEnd = 0
    Op.endUntil = 0
end
OpResetAll()

local FACT_NAME = { rkka = "СССР", eagle = "АМЕРИКА" }

local function OpAnnounce(txt)
    net.Start("P11_Announce")
        net.WriteString(txt)
        net.WriteString("ОПЕРАЦИЯ «РУБЕЖ»")
    net.Broadcast()
end

local function OpReset(ply)
    P11FW.SetJob(ply, (P11FW.Config and P11FW.Config.DefaultJob) or "recruit", nil, true)
end

-- участникам в ходе операции профы не меняют (ворота fw_sv_jobs)
function POLUS11.OpJobBlock(ply)
    return IsValid(ply) and Op.phase ~= "idle" and Op.side[ply] ~= nil
end

-- ============ ТОЧКИ НА КАРТЕ (случайные) ============

local ANCHOR_CLASSES = {
    "polus_p11_shopnpc", "polus_p11_contractnpc", "polus_p11_jailnpc",
    "polus11_hearth", "polus_p11_kitchen", "polus11_terminal",
    "polus11_labtable", "polus11_bloodlab", "polus11_avtosalon",
    "polus_p11_storage", "polus11_crafttable", "polus_fw_jobnpc",
    "polus11_cappoint",
}

local function AnchorSpots()
    local out, seen = {}, {}
    local function push(p)
        local k = math.floor(p.x / 96) .. "_" .. math.floor(p.y / 96)
        if seen[k] then return end
        seen[k] = true
        out[#out + 1] = Vector(p.x, p.y, p.z + 2)
    end
    for _, cls in ipairs(ANCHOR_CLASSES) do
        for _, e in ipairs(ents.FindByClass(cls)) do
            if IsValid(e) and not e.P11_OpPoint then push(e:GetPos()) end
        end
    end
    for _, e in ipairs(ents.FindByClass("info_player_start")) do
        if IsValid(e) then push(e:GetPos()) end
    end
    return out
end

local function PickOpSpots(n)
    local pool = AnchorSpots()
    for i = #pool, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    local picked = {}
    local minD = 1300
    local guard = 0
    while #picked < n and guard < 60 do
        guard = guard + 1
        for _, p in ipairs(pool) do
            if #picked >= n then break end
            local ok = true
            for _, q in ipairs(picked) do
                if p:DistToSqr(q) < minD * minD then ok = false break end
            end
            if ok then picked[#picked + 1] = p end
        end
        minD = minD - 240
        if minD < 420 and #picked < n then break end
    end
    while #picked < n do
        local base = pool[1] or Vector(0, 0, 0)
        picked[#picked + 1] = Vector(base.x + math.random(-700, 700), base.y + math.random(-700, 700), base.z + 4)
    end
    return picked
end

local function OpPointsSpawn()
    Op.points = {}
    for _, p in ipairs(PickOpSpots(POINTS_N)) do
        local e = ents.Create("polus11_cappoint")
        if IsValid(e) then
            e:SetPos(p)
            e:SetAngles(Angle(0, math.random(0, 359), 0))
            e:Spawn()
            e:Activate()
            e.P11_OpPoint = true
            e:SetNWBool("P11_OpPoint", true)  -- v4.24.1 «МАЯК»: маяки мест точек на HUD
            Op.points[#Op.points + 1] = e
        end
    end
end

local function OpPointsClear()
    for _, e in ipairs(Op.points or {}) do
        if IsValid(e) then e:Remove() end
    end
    Op.points = {}
end

-- ============ СТОРОНЫ ============

local function OpAssign(ply, fac)
    if not (IsValid(ply) and ply:Alive()) then return end
    if fac ~= "rkka" and fac ~= "eagle" then return end
    Op.side[ply] = fac
    ply:SetNWString("P11_OpSide", fac)
    local jobId = (fac == "eagle") and "seed_eagle_svyaznoi" or "seed_rkka_soldat"
    P11FW.SetJob(ply, jobId, nil, true)
    POLUS11.Notify(ply, "Ты солдат стороны «" .. FACT_NAME[fac] .. "». Оружие к бою — точки решат всё!")
end

local function OpAutoBalance(ply)
    local a, b = 0, 0
    for _, f in pairs(Op.side) do
        if f == "rkka" then a = a + 1 elseif f == "eagle" then b = b + 1 end
    end
    OpAssign(ply, (a <= b) and "rkka" or "eagle")
end

-- ============ ХОД ОПЕРАЦИИ ============

function POLUS11.OpStart(by)
    if Op.phase ~= "idle" then
        if IsValid(by) then POLUS11.Notify(by, "Операция уже идёт: фаза «" .. Op.phase .. "».") end
        return
    end
    -- v4.24.1 «МАЯК»: два ивента сразу не идут — во время рейда операции молчат
    if POLUS11.Raid and POLUS11.Raid.phase and POLUS11.Raid.phase ~= "idle" then
        if IsValid(by) then POLUS11.Notify(by, "Идёт РЕЙД — операцию объявишь после его финала.") end
        return
    end
    OpResetAll()
    Op.phase = "recruit"
    Op.recruitEnd = CurTime() + RECRUIT_T
    -- «кик с проф на новобранца» у всей станции
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() then OpReset(ply) end
    end
    OpAnnounce("ОПЕРАЦИЯ «РУБЕЖ» ОБЪЯВЛЕНА: вахты сброшены! Выбери сторону — СССР или АМЕРИКА. Запись " .. RECRUIT_T .. " сек.")
    net.Start("P11_OpUI")
        net.WriteString("call")
    net.Broadcast()
    SetGlobalString("P11_Op", "recruit|" .. RECRUIT_T)
    POLUS11.Log("ОПЕРАЦИЯ: старт от " .. (IsValid(by) and by:Nick() or "консоли"))
end

function POLUS11.OpAbort(by)
    if Op.phase == "idle" then return end
    OpPointsClear()
    for ply in pairs(Op.side) do
        if IsValid(ply) then
            ply:SetNWString("P11_OpSide", "")
            OpReset(ply)
        end
    end
    OpAnnounce("ОПЕРАЦИЯ ОТМЕНЕНА командованием. Вахты свободны — выбери должность в F4.")
    SetGlobalString("P11_Op", "")
    POLUS11.Log("ОПЕРАЦИЯ: отменена (" .. (IsValid(by) and by:Nick() or "консоль") .. ")")
    OpResetAll()
end

local function OpBattleStart()
    Op.phase = "battle"
    Op.endT = CurTime() + BATTLE_T
    -- нерешившиеся — автобаланс в меньшую сторону
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() and not Op.side[ply] then
            OpAutoBalance(ply)
        end
    end
    OpPointsSpawn()
    OpAnnounce("БОЙ НАЧАЛСЯ: на станции " .. #Op.points ..
        " точек захвата! Удерживайте ВСЕ сразу 5 минут — или больше по итогу 30 минут. Огонь по чужой стороне разрешён.")
    net.Start("P11_OpUI")
        net.WriteString("battle")
    net.Broadcast()
end

local function OpFinish(result)
    Op.phase = "end"
    Op.endUntil = CurTime() + 25

    -- награды активным (участникам онлайн)
    for ply in pairs(Op.side) do
        if IsValid(ply) then
            local mine = Op.side[ply]
            local pay = (result == "draw") and DRAW_PAY
                or (mine == result and WIN_PAY or LOSE_PAY)
            if POLUS11.AddMoney then
                POLUS11.AddMoney(ply, pay, "Операция «РУБЕЖ»: " ..
                    (result == "draw" and "ничья" or (mine == result and "победа стороны" or "проигрыш стороны")))
            end
        end
    end

    local tname = (result == "draw") and "НИЧЬЯ" or ("ПОБЕДА: " .. (FACT_NAME[result] or "?"))
    OpAnnounce("ОПЕРАЦИЯ ЗАВЕРШЕНА — " .. tname .. "! Победителям 5000₽, проигравшим 1000₽ (участникам). Лидерборд на экране.")

    -- лидерборд
    local top = {}
    for _, rec in pairs(Op.pkills) do
        top[#top + 1] = rec
    end
    table.sort(top, function(a, b) return (a.k or 0) > (b.k or 0) end)
    while #top > 8 do top[#top] = nil end
    net.Start("P11_OpBoard")
        net.WriteString(util.TableToJSON({
            winner = result, wname = tname,
            holdA = math.floor(Op.hold.rkka), holdB = math.floor(Op.hold.eagle),
            killsA = Op.kills.rkka, killsB = Op.kills.eagle,
            top = top, winPay = WIN_PAY, losePay = LOSE_PAY, drawPay = DRAW_PAY,
        }) or "{}")
    net.Broadcast()
    POLUS11.Log("ОПЕРАЦИЯ: финал — " .. tname ..
        " (держали " .. math.floor(Op.hold.rkka) .. "с/" .. math.floor(Op.hold.eagle) ..
        "с, фраги " .. Op.kills.rkka .. "/" .. Op.kills.eagle .. ")")
end

local function OpCleanup()
    OpPointsClear()
    for ply in pairs(Op.side) do
        if IsValid(ply) then
            ply:SetNWString("P11_OpSide", "")
            OpReset(ply)
            POLUS11.Notify(ply, "Операция окончена. Вахта свободна — выбери должность в F4.")
        end
    end
    SetGlobalString("P11_Op", "")
    OpResetAll()
end

-- ============ ТИК ============

timer.Create("P11.OpTick", 2, 0, function()
    if Op.phase == "recruit" then
        local left = math.max(0, Op.recruitEnd - CurTime())
        SetGlobalString("P11_Op", "recruit|" .. math.ceil(left))
        if left <= 0 then OpBattleStart() end
        return
    end

    if Op.phase == "battle" then
        -- владение точками
        local own = { rkka = 0, eagle = 0 }
        local alivePts = 0
        for _, e in ipairs(Op.points) do
            if IsValid(e) then
                alivePts = alivePts + 1
                local ow = e.GetOwnerFact and e:GetOwnerFact() or ""
                if own[ow] then own[ow] = own[ow] + 1 end
            end
        end
        -- держим ВСЕ сразу?
        if alivePts > 0 and own.rkka == alivePts then
            Op.hold.rkka = Op.hold.rkka + 2
        end
        if alivePts > 0 and own.eagle == alivePts then
            Op.hold.eagle = Op.hold.eagle + 2
        end

        -- досрочная победа удержанием
        if Op.hold.rkka >= HOLD_WIN or Op.hold.eagle >= HOLD_WIN then
            OpFinish(Op.hold.rkka >= HOLD_WIN and "rkka" or "eagle")
            return
        end

        -- таймер вышел — по итогам
        if CurTime() >= Op.endT then
            local res = "draw"
            if Op.hold.rkka ~= Op.hold.eagle then
                res = (Op.hold.rkka > Op.hold.eagle) and "rkka" or "eagle"
            elseif own.rkka ~= own.eagle then
                res = (own.rkka > own.eagle) and "rkka" or "eagle"
            elseif Op.kills.rkka ~= Op.kills.eagle then
                res = (Op.kills.rkka > Op.kills.eagle) and "rkka" or "eagle"
            end
            OpFinish(res)
            return
        end

        local left = math.max(0, Op.endT - CurTime())
        SetGlobalString("P11_Op", "battle|" .. math.ceil(left) .. "|" ..
            math.floor(Op.hold.rkka) .. "|" .. math.floor(Op.hold.eagle) ..
            "|" .. own.rkka .. "|" .. own.eagle .. "|" .. alivePts)
        return
    end

    if Op.phase == "end" and CurTime() >= Op.endUntil then
        OpCleanup()
    end
end)

-- фраги противоположной стороны — в счёт
hook.Add("PlayerDeath", "P11.OpFrag", function(vic, inf, att)
    if Op.phase ~= "battle" then return end
    local fv = IsValid(vic) and Op.side[vic] or nil
    local fa = IsValid(att) and att:IsPlayer() and Op.side[att] or nil
    if fv and fa and fv ~= fa then
        Op.kills[fa] = Op.kills[fa] + 1
        local rec = Op.pkills[att]
        if not rec then
            rec = { name = att:Nick(), fac = fa, k = 0 }
            Op.pkills[att] = rec
        end
        rec.k = rec.k + 1
        rec.name = att:Nick()
    end
end)

-- поздний вход в горячую точку
hook.Add("PlayerInitialSpawn", "P11.OpJoin", function(ply)
    timer.Simple(9, function()
        if not IsValid(ply) then return end
        if (Op.phase == "recruit" or Op.phase == "battle") and not Op.side[ply] then
            net.Start("P11_OpUI")
                net.WriteString("call")
            net.Send(ply)
        end
    end)
end)

hook.Add("PlayerDisconnected", "P11.OpBye", function(ply)
    if Op.side and Op.side[ply] then
        Op.side[ply] = nil -- вознаграждение только онлайн-участникам
        Op.pkills[ply] = nil
    end
end)

-- ============ СЕТЬ: выбор фракции / админ ============

net.Receive("P11_OpPick", function(_, ply)
    if not IsValid(ply) then return end
    ply.P11_OpNext = ply.P11_OpNext or 0
    if CurTime() < ply.P11_OpNext then return end
    ply.P11_OpNext = CurTime() + 0.5

    local msg = string.sub(net.ReadString() or "", 1, 16)

    if msg == "adm_start" or msg == "adm_stop" then
        if not (P11FW.Config and P11FW.Config.Admin and P11FW.Config.Admin(ply)) then return end
        if msg == "adm_start" then POLUS11.OpStart(ply) else POLUS11.OpAbort(ply) end
        return
    end

    if Op.phase ~= "recruit" and Op.phase ~= "battle" then return end
    if Op.side[ply] then
        POLUS11.Notify(ply, "Сторона уже выбрана: «" .. (FACT_NAME[Op.side[ply]] or "?") .. "». За Родину!")
        return
    end
    OpAssign(ply, msg)
    net.Start("P11_OpUI")
        net.WriteString("joined|" .. msg)
    net.Send(ply)
end)

print("[POLUS-11] ОПЕРАЦИИ «РУБЕЖ» v4.24.0: админ-старт, СССР/АМЕРИКА, случайные точки, 30 мин, 5к/1к награды")
