-- TairUI Objective Tracker
-- A minimalist quest tracking frame designed to emphasize immersion and reduce clutter.

-- Fetch the TairUI addon namespace if it exists.
local addonName = ...
local TairUI = _G.TairUI or {}

-- Load configuration from the global TairUI table if present, or fallback to Blizzard UI-friendly defaults.

local _, defaultSize = GameFontNormal:GetFont()
defaultSize = defaultSize or 12 

local baseConfig = TairUI.Config or {
    Layout = { edgeMargin = 20 },
    General = {
        HUDTextGapLarge = 16,
        HUDTextGap = 8,
        HUDTextAlpha = 1,
        HUDTitleSize = defaultSize + 3 or 15,
        HUDTextSize = defaultSize or 12,
        HUDTextShadowAlpha = 1,
        HUDTextFlags = "",
    },
    Colors = {
        ui = {
            gold = { r = 1, g = 0.82, b = 0 },
            light_gray = { r = 0.75, g = 0.75, b = 0.75 },
            med_gray = { r = 0.66, g = 0.66, b = 0.66 },
            white = { r = 1, g = 1, b = 1 },
        }
    }
}

-- Derive working config for the tracker's layout and appearance
local config = {
    marginX = baseConfig.Layout.edgeMargin * -1,
    marginY = baseConfig.Layout.edgeMargin * -1,
    vPadding = 0,
    hPadding = 0,
    questSpacing = 12,
    lineSpacing = baseConfig.General.HUDTextGap,
    maxQuests = 6,
    shadowAlpha = 1,
    frameAlpha = 1,
    titleFontSize = baseConfig.General.HUDTitleSize,
    objectiveFontSize = baseConfig.General.HUDTextSize,
    fontFace = "Fonts\\FRIZQT__.TTF",
    fontFlag = "",
    titleColor = baseConfig.Colors.ui.gold,
    completeColor = baseConfig.Colors.ui.med_gray,
    incompleteColor = baseConfig.Colors.ui.white,
}

local useGradient = TairUI.Config or false

if useGradient then
    config.vPadding = 12
    config.hPadding = TairUI.Config.Layout.edgeMargin
end

-- Working feature flags
local showSuperTracked = true
local showProximity = true
local useTairTracker = true

----------------------------------------
-- Objective Frame Class
----------------------------------------

local TairUI_ObjectiveFrame = {}
TairUI_ObjectiveFrame.__index = TairUI_ObjectiveFrame

-- Create an objective frame that draws an objective title and series of objectives
function TairUI_ObjectiveFrame:new(index)

    local self = setmetatable({}, TairUI_ObjectiveFrame)
    self.index = index
    self.questId = 0
    self.objectiveFontStrings = {}
    self.cachedObjectives = {}
    self.cachedTitle = ""

    self.frame = CreateFrame("Frame", nil, TairUI.Tracker.frame)

    self.frame:SetSize(250, 0)
    self.frame:SetAlpha(config.frameAlpha)

    self.titleFontString = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.titleFontString:SetFont(config.fontFace, config.titleFontSize, config.fontFlag)
    self.titleFontString:SetTextColor(config.titleColor.r, config.titleColor.g, config.titleColor.b, 1)
    self.titleFontString:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, o)
    self.titleFontString:SetJustifyV("MIDDLE")
    self.titleFontString:SetShadowColor(0, 0, 0, config.shadowAlpha)

    -- Create a new heads up frame to display latest objectives
    self.latestObjectiveFrame = CreateFrame("Frame", nil, UIParent)
    self.latestObjectiveFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    self.latestObjectiveText = self.latestObjectiveFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.latestObjectiveText:SetFont(config.fontFace, config.titleFontSize + 4, "OUTLINE")
    self.latestObjectiveText:SetTextColor(config.incompleteColor.r, config.incompleteColor.g, config.incompleteColor.b, 1)
    self.latestObjectiveText:SetShadowColor(0, 0, 0, config.shadowAlpha)
    self.latestObjectiveText:SetPoint("CENTER", latestObjectiveFrame, "CENTER", 0, 100)
    -- self.latestObjectiveText:SetText("Test")

    return self
end

-- Set the objective frame's quest id
function TairUI_ObjectiveFrame:SetQuest(questID)
    self.questId = questID
    self.cachedObjectives = {}
    self:Update()
end

-- Clear the objecive frame's objective strings
function TairUI_ObjectiveFrame:ClearObjectives()
    for _, fs in ipairs(self.objectiveFontStrings) do fs:Hide() end
    self.objectiveFontStrings = {}
end

-- Auto calculate the height of the objective frame based on its contents
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

