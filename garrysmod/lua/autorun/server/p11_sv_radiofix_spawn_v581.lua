-- ============================================================
--  ПОЛЮС-11 — РАЦИЯ: ФИКС + ДИАГНОСТИКА v5.8.1 (server, autorun)
--  Жалоба: «Сообщения в рацию не приходят».
--  КОРЕНЬ: купленная в ларьке рация лежит в виртуальном БАГАЖЕ,
--  а не в руках. Штатный обработчик требует HasWeapon("weapon_
--  polus11_radio") → «нет рации», эфир молчит у всех, кто не
--  достал рацию из багажа (военным она в снаряжении — у них ок).
--  РЕШЕНИЕ (старые файлы НЕ трогаем):
--   • hook.Add с тем же именем «P11_RadioSay» ЗАМЕНЯЕТ штатный
--     обработчик (документированное поведение GMod);
--   • рация из багажа сама достаётся в руки при отправке;
--   • слышат и те, у кого рация в багаже;
--   • отправителю — «тебя слышат N бойцов» (обратная связь);
--   • весь обработчик в pcall — сообщение не теряется никогда.
--  Диагностика: p11_radiotest (админ/суперадмин).
--  Также спавнит энтити polus_p11_bugfix581 (клиентские фиксы:
--  кнопка «Багаж», документы, подсказка рации).
-- ============================================================

-- ============ ПРОВЕРКА РАЦИИ (руки ИЛИ багаж) ============
local function RadioInInv(ply)
    if not (POLUS11 and POLUS11.InvOf) then return false end
    local ok, inv = pcall(POLUS11.InvOf, ply)
    if ok and inv and inv.items and (inv.items.radio or 0) > 0 then return true end
    return false
end

local function HasRadioAny(ply)
    if not IsValid(ply) or not ply:Alive() then return false end
    if ply:HasWeapon("weapon_polus11_radio") then return true end
    return RadioInInv(ply)
end

-- достать рацию из багажа в руки (при отправке — сама)
local function TakeRadioToHands(ply)
    if not IsValid(ply) then return false end
    if ply:HasWeapon("weapon_polus11_radio") then return true end
    if not (POLUS11 and POLUS11.InvOf) then return false end
    local ok, inv = pcall(POLUS11.InvOf, ply)
    if not ok or not inv or not inv.items or (inv.items.radio or 0) <= 0 then return false end
    ply:Give("weapon_polus11_radio")
    inv.items.radio = inv.items.radio - 1
    if inv.items.radio <= 0 then inv.items.radio = nil end
    if POLUS11.InvSync then pcall(POLUS11.InvSync, ply) end
    if POLUS11.InvSaveNow then pcall(POLUS11.InvSaveNow, ply) end
    if POLUS11.Notify then
        POLUS11.Notify(ply, "Рация из багажа — теперь в руках (R — канал).")
    end
    return true
end

-- ============ ПОМЕХИ (та же логика, что в штатной) ============
local function Garble(text, rate)
    local out = {}
    for i = 1, #text do
        local ch = string.sub(text, i, i)
        local b = string.byte(ch)
        if rate and math.random() < rate and b < 128 and ch:match("[%a%d]") then
            out[#out + 1] = (math.random() < 0.5) and "#" or "&"
        else
            out[#out + 1] = ch
        end
    end
    return table.concat(out, "")
end

-- ============ ОСНОВНОЙ ОБРАБОТЧИК /r (ЗАМЕНА ШТАТНОГО) ============
hook.Add("PlayerSay", "P11_RadioSay", function(ply, text)
    local ret
    local ok, err = pcall(function()
        text = string.Trim(text or "")
        local lower = string.lower(text)

        -- смещение префикса в БАЙТАХ: "/r " = 3+1, "/р " = 4+1 (кириллица — 2 байта)
        local off = nil
        if string.StartWith(lower, "/r ") then off = 4
        elseif string.StartWith(lower, "/р ") then off = 5 end
        if not off then return end -- не наше сообщение

        -- рация: в руках? если нет — попробовать достать из багажа
        if not (IsValid(ply) and ply:HasWeapon("weapon_polus11_radio")) then
            if not TakeRadioToHands(ply) then
                if POLUS11.Notify then
                    POLUS11.Notify(ply, "Нет рации! Купи у снабженца (1800₽) — или возьми у кадровика. Багаж → ИСПОЛЬЗОВАТЬ.")
                end
                ret = ""
                return
            end
        end

        local msg = string.sub(text, off)
        if msg == "" then ret = "" return end

        local channel = ply:GetNWString("P11_RadioCh", "all")
        local chName = (POLUS11.RadioChannels and POLUS11.RadioChannels[channel]) or channel

        -- буря глушит эфир
        local storm = GetGlobalBool("P11_Storm", false)
        if storm and POLUS11.Config and POLUS11.Config.StormBlocksRadio then
            ply:ChatPrint("[Рация] Эфир забит помехами бури... связи нет.")
            ply:EmitSound("npc/combine_soldier/die3.wav", 40, 80)
            ret = ""
            return
        end

        local garble = 0.10
        if storm and POLUS11.Config then garble = POLUS11.Config.RadioStormGarble or 0.5 end
        if not storm and POLUS11.Config then garble = POLUS11.Config.RadioGarble or 0.10 end

        local airName = (POLUS11.DisplayName and POLUS11.DisplayName(ply)) or ply:Nick()

        local heard = 0
        for _, recv in ipairs(player.GetAll()) do
            if recv ~= ply and IsValid(recv) and HasRadioAny(recv) then
                local rch = recv:GetNWString("P11_RadioCh", "all")
                local hearsAll = recv:GetNWBool("P11_Infected", false) and recv:GetNWBool("P11_InfActive", false)

                local okCh = (channel == "all") or (rch == "all") or (rch == channel) or hearsAll
                if okCh then
                    local finalMsg
                    if hearsAll and not ((channel == "all") or (rch == "all") or (rch == channel)) then
                        finalMsg = Garble(msg, 0.35)
                    else
                        finalMsg = Garble(msg, garble)
                    end
                    recv:ChatPrint("[Рация:" .. chName .. "] " .. airName .. ": " .. finalMsg)
                    recv:SendLua([[surface.PlaySound("buttons/combine_button" .. math.random(1,3) .. ".wav")]])
                    heard = heard + 1
                end
            end
        end

        -- отправитель слышит себя + обратная связь «кто услышал»
        ply:ChatPrint("[Рация:" .. chName .. "] " .. airName .. ": " .. msg)
        if heard > 0 then
            ply:ChatPrint("📻 Тебя слышат: " .. heard .. " бойц(а/ов) на канале «" .. chName .. "»")
        else
            ply:ChatPrint("📻 В эфире пока пусто: тебя никто не слышит (нужна рация у слушателя, канал «" .. chName .. "»).")
        end

        -- лог сервера
        if POLUS11.Log then
            POLUS11.Log("РАЦИЯ-ФИКС [" .. chName .. "] " .. ply:Nick()
                .. ((airName ~= ply:Nick()) and (" (в эфире как «" .. airName .. "»)") or "")
                .. ": " .. msg)
        end
        if POLUS11.TaskEvent then POLUS11.TaskEvent(ply, "radio") end
        ret = ""
    end)
    if not ok then
        ErrorNoHalt("[POLUS-11][РАДИО-ФИКС] " .. tostring(err) .. "\n")
        ret = ""
    end
    return ret
end)

-- ============ ДИАГНОСТИКА p11_radiotest ============
concommand.Add("p11_radiotest", function(ply)
    local isAdmin = (not IsValid(ply)) or (P11FW.Config and P11FW.Config.Admin(ply)) or ply:IsSuperAdmin()
    if not isAdmin then
        if IsValid(ply) then ply:ChatPrint("[Рация] Только для админов.") end
        return
    end

    local out = { "== РАЦИЯ: ДИАГНОСТИКА ==" }
    out[#out + 1] = "Буря: " .. tostring(GetGlobalBool("P11_Storm", false))
        .. " | глушит эфир: " .. tostring(POLUS11.Config and POLUS11.Config.StormBlocksRadio)
    out[#out + 1] = "Каналы: " .. tostring(POLUS11.RadioChannels and table.Count(POLUS11.RadioChannels) or 0)
    local withRadio = 0
    for _, p in ipairs(player.GetAll()) do
        local hands = p:HasWeapon("weapon_polus11_radio")
        local bag = RadioInInv(p)
        local ch = p:GetNWString("P11_RadioCh", "all")
        if hands or bag then withRadio = withRadio + 1 end
        out[#out + 1] = "  " .. p:Nick() .. " | руки:" .. tostring(hands)
            .. " | багаж:" .. tostring(bag) .. " | канал:" .. ch
    end
    out[#out + 1] = "С рацией: " .. withRadio .. " из " .. #player.GetAll()

    local text = table.concat(out, "\n")
    print(text)
    if IsValid(ply) then
        for _, line in ipairs(out) do ply:ChatPrint(line) end
    end
end)

-- ============ СПАВН ЭНТИТИ-«КУРЬЕРА» (клиентские фиксы) ============
local function SpawnCarrier()
    if ents.FindByClass("polus_p11_bugfix581")[1] then return end
    local e = ents.Create("polus_p11_bugfix581")
    if IsValid(e) then
        e:SetPos(Vector(0, 0, -20000))
        e:Spawn()
    end
end

hook.Add("InitPostEntity", "P11.RadioFix.Start", function()
    timer.Simple(0.5, function()
        SpawnCarrier()
    end)
end)
hook.Add("PostCleanupMap", "P11.RadioFix.Reload", function()
    timer.Simple(3, SpawnCarrier)
end)

print("[POLUS-11] РАЦИЯ-ФИКС v5.8.1: рация из багажа достаётся сама, слышат с багажом, обратная связь «слышат N», p11_radiotest")
