-- objectives.lua
local TairUI = _G.TairUI
local config = TairUI.Config

local showSuperTracked = true
local showProximity = true
local useTairTracker = true

----------------------------------------
-- Objective Frame Class
----------------------------------------

local TairUI_ObjectiveFrame = {}
TairUI_ObjectiveFrame.__index = TairUI_ObjectiveFrame

function TairUI_ObjectiveFrame:new(index)
    local self = setmetatable({}, TairUI_ObjectiveFrame)
    self.index = index
    self.questId = 0
    self.objectiveFontStrings = {}
    self.cachedObjectives = {}
    self.cachedTitle = ""

    self.frame = CreateFrame("Frame", nil, TairUI_TrackerFrame)

    -- Mouse handling
    -- self.frame:EnableMouse(true)
    -- self.frame:SetScript("OnMouseUp", function(_, button)
    --     if InCombatLockdown() then
    --         print("Addon cannot access secure function in combat.")
    --         return
    --     end
    --     if button == "LeftButton" and self.questId and self.questId ~= 0 then
    --         QuestMapFrame_OpenToQuestDetails(self.questId)
    --     end
    -- end)
    -- Mouseover
    -- self.frame:SetScript("OnEnter", function()
    --     self.frame:SetAlpha(1)
    -- end)
    -- -- Mouseout
    -- self.frame:SetScript("OnLeave", function()
    --     self.frame:SetAlpha(config.frameAlpha)
    -- end)

    self.frame:SetSize(250, 0)
    self.frame:SetAlpha(config.frameAlpha)

    self.titleFontString = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.titleFontString:SetFont("Fonts\\FRIZQT__.TTF", config.titleFontSize, config.fontFlag)
    self.titleFontString:SetTextColor(config.titleColor.r, config.titleColor.g, config.titleColor.b, 1)
    self.titleFontString:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)
    self.titleFontString:SetShadowColor(0, 0, 0, config.shadowAlpha)

    return self
end

function TairUI_ObjectiveFrame:SetQuest(questID)
    self.questId = questID
    self:Update()
end

function TairUI_ObjectiveFrame:ClearObjectives()
    for _, fs in ipairs(self.objectiveFontStrings) do fs:Hide() end
    self.objectiveFontStrings = {}
end

function TairUI_ObjectiveFrame:GetContentHeight()
    local height = 0
    if self.titleFontString:IsShown() then
        height = height + self.titleFontString:GetStringHeight()
    end
    for _, fs in ipairs(self.objectiveFontStrings) do
        if fs:IsShown() and fs:GetText() ~= "" then
            height = height + fs:GetStringHeight() + config.lineSpacing
        end
    end
    return height
end

function TairUI_ObjectiveFrame:CreateObjectiveFontString(anchor, text, color)
    local fs = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetFont("Fonts\\FRIZQT__.TTF", config.objectiveFontSize, config.fontFlag)
    fs:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -config.lineSpacing)
    fs:SetTextColor(color.r, color.g, color.b, 1)
    fs:SetShadowColor(0, 0, 0, config.shadowAlpha)
    fs:SetText(text or "")
    fs:Show()
    table.insert(self.objectiveFontStrings, fs)
    return fs
end

function TairUI_ObjectiveFrame:Update()
    local newTitle = C_QuestLog.GetTitleForQuestID(self.questId) or "Unknown Quest"
    if newTitle ~= self.cachedTitle then
        self.titleFontString:SetText(newTitle)
        self.cachedTitle = newTitle
    end

    local objectives = C_QuestLog.GetQuestObjectives(self.questId)
    local changed = false

    if C_QuestLog.IsComplete(self.questId) then
        changed = (self.cachedObjectives[1] ~= "Ready for turn-in")
        if changed then
            self:ClearObjectives()
            self:CreateObjectiveFontString(self.titleFontString, "Ready for turn-in", config.completeColor)
            self.cachedObjectives = { "Ready for turn-in" }
        end
    elseif objectives then
        if #objectives ~= #self.cachedObjectives then
            changed = true
        else
            for i, obj in ipairs(objectives) do
                local key = (obj.text or "") .. (obj.finished and "1" or "0")
                if self.cachedObjectives[i] ~= key then
                    changed = true
                    break
                end
            end
        end

        if changed then
            self:ClearObjectives()
            local lastAnchor = self.titleFontString
            self.cachedObjectives = {}
            for _, obj in ipairs(objectives) do
                local color = obj.finished and config.completeColor or config.incompleteColor
                lastAnchor = self:CreateObjectiveFontString(lastAnchor, obj.text, color)
                table.insert(self.cachedObjectives, (obj.text or "") .. (obj.finished and "1" or "0"))
            end
        end
    end

    self.frame:SetHeight(self:GetContentHeight())
end