-- ============================================================
--  ПОЛЮС-11 — ДЕЛА ВТОРОЙ ВОЛНЫ (server) v4.2
--  ПОВАР (полевая кухня → паёк), ГРУЗЧИК (заявки снабжения из
--  C-меню), МЕДИК (ампулы для процедур), СБРОС СНАБЖЕНИЯ,
--  ДОСЬЕ НКВД на терминале, СКИДКА ДНЯ в ларьке, ИТОГИ СМЕНЫ.
-- ============================================================

util.AddNetworkString("P11_PorterReq")   -- C2S: текст заявки
util.AddNetworkString("P11_PorterSync")  -- S2C: маркер заявки
util.AddNetworkString("P11_Dossier")     -- S2C: JSON лента НКВД
util.AddNetworkString("P11_ShiftBoard")  -- S2C: JSON экран итогов смены (v5.0.0)
util.AddNetworkString("P11_DossierReq")  -- C2S: дай ленту

local function Cfg(k, d)
    return (POLUS11.Config and POLUS11.Config[k]) or d
end

local function JobId(ply)
    if P11FW and P11FW.GetJobId then return P11FW.GetJobId(ply) or "" end
    return ""
end

-- ============================================================
--  ПОВАР: ПОЛЕВАЯ КУХНЯ
-- ============================================================

local function IsCook(ply) return JobId(ply) == "cook" end

function POLUS11.KitchenUse(stove, ply)
    if not IsValid(stove) or not IsValid(ply) then return end
    if ply:GetPos():DistToSqr(stove:GetPos()) > 150 * 150 then return end
    if not IsCook(ply) then
        POLUS11.Notify(ply, "С плитой управится ПОВАР — позовите снабженца.")
        return
    end
    if (stove.P11_NextCook or 0) > CurTime() then
        POLUS11.Notify(ply, "Плита ещё не остыла: следующая порция через " ..
            math.ceil(stove.P11_NextCook - CurTime()) .. " сек.")
        return
    end
    -- на плите не больше 2 порций
    local meals = 0
    for _, e in ipairs(ents.FindByClass("polus_p11_meal")) do
        if IsValid(e) then meals = meals + 1 end
    end
    if meals >= 2 then
        POLUS11.Notify(ply, "Стол заставлен — пусть сначала едят!")
        return
    end
    if POLUS11.MiniSessions and POLUS11.MiniSessions[ply] then return end

    POLUS11.Notify(ply, "ГОТОВКА: следи за помоями рецепта [R/F/T/G]!")
    POLUS11.MiniStart(ply, stove, {
        steps = 3, window = 2.4, title = "ГОТОВКА ПАЙКА",
        cb = function(p, ent, ok)
            if not IsValid(ent) then return end
            ent.P11_NextCook = CurTime() + 20
            if ok then
                local meal = ents.Create("polus_p11_meal")
                if IsValid(meal) then
                    meal:SetPos(ent:GetPos() + ent:GetUp() * 50 + ent:GetForward() * 18)
                    meal:Spawn()
                    meal:Activate()
                    meal.P11_Cook = p
                end
                ent:EmitSound("ambient/levels/canals/toxic_slime_gurgle2.wav", 60, 120)
                if POLUS11.TaskEvent then POLUS11.TaskEvent(p, "cook") end
                if POLUS11.AddMoney then
                    POLUS11.AddMoney(p, Cfg("CookPay", 40), "горячий паёк готов")
                end
                POLUS11.Notify(p, "Паёк готов! Кто-то явно проголодался.")
            else
                ent:EmitSound("items/battery_pickup.wav", 55, 60)
                POLUS11.Notify(p, "Подгорело. Помои — в мусор, кастрюлю — на снег.")
            end
        end,
    })
end

