-- ============================================================
--  ПОЛЮС-11 — ОБМЕН (торговля игрок ↔ игрок) (server) v4.6.9
--  Социальная экономика станции: обмен предметами из инвентаря
--  и рублями ЛИЦОМ К ЛИЦУ. Поток: запрос → принятие (30 сек) →
--  окно обмена → ОБЕ стороны жмут «ГОТОВ» → атомарный обмен
--  с полной валидацией на исполнении. Любая правка оффера
--  сбрасывает обе готовности (не подменишь перед нажатием).
--  Срыв: смерть / дистанция >460 / дисконнект / кнопка ОТМЕНА.
--  Чат-команды: /обмен, !обмен — окно выбора партнёра рядом.
-- ============================================================

util.AddNetworkString("P11_TradeNet")

local REQUEST_DIST = 350   -- дистанция предложения обмена
local TRADE_DIST   = 460   -- дистанция ЖИВОГО обмена (шире запроса)
local REQUEST_TTL  = 30    -- сек на ответ
local SESSION_GAP  = 8     -- кулдаун между запросами одному и тому же

-- актуальные сессии: ply -> session { a, b, offerA, offerB, readyA, readyB }
local live = {}
-- входящие запросы: targetPly -> { from = ply, till = CurTime() }
local pending = {}
-- кулдауны запросов: ply -> { [targetSid] = till }
local reqCd = {}

-- === оп-байты P11_TradeNet ===
-- сервер → клиент:
--   1 входящий запрос  {sid, name}
--   2 отказ/истёк      {reason}
--   3 окно открылось   {partnerSid, partnerName}
--   4 оффер партнёра   {itemsJSON, money}
--   5 флаги готовности {meReady, partnerReady}
--   6 финал            {ok, reason}
--   9 открыть выбор партнёра (чат-команда)
local function TSend(ply, op, writer)
    if not IsValid(ply) then return end
    net.Start("P11_TradeNet")
        net.WriteUInt(op, 4)
        if writer then writer() end
    net.Send(ply)
end

local function OfferFor(s, ply)    return (s.a == ply) and s.offerA or s.offerB end
local function PartnerOf(s, ply)   return (s.a == ply) and s.b or s.a end

local function PushOffers(s)
    TSend(s.a, 4, function()
        net.WriteString(util.TableToJSON(s.offerB.items) or "{}")
        net.WriteUInt(math.max(0, math.floor(s.offerB.money or 0)), 24)
    end)
    TSend(s.b, 4, function()
        net.WriteString(util.TableToJSON(s.offerA.items) or "{}")
        net.WriteUInt(math.max(0, math.floor(s.offerA.money or 0)), 24)
    end)
end

local function PushReady(s)
    TSend(s.a, 5, function()
        net.WriteBool(s.readyA == true) net.WriteBool(s.readyB == true)
    end)
    TSend(s.b, 5, function()
        net.WriteBool(s.readyB == true) net.WriteBool(s.readyA == true)
    end)
end

local function SetReady(s, ply, v)
    if s.a == ply then s.readyA = v == true else s.readyB = v == true end
end

local function Finish(s, ok, reason)
    TSend(s.a, 6, function() net.WriteBool(ok == true) net.WriteString(reason or "") end)
    TSend(s.b, 6, function() net.WriteBool(ok == true) net.WriteString(reason or "") end)
    if IsValid(s.a) then live[s.a] = nil end
    if IsValid(s.b) then live[s.b] = nil end
end

local function BothAliveClose(s)
    return IsValid(s.a) and IsValid(s.b) and s.a:Alive() and s.b:Alive()
        and s.a:GetPos():DistToSqr(s.b:GetPos()) <= TRADE_DIST * TRADE_DIST
end

-- сторож: раз в секунду рвать мёртвые/дальние обмены, протухать запросы
timer.Create("P11.TradeWatch", 1, 0, function()
    local seen = {}
    for _, s in pairs(live) do
        if not seen[s] then
            seen[s] = true
            if not BothAliveClose(s) then
                Finish(s, false, "Обмен сорван: разбежались или кто-то погиб.")
            end
        end
    end
    for target, req in pairs(pending) do
        if CurTime() > req.till then
            pending[target] = nil
            if IsValid(target) then
                TSend(target, 2, function() net.WriteString("Запрос на обмен истёк.") end)
            end
            if IsValid(req.from) then
                TSend(req.from, 2, function()
                    net.WriteString((IsValid(target) and target:Nick() or "Игрок") .. " не ответил — запрос снят.")
                end)
            end
        end
    end
end)

