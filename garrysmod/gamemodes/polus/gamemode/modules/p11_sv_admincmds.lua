-- ============================================================
--  ПОЛЮС-11 — АДМИН-ЧАТ-КОМАНДЫ (server) v4.1 «КОМАНДОР»
--  /tp <ник> и /goto <ник>  — телепорт СЕБЯ к игроку
--  /bring <ник>             — притащить игрока К СЕБЕ
--  /return                  — вернуться туда, откуда тпшило
--  /cloak                   — невидимость вкл/выкл СЕБЕ (Хелпер+ с v4.30.1 «ДОПУСК»; и оружие тоже)
--  /warn <ник> <причина>    — быстрый варн (Хелпер+, v4.29.0 «НАДЗОР»)
--  /ban <ник> <мин 0=перма> [причина] — быстрый бан (v4.30.0):
--      ворота прав/иерархии/лимиты срока — внутри RequestPunish
--  /kick <ник> [причина]    — быстрый кик (Модератор+, внутри Kick)
--  /mute <ник> <мин> [причина] — мут чата (Хелпер+, лимит внутри Mute)
--  /unmute <ник>            — снять мут (Хелпер+)
--  /heal [ник]              — полечить (без ника — себя)
--  /god                     — бессмертие вкл/выкл
--  /ранги, /ranks           — открыть меню выдачи рангов
--    (Deputy Staff Leader+ = ранг 10, правится Config.RankManageLevel)
--  Быстрые действия с правом «heal» = Administrator (ранг 4) и выше.
-- ============================================================

local function CanFast(ply)
    return P11FW.CanMod(ply, "heal") -- ранг 3+ (Модератор), с v4.30.1 «ДОПУСК» (был Админ 4)
end

-- найти игрока по части ника
local function FindByArg(arg)
    if not arg or arg == "" then return nil end
    local low = string.lower(arg)
    for _, p in ipairs(player.GetAll()) do
        if string.find(string.lower(p:Nick()), low, 1, true) then return p end
    end
    return nil
end

local function SaveReturn(ply)
    ply.P11_ReturnPos = ply:GetPos()
    ply.P11_ReturnAng = ply:GetAngles()
end

-- ============ ДЕЙСТВИЯ ============

local function DoTp(ply, arg)
    local target = FindByArg(arg)
    if not IsValid(target) then
        POLUS11.Notify(ply, "Игрок не найден: " .. tostring(arg))
        return
    end
    if target == ply then
        POLUS11.Notify(ply, "Ты уже у себя под ногами.")
        return
    end
    SaveReturn(ply)
    ply:SetPos(target:GetPos() + target:GetForward() * -60 + Vector(0, 0, 6))
    ply:SetEyeAngles((target:GetPos() - ply:EyePos()):Angle())
    POLUS11.Notify(ply, "Телепорт к " .. target:Nick() .. " (/return — обратно).")
    ply:EmitSound("buttons/button9.wav", 55, 130)
    if P11FW.ModLog then P11FW.ModLog("tp", ply, target, "goto") end
end

local function DoBring(ply, arg)
    local target = FindByArg(arg)
    if not IsValid(target) then
        POLUS11.Notify(ply, "Игрок не найден: " .. tostring(arg))
        return
    end
    target.P11_ReturnPos = target:GetPos()
    target.P11_ReturnAng = target:GetAngles()
    target:SetPos(ply:GetPos() + ply:GetForward() * 60 + Vector(0, 0, 6))
    target:SetEyeAngles((ply:GetPos() - target:EyePos()):Angle())
    POLUS11.Notify(ply, target:Nick() .. " притянут к тебе.")
    POLUS11.Notify(target, "Администрация переместила тебя к " .. ply:Nick() .. ".")
    ply:EmitSound("buttons/button9.wav", 55, 130)
    if P11FW.ModLog then P11FW.ModLog("tp", ply, target, "bring") end
end

local function DoReturn(ply)
    if not ply.P11_ReturnPos then
        POLUS11.Notify(ply, "Некуда возвращаться — ещё не телепортировался.")
        return
    end
    local pos, ang = ply.P11_ReturnPos, ply.P11_ReturnAng
    ply.P11_ReturnPos = nil
    ply:SetPos(pos)
    if ang then ply:SetEyeAngles(ang) end
    POLUS11.Notify(ply, "Вернулся на место.")
end

