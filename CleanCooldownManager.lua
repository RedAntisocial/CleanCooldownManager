-- CleanCooldownManager.lua
-- Local variables

local addon = CreateFrame("Frame")


-- Register Events
addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Strips the borders and edges off the buttons. Doesn't strip anything inappropriate
local function CleanButtons(button)
    if button.Border then button.Border:Hide() end
    if button.NormalTexture then button.NormalTexture:SetTexture(nil) end
    if button.PushedTexture then button.PushedTexture:SetTexture(nil) end
    if button.HighlightTexture then button.HighlightTexture:SetTexture(nil) end
    if button.IconMask then button.IconMask:Hide() end
end

-- Strips the borders from the containers
local function RemoveBorders(container)
    if container.EnumerateFrames then
        for _, child in container:EnumerateFrames() do
            CleanButtons(child)
        end
    end

    hooksecurefunc(container, "AddFrame", function(self, frame)
        CleanButtons(frame)
    end)
end

-- Does what it says on the tin. And the original driver for this addon.
local function ApplyZeroPadding(container)
    if container.SetSpacing then
        container:SetSpacing(0)
    end

    hooksecurefunc(container, "SetSpacing", function(self, spacing)
        if spacing ~= 0 then
            rawset(self, "spacing", 0)
        end
    end)
end

-- Centered growth for the bar layout. Also, the most likely part of the addon to break.
local function CenterGrowLayout(self)
    local children = self:GetLayoutChildren()
    local count = #children
    if count == 0 then return end

    local totalWidth = 0
    for i, child in ipairs(children) do
        totalWidth = totalWidth + child:GetWidth()
    end

    local spacing = 0
    totalWidth = totalWidth + (count - 1) * spacing

    local startX = -totalWidth / 2

    local x = startX
    for _, child in ipairs(children) do
        child:ClearAllPoints()
        child:SetPoint("CENTER", self, "CENTER", x + child:GetWidth()/2, 0)
        x = x + child:GetWidth() + spacing
    end
end

-- Blizzard likes to refresh the layout on load or once you open edit mode.
local function OverrideCenteredGrowLayout(container)
    container.LayoutChildren = CenterGrowLayout
    container:MarkDirty()
end

local function ApplyModifications()
    if not CooldownManager or not CooldownManager.Container then
        return
    end

    local container = CooldownManager.Container

    ApplyZeroPadding(container)
    RemoveBorders(container)
    OverrideCenteredGrowLayout(container)
end

addon:SetScript("OnEvent", function(self, event, arg)
    if event == "ADDON_LOADED" and arg == "Blizzard_CooldownManager" then
        ApplyModifications()
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, ApplyModifications)
    end
end)
