-- ============================================================
--  ПОЛЮС-11 — НЕЧТО «КОРЕНЬ» (server) v4.13.1 «ТУША»
--  ЗАЯВКИ ВЛАДЕЛЬЦА:
--   1) «если ты умер взяв себе нечто или поменял профу — нечто
--      пропадает, а не остаётся до рестарта» → НЕЧТО ТЕПЕРЬ
--      ОСТАЁТСЯ ДО РЕСТАРТА СЕРВЕРА. Смерть и смена должности
--      заражение НЕ снимают: флаги переподтверждаются из снимка
--      (даже если какой-то сторонний хук их стёр), когти
--      возвращаются, а на смене должности чужая личина
--      НАТЯГИВАЕТСЯ ОБРАТНО поверх лоадаута новой профы.
--      Излечить может только медицина (антидот) или админ-пульт.
--   2) «нечто должно маскироваться, забирая модельку чела,
--      которого убило, имя и номер документов — полная
--      маскировка» → авто-поглощение (ЛИЧИНА 3.0) уже носит
--      облик+позывной+документ+должность жертвы; «КОРЕНЬ» доводит
--      маскировку до ПОЛНОЙ: личина запоминается (P11_LastIdentity)
--      и переживает смену профы, в ЧАТЕ тварь зовётся украденным
--      именем (bonchat/message.lua), РАЦИЯ подписывает эфир
--      личиной (p11_sv_radio.lua), а TAB/ники/документы видят
--      личину уже давно. Логи сервера — честные (реальное имя).
--   3) «свеп нечто автоматом даёт 400 ХП» (v4.13.1) → пока в
--      снаряже есть КОГТИ и тварь АКТИВНА — тело уплотняется до
--      400 ХП (максимум и полный хил при обрастании плотью).
--      Когти ушли/антидот — тело возвращается к ХП профы.
--      Туша Поглотителя пересчитана: +70 поверх 400 (470),
--      а не срез до старых 170 (см. weapon_polus11_thing_brute).
--
--  ЭТОТ ФАЙЛ ВКЛЮЧЁН ПОСЛЕДНИМ: его PlayerSpawn/JobChanged
--  бегут за старыми контурами и перевыставляют состояние.
-- ============================================================

-- заявка «остаётся до рестарта»: рубильник навсегда в «вкл»
if POLUS11.Config then POLUS11.Config.InfectionPersists = true end

local CLAW_WEPS = {
    weapon_polus11_thing = true,
    weapon_polus11_thing_split = true,
    weapon_polus11_thing_brute = true,
    weapon_polus11_thing_spore = true,
}

local function HasAnyClaw(ply)
    for cls in pairs(CLAW_WEPS) do
        if ply:HasWeapon(cls) then return true end
    end
    return false
end
POLUS11.ThingHasClaw = HasAnyClaw

local function IsActiveThing(ply)
    return IsValid(ply)
        and ply:GetNWBool("P11_Infected", false)
        and ply:GetNWBool("P11_InfActive", false)
end

local function RLog(msg)
    if POLUS11.Log then
        POLUS11.Log("НЕЧТО·КОРЕНЬ: " .. msg)
    else
        print("[POLUS-11] НЕЧТО·КОРЕНЬ: " .. msg)
    end
end

local function RNotify(ply, msg)
    if POLUS11.Notify then POLUS11.Notify(ply, msg)
    else ply:ChatPrint("[ПОЛЮС-11] " .. msg) end
end

-- ХП должности бойца (эталон «человеческого» тела)
local function JobHP(ply)
    local job = P11FW and P11FW.GetJob and P11FW.GetJob(ply)
    local hp = tonumber(job and job.hp) or 100
    if hp <= 0 then hp = 100 end
    return math.Clamp(hp, 1, 1000)
end

