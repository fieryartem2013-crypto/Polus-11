-- ============================================================
--  ПОЛЮС-11 — ПРОФЫ С УНИКАЛЬНЫМИ МОДЕЛЯМИ (server) v5.2.9 (НОВЫЙ ФАЙЛ)
--  Владелец дал модели и названия:
--    1) models/.../nkvd/border_guards/en/m35_1941_s1_04.mdl
--       → профа «НКВД пониженный до РККА» (фракция РККА);
--    2) models/.../nkvd/internal_troops/en/m35_1941_s1_04f.mdl
--       → профа «НКВД: боец внутренних войск» (фракция НКВД);
--    3) models/.../undeadarmy/infantry/co/m38occult_s1_skeleton.mdl
--       → «Унтер-офицер СС» (переименование «Унтер-офицера Осовца»).
--
--  Регистрируем ЧЕРЕЗ P11FW.CustomJobs + RegisterCustomJobs —
--  ровно как админские кастомные профы: клиенты получат их через
--  P11FW_JobsSync (F4 покажет новые профы). Старые файлы не трогаем.
-- ============================================================

local function AddJob(rec)
    if not (P11FW and P11FW.CustomJobs) then return end
    -- защита от двойного добавления (файл грузится один раз, но всё же)
    for _, r in ipairs(P11FW.CustomJobs) do
        if r.id == rec.id then return end
    end
    table.insert(P11FW.CustomJobs, rec)
end

-- дождаться, пока сид и кастомные профы встанут, потом добавить наши
hook.Add("InitPostEntity", "P11.Profes529", function()
    timer.Simple(2, function()
        if not (P11FW and P11FW.CustomJobs and P11FW.RegisterCustomJobs) then return end

        -- 1) НКВД пониженный до РККА (фракция РККА)
        AddJob({
            id = "ev_nkvd_ponizhen",
            name = "НКВД пониженный до РККА",
            desc = "Разжалованный сотрудник НКВД, отправлен в окопы гарнизона. Форма ещё помнит комиссариат, но теперь ты — красноармеец. 105 ХП / 40 брони.",
            category = "rkka",
            order = 33,
            models = { "models/hts/comradebear/pm0v3/player/nkvd/border_guards/en/m35_1941_s1_04.mdl" },
            weapons = { { "weapon_pistol" }, "weapon_polus11_radio" },
            hp = 105, armor = 40, max = 2, time = 30,
            color = { r = 175, g = 165, b = 95 },
        })

        -- 2) НКВД: боец внутренних войск (фракция НКВД)
        AddJob({
            id = "ev_nkvd_vnutr",
            name = "НКВД: боец внутренних войск",
            desc = "Боец внутренних войск НКВД: караул, конвой, зачистка. Тяжёлая шинель и короткий ствол. 110 ХП / 60 брони.",
            category = "nkvd",
            order = 52,
            whitelist = true,
            models = { "models/hts/comradebear/pm0v3/player/nkvd/internal_troops/en/m35_1941_s1_04f.mdl" },
            weapons = { { "weapon_pistol" }, "weapon_polus11_radio" },
            hp = 110, armor = 60, max = 2, time = 45,
            color = { r = 120, g = 20, b = 24 },
        })

        -- 3) Унтер-офицер СС (переименование Унтер-офицера Осовца + рунная модель)
        local nco = P11FW.Jobs and P11FW.Jobs["seed_oso_nco"]
        if nco then
            nco.name = "Унтер-офицер СС"
            nco.models = { "models/hts/comradebear/pm0v3/player/undeadarmy/infantry/co/m38occult_s1_skeleton.mdl" }
            nco.desc = "Костлявый командир отделения СС: руны, оккультный арсенал, приказ — превыше всего. Секретный штурмовой карабин рейха. 120 ХП / 80 брони."
            local t = P11FW.JobTeams and P11FW.JobTeams["seed_oso_nco"]
            if t and team.SetUp then
                team.SetUp(t, nco.name, nco.color, true)
            end
            if P11FW.Log then P11FW.Log("ПРОФА (v5.2.9): «Унтер-офицер Осовца» → «Унтер-офицер СС» + рунная модель") end
        end

        -- регистрируем наши кастомные (клиенты получат их через JobsSync)
        P11FW.RegisterCustomJobs(P11FW.CustomJobs)
        if P11FW.SyncCustomJobs then P11FW.SyncCustomJobs(nil) end

        if P11FW.Log then P11FW.Log("ПРОФЫ (v5.2.9): добавлены «НКВД пониженный до РККА» и «НКВД: боец внутренних войск»") end
    end)
end)

print("[POLUS-11] ПРОФЫ v5.2.9 (server, autorun): НКВД пониженный до РККА · НКВД боец внутренних войск · Унтер-офицер СС")
