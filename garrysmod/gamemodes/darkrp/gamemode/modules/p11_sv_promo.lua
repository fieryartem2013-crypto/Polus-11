-- ============================================================
--  ПОЛЮС-11 — ТАЛОНЫ (промокоды) (server) v4.9.0 «ТАЛОН»
--  Заявка владельца: «сделай промокоды, которые вводят в Донат
--  меню; добавь 3 промокода со своими приколами — деньги, випка».
--
--  КАК РАБОТАЕТ: игрок открывает F6 (донат-витрина) → внизу поле
--  «ТАЛОН НАГРАДЫ» → вводит код → награда сразу. Те же пути:
--  чат «!промо КОД» и консоль «p11_promo КОД» (команда публичная
--  — в p11_sv_cmdlock занесена в белый список сознательно).
--
--  ЖЕЛЕЗНЫЕ ПРАВИЛА:
--   • код погашается ОДИН РАЗ на SteamID (сейв: polus11/promos_used.json)
--   • текучесть: не чаще 1 попытки в 1.5 сек; после 8 промахов —
--     карантин 5 минут (переборщики мёрзнут)
--   • ответ «неверный талон» одинаковый всегда — перебором код
--     не нащупать (одинаковый текст и для «нет кода», и для «уже погашен»)
--   • список талонов знает только владелец: p11_promolist (Глава,
--     ранг 16; внутренняя планка Куратор+ даже если замок снят)
--   • НИКАКИХ реальных карт в коде: оплата реальными деньгами =
--     только через донат-сервис (EasyDonate/CraftedStore/Tebex),
--     который сам платит тебе на карту. Ключи/карты сюда не пишем!
--
--  НОВЫЙ ТАЛОН = одна строка в POLUS11.PromoList ниже. Коды пиши
--  БОЛЬШИМИ буквами как тут — код СТРОГИЙ (регистр учитывается),
--  публикуй его игрокам в точности. \n/пробелы по краям срезаются.
-- ============================================================

util.AddNetworkString("p11_promo_use")

local FILE = "polus11/promos_used.json"

-- ============ КАТАЛОГ ТАЛОНОВ (правь тут) ============

POLUS11.PromoList = {
    {
        code = "ПУРГА",
        title = "полярная надбавка",
        desc = "+25 000₽ на кошелёк",
        reward = function(ply)
            local v = POLUS11.AddMoney(ply, 25000, "талон «ПУРГА»")
            return "Талон «ПУРГА» погашен: +25 000₽ полярной надбавки! Кошелёк: " .. v .. "₽. Переживём бурю в тепле."
        end,
    },
    {
        code = "ПОЛЯРНИК",
        title = "золотой талон полярника",
        desc = "ранг VIP + секция 💎 VIP-СЛУЖБА в F4",
        reward = function(ply)
            if P11FW.GetRankLevel and P11FW.GetRankLevel(ply) >= 1 then
                local v = POLUS11.AddMoney(ply, 8000, "талон «ПОЛЯРНИК» (конверсия)")
                return "У тебя уже есть VIP-доступ — золотой талон «ПОЛЯРНИК» конвертирован в +8 000₽ (кошелёк: " .. v .. "₽)."
            end
            if P11FW.SetRank then P11FW.SetRank(ply, "vip", nil) end
            PrintMessage(HUD_PRINTTALK, "★ ЗОЛОТОЙ ТАЛОН: боец " .. ply:Nick() .. " погасил «ПОЛЯРНИК» и теперь носит золотой ранг VIP!")
            return "ЗОЛОТОЙ ТАЛОН «ПОЛЯРНИК» погашен! Ранг VIP — твой: F4 → секция 💎 VIP-СЛУЖБА уже открыта."
        end,
    },
    {
        code = "ПАЁК82",
        title = "сухой паёк полярника",
        desc = "+5 000₽ + броня 100 + здоровье до 100",
        reward = function(ply)
            local v = POLUS11.AddMoney(ply, 5000, "талон «ПАЁК82»")
            ply:SetArmor(math.max(ply:Armor(), 100))
            ply:SetHealth(math.min(ply:GetMaxHealth(), math.max(ply:Health(), 100)))
            local jokes = {
                "В обмёрзшем кармане — шпроты, тушёнка и анекдот про полярника и пургу.",
                "В пайке обнаружен шоколад 1978 года выпуска. Он вкуснее, чем у остальных. Не спрашивай.",
                "Бонусом — пачка «Примы» и личное благословение начальника экспедиции.",
                "Судя по запаху, паёк защищал станцию ещё при царе Горохе. Съедобно!",
            }
            PrintMessage(HUD_PRINTTALK, "☭ Боец " .. ply:Nick() .. " погасил талон «ПАЁК82» — сухой паёк полярника получен, моральный дух крепнет.")
            return "Талон «ПАЁК82» погашен: +5 000₽ (кошелёк: " .. v .. "₽), броня 100, здоровье подтянуто. " .. table.Random(jokes)
        end,
    },
    -- v5.8.20 «STOLINOV11»: НОВЫЙ БОНУС НАБОРА. Лимит 100 РАЗНЫХ игроков,
    -- действует НЕДЕЛЮ (срок хранится в data/polus11/promo_expire.json —
    -- переживает рестарты), награда: VIP на 2 дня + 35 000₽.
    {
        code = "STOLINOV11",
        title = "бонус нового набора",
        desc = "VIP на 2 дня + 35 000₽ (лимит: 100 бойцов · действует неделю)",
        maxUses = 100,
        expireDays = 7,
        reward = function(ply)
            local v = POLUS11.AddMoney(ply, 35000, "талон «STOLINOV11»")
            local gotVIP = false
            if POLUS11.GrantTempVIP then
                gotVIP = POLUS11.GrantTempVIP(ply, 2)
            else
                if P11FW.SetRank then P11FW.SetRank(ply, "vip", nil) end
                gotVIP = true
            end
            PrintMessage(HUD_PRINTTALK, "★ ТАЛОН STOLINOV11: боец " .. ply:Nick() .. " получил VIP на 2 дня и +35 000₽! (осталось: " .. POLUS11.PromoLeft and POLUS11.PromoLeft("STOLINOV11") or "?" .. " из 100)")
            return "Талон «STOLINOV11» погашен: " .. (gotVIP and "VIP на 2 дня активирован" or "ранг VIP уже есть — бонус в силе") .. " + 35 000₽ (кошелёк: " .. v .. "₽)."
        end,
    },
}