function POLUS11.MealEat(meal, ply)
    if not IsValid(meal) or not IsValid(ply) then return end
    if ply:GetPos():DistToSqr(meal:GetPos()) > 120 * 120 then return end
    if not ply:Alive() then return end

    local maxhp = ply:GetMaxHealth() > 0 and ply:GetMaxHealth() or 100
    ply:SetHealth(math.min(maxhp, ply:Health() + 15))
    if POLUS11.AddWarmth then POLUS11.AddWarmth(ply, Cfg("MealWarmth", 60)) end
    ply:EmitSound("items/smallmedkit1.wav", 55, 110)
    POLUS11.Notify(ply, "Горячий паёк! +15 ХП, внутри потеплело.")
    meal:Remove()

    -- комиссия повару за порцию (фонд столовой)
    local cook = meal.P11_Cook
    if IsValid(cook) and cook ~= ply and cook:IsPlayer() and POLUS11.AddMoney then
        POLUS11.AddMoney(cook, Cfg("MealCommission", 15), "порция съедена: " .. ply:Nick())
    end
    -- сытость экипажа — заслуга повара в задачах
    if IsValid(cook) and cook:IsPlayer() and POLUS11.TaskEvent then
        POLUS11.TaskEvent(cook, "fed")
    end
end

-- ============================================================
--  ГРУЗЧИК: ЗАЯВКИ СНАБЖЕНИЯ
--  Любой в C-меню пишет, что нужно; ВСЕ грузчики видят маркер
--  к заявителю, первый пришедший закрывает заявку за премию.
-- ============================================================

POLUS11.PorterRequest = nil -- { from=ply, text=, pos=, started= }

local function PorterSync()
    local req = POLUS11.PorterRequest
    local payload = "{}"
    if req and IsValid(req.from) then
        payload = util.TableToJSON({
            text = req.text,
            nick = req.from:Nick(),
            x = req.from:GetPos().x, y = req.from:GetPos().y, z = req.from:GetPos().z,
        })
    end
    net.Start("P11_PorterSync")
        net.WriteString(payload)
    net.Broadcast()
end
POLUS11.PorterSync = PorterSync

