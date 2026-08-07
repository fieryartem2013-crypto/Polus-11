-- ============================================================
--  ПОЛЮС-11 — ЯДРО СПАВНА «ТОЧКА СБОРА 2.0» (server) v4.8.7
--  СПАВН ПЕРЕПИСАН С ЧИСТОГО ЛИСТА (заявка владельца: «спавны
--  не работают вообще — удали и сделай заново»).
--
--  ЧТО БЫЛО СЛОМАНО В СТАРОМ ДИЗАЙНЕ:
--   ● три гоняющихся таймера (0.05 / 0.09 / 0.4 сек после
--     PlayerSpawn) — чей таймер заикнётся, того и точка;
--   ● движок СНАЧАЛА ставил бойца на спавн карты, а таймер
--     перетаскивал следом → дёрганье, телепорт «в никуда»,
--     при лаге — оставался на карте навсегда;
--   ● две системы (общий спавн из fw_sv_setup и прибытия из
--     p11_sv_arrival) дрались друг с другом.
--
--  КАК РАБОТАЕТ ТЕПЕРЬ (один канонический путь):
--   1. GM-хук PlayerSelectSpawn — движок спрашивает у нас
--      СУЩНОСТЬ-ТОЧКУ и ставит бойца ровно в неё ДО первого
--      кадра. Никаких таймеров-гонок. Точку отдаём через
--      невидимый якорь (info_player_start), который перед
--      отдачей мгновенно переносится в нужное место.
--   2. Страховка на 0-тик: если какой-то чужой аддон всё же
--      перебил PlayerSelectSpawn позже нас — переносим сами
--      до того, как клиент отрендерит кадр.
--   3. Смена должности → немедленный перенос на новую службу
--      (JobTeleportOnChange в p11_sh_config).
--
--  ВАЖНО про якорь: класс info_target, чтобы базовый
--  PlayerSelectSpawn его не глотнул как «спавн карты» (он видит
--  только info_player_start и родственные классы).
--
--  ПРИОРИТЕТ ТОЧКИ:  АРЕСТ (камера) → точка МОЕЙ ПРОФЫ →
--   зона МОЕЙ ФРАКЦИИ → ОБЩИЙ спавн гарнизона → спавн карты
--   (когда своих точек нет вовсе — ведёт себя как обычно).
--
--  Данные не ломаем: те же сохранённые точки, что раньше —
--  P11FW.Points (spawn/jail) + POLUS11.Arrivals (фракции) +
--  POLUS11.JobArrivals (профы) из p11_sv_arrival.lua.
--  Ставить точки: /menu → УТИЛИТЫ, p11_arrival, polus_fw_setspawn.
--  Диагностика: p11_spawndiag (сервер), p11_wherespawn (себя).
-- ============================================================

-- таблицы точек объявляем зеркально (p11_sv_arrival тоже их
-- объявляет — кто грузится первым, тот и создаст; данные одни)
POLUS11 = POLUS11 or {}
POLUS11.Arrivals    = POLUS11.Arrivals    or {} -- facId → { pos, ang }
POLUS11.JobArrivals = POLUS11.JobArrivals or {} -- jobId → { pos, ang }

