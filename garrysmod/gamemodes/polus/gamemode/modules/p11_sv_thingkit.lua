-- ============================================================
--  ПОЛЮС-11 — НЕЧТО «ЛИЧИНА 3.0» (server) v4.10.0 «ГАРАЖ»
--  ЗАЯВКА ВЛАДЕЛЬЦА: «нечто не может маскироваться — почини с
--  чистого листа, прям с нового, чтобы работало; там было меню
--  мутаций и так далее».
--
--  ПЕРЕПИСАНО НАЧИСТО, ОДНИМ ЦЕЛЬНЫМ ОРГАНОМ (файл включён
--  ПОСЛЕДНИМ в серверном списке — его версии функций выигрывают
--  у старых по времени вызова):
--   1) КИБОРГ-ЦЕПЬ МАСКИРОВКИ (ТК-API): снять личность / надеть
--      личину / снять личину — с тем же сетевым контрактом, что
--      видят TAB/никнеймы/документы (P11_FakeNick/FakeJob/FakeDesc).
--   2) АВТО-ПОГЛОЩЕНИЕ: убийство КОГТЯМИ активного Нечто → через
--      0.35 сек труп жертвы съеден, а личина (облик+позывной+
--      должность+документ) уже на охотнике. Каждый шаг кричит
--      в консоль сервера [TK] — «не работает» теперь ДИАГНОСТИРУЕМО.
--   3) ЯВЛЕНИЕ/СКРЫТИЕ формы монстра — свои reveal/hide (глобалы
--      POLUS11_RevealThing/POLUS11_HideThing подменены этими).
--   4) КОГТИ-СТРАХОВЬ: активному Нечто без когтей — вернуть, раз
--      в 2 сек (корень классического «меню мёртво» — когтей нет).
--   5) НОВЫЙ КАНАЛ МЕНЮ: P11_TKit (mask/unmask/form/spider/test) —
--      каждая кнопка отвечает в ЧАТ и звуком: видно, что случилось.
--   Старая ветка v4.8.8 отключается флагом ниже (её хук сам молчит).
--
--  ДИАГНОСТИКА ИГРОКОМ: консоль «p11_thingtest» (публичная; чат
--  ответит по шагам: заражён? активен? когти в руках? личина?).
-- ============================================================

-- выключаем старую ветку v4.8.8 (её PlayerDeath молчит по этому флагу)
if POLUS11.Config then POLUS11.Config.ThingAutoDevour = false end

util.AddNetworkString("P11_TKit")

local DEVOUR_DELAY = 0.35
local DEVOUR_HEAL  = 25
local REVEAL_TIME  = 20

local CLAW_WEPS = {
    weapon_polus11_thing = true, weapon_polus11_thing_split = true,
    weapon_polus11_thing_brute = true, weapon_polus11_thing_spore = true,
}

local function IsThing(ply)
    return IsValid(ply)
        and ply:GetNWBool("P11_Infected", false)
        and ply:GetNWBool("P11_InfActive", false)
end

local function Tell(ply, msg)
    -- и тоаст, и строчка в чат — под BonChat гарантированно видно хоть что-то
    if POLUS11.Notify then POLUS11.Notify(ply, msg) end
    ply:ChatPrint("[НЕЧТО] " .. msg)
end

local function TKLog(msg)
    print("[TK] " .. msg)
    if POLUS11.Log then POLUS11.Log("НЕЧТО·ТК: " .. msg) end
end

-- ============ 1) СНЯТЬ ЛИЧНОСТЬ (с живого тела) ============
local function TK_Capture(v)
    if not IsValid(v) then return nil end
    local bg = {}
    for i = 0, v:GetNumBodyGroups() - 1 do
        bg[i] = v:GetBodygroup(i)
    end
    local id = {
        nick  = v:Nick(),
        model = v:GetModel(),
        skin  = v:GetSkin(),
        color = v:GetColor(),
        pcolor = v:GetPlayerColor(),
        wcolor = v:GetWeaponColor(),
        bodygroups = bg,
        doc   = v:GetNWString("P11_DocCode", ""),
        job   = v:Team(),
        desc  = v:GetNWString("P11_CharDesc", ""),
    }
    local cn = v:GetNWString("P11_CharName", "")
    if cn ~= "" then id.nick = cn end
    local worn = v:GetNWString("P11_FakeNick", "")
    if worn ~= "" then id.nick = worn end -- цепочка личин: тварь в лице отдаёт лицо дальше
    return id
end

