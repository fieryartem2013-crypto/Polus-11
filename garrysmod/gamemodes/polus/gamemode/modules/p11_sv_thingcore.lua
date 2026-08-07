-- ============================================================
--  ПОЛЮС-11 — ЯДРО НЕЧТО «ЛИЧИНА 2.0» (server) v4.8.8
--  ЗАЯВКА ВЛАДЕЛЬЦА: «Нечто вырежи и сделай с нуля — с
--  АВТОМАСКИРОВКОЙ после убийства, чтобы работало, и мутация
--  тоже». Старый конвейер (PlayerDeath → трекер трупа таймером
--  → CorpseTagged → второй таймер → обёртка EatCorpse мутациями)
--  рвался на каждом стыке — вот и «не роботает».
--
--  ТЕПЕРЬ ОДНА ПРЯМАЯ ЦЕПЬ, БЕЗ ТРУПО-ГОНОК:
--   1. PlayerDeath: убийца — активное Нечто с когтями Имитатора?
--      Личность жертвы СНИМАЕТСЯ С ЖИВОГО ТЕЛА прямо в хуке
--      (не с трупа через кадр — надёжно).
--   2. Через 0.35 сек (закон принятия пищи): Нечто само жрёт
--      труп — ragdoll жертвы исчезает, на Нечто НАДЕВАЕТСЯ
--      ЧУЖАЯ ЛИЧИНА: модель/скин/бодигруппы/цвет + позывной,
--      должность, описание и КОД ДОКУМЕНТА жертвы (та же
--      NW-механика, что у кейса «ЛЕГАТ» и старых личин).
--   3. Лечение +25, инфекционная мутация засчитана, крик в лог.
--   Отключить авто-поглощение: Config.ThingAutoDevour = false.
--
--  Здесь же — ЕДИНОЕ API личины (используют когти, R-съедение,
--  кнопка меню «снять личину», модуль п11_sv_nechto):
--   POLUS11.ThingCaptureIdentity(victim)  → таблица личности
--   POLUS11.ThingApplyIdentity(ply, id)   → надеть личину
--   POLUS11.ThingRestoreIdentity(ply)     → вернуть СЕБЯ
--   POLUS11.ThingDevourCorpse(ply,corpse) → R-съесть чужой труп
-- ============================================================

local DEVOUR_DELAY  = 0.35 -- закон принятия пищи после убийства
local DEVOUR_HEAL   = 25   -- плоть жертвы в лечение

local function IsThing(ply)
    return IsValid(ply)
        and ply:GetNWBool("P11_Infected", false)
        and ply:GetNWBool("P11_InfActive", false)
end

-- ============ СНЯТЬ ЛИЧНОСТЬ (с живого — в момент смерти) ============
-- Те же поля, что сохранял трекер трупов p11_sv_infection: облик
-- целиком + документ/должность/описание, позывной с учётом чужих
-- личин (тварь в личине отдаёт личину дальше по цепочке).
function POLUS11.ThingCaptureIdentity(p)
    if not IsValid(p) then return nil end
    local bg = {}
    for i = 0, p:GetNumBodyGroups() - 1 do
        bg[i] = p:GetBodygroup(i)
    end
    local id = {
        nick = p:Nick(),
        model = p:GetModel(),
        skin = p:GetSkin(),
        color = p:GetColor(),
        pcolor = p:GetPlayerColor(),
        wcolor = p:GetWeaponColor(),
        bodygroups = bg,
        doc  = p:GetNWString("P11_DocCode", ""),
        job  = p:Team(),
        desc = p:GetNWString("P11_CharDesc", ""),
    }
    local cn = p:GetNWString("P11_CharName", "")
    if cn ~= "" then id.nick = cn end
    local worn = p:GetNWString("P11_FakeNick", "")
    if worn ~= "" then id.nick = worn end -- цепочка личин
    return id
end

