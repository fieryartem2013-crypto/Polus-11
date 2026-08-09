-- ============================================================
--  ПОЛЮС-11 — СТОКИ ЭКОНОМИКИ (server) v4.20.0 «СЛЕД»
--  Заявка владельца (банк аналитики №5): «стоки экономики:
--  ремонт/заправка/аренда/штрафы — баланс рубля».
--
--  ТРИ СТОКА (рубли УХОДЯТ из оборота, а не пылятся):
--   ① ШТРАФ НКВД:  !штраф <ник> <50..5000> [причина] — деньги
--      сгорают в «казну порядка» (счёт: !казна, видят НКВД/штаб);
--      перезарядка 60 сек на офицера, себя штрафовать нельзя;
--   ② АРЕНДА ЛИЧНОГО СЕЙФА: первые сутки — льгота станции, дальше
--      200₽/сутки у кладовщика; просрочил — ячейка не откроется;
--   ③ НОЧНОЙ ТАРИФ ЛАРЬКА: 23:00–07:00 интендант накидывает +35%
--      к чеку (множитель читает ShopBuy через POLUS11.NightTariffFactor).
-- ============================================================

local FILE_FUND  = "polus11/finefund.json"
local FILE_RENT  = "polus11/storrent.json"
local RENT_PRICE = 200
local RENT_SEC   = 86400
local FINE_MIN, FINE_MAX, FINE_CD = 50, 5000, 60

POLUS11.FineFund = POLUS11.FineFund or { total = 0 }
POLUS11.StorRent = POLUS11.StorRent or {} -- [sid] = unix конца оплаченной аренды

local function SinkSave(path, tbl)
    if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
    file.Write(path, util.TableToJSON(tbl, true) or "{}")
end

local function SinkLoad()
    local raw = file.Read(FILE_FUND, "DATA")
    if raw then
        local ok, tbl = pcall(util.JSONToTable, raw)
        if ok and istable(tbl) then POLUS11.FineFund = tbl end
    end
    raw = file.Read(FILE_RENT, "DATA")
    if raw then
        local ok, tbl = pcall(util.JSONToTable, raw)
        if ok and istable(tbl) then POLUS11.StorRent = tbl end
    end
end

hook.Add("InitPostEntity", "P11.SinksLoad", function() timer.Simple(1.5, SinkLoad) end)
hook.Add("PlayerDisconnected", "P11.SinksBye", function()
    SinkSave(FILE_FUND, POLUS11.FineFund)
    SinkSave(FILE_RENT, POLUS11.StorRent)
end)

-- ============ ③ НОЧНОЙ ТАРИФ (множитель читает ларёк) ============
function POLUS11.NightTariffFactor()
    local h = tonumber(os.date("%H")) or 12
    if h >= 23 or h < 7 then return 1.35 end
    return 1
end

-- ============ НКВД / ПОИСК ============
local function IsNKVD(ply)
    if not IsValid(ply) then return false end
    local j = P11FW and P11FW.GetJob and P11FW.GetJob(ply)
    if j and (j.category or j.faction) == "nkvd" then return true end
    return P11FW.Config and P11FW.Config.Admin and P11FW.Config.Admin(ply) or false
end

local function FindPly(part)
    part = string.lower(tostring(part or ""))
    if part == "" then return nil end
    for _, p in ipairs(player.GetAll()) do
        if string.find(string.lower(p:Nick()), part, 1, true) then return p end
    end
    return nil
end

-- ============ ① ШТРАФ НКВД ============
local function DoFine(ply, args)
    if not IsNKVD(ply) then
        POLUS11.Notify(ply, "Штрафы накладывает ОСОБЫЙ ОТДЕЛ (НКВД). Если считаешь штраф ошибкой — жалоба командованию.")
        ply:EmitSound("buttons/button10.wav", 60, 90)
        return
    end
    local target = FindPly(args[2])
    if not IsValid(target) then
        POLUS11.Notify(ply, "Игрок не найден: «" .. tostring(args[2] or "") .. "». Пиши кусок ника: !штраф <ник> <50..5000> [причина]")
        return
    end
    if target == ply then
        POLUS11.Notify(ply, "Самого себя штрафовать — самоуправство. Даже для НКВД.")
        return
    end
    local sum = math.floor(tonumber(args[3]) or 0)
    if sum < FINE_MIN or sum > FINE_MAX then
        POLUS11.Notify(ply, "Размер штрафа: от " .. FINE_MIN .. " до " .. FINE_MAX .. "₽. У тебя: «" .. tostring(args[3] or "") .. "».")
        return
    end
    ply.P11_FineCd = ply.P11_FineCd or 0
    if CurTime() < ply.P11_FineCd then
        POLUS11.Notify(ply, "Бланки штрафов закончились — следующий через " .. math.ceil(ply.P11_FineCd - CurTime()) .. " сек.")
        return
    end
    if (POLUS11.GetMoney and POLUS11.GetMoney(target) or 0) < sum then
        POLUS11.Notify(ply, "У «" .. target:Nick() .. "» нет " .. sum .. "₽ в кошельке — штрафы берутся живыми деньгами.")
        return
    end
    local reason = string.Trim(table.concat(args, " ", 4))
    reason = string.sub(reason, 1, 60)

    ply.P11_FineCd = CurTime() + FINE_CD
    POLUS11.TakeMoney(target, sum, "штраф НКВД" .. (reason ~= "" and (": " .. reason) or ""))
    POLUS11.FineFund.total = (tonumber(POLUS11.FineFund.total) or 0) + sum
    SinkSave(FILE_FUND, POLUS11.FineFund)

    local line = "Особый отдел: " .. ply:Nick() .. " оштрафовал " .. target:Nick() .. " на " .. sum .. "₽" ..
        (reason ~= "" and (" — «" .. reason .. "»") or "") .. "."
    PrintMessage(HUD_PRINTTALK, "[НКВД] " .. line)
    POLUS11.Log("ШТРАФ: " .. line .. " (казна порядка: " .. POLUS11.FineFund.total .. "₽)")
    POLUS11.Notify(target, "ШТРАФ: −" .. sum .. "₽ от особого отдела" ..
        (reason ~= "" and (" за «" .. reason .. "»") or "") .. ". Обжалование — начальнику НКВД лично.")
    target:EmitSound("buttons/button10.wav", 60, 90)
