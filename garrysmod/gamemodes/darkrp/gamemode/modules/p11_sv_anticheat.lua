-- ============================================================
--  ПОЛЮС-11 — АНТИСПАМ/АНТИЧИТ (server) v4.2
--  1) Обёртка net.Receive: лимит частоты ПО КАЖДОМУ протоколу.
--     Флуд → страйки → алерт админам (+журнал). Этот модуль
--     грузится ПЕРВЫМ в списке sv (init.lua), поэтому сторожит
--     все протоколы сборки.
--  2) Телеметрия движения: ускорение/телепортация без причины.
--     Только ФЛАГИ для админов (авто-киков нет: фаза альфы).
-- ============================================================

local AC = {
    allowed = {},    -- имя протокола -> { perSec, burst } (пусто = дефолт)
    buckets = {},    -- ply -> { [name] = { t0, count } }
    strikes = {},    -- steamid -> число нарушений
    posTrack = {},   -- ply -> { pos, t }
}
POLUS11.AC = AC

local DEF = { perSec = 12, burst = 20 }  -- дефолтный лимит протокола
-- особо частые легальные протоколы (даём широкий коридор)
local PER_PROTO = {
    P11_MiniHit   = { perSec = 10, burst = 14 }, -- миниигры: до 4 шагов за игру + джиттер
    P11_Money     = { perSec = 4,  burst = 6 },
    P11_InvAct    = { perSec = 6,  burst = 10 },
    P11_PorterReq = { perSec = 0.1, burst = 2 },
    P11FW_PunishReq = { perSec = 1, burst = 3 },
}

local function AcRankLevel(ply)
    if P11FW and P11FW.GetRankLevel then
        local ok, lvl = pcall(P11FW.GetRankLevel, ply)
        if ok and isnumber(lvl) then return lvl end
    end
    return 0
end

local function AcNotifyAdmins(msg)
    for _, p in ipairs(player.GetAll()) do
        if AcRankLevel(p) >= 3 or p:IsAdmin() then
            if P11FW.Notify then P11FW.Notify(p, msg) else p:ChatPrint(msg) end
        end
    end
    if P11FW.Log then P11FW.Log("[AC] " .. msg) end
    print("[POLUS AC] " .. msg)
end

local function AcStrike(ply, why)
    if not IsValid(ply) then return end
    local sid = ply:SteamID()
    AC.strikes[sid] = (AC.strikes[sid] or 0) + 1
    local n = AC.strikes[sid]
    if n == 10 or n == 30 or (n % 50 == 0) then
        AcNotifyAdmins("⚠ ПОДОЗРЕНИЕ: " .. ply:Nick() .. " (" .. why .. "), страйков: " .. n)
    end
end

-- ============ ОБЁРТКА net.Receive ============

local baseReceive = net.Receive
function net.Receive(name, fn)
    -- руками вписанные «экзотические» допуски
    local lim = PER_PROTO[name] or DEF

    baseReceive(name, function(len, ply)
        if IsValid(ply) then
            local bk = AC.buckets[ply]
            if not bk then bk = {} AC.buckets[ply] = bk end
            local b = bk[name]
            local now = CurTime()
            if not b then
                b = { t0 = now, count = 0 }
                bk[name] = b
            end
            b.count = b.count + 1
            -- окно 1 сек
            if now - b.t0 >= 1 then
                if b.count > lim.burst then
                    AcStrike(ply, "флуд " .. name .. " (" .. b.count .. "/с)")
                    b.t0, b.count = now, 0
                    return -- пакет отброшен
                end
                b.t0, b.count = now, 0
            elseif b.count > lim.perSec * 3 then
                -- мгновенная вспышка меньше секунды
                AcStrike(ply, "вспышка " .. name)
                return
            end
        end
        -- вызов оригинального обработчика всегда в защите
        local ok, err = pcall(fn, len, ply)
        if not ok then
            print("[POLUS][ERROR] net." .. tostring(name) .. " → " .. tostring(err))
        end
    end)
end

hook.Add("PlayerDisconnected", "P11.ACLeave", function(ply)
    if IsValid(ply) then
        AC.buckets[ply] = nil
        AC.posTrack[ply] = nil
    end
end)

-- ============ ТЕЛЕМЕТРИЯ ДВИЖЕНИЯ ============
-- ранг 2+ (админский состав) не флагается: им нужны /tp и ноклип.

local SPEED_HARD = 620   -- юн/сек усреднённо: разбег 330 + люфт; выше — подозрительно
local TELEPORT_JUMP = 1700 -- разовый скачок за тик 1 сек

timer.Create("P11.ACMove", 1, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        local skip = false
        if not IsValid(ply) or not ply:Alive() then skip = true end
        if not skip and ply:GetMoveType() == MOVETYPE_NOCLIP then AC.posTrack[ply] = nil skip = true end
        if not skip and AcRankLevel(ply) >= 2 then AC.posTrack[ply] = nil skip = true end
        if not skip and ply.P11_ACGrace and CurTime() < ply.P11_ACGrace then AC.posTrack[ply] = nil skip = true end

        if not skip then
        local pos = ply:GetPos()
        local tr = AC.posTrack[ply]
        if tr then
            local dt = CurTime() - tr.t
            if dt > 0.05 then
                local dist = pos:Distance(tr.pos)
                local speed = dist / dt
                if dist > TELEPORT_JUMP then
                    AcStrike(ply, "телепортация " .. math.floor(dist) .. " юн")
                    AcNotifyAdmins("⚡ ТЕЛЕПОРТ у " .. ply:Nick() ..
                        " (" .. math.floor(dist) .. " юн за " .. string.format("%.1f", dt) .. "с) — проверь глазами")
                elseif speed > SPEED_HARD and ply:OnGround() then
                    AC.posTrack[ply].speedStrikes = (AC.posTrack[ply].speedStrikes or 0) + 1
                    if AC.posTrack[ply].speedStrikes >= 4 then
                        AC.posTrack[ply].speedStrikes = 0
                        AcStrike(ply, "скорость ~" .. math.floor(speed) .. " юн/с")
                        AcNotifyAdmins("🏃 СКОРОСТЬ у " .. ply:Nick() ..
                            " ≈ " .. math.floor(speed) .. " юн/с — похоже на speedhack")
                    end
                else
                    AC.posTrack[ply].speedStrikes = 0
                end
            end
        end
        AC.posTrack[ply] = { pos = pos, t = CurTime(), speedStrikes = (tr and tr.speedStrikes) or 0 }
        end -- if not skip
    end
end)

-- свои же серверные телепорты помечаем льготным окном (патруль/арест/возврат)
function POLUS11.ACMarkTeleport(ply)
    if IsValid(ply) then ply.P11_ACGrace = CurTime() + 2 end
end
-- админ-команды телепорта: мягко помечаем обе стороны
hook.Add("P11FW.Punished", "P11.ACPunishGrace", function(target)
    POLUS11.ACMarkTeleport(target)
end)

print("[POLUS-11] антиспам/античит v4.2 активен (перехват net + флаги движения)")
