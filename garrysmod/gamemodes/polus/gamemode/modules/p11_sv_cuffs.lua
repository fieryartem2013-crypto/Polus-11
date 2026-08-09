-- ============================================================
--  ПОЛЮС-11 — НАРУЧНИКИ / КОНВОЙ / КАРАУЛ (сервер)
--  v4.22.0 «ОКОВЫ»
--   • Свеп weapon_polus11_cuffs: ЛКМ — защёлкнуть, ПКМ/R — отпустить.
--   • Связанный: снаряжение в сохранку, идёт за конвоиром (тик 0.1с,
--     подтяжка от 700 юн), ходьба/огонь/юз глушены, суицид/машина/
--     подбор/смена должности закрыты (ворота — в fw_sv_jobs).
--   • НПС polus_p11_jailnpc «Начальник караула» (📍 «Расставить»):
--     E → окно срока 3/5/10 мин (P11FW.Punish → арест-дело конвоиру
--     +25 опыта древа/запись в досье) или «отпустить».
--   • Кто вяжет: особый отдел (категория nkvd) + комиссар/генералы РККА.
--     Стафф ранга 3+ в наручники не берём (дежурство).
-- ============================================================

util.AddNetworkString("P11_JailUI")
util.AddNetworkString("P11_JailAct")

-- ============ КТО ВЯЖЕТ ============

local CUFF_JOBS = {
    seed_rkka_komissar   = true,
    seed_rkka_general    = true,
    seed_rkka_generalpeh = true,
}

function POLUS11.CuffAllowed(ply)
    if not IsValid(ply) then return false end
    local jid = P11FW.GetJobId and P11FW.GetJobId(ply)
    local job = jid and P11FW.Jobs and P11FW.Jobs[jid]
    if not job then return false end
    if job.category == "nkvd" then return true end
    return CUFF_JOBS[jid] == true
end

-- ============ СОСТОЯНИЕ ============
-- [target] = { by = captor, weps = {{class,c1,c2}}, ammo = {{id,n}} }

POLUS11.Cuffed = POLUS11.Cuffed or {}

function POLUS11.IsCuffed(ply)
    return IsValid(ply) and POLUS11.Cuffed[ply] ~= nil
end

local function CuffOf(captor)
    for tar, st in pairs(POLUS11.Cuffed) do
        if IsValid(tar) and st.by == captor then return tar end
    end
    return nil
end

-- ============ ЗАЩЁЛКНУТЬ ============

