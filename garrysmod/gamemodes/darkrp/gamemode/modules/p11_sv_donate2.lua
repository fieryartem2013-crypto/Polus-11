-- ============================================================
--  ПОЛЮС-11 — ДОНАТ-ВАЛЮТА «ПОЛЮС-ФЛЮКС» (server)
--  v4.10.0 «ГАРАЖ». Заявки владельца:
--   «добавь донат валюту», «много ассортимента в донат-меню»,
--   «меню утилит для выдачи этой донат валюты».
--
--  ЧТО ЭТО:
--   • «ПОЛЮС-ФЛЮКС» (ПФ) — валюта поддержки: платная сторона
--     живёт ВНЕ игры (СБП / CraftedStore — docs/DONATE.md), здесь
--     только учёт: баланс пишется в polus11/flux.json по SteamID64,
--     синхронится клиенту как NWInt «P11_Flux»;
--   • трата ПФ — в F6: витрина «ПОТРАТИТЬ ПОТОК» (9 позиций);
--   • выдача ПФ: консоль p11_fluxgive <SteamID|64> <сколько>
--     (серверная консоль/RCON магазина или Глава, ранг 16) —
--     онлайн начислится сразу, оффлайн дождётся входа;
--   • УТИЛИТ-МЕНЮ (rank ≥ 4): p11_utils — список бойцов онлайн,
--     кнопки +100/+500/−100 и произвольная сумма. Все движения
--     ПФ пишутся в журнал POLUS11.Log.
--   Денежной автопродажи (карты) в коде нет и не будет: реальные
--   рубли идут через СБП-закреп ДС или донат-сервис.
-- ============================================================

util.AddNetworkString("P11_FluxBuy")
util.AddNetworkString("P11_FluxAdmin")
util.AddNetworkString("P11_FluxRoster")

local FILE = "polus11/flux.json" -- [steamid64] = число флюкса

POLUS11.Flux = POLUS11.Flux or {}

local function FLoad()
    local raw = file.Read(FILE, "DATA")
    if not raw then return end
    local ok, tbl = pcall(util.JSONToTable, raw)
    if ok and istable(tbl) then POLUS11.Flux = tbl end
end
local function FSave()
    if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
    file.Write(FILE, util.TableToJSON(POLUS11.Flux, true))
end
hook.Add("InitPostEntity", "P11.FluxLoad", function()
    timer.Simple(1.6, FLoad)
    -- ключи ФЛЮКСА (Як-2) бывших бойцов не вечны — живут в памяти только сессию
end)
hook.Add("PlayerDisconnected", "P11.FluxBye", function() FSave() end)

-- ============ API ВАЛЮТЫ ============

function POLUS11.FluxSync(ply)
    if not IsValid(ply) then return end
    ply:SetNWInt("P11_Flux", POLUS11.FluxGet(ply))
end

function POLUS11.FluxGet(plyorsid64)
    local k = isstring(plyorsid64) and plyorsid64
        or (IsValid(plyorsid64) and plyorsid64:SteamID64() or nil)
    if not k then return 0 end
    return math.max(0, tonumber(POLUS11.Flux[k]) or 0)
end

-- delta со знаком; возвращает новый баланс
function POLUS11.FluxAdd(plyorsid64, delta, why)
    local k = isstring(plyorsid64) and plyorsid64
        or (IsValid(plyorsid64) and plyorsid64:SteamID64() or nil)
    if not k then return 0 end
    local v = math.max(0, (tonumber(POLUS11.Flux[k]) or 0) + math.floor(tonumber(delta) or 0))
    POLUS11.Flux[k] = v
    FSave()
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:SteamID64() == k then
            POLUS11.FluxSync(p)
            if why and why ~= "" then
                POLUS11.Notify(p, "💠 ПОЛЮС-ФЛЮКС: " .. (delta >= 0 and "+" or "") ..
                    math.floor(delta) .. " ПФ. " .. why .. " Баланс: " .. v .. " ПФ.")
                p:EmitSound(delta >= 0 and "buttons/button15.wav" or "buttons/button10.wav", 55, 100)
            end
            break
        end
    end
    return v
end

-- списание с проверкой (true/false)
function POLUS11.FluxTake(ply, price)
    local v = POLUS11.FluxGet(ply)
    if v < price then return false end
    POLUS11.FluxAdd(ply, -price, nil)
    return true
end

