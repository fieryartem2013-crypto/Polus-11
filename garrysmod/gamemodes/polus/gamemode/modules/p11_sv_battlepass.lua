-- ============================================================
--  ПОЛЮС-11 — БАТЛ-ПАСС «БИТВА ВРЕМЕНИ» (server) v5.2.0
--  Ивентовый сезонный пропуск: делай дела станции — копи XP,
--  открывай уровни 1..20 и ЗАБИРАЙ награды в меню F5.
--  Награды: рубли, ПОЛЮС-ФЛЮКС, СЕКРЕТНЫЙ АРСЕНАЛ РЕЙХА
--  (StG-44 / MP-40 / Gewehr 43 / Luger P08 — трофеи Осовца),
--  на 20 уровне — VIP + 50 000₽ + медаль «Легенда Полюса».
--  Хранение: data/polus11/battlepass.json
-- ============================================================

util.AddNetworkString("P11_BP_Sync")
util.AddNetworkString("P11_BP_Claim")
util.AddNetworkString("P11_BP_Wear")   -- v5.2.1: гардероб (надеть/снять модель)

local BP_FILE = "polus11/battlepass.json"
POLUS11.BP = POLUS11.BP or { data = {} }   -- [sid64] = { xp, claimed={} }

-- ============ УРОВНИ И НАГРАДЫ ============

local BP_MAX_LVL = 20
local function BPNeed(lvl)
    return 100 + (lvl - 1) * 50   -- 100, 150, 200, ...
end

-- награда: kind = money | flux | item | grand
local BP_REWARDS = {
    { lvl = 1,  kind = "money", amt = 3000,  name = "+3 000₽" },
    { lvl = 2,  kind = "flux",  amt = 50,    name = "+50 ПОЛЮС-ФЛЮКС" },
    { lvl = 3,  kind = "item",  id = "p08",  name = "Luger P08 «Парабеллум»" },
    { lvl = 4,  kind = "money", amt = 4000,  name = "+4 000₽" },
    { lvl = 5,  kind = "item",  id = "mp40", name = "MP-40 «Машиненпистоле»" },
    { lvl = 6,  kind = "flux",  amt = 75,    name = "+75 ПОЛЮС-ФЛЮКС" },
    { lvl = 7,  kind = "money", amt = 5000,  name = "+5 000₽" },
    { lvl = 8,  kind = "flux",  amt = 100,   name = "+100 ПОЛЮС-ФЛЮКС" },
    { lvl = 9,  kind = "money", amt = 6000,  name = "+6 000₽" },
    { lvl = 10, kind = "item",  id = "g43",  name = "Gewehr 43" },
    { lvl = 11, kind = "money", amt = 7000,  name = "+7 000₽" },
    { lvl = 12, kind = "flux",  amt = 120,   name = "+120 ПОЛЮС-ФЛЮКС" },
    { lvl = 13, kind = "money", amt = 8000,  name = "+8 000₽" },
    { lvl = 14, kind = "flux",  amt = 150,   name = "+150 ПОЛЮС-ФЛЮКС" },
    { lvl = 15, kind = "item",  id = "stg44",name = "StG-44 «Штурмгевер»" },
    { lvl = 16, kind = "money", amt = 10000, name = "+10 000₽" },
    { lvl = 17, kind = "flux",  amt = 180,   name = "+180 ПОЛЮС-ФЛЮКС" },
    { lvl = 18, kind = "money", amt = 12000, name = "+12 000₽" },
    { lvl = 19, kind = "flux",  amt = 200,   name = "+200 ПОЛЮС-ФЛЮКС" },
    { lvl = 20, kind = "grand", name = "VIP-статус + 50 000₽ + медаль «Легенда Полюса»" },
}

local function BPRewardFor(lvl)
    for _, r in ipairs(BP_REWARDS) do
        if r.lvl == lvl then return r end
    end
    return nil
end

-- ============ ХРАНЕНИЕ ============