-- ============ РЕЗОЛВЕР: КУДА СПАВНИТЬ ЭТОГО БОЙЦА ============
-- Возвращает { pos=Vector, ang=Angle, why=строка } или nil
-- (nil = своих точек нет — пусть работает спавн карты).
function POLUS11.SpawnResolve(ply)
    if not IsValid(ply) then return nil end

    -- 0) АРЕСТ: посаженного — сразу в камеру (пенальти-поток
    --    fw_sv_punish её же и применяет; тут — чтобы движок сразу
    --    поставил в камеру, без «кадра на свободе»)
    local pun = P11FW.IsPunished and P11FW.IsPunished(ply)
    if pun == "arrest" then
        local jl = P11FW.GetPoint and P11FW.GetPoint("jail")
        if jl then
            return { pos = jl.pos + Vector(0, 0, 2), ang = jl.ang, why = "КАМЕРА АРЕСТА" }
        end
    end

    -- 1) точка МОЕЙ должности
    local jobId = P11FW.GetJobId and P11FW.GetJobId(ply)
    if jobId then
        local a = (POLUS11.JobArrivals or {})[jobId]
        if a then
            local job = P11FW.Jobs and P11FW.Jobs[jobId]
            return { pos = a.pos, ang = a.ang,
                why = "СПАВН ПРОФЫ «" .. (job and job.name or jobId) .. "»" }
        end
    end

    -- 2) зона МОЕЙ фракции
    local job = P11FW.GetJob and P11FW.GetJob(ply)
    local fac = job and (job.faction or job.category)
    if fac then
        local a = (POLUS11.Arrivals or {})[fac]
        if a then
            local nm = fac
            for _, c in ipairs(P11FW.CategoryList or {}) do
                if c.id == fac then nm = c.name or fac break end
            end
            return { pos = a.pos, ang = a.ang, why = "ЗОНА ФРАКЦИИ «" .. tostring(nm) .. "»" }
        end
    end

    -- 3) ОБЩИЙ спавн гарнизона
    local sp = P11FW.GetPoint and P11FW.GetPoint("spawn")
    if sp then
        return { pos = sp.pos, ang = sp.ang, why = "ОБЩИЙ СПАВН ГАРНИЗОНА" }
    end

    return nil -- своих точек нет: движок отведёт на спавн карты
end

-- ============ СВОБОДНО ЛИ МЕСТО (анти-врезка) ============
local function NudgePoint(ply, pos)
    local mins, maxs = ply:GetHull()

    local function WorldFree(p)
        local tr = util.TraceHull({
            start = p, endpos = p, mins = mins, maxs = maxs,
            filter = ply, mask = MASK_PLAYERSOLID,
        })
        return not tr.Hit
    end
    local function NoBodyThere(p)
        for _, o in ipairs(player.GetAll()) do
            if o ~= ply and o:Alive() and o:GetPos():DistToSqr(p) < 44 * 44 then
                return false
            end
        end
        return true
    end
    local function Free(p) return WorldFree(p) and NoBodyThere(p) end

    if Free(pos) then return pos end

    -- точка занята: кольцо обхода + подъём, максимум ~14 проб
    local ring = {
        Vector(36, 0, 2), Vector(-36, 0, 2),
        Vector(0, 36, 2), Vector(0, -36, 2),
        Vector(36, 36, 2), Vector(-36, -36, 2),
        Vector(36, -36, 2), Vector(-36, 36, 2),
    }
    for _, off in ipairs(ring) do
        if Free(pos + off) then return pos + off end
    end
    for dz = 8, 64, 8 do
        local p2 = pos + Vector(0, 0, dz)
        if WorldFree(p2) then return p2 end
    end
    return pos -- совсем тесно: отдать как есть (лучше точка, чем карта)
end

-- ============ НЕВИДИМЫЙ ЯКОРЬ-ТОЧКА ДЛЯ ДВИЖКА ============
-- Класс — info_target НАРОЧНО: базовый GM:PlayerSelectSpawn гребёт
-- только info_player_start/gmod_player_start/info_player_combine/
-- info_player_rebel. info_target в его сетях НЕ числится — якорь
-- никогда не попадётся «случайным» спавном игрокам без своих точек.
local AnchorEnt = nil

local function EnsureAnchor()
    if IsValid(AnchorEnt) then return AnchorEnt end
    for _, e in ipairs(ents.FindByClass("info_target")) do
        if e.P11_SpawnAnchor then AnchorEnt = e return AnchorEnt end
    end
    local e = ents.Create("info_target")
    if not IsValid(e) then return nil end
    e:SetPos(Vector(0, 0, -16000))
    e:SetAngles(Angle(0, 0, 0))
    e.P11_SpawnAnchor = true
    e:Spawn()
    AnchorEnt = e
    if P11FW and P11FW.Log then P11FW.Log("СПАВН: якорь-точка создан (info_target, PlayerSelectSpawn работает)") end
    return AnchorEnt
