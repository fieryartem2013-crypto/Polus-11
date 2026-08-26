-- ============================================================
--  ПОЛЮС-11 — «ОСОБАЯ ВАКАНСИЯ» У КАДРОВИКА (server) v3.9
--  Нечто теперь БЕРЁТСЯ С NPC: время от времени у кадровика
--  открывается «особая вакансия» — красная строка над головой,
--  объявление в чат. ПЕРВЫЙ, кто нажмёт E по кадровику в окно,
--  тихо заражается (активация через пару секунд, как обычный
--  инкубант... только быстрее). Вакансия тут же закрывается,
--  никто не знает, КТО её взял. Не успели — окно схлопывается
--  и появится позже. Активное Нечто на сервере не плодится:
--  одна вакансия = один хищник.
--  Ручной p11_offer (админ) — форс-открыть окно для ивента.
--  Настройки — POLUS11.Config.ThingOffer* в p11_sh_config.lua.
-- ============================================================

local NPC_CLASS = "polus_fw_jobnpc"

local function Cfg()
    local c = POLUS11.Config or {}
    return {
        on     = c.ThingOfferEnabled ~= false,
        gapMin = tonumber(c.ThingOfferGapMin) or 240,
        gapMax = tonumber(c.ThingOfferGapMax) or 480,
        window = tonumber(c.ThingOfferWindow) or 90,
    }
end

local P = P11_ThingOffer or {} -- модуль-состояние (переживает autorefresh)
P11_ThingOffer = P

local function Now() return CurTime() end

function POLUS11.ThingOfferActive()
    return Now() < (GetGlobalFloat("P11_ThingOfferUntil", 0))
end

-- есть ли на сервере АКТИВНОЕ (проявившееся) Нечто
function POLUS11.ActiveThingExists()
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:GetNWBool("P11_Infected", false)
            and p:GetNWBool("P11_InfActive", false) then
            return true
        end
    end
    return false
end

function POLUS11.ThingOfferOpen(manual)
    if POLUS11.ThingOfferActive() then return end
    if POLUS11.ActiveThingExists() then
        -- уже охотится — вакансия бессмысленна, передвинем плановую
        P.NextOffer = Now() + math.random(Cfg().gapMin, Cfg().gapMax)
        return
    end
    local cfg = Cfg()
    SetGlobalFloat("P11_ThingOfferUntil", Now() + cfg.window)
    P.NextOffer = nil
    PrintMessage(HUD_PRINTTALK, "[КАДРЫ] Поступила ОСОБАЯ ВАКАНСИЯ — подойди к КАДРОВИКУ и нажми [E]. "
        .. "Действует " .. cfg.window .. " сек.")
    -- v4.8.8 «ЛИЧИНА»: красная плашка над кадровиком рисует клиент
    -- (p11_cl_thingoffer), а сервер дополнительно НАПОМИНАЕТ раз в 20 сек
    timer.Remove("P11_ThingOfferRemind")
    local reps = math.max(1, math.floor(cfg.window / 20) - 1)
    timer.Create("P11_ThingOfferRemind", 20, reps, function()
        if not POLUS11.ThingOfferActive() then return end
        PrintMessage(HUD_PRINTTALK, "[КАДРЫ] Особая вакансия всё ещё ОТКРЫТА — красная плашка над кадровиком. Осталось "
            .. math.ceil(GetGlobalFloat("P11_ThingOfferUntil", 0) - CurTime()) .. " сек.")
    end)
    POLUS11.Log("Вакансия Нечто открыта" .. (manual and " (вручную)" or ""))
    print("[КАДРЫ] ОСОБАЯ ВАКАНСИЯ открыта: " .. cfg.window .. " сек (p11_offerdiag — состояние)")
end

local function ThingOfferClose(reason)
    if not POLUS11.ThingOfferActive() then return end
    SetGlobalFloat("P11_ThingOfferUntil", 0)
    timer.Remove("P11_ThingOfferRemind")
    POLUS11.Log("Вакансия Нечто закрыта: " .. (reason or "истекла"))
end