hook.Add("PlayerInitialSpawn", "P11.FluxJoin", function(ply)
    timer.Simple(7, function()
        if IsValid(ply) then POLUS11.FluxSync(ply) end
    end)
end)

-- ============ ВИТРИНА ЗА ПОТОК (F6 → «ПОТРАТИТЬ ПОТОК») ============

-- v4.20.0 «СЛЕД»: реестр мод-испытаний объявлен до витрины (run ссылается)
POLUS11.TrialMods = POLUS11.TrialMods or {} -- [sid64] = { untilT, prev, sid }
local TrialSave -- ниже по файлу (замыкание витрины)

POLUS11.FluxShop = {
    {
        id = "vip", price = 100, icon = "💎",
        name = "Статус VIP (ранг станции)",
        desc = "Золотой ранг VIP + секция 💎 VIP-СЛУЖБА в F4 (3 должности).",
        run = function(ply)
            if P11FW.GetRankLevel and P11FW.GetRankLevel(ply) >= 1 then
                return false, "у тебя уже ранг VIP или выше — флюкс не списан"
            end
            if P11FW.SetRank then P11FW.SetRank(ply, "vip", nil) end
            PrintMessage(HUD_PRINTTALK, "💎 ВИТРИНА: боец " .. ply:Nick() .. " теперь носит золотой ранг VIP!")
            return true, "Статус VIP активен! F4 → 💎 VIP-СЛУЖБА открыта."
        end,
    },
    {
        id = "money25", price = 40, icon = "💰",
        name = "Перевод казначейства: +25 000 ₽",
        desc = "Счёт станции перекидывает кругленькую сумму на твой кошелёк.",
        run = function(ply)
            local v = POLUS11.AddMoney(ply, 25000, "витрина ФЛЮКСА: перевод 25 000₽")
            return true, "+25 000₽! Кошелёк: " .. v .. "₽."
        end,
    },
    {
        id = "money60", price = 80, icon = "🏦",
        name = "Перевод казначейства: +60 000 ₽",
        desc = "На любой грузовик в гараже хватит, и на огнемёт останется.",
        run = function(ply)
            local v = POLUS11.AddMoney(ply, 60000, "витрина ФЛЮКСА: перевод 60 000₽")
            return true, "+60 000₽! Кошелёк: " .. v .. "₽."
        end,
    },
    {
        id = "rpd", price = 60, icon = "🔫",
        name = "РПД — прямо в инвентарь",
        desc = "ARC9 EFT РПД, дисковый. «Использовать» в 🎒 — и пулемёт в руках.",
        run = function(ply)
            local data = POLUS11.InvOf(ply)
            data.items["rpd"] = (data.items["rpd"] or 0) + 1
            POLUS11.InvSync(ply)
            return true, "«РПД» лежит в твоём инвентаре (🎒 C-меню → ИСПОЛЬЗОВАТЬ)."
        end,
    },
    {
        id = "flamer", price = 70, icon = "🔥",
        name = "Кустарный огнемёт — в инвентарь",
        desc = "Единственный честный аргумент против Нечто. Без похода к ларьку.",
        run = function(ply)
            local data = POLUS11.InvOf(ply)
            data.items["flamer"] = (data.items["flamer"] or 0) + 1
            POLUS11.InvSync(ply)
            return true, "«Кустарный огнемёт» — в инвентаре (🎒 C-меню)."
        end,
    },
    {
        id = "medset", price = 30, icon = "🩹",
        name = "Меднабор дежурного",
        desc = "Медкейс + инъектор «УКОЛ-С» + 3 полевых шприца — в инвентарь.",
        run = function(ply)
            local data = POLUS11.InvOf(ply)
            data.items["medkit"]  = (data.items["medkit"] or 0) + 1
            data.items["ukol"]    = (data.items["ukol"] or 0) + 1
            data.items["syringe"] = (data.items["syringe"] or 0) + 3
            POLUS11.InvSync(ply)
            return true, "Меднабор в инвентаре (🎒): медкейс, «УКОЛ-С», шприцы ×3."
        end,
    },
    {
        id = "thermos", price = 15, icon = "☕",
        name = "Термос полярника",
        desc = "Мгновенно тепло 100 и три горячих пайка в инвентарь. Буря ждёт.",
        run = function(ply)
            if POLUS11.AddWarmth then POLUS11.AddWarmth(ply, 100) end
            local data = POLUS11.InvOf(ply)
            data.items["ration"] = (data.items["ration"] or 0) + 3
            POLUS11.InvSync(ply)
            return true, "Термос выпит: тепло полное. Пайки ×3 — в инвентаре."
        end,
    },
    {
        id = "antidote", price = 60, icon = "🧪",
        name = "Ампула чистой крови",
        desc = "Снимает инкубацию заражения (пока оно не проснулось). Активной твари поздно.",
        run = function(ply)
            local inf = ply:GetNWBool("P11_Infected", false)
            local act = ply:GetNWBool("P11_InfActive", false)
            if not inf then return false, "ты не заражён — ампула не списана" end
            if act then return false, "слишком поздно: оно уже проснулось внутри" end
            if POLUS11.Cure then POLUS11.Cure(ply, true) end
            POLUS11.Notify(ply, "🧪 Холод отпустил. Инкубация остановлена — ты снова человек.")
            return true, "Ампула чистой крови сработала: заражение снято."
        end,
    },
    {
        id = "yakkey", price = 350, icon = "🔑",
        name = "Ключ от Як-2",
        desc = "Разовый бесплатный борт в «ПОЛЮС-АВТО»: самолёт без должности лётчика.",
        run = function(ply)
            if ply.P11_FluxYak == true then
                return false, "ключ уже у тебя — иди в гараж поднимать Як-2 (флюкс не списан)"
            end
            ply.P11_FluxYak = true
            return true, "🔑 Ключ получен: в гараже «ПОЛЮС-АВТО» Як-2 для тебя — бесплатно (разово)."
        end,
    },
    -- v4.20.0 «СЛЕД». Заявка владельца: «добавь в донат модератора на
    -- неделю за 50 ПФ — это как пробный период, чтобы знать: стать
    -- модером или нет». Ранг Moderator ровно на 7 суток; по истечении
    -- снимается САМ (если штаб за это время не продлил вручную).
    {
        id = "modtrial", price = 50, icon = "🛡",
        name = "Модератор — испытательный срок (7 дней)",
        desc = "Пробная неделя в модерации станции: варн/мут/арест/кик по уставу. Посмотришь изнутри — твоё ли это. Ранг снимется сам через 7 суток (штаб может продлить раньше).",
        run = function(ply)
            local lvl = P11FW.GetRankLevel and P11FW.GetRankLevel(ply) or 0
            if lvl >= 3 then
                return false, "ты уже в команде станции (Moderator и выше) — испытание не нужно, флюкс не списан"
            end
            local prev = "user"
            if P11FW.GetRank then
                local r = P11FW.GetRank(ply)
                if r and r.id then prev = r.id end
            end
            POLUS11.TrialMods[ply:SteamID64()] = {
                untilT = os.time() + 7 * 86400,
                prev   = prev,
                sid    = ply:SteamID(),
            }
            if TrialSave then TrialSave() end
            if P11FW.SetRank then P11FW.SetRank(ply, "moderator", nil) end
            PrintMessage(HUD_PRINTTALK, "🛡 ИСПЫТАНИЕ: боец " .. ply:Nick() ..
                " неделю проводит модератором. Судите строго, но по делу!")
            POLUS11.Log("МОД-ИСПЫТАНИЕ: " .. ply:Nick() .. " (" .. ply:SteamID() ..
                ") купил пробную неделю модератора за 50 ПФ (до " .. os.date("%d.%m %H:%M", os.time() + 7 * 86400) ..
                ", возврат в «" .. prev .. "»)")
            return true, "🛡 Испытательный срок НАЧАЛСЯ: 7 суток ранга Moderator. Права и устав — C-меню «📜 Права». Не зарывайся: каждое наказание пишется в журнал."
        end,
    },
}

