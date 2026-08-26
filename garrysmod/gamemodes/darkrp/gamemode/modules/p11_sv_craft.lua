-- ============================================================
--  ПОЛЮС-11 — КУСТАРНАЯ МАСТЕРСКАЯ (крафт) (server)
--  v4.10.0 «ГАРАЖ». Заявка владельца: «нет крафтов».
--  Рецепты из материалов ларька → готовые предметы в инвентарь.
--   • материалы — обычные позиции каталога POLUS11.Items с флагом
--     mat = true (в ларьке дёшевы; в инвентаре не используются,
--     сервер так и скажет: «это материал — к мастеру»);
--   • собранное ложится в ИНВЕНТАРЬ (🎒 C-меню), оттуда — «ИСПОЛЬЗОВАТЬ»;
--   • окно мастерской: кнопка в инвентаре, чат !крафт, консоль p11_craft.
-- ============================================================

util.AddNetworkString("P11_CraftDo")
util.AddNetworkString("P11_CraftOpen") -- sv→cl: дёрнуть окно мастерской (чат !крафт)

-- ============ РЕЦЕПТЫ ============
-- needs: { id_материала = кол-во }   give: id из POLUS11.Items
POLUS11.Crafts = {
    ration = {
        name = "Горячий паёк",
        give = "ration",
        needs = { cons = 1, fuel = 1 },
        desc = "Тушёнку разогреть на соляре — и вот уже полярный обед.",
    },
    chemlight = {
        name = "Химсвет (пачка)",
        give = "chemlight",
        needs = { spirit = 1, cloth = 1 },
        desc = "Спирт + брезентовый фитиль: метка света в белой мгле.",
    },
    syringe = {
        name = "Полевой шприц",
        give = "syringe",
        needs = { spirit = 1, parts = 1 },
        desc = "Из запчастей — шприц-тюбик, спиртом — стерильность.",
    },
    radio = {
        name = "Рация (самосбор)",
        give = "radio",
        needs = { parts = 1, scrap = 1 },
        desc = "Приёмник из лома и запчастей. Центр услышит.",
    },
    medkit = {
        name = "Полевой медкейс",
        give = "medkit",
        needs = { cloth = 2, spirit = 1 },
        desc = "Бинт, спирт, упаковка. Медики одобряют самодеятельность.",
    },
    flamer = {
        name = "Кустарный огнемёт",
        give = "flamer",
        needs = { fuel = 2, parts = 2, scrap = 2 },
        desc = "ГЛАВНЫЙ рецепт войны с Нечто: соляра, запчасти, лом — и струя огня.",
    },
    -- v4.11.0 «КУЗНЯ»: верстак развернули — новые рецепты (боеприпасы и инструмент)
    ammo9 = {
        name = "Самокрут 9×18 (x60)",
        give = "ammo_pistol",
        needs = { scrap = 1, parts = 1 },
        desc = "Гильзы из лома, капсюли из запчастей. К пистолетам станции.",
    },
    ammosmg = {
        name = "ПП-патроны самосбор (x90)",
        give = "ammo_smg",
        needs = { scrap = 1, parts = 1, spirit = 1 },
        desc = "Для АКС/ППШ: спирт-смазка — не клинит на морозе.",
    },
    ammoar = {
        name = "Винтовочно-автоматные (x60)",
        give = "ammo_ar",
        needs = { scrap = 2, parts = 1 },
        desc = "Полный рожок к АК-74 и РПД из станочных остатков.",
    },
    ammobuck = {
        name = "Картечь 12-го самосбор (x16)",
        give = "ammo_buck",
        needs = { scrap = 1, cloth = 1, spirit = 1 },
        desc = "Гвозди из лома, пыж из брезента — двустволка скажет спасибо.",
    },
    scalpel = {
        name = "Скальпель",
        give = "scalpel",
        needs = { scrap = 1, parts = 1 },
        desc = "Обмолоток лома, заточка о наждак — режет честно.",
    },
    ukol = {
        name = "Инъектор «УКОЛ-С»",
        give = "ukol",
        needs = { parts = 2, spirit = 2 },
        desc = "Шприц-тюбики + стерильный спирт: два заряда живучести.",
    },
}

