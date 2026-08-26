-- ============================================================
--  ПОЛЮС-11 — ЯДРО СПАВНА «ТОЧКА СБОРА 3.0» (server) v4.8.9
--  «МАЯК» — ПОЧИНКА РЕЦИДИВА «СПАВН НЕ РАБОТАЕТ».
--
--  ЧТО ПОМЕНЯЛОСЬ КОНСТРУКТИВНО:
--   1. Выбор точки вынесен в ПРЯМОЙ GM-ОВЕРРАЙД
--      GM:PlayerSelectSpawn (конец gamemode/init.lua) — движок
--      зовёт функцию гейммода ГАРАНТИРОВАННО, не зависим от того,
--      добегает ли внешний hook.Add до движка в твоей сборке.
--      Здесь — только API якоря/обхода/резолвера.
--   2. Страховка на 0-тик после PlayerSpawn — безусловная:
--      если бойца поставили НЕ на его точку — переносим и пишем
--      в консоль КУДА и ПОЧЕМУ (раньше молча проходило мимо).
--   3. ГРОМКАЯ ДИАГНОСТИКА: при загрузке ядро пишет в консоль,
--      сколько точек видит (общий/фракций/проф). Точек НЕТ —
--      тогда и спавнить некуда: ядро прямо подсказывает команду
--      установки. Каждый спавн пишется: «СПАВН: ник → причина».
--   4. p11_spawntest — немедленно переносит ТЕБЯ на твою точку
--      резолвера: проверка расстановки за 2 секунды.
--
--  Приоритет: АРЕСТ(камера) → точка МОЕЙ ПРОФЫ → зона ФРАКЦИИ →
--   ОБЩИЙ спавн → карта. Данные: P11FW.Points (spawn/jail) +
--   POLUS11.Arrivals/JobArrivals (p11_sv_arrival).
-- ============================================================

POLUS11 = POLUS11 or {}
POLUS11.Arrivals    = POLUS11.Arrivals    or {} -- facId → { pos, ang }
POLUS11.JobArrivals = POLUS11.JobArrivals or {} -- jobId → { pos, ang }

-- ============ РЕЗОЛВЕР: КУДА СПАВНИТЬ ЭТОГО БОЙЦА ============
function POLUS11.SpawnResolve(ply)
    if not IsValid(ply) then return nil end

    -- 0) арест → камера
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

    return nil -- своих точек нет: спавн карты
end

-- ============ СВОБОДНО ЛИ МЕСТО (анти-врезка) ============
function POLUS11.SpawnNudge(ply, pos)
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
    return pos
end

-- ============ ЯКОРЬ-ТОЧКА ДЛЯ ДВИЖКА ============
-- Класс — info_target НАРОЧНО: базовый PlayerSelectSpawn гребёт
-- только info_player_start и родственников; наш якорь он не съест.
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
    if P11FW and P11FW.Log then
        P11FW.Log("СПАВН v4.8.9 «МАЯК»: якорь-точка создан (info_target)")
    end
    return AnchorEnt
end

-- ПЕРЕДВИНУТЬ якорь на нужную точку и вернуть его движку.
-- Эту функцию зовёт ПРЯМОЙ оверрайд GM:PlayerSelectSpawn в init.lua.
function POLUS11.SpawnAnchor(ply, pos, ang)
    local anchor = EnsureAnchor()
    if not IsValid(anchor) then return nil end
    anchor:SetPos(pos)
    anchor:SetAngles(ang or Angle(0, 0, 0))
    return anchor
end

