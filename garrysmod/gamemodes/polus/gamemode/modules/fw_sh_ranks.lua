-- ============================================================
--  ПОЛЮС FRAMEWORK — РАНГИ АДМИНИСТРАЦИИ (shared) v2.0
--  v3.8.2: НОВАЯ ИЕРАРХИЯ проекта — 16 рангов от User до
--  «Глава Проекта» (список от владельца сервера). Ранг живёт
--  отдельно от GMod-групп: хранится у нас (ranks.json),
--  синхронизируется через NWString; под движковые права
--  ранг мапится на user/admin/superadmin автоматически.
--  ВНИМАНИЕ: id «glava» зашит в ключ основателя (p11_access),
--  верхнюю строчку не переназывай; остальные строки/цвета/уровни
--  можно править прямо здесь — админка и TAB подхватят сами.
-- ============================================================

P11FW = P11FW or {}

P11FW.Ranks = {
    { id = "user",              name = "User",                  level = 0,  color = Color(170, 170, 170) },
    { id = "vip",               name = "VIP",                   level = 1,  color = Color(235, 205, 100) },
    -- v4.4.0: ДОЛЖНОСТНЫЕ ранги вайтлиста — это НЕ админка (прав модерации
    -- нет, уровень 1), но есть доступ к меню ВАЙТЛИСТА (выдача допусков
    -- на whitelist-должности, напр. всё НКВД). Флаг wl = true.
    { id = "faction_officer",   name = "Faction Officer",       level = 1,  color = Color(150, 200, 255), wl = true },
    { id = "faction_leader",    name = "Faction Leader",        level = 1,  color = Color(255, 180, 110), wl = true },
    { id = "helper",            name = "Helper",                level = 2,  color = Color(140, 220, 150) },
    { id = "moderator",         name = "Moderator",             level = 3,  color = Color(140, 190, 250) },
    { id = "admin",             name = "Administrator",         level = 4,  color = Color(235, 150, 90) },
    { id = "head_admin",        name = "Head Administrator",    level = 5,  color = Color(240, 135, 75) },
    { id = "super_admin",       name = "Super Administrator",   level = 6,  color = Color(240, 100, 100), fx = "shimmer" },
    { id = "global_admin",      name = "Global Administrator",  level = 7,  color = Color(235, 95, 145),  fx = "shimmer" },
    { id = "anticheat",         name = "Anticheat Helper",      level = 8,  color = Color(120, 220, 210), fx = "shimmer" },
    { id = "developer",         name = "Developer",             level = 9,  color = Color(110, 205, 255), fx = "shimmer" },
    { id = "dep_staff_leader",  name = "Deputy Staff Leader",   level = 10, color = Color(185, 145, 235), fx = "shimmer" },
    { id = "dep_chief_curator", name = "Deputy Chief Curator",  level = 11, color = Color(215, 125, 165), fx = "shimmer" },
    { id = "curator",           name = "Curator",               level = 12, color = Color(225, 120, 110), fx = "shimmer" },
    { id = "chief_curator",     name = "Chief Curator",         level = 13, color = Color(205, 105, 220), fx = "aurora" },
    { id = "staff_leader",      name = "Staff Leader",          level = 14, color = Color(255, 150, 80),  fx = "aurora" },
    { id = "chief_staff_leader",name = "Chief Staff Leader",    level = 15, color = Color(255, 185, 95),  fx = "aurora" },
    { id = "glava",             name = "Глава Проекта",         level = 16, color = Color(255, 215, 90),  fx = "aurora" },
}

P11FW.RankById = {}
for _, r in ipairs(P11FW.Ranks) do
    P11FW.RankById[r.id] = r
end

-- v3.8.2: АЛИАСЫ СТАРЫХ ID (сейвы v3.3..v3.8.1 в ranks.json) -> новые id.
-- Иначе «founder»/«sozdatel» из старого файла слетали бы в user.
P11FW.RankLegacy = {
    superadmin = "super_admin",
    founder    = "global_admin",
    sozdatel   = "chief_staff_leader",
    kurator    = "curator",
}

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
    id = P11FW.RankLegacy[id] or id
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

