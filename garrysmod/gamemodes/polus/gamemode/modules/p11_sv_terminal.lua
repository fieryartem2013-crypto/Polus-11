-- ============================================================
--  ПОЛЮС-11 — СМЕННЫЙ ТЕРМИНАЛ + ДОП-ЗАДАЧИ (server) v2.7
--  Терминал — стационарная консоль (persist на карту).
--  Игрок с должностью, у которой стоит галочка «допуск к
--  терминалу» (в админ-редакторе должностей), либо админ,
--  назначает ЭКИПАЖУ дополнительные задачи из готового
--  каталога. Прогресс идёт через общую систему TaskEvent.
-- ============================================================

util.AddNetworkString("P11_TermOpen")
util.AddNetworkString("P11_TermData")
util.AddNetworkString("P11_TermAct")

-- ============ ГОТОВЫЕ ДОП-ЗАДАЧИ (каталог терминала) ============
-- event = ключ события из системы задач; max = сколько раз.

POLUS11.XTaskCatalog = {
    { key = "refuel_gen",  name = "Долить солярку в генератор",        max = 1 },
    { key = "repair_gen",  name = "Отремонтировать генератор",         max = 1 },
    { key = "refill_ft",   name = "Заправить огнемёт",                max = 1 },
    { key = "blood_draw",  name = "Взять образец крови",              max = 1 },
    { key = "blood_test",  name = "Провести тест крови",              max = 1 },
    { key = "autopsy",     name = "Провести вскрытие трупа",          max = 1 },
    { key = "fed",         name = "Накормить 2 членов экипажа",       max = 2 },
    { key = "radio",       name = "Доложить в рацию дважды",          max = 2 },
    { key = "build_up",    name = "Закрепить 3 предмета (стройка)",   max = 3 },
    { key = "damage_thing",name = "Нанести 100 урона Нечто",          max = 100 },
    { key = "alive",       name = "Патруль: 6 минут в живых",         max = 360 },
    { key = "fist_hit",    name = "Спарринг: 10 ударов кулаками",     max = 10 },
}

-- ============ ДОПУСК ============

function POLUS11.CanUseTerminal(ply)
    if not IsValid(ply) then return false end
    if P11FW.Config.Admin(ply) then return true end
    local job = P11FW.GetJob and P11FW.GetJob(ply)
    return job and job.terminal == true
end

-- ============ СПАВН / УДАЛЕНИЕ (админ) + PERSIST ============

local function TermFile()
    return "polus11/terminal_" .. game.GetMap() .. ".json"
end

local function SaveTerminals()
    if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
    local list = {}
    for _, ent in ipairs(ents.FindByClass("polus11_terminal")) do
        local p, a = ent:GetPos(), ent:GetAngles()
        list[#list + 1] = {
            pos = { x = p.x, y = p.y, z = p.z },
            ang = { p = a.p, y = a.y, r = a.r },
        }
    end
    file.Write(TermFile(), util.TableToJSON(list, true))
end

local function SpawnAt(pos, ang)
    local t = ents.Create("polus11_terminal")
    if not IsValid(t) then return end
    t:SetPos(pos)
    t:SetAngles(ang)
    t:Spawn()
    return t
end

local function LoadTerminals()
    -- чистим старые (не дублим при повторной загрузке)
    for _, e in ipairs(ents.FindByClass("polus11_terminal")) do e:Remove() end
    local raw = file.Read(TermFile(), "DATA")
    if not raw then return end
    local ok, list = pcall(util.JSONToTable, raw)
    if not (ok and istable(list)) then return end
    for _, rec in ipairs(list) do
        local p = rec.pos or {}
        local a = rec.ang or {}
        SpawnAt(Vector(p.x or 0, p.y or 0, p.z or 0), Angle(a.p or 0, a.y or 0, a.r or 0))
    end
end

hook.Add("InitPostEntity", "P11.TermLoad", function()
    timer.Simple(0.8, LoadTerminals)
end)
hook.Add("PostCleanupMap", "P11.TermLoad2", function()
    timer.Simple(0.8, LoadTerminals)
end)

function POLUS11.SpawnTerminal(ply)
    local ang = ply:EyeAngles()
    ang.p, ang.r = 0, 0
    local ent = SpawnAt(ply:GetPos() + ang:Forward() * 60, ang)
    if IsValid(ent) then
        SaveTerminals()
        P11FW.Notify(ply, "Терминал установлен (сохранён на карту).")
        POLUS11.Log("Терминал поставил " .. ply:Nick())
    end
end

function POLUS11.RemoveTerminalNear(ply)
    for _, e in ipairs(ents.FindInSphere(ply:GetPos(), 160)) do
        if e:GetClass() == "polus11_terminal" then
            e:Remove()
            SaveTerminals()
            P11FW.Notify(ply, "Терминал убран.")
            return
        end
    end
    P11FW.Notify(ply, "Рядом терминала нет.")
end

-- ============ ДОП-ЗАДАЧИ (назначенные через терминал) ============

local function XTasksOf(ply)
    ply.P11_XTasks = ply.P11_XTasks or {}
    return ply.P11_XTasks
end

