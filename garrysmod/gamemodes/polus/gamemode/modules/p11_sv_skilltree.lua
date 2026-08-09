-- ============================================================
--  ПОЛЮС-11 — ДРЕВО СЛУЖБЫ: уровень, три пути, откат (server)
--  v4.21.0 «ДРЕВО». Заявка владельца (дословно, расшифровка):
--  «система древо навыков и прокачки; теперь чтобы получить
--   профы надо НЕ ДЕНЬГИ, а УРОВЕНЬ, который получаешь за
--   выполнение задач смены и другие вещи (подробнее придумай
--   сам); потом в C-меню открываешь древо навыков фракции и
--   идёшь по 3 путям, открывая какую-то роль, а какую-то уже
--   НЕ сможешь открыть, если пошёл по другому пути; за
--   100.000₽ можно откатить древо прокачки проф и пойти по
--   другому пути, СОХРАНИВ СВОЙ ОПЫТ, и протестить другие
--   профы; древо доступно фракциям РККА и УЧЁНЫЕ, пока что —
--   может быть, будут и другие; данная механика НЕ РАБОТАЕТ
--   с Staff Leader и выше».
--
--  КАК ЖИВЁТ:
--   • УРОВЕНЬ СЛУЖБЫ (0..10) — из опыта за штатные дела: цепь
--     TaskEvent (та же труба, что задачи/контракты):
--     закрытый наряд +50, сдача улики +30, груз снабжения +30,
--     анализ крови/арест +25, лечение/взятие должности +20,
--     крафт/приказ +15, кухня/уборка/взятие
--     контракта +10, рация/обыск +5, покупка в ларьке +3,
--     урон по Нечто +1..10 за залп;
--   • ДРЕВА: РККА и УЧЁНЫЕ (остальные фракции — «позже», старые
--     правила вайтлиста/стажа у них не тронуты). У каждого —
--     БАЗОВАЯ колея (открыта по уровню сама, без выбора пути)
--     и ТРИ ПУТИ: первый открытый узел пути ВЫБИРАЕТ его —
--     два других закрываются навсегда (до отката);
--   • по пути идёшь СТРОГО сверху вниз, каждый узел требует
--     уровень; открытая ДОЛЖНОСТЬ берётся через F4 как обычно
--     (стаж/вайтлист/место — как раньше, дерево — ПОВЕРХ);
--   • ОТКАТ ветки фракции — 100 000₽: путь и узлы стираются,
--     ОПЫТ И УРОВЕНЬ СОХРАНЯЮТСЯ (тест других профов бесплатен
--     по опыту); текущую твою должность откат не трогает до
--     смены;
--   • ранг Staff Leader+ (14+): механика к ним НЕ ПРИМЕНЯЕТСЯ
--     (заявка) — должности для них без древесных ворот;
--   • перки-узлы (научная ветка «ПОЛЕВОЙ ПРОТОКОЛ»): +25% к
--     опыту за научные дела и разовая стипендия ЦНИИ;
--   • сейв polus11/skilltree.json, опыт клиенту — NWInt
--     P11_SkillXP, состояние веток — P11_TreeSync (JSON).
-- ============================================================

util.AddNetworkString("P11_TreeSync")
util.AddNetworkString("P11_TreeAct")

local FILE        = "polus11/skilltree.json"
local LEVEL_MAX   = 10
local RESET_PRICE = 100000

-- ============ ПОРОГИ УРОВНЕЙ (накопительно) ============
-- lvl n открывается при xp >= POLUS11.TreeXP[n]
POLUS11.TreeXP = { 0, 150, 400, 800, 1400, 2200, 3200, 4500, 6000, 8000 }

function POLUS11.TreeLevelOf(xp)
    xp = tonumber(xp) or 0
    local lvl = 0
    for i = 1, LEVEL_MAX do
        if xp >= POLUS11.TreeXP[i] then lvl = i else break end
    end
    return lvl
end