--- v4.4.0: может ли игрок УПРАВЛЯТЬ ВАЙТЛИСТОМ должностей
--- (выдавать/снимать допуски на whitelist-профы — вкладка ВАЙТЛИСТ):
--- администрация ИЛИ ранг с флагом wl (Faction Officer / Faction Leader).
function P11FW.CanWhitelist(ply)
    if not IsValid(ply) then return false end
    if ply:IsListenServerHost() then return true end
    if P11FW.Config and P11FW.Config.Admin and P11FW.Config.Admin(ply) then return true end
    local r = P11FW.GetRank and P11FW.GetRank(ply)
    return r ~= nil and r.wl == true
end

--- v4.8.0: VIP-СТАТУС — может ли игрок брать VIP-должности (F4 → 💎 VIP-СЛУЖБА).
--- Пускаем: ранг VIP, любой стафф от Helper (ур.2) и выше, админов движка,
--- слушающего хоста. Обычный User — нет (стимул поддержать станцию через F6).
function P11FW.IsVIP(ply)
    if not IsValid(ply) then return false end
    if ply:IsListenServerHost() then return true end
    if ply:IsSuperAdmin() or ply:IsAdmin() then return true end
    local r = P11FW.GetRank(ply)
    if not r then return false end
    return r.id == "vip" or (r.level or 0) >= 2
end

--- v4.8.0: Q-МЕНЮ (спавнменю) — только с ранга Developer (ур.9) и выше.
--- Ниже рангом меню НЕ открывается (заявка владельца). Порог настраивается
--- в P11FW.Config.DevMenuLevel (fw_sh_config.lua).
function P11FW.CanDevMenu(ply)
    if not IsValid(ply) then return false end
    if ply:IsListenServerHost() then return true end
    if ply:IsSuperAdmin() then return true end
    local need = (P11FW.Config and P11FW.Config.DevMenuLevel) or 9
    return P11FW.GetRankLevel(ply) >= need
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

-- минимальный уровень ранга для команды (v3.8.2, новая шкала):
-- 0=User 1=VIP 2=Helper 3=Moderator 4=Administrator 5=Head Admin
-- 6=Super Admin 7=Global Admin 8=Anticheat 9=Developer 10=Dep.Staff
-- 11=Dep.Chief Curator 12=Curator 13=Chief Curator 14=Staff Leader
-- 15=Chief Staff Leader 16=Глава Проекта
P11FW.PermLevel = {
    warn    = 2, -- Helper
    mute    = 2, -- Helper
    arrest  = 3, -- Moderator (арест и рабство)
    kick    = 3, -- Moderator
    heal    = 4, -- Administrator (быстрые действия: лечить/возродить/тп/заморозить/убить)
    ban     = 4, -- Administrator
    unban   = 6, -- Super Administrator
}

-- Лимиты СРОКОВ в МИНУТАХ по уровню ранга. 0 = безлимит (включая перму).
-- Читается сверху вниз: своего уровня в таблице может не быть — берём ближайший снизу.
P11FW.TimeLimits = {
    mute = {  -- Helper 30м … Curator 2сут … Chief Staff Leader безлимит
        [2] = 30,       [3] = 240,      [4] = 720,      [5] = 1440,
        [6] = 10080,    [8] = 20160,    [10] = 43200,   [12] = 172800,
        [15] = 0,
    },
    arrest = { -- Moderator 1ч … Developer 3д … Chief Staff Leader безлимит
        [3] = 60,       [4] = 180,      [5] = 1440,     [6] = 4320,
        [7] = 10080,    [9] = 43200,    [12] = 86400,   [15] = 0,
    },
    ban = {    -- Administrator 3д … Global Admin 70д … Deputy Staff 300д … Staff Leader 2года … Chief Staff Leader НАВСЕГДА
        [4] = 4320,     [5] = 10080,    [6] = 43200,    [7] = 100800,
        [8] = 144000,   [9] = 432000,   [10] = 432000,  [11] = 518400,
        [14] = 1051200, [15] = 0,
    },
}

