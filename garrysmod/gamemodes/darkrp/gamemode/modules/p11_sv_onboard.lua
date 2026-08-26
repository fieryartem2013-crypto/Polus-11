-- ============================================================
--  ПОЛЮС-11 — ОНБОРДИНГ «ПЕРВЫЙ ДЕНЬ» (server) v4.20.0 «СЛЕД»
--  Заявка владельца (банк аналитики №6 — «ПЕРВЫЙ ДЕНЬ»):
--  «5 поручений новичку (ларёк → профа → анализ → нарядник),
--   с наградой пайком и ₽ — удержание первого часа».
--
--  КАК ЖИВЁТ:
--   • новичок = наиграно меньше 4 часов (POLUS11.GetPlayMin) и
--     цепочка ещё не закрыта (сейв polus11/onboard.json);
--   • 5 живых шагов на штатных событиях станции (цепь TaskEvent):
--       ① должность (job_taken)      → 300₽ + горячий паёк
--       ② покупка в ларьке (shop_buy) → 300₽
--       ③ обыск ящика (loot_find)     → 300₽
--       ④ взять наряд (contract_take) → 400₽
--       ⑤ закрыть наряд (contract_done)→ 1500₽
--   • прогресс у новичка — HUD-плашка справа (NWInt P11_OnbStep:
--     0 скрыто, 1..5 шаг, 6 — пройдено и погашено);
--   • грузится ПОСЛЕ контрактов — contract_take/contract_done
--     доезжают по общей цепи без правок чужих звеньев.
-- ============================================================

local FILE        = "polus11/onboard.json"
local HOURS_LIMIT = 240 -- минут стажа (4 ч): дальше «ПЕРВЫЙ ДЕНЬ» не предлагаем
local STEP_LAST   = 5

POLUS11.OnboardSteps = {
    [1] = { key = "job_taken",     name = "Возьми должность (F4 или кадровик)",            pay = 300,  give = { ration = 1 } },
    [2] = { key = "shop_buy",      name = "Купи товар в ларьке снабжения (E по торговцу)", pay = 300 },
    [3] = { key = "loot_find",     name = "Обыщи ящик/бочку/тайник по станции",            pay = 300 },
    [4] = { key = "contract_take", name = "Возьми наряд у интенданта (стойка «НАРЯДНИК»)", pay = 400 },
    [5] = { key = "contract_done", name = "Закрой взятый наряд до конца",                  pay = 1500 },
}

POLUS11.Onboard = POLUS11.Onboard or {} -- [sid] = { step = 1..6, done = bool }

local function OnbSave()
    if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
    file.Write(FILE, util.TableToJSON(POLUS11.Onboard, true) or "{}")
end

local function OnbLoad()
    local raw = file.Read(FILE, "DATA")
    if not raw then return end
    local ok, tbl = pcall(util.JSONToTable, raw)
    if ok and istable(tbl) then POLUS11.Onboard = tbl end
end

hook.Add("InitPostEntity", "P11.OnbLoad", function() timer.Simple(1.8, OnbLoad) end)
hook.Add("PlayerDisconnected", "P11.OnbBye", OnbSave)

-- ============ ДОПУСК ============
function POLUS11.OnbEligible(ply)
    if not IsValid(ply) then return false end
    local st = POLUS11.Onboard[ply:SteamID()]
    if st and st.done then return false end
    local mins = (POLUS11.GetPlayMin and POLUS11.GetPlayMin(ply)) or 0
    return mins < HOURS_LIMIT
end

local function OnbState(ply)
    local sid = ply:SteamID()
    local st = POLUS11.Onboard[sid]
    if not st then
        st = { step = 1, done = false }
        POLUS11.Onboard[sid] = st
    end
    return st
end

local function OnbSync(ply)
    if not IsValid(ply) then return end
    local st = POLUS11.Onboard[ply:SteamID()]
    local show = 0
    if POLUS11.OnbEligible(ply) then
        show = math.floor(tonumber(st and st.step) or 1)
    elseif st and st.done then
        show = 6 -- пройдено: клиент гасит плашку
    end
    ply:SetNWInt("P11_OnbStep", show)
