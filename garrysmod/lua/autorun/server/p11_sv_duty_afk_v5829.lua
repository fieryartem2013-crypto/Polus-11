-- ============================================================
--  ПОЛЮС-11 — ДЕЖУРСТВО БЕЗ ФАРМА v5.8.29 (НОВЫЙ ФАЙЛ, server)
-- ============================================================
--  ДЫРА ЭКОНОМИКИ: оклад дежурства (lua/autorun/server/p11_sv_v525_autorun.lua)
--  платит p11_dutywage ₽/мин каждому, у кого стоит NW-флаг поста и кто жив.
--  Ни позиции, ни движения не проверяется — постоял АФК у стены три часа
--  = 18 000 ₽ из воздуха.
--
--  ЧТО ДЕЛАЕМ (старые файлы не трогаем):
--    1) раз в секунду смотрим, двигался ли боец: сместился больше чем на
--       p11_duty_move (по умолчанию 40 юн.) — счётчик АФК обнуляется;
--    2) не двигался p11_duty_afk секунд (по умолчанию 240) — ставим флаг
--       АФК и в чат одно предупреждение;
--    3) оборачиваем POLUS11.AddMoney: начисление с причиной
--       «дежурство на посту» АФК-бойцу не проходит (остальные причины
--       не трогаем вообще).
--
--  Тюнинг без рестарта:  p11_duty_afk <сек>   p11_duty_move <юниты>
--  Откат: удалить этот файл.
-- ============================================================

local cvAfk  = CreateConVar("p11_duty_afk", "240", FCVAR_ARCHIVE,
    "POLUS-11 v5.8.29: сколько секунд без движения = АФК на посту (0 = выключить)")
local cvMove = CreateConVar("p11_duty_move", "40", FCVAR_ARCHIVE,
    "POLUS-11 v5.8.29: какое смещение считается движением (юниты)")

local Track = {} -- ply -> { pos = Vector, still = число секунд без движения }

local function OnDuty(ply)
    return IsValid(ply) and ply:GetNWString("P11_DutyLoc", "") ~= ""
end

timer.Create("P11.DutyAFK.Tick", 1, 0, function()
    local afkLimit = math.max(0, cvAfk:GetInt())
    local moveMin  = math.max(1, cvMove:GetInt())
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() then
            Track[ply] = nil
        elseif OnDuty(ply) then
            local t = Track[ply]
            local pos = ply:GetPos()
            if not t then
                Track[ply] = { pos = pos, still = 0 }
            else
                if t.pos and t.pos:Distance(pos) >= moveMin then
                    t.still = 0
                    if t.afk then
                        t.afk = nil
                        if POLUS11 and POLUS11.Notify then
                            POLUS11.Notify(ply, "🛡 Пост снова засчитан: оклад пошёл.")
                        end
                    end
                else
                    t.still = t.still + 1
                end
                t.pos = pos
                if afkLimit > 0 and not t.afk and t.still >= afkLimit then
                    t.afk = true
                    if POLUS11 and POLUS11.Notify then
                        POLUS11.Notify(ply, "🛑 Пост не засчитан: нет движения " .. afkLimit ..
                            " сек. Оклад на паузе — обойди участок.")
                    end
                    if POLUS11 and POLUS11.Log then
                        POLUS11.Log("ДЕЖУРСТВО/АФК: " .. ply:Nick() .. " — оклад на паузе (" ..
                            afkLimit .. " с без движения)")
                    end
                end
            end
        else
            Track[ply] = nil
        end
    end
end)

local function IsAFK(ply)
    local t = Track[ply]
    return t ~= nil and t.afk == true
end

-- ============ ЗАМОК НАЧИСЛЕНИЯ ============
-- Метку «обёртка стоит» храним в своей таблице: индексировать функцию в
-- Lua 5.1/LuaJIT нельзя (см. p11_sv_funcmeta_v5829.lua).
local Wrapped = setmetatable({}, { __mode = "k" })

local function WrapAddMoney()
    if not (POLUS11 and POLUS11.AddMoney) then return false end
    if Wrapped[POLUS11.AddMoney] then return true end
    local orig = POLUS11.AddMoney
    local wrap = function(ply, amount, reason, ...)
        if IsValid(ply) and tostring(reason or "") == "дежурство на посту" and IsAFK(ply) then
            return false
        end
        return orig(ply, amount, reason, ...)
    end
    Wrapped[wrap] = true
    POLUS11.AddMoney = wrap
    print("[POLUS-11] v5.8.29: оклад дежурства не капает АФК-бойцам (порог " ..
        cvAfk:GetInt() .. " с)")
    return true
end

hook.Add("InitPostEntity", "P11.DutyAFK.v5829", function()
    timer.Simple(0.5, WrapAddMoney)
    timer.Simple(3, WrapAddMoney)
    timer.Simple(10, WrapAddMoney)
end)
timer.Simple(0.3, WrapAddMoney)

hook.Add("PlayerDisconnected", "P11.DutyAFK.v5829", function(ply) Track[ply] = nil end)
hook.Add("PlayerDeath", "P11.DutyAFK.v5829", function(ply) Track[ply] = nil end)
