-- ============================================================
--  ПОЛЮС-11 — ТЕСТ КРОВИ (сервер)
--  Результат видит ТОЛЬКО тестирующий. Заражённый учёный
--  может ПОДМЕНИТЬ результат.
-- ============================================================

util.AddNetworkString("P11_FalsifyAsk")
util.AddNetworkString("P11_FalsifySet")
util.AddNetworkString("P11_TestResult")

POLUS11.PendingTests = POLUS11.PendingTests or {}

function POLUS11.StartBloodTest(tableEnt, vial, tester)
    tableEnt:SetTesting(true)
    POLUS11.PendingTests[tester] = {
        table = tableEnt,
        vial = vial,
        infected = vial.DonorInfected == true,
        falsify = false,
    }

    -- звук нагрева проволоки
    tableEnt:EmitSound("ambient/energy/weld1.wav", 65, 100)

    -- если тестирующий — Нечто, предлагаем подменить результат
    if POLUS11.IsInfected(tester) and tester:GetNWBool("P11_InfActive", false) then
        net.Start("P11_FalsifyAsk")
            net.WriteString(vial:GetDonorName())
        net.Send(tester)
    end

    -- эффекты нагрева во время теста
    local id = "P11_TestSpark_" .. tableEnt:EntIndex()
    timer.Create(id, 0.5, POLUS11.Config.BloodTestTime * 2, function()
        if not IsValid(tableEnt) then timer.Remove(id) return end
        local ed = EffectData()
        ed:SetOrigin(tableEnt:GetPos() + Vector(0, 0, 42))
        util.Effect("sparks", ed, true, true)
    end)

    timer.Simple(POLUS11.Config.BloodTestTime, function()
        POLUS11.FinishBloodTest(tester)
    end)
end

function POLUS11.FinishBloodTest(tester)
    local t = POLUS11.PendingTests[tester]
    POLUS11.PendingTests[tester] = nil
    if not t or not IsValid(t.table) then return end

    t.table:SetTesting(false)

    local thing = t.infected
    if t.falsify then thing = not thing end

    local pos = t.table:GetPos() + Vector(0, 0, 40)
    local donor = "?"
    if IsValid(t.vial) then donor = t.vial:GetDonorName() end

    if thing then
        -- КРОВЬ ВОПИТ: колба "оживает"
        t.table:EmitSound("npc/zombie_poison/pz_alert1.wav", 90, 95)
        t.table:EmitSound("npc/zombie_poison/pz_alert2.wav", 80, 120)

        if IsValid(t.vial) then
            -- колба подпрыгивает и дёргается
            local startPos = t.vial:GetPos()
            for i = 1, 10 do
                timer.Simple(i * 0.08, function()
                    if IsValid(t.vial) then
                        t.vial:SetPos(startPos + Vector(math.random(-8, 8), math.random(-8, 8), 6 + math.abs(math.sin(i)) * 18))
                    end
                end)
            end
            timer.Simple(0.9, function()
                if IsValid(t.vial) then t.vial:SetPos(startPos) end
            end)
        end

        -- зелёный пар
        for i = 1, 4 do
            local ed = EffectData()
            ed:SetOrigin(pos + Vector(math.random(-6, 6), math.random(-6, 6), i * 5))
            util.Effect("sparks", ed, true, true)
        end
        local gas = EffectData()
        gas:SetOrigin(pos)
        util.Effect("smoke_trail", gas, true, true)

        POLUS11.Log("ТЕСТ КРОВИ [" .. donor .. "]: НЕЧТО" .. (t.falsify and " (подменено на ЧИСТ)" or "") .. " | тестировал: " .. tester:Nick())
    else
        -- человек: обычный пар
        t.table:EmitSound("ambient/levels/canals/toxic_slime_sizzle2.wav", 60, 100)
        local ed = EffectData()
        ed:SetOrigin(pos)
        util.Effect("smoke_trail", ed, true, true)
        POLUS11.Log("ТЕСТ КРОВИ [" .. donor .. "]: чист" .. (t.falsify and " (подменено на НЕЧТО!)" or "") .. " | тестировал: " .. tester:Nick())
    end

    -- результат сообщаем ТОЛЬКО тестирующему
    net.Start("P11_TestResult")
        net.WriteBool(thing)
        net.WriteString(donor)
        net.WriteBool(t.falsify)
    net.Send(tester)

    if POLUS11.TaskEvent then POLUS11.TaskEvent(tester, "blood_test") end -- задача учёных
end

-- учёный решил подменить (или нет)
net.Receive("P11_FalsifySet", function(len, ply)
    local fake = net.ReadBool()
    local t = POLUS11.PendingTests[ply]
    if not t then return end
    t.falsify = fake
end)
