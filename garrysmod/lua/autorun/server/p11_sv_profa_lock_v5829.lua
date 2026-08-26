-- ============================================================
--  ПОЛЮС-11 — ЗАМОК «!ПРОФА» v5.8.29 (НОВЫЙ ФАЙЛ, server)
-- ============================================================
--  ДЫРА: p11_sv_zz_fixes_v5814.lua даёт ЛЮБОМУ игроку команду
--  !профа <текст> — она пишет NWString P11_JobName, а его читают
--  намики и ТАБ. То есть Нечто в личине или шпион может написать
--  себе «НАЧАЛЬНИК НКВД» / «ГЛАВА ПРОЕКТА» без всякого вайтлиста.
--
--  ЧТО ДЕЛАЕМ (старые файлы не трогаем):
--    • оборачиваем обработчик P11.ChatCore (тот же приём, что и v5.8.14,
--      но встаём ПОСЛЕ него — имя файла zz_* и повторные попытки) и
--      пускаем !профа только с ранга p11_profa_minlevel (по умолчанию 2 =
--      Helper и выше);
--    • остальным — вежливый отказ и подсказка, что позывной меняется
--      в анкете бойца, а не должностью;
--    • страховка: раз в 15 сек чистим P11_JobName тем, кто не проходит
--      по рангу (если имя всё же успели поставить в обход).
--
--  Тюнинг без рестарта:  p11_profa_minlevel <0..16>   (0 = разрешить всем)
--  Откат: удалить этот файл.
-- ============================================================

local cvMin = CreateConVar("p11_profa_minlevel", "2", FCVAR_ARCHIVE,
    "POLUS-11 v5.8.29: с какого ранга можно менять название должности через !профа (0 = всем)")

local function RankLevel(ply)
    if not IsValid(ply) then return 0 end
    if P11FW and P11FW.GetRankLevel then
        local ok, lvl = pcall(P11FW.GetRankLevel, ply)
        if ok and isnumber(lvl) then return lvl end
    end
    if ply.IsSuperAdmin and ply:IsSuperAdmin() then return 99 end
    return 0
end

local function Allowed(ply)
    local need = math.max(0, cvMin:GetInt())
    if need <= 0 then return true end
    return RankLevel(ply) >= need
end

local function IsProfaCmd(first)
    first = string.lower(tostring(first or ""))
    return first == "!профа" or first == "!профa" or first == "/профа"
end

-- ============ 1) ПЕРЕХВАТ КОМАНДЫ (встаём поверх v5.8.14) ============
-- Метки «обёртка уже стоит» держим в СВОЕЙ таблице, а не в полях функции:
-- в чистом Lua 5.1/LuaJIT индексация функции = ошибка
-- («attempt to index a function value»). См. p11_sv_funcmeta_v5829.lua.
local Wrapped = setmetatable({}, { __mode = "k" })

local function ReadFlag(fn, key)
    local v
    pcall(function() v = fn[key] end)
    return v
end

local function PatchProfa()
    local t = hook.GetTable()
    local ps = t and t.PlayerSay
    local orig = ps and ps["P11.ChatCore"]
    if not orig then return false end
    if Wrapped[orig] then return true end

    local wrap = function(ply, text)
        local raw = string.Trim(tostring(text or ""))
        local first = string.match(raw, "^(%S+)") or ""
        if IsProfaCmd(first) then
            if not Allowed(ply) then
                if POLUS11 and POLUS11.Notify then
                    POLUS11.Notify(ply, "Название должности меняет состав от ранга " ..
                        cvMin:GetInt() .. "+ (стафф). Свой позывной — в анкете бойца (/анкета).")
                elseif IsValid(ply) then
                    ply:ChatPrint("[ПОЛЮС-11] !профа доступна стаффу.")
                end
                if POLUS11 and POLUS11.Log then
                    POLUS11.Log("!профа ОТКАЗ: " .. ply:Nick() .. " [" .. ply:SteamID() ..
                        "] (ранг " .. RankLevel(ply) .. ")")
                end
                return ""
            end
        end
        return orig(ply, text)
    end
    Wrapped[wrap] = true
    pcall(function() wrap.P11_ProfaFix = ReadFlag(orig, "P11_ProfaFix") end) -- метка v5.8.14
    ps["P11.ChatCore"] = wrap
    print("[POLUS-11] v5.8.29: !профа — только ранг " .. cvMin:GetInt() .. "+ (замок поверх v5.8.14)")
    return true
end

-- v5.8.14 ставит свою обёртку таймерами до 10 сек — встаём позже
hook.Add("InitPostEntity", "P11.ProfaLock.v5829", function()
    timer.Simple(11, PatchProfa)
    timer.Simple(15, PatchProfa)
    timer.Simple(30, PatchProfa)
end)
timer.Simple(12, PatchProfa)
timer.Simple(20, PatchProfa)

-- ============ 2) ЖЁСТКИЙ ЗАМОК НА УРОВНЕ МЕТАТАБЛИЦЫ ИГРОКА ============
-- Перехват чат-команды зависит от того, чья обёртка встала последней
-- (v5.8.14 ставит свою таймерами до 10 сек). Поэтому держим ещё один,
-- ПОРЯДКОНЕЗАВИСИМЫЙ замок: P11_JobName просто не записывается тому,
-- у кого нет ранга. Обойти нельзя ни чатом, ни net, ни консолью.
local function InstallMetaLock()
    local meta = FindMetaTable and FindMetaTable("Player")
    if not meta then return false end
    if rawget(meta, "P11_ProfaMeta5829") then return true end
    local origSet = meta.SetNWString
    meta.SetNWString = function(self, key, value)
        if key == "P11_JobName" and not Allowed(self) then
            if POLUS11 and POLUS11.Notify and not self.P11_ProfaTold then
                self.P11_ProfaTold = CurTime() + 30
                POLUS11.Notify(self, "Название должности меняет состав от ранга " ..
                    cvMin:GetInt() .. "+. Свой позывной — в анкете бойца (/анкета).")
            end
            if POLUS11 and POLUS11.Log then
                POLUS11.Log("!профа БЛОК: " .. tostring(self:Nick()) .. " — попытка записать «" ..
                    tostring(value) .. "» без прав")
            end
            return
        end
        if origSet then return origSet(self, key, value) end
    end
    rawset(meta, "P11_ProfaMeta5829", true)
    print("[POLUS-11] v5.8.29: запись P11_JobName закрыта на уровне метатаблицы игрока")
    return true
end

hook.Add("InitPostEntity", "P11.ProfaMeta.v5829", function()
    timer.Simple(0.3, InstallMetaLock)
    timer.Simple(3, InstallMetaLock)
end)
timer.Simple(0.1, InstallMetaLock)

-- ============ 3) СТРАХОВКА: чистим чужие «должности» ============
timer.Create("P11.ProfaLock.Sweep", 15, 0, function()
    if cvMin:GetInt() <= 0 then return end
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and not Allowed(ply) then
            if ply:GetNWString("P11_JobName", "") ~= "" then
                ply:SetNWString("P11_JobName", "")
                if POLUS11 and POLUS11.Log then
                    POLUS11.Log("!профа СБРОС: " .. ply:Nick() .. " — название должности снято (нет прав)")
                end
            end
        end
    end
end)
