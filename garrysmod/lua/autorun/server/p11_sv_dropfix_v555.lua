-- ============================================================
--  ПОЛЮС-11 — ФИКС util.DropToFloor (server) v5.5.5 (НОВЫЙ ФАЙЛ)
--  В GMod НЕТ функции util.DropToFloor — правильно ent:DropToFloor().
--  Весь проект зовёт util.DropToFloor(self) (dirt/terminal/jobnpc/
--  clue/dutynpc/...), из-за чего энтити падают при спавне:
--    [ERROR] .../polus_p11_dirt/init.lua:33: attempt to call field
--    'DropToFloor' (a nil value)
--  Старые файлы НЕ трогаем: доопределяем util.DropToFloor глобально,
--  он вызывает штатный метод ent:DropToFloor(). Чинит ВСЕ энтити.
-- ============================================================

if not util.DropToFloor then
    util.DropToFloor = function(ent)
        if IsValid(ent) and ent.DropToFloor then
            local ok = pcall(ent.DropToFloor, ent)
            if not ok then
                -- fallback: мягко опустить на 1 юнит (на случай отсутствия метода)
                ent:SetPos(ent:GetPos() - Vector(0, 0, 1))
            end
        end
    end
end

print("[POLUS-11] ФИКС util.DropToFloor v5.5.5 (server, autorun): все энтити больше не падают")