-- ============ 2) НАДЕТЬ ЛИЧИНУ ============
local function TK_Apply(ply, id)
    if not (IsValid(ply) and ply:Alive() and istable(id)) then return false, "нет личности" end

    -- если явлен монстром — спрятаться тихо (иначе автотаймер сорвёт облик)
    if ply.P11_Revealed and POLUS11_HideThing then POLUS11_HideThing(ply) end

    -- СВОЁ лицо запоминается ровно один раз (возврат к человеку)
    if not ply.P11_TrueIdentity then
        local bg = {}
        for i = 0, ply:GetNumBodyGroups() - 1 do
            bg[i] = ply:GetBodygroup(i)
        end
        ply.P11_TrueIdentity = {
            model = ply:GetModel(), skin = ply:GetSkin(), color = ply:GetColor(),
            pcolor = ply:GetPlayerColor(), wcolor = ply:GetWeaponColor(), bodygroups = bg,
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

    -- свой код документа прячем (вернём при снятии личины)
    if ply.P11_OwnDoc == nil then
        ply.P11_OwnDoc = ply:GetNWString("P11_DocCode", "")
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

-- ============ 3) СНЯТЬ ЛИЧИНУ (вернуть СЕБЯ) ============
local function TK_Drop(ply)
    if not IsValid(ply) then return end
    local a = ply.P11_TrueIdentity
    if not a then return end

    if isstring(a.model) and file.Exists(a.model, "GAME") then ply:SetModel(a.model) end
    ply:SetSkin(a.skin or 0)
    ply:SetColor(a.color or Color(255, 255, 255))
    if isvector(a.pcolor) then ply:SetPlayerColor(a.pcolor) end
    if isvector(a.wcolor) then ply:SetWeaponColor(a.wcolor) end
    local maxBg = ply:GetNumBodyGroups()
    for k, v in pairs(a.bodygroups or {}) do
        if isnumber(k) and k < maxBg then ply:SetBodygroup(k, v) end
    end

    ply.P11_FakeNick = nil
    ply.P11_Revealed = false
    ply.P11_RevealedAt = 0
    ply:SetNWBool("P11_Revealed", false)
    ply:SetNWString("P11_FakeNick", "")
    ply:SetNWInt("P11_FakeJob", 0)
    ply:SetNWString("P11_FakeDesc", "")
    if ply.P11_OwnDoc ~= nil then
        ply:SetNWString("P11_DocCode", ply.P11_OwnDoc)
        ply.P11_OwnDoc = nil
    end
end

-- ============ ЯВЛЕНИЕ/СКРЫТИЕ МОНСТРА (глобалы подменены — СТРОГО эти) ============

function POLUS11_RevealThing(ply)
    if not IsValid(ply) or ply.P11_Revealed then return end
    if not ply.P11_SavedModel then ply.P11_SavedModel = ply:GetModel() end

    ply.P11_Revealed = true
    ply.P11_RevealedAt = CurTime()
    ply:SetNWBool("P11_Revealed", true)

    -- операторская модель монстра по текущей форме (своё тело — своё)
    local mdl = (POLUS11.MonsterModels and POLUS11.MonsterModels.brute) or "models/zombie/poison.mdl"
    local forms = POLUS11.ThingForms or {}
    local form = forms[ply.P11_ThingForm or ""]
    if form and isstring(form.model) then mdl = form.model end
    if (ply:GetNWInt("P11_MutTier", 0) or 0) >= 3 then
        mdl = "models/zombie/fast.mdl" -- мутация Т3 «АРАХНА» поверх любой формы
    end
    ply:SetModel(mdl)

    -- тяжёлое тело Поглотителя возвращается вместе с явлением
    if ply.P11_ThingForm == "brute" and P11_BruteApply and ply:HasWeapon("weapon_polus11_thing_brute") then
        P11_BruteApply(ply)
    end

    ply:EmitSound("npc/zombie_poison/pz_alert2.wav", 85, 90)
    local ed = EffectData()
    ed:SetOrigin(ply:GetPos() + Vector(0, 0, 40))
    util.Effect("BloodImpact", ed, true, true)

    TKLog("РАСКРЫЛСЯ: " .. ply:Nick())

    timer.Simple(REVEAL_TIME, function()
        if IsValid(ply) and ply.P11_Revealed then
            POLUS11_HideThing(ply)
        end
    end)
end

function POLUS11_HideThing(ply)
    if not IsValid(ply) or not ply.P11_Revealed then return end
    ply.P11_Revealed = false
    ply:SetNWBool("P11_Revealed", false)

    if ply.P11_ThingForm == "brute" and P11_BruteRemove then
        P11_BruteRemove(ply)
    end

    if ply.P11_SavedModel then
        ply:SetModel(ply.P11_SavedModel)
        ply.P11_SavedModel = nil
    end
