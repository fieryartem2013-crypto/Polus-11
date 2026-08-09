-- ============================================================
--  ПОЛЮС-11 — УЛИКИ «СЛЕД» (server) v4.20.0
--  Заявка владельца (банк аналитики №3): «место поглощения
--  оставляет обрывок (форма/документ/след), НКВД собирает 2–3 →
--  профиль: профа/рост/время БЕЗ имени — даёт детективу
--  инструмент взамен меток».
--
--  КАК ЖИВЁТ:
--   • ядро Нечто дёргает hook Polus11.ThingDevoured — на месте
--     трапезы остаётся УЛИКА (энтити polus_p11_clue, 3 вида);
--   • улика помнит: ДОЛЖНОСТЬ жертвы, ~рост (168–192) и время
--     атаки. ИМЕНИ жертвы НЕТ и не будет — только РП-профиль;
--   • E по улике: следственная группа НКВД (категория nkvd)
--     кладёт находку в планшет-досье (максимум 8 записей);
--     посторонних прогоняет, а НЕЧТО (заражённый/активный) может
--     улику УНИЧТОЖИТЬ — следы подчищает сам;
--   • досье: чат !улики — список находок + сводный ПРОФИЛЬ
--     («цели: Полевой медик, Техник…; рост ~181; атаки 21:04–23:40»).
--     Профиль считается от 2 улик (п. заявки «собирает 2–3»);
--   • жизнь улики 10 минут; живых одновременно ≤ 14; за сданную
--     улику следователю — 50₽ оперативных расходов.
-- ============================================================

util.AddNetworkString("P11_ClueSync")
util.AddNetworkString("P11_ClueOpen")

local MAX_ALIVE   = 14
local CLUE_LIFE   = 600  -- сек жизни находки
local DOSSIER_MAX = 8    -- записей в планшете следователя
local CLUE_PAY    = 50   -- оперативные за сданную улику

POLUS11.ClueKinds = {
    { id = "forma", name = "обрывок формы",     model = "models/props_c17/paper01.mdl" },
    { id = "doc",   name = "смятый документ",   model = "models/props_lab/clipboard.mdl" },
    { id = "sled",  name = "брошенный ботинок", model = "models/props_junk/shoe001a.mdl" },
}

POLUS11.ClueDossier = POLUS11.ClueDossier or {} -- [sid] = { rec, ... } (живёт сессию карты)

-- должность и категория по индексу команды жертвы
local function JobInfo(teamIdx)
    teamIdx = tonumber(teamIdx) or 0
    local jid = P11FW and P11FW.TeamJobs and P11FW.TeamJobs[teamIdx]
    local jt  = jid and P11FW.Jobs and P11FW.Jobs[jid]
    local name = (jt and jt.name) or (teamIdx > 0 and team.GetName(teamIdx)) or "неизвестно"
    local cat  = (jt and (jt.category or jt.faction)) or "misc"
    return name, cat
end