-- каталог по коду для быстрого поиска (регистр СТРОГИЙ, поля trim)
local BYCODE = {}
for _, p in ipairs(POLUS11.PromoList) do BYCODE[p.code] = p end

-- ============ ХРАНИЛИЩЕ ПОГАШЕНИЙ ============

POLUS11.PromoUsed = POLUS11.PromoUsed or {} -- [code] = { [steamid] = unixtime }

local function PromoLoad()
    local raw = file.Read(FILE, "DATA")
    if not raw then return end
    local ok, tbl = pcall(util.JSONToTable, raw)
    if ok and istable(tbl) then POLUS11.PromoUsed = tbl end
end

local function PromoSave()
    if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
    file.Write(FILE, util.TableToJSON(POLUS11.PromoUsed, true))
end

hook.Add("InitPostEntity", "P11.PromoLoad", function()
    timer.Simple(1.4, PromoLoad)
end)

-- ============ ЯДРО: попытка погасить талон ============

local function Reply(ply, ok, msg)
    net.Start("p11_promo_use")
        net.WriteBool(ok and true or false)
        net.WriteString(tostring(msg or ""))
    net.Send(ply)
end

-- одна и та же фраза на «нет такого кода», «уже погашен» и «перебор»
local DENY = "Талон не принят: код не найден, уже погашен на этом бойце или истёк. (Перебор не сработает — служба связи всё пишет.)"

function POLUS11.PromoTry(ply, raw)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local code = string.Trim(tostring(raw or ""))
    if code == "" then
        Reply(ply, false, "Введи код талона — например, из рассылки станции.")
        return
    end

    local now = CurTime()

    -- текучесть: 1 попытка в 1.5 сек
    if ply.P11PromoNextAt and now < ply.P11PromoNextAt then
        Reply(ply, false, "Слишком часто. Служба связи прошивает ленту — повтори через пару секунд.")
        return
    end
    ply.P11PromoNextAt = now + 1.5

    -- карантин переборщика
    if ply.P11PromoBanUntil and now < ply.P11PromoBanUntil then
        Reply(ply, false, "Карантин за перебор кодов ещё " .. math.ceil(ply.P11PromoBanUntil - now) .. " сек. Мёрзни молча.")
        return
    end

    local p = BYCODE[code]
    local sid = ply:SteamID()
    local used = istable(POLUS11.PromoUsed[code]) and POLUS11.PromoUsed[code][sid] ~= nil

    -- v5.8.20 «STOLINOV11»: лимит использований (разные игроки) и срок действия
    if p and p.maxUses then
        local cnt = 0
        local tbl = POLUS11.PromoUsed[code]
        if istable(tbl) then
            for _ in pairs(tbl) do cnt = cnt + 1 end
        end
        if cnt >= p.maxUses then
            ply:ChatPrint("[ПОЛЮС-11] Талон «" .. code .. "» исчерпан: все " .. p.maxUses .. " мест разобрали. Следи за рассылкой станции!")
            Reply(ply, false, DENY)
            return
        end
    end
    if p and p.expireDays and POLUS11.PromoExpireAt then
        local ex = POLUS11.PromoExpireAt(code, p.expireDays)
        if ex and os.time() > ex then
            Reply(ply, false, DENY)
            return
        end
    end

    if not p or used then
        ply.P11PromoFails = (ply.P11PromoFails or 0) + 1
        print("[POLUS-11] ТАЛОН: промах от " .. ply:Nick() .. " («" .. sid .. "»), всего промахов: " .. ply.P11PromoFails)
        if ply.P11PromoFails >= 8 then
            ply.P11PromoBanUntil = now + 300
            ply.P11PromoFails = 0
            print("[POLUS-11] ТАЛОН: карантин 5 минут — " .. ply:Nick() .. " («" .. sid .. "»), перебор")
            if P11FW.ModLog then P11FW.ModLog("талоны: карантин", ply, nil, "перебор кодов") end
        end
        Reply(ply, false, DENY)
        return
    end

    -- УСПЕХ: сначала гашение в журнал (повтор невозможен даже при дисконекте), потом награда
    POLUS11.PromoUsed[code] = POLUS11.PromoUsed[code] or {}
    POLUS11.PromoUsed[code][sid] = os.time()
    PromoSave()
    ply.P11PromoFails = 0

    local okRun, msg = xpcall(function() return p.reward(ply) end, function(err)
        ErrorNoHalt("[POLUS-11] ТАЛОН: ошибка награды «" .. code .. "»: " .. tostring(err) .. "\n")
    end)
    if not okRun then
        Reply(ply, false, "Талон принят, но выдача споткнулась — позови Главу, награда зафиксирована в журнале.")
        return
    end

    print("[POLUS-11] ТАЛОН: ПОГАШЕН «" .. code .. "» → " .. ply:Nick() .. " («" .. sid .. "»)")
    if P11FW.ModLog then P11FW.ModLog("талон: " .. code, ply, nil, p.desc) end
    Reply(ply, true, tostring(msg or ("Талон «" .. code .. "» погашен.")))
    if POLUS11.Notify then POLUS11.Notify(ply, tostring(msg or "Талон погашен!")) end
