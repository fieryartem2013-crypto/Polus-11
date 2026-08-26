-- ============================================================
--  ПОЛЮС-11 — РЕПОРТЫ v4.8.2 «ДОКЛАД» (server)
--  Заявка владельца: «сделай отдельно меню для репортов, чтобы
--  там их ПРИНЯТЬ и ТЕПНУТЬ К СЕБЕ — менюшка, там всё написано».
--
--  БЫЛО: /report падал строчкой в чат админам — прочитал и забыл,
--  никаких кнопок. ТЕПЕРЬ — тикеты:
--   • окно /репорты (команды: /репорты /reports !репорты !reports,
--     консоль p11_reports): у админа — ВСЕ жалобы, у игрока — свои;
--   • у карточки кнопки: ✔ ПРИНЯТЬ • ↗ К НЕМУ • ↙ К СЕБЕ • ✕ ЗАКРЫТЬ;
--   • новый репорт — звонок + тост всем админам онлайн;
--   • телепорты помечены льготным окном античита (ACMarkTeleport);
--   • журнал по-прежнему пишется в data/polus11/reports.txt
--     (это делает мост в POLUS11.SendReport, p11_sv_command.lua).
--
--  СЕТЬ (одна строка P11_Rep, порядок оп-кодов):
--   C2S: 1=создать (string)  2=принять (id)  3=тп к автору (id)
--        4=автора к себе (id)  5=закрыть (id)  6=дать список
--   S2C: 1=список (для глаз получателя)  2=тост  4=открыть окно
-- ============================================================

util.AddNetworkString("P11_Rep")

local MAX_LIVE = 25 -- сколько живых (не закрытых) тикетов держим

POLUS11.Reports = POLUS11.Reports or {}
local nextId = 1
for _, r in ipairs(POLUS11.Reports) do
    nextId = math.max(nextId, (tonumber(r.id) or 0) + 1)
end

local function IsAdm(ply)
    return IsValid(ply) and P11FW.Config and P11FW.Config.Admin
        and P11FW.Config.Admin(ply)
end

local function FindRep(id)
    for _, r in ipairs(POLUS11.Reports) do
        if r.id == id then return r end
    end
end

local function FindPlayerBySid(sid)
    for _, p in ipairs(player.GetAll()) do
        if p:SteamID() == sid then return p end
    end
end

-- ============ ОТПРАВКА СПИСКА (админу — всё, игроку — своё) ============

