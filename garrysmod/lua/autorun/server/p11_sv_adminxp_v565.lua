-- ============================================================
--  ПОЛЮС-11 — ВЫДАЧА ОПЫТА/СТАЖА (server) v5.6.5 (НОВЫЙ ФАЙЛ)
--  Владелец: «добавь новую вкладку для выдачи опыта» +
--  «время не выдаётся». Админ-окно «ВЫДАЧА ОПЫТА»:
--    • ОПЫТ СЛУЖБЫ (древо, skilltree.json)
--    • XP БАТЛ-ПАССА (POLUS11.BPAdd)
--    • СТАЖ/ВРЕМЯ (playtime.json, минуты)
--  Вход: чат !опыт / консоль p11_xp (админ).
--  Всё через net (обходит cmdlock-замок, гейт — Config.Admin).
--  Старые файлы не трогаем.
-- ============================================================

util.AddNetworkString("P11_XPAct")
util.AddNetworkString("P11_XPOpen")

local function IsAdmin(ply)
    return IsValid(ply) and P11FW and P11FW.Config and P11FW.Config.Admin
        and P11FW.Config.Admin(ply)
end

local function FindBy(part)
    part = tostring(part or "")
    local low = string.lower(part)
    for _, p in ipairs(player.GetAll()) do
        if string.lower(p:Nick()):find(low, 1, true)
            or p:SteamID() == part or tostring(p:SteamID64()) == part then
            return p
        end
    end
    return nil
end

net.Receive("P11_XPAct", function(_, ply)
    if not IsAdmin(ply) then return end
    ply.P11_XPNext = ply.P11_XPNext or 0
    if CurTime() < ply.P11_XPNext then return end
    ply.P11_XPNext = CurTime() + 0.5

    local mode = net.ReadUInt(2)
    local nick = net.ReadString()
    local amt = math.floor(tonumber(net.ReadUInt(20)) or 0)
    if amt <= 0 then return end

    local target = FindBy(nick)
    if not IsValid(target) then
        if POLUS11.Notify then POLUS11.Notify(ply, "Игрок не найден: " .. tostring(nick)) end
        return
    end

    if mode == 1 then -- опыт службы (древо)
        local sid = target:SteamID()
        POLUS11.Tree = POLUS11.Tree or {}
        local st = POLUS11.Tree[sid] or { xp = 0, trees = {} }
        st.xp = (tonumber(st.xp) or 0) + amt
        POLUS11.Tree[sid] = st
        if file and file.Write then
            if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
            file.Write("polus11/skilltree.json", util.TableToJSON(POLUS11.Tree, true) or "{}")
        end
        if POLUS11.TreeSync then POLUS11.TreeSync(target) end
        if POLUS11.Notify then POLUS11.Notify(target, "Опыт службы +" .. amt .. " (выдал " .. ply:Nick() .. ")") end
        if POLUS11.Log then POLUS11.Log("ОПЫТ: " .. ply:Nick() .. " → " .. target:Nick() .. " +" .. amt .. " опыта службы") end
    elseif mode == 2 then -- XP батл-пасса
        if POLUS11.BPAdd then POLUS11.BPAdd(target, amt, "выдал " .. ply:Nick()) end
        if POLUS11.Notify then POLUS11.Notify(target, "XP батл-пасса +" .. amt .. " (выдал " .. ply:Nick() .. ")") end
        if POLUS11.Log then POLUS11.Log("XP БП: " .. ply:Nick() .. " → " .. target:Nick() .. " +" .. amt) end
    elseif mode == 3 then -- стаж/время (минуты)
        local sid = target:SteamID()
        POLUS11.Playtime = POLUS11.Playtime or {}
        POLUS11.Playtime[sid] = (tonumber(POLUS11.Playtime[sid]) or 0) + amt
        if file and file.Write then
            if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
            file.Write("polus11/playtime.json", util.TableToJSON(POLUS11.Playtime, true) or "{}")
        end
        target:SetNWInt("P11_PlayMin", math.floor(tonumber(POLUS11.Playtime[sid]) or 0))
        if POLUS11.Notify then POLUS11.Notify(target, "Стаж +" .. amt .. " мин (выдал " .. ply:Nick() .. ")") end
        if POLUS11.Log then POLUS11.Log("СТАЖ: " .. ply:Nick() .. " → " .. target:Nick() .. " +" .. amt .. " мин") end
    end
end)

-- открыть окно выдачи (админу)
local function OpenXP(ply)
    if IsAdmin(ply) then
        net.Start("P11_XPOpen")
        net.Send(ply)
    elseif IsValid(ply) and POLUS11.Notify then
        POLUS11.Notify(ply, "Выдача опыта — только для администрации.")
    end
end

concommand.Add("p11_xp", function(ply) OpenXP(ply) end)

-- чат !опыт (оборачиваем роутер, чтобы съелась до OOC)
do
    local t = hook.GetTable()
    local ps = t and t["PlayerSay"]
    if ps and ps["P11.ChatCore"] then
        local orig = ps["P11.ChatCore"]
        ps["P11.ChatCore"] = function(ply, text)
            if IsValid(ply) and text then
                local low = string.lower(string.Trim(text))
                if low == "!опыт" then
                    OpenXP(ply)
                    return ""
                end
            end
            return orig(ply, text)
        end
    end
end

print("[POLUS-11] ВЫДАЧА ОПЫТА v5.6.5 (server): !опыт / p11_xp — опыт службы, XP батл-пасса, стаж")
