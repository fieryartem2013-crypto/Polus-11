-- ============================================================
--  ПОЛЮС-11 — ДЕЖУРСТВА (server) v5.2.3
--  Заявка владельца: «система Дежурства с выбором локации:
--  КПП 2 / КПП Приезжая часть / Поверхность / Комплекс за
--  Сотрудником — берётся у НПС Дежурного главы».
--
--  E по НПС «Дежурный главы» (polus_p11_dutynpc) → меню поста →
--  выбор локации. Пока дежуришь: плашка «ДЕЖУРНЫЙ · <пост>»
--  над ником и в TAB + оклад за минуту. Смерть/выход — пост снят.
--  Снять можно также: /снятьдежурство (или /снять пост).
-- ============================================================

util.AddNetworkString("P11_DutyOpen")
util.AddNetworkString("P11_DutyAct")

POLUS11.DutyLocs = POLUS11.DutyLocs or {
    kpp2    = { name = "КПП 2",                 desc = "Главный пропускной пост. Встречай и проверяй прибывающих." },
    kpparr  = { name = "КПП · Приезжая часть",  desc = "Пост у колонны прибытия. Приём новичков, груза и техники." },
    pov     = { name = "Поверхность",           desc = "Наружный периметр. Глаза на буран и горизонт." },
    complex = { name = "Комплекс за Сотрудником", desc = "Тыловой комплекс. Склад, техника и порядок в тылу." },
}

-- оклад за минуту дежурства (живой тюнинг: p11_dutywage 0..1000)
local cvWage = CreateConVar("p11_dutywage", "100", FCVAR_ARCHIVE,
    "POLUS-11: оклад дежурного за минуту (₽)")

function POLUS11.GetDutyLoc(ply)
    if not IsValid(ply) then return "" end
    return ply:GetNWString("P11_DutyLoc", "")
end

function POLUS11.DutyTake(ply, locId)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    locId = string.sub(tostring(locId or ""), 1, 24)
    local loc = POLUS11.DutyLocs[locId]
    if not loc then return false end
    if not ply:Alive() then
        if POLUS11.Notify then POLUS11.Notify(ply, "Мёртвых на пост не ставят.") end
        return false
    end
    local prev = ply.P11_DutyLoc
    ply.P11_DutyLoc = locId
    ply.P11_DutyStart = CurTime()
    ply:SetNWString("P11_DutyLoc", locId)
    if prev == locId then
        if POLUS11.Notify then
            POLUS11.Notify(ply, "🛡 Ты уже дежуришь на «" .. loc.name .. "» — таймер поста обновлён.")
        end
    else
        if POLUS11.Notify then
            POLUS11.Notify(ply, "🛡 Пост принят: «" .. loc.name .. "». Оклад +" .. cvWage:GetInt() .. "₽/мин. Снять: меню НПС или !снятьдежурство.")
        end
        if POLUS11.Log then POLUS11.Log("ДЕЖУРСТВО: " .. ply:Nick() .. " → «" .. loc.name .. "»") end
    end
    return true
end

function POLUS11.DutyEnd(ply, silent)
    if not IsValid(ply) then return end
    local cur = ply:GetNWString("P11_DutyLoc", "")
    if cur == "" and not ply.P11_DutyLoc then return end
    local was = ply.P11_DutyLoc or cur
    local mins = was ~= "" and math.floor((CurTime() - (ply.P11_DutyStart or CurTime())) / 60) or 0
    ply.P11_DutyLoc = nil
    ply.P11_DutyStart = nil
    ply:SetNWString("P11_DutyLoc", "")
    if not silent then
        if POLUS11.Notify then
            POLUS11.Notify(ply, "Пост сдан. Дежурил: " .. mins .. " мин. Спасибо за службу.")
        end
        if POLUS11.Log then POLUS11.Log("ДЕЖУРСТВО: " .. ply:Nick() .. " снял пост («" .. tostring(was) .. "», " .. mins .. " мин)") end
    end
end

-- оклад: раз в минуту всем, кто на посту
timer.Create("P11.DutyWage", 60, 0, function()
    local amt = math.max(0, cvWage:GetInt())
    if amt <= 0 then return end
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:Alive() and p:GetNWString("P11_DutyLoc", "") ~= "" then
            if POLUS11.AddMoney then
                POLUS11.AddMoney(p, amt, "дежурство на посту")
            end
        end
    end
end)

-- смерть / выход — пост снимается
hook.Add("PlayerDeath", "P11.DutyDeath", function(ply)
    POLUS11.DutyEnd(ply, true)
end)
hook.Add("PlayerDisconnected", "P11.DutyBye", function(ply)
    POLUS11.DutyEnd(ply, true)
end)

-- НПС «Дежурный главы»: открыть меню поста
function POLUS11.OpenDutyUI(ply, ent)
    if not IsValid(ply) then return end
    if IsValid(ent) then ply.P11_DutyNpcEnt = ent end
    net.Start("P11_DutyOpen")
        net.WriteTable(POLUS11.DutyLocs)
    net.Send(ply)
end

-- клиент: взять пост / снять
net.Receive("P11_DutyAct", function(_, ply)
    if not IsValid(ply) then return end
    ply.P11_DutyNext = ply.P11_DutyNext or 0
    if CurTime() < ply.P11_DutyNext then return end
    ply.P11_DutyNext = CurTime() + 0.5

    local act = net.ReadUInt(2)
    if act == 1 then
        POLUS11.DutyTake(ply, net.ReadString())
    elseif act == 2 then
        POLUS11.DutyEnd(ply, false)
    end
end)

-- чат-команда снятия (удобно прямо на посту)
hook.Add("PlayerSay", "P11.DutyChat", function(ply, text)
    if not IsValid(ply) or not text then return end
    local t = string.lower(string.Trim(text))
    -- v5.2.3: команды станции — ТОЛЬКО через «!» (как !гараж/!крафт/!пульт)
    if t == "!снятьдежурство" or t == "!снятьпост" or t == "!снять пост" then
        POLUS11.DutyEnd(ply, false)
        return ""
    end
end)

print("[POLUS-11] ДЕЖУРСТВА v5.2.3: НПС «Дежурный главы» → КПП 2 / Приезжая часть / Поверхность / Комплекс · оклад +100₽/мин · !снятьдежурство")
