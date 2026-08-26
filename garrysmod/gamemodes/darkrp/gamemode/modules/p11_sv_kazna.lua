-- ============================================================
--  ПОЛЮС-11 — КАЗНА СТАНЦИИ (server) v4.14.2
--  ЗАЯВКА ВЛАДЕЛЬЦА: «сделай вкладку и для выдачи времени и
--  денег» — одна казна на ТРИ вида начислений:
--   💠 flux  — ПОЛЮС-ФЛЮКС (донат-валюта; оффлайн — очередь)
--   ₽  money — рубли кошелька (сейв data/polus11/economy.json)
--   ⏱  time  — наигранные минуты (сейв data/polus11/playtime.json)
--  Цель: часть ника онлайн / STEAM_0:x / SteamID64 (оффлайн тоже —
--  пишем прямо в сейвы; ПФ — в его очередь donate2).
--  ДВЕРИ: сетка ростера (P11_KaznaRoster/P11_KaznaDo, ранг 4+) и
--  консоль p11_kaznagive <flux|money|time> <цель> <сумма> (под
--  замком Главы 16, как остальные p11_*). Всё журналируется.
-- ============================================================

util.AddNetworkString("P11_KaznaRoster")
util.AddNetworkString("P11_KaznaDo")

local KINDS = { flux = "💠 ПФ", money = "₽ рубли", time = "⏱ мин." }
POLUS11.KaznaKinds = KINDS

local function Log(msg)
    if POLUS11.Log then POLUS11.Log(msg) else print("[POLUS-11] " .. msg) end
end

local function CanUse(ply)
    return IsValid(ply) and P11FW.Config.Admin(ply) -- rank 4+, как вкладка 💠 ПОТОК
end

local function SaveJSON(path, tbl)
    if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
    file.Write(path, util.TableToJSON(tbl, true))
end

local function SidKey(ply)
    local s = ply:SteamID()
    if not s or s == "" then s = ply:SteamID64() end
    return s
end

-- ============ РАЗРЕШАТЕЛЬ ЦЕЛИ ============
-- возвращает player(или nil), sid-key(STEAM_0:x), sid64, показное имя
local function ResolveTarget(target)
    if IsValid(target) and target:IsPlayer() then
        return target, SidKey(target), target:SteamID64(), target:Nick()
    end
    target = string.Trim(tostring(target or ""))
    if target == "" then return nil, nil, nil, nil end

    local low = string.lower(target)
    for _, p in ipairs(player.GetAll()) do
        if string.find(string.lower(p:Nick()), low, 1, true)
            or p:SteamID() == target or p:SteamID64() == target then
            return p, SidKey(p), p:SteamID64(), p:Nick()
        end
    end

    -- оффлайн по сырому идентификатору
    if string.StartWith(target, "STEAM_") then
        return nil, target, util.SteamIDTo64(target), "[" .. target .. "]"
    end
    if string.match(target, "^%d+$") and #target >= 15 then
        local sid = util.SteamIDFrom64(target)
        if sid then return nil, sid, target, "[" .. target .. "]" end
    end
    return nil, nil, nil, nil
end

-- ============ БАЛАНС (для ростера/ответов) ============
local function BalOf(ply, kind)
    if kind == "flux" then
        return math.floor(tonumber(POLUS11.FluxGet and POLUS11.FluxGet(ply)) or 0)
    elseif kind == "money" then
        return math.floor(tonumber(POLUS11.GetMoney and POLUS11.GetMoney(ply)) or 0)
    end
    return math.floor(tonumber(POLUS11.GetPlayMin and POLUS11.GetPlayMin(ply)) or 0)
end

-- ============ ВЫДАЧА (главная дверь) ============
-- giver может быть nil (RCON); target — player или строка-цель.
function POLUS11.KaznaGive(kind, target, amount, giver)
    amount = math.floor(tonumber(amount) or 0)
    if not KINDS[kind] then return false, "нет такого вида (flux/money/time)" end
    if amount == 0 then return false, "сумма нулевая" end
    if math.abs(amount) > 1000000 then return false, "слишком жирно даже для казны" end

    local tp, sid, sid64, name = ResolveTarget(target)
    if not sid then
        return false, "цель не найдена: онлайн-ник (куском) / STEAM_0:x / SteamID64"
    end
    if not sid64 and tp then sid64 = tp:SteamID64() end
    if not sid64 then sid64 = util.SteamIDTo64(sid) end
    local gname = IsValid(giver) and giver:Nick() or "console"

    if kind == "flux" then
        -- donate2 умеет оффлайн-очередь сам (принимает player или sid64)
        POLUS11.FluxAdd(sid64, amount, "казна: " .. gname)

    elseif kind == "money" then
        if IsValid(tp) then
            POLUS11.AddMoney(tp, amount, "казна: " .. gname)
        else
            if POLUS11.Wallet[sid] == nil then
                POLUS11.Wallet[sid] = (POLUS11.Config and POLUS11.Config.MoneyStart) or 500
            end
            POLUS11.Wallet[sid] = math.max(0, math.floor(POLUS11.Wallet[sid] + amount))
            SaveJSON("polus11/economy.json", POLUS11.Wallet)
        end

    else -- time
        POLUS11.Playtime[sid] = math.max(0, math.floor((tonumber(POLUS11.Playtime[sid]) or 0) + amount))
        if IsValid(tp) then
            tp:SetNWInt("P11_PlayMin", math.floor(POLUS11.Playtime[sid]))
        end
        SaveJSON("polus11/playtime.json", POLUS11.Playtime)
    end

    Log("КАЗНА: " .. gname .. " → " .. tostring(name)
        .. " | " .. kind .. " " .. (amount > 0 and "+" or "") .. amount
        .. " (sid " .. sid .. ")" .. (IsValid(tp) and "" or " ОФФЛАЙН"))
    if IsValid(giver) then
        POLUS11.Notify(giver, "КАЗНА: «" .. tostring(name) .. "» — "
            .. KINDS[kind] .. (amount > 0 and " +" or " ") .. amount
            .. (IsValid(tp) and "" or " (оффлайн: зачтётся при входе)"))
    end
    if IsValid(tp) and tp ~= giver then
        local what = kind == "flux" and "ПОЛЮС-ФЛЮКСА" or kind == "money" and "рублей" or "минут стажа"
        POLUS11.Notify(tp, "⭐ Администрация начислила тебе " .. what .. ": "
            .. (amount > 0 and "+" or "") .. amount .. "!")
    end
    return true
