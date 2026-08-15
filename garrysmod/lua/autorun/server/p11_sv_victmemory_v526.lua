-- ============================================================
--  ПОЛЮС-11 — ПАМЯТЬ ЖЕРТВЫ (server) v5.2.6 (НОВЫЙ ФАЙЛ, autorun)
--  Идея владельца №15: «Нечто, поглотив игрока, получает фрагменты
--  его памяти (последние действия/место) и может врать убедительнее
--  в допросах. Разум жертвы — расширить».
--
--  Как работает:
--   • при смерти игрока снимаем «снимок» (где был, на дежурстве ли,
--     в розыске, звание смены) — кладём на энтити жертвы;
--   • при поглощении (хук Polus11.ThingDevoured — тот же, что у
--     «Разума жертвы») Нечто получает ПАМЯТЬ: ник + должность +
--     место + пост + розыск + документ (до 3 личностей);
--   • команда «!память» — показать фрагменты (тварь в личине может
--     врать в допросах по РП, НКВД ловит на нестыковках).
--  Старые файлы не трогаем — всё в autorun/server.
-- ============================================================

POLUS_BUILD = "5.2.6"

local function IsThing(ply)
    return IsValid(ply)
        and ply:GetNWBool("P11_Infected", false)
        and ply:GetNWBool("P11_InfActive", false)
end

-- ============ ИМЕНА ЗОН СТАНЦИИ (по ближайшей энтити) ============

local ZONES = {
    polus_fw_jobnpc        = "у кадровика",
    polus_p11_shopnpc      = "у ларька снабжения",
    polus_p11_evshop       = "у интенданта ярмарки",
    polus11_terminal       = "у сменного терминала",
    polus11_bloodlab       = "в лаборатории (анализ крови)",
    polus11_labtable       = "у лабораторного стола",
    polus11_crafttable     = "у верстака",
    polus_p11_kitchen      = "на кухне",
    polus11_hearth         = "у буржуйки",
    polus_p11_contractnpc  = "у нарядника",
    polus_p11_stashnpc     = "у кладмена",
    polus_p11_jailnpc      = "у караула",
    polus11_cappoint       = "у точки захвата",
    polus_p11_raidterm     = "у терминала рейда",
}

local function ZoneName(pos)
    if not pos then return "на станции" end
    local best, bestD = nil, 700 * 700
    for cls, lbl in pairs(ZONES) do
        for _, e in ipairs(ents.FindByClass(cls)) do
            if IsValid(e) then
                local d = e:GetPos():DistToSqr(pos)
                if d < bestD then best, bestD = lbl, d end
            end
        end
    end
    if best then return best end
    return string.format("в районе координат %d,%d", math.floor(pos.x / 100), math.floor(pos.y / 100))
end

-- ============ СНИМОК ЖЕРТВЫ ПРИ СМЕРТИ ============

hook.Add("PlayerDeath", "P11.VictMemDeath", function(victim)
    if not IsValid(victim) or not victim:IsPlayer() then return end
    victim.P11_MemSnapshot = {
        pos    = victim:GetPos(),
        duty   = victim:GetNWString("P11_DutyLoc", ""),
        wanted = victim:GetNWString("P11_Wanted", ""),
        title  = victim:GetNWString("P11_Title", ""),
        at     = os.time(),
    }
end)

-- найти мёртвую жертву по нику из identity (снимок на энтити)
local function FindVictim(identity)
    local nick = identity and identity.nick
    if not nick then return nil end
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and not p:Alive() and p.P11_MemSnapshot and p:Nick() == nick then
            return p
        end
    end
    return nil
end

-- ============ ПОГЛОЩЕНИЕ → ПАМЯТЬ ============