end

-- маскировка вкл/выкл (из меню P11_TKit + !маскировка)
function POLUS11.ToggleMask(ply)
    if not IsThing(ply) then
        Tell(ply, "Это доступно только активному Нечто (заражение должно проснуться).")
        return
    end
    ply.P11_NextMask = ply.P11_NextMask or 0
    if CurTime() < ply.P11_NextMask then return end
    ply.P11_NextMask = CurTime() + 1.2

    if ply.P11_Revealed then
        if CurTime() - (ply.P11_RevealedAt or 0) < 4 then
            Tell(ply, "Плоть ещё горячая — подожди пару секунд, потом спрячешься.")
            return
        end
        POLUS11_HideThing(ply)
        ply:EmitSound("npc/zombie/zombie_voice_idle2.wav", 60, 90)
        Tell(ply, "Маскировка: ты снова выглядишь как человек.")
        TKLog(ply:Nick() .. " скрыл форму")
    else
        POLUS11_RevealThing(ply)
        Tell(ply, "ФОРМА ЯВЛЕНА на " .. REVEAL_TIME .. " сек. Все увидели тварь.")
    end
end

-- ============ 4) ЛИЧНОСТЬ ПОГЛОЩЕНА: сводка + эффекты ============
local function Devoured(ply, id, pos)
    hook.Run("Polus11.ThingDevoured", ply, id) -- мутации считают жертву сами

    ply:EmitSound("npc/barnacle/barnacle_digesting1.wav", 75, 90)
    local ed = EffectData()
    ed:SetOrigin((pos or ply:GetPos()) + Vector(0, 0, 20))
    util.Effect("BloodImpact", ed, true, true)
    util.Effect("bloodspray", ed, true, true)

    local maxhp = ply:GetMaxHealth()
    if maxhp <= 0 then maxhp = 100 end
    ply:SetHealth(math.min(maxhp, ply:Health() + DEVOUR_HEAL))

    local jobLine = ""
    if P11FW and P11FW.TeamJobs and tonumber(id.job) then
        local jid = P11FW.TeamJobs[tonumber(id.job)]
        local jt = jid and P11FW.Jobs and P11FW.Jobs[jid]
        if jt and jt.name then jobLine = " · " .. jt.name end
    end
    Tell(ply, "🩸 Личность поглощена: «" .. tostring(id.nick) .. "»" .. jobLine ..
        ". TAB/чат/документы видят личину. R → пульт тела (снять личину там).")
    TKLog("ЛИЧИНА НАДЕТА: " .. ply:Nick() .. " стал «" .. tostring(id.nick) .. "»" .. jobLine)
end

-- ============ 5) АВТО-ПОГЛОЩЕНИЕ ПРИ УБИЙСТВЕ ============
hook.Add("PlayerDeath", "P11.TKAutoDevour", function(victim, inf, att)
    if not (IsValid(victim) and victim:IsPlayer()) then return end
    if not (IsValid(att) and att:IsPlayer() and att ~= victim and att:Alive()) then return end
    if not IsThing(att) then return end

    local wep = att.GetActiveWeapon and att:GetActiveWeapon()
    if not (IsValid(wep) and wep:GetClass() == "weapon_polus11_thing") then return end

    local id = TK_Capture(victim)
    if not id then return end
    local pos = victim:GetPos()
    TKLog("убийство когтями: " .. att:Nick() .. " → " .. victim:Nick() ..
        ", личность снята, поглощение через " .. DEVOUR_DELAY .. "с")

    timer.Simple(DEVOUR_DELAY, function()
        if not (IsValid(att) and att:Alive() and IsThing(att)) then
            TKLog("поглощение сорвалось: охотник ушёл/умер/отпал")
            return
        end

        -- труп жертвы съеден: убираем свежий ragdoll тела
        local eaten = 0
        for _, e in ipairs(ents.FindInSphere(pos, 110)) do
            if IsValid(e) and e:GetClass() == "prop_ragdoll" then
                local tagged = istable(e.P11_Identity) and e.P11_Identity.nick == id.nick
                local freshTwin = (not e.P11_Identity)
                    and (CurTime() - e:GetCreationTime()) < 4
                    and isstring(id.model) and e:GetModel() == id.model
                if tagged or freshTwin then e:Remove() eaten = eaten + 1 end
            end
        end

        local ok, why = TK_Apply(att, id)
        if ok then
            Devoured(att, id, pos)
        else
            TKLog("НЕ НАДЕЛАСЬ личина «" .. tostring(id.nick) .. "»: " .. tostring(why))
        end
        TKLog("трупов съедено: " .. eaten)
    end)
end)