local function DoCloak(ply)
    ply.P11_Cloak = not ply.P11_Cloak
    ply:SetNoDraw(ply.P11_Cloak)
    local wep = ply:GetActiveWeapon()
    if IsValid(wep) then wep:SetNoDraw(ply.P11_Cloak) end
    -- следы/тень
    ply:DrawShadow(not ply.P11_Cloak)
    POLUS11.Notify(ply, ply.P11_Cloak and "НЕВИДИМОСТЬ ВКЛ. Оружие/тень скрыты. /cloak — выкл."
        or "Невидимость выкл.")
    ply:EmitSound("buttons/button9.wav", 50, ply.P11_Cloak and 150 or 90)
    if P11FW.ModLog then P11FW.ModLog("cloak", ply, ply, ply.P11_Cloak and "on" or "off") end
end

-- смена оружия в невидимости — новая пушка тоже прячется
hook.Add("PlayerSwitchWeapon", "P11.CloakWep", function(ply, old, new)
    if ply.P11_Cloak and IsValid(new) then new:SetNoDraw(true) end
end)

local function DoHeal(ply, arg)
    local target = ply
    if arg and arg ~= "" then
        target = FindByArg(arg) or ply
    end
    if not IsValid(target) then return end
    if not target:Alive() then target:Spawn() end
    target:SetHealth(target:GetMaxHealth())
    target:Extinguish()
    POLUS11.Notify(target, "Тебя подлатали (" .. ply:Nick() .. ").")
    if target ~= ply then POLUS11.Notify(ply, "Вылечен: " .. target:Nick()) end
    ply:EmitSound("items/smallmedkit1.wav", 60, 120)
end

local function DoGod(ply)
    ply.P11_God = not ply.P11_God
    ply:GodEnable(ply.P11_God)
    POLUS11.Notify(ply, ply.P11_God and "БЕССМЕРТИЕ ВКЛ (/god — выкл)." or "Бессмертие выкл.")
end

-- ============ РАЗБОР ЧАТА ============