-- список материалов (для кл.-подписей; живут в POLUS11.Items с mat=true)
POLUS11.CraftMats = { "scrap", "cloth", "spirit", "fuel", "parts", "cons" }

function POLUS11.CraftDo(ply, id)
    local rc = POLUS11.Crafts[id]
    if not rc then return end
    if not ply:Alive() then
        POLUS11.Notify(ply, "Мёртвым гайки не крутят.")
        return
    end
    local prod = POLUS11.Items and POLUS11.Items[rc.give]
    if not prod then
        POLUS11.Notify(ply, "Изделие «" .. rc.name .. "» вне каталога склада — скажи Главе.")
        return
    end
    -- изделие — оружие и его класса нет (нет пака) → не собрать
    if isstring(prod.class) and not prod.ent and not POLUS11.InvCanUse(prod.class) then
        POLUS11.Notify(ply, "«" .. rc.name .. "» не собрать: на сервере нет пака этого изделия.")
        ply:EmitSound("buttons/button10.wav", 60, 90)
        return
    end

    local data = POLUS11.InvOf(ply)
    for mid, n in pairs(rc.needs) do
        local have = tonumber(data.items[mid]) or 0
        if have < n then
            local mname = (POLUS11.Items[mid] and POLUS11.Items[mid].name) or mid
            POLUS11.Notify(ply, "Не хватает материала «" .. mname .. "»: надо " .. n ..
                ", есть " .. have .. ". Материалы — в ларьке (дешевле готового!).")
            ply:EmitSound("buttons/button10.wav", 60, 90)
            return
        end
    end
    for mid, n in pairs(rc.needs) do
        data.items[mid] = (tonumber(data.items[mid]) or 0) - n
        if data.items[mid] <= 0 then data.items[mid] = nil end
    end
    data.items[rc.give] = (tonumber(data.items[rc.give]) or 0) + 1
    if POLUS11.InvSaveNow then POLUS11.InvSaveNow() end
    -- v4.12.0 «ОТБОЙ»: сборка на верстаке — дело смены (задача «Собери …»)
    if POLUS11.TaskEvent then POLUS11.TaskEvent(ply, "craft_do") end

    POLUS11.Notify(ply, "🛠 Собрано: «" .. rc.name .. "» — лежит в инвентаре (🎒 C-меню).")
    ply:ChatPrint("[МАСТЕРСКАЯ] Готово: «" .. rc.name .. "». Открой 🎒 инвентарь → ИСПОЛЬЗОВАТЬ.")
    ply:EmitSound("buttons/button24.wav", 65, 100)
    POLUS11.Log("КРАФТ: " .. ply:Nick() .. " собрал «" .. rc.name .. "»")
    POLUS11.InvSync(ply)
end

net.Receive("P11_CraftDo", function(_, ply)
    if not IsValid(ply) then return end
    ply.P11_CraftNext = ply.P11_CraftNext or 0
    if CurTime() < ply.P11_CraftNext then return end
    ply.P11_CraftNext = CurTime() + 0.6
    local id = string.sub(net.ReadString() or "", 1, 24)
    POLUS11.CraftDo(ply, id)
end)

-- чат-дверь: !крафт / !мастерская — прислать клиенту окно (свежий синк прилагается)
hook.Add("PlayerSay", "P11.CraftChat", function(ply, text)
    local t = string.lower(string.Trim(tostring(text or "")))
    if t == "!крафт" or t == "!craft" or t == "!мастерская" or t == "!сборка"
        or t == "/крафт" or t == "/craft" or t == "/мастерская" or t == "/сборка" then
        POLUS11.InvSync(ply)
        net.Start("P11_CraftOpen")
        net.Send(ply)
        return ""
    end
end)

print("[POLUS-11] кустарная мастерская v4.11.0 «КУЗНЯ»: 12 рецептов (от пайка до огнемёта + самосбор патронов/скальпель/УКОЛ-С), окно — 🎒/!крафт/p11_craft/ВЕРСТАК")
