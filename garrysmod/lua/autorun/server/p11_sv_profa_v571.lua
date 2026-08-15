-- ============================================================
--  ПОЛЮС-11 — !ПРОФА + ФИКСЫ v5.7.1 (server, autorun)
--  Владелец:
--    1) команда !Профа <название> — меняет название профессии
--       игрока на то, что напишут после команды (персонально,
--       видно в намиках и TAB);
--    2) добить медали насмерть: глушим серверные оповещения о
--       награждении (P11_Announce «НАГРАЖДЕНИЕ») и медальные
--       каналы — в логе всё ещё приходили «награждён медалью».
--
--  Механика !Профа: сохраняем «ник профы» на сервере (NWString
--  P11_JobName), клиентская обёртка GetJobName (в fixboot) вернёт
--  его в намиках/TAB. Сброс: !Профа (без текста) или !Профа сброс.
--  Старые файлы не трогаем.
-- ============================================================

local ok, err = pcall(function()

-- ============ 1) !ПРОФА ============
local function SetJobName(ply, name)
    if not IsValid(ply) then return end
    name = string.Trim(tostring(name or ""))
    -- сброс
    if name == "" or string.lower(name) == "сброс" or string.lower(name) == "reset" then
        ply:SetNWString("P11_JobName", "")
        if POLUS11.Notify then POLUS11.Notify(ply, "Название профессии сброшено (штатное).") end
        return
    end
    -- валидация длины
    name = string.sub(name, 1, 40)
    if #name < 2 then
        if POLUS11.Notify then POLUS11.Notify(ply, "Слишком коротко — минимум 2 символа.") end
        return
    end
    ply:SetNWString("P11_JobName", name)
    if POLUS11.Notify then
        POLUS11.Notify(ply, "Название профессии: «" .. name .. "» — теперь так видно в TAB и над головой.")
    end
    if POLUS11.Log then POLUS11.Log("!Профа: " .. ply:Nick() .. " переименовал профу в «" .. name .. "»") end
end

-- перехват !Профа (оборачиваем роутер чата)
do
    local t = hook.GetTable()
    local ps = t and t["PlayerSay"]
    if ps and ps["P11.ChatCore"] then
        local orig = ps["P11.ChatCore"]
        ps["P11.ChatCore"] = function(ply, text)
            if IsValid(ply) and isstring(text) then
                local low = string.lower(string.Trim(text))
                if string.StartWith(low, "!профа") then
                    local name = string.Trim(string.sub(text, 8)) -- после "!Профа "
                    SetJobName(ply, name)
                    return ""
                end
            end
            return orig(ply, text)
        end
    end
end

-- ============ 2) МЕДАЛИ НАСМЕРТЬ: ГЛУШИМ ОПОВЕЩЕНИЯ ============
-- (сервер всё ещё мог слать P11_Announce «НАГРАЖДЕНИЕ»/«АВТОНАГРАДА»)
POLUS11.MedalDefs  = {}
POLUS11.Medals     = {}
POLUS11.AutoStats  = {}
POLUS11.AutoMedals = {}
POLUS11.MedalPush      = function() end
POLUS11.MedalAward     = function() return false end
POLUS11.MedalRevoke    = function() return false end
POLUS11.MedalScope     = function() return nil end
POLUS11.MedalAutoGrant = function() return false end
POLUS11.MedalStatEvent = function() end

-- глушим анонсы награждения (P11_Announce с заголовком НАГРАЖДЕНИЕ/АВТОНАГРАДА)
do
    local base = P11FW and P11FW.Announce
    if POLUS11.Announce then
        local origAnn = POLUS11.Announce
        POLUS11.Announce = function(txt, by)
            if isstring(by) and (by == "НАГРАЖДЕНИЕ" or by == "АВТОНАГРАДА") then
                return -- медали вырезаны — молчим
            end
            return origAnn(txt, by)
        end
    end
end

end)
if not ok then
    print("[POLUS-11][!Профа] ошибка: " .. tostring(err))
end

print("[POLUS-11] !ПРОФА v5.7.1: !Профа <название> меняет название профы · медали добиты (анонсы заглушены)")