-- ============ ДЕРЕВЬЯ ============
--  base  — базовая колея (без пути; нужен только уровень)
--  paths — три ветки; perk = узел-перк (не должность)
POLUS11.TreeDefs = {
    rkka = {
        name = "РККА",
        base = {
            { id = "rk_nov",  job = "seed_rkka_novobranets", lvl = 0 },
            { id = "rk_post", job = "seed_rkka_postovoy",    lvl = 1 },
            { id = "rk_sold", job = "seed_rkka_soldat",      lvl = 2 },
        },
        paths = {
            shturm = { name = "ПУТЬ ШТУРМА", nodes = {
                { id = "rk_sht",  job = "seed_rkka_shturmovik",   lvl = 3 },
                { id = "rk_pul",  job = "seed_rkka_pulemetchik",  lvl = 5 },
                { id = "rk_let",  job = "seed_rkka_letchik",      lvl = 7 },
                { id = "rk_gpeh", job = "seed_rkka_generalpeh",   lvl = 9 },
            }},
            razved = { name = "ПУТЬ РАЗВЕДКИ", nodes = {
                { id = "rk_raz", job = "seed_rkka_razvedchik", lvl = 3 },
                { id = "rk_kom", job = "seed_rkka_komissar",   lvl = 6 },
                { id = "rk_gen", job = "seed_rkka_general",    lvl = 9 },
            }},
            med = { name = "ПУТЬ МЕДСЛУЖБЫ", nodes = {
                { id = "rk_ms", job = "seed_rkka_medsestra", lvl = 3 },
                { id = "rk_mg", job = "seed_rkka_medglav",   lvl = 6 },
            }},
        },
    },
    science = {
        name = "УЧЁНЫЕ",
        base = {
            { id = "sc_lab", job = "seed_sci_laborant", lvl = 0 },
            { id = "sc_uch", job = "seed_sci_ucheniy",  lvl = 1 },
        },
        paths = {
            bio = { name = "ПУТЬ БИОХИМИИ", nodes = {
                { id = "sc_bio", job = "seed_sci_biohim",   lvl = 2 },
                { id = "sc_soz", job = "seed_sci_sozdatel", lvl = 6 },
            }},
            upr = { name = "ПУТЬ РУКОВОДСТВА", nodes = {
                { id = "sc_ved", job = "seed_sci_vedushiy",  lvl = 3 },
                { id = "sc_men", job = "seed_sci_menedzher", lvl = 5 },
            }},
            pole = { name = "ПОЛЕВОЙ ПРОТОКОЛ", nodes = {
                { id = "sc_p1", perk = { name = "Полевой протокол", desc = "+25% к опыту службы за анализы крови" }, lvl = 2 },
                { id = "sc_p2", perk = { name = "Стипендия ЦНИИ",   desc = "разовая выплата 2 500₽ из гранта института — сразу на карту", money = 2500 }, lvl = 4 },
            }},
        },
    },
}

-- научные дела для перка sc_p1
local SCIENCE_KEYS = { blood_test = true } -- v4.22.1 «ВЕСЫ»: calibrate/gen_service из опыта вырезаны (заявка)

-- ============ ОПЫТ ЗА ДЕЛА ============
local XP_KEYS = {
    contract_done = 50, clue_turn = 30, haul = 30,
    blood_test = 25, arrest = 25,
    heal_player = 20, -- job_taken вырезан v4.22.0 «ОКОВЫ» (заявка: должность ≠ дело)
    craft_do = 15, rollcall = 15, -- calibrate/gen_service вырезаны v4.22.1 «ВЕСЫ» (заявка: тех. рутина ≠ служба)
    cook = 10, fed = 10, clean = 10, contract_take = 10,
    loot_find = 5, shop_buy = 3, -- radio вырезана v4.22.0 «ОКОВЫ» (заявка: болтовня ≠ дело)
}

-- ============ СОСТОЯНИЕ ============
-- [sid] = { xp = n, trees = { [fac] = { path = "", nodes = { [nodeId] = true } } } }
POLUS11.Tree = POLUS11.Tree or {}
local treeDirty = false

local function TreeSave()
    if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
    file.Write(FILE, util.TableToJSON(POLUS11.Tree, true) or "{}")
end
local function TreeLoad()
    local raw = file.Read(FILE, "DATA")
    if not raw then return end
    local ok, tbl = pcall(util.JSONToTable, raw)
    if ok and istable(tbl) then POLUS11.Tree = tbl end
end
hook.Add("InitPostEntity", "P11.TreeLoad", function() timer.Simple(1.9, TreeLoad) end)
hook.Add("PlayerDisconnected", "P11.TreeBye", function() TreeSave() end)
timer.Create("P11.TreeFlush", 20, 0, function()
    if treeDirty then treeDirty = false TreeSave() end
end)