-- v4.9.3 «ГРОШ»: ВЗЯТИЕ ВАКАНСИИ УНИФИЦИРОВАНО (жалоба «не могут
-- брать Нечто даже при ивенте у кадровика»). Одна дверь (E по NPC)
-- теперь — ЧЕТЫРЕ двери в ОДНУ функцию:
--   1) E по кадровику (PlayerUse);
--   2) KeyPress E навстречу кадровику (страховка, ТОНЕТ ли движковый Use);
--   3) красная кнопка «ОСОБАЯ ВАКАНСИЯ» в F4 (net P11_VacancyTake —
--      её видно ТОЛЬКО в окно вакансии — отвечает заявке «не видят в F4»);
--   4) чат !вакансия / !взять + консоль p11_takeoffer (public).
-- Отказ всегда ОЗВУЧЕН причиной (так «не берётся» сразу объяснимо).
function POLUS11.ThingOfferTake(ply, via)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if not ply:Alive() then
        POLUS11.Notify(ply, "Мёртвому особые задания не полагаются.")
        return false
    end
    if not POLUS11.ThingOfferActive() then
        POLUS11.Notify(ply, "Особой вакансии сейчас НЕТ — жди красную плашку над кадровиком (или админскую p11_offer).")
        return false
    end
    if ply:GetNWBool("P11_Infected", false) then
        POLUS11.Notify(ply, "Ты уже носитель — вакансия не про тебя.")
        return false
    end
    if POLUS11.ActiveThingExists() then
        ThingOfferClose("кто-то уже проявился")
        POLUS11.Notify(ply, "Проявившееся Нечто уже охотится — вакансии больше нет.")
        return false
    end

    -- ===== ВЗЯЛИ ВАКАНСИЮ: тихое заражение с быстрой активацией =====
    ThingOfferClose("вакансия занята" .. (via and (" через " .. via) or ""))
    POLUS11.Infect(ply, "vacancy", true)
    ply.P11_Incubation = 2 -- активируется первым же тиком инкубации (~3 сек)
    ply.P11_InfectedAt = Now()

    PrintMessage(HUD_PRINTTALK, "[КАДРЫ] Особая вакансия закрыта.")
    POLUS11.Notify(ply, "Кадровик отводит взгляд и шепчет: «Особое задание принято... "
        .. "храните молчание». Тебя колотит изнутри.")
    POLUS11.Log(ply:Nick() .. " (" .. ply:SteamID() .. ") взял вакансию Нечто"
        .. (via and (" [" .. via .. "]") or ""))
    return true
end