-- ============ 4) СВЕП НЕЧТО = 400 ХП (заявка v4.13.1 «ТУША») ============
-- Пока активная тварь держит КОГТИ в снаряге — плоть уплотнена до 400.
-- Снятие: когти ушли (странным путём), антидот, админ-излечение.
local THING_HP = 400
POLUS11.ThingHPValue = THING_HP

local function ThingHPPutOn(ply)
    if ply.P11_ThingHPSaved then return end -- плоть уже уплотнена
    local oldMax = ply:GetMaxHealth()
    if oldMax <= 0 then oldMax = 100 end
    if oldMax >= THING_HP then
        -- максимум уже раздут (хвост брута/старой жизни): эталон — ХП профы
        oldMax = JobHP(ply)
        if oldMax >= THING_HP then oldMax = 100 end
    end
    ply.P11_ThingHPSaved = oldMax
    ply:SetMaxHealth(THING_HP)
    ply:SetHealth(THING_HP) -- «автоматом даёт 400 ХП»: оброс — сразу полный
end
POLUS11.ThingHPPutOn = ThingHPPutOn

local function ThingHPTakeOff(ply)
    local s = ply.P11_ThingHPSaved
    if not s then return end
    ply.P11_ThingHPSaved = nil
    ply:SetMaxHealth(s > 0 and s or 100)
    if ply:Health() > ply:GetMaxHealth() then
        ply:SetHealth(ply:GetMaxHealth())
    end
end
POLUS11.ThingHPTakeOff = ThingHPTakeOff

timer.Create("P11.ThingRootHP", 1, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() then
            local boosted = (ply.P11_ThingHPSaved ~= nil)
            if IsActiveThing(ply) and HasAnyClaw(ply) then
                if not boosted then
                    ThingHPPutOn(ply)
                    RNotify(ply, "Плоть уплотнилась — тело нечто: " .. THING_HP .. " ХП.")
                    RLog("тело нечто (" .. THING_HP .. " ХП) надето: " .. ply:Nick())
                end
            elseif boosted then
                ThingHPTakeOff(ply)
                RLog("тело нечто снято (когтей нет): " .. ply:Nick())
            end
        end
    end
end)

-- ============ ОБЁРТКИ ЯДРА (без накопления при auto-refresh) ============

-- запоминаем ПОСЛЕДНЮЮ надетую личину (переодевание после смены профы)
POLUS11._RootApplyOrig = POLUS11._RootApplyOrig or POLUS11.ThingApplyIdentity
local rootApplyOrig = POLUS11._RootApplyOrig
function POLUS11.ThingApplyIdentity(ply, id)
    local ok, why = false, "ядро личины не поднялось"
    if rootApplyOrig then ok, why = rootApplyOrig(ply, id) end
    if ok ~= false and ok ~= nil and IsValid(ply) and istable(id) then
        ply.P11_LastIdentity = {
            nick = id.nick, model = id.model, skin = id.skin,
            color = id.color, pcolor = id.pcolor, wcolor = id.wcolor,
            bodygroups = id.bodygroups, doc = id.doc, job = id.job,
            desc = id.desc,
        }
    end
    return ok, why
end

-- ручное снятие личины (старые меню/админ) — забыть чужое лицо
POLUS11._RootRestoreOrig = POLUS11._RootRestoreOrig or POLUS11.ThingRestoreIdentity
local rootRestoreOrig = POLUS11._RootRestoreOrig
function POLUS11.ThingRestoreIdentity(ply)
    if IsValid(ply) then ply.P11_LastIdentity = nil end
    if rootRestoreOrig then return rootRestoreOrig(ply) end
end
POLUS11_RestoreTrueIdentity = POLUS11.ThingRestoreIdentity -- совместимость

