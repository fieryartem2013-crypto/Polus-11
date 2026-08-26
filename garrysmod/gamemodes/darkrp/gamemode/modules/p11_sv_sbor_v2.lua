-- ============================================================
--  ПОЛЮС-11 — ЭКСТРЕННЫЙ СБОР (server) v5.8.29 «СБОР-2» (НОВЫЙ ФАЙЛ)
--  Копия v5.0.0 + ДВА исправленных места:
--    1) concommand p11_sbor — аргументы (была ошибка компиляции);
--    2) PlayerSay !сбор — сравнение по БАЙТАМ UTF-8 (команда не ловилась).
--  Старый p11_sv_sbor.lua НЕ удалён (сувенир) и вынут из списка загрузки.
--  Заявка владельца: «ЭКСТРЕННЫЙ СБОР (!сбор) — для сборов
--  причина и место».
--  Любой боец объявляет:  /сбор <причина>   (или !сбор / !сбор <причина>)
--  • Место сбора фиксируется ТАМ, ГДЕ СТОИТ объявивший;
--  • Все игроки видят баннер с ПРИЧИНОЙ и маркер-стрелку к месту
--    (HUD + маяк над точкой), таймер 60 сек;
--  • Кто пришёл в радиус 400 юн — «на сборе», отмечается;
--  • Итог переклички: «На сборе X из Y» + список явившихся;
--  • Объявившему и явившимся — отметка дела (rollcall).
--  Антиспам: 1 сбор на игрока в 90 сек, максимум 3 сбора одновременно.
-- ============================================================

util.AddNetworkString("P11_SborState")  -- S2C: состояние сбора (баннер/маркер)
util.AddNetworkString("P11_SborResult") -- S2C: итог переклички

POLUS11.Sbor = POLUS11.Sbor or {}

local SBOR_TIME  = 60    -- секунд на сбор
local SBOR_RAD   = 400   -- радиус «пришёл на сбор»
local SBOR_CD    = 90    -- антиспам между сборами одного игрока
local SBOR_MAX   = 3     -- максимум одновременных сборов