end

hook.Add("InitPostEntity", "P11.SpawnAnchorInit", function()
    timer.Simple(1.0, EnsureAnchor)
end)
hook.Add("PostCleanupMap", "P11.SpawnAnchorClean", function()
    AnchorEnt = nil
    timer.Simple(1.0, EnsureAnchor)
end)

-- ============ 1) КАНОНИЧЕСКИЙ ПУТЬ: PlayerSelectSpawn ============
-- GM-хук: движок спрашивает сущность-точку ПЕРЕД спавном и ставит
-- бойца ровно в неё (позиция+угол) — до первого кадра, без рывков.
hook.Add("PlayerSelectSpawn", "P11.SpawnCore", function(ply, transition)
    if transition then return end -- переход между картами — не наше дело

    local r = POLUS11.SpawnResolve(ply)
    if not r then return end -- своих точек нет → поведение как в базе

    local anchor = EnsureAnchor()
    if not IsValid(anchor) then return end

    local pos = NudgePoint(ply, r.pos)
    anchor:SetPos(pos)
    anchor:SetAngles(r.ang or Angle(0, 0, 0))

    if P11FW and P11FW.Log then
        P11FW.Log("СПАВН: " .. ply:Nick() .. " → " .. r.why)
    end
    return anchor
end)

-- ============ 2) СТРАХОВКА НА 0-ТИК ============
-- Если чужой аддон всё-таки вернул свою сущность позже нас —
-- переносим бойца на его точку до кадра отрисовки.
hook.Add("PlayerSpawn", "P11.SpawnCoreBackup", function(ply)
    timer.Simple(0, function()
        if not IsValid(ply) or not ply:Alive() then return end
        local r = POLUS11.SpawnResolve(ply)
        if not r then return end
        local pos = NudgePoint(ply, r.pos)
        -- переносим только если движок НЕ поставил куда надо (уже там — не дёргаем)
        if ply:GetPos():DistToSqr(pos) > 4 * 4 then
            ply:SetPos(pos)
            ply:SetEyeAngles(r.ang or ply:EyeAngles())
            if POLUS11.ACMarkTeleport then POLUS11.ACMarkTeleport(ply) end
            if P11FW and P11FW.Log then
                P11FW.Log("СПАВН (страховка 0-тик): " .. ply:Nick() .. " → " .. r.why)
            end
        end
    end)
end)

-- ============ 3) СМЕНА ДОЛЖНОСТИ → НОВАЯ ТОЧКА СЛУЖБЫ ============
hook.Add("P11FW.JobChanged", "P11.SpawnCoreJobTP", function(ply, jobId, oldId)
    if POLUS11.Config and POLUS11.Config.JobTeleportOnChange == false then return end
    if not IsValid(ply) or not ply:Alive() then return end
    if P11FW.IsPunished and P11FW.IsPunished(ply) then return end -- наказанных ведёт пенальти
    timer.Simple(0.15, function()
        if not IsValid(ply) or not ply:Alive() then return end
        if P11FW.GetJobId(ply) ~= jobId then return end -- успел сменить ещё раз
        if P11FW.IsPunished and P11FW.IsPunished(ply) then return end
        local r = POLUS11.SpawnResolve(ply)
        if not r then return end -- точек для профы нет и общего нет — остаётся где стоит
        local pos = NudgePoint(ply, r.pos)
        ply:SetPos(pos)
        ply:SetEyeAngles(r.ang or ply:EyeAngles())
        if POLUS11.ACMarkTeleport then POLUS11.ACMarkTeleport(ply) end
        ply:EmitSound("buttons/button15.wav", 60, 105)
        local job = P11FW.Jobs and P11FW.Jobs[jobId]
        POLUS11.Notify(ply, "📍 Ты прибыл на место службы: " ..
            (job and job.name or tostring(jobId)) .. ".")
        if P11FW and P11FW.Log then
            P11FW.Log("СПАВН (смена должности): " .. ply:Nick() .. " → " .. r.why)
        end
    end)
end)

