-- tracker.lua
local TairUI = _G.TairUI
local config = TairUI.Config

----------------------------------------
-- TairUI_Tracker Class
----------------------------------------

local TairUI_Tracker = {}
TairUI_Tracker.__index = TairUI_Tracker

function TairUI_Tracker:new()
    local self = setmetatable({}, TairUI_Tracker)
    self.frame = CreateFrame("Frame", "TairUI_TrackerFrame", UIParent)
    self.frame:SetSize(200, 50)
    self.frame:SetPoint("TOPRIGHT", ObjectiveTrackerFrame, "TOPRIGHT", 0, 0)
    
    self.useTairTracker = true
    self.toggleDeferred = false
    self.hideDeferred = false
    self.questFrames = {}

    self:InitializeModes()
    self:RegisterEvents()

    return self
end

function TairUI_Tracker:RegisterEvents()
    self.frame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            self:HideBlizzardTracker()
        elseif event == "PLAYER_REGEN_ENABLED" then
            if self.toggleDeferred then
                self.toggleDeferred = false
                C_Timer.After(0.1, function() self:Toggle() end)
            elseif self.hideDeferred then
                self.hideDeferred = false
                C_Timer.After(0.1, function() self:HideBlizzardTracker() end)
            end
        else
            self:OnEvent(event, ...)
        end
    end)

    local events = {
        "QUEST_LOG_UPDATE", "QUEST_WATCH_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED",
        "QUEST_POI_UPDATE", "MAP_EXPLORATION_UPDATED", "ZONE_CHANGED_NEW_AREA",
        "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "SUPER_TRACKING_CHANGED",
        "ACTIVE_DELVE_DATA_UPDATE", "WALK_IN_DATA_UPDATE",
        "SCENARIO_UPDATE", "SCENARIO_CRITERIA_UPDATE", "SCENARIO_POI_UPDATE",
        "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", -- ⬅️ Just add them here
    }

    for _, e in ipairs(events) do
        self.frame:RegisterEvent(e)
    end
end

function TairUI_Tracker:OnEvent(event, ...)
    self:UpdateTrackedQuests()
end

function TairUI_Tracker:ClearAndHideAllQuestFrames()
    for _, frame in ipairs(self.questFrames) do frame.frame:Hide() end
end

function TairUI_Tracker:InitializeModes()
    self.modes = {
        ["open_world"] = function() self:UpdateOpenWorld() end,
        ["delve"] = function() self:UpdateDelve() end,
        ["event"] = function() self:UpdateEvent() end,
    }
end

function TairUI_Tracker:GetCurrentMode()
    if C_Scenario.IsInScenario() then return "delve" end
    return "open_world"
end

function TairUI_Tracker:UpdateTrackedQuests()
    self:StartLayout()
    local mode = self:GetCurrentMode()
    if self.modes[mode] then self.modes[mode]() end
    self:FinalizeLayout()
end

function TairUI_Tracker:StartLayout()
    self:ClearAndHideAllQuestFrames()
    self.currentIndex = 1
    self.lastAnchor = nil
    self.shownQuests = {} -- track shown quests for deduplication
end

function TairUI_Tracker:FinalizeLayout()
    -- Reserved for future layout adjustments
end

function TairUI_Tracker:AppendHeader(title)
    local frame = self.questFrames[self.currentIndex] or TairUI_ObjectiveFrame:new(self.currentIndex)
    self.questFrames[self.currentIndex] = frame

    frame.titleFontString:SetText(title)
    frame.cachedTitle = title
    frame:ClearObjectives()
    frame.cachedObjectives = {}

    frame.frame:ClearAllPoints()
    if not self.lastAnchor then
        frame.frame:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)
    else
        frame.frame:SetPoint("TOPRIGHT", self.lastAnchor.frame, "BOTTOMRIGHT", 0, -config.questSpacing)
    end

    frame.frame:SetHeight(frame:GetContentHeight())
    frame.frame:Show()
    self.lastAnchor = frame
    self.currentIndex = self.currentIndex + 1
end

function TairUI_Tracker:AppendScenarioObjectives()
    local frame = self.questFrames[self.currentIndex] or TairUI_ObjectiveFrame:new(self.currentIndex)
    self.questFrames[self.currentIndex] = frame

    -- Get scenario and stage names
    local scenarioName = nil
    local scenarioInfo = C_ScenarioInfo.GetScenarioInfo()
    scenarioName = scenarioInfo and scenarioInfo.name

    local stepInfo = C_ScenarioInfo.GetScenarioStepInfo()
    local stageName = stepInfo and stepInfo.title

    -- Title
    local titleParts = {}
    if scenarioName then table.insert(titleParts, scenarioName) end
    if stageName then
        -- If the stage name is the same as the scenario (some dungeons), don't add it
        if stageName ~= scenarioName then
            table.insert(titleParts, stageName)
        end
    end
    local fullTitle = #titleParts > 0 and table.concat(titleParts, ": ") or "Scenario"

    -- Frame
    frame.titleFontString:SetText(fullTitle)
    frame.cachedTitle = fullTitle
    frame:ClearObjectives()
    frame.cachedObjectives = {}

    local anchor = frame.titleFontString
    local criteriaAdded = false

    -- ✅ Use proper scenario step info API
    local numCriteria = stepInfo and stepInfo.numCriteria or 0

    for i = 1, numCriteria do
        local criteria = C_ScenarioInfo.GetCriteriaInfo(i)
        if criteria and criteria.description then
            local text
            if criteria.isWeightedProgress then
                local percent = math.floor(criteria.quantity)
                text = string.format("%s (%d%%)", criteria.description, percent)
            else
                text = string.format("%s (%d/%d)", criteria.description, criteria.quantity or 0, criteria.totalQuantity or 0)
            end
            local color = criteria.completed and config.completeColor or config.incompleteColor
            anchor = frame:CreateObjectiveFontString(anchor, text, color)
            table.insert(frame.cachedObjectives, text .. (criteria.completed and "1" or "0"))
            criteriaAdded = true
        end
    end

    -- Fallback to step description if no criteria shown
    if not criteriaAdded and stepInfo and stepInfo.description and stepInfo.description ~= "" then
        local fallback = stepInfo.description
        anchor = frame:CreateObjectiveFontString(anchor, fallback, config.incompleteColor)
        table.insert(frame.cachedObjectives, fallback .. "0")
        criteriaAdded = true
    end

    -- Final fallback
    if not criteriaAdded then
        local fallbackText = "Scenario objective not defined"
        anchor = frame:CreateObjectiveFontString(anchor, fallbackText, config.incompleteColor)
        table.insert(frame.cachedObjectives, fallbackText .. "0")
    end

    -- Layout
    frame.frame:ClearAllPoints()
    if not self.lastAnchor then
        frame.frame:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)
    else
        frame.frame:SetPoint("TOPRIGHT", self.lastAnchor.frame, "BOTTOMRIGHT", 0, -config.questSpacing)
    end

    frame.frame:SetHeight(frame:GetContentHeight())
    frame.frame:Show()

    self.lastAnchor = frame
    self.currentIndex = self.currentIndex + 1