local function FluxEntry(id)
    for _, it in ipairs(POLUS11.FluxShop) do
        if it.id == id then return it end
    end
    return nil
end

net.Receive("P11_FluxBuy", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    ply.P11_FluxBuyNext = ply.P11_FluxBuyNext or 0
    if CurTime() < ply.P11_FluxBuyNext then return end
    ply.P11_FluxBuyNext = CurTime() + 0.8
    local id = string.sub(net.ReadString() or "", 1, 24)
    local it = FluxEntry(id)
    if not it then return end

    -- награда может отказаться БЕЗ списания (уже VIP, ключ в кармане, не заражён)
    if not POLUS11.FluxTake(ply, it.price) then
        POLUS11.Notify(ply, "Не хватает ПОЛЮС-ФЛЮКСА: нужно " .. it.price ..
            " ПФ, у тебя " .. POLUS11.FluxGet(ply) .. " ПФ. Пополнение — кнопки выше (ДС-закреп).")
        ply:EmitSound("buttons/button10.wav", 60, 90)
        return
    end
    local ok, msg = it.run(ply)
    if not ok then
        -- откат списания: награда отказалась (условие не выполнено)
        POLUS11.FluxAdd(ply, it.price, nil)
        POLUS11.Notify(ply, "❌ " .. it.name .. ": " .. tostring(msg) .. ".")
        ply:EmitSound("buttons/button10.wav", 60, 90)
        POLUS11.FluxSync(ply)
        return
    end
    POLUS11.Notify(ply, "✅ " .. tostring(msg or it.name))
    ply:ChatPrint("[ВИТРИНА] " .. it.icon .. " «" .. it.name .. "» за " .. it.price ..
        " ПФ — получено. Баланс: " .. POLUS11.FluxGet(ply) .. " ПФ.")
    ply:EmitSound("buttons/button15.wav", 55, 105)
    POLUS11.Log("ФЛЮКС-ВИТРИНА: " .. ply:Nick() .. " (" .. ply:SteamID() .. ") купил «" ..
        it.name .. "» за " .. it.price .. " ПФ (остаток " .. POLUS11.FluxGet(ply) .. ")")
    POLUS11.FluxSync(ply)
end)