-- ============ НАДЕТЬ ЛИЧИНУ ============
function POLUS11.ThingApplyIdentity(ply, id)
    if not (IsValid(ply) and ply:Alive() and istable(id)) then return false end

    -- форма монстра прячется, чтобы автотаймер явления не сорвал личину
    if ply.P11_Revealed and POLUS11_HideThing then POLUS11_HideThing(ply) end

    -- СВОЯ личность запоминается ровно один раз
    if not ply.P11_TrueIdentity then
        local bg = {}
        for i = 0, ply:GetNumBodyGroups() - 1 do
            bg[i] = ply:GetBodygroup(i)
        end
        ply.P11_TrueIdentity = {
            model = ply:GetModel(), skin = ply:GetSkin(), color = ply:GetColor(),
            pcolor = ply:GetPlayerColor(), wcolor = ply:GetWeaponColor(),
            bodygroups = bg,
        }
    end

    if isstring(id.model) and file.Exists(id.model, "GAME") then
        ply:SetModel(id.model)
    end
    ply:SetSkin(id.skin or 0)
    ply:SetColor(id.color or Color(255, 255, 255))
    if isvector(id.pcolor) then ply:SetPlayerColor(id.pcolor) end
    if isvector(id.wcolor) then ply:SetWeaponColor(id.wcolor) end
    local maxBg = ply:GetNumBodyGroups()
    for k, v in pairs(id.bodygroups or {}) do
        if isnumber(k) and k < maxBg then ply:SetBodygroup(k, v) end
    end

    ply.P11_FakeNick = id.nick
    ply.P11_IdentityTakenAt = CurTime()
    ply:SetNWString("P11_FakeNick", tostring(id.nick or ""))
    ply:SetNWInt("P11_FakeJob", tonumber(id.job) or 0)
    ply:SetNWString("P11_FakeDesc", isstring(id.desc) and id.desc or "")
    if isstring(id.doc) and id.doc ~= "" then
        ply:SetNWString("P11_DocCode", id.doc)
    end
    return true
end

-- ============ ВЕРНУТЬ СЕБЯ ============
function POLUS11.ThingRestoreIdentity(ply)
    if not IsValid(ply) then return end
    local a = ply.P11_FakeRestore or ply.P11_TrueIdentity
    if not a then return end

    if isstring(a.model) and file.Exists(a.model, "GAME") then ply:SetModel(a.model) end
    ply:SetSkin(a.skin or 0)
    ply:SetColor(a.color or Color(255, 255, 255))
    ply:SetPlayerColor(a.pcolor or Vector(1, 1, 1))
    ply:SetWeaponColor(a.wcolor or Vector(0, 0.1, 0.6))
    local maxBg = ply:GetNumBodyGroups()
    for k, v in pairs(a.bodygroups or {}) do
        if isnumber(k) and k < maxBg then ply:SetBodygroup(k, v) end
    end

    ply.P11_FakeNick = nil
    ply.P11_FakeRestore = nil
    ply.P11_Revealed = false
    ply.P11_RevealedAt = 0
    ply:SetNWString("P11_FakeNick", "")
    ply:SetNWInt("P11_FakeJob", 0)
    ply:SetNWString("P11_FakeDesc", "")
    if ply.P11_DocCode then ply:SetNWString("P11_DocCode", ply.P11_DocCode) end
end
-- совместимость: старый глобал, которым пользуется !меню мутаций
POLUS11_RestoreTrueIdentity = POLUS11.ThingRestoreIdentity

