-- ============================================================
--  ПОЛЮС-11 — РАЦИИ (сервер) v4.8.1 «ЭФИР»
--  Каналы: «РККА», «НКВД», «Наука», «Персонал», «Общий»
--  (v3.9; v4.8.1 — канал ПО УМОЛЧАНИЮ = «Общий», чтобы рация
--  «просто работала» из коробки у всех, кто её получил).
--  Текст: /r сообщение • Голос-эфир: модули p11_sv_voice.lua
--  (3D-голос + радио-линк живут там, хук один — здесь убран).
--  Канал переключается: R на рации ИЛИ командой /канал <имя>.
--  Буря глушит эфир (местная речь доступна и в бурю).
--  Заражённый с рацией слышит ВСЕ каналы.
--  v4.8.1: рация выдана ВСЕМ военным (сид v4.8.1, миграция
--  radioV481) — жалоба «у штурмовика задача по рации, а рации
--  нет» закрыта.
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

-- v4.8.2: единый переключатель канала (одна точка правды для
-- SWEP:Reload и страхующего перехвата клавиши R ниже).
POLUS11.RadioOrder = { "rkka", "nkvd", "science", "personnel", "all" }

function POLUS11.RadioCycleChannel(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local cur = ply:GetNWString("P11_RadioCh", "all")
    local idx = 1
    for i, ch in ipairs(POLUS11.RadioOrder) do
        if ch == cur then idx = (i % #POLUS11.RadioOrder) + 1 break end
    end
    local newCh = POLUS11.RadioOrder[idx]
    ply:SetNWString("P11_RadioCh", newCh)
    POLUS11.Notify(ply, "Канал: " .. (POLUS11.RadioChannels[newCh] or newCh))
    ply:EmitSound("buttons/combine_button" .. math.random(1, 3) .. ".wav", 55, 110)
end

-- v4.8.2 СТРАХОВКА КЛАВИШИ R: жалоба «в описании R, нажимаю —
-- ничего». У части клиентов SWEP:Reload глушится связкой/паком
-- оружия — перехватываем саму клавишу на сервере. Общий кулдаун
-- P11_RadioNextCycle делит и SWEP:Reload — двойного щелчка нет.
local function RadioKeyGuard(ply)
    ply.P11_RadioNextCycle = ply.P11_RadioNextCycle or 0
    if CurTime() < ply.P11_RadioNextCycle then return end
    ply.P11_RadioNextCycle = CurTime() + 0.8
    POLUS11.RadioCycleChannel(ply)
end

hook.Add("PlayerButtonDown", "P11_RadioKeyR", function(ply, btn)
    if btn ~= KEY_R or not IsValid(ply) then return end
    local wep = ply:GetActiveWeapon()
    if IsValid(wep) and wep:GetClass() == "weapon_polus11_radio" then
        RadioKeyGuard(ply)
    end
end)

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

    local channel = ply:GetNWString("P11_RadioCh", "all") -- v4.8.1: дефолт «Общий»
    local chName = POLUS11.RadioChannels[channel] or channel

    -- буря полностью рубит эфир
    local storm = GetGlobalBool("P11_Storm", false)
    if storm and POLUS11.Config.StormBlocksRadio then
        ply:ChatPrint("[Рация] Эфир забит помехами бури... связи нет.")
        ply:EmitSound("npc/combine_soldier/die3.wav", 40, 80)
        return ""
    end

    local garble = storm and POLUS11.Config.RadioStormGarble or POLUS11.Config.RadioGarble

    -- v4.13.0 «КОРЕНЬ»: эфир подписан ЛИЧИНОЙ (полная маскировка в эфире)
    local airName = (POLUS11.DisplayName and POLUS11.DisplayName(ply)) or ply:Nick()

    for _, recv in ipairs(player.GetAll()) do
        if recv ~= ply and POLUS11.HasRadio(recv) then
            local rch = recv:GetNWString("P11_RadioCh", "all") -- v4.8.1
            local hearsAll = recv:GetNWBool("P11_Infected", false) and recv:GetNWBool("P11_InfActive", false)

            local ok = (channel == "all") or (rch == "all") or (rch == channel) or hearsAll
            if ok then
                local finalMsg
                if hearsAll and not ((channel == "all") or (rch == "all") or (rch == channel)) then
                    finalMsg = Garble(msg, 0.35) -- чужой канал слышно хуже
                else
                    finalMsg = Garble(msg, garble)
                end

                recv:ChatPrint("[Рация:" .. chName .. "] " .. airName .. ": " .. finalMsg)
                recv:SendLua([[surface.PlaySound("buttons/combine_button" .. math.random(1,3) .. ".wav")]])
            end
        end
    end

    -- отправитель слышит себя (тоже под личиной — иначе сам себя спалит)
    ply:ChatPrint("[Рация:" .. chName .. "] " .. airName .. ": " .. msg)

    -- лог сервера — ЧЕСТНЫЙ: настоящее имя + маска, если вылез в эфир чужим
    POLUS11.Log("РАЦИЯ [" .. chName .. "] " .. ply:Nick()
        .. ((airName ~= ply:Nick()) and (" (в эфире как «" .. airName .. "»)") or "")
        .. ": " .. msg)
    if POLUS11.TaskEvent then POLUS11.TaskEvent(ply, "radio") end -- задача охраны
    return ""
end)

-- v4.8.1: /канал — переключить канал рации БЕЗ кнопки R
-- (страховка на случай, если R не срабатывает на чьей-то связке)
hook.Add("PlayerSay", "P11_RadioChannelCmd", function(ply, text)
    local t = string.Trim(text)
    local low = string.lower(t)
    if not string.StartWith(low, "/канал") then return end

    if not POLUS11.HasRadio(ply) then
        POLUS11.Notify(ply, "У вас нет рации!")
        return ""
    end

    local arg = string.Trim(string.sub(t, #"/канал" + 1))
    arg = string.lower(arg)

    if arg == "" then
        local cur = ply:GetNWString("P11_RadioCh", "all")
        ply:ChatPrint("[Рация] Текущий канал: " .. (POLUS11.RadioChannels[cur] or cur)
            .. ". Смена: /канал общий | ркка | нквд | наука | персонал — или клавиша R на рации.")
        return ""
    end

    local want = nil
    if string.find(arg, "общ") or arg == "all" or string.find(arg, "все") then want = "all"
    elseif string.find(arg, "ркка") or arg == "rkka" then want = "rkka"
    elseif string.find(arg, "нквд") or arg == "nkvd" then want = "nkvd"
    elseif string.find(arg, "наук") or arg == "science" then want = "science"
    elseif string.find(arg, "персонал") or arg == "personnel" then want = "personnel"
    end

    if not want then
        ply:ChatPrint("[Рация] Нет такого канала. Бывают: общий, ркка, нквд, наука, персонал.")
        return ""
    end

    ply:SetNWString("P11_RadioCh", want)
    POLUS11.Notify(ply, "Канал: " .. POLUS11.RadioChannels[want])
    ply:EmitSound("buttons/combine_button2.wav", 55, 110)
    return ""
end)