-- ============ ВЫДАЧА: консоль магазина / Глава ============

local function FindBySid(sid)
    sid = tostring(sid or "")
    if sid == "" then return nil end
    for _, p in ipairs(player.GetAll()) do
        if p:SteamID() == sid or p:SteamID64() == sid then return p end
    end
    return nil
end

-- p11_fluxgive <SteamID|SteamID64> <кол-во> — серверная консоль/RCON
-- магазина (CraftedStore: шаблон «p11_fluxgive {steamid64} 100») или Глава.
concommand.Add("p11_fluxgive", function(ply, _, args)
    if IsValid(ply) and (not P11FW.GetRankLevel or P11FW.GetRankLevel(ply) < 16) then
        POLUS11.Notify(ply, "Начисление ФЛЮКСА — только консоль сервера и Глава (ранг 16).")
        return
    end
    local sid = tostring(args and args[1] or "")
    local n   = math.floor(tonumber(args and args[2] or 0) or 0)
    if sid == "" or n == 0 then
        local out = "p11_fluxgive <SteamID|SteamID64> <кол-во ПФ> — начислить ПОЛЮС-ФЛЮКС (онлайн сразу, оффлайн — при входе)"
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, out) else print(out) end
        return
    end
    local k64 = sid
    if string.sub(sid, 1, 5) == "STEAM" then
        k64 = util.SteamIDTo64(sid)
    end
    local v = POLUS11.FluxAdd(k64, n, "начисление магазина/казначейства")
    local target = FindBySid(sid)
    local msg = "ФЛЮКС: " .. sid .. " +" .. n .. " ПФ → баланс " .. v ..
        (IsValid(target) and (" (онлайн: " .. target:Nick() .. ")") or " (оффлайн — ждёт входа)")
    print("[POLUS-11] " .. msg)
    if POLUS11.Log then POLUS11.Log(msg) end
    if IsValid(ply) then POLUS11.Notify(ply, msg) end
end)

-- ============ УТИЛИТ-МЕНЮ (rank ≥ 4) ============

local UTIL_MIN_RANK = 4 -- Administrator и старше

local function UtilAllowed(ply)
    return IsValid(ply) and P11FW.GetRankLevel and P11FW.GetRankLevel(ply) >= UTIL_MIN_RANK
end

-- список бойцов в утилит-меню (по запросу клиента — net P11_FluxRoster из клиента пустой)
net.Receive("P11_FluxRoster", function(_, ply)
    if not UtilAllowed(ply) then return end
    local rows = {}
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then
            rows[#rows + 1] = {
                e = p:EntIndex(),
                name = p:Nick(),
                sid = p:SteamID(),
                flux = POLUS11.FluxGet(p),
                rank = (P11FW.GetRankName and P11FW.GetRankName(p)) or "User",
            }
        end
    end
    net.Start("P11_FluxRoster")
        net.WriteString(util.TableToJSON(rows) or "[]")
    net.Send(ply)
end)