local function TreeState(ply)
    local sid = ply:SteamID()
    local st = POLUS11.Tree[sid]
    if not st then
        st = { xp = 0, trees = {} }
        POLUS11.Tree[sid] = st
    end
    return st
end

local function BranchState(st, fac)
    st.trees[fac] = st.trees[fac] or { path = "", nodes = {} }
    return st.trees[fac]
end

-- ============ СИНХРОНИЗАЦИЯ ============
function POLUS11.TreeSync(ply)
    if not IsValid(ply) then return end
    local st = TreeState(ply)
    local out = { xp = math.floor(tonumber(st.xp) or 0), trees = {}, reset = RESET_PRICE }
    for fac in pairs(POLUS11.TreeDefs) do
        local b = st.trees[fac]
        out.trees[fac] = {
            path  = b and tostring(b.path or "") or "",
            nodes = (b and istable(b.nodes)) and b.nodes or {},
        }
    end
    ply:SetNWInt("P11_SkillXP", out.xp)
    net.Start("P11_TreeSync")
        net.WriteString(util.TableToJSON(out) or "{}")
    net.Send(ply)
end

hook.Add("PlayerInitialSpawn", "P11.TreeJoin", function(ply)
    timer.Simple(12, function()
        if IsValid(ply) then POLUS11.TreeSync(ply) end
    end)
end)

-- ============ ОПЫТ / УРОВЕНЬ ============
function POLUS11.TreeHasPerk(ply, perkId)
    if not IsValid(ply) then return false end
    local st = POLUS11.Tree[ply:SteamID()]
    if not st then return false end
    for _, b in pairs(st.trees or {}) do
        if istable(b.nodes) and b.nodes[perkId] then return true end
    end
    return false
end

function POLUS11.SkillLevel(ply)
    if not IsValid(ply) then return 0 end
    local st = POLUS11.Tree[ply:SteamID()]
    return POLUS11.TreeLevelOf(st and st.xp or 0)
end

function POLUS11.TreeXPAdd(ply, xp, why)
    if not (IsValid(ply) and ply:IsPlayer()) then return end
    xp = math.floor(tonumber(xp) or 0)
    if xp <= 0 then return end

    -- перк «Полевой протокол»: +25% за научные дела
    if why and SCIENCE_KEYS[why] and POLUS11.TreeHasPerk(ply, "sc_p1") then
        xp = math.floor(xp * 1.25)
    end

    local st = TreeState(ply)
    local before = POLUS11.TreeLevelOf(st.xp)
    st.xp = (tonumber(st.xp) or 0) + xp
    local after = POLUS11.TreeLevelOf(st.xp)
    treeDirty = true

    ply:SetNWInt("P11_SkillXP", st.xp)
    if after > before then
        ply:EmitSound("buttons/button15.wav", 70, 105)
        if after >= 9 then ply:EmitSound("ambient/alarms/warningbell1.wav", 55, 130) end
        POLUS11.Notify(ply, "⭐ УРОВЕНЬ СЛУЖБЫ: " .. after .. "! Новые ветви в ДРЕВЕ (C-меню → «⭐ ДРЕВО СЛУЖБЫ»).")
        POLUS11.Log("УРОВЕНЬ: " .. ply:Nick() .. " достиг " .. after .. " (опыт " .. math.floor(st.xp) .. ")")
    elseif math.random() < 0.16 then
        -- не на каждый чих, но чувство роста
        local need = (after < LEVEL_MAX) and (POLUS11.TreeXP[after + 1] - math.floor(st.xp)) or 0
        if need > 0 then
            POLUS11.Notify(ply, "Опыт службы +" .. xp .. " (" .. why .. "). До " .. (after + 1) .. " уровня: " .. need .. ".")
        end
    end
end

-- звено в цепи TaskEvent (грузимся поздно — доезжают и contract_*)
do
    local base = POLUS11.TaskEvent
    POLUS11.TaskEvent = function(ply, key, add)
        if base then base(ply, key, add) end
        if not IsValid(ply) or not ply:IsPlayer() then return end
        local xp = XP_KEYS[key]
        if xp then
            POLUS11.TreeXPAdd(ply, xp, key)
        elseif key == "damage_thing" then
            POLUS11.TreeXPAdd(ply, math.Clamp(math.floor((tonumber(add) or 1) / 50), 1, 10), key)
        end
    end
end

