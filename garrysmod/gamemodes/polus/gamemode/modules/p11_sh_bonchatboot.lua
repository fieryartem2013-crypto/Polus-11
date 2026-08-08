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

    -- ============ v4.12.2 «ЭФИР»: СТРАХОВКА «КАСТОМНОГО ЧАТА НЕТ» ============
    -- Исторический сценарий падения: у клиента bonchat_enable стоит 0
    -- (выключено когда-то руками/чужим конфигом, конвар архивный и живёт
    -- вечно) — чат ванильный вечно. Лечим сами через 9 сек: вернуть 1
    -- (BonChat перехватит конвар ДИНАМИЧЕСКИ — перезаход не нужен).
    timer.Simple(9, function()
        local cv = GetConVar("bonchat_enable")
        if cv and not cv:GetBool() then
            RunConsoleCommand("bonchat_enable", "1")
            notification.AddLegacy("ЭФИР: чат станции был выключен — включён обратно автоматически (bonchat_enable 1).", NOTIFY_HINT, 6)
            print("[P11-ЭФИР] СТРАХОВКА: bonchat_enable был 0 → вернули 1 (окно ЭФИРА оживёт без перезахода)")
        end
        if not (BonChat and IsValid(BonChat.frame)) then
            notification.AddLegacy("ЭФИР: кастомный чат не поднялся — напиши в консоль p11_chatfix и скинь владельцу КРАСНЫЕ строки консоли клиента (клавиша ~).", NOTIFY_ERROR, 9)
            print("[P11-ЭФИР] ВНИМАНИЕ: BonChat.frame не создан через 9 сек после загрузки — мешает чужой аддон-чат или ошибка клиента ВЫШЕ по этому логу. Команда: p11_chatfix")
        end
    end)

    -- самопочинка по требованию: включить + статус в консоль
    concommand.Add("p11_chatfix", function()
        local cv = GetConVar("bonchat_enable")
        if cv and not cv:GetBool() then
            RunConsoleCommand("bonchat_enable", "1")
            print("[P11-ЭФИР] chatfix: bonchat_enable → 1 (окно ЭФИРА оживает немедленно)")
        end
        local alive = BonChat and IsValid(BonChat.frame)
        print("[P11-ЭФИР] chatfix: панель BonChat = " .. (alive and "ЖИВА" or "НЕТ — ищи КРАСНУЮ ошибку клиента выше (чаще чужой аддон-чат)"))
        notification.AddLegacy(
            alive and "ЭФИР: чат жив — открывайся клавишей Enter или Y."
                    or  "ЭФИР: чат НЕ поднят — красные строки консоли клиента (~) → владельцу.",
            alive and NOTIFY_HINT or NOTIFY_ERROR, 6)
    end, nil, "Самопочинка чата станции: включить BonChat + статус (v4.12.2)")
end