function POLUS11.XAssign(target, catKey, by)
    local cat = nil
    for _, c in ipairs(POLUS11.XTaskCatalog) do
        if c.key == catKey then cat = c break end
    end
    if not cat then return false, "нет такой задачи в каталоге" end

    local list = XTasksOf(target)
    if #list >= 4 then return false, "у игрока уже 4 доп-задачи (макс)" end
    for _, t in ipairs(list) do
        if t.key == cat.key and not t.done then return false, "такая задача уже назначена" end
    end

    list[#list + 1] = {
        key   = cat.key,
        name  = cat.name,
        max   = cat.max,
        cur   = 0,
        done  = false,
        since = CurTime(), -- v2.9: для ложного прогресса Нечто
        by    = IsValid(by) and by:Nick() or "терминал",
    }
    POLUS11.SyncTasks(target)
    target:ChatPrint("[ЗАДАНИЕ] Терминал выдал тебе: " .. cat.name)
    target:EmitSound("buttons/button15.wav", 60, 100)
    return true
end

function POLUS11.XRevoke(target, catKey)
    local list = XTasksOf(target)
    for i, t in ipairs(list) do
        if t.key == catKey and not t.done then
            table.remove(list, i)
            POLUS11.SyncTasks(target)
            target:ChatPrint("[ЗАДАНИЕ] Снято задание: " .. t.name)
            return true
        end
    end
    return false
end

-- тик событий по доп-задачам (вызывается из POLUS11.TaskEvent)
function POLUS11.XTaskEvent(ply, key, add)
    if not IsValid(ply) or not ply.P11_XTasks then return end
    add = add or 1
    local changed = false
    for _, t in ipairs(ply.P11_XTasks) do
        if t.key == key and not t.done then
            t.cur = math.min(t.max, t.cur + add)
            changed = true
            if t.cur >= t.max then
                t.done = true
                ply:EmitSound("buttons/button9.wav", 60, 130)
                POLUS11.Notify(ply, "Доп-задача выполнена: " .. t.name .. " (+10 хп бодрости)")
                local maxhp = ply:GetMaxHealth() > 0 and ply:GetMaxHealth() or 100
                ply:SetHealth(math.min(maxhp, ply:Health() + 10))
            end
        end
    end
    if changed then POLUS11.SyncTasks(ply) end
end

-- ============ СЕТЬ ============

function POLUS11.TermSendData(ply)
    if not IsValid(ply) then return end

    net.Start("P11_TermData")
        net.WriteUInt(#POLUS11.XTaskCatalog, 8)
        for _, c in ipairs(POLUS11.XTaskCatalog) do
            net.WriteString(c.key) net.WriteString(c.name) net.WriteUInt(c.max, 12)
        end

        local list = {}
        for _, p in ipairs(player.GetAll()) do
            if p:Alive() then list[#list + 1] = p end
        end
        net.WriteUInt(#list, 8)
        for _, p in ipairs(list) do
            net.WriteUInt(p:EntIndex(), 8)
            net.WriteString(p:Nick())
            net.WriteString(P11FW.GetJobName and P11FW.GetJobName(p) or "")
            -- v2.9: если игрок — замаскированное Нечто, начальству он
            -- «врёт»: в терминале его прогресс растёт сам собой быстрее
            -- реальности (ползёт +1 каждые ~25 сек с момента назначения).
            local masked = POLUS11.IsMaskedThing and POLUS11.IsMaskedThing(p) or false
            local rows = {}
            for _, t in ipairs(p.P11_XTasks or {}) do
                local shown = math.floor(t.cur)
                if masked and not t.done and t.since then
                    shown = math.min(t.max, shown + math.floor((CurTime() - t.since) / 25))
                end
                rows[#rows + 1] = { key = t.key, name = t.name, cur = shown, max = t.max, done = t.done }
            end
            net.WriteString(util.TableToJSON(rows) or "[]")
        end
    net.Send(ply)
end

function POLUS11.OpenTerminal(ply)
    net.Start("P11_TermOpen")
    net.Send(ply)
    POLUS11.TermSendData(ply)
end

net.Receive("P11_TermAct", function(len, ply)
    if not IsValid(ply) or not POLUS11.CanUseTerminal(ply) then return end

    ply.P11_TermNext = ply.P11_TermNext or 0
    if CurTime() < ply.P11_TermNext then return end
    ply.P11_TermNext = CurTime() + 0.4

    local act = net.ReadUInt(2)
    if act == 0 then -- просто обновить данные
        POLUS11.TermSendData(ply)
        return
    end

    local target = Entity(net.ReadUInt(8))
    local catKey = net.ReadString()

    if act == 3 then -- взять задачу СЕБЕ (у терминала с допуском)
        local ok, err = POLUS11.XAssign(ply, catKey, ply)
        P11FW.Notify(ply, ok and "Задача взята себе." or ("Ошибка: " .. tostring(err)))
        POLUS11.TermSendData(ply)
        return
    end

    if not (IsValid(target) and target:IsPlayer()) then return end

    if act == 1 then -- назначить
        local ok, err = POLUS11.XAssign(target, catKey, ply)
        P11FW.Notify(ply, ok and ("Назначено: " .. target:Nick()) or ("Ошибка: " .. tostring(err)))
    elseif act == 2 then -- снять
        local ok = POLUS11.XRevoke(target, catKey)
        P11FW.Notify(ply, ok and ("Снято: " .. target:Nick()) or "Такой активной доп-задачи нет.")
    end
    POLUS11.TermSendData(ply)
end)
