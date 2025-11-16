-- CleanCooldownManager.lua

-- SavedVariables
CleanCooldownManagerDB = CleanCooldownManagerDB or {}

-- Local variables
local useBorders = false

local addon = CreateFrame("Frame")
addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")

local function RemovePadding(viewer)
    -- Don't apply modifications in edit mode
    if EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() then
        return
    end
    
    local children = {viewer:GetChildren()}
    
    -- Get the visible icons (because they're fully dynamic)
    local visibleChildren = {}
    for _, child in ipairs(children) do
        if child:IsShown() then
            -- Store original position for sorting
            local point, relativeTo, relativePoint, x, y = child:GetPoint(1)
            child.originalX = x or 0
            child.originalY = y or 0
            table.insert(visibleChildren, child)
        end
    end
    
    if #visibleChildren == 0 then return end
    
    -- Sort by original position to maintain Blizzard's order
    local isHorizontal = viewer.isHorizontal
    if isHorizontal then
        -- Sort left to right, then top to bottom
        table.sort(visibleChildren, function(a, b)
            if math.abs(a.originalY - b.originalY) < 1 then
                return a.originalX < b.originalX
            end
            return a.originalY > b.originalY
        end)
    else
        -- Sort top to bottom, then left to right
        table.sort(visibleChildren, function(a, b)
            if math.abs(a.originalX - b.originalX) < 1 then
                return a.originalY > b.originalY
            end
            return a.originalX < b.originalX
        end)
    end
    
    -- Get layout settings from the viewer
    local stride = viewer.stride or #visibleChildren
    local iconOpacity = math.min(1, (viewer.iconScale or 1) + 0.2) -- Border is 20% more opaque than the configured Icon Opacity
    
    -- CONFIGURATION OPTIONS:
    local overlap = useBorders and 0 or -3 -- No overlap when using borders
    local iconScale = 1.15 -- Scale for icons
    
    -- Scale the icons to overlap and hide the transparent borders baked into the textures
    for _, child in ipairs(visibleChildren) do
        if child.Icon then
            child.Icon:ClearAllPoints()
            child.Icon:SetPoint("CENTER", child, "CENTER", 0, 0)
            child.Icon:SetSize(child:GetWidth() * iconScale, child:GetHeight() * iconScale)
        end
        
        -- Add black border if enabled
        if useBorders then
            if not child.border then
                child.border = child:CreateTexture(nil, "BACKGROUND")
                child.border:SetColorTexture(0, 0, 0, iconOpacity) -- Black with configured Opacity
                child.border:SetAllPoints(child)
            else
                child.border:SetAlpha(iconOpacity)
            end
            child.border:Show()
            
            -- Create inner frame to show border effect
            if not child.borderInset then
                child.borderInset = child:CreateTexture(nil, "BACKGROUND")
                child.borderInset:SetColorTexture(0, 0, 0, iconOpacity)
                child.borderInset:SetPoint("TOPLEFT", child, "TOPLEFT", 1, -1)
                child.borderInset:SetPoint("BOTTOMRIGHT", child, "BOTTOMRIGHT", -1, 1)
            else
                child.borderInset:SetAlpha(iconOpacity)
            end
            child.borderInset:Show()
        else
            -- Hide borders if they exist
            if child.border then child.border:Hide() end
            if child.borderInset then child.borderInset:Hide() end
        end
    end
    
    -- Reposition buttons respecting orientation and stride
    local buttonWidth = visibleChildren[1]:GetWidth()
    local buttonHeight = visibleChildren[1]:GetHeight()
    
    -- Calculate grid dimensions
    local numIcons = #visibleChildren
    local totalWidth, totalHeight
    
    if isHorizontal then
        local cols = math.min(stride, numIcons)
        local rows = math.ceil(numIcons / stride)
        totalWidth = cols * buttonWidth + (cols - 1) * overlap
        totalHeight = rows * buttonHeight + (rows - 1) * overlap
    else
        local rows = math.min(stride, numIcons)
        local cols = math.ceil(numIcons / stride)
        totalWidth = cols * buttonWidth + (cols - 1) * overlap
        totalHeight = rows * buttonHeight + (rows - 1) * overlap
    end
    
    -- Calculate offsets to center the grid
    local startX = -totalWidth / 2
    local startY = totalHeight / 2
    
    if isHorizontal then
        -- Horizontal layout with wrapping
        for i, child in ipairs(visibleChildren) do
            local col = (i - 1) % stride
            local row = math.floor((i - 1) / stride)
            
            local xOffset = startX + col * (buttonWidth + overlap)
            local yOffset = startY - row * (buttonHeight + overlap)
            
            child:ClearAllPoints()
            child:SetPoint("CENTER", viewer, "CENTER", xOffset + buttonWidth/2, yOffset - buttonHeight/2)
        end
    else
        -- Vertical layout with wrapping
        for i, child in ipairs(visibleChildren) do
            local row = (i - 1) % stride
            local col = math.floor((i - 1) / stride)
            
            local xOffset = startX + col * (buttonWidth + overlap)
            local yOffset = startY - row * (buttonHeight + overlap)
            
            child:ClearAllPoints()
            child:SetPoint("CENTER", viewer, "CENTER", xOffset + buttonWidth/2, yOffset - buttonHeight/2)
        end
    end
end

local function ApplyModifications()
    local viewers = {
        _G.UtilityCooldownViewer,
        _G.EssentialCooldownViewer,
        _G.BuffCoolDownViewer
    }
    
    for _, viewer in ipairs(viewers) do
        if viewer then
            RemovePadding(viewer)
            
            -- Hook Layout to reapply when Blizzard updates
            if viewer.Layout then
                hooksecurefunc(viewer, "Layout", function()
                    C_Timer.After(0, function()
                        RemovePadding(viewer)
                    end)
                end)
            end
            
            -- Hook Show/Hide to reapply when icons appear/disappear
            local children = {viewer:GetChildren()}
            for _, child in ipairs(children) do
                child:HookScript("OnShow", function()
                    C_Timer.After(0, function()
                        RemovePadding(viewer)
                    end)
                end)
                child:HookScript("OnHide", function()
                    C_Timer.After(0, function()
                        RemovePadding(viewer)
                    end)
                end)
            end
        end
    end
end

local function LoadSettings()
    -- Load saved border preference
    if CleanCooldownManagerDB.useBorders ~= nil then
        useBorders = CleanCooldownManagerDB.useBorders
    end
end

local function SaveSettings()
    -- Save border preference
    CleanCooldownManagerDB.useBorders = useBorders
end

addon:SetScript("OnEvent", function(self, event, arg)
    if event == "ADDON_LOADED" and arg == "CleanCooldownManager" then
        LoadSettings()
    elseif event == "ADDON_LOADED" and arg == "Blizzard_CooldownManager" then
        C_Timer.After(0.5, ApplyModifications)
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(2, ApplyModifications)
    end
end)

-- Slash command
SLASH_CLEANCOOLDOWN1 = "/cleancooldownmanager"
SLASH_CLEANCOOLDOWN2 = "/ccm"
SlashCmdList["CLEANCOOLDOWN"] = function(msg)
    if msg == "rant" then
        print("I spent HOURS digging through the UI trying to identify the element controlling the padding... There isn't one...")
		print("The padding is a LIE! The padding is a LIE! The padding is a LIE! The padding is a LIE! The padding is a LIE! The padding is a LIE!")
		print("BIG ICONS ARE LYING TO YOU!!!!")
		print("The icons themselves have a 1px transparent edge. There IS NO PADDING!!!") 
		print("YOUR ICONS SIT ON A THRONE OF LIES!!!")
		print("But I fixed it anyway.")
		print(" - Peri")
	elseif msg == "borders" then
		useBorders = not useBorders
		SaveSettings()
		print("CleanCooldownManager: Borders " .. (useBorders and "enabled" or "disabled"))
		ApplyModifications()
    elseif msg == "reload" then
        ApplyModifications()
        print("Reapplied modifications")
    else
        print("CleanCooldownManager commands:")
        print("  /ccm rant - Get my thoughts")
		print("  /ccm borders - Toggle black borders (currently " .. (useBorders and "ON" or "OFF") .. ")")
        print("  /ccm reload - Reapply modifications")
    end
end
