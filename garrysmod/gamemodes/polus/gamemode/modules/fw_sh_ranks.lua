-- ============================================================
--  ПОЛЮС FRAMEWORK — РАНГИ АДМИНИСТРАЦИИ (shared) v1.5
--  10 рангов от User до «Глава Полюса-11». Ранг живёт
--  отдельно от GMod-групп: хранится у нас (ranks.json),
--  синхронизируется через NWString; под движковые права
--  ранг мапится на user/admin/superadmin автоматически.
-- ============================================================

P11FW = P11FW or {}

P11FW.Ranks = {
    { id = "user",       name = "User",            level = 0, color = Color(170, 170, 170) },
    { id = "vip",        name = "VIP",             level = 1, color = Color(235, 205, 100) },
    { id = "helper",     name = "Хелпер",          level = 2, color = Color(140, 220, 150) },
    { id = "moderator",  name = "Модератор",       level = 3, color = Color(140, 190, 250) },
    { id = "admin",      name = "Админ",           level = 4, color = Color(235, 150, 90) },
    { id = "curator",    name = "Куратор",         level = 5, color = Color(225, 120, 110), fx = "shimmer" },
    { id = "superadmin", name = "Суперадмин",      level = 6, color = Color(240, 100, 100), fx = "shimmer" },
    { id = "founder",    name = "Основатель",      level = 7, color = Color(255, 90, 90),   fx = "shimmer" },
    { id = "sozdatel",   name = "Создатель",       level = 8, color = Color(255, 150, 80),  fx = "aurora" },
    { id = "glava",      name = "Глава Полюса-11", level = 9, color = Color(255, 215, 90),  fx = "aurora" },
}

P11FW.RankById = {}
for _, r in ipairs(P11FW.Ranks) do
    P11FW.RankById[r.id] = r
end

--- Ранг игрока (таблица) — user, если не выдан.
function P11FW.GetRank(ply)
    local id = "user"
    if IsValid(ply) then
        if SERVER and ply.P11FW_RankId then
            id = ply.P11FW_RankId
        else
            id = ply:GetNWString("P11FW_Rank", "user")
        end
    end
    return P11FW.RankById[id] or P11FW.RankById.user
end

function P11FW.GetRankLevel(ply)
    if not IsValid(ply) then return 0 end
    -- движковый superadmin считаем верхом стволовой ветки (страховка от локаута)
    if ply:IsSuperAdmin() then
        local r = P11FW.GetRank(ply)
        return math.max(r.level or 0, 6)
    end
    return (P11FW.GetRank(ply) or P11FW.RankById.user).level or 0
end

function P11FW.GetRankName(ply)
    return (P11FW.GetRank(ply) or P11FW.RankById.user).name or "User"
end

function P11FW.GetRankColor(ply)
    return (P11FW.GetRank(ply) or P11FW.RankById.user).color or Color(170, 170, 170)
end

--- Есть ли у ранга живой эффект цвета (Куратор+)
function P11FW.RankHasFx(ply)
    local r = P11FW.GetRank(ply)
    return r and r.fx ~= nil
end

--- v1.6: «ЖИВОЙ» ЦВЕТ РАНГА — для высоких рангов.
--  shimmer = мягкое переливание вокруг базового оттенка (Куратор..Основатель)
--  aurora  = северное сияние (Создатель, Глава Полюса-11)
function P11FW.RankFxColor(ply, t)
    local r = P11FW.GetRank(ply) or P11FW.RankById.user
    local c = r.color or Color(170, 170, 170)
    if not r.fx then return c end
    t = t or (CLIENT and CurTime()) or os.clock()
    local h, s, v = ColorToHSV(c)
    if r.fx == "aurora" then
        -- медленная смена оттенка золото→оранж→роза→золото, пульс яркости
        local wave = math.sin(t * 1.1) * 40 + math.sin(t * 0.7 + 2) * 20
        h = (h + wave) % 360
        s = math.Clamp(s - 0.08 + math.sin(t * 2.4) * 0.10, 0.35, 1)
        v = 0.86 + math.sin(t * 3.0) * 0.14
        return HSVToColor(h, s, v)
    else
        -- shimmer: оттенок качается ±25°, лёгкий блеск
        h = (h + math.sin(t * 1.6 + r.level * 0.8) * 25) % 360
        v = 0.82 + math.sin(t * 2.8) * 0.18
        return HSVToColor(h, s, v)
    end
end