end

-- ============ РОСТЕР → КЛИЕНТ ============
local function SendRoster(ply)
    net.Start("P11_KaznaRoster")
    local list = {}
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:IsPlayer() then list[#list + 1] = p end
    end
    net.WriteUInt(#list, 8)
    for _, p in ipairs(list) do
        net.WriteUInt(p:EntIndex(), 16)
        net.WriteString(p:Nick())
        net.WriteInt(BalOf(p, "flux"), 32)
        net.WriteInt(BalOf(p, "money"), 32)
        net.WriteUInt(BalOf(p, "time"), 32)
    end
    net.Send(ply)
end

net.Receive("P11_KaznaRoster", function(_, ply)
    if not CanUse(ply) then return end
    SendRoster(ply)
end)

-- ============ ВЫДАЧА ОТ КЛИЕНТА (ростер) ============
net.Receive("P11_KaznaDo", function(_, ply)
    if not CanUse(ply) then
        POLUS11.Notify(ply, "КАЗНА — с ранга Administrator (4+).")
        return
    end
    -- антиспам
    ply.P11_KaznaNext = ply.P11_KaznaNext or 0
    if CurTime() < ply.P11_KaznaNext then return end
    ply.P11_KaznaNext = CurTime() + 0.4

    local kindId = net.ReadUInt(2)
    local idx = net.ReadUInt(16)
    local amount = net.ReadInt(32)
    local kind = ({ [0] = "flux", [1] = "money", [2] = "time" })[kindId]
    if not kind then return end
    local tp = Entity(idx)
    if not (IsValid(tp) and tp:IsPlayer()) then
        POLUS11.Notify(ply, "КАЗНА: боец уже ушёл со станции — давай по SteamID64 (форма во вкладке 💠 ПОТОК).")
        return
    end
    local ok, why = POLUS11.KaznaGive(kind, tp, amount, ply)
    if not ok then POLUS11.Notify(ply, "КАЗНА: " .. tostring(why)) return end
    SendRoster(ply) -- свежие цифры сразу
end)

-- ============ КОНСОЛЬ: p11_kaznagive <flux|money|time> <цель> <сумма> ============
concommand.Add("p11_kaznagive", function(ply, cmd, args)
    if IsValid(ply) and not CanUse(ply) then
        POLUS11.Notify(ply, "КАЗНА — с ранга Administrator (4+).")
        return
    end
    local kind = tostring(args[1] or "")
    local target = args[2]
    local amount = tonumber(args[3] or "")
    if not KINDS[kind] or not target or not amount then
        local msg = "p11_kaznagive <flux|money|time> <ник-кусок|STEAM_0:x|SteamID64> <сумма>"
            .. "  (минус — СПИСАТЬ; время в минутах стажа)"
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print(msg) end
        return
    end
    local ok, why = POLUS11.KaznaGive(kind, target, amount, IsValid(ply) and ply or nil)
    if not ok then
        local msg = "[КАЗНА] " .. tostring(why)
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
    end
end)

-- справочная диагностика: чем богата станция
concommand.Add("p11_kaznalist", function(ply)
    if IsValid(ply) and not CanUse(ply) then return end
    local out = { "== КАЗНА СТАНЦИИ: онлайн-балансы ==",
        string.format("  %-22s %-22s %8s %10s %8s", "БОЕЦ", "STEAM", "💠 ПФ", "₽", "⏱ мин") }
    for _, p in ipairs(player.GetAll()) do
        out[#out + 1] = string.format("  %-22s %-22s %8d %10d %8d",
            p:Nick(), p:SteamID(), BalOf(p, "flux"), BalOf(p, "money"), BalOf(p, "time"))
    end
    local txt = table.concat(out, "\n")
    if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, txt) else print(txt) end
end)

print("[POLUS-11] КАЗНА СТАНЦИИ v4.14.2: выдача 💠 ПФ / ₽ рублей / ⏱ стажа — ростер для ранга 4+ (вкладка 💠 ПОТОК / p11_kazna), оффлайн по SteamID — p11_kaznagive, справка — p11_kaznalist")
