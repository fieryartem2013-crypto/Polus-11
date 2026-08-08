-- ============================================================
--  ПОЛЮС-11 — «ГЛАЗ»: ДИСПЕТЧЕР КРАСНЫХ ОРЛОВ (server)
--  v4.19.0 «ГЛАЗ» — заявка владельца: «система диспетчера:
--  камеры; профа диспетчер Красных орлов, который может
--  меняться через камеры и переключаться на игроков и смотреть
--  с 3-го лица за ними, с менюшкой выдачи ХП, брони и оружия
--  из пака EFT; возможность открывания и блокирования дверей
--  и другие приколы; и энтити — его терминал, через который
--  он и может это всё».
--
--  ДОПУСК: должность seed_eagle_dispatcher (вайтлист, 1 место)
--  или администратор ранг 4+ (можно гонять пульт на ивентах).
--  ЭНТИТИ: камера polus11_seccam (роль cam), терминал
--  polus11_dspterm (роль dspterm) — обе из 📍 «Расставить».
--
--  ПРОТОКОЛ P11_Dsp (op — 4 бита):
--    S→C  1 OPEN          (сеанс открыт)
--         2 EXIT + string (сеанс закрыт сервером, текст-причина)
--         3 RPLY + string (ответ-строка в чат пульта)
--         4 DOORS         (синх списка дверей: u16 n, далее n ×
--                          {string имя, bool locked, bool open})
--    C→S  1 EXIT          (попросился выйти)
--         2 HP    + u16 entidx цели           (+25 ХП, кд 30с)
--         3 ARMOR + u16 entidx цели           (+50 брони, кд 30с)
--         4 WEAPON+ u16 entidx цели + u8 idx  (ствол каталога, кд 60с)
--         5 MARK  + u16 entidx цели           (маяк 60с орлам, кд 25с)
--         6 SIGNAL                            (эфир всем орлам, кд 20с)
--         7 DLOCK + u16 idx двери             (блок/разблок)
--         8 DOPEN + u16 idx двери             (открыть/закрыть)
-- ============================================================

util.AddNetworkString("P11_Dsp")

local NET = "P11_Dsp"

local DOOR_CLASSES = {
    prop_door_rotating = true,
    func_door          = true,
    func_door_rotating = true,
}

-- Арсенал Центра (ARC9 EFT; фолбэки на HL2-сток — как в сидах орлов)
local CATALOG = {
    { name = "MP5A3",   entry = { "arc9_eft_mp5", "weapon_smg1" } },
    { name = "UMP-45",  entry = { "arc9_eft_ump45", "arc9_eft_ump", "weapon_smg1" } },
    { name = "M4A1",    entry = { "arc9_eft_m4a1", "weapon_ar2" } },
    { name = "M1A",     entry = { "arc9_eft_m1a", "weapon_ar2" } },
    { name = "SA-58",   entry = { "arc9_eft_sa58", "weapon_ar2" } },
    { name = "M700",    entry = { "arc9_eft_m700", "weapon_crossbow" } },
    { name = "Rem 870", entry = { "arc9_eft_m870", "weapon_shotgun" } },
    { name = "M1911A1", entry = { "arc9_eft_m1911a1", "weapon_pistol" } },
}

local CD = { hp = 30, armor = 30, weapon = 60, mark = 25, signal = 20, door = 0.8 }

-- ============ ДОПУСК ============

local function IsAdm(ply)
    return P11FW and P11FW.GetRankLevel and P11FW.GetRankLevel(ply) >= 4
end

function POLUS11.CanDispatch(ply)
    if not (IsValid(ply) and ply:IsPlayer() and ply:Alive()) then return false end
    if IsAdm(ply) then return true end
    return P11FW.GetJobId and P11FW.GetJobId(ply) == "seed_eagle_dispatcher"
end

local function IsEagle(p)
    if not (P11FW and P11FW.GetJob) then return false end
    local j = P11FW.GetJob(p)
    local f = istable(j) and (j.faction or j.category) or nil
    return f == "eagle"
end

-- ============ ОТВЕТЫ КЛИЕНТУ ============

local function Reply(ply, msg)
    net.Start(NET)
        net.WriteUInt(3, 4)
        net.WriteString(msg)
    net.Send(ply)
end

local function ForceExit(ply, why)
    net.Start(NET)
        net.WriteUInt(2, 4)
        net.WriteString(why or "")
    net.Send(ply)
end

-- ============ ДВЕРИ ============