-- излечение (антидот/админ) ЧЕСТНО снимает всё — снимок КОРНЯ тоже
POLUS11._RootCureOrig = POLUS11._RootCureOrig or POLUS11.Cure
local rootCureOrig = POLUS11._RootCureOrig
function POLUS11.Cure(ply, silent)
    if IsValid(ply) then
        ply.P11_RootWasInf = nil
        ply.P11_RootWasAct = nil
        ply.P11_LastIdentity = nil -- вылеченный не носит чужих лиц
        ThingHPTakeOff(ply)          -- и уплотнённой плоти (400 ХП)
    end
    if rootCureOrig then return rootCureOrig(ply, silent) end
end

-- ============ 1) СМЕРТЬ: снимок → РЕСПАВН: переподтверждение ============

hook.Add("PlayerDeath", "P11.ThingRootDeath", function(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return end
    if ply:GetNWBool("P11_Infected", false) then
        ply.P11_RootWasInf = true
        ply.P11_RootWasAct = ply:GetNWBool("P11_InfActive", false) or nil
    else
        ply.P11_RootWasInf = nil
        ply.P11_RootWasAct = nil
    end
end)

hook.Add("PlayerSpawn", "P11.ThingRootSpawn", function(ply)
    if not IsValid(ply) then return end

    -- личина УМЕРЛА публично (её видели убитой) — честно сгорает;
    -- заражение — НЕТ, оно до рестарта
    ply.P11_LastIdentity = nil

    -- тело 400 ХП прошлой жизни сгорает вместе с тушей:
    -- максимум выравниваем до ХП профы (буст наденется заново,
    -- как только вернутся когти)
    ply.P11_ThingHPSaved = nil
    local jhp = JobHP(ply)
    if ply:GetMaxHealth() > jhp then
        ply:SetMaxHealth(jhp)
        if ply:Health() > jhp then ply:SetHealth(jhp) end
    end

    if not ply.P11_RootWasInf then return end
    ply:SetNWBool("P11_Infected", true)
    if ply.P11_RootWasAct then ply:SetNWBool("P11_InfActive", true) end

    timer.Simple(1.2, function()
        if not (IsValid(ply) and ply:Alive()) then return end
        -- второй контур: если что-то стороннее стёрло флаги — вернуть
        if not ply:GetNWBool("P11_Infected", false) then
            ply:SetNWBool("P11_Infected", true)
            RLog("флаг заражения был стёр на спавне — переподтверждён: " .. ply:Nick())
        end
        if ply.P11_RootWasAct and not ply:GetNWBool("P11_InfActive", false) then
            ply:SetNWBool("P11_InfActive", true)
            RLog("флаг активности был стёр на спавне — переподтверждён: " .. ply:Nick())
        end
        -- когти (страховь ЛИЧИНЫ 3.0 делает то же; здесь — запасной круг)
        if IsActiveThing(ply) and not HasAnyClaw(ply) then
            ply:Give("weapon_polus11_thing")
        end
        RNotify(ply, "Холод в жилах никуда не делся — ОНО ОСТАЛОСЬ с тобой. Смерть его не выпускает.")
    end)
end)

-- ============ 2) СМЕНА ДОЛЖНОСТИ: заражение остаётся, личина натянута ============

