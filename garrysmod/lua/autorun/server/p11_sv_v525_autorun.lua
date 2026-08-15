-- ============================================================
--  ПОЛЮС-11 — СЕРВЕРНЫЙ ПАТЧ v5.2.5 (НОВЫЙ ФАЙЛ, autorun)
--  Правило владельца: старые файлы НЕ редактируются — всё новое
--  отдельными файлами в lua/autorun/. Этот файл грузится САМ
--  после гейммода (никаких правок init.lua) и содержит:
--    1) МЕДАЛИ ВЫРЕЗАНЫ (заглушки API, ничего не рисуется/не шлётся)
--    2) СИСТЕМА ДЕЖУРСТВ (сервер: посты, оклад, снятие)
--    3) ПАТЧ ЧАТА: !снятьдежурство / !снятьпост перехватываются
--       раньше роутера (обёртка поверх хука P11.ChatCore)
--    4) Версия сборки
-- ============================================================

POLUS_BUILD = "5.2.5"

util.AddNetworkString("P11_DutyOpen")
util.AddNetworkString("P11_DutyAct")

-- ============ 1) МЕДАЛИ ВЫРЕЗАНЫ ============
-- Старый медальный модуль загружается гейммодом, но мы ПОСЛЕ него
-- переопределяем весь API на no-op: реестр пуст, выдача невозможна,
-- синк ничего не шлёт. Намики/TAB/админка ничего не рисуют.

POLUS11.MedalDefs  = {}
POLUS11.Medals     = {}
POLUS11.AutoStats  = {}
POLUS11.AutoMedals = {}

POLUS11.MedalPush      = function() end
POLUS11.MedalAward     = function(ply) if POLUS11.Notify then POLUS11.Notify(ply, "Медали отключены (v5.2.5).") end return false end
POLUS11.MedalRevoke    = function() return false end
POLUS11.MedalScope     = function() return nil end
POLUS11.MedalAutoGrant = function() return false end
POLUS11.MedalStatEvent = function() end

-- ============ 2) СИСТЕМА ДЕЖУРСТВ (сервер) ============

POLUS11.DutyLocs = POLUS11.DutyLocs or {
    kpp2    = { name = "КПП 2",                 desc = "Главный пропускной пост. Встречай и проверяй прибывающих." },
    kpparr  = { name = "КПП · Приезжая часть",  desc = "Пост у колонны прибытия. Приём новичков, груза и техники." },
    pov     = { name = "Поверхность",           desc = "Наружный периметр. Глаза на буран и горизонт." },
    complex = { name = "Комплекс за Сотрудником", desc = "Тыловой комплекс. Склад, техника и порядок в тылу." },
}

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
    ply.P11_DutyLoc = locId
    ply.P11_DutyStart = CurTime()
    ply:SetNWString("P11_DutyLoc", locId)
    if POLUS11.Notify then
        POLUS11.Notify(ply, "🛡 Пост принят: «" .. loc.name .. "». Оклад +" .. cvWage:GetInt() .. "₽/мин. Снять: меню НПС или !снятьдежурство.")
    end
    if POLUS11.Log then POLUS11.Log("ДЕЖУРСТВО: " .. ply:Nick() .. " → «" .. loc.name .. "»") end
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

hook.Add("PlayerDeath", "P11.DutyDeath", function(ply) POLUS11.DutyEnd(ply, true) end)
hook.Add("PlayerDisconnected", "P11.DutyBye", function(ply) POLUS11.DutyEnd(ply, true) end)

function POLUS11.OpenDutyUI(ply, ent)
    if not IsValid(ply) then return end
    if IsValid(ent) then ply.P11_DutyNpcEnt = ent end
    net.Start("P11_DutyOpen")
        net.WriteTable(POLUS11.DutyLocs)
    net.Send(ply)
end

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

-- ============ 3) ПАТЧ ЧАТА: !снятьдежурство ============
-- Оборачиваем хук роутера (P11.ChatCore) БЕЗ правки p11_sv_chat.lua:
-- перехватываем наши команды ДО роутера, остальное — как было.

do
    local t = hook.GetTable()
    local ps = t and t["PlayerSay"]
    if ps and ps["P11.ChatCore"] then
        local orig = ps["P11.ChatCore"]
        ps["P11.ChatCore"] = function(ply, text)
            if IsValid(ply) and text then
                local low = string.lower(string.Trim(text))
                if low == "!снятьдежурство" or low == "!снятьпост" or low == "!снять пост" then
                    POLUS11.DutyEnd(ply, false)
                    return ""
                end
            end
            return orig(ply, text)
        end
    end
end

print("[POLUS-11] v5.2.5 autorun/server: медали вырезаны · дежурства активны · !снятьдежурство работает")