-- ============ ВОРОТА ДОЛЖНОСТЕЙ (зовёт fw_sv_jobs) ============
-- job в дереве? вернуть fac, node, inPath
local function TreeNodeLookup(jobId)
    for fac, def in pairs(POLUS11.TreeDefs) do
        for _, n in ipairs(def.base) do
            if n.job == jobId then return fac, n, false end
        end
        for _, pdef in pairs(def.paths) do
            for _, n in ipairs(pdef.nodes) do
                if n.job == jobId then return fac, n, true end
            end
        end
    end
    return nil
end

-- true или false+причина. Staff Leader+ (14): механика к ним НЕ применяется.
function POLUS11.SkillTreeJobOK(ply, jobId)
    if not IsValid(ply) then return true end
    local fac, node, inPath = TreeNodeLookup(tostring(jobId or ""))
    if not fac then return true end -- должность вне деревьев — старые правила
    if ply:IsListenServerHost() then return true end
    if P11FW.GetRankLevel and P11FW.GetRankLevel(ply) >= 14 then return true end

    local st = TreeState(ply)
    local lvl = POLUS11.TreeLevelOf(st.xp)
    local jobName = (P11FW.Jobs[jobId] and P11FW.Jobs[jobId].name) or jobId
    local def = POLUS11.TreeDefs[fac]

    if (tonumber(node.lvl) or 0) > lvl then
        return false, "«" .. jobName .. "» — нужен УРОВЕНЬ СЛУЖБЫ " .. node.lvl ..
            " (у тебя " .. lvl .. "). Качай: дела смены, наряды, анализы, груз. Древо: C-меню → «⭐ ДРЕВО СЛУЖБЫ»."
    end
    if not inPath then return true end -- базова колея: уровня хватило

    local b = BranchState(st, fac)
    if b.nodes[node.id] then return true end -- узел открыт

    return false, "«" .. jobName .. "» закрыта в ДРЕВЕ СЛУЖБЫ (" .. def.name ..
        "). Открой ветку: C-меню → «⭐ ДРЕВО СЛУЖБЫ» (C)."
end

-- ============ ОТКРЫТИЕ УЗЛА ============
local function TreeNodeById(fac, nodeId)
    local def = POLUS11.TreeDefs[fac]
    if not def then return nil end
    for pid, pdef in pairs(def.paths) do
        for i, n in ipairs(pdef.nodes) do
            if n.id == nodeId then return n, pid, pdef, i end
        end
    end
    return nil
end

function POLUS11.TreeUnlock(ply, fac, nodeId)
    fac, nodeId = tostring(fac or ""), tostring(nodeId or "")
    local def = POLUS11.TreeDefs[fac]
    local node, pid, pdef, idx = TreeNodeById(fac, nodeId)
    if not def or not node then return end

    if P11FW.GetRankLevel and P11FW.GetRankLevel(ply) >= 14 then
        POLUS11.Notify(ply, "Штабу (ранг 14+) древо не нужно — должности и так открыты.")
        return
    end

    local st = TreeState(ply)
    local b = BranchState(st, fac)
    local lvl = POLUS11.TreeLevelOf(st.xp)

    if b.nodes[node.id] then
        POLUS11.Notify(ply, "Узел уже открыт.")
        return
    end
    if lvl < (tonumber(node.lvl) or 0) then
        POLUS11.Notify(ply, "Рано: нужен уровень " .. node.lvl .. ", у тебя " .. lvl .. ".")
        ply:EmitSound("buttons/button10.wav", 60, 90)
        return
    end
    -- выбор пути: первый узел фиксирует ветку, остальные закрываются
    if b.path ~= "" and b.path ~= pid then
        local other = POLUS11.TreeDefs[fac].paths[b.path]
        POLUS11.Notify(ply, "Твой путь в «" .. def.name .. "» уже выбран: «" ..
            ((other and other.name) or b.path) .. "». Сменить ветку — откат за " .. RESET_PRICE .. "₽ (опыт сохранится).")
        ply:EmitSound("buttons/button10.wav", 60, 90)
        return
    end
    -- строго по лесенке
    if idx > 1 then
        local prev = pdef.nodes[idx - 1]
        if prev and not b.nodes[prev.id] then
            POLUS11.Notify(ply, "Сначала открой предыдущий узел ветки: «" ..
                (prev.job and (P11FW.Jobs[prev.job] and P11FW.Jobs[prev.job].name or prev.job) or (prev.perk and prev.perk.name) or "?") .. "».")
            ply:EmitSound("buttons/button10.wav", 60, 90)
            return
        end
    end

    if b.path == "" then
        b.path = pid
        POLUS11.Notify(ply, "ПУТЬ ВЫБРАН: «" .. pdef.name .. "» (" .. def.name ..
            "). Две другие ветки закрылись. Откат — " .. RESET_PRICE .. "₽.")
        POLUS11.Log("ДРЕВО: " .. ply:Nick() .. " выбрал путь «" .. pid .. "» (" .. fac .. ")")
    end
    b.nodes[node.id] = true
    treeDirty = true

    if node.job then
        local jn = (P11FW.Jobs[node.job] and P11FW.Jobs[node.job].name) or node.job
        POLUS11.Notify(ply, "⭐ ВЕТВЬ ОТКРЫТА: должность «" .. jn .. "» теперь доступна (F4). Дальше по пути — качай уровень.")
        POLUS11.Log("ДРЕВО: " .. ply:Nick() .. " открыл «" .. jn .. "» (" .. fac .. "/" .. pid .. ")")
    elseif node.perk then
        if node.perk.money and POLUS11.AddMoney then
            POLUS11.AddMoney(ply, node.perk.money, "перк ветки: " .. node.perk.name)
        end
        POLUS11.Notify(ply, "⭐ ПЕРК ОТКРЫТ: «" .. node.perk.name .. "» — " .. (node.perk.desc or "") .. ".")
        POLUS11.Log("ДРЕВО: " .. ply:Nick() .. " открыл перк «" .. node.perk.name .. "» (" .. fac .. ")")
    end
    ply:EmitSound("buttons/button15.wav", 65, 108)
    POLUS11.TreeSync(ply)
