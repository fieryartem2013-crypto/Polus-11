-- ============================================================
--  ПОЛЮС FRAMEWORK — выдача должностей (сервер)
-- ============================================================

util.AddNetworkString("P11FW_TakeJob")
util.AddNetworkString("P11FW_OpenMenu")

-- ============ СНАРЯЖЕНИЕ / МОДЕЛЬ ============

function P11FW.ApplyLoadout(ply, modelIdx, fullHeal)
    local job = P11FW.GetJob(ply)
    if not job then return end

    -- снаряжение
    if P11FW.Config.StripOnJobChange then
        ply:StripWeapons()
        ply:StripAmmo()
    end

    for _, class in ipairs(P11FW.Config.BaseLoadout or {}) do
        if weapons.Get(class) then ply:Give(class) end
    end

    -- админам — инструменты настройки карты
    if P11FW.Config.AdminLoadout and P11FW.Config.Admin(ply) then
        for _, class in ipairs(P11FW.Config.AdminLoadout) do
            if weapons.Get(class) then ply:Give(class) end
        end
    end

    for _, class in ipairs(P11FW.ValidWeapons(job)) do
        ply:Give(class)
        -- v4.8.0: стоковым фолбэкам (HL2) — боезапас; EFT-стволы сами разберутся
        local am = POLUS11 and POLUS11.WepAmmoHL2 and POLUS11.WepAmmoHL2[class]
        if am then ply:GiveAmmo(am[2] or 30, am[1], true) end
    end

    -- v3.8.2: РУКИ выдаются всем (ношение ящиков/бочек, обыск и т.д.)
    if weapons.Get("weapon_polus11_hands") and not ply:HasWeapon("weapon_polus11_hands") then
        ply:Give("weapon_polus11_hands")
    end

    for _, a in ipairs(job.ammo or {}) do
        if isstring(a[1]) and isnumber(a[2]) then
            ply:GiveAmmo(a[2], a[1], true)
        end
    end

    -- v3.8.2: ХАРАКТЕРИСТИКИ ДОЛЖНОСТИ (у штурмовика 125ХП/145бр и т.д.)
    -- v4.8.4 «ВЫСАДКА»: на спавне (fullHeal) — ПОЛНЫЕ ХП профы, а не
    -- «обрезать сверху»: раньше штурмовик 125ХП возрождался с 100.
    local hp = math.Clamp(tonumber(job.hp) or 100, 1, 1000)
    ply:SetMaxHealth(hp)
    if fullHeal then
        ply:SetHealth(hp)
    elseif ply:Health() > hp then
        ply:SetHealth(hp) -- смена профы/модели на лету: без халявного хила
    end
    ply:SetArmor(math.Clamp(tonumber(job.armor) or 0, 0, 500))

    -- внешность: выбранный вариант из меню, иначе случайный из валидных
    local valids = P11FW.ValidModels(job)
    local model = valids[1]
    if modelIdx and isnumber(modelIdx) and valids[modelIdx] then
        model = valids[modelIdx]
    elseif #valids > 1 then
        model = valids[math.random(#valids)]
    end
    ply:SetModel(model)
end

-- ============ СМЕНА ДОЛЖНОСТИ ============

-- возвращает true/false, ошибку
function P11FW.SetJob(ply, jobId, modelIdx, force)
    if not IsValid(ply) then return false, "нет игрока" end

    local job = P11FW.Jobs[jobId]
    if not job then return false, "такой должности нет" end

    local oldId = P11FW.GetJobId(ply)
    if oldId == jobId then
        -- v3.9: та же должность, но другой ВАРИАНТ МОДЕЛИ (C-меню/F4-выбор внешности)
        if modelIdx and ply:Alive() then
            P11FW.ApplyLoadout(ply, modelIdx)
            return true
        end
        return false, "вы уже на этой должности"
    end

    -- арестованным и рабам должности не выдают (кроме системных вызовов с force)
    if not force then
        local pun = ply:GetNWString("P11FW_Punish", "")
        if pun == "arrest" then return false, "вы арестованы — без должности" end
        if pun == "slavery" then return false, "вы в рабстве — без должности" end
    end

    -- v4.22.0 «ОКОВЫ»: в наручниках должность не меняют — вас ведут под конвоем
    if not force and POLUS11 and POLUS11.IsCuffed and POLUS11.IsCuffed(ply) then
        return false, "вы в наручниках — должность не сменить под конвоем"
    end

    -- v4.24.0 «РУБЕЖ»: участникам ОПЕРАЦИИ должность заморожена до финала
    if not force and POLUS11 and POLUS11.OpJobBlock and POLUS11.OpJobBlock(ply) then
        return false, "идёт операция — ты на боевом посту, должность заморожена"
    end

    -- v3.8.2 → v4.8.8 «ЛИЧИНА»: ИВЕНТОВЫЕ роли (Нечто-формы и пр.) —
    -- только СТАРШАЯ администрация (Куратор+, ранг 12) или движковый
    -- superadmin. Раньше планка была ранг 4 — младшая администрация
    -- брала себе [ИВЕНТ] Нечто (репорт: «ранги ниже берут ранги выше»).
    if job.event and not force then
        local allowed = ply:IsSuperAdmin()
            or (P11FW.GetRankLevel(ply) >= ((P11FW.Config and P11FW.Config.EventJobRankLevel) or 12))
        if not allowed then
            P11FW.Log("ОТКАЗ ивент-роль: " .. ply:Nick() .. " попытался взять «"
                .. tostring(job.name) .. "» без ранга Куратор+")
            return false, "ивентовая роль — только у старшей администрации (Куратор+): для Нечто есть укол/вакансия у кадровика/админ-пульт"
        end
    end

    -- v4.4.0: ВАЙТЛИСТ-ДОПУСК (должности с галочкой «ВАЙТЛИСТ», напр. всё НКВД).
    -- Администрация проходит свободно, остальным нужен допуск (вкладка ВАЙТЛИСТ
    -- в /menu у администрации и рангов Faction Officer/Leader).
    if job.whitelist and not force then
        -- v4.5.0: «Главе Проекта доступны ВСЕ вайтлисты» (по заявке владельца)
        local allowed = P11FW.Config.Admin(ply)
            or (P11FW.HasWhitelist and P11FW.HasWhitelist(ply, jobId))
            or (P11FW.GetRankLevel(ply) >= 16)
        if not allowed then
            return false, "должность в ВАЙТЛИСТЕ 🔒 — допуск выдают офицеры НКВД / администрация (вкладка ВАЙТЛИСТ в /menu)"
        end
    end

    -- v4.5.0: ВРЕМЯ ДЛЯ ПРОФЫ (job.time мин. игры; Super Admin+ обходит)
    if not force and (job.time or 0) > 0 and POLUS11 and POLUS11.TimeGate then
        local toks, terr = POLUS11.TimeGate(ply, job)
        if not toks then return false, terr end
    end

    -- v4.21.0 «ДРЕВО»: узел дерева службы (РККА/Учёные) — уровень/путь.
    -- Ранг Staff Leader+ (14+) вне механики (заявка владельца).
    if not force and POLUS11 and POLUS11.SkillTreeJobOK then
        local tok, terr = POLUS11.SkillTreeJobOK(ply, jobId)
        if not tok then return false, terr end
    end

    -- v4.8.0: VIP-ДОЛЖНОСТЬ (секция 💎 VIP-СЛУЖБА) — с ранга VIP
    -- (P11FW.IsVIP: VIP, стафф уровня 2+, админы движка, хост).
    if job.vip and not force then
        if not (P11FW.IsVIP and P11FW.IsVIP(ply)) then
            return false, "VIP-должность 💎 — доступна с ранга VIP (поддержка станции, меню F6)"
        end
    end

    if not force and P11FW.JobFull(jobId, ply) then
        return false, "нет свободных мест (" .. P11FW.TeamCount(jobId, ply) .. "/" .. (job.max or 0) .. ")"
    end

    ply:SetTeam(P11FW.JobTeams[jobId])

    if ply:Alive() then
        P11FW.ApplyLoadout(ply, modelIdx)
    end

    hook.Run("P11FW.JobChanged", ply, jobId, oldId)
    P11FW.Log(ply:Nick() .. ": " .. P11FW.Jobs[oldId].name .. " -> " .. job.name)

    return true
end

function P11FW.Demote(ply, force)
    local def = P11FW.Config.DefaultJob
    if P11FW.GetJobId(ply) == def then return false, "уже без назначения" end
    return P11FW.SetJob(ply, def, nil, force)
end

-- ============ NET: игрок просит должность ============

net.Receive("P11FW_TakeJob", function(len, ply)
    -- антиспам
    ply.P11FW_NextReq = ply.P11FW_NextReq or 0
    if CurTime() < ply.P11FW_NextReq then return end
    ply.P11FW_NextReq = CurTime() + 1

    local jobId = net.ReadString()
    local modelIdx = net.ReadUInt(5)

    local ok, err = P11FW.SetJob(ply, jobId, modelIdx > 0 and modelIdx or nil, false)
    if ok then
        local job = P11FW.Jobs[jobId]
        P11FW.Notify(ply, "Должность получена: " .. job.name .. ". Удачной службы!")
        PrintMessage(HUD_PRINTTALK, "[Личный состав] " .. ply:Nick() .. " теперь: " .. job.name)
    else
        P11FW.Notify(ply, "Отказано: " .. tostring(err))
        ply:EmitSound("buttons/button10.wav", 60, 100)
    end
end)

-- ============ СТАРТ / РЕСПАВН ============

-- новичок заходит: ставим должность по умолчанию
hook.Add("PlayerInitialSpawn", "P11FW.FirstJoin", function(ply)
    timer.Simple(1, function()
        if not IsValid(ply) then return end
        if not P11FW.TeamJobs[ply:Team()] then
            ply:SetTeam(P11FW.JobTeams[P11FW.Config.DefaultJob])
        end
    end)
end)

-- респавн: выдать должностное снаряжение и модель
hook.Add("PlayerSpawn", "P11FW.SpawnLoadout", function(ply)
    -- после стандартного лоадаута песочницы
    timer.Simple(0.1, function()
        if IsValid(ply) and ply:Alive() then
            P11FW.ApplyLoadout(ply, nil, true) -- на спавне: ПОЛНЫЕ ХП/броня профы
        end
    end)
    -- v4.8.4: страховочная волна ХП/брони (если чужой аддон переписал
    -- здоровье после нашей выдачи — вернём честные цифры профы)
    timer.Simple(0.55, function()
        if not (IsValid(ply) and ply:Alive()) then return end
        local job = P11FW.GetJob(ply)
        if not job then return end
        local hp = math.Clamp(tonumber(job.hp) or 100, 1, 1000)
        local ar = math.Clamp(tonumber(job.armor) or 0, 0, 500)
        ply:SetMaxHealth(hp)
        if ply:Health() ~= hp then ply:SetHealth(hp) end
        if ply:Armor() ~= ar then ply:SetArmor(ar) end
    end)
end)

-- ============ ЧАТ-КОМАНДЫ ============

hook.Add("PlayerSay", "P11FW.ChatCmds", function(ply, text)
    if not P11FW.Config.ChatMenuCommands then return end
    local t = string.lower(string.Trim(text))

    if t == "!работа" or t == "!job" or t == "!f4" or t == "!профа" then
        net.Start("P11FW_OpenMenu")
        net.Send(ply)
        return ""
    end
end)

-- ============ АДМИН-КОМАНДЫ ============

local function FindPlayer(arg)
    if not arg or arg == "" then return nil end
    local byId = player.GetByID(tonumber(arg) or -1)
    if IsValid(byId) then return byId end
    local low = string.lower(arg)
    for _, p in ipairs(player.GetAll()) do
        if string.find(string.lower(p:Nick()), low, 1, true) then return p end
    end
    return nil
end

-- polus_fw_setjob <игрок> <jobId>  — выдать насильно (в обход лимита)
concommand.Add("polus_fw_setjob", function(ply, cmd, args)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then return end
    local target = FindPlayer(args[1])
    if not IsValid(target) then print("[P11FW] игрок не найден: " .. tostring(args[1])) return end
    if not P11FW.Jobs[args[2]] then print("[P11FW] должность не найдена: " .. tostring(args[2])) return end

    local ok, err = P11FW.SetJob(target, args[2], nil, true)
    local out = ok and ("OK: " .. target:Nick() .. " теперь " .. P11FW.Jobs[args[2]].name) or ("ОШИБКА: " .. tostring(err))
    if IsValid(ply) then P11FW.Notify(ply, out) else print("[P11FW] " .. out) end
end)

-- polus_fw_demote <игрок> — снять с должности
concommand.Add("polus_fw_demote", function(ply, cmd, args)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then return end
    local target = FindPlayer(args[1])
    if not IsValid(target) then print("[P11FW] игрок не найден: " .. tostring(args[1])) return end

    local ok, err = P11FW.Demote(target, true)
    local out = ok and ("OK: " .. target:Nick() .. " уволен в новобранцы") or ("ОШИБКА: " .. tostring(err))
    if ok then P11FW.Notify(target, "Вас сняли с должности.") end
    if IsValid(ply) then P11FW.Notify(ply, out) else print("[P11FW] " .. out) end
end)

-- polus_fw_jobs — кто где служит (консоль)
concommand.Add("polus_fw_jobs", function(ply)
    local out = { "== ШТАТ СТАНЦИИ ==" }
    for _, id in ipairs(P11FW.JobIds) do
        local job = P11FW.Jobs[id]
        local names = {}
        local t = P11FW.JobTeams[id]
        for _, p in ipairs(player.GetAll()) do
            if p:Team() == t then names[#names + 1] = p:Nick() end
        end
        if #names > 0 then
            out[#out + 1] = "  " .. job.name .. " [" .. #names .. ((job.max or 0) > 0 and ("/" .. job.max) or "") .. "]: " .. table.concat(names, ", ")
        end
    end
    local text = table.concat(out, "\n")
    if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, text) else print(text) end
end)
