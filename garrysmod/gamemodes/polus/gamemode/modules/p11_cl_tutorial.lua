-- ============================================================
--  ПОЛЮС-11 — ТУТОРИАЛ НОВИЧКА (client) v4.2
--  Первые 10 минут жизни на станции: карточки-подсказки и
--  маяки-стрелки к нужным объектам. Прогресс — в локальный
--  файл, один раз на клиент. /туториал — прогнать ещё раз.
-- ============================================================

surface.CreateFont("P11.Tut.Big",   { font = "Roboto", size = 26, weight = 800, extended = true })
surface.CreateFont("P11.Tut.Small", { font = "Roboto", size = 16, weight = 500, extended = true })

local TUT_FILE = "polus11/tutorial_done.txt"

local TUT = {
    active = false,
    step   = 1,
    stepAt = 0,
}

-- шаг → цель-энтити + условие завершения
local STEPS = {
    {
        hint = "НАЙДИ КАДРОВИКА",
        sub = "Иди на маяк и жми E (или F4) — возьми должность. Без неё ты просто новобранец.",
        cls = "polus_fw_jobnpc",
        check = function()
            local id = P11FW and P11FW.GetJobId and P11FW.GetJobId(LocalPlayer()) or ""
            return id ~= "" and id ~= "recruit" and id ~= "novobranets"
        end,
    },
    {
        hint = "ДЕЛАЙ СМЕННЫЕ ДЕЛА",
        sub = "Список задач — слева на экране. За все задачи 2000₽, за дело своей должности — на каждом шагу. 45 секунд на осмотр.",
        cls = nil,
        wait = 45,
        check = function() return CurTime() - TUT.stepAt >= 45 end,
    },
    {
        hint = "ЗАГЛЯНИ В ЛАРЁК",
        sub = "У торговца снабжением продают стволы, рации и пайки. Подойди поближе к маяку — засчитаю визит.",
        cls = "polus_p11_shopnpc",
        near = 450,
        check = function()
            local e = NearestTutEnt("polus_p11_shopnpc")
            if not IsValid(e) then
                -- ларька на карте ещё нет — иначе этот шаг не пройти; пропускаем мягко
                return CurTime() - TUT.stepAt >= 25
            end
            return LocalPlayer():GetPos():DistToSqr(e:GetPos()) < 450 * 450
        end,
    },
    {
        hint = "НАВЕДАЙСЯ К ГЕНЕРАТОРУ",
        sub = "Сердце станции: солярка, износ, поломки. Замёрзнешь — грейся ТОЛЬКО у работающего генератора.",
        cls = "polus11_generator",
        near = 550,
        check = function()
            local e = NearestTutEnt("polus11_generator")
            if not IsValid(e) then return CurTime() - TUT.stepAt >= 25 end
            return LocalPlayer():GetPos():DistToSqr(e:GetPos()) < 550 * 550
        end,
    },
    {
        hint = "СПРАВКА: F1",
        sub = "Всё остальное (бурая печать глав страха) — в памятке по F1. Добро пожаловать на Полюс-11.",
        cls = nil,
        check = function() return CurTime() - TUT.stepAt >= 25 end,
    },
}

function NearestTutEnt(cls)
    local best, bd
    for _, e in ipairs(ents.FindByClass(cls)) do
        local d = e:GetPos():DistToSqr(LocalPlayer():GetPos())
        if not bd or d < bd then best, bd = e, d end
    end
    return best
end

local function TutStep(i)
    TUT.step = i
    TUT.stepAt = CurTime()
    if i > #STEPS then
        TUT.active = false
        -- отметка «обучен»
        if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
        file.Write(TUT_FILE, "done " .. os.date("%Y-%m-%d %H:%M"))
        chat.AddText(Color(160, 210, 255), "[ПОЛЮС-11] Обучение завершено. F1 — памятка, !репорт — если что-то не так.")
        return
    end
    surface.PlaySound("buttons/button15.wav")
end

-- старт обучения
local function TutStart(force)
    if not force and file.Exists(TUT_FILE, "DATA") then return end
    if force then
        if file.Exists(TUT_FILE, "DATA") then file.Delete(TUT_FILE) end
    end
    TUT.active = true
    timer.Simple(6, function() TutStep(1) end)
end

hook.Add("InitPostEntity", "P11.TutorialBoot", function()
    timer.Simple(15, function() TutStart(false) end)
end)

concommand.Add("p11_tutorial", function() TutStart(true) end)

-- тик условий
timer.Create("P11.Tutorial", 1, 0, function()
    if not TUT.active then return end
    local me = LocalPlayer()
    if not IsValid(me) or not me:Alive() then return end
    local st = STEPS[TUT.step]
    if not st then return end
    if st.check and st.check() then
        TutStep(TUT.step + 1)
    end
end)

-- рисование: карточка + маяк
hook.Add("HUDPaint", "P11.TutorialHUD", function()
    if not TUT.active then return end
    local st = STEPS[TUT.step]
    if not st then return end

    local w, h = ScrW(), ScrH()

    -- карточка сверху
    draw.RoundedBox(10, w / 2 - 300, 16, 600, 74, Color(8, 14, 20, 220))
    surface.SetDrawColor(120, 185, 255, 170)
    surface.DrawOutlinedRect(w / 2 - 300, 16, 600, 74, 1)
    draw.SimpleText("ОБУЧЕНИЕ " .. TUT.step .. "/" .. #STEPS .. ": " .. st.hint, "P11.Tut.Big",
        w / 2, 34, Color(150, 210, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    draw.SimpleText(st.sub, "P11.Tut.Small", w / 2, 66, Color(215, 222, 232), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

    -- маяк у цели
    if st.cls then
        local ent = NearestTutEnt(st.cls)
        if IsValid(ent) then
            local pos = ent:GetPos() + Vector(0, 0, 86)
            local scr = pos:ToScreen()
            if scr.visible then
                local pulse = 0.6 + math.sin(CurTime() * 5) * 0.4
                local dist = math.floor(LocalPlayer():GetPos():Distance(ent:GetPos()))
                draw.RoundedBox(6, scr.x - 70, scr.y - 40, 140, 50, Color(8, 14, 20, 200 * (0.4 + 0.6 * pulse)))
                surface.SetDrawColor(120, 185, 255, 220 * pulse)
                surface.DrawOutlinedRect(scr.x - 70, scr.y - 40, 140, 50, 2)
                draw.SimpleText("▼ ЦЕЛЬ", "P11.Tut.Small", scr.x, scr.y - 30,
                    Color(160, 215, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText(dist .. " м", "P11.Tut.Small", scr.x, scr.y - 12,
                    Color(200, 210, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            -- столб света над объектом
            render.SetColorMaterial()
            render.DrawBeam(ent:GetPos() + Vector(0, 0, 20), ent:GetPos() + Vector(0, 0, 420),
                10, 0, 1, Color(120, 185, 255, 60 + 60 * math.abs(math.sin(CurTime() * 2))))
        end
    end
end)

print("[POLUS-11] туториал новичка загружен")