local function BPLoad()
    local raw = file.Read(BP_FILE, "DATA")
    if not raw then return end
    local ok, tbl = pcall(util.JSONToTable, raw)
    if ok and istable(tbl) then POLUS11.BP.data = tbl end
end

local bpDirty = false
local function BPSave()
    bpDirty = false
    if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
    file.Write(BP_FILE, util.TableToJSON(POLUS11.BP.data, true) or "{}")
end

hook.Add("InitPostEntity", "P11.BPLoad", function()
    timer.Simple(1.5, BPLoad)
end)
hook.Add("PlayerDisconnected", "P11.BPBye", function() BPSave() end)
timer.Create("P11.BPFlush", 20, 0, function()
    if bpDirty then BPSave() end
end)

local function BPOf(ply)
    local sid = ply:SteamID64()
    POLUS11.BP.data[sid] = POLUS11.BP.data[sid] or { xp = 0, claimed = {} }
    local d = POLUS11.BP.data[sid]
    d.claimed = d.claimed or {}
    return d
end

-- ============ XP ============

local function BPLvlOf(xp)
    local lvl, left = 1, xp
    while lvl < BP_MAX_LVL do
        local need = BPNeed(lvl)
        if left < need then break end
        left = left - need
        lvl = lvl + 1
    end
    return lvl, left
end

function POLUS11.BPAdd(ply, amt, why)
    if not IsValid(ply) or amt <= 0 then return end
    local d = BPOf(ply)
    local oldLvl = BPLvlOf(d.xp)
    d.xp = d.xp + amt
    bpDirty = true
    local newLvl = BPLvlOf(d.xp)
    if newLvl > oldLvl then
        POLUS11.Notify(ply, "⚡ БАТЛ-ПАСС: уровень " .. newLvl .. "! Награда ждёт в меню [F5].")
        ply:EmitSound("buttons/button15.wav", 70, 105)
        POLUS11.Log("БАТЛ-ПАСС: " .. ply:Nick() .. " → уровень " .. newLvl .. " (" .. why .. ")")
    end
    POLUS11.BPSync(ply)
end

-- звено в цепи TaskEvent
do
    local base = POLUS11.TaskEvent
    POLUS11.TaskEvent = function(ply, key, add)
        if base then base(ply, key, add) end
        if not IsValid(ply) then return end
        local XP = {
            blood_test = 15, craft_do = 10, heal_player = 12,
            contract_done = 25, rollcall = 8, fed = 5, haul = 8,
            loot_find = 5, shop_buy = 3, calibrate = 6, clean = 5,
            gen_service = 8, clue_turn = 6,
        }
        local v = XP[key]
        if v then POLUS11.BPAdd(ply, v, key) end
        if key == "damage_thing" then
            POLUS11.BPAdd(ply, math.Clamp(math.floor((tonumber(add) or 1) / 50), 1, 10), "урон Нечто")
        end
    end
end

-- фраги врагов капают XP (в операции — больше)
hook.Add("PlayerDeath", "P11.BPFrag", function(vic, inf, att)
    if not (IsValid(att) and att:IsPlayer() and IsValid(vic)) then return end
    if att == vic then return end
    if POLUS11.Op and POLUS11.Op.phase == "battle" and POLUS11.Op.side and POLUS11.Op.side[att] and POLUS11.Op.side[vic] then
        POLUS11.BPAdd(att, 15, "фраг в операции")
    else
        POLUS11.BPAdd(att, 5, "фраг")
    end
end)

-- ============ ВЫДАЧА НАГРАДЫ ============

