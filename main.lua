-- main.lua
local addonName = ...
local TairUI = _G.TairUI or {}
_G.TairUI = TairUI 

local _, defaultTextSize = GameFontNormal:GetFont()
TairUI.Config = TairUI.Config or {
    Layout = { edgeMargin = 20 },
    General = {
        HUDTextGapLarge = 16,
        HUDTextGap = 8,
        HUDTextAlpha = 1,
        HUDTitleSize = defaultTextSize + 3 or 15,
        HUDTextSize = defaultTextSize or 12,
        HUDTextShadowAlpha = 1,
        HUDTextFlag = "",
    },
    Colors = {
        ui = {
            gold = { r = 1, g = 0.82, b = 0 },
            light_gray = { r = 0.75, g = 0.75, b = 0.75 },
            white = { r = 1, g = 1, b = 1 },
        }
    }
}