-- Auto calculate the width of the objective frame based on its contents
function TairUI_ObjectiveFrame:GetLongestStringWidth()
    local width = 0
    if self.titleFontString:IsShown() then
        local stringWidth = self.titleFontString:GetStringWidth()
        if stringWidth > width then width = stringWidth end
    end
    for _, fs in ipairs(self.objectiveFontStrings) do
        if fs:IsShown() and fs:GetText() ~= "" then
            local stringWidth = fs:GetStringWidth()
            if stringWidth > width then width = stringWidth end
        end
    end
    return width
end

-- Create a fontstring for an objective string (e.g. 'Kill bats 1/1')
function TairUI_ObjectiveFrame:CreateObjectiveFontString(anchor, text, color)
    local fs = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetFont(config.fontFace, config.objectiveFontSize, config.fontFlag)
    fs:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -config.lineSpacing)
    fs:SetTextColor(color.r, color.g, color.b, 1)
    fs:SetShadowColor(0, 0, 0, config.shadowAlpha)
    fs:SetText(text or "")
    fs:Show()
    table.insert(self.objectiveFontStrings, fs)
    return fs
end

-- Update handler for the objective frame
function TairUI_ObjectiveFrame:Update()
    local isWorldQuest = C_TaskQuest.IsActive(self.questId)
    local newTitle
    local objectives
    local changed = false

    if isWorldQuest then
        newTitle = C_TaskQuest.GetQuestInfoByQuestID(self.questId) or "World Quest"
        -- World quests still pull objectives from C_QuestLog
        objectives = C_QuestLog.GetQuestObjectives(self.questId)
    else
        newTitle = C_QuestLog.GetTitleForQuestID(self.questId) or "Unknown Quest"
        objectives = C_QuestLog.GetQuestObjectives(self.questId)
    end

    if newTitle ~= self.cachedTitle then
        self.titleFontString:SetText(newTitle)
        self.cachedTitle = newTitle
    end

    -- add new world quest support
    if isWorldQuest then
        if objectives and #objectives > 0 then
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
    else
        -- existing logic for regular quests
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
    end

    self.frame:SetHeight(self:GetContentHeight())
    self.frame:SetWidth(self:GetLongestStringWidth())
end

----------------------------------------
-- Tracker Frame Class
----------------------------------------

local TairUI_Tracker = {}
TairUI_Tracker.__index = TairUI_Tracker

-- Create the parent tracker frame to hold the objective frames
function TairUI_Tracker:new()
    local self = setmetatable({}, TairUI_Tracker)
    self.frame = CreateFrame("Frame", nil, UIParent)
    self.frame:SetSize(200, 300)
    self.frame:SetPoint("TOP", Minimap, "BOTTOM", 0, config.marginY)
    self.frame:SetPoint("RIGHT", UIParent, "RIGHT", 0, 0)

    if useGradient then
        local color1 = TairUI.getColor("ui", "gradient1")
        local color2 = TairUI.getColor("ui", "gradient2")
        self.background = self.frame:CreateTexture()
        self.background:SetAllPoints()
        self.background:SetColorTexture(color1.r, color1.g, color1.b, color1.a)
        self.background:SetGradient("HORIZONTAL", color2, color1)
    end
    
    self.useTairTracker = true
    self.toggleDeferred = false
    self.hideDeferred = false
    self.questFrames = {}

    self.lastLayoutHeight = 0
    self.lastLayoutWidth = 0
    self.lastLayoutQuestCount = 0

    self:InitializeModes()
    self:RegisterEvents()

    return self
end

-- Register the events associated with the tracker frame
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
        "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    }

    for _, e in ipairs(events) do
        self.frame:RegisterEvent(e)
    end
end

-- Event handling for the tracker frame
function TairUI_Tracker:OnEvent(event, ...)
    self:UpdateTrackedQuests()
end

-- Mass hide any objective frames
function TairUI_Tracker:ClearAndHideAllQuestFrames()
    for _, frame in ipairs(self.questFrames) do frame.frame:Hide() end
end

-- Mode system: open worlds, dungeons, etc.
function TairUI_Tracker:InitializeModes()
    self.modes = {
        ["open_world"] = function() self:UpdateOpenWorld() end,
        ["delve"] = function() self:UpdateDelve() end,
        ["event"] = function() self:UpdateEvent() end,
    }
end

-- Returns the current mode based on in-game context
function TairUI_Tracker:GetCurrentMode()
    if C_Scenario.IsInScenario() then return "delve" end
    return "open_world"
end

-- Update the quests we're currently tracking
function TairUI_Tracker:UpdateTrackedQuests()
    self:StartLayout()
    local mode = self:GetCurrentMode()
    if self.modes[mode] then self.modes[mode]() end
    self:FinalizeLayout()
end