-- ============ СЪЕДЕНИЕ: сводка + эффекты + мутация ============
local function DevourFinish(ply, identity, corpsePos)
    hook.Run("Polus11.ThingDevoured", ply, identity)

    ply:EmitSound("npc/barnacle/barnacle_digesting1.wav", 75, 90)
    ply:EmitSound("npc/zombie/zo_attack" .. math.random(1, 2) .. ".wav", 70, 85)
    local ed = EffectData()
    ed:SetOrigin((corpsePos or ply:GetPos()) + Vector(0, 0, 20))
    util.Effect("BloodImpact", ed, true, true)
    util.Effect("bloodspray", ed, true, true)

    local maxhp = ply:GetMaxHealth()
    if maxhp <= 0 then maxhp = 100 end
    ply:SetHealth(math.min(maxhp, ply:Health() + DEVOUR_HEAL))

    local jobLine = ""
    if P11FW and P11FW.TeamJobs and tonumber(identity.job) then
        local jid = P11FW.TeamJobs[tonumber(identity.job)]
        local jt = jid and P11FW.Jobs and P11FW.Jobs[jid]
        if jt and jt.name then jobLine = " · " .. jt.name end
    end
    local docLine = (isstring(identity.doc) and identity.doc ~= "")
        and (" · док. " .. identity.doc) or ""
    POLUS11.Notify(ply, "Личность поглощена: «" .. tostring(identity.nick) .. "»" ..
        jobLine .. docLine .. ".")
    ply:ChatPrint("[ПОЛЮС-11] Перевоплощение: ты — «" .. tostring(identity.nick) .. "»" ..
        jobLine .. docLine .. ". TAB, чат и документы видят личину. R → меню (снять личину).")
    POLUS11.Log("ПОГЛОЩЕНИЕ ЛИЧНОСТИ: " .. ply:Nick() .. " надел личину «" ..
        tostring(identity.nick) .. "»" .. jobLine .. docLine)
end

-- ============ 1) АВТО-ПОГЛОЩЕНИЕ ПРИ УБИЙСТВЕ (главная ветка) ============
hook.Add("PlayerDeath", "P11.ThingCoreAutoDevour", function(victim, inf, att)
    if POLUS11.Config and POLUS11.Config.ThingAutoDevour == false then return end
    if not (IsValid(victim) and victim:IsPlayer()) then return end
    if not (IsValid(att) and att:IsPlayer() and att ~= victim and att:Alive()) then return end
    if not IsThing(att) then return end

    -- только когтями ИМИТАТОРА: у него в природе и есть кража лица.
    -- Остальные формы жрут силу через свой ПКМ/способности, личину не носят.
    local wep = att.GetActiveWeapon and att:GetActiveWeapon()
    if not (IsValid(wep) and wep:GetClass() == "weapon_polus11_thing") then return end

    -- ЛИЧНОСТЬ СНИМАЕМ СЕЙЧАС, с живого тела (не с трупа через кадр)
    local id = POLUS11.ThingCaptureIdentity(victim)
    if not id then return end
    local pos = victim:GetPos()

    timer.Simple(DEVOUR_DELAY, function()
        if not (IsValid(att) and att:Alive() and IsThing(att)) then return end

        -- труп жертвы съеден: убираем ragdoll (трекер обычно успевает
        -- пометить его к этому моменту; на всякий случай — и свежий
        -- непомеченный с моделью жертвы)
        for _, e in ipairs(ents.FindInSphere(pos, 95)) do
            if IsValid(e) and e:GetClass() == "prop_ragdoll" then
                local tagged = istable(e.P11_Identity) and e.P11_Identity.nick == id.nick
                local freshTwin = (not e.P11_Identity)
                    and (CurTime() - e:GetCreationTime()) < 3
                    and isstring(id.model) and e:GetModel() == id.model
                if tagged or freshTwin then e:Remove() end
            end
        end

        if POLUS11.ThingApplyIdentity(att, id) then
            DevourFinish(att, id, pos)
        end
    end)
end)

-- ============ 2) R-СЪЕДЕНИЕ ЧУЖОГО ТРУПА (ручное, из когтей) ============
-- Труп с личностью от трекера p11_sv_infection (P11_Identity +
-- P11_CorpseName). Возвращает true, если съел.
function POLUS11.ThingDevourCorpse(ply, corpse)
    if not (IsValid(ply) and ply:Alive() and IsValid(corpse)) then return false end
    local id = corpse.P11_Identity
    if not istable(id) then return false end

    local pos = corpse:GetPos()
    timer.Simple(0.2, function()
        if IsValid(corpse) then corpse:Remove() end
    end)

    if not POLUS11.ThingApplyIdentity(ply, id) then return false end
    DevourFinish(ply, id, pos)
    return true
end

print("[POLUS-11] ЯДРО НЕЧТО «ЛИЧИНА 2.0» v4.8.8: убийство когтями Имитатора САМО жрёт труп жертвы и надевает её личину (без трупо-гонок старой схемы); R-съедение и снятие личины — на ядре")