local doorCache, doorCacheT = {}, 0
local function Doors()
    if CurTime() < doorCacheT and #doorCache > 0 then return doorCache end
    doorCache = {}
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and DOOR_CLASSES[ent:GetClass()] then
            doorCache[#doorCache + 1] = ent
        end
    end
    table.sort(doorCache, function(a, b) return a:EntIndex() < b:EntIndex() end)
    doorCacheT = CurTime() + 5
    return doorCache
end

local DoorState = {} -- [door] = { locked = bool, open = bool }

local function SendDoors(ply)
    local list = Doors()
    net.Start(NET)
        net.WriteUInt(4, 4)
        net.WriteUInt(math.min(#list, 65535), 16)
        for i = 1, #list do
            local d  = list[i]
            local st = DoorState[d] or {}
            local nm = d:GetName()
            if not isstring(nm) or nm == "" then nm = "ДВЕРЬ #" .. i end
            net.WriteString(nm)
            net.WriteBool(st.locked and true or false)
            net.WriteBool(st.open and true or false)
        end
    net.Send(ply)
end

-- ============ СЕССИИ ============

local Sessions = {} -- [ply] = { term = ent, cds = {} }

function POLUS11.DispatchClose(ply, why)
    if not IsValid(ply) then return end
    if not Sessions[ply] then return end
    Sessions[ply] = nil
    ply:Freeze(false)
    ForceExit(ply, why or "Сеанс диспетчера завершён.")
    if P11FW and P11FW.Log then
        P11FW.Log("ГЛАЗ: " .. ply:Nick() .. " — выход из терминала" ..
            (why and (" (" .. why .. ")") or ""))
    end
end

function POLUS11.DispatchDrop(ply) -- тихий срыв: смерть/дисконнект/смена допуска
    if not IsValid(ply) then Sessions[ply] = nil return end
    if Sessions[ply] then
        Sessions[ply] = nil
        ply:Freeze(false)
    end
end

function POLUS11.DispatchUse(ply, term)
    if not (IsValid(ply) and IsValid(term)) then return end

    if Sessions[ply] then -- повторный E — выйти
        POLUS11.DispatchClose(ply, "Сам встал из-за пульта.")
        return
    end
    if ply:GetPos():DistToSqr(term:GetPos()) > 170 * 170 then
        if POLUS11.Notify then POLUS11.Notify(ply, "Подойди к терминалу вплотную.") end
        return
    end
    if not POLUS11.CanDispatch(ply) then
        if POLUS11.Notify then
            POLUS11.Notify(ply, "Доступ к «ГЛАЗУ» — у Диспетчера «Красного Орла» (вайтлист) или у администрации 4+.")
        end
        return
    end

    Sessions[ply] = { term = term, cds = {}, since = CurTime(), ready = false } -- v4.19.2: READY-рукопожатие
    ply:Freeze(true)

    net.Start(NET)
        net.WriteUInt(1, 4) -- OPEN
    net.Send(ply)
    SendDoors(ply)

    if POLUS11.Notify then
        POLUS11.Notify(ply, "Сеанс «ГЛАЗА» открыт: [A/D] — переключение, [SPACE] — камеры/люди, [E] — выход.")
    end
    if P11FW and P11FW.Log then
        P11FW.Log("ГЛАЗ: " .. ply:Nick() .. " сел за терминал диспетчера")
    end
end

-- надзор за сеансами: терминал снесли / отошёл / умер / допуск снят
timer.Create("P11.DspWatchdog", 1, 0, function()
    for ply, s in pairs(Sessions) do
        if not (IsValid(ply) and ply:Alive()) then
            POLUS11.DispatchDrop(ply)
        elseif not s.ready and (s.since or 0) > 0 and CurTime() > s.since + 3 then
            -- v4.19.2 «ШЛЮЗ» (заявка «из терминала не выйти»): пульт на
            -- клиенте не поднялся (модуль не доехал или дал ошибку), а
            -- тело морожено — заморозка сама отпускает за 3 секунды
            POLUS11.DispatchDrop(ply)
            if POLUS11.Notify then
                POLUS11.Notify(ply, "Пульт «ГЛАЗА» не откликнулся с твоей стороны — сеанс сорван, руки свободны. Повторится — глянь клиентскую консоль (строки [POLUS]).")
            end
            if P11FW and P11FW.Log then
                P11FW.Log("ГЛАЗ: сеанс " .. ply:Nick() .. " сорван молчанием пульта (READY не пришёл за 3 сек)")
            end
        elseif not IsValid(s.term) then
            POLUS11.DispatchClose(ply, "Терминал утрачен — сеанс закрыт.")
        elseif ply:GetPos():DistToSqr(s.term:GetPos()) > 200 * 200 then
            POLUS11.DispatchClose(ply, "Отошёл от терминала — сеанс закрыт.")
        elseif not POLUS11.CanDispatch(ply) then
            POLUS11.DispatchClose(ply, "Допуск «ГЛАЗА» отозван — сеанс закрыт.")
        end
    end
end)

hook.Add("PlayerDisconnected", "P11.DspDC", function(ply)
    Sessions[ply] = nil
end)
hook.Add("OnPlayerChangedTeam", "P11.DspTeam", function(ply)
    if Sessions[ply] then POLUS11.DispatchDrop(ply) end
end)
hook.Add("PlayerDeath", "P11.DspDeath", function(ply)
    if Sessions[ply] then POLUS11.DispatchDrop(ply) end
end)

-- в сеансе: ни стрельбы, ни ходьбы, ни смены оружия (руки на пульте)
hook.Add("PlayerSwitchWeapon", "P11.DspNoWep", function(ply)
    if Sessions[ply] then return true end
end)
hook.Add("SetupMove", "P11.DspLockMove", function(ply, mv)
    if not Sessions[ply] then return end
    mv:SetButtons(0)
    mv:SetForwardSpeed(0)
    mv:SetSideSpeed(0)
    mv:SetUpSpeed(0)
end)

-- ============ ВЫДАЧА ============

local function TargetOf(idx)
    local t = Entity(tonumber(idx) or 0)
    if IsValid(t) and t:IsPlayer() and t:Alive() then return t end
    return nil
end

local function CDok(ply, kind)
    local s = Sessions[ply]
    if not s then return false end
    s.cds[kind] = s.cds[kind] or 0
    if CurTime() < s.cds[kind] then
        Reply(ply, "ГЛАЗ: канал перезаряжается ещё " .. math.ceil(s.cds[kind] - CurTime()) .. " сек.")
        return false
    end
    s.cds[kind] = CurTime() + (CD[kind] or 1)
    return true
end

local function LogLine(ply, txt)
    if P11FW and P11FW.Log then
        P11FW.Log("ГЛАЗ: " .. ply:Nick() .. " → " .. txt)
    end
end

-- ============ ПРИЁМ КОМАНД ============

net.Receive(NET, function(len, ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return end
    ply.P11_DspNext = ply.P11_DspNext or 0
    if CurTime() < ply.P11_DspNext then return end
    ply.P11_DspNext = CurTime() + 0.25

    local op = net.ReadUInt(4)

    if op == 1 then -- просится выйти
        if Sessions[ply] then
            POLUS11.DispatchClose(ply, "Сам встал из-за пульта.")
        end
        return
    end

    if not Sessions[ply] then return end -- ниже — только с живого пульта

    if op == 9 then -- READY: пульт клиента жив (рукопожатие v4.19.2 против «не выйти»)
        Sessions[ply].ready = true
        return
    end

    if op == 2 then -- медпомощь +25 ХП
        local t = TargetOf(net.ReadUInt(16))
        if not t then Reply(ply, "Цели нет в эфире.") return end
        if not CDok(ply, "hp") then return end
        local mx = t.GetMaxHealth and t:GetMaxHealth() or 100
        t:SetHealth(math.min(mx, t:Health() + 25))
        if POLUS11.Notify then POLUS11.Notify(t, "📡 ЦЕНТР: полевая медпомощь — +25 ХП.") end
        Reply(ply, "ЦЕНТР → «" .. t:Nick() .. "»: +25 ХП.")
        LogLine(ply, "медпомощь (+25 ХП) для " .. t:Nick())

    elseif op == 3 then -- бронежилет +50
        local t = TargetOf(net.ReadUInt(16))
        if not t then Reply(ply, "Цели нет в эфире.") return end
        if not CDok(ply, "armor") then return end
        t:SetArmor(math.min(255, t:Armor() + 50))
        if POLUS11.Notify then POLUS11.Notify(t, "📡 ЦЕНТР: бронежилет доставлен — +50.") end
        Reply(ply, "ЦЕНТР → «" .. t:Nick() .. "»: +50 брони.")
        LogLine(ply, "бронежилет (+50) для " .. t:Nick())

    elseif op == 4 then -- ствол из каталога Центра
        local t  = TargetOf(net.ReadUInt(16))
        local wi = tonumber(net.ReadUInt(8)) or 0
        local item = CATALOG[wi]
        if not t then Reply(ply, "Цели нет в эфире.") return end
        if not item then Reply(ply, "Позиции нет в каталоге.") return end
        if not CDok(ply, "weapon") then return end
        local cls = POLUS11.ResolveWeaponClass and POLUS11.ResolveWeaponClass(item.entry) or nil
        if not cls then
            Reply(ply, "«" .. item.name .. "» недоступна: нет пака EFT и стокового ствола.")
            return
        end
        local w = t:Give(cls)
        if IsValid(w) and w.GetPrimaryAmmoType then
            local am = w:GetPrimaryAmmoType()
            if am and am >= 0 then t:GiveAmmo(120, am, true) end
        end
        if POLUS11.Notify then POLUS11.Notify(t, "📡 ЦЕНТР: тайник вскрыт — «" .. item.name .. "».") end
        Reply(ply, "ЦЕНТР → «" .. t:Nick() .. "»: «" .. item.name .. "» (" .. cls .. ").")
        LogLine(ply, "выдача «" .. item.name .. "» (" .. tostring(cls) .. ") для " .. t:Nick())

    elseif op == 5 then -- маяк цели: 60 сек видят все орлы
        local t = TargetOf(net.ReadUInt(16))
        if not t then Reply(ply, "Цели нет в эфире.") return end
        if not CDok(ply, "mark") then return end
        t:SetNWFloat("P11_DspMark", CurTime() + 60)
        Reply(ply, "Маяк на «" .. t:Nick() .. "»: 60 сек — в поле зрения всех орлов.")
        LogLine(ply, "маяк цели на " .. t:Nick())

    elseif op == 6 then -- сигнал в эфир всем орлам
        if not CDok(ply, "signal") then return end
        local msg = "📡 ЦЕНТР (диспетчер «" .. ply:Nick() .. "»): проверка связи — держать курс."
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and IsEagle(p) then p:ChatPrint(msg) end
        end
        Reply(ply, "Сигнал ушёл всем орлам в эфире.")
        LogLine(ply, "сигнал орлам")

    elseif op == 7 then -- дверь: блок / разблок
        local i = tonumber(net.ReadUInt(16)) or 0
        if not CDok(ply, "door") then return end
        local d = Doors()[i]
        if not IsValid(d) then Reply(ply, "Дверь больше не существует.") return end
        local st = DoorState[d] or {}
        DoorState[d] = st
        st.locked = not st.locked
        local ok = pcall(function()
            d:Fire(st.locked and "Lock" or "Unlock")
        end)
        doorCacheT = 0
        SendDoors(ply)
        if ok then
            Reply(ply, st.locked and ("ДВЕРЬ #" .. i .. " — ЗАБЛОКИРОВАНА.")
                                or  ("ДВЕРЬ #" .. i .. " — разблокирована."))
            LogLine(ply, "дверь #" .. i .. (st.locked and " ЗАБЛОКИРОВАНА" or " разблокирована"))
        else
            Reply(ply, "Дверь #" .. i .. " не приняла команду (нет входа Lock/Unlock).")
        end

    elseif op == 8 then -- дверь: открыть / закрыть
        local i = tonumber(net.ReadUInt(16)) or 0
        if not CDok(ply, "door") then return end
        local d = Doors()[i]
        if not IsValid(d) then Reply(ply, "Дверь больше не существует.") return end
        local st = DoorState[d] or {}
        DoorState[d] = st
        st.open = not st.open
        local ok = pcall(function()
            d:Fire(st.open and "Open" or "Close")
        end)
        doorCacheT = 0
        SendDoors(ply)
        if ok then
            Reply(ply, st.open and ("ДВЕРЬ #" .. i .. " — открыта.")
                                or  ("ДВЕРЬ #" .. i .. " — закрыта."))
            LogLine(ply, "дверь #" .. i .. (st.open and " открыта" or " закрыта"))
        else
            Reply(ply, "Дверь #" .. i .. " не приняла команду (нет входа Open/Close).")
        end
    end
end)

-- ============ ЗАПАСНЫЕ ДВЕРИ ВЫХОДА (v4.19.2 «ШЛЮЗ») ============

-- чатовая (если чат-ядро пропустит сигнал до нас — молча отработает)
hook.Add("PlayerSay", "P11.DspSayExit", function(ply, text)
    if not Sessions[ply] then return end
    local t = tostring(text or "")
    t = string.gsub(t, "^%s*(.-)%s*$", "%1")
    if string.find(t, "!вых", 1, true) or string.find(t, "/вых", 1, true)
        or string.find(t, "!ВЫХ", 1, true) or string.find(t, "!exit", 1, true)
        or string.find(t, "!глаз выход", 1, true) then
        POLUS11.DispatchClose(ply, "Вышел чатовой командой.")
        return ""
    end
end)

-- железная консольная: консоль открывается даже из морозилки
concommand.Add("p11_dspxit", function(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return end
    if Sessions[ply] then
        POLUS11.DispatchClose(ply, "Вышел консольной командой.")
    end
end)

print("[POLUS-11] «ГЛАЗ»: диспетчер-камеры Красных Орлов v4.19.2 «ШЛЮЗ»")