hook.Add("PlayerDisconnected", "P11.TradeBye", function(ply)
    local s = live[ply]
    if s then Finish(s, false, "Партнёр покинул станцию — обмен отменён.") end
    pending[ply] = nil
    reqCd[ply] = nil
end)

-- ============ ВАЛИДАЦИЯ + ИСПОЛНЕНИЕ ============

local function ValidateOffer(ply, off)
    local data = POLUS11.InvOf(ply)
    for id, cnt in pairs(off.items or {}) do
        local it = POLUS11.Items[id]
        if not it then return false, "в обмене неизвестный предмет: " .. tostring(id) end
        cnt = tonumber(cnt) or 0
        if cnt > 0 and (data.items[id] or 0) < cnt then
            return false, "у " .. ply:Nick() .. " нет «" .. it.name .. "» ×" .. cnt
        end
    end
    off.money = math.Clamp(math.floor(tonumber(off.money) or 0), 0,
        (POLUS11.Config and POLUS11.Config.MoneyMax) or 100000)
    if off.money > POLUS11.GetMoney(ply) then
        return false, "у " .. ply:Nick() .. " не хватает " .. off.money .. "₽"
    end
    return true
end

local function Execute(s)
    local okA, errA = ValidateOffer(s.a, s.offerA)
    local okB, errB = ValidateOffer(s.b, s.offerB)
    if not okA or not okB then
        return false, errA or errB
    end
    -- потолок кошелька после обмена ни у кого не должен треснуть
    local maxm = (POLUS11.Config and POLUS11.Config.MoneyMax) or 100000
    if POLUS11.GetMoney(s.a) - s.offerA.money + s.offerB.money > maxm
        or POLUS11.GetMoney(s.b) - s.offerB.money + s.offerA.money > maxm then
        return false, "кошелёк партнёра переполнится (потолок " .. maxm .. "₽) — убавь ₽"
    end

    -- предметы: A → B
    local dataA, dataB = POLUS11.InvOf(s.a), POLUS11.InvOf(s.b)
    for id, cnt in pairs(s.offerA.items or {}) do
        cnt = tonumber(cnt) or 0
        if cnt > 0 then
            dataA.items[id] = (dataA.items[id] or 0) - cnt
            if dataA.items[id] <= 0 then dataA.items[id] = nil end
            dataB.items[id] = (dataB.items[id] or 0) + cnt
        end
    end
    -- предметы: B → A
    for id, cnt in pairs(s.offerB.items or {}) do
        cnt = tonumber(cnt) or 0
        if cnt > 0 then
            dataB.items[id] = (dataB.items[id] or 0) - cnt
            if dataB.items[id] <= 0 then dataB.items[id] = nil end
            dataA.items[id] = (dataA.items[id] or 0) + cnt
        end
    end
    -- рубли в обе стороны
    POLUS11.SetMoney(s.a, POLUS11.GetMoney(s.a) - s.offerA.money + s.offerB.money)
    POLUS11.SetMoney(s.b, POLUS11.GetMoney(s.b) - s.offerB.money + s.offerA.money)
    if POLUS11.InvSaveNow then POLUS11.InvSaveNow() end
    POLUS11.InvSync(s.a)
    POLUS11.InvSync(s.b)

    POLUS11.Log("ОБМЕН: " .. s.a:Nick() .. " ↔ " .. s.b:Nick() ..
        " | ₽ " .. s.offerA.money .. " ↔ " .. s.offerB.money ..
        " | позиций: " .. table.Count(s.offerA.items or {}) .. " ↔ " .. table.Count(s.offerB.items or {}))
    return true
end