hook.Add("InitPostEntity", "P11.SpawnAnchorInit", function()
    timer.Simple(1.0, EnsureAnchor)
    -- ГРОМКАЯ ДИАГНОСТИКА при загрузке: видно, есть ли ВООБЩЕ точки
    timer.Simple(2.2, function()
        local sp = P11FW.GetPoint and P11FW.GetPoint("spawn")
        local jl = P11FW.GetPoint and P11FW.GetPoint("jail")
        local nf, nj = 0, 0
        for _ in pairs(POLUS11.Arrivals or {}) do nf = nf + 1 end
        for _ in pairs(POLUS11.JobArrivals or {}) do nj = nj + 1 end
        local msg = string.format(
            "СПАВН v4.8.9 «МАЯК»: точек — общий:%s камера:%s фракций:%d проф:%d",
            sp and "ДА" or "НЕТ", jl and "ДА" or "НЕТ", nf, nj)
        if P11FW and P11FW.Log then P11FW.Log(msg) else print("[POLUS-11] " .. msg) end
        if not sp and nf == 0 and nj == 0 then
            local hint = "СПАВН: точек НЕТ на этой карте — поставь ОБЩИЙ: встань где надо → " ..
                "консоль polus_fw_setspawn (или /menu → УТИЛИТЫ → спавн гарнизона); " ..
                "фракции: p11_arrival <facId>; профы: p11_arrival job <jobId>"
            if P11FW and P11FW.Log then P11FW.Log(hint) else print("[POLUS-11] " .. hint) end
        end
    end)
end)
hook.Add("PostCleanupMap", "P11.SpawnAnchorClean", function()
    AnchorEnt = nil
    timer.Simple(1.0, EnsureAnchor)
end)

-- ============ СТРАХОВКА НА 0-ТИК (безусловная, с громким логом) ============
hook.Add("PlayerSpawn", "P11.SpawnCoreBackup", function(ply)
    timer.Simple(0, function()
        if not IsValid(ply) or not ply:Alive() then return end
        local r = POLUS11.SpawnResolve(ply)
        if not r then
            -- v4.8.9: молчание лечим — видно, что точек у бойца нет
            P11FW.Log("СПАВН: " .. ply:Nick() .. " → СПАВН КАРТЫ (своих точек: нет; ставь polus_fw_setspawn / p11_arrival)")
            return
        end
        local pos = POLUS11.SpawnNudge(ply, r.pos)
        if ply:GetPos():DistToSqr(pos) > 4 * 4 then
            ply:SetPos(pos)
            ply:SetEyeAngles(r.ang or ply:EyeAngles())
            if POLUS11.ACMarkTeleport then POLUS11.ACMarkTeleport(ply) end
            P11FW.Log("СПАВН (страховка 0-тик): " .. ply:Nick() .. " → " .. r.why .. " ✓")
        else
            P11FW.Log("СПАВН: " .. ply:Nick() .. " → " .. r.why .. " ✓")
        end
    end)
end)

-- ============ СМЕНА ДОЛЖНОСТИ → НОВАЯ ТОЧКА СЛУЖБЫ ============
hook.Add("P11FW.JobChanged", "P11.SpawnCoreJobTP", function(ply, jobId, oldId)
    if POLUS11.Config and POLUS11.Config.JobTeleportOnChange == false then return end
    if not IsValid(ply) or not ply:Alive() then return end
    if P11FW.IsPunished and P11FW.IsPunished(ply) then return end
    timer.Simple(0.15, function()
        if not IsValid(ply) or not ply:Alive() then return end
        if P11FW.GetJobId(ply) ~= jobId then return end
        if P11FW.IsPunished and P11FW.IsPunished(ply) then return end
        local r = POLUS11.SpawnResolve(ply)
        if not r then return end
        local pos = POLUS11.SpawnNudge(ply, r.pos)
        ply:SetPos(pos)
        ply:SetEyeAngles(r.ang or ply:EyeAngles())
        if POLUS11.ACMarkTeleport then POLUS11.ACMarkTeleport(ply) end
        ply:EmitSound("buttons/button15.wav", 60, 105)
        local job = P11FW.Jobs and P11FW.Jobs[jobId]
        POLUS11.Notify(ply, "📍 Ты прибыл на место службы: " ..
            (job and job.name or tostring(jobId)) .. ".")
        P11FW.Log("СПАВН (смена должности): " .. ply:Nick() .. " → " .. r.why)
    end)
end)