-- Begin building the frame layout
function TairUI_Tracker:StartLayout()
    self:ClearAndHideAllQuestFrames()
    self.currentIndex = 1
    self.lastAnchor = nil
    self.shownQuests = {} -- track shown quests for deduplication
end

-- Finalize the tracker layout on update
function TairUI_Tracker:FinalizeLayout()
    local totalHeight = 0
    local maxWidth = 0
    local shownCount = 0

    for _, frame in ipairs(self.questFrames) do
        if frame.frame:IsShown() then
            shownCount = shownCount + 1
            totalHeight = totalHeight + frame.frame:GetHeight()
            maxWidth = math.max(maxWidth, frame.frame:GetWidth())
            if shownCount > 1 then
                totalHeight = totalHeight + config.questSpacing
            end
        end
    end

    totalHeight = totalHeight + (config.vPadding * 2)

    -- Skip if layout hasn’t changed
    if self.lastLayoutHeight == totalHeight and
       self.lastLayoutWidth == maxWidth and
       self.lastLayoutQuestCount == shownCount then
        return
    end

    self.lastLayoutHeight = totalHeight
    self.lastLayoutWidth = maxWidth
    self.lastLayoutQuestCount = shownCount

    -- Update layout   
    if shownCount == 0 then
        self.frame:Hide()
    else
        self.frame:SetWidth(maxWidth + (config.hPadding * 2 ))
        self.frame:SetHeight(totalHeight)
        self.frame:Show()
    end
    
end

-- Append a header (title) frame
function TairUI_Tracker:AppendHeader(title)
    local frame = self.questFrames[self.currentIndex] or TairUI_ObjectiveFrame:new(self.currentIndex)
    self.questFrames[self.currentIndex] = frame

    frame.titleFontString:SetText(title)
    frame.cachedTitle = title
    frame:ClearObjectives()
    frame.cachedObjectives = {}

    frame.frame:ClearAllPoints()
    if not self.lastAnchor then
        local y = -config.vPadding
        local x = -config.hPadding
        frame.frame:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", x, y)
    else
        local y = -config.lineSpacing
        local x = 0
        frame.frame:SetPoint("TOPRIGHT", self.lastAnchor.frame, "BOTTOMRIGHT", x, y)
    end

    frame.frame:SetHeight(frame:GetContentHeight())
    frame.frame:Show()
    self.lastAnchor = frame
    self.currentIndex = self.currentIndex + 1
end

