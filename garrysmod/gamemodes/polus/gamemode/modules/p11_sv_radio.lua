-- ============================================================
--  ПОЛЮС-11 — РАЦИИ (сервер)
--  Каналы: «РККА», «НКВД», «Наука», «Персонал», «Общий» (v3.9).
--  Текст: /r сообщение | Голос: дальняя связь при общем канале.
--  Буря глушит эфир. Заражённый с рацией слышит ВСЕ каналы.
-- ============================================================

POLUS11.RadioChannels = {
    rkka      = "РККА",
    nkvd      = "НКВД",
    science   = "Наука",
    personnel = "Персонал",
    all       = "Общий",
}

function POLUS11.HasRadio(ply)
    return IsValid(ply) and ply:Alive() and ply:HasWeapon("weapon_polus11_radio")
end

-- искажение текста помехами (ASCII-буквы/цифры, UTF-8 не трогаем)
local function Garble(text, rate)
    local out = {}
    for i = 1, #text do
        local ch = string.sub(text, i, i)
        local b = string.byte(ch)
        if math.random() < rate and b < 128 and ch:match("[%a%d]") then
            out[#out + 1] = (math.random() < 0.5) and "#" or "&"
        else
            out[#out + 1] = ch
        end
    end
    return table.concat(out, "")
end

-- радио-сообщение /r текст
hook.Add("PlayerSay", "P11_RadioSay", function(ply, text)
    text = string.Trim(text)
    local lower = string.lower(text)

    -- смещение префикса в БАЙТАХ: "/r " = 3, "/р " = 4 (кириллическая р — 2 байта в UTF-8)
    local off = nil
    if string.StartWith(lower, "/r ") then off = 4
    elseif string.StartWith(lower, "/р ") then off = 5 end
    if not off then return end

    if not POLUS11.HasRadio(ply) then
        POLUS11.Notify(ply, "У вас нет рации!")
        return ""
    end

    local msg = string.sub(text, off)
    if msg == "" then return "" end

    local channel = ply:GetNWString("P11_RadioCh", "rkka")
    local chName = POLUS11.RadioChannels[channel] or channel

    -- буря полностью рубит эфир
    local storm = GetGlobalBool("P11_Storm", false)
    if storm and POLUS11.Config.StormBlocksRadio then
        ply:ChatPrint("[Рация] Эфир забит помехами бури... связи нет.")
        ply:EmitSound("npc/combine_soldier/die3.wav", 40, 80)
        return ""
    end

    local garble = storm and POLUS11.Config.RadioStormGarble or POLUS11.Config.RadioGarble

    for _, recv in ipairs(player.GetAll()) do
        if recv ~= ply and POLUS11.HasRadio(recv) then
            local rch = recv:GetNWString("P11_RadioCh", "rkka")
            local hearsAll = recv:GetNWBool("P11_Infected", false) and recv:GetNWBool("P11_InfActive", false)

            local ok = (channel == "all") or (rch == "all") or (rch == channel) or hearsAll
            if ok then
                local finalMsg
                if hearsAll and not ((channel == "all") or (rch == "all") or (rch == channel)) then
                    finalMsg = Garble(msg, 0.35) -- чужой канал слышно хуже
                else
                    finalMsg = Garble(msg, garble)
                end

                recv:ChatPrint("[Рация:" .. chName .. "] " .. ply:Nick() .. ": " .. finalMsg)
                recv:SendLua([[surface.PlaySound("buttons/combine_button" .. math.random(1,3) .. ".wav")]])
            end
        end
    end

    -- отправитель слышит себя
    ply:ChatPrint("[Рация:" .. chName .. "] " .. ply:Nick() .. ": " .. msg)

    POLUS11.Log("РАЦИЯ [" .. chName .. "] " .. ply:Nick() .. ": " .. msg)
    if POLUS11.TaskEvent then POLUS11.TaskEvent(ply, "radio") end -- задача охраны
    return ""
end)

-- голосовая рация: один канал = слышно независимо от дистанции
hook.Add("PlayerCanHearPlayersVoice", "P11_RadioVoice", function(listener, talker)
    if not POLUS11.HasRadio(listener) or not POLUS11.HasRadio(talker) then return end

    local storm = GetGlobalBool("P11_Storm", false)
    if storm and POLUS11.Config.StormBlocksRadio then return false, false end

    local lch = listener:GetNWString("P11_RadioCh", "rkka")
    local tch = talker:GetNWString("P11_RadioCh", "rkka")

    if lch == "all" or tch == "all" or lch == tch then
        return true, false -- слышно на любой дистанции, стерео
    end

    -- НЕЧТО с рацией слышит ВСЕ голосовые каналы
    if listener:GetNWBool("P11_Infected", false) and listener:GetNWBool("P11_InfActive", false) then
        return true, false
    end
end)