function POLUS11.CuffTry(captor, target)
    if not (IsValid(captor) and IsValid(target)) then return end
    if not captor:Alive() or not target:Alive() then return end
    if target == captor then return end
    if not target:IsPlayer() then return end

    if not POLUS11.CuffAllowed(captor) then
        POLUS11.Notify(captor, "Наручники — только особому отделу и командирам.")
        return
    end
    if P11FW.GetRankLevel and P11FW.GetRankLevel(target) >= 3 then
        POLUS11.Notify(captor, "Стафф не вяжем — он на дежурстве. Вопросы — через !репорт.")
        return
    end
    if P11FW.IsPunished and P11FW.IsPunished(target) then
        POLUS11.Notify(captor, "Он уже наказан — камера ждёт, руки свободны.")
        return
    end
    if POLUS11.Cuffed[target] then
        POLUS11.Notify(captor, "Он уже в наручниках.")
        return
    end
    if target:InVehicle() then
        POLUS11.Notify(captor, "Вытащи его из машины сначала.")
        return
    end
    if IsValid(CuffOf(captor)) then
        POLUS11.Notify(captor, "Ты уже ведёшь задержанного — один подопечный на конвоира.")
        return
    end

    -- связали того, кто САМ кого-то вёл: его подопечный освобождается
    local sub = CuffOf(target)
    if IsValid(sub) then
        POLUS11.CuffRelease(sub, true)
        POLUS11.Notify(sub, "Твоего конвоира самого связали — ты свободен.")
    end

    -- снаряжение — в сохранку
    local weps, ammo = {}, {}
    for _, w in ipairs(target:GetWeapons()) do
        if IsValid(w) then
            weps[#weps + 1] = { class = w:GetClass(), c1 = w:Clip1(), c2 = w:Clip2() }
        end
    end
    for i = 1, 32 do
        local n = target:GetAmmoCount(i)
        if n > 0 then ammo[#ammo + 1] = { i, n } end
    end
    target:StripWeapons()
    target:StripAmmo()

    POLUS11.Cuffed[target] = { by = captor, weps = weps, ammo = ammo }
    target:SetNWBool("P11_Cuffed", true)
    target:SetNWString("P11_CuffBy", captor:Nick())
    captor:SetNWString("P11_CuffLead", target:Nick())

    target:EmitSound("physics/metal/metal_box_impact_hard3.wav", 75, 90)
    captor:EmitSound("weapons/pistol/pistol_empty.wav", 60, 120)
    POLUS11.Notify(captor, "Наручники защёлкнуты: " .. target:Nick() .. ". Веди к начальнику караула — оформит камеру.")
    POLUS11.Notify(target, "Тебя связал " .. captor:Nick() .. ". Снаряжение изъято, идёшь за конвоиром.")
    POLUS11.Log("КОНВОЙ: " .. captor:Nick() .. " защёлкнул наручники на " .. target:Nick())
end

-- ============ ОТПУСТИТЬ ============

function POLUS11.CuffRelease(target, restore)
    local st = POLUS11.Cuffed[target]
    if not st then return end
    POLUS11.Cuffed[target] = nil
    if IsValid(st.by) then st.by:SetNWString("P11_CuffLead", "") end
    if IsValid(target) then
        target:SetNWBool("P11_Cuffed", false)
        target:SetNWString("P11_CuffBy", "")
    end
    if restore and IsValid(target) and target:Alive() then
        for _, d in ipairs(st.weps or {}) do
            if weapons.Get(d.class) and not target:HasWeapon(d.class) then
                local w = target:Give(d.class)
                if IsValid(w) then
                    if d.c1 and d.c1 >= 0 then w:SetClip1(d.c1) end
                    if d.c2 and d.c2 >= 0 then w:SetClip2(d.c2) end
                end
            end
        end
        for _, a in ipairs(st.ammo or {}) do
            target:SetAmmo(a[2], a[1])
        end
        target:EmitSound("weapons/pistol/pistol_empty.wav", 55, 90)
    end
end

function POLUS11.CuffReleaseBy(captor)
    local tar = CuffOf(captor)
    if not IsValid(tar) then
        if IsValid(captor) then POLUS11.Notify(captor, "Ты никого не ведёшь.") end
        return
    end
    POLUS11.CuffRelease(tar, true)
    POLUS11.Notify(captor, "Отпустил: " .. tar:Nick() .. ". Снаряжение возвращено.")
    POLUS11.Notify(tar, "Конвоир " .. captor:Nick() .. " снял наручники. Свободен.")
    POLUS11.Log("КОНВОЙ: " .. captor:Nick() .. " отпустил " .. tar:Nick())
end

-- ============ ПОВОДОК (идёт за конвоиром) ============

timer.Create("P11.CuffsTick", 0.1, 0, function()
    local gone = {}
    for tar, st in pairs(POLUS11.Cuffed) do
        local cap = st.by
        if not IsValid(tar) or not IsValid(cap) or not tar:Alive() or not cap:Alive() then
            gone[#gone + 1] = tar
        elseif cap:InVehicle() then
            -- конвоир сел в машину: не тащим через стены, ждём
        else
            local anchor = cap:GetPos() - cap:GetForward() * 55
            anchor.z = cap:GetPos().z
            local tpos = tar:GetPos()
            local d2 = tpos:DistToSqr(anchor)
            if d2 > 700 * 700 then
                -- оторвался через стены: подтяжка (античит — льготное окно)
                tar:SetPos(anchor)
                tar:SetEyeAngles(cap:EyeAngles())
                tar:SetLocalVelocity(vector_origin)
                if POLUS11.ACMarkTeleport then POLUS11.ACMarkTeleport(tar) end
            elseif d2 > 42 * 42 then
                local dir = anchor - tpos
                dir.z = 0
                if dir:LengthSqr() > 1 then
                    dir:Normalize()
                    local v = dir * 200
                    v.z = tar:GetVelocity().z
                    tar:SetLocalVelocity(v)
                end
            end
        end
    end
    for _, tar in ipairs(gone) do
        -- невалид/смерть конвоира: очистка с возвратом снаряги живому
        POLUS11.CuffRelease(tar, IsValid(tar) and tar:Alive())
    end
end)

-- ============ ЗАПРЕТЫ СВЯЗАННОГО ============

hook.Add("StartCommand", "P11.CuffsKeys", function(ply, cmd)
    if not POLUS11.Cuffed[ply] then return end
    cmd:ClearMovement()
    cmd:RemoveKey(IN_ATTACK + IN_ATTACK2 + IN_JUMP + IN_DUCK + IN_USE
        + IN_RELOAD + IN_ZOOM + IN_GRENADE1 + IN_GRENADE2 + IN_WEAPON1 + IN_WEAPON2)
end)

local function NoWhileCuffed(ply)
    if POLUS11.Cuffed[ply] then return false end
end
hook.Add("CanPlayerSuicide",      "P11.CuffsNoDie",   NoWhileCuffed)
hook.Add("PlayerCanPickupWeapon", "P11.CuffsNoPick",  NoWhileCuffed)
hook.Add("PlayerCanPickupItem",   "P11.CuffsNoItem",  NoWhileCuffed)
hook.Add("CanPlayerEnterVehicle", "P11.CuffsNoCar",   NoWhileCuffed)
hook.Add("PlayerUse",             "P11.CuffsNoUse",   NoWhileCuffed)

hook.Add("PlayerDeath", "P11.CuffsDeath", function(ply)
    if POLUS11.Cuffed[ply] then
        POLUS11.CuffRelease(ply, false) -- на респауне снарягу даст лоадаут
        return
    end
    local tar = CuffOf(ply)
    if IsValid(tar) then
        POLUS11.CuffRelease(tar, true)
        POLUS11.Notify(tar, "Конвоир погиб — наручники сняты.")
    end
end)

hook.Add("PlayerDisconnected", "P11.CuffsBye", function(ply)
    if POLUS11.Cuffed[ply] then POLUS11.Cuffed[ply] = nil end
    local tar = CuffOf(ply)
    if IsValid(tar) then
        POLUS11.CuffRelease(tar, true)
        POLUS11.Notify(tar, "Конвоир покинул станцию — наручники сняты.")
    end
end)

-- админский арест/рабство связанного: камера сама разоружает
hook.Add("P11FW.Punished", "P11.CuffsPunished", function(target)
    if IsValid(target) and POLUS11.Cuffed[target] then
        POLUS11.CuffRelease(target, false)
    end
end)

-- ============ ВЫДАЧА СВЕПА ============

local function CuffArm(ply)
    timer.Simple(0.7, function()
        if not IsValid(ply) or not ply:Alive() then return end
        if not POLUS11.CuffAllowed(ply) then return end
        if P11FW.IsPunished and P11FW.IsPunished(ply) then return end
        if weapons.Get("weapon_polus11_cuffs") and not ply:HasWeapon("weapon_polus11_cuffs") then
            ply:Give("weapon_polus11_cuffs")
        end
    end)
end
hook.Add("PlayerSpawn", "P11.CuffsArm", CuffArm)
hook.Add("P11FW.JobChanged", "P11.CuffsArmJob", function(ply) CuffArm(ply) end)

-- ============ КАРАУЛ: ОФОРМЛЕНИЕ ============

function POLUS11.JailNPCUse(npc, ply)
    local target, hasFar = nil, false
    for tar, st in pairs(POLUS11.Cuffed) do
        if IsValid(tar) and st.by == ply then
            if IsValid(npc) and tar:GetPos():DistToSqr(npc:GetPos()) <= 350 * 350 then
                target = tar
            else
                hasFar = true
            end
        end
    end
    if IsValid(target) then
        net.Start("P11_JailUI")
            net.WriteEntity(target)
        net.Send(ply)
    elseif hasFar then
        POLUS11.Notify(ply, "Подведи связанного ближе к караулу — оформлялка короткая.")
        ply:EmitSound("buttons/button10.wav", 55, 100)
    else
        POLUS11.Notify(ply, "Караул: «Задержанный будет? Веди в наручниках — оформлю камеру за минуту.»")
        ply:EmitSound("buttons/button10.wav", 55, 100)
    end
end

net.Receive("P11_JailAct", function(_, ply)
    if not IsValid(ply) then return end
    ply.P11_JailNext = ply.P11_JailNext or 0
    if CurTime() < ply.P11_JailNext then return end
    ply.P11_JailNext = CurTime() + 0.8

    local tar  = net.ReadEntity()
    local mins = net.ReadUInt(4)
    if not IsValid(tar) or not tar:IsPlayer() then return end
    local st = POLUS11.Cuffed[tar]
    if not st or st.by ~= ply then return end
    if not POLUS11.CuffAllowed(ply) then return end

    -- конвоир обязан стоять у караула
    local near = false
    for _, e in ipairs(ents.FindByClass("polus_p11_jailnpc")) do
        if IsValid(e) and ply:GetPos():DistToSqr(e:GetPos()) <= 430 * 430 then
            near = true
            break
        end
    end
    if not near then
        POLUS11.Notify(ply, "Ты далеко от начальника караула — вернись к оформлялке.")
        return
    end

    if mins == 0 then
        POLUS11.CuffRelease(tar, true)
        POLUS11.Notify(ply, "Задержание отменено: " .. tar:Nick() .. " отпущен.")
        POLUS11.Notify(tar, "Караул отпустил тебя без камеры.")
        POLUS11.Log("КАРАУЛ: " .. ply:Nick() .. " отпустил " .. tar:Nick() .. " без камеры (конвой).")
        return
    end
    if mins ~= 3 and mins ~= 5 and mins ~= 10 then return end

    POLUS11.CuffRelease(tar, false)
    P11FW.Punish(tar, "arrest", mins, "за решётку конвоем (" .. ply:Nick() .. ")", ply)
    POLUS11.Log("КАРАУЛ: " .. ply:Nick() .. " посадил " .. tar:Nick() .. " на " .. mins .. " мин (конвой).")
    net.Start("P11_Announce")
        net.WriteString("ЗАДЕРЖАН: " .. tar:Nick() .. " — " .. mins .. " мин камеры. Вёл: " .. ply:Nick() .. ".")
        net.WriteString("ОСОБЫЙ ОТДЕЛ")
    net.Broadcast()
end)

print("[POLUS-11] наручники/конвой v4.22.0 «ОКОВЫ»: ЛКМ вязать, ПКМ/R отпустить, караул оформляет")