-- Try to fetch and add scenario/dungeon/delve objecives (aka criteria)
function TairUI_Tracker:AppendScenarioObjectives()

    local frame = self.questFrames[self.currentIndex] or TairUI_ObjectiveFrame:new(self.currentIndex)
    self.questFrames[self.currentIndex] = frame

    -- Fetch the scenario and stage names
    local scenarioName = nil
    local scenarioInfo = C_ScenarioInfo.GetScenarioInfo()
    scenarioName = scenarioInfo and scenarioInfo.name

    local stepInfo = C_ScenarioInfo.GetScenarioStepInfo()
    local stageName = stepInfo and stepInfo.title

    -- Title
    local titleParts = {}
    if scenarioName then table.insert(titleParts, scenarioName) end
    if stageName then
        -- If the stage name is the same as the scenario (some dungeons), skip it
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

    -- Walk and fetch scenario objectives using the scenario API, currently C_ScenarioInfo
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

    -- Layout
    frame.frame:ClearAllPoints()
    if not self.lastAnchor then
        local y = -config.vPadding
        local x = -config.hPadding
        frame.frame:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", x, y)
    else
        local y = -config.lineSpacing
        local x = 0
        frame.frame:SetPoint("TOPRIGHT", self.lastAnchor.frame, "BOTTOMRIGHT", x, y)
    end

    frame.frame:SetHeight(frame:GetContentHeight())
    frame.frame:Show()

    -- Fall back to not displaying the quest if no objectives are defineds
    if not criteriaAdded then
        -- local fallbackText = "Scenario objective not defined"
        -- anchor = frame:CreateObjectiveFontString(anchor, fallbackTe
        frame.frame:Hide()
        return
    end

    -- local debugTexture = frame.frame:CreateTexture()
    -- debugTexture:SetAllPoints(frame.frame)
    -- debugTexture:SetColorTexture(0, 1, 0.5, 0.33) -- alpha to see any overlapping of frames

    self.lastAnchor = frame
    self.currentIndex = self.currentIndex + 1
end

-- Append the player's focused quest
function TairUI_Tracker:AppendSuperTrackedQuest()
    local questID = C_SuperTrack.GetSuperTrackedQuestID()
    if questID then self:ShowQuest(questID) end
end

-- Not used, but this should fetch any quests on the current map
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

-- Not used, but if we want to track *all* of the quests on the map
function TairUI_Tracker:AppendMapQuests()
    for _, questID in ipairs(self:GetMapQuests()) do
        if not self.shownQuests[questID] then
            self:ShowQuest(questID)
        end
    end
end

-- Try to parse out Blizzard's hidden quests
local function IsVisibleQuest(questID)
    if not questID then return end
    local index = C_QuestLog.GetLogIndexForQuestID(questID)
    if not index then return false end

    local title = C_QuestLog.GetTitleForQuestID(questID)
    if title == "Thanks for the Wax" then
        return false
    end

    local info = C_QuestLog.GetInfo(index)
    if not info then return false end

    return not info.isHidden and not info.isHeader and info.questID
end

-- Open world update routine
function TairUI_Tracker:UpdateOpenWorld()
    local shown = 0
    local superTracked = C_SuperTrack.GetSuperTrackedQuestID()

    -- If we are supertracking and the supertracked quest is a world quest or is a valid/visible quest, show it
    if superTracked then
        local isSuperTrackedWorldQuest = C_TaskQuest.IsActive(superTracked)
        if showSuperTracked then
            if isSuperTrackedWorldQuest or IsVisibleQuest(superTracked) then
                self:ShowQuest(superTracked)
                shown = shown + 1
            end
        end
    end

    -- Try to detect quests with objectives in the immediate area
    if showProximity then
        local quests = {}
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and info.isOnMap then
                local distSqr, onContinent = C_QuestLog.GetDistanceSqToQuest(info.questID)
                -- 100000 is arbitrary, this is all probably not ideal
                if distSqr and onContinent and distSqr <= 100000 and info.questID ~= superTracked then
                    table.insert(quests, {
                        questID = info.questID,
                        distSq = distSqr
                    })
                end
            end
        end

        -- Sort the quests by proximity to the player
        table.sort(quests, function(a, b) return a.distSq < b.distSq end)

        -- Iterate through and display the quests 
        for _, quest in ipairs(quests) do
            if shown >= config.maxQuests then break end
            self:ShowQuest(quest.questID)
            shown = shown + 1
        end
    end
end

-- Scenario (delve) update routine
function TairUI_Tracker:UpdateDelve()
    self:AppendScenarioObjectives()
    if showSuperTracked then self:AppendSuperTrackedQuest() end
end

-- Event update routine; seems like scenarios cover everything we need.
function TairUI_Tracker:UpdateEvent()
    print("Event mode not implemented.")
end

-- Function to display a quest on the tracker. We use an existing objective frame or create a new one if needed.
function TairUI_Tracker:ShowQuest(questID)
    if self.shownQuests[questID] then return end

    local title = C_QuestLog.GetTitleForQuestID(questID)
    if title == "Thanks for the Wax" then
        return
    end

    -- Allow supertracked quest even if invisible
    local isSupertracked = questID == C_SuperTrack.GetSuperTrackedQuestID()
    local isWorldQuest = C_TaskQuest.IsActive(questID)
    local visibleQuest = IsVisibleQuest(questID)

    if not isWorldQuest and not visibleQuest and not isSupertracked then
        return
    end

    self.shownQuests[questID] = true

    local quest = self.questFrames[self.currentIndex] or TairUI_ObjectiveFrame:new(self.currentIndex)
    self.questFrames[self.currentIndex] = quest
    quest:SetQuest(questID)

    quest.frame:ClearAllPoints()
    if not self.lastAnchor then
        local x = -config.hPadding
        local y = -config.vPadding
        quest.frame:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", x, y)
    else
        local x = 0
        local y = -config.questSpacing
        quest.frame:SetPoint("TOPRIGHT", self.lastAnchor.frame or self.lastAnchor, "BOTTOMRIGHT", x, y)
    end

    quest.frame:Show()
    self.lastAnchor = quest.frame
    self.currentIndex = self.currentIndex + 1
end

-- Hide the blizzard tracker. Out of combat only!
function TairUI_Tracker:HideBlizzardTracker()
    if InCombatLockdown() then
        self.hideDeferred = true
        print("TairUI: Switching tracker after combat...")
        return
    end
    ObjectiveTrackerFrame:Hide()
    ObjectiveTrackerFrame:SetAlpha(0)
end

-- Toggle our tracker. Out of combat only to avoid taint.
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

-- Slash command; type /tt to toggle trackers
SLASH_TAIRTRACKER1 = "/tt"
SlashCmdList["TAIRTRACKER"] = function()
    if TairUI.Tracker and TairUI.Tracker.Toggle then
        TairUI.Tracker:Toggle()
    else
        print("TairUI: Tracker toggle function not found.")
    end
end