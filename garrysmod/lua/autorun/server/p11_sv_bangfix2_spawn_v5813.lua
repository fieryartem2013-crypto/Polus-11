-- ============================================================
--  ПОЛЮС-11 — ФИКС «!»-КОМАНД: НЕ УХОДЯТ В OOC v5.8.13 (server)
--  Жалоба: «если писать ! а потом что угодно — пишется в OOC чат».
--  ПРИЧИНА: ChatCore (p11_sv_chat.lua) для НЕизвестных «!»-строк
--  вызывает ChatSend(OOC) — текст уходил в OOC. Плюс новые команды
--  (v5.8.x: !радио, !музыка, !музстоп, !о нас, !дежурство и т.д.)
--  НЕ внесены в старый список BANG_SERVER → тоже уходили в OOC.
--
--  РЕШЕНИЕ (старые файлы НЕ трогаем): заменяем обработчик
--  "P11.ChatCore" в таблице хуков обёрткой:
--   • известные команды (полный список, включая новые v5.8.x) —
--     пропускаем оригиналу → их съедают свои обработчики;
--   • НЕизвестные «!»-строки — МОЛЧА ГЛОТАЕМ (не уходят в OOC),
--     автору короткая подсказка (с антиспамом 10 сек).
-- ============================================================

-- полный список известных команд (первое слово). Кириллица — как
-- пишется (string.lower не трогает кириллицу — храним оба регистра
-- для ключевых).
local KNOWN = {
    -- === базовые (из BANG_SERVER p11_sv_chat) ===
    ["!работа"]=true, ["!job"]=true, ["!f4"]=true, ["!профа"]=true, ["!Профа"]=true,
    ["!нпс"]=true, ["!npc"]=true, ["!menu"]=true, ["!фвадмин"]=true, ["!fw"]=true, ["!p11"]=true,
    ["!персонаж"]=true, ["!name"]=true, ["!приказ"]=true, ["!order"]=true,
    ["!розыск"]=true, ["!wanted"]=true, ["!репорт"]=true, ["!report"]=true,
    ["!ролл"]=true, ["!roll"]=true, ["!репорты"]=true, ["!reports"]=true,
    ["!дать"]=true, ["!give"]=true, ["!ларёк"]=true, ["!ларек"]=true,
    ["!shop"]=true, ["!магазин"]=true, ["!маскировка"]=true, ["!маск"]=true,
    ["!разрыв"]=true, ["!взрыв"]=true, ["!крик"]=true, ["!буря"]=true, ["!storm"]=true,
    ["!обмен"]=true, ["!trade"]=true, ["!промо"]=true, ["!ПРОМО"]=true, ["!promo"]=true,
    ["!вакансия"]=true, ["!ВАКАНСИЯ"]=true, ["!взять"]=true, ["!ВЗЯТЬ"]=true, ["!take"]=true,
    ["!ивент"]=true, ["!ИВЕНТ"]=true, ["!event"]=true, ["!крафт"]=true, ["!craft"]=true,
    ["!мастерская"]=true, ["!сборка"]=true, ["!гараж"]=true, ["!garage"]=true,
    ["!авто"]=true, ["!машина"]=true, ["!улики"]=true, ["!УЛИКИ"]=true, ["!uliki"]=true, ["!clues"]=true,
    ["!штраф"]=true, ["!Штраф"]=true, ["!ШТРАФ"]=true, ["!shtraf"]=true, ["!fine"]=true,
    ["!казна"]=true, ["!Казна"]=true, ["!КАЗНА"]=true,
    -- === клиентские (BANG_CLIENT) ===
    ["!смена"]=true, ["!выбор"]=true, ["!пульт"]=true, ["!pult"]=true, ["!panel"]=true, ["!меню"]=true,
    -- === новые v5.8.x (радио/музыка/о нас) ===
    ["!радио"]=true, ["!радиостоп"]=true, ["!радиогром"]=true, ["!радиоцикл"]=true,
    ["!музыка"]=true, ["!музстоп"]=true, ["!музгром"]=true, ["!музцикл"]=true,
    ["!о"]=true, ["!О"]=true, ["!об"]=true, ["!проект"]=true, ["!Проект"]=true,
    -- === дежурства/служба ===
    ["!дежурство"]=true, ["!Дежурство"]=true, ["!опыт"]=true, ["!память"]=true,
    ["!состояние"]=true, ["!сбор"]=true, ["!помощь"]=true, ["!гайд"]=true, ["!донат"]=true,
}

local function IsKnown(first)
    return KNOWN[first] or KNOWN[string.lower(first)]
        or string.StartWith(string.lower(first), "!форма") -- префикс Нечто
end

-- ============ ЗАМЕНА ОБРАБОТЧИКА ============
local patched = false
local function PatchChatCore()
    if patched then return true end
    local t = hook.GetTable()
    local ps = t and t.PlayerSay
    local orig = ps and ps["P11.ChatCore"]
    if not orig then return false end

    -- защита от двойной обёртки
    if orig.P11_BangFix then
        patched = true
        return true
    end

    local Wrap = function(ply, text)
        local raw = string.Trim(tostring(text or ""))
        if string.StartWith(raw, "!") then
            local first = string.match(raw, "^(%S+)") or ""
            if IsKnown(first) then
                return orig(ply, text) -- известная команда — пусть обрабатывают
            end
            -- неизвестная «!» — глотаем: НЕ уходит в OOC
            local now = CurTime()
            if IsValid(ply) and (ply.P11_BangNoteT or 0) < now then
                ply.P11_BangNoteT = now + 10
                ply:ChatPrint("⚠ Неизвестная команда: «" .. raw .. "» (напиши !помощь или F1)")
            end
            return ""
        end
        return orig(ply, text)
    end
    Wrap.P11_BangFix = true
    ps["P11.ChatCore"] = Wrap
    patched = true
    print("[POLUS-11] ФИКС v5.8.13: неизвестные «!»-команды больше НЕ уходят в OOC")
    return true
end

-- ставим сразу и повторяем (на случай порядка загрузки)
hook.Add("InitPostEntity", "P11.BangFix.Start", function()
    timer.Simple(1, PatchChatCore)
end)
timer.Simple(0.5, PatchChatCore)
timer.Simple(2, PatchChatCore)
timer.Simple(5, PatchChatCore)