local function BPGrant(ply, r)
    if r.kind == "money" then
        if POLUS11.AddMoney then POLUS11.AddMoney(ply, r.amt, "Батл-пасс «Битва Времени»") end
    elseif r.kind == "flux" then
        if POLUS11.FluxAdd then POLUS11.FluxAdd(ply, r.amt, "Батл-пасс «Битва Времени»") end
    elseif r.kind == "item" then
        local it = POLUS11.Items and POLUS11.Items[r.id]
        if it then
            local data = POLUS11.InvOf and POLUS11.InvOf(ply)
            if data then
                data.items[r.id] = (data.items[r.id] or 0) + 1
                if POLUS11.InvSync then POLUS11.InvSync(ply) end
            end
        end
    elseif r.kind == "model" then
        -- v5.2.1: разблокировка модели для ГАРДЕРОБА (F5 → ГАРДЕРОБ → НАДЕТЬ)
        local d = BPOf(ply)
        d.models[r.id] = true
        bpDirty = true
    elseif r.kind == "grand" then
        -- VIP-статус
        if P11FW.SetRank then P11FW.SetRank(ply, "vip", ply) end
        -- 100 000₽ (v5.2.1: было 50к)
        if POLUS11.AddMoney then POLUS11.AddMoney(ply, 100000, "Батл-пасс: ГЛАВНЫЙ ПРИЗ") end
        -- 500 ПФ (v5.2.1)
        if POLUS11.FluxAdd then POLUS11.FluxAdd(ply, 500, "Батл-пасс: ГЛАВНЫЙ ПРИЗ") end
        -- v5.2.1: модель «Мёртвый Офицер Осовца» в гардероб
        local dG = BPOf(ply)
        dG.models["models/hts/comradebear/pm0v3/player/undeadarmy/infantry/co/m38_s1_skeleton.mdl"] = true
        -- медаль «Легенда Полюса» (прямо в реестр)
        if POLUS11.MedalDefs and POLUS11.Medals then
            local sid = ply:SteamID64()
            POLUS11.Medals[sid] = POLUS11.Medals[sid] or {}
            local has = false
            for _, m in ipairs(POLUS11.Medals[sid]) do
                if m.id == "legenda" then has = true break end
            end
            if not has then
                table.insert(POLUS11.Medals[sid], { id = "legenda", by = "БАТЛ-ПАСС", at = os.time() })
                if POLUS11.MedalPush then POLUS11.MedalPush(nil) end
            end
        end
    end
end

function POLUS11.BPClaim(ply, lvl)
    if not IsValid(ply) then return false end
    lvl = math.floor(tonumber(lvl) or 0)
    if lvl < 1 or lvl > BP_MAX_LVL then return false end
    local d = BPOf(ply)
    local curLvl = BPLvlOf(d.xp)
    if lvl > curLvl then
        POLUS11.Notify(ply, "Уровень " .. lvl .. " ещё не открыт — нужно больше XP.")
        return false
    end
    if d.claimed[lvl] then
        POLUS11.Notify(ply, "Награда уровня " .. lvl .. " уже забрана.")
        return false
    end
    local r = BPRewardFor(lvl)
    if not r then return false end
    BPGrant(ply, r)
    d.claimed[lvl] = true
    bpDirty = true
    POLUS11.Notify(ply, "🎖 Батл-пасс: награда «" .. r.name .. "» получена!")
    ply:EmitSound("items/ammo_pickup2.wav", 70, 105)
    POLUS11.BPSync(ply)
    POLUS11.Log("БАТЛ-ПАСС: " .. ply:Nick() .. " забрал уровень " .. lvl .. " («" .. r.name .. "»)")
    return true
end

-- ============ СИНК ============

