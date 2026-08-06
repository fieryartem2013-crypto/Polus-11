-- ============================================================
--  ПОЛЮС-11 — СМЕННЫЕ ДЕЛА v4.1 (server)
--  Миниигра-протокол «нажми клавишу вовремя» + дела должностей:
--   • УЧЁНЫЕ  — калибровка лабораторного стола, ОЧКИ НАУКИ (RP),
--               грант ЦНИИ 250₽ за каждые 5 RP.
--   • ТЕХНИК  — ТО генератора миниигрой (износ -50, снятие аварии).
--   • УБОРЩИК — пятна грязи по станции (спавнятся сами).
--   • РККА    — ПАТРУЛЬ: обход постов (E + 3 сек), цикл = премия.
-- ============================================================

util.AddNetworkString("P11_MiniOpen")
util.AddNetworkString("P11_MiniStep")
util.AddNetworkString("P11_MiniHit")
util.AddNetworkString("P11_MiniEnd")
util.AddNetworkString("P11_PatrolSync")

local KEYS = { "R", "F", "T", "G" }

-- ============ ДВИЖОК МИНИИГРЫ ============
-- Сессия: { ent, steps, step, letter, sentAt, window, cb, startPos }

POLUS11.MiniSessions = POLUS11.MiniSessions or {}