-- ============ КОНСОЛЬ: СЕБЕ ПОКАЗАТЬ, КУДА ЗАСПАВНИШЬСЯ ============
concommand.Add("p11_wherespawn", function(ply)
    if not IsValid(ply) then return end
    local r = POLUS11.SpawnResolve(ply)
    if not r then
        POLUS11.Notify(ply, "🧭 Твоих точек спавна нет — заспавнишься на СПАВНЕ КАРТЫ. " ..
            "Пусть админ поставит: polus_fw_setspawn / p11_arrival <facId> / p11_arrival job <jobId>.")
        return
    end
    POLUS11.Notify(ply, "🧭 Ты заспавнишься: " .. r.why ..
        " (X" .. math.floor(r.pos.x) .. " Y" .. math.floor(r.pos.y) ..
        " Z" .. math.floor(r.pos.z) .. "). Метка-куб на 6 сек.")
    if POLUS11.SpawnMark then
        POLUS11.SpawnMark(r.pos, r.ang, 3, "ТВОЙ СПАВН: " .. r.why, 6)
    end
end)

-- ============ КОНСОЛЬ: ПРОГОН СЕБЯ НА ТОЧКУ (проверка точки за 2 сек) ============
concommand.Add("p11_spawntest", function(ply)
    if not IsValid(ply) then return end
    local r = POLUS11.SpawnResolve(ply)
    if not r then
        POLUS11.Notify(ply, "Твоих точек спавна НЕТ — нечего проверять (ставь polus_fw_setspawn / p11_arrival).")
        return
    end
    local pos = POLUS11.SpawnNudge(ply, r.pos)
    ply:SetPos(pos)
    ply:SetEyeAngles(r.ang or ply:EyeAngles())
    if POLUS11.ACMarkTeleport then POLUS11.ACMarkTeleport(ply) end
    POLUS11.Notify(ply, "🧪 ТЕСТ: ты на своей точке спавна — " .. r.why .. ".")
    P11FW.Log("СПАВН-ТЕСТ: " .. ply:Nick() .. " перенесён на " .. r.why)
end)

-- ============ КОНСОЛЬ: ПОЛНАЯ ДИАГНОСТИКА (админ) ============
function POLUS11.SpawnCoreDiag(ply)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then return end
    local out = { "== ЯДРО СПАВНА «ТОЧКА СБОРА 3.0» (v4.8.9 «МАЯК») ==" }
    out[#out + 1] = "  путь: ПРЯМОЙ GM:PlayerSelectSpawn (init.lua) + страховка 0-тик + телепорт при смене должности"
    out[#out + 1] = "  якорь: " .. (IsValid(AnchorEnt) and "ЖИВ (" .. tostring(AnchorEnt) .. ")" or "НЕТ — создастся при первом спавне")
    out[#out + 1] = "  телепорт при смене должности: "
        .. ((POLUS11.Config and POLUS11.Config.JobTeleportOnChange ~= false) and "ВКЛ" or "ВЫКЛ")
    local sp = P11FW.GetPoint and P11FW.GetPoint("spawn")
    local jl = P11FW.GetPoint and P11FW.GetPoint("jail")
    out[#out + 1] = "  общий спавн: " .. (sp and "ЕСТЬ" or "НЕТ!! (polus_fw_setspawn)")
        .. " | камера ареста: " .. (jl and "ЕСТЬ" or "нет")
    local nf, nj = 0, 0
    for _ in pairs(POLUS11.Arrivals or {}) do nf = nf + 1 end
    for _ in pairs(POLUS11.JobArrivals or {}) do nj = nj + 1 end
    out[#out + 1] = "  зон фракций: " .. nf .. " | точек проф: " .. nj
    if (not sp) and nf == 0 and nj == 0 then
        out[#out + 1] = "  ⚠ ТОЧЕК НЕТ ВООБЩЕ — все спавнятся на спавне КАРТЫ. Поставь polus_fw_setspawn!"
    end
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

print("[POLUS-11] ЯДРО СПАВНА «ТОЧКА СБОРА 3.0» v4.8.9 «МАЯК»: прямой GM-путь + безусловная страховка с ЛОГОМ каждого спавна + p11_spawntest; точек нет — ядро само скажет команду расстановки")