end

-- ============ ЧАТ: !штраф / !казна ============
-- кириллица не lowercase'ится — смотрим первое слово в обоих регистрах
local CMD = {
    ["!штраф"] = "fine", ["!Штраф"] = "fine", ["!ШТРАФ"] = "fine",
    ["!shtraf"] = "fine", ["!fine"] = "fine",
    ["!казна"] = "fund", ["!Казна"] = "fund", ["!КАЗНА"] = "fund",
}

hook.Add("PlayerSay", "P11.SinksSay", function(ply, text)
    local raw = string.Trim(tostring(text or ""))
    if raw == "" then return end
    local first = string.match(raw, "^(%S+)") or ""
    local kind = CMD[first]
    if not kind then return end

    if kind == "fund" then
        if IsNKVD(ply) or (P11FW.GetRankLevel and P11FW.GetRankLevel(ply) >= 5) then
            POLUS11.Notify(ply, "КАЗНА ПОРЯДКА: на счету " .. (tonumber(POLUS11.FineFund.total) or 0) ..
                "₽ штрафов особого отдела. Деньги сожжены — обратно в экономику не уходят.")
        else
            POLUS11.Notify(ply, "Казна порядка — тайна особого отдела. Посторонним вход воспрещён.")
        end
        return "" -- глушим строку
    end

    local args = string.Explode(" ", raw)
    DoFine(ply, args)
    return ""
end)

-- ============ ② АРЕНДА ЛИЧНОГО СЕЙФА ============
function POLUS11.StorageRentOK(ply)
    if not IsValid(ply) then return false end
    local sid = ply:SteamID()
    local untilT = tonumber(POLUS11.StorRent[sid]) or 0
    local now = os.time()

    if untilT > now then return true end -- оплачено

    if untilT <= 0 then
        -- первый визит к ячейке: сутки льготы
        POLUS11.StorRent[sid] = now + RENT_SEC
        SinkSave(FILE_RENT, POLUS11.StorRent)
        POLUS11.Notify(ply, "Личный сейф: первые сутки аренды — ЛЬГОТА станции. Дальше " .. RENT_PRICE .. "₽/сутки у кладовщика.")
        return true
    end

    if POLUS11.TakeMoney and POLUS11.TakeMoney(ply, RENT_PRICE, "аренда личного сейфа (сутки)") then
        POLUS11.StorRent[sid] = now + RENT_SEC
        SinkSave(FILE_RENT, POLUS11.StorRent)
        POLUS11.Notify(ply, "Аренда сейфа оплачена: " .. RENT_PRICE .. "₽ — ячейка твоя ещё на сутки.")
        return true
    end

    POLUS11.Notify(ply, "АРЕНДА СЕЙФА ПРОСРОЧЕНА! Кладовщик просит " .. RENT_PRICE .. "₽/сутки, а у тебя " ..
        (POLUS11.GetMoney and POLUS11.GetMoney(ply) or 0) .. "₽. Разживёшься — возвращайся.")
    ply:EmitSound("buttons/button10.wav", 60, 90)
    return false
end

-- ворота поверх штатного открытия (инвентарь грузится раньше —
-- обёртка ставится здесь и работает мгновенно)
do
    local base = POLUS11.OpenStorageUI
    POLUS11.OpenStorageUI = function(ply, ent)
        if not IsValid(ply) then return end
        if not POLUS11.StorageRentOK(ply) then return end
        if base then base(ply, ent) end
    end
end

print("[POLUS-11] стоки экономики v4.20.0: штраф НКВД (!штраф/!казна), аренда сейфа " ..
    RENT_PRICE .. "₽/сутки, ночной тариф ларька +35% (23:00–07:00)")