-- дверь 1: E по кадровику
hook.Add("PlayerUse", "P11_ThingOfferUse", function(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    if ent:GetClass() ~= NPC_CLASS then return end
    if not POLUS11.ThingOfferActive() then return end
    if POLUS11.ThingOfferTake(ply, "E по кадровику") then
        return false -- меню должностей не открываем в этот момент
    end
end)

-- дверь 2: KeyPress E навстречу кадровику (если движковый Use где-то тонет)
hook.Add("KeyPress", "P11_ThingOfferKey", function(ply, key)
    if key ~= IN_USE then return end
    if not POLUS11.ThingOfferActive() then return end
    local tr = ply:GetEyeTrace()
    if not (tr and IsValid(tr.Entity) and tr.Entity:GetClass() == NPC_CLASS
        and tr.HitPos:DistToSqr(ply:GetPos()) < 200 * 200) then return end
    POLUS11.ThingOfferTake(ply, "KeyPress у кадровика")
end)

-- дверь 3: кнопка в F4 (клиент показывает её только в окно вакансии)
util.AddNetworkString("P11_VacancyTake")
net.Receive("P11_VacancyTake", function(_, ply)
    POLUS11.ThingOfferTake(ply, "кнопка F4")
end)

-- дверь 4: чат + консоль
hook.Add("PlayerSay", "P11_ThingOfferChat", function(ply, text)
    local raw = string.Trim(tostring(text or ""))
    local t = string.lower(raw)
    if t == "!вакансия" or t == "!взять" or t == "!take" then
        POLUS11.ThingOfferTake(ply, "чат")
        return ""
    end
    -- v4.15.2 «НАБОР»: чат-запуск ивента (ранг 4+): !ивент [стоп/статус] / !event [off/status]
    local w1 = string.match(t, "^(%S+)") or ""
    if w1 == "!ивент" or w1 == "!ИВЕНТ" or w1 == "!event" then
        local w2 = string.match(t, "^%S+%s+(%S+)") or ""
        EventSwitch(ply, w2)
        return ""
    end
end)
concommand.Add("p11_takeoffer", function(ply)
    if IsValid(ply) then POLUS11.ThingOfferTake(ply, "консоль") end
end)

-- планировщик: окно появляется раз в gapMin..gapMax сек, пустое — закрывается само
timer.Create("P11_ThingOfferTimer", 5, 0, function()
    if not Cfg().on then
        if POLUS11.ThingOfferActive() then ThingOfferClose("выключено в конфиге") end
        return
    end
    if POLUS11.ThingOfferActive() then return end

    P.NextOffer = P.NextOffer or (Now() + math.random(Cfg().gapMin, Cfg().gapMax))
    if Now() >= P.NextOffer then
        P.NextOffer = nil
        POLUS11.ThingOfferOpen(false)
    end
end)

-- v4.8.1: ДИАГНОСТИКА вакансии (владелец жаловался «не появляется»)
concommand.Add("p11_offerdiag", function(ply)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then return end
    local cfg = Cfg()
    local out = {
        "== ВАКАНСИЯ НЕЧТО: ДИАГНОСТИКА ==",
        "  включена: " .. tostring(cfg.on),
        "  окно открыто: " .. tostring(POLUS11.ThingOfferActive())
            .. (POLUS11.ThingOfferActive() and (" (ещё " .. math.ceil(GetGlobalFloat("P11_ThingOfferUntil", 0) - CurTime()) .. " сек)") or ""),
        "  активное Нечто есть: " .. tostring(POLUS11.ActiveThingExists()),
        "  следующая плановая: " .. (P.NextOffer and ("через " .. math.max(0, math.ceil(P.NextOffer - CurTime())) .. " сек") or "не назначена (сейчас окно/последняя закрылась)"),
        "  промежуток: " .. cfg.gapMin .. ".." .. cfg.gapMax .. " сек, окно: " .. cfg.window .. " сек",
    }
    local n = 0
    for _, ent in ipairs(ents.FindByClass(NPC_CLASS)) do
        n = n + 1
        out[#out + 1] = string.format("  кадровик #%d: стоит (%.0f, %.0f, %.0f)",
            n, ent:GetPos().x, ent:GetPos().y, ent:GetPos().z)
    end
    if n == 0 then
        out[#out + 1] = "  КАДРОВИКА НА КАРТЕ НЕТ! Поставь: /menu → УТИЛИТЫ → NPC кадровик (это и есть причина «нет вакансий»)."
    end
    local txt = table.concat(out, "\n")
    if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, txt) else print(txt) end
end)

-- v4.15.2 «НАБОР» (заявка: «сделай команду по активации ивента с нечто
-- и кадровиком»): ЯВНАЯ команда запуска/отмены ивента. Одна дверь для
-- консоли и чата. Гейт: Administrator (4)+ (замок консоли Главы 16 — снаружи).
local function EventSwitch(ply, arg)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then
        POLUS11.Notify(ply, "Только администрация (ранг 4+) управляет ивентом Нечто.")
        return false
    end
    arg = string.lower(string.Trim(tostring(arg or "")))
    local active = POLUS11.ThingOfferActive()
    local wantOpen  = (arg == "" and not active) or arg == "on" or arg == "open" or arg == "start"
        or arg == "1" or arg == "открыть" or arg == "старт" or arg == "да"
    local wantClose = arg == "off" or arg == "close" or arg == "stop" or arg == "0"
        or arg == "закрыть" or arg == "стоп" or arg == "нет"
    local wantStatus = arg == "status" or arg == "статус" or arg == "инфо"

    if wantStatus then
        local left = math.ceil(GetGlobalFloat("P11_ThingOfferUntil", 0) - CurTime())
        local msg = "ИВЕНТ НЕЧТО: " .. (active and ("ОТКРЫТ (окно ещё ~" .. left .. " сек)")
            or ("закрыт; плановая волна — раз в " .. (POLUS11.Config.ThingOfferGapMin or 900) ..
                "–" .. (POLUS11.Config.ThingOfferGapMax or 1800) .. " сек"))
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) ply:ChatPrint(msg) else print(msg) end
        return true
    end

    if wantClose or (arg == "" and active) then
        if not active then
            local msg = "ИВЕНТ НЕЧТО сейчас и так закрыт — отменять нечего."
            if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
            return true
        end
        ThingOfferClose("отменено ивент-командой")
        PrintMessage(HUD_PRINTTALK, "[КАДРЫ] Особая вакансия ОТОЗВАНА администрацией.")
        POLUS11.Log("ИВЕНТ НЕЧТО отменён вручную (" .. (IsValid(ply) and ply:Nick() or "RCON") .. ")")
        return true
    end

    if active then
        local left = math.ceil(GetGlobalFloat("P11_ThingOfferUntil", 0) - CurTime())
        local msg = "ИВЕНТ НЕЧТО уже открыт (окно ещё ~" .. left .. " сек) — «стоп» отзовёт."
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return true
    end
    SetGlobalFloat("P11_ThingOfferUntil", 0) -- сброс флага планировщика
    POLUS11.ThingOfferOpen(true)
    POLUS11.Log("ИВЕНТ НЕЧТО запущен вручную (" .. (IsValid(ply) and ply:Nick() or "RCON") .. ")")
    return true