-- выдача/списание из утилит-меню
net.Receive("P11_FluxAdmin", function(_, ply)
    if not UtilAllowed(ply) then return end
    local ei  = net.ReadUInt(8)
    local delta = net.ReadInt(32)
    if delta == 0 then return end
    if math.abs(delta) > 100000 then delta = delta > 0 and 100000 or -100000 end
    local target = Entity(ei)
    if not (IsValid(target) and target:IsPlayer()) then
        POLUS11.Notify(ply, "Игрок уже вышел — выдай оффлайн-командой p11_fluxgive <SteamID64> <n>.")
        return
    end
    local v = POLUS11.FluxAdd(target, delta, "утилит-выдача от " .. ply:Nick())
    POLUS11.Notify(ply, "💠 " .. target:Nick() .. ": " .. (delta >= 0 and "+" or "") ..
        delta .. " ПФ → баланс " .. v .. " ПФ.")
    POLUS11.Log("ФЛЮКС-УТИЛИТЫ: " .. ply:Nick() .. " (" .. ply:SteamID() .. ") → " ..
        target:Nick() .. " (" .. target:SteamID() .. "): " .. delta .. " ПФ (баланс " .. v .. ")")
end)

-- ============ МОД-ИСПЫТАНИЕ: сроки (v4.20.0 «СЛЕД») ============

local TRIAL_FILE = "polus11/trialmods.json"

local function TrialSaveReal()
    if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
    file.Write(TRIAL_FILE, util.TableToJSON(POLUS11.TrialMods, true) or "{}")
end
TrialSave = TrialSaveReal -- замыкание из витрины теперь живое

local function TrialLoad()
    local raw = file.Read(TRIAL_FILE, "DATA")
    if not raw then return end
    local ok, tbl = pcall(util.JSONToTable, raw)
    if ok and istable(tbl) then POLUS11.TrialMods = tbl end
end
hook.Add("InitPostEntity", "P11.TrialLoad", function() timer.Simple(1.7, TrialLoad) end)

-- истёкшие сроки: ранг Moderator снимается САМ (если штаб не поменял его вручную)
local function TrialSweep()
    local now = os.time()
    local changed = false
    for sid64, rec in pairs(POLUS11.TrialMods) do
        local untilT = tonumber(rec and rec.untilT) or 0
        if untilT <= now then
            local online = nil
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and p:SteamID64() == sid64 then online = p break end
            end
            if not IsValid(online) then
                -- боец оффлайн: запись НЕ гасим — ранг снимется при его входе
                -- (join-свип дожмёт), иначе остался бы вечный Moderator
            else
                local cur = P11FW.GetRank and P11FW.GetRank(online)
                if cur and cur.id == "moderator" then
                    if P11FW.SetRank then P11FW.SetRank(online, (rec.prev or "user"), nil) end
                    POLUS11.Notify(online, "🛡 Испытательный срок модератора ЗАВЕРШЁН. Спасибо за неделю службы — " ..
                        "решение о постоянном месте за штабом станции.")
                    POLUS11.Log("МОД-ИСПЫТАНИЕ ЗАВЕРШЕНО: " .. online:Nick() ..
                        " — ранг возвращён в «" .. tostring(rec.prev or "user") .. "»")
                else
                    POLUS11.Log("МОД-ИСПЫТАНИЕ ЗАВЕРШЕНО: " .. sid64 ..
                        " — ранг уже менял штаб («" .. tostring(cur and cur.id) .. "»), запись просто погашена")
                end
                POLUS11.TrialMods[sid64] = nil
                changed = true
            end
        end
    end
    if changed then TrialSaveReal() end
end

timer.Create("P11.TrialSweep", 240, 0, TrialSweep)

-- срок вышел, пока боец был оффлайн: ранг снимется при входе (после ApplyRank)
hook.Add("PlayerInitialSpawn", "P11.TrialJoin", function(ply)
    timer.Simple(11, function()
        if IsValid(ply) then TrialSweep() end
    end)
end)

print("[POLUS-11] донат-валюта «ПОЛЮС-ФЛЮКС» v4.20.0 «СЛЕД»: витрина 10 позиций за ПФ (" ..
    "+ МОДЕРАТОР НА НЕДЕЛЮ за 50 ПФ — испытательный срок, сам снимается), " ..
    "p11_fluxgive <sid> <n> для магазина, утилиты p11_utils (rank " .. UTIL_MIN_RANK .. "+)")
