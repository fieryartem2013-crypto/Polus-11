-- ============================================================
--  ПОЛЮС-11 — КОНТЕКСТНОЕ МЕНЮ ПО Е (server) v5.8.21 (autorun)
--  Смотришь на игрока + зажал Е (0.7 сек) → меню действий:
--    💰 Передать деньги (из своего кошелька, макс 50 000)
--    👋 Подозвать (жест «Сюда!»)
--    📄 Показать документы (твоё удостоверение — ему в окно)
--    💨 Толкнуть (лёгкий пинок)
--    ⭐ Выдать опыт службы (древо) — ТОЛЬКО командиры/генералы,
--       макс 1000 за раз
--    🔫 Случайное оружие из твоего багажа — ему в руки
--  Все действия: дистанция ~250, оба живы. Старые файлы не трогаем.
--  Также спавнит энтити polus_p11_emenu (клиентское меню).
-- ============================================================

util.AddNetworkString("P11_EMenu")
util.AddNetworkString("P11_EMenu_Emote") -- сервер → клиент: сыграть жест

local DIST = 250

-- ============ ПРОВЕРКИ ============
local function Near(ply, target)
    if not IsValid(ply) or not IsValid(target) then return false end
    if not ply:Alive() or not target:Alive() then return false end
    return ply:GetPos():DistToSqr(target:GetPos()) <= DIST * DIST
end

-- командир/генерал фракции (может выдавать опыт)
local function IsCommander(ply)
    if not IsValid(ply) then return false end
    -- ранг Head Admin+ тоже умеет
    if P11FW.GetRankLevel and P11FW.GetRankLevel(ply) >= 5 then return true end
    local jid = P11FW.GetJobId and P11FW.GetJobId(ply)
    local job = jid and P11FW.Jobs and P11FW.Jobs[jid]
    if not job then return false end
    if job.command == true then return true end
    -- командир ГОК (вайтлист) — тоже командная должность
    if job.id == "seed_un_komandir" then return true end
    return false
end

-- отметить Командира ГОК как командира (runtime, файл сида не трогаем)
local function MarkUNCommanders()
    local j = P11FW.Jobs and P11FW.Jobs["seed_un_komandir"]
    if j then j.command = true end
end

-- ============ ПЕРЕДАЧА ДЕНЕГ ============
local function GiveMoney(ply, target, amt)
    if not Near(ply, target) then return "Слишком далеко — подойди ближе." end
    amt = math.floor(tonumber(amt) or 0)
    if amt < 1 or amt > 50000 then return "Сумма от 1 до 50 000₽." end
    local have = POLUS11.GetMoney and POLUS11.GetMoney(ply) or 0
    if have < amt then return "У тебя столько нет: " .. have .. "₽." end
    POLUS11.AddMoney(ply, -amt, "передал " .. target:Nick())
    POLUS11.AddMoney(target, amt, "получил от " .. ply:Nick())
    POLUS11.Notify(ply, "Передал " .. amt .. "₽ → " .. target:Nick())
    POLUS11.Notify(target, ply:Nick() .. " передал тебе " .. amt .. "₽")
    POLUS11.Log("E-меню: " .. ply:Nick() .. " передал " .. amt .. "₽ → " .. target:Nick())
    return nil
end

-- ============ ПОКАЗАТЬ ДОКУМЕНТЫ ============
local function ShowDocs(ply, target)
    if not Near(ply, target) then return "Слишком далеко." end
    -- собрать удостоверение действующего и показать ЦЕЛИ (тот, на кого смотрим)
    local name = ply:GetNWString("P11_FakeNick", "")
    if name == "" then name = ply:GetNWString("P11_CharName", "") end
    if name == "" then name = ply:Nick() end
    local jobTab = nil
    if P11FW.GetJob then jobTab = P11FW.GetJob(ply) end
    local jobName = (jobTab and jobTab.name) or "без назначения"
    local facName = "ПЕРСОНАЛ СТАНЦИИ"
    if P11FW.CategoryList and jobTab then
        local cid = jobTab.faction or jobTab.category
        for _, c in ipairs(P11FW.CategoryList) do
            if c.id == cid then facName = c.name break end
        end
    end
    local code = ply:GetNWString("P11_DocCode", "")
    if code == "" and DocCodeOf then code = DocCodeOf(ply) end
    net.Start("P11_DocShow")
        net.WriteString(name)
        net.WriteString(jobName)
        net.WriteString(code)
        net.WriteString(os.date("%d.%m.%Y %H:%M"))
        net.WriteString(facName)
    net.Send(target)
    POLUS11.Notify(ply, "Показал документы → " .. target:Nick())
    return nil
end

-- ============ ТОЛКНУТЬ ============
local function PushPlayer(ply, target)
    if not Near(ply, target) then return "Слишком далеко." end
    local dir = (target:GetPos() - ply:GetPos())
    dir.z = 0
    if dir:LengthSqr() < 1 then dir = target:GetForward() end
    dir:Normalize()
    local v = target:GetVelocity() + dir * 240 + Vector(0, 0, 60)
    target:SetVelocity(v)
    target:EmitSound("physics/flesh/flesh_impact_hard1.wav", 60, 100)
    if POLUS11.Log then POLUS11.Log("E-меню: " .. ply:Nick() .. " толкнул " .. target:Nick()) end
    return nil
