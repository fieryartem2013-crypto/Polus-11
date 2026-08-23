-- ============================================================
--  ПОЛЮС-11 — КОНФИГ ВЫДАЧИ РАНГОВ v5.8.28 (НОВЫЙ ФАЙЛ)
--  Список разрешённых рангов для Staff Leader живёт ЗДЕСЬ
--  (и может быть перезаписан data/polus_framework/rank_grant.json
--  на сервере). Старые fw_sh_ranks / fw_sv_ranks НЕ трогаем.
-- ============================================================

P11FW = P11FW or {}

-- id рангов, которые Staff Leader НИКОГДА не выдаёт (жёсткий запрет)
P11FW.RankGrantHardDeny = {
    admin = true, -- «Administrator» — только Главный админ и выше
}

-- дефолтный белый список (явный, как требует ТЗ)
-- править можно тут ИЛИ файлом data/polus_framework/rank_grant.json
P11FW.RankGrantAllow = P11FW.RankGrantAllow or {
    staff_leader = {
        "user",
        "vip",
        "faction_officer",
        "faction_leader",
        "helper",
        "moderator",
        -- Administrator (admin) СОЗНАТЕЛЬНО отсутствует
    },
}

function P11FW.RankGrantAllowed(granterId, targetId)
    granterId = tostring(granterId or "")
    targetId  = tostring(targetId or "")
    if targetId == "" then return false, "нет такого ранга" end

    -- жёсткий запрет «Администратор» для Staff Leader
    if granterId == "staff_leader" and P11FW.RankGrantHardDeny[targetId] then
        return false, "У вас нет прав для выдачи этого ранга"
    end

    local list = P11FW.RankGrantAllow and P11FW.RankGrantAllow[granterId]
    if not list then
        return true -- у ранга нет отдельного списка — действует старое правило «ниже себя»
    end
    for _, id in ipairs(list) do
        if id == targetId then
            if P11FW.RankGrantHardDeny[targetId] and granterId == "staff_leader" then
                return false, "У вас нет прав для выдачи этого ранга"
            end
            return true
        end
    end
    return false, "У вас нет прав для выдачи этого ранга"
end
