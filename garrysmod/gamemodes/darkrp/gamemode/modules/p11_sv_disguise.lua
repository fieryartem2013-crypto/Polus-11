-- ============================================================
--  ПОЛЮС-11 — МАСКИРОВКА «ЛЕГАТ» (server) v4.8.5 «КРАСНЫЙ ОРЁЛ»
--  Серверная сторона кейса маскировки: сбор легенды
--  (липовой позывной + облик РККА/науки/техперсонала +
--  липовая должность + липовой код документа), наложение
--  за 3 сек (срывается движением), быстрое ПКМ по последней
--  легенде, кулдаун переодевания, снятие при смерти/смене
--  должности. Механика отображения — та же, что у личин
--  Нечто (P11_FakeNick / P11_FakeJob / P11_FakeDesc /
--  P11_DocCode): TAB, ники над головами, голос и документы
--  показывают ЛЕГЕНДУ, а не истинное лицо.
--  Админ-зеркало: p11_spies — кто сейчас в маскировке.
-- ============================================================

util.AddNetworkString("P11_Disguise")

local APPLY_TIME = 3.0   -- секунд наложения (прогресс у клиента)
local RE_COOLDOWN = 20   -- секунд до повторного наложения после снятия
local MOVE_TOLERANCE = 150 -- сдвинулся дальше — маскировка сорвана

local function Notify(ply, msg)
    if POLUS11 and POLUS11.Notify then POLUS11.Notify(ply, msg)
    elseif P11FW and P11FW.Notify then P11FW.Notify(ply, msg)
    else ply:ChatPrint("[ЛЕГАТ] " .. msg) end
end

local function Log(msg)
    if P11FW and P11FW.Log then P11FW.Log(msg) else print("[ЛЕГАТ] " .. msg) end
end

-- ============ КОСТЮМЫ ЛЕГЕНДЫ ============
-- jobIds — под какую должность притворяемся (должна существовать);
-- models — кандидаты внешности: первая случайная СУЩЕСТВУЮЩАЯ
-- (нет пака моделей — сработает стоковый фолбэк, кейс не пустой).
local SUITS = {
    {
        id = "rkka_m35", name = "Стрелковый состав РККА (М35)",
        desc = "Гимнастёрка обр. 1941 г. Дежурный боец периметра — таких на станции десятки, на тебя не посмотрят дважды.",
        jobIds = { "seed_rkka_soldat", "seed_rkka_postovoy", "seed_rkka_novobranets" },
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_02.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_03.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_04.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_05.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_06.mdl",
        },
        autoDesc = "Боец гарнизона «Полюс-11». При исполнении, разговорчив мало.",
    },
    {
        id = "rkka_m43", name = "Штурмовой состав РККА (М43)",
        desc = "Полевой комплект М43 и потёртый бронежилет. Первым идёт в заражённые отсеки — и выходит оттуда.",
        jobIds = { "seed_rkka_shturmovik" },
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m43_s1_02.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m43_s1_03.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m43_s1_04.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m43_s1_05.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m43_s1_06.mdl",
        },
        autoDesc = "Штурмовик гарнизона. От него пахнет порохом и озоном.",
    },
    {
        id = "rkka_officer", name = "Командный состав РККА",
        desc = "Офицерская гимнастёрка с портупеей. Людям с бумагами и прямой спиной двери открываются сами.",
        jobIds = { "seed_rkka_komissar" },
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_02.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_03.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_04.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_05.mdl",
        },
        autoDesc = "Офицер гарнизона. Смотрит так, будто ведёт на тебя досье.",
    },
    {
        id = "rkka_general", name = "Генштаб РККА",
        desc = "Парадный китель М40 генеральского штаба. Маскировка смелая — генерала знают в лицо, если он НА САМОМ деле на станции.",
        jobIds = { "seed_rkka_general", "seed_rkka_generalpeh" },
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/general_staff/gen/m40_1941_s1_05.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/gen/m40_1941_s1_02.mdl",
        },
        autoDesc = "Генерал из штаба. Отдаёт приказы одним подбородком.",
    },
    {
        id = "science", name = "Научный сотрудник",
        desc = "Белый халат лабораторного блока. Учёного пропускают туда, куда солдату хода нет.",
        jobIds = { "seed_sci_ucheniy", "seed_sci_laborant", "seed_sci_biohim" },
        models = {
            "Models/UIF/scientists/UIF_scientist_7.mdl",
            "Models/UIF/scientists/UIF_scientist_8.mdl",
            "models/player/barney.mdl", -- v5.8.18: учёный-фолбэк (роб/очки), НЕ Кляйнер
        },
        autoDesc = "Исследователь комплекса. Руки пахнут формалином.",
    },
    {
        -- v4.33.1 «МЕДАЛЬ»: кейс «ОБСЛУГА» обновлён — легенда умеет
        -- притворяться ВСЕМ персоналом станции: встроенные должности
        -- + Водитель (seed_pers_voditel, v4.10) + Инженер. В op==6
        -- должности собираются ДИНАМИЧЕСКИ из живого ростера
        -- (P11FW.Jobs с category == "personnel") — кастомные и
        -- переименованные профы тоже попадают в легенду.
        id = "personnel", name = "Техперсонал станции",
        desc = "Рабочая куртка обслуги: механик, сантехник, «тот парень с ключами». Незаметен, как тень.",
        jobIds = { "janitor", "cook", "porter", "tech", "medic", "engineer", "seed_pers_voditel" }, -- v4.17.0 «КОНТРАБАНДА»: ВЕСЬ персонал для кейса «ОБСЛУГА»
        models = {
            "models/player/Group01/male_01.mdl",
            "models/player/Group01/male_04.mdl",
            "models/player/Group01/male_06.mdl",
            "models/player/Group01/female_02.mdl",
            "models/player/barney.mdl", -- v4.33.1: техник в робе (стоковый)
        },
        autoDesc = "Обслуга станции. Вечно куда-то спешит с ключами.",
    },
}