--- v4.8.3: ТАБЕЛЬ О РАНГАХ — читаемая матрица прав (одна точка
--- правды): C-меню «📜 Права» и подсказки админки берут строки отсюда.
--- rank — таблица из P11FW.Ranks ({id, name, level, wl, fx}).
local function LimitText(level, kind)
    local t = P11FW.TimeLimits and P11FW.TimeLimits[kind]
    if not t then return "∞" end
    for l = math.min(level, 16), 0, -1 do
        local v = t[l]
        if v == 0 then return "∞ (включая перманент)" end
        if v then
            if v >= 1440 and v % 1440 == 0 then return (v / 1440) .. " сут" end
            if v >= 60 and v % 60 == 0 then return (v / 60) .. " ч" end
            return v .. " мин"
        end
    end
    return "∞ (включая перманент)"
end

function P11FW.RankRightsInfo(rank)
    local lvl = (rank and rank.level) or 0
    local out = {}
    if lvl <= 0 then
        return { "игра в составе персонала (F4 — должности, TAB — состав)",
                 "жалобы админам: /report <текст>, окно /репорты",
                 "своё время службы: p11_playtime в консоли" }
    end
    if rank and rank.id == "vip" then
        out[#out + 1] = "💎 VIP: должности 💎 VIP-СЛУЖБА в F4"
    end
    if rank and rank.wl then
        out[#out + 1] = "🔒 вайтлист: выдача допусков на закрытые должности"
    end
    if lvl >= 2 then
        out[#out + 1] = "мут до " .. LimitText(lvl, "mute")
        out[#out + 1] = "варн игрокам (вкладка МОДЕРАЦИЯ)"
        out[#out + 1] = "окно репортов /репорты: принять, тп к жалобщику, закрыть"
    end
    if lvl >= 3 then
        out[#out + 1] = "арест/рабство до " .. LimitText(lvl, "arrest")
        out[#out + 1] = "кик игроков"
    end
    if lvl >= 4 then
        out[#out + 1] = "бан до " .. LimitText(lvl, "ban")
        out[#out + 1] = "быстрые действия: /heal /tp /goto /bring /return /заморозка"
    end
    if lvl >= 5 then
        out[#out + 1] = "казна: выдача денег !дать <ник> <сумма>"
    end
    if lvl >= 6 then
        out[#out + 1] = "разбан (вкладка МОДЕРАЦИЯ)"
    end
    if lvl >= 9 then
        out[#out + 1] = "Q-меню движка (спавнменю, инструменты)"
    end
    if lvl >= ((P11FW.Config and P11FW.Config.RankManageLevel) or 12) then
        out[#out + 1] = "выдача и снятие рангов НИЖЕ СВОЕГО (вкладка АДМИНКИ, p11_rank)"
    end
    if lvl >= 16 then
        out[#out + 1] = "ВСЁ: серверные команды p11_*/polus_* (замок p11_cmdlock)"
        out[#out + 1] = "перманентные наказания, ранг может дать до 15-го"
    end
    if #out == 0 then
        out[1] = "базовый ранг без модераторских прав"
    end
    return out
end

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
    -- v4.8.0: был клэмп 0..9 — ранг 10..16 (включая самого Главу) получал
    -- лимит Девелопера и НЕ МОГ выдать постоянный бан, хотя таблица
    -- TimeLimits такие сроки предусматривает. Клэмпим по верх школы — 16.
    local lvl = math.Clamp(P11FW.GetRankLevel(ply), 0, 16)
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
    -- v4.8.0: раньше «mine >= 9 → theirs < 9» не пускало даже Главу
    -- наказывать свой штаб (10..15) — чиним в соответствии с описанием.
    if mine >= 16 then return theirs < 16 end -- Глава: всех, кроме других Глав
    if mine >= 9 then return theirs < 9 end   -- штаб не трогает друг друга
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