-- ============ КОНСОЛЬ: СЕБЕ ПОКАЗАТЬ, КУДА ЗАСПАВНИШЬСЯ ============
concommand.Add("p11_wherespawn", function(ply)
    if not IsValid(ply) then return end
    local r = POLUS11.SpawnResolve(ply)
    if not r then
        POLUS11.Notify(ply, "🧭 Твоих точек спавна нет — заспавнишься на СПАВНЕ КАРТЫ. " ..
            "Пусть админ поставит: /menu → УТИЛИТЫ → спавн гарнизона / зону фракции / точку профы.")
        return
    end
    POLUS11.Notify(ply, "🧭 Ты заспавнишься: " .. r.why ..
        " (X" .. math.floor(r.pos.x) .. " Y" .. math.floor(r.pos.y) ..
        " Z" .. math.floor(r.pos.z) .. "). Метка-куб на 6 сек.")
    if POLUS11.SpawnMark then
        POLUS11.SpawnMark(r.pos, r.ang, 3, "ТВОЙ СПАВН: " .. r.why, 6)
    end
end)

-- ============ КОНСОЛЬ: ПОЛНАЯ ДИАГНОСТИКА (админ) ============
function POLUS11.SpawnCoreDiag(ply)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then return end
    local out = { "== ЯДРО СПАВНА «ТОЧКА СБОРА 2.0» (v4.8.7) ==" }
    out[#out + 1] = "  путь: GM:PlayerSelectSpawn (точка ДО первого кадра) + страховка 0-тик + телепорт при смене должности"
    out[#out + 1] = "  якорь: " .. (IsValid(AnchorEnt) and "ЖИВ (" .. tostring(AnchorEnt) .. ")" or "НЕТ — создастся при первом спавне")
    out[#out + 1] = "  телепорт при смене должности: "
        .. ((POLUS11.Config and POLUS11.Config.JobTeleportOnChange ~= false) and "ВКЛ" or "ВЫКЛ")
    local sp = P11FW.GetPoint and P11FW.GetPoint("spawn")
    local jl = P11FW.GetPoint and P11FW.GetPoint("jail")
    out[#out + 1] = "  общий спавн: " .. (sp and "ЕСТЬ" or "нет") .. " | камера ареста: " .. (jl and "ЕСТЬ" or "нет")
    local nf, nj = 0, 0
    for _ in pairs(POLUS11.Arrivals or {}) do nf = nf + 1 end
    for _ in pairs(POLUS11.JobArrivals or {}) do nj = nj + 1 end
    out[#out + 1] = "  зон фракций: " .. nf .. " | точек проф: " .. nj
    out[#out + 1] = "  -- куда заспавнится каждый:"
    for _, p in ipairs(player.GetAll()) do
        local r = POLUS11.SpawnResolve(p)
        out[#out + 1] = "     " .. string.format("%-22s → %s", p:Nick(),
            r and r.why or "спавн карты (своих точек нет)")
    end
    local txt = table.concat(out, "\n")
    if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, txt) else print(txt) end
end

concommand.Add("p11_spawncore", function(ply)
    POLUS11.SpawnCoreDiag(ply)
end)

print("[POLUS-11] ЯДРО СПАВНА «ТОЧКА СБОРА 2.0» v4.8.7: точка ДО первого кадра (PlayerSelectSpawn) — гонка таймеров упразднена | приоритет: арест → профа → фракция → общий → карта | p11_spawncore / p11_wherespawn")