local function SborCleanup()
    local out = {}
    for _, s in ipairs(POLUS11.Sbor.list or {}) do
        if s and s.untilT > CurTime() then out[#out + 1] = s end
    end
    POLUS11.Sbor.list = out
end

local function SborBroadcast()
    SborCleanup()
    local list = {}
    for _, s in ipairs(POLUS11.Sbor.list or {}) do
        list[#list + 1] = {
            reason = s.reason,
            x = s.pos.x, y = s.pos.y, z = s.pos.z,
            by = s.byName,
            left = math.max(0, math.ceil(s.untilT - CurTime())),
        }
    end
    net.Start("P11_SborState")
        net.WriteString(util.TableToJSON(list) or "[]")
    net.Broadcast()
end

-- кто сейчас в радиусе сбора
local function SborPresent(s)
    local out = {}
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:Alive() then
            if p:GetPos():DistToSqr(s.pos) <= SBOR_RAD * SBOR_RAD then
                out[#out + 1] = p
            end
        end
    end
    return out
end

function POLUS11.SborDeclare(ply, reason)
    if not IsValid(ply) or not ply:Alive() then
        POLUS11.Notify(ply, "Сбор объявляют на ногах.")
        return false
    end
    reason = string.sub(string.Trim(tostring(reason or "")), 1, 80)
    if reason == "" then reason = "экстренная перекличка" end

    -- антиспам
    ply.P11_SborCD = ply.P11_SborCD or 0
    if CurTime() < ply.P11_SborCD then
        POLUS11.Notify(ply, "Сбор уже собирали недавно. Подожди " ..
            math.ceil(ply.P11_SborCD - CurTime()) .. " сек.")
        return false
    end
    SborCleanup()
    if #(POLUS11.Sbor.list or {}) >= SBOR_MAX then
        POLUS11.Notify(ply, "На станции уже идёт " .. SBOR_MAX .. " сбора — дождись конца.")
        return false
    end

    ply.P11_SborCD = CurTime() + SBOR_CD
    POLUS11.Sbor.list = POLUS11.Sbor.list or {}
    POLUS11.Sbor.list[#POLUS11.Sbor.list + 1] = {
        reason = reason,
        pos    = ply:GetPos(),
        by     = ply,
        byName = ply:Nick(),
        untilT = CurTime() + SBOR_TIME,
    }

    -- громкое объявление
    net.Start("P11_Announce")
        net.WriteString("⚠ ЭКСТРЕННЫЙ СБОР: " .. reason .. " — место: " .. ply:Nick())
        net.WriteString("СБОР")
    net.Broadcast()
    PrintMessage(HUD_PRINTTALK, "[ГРОМКОГОВОРИТЕЛЬ] " .. ply:Nick() .. " объявляет СБОР: «" .. reason ..
        "». Явиться к месту объявления (" .. SBOR_TIME .. " сек)!")
    for _, p in ipairs(player.GetAll()) do
        p:EmitSound("ambient/alarms/warningbell1.wav", 60, 85)
    end
    POLUS11.Log("СБОР: объявил " .. ply:Nick() .. " — «" .. reason .. "»")
    SborBroadcast()
    return true
end

-- тик: следим за сборами, подводим итоги
timer.Create("P11.SborTick", 1, 0, function()
    SborCleanup()
    local list = POLUS11.Sbor.list or {}
    if #list == 0 then return end

    local finished = {}
    for i, s in ipairs(list) do
        if CurTime() >= s.untilT then finished[#finished + 1] = i end
    end
    -- подводим итоги с конца, чтобы индексы не съезжали
    for i = #finished, 1, -1 do
        local s = table.remove(list, finished[i])
        local present = SborPresent(s)
        local names = {}
        for _, p in ipairs(present) do
            names[#names + 1] = p:Nick()
            -- явившимся — отметка дела (rollcall)
            if POLUS11.TaskEvent then POLUS11.TaskEvent(p, "rollcall") end
        end
        local msg = "СБОР ЗАВЕРШЁН: «" .. s.reason .. "» — явились " .. #present ..
            " из " .. #player.GetAll() .. ( #names > 0 and (": " .. table.concat(names, ", ")) or "" )
        PrintMessage(HUD_PRINTTALK, msg)
        POLUS11.Log("СБОР ИТОГ: «" .. s.reason .. "» — " .. #present .. " из " .. #player.GetAll())

        -- результат лично каждому (виден и объявившему)
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) then
                net.Start("P11_SborResult")
                    net.WriteString(s.reason)
                    net.WriteString(s.byName)
                    net.WriteUInt(#present, 8)
                    net.WriteUInt(#player.GetAll(), 8)
                    net.WriteString(table.concat(names, ", "))
                net.Send(p)
            end
        end
    end
    if #finished > 0 then SborBroadcast() end
end)

-- /сбор <причина> и !сбор [причина]
-- v5.8.29 «СБОР-2»: КОРЕНЬ БАГА — здесь было `function(ply)` и `{...}`
-- внутри. В Lua 5.1/LuaJIT `...` вне vararg-функции — ОШИБКА КОМПИЛЯЦИИ,
-- поэтому весь модуль p11_sv_sbor.lua не грузился ВООБЩЕ (сбор мёртв
-- с v5.0.0). Теперь аргументы приходят штатным третьим параметром.
concommand.Add("p11_sbor", function(ply, cmd, args)
    if not IsValid(ply) then return end
    local reason = table.concat(args or {}, " ")
    POLUS11.SborDeclare(ply, reason)
end)

-- v5.8.29: ВТОРОЙ КОРЕНЬ БАГА — string.sub в Lua 5.1 режет БАЙТЫ, а не символы.
-- «!сбор» в UTF-8 = 9 байт, поэтому string.sub(t, 1, 5) давало «!сб» и условие
-- НЕ срабатывало никогда: !сбор / /сбор из чата просто уходили в OOC.
-- Работала только консольная p11_sbor.
local SBOR_WORDS = { "!сбор", "/сбор" }
hook.Add("PlayerSay", "P11.SborChat", function(ply, text)
    local raw = string.Trim(tostring(text or ""))
    local t = string.lower(raw)
    for _, w in ipairs(SBOR_WORDS) do
        if string.sub(t, 1, #w) == w then
            -- «!сборка» — это КРАФТ, а не сбор: дальше должен быть пробел или конец
            local tail = string.sub(t, #w + 1)
            if tail == "" or string.sub(tail, 1, 1) == " " then
                POLUS11.SborDeclare(ply, string.Trim(string.sub(raw, #w + 1)))
                return ""
            end
        end
    end
end)

print("[POLUS-11] ЭКСТРЕННЫЙ СБОР v5.0.0 «СБОР»: /сбор <причина> · !сбор · место = где стоишь · 60 сек · итог переклички")
