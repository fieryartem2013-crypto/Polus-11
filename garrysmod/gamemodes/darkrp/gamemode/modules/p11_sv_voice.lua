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

-- v4.18.0 «РЕПРОДУКТОР» (заявка «чат весь сервер слышно — уменьши радиус»):
-- радиус местной речи уменьшен до 750u и вынесен в живой конвар
-- p11_voiceradius (0 = по конфигу) — крутится без рестарта.
local cvRad = CreateConVar("p11_voiceradius", "750", FCVAR_ARCHIVE,
    "POLUS-11: радиус местной голосовой речи (юн), 0 = по конфигу")

local function VC()
    local c = POLUS11.Config or {}
    local h = cvRad:GetInt()
    if h <= 0 then h = tonumber(c.VoiceHearRadius) or 750 end
    return {
        hear = h,
        full = tonumber(c.VoiceFullRadius) or 340,
        use3d = c.Voice3D ~= false,
        allr = h * 3, -- «Общий» канал теперь полевой эфир (×3 местной речи)
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
    -- проявившееся Нечто с рацией слышит весь эфир (как и раньше)
    if listener:GetNWBool("P11_Infected", false)
        and listener:GetNWBool("P11_InfActive", false) then
        return true
    end
    -- v4.18.0 «РЕПРОДУКТОР» (заявка «3D чат не работает — на всю карту
    -- слышно»): КОРЕНЬ БЫЛ ЗДЕСЬ. «Общий» канал самолинковал ВЕСЬ сервер
    -- в стерео (все профы носят рацию на «Общем») — отсюда «говоришь в
    -- одном конце карты, слышно в другом как из-за плеча». Теперь:
    --   • совпавшие ЯВНЫЕ каналы (не «all») — эфир на всю карту (суть
    --     полевой рации: «Командный», «Наука» и т.д.);
    --   • «Общий»+«Общий» — только ПОЛЕВОЙ эфир в пределах allr (×3
    --     местной речи, по умолчанию 2250u): пост рядом слышит, другой
    --     конец карты — нет;
    --   • «Общий» ↔ явный канал в эфире НЕ встречаются.
    if lch ~= "all" and tch ~= "all" and lch == tch then
        return true
    end
    if lch == "all" and tch == "all" then
        local rr = VC().allr
        return listener:GetPos():DistToSqr(talker:GetPos()) <= rr * rr
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

-- v4.9.2 «ПРИЁМ»: самопроверка рации и голосового линка — p11_voiceradio.
-- Отвечает игроку: есть ли у него рация, канал, сколько бойцов сейчас
-- слышит его в эфире. Эфир «не работает» в 99% случаев = у одной
-- стороны НЕТ РАЦИИ в снаряге (до этой версии её не было у НАУКИ — раньше
-- радио выдавалось только РККА/НКВД; с v4.9.2 рация — у всей науки,
-- сид + миграция radioV492).
concommand.Add("p11_voiceradio", function(ply)
    if not IsValid(ply) then print("p11_voiceradio — команда ИГРОКА") return end
    local has = POLUS11.HasRadio and POLUS11.HasRadio(ply)
    local ch = ply:GetNWString("P11_RadioCh", "all")
    local linked = 0
    for _, p2 in ipairs(player.GetAll()) do
        if p2 ~= ply and IsValid(p2) and p2:Alive() and ply:Alive()
            and RadioLinked(p2, ply) then
            linked = linked + 1
        end
    end
    POLUS11.Notify(ply, "📻 РАЦИЯ: у тебя " .. (has and "ЕСТЬ" or "НЕТ в снаряге — в эфир не выйдешь (возьми в ларьке/у командира)")
        .. " • канал: «" .. tostring(ch == "all" and "Общий" or ch) .. "»"
        .. (ch == "all" and " (полевой эфир в пределах " .. VC().allr .. "u — дальше тишина)" or ""))
    POLUS11.Notify(ply, "📻 ЭФИР СЕЙЧАС: тебя в рации слышит живых: " .. linked .. ". Местная речь голосом — до "
        .. tostring(VC().hear) .. "u. Буря " .. (GetGlobalBool("P11_Storm", false) and "ИДЁТ — эфир глушится!" or "ясная — эфир работает."))
end)

print("[POLUS-11] 3D-голос v4.18.0 «РЕПРОДУКТОР»: местная речь до " .. VC().hear .. "u (p11_voiceradius), «Общий» канал — полевой эфир до " .. VC().allr .. "u, явные каналы — на всю карту; самодиагностика p11_voiceradio")
