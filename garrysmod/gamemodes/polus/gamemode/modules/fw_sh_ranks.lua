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
    { id = "curator",    name = "Куратор",         level = 5, color = Color(225, 120, 110) },
    { id = "superadmin", name = "Суперадмин",      level = 6, color = Color(240, 100, 100) },
    { id = "founder",    name = "Основатель",      level = 7, color = Color(255, 90, 90) },
    { id = "sozdatel",   name = "Создатель",       level = 8, color = Color(255, 150, 80) },
    { id = "glava",      name = "Глава Полюса-11", level = 9, color = Color(255, 215, 90) },
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

--- Может ли ply выдавать ранги (и не выше себя)?
function P11FW.CanManageRank(ply, targetLevel)
    if not IsValid(ply) then return false end
    local need = P11FW.Config and P11FW.Config.RankManageLevel or 5
    local my = P11FW.GetRankLevel(ply)
    if my < need then return false end
    if targetLevel and targetLevel >= my then return false end
    return true
end