function POLUS11.BPSync(ply)
    if not IsValid(ply) then return end
    local d = BPOf(ply)
    local lvl, left = BPLvlOf(d.xp)
    -- v5.2.1: разблокированные модели (для ГАРДЕРОБА)
    local ownedModels = {}
    for _, r in ipairs(BP_REWARDS) do
        if r.kind == "model" and d.models and d.models[r.id] then
            ownedModels[#ownedModels + 1] = { path = r.id, name = r.name }
        end
    end
    net.Start("P11_BP_Sync")
        net.WriteString(util.TableToJSON({
            lvl = lvl, xp = d.xp, left = left, need = BPNeed(lvl),
            max = BP_MAX_LVL, claimed = d.claimed or {},
            rewards = BP_REWARDS,
            models = ownedModels, wardrobe = d.wardrobe or "",
        }) or "{}")
    net.Send(ply)
end

hook.Add("PlayerInitialSpawn", "P11.BPJoin", function(ply)
    timer.Simple(6, function()
        if IsValid(ply) then POLUS11.BPSync(ply) end
    end)
end)

net.Receive("P11_BP_Claim", function(_, ply)
    if not IsValid(ply) then return end
    ply.P11_BPNext = ply.P11_BPNext or 0
    if CurTime() < ply.P11_BPNext then return end
    ply.P11_BPNext = CurTime() + 0.5
    local lvl = net.ReadUInt(8)
    POLUS11.BPClaim(ply, lvl)
end)

-- v5.2.1: ГАРДЕРОБ — надеть/снять разблокированную модель
net.Receive("P11_BP_Wear", function(_, ply)
    if not IsValid(ply) then return end
    ply.P11_BPNext = ply.P11_BPNext or 0
    if CurTime() < ply.P11_BPNext then return end
    ply.P11_BPNext = CurTime() + 0.5
    local path = string.sub(net.ReadString() or "", 1, 200)
    local d = BPOf(ply)

    if path == "" then
        -- снять: вернуть модель профы
        d.wardrobe = ""
        ply.P11_Wardrobe = nil
        local job = P11FW.GetJob and P11FW.GetJob(ply)
        local m = job and job.models and job.models[1] or nil
        if m and util.IsValidModel(m) then ply:SetModel(m) end
        bpDirty = true
        POLUS11.Notify(ply, "Гардероб: облик снят — снова форма должности.")
        POLUS11.BPSync(ply)
        return
    end

    if not d.models[path] then
        POLUS11.Notify(ply, "Эта модель не разблокирована — её дают уровни батл-пасса.")
        return
    end
    if not util.IsValidModel(path) then
        POLUS11.Notify(ply, "Модель не найдена — проверь, что пак моделей подключён.")
        return
    end
    -- не трогаем маскировки/активную тварь
    if ply.P11_Disguise then
        POLUS11.Notify(ply, "Сними маскировку, потом меняй облик.")
        return
    end
    if ply:GetNWBool("P11_InfActive", false) then
        POLUS11.Notify(ply, "Тело само выбирает свой облик.")
        return
    end
    d.wardrobe = path
    ply.P11_Wardrobe = path
    ply:SetModel(path)
    bpDirty = true
    POLUS11.Notify(ply, "🎭 Гардероб: облик надет! Он сохранится после респавна.")
    POLUS11.BPSync(ply)
end)

-- v5.2.1: восстановление облика после респавна (если нет маски/твари)
hook.Add("PlayerSpawn", "P11.BPWardrobeRestore", function(ply)
    if not IsValid(ply) then return end
    local d = POLUS11.BP.data and POLUS11.BP.data[ply:SteamID64()]
    local w = d and d.wardrobe or ""
    if w == "" then return end
    timer.Simple(0.8, function()
        if not IsValid(ply) or not ply:Alive() then return end
        if ply.P11_Disguise then return end
        if ply:GetNWBool("P11_InfActive", false) then return end
        if util.IsValidModel(w) then ply:SetModel(w) end
    end)
end)

-- админ: дать XP вручную (p11_bpxp <ник> <кол-во>)
concommand.Add("p11_bpxp", function(ply, _, args)
    if IsValid(ply) and not (P11FW.Config and P11FW.Config.Admin and P11FW.Config.Admin(ply)) then
        POLUS11.Notify(ply, "XP выдаёт только командование.")
        return
    end
    local nick = tostring(args[1] or "")
    local amt = tonumber(args[2]) or 0
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and string.find(string.lower(p:Nick()), string.lower(nick), 1, true) then
            POLUS11.BPAdd(p, amt, "выдача командованием")
            return
        end
    end
    print("[БАТЛ-ПАСС] боец не найден: " .. nick)
end)

print("[POLUS-11] БАТЛ-ПАСС «БИТВА ВРЕМЕНИ» v5.2.0: 20 уровней · XP за дела/фраги · награды (₽/ПФ/секретный арсенал рейха/ГЛАВНЫЙ ПРИЗ на 20) · меню F5")