-- ============ 6) R-СЪЕДЕНИЕ ТРУПА (ручное, из когтей) ============
-- подменяет старую POLUS11.ThingDevourCorpse (SWEP зовёт по имени).
function POLUS11.ThingDevourCorpse(ply, corpse)
    if not (IsValid(ply) and ply:Alive() and IsValid(corpse)) then return false end
    local id = corpse.P11_Identity
    if not istable(id) then
        Tell(ply, "Этот труп уже пуст — личность выедена.")
        return false
    end
    local pos = corpse:GetPos()
    timer.Simple(0.2, function()
        if IsValid(corpse) then corpse:Remove() end
    end)
    if not TK_Apply(ply, id) then return false end
    Devoured(ply, id, pos)
    return true
end

-- экспорт ТК-API наружу (совместимость имён v4.8.8)
POLUS11.ThingCaptureIdentity = TK_Capture
POLUS11.ThingApplyIdentity   = TK_Apply
function POLUS11.ThingRestoreIdentity(ply) TK_Drop(ply) end
POLUS11_RestoreTrueIdentity  = POLUS11.ThingRestoreIdentity

-- ============ 7) КОГТИ-СТРАХОВЬ (корень «меню не открывается») ============
timer.Create("P11.TKClawGuard", 2, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() and IsThing(ply) then
            local has = false
            for cls in pairs(CLAW_WEPS) do
                if ply:HasWeapon(cls) then has = true break end
            end
            if not has then
                ply:Give("weapon_polus11_thing")
                Tell(ply, "Когти вернулись в ладони (пульт тела — на R).")
                TKLog("когти перевыданы: " .. ply:Nick() .. " (были потеряны)")
            end
        end
    end
end)

-- ============ 8) КАНАЛ МЕНЮ P11_TKit (кнопки → сервер) ============
local FORM_CD = function() return (POLUS11.Config and POLUS11.Config.ClassSwitchCooldown) or 60 end

net.Receive("P11_TKit", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local act = net.ReadString()

    -- диагностика доступна всем (и НЕ-Нечто тоже — скажет, чего не хватает)
    if act == "test" then
        local wep = IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon():GetClass() or "?"
        local anyClaw = false
        for cls in pairs(CLAW_WEPS) do
            if ply:HasWeapon(cls) then anyClaw = true break end
        end
        local lines = {
            "== НЕЧТО-ДИАГНОСТИКА (ЛИЧИНА 3.0) ==",
            "  заражён (P11_Infected): " .. tostring(ply:GetNWBool("P11_Infected", false)),
            "  активен (P11_InfActive): " .. tostring(ply:GetNWBool("P11_InfActive", false)),
            "  когти в снаряге: " .. tostring(anyClaw) .. " | в руках: " .. wep,
            "  форма: " .. ply:GetNWString("P11_ThingForm", "imitator"),
            "  явлен монстром: " .. tostring(ply:GetNWBool("P11_Revealed", false)),
            "  личина: «" .. ply:GetNWString("P11_FakeNick", "") .. "» (пусто = нет)",
            "  жертв/тир: " .. ply:GetNWInt("P11_MutKills", 0) .. "/" .. ply:GetNWInt("P11_MutTier", 0),
            "  авто-ПОГЛОЩЕНИЕ работает так: убей человека КОГТЯМИ Имитатора →",
            "  через 0.35 сек труп исчезает, а ты становишься им (облик+позывной).",
            "  если не так — пришли этот вывод Главе + строчки [TK] из консоли сервера.",
        }
        for _, ln in ipairs(lines) do ply:ChatPrint(ln) end
        ply:PrintMessage(HUD_PRINTCONSOLE, table.concat(lines, "\n"))
        TKLog("diag: " .. ply:Nick() .. " inf=" .. tostring(ply:GetNWBool("P11_Infected", false)) ..
            " act=" .. tostring(ply:GetNWBool("P11_InfActive", false)) .. " claws=" .. tostring(anyClaw))
        return
    end

    -- дальше — только активному Нечто
    if not IsThing(ply) then
        Tell(ply, "Пульт тела работает только у активного Нечто. " ..
            (ply:GetNWBool("P11_Infected", false) and "Инкубация ещё идёт — жди пробуждения."
                or "Ты не заражён: вакансия у кадровика / укол твари / админ-пульт."))
        return
    end

    if act == "mask" then
        POLUS11.ToggleMask(ply)

    elseif act == "unmask" then
        if not ply:GetNWString("P11_FakeNick", "") or ply:GetNWString("P11_FakeNick", "") == "" then
            if not ply.P11_FakeNick then
                Tell(ply, "Ты сейчас не в чужой личине (съешь труп когтями или R по трупу).")
                return
            end
        end
        if CurTime() - (ply.P11_IdentityTakenAt or 0) < 5 then
            Tell(ply, "Ещё перевариваю жертву… " ..
                math.ceil(5 - (CurTime() - ply.P11_IdentityTakenAt)) .. " сек.")
            return
        end
        TK_Drop(ply)
        ply:EmitSound("npc/zombie/zombie_voice_idle2.wav", 60, 90)
        Tell(ply, "Чужая личина сброшена — ты снова сам(а).")
        TKLog("личина снята вручную: " .. ply:Nick())

    elseif act == "form" then
        local formId = net.ReadString()
        if not (POLUS11.ThingForms and POLUS11.ThingForms[formId]) then return end
        ply.P11_NextForm = ply.P11_NextForm or 0
        if CurTime() < ply.P11_NextForm then
            Tell(ply, "Форму можно сменить через " .. math.ceil(ply.P11_NextForm - CurTime()) .. " сек.")
            return
        end
        if POLUS11.SetThingForm and POLUS11.SetThingForm(ply, formId) then
            ply.P11_NextForm = CurTime() + FORM_CD()
            ply:SetNWFloat("P11_FormCd", ply.P11_NextForm)
            Tell(ply, "Форма сменена: «" .. POLUS11.ThingForms[formId].name .. "». Способность формы — ПКМ.")
        end

    elseif act == "spider" then
        if (ply.P11_ThingForm or "") ~= "split" then
            Tell(ply, "Паучья форма есть только у «Разделённого».")
            return
        end
        if ply.P11_Revealed then
            POLUS11_HideThing(ply)
            Tell(ply, "Паучья туша убрана — снова человек.")
        else
            POLUS11_RevealThing(ply)
            Tell(ply, "Паучья туша явлена.")
        end
    end
end)