local function MiniSendStep(ply)
    local s = POLUS11.MiniSessions[ply]
    if not s then return end
    s.letter = KEYS[math.random(#KEYS)]
    s.sentAt = CurTime()
    net.Start("P11_MiniStep")
        net.WriteUInt(s.step, 4)
        net.WriteString(s.letter)
        net.WriteFloat(s.window)
    net.Send(ply)
end

-- cb(ply, ent, ok, hits)
function POLUS11.MiniStart(ply, ent, opts)
    if not IsValid(ply) or not ply:Alive() then return false end
    if POLUS11.MiniSessions[ply] then return false end -- уже играет

    local s = {
        ent = ent,
        steps = opts.steps or 3,
        step = 0,
        window = opts.window or 2.0,
        cb = opts.cb,
        hits = 0,
        startPos = ply:GetPos(),
        endsAt = CurTime() + (opts.steps or 3) * (opts.window or 2.0) + 3,
    }
    POLUS11.MiniSessions[ply] = s

    net.Start("P11_MiniOpen")
        net.WriteString(opts.title or "ПРОВЕРКА")
        net.WriteUInt(s.steps, 4)
    net.Send(ply)

    s.step = 1
    MiniSendStep(ply)
    return true
end

local function MiniFinish(ply, ok, silent)
    local s = POLUS11.MiniSessions[ply]
    POLUS11.MiniSessions[ply] = nil
    net.Start("P11_MiniEnd")
        net.WriteBool(ok)
    net.Send(ply)
    if s and s.cb and not silent then
        pcall(s.cb, ply, s.ent, ok, s.hits)
    end
end

net.Receive("P11_MiniHit", function(len, ply)
    local s = POLUS11.MiniSessions[ply]
    if not s then return end

    local step = net.ReadUInt(4)
    local letter = string.sub(net.ReadString() or "", 1, 2)
    if step ~= s.step then return end -- старый пакет

    -- анти-макрос: только валидный отклик в окне ответа (с лаговой скидкой)
    local dt = CurTime() - (s.sentAt or 0)
    if letter == s.letter and dt > 0.12 and dt < s.window + 0.6 then
        s.hits = s.hits + 1
    end

    if s.step >= s.steps then
        MiniFinish(ply, s.hits >= s.steps)
        return
    end
    s.step = s.step + 1
    MiniSendStep(ply)
end)

-- контроль: сдвинулся/умер/таймаут — игра сгорает
timer.Create("P11.MiniGuard", 0.5, 0, function()
    for ply, s in pairs(POLUS11.MiniSessions or {}) do
        local bad = (not IsValid(ply)) or (not ply:Alive())
            or ply:GetPos():DistToSqr(s.startPos) > 45 * 45
            or CurTime() > (s.endsAt or 0)
            or (IsValid(s.ent) and ply:GetPos():DistToSqr(s.ent:GetPos()) > 260 * 260)
        if bad then MiniFinish(ply, false) end
    end
end)

-- ============ ОЧКИ НАУКИ (RP) ============

function POLUS11.AddRP(ply, n, why)
    if not IsValid(ply) then return end
    local rp = (ply:GetNWInt("P11_RP", 0) or 0) + n
    ply:SetNWInt("P11_RP", rp)
    POLUS11.Notify(ply, "+" .. n .. " к очкам науки (" .. (why or "исследование") .. "). Всего: " .. rp .. " RP.")

    -- грант ЦНИИ: каждые 5 RP → 250₽
    if rp > 0 and rp % 5 == 0 and POLUS11.AddMoney then
        local grant = (POLUS11.Config and POLUS11.Config.ScienceGrant) or 250
        POLUS11.AddMoney(ply, grant, "грант ЦНИИ за исследования")
        PrintMessage(HUD_PRINTTALK, "[ЦНИИ] " .. ply:Nick() .. " получил грант за исследования (" .. rp .. " RP).")
    end
end

-- обёртка событий: научная рутина кормит RP
do
    local baseTaskEvent = POLUS11.TaskEvent
    local RP_FOR = { blood_draw = 1, blood_test = 2, autopsy = 3, calibrate = 1 }
    POLUS11.TaskEvent = function(ply, key, add)
        baseTaskEvent(ply, key, add)
        local rp = RP_FOR[key]
        if rp and POLUS11.IsScientist and POLUS11.IsScientist(ply) then
            POLUS11.AddRP(ply, rp, key == "calibrate" and "калибровка" or "лабораторная работа")
        end
    end
end

-- ============ УЧЁНЫЕ: КАЛИБРОВКА СТОЛА ============

function POLUS11.StartCalibration(tableEnt, ply)
    if not IsValid(tableEnt) or not IsValid(ply) then return false end
    if not (POLUS11.IsScientist and POLUS11.IsScientist(ply)) then return false end
    if (tableEnt.P11_CalNext or 0) > CurTime() then
        POLUS11.Notify(ply, "Анализатор уже откалиброван. Следующая калибровка через " ..
            math.ceil(tableEnt.P11_CalNext - CurTime()) .. " сек.")
        return true
    end

    tableEnt:EmitSound("ambient/energy/zap1.wav", 60, 120)
    POLUS11.Notify(ply, "КАЛИБРОВКА АНАЛИЗАТОРА: жми подсвеченные клавиши [R/F/T/G]!")

    return POLUS11.MiniStart(ply, tableEnt, {
        steps = 4, window = 2.2, title = "КАЛИБРОВКА АНАЛИЗАТОРА",
        cb = function(p, ent, ok)
            if not IsValid(ent) then return end
            ent.P11_CalNext = CurTime() + 60
            if ok then
                ent:EmitSound("buttons/button9.wav", 60, 120)
                POLUS11.Notify(p, "Калибровка завершена! Погрешность 0.00%.")
                if POLUS11.TaskEvent then POLUS11.TaskEvent(p, "calibrate") end
                if POLUS11.AddMoney then
                    POLUS11.AddMoney(p, (POLUS11.Config and POLUS11.Config.CalibratePay) or 60, "калибровка анализатора")
                end
            else
                ent:EmitSound("buttons/button10.wav", 60, 90)
                POLUS11.Notify(p, "Калибровка сорвалась — спектрометр дал разброс.")
            end
        end,
    })
end

-- ============ ТЕХНИК: ТО ГЕНЕРАТОРА МИНИИГРОЙ ============

local function IsTechJob(ply)
    if POLUS11.IsEngineer and POLUS11.IsEngineer(ply) then return true end
    if P11FW and P11FW.GetJobId then
        local id = P11FW.GetJobId(ply)
        if id == "tech" then return true end
    end
    return false
end

-- вызывается из Use генератора ПЕРЕД обычным «держи E» сервисом
function POLUS11.TryServiceMinigame(gen, ply)
    if not IsValid(gen) or not IsValid(ply) then return false end
    if not IsTechJob(ply) then return false end
    if gen:GetDamaged() then return false end -- авария — старым способом, длинным ремонтом
    local fault = gen:GetFault()
    local wear = gen:GetWear()
    if fault == "" and wear < 35 then return false end -- нечего обслуживать
    if (gen.P11_TONext or 0) > CurTime() then return false end -- только что обслуживали

    if POLUS11.MiniSessions[ply] then return true end
    gen.P11_TONext = CurTime() + 20

    POLUS11.Notify(ply, "ТЕХОСМОТР: пройди стендовые проверки [R/F/T/G]!")
    POLUS11.MiniStart(ply, gen, {
        steps = 4, window = 2.0, title = "ТЕХОСМОТР ГЕНЕРАТОРА",
        cb = function(p, ent, ok)
            if not IsValid(ent) then return end
            if ok then
                local hadFault = ent:GetFault() ~= ""
                ent:SetFault("")
                ent:SetWear(math.max(0, ent:GetWear() - 50))
                ent:EmitSound("buttons/button9.wav", 65, 110)
                POLUS11.Notify(p, hadFault and "Поломка устранена! Износ снижен."
                    or "ТО завершено: нагар снят, контакты протянуты.")
                if POLUS11.TaskEvent then POLUS11.TaskEvent(p, "gen_service") end
                if POLUS11.AddMoney then
                    POLUS11.AddMoney(p, (POLUS11.Config and POLUS11.Config.GenServicePay) or 100, "ТО генератора")
                end
                POLUS11.Log(p:Nick() .. " провёл ТО генератора миниигрой")
            else
                ent:EmitSound("ambient/energy/spark2.wav", 65, 80)
                POLUS11.Notify(p, "ТО сорван: щиток дал искру. Генератор не пострадал.")
            end
        end,
    })
    return true
end

-- ============ УБОРЩИК: ГРЯЗЬ ============

local DIRT_MAX = 6

local function IsJanitor(ply)
    if P11FW and P11FW.GetJobId then
        return P11FW.GetJobId(ply) == "janitor"
    end
    return false
end

function POLUS11.DirtUse(ent, ply)
    if not IsValid(ent) or not IsValid(ply) then return end
    if ply:GetPos():DistToSqr(ent:GetPos()) > 140 * 140 then return end
    if not IsJanitor(ply) then
        POLUS11.Notify(ply, "Грязь убирает УБОРЩИК — позовите персонал.")
        return
    end
    if POLUS11.MiniSessions[ply] then return end

    POLUS11.MiniStart(ply, ent, {
        steps = 2, window = 2.6, title = "УБОРКА",
        cb = function(p, ent2, ok)
            if not IsValid(ent2) then return end
            if ok then
                ent2:EmitSound("ambient/levels/canals/toxic_slime_gurgle1.wav", 55, 130)
                ent2:Remove()
                if POLUS11.TaskEvent then POLUS11.TaskEvent(p, "clean") end
                if POLUS11.AddMoney then
                    POLUS11.AddMoney(p, (POLUS11.Config and POLUS11.Config.CleanPay) or 35, "уборка станции")
                end
                POLUS11.Notify(p, "Прибрано. Станция чище.")
            else
                POLUS11.Notify(p, "Размазал по полу. Попробуй аккуратнее.")
            end
        end,
    })
end

-- спавнер грязи: якоримся к жилым точкам станции
timer.Create("P11.DirtSpawn", 55, 0, function()
    local dirt = ents.FindByClass("polus_p11_dirt")
    if #dirt >= DIRT_MAX then return end

    local anchors = {}
    for _, cls in ipairs({ "polus_fw_jobnpc", "polus11_terminal", "polus11_generator", "polus_p11_shopnpc" }) do
        for _, e in ipairs(ents.FindByClass(cls)) do
            if IsValid(e) then anchors[#anchors + 1] = e:GetPos() end
        end
    end
    for _, ply in ipairs(player.GetAll()) do
        if ply:Alive() then anchors[#anchors + 1] = ply:GetPos() end
    end
    if #anchors == 0 then return end

    local base = anchors[math.random(#anchors)]
    local off = Vector(math.random(-900, 900), math.random(-900, 900), 0)
    local start = base + off + Vector(0, 0, 60)
    local tr = util.TraceLine({
        start = start,
        endpos = start - Vector(0, 0, 400),
        filter = function(e) return e:IsPlayer() end,
    })
    if not tr.Hit or tr.HitSky then return end
    if tr.HitPos:DistToSqr(base) > 1400 * 1400 then return end
    -- не сыпать туда, где уже грязно
    for _, d in ipairs(dirt) do
        if IsValid(d) and d:GetPos():DistToSqr(tr.HitPos) < 200 * 200 then return end
    end

    local e = ents.Create("polus_p11_dirt")
    if not IsValid(e) then return end
    e:SetPos(tr.HitPos + Vector(0, 0, 2))
    e:SetAngles(Angle(0, math.random(0, 359), 0))
    e:Spawn()
    e:Activate()
end)

-- ============ РККА: ПАТРУЛЬ ============

local function PatrolEligible(ply)
    if not (P11FW and P11FW.GetJobId) then return false end
    local job = P11FW.GetJob and P11FW.GetJob(ply)
    local fac = (job and (job.faction or job.category)) or ""
    local cfg = (POLUS11.Config and POLUS11.Config.PatrolFactions) or { rkka = true }
    return cfg[fac] == true
end

local function PatrolPoints()
    local pts = {}
    for _, e in ipairs(ents.FindByClass("polus_p11_patrol")) do
        if IsValid(e) then pts[#pts + 1] = e end
    end
    table.sort(pts, function(a, b) return a:EntIndex() < b:EntIndex() end)
    return pts
end

local function PatrolSyncAll(ply)
    -- клиенту: список постов + его следующая точка
    local pts, rows = PatrolPoints(), {}
    for i, e in ipairs(pts) do
        if not e:GetPatrolId() or e:GetPatrolId() == 0 then e:SetPatrolId(i) end
        rows[#rows + 1] = { id = e:EntIndex(), n = e:GetPatrolId(), x = e:GetPos().x, y = e:GetPos().y, z = e:GetPos().z }
    end
    local nextId = 0
    if IsValid(ply) and ply.P11_PatrolVisited then
        for _, e in ipairs(pts) do
            if not ply.P11_PatrolVisited[e:EntIndex()] then nextId = e:EntIndex() break end
        end
    end
    net.Start("P11_PatrolSync")
        net.WriteString(util.TableToJSON({ pts = rows, next = nextId }))
    if IsValid(ply) then net.Send(ply) else net.Broadcast() end
end
POLUS11.PatrolSyncAll = PatrolSyncAll

function POLUS11.PatrolUse(ent, ply)
    if not IsValid(ent) or not IsValid(ply) then return end
    if ply:GetPos():DistToSqr(ent:GetPos()) > 140 * 140 then return end
    if (ply.P11_PatrolBusyUntil or 0) > CurTime() then return end

    if not PatrolEligible(ply) then
        POLUS11.Notify(ply, "Посты обходят бойцы РККА. Это не твоя служба.")
        return
    end
    if #PatrolPoints() < 2 then
        POLUS11.Notify(ply, "Маршрут не размечен: администрация ставит посты (УТИЛИТЫ → Расстановка).")
        return
    end
    if ply.P11_PatrolVisited and ply.P11_PatrolVisited[ent:EntIndex()] then
        POLUS11.Notify(ply, "Этот пост уже проверен. Иди на следующий.")
        return
    end

    -- 3 секунды досмотра поста (держать E рядом)
    ply.P11_PatrolBusyUntil = CurTime() + 3.5
    ply.P11_PatrolHold = { ent = ent, pos = ply:GetPos(), endsAt = CurTime() + 3 }
    ply:EmitSound("items/ammo_pickup.wav", 55, 120)
    POLUS11.Notify(ply, "Осматриваешь пост… стой на месте (3 сек).")
end

timer.Create("P11.PatrolHold", 0.25, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        local h = ply.P11_PatrolHold
        if h then
            local ent = h.ent
            local broken = (not IsValid(ent)) or (not ply:Alive())
                or ply:GetPos():DistToSqr(h.pos) > 30 * 30
                or ply:GetPos():DistToSqr(ent:GetPos()) > 150 * 150
                or not ply:KeyDown(IN_USE)
            if broken then
                ply.P11_PatrolHold = nil
                if IsValid(ply) then POLUS11.Notify(ply, "Досмотр поста прерван.") end
            elseif CurTime() >= h.endsAt then
                ply.P11_PatrolHold = nil
                ply.P11_PatrolVisited = ply.P11_PatrolVisited or {}
                ply.P11_PatrolVisited[ent:EntIndex()] = true

                ent:EmitSound("buttons/button9.wav", 60, 115)
                if POLUS11.TaskEvent then POLUS11.TaskEvent(ply, "patrol_point") end
                if POLUS11.AddMoney then
                    POLUS11.AddMoney(ply, (POLUS11.Config and POLUS11.Config.PatrolPointPay) or 25, "обход поста")
                end

                -- цикл завершён?
                local done = true
                for _, e in ipairs(PatrolPoints()) do
                    if not ply.P11_PatrolVisited[e:EntIndex()] then done = false break end
                end
                if done then
                    ply.P11_PatrolVisited = nil
                    local bonus = (POLUS11.Config and POLUS11.Config.PatrolCyclePay) or 150
                    if POLUS11.AddMoney then POLUS11.AddMoney(ply, bonus, "полный обход патруля") end
                    if POLUS11.TaskEvent then POLUS11.TaskEvent(ply, "patrol_done") end
                    PrintMessage(HUD_PRINTTALK, "[ГАРНИЗОН] " .. ply:Nick() .. " завершил полный обход патруля.")
                    POLUS11.Log("ПАТРУЛЬ: полный обход — " .. ply:Nick())
                else
                    POLUS11.Notify(ply, "Пост проверен. Ищи следующий маркер.")
                end
                PatrolSyncAll(ply)
            end
        end
    end
end)

hook.Add("PlayerInitialSpawn", "P11.PatrolJoin", function(ply)
    timer.Simple(8, function()
        if IsValid(ply) then PatrolSyncAll(ply) end
    end)
end)

hook.Add("P11FW.JobChanged", "P11.PatrolJob", function(ply)
    ply.P11_PatrolVisited = nil
    ply.P11_PatrolHold = nil
    timer.Simple(1, function()
        if IsValid(ply) then PatrolSyncAll(ply) end
    end)
end)

print("[POLUS-11] сменные дела v4.1 загружены (наука/ТО/грязь/патруль)")
