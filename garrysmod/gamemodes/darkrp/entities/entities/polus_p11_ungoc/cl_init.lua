-- ============================================================
--  ПОЛЮС-11 — v5.8.15 КЛИЕНТ: ВЫРЕЗАТЬ ОСОВЕЦ ИЗ F4
--  Осовец (фракция «Крепость Осовец») — прошлая ивентовая,
--  вырезана на сервере. На клиенте убираем категорию из
--  P11FW.Categories / CategoryList / CustomFactions, чтобы она
--  не висела пустой в F4. Старые файлы не трогаем.
--  ДОСТАВКА: cl_init энтити раздаётся клиентам ВСЕГДА.
-- ============================================================

local function CutOsovecClient()
    if P11FW then
        if P11FW.Categories then
            local keep = {}
            for _, c in ipairs(P11FW.Categories) do
                if not (c and c.id == "osowiec") then keep[#keep + 1] = c end
            end
            P11FW.Categories = keep
        end
        if P11FW.CategoryList then
            local keep = {}
            for _, c in ipairs(P11FW.CategoryList) do
                if not (c and c.id == "osowiec") then keep[#keep + 1] = c end
            end
            P11FW.CategoryList = keep
        end
        if P11FW.CustomFactions and P11FW.CustomFactions.osowiec then
            P11FW.CustomFactions.osowiec = nil
        end
    end
end

CutOsovecClient()
timer.Simple(1, CutOsovecClient)
timer.Simple(3, CutOsovecClient)
timer.Simple(6, CutOsovecClient)
timer.Simple(10, CutOsovecClient)

-- после каждого приёма фракций с сервера (P11FW_FactionsSync →
-- RegisterCustomFactions) — повторно чистим osowiec (обёртка)
if P11FW and P11FW.RegisterCustomFactions then
    local origF = P11FW.RegisterCustomFactions
    P11FW.RegisterCustomFactions = function(records)
        local out = {}
        for _, rec in ipairs(istable(records) and records or {}) do
            if not (rec and rec.id == "osowiec") then out[#out + 1] = rec end
        end
        return origF(out)
    end
end

print("[POLUS-11] v5.8.15: категория «Осовец» убрана из F4 на клиенте")