end

function TairUI_Tracker:AppendSuperTrackedQuest()
    local questID = C_SuperTrack.GetSuperTrackedQuestID()
    if questID then self:ShowQuest(questID) end
end

function TairUI_Tracker:GetMapQuests()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return {} end
    local quests = C_QuestLog.GetQuestsOnMap(mapID) or {}
    local active = {}
    for _, q in ipairs(quests) do
        if q.inProgress then table.insert(active, q.questID) end
    end
    return active
end

function TairUI_Tracker:AppendMapQuests()
    for _, questID in ipairs(self:GetMapQuests()) do
        if not self.shownQuests[questID] then
            self:ShowQuest(questID)
        end
    end
end

local function IsVisibleQuest(questID)
    if not questID then return end
    local index = C_QuestLog.GetLogIndexForQuestID(questID)
    if not index then return false end

    local info = C_QuestLog.GetInfo(index)
    if not info then return false end

    return not info.isHidden and not info.isHeader and info.questID
end

function TairUI_Tracker:UpdateOpenWorld()
    local shown = 0
    local superTracked = C_SuperTrack.GetSuperTrackedQuestID()
    -- Only use it if it's visible in the log (and not a hidden server quest like 72560)
    if showSuperTracked and IsVisibleQuest(superTracked) then
        self:ShowQuest(superTracked)
        shown = shown + 1
    end

    if showProximity then
        local quests = {}
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and info.isOnMap then
                local distSqr, onContinent = C_QuestLog.GetDistanceSqToQuest(info.questID)
                if distSqr and onContinent and distSqr <= 100000 and info.questID ~= superTracked then
                    table.insert(quests, {
                        questID = info.questID,
                        distSq = distSqr
                    })
                end
            end
        end

        table.sort(quests, function(a, b) return a.distSq < b.distSq end)

        for _, quest in ipairs(quests) do
            if shown >= config.maxQuests then break end
            self:ShowQuest(quest.questID)
            shown = shown + 1
        end
    end
end

function TairUI_Tracker:UpdateDelve()
    self:AppendScenarioObjectives()
    if showSuperTracked then self:AppendSuperTrackedQuest() end
    -- if showDungeonQuests then self:AppendMapQuests() end
end

function TairUI_Tracker:UpdateEvent()
    print("Event mode not implemented.")
end

function TairUI_Tracker:ShowQuest(questID)
    if self.shownQuests[questID] then return end -- avoid duplicates
    self.shownQuests[questID] = true

    local frame = self.questFrames[self.currentIndex] or TairUI_ObjectiveFrame:new(self.currentIndex)
    self.questFrames[self.currentIndex] = frame
    frame:SetQuest(questID)

    frame.frame:ClearAllPoints()
    if not self.lastAnchor then
        frame.frame:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)
    else
        frame.frame:SetPoint("TOPRIGHT", self.lastAnchor.frame, "BOTTOMRIGHT", 0, -config.questSpacing)
    end

    frame.frame:SetHeight(frame:GetContentHeight())
    frame.frame:Show()

    self.lastAnchor = frame
    self.currentIndex = self.currentIndex + 1
end

function TairUI_Tracker:HideBlizzardTracker()
    if InCombatLockdown() then
        self.hideDeferred = true
        print("TairUI: Switching tracker after combat...")
        return
    end
    ObjectiveTrackerFrame:Hide()
    ObjectiveTrackerFrame:SetAlpha(0)
end

function TairUI_Tracker:Toggle()
    if InCombatLockdown() then
        self.toggleDeferred = true
        print("TairUI: Switching tracker after combat...")
        return
    end

    self.useTairTracker = not self.useTairTracker

    if self.useTairTracker then
        self:HideBlizzardTracker()
        self.frame:Show()
    else
        ObjectiveTrackerFrame:Show()
        ObjectiveTrackerFrame:SetAlpha(1)
        self.frame:Hide()
    end
end

----------------------------------------
-- Initialize
----------------------------------------

TairUI.Tracker = TairUI_Tracker:new()

SLASH_TAIRTRACKER1 = "/tt"
SlashCmdList["TAIRTRACKER"] = function()
    if TairUI.Tracker and TairUI.Tracker.Toggle then
        TairUI.Tracker:Toggle()
    else
        print("TairUI: Tracker toggle function not found.")
    end
end