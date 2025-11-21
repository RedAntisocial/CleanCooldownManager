-- CleanCooldownManager.lua
-- SavedVariables
CleanCooldownManagerDB = CleanCooldownManagerDB or {}

-- Local variables
local useBorders = false
local centerBuffs = true
local viewerSettings = {
    UtilityCooldownViewer = true,
    EssentialCooldownViewer = true,
    BuffIconCooldownViewer = true
    }
    
local addon = CreateFrame("Frame")
addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")

local viewerPending = {}
local updateBucket = {}

-- Core function to remove padding and apply modifications. Doing Blizzard's work for them.
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
    local isHorizontal = viewer.isHorizontal
    
    -- Skip repositioning for BuffIconCooldownViewer if centering is disabled
    if viewer == _G.BuffIconCooldownViewer and not centerBuffs then
        -- Still apply scaling and borders
        for _, child in ipairs(visibleChildren) do
            local iconAlpha = (child.Icon and child.Icon:GetAlpha()) or 1

            if child.Icon then
                child.Icon:ClearAllPoints()
                child.Icon:SetPoint("CENTER", child, "CENTER", 0, 0)
                child.Icon:SetSize(child:GetWidth() * (viewer.iconScale or 1), child:GetHeight() * (viewer.iconScale or 1))
                child.Icon:SetAlpha(iconAlpha)
            end

            if useBorders then
                local borderAlpha = math.min(1, iconAlpha + 0.05)
                if not child.border then
                    child.border = child:CreateTexture(nil, "BACKGROUND")
                    child.border:SetColorTexture(0, 0, 0, borderAlpha)
                    child.border:SetAllPoints(child)
                else
                    child.border:SetAlpha(borderAlpha)
                end
                child.border:Show()

                if not child.borderInset then
                    child.borderInset = child:CreateTexture(nil, "BACKGROUND")
                    child.borderInset:SetColorTexture(0, 0, 0, borderAlpha)
                    child.borderInset:SetPoint("TOPLEFT", child, "TOPLEFT", 1, -1)
                    child.borderInset:SetPoint("BOTTOMRIGHT", child, "BOTTOMRIGHT", -1, 1)
                else
                    child.borderInset:SetAlpha(borderAlpha)
                end
                child.borderInset:Show()
            else
                if child.border then child.border:Hide() end
                if child.borderInset then child.borderInset:Hide() end
            end
        end
        return
    end

    -- Sort by original position for all viewers
    if isHorizontal then
        table.sort(visibleChildren, function(a, b)
            if math.abs(a.originalY - b.originalY) < 1 then
                return a.originalX < b.originalX
            end
            return a.originalY > b.originalY
        end)
    else
        table.sort(visibleChildren, function(a, b)
            if math.abs(a.originalX - b.originalX) < 1 then
                return a.originalY > b.originalY
            end
            return a.originalX < b.originalX
        end)
    end
    
    -- Get layout settings from the viewer
    local stride = viewer.stride or #visibleChildren

	-- CONFIGURATION OPTIONS:
	local overlap = useBorders and 0 or -3 -- No overlap when using borders
	local iconScale = viewer.iconScale or 1

	-- Scale the icons and preserve actual alpha
	for _, child in ipairs(visibleChildren) do
		local iconAlpha = (child.Icon and child.Icon:GetAlpha()) or 1

		if child.Icon then
			child.Icon:ClearAllPoints()
			child.Icon:SetPoint("CENTER", child, "CENTER", 0, 0)
			child.Icon:SetSize(child:GetWidth() * iconScale, child:GetHeight() * iconScale)
			child.Icon:SetAlpha(iconAlpha)
		end

		if useBorders then
			local borderAlpha = math.min(1, iconAlpha + 0.05)
			if not child.border then
				child.border = child:CreateTexture(nil, "BACKGROUND")
				child.border:SetColorTexture(0, 0, 0, borderAlpha)
				child.border:SetAllPoints(child)
			else
				child.border:SetAlpha(borderAlpha)
			end
			child.border:Show()

			if not child.borderInset then
				child.borderInset = child:CreateTexture(nil, "BACKGROUND")
				child.borderInset:SetColorTexture(0, 0, 0, borderAlpha)
				child.borderInset:SetPoint("TOPLEFT", child, "TOPLEFT", 1, -1)
				child.borderInset:SetPoint("BOTTOMRIGHT", child, "BOTTOMRIGHT", -1, 1)
			else
				child.borderInset:SetAlpha(borderAlpha)
			end
			child.borderInset:Show()
		else
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
            local index = i - 1
            local row = math.floor(index / stride)
            local col = index % stride

            -- Determine number of icons in this row
            local rowStart = row * stride + 1
            local rowEnd = math.min(rowStart + stride - 1, numIcons)
            local iconsInRow = rowEnd - rowStart + 1

            -- Compute the actual width of this row
            local rowWidth = iconsInRow * buttonWidth + (iconsInRow - 1) * overlap

            -- Center this row
            local rowStartX = -rowWidth / 2

            -- Column offset inside centered row
            local xOffset = rowStartX + col * (buttonWidth + overlap)
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


local updaterFrame = CreateFrame("Frame")
updaterFrame:Hide()

updaterFrame:SetScript("OnUpdate", function()
    updaterFrame:Hide()

    for viewer in pairs(updateBucket) do
        updateBucket[viewer] = nil
        RemovePadding(viewer)
    end
end)

-- Schedule an update to apply the modifications during the same frame, but after Blizzard is done mucking with things
local function ScheduleUpdate(viewer)
    updateBucket[viewer] = true
    updaterFrame:Show()
end

-- Do the work
local function ApplyModifications()
    local viewers = {
        _G.UtilityCooldownViewer,
        _G.EssentialCooldownViewer,
        _G.BuffIconCooldownViewer
    }
    
    for _, viewer in ipairs(viewers) do
        if viewer and viewerSettings[viewer:GetName()] then
            RemovePadding(viewer)
            
            -- Hook Layout to reapply when Blizzard updates
            if viewer.Layout then
                hooksecurefunc(viewer, "Layout", function()
                    ScheduleUpdate(viewer)
                end)
            end
            
            -- Hook Show/Hide to reapply when icons appear/disappear
            local children = {viewer:GetChildren()}
            for _, child in ipairs(children) do
                child:HookScript("OnShow", function()
                    ScheduleUpdate(viewer)
                end)
                child:HookScript("OnHide", function()
                    ScheduleUpdate(viewer)
                end)
            end
        end
    end
    -- BuffIconCooldownViewer loads later, hook it separately
    C_Timer.After(0.1, function()
        if _G.BuffIconCooldownViewer and viewerSettings.BuffIconCooldownViewer then
            RemovePadding(_G.BuffIconCooldownViewer)
            
            -- Hook Layout to reapply when icons change
            if _G.BuffIconCooldownViewer.Layout then
                hooksecurefunc(_G.BuffIconCooldownViewer, "Layout", function()
                    ScheduleUpdate(_G.BuffIconCooldownViewer)
                end)
            end
            
            -- Hook Show/Hide on existing and future children
            local function HookChild(child)
                child:HookScript("OnShow", function()
                    ScheduleUpdate(_G.BuffIconCooldownViewer)
                end)
                child:HookScript("OnHide", function()
                    ScheduleUpdate(_G.BuffIconCooldownViewer)
                end)
            end
            
            local children = {_G.BuffIconCooldownViewer:GetChildren()}
            for _, child in ipairs(children) do
                HookChild(child)
            end
            
            -- Monitor for new children
            _G.BuffIconCooldownViewer:HookScript("OnUpdate", function(self)
                local currentChildren = {self:GetChildren()}
                for _, child in ipairs(currentChildren) do
                    if not child.cleanCooldownHooked then
                        child.cleanCooldownHooked = true
                        HookChild(child)
                        ScheduleUpdate(self)
                    end
                end
            end)
        end
    end)
end

-- Oh, are these settings yours? Here you go.
local function LoadSettings()
    -- Load saved border preference
    if CleanCooldownManagerDB.useBorders ~= nil then
        useBorders = CleanCooldownManagerDB.useBorders
    end
    if CleanCooldownManagerDB.centerBuffs ~= nil then
        centerBuffs = CleanCooldownManagerDB.centerBuffs
    end
    -- Load viewer settings
    if CleanCooldownManagerDB.viewerSettings then
        for k, v in pairs(CleanCooldownManagerDB.viewerSettings) do
            viewerSettings[k] = v
        end
    end
end

-- Put those away for later.
local function SaveSettings()
    -- Save border preference
    CleanCooldownManagerDB.useBorders = useBorders
    CleanCooldownManagerDB.centerBuffs = centerBuffs
    CleanCooldownManagerDB.viewerSettings = viewerSettings
end


-- Event handler
addon:SetScript("OnEvent", function(self, event, arg)
    if event == "ADDON_LOADED" and arg == "CleanCooldownManager" then
        LoadSettings()
    elseif event == "ADDON_LOADED" and arg == "Blizzard_CooldownManager" then
        C_Timer.After(0.5, ApplyModifications)
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, ApplyModifications)
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
    elseif msg == "centerbuffs" then
        centerBuffs = not centerBuffs
        SaveSettings()
        print("CleanCooldownManager: Buff centering " .. (centerBuffs and "enabled" or "disabled"))
        ApplyModifications()
    elseif msg == "utility" then
        viewerSettings.UtilityCooldownViewer = not viewerSettings.UtilityCooldownViewer
        SaveSettings()
        print("CleanCooldownManager: Utility bar " .. (viewerSettings.UtilityCooldownViewer and "enabled" or "disabled"))
        ApplyModifications()
    elseif msg == "essential" then
        viewerSettings.EssentialCooldownViewer = not viewerSettings.EssentialCooldownViewer
        SaveSettings()
        print("CleanCooldownManager: Essential bar " .. (viewerSettings.EssentialCooldownViewer and "enabled" or "disabled"))
        ApplyModifications()
    elseif msg == "buff" then
        viewerSettings.BuffIconCooldownViewer = not viewerSettings.BuffIconCooldownViewer
        SaveSettings()
        print("CleanCooldownManager: Buff bar " .. (viewerSettings.BuffIconCooldownViewer and "enabled" or "disabled"))
        ApplyModifications()
    elseif msg == "reload" then
        ApplyModifications()
        print("Reapplied modifications")
    else
        print("CleanCooldownManager commands:")
        print("  /ccm rant - Get my thoughts")
		print("  /ccm borders - Toggle black borders (currently " .. (useBorders and "ON" or "OFF") .. ")")
        print("  /ccm centerbuffs - Toggle buff icon centering (currently " .. (centerBuffs and "ON" or "OFF") .. ")")
        print("  /ccm utility - Toggle utility bar (currently " .. (viewerSettings.UtilityCooldownViewer and "ON" or "OFF") .. ")")
        print("  /ccm essential - Toggle essential bar (currently " .. (viewerSettings.EssentialCooldownViewer and "ON" or "OFF") .. ")")
        print("  /ccm buff - Toggle buff bar (currently " .. (viewerSettings.BuffIconCooldownViewer and "ON" or "OFF") .. ")")
        print("  /ccm reload - Reapply modifications")
    end
end