hook.Add("P11FW.JobChanged", "P11.ThingRootJob", function(ply, newId, oldId)
    if not IsValid(ply) then return end
    if not ply:GetNWBool("P11_Infected", false) then return end

    -- явленную форму монстра лоадаут новой профы всё равно перекроет —
    -- спрячем её сразу, чтобы таймер явления не сорвал личину позже
    if ply.P11_Revealed and POLUS11_HideThing then
        POLUS11_HideThing(ply)
    end

    local last = ply.P11_LastIdentity
    local wasAct = ply:GetNWBool("P11_InfActive", false)

    timer.Simple(0.15, function()
        if not (IsValid(ply) and ply:Alive()) then return end
        if not ply:GetNWBool("P11_Infected", false) then return end

        -- «человеческий» максимум новой профы: старый сейв ТУШИ
        -- недействителен (лоадаут уже выставил ХП новой должности)
        ply.P11_ThingHPSaved = nil
        if not (IsActiveThing(ply) and HasAnyClaw(ply)) then
            local njhp = JobHP(ply)
            if ply:GetMaxHealth() > njhp then ply:SetMaxHealth(njhp) end
        end

        if ply:GetNWString("P11_FakeNick", "") ~= "" and istable(last) then
            -- чужая личина: лоадаут профы перекрыл облик — НАТЯНУТЬ ОБРАТНО
            if POLUS11.ThingApplyIdentity then
                POLUS11.ThingApplyIdentity(ply, last)
                RNotify(ply, "Смена должности личину не тронула — ты всё ещё «"
                    .. tostring(last.nick or "?") .. "».")
                RLog("смена должности: личина «" .. tostring(last.nick or "?")
                    .. "» натянута обратно на " .. ply:Nick())
            end
        else
            -- своё лицо: новая профа = новая «истинная внешность»,
            -- чтобы «снять личину» вернуло АКТУАЛЬНОГО себя
            ply.P11_TrueIdentity = nil
        end

        -- когти, если профа их стёрла (страховь ЛИЧИНЫ 3.0 — запасной круг)
        timer.Simple(1, function()
            if IsValid(ply) and ply:Alive()
            and IsActiveThing(ply) and not HasAnyClaw(ply) then
                ply:Give("weapon_polus11_thing")
            end
        end)

        if wasAct or IsActiveThing(ply) then
            RNotify(ply, "ОНО осталось с тобой — смена должности его не выпускает. Когти при тебе, R — пульт тела.")
        else
            RNotify(ply, "Холод под кожей остался — смена должности заражение не снимает.")
        end
    end)

    RLog("смена должности при заражении: " .. ply:Nick()
        .. " (" .. tostring(oldId) .. " → " .. tostring(newId)
        .. "), нечто остаётся до рестарта"
        .. (istable(last) and (", личина «" .. tostring(last.nick or "?") .. "» будет натянута") or ""))
end)

-- ============ 3) САМОДИАГНОСТИКА (военсовет смотрит КОНКРЕТНОГО бойца) ============

concommand.Add("p11_thingroot", function(ply, cmd, args)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then return end
    local out = { "== НЕЧТО·КОРЕНЬ: КТО НЕСЁТ ЗАРАЖЕНИЕ ДО РЕСТАРТА ==" }
    local n = 0
    for _, p in ipairs(player.GetAll()) do
        if p:GetNWBool("P11_Infected", false) then
            n = n + 1
            local li = p.P11_LastIdentity
            out[#out + 1] = string.format(
                "  %-20s актив=%s снимокСмерти=%s личина=«%s» когти=%s ХП=%d/%d(буст=%s)",
                p:Nick(),
                tostring(p:GetNWBool("P11_InfActive", false)),
                tostring(p.P11_RootWasInf == true),
                (istable(li) and tostring(li.nick or "?")) or "нет",
                tostring(HasAnyClaw(p)),
                p:Health(), p:GetMaxHealth(),
                tostring(p.P11_ThingHPSaved ~= nil)
            )
        end
    end
    if n == 0 then out[#out + 1] = "  заражённых нет." end
    out[#out + 1] = "  смерть/смена профы заражение НЕ снимают; снимают антидот и админ-пульт."
    local txt = table.concat(out, "\n")
    if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, txt) else print(txt) end
end)

print("[POLUS-11] НЕЧТО «КОРЕНЬ» v4.13.1 «ТУША»: заражение НЕУБИВАЕМО до рестарта — смерть/смена профы переподтверждаются из снимка; "
    .. "личина переживает смену профы (P11_LastIdentity); чат/рация зовут тварь украденным именем; "
    .. "СВЕП НЕЧТО АВТОМАТОМ ДАЁТ " .. THING_HP .. " ХП (когти есть и тварь активна — плоть уплотнена); диагностика p11_thingroot")