end

-- ============ ВЫДАТЬ ОПЫТ (древо службы) ============
local function GiveXP(ply, target, amt)
    if not IsCommander(ply) then return "Выдавать опыт могут командиры и генералы фракций." end
    if not Near(ply, target) then return "Слишком далеко." end
    amt = math.floor(tonumber(amt) or 0)
    if amt < 1 or amt > 1000 then return "Опыт от 1 до 1000 за раз." end
    -- тот же путь, что у админской выдачи (поле P11_XPAct mode 1)
    local sid = target:SteamID()
    POLUS11.Tree = POLUS11.Tree or {}
    local st = POLUS11.Tree[sid] or { xp = 0, trees = {} }
    st.xp = (tonumber(st.xp) or 0) + amt
    POLUS11.Tree[sid] = st
    if file.IsDir and not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
    file.Write("polus11/skilltree.json", util.TableToJSON(POLUS11.Tree, true) or "{}")
    if POLUS11.TreeSync then POLUS11.TreeSync(target) end
    POLUS11.Notify(target, "Опыт службы +" .. amt .. " (выдал командир " .. ply:Nick() .. ")")
    POLUS11.Notify(ply, "Выдал опыт +" .. amt .. " → " .. target:Nick())
    if POLUS11.Log then POLUS11.Log("E-меню ОПЫТ: " .. ply:Nick() .. " → " .. target:Nick() .. " +" .. amt) end
    return nil
end

-- ============ СЛУЧАЙНОЕ ОРУЖИЕ ИЗ БАГАЖА ============
local function GiveRandomGun(ply, target)
    if not Near(ply, target) then return "Слишком далеко." end
    local inv = POLUS11.InvOf and POLUS11.InvOf(ply)
    if not inv or not inv.items then return "У тебя пусто в багаже." end
    -- собрать предметы-оружие (есть class и он существует на сервере)
    local guns = {}
    for id, n in pairs(inv.items) do
        if n > 0 then
            local it = POLUS11.Items and POLUS11.Items[id]
            if it and isstring(it.class) and it.ent ~= true and POLUS11.InvCanUse and POLUS11.InvCanUse(it.class) then
                guns[#guns + 1] = id
            end
        end
    end
    if #guns == 0 then return "В багаже нет оружия, которое можно отдать." end
    local id = guns[math.random(#guns)]
    local it = POLUS11.Items[id]
    inv.items[id] = inv.items[id] - 1
    if inv.items[id] <= 0 then inv.items[id] = nil end
    if POLUS11.InvSync then POLUS11.InvSync(ply) end
    if POLUS11.InvSync then POLUS11.InvSync(target) end
    target:Give(it.class)
    POLUS11.Notify(ply, "Отдал из багажа: «" .. it.name .. "» → " .. target:Nick())
    POLUS11.Notify(target, ply:Nick() .. " отдал тебе из багажа: «" .. it.name .. "»")
    if POLUS11.Log then POLUS11.Log("E-меню ОРУЖИЕ: " .. ply:Nick() .. " → " .. target:Nick() .. " «" .. it.name .. "»") end
    return nil
end

-- ============ СЕТЬ ============
net.Receive("P11_EMenu", function(len, ply)
    if not IsValid(ply) then return end
    local op = net.ReadString()
    local target = net.ReadEntity()
    if not IsValid(target) or not target:IsPlayer() then return end
    if target == ply then return end
    ply.P11_EMenuNext = ply.P11_EMenuNext or 0
    if CurTime() < ply.P11_EMenuNext then return end
    ply.P11_EMenuNext = CurTime() + 0.6

    local err = nil
    if op == "money" then
        err = GiveMoney(ply, target, net.ReadUInt(20))
    elseif op == "docs" then
        err = ShowDocs(ply, target)
    elseif op == "push" then
        err = PushPlayer(ply, target)
    elseif op == "xp" then
        err = GiveXP(ply, target, net.ReadUInt(20))
    elseif op == "gun" then
        err = GiveRandomGun(ply, target)
    end
    if err then POLUS11.Notify(ply, err) end
end)

-- подозвать: сервер просит клиента сыграть жест «Сюда!» (ид 5)
net.Receive("P11_EMenu_Beckon", function(len, ply)
    if not IsValid(ply) then return end
    net.Start("P11_EMenu_Emote")
        net.WriteUInt(5, 4) -- «Сюда!»
    net.Send(ply)
end)

-- ============ СПАВН ЭНТИТИ (клиентское меню) ============
local function SpawnMenu()
    if ents.FindByClass("polus_p11_emenu")[1] then return end
    local e = ents.Create("polus_p11_emenu")
    if IsValid(e) then
        e:SetPos(Vector(0, 0, -20000))
        e:Spawn()
    end
end

hook.Add("InitPostEntity", "P11.EMenu.Start", function()
    timer.Simple(1, function()
        MarkUNCommanders()
        SpawnMenu()
    end)
end)
hook.Add("PostCleanupMap", "P11.EMenu.Map", function()
    timer.Simple(3, SpawnMenu)
end)

print("[POLUS-11] E-МЕНЮ v5.8.21: смотри на игрока + удержать Е → действия (деньги/жест/документы/толчок/опыт/оружие)")