local function PushTo(ply)
    if not IsValid(ply) then return end
    local adm = IsAdm(ply)
    local mine = ply:SteamID()
    local list = {}
    -- свежие сверху
    for i = #POLUS11.Reports, 1, -1 do
        local r = POLUS11.Reports[i]
        if r.status ~= "closed" and (adm or r.sid == mine) then
            list[#list + 1] = r
        end
    end
    if #list == 0 and not adm then
        -- игроку покажем и его закрытые (вдруг ждёт ответа)
        for i = #POLUS11.Reports, 1, -1 do
            local r = POLUS11.Reports[i]
            if r.sid == mine then list[#list + 1] = r end
            if #list >= 5 then break end
        end
    end

    net.Start("P11_Rep")
        net.WriteUInt(1, 4)
        net.WriteUInt(#list, 8)
        for _, r in ipairs(list) do
            net.WriteUInt(r.id, 16)
            net.WriteString(r.name or "?")
            net.WriteString(r.sid or "?")
            net.WriteString(r.text or "")
            net.WriteString(r.status or "open")
            net.WriteString(r.by or "")
            net.WriteUInt(math.min(65000, math.floor(CurTime() - (r.at or CurTime()))), 16)
        end
    net.Send(ply)
end

local function PushAll()
    for _, p in ipairs(player.GetAll()) do PushTo(p) end
end

local function Toast(ply, text, snd)
    if not IsValid(ply) then return end
    net.Start("P11_Rep")
        net.WriteUInt(2, 4)
        net.WriteString(text)
        net.WriteBool(snd and true or false)
    net.Send(ply)
    -- v4.9.3 «ГРОШ»: двойная страховка видимости — chat.AddText под
    -- BonChat может утопать в дефолтной панели, а серверный ChatPrint
    -- BonChat показывает ЖЕЛЕЗНО (тип «none» в его роутере миски).
    ply:ChatPrint("[РЕПОРТЫ] " .. text)
end

local function ToastAdmins(text, snd)
    for _, p in ipairs(player.GetAll()) do
        if IsAdm(p) then Toast(p, text, snd) end
    end
end

-- ============ СОЗДАНИЕ ТИКЕТА (мост дергает POLUS11.SendReport) ============

function POLUS11.RepAdd(ply, text)
    text = string.sub(string.Trim(tostring(text or "")), 1, 220)
    if not IsValid(ply) or text == "" then return false end

    local live = 0
    for _, r in ipairs(POLUS11.Reports) do
        if r.status ~= "closed" then live = live + 1 end
    end
    if live >= MAX_LIVE then
        -- выдавить самый старый живой
        for i, r in ipairs(POLUS11.Reports) do
            if r.status ~= "closed" then
                table.remove(POLUS11.Reports, i)
                break
            end
        end
    end
    -- мусорка: закрытых больше 40 — подметаем старые
    while #POLUS11.Reports > 60 do
        local cut = false
        for i, r in ipairs(POLUS11.Reports) do
            if r.status == "closed" then
                table.remove(POLUS11.Reports, i)
                cut = true
                break
            end
        end
        if not cut then break end
    end

    local r = {
        id = nextId,
        sid = ply:SteamID(),
        name = (POLUS11.DisplayName and POLUS11.DisplayName(ply)) or ply:Nick(),
        text = text,
        at = CurTime(),
        status = "open",
    }
    nextId = nextId + 1
    POLUS11.Reports[#POLUS11.Reports + 1] = r

    ToastAdmins("Новый репорт #" .. r.id .. " от " .. r.name
        .. ": «" .. string.sub(text, 1, 60) .. "» — окно: /репорты", true)
    if P11FW.ModLog then P11FW.ModLog("report", ply, nil, "#" .. r.id .. " " .. text) end
    -- v4.9.3 «ГРОШ»: громкая подпись серверного лога — репорт никогда
    -- теперь не «исчезает молча»: каждый созданный тикет виден в консоли.
    print("[POLUS-11] РЕПОРТ #" .. r.id .. " от " .. r.name .. " («" .. r.sid .. "»): " .. text)
    -- и сам отправитель получает ГРОМКОЕ подтверждение (также серверным ChatPrint)
    Toast(ply, "Твой репорт #" .. r.id .. " создан — админы видят его в окне /репорты.", true)
    PushAll()
    return true, r
end

-- ============ ПРИЁМ ОТ КЛИЕНТА ============

net.Receive("P11_Rep", function(len, ply)
    if not IsValid(ply) then return end
    local op = net.ReadUInt(4)

    if op == 6 then -- просят список (открыли окно / обновили)
        PushTo(ply)
        return
    end

    if op == 1 then -- создать из окна (кулдаун общий с /report)
        local text = net.ReadString()
        ply.P11_ReportCd = ply.P11_ReportCd or 0
        if CurTime() < ply.P11_ReportCd then
            Toast(ply, "Следующий репорт через "
                .. math.ceil(ply.P11_ReportCd - CurTime()) .. " сек.", false)
            return
        end
        if POLUS11.SendReport then
            POLUS11.SendReport(ply, text) -- он и тикет создаст (мост)
        elseif POLUS11.RepAdd then
            POLUS11.RepAdd(ply, text)
        end
        PushTo(ply)
        return
    end

    -- дальше всё — действия админа над тикетом
    if not IsAdm(ply) then return end
    local id = net.ReadUInt(16)
    local r = id and FindRep(id)
    if not r then return end

    if op == 2 then -- ✔ ПРИНЯТЬ
        if r.status == "taken" and r.by == ply:Nick() then return end
        r.status = "taken"
        r.by = ply:Nick()
        ToastAdmins(ply:Nick() .. " принял репорт #" .. id .. " в работу.", false)
        local author = FindPlayerBySid(r.sid)
        if IsValid(author) then
            Toast(author, "Твой репорт #" .. id .. " взял администратор "
                .. ply:Nick() .. ". Скоро будет.", false)
        end
        if P11FW.ModLog then P11FW.ModLog("report_take", ply, author, "#" .. id) end
        PushAll()

    elseif op == 3 then -- ↗ К НЕМУ
        local t = FindPlayerBySid(r.sid)
        if not (IsValid(t) and t:Alive()) then
            Toast(ply, "Автор репорта #" .. id .. " недоступен (offline/мёртв).", false)
            return
        end
        if POLUS11.ACMarkTeleport then POLUS11.ACMarkTeleport(ply) end
        ply:SetPos(t:GetPos() + t:GetForward() * -60 + Vector(0, 0, 6))
        ply:SetEyeAngles((t:GetPos() - ply:EyePos()):Angle())
        Toast(ply, "Ты у автора репорта #" .. id .. " (" .. t:Nick() .. ").", false)
        ply:EmitSound("buttons/button9.wav", 55, 130)
        if P11FW.ModLog then P11FW.ModLog("report_goto", ply, t, "#" .. id) end
        PushAll()

    elseif op == 4 then -- ↙ К СЕБЕ
        local t = FindPlayerBySid(r.sid)
        if not (IsValid(t) and t:Alive()) then
            Toast(ply, "Автор репорта #" .. id .. " недоступен (offline/мёртв).", false)
            return
        end
        if POLUS11.ACMarkTeleport then
            POLUS11.ACMarkTeleport(t)
            POLUS11.ACMarkTeleport(ply)
        end
        t:SetPos(ply:GetPos() + ply:GetForward() * 60 + Vector(0, 0, 6))
        t:SetEyeAngles((ply:GetPos() - t:EyePos()):Angle())
        Toast(t, "Администратор " .. ply:Nick() .. " подтянул тебя по репорту #" .. id .. ".", false)
        Toast(ply, "Автор репорта #" .. id .. " у тебя.", false)
        ply:EmitSound("buttons/button9.wav", 55, 130)
        if P11FW.ModLog then P11FW.ModLog("report_bring", ply, t, "#" .. id) end
        PushAll()

    elseif op == 5 then -- ✕ ЗАКРЫТЬ
        r.status = "closed"
        r.by = ply:Nick()
        ToastAdmins(ply:Nick() .. " закрыл репорт #" .. id .. ".", false)
        local author = FindPlayerBySid(r.sid)
        if IsValid(author) then
            Toast(author, "Твой репорт #" .. id .. " закрыт администрацией. Спасибо за сигнал.", false)
        end
        if P11FW.ModLog then P11FW.ModLog("report_close", ply, author, "#" .. id) end
        PushAll()
    end
end)

-- ============ КОМАНДЫ ОТКРЫТИЯ ОКНА ============

hook.Add("PlayerSay", "P11.ReportsChat", function(ply, text)
    local t = string.lower(string.Trim(tostring(text or "")))
    if t == "/репорты" or t == "/reports" or t == "!репорты" or t == "!reports" then
        net.Start("P11_Rep")
            net.WriteUInt(4, 4) -- открыть окно
        net.Send(ply)
        timer.Simple(0.1, function() if IsValid(ply) then PushTo(ply) end end)
        return ""
    end
end)

concommand.Add("p11_reports", function(ply)
    if not IsValid(ply) then return end
    net.Start("P11_Rep")
        net.WriteUInt(4, 4)
    net.Send(ply)
    PushTo(ply)
end)

-- вошедшего админа встречаем счётчиком висящих репортов
hook.Add("PlayerInitialSpawn", "P11.ReportsGreet", function(ply)
    timer.Simple(15, function()
        if not IsValid(ply) or not IsAdm(ply) then return end
        local open = 0
        for _, r in ipairs(POLUS11.Reports) do
            if r.status == "open" then open = open + 1 end
        end
        if open > 0 then
            Toast(ply, "Открытых репортов: " .. open .. ". Окно: /репорты", true)
        end
    end)
end)

print("[POLUS-11] репорты-тикеты v4.8.2 «ДОКЛАД» загружены (/репорты, кнопки принять/тп/закрыть)")
