include("shared.lua")

surface.CreateFont("P11FW.NPC.Big",   { font = "Roboto", size = 40, weight = 800, extended = true })
surface.CreateFont("P11FW.NPC.Small", { font = "Roboto", size = 26, weight = 500, extended = true })

-- ============================================================
--  v4.2.1 HOTFIX: кадровик больше НЕ спамит ошибками.
--  Причина x2382: в GMod НЕ СУЩЕСТВУЕТ метода
--  GetPoseParameterIndex — старый код звал пустоту каждый
--  Think. Правильный API:
--      ent:GetPoseParameter("head_yaw")  → индекс (или -1)
--      ent:SetPoseParameter(индекс, значение)
--  Индексы ищем ОДИН раз и кешируем. Если у выбранной
--  модели нет head_yaw/head_pitch — слежение мягко
--  отключается: никаких ошибок, никакого спама.
--  Любая прочая ошибка → kill-switch: один лог в консоль
--  и тихая работа дальше.
-- ============================================================

local HEAD_BONE = "ValveBiped.Bip01_Head1"

function ENT:Initialize()
    self.P11_HeadY, self.P11_HeadP = 0, 0
    self.P11_YawId,  self.P11_PitId = nil, nil
    self.P11_PoseTries = 0
    self.P11_PoseDead  = false -- модель не умеет крутить голову
    self.P11_ThinkDead = false -- kill-switch на любую ошибку
    -- запускаем цепочку клиентских Think явно: без первого
    -- SetNextClientThink Think на клиенте может не стартовать вовсе
    if self.SetNextClientThink then
        self:SetNextClientThink(CurTime() + 0.2)
    end
end

-- одноразовый (и терпеливый) поиск pose-параметров головы
local function ResolvePose(self)
    if self.P11_PoseDead then return end
    if self.P11_YawId ~= nil and self.P11_PitId ~= nil then return end

    self.P11_PoseTries = (self.P11_PoseTries or 0) + 1

    if self.P11_YawId == nil and self.GetPoseParameter then
        local ok, idx = pcall(self.GetPoseParameter, self, "head_yaw")
        if ok and isnumber(idx) and idx >= 0 then self.P11_YawId = idx end
    end
    if self.P11_PitId == nil and self.GetPoseParameter then
        local ok, idx = pcall(self.GetPoseParameter, self, "head_pitch")
        if ok and isnumber(idx) and idx >= 0 then self.P11_PitId = idx end
    end

    -- ~4 секунды не нашли — у модели просто нет этих костей; живём без слежения
    if self.P11_PoseTries >= 40 and self.P11_YawId == nil then
        self.P11_PoseDead = true
    end
end

local function ThinkHead(self)
    local me = LocalPlayer()
    if not IsValid(me) or not me.EyePos then return end

    ResolvePose(self)
    if self.P11_PoseDead then return end

    -- цель: ближайший живой игрок в радиусе; нет цели — голова в нейтраль
    local wantYaw, wantPit = 0, 0
    if me:Alive() and me:GetPos():DistToSqr(self:GetPos()) < 420 * 420 then
        local headPos = nil
        if self.LookupBone then
            local bone = self:LookupBone(HEAD_BONE)
            if bone and bone >= 0 and self.GetBonePosition then
                headPos = self:GetBonePosition(bone)
            end
        end
        if not headPos then headPos = self:GetPos() + Vector(0, 0, 64) end

        local worldAng = (me:EyePos() - headPos):Angle()
        local localAng = self:WorldToLocalAngles(worldAng)
        wantYaw = math.Clamp(math.NormalizeAngle(localAng.y), -75, 75)
        wantPit = math.Clamp(math.NormalizeAngle(localAng.p), -40, 40)
    end

    -- плавное наведение (кадр ограничен — на лагах не «прыгает»)
    local ft = math.Clamp(FrameTime(), 0.001, 0.1)
    self.P11_HeadY = Lerp(ft * 5, self.P11_HeadY or 0, wantYaw)
    self.P11_HeadP = Lerp(ft * 5, self.P11_HeadP or 0, wantPit)

    if self.P11_YawId ~= nil then self:SetPoseParameter(self.P11_YawId, self.P11_HeadY) end
    if self.P11_PitId ~= nil then self:SetPoseParameter(self.P11_PitId, self.P11_HeadP) end
    if self.InvalidateBoneCache then self:InvalidateBoneCache() end
end

function ENT:Think()
    if not self.P11_ThinkDead then
        local ok, err = pcall(ThinkHead, self)
        if not ok then
            self.P11_ThinkDead = true -- больше НИ ОДНОЙ ошибки из этого файла
            print("[POLUS][WARN] кадровик: слежение головой отключено: " .. tostring(err))
        end
    end
    if self.SetNextClientThink then
        self:SetNextClientThink(CurTime() + 0.05)
    end
    return true
end

function ENT:Draw()
    self:DrawModel()

    -- табличка над головой: сбой здесь тоже не имеет права спамить
    if (self.P11_DrawOff or 0) >= 2 then return end
    local ok, err = pcall(function()
        local me = LocalPlayer()
        if not IsValid(me) then return end
        if me:GetPos():DistToSqr(self:GetPos()) > 550 * 550 then return end

        local npcName = "КАДРОВЫЙ ОТДЕЛ"
        if P11FW and P11FW.Config and P11FW.Config.NPCName then
            npcName = tostring(P11FW.Config.NPCName)
        end

        local pos = self:GetPos() + Vector(0, 0, 84)
        local ang = Angle(0, (me:EyePos() - pos):Angle().y - 90, 90)

        cam.Start3D2D(pos, ang, 0.09)
            draw.SimpleTextOutlined(npcName, "P11FW.NPC.Big", 0, 0,
                Color(255, 210, 110, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
            draw.SimpleTextOutlined("[ E ] — устроиться на должность", "P11FW.NPC.Small", 0, 46,
                Color(200, 230, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
            -- «ОСОБАЯ ВАКАНСИЯ» — пульсирующая строка, пока окно открыто
            if GetGlobalFloat("P11_ThingOfferUntil", 0) > CurTime() then
                local k = 0.6 + math.sin(CurTime() * 6) * 0.4
                draw.SimpleTextOutlined("⚠ ОСОБАЯ ВАКАНСИЯ — успей нажать [ E ]", "P11FW.NPC.Small", 0, 92,
                    Color(255, 80 + 60 * k, 60 + 40 * k, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 230))
            end
        cam.End3D2D()
    end)
    if not ok then
        self.P11_DrawOff = (self.P11_DrawOff or 0) + 1
        print("[POLUS][WARN] кадровик: табличка над головой отключена: " .. tostring(err))
    else
        self.P11_DrawOff = 0
    end
end
