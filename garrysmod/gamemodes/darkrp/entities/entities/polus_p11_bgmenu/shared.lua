ENT.Type            = "point"
ENT.Base            = "base_point"
ENT.PrintName       = "BodyGroups v5.7.7 (служебная, не спавнить)"
ENT.Author          = "POLUS-11"
ENT.Category        = "ПОЛЮС-11"
ENT.Spawnable       = false
ENT.AdminSpawnable  = false

-- v5.8.24: регистрация net-канала ДУБЛИРОВАНА сюда (shared энтити
-- грузится на сервере через init.lua энтити — гарантированно).
-- Раньше жила только в lua/autorun/server/p11_sv_bgmenu_spawn_v577.lua;
-- если тот файл не доезжал до сервера (старая установка/конфликт
-- папок) — клиент получал «unpooled message name» при каждом клике
-- в меню бодигрупп.
if SERVER then
    util.AddNetworkString("P11_BGSet")
end
