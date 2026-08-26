-- ============================================================
--  ПОЛЮС-11 — ТАНЦ-ПЛОЩАДКА ЧАТА «ЭФИР» (shared bootstrap) v4.8.6
--  По заявке владельца: «сам чат вырежи, найди готовый с инета,
--  отредактируй под нас». ВЗЯТ готовый проверенный чат —
--  **BonChat** (MIT © Bonyoze, github.com/Bonyoze/legacy-bonchat,
--  лицензия: gamemode/bonchat/LICENSE) — 3+ года на прод-серверах,
--  своя история, скролл, тайм-стампы, эмодзи, вложения,
--  командный чат по T, тик-звук, настройки шестерёнкой.
--
--  ОТРЕДАКТИРОВАНО ПОД НАС:
--   • база сервера: фикс «молчит роутер — терялось сообщение»;
--   • кастомы станции: русские «зашёл/покинул станцию», «сменил
--     позывной», титул рамы «ПОЛЮС-11 · ЭФИР»;
--   • русские плейсхолдеры ввода с НАШИМИ префиксами каналов
--     ( // OOC · /w шёпот · /y крик · /r рация · /report );
--   • русифицирована панель настроек и инфо-сообщения;
--   • совместимость с ПОЛЮС-11: серверный роутер каналов
--     (p11_sv_chat) работает КАК РАНЬШЕ — BonChat шлёт текст через
--     PlayerSay, а приём каналов идёт через chat.AddText, который
--     BonChat сам отрисовывает со всеми нашими цветами префиксов.
--   • АВАРИЙНЫЙ ВЫХОД остался: bonchat_enable 0 = движковый чат.
--
--  Этот файл — только томагавк загрузки: серверу — base_sv
--  (сетевые строки+роутинг), клиенту — base_cl (панель+перехват).
-- ============================================================

BonChat = BonChat or {}

-- статус «печатает…» для тех, кто его читает (платёжка из оригинального
-- autorun BonChat — сам файл мы не тащим, докидываем руками)
local plyMeta = FindMetaTable("Player")
BonChat.oldPlyIsTyping = BonChat.oldPlyIsTyping or plyMeta.IsTyping
function plyMeta:IsTyping()
    return (BonChat.oldPlyIsTyping and BonChat.oldPlyIsTyping(self))
        or self.bonchatIsTyping or false
end

if SERVER then
    include("bonchat/base_sv.lua")
    print("[P11-ЭФИР] фронтенд чата: BonChat (MIT © Bonyoze) подключён сервером ✔")
else
    include("bonchat/base_cl.lua")
    print("[P11-ЭФИР] фронтенд чата: BonChat (MIT © Bonyoze) подключён клиенту ✔ | движковый чат: bonchat_enable 0")

    -- ============ v4.14.0 «СВЯЗЬ»: свой чат старший; страховка выровнена ============
    -- Расклад: если свой чат «СВЯЗЬ» (p11_ownchat 1, окно живо) — BonChat
    -- СПИТ (конвар держим в 0). Если «СВЯЗЬ» выключена или не поднялась —
    -- BonChat возвращается сам (старое поведение страховки).
    timer.Simple(9, function()
        local own = GetConVar("p11_ownchat")
        local ownAlive = own and own:GetBool()
            and IsValid(P11CHAT and P11CHAT.Frame)
        local cv = GetConVar("bonchat_enable")
        if ownAlive then
            if cv and cv:GetBool() then
                RunConsoleCommand("bonchat_enable", "0")
                print("[P11-ЭФИР] страховка: свой чат «СВЯЗЬ» жив — BonChat оставлен спящим (назад: p11_ownchat 0)")
            end
            return
        end
        -- свой чат отсутствует/сломан → добиваемся BonChat как раньше
        if cv and not cv:GetBool() then
            RunConsoleCommand("bonchat_enable", "1")
            notification.AddLegacy("ЭФИР: свой чат «СВЯЗЬ» не поднялся — включён запасной BonChat (вернуть: p11_ownchat 1).", NOTIFY_HINT, 6)
            print("[P11-ЭФИР] СТРАХОВКА: свой чат не жив (p11_ownchat=0 или окно не создано) → bonchat_enable 1")
        end
        if not (BonChat and IsValid(BonChat.frame)) then
            notification.AddLegacy("ЭФИР: чаты не поднялись (и «СВЯЗЬ», и BonChat) — напиши в консоль p11_chatfix и скинь владельцу КРАСНЫЕ строки консоли клиента (клавиша ~).", NOTIFY_ERROR, 9)
            print("[P11-ЭФИР] ВНИМАНИЕ: ни «СВЯЗЬ», ни BonChat.frame не созданы через 9 сек после загрузки — мешает чужой аддон-чат или ошибка клиента ВЫШЕ по этому логу. Команда: p11_chatfix")
        end
    end)

    -- самопочинка по требованию: статус обоих фронтов + поднять живое
    concommand.Add("p11_chatfix", function()
        local ownAlive = IsValid(P11CHAT and P11CHAT.Frame)
        local bcv = GetConVar("bonchat_enable")
        print("[P11-ЭФИР] chatfix: свой чат «СВЯЗЬ» = " .. (ownAlive and "ЖИВ" or "НЕТ")
            .. " | BonChat = " .. ((BonChat and IsValid(BonChat.frame)) and "ЖИВ" or "НЕТ")
            .. " | bonchat_enable = " .. (bcv and bcv:GetString() or "?"))
        if ownAlive then
            if bcv and bcv:GetBool() then RunConsoleCommand("bonchat_enable", "0") end
            notification.AddLegacy("ЭФИР: свой чат «СВЯЗЬ» жив — открывайся клавишей Y.", NOTIFY_HINT, 6)
        else
            if bcv then RunConsoleCommand("bonchat_enable", "1") end
            notification.AddLegacy("ЭФИР: чиню — включён BonChat; вернуть свой чат: p11_ownchat 1.", NOTIFY_HINT, 6)
        end
    end, nil, "Самопочинка чатов станции: статус «СВЯЗЬ»/BonChat + поднять живое (v4.14.0)")
end