--- Может ли ply выдавать ранги (и не выше себя)?
function P11FW.CanManageRank(ply, targetLevel)
    if not IsValid(ply) then return false end
    local need = P11FW.Config and P11FW.Config.RankManageLevel or 5
    local my = P11FW.GetRankLevel(ply)
    if my < need then return false end
    if targetLevel and targetLevel >= my then return false end
    return true
end

-- ============================================================
--  ПРАВА МОДЕРАЦИИ ПО РАНГАМ (v1.6)
--  Чем выше ранг — тем больше команд и тем ДЛИННЕЕ доступный
--  срок бана/мута/ареста. Shared: клиенту нужно знать свои
--  права, чтобы серить кнопки во вкладке «МОДЕРАЦИЯ».
-- ============================================================

-- минимальный уровень ранга для команды:
-- 0=User 1=VIP 2=Хелпер 3=Модератор 4=Админ 5=Куратор
-- 6=Суперадмин 7=Основатель 8=Создатель 9=Глава Полюса-11
P11FW.PermLevel = {
    warn    = 2, -- Хелпер
    mute    = 2, -- Хелпер
    arrest  = 3, -- Модератор (арест и рабство)
    kick    = 3, -- Модератор
    heal    = 4, -- Админ (быстрые действия: лечить/возродить/тп/заморозить/убить)
    ban     = 4, -- Админ
    unban   = 6, -- Суперадмин
}

-- Лимиты СРОКОВ в МИНУТАХ по уровню ранга. 0 = безлимит (включая перму).
-- Читается сверху вниз: своего уровня в таблице может не быть — берём ближайший снизу.
P11FW.TimeLimits = {
    mute = {  -- Хелпер 30м … Создатель 30д … Глава безлимит
        [2] = 30,      [3] = 240,     [4] = 720,      [5] = 1440,
        [6] = 10080,   [7] = 20160,   [8] = 43200,    [9] = 0,
    },
    arrest = { -- Модератор 1ч … Создатель 7д … Глава безлимит
        [3] = 60,      [4] = 180,     [5] = 1440,     [6] = 4320,
        [7] = 10080,   [8] = 10080,   [9] = 0,
    },
    ban = {    -- Админ 3д … Куратор 7д … Суперадмин 30д … Основатель 70д … Создатель 300д … Глава НАВСЕГДА
        [4] = 4320,    [5] = 10080,   [6] = 43200,    [7] = 100800,
        [8] = 432000,  [9] = 0,
    },
}

--- Есть ли у ранга игрока право на действие (perm из P11FW.PermLevel)?
function P11FW.CanMod(ply, perm)
    if not IsValid(ply) then return false end
    if ply:IsListenServerHost() then return true end
    local need = P11FW.PermLevel and P11FW.PermLevel[perm]
    if not need then return false end
    return P11FW.GetRankLevel(ply) >= need
end

--- Максимальный срок (мин) для kind=mute/arrest/ban.
--- nil — вообще нельзя; 0 — безлимит (перманент доступен).
function P11FW.PunishLimit(ply, kind)
    if not IsValid(ply) then return nil end
    if not P11FW.CanMod(ply, kind) then return nil end
    if ply:IsListenServerHost() then return 0 end
    local lvl = math.Clamp(P11FW.GetRankLevel(ply), 0, 9)
    local t = P11FW.TimeLimits and P11FW.TimeLimits[kind]
    if not t then return 0 end
    for l = lvl, 0, -1 do
        if t[l] ~= nil then return t[l] end
    end
    return 0
end

--- Можно ли наказать ЭТОГО игрока? Нельзя трогать равных и выше,
--- Глава — всех кроме других Глав.
function P11FW.CanTarget(ply, target)
    if not IsValid(ply) or not IsValid(target) then return false end
    if not target:IsPlayer() then return false end
    if ply:IsListenServerHost() then return true end
    local mine   = P11FW.GetRankLevel(ply)
    local theirs = P11FW.GetRankLevel(target)
    if mine >= 9 then return theirs < 9 end
    return mine > theirs
end

--- Человекочитаемый срок минут: «3 дн. 4 ч.», «45 мин.», «НАВСЕГДА»
function P11FW.FmtMinutes(mins)
    mins = tonumber(mins) or 0
    if mins == 0 then return "НАВСЕГДА" end
    local d = math.floor(mins / 1440)
    local h = math.floor((mins % 1440) / 60)
    local m = mins % 60
    local out = {}
    if d > 0 then out[#out + 1] = d .. " дн." end
    if h > 0 then out[#out + 1] = h .. " ч." end
    if m > 0 or #out == 0 then out[#out + 1] = m .. " мин." end
    return table.concat(out, " ")
end