local function FindSuit(id)
    for _, s in ipairs(SUITS) do
        if s.id == id then return s end
    end
    return nil
end

-- первая случайная СУЩЕСТВУЮЩАЯ модель из костюма
local function ResolveModel(suit)
    local ok = {}
    for _, m in ipairs(suit.models) do
        if file.Exists(m, "GAME") then ok[#ok + 1] = m end
    end
    if #ok == 0 then return nil end
    return ok[math.random(#ok)]
end

-- ============ ЛИПОВЫЙ ПОЗЫВНОЙ / ДОКУМЕНТ ============

local LASTS = { "Петров", "Кузнецов", "Смирнов", "Соколов", "Попов", "Морозов",
    "Волков", "Алексеев", "Лебедев", "Семёнов", "Егоров", "Крылов", "Степанов",
    "Николаев", "Орлов", "Андреев", "Макаров", "Захаров", "Борисов", "Гусев",
    "Фролов", "Медведев", "Антонов", "Тарасов", "Белов", "Комаров", "Дмитриев",
    "Громов", "Фомин", "Быков", "Тихонов", "Киселёв", "Михайлов", "Новиков" }
local INITS = { "А.", "В.", "Д.", "И.", "М.", "Н.", "О.", "П.", "С.", "Г." }

local function RandomCallSign()
    return LASTS[math.random(#LASTS)] .. " " .. INITS[math.random(#INITS)]
end

local function NewFakeDoc()
    local chars = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
    local p1 = ""
    for i = 1, 4 do
        local r = math.random(#chars)
        p1 = p1 .. string.sub(chars, r, r)
    end
    return "П11-" .. p1 .. "-" .. math.random(100, 999) -- тот же формат у настоящих
end

-- ============ УТИЛИТЫ ============

local function CleanName(str)
    str = tostring(str or "")
    str = string.gsub(str, "[%c\n\r\t]+", " ")
    str = string.gsub(str, "%s%s+", " ")
    str = string.Trim(str)
    if #str > 32 then str = string.sub(str, 1, 32) end
    return str
end

local function HasCase(ply)
    return IsValid(ply) and ply:Alive() and ply:HasWeapon("weapon_polus11_disguise")
end

local function IsActiveThing(ply)
    return IsValid(ply) and ply:GetNWBool("P11_InfActive", false)
end

-- нельзя прикинуться игроком, который УЖЕ ходит по станции
local function NameTaken(name, selfPly)
    local low = string.lower(name)
    for _, p in ipairs(player.GetAll()) do
        if p ~= selfPly then
            local n1 = string.lower(p:Nick() or "")
            local n2 = string.lower(p:GetNWString("P11_CharName", ""))
            local n3 = string.lower(p:GetNWString("P11_FakeNick", ""))
            if low == n1 or (n2 ~= "" and low == n2) or (n3 ~= "" and low == n3) then
                return true
            end
        end
    end
    return false
end

local function SuitJobValid(suit, jobTeam)
    for _, jobId in ipairs(suit.jobIds) do
        local jt = P11FW.JobTeams and P11FW.JobTeams[jobId]
        if jt == jobTeam then return true end
    end
    return false
end

-- результат операции → клиент
local function Result(ply, ok, msg)
    net.Start("P11_Disguise")
        net.WriteUInt(2, 3)
        net.WriteBool(ok == true)
        net.WriteString(string.sub(tostring(msg or ""), 1, 200))
    net.Send(ply)
end

-- ============ СПИСОК ЛЕГЕНД → КЛИЕНТ ============

local function SendMenuData(ply)
    if not HasCase(ply) then return end

    local list = {}
    for _, s in ipairs(SUITS) do
        local jobs = {}
        for _, jobId in ipairs(s.jobIds) do
            local jt = P11FW.JobTeams and P11FW.JobTeams[jobId]
            local job = P11FW.Jobs and P11FW.Jobs[jobId]
            if jt and job then
                jobs[#jobs + 1] = { team = jt, name = job.name }
            end
        end
        local modelOK = false
        for _, m in ipairs(s.models) do
            if file.Exists(m, "GAME") then modelOK = true break end
        end
        if #jobs > 0 and modelOK then
            list[#list + 1] = { id = s.id, name = s.name, desc = s.desc, jobs = jobs }
        end
    end

    local d = ply.P11_Disguise
    net.Start("P11_Disguise")
        net.WriteUInt(1, 3)
        net.WriteBool(d ~= nil)
        net.WriteString(d and d.name or "")
        net.WriteUInt(d and d.job or 0, 16)
        net.WriteFloat(math.max(0, (ply.P11_DsgCD or 0) - CurTime()))
        net.WriteFloat(APPLY_TIME)
        net.WriteUInt(#list, 8)
        for _, it in ipairs(list) do
            net.WriteString(it.id)
            net.WriteString(it.name)
            net.WriteString(it.desc)
            net.WriteUInt(#it.jobs, 8)
            for _, j in ipairs(it.jobs) do
                net.WriteUInt(j.team, 16)
                net.WriteString(j.name)
            end
        end
    net.Send(ply)
end

-- ============ НАЛОЖЕНИЕ ============

local function ApplyDisguise(ply, suit, jobTeam, name)
    local model = ResolveModel(suit)
    if not model then return false, "Нет моделей облика (паки не доехали)" end
    if ply.P11_Disguise then return false, "Маскировка уже надета" end

    if name == "" then name = RandomCallSign() end
    if NameTaken(name, ply) then
        return false, "Боец с таким позывным уже ходит по станции — возьми другой"
    end

    ply.P11_Disguise = {
        ownModel = ply:GetModel(),
        ownFakeNick = ply:GetNWString("P11_FakeNick", ""),
        ownFakeJob = ply:GetNWInt("P11_FakeJob", 0),
        ownFakeDesc = ply:GetNWString("P11_FakeDesc", ""),
        ownDoc = ply:GetNWString("P11_DocCode", ""),
        name = name, job = jobTeam, suit = suit.id, at = CurTime(),
    }

    ply:SetModel(model)
    ply:SetNWString("P11_FakeNick", name)
    ply:SetNWInt("P11_FakeJob", jobTeam)
    ply:SetNWString("P11_FakeDesc", suit.autoDesc or "Боец гарнизона.")
    ply:SetNWString("P11_DocCode", NewFakeDoc())

    -- последняя легенда = быстрое ПКМ
    ply.P11_DsgPreset = { suit = suit.id, job = jobTeam, name = name }

    local jobName = team.GetName(jobTeam) or "?"
    Log("МАСКИРОВКА: " .. ply:Nick() .. " → «" .. name .. "» (" .. suit.id .. " / " .. jobName .. ")")
    Notify(ply, "🎭 Легенда наложена: ты — «" .. name .. "», " .. jobName .. ". ПКМ — сорвать маску.")
    ply:EmitSound("items/ammocrate_close.wav", 70, 100)
    return true
end

-- ============ СНЯТИЕ ============

local function RemoveDisguise(ply, silentDeath)
    local d = ply.P11_Disguise
    if not d then
        if not silentDeath then Notify(ply, "Маскировки нет — ты и так сам(а) собой.") end
        return false
    end

    if not silentDeath then
        if isstring(d.ownModel) and util.IsValidModel(d.ownModel) then
            ply:SetModel(d.ownModel)
        end
    end

    ply.P11_Disguise = nil
    ply:SetNWString("P11_FakeNick", silentDeath and "" or (d.ownFakeNick or ""))
    ply:SetNWInt("P11_FakeJob", silentDeath and 0 or (d.ownFakeJob or 0))
    ply:SetNWString("P11_FakeDesc", silentDeath and "" or (d.ownFakeDesc or ""))
    ply:SetNWString("P11_DocCode",
        (not silentDeath and d.ownDoc ~= "") and d.ownDoc or (ply.P11_DocCode or ""))

    if not silentDeath then
        ply.P11_DsgCD = CurTime() + RE_COOLDOWN
        Log("МАСКИРОВКА СНЯТА: " .. ply:Nick() .. " (был «" .. (d.name or "?") .. "»)")
        Notify(ply, "Маска сорвана. Повторное наложение через " .. RE_COOLDOWN .. " сек.")
        ply:EmitSound("items/ammocrate_close.wav", 70, 110)
    end
    return true
end

-- ============ NET ============

net.Receive("P11_Disguise", function(len, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    -- антиспам
    ply.P11_DsgNext = ply.P11_DsgNext or 0
    if CurTime() < ply.P11_DsgNext then return end
    ply.P11_DsgNext = CurTime() + 0.5

    local op = net.ReadUInt(3)

    if op == 1 then -- запрос списка легенд (открытие кейса)
        SendMenuData(ply)
        return
    end

    -- v4.17.0 «КОНТРАБАНДА»: кейс «ОБСЛУГА» (weapon_polus11_disguise2) —
    -- МГНОВЕННАЯ авто-легенда ПЕРСОНАЛА: облик обслуги, позывной сами,
    -- должность из куртки-постного блока, липовой документ. Стоит ДО
    -- гейта HasCase «ЛЕГАТА» — кейс криминала проверяем своим классом.
    if op == 6 then
        if not ply:HasWeapon("weapon_polus11_disguise2") then
            Result(ply, false, "Кейса «ОБСЛУГА» нет в снаряге.")
            return
        end
        if IsActiveThing(ply) then
            Result(ply, false, "Телу кейс не нужен — оно само лицо меняет.")
            return
        end
        if ply.P11_Disguise then -- маска есть → ПКМ-повтор срывает её
            if RemoveDisguise(ply, false) then
                Result(ply, true, "Маска сорвана. Ты снова сам(а) собой.")
            end
            return
        end
        if CurTime() < (ply.P11_DsgCD or 0) then
            Result(ply, false, "Грим ещё не готов. Жди " .. math.ceil((ply.P11_DsgCD or 0) - CurTime()) .. " сек.")
            return
        end
        local suit = FindSuit("personnel")
        if not suit then Result(ply, false, "Легенд персонала не завезли.") return end
        -- v4.33.1 «МЕДАЛЬ»: должности персонала собираем ДИНАМИЧЕСКИ из
        -- живого ростера (категория "personnel") — кейс «ОБСЛУГА» умеет
        -- притворяться ЛЮБОЙ профой обслуги: встроенные, Водитель v4.10,
        -- Инженер, кастомные должности админа. Захардкоженный список
        -- 5 должностей отбрасывал всё, чего в нём не было.
        local opts = {}
        for jid, job in pairs(P11FW.Jobs or {}) do
            if job and job.category == "personnel" then
                local t = P11FW and P11FW.JobTeams and P11FW.JobTeams[jid]
                if t then opts[#opts + 1] = t end
            end
        end
        -- страховка: если категория не сработала, падаем на статический список
        if #opts == 0 then
            for _, jid in ipairs(suit.jobIds) do
                local t = P11FW and P11FW.JobTeams and P11FW.JobTeams[jid]
                if t then opts[#opts + 1] = t end
            end
        end
        if #opts == 0 then
            Result(ply, false, "На станции нет должностей персонала для легенды.")
            return
        end
        local ok, err
        for _ = 1, 4 do -- позывной мог пересечься — пробуем ещё раз
            ok, err = ApplyDisguise(ply, suit, opts[math.random(#opts)], "")
            if ok then break end
        end
        Result(ply, ok, ok and "🎭 Легенда обслуги наложена — станция видит тебя персоналом." or (err or "Грим сорвался."))
        return
    end

    -- дальше — только с кейсом в снаряге
    if not HasCase(ply) then
        Result(ply, false, "Кейса «ЛЕГАТ» нет в снаряге.")
        return
    end
    if IsActiveThing(ply) then
        Result(ply, false, "Телу кейс не нужен — оно само лицо меняет.")
        return
    end

    if op == 5 then -- старт наложения: легенда выбрана
        local suitId = string.sub(tostring(net.ReadString() or ""), 1, 32)
        local jobTeam = net.ReadUInt(16)
        local name = CleanName(net.ReadString())

        local suit = FindSuit(suitId)
        if not suit then Result(ply, false, "Нет такого облика.") return end
        if not SuitJobValid(suit, jobTeam) then
            Result(ply, false, "Эта должность к облику не подходит.") return
        end
        if ply.P11_Disguise then
            Result(ply, false, "Маскировка уже надета — сначала сорви старую.") return
        end
        if CurTime() < (ply.P11_DsgCD or 0) then
            Result(ply, false, "Грим ещё не готов. Жди " .. math.ceil((ply.P11_DsgCD or 0) - CurTime()) .. " сек.")
            return
        end
        if name ~= "" and #name < 3 then
            Result(ply, false, "Позывной короткий (минимум 3 знака) или оставь пустым — сочиним сами.")
            return
        end

        ply.P11_DsgPending = {
            suit = suitId, job = jobTeam, name = name,
            at = CurTime(), pos = ply:GetPos(),
        }
        ply:EmitSound("items/ammocrate_open.wav", 70, 100)
        Result(ply, true, "Накладываю грим… не двигайся " .. APPLY_TIME .. " сек.")

    elseif op == 2 then -- commit после прогресса
        local p = ply.P11_DsgPending
        if not p then Result(ply, false, "Наложение не начиналось.") return end
        if CurTime() - p.at < APPLY_TIME - 0.15 then
            Result(ply, false, "Ещё накладываешься…") return
        end
        if ply:GetPos():DistToSqr(p.pos) > MOVE_TOLERANCE * MOVE_TOLERANCE then
            ply.P11_DsgPending = nil
            Result(ply, false, "Маскировка сорвана — ты двигался во время грима!")
            return
        end
        ply.P11_DsgPending = nil
        local suit = FindSuit(p.suit)
        local ok, err = ApplyDisguise(ply, suit, p.job, p.name)
        Result(ply, ok, ok and "Готово — легенда наложена." or err)

    elseif op == 3 then -- снять маскировку
        if RemoveDisguise(ply, false) then
            Result(ply, true, "Маска снята.")
        else
            Result(ply, false, "Снимать нечего.")
        end

    elseif op == 4 then -- ПКМ: быстро надеть/снять по последней легенде
        if ply.P11_Disguise then
            if RemoveDisguise(ply, false) then Result(ply, true, "Маска сорвана.") end
            return
        end
        local pr = ply.P11_DsgPreset
        if not pr then
            -- пресета нет: пусть откроет кейс
            net.Start("P11_Disguise")
                net.WriteUInt(6, 3)
            net.Send(ply)
            return
        end
        if CurTime() < (ply.P11_DsgCD or 0) then
            Result(ply, false, "Грим ещё не готов. Жди " .. math.ceil((ply.P11_DsgCD or 0) - CurTime()) .. " сек.")
            return
        end
        local suit = FindSuit(pr.suit)
        if not suit then Result(ply, false, "Легенда потерялась — собери заново в кейсе.") return end
        local ok, err = ApplyDisguise(ply, suit, pr.job, pr.name)
        Result(ply, ok, ok and "Готово — легенда наложена." or err)
    end
end)

-- ============ СБРОС: СМЕРТЬ / СМЕНА ДОЛЖНОСТИ ============

hook.Add("PlayerSpawn", "P11.DisguiseSpawnClear", function(ply)
    ply.P11_DsgPending = nil
    if ply.P11_Disguise then
        RemoveDisguise(ply, true) -- модель задаст лоадаут профы
    end
end)

hook.Add("P11FW.JobChanged", "P11.DisguiseJobClear", function(ply)
    if ply.P11_Disguise then
        RemoveDisguise(ply, true)
        Notify(ply, "Маскировка снята при смене должности.")
    end
end)

-- ============ АДМИН-ЗЕРКАЛО ============

concommand.Add("p11_spies", function(ply)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then return end
    local out = { "== МАСКИРОВКИ «ЛЕГАТ» (кто сейчас в липовой легенде) ==" }
    local n = 0
    for _, p in ipairs(player.GetAll()) do
        local d = p.P11_Disguise
        if d then
            n = n + 1
            out[#out + 1] = string.format("  %-22s → «%s» | костюм: %s | должность-легенда: %s | %d сек назад",
                p:Nick(), d.name, d.suit, team.GetName(d.job) or tostring(d.job),
                math.floor(CurTime() - d.at))
        end
    end
    if n == 0 then out[#out + 1] = "  активных маскировок нет." end
    out[#out + 1] = "  выдать кейс: give <ник> weapon_polus11_disguise"
    local txt = table.concat(out, "\n")
    if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, txt) else print(txt) end
end)

print("[POLUS-11] маскировка «ЛЕГАТ» v4.8.5 «КРАСНЫЙ ОРЁЛ»: кейс weapon_polus11_disguise | обликов: " .. #SUITS .. " | админ-зеркало: p11_spies")