end

hook.Add("PlayerInitialSpawn", "P11.OnbJoin", function(ply)
    timer.Simple(10, function()
        if not IsValid(ply) then return end
        if POLUS11.OnbEligible(ply) then
            local st = OnbState(ply)
            if (tonumber(st.step) or 1) <= 1 then
                POLUS11.Notify(ply, "ПЕРВЫЙ ДЕНЬ на «Полюсе-11»? Держи план из 5 шагов (плашка справа). За каждый — деньги, за весь план — 1500₽. Удачи, боец.")
            end
        end
        OnbSync(ply)
    end)
end)

-- ============ ЗАКРЫТИЕ ШАГА ============
local function OnbAdvance(ply, st)
    local def = POLUS11.OnboardSteps[st.step]
    if not def then return end

    if def.give and POLUS11.InvOf then
        local data = POLUS11.InvOf(ply)
        if data then
            for id, n in pairs(def.give) do
                data.items[id] = (data.items[id] or 0) + n
            end
            if POLUS11.InvSaveNow then POLUS11.InvSaveNow() end
            if POLUS11.InvSync then POLUS11.InvSync(ply) end
        end
    end
    if POLUS11.AddMoney then
        POLUS11.AddMoney(ply, def.pay, "ПЕРВЫЙ ДЕНЬ: шаг " .. st.step .. "/" .. STEP_LAST)
    end
    ply:EmitSound("buttons/button15.wav", 65, 108)

    if st.step >= STEP_LAST then
        st.done = true
        st.step = STEP_LAST + 1
        POLUS11.Notify(ply, "«ПЕРВЫЙ ДЕНЬ» пройден ЦЕЛИКОМ! Теперь ты полноценный боец Полюса: держись тех, кому доверяешь, и помни — огонь не лжёт.")
        ply:ChatPrint("[ПОЛЮС-11] Онбординг закрыт 5/5 — добро пожаловать в гарнизон.")
        POLUS11.Log("ОНБОРДИНГ: " .. ply:Nick() .. " (" .. ply:SteamID() .. ") прошёл «ПЕРВЫЙ ДЕНЬ» целиком")
    else
        st.step = st.step + 1
        local nxt = POLUS11.OnboardSteps[st.step]
        POLUS11.Notify(ply, "ПЕРВЫЙ ДЕНЬ " .. (st.step - 1) .. "/" .. STEP_LAST ..
            " — готово (+" .. def.pay .. "₽). Дальше: " .. (nxt and nxt.name or "") .. ".")
    end
    OnbSave()
    OnbSync(ply)
end

function POLUS11.OnbEvent(ply, key)
    if not POLUS11.OnbEligible(ply) then return end
    local st = OnbState(ply)
    if st.done then return end
    local def = POLUS11.OnboardSteps[math.floor(tonumber(st.step) or 1)]
    if def and def.key == key then
        OnbAdvance(ply, st)
    end
end

do
    local base = POLUS11.TaskEvent
    POLUS11.TaskEvent = function(ply, key, add)
        if base then base(ply, key, add) end
        POLUS11.OnbEvent(ply, key)
    end
end

-- стаж перевалил 4 часа посреди сессии — плашку гасим тихо
timer.Create("P11.OnbWatcher", 120, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        local st = POLUS11.Onboard[ply:SteamID()]
        if st and not st.done and POLUS11.GetPlayMin and POLUS11.GetPlayMin(ply) >= HOURS_LIMIT then
            st.done = true
            ply:SetNWInt("P11_OnbStep", 6)
            OnbSave()
        end
    end
end)

print("[POLUS-11] онбординг «ПЕРВЫЙ ДЕНЬ» v4.20.0: 5 шагов новичку, плашка справа, сейв polus11/onboard.json")
