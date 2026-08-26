AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("P11FW_OpenMenu")

-- ============================================================
--  v4.2.3 КАДРОВИК: усиленная починка «T-pose / не меняется
--  модель / E не срабатывает».
--   • стойка ищется перебором АКТИВНОСТЕЙ и известных имён
--     секвенсов; найденная запоминается и ПЕРЕПРИМЕНЯЕТСЯ,
--     если что-то её сбило (ни один кадр T-pose не доживает
--     дольше полсекунды);
--   • модель можно поменять В ИГРЕ: p11_npcmodel "путь/к/модели"
--     (админам; сохраняется в data и подхватывается при старте);
--   • E продублирован ТРЕМЯ путями: движковый Use, KeyPress
--     по прицелу и KeyPress по БЛИЗОСТИ+взгляду (запасной
--     вариант для кривой физики).
-- ============================================================

local IDLE_ACTS = { ACT_IDLE, ACT_IDLE_ANGRY, ACT_IDLE_STIMULATED, ACT_IDLE_RELAXED }
local IDLE_SEQS = { "idle_all_01", "idle_all_02", "idle_subtle", "idle", "menu_combine" }

local function ResolveIdleSeq(self)
    for _, act in ipairs(IDLE_ACTS) do
        local ok, seq = pcall(self.SelectWeightedSequence, self, act)
        if ok and seq and seq > 0 then return seq end
    end
    for _, name in ipairs(IDLE_SEQS) do
        local ok, seq = pcall(self.LookupSequence, self, name)
        if ok and seq and seq >= 0 then return seq end
    end
    return 0
end

local function NpcModel()
    -- живая замена из консоли админа важнее конфига
    local saved = file.Read("polus_framework/npc_model.txt", "DATA")
    if isstring(saved) and saved ~= "" and file.Exists(saved, "GAME") then
        return saved
    end
    local cfg = (P11FW and P11FW.Config) or {}
    local model = cfg.NPCModel or "models/player/barney.mdl"
    if not file.Exists(model, "GAME") then
        model = "models/player/barney.mdl"
    end
    return model
end

function ENT:Initialize()
    self:SetModel(NpcModel())

    self:SetHullType(HULL_HUMAN)
    self:SetHullSizeNormal()
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false)
        phys:SetMass(90)
    end

    util.DropToFloor(self)

    -- тело держим ровно как поставили (крутится только голова — клиент)
    self.P11_BaseYaw = self:GetAngles().y

    self:ApplyIdle()

    self.NextGaze = 0
end

-- применить стойку (и запомнить её индекс)
function ENT:ApplyIdle()
    local seq = ResolveIdleSeq(self)
    self.P11_IdleSeq = seq
    self:ResetSequence(seq)
    self:SetCycle(math.Rand(0, 1))
    self:SetPlaybackRate(1)
    self.AutomaticFrameAdvance = true -- анимация играет сама (без T-pose)
end

function ENT:Think()
    self.NextGaze = tonumber(self.NextGaze) or 0
    if CurTime() >= self.NextGaze then
        self.NextGaze = CurTime() + 0.5

        -- v4.2.3: что бы ни сбило стойку — вернуть её (нет шансов у T-pose)
        if self.GetSequence and self.P11_IdleSeq ~= nil then
            local ok, cur = pcall(self.GetSequence, self)
            if ok and cur ~= self.P11_IdleSeq then
                self:ResetSequence(self.P11_IdleSeq)
                self:SetPlaybackRate(1)
            end
        end

        -- держим корпус на базовом угле (клиент крутит только голову)
        local a = self:GetAngles()
        if math.abs(math.AngleDifference(a.y, self.P11_BaseYaw or a.y)) > 0.5 then
            self:SetAngles(Angle(0, self.P11_BaseYaw or a.y, 0))
        end
    end
    self:NextThink(CurTime() + 0.5)
    return true
end

local function OpenJobMenu(self, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if ply:GetPos():DistToSqr(self:GetPos()) > 190 * 190 then return end
    if (ply.P11_NpcUse or 0) > CurTime() then return end
    ply.P11_NpcUse = CurTime() + 1

    net.Start("P11FW_OpenMenu")
    net.Send(ply)
    self:EmitSound("buttons/button9.wav", 55, 100)
end

function ENT:Use(activator)
    OpenJobMenu(self, activator)
end

-- ЗАПАСНЫЕ ПУТИ: 2) E при прицеле; 3) E рядом + смотрит на кадровика
hook.Add("KeyPress", "P11FW.JobNpcE", function(ply, key)
    if key ~= IN_USE then return end

    local tr = ply:GetEyeTrace()
    local ent = tr.Entity
    if IsValid(ent) and ent:GetClass() == "polus_fw_jobnpc" then
        OpenJobMenu(ent, ply)
        return
    end

    -- близко + взгляд в его сторону (если прицел «промахнулся» мимо физики)
    local eye = ply:EyePos()
    local fwd = ply:GetAimVector()
    for _, npc in ipairs(ents.FindInSphere(ply:GetPos(), 150)) do
        if IsValid(npc) and npc:GetClass() == "polus_fw_jobnpc" then
            local toHim = (npc:WorldSpaceCenter() - eye)
            local dist = toHim:Length()
            if dist < 165 then
                toHim:Normalize()
                if toHim:Dot(fwd) > 0.72 then
                    OpenJobMenu(npc, ply)
                    return
                end
            end
        end
    end
end)

-- ============================================================
--  ЖИВАЯ СМЕНА МОДЕЛИ: p11_npcmodel "models/....mdl"
--  (админ; сохраняется навсегда в data/polus_framework/npc_model.txt)
-- ============================================================
concommand.Add("p11_npcmodel", function(ply, cmd, args)
    if IsValid(ply) and not (P11FW and P11FW.Config and P11FW.Config.Admin(ply)) then return end
    local mdl = tostring(args[1] or "")
    if mdl == "" then
        if IsValid(ply) then ply:ChatPrint("[P11FW] p11_npcmodel \"models/путь/к/модели.mdl\" | сброс: p11_npcmodel reset") end
        return
    end
    if mdl == "reset" then
        if file.Exists("polus_framework/npc_model.txt", "DATA") then file.Delete("polus_framework/npc_model.txt") end
        mdl = ((P11FW and P11FW.Config) or {}).NPCModel or "models/player/barney.mdl"
    end
    if not file.Exists(mdl, "GAME") then
        if IsValid(ply) then ply:ChatPrint("[P11FW] Такой модели нет на сервере: " .. mdl) end
        return
    end

    file.Write("polus_framework/npc_model.txt", mdl)

    for _, e in ipairs(ents.FindByClass("polus_fw_jobnpc")) do
        e:SetModel(mdl)
        if e.ApplyIdle then e:ApplyIdle() end
    end

    local msg = "[P11FW] Модель кадровика: " .. mdl .. " (сохранено)"
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)