hook.Add("Polus11.ThingDevoured", "P11.VictMemDevour", function(ply, identity)
    if not IsValid(ply) or not IsThing(ply) then return end
    if not identity or not identity.nick then return end

    local v = FindVictim(identity)
    local snap = v and v.P11_MemSnapshot

    local jobName = "?"
    if P11FW and P11FW.TeamJobs and tonumber(identity.job) then
        local jid = P11FW.TeamJobs[tonumber(identity.job)]
        local jt = jid and P11FW.Jobs and P11FW.Jobs[jid]
        if jt and jt.name then jobName = jt.name end
    end

    local mem = {
        nick   = identity.nick,
        job    = jobName,
        doc    = identity.doc or "",
        zone   = snap and ZoneName(snap.pos) or "неизвестно",
        duty   = (snap and snap.duty) or "",
        wanted = (snap and snap.wanted) or "",
        title  = (snap and snap.title) or "",
        at     = os.time(),
    }

    ply.P11_Mem = ply.P11_Mem or {}
    table.insert(ply.P11_Mem, mem)
    if #ply.P11_Mem > 3 then table.remove(ply.P11_Mem, 1) end

    -- авто-шепот твари: краткая сводка, чтобы врать в допросах
    timer.Simple(1, function()
        if not IsValid(ply) then return end
        local dutyName = ""
        if mem.duty ~= "" and POLUS11.DutyLocs and POLUS11.DutyLocs[mem.duty] then
            dutyName = " · был(а) на посту «" .. POLUS11.DutyLocs[mem.duty].name .. "»"
        end
        POLUS11.Notify(ply, "🧠 ПАМЯТЬ ЖЕРТВЫ: «" .. mem.nick .. "» — " .. mem.job
            .. " · был(а) " .. mem.zone .. dutyName
            .. ". Ври убедительно! «!память» — все фрагменты.")
        if POLUS11.Log then POLUS11.Log("ПАМЯТЬ ЖЕРТВЫ: " .. ply:Nick() .. " усвоил личность «" .. mem.nick .. "» (" .. mem.job .. ", " .. mem.zone .. ")") end
    end)
end)

-- ============ КОМАНДА «!память» ============

local function PrintMemory(ply)
    local mem = ply.P11_Mem
    if not mem or #mem == 0 then
        ply:ChatPrint("[ПАМЯТЬ ЖЕРТВЫ] Ты пока никого не поглотил — памяти нет.")
        return
    end
    local m = mem[#mem]
    ply:ChatPrint("🧠 ПАМЯТЬ ЖЕРТВЫ (последняя личность):")
    ply:ChatPrint("  • Это был(а): «" .. m.nick .. "» — " .. m.job)
    ply:ChatPrint("  • Находился(ась): " .. m.zone)
    if m.duty and m.duty ~= "" then
        local dn = (POLUS11.DutyLocs and POLUS11.DutyLocs[m.duty] and POLUS11.DutyLocs[m.duty].name) or m.duty
        ply:ChatPrint("  • Был(а) на дежурстве: «" .. dn .. "»")
    end
    if m.wanted and m.wanted ~= "" then ply:ChatPrint("  • В розыске: ДА") end
    if m.title and m.title ~= "" then ply:ChatPrint("  • Звание смены: «" .. m.title .. "»") end
    if m.doc and m.doc ~= "" then ply:ChatPrint("  • Код документа: «" .. m.doc .. "»") end
    ply:ChatPrint("  • Усвоено в: " .. os.date("%H:%M", m.at))
    if #mem > 1 then
        ply:ChatPrint("  (в памяти ещё " .. (#mem - 1) .. " личность(и) — детали только у последней)")
    end
end

-- перехват «!память» ДО роутера чата (обёртка P11.ChatCore, как у !снятьдежурство)
do
    local t = hook.GetTable()
    local ps = t and t["PlayerSay"]
    if ps and ps["P11.ChatCore"] then
        local orig = ps["P11.ChatCore"]
        ps["P11.ChatCore"] = function(ply, text)
            if IsValid(ply) and text and IsThing(ply) then
                local low = string.lower(string.Trim(text))
                if low == "!память" then
                    PrintMemory(ply)
                    return ""
                end
            end
            return orig(ply, text)
        end
    end
end

print("[POLUS-11] ПАМЯТЬ ЖЕРТВЫ v5.2.6 (server, autorun): фрагменты памяти при поглощении + !память")
