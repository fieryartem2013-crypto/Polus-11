-- ============================================================
--  ПОЛЮС-11 — СИСТЕМА ВНЕШНОСТИ (server) v4.4.0 — НАПИСАНА С НУЛЯ
--  Единая точка выдачи моделей игрокам.
--
--  КАНАЛЫ:
--   • P11_ModelWear — «надеть себе» из меню моделей (p11_cl_models).
--       — модель ИЗ СПИСКА СВОЕЙ должности: может КАЖДЫЙ
--         (идёт через P11FW.SetJob с индексом — как в F4,
--          снаряжение не сбивается с должности);
--       — любая другая модель: только АДМИНИСТРАЦИЯ (косметика
--         до респавна/смены должности).
--   • P11_ModelGive — ВЫДАТЬ МОДЕЛЬ ДРУГОМУ игроку (только админ).
--
--  Проверки: путь <= 96 символов, только models/player/*.mdl,
--  без «..», троттлинг по CurTime, живой игрок. Модель-без-файла
--  ставится с предупреждением (воркшоп-пак может быть у клиентов).
-- ============================================================

util.AddNetworkString("P11_ModelWear")
util.AddNetworkString("P11_ModelGive")

-- ============ ВАЛИДАЦИЯ ПУТИ ============

local function SanitizeModel(raw)
    local mdl = string.lower(string.Trim(tostring(raw or "")))
    if mdl == "" or #mdl > 96 then return nil end
    if #mdl < 12 then return nil end
    if not string.find(mdl, "models/player/", 1, true) then return nil end
    if string.find(mdl, "%.%.") then return nil end
    if not string.EndsWith(mdl, ".mdl") then return nil end
    return mdl
end

-- общий хвост: поставить модель + честно предупредить про воркшоп
local function ApplyModel(ply, mdl)
    local has = file.Exists(mdl, "GAME")
    if has then util.PrecacheModel(mdl) end
    ply:SetModel(mdl)
    return has
end

local function WearNotify(ply, has)
    if has then
        P11FW.Notify(ply, "Внешность изменена (до респавна/смены должности).")
    else
        P11FW.Notify(ply, "Внешность изменена. ⚠ Файла на сервере нет — у игроков без воркшоп-пака будет ERROR!")
    end
end

-- ============ НАДЕТЬ СЕБЕ ============

net.Receive("P11_ModelWear", function(len, ply)
    if not IsValid(ply) or not ply:Alive() then return end

    ply.P11Mdl_Next = ply.P11Mdl_Next or 0
    if CurTime() < ply.P11Mdl_Next then return end
    ply.P11Mdl_Next = CurTime() + 0.6

    local mdl = SanitizeModel(net.ReadString())
    if not mdl then return end

    -- 1) модель из списка СВОЕЙ должности — может каждый.
    --    Идём официальным путём SetJob(та же, idx): это ровно то,
    --    что делает F4 при выборе варианта внешности.
    local job = P11FW.GetJob(ply)
    if job and istable(job.models) then
        for i, m in ipairs(job.models) do
            if string.lower(tostring(m)) == mdl then
                P11FW.SetJob(ply, P11FW.GetJobId(ply), i, false)
                P11FW.Notify(ply, "Форма по должности надета.")
                return
            end
        end
    end

    -- 2) чужая/произвольная модель — только администраторская косметика
    if not P11FW.Config.Admin(ply) then
        P11FW.Notify(ply, "Свободно надевать можно только модели СВОЕЙ должности — остальное через администрацию.")
        return
    end

    WearNotify(ply, ApplyModel(ply, mdl))
    if P11FW.ModLog then P11FW.ModLog("model", ply, ply, mdl) end
end)

-- ============ ВЫДАТЬ ДРУГОМУ (админ) ============

net.Receive("P11_ModelGive", function(len, ply)
    if not IsValid(ply) or not P11FW.Config.Admin(ply) then return end

    ply.P11Mdl_NextGive = ply.P11Mdl_NextGive or 0
    if CurTime() < ply.P11Mdl_NextGive then return end
    ply.P11Mdl_NextGive = CurTime() + 0.6

    local target = Entity(net.ReadUInt(8))
    local mdl = SanitizeModel(net.ReadString())
    if not IsValid(target) or not target:IsPlayer() or not target:Alive() or not mdl then return end

    ApplyModel(target, mdl)
    P11FW.Notify(ply, "Модель выдана: " .. target:Nick() .. " → " .. mdl ..
        (file.Exists(mdl, "GAME") and "" or "  ⚠ нет файла на сервере!"))
    target:ChatPrint("[ПОЛЮС-11] Администрация сменила твою внешность (до респавна/смены должности).")
    if P11FW.ModLog then P11FW.ModLog("modelgive", ply, target, mdl) end
end)

-- ============ КОНСОЛЬ ============

-- p11_model "models/player/....mdl" — надеть себе (админ)
concommand.Add("p11_model", function(ply, cmd, args, line)
    if not IsValid(ply) or not P11FW.Config.Admin(ply) then return end
    local mdl = SanitizeModel(args[1])
    if not mdl then
        ply:PrintMessage(HUD_PRINTCONSOLE, "p11_model <models/player/....mdl>")
        return
    end
    WearNotify(ply, ApplyModel(ply, mdl))
end)

-- p11_modelgive <игрок> <models/player/....mdl> — выдать другому (админ)
concommand.Add("p11_modelgive", function(ply, cmd, args)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then return end
    local low = string.lower(tostring(args[1] or ""))
    local target = nil
    for _, p in ipairs(player.GetAll()) do
        if string.find(string.lower(p:Nick()), low, 1, true) then target = p break end
    end
    local mdl = SanitizeModel(args[2])
    if not IsValid(target) or not mdl then
        local msg = "p11_modelgive <часть ника> <models/player/....mdl>"
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print("[P11] " .. msg) end
        return
    end
    ApplyModel(target, mdl)
    local msg = "OK: " .. target:Nick() .. " → " .. mdl
    if IsValid(ply) then P11FW.Notify(ply, msg) else print("[P11] " .. msg) end
end)