net.Receive("P11_PorterReq", function(len, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    ply.P11_PorterNext = ply.P11_PorterNext or 0
    if CurTime() < ply.P11_PorterNext then return end
    ply.P11_PorterNext = CurTime() + 30

    local text = string.sub(net.ReadString() or "", 1, 60)
    text = string.Trim(text)
    if text == "" then return end

    POLUS11.PorterRequest = { from = ply, text = text, started = CurTime() }
    PorterSync()
    POLUS11.Notify(ply, "Заявка отправлена грузчикам: «" .. text .. "». Придут к тебе.")

    -- все грузчики услышат зуммер склада
    for _, p in ipairs(player.GetAll()) do
        if JobId(p) == "porter" then
            p:EmitSound("buttons/button17.wav", 65, 110)
            POLUS11.Notify(p, "ЗАЯВКА СНАБЖЕНИЯ от " .. ply:Nick() .. ": «" .. text ..
                "». Маркер на карте — неси!")
        end
    end
end)

-- истечение и выполнение заявки
timer.Create("P11.PorterTick", 1, 0, function()
    local req = POLUS11.PorterRequest
    if not req then return end

    if not IsValid(req.from) or CurTime() - req.started > 240 then
        POLUS11.PorterRequest = nil
        PorterSync()
        return
    end

    -- грузчик добрался руками до заявителя?
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:Alive() and JobId(p) == "porter" then
            if p:GetPos():DistToSqr(req.from:GetPos()) < 130 * 130 then
                local spent = CurTime() - req.started
                local base = Cfg("PorterBonus", 120)
                local pay = math.max(40, math.floor(base * (1 - spent / 240)))
                POLUS11.PorterRequest = nil
                PorterSync()
                if POLUS11.AddMoney then
                    POLUS11.AddMoney(p, pay, "заявка снабжения: " .. req.from:Nick())
                end
                if POLUS11.TaskEvent then POLUS11.TaskEvent(p, "haul") end
                POLUS11.Notify(p, "Заявка выполнена за " .. math.floor(spent) ..
                    " сек. Премия " .. pay .. "₽.")
                POLUS11.Notify(req.from, "Грузчик " .. p:Nick() .. " по твоей заявке — тут.")
                break
            end
        end
    end
end)

-- ============================================================
--  СБРОС СНАБЖЕНИЯ В МЕТЕЛЬ (авто-эвент)
-- ============================================================

local SUPPLY_NEXT = CurTime() + math.Rand(Cfg("SupplyGapMin", 900), Cfg("SupplyGapMax", 1500))

local function SpawnSupply()
    -- точка: улица = виден небосвод; якоримся к постам/генераторам
    local anchors = {}
    -- v4.12.0 «ОТБОЙ»: якорь-генератор вырезан из игры → якоримся к лутницам станции
    for _, cls in ipairs({ "polus11_lootcrate", "polus_fw_jobnpc", "polus_p11_contractnpc" }) do -- v4.19.5 «ДОПРОС»: патруль вырезан — якорь нарядник
        for _, e in ipairs(ents.FindByClass(cls)) do
            if IsValid(e) then anchors[#anchors + 1] = e:GetPos() end
        end
    end
    if #anchors == 0 then return end

    local spot, tries = nil, 0
    repeat
        tries = tries + 1
        local base = anchors[math.random(#anchors)]
        local probe = base + Vector(math.random(-2500, 2500), math.random(-2500, 2500), 0)
        local tr = util.TraceLine({ start = probe + Vector(0, 0, 80), endpos = probe - Vector(0, 0, 400), mask = MASK_SOLID_BRUSHONLY })
        if tr.Hit and not tr.HitSky then
            -- метель: только под открытым небом
            local sky = util.TraceLine({ start = tr.HitPos + Vector(0, 0, 4), endpos = tr.HitPos + Vector(0, 0, 800), mask = MASK_SOLID_BRUSHONLY })
            if sky.HitSky or not sky.Hit then spot = tr.HitPos end
        end
    until spot or tries > 12
    if not spot then return end

    local crate = ents.Create("polus_p11_supply")
    if not IsValid(crate) then return end
    crate:SetPos(spot + Vector(0, 0, 8))
    crate:Spawn()
    crate:Activate()

    PrintMessage(HUD_PRINTTALK, "[СНАБЖЕНИЕ] С материка сброшен ЯЩИК! Оранжевый маяк над метелью — за добычей, группой!")
    POLUS11.Log("СБРОС СНАБЖЕНИЯ @ " .. tostring(spot))

    -- маяк звуком по станции
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then p:EmitSound("npc/attack_helicopter/aheli_mine_drop1.wav", 60, 90) end
    end

    -- сгниёт через 6 минут
    timer.Simple(360, function()
        if IsValid(crate) then
            crate:Remove()
            PrintMessage(HUD_PRINTTALK, "[СНАБЖЕНИЕ] Ящик замёрз насмерть — его не успели вскрыть.")
        end
    end)

    SUPPLY_NEXT = CurTime() + math.Rand(Cfg("SupplyGapMin", 900), Cfg("SupplyGapMax", 1500))
end

timer.Create("P11.SupplyDrop", 10, 0, function()
    if CurTime() >= SUPPLY_NEXT then SpawnSupply() end
end)

concommand.Add("p11_supply", function(ply)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then return end
    SpawnSupply()
end)

-- вскрытие ящика: держать E 8 сек
function POLUS11.SupplyUse(crate, ply)
    if not IsValid(crate) or not IsValid(ply) or not ply:Alive() then return end
    if ply:GetPos():DistToSqr(crate:GetPos()) > 150 * 150 then return end
    if ply.P11_SupplyHold then return end
    ply.P11_SupplyHold = { crate = crate, pos = ply:GetPos(), endsAt = CurTime() + 8 }
    POLUS11.Notify(ply, "Вскрываешь ящик… держи E и стой (8 сек).")
end

timer.Create("P11.SupplyHold", 0.25, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        local h = ply.P11_SupplyHold
        if h then
            local crate = h.crate
            local broken = (not IsValid(crate)) or (not ply:Alive())
                or ply:GetPos():DistToSqr(h.pos) > 30 * 30
                or ply:GetPos():DistToSqr(crate:GetPos()) > 160 * 160
                or not ply:KeyDown(IN_USE)
            if broken then
                ply.P11_SupplyHold = nil
                if IsValid(crate) then crate:SetOpenProgress(0) end
                if IsValid(ply) then POLUS11.Notify(ply, "Вскрытие прервано.") end
            else
                local frac = math.Clamp(1 - (h.endsAt - CurTime()) / 8, 0, 1)
                crate:SetOpenProgress(frac)
                if CurTime() >= h.endsAt then
                    ply.P11_SupplyHold = nil
                    ply:EmitSound("items/ammo_pickup.wav", 70, 100)

                    -- добыча: 1 ствол + пайки + расходка
                    local weps = { "aks74u", "aks74", "ppsh41", "mosin", "mr43", "k98", "radio", "flamer" }
                    local loot = { weps[math.random(#weps)] }
                    for _ = 1, 2 do loot[#loot + 1] = "ration" end
                    loot[#loot + 1] = "ampoule"
                    loot[#loot + 1] = (math.random() < 0.5) and "syringe" or "chemlight"

                    local data = POLUS11.InvOf and POLUS11.InvOf(ply) or nil
                    if data then
                        for _, id in ipairs(loot) do
                            data.items[id] = (data.items[id] or 0) + 1
                        end
                        POLUS11.InvSync(ply)
                    end
                    if POLUS11.AddWarmth then POLUS11.AddWarmth(ply, 45) end
                    POLUS11.Notify(ply, "ЯЩИК ВСКРЫТ: добыча у тебя в 🎒 Багаже. Уходи из метели!")
                    POLUS11.Log("СНАБЖЕНИЕ вскрыл: " .. ply:Nick())
                    PrintMessage(HUD_PRINTTALK, "[СНАБЖЕНИЕ] Ящик вскрыт: " .. ply:Nick() .. " тащит добычу со льда.")
                    if IsValid(crate) then crate:Remove() end
                end
            end
        end
    end
end)

-- ============================================================
--  ДОСЬЕ НКВД (лента инцидентов на терминале)
-- ============================================================

POLUS11.Dossier = POLUS11.Dossier or {}
local DOSSIER_MAX = 40

local function DossierEligible(ply)
    if not IsValid(ply) then return false end
    local job = P11FW and P11FW.GetJob and P11FW.GetJob(ply)
    local fac = (job and (job.faction or job.category)) or ""
    if fac == "nkvd" then return true end
    if job and job.command then return true end
    if POLUS11.Config and POLUS11.Config.Admin(ply) then return true end
    return false
end
POLUS11.DossierEligible = DossierEligible

local function DossierPush(ply)
    if not DossierEligible(ply) then return end
    net.Start("P11_Dossier")
        net.WriteString(util.TableToJSON(POLUS11.Dossier))
    net.Send(ply)
end

local function DossierBroadcast()
    for _, p in ipairs(player.GetAll()) do DossierPush(p) end
end

function POLUS11.DossierAdd(kind, text, byName)
    POLUS11.Dossier[#POLUS11.Dossier + 1] = {
        t = os.date("%H:%M"), kind = kind, text = text, by = byName or "—",
    }
    if #POLUS11.Dossier > DOSSIER_MAX then
        table.remove(POLUS11.Dossier, 1)
    end
    DossierBroadcast()
end

hook.Add("P11FW.Punished", "P11.DossierArrest", function(target, ptype, by)
    if not IsValid(target) then return end
    if ptype == "arrest" or ptype == "ban" or ptype == "slavery" then
        POLUS11.DossierAdd(string.upper(ptype), target:Nick() ..
            " — " .. (ptype == "arrest" and "задержан" or ptype == "ban" and "заблокирован" or "приговорён"),
            IsValid(by) and by:Nick() or "система")
    end
end)

-- розыск (ToggleWanted — из модуля команд v3.9)
do
    local base = POLUS11.ToggleWanted
    POLUS11.ToggleWanted = function(ply, namePart, reason)
        -- до вызова: был ли целевой уже в розыске?
        local target = nil
        for _, tp in ipairs(player.GetAll()) do
            if string.find(string.lower(tp:Nick()), string.lower(tostring(namePart or "")), 1, true) then
                target = tp break
            end
        end
        local wasWanted = IsValid(target) and target:GetNWString("P11_Wanted", "") ~= ""
        local ok = base(ply, namePart, reason)
        if ok and IsValid(target) then
            if wasWanted then
                POLUS11.DossierAdd("СНЯТИЕ РОЗЫСКА", target:Nick() .. " — снят с розыска",
                    IsValid(ply) and ply:Nick() or "командование")
            else
                POLUS11.DossierAdd("РОЗЫСК", target:Nick() .. " — " .. tostring(reason or "подозрение"),
                    IsValid(ply) and ply:Nick() or "командование")
            end
        end
        return ok
    end
end

-- тесты крови
do
    local base = POLUS11.FinishBloodTest
    POLUS11.FinishBloodTest = function(tester)
        local pend = POLUS11.PendingTests and POLUS11.PendingTests[tester]
        local donor = "?"
        local res = "?"
        if pend then
            donor = (IsValid(pend.vial) and pend.vial.GetDonorName and pend.vial:GetDonorName()) or "?"
            local thing = pend.infected == true
            if pend.falsify then thing = not thing end
            res = thing and "НЕЧТО" or "чист"
        end
        base(tester)
        POLUS11.DossierAdd("ТЕСТ КРОВИ", "донор «" .. donor .. "» → " .. res ..
            (pend and pend.falsify and " (ПОДМЕНА РЕЗУЛЬТАТА)" or ""),
            IsValid(tester) and tester:Nick() or "?")
    end
end

hook.Add("PlayerInitialSpawn", "P11.DossierJoin", function(ply)
    timer.Simple(10, function()
        if IsValid(ply) then DossierPush(ply) end
    end)
end)

hook.Add("P11FW.JobChanged", "P11.DossierJob", function(ply)
    timer.Simple(1, function()
        if IsValid(ply) then DossierPush(ply) end
    end)
end)

net.Receive("P11_DossierReq", function(len, ply)
    if not IsValid(ply) then return end
    if DossierEligible(ply) then
        DossierPush(ply)
    else
        POLUS11.Notify(ply, "Лента досье — для особого отдела и командования.")
    end
end)

concommand.Add("p11_dossier", function(ply)
    if not IsValid(ply) or not DossierEligible(ply) then
        if IsValid(ply) then POLUS11.Notify(ply, "Досье ведёт особый отдел — доступа нет.") end
        return
    end
    DossierPush(ply)
end)

-- ============================================================
--  СКИДКА ДНЯ В ЛАРЬКЕ (−40% на случайный товар)
-- ============================================================

POLUS11.SaleOfDay = POLUS11.SaleOfDay or { day = "", id = nil, pct = 0 }

local function RollSale()
    local ids = {}
    for id in pairs(POLUS11.Items or {}) do ids[#ids + 1] = id end
    if #ids == 0 then return end
    local day = os.date("%j")
    if POLUS11.SaleOfDay.day == day and POLUS11.SaleOfDay.id then return end
    -- детерминированно от дня, чтобы у всех одно и то же
    math.randomseed(tonumber(day) + 11)
    local id = ids[math.random(#ids)]
    math.randomseed(os.time())
    POLUS11.SaleOfDay = { day = day, id = id, pct = Cfg("SalePct", 0.4) }
    POLUS11.Log("СКИДКА ДНЯ в ларьке: «" .. (POLUS11.Items[id] and POLUS11.Items[id].name or id) .. "» −" .. math.floor(POLUS11.SaleOfDay.pct * 100) .. "%")
end
RollSale()
timer.Create("P11.SaleRoll", 300, 0, RollSale)

function POLUS11.SalePrice(id)
    local it = POLUS11.Items and POLUS11.Items[id]
    if not it then return 0 end
    if POLUS11.SaleOfDay.id == id then
        return math.max(1, math.floor(it.price * (1 - POLUS11.SaleOfDay.pct)))
    end
    return it.price
end

--
-- ============================================================
--  ИТОГИ СМЕНЫ: лучший работник / учёный / стрелок + звания в TAB
-- ============================================================

local Shift = { earn = {}, rp = {}, dmg = {} } -- steamid -> число за смену

local function TrackHook()
    -- заработок
    local baseAdd = POLUS11.AddMoney
    POLUS11.AddMoney = function(ply, amount, reason)
        local v = baseAdd(ply, amount, reason)
        if amount > 0 and reason ~= "выдала администрация" and IsValid(ply) then
            local sid = ply:SteamID()
            Shift.earn[sid] = (Shift.earn[sid] or 0) + amount
        end
        return v
    end
    -- очки науки (AddRP из activities, если этот модуль позже — оборачиваем аккуратно)
    if POLUS11.AddRP then
        local baseRP = POLUS11.AddRP
        POLUS11.AddRP = function(ply, n, why)
            baseRP(ply, n, why)
            if IsValid(ply) then
                Shift.rp[ply:SteamID()] = (Shift.rp[ply:SteamID()] or 0) + n
            end
        end
    end
    -- урон по Нечто (TaskEvent уже обёрнут наукой — ещё одно звено)
    local baseTE = POLUS11.TaskEvent
    POLUS11.TaskEvent = function(ply, key, add)
        baseTE(ply, key, add)
        if key == "damage_thing" and IsValid(ply) then
            Shift.dmg[ply:SteamID()] = (Shift.dmg[ply:SteamID()] or 0) + (add or 1)
        end
    end
end
TrackHook()

local function ShiftReset()
    Shift.earn, Shift.rp, Shift.dmg = {}, {}, {}
end

local function TopOf(tbl)
    local best, bestV = nil, 0
    for sid, v in pairs(tbl) do
        if v > bestV then best, bestV = sid, v end
    end
    if not best then return nil, 0 end
    for _, p in ipairs(player.GetAll()) do
        if p:SteamID() == best then return p, bestV end
    end
    return nil, bestV
end

local function ShiftNick(sid)
    for _, p in ipairs(player.GetAll()) do
        if p:SteamID() == sid then return p:Nick(), true end
    end
    return sid, false
end

function POLUS11.ShiftAwards()
    -- v5.0.0 «СБОР»: бонус за звание — 5000₽ (заявка владельца)
    local cats = {
        { tbl = Shift.earn, title = "ЛУЧШИЙ РАБОТНИК", unit = "₽ заработано", bonus = Cfg("AwardPay", 5000) },
        { tbl = Shift.rp,   title = "ЛУЧШИЙ УЧЁНЫЙ",  unit = "RP исследований", bonus = Cfg("AwardPay", 5000) },
        { tbl = Shift.dmg,  title = "ЛУЧШИЙ СТРЕЛОК", unit = " урона Нечто", bonus = Cfg("AwardPay", 5000) },
    }
    local any = false
    local board = {}  -- для клиентского экрана-итога

    PrintMessage(HUD_PRINTTALK, "════════ ИТОГИ СМЕНЫ ════════")
    for _, c in ipairs(cats) do
        local winner, val = TopOf(c.tbl)
        if IsValid(winner) and val > 0 then
            any = true
            winner:SetNWString("P11_Title", c.title)
            if POLUS11.AddMoney then
                POLUS11.AddMoney(winner, c.bonus, "звание смены: " .. c.title)
            end
            PrintMessage(HUD_PRINTTALK, "★ " .. c.title .. ": " .. winner:Nick() ..
                " — " .. val .. c.unit)
            winner:EmitSound("buttons/button15.wav", 70, 100)
            POLUS11.Log("ИТОГИ СМЕНЫ: " .. c.title .. " → " .. winner:Nick() .. " (" .. val .. ")")
            board[#board + 1] = { t = c.title, name = winner:Nick(), v = val, unit = c.unit, pay = c.bonus }
        end
    end
    if not any then
        PrintMessage(HUD_PRINTTALK, "Смена прошла тихо: героев не объявилось.")
    end

    -- v5.0.0 «СБОР»: экран-итог на 20 сек всем (клиент показывает баннер)
    net.Start("P11_ShiftBoard")
        net.WriteString(util.TableToJSON(board) or "[]")
    net.Broadcast()

    ShiftReset()
end

-- привязка к циклу распорядка: вручную /итоги, и авто каждые 90 минут
timer.Create("P11.ShiftAwards", 5400, 0, function()
    if player.GetCount() >= 2 then POLUS11.ShiftAwards() end
end)

concommand.Add("p11_awards", function(ply)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then
        POLUS11.Notify(ply, "Итоги подводит командование.")
        return
    end
    POLUS11.ShiftAwards()
end)

hook.Add("PlayerSay", "P11.AwardsChat", function(ply, text)
    local t = string.lower(text)
    if t == "/итоги" or t == "/awards" then
        ply:ConCommand("p11_awards") -- админская команда: сама проверит права
        return ""
    end
    if t == "/моизвание" or t == "/title" then
        local ttl = ply:GetNWString("P11_Title", "")
        POLUS11.Notify(ply, ttl ~= "" and ("Твоё звание смены: «" .. ttl .. "»")
            or "Звания пока нет — геройство ещё впереди.")
        return ""
    end
end)

print("[POLUS-11] дела второй волны загружены (повар/грузчик/снабжение/досье/скидка/итоги)")

-- ============================================================
--  МЕДИК: ПРОЦЕДУРНАЯ ИНЪЕКЦИЯ (ампула + миниигра, +25 ХП)
-- ============================================================

function POLUS11.StartInjection(medic, target)
    if not IsValid(medic) or not IsValid(target) then return false end
    -- ампула в багаже?
    local data = POLUS11.InvOf and POLUS11.InvOf(medic)
    if not data or (data.items["ampoule"] or 0) <= 0 then return false end
    if not (POLUS11.MiniStart) then return false end
    if POLUS11.MiniSessions and POLUS11.MiniSessions[medic] then return true end

    POLUS11.Notify(medic, "ПРОЦЕДУРА: держи руку ровно, веди иглу [R/F/T/G]!")
    POLUS11.Notify(target, "Медик " .. medic:Nick() .. " ставит тебе инъекцию… стой спокойно.")

    local started = POLUS11.MiniStart(medic, target, {
        steps = 3, window = 2.0, title = "ИНЪЕКЦИЯ",
        cb = function(p, ent, ok)
            if not IsValid(ent) then return end
            if ok then
                local d2 = POLUS11.InvOf(p)
                d2.items["ampoule"] = (d2.items["ampoule"] or 1) - 1
                if d2.items["ampoule"] <= 0 then d2.items["ampoule"] = nil end
                if POLUS11.InvSync then POLUS11.InvSync(p) end

                local maxhp = ent:GetMaxHealth() > 0 and ent:GetMaxHealth() or 100
                ent:SetHealth(math.min(maxhp, ent:Health() + 25))
                ent.P11_LastHealed = CurTime()
                ent:EmitSound("items/smallmedkit1.wav", 65, 108)
                if POLUS11.AddWarmth then POLUS11.AddWarmth(ent, 20) end
                POLUS11.Notify(ent, "Инъекция проколота чисто: +25 ХП.")
                POLUS11.Notify(p, "Пациент " .. ent:Nick() .. " восстановлен (+25 ХП). Ампула -1.")
                if POLUS11.TaskEvent then POLUS11.TaskEvent(p, "heal_player") end
                if POLUS11.AddMoney then
                    POLUS11.AddMoney(p, (POLUS11.Config and POLUS11.Config.InjectPay) or 40, "процедурная инъекция")
                end
            else
                POLUS11.Notify(p, "Игла сорвалась. Ампула цела — подыми шприц ещё раз.")
                POLUS11.Notify(ent, "Медик дрогнул — инъекция не вышла.")
            end
        end,
    })
    return started == true
end