-- ============ NET: ПРИЁМ ОТ КЛИЕНТА ============
-- клиент → сервер:
--   1 запросить обмен {targetSid}
--   2 ответ на запрос  {fromSid, accept}
--   3 мой оффер        {itemsJSON, money}
--   4 готовность       {bool}
--   5 отмена
net.Receive("P11_TradeNet", function(len, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local op = net.ReadUInt(4)

    if op == 1 then
        local tsid = string.sub(net.ReadString() or "", 1, 32)
        local target = nil
        for _, p in ipairs(player.GetAll()) do
            if p:SteamID() == tsid then target = p break end
        end
        if not IsValid(target) then
            TSend(ply, 2, function() net.WriteString("Партнёр уже не на станции.") end)
            return
        end
        if target == ply then return end
        if live[ply] or live[target] then
            TSend(ply, 2, function() net.WriteString("Кто-то из вас уже в обмене.") end)
            return
        end
        if ply:GetPos():DistToSqr(target:GetPos()) > REQUEST_DIST * REQUEST_DIST then
            TSend(ply, 2, function() net.WriteString("Подойди ближе: обмен — только лицом к лицу.") end)
            return
        end
        reqCd[ply] = reqCd[ply] or {}
        if CurTime() < (reqCd[ply][tsid] or 0) then
            TSend(ply, 2, function() net.WriteString("Слишком часто — попробуй через пару секунд.") end)
            return
        end
        reqCd[ply][tsid] = CurTime() + SESSION_GAP
        pending[target] = { from = ply, till = CurTime() + REQUEST_TTL }
        TSend(target, 1, function()
            net.WriteString(ply:SteamID())
            net.WriteString(ply:Nick())
        end)
        POLUS11.Notify(ply, "🤝 Запрос обмена отправлен: " .. target:Nick() .. " (" .. REQUEST_TTL .. " сек на ответ).")

    elseif op == 2 then
        local fsid = string.sub(net.ReadString() or "", 1, 32)
        local accept = net.ReadBool()
        local req = pending[ply]
        pending[ply] = nil
        local from = nil
        for _, p in ipairs(player.GetAll()) do
            if p:SteamID() == fsid then from = p break end
        end
        if not req or not IsValid(from) or req.from ~= from then return end
        if not accept then
            TSend(from, 2, function() net.WriteString(ply:Nick() .. " отклонил обмен.") end)
            return
        end
        -- приняли: оба живы, рядом и свободны?
        if live[ply] or live[from] then
            TSend(from, 2, function() net.WriteString("Опоздал — партнёр уже в другом обмене.") end)
            TSend(ply,  2, function() net.WriteString("Опоздал — партнёр уже в другом обмене.") end)
            return
        end
        if ply:GetPos():DistToSqr(from:GetPos()) > REQUEST_DIST * REQUEST_DIST then
            TSend(from, 2, function() net.WriteString("Партнёр успел отойти — обмен не начался.") end)
            TSend(ply,  2, function() net.WriteString("Ты слишком далеко — обмен не начался.") end)
            return
        end
        local s = {
            a = from, b = ply,
            offerA = { items = {}, money = 0 }, offerB = { items = {}, money = 0 },
            readyA = false, readyB = false,
        }
        live[from] = s
        live[ply] = s
        for _, side in ipairs({ from, ply }) do
            local partner = PartnerOf(s, side)
            TSend(side, 3, function()
                net.WriteString(partner:SteamID())
                net.WriteString(partner:Nick())
            end)
        end
        PushReady(s)

    elseif op == 3 then
        local s = live[ply]
        if not s then return end
        local items = util.JSONToTable(net.ReadString() or "") or {}
        local money = math.floor(net.ReadUInt(24))
        local off = OfferFor(s, ply)
        -- обрезаем под свой инвентарь (демонстративно; жёсткая проверка на исполнении)
        local data = POLUS11.InvOf(ply)
        off.items = {}
        for id, cnt in pairs(items) do
            cnt = math.floor(tonumber(cnt) or 0)
            if cnt > 0 and POLUS11.Items[id] then
                local own = data.items[id] or 0
                if own > 0 then off.items[id] = math.min(cnt, own) end
            end
        end
        off.money = math.Clamp(money, 0, POLUS11.GetMoney(ply))
        -- ЛЮБАЯ правка оффера сбрасывает обе готовности (анти-подмена)
        SetReady(s, ply, false)
        SetReady(s, PartnerOf(s, ply), false)
        PushOffers(s)
        PushReady(s)

    elseif op == 4 then
        local s = live[ply]
        if not s then return end
        SetReady(s, ply, net.ReadBool())
        if s.readyA and s.readyB then
            local ok, why = Execute(s)
            Finish(s, ok, ok and "Обмен состоялся — честная сделка! 🤝"
                or ("Обмен сорван: " .. tostring(why)))
        else
            PushReady(s)
        end

    elseif op == 5 then
        local s = live[ply]
        if not s then return end
        Finish(s, false, ply:Nick() .. " отменил обмен.")
    end
end)

-- чат: /обмен — окно выбора партнёра из окружения
hook.Add("PlayerSay", "P11.TradeChat", function(ply, text)
    local t = string.lower(string.Trim(tostring(text or "")))
    if t == "/обмен" or t == "!обмен" or t == "/trade" or t == "!trade" then
        TSend(ply, 9, function() end)
        return ""
    end
end)

print("[POLUS-11] обмен v4.6.9: торговля лицом к лицу (C-меню: 🤝 Обмен • чат: /обмен)")
