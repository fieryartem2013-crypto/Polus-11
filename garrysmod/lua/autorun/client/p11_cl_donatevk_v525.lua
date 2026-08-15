-- ============================================================
--  ПОЛЮС-11 — ДОНАТ → VK (client) v5.2.5 (НОВЫЙ ФАЙЛ, autorun)
--  Владелец: «донат поменяй с ДС на ВК vk.ru/stolinov».
--  Старый p11_cl_donate.lua НЕ трогаем: переопределяем функцию
--  P11D.BuyInDiscord (открытие покупки) — теперь всегда открывает
--  VK владельца, тексты про VK (не про ДС). Оригинал работает
--  тем же кодом, но мы перекрываем его ПОСЛЕ загрузки гейммода.
-- ============================================================

local VK_URL = "https://vk.ru/stolinov"

if P11D then
    P11D.BuyInDiscord = function(packName, price)
        surface.PlaySound("ui/buttonclick.wav")
        P11D.PromoMsg = "Открываю VK владельца: «" .. tostring(packName) .. "» (" .. tostring(price) .. ")…"
        P11D.PromoOk = true
        gui.OpenURL(VK_URL)
        chat.AddText(Color(235, 205, 100), "[ПОДДЕРЖКА] ",
            Color(225, 230, 240), "Открыл VK (vk.ru/stolinov): оплата по договорённости, пакет «" .. tostring(packName)
            .. "» за " .. tostring(price) .. ". ПФ долетит на баланс (магазин/Глава: p11_fluxgive).")
    end
end

print("[POLUS-11] ДОНАТ → VK v5.2.5 (client, autorun): vk.ru/stolinov")