-- диагностика из консоли (публичная — занесена в замок p11_sv_cmdlock)
concommand.Add("p11_thingtest", function(ply)
    if not IsValid(ply) then
        -- из серверной консоли: общий статус всех заражённых
        print("== НЕЧТО-СТАТУС СЕРВЕРА ==")
        for _, p in ipairs(player.GetAll()) do
            if p:GetNWBool("P11_Infected", false) then
                print("  " .. p:Nick() .. " inf=1 active=" .. tostring(p:GetNWBool("P11_InfActive", false)) ..
                    " form=" .. p:GetNWString("P11_ThingForm", "?") ..
                    " fake=«" .. p:GetNWString("P11_FakeNick", "") .. "»")
            end
        end
        return
    end
    -- у игрока: та же диагностика, что кнопка ДИАГНОСТИКА в пульте тела
    local anyClaw = false
    for cls in pairs(CLAW_WEPS) do
        if ply:HasWeapon(cls) then anyClaw = true break end
    end
    local lines = {
        "== НЕЧТО-ДИАГНОСТИКА (ЛИЧИНА 3.0) ==",
        "  заражён (P11_Infected): " .. tostring(ply:GetNWBool("P11_Infected", false)),
        "  активен (P11_InfActive): " .. tostring(ply:GetNWBool("P11_InfActive", false)),
        "  когти в снаряге: " .. tostring(anyClaw),
        "  форма: " .. ply:GetNWString("P11_ThingForm", "imitator"),
        "  явлен монстром: " .. tostring(ply:GetNWBool("P11_Revealed", false)),
        "  личина: «" .. ply:GetNWString("P11_FakeNick", "") .. "» (пусто = нет)",
        "  жертв/тир: " .. ply:GetNWInt("P11_MutKills", 0) .. "/" .. ply:GetNWInt("P11_MutTier", 0),
        "  авто-ПОГЛОЩЕНИЕ: убей человека КОГТЯМИ Имитатора → через 0.35 сек",
        "  труп исчезает, а ты становишься им. Лог шагов: [TK] в консоли сервера.",
    }
    for _, ln in ipairs(lines) do ply:ChatPrint(ln) end
    ply:PrintMessage(HUD_PRINTCONSOLE, table.concat(lines, "\n"))
end)

print("[POLUS-11] НЕЧТО «ЛИЧИНА 3.0» v4.10.0: маскировка переписана начисто — ТК-API, " ..
    "автопоглощение с логом [TK], когти-страховь, пульт тела P11_TKit, diag p11_thingtest")