hook.Add("PlayerSay", "P11.AdminChatCmds", function(ply, text)
    local t = string.Trim(text)
    if string.sub(t, 1, 1) ~= "/" then return end

    local sp = string.find(t, " ", 1, true)
    local cmd = string.lower(sp and string.sub(t, 1, sp - 1) or t)
    local arg = sp and string.Trim(string.sub(t, sp + 1)) or ""

    if cmd == "/ранги" or cmd == "/ranks" then
        -- меню выдачи рангов: Deputy Staff Leader+ (ранг 10, Config.RankManageLevel)
        if not P11FW.CanManageRank(ply) then
            POLUS11.Notify(ply, "Меню рангов — с ранга Deputy Staff Leader (10) и выше.")
            return ""
        end
        net.Start("P11FW_OpenAdminRanks") -- клиент: открыть админку на вкладке ИГРОКИ
        net.Send(ply)
        return ""
    end

    -- v4.29.0 «НАДЗОР»: быстрый ВАРН одной строкой (Хелпер+, ранг 2+).
    -- Формат: /warn <ник или кусок ника> <причина>
    if cmd == "/warn" or cmd == "/варн" then
        local name, reason = string.match(arg, "^(%S+)%s+(.+)$")
        if not reason then
            POLUS11.Notify(ply, "Формат: /warn <ник или кусок ника> <причина>")
            return ""
        end
        local target = FindByArg(name)
        if not IsValid(target) then
            POLUS11.Notify(ply, "Игрок не найден: " .. name)
            return ""
        end
        if target == ply then
            POLUS11.Notify(ply, "Себе варн не пишут.")
            return ""
        end
        local ok, err = P11FW.Warn(ply, target, reason) -- ворота/тост/журнал/автокик — внутри
        if not ok then POLUS11.Notify(ply, "ОТКАЗ: " .. tostring(err)) end
        return ""
    end

    -- ============ v4.30.0 «КОМАНДОР»: БЫСТРЫЕ НАКАЗАНИЯ ИЗ ЧАТА ============
    -- Стоят ДО ворот CanFast: каждая команда гейтится СВОИМ API
    -- (варн/мут — Хелпер+, кик — Модератор+, бан — Админ+ + лимит срока).

    -- /ban <ник> <минуты 0=перма> [причина]
    if cmd == "/ban" or cmd == "/бан" then
        local name, minsS, reason = string.match(arg, "^(%S+)%s+(%d+)%s*(.-)%s*$")
        if not minsS then
            POLUS11.Notify(ply, "Формат: /ban <ник> <минуты 0=перма> [причина]")
            return ""
        end
        local target = FindByArg(name)
        if not IsValid(target) then
            POLUS11.Notify(ply, "Игрок не найден: " .. name)
            return ""
        end
        if target == ply then
            POLUS11.Notify(ply, "Сам себя не забанишь.")
            return ""
        end
        local mins = math.min(tonumber(minsS) or 0, 525600) -- потолок: год
        local ok, err = P11FW.RequestPunish(ply, target, "ban", mins,
            (reason and reason ~= "") and reason or nil)
        POLUS11.Notify(ply, ok and "Бан поставлен." or ("ОТКАЗ: " .. tostring(err)))
        return ""
    end

    -- /kick <ник> [причина]
    if cmd == "/kick" or cmd == "/кик" then
        local name, reason = string.match(arg, "^(%S+)%s*(.-)%s*$")
        if not name or name == "" then
            POLUS11.Notify(ply, "Формат: /kick <ник> [причина]")
            return ""
        end
        local target = FindByArg(name)
        if not IsValid(target) then
            POLUS11.Notify(ply, "Игрок не найден: " .. name)
            return ""
        end
        if target == ply then
            POLUS11.Notify(ply, "Сам себя не кикнешь.")
            return ""
        end
        local ok, err = P11FW.Kick(ply, target, (reason and reason ~= "") and reason or nil)
        POLUS11.Notify(ply, ok and ("Кикнут: " .. target:Nick()) or ("ОТКАЗ: " .. tostring(err)))
        return ""
    end

    -- /mute <ник> <минуты> [причина]
    if cmd == "/mute" or cmd == "/мут" then
        local name, minsS, reason = string.match(arg, "^(%S+)%s+(%d+)%s*(.-)%s*$")
        if not minsS then
            POLUS11.Notify(ply, "Формат: /mute <ник> <минуты> [причина]")
            return ""
        end
        local target = FindByArg(name)
        if not IsValid(target) then
            POLUS11.Notify(ply, "Игрок не найден: " .. name)
            return ""
        end
        if target == ply then
            POLUS11.Notify(ply, "Сам себя не заглушишь.")
            return ""
        end
        local ok, err = P11FW.Mute(ply, target, tonumber(minsS) or 5,
            (reason and reason ~= "") and reason or nil) -- свой тост/журнал/урезка лимита внутри
        if not ok then POLUS11.Notify(ply, "ОТКАЗ: " .. tostring(err)) end
        return ""
    end

    -- /unmute <ник>
    if cmd == "/unmute" or cmd == "/размут" then
        local name = string.match(arg, "^(%S+)")
        if not name then
            POLUS11.Notify(ply, "Формат: /unmute <ник>")
            return ""
        end
        local target = FindByArg(name)
        if not IsValid(target) then
            POLUS11.Notify(ply, "Игрок не найден: " .. name)
            return ""
        end
        local ok, err = P11FW.Unmute(ply, target)
        POLUS11.Notify(ply, ok and ("Мут снят: " .. target:Nick()) or ("ОТКАЗ: " .. tostring(err)))
        return ""
    end

    -- v4.30.1 «ДОПУСК»: /cloak — невидимость СЕБЕ с ранга Хелпер (2+)
    if cmd == "/cloak" then
        if not P11FW.CanMod(ply, "cloak") then
            POLUS11.Notify(ply, "Невидимость — с ранга Хелпер (2) и выше.")
            return ""
        end
        DoCloak(ply)
        return ""
    end

    -- ниже — быстрые действия (heal, ранг 3+ Модератор с v4.30.1)
    if not CanFast(ply) then return end -- пропускаем дальше: это не наши команды/прав нет

    if cmd == "/tp" or cmd == "/goto" then
        DoTp(ply, arg)
        return ""
    elseif cmd == "/bring" then
        DoBring(ply, arg)
        return ""
    elseif cmd == "/return" then
        DoReturn(ply)
        return ""
    elseif cmd == "/heal" then
        DoHeal(ply, arg)
        return ""
    elseif cmd == "/god" then
        DoGod(ply)
        return ""
    end
end)

util.AddNetworkString("P11FW_OpenAdminRanks")