end

-- ============ ДОРОГИ ВВОДА КОДА ============

-- (1) поле в донат-витрине F6
net.Receive("p11_promo_use", function(_, ply)
    POLUS11.PromoTry(ply, net.ReadString())
end)

-- (2) чат: !промо КОД / !promo КОД (строка доходит сюда из белого списка чат-ядра)
--  ВНИМАНИЕ, КИРИЛЛИЦА: «!промо» в UTF-8 = 11 байт — режем по ДЛИНЕ префикса,
--  а string.lower трогает только ASCII, поэтому ловим и ПРОПИСНЫЕ варианты явно.
local CHAT_PREFIX = { "!промо", "!ПРОМО", "!promo", "!PROMO" }
hook.Add("PlayerSay", "P11.PromoChat", function(ply, text)
    local raw = string.Trim(tostring(text or ""))
    local code = nil
    for _, pfx in ipairs(CHAT_PREFIX) do
        if string.StartWith(raw, pfx) then
            code = string.Trim(string.sub(raw, #pfx + 1))
            break
        end
    end
    if code == nil then return end
    if code == "" then
        ply:ChatPrint("[ПОЛЮС-11] Напиши так: !промо КОД (команду — маленькими; или поле «ТАЛОН» в F6, или консоль: p11_promo КОД)")
        return ""
    end
    POLUS11.PromoTry(ply, code)
    return ""
end)

-- (3) консоль: p11_promo КОД (команда ПУБЛИЧНАЯ — в p11_sv_cmdlock занесена в PUBLIC)
concommand.Add("p11_promo", function(ply, _, args)
    if not IsValid(ply) then
        print("p11_promo — команда ИГРОКА. Список талонов: p11_promolist")
        return
    end
    POLUS11.PromoTry(ply, table.concat(args or {}, " "))
end)

-- ============ СПИСОК ТАЛОНОВ — ТОЛЬКО ВЛАДЕЛЬЦУ ============

concommand.Add("p11_promolist", function(ply)
    if IsValid(ply) and P11FW.GetRankLevel and P11FW.GetRankLevel(ply) < 12 then
        if POLUS11.Notify then POLUS11.Notify(ply, "Каталог талонов — только Куратору и выше.") end
        return
    end
    local tell = IsValid(ply) and function(s) ply:PrintMessage(HUD_PRINTCONSOLE, s) end or print
    tell("== ПОЛЮС-11 · ТАЛОНЫ (v4.9.0 «ТАЛОН») ==")
    for _, p in ipairs(POLUS11.PromoList) do
        local n = 0
        for _ in pairs(POLUS11.PromoUsed[p.code] or {}) do n = n + 1 end
        tell(string.format("  • %-12s — %s (%s) — погашен x%d", p.code, p.title, p.desc, n))
    end
    tell("  ввод игроком: F6 → поле «ТАЛОН» • чат «!промо КОД» • консоль «p11_promo КОД»")
    tell("  журнал погашений: garrysmod/data/polus11/promos_used.json")
end)

print("[POLUS-11] талоны v4.9.0 загружены: " .. #POLUS11.PromoList .. " шт. (каталог для Главы: p11_promolist)")
