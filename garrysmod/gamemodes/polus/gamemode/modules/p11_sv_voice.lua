-- ============================================================
--  ПОЛЮС-11 — 3D ГОЛОС + РАДИО-ЭФИР (server) v4.8.1 «ЭФИР»
--  Заявка владельца: «3Д чат — когда чел далеко, его не слышно,
--  рядом — слышно, в воис чат и в просто чат».
--
--  ГОЛОС (PlayerCanHearPlayersVoice, единственный хук голоса):
--   • МЕСТНАЯ РЕЧЬ: в пределах POLUS11.Config.VoiceHearRadius
--     (по умолчанию 950u) — слышно, дальше — тишина. Второй
--     возврат true = 3D-позиционный звук: громкость сама тает
--     с расстоянием (за стеной тише, вплотную — громко).
--   • РАЦИЯ: оба с рацией и каналы совпали (или кто-то на
--     «Общем») — слышно через эфир на ЛЮБОЙ дистанции.
--     Буря рубит ТОЛЬКО эфир — говорить в лицо можно и в бурю.
--   • НЕЧТО с рацией (проявившееся) слышит ВСЕ каналы.
--   • Мёртвые не говорят живым; мертвецы-наблюдатели слышат всех.
--
--  ТЕКСТ: радиусная речь живёт в p11_sv_chat.lua (РЕЧЬ / шёпот /
--  крик — радиусы там же в конфиге).
--  Тонкая подвязка: GM:PlayerCanHearPlayersVoice в shared.lua
--  намеренно возвращает nil — решение всегда за ЭТИМ хуком.
-- ============================================================

local function VC()
    local c = POLUS11.Config or {}
    return {
        hear = tonumber(c.VoiceHearRadius) or 950,
        full = tonumber(c.VoiceFullRadius) or 340,
        use3d = c.Voice3D ~= false,
    }
end

-- радио-линк: совпадение каналов (NWString; v4.8.1 — дефолт «Общий»)
local function RadioLinked(listener, talker)
    if not (POLUS11.HasRadio and POLUS11.HasRadio(listener) and POLUS11.HasRadio(talker)) then
        return false
    end
    -- буря глушит эфир (местную речь — НЕ трогает)
    if GetGlobalBool("P11_Storm", false)
        and POLUS11.Config and POLUS11.Config.StormBlocksRadio then
        return false
    end
    local lch = listener:GetNWString("P11_RadioCh", "all")
    local tch = talker:GetNWString("P11_RadioCh", "all")
    if lch == "all" or tch == "all" or lch == tch then
        return true
    end
    -- проявившееся Нечто с рацией слышит весь эфир
    if listener:GetNWBool("P11_Infected", false)
        and listener:GetNWBool("P11_InfActive", false) then
        return true
    end
    return false
end

hook.Add("PlayerCanHearPlayersVoice", "P11.Voice3D", function(listener, talker)
    if not IsValid(listener) or not IsValid(talker) then return false end
    if listener == talker then return true end

    -- говорящий мёртв: слышат только такие же наблюдатели
    if not talker:Alive() then
        return not listener:Alive(), false
    end
    -- слушающий мёртв: наблюдатель — слышит всех живых
    if not listener:Alive() then
        return true, false
    end

    -- 1) РАДИО-ЭФИР: каналы совпали — дистанция не важна
    if RadioLinked(listener, talker) then
        return true, false -- стерео: это «линия», а не голос рядом
    end

    -- 2) МЕСТНАЯ РЕЧЬ: 3D - рядом громко, издали тихо, за радиусом — нет
    local d = listener:GetPos():Distance(talker:GetPos())
    if d > VC().hear then return false end
    return true, VC().use3d
end)

print("[POLUS-11] 3D-голос v4.8.1: местная речь до " .. VC().hear .. "u (затухание), рация — эфирным линком")