end
POLUS11.ThingEventSwitch = EventSwitch

-- явная ивент-команда: p11_thingevent [on/off/status]
concommand.Add("p11_thingevent", function(ply, cmd, args)
    EventSwitch(ply, args and args[1] or "")
end, nil, "Ивент Нечто у кадровика: p11_thingevent on|off|status (без аргумента — переключить)")

-- админская форс-вакансия (для ивентов): p11_offer
concommand.Add("p11_offer", function(ply)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then
        POLUS11.Notify(ply, "Только администрация открывает вакансии.")
        return
    end
    if POLUS11.ThingOfferActive() then
        ThingOfferClose("отменено вручную p11_offer")
        PrintMessage(HUD_PRINTTALK, "[КАДРЫ] Особая вакансия отозвана.")
        return
    end
    SetGlobalFloat("P11_ThingOfferUntil", 0) -- сброс флага планировщика
    POLUS11.ThingOfferOpen(true)
end)

-- ============ v4.18.2 «ВЕРБОВКА»: ИВЕНТ КНОПКОЙ (ранг 4+, без консоли) ============
-- Заявка владельца: «сделай так, чтобы админы могли включать сами ивент
-- с кадровщиком на взятие Нечто». Консоль p11_thingevent резал замок
-- Главы (16) — теперь она открыта (PUBLIC), а для кнопки в F4 → АДМИН →
-- «ИВЕНТ НЕЧТО» работает прямой канал: query/on/off, статус — ответом.
util.AddNetworkString("P11_ThingEvent")

local function EventStatusReply(ply)
    local active = POLUS11.ThingOfferActive() and 1 or 0
    local left = (active == 1)
        and math.max(0, math.ceil(GetGlobalFloat("P11_ThingOfferUntil", 0) - CurTime())) or 0
    local nextIn = (active == 0 and P.NextOffer)
        and math.max(0, math.ceil(P.NextOffer - CurTime())) or 0
    net.Start("P11_ThingEvent")
        net.WriteUInt(active, 2)
        net.WriteUInt(math.Clamp(left, 0, 65535), 16)
        net.WriteUInt(math.Clamp(nextIn, 0, 65535), 16)
        net.WriteUInt(math.Clamp(Cfg().window, 0, 65535), 16)
        net.WriteUInt(math.Clamp(Cfg().gapMin, 0, 65535), 16)
        net.WriteUInt(math.Clamp(Cfg().gapMax, 0, 65535), 16)
    net.Send(ply)
end

net.Receive("P11_ThingEvent", function(len, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not P11FW.Config.Admin(ply) then
        POLUS11.Notify(ply, "Только администрация (ранг 4+) управляет ивентом Нечто.")
        return
    end
    ply.P11_ThingEventNext = ply.P11_ThingEventNext or 0
    if CurTime() < ply.P11_ThingEventNext then return end
    ply.P11_ThingEventNext = CurTime() + 0.4

    local act = net.ReadUInt(2)
    if act == 1 then
        EventSwitch(ply, "on")
    elseif act == 2 then
        EventSwitch(ply, "off")
    end
    EventStatusReply(ply)
end)

print("[POLUS-11] ИВЕНТ НЕЧТО v4.18.2 «ВЕРБОВКА»: админы (ранг 4+) включают сами — вкладка F4→АДМИН «ИВЕНТ НЕЧТО», p11_thingevent открыт замком, !ивент")

