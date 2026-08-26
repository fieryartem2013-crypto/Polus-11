ENT.Type      = "anim"
ENT.Base      = "base_anim"

ENT.PrintName = "Станционный генератор"
ENT.Author    = "POLUS-11"
ENT.Category  = "ПОЛЮС-11"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH

-- v3.7 РЕВОРК ГЕНЕРАТОРОВ:
--  • ИЗНОС (0-100%): копится от работы (в бурю — вдвое быстрее),
--    после ~55% возможны ПОЛОМКИ 4 типов: перегрев, утечка масла,
--    стартер, скачок напряжения. Поломка = расход х1.6 + искры,
--    перегрев на 100% АВАРИЯ (генератор глохнет → блэкаут).
--  • РЕЖИМ «РЕЗЕРВ»: резервный молчит, пока свет есть, и сам
--    включается в блэкаут — классика «аварийного дизеля».
--  • ОБСЛУЖИВАНИЕ: долгое E рядом — «чек-лист механика»
--    (любой человек, инженер/техник быстрее) — снимает износ,
--    чинит поломку. Это новые рабочие задачи для техсостава.
--  • Переключение режима: присесть (CTRL) + E — инженер/командный.

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "Fuel")        -- секунд топлива осталось
    self:NetworkVar("Bool", 0, "Damaged")
    self:NetworkVar("Float", 1, "UseProgress") -- прогресс действия E 0..1
    self:NetworkVar("String", 0, "UseAction")  -- "repair"/"sabotage"/"service"/""
    self:NetworkVar("Float", 2, "Wear")        -- износ 0..100
    self:NetworkVar("String", 1, "Fault")      -- ""/overheat/leak/starter/voltage
    self:NetworkVar("Bool", 1, "Reserve")      -- режим резерва
end

-- описание поломок (общая таблица — нужна и клиенту для 3D2D)
POLUS11_GEN_FAULTS = {
    overheat = { name = "ПЕРЕГРЕВ",          hint = "держи E — продуй радиатор" },
    leak     = { name = "УТЕЧКА МАСЛА",      hint = "держи E — подтяни магистраль" },
    starter  = { name = "СБОЙ СТАРТЕРА",     hint = "держи E — заведи вручную" },
    voltage  = { name = "СКАЧКИ НАПРЯЖЕНИЯ", hint = "держи E — перебери щиток" },
}