end

-- ============ ОТКАТ ВЕТКИ (100 000₽, опыт сохраняется) ============
function POLUS11.TreeReset(ply, fac)
    fac = tostring(fac or "")
    local def = POLUS11.TreeDefs[fac]
    if not def then return end
    local st = TreeState(ply)
    local b = st.trees[fac]
    if not b or (b.path == "" and (not b.nodes or next(b.nodes) == nil)) then
        POLUS11.Notify(ply, "В «" .. def.name .. "» ещё ничего не открыто — и откатывать нечего.")
        return
    end
    if not (POLUS11.TakeMoney and POLUS11.TakeMoney(ply, RESET_PRICE, "откат древа: " .. def.name)) then
        POLUS11.Notify(ply, "Откат стоит " .. RESET_PRICE .. "₽, у тебя " ..
            (POLUS11.GetMoney and POLUS11.GetMoney(ply) or 0) .. "₽.")
        ply:EmitSound("buttons/button10.wav", 60, 90)
        return
    end
    st.trees[fac] = { path = "", nodes = {} }
    treeDirty = true
    POLUS11.Notify(ply, "ДРЕВО «" .. def.name .. "» ОТКАЧЕНО за " .. RESET_PRICE ..
        "₽. Опыт и уровень СОХРАНЕНЫ — пробуй другой путь. (Текущая должность остаётся до смены.)")
    POLUS11.Log("ДРЕВО ОТКАТ: " .. ply:Nick() .. " сбросил «" .. def.name .. "» за " .. RESET_PRICE .. "₽")
    ply:EmitSound("ambient/alarms/warningbell1.wav", 55, 120)
    POLUS11.TreeSync(ply)
end

-- ============ NET ============
net.Receive("P11_TreeAct", function(_, ply)
    if not IsValid(ply) then return end
    ply.P11_TreeNext = ply.P11_TreeNext or 0
    if CurTime() < ply.P11_TreeNext then return end
    ply.P11_TreeNext = CurTime() + 0.4

    local act = net.ReadUInt(4)
    if act == 9 then
        POLUS11.TreeSync(ply)
        return
    end
    local fac = string.sub(net.ReadString() or "", 1, 10)
    if act == 1 then
        local nodeId = string.sub(net.ReadString() or "", 1, 16)
        POLUS11.TreeUnlock(ply, fac, nodeId)
    elseif act == 2 then
        POLUS11.TreeReset(ply, fac)
    end
end)

print("[POLUS-11] ДРЕВО СЛУЖБЫ v4.21.0: уровень за дела (0..10), РККА+УЧЁНЫЕ по 3 пути, откат " ..
    RESET_PRICE .. "₽ сохраняет опыт, ранг 14+ вне механики")