-- ============ СПАВН НА МЕСТЕ ПОГЛОЩЕНИЯ ============
hook.Add("Polus11.ThingDevoured", "P11.ClueDrop", function(ply, identity)
    if not IsValid(ply) then return end -- ply = невидимый гость на трапезе

    local alive = ents.FindByClass("polus_p11_clue")
    if #alive >= MAX_ALIVE then
        table.sort(alive, function(a, b) return (a.P11_SpawnT or 0) < (b.P11_SpawnT or 0) end)
        if IsValid(alive[1]) then alive[1]:Remove() end
    end

    local k = POLUS11.ClueKinds[math.random(#POLUS11.ClueKinds)]
    local e = ents.Create("polus_p11_clue")
    if not IsValid(e) then return end
    local ang = math.rad(math.random(0, 359))
    local off = Vector(math.cos(ang), math.sin(ang), 0) * math.random(18, 46)
    e:SetPos(ply:GetPos() + off + Vector(0, 0, 6))
    e:SetAngles(Angle(0, math.random(0, 360), 0))
    e:Spawn()

    local jname, jcat = JobInfo(identity and identity.job)
    e.P11_KindName   = k.name
    e.P11_Model      = k.model
    if e.P11ApplyLook then e:P11ApplyLook() end
    e.P11_VictimJob  = jname
    e.P11_VictimCat  = jcat
    e.P11_VictimH    = math.random(168, 192)
    e.P11_VictimTime = os.date("%H:%M")
    e.P11_SpawnT     = CurTime()
    e.P11_DieT       = CurTime() + CLUE_LIFE
    e:SetNWString("P11_ClueKind", k.name)
end)

-- ============ ДОПУСКИ ============
local function IsDetective(ply)
    if not IsValid(ply) then return false end
    local j = P11FW and P11FW.GetJob and P11FW.GetJob(ply)
    if j and (j.category or j.faction) == "nkvd" then return true end
    return P11FW.Config and P11FW.Config.Admin and P11FW.Config.Admin(ply) or false
end

local function IsThing(ply)
    return IsValid(ply) and (ply:GetNWBool("P11_InfActive", false) or ply:GetNWBool("P11_Infected", false))
end

-- ============ ПРОФИЛЬ (от 2 улик; имён — никогда) ============
local function ProfileOf(arr)
    if #arr < 2 then return nil end
    local jobSet, catSet, jobs, cats = {}, {}, {}, {}
    local hsum, tmin, tmax = 0, nil, nil
    for _, r in ipairs(arr) do
        if r.job and not jobSet[r.job] then jobSet[r.job] = true jobs[#jobs + 1] = r.job end
        if r.cat and not catSet[r.cat] then catSet[r.cat] = true cats[#cats + 1] = r.cat end
        hsum = hsum + (tonumber(r.h) or 180)
        local t = tostring(r.time or "")
        if t ~= "" then
            if not tmin or t < tmin then tmin = t end
            if not tmax or t > tmax then tmax = t end
        end
    end
    return {
        jobs = jobs, cats = cats,
        havg = math.floor(hsum / #arr + 0.5),
        tmin = tmin or "?:??", tmax = tmax or "?:??",
        n = #arr,
    }
end

local CAT_NAMES = {
    rkka = "гарнизон РККА", nkvd = "особый отдел", science = "наука",
    personnel = "обслуга", eagle = "иногородние", crime = "теневики",
    nechto = "нечто", vip = "особые", misc = "без назначения",
}
local function CatName(id) return CAT_NAMES[id] or id end

function POLUS11.ClueDossierSync(ply)
    if not IsValid(ply) then return end
    local arr = POLUS11.ClueDossier[ply:SteamID()] or {}
    local prof = ProfileOf(arr)
    local ptxt = nil
    if prof then
        local jlines = {}
        for _, jn in ipairs(prof.jobs) do jlines[#jlines + 1] = jn end
        local clines = {}
        for _, c in ipairs(prof.cats) do clines[#clines + 1] = CatName(c) end
        ptxt = {
            jobs = table.concat(jlines, ", "),
            cats = table.concat(clines, ", "),
            havg = prof.havg, tmin = prof.tmin, tmax = prof.tmax, n = prof.n,
        }
    end
    net.Start("P11_ClueSync")
        net.WriteString(util.TableToJSON({ list = arr, prof = ptxt }) or "{}")
    net.Send(ply)
end

-- ============ СБОР (зовёт энтити из ENT:Use) ============
function POLUS11.ClueCollect(ply, ent)
    if not (IsValid(ply) and IsValid(ent)) then return end

    if IsDetective(ply) then
        local rec = {
            kind = ent.P11_KindName or "улика",
            job  = ent.P11_VictimJob or "неизвестно",
            cat  = ent.P11_VictimCat or "misc",
            h    = ent.P11_VictimH or 180,
            time = ent.P11_VictimTime or "?:??",
        }
        local sid = ply:SteamID()
        local arr = POLUS11.ClueDossier[sid] or {}
        arr[#arr + 1] = rec
        while #arr > DOSSIER_MAX do table.remove(arr, 1) end
        POLUS11.ClueDossier[sid] = arr
        local kindName = rec.kind
        ent:Remove()

        ply:EmitSound("npc/roller/remote_yip.wav", 55, 120)
        if POLUS11.AddMoney then POLUS11.AddMoney(ply, CLUE_PAY, "сдана улика: " .. kindName) end
        if POLUS11.TaskEvent then POLUS11.TaskEvent(ply, "clue_turn") end -- v4.21.0 «ДРЕВО»: опыт службы (+30)
        POLUS11.Log("УЛИКА СДАНА: " .. ply:Nick() .. " — «" .. kindName .. "» (жертва: " .. rec.job .. ", " .. rec.time .. ")")

        local prof = ProfileOf(arr)
        if prof then
            POLUS11.Notify(ply, "УЛИКА «" .. kindName .. "» в досье (" .. #arr .. "/" .. DOSSIER_MAX ..
                "). ПРОФИЛЬ: цели — " .. table.concat(prof.jobs, ", ") .. "; рост ~" .. prof.havg ..
                " см; атаки " .. prof.tmin .. "–" .. prof.tmax .. ". Всё досье: !улики")
        else
            POLUS11.Notify(ply, "УЛИКА «" .. kindName .. "» в досье (" .. #arr .. "/" .. DOSSIER_MAX ..
                "). Для ПРОФИЛЯ нужна ещё минимум одна находка. Досье: !улики")
        end
        POLUS11.ClueDossierSync(ply)

    elseif IsThing(ply) then
        local kn = ent.P11_KindName or "улика"
        ent:Remove()
        POLUS11.Notify(ply, "Следы подчищены: «" .. kn .. "» больше не существует.")
        ply:EmitSound("ambient/materials/squeekyfloor1.wav", 45, 80)
        POLUS11.Log("УЛИКА УНИЧТОЖЕНА НЕЧТО: " .. ply:Nick() .. " — «" .. kn .. "»")

    else
        ply.P11_ClueHintCd = ply.P11_ClueHintCd or 0
        if CurTime() >= ply.P11_ClueHintCd then
            ply.P11_ClueHintCd = CurTime() + 3
            POLUS11.Notify(ply, "НЕ ТРОНЬ! Это улика («" .. (ent.P11_KindName or "?") ..
                "») — зови следователя НКВД. Осквернение места происшествия — статья.")
        end
    end
end

-- ============ ЧАТ: !улики ============
hook.Add("PlayerSay", "P11.ClueSay", function(ply, text)
    local raw = string.Trim(tostring(text or ""))
    if raw ~= "!улики" and raw ~= "!УЛИКИ" and raw ~= "!uliki" and raw ~= "!clues" then return end
    if not IsDetective(ply) then
        POLUS11.Notify(ply, "Планшет улик — у следственной группы НКВД. Нашёл что-то странное — сообщи оперу.")
        return ""
    end
    POLUS11.ClueDossierSync(ply)
    net.Start("P11_ClueOpen")
    net.Send(ply)
    return ""
end)
