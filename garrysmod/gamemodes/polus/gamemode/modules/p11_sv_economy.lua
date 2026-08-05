-- ============================================================
--  ПОЛЮС-11 — ЭКОНОМИКА: РУБЛИ (server) v4.0
--  Кошелёк игрока (NWInt «P11_Money» + сейв в data/polus11/economy.json).
--  Начисления: +2000₽ за все задачи смены, +500₽ за доп-задачу
--  (подключено в p11_sv_tasks / p11_sv_terminal).
--  Админ-выдача: p11_givemoney <ник/часть> <сумма> (Head Administrator+).
-- ============================================================

local FILE = "polus11/economy.json"

POLUS11.Wallet = POLUS11.Wallet or {} -- steamid -> balance

local function LoadWallet()
    local raw = file.Read(FILE, "DATA")
    if not raw then return end
    local ok, tbl = pcall(util.JSONToTable, raw)
    if ok and istable(tbl) then POLUS11.Wallet = tbl end
end

local savePending = false
local function SaveWallet()
    savePending = false
    if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
    file.Write(FILE, util.TableToJSON(POLUS11.Wallet, true))
end

local function DebouncedSave()
    if savePending then return end
    savePending = true
    timer.Simple(8, SaveWallet)
end

hook.Add("InitPostEntity", "P11.WalletLoad", function()
    timer.Simple(1.2, LoadWallet)
end)

-- ============ API ============

function POLUS11.GetMoney(ply)
    if not IsValid(ply) then return 0 end
    local sid = ply:SteamID()
    local v = tonumber(POLUS11.Wallet[sid])
    if v == nil then
        v = (POLUS11.Config and POLUS11.Config.MoneyStart) or 500
        POLUS11.Wallet[sid] = v
    end
    return v
end

function POLUS11.SetMoney(ply, amount, silent)
    if not IsValid(ply) then return 0 end
    local maxm = (POLUS11.Config and POLUS11.Config.MoneyMax) or 100000
    local v = math.Clamp(math.floor(tonumber(amount) or 0), 0, maxm)
    POLUS11.Wallet[ply:SteamID()] = v
    ply:SetNWInt("P11_Money", v)
    DebouncedSave()
    return v
end

function POLUS11.AddMoney(ply, amount, reason)
    if not IsValid(ply) then return 0 end
    local v = POLUS11.SetMoney(ply, POLUS11.GetMoney(ply) + (tonumber(amount) or 0))
    if POLUS11.Notify and reason then
        if (tonumber(amount) or 0) >= 0 then
            POLUS11.Notify(ply, "💰 +" .. math.floor(amount) .. "₽ — " .. reason ..
                "  (всего: " .. v .. "₽)")
        else
            POLUS11.Notify(ply, "💸 " .. math.floor(amount) .. "₽ — " .. reason ..
                "  (осталось: " .. v .. "₽)")
        end
    end
    return v
end

-- снять, если хватает; вернуть true/false
function POLUS11.TakeMoney(ply, amount, reason)
    if not IsValid(ply) then return false end
    amount = math.floor(tonumber(amount) or 0)
    if POLUS11.GetMoney(ply) < amount then return false end
    POLUS11.SetMoney(ply, POLUS11.GetMoney(ply) - amount)
    if POLUS11.Notify and reason then
        POLUS11.Notify(ply, "💸 -" .. amount .. "₽ — " .. reason ..
            "  (осталось: " .. POLUS11.GetMoney(ply) .. "₽)")
    end
    return true
end

-- ============ ЖИЗНЕННЫЙ ЦИКЛ ============

hook.Add("PlayerInitialSpawn", "P11.WalletJoin", function(ply)
    timer.Simple(3, function()
        if IsValid(ply) then ply:SetNWInt("P11_Money", POLUS11.GetMoney(ply)) end
    end)
end)

hook.Add("PlayerDisconnected", "P11.WalletBye", function()
    SaveWallet()
end)

-- снять с себя вопрос «сколько у меня денег»: чат /деньги — для всех
hook.Add("PlayerSay", "P11.MoneyChat", function(ply, text)
    local t = string.lower(string.Trim(text))
    if t == "/деньги" or t == "/money" or t == "/баланс" then
        POLUS11.Notify(ply, "Твой кошелёк: " .. POLUS11.GetMoney(ply) .. "₽. "
            .. "Заработок: все задачи смены — +" .. ((POLUS11.Config and POLUS11.Config.MoneyTaskAll) or 2000)
            .. "₽, доп-задача с терминала — +" .. ((POLUS11.Config and POLUS11.Config.MoneyTaskExtra) or 500) .. "₽.")
        return ""
    end
end)

-- админ-выдача денег: p11_givemoney <ник/часть> <+-сумма>
concommand.Add("p11_givemoney", function(ply, cmd, args)
    if IsValid(ply) and P11FW.GetRankLevel(ply) < 5 then
        POLUS11.Notify(ply, "Выдача денег — с Head Administrator (ранк 5+).")
        return
    end
    local low = string.lower(tostring(args[1] or ""))
    local amount = math.floor(tonumber(args[2]) or 0)
    if low == "" or amount == 0 then
        print("p11_givemoney <ник/часть> <+-сумма>")
        return
    end
    for _, p in ipairs(player.GetAll()) do
        if string.find(string.lower(p:Nick()), low, 1, true) then
            local v = POLUS11.AddMoney(p, amount, "выдала администрация")
            POLUS11.Notify(IsValid(ply) and ply or p,
                "Кошелёк " .. p:Nick() .. ": " .. v .. "₽ (" .. (amount >= 0 and "+" or "") .. amount .. ")")
            POLUS11.Log((IsValid(ply) and ply:Nick() or "console") ..
                " выдал " .. amount .. "₽ игроку " .. p:Nick())
            return
        end
    end
    if IsValid(ply) then POLUS11.Notify(ply, "Игрок не найден: " .. args[1]) end
end)
