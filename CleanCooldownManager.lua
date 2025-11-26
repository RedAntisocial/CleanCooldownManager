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

-- A clean up for when bars are disabled.
local function RemoveModifications(viewer)
    local children = {viewer:GetChildren()}
	-- debug
	-- print("RemoveModifications: found", #children, "children for", viewer:GetName())
    for _, child in ipairs(children) do
		-- debug
		-- print("  Processing child:", child:GetName() or "unnamed")
        if child.Icon then
            child.Icon:ClearAllPoints()
            child.Icon:SetPoint("CENTER", child, "CENTER", 0, 0)
            child.Icon:SetSize(child:GetWidth(), child:GetHeight())
			-- debug
			-- print("    Reset icon size and position")
        end
        if child.border then 
			child.border:Hide() 
			-- debug
			-- print("    Hid border")
		end
        if child.borderInset then 
			child.borderInset:Hide()
			-- debug
			-- print("    Hid borderInset")
		end
    end
end

-- Core function to remove padding and apply modifications. Doing Blizzard's work for them.
local function RemovePadding(viewer)
    -- Skip modifications if the viewer is disabled
    local viewerName = viewer:GetName()
	-- debug
	-- print("RemovePadding called for", viewerName, "enabled:", viewerSettings[viewerName])
    if not viewerSettings[viewerName] then
		-- debug
		-- print("Calling RemoveModifications for", viewerName)
		RemoveModifications(viewer)
        return
    end
	
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
            if child.Icon then
				-- Store original alpha if not already stored
				if not child.originalIconAlpha then
					child.originalIconAlpha = child.Icon:GetAlpha()
				end
				
				-- Scale the entire button frame
				local scale = viewer.iconScale or 1
				child.Icon:SetSize(child:GetWidth() * scale, child:GetHeight() * scale)

				child.Icon:ClearAllPoints()
				child.Icon:SetPoint("CENTER", child, "CENTER", 0, 0)
				
				if useBorders then
					local adjustedIconAlpha = math.max(0, (child.originalIconAlpha or 1) - 0.2)
					child.Icon:SetAlpha(adjustedIconAlpha)
				else
					child.Icon:SetAlpha(child.originalIconAlpha or 1)
				end
			end

            if useBorders then
                if not child.border then
                    child.border = child:CreateTexture(nil, "BACKGROUND")
                    child.border:SetColorTexture(0, 0, 0, child.originalIconAlpha or 1)
                    child.border:SetAllPoints(child)
                else
                    child.border:SetAlpha(child.originalIconAlpha or 1)
                end
                child.border:Show()

                if not child.borderInset then
                    child.borderInset = child:CreateTexture(nil, "BACKGROUND")
                    child.borderInset:SetColorTexture(0, 0, 0, child.originalIconAlpha or 1)
                    child.borderInset:SetPoint("TOPLEFT", child, "TOPLEFT", 1, -1)
                    child.borderInset:SetPoint("BOTTOMRIGHT", child, "BOTTOMRIGHT", -1, 1)
                else
                    child.borderInset:SetAlpha(child.originalIconAlpha or 1)
                end
                child.borderInset:Show()
            else
                if child.border then child.border:Hide() end
                if child.borderInset then child.borderInset:Hide() end
            end
        end
        return
    end

 	-- Handle sorting based on viewer type
	if viewer == _G.BuffIconCooldownViewer then
		-- Get BuffIconCooldownViewer's sorted list
		local buffIcons = viewer:GetItemFrames()
		if buffIcons and #buffIcons > 0 then
			-- Filter to only visible ones
			visibleChildren = {}
			for _, frame in ipairs(buffIcons) do
				if frame:IsShown() then
					table.insert(visibleChildren, frame)
				end
			end
		end
	else
		-- Sort by original position for other viewers
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
	end
    
	-- Use special centering logic for BuffIconCooldownViewer
	if viewer == _G.BuffIconCooldownViewer and centerBuffs then
		local padding = useBorders and 0 or -3
		local count = #visibleChildren
		local isEven = count % 2 == 0
		
		if isEven then
			local leftMiddleIndex = count / 2
			local rightMiddleIndex = leftMiddleIndex + 1
			
			visibleChildren[leftMiddleIndex]:ClearAllPoints()
			visibleChildren[leftMiddleIndex]:SetPoint("RIGHT", viewer, "CENTER", -padding / 2, 0)
			
			visibleChildren[rightMiddleIndex]:ClearAllPoints()
			visibleChildren[rightMiddleIndex]:SetPoint("LEFT", viewer, "CENTER", padding / 2, 0)
		else
			local middleIndex = math.ceil(count / 2)
			visibleChildren[middleIndex]:ClearAllPoints()
			visibleChildren[middleIndex]:SetPoint("CENTER", viewer, "CENTER", 0, 0)
		end
		
		-- Position left side
		local leftStart = isEven and (count / 2 - 1) or (math.ceil(count / 2) - 1)
		for i = leftStart, 1, -1 do
			visibleChildren[i]:ClearAllPoints()
			visibleChildren[i]:SetPoint("RIGHT", visibleChildren[i + 1], "LEFT", -padding, 0)
		end
		
		-- Position right side
		local rightStart = isEven and (count / 2 + 2) or (math.ceil(count / 2) + 1)
		for i = rightStart, count do
			visibleChildren[i]:ClearAllPoints()
			visibleChildren[i]:SetPoint("LEFT", visibleChildren[i - 1], "RIGHT", padding, 0)
		end
		-- Apply scaling and borders for BuffIconCooldownViewer
		for _, child in ipairs(visibleChildren) do
			if child.Icon then
				-- Store original alpha if not already stored
				if not child.originalIconAlpha then
					child.originalIconAlpha = child.Icon:GetAlpha()
				end
				
				child.Icon:ClearAllPoints()
				child.Icon:SetPoint("CENTER", child, "CENTER", 0, 0)
				child.Icon:SetSize(child:GetWidth() * (viewer.iconScale or 1), child:GetHeight() * (viewer.iconScale or 1))
				
				if useBorders then
					local adjustedIconAlpha = math.max(0, (child.originalIconAlpha or 1) - 0.2)
					child.Icon:SetAlpha(adjustedIconAlpha)
				else
					child.Icon:SetAlpha(child.originalIconAlpha or 1)
				end
			end

			if useBorders then
				if not child.border then
					child.border = child:CreateTexture(nil, "BACKGROUND")
					child.border:SetColorTexture(0, 0, 0, child.originalIconAlpha or 1)
					child.border:SetAllPoints(child)
				else
					child.border:SetAlpha(child.originalIconAlpha or 1)
				end
				child.border:Show()

				if not child.borderInset then
					child.borderInset = child:CreateTexture(nil, "BACKGROUND")
					child.borderInset:SetColorTexture(0, 0, 0, child.originalIconAlpha or 1)
					child.borderInset:SetPoint("TOPLEFT", child, "TOPLEFT", 1, -1)
					child.borderInset:SetPoint("BOTTOMRIGHT", child, "BOTTOMRIGHT", -1, 1)
				else
					child.borderInset:SetAlpha(child.originalIconAlpha or 1)
				end
				child.borderInset:Show()
			else
				if child.border then child.border:Hide() end
				if child.borderInset then child.borderInset:Hide() end
			end
		end
		return
	end
	
    -- Get layout settings from the viewer
    local stride = viewer.stride or #visibleChildren
	-- debug
	-- print("About to reposition", viewer:GetName(), "with", #visibleChildren, "icons")

	-- CONFIGURATION OPTIONS:
	local overlap = useBorders and 0 or -3 -- No overlap when using borders
	local iconScale = viewer.iconScale or 1

	-- Scale the icons and preserve actual alpha
	for _, child in ipairs(visibleChildren) do
		if child.Icon then
			-- Store original alpha if not already stored
			if not child.originalIconAlpha then
				child.originalIconAlpha = child.Icon:GetAlpha()
			end
			
			-- Scale the entire button frame
			local scale = viewer.iconScale or 1
			child.Icon:SetSize(child:GetWidth() * scale, child:GetHeight() * scale)

			child.Icon:ClearAllPoints()
			child.Icon:SetPoint("CENTER", child, "CENTER", 0, 0)
			
			if useBorders then
				local adjustedIconAlpha = math.max(0, (child.originalIconAlpha or 1) - 0.2)
				child.Icon:SetAlpha(adjustedIconAlpha)
			else
				child.Icon:SetAlpha(child.originalIconAlpha or 1)
			end
		end

		if useBorders then
			if not child.border then
				child.border = child:CreateTexture(nil, "BACKGROUND")
				child.border:SetColorTexture(0, 0, 0, child.originalIconAlpha or 1)
				child.border:SetAllPoints(child)
			else
				child.border:SetAlpha(child.originalIconAlpha or 1)
			end
			child.border:Show()

			if not child.borderInset then
				child.borderInset = child:CreateTexture(nil, "BACKGROUND")
				child.borderInset:SetColorTexture(0, 0, 0, child.originalIconAlpha or 1)
				child.borderInset:SetPoint("TOPLEFT", child, "TOPLEFT", 1, -1)
				child.borderInset:SetPoint("BOTTOMRIGHT", child, "BOTTOMRIGHT", -1, 1)
			else
				child.borderInset:SetAlpha(child.originalIconAlpha or 1)
			end
			child.borderInset:Show()
		else
			if child.border then child.border:Hide() end
			if child.borderInset then child.borderInset:Hide() end
		end
	end

    -- Reposition icons respecting orientation and stride
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
	local viewerName = viewer:GetName()
    if not viewerSettings[viewerName] then return end
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
        if viewer then
            local viewerName = viewer:GetName()
			RemovePadding(viewer)
			
            if viewerSettings[viewerName] then
                
                -- Hook Layout to reapply when Blizzard updates
                if viewer.Layout and not viewer.cleanCooldownLayoutHooked then
                    viewer.cleanCooldownLayoutHooked = true
                    hooksecurefunc(viewer, "Layout", function()
                        if viewerSettings[viewerName] then
                            ScheduleUpdate(viewer)
                        end
                    end)
                end
                
                -- Hook Show/Hide to reapply when icons appear/disappear
                local children = {viewer:GetChildren()}
                for _, child in ipairs(children) do
                    if not child.cleanCooldownHooked then
                        child.cleanCooldownHooked = true
                        child:HookScript("OnShow", function()
                            if viewerSettings[viewerName] then
                                ScheduleUpdate(viewer)
                            end
                        end)
                        child:HookScript("OnHide", function()
                            if viewerSettings[viewerName] then
                                ScheduleUpdate(viewer)
                            end
                        end)
                    end
                end
            end
        end
    end
    -- BuffIconCooldownViewer loads later, hook it separately
    C_Timer.After(0.1, function()
        if _G.BuffIconCooldownViewer then
            if viewerSettings.BuffIconCooldownViewer then
                RemovePadding(_G.BuffIconCooldownViewer)
            end
            
            -- Hook Layout to reapply when icons change
            if _G.BuffIconCooldownViewer.Layout and not _G.BuffIconCooldownViewer.cleanCooldownLayoutHooked then
                _G.BuffIconCooldownViewer.cleanCooldownLayoutHooked = true
                hooksecurefunc(_G.BuffIconCooldownViewer, "Layout", function()
                    if viewerSettings.BuffIconCooldownViewer then
                        ScheduleUpdate(_G.BuffIconCooldownViewer)
                    end
                end)
            end
            
            -- Hook Show/Hide on existing and future children
            local function HookChild(child)
                if not child.cleanCooldownHooked then
                    child.cleanCooldownHooked = true
                    child:HookScript("OnShow", function()
                        if viewerSettings.BuffIconCooldownViewer then
                            ScheduleUpdate(_G.BuffIconCooldownViewer)
                        end
                    end)
                    child:HookScript("OnHide", function()
                        if viewerSettings.BuffIconCooldownViewer then
                            ScheduleUpdate(_G.BuffIconCooldownViewer)
                        end
                    end)
                end
            end
            
            local children = {_G.BuffIconCooldownViewer:GetChildren()}
            for _, child in ipairs(children) do
                HookChild(child)
            end
            
            -- Monitor for new children
            if not _G.BuffIconCooldownViewer.cleanCooldownUpdateHooked then
                _G.BuffIconCooldownViewer.cleanCooldownUpdateHooked = true
                _G.BuffIconCooldownViewer:HookScript("OnUpdate", function(self)
                    local currentChildren = {self:GetChildren()}
                    for _, child in ipairs(currentChildren) do
                        if not child.cleanCooldownHooked then
                            HookChild(child)
                            if viewerSettings.BuffIconCooldownViewer then
                                ScheduleUpdate(self)
                            end
                        end
                    end
                end)
            end
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
	elseif msg == "settings" then
		C_AddOns.LoadAddOn("Blizzard_CooldownManager")
		C_Timer.After(0.1, function()
			if _G.CooldownViewerSettings then
				_G.CooldownViewerSettings:Show()
			else
				print("CooldownViewerSettings not available")
			end
		end)
    else
        print("CleanCooldownManager commands:")
        print("  /ccm rant - Get my thoughts")
		print("  /ccm borders - Toggle black borders (currently " .. (useBorders and "ON" or "OFF") .. ")")
        print("  /ccm centerbuffs - Toggle buff icon centering (currently " .. (centerBuffs and "ON" or "OFF") .. ")")
        print("  /ccm utility - Toggle utility bar (currently " .. (viewerSettings.UtilityCooldownViewer and "ON" or "OFF") .. ")")
        print("  /ccm essential - Toggle essential bar (currently " .. (viewerSettings.EssentialCooldownViewer and "ON" or "OFF") .. ")")
        print("  /ccm buff - Toggle buff bar (currently " .. (viewerSettings.BuffIconCooldownViewer and "ON" or "OFF") .. ")")
		print("  /ccm settings - Open Advanced Cooldown Manager Settings")
        print("  /ccm reload - Reapply modifications")
    end
end

-- Options Panel Setup
local panel = OptionsPanel:NewPanel({
    name = "CleanCooldownManager",
    displayName = "Clean Cooldown Manager",
    title = "Clean Cooldown Manager"
})

-- Borders checkbox
OptionsPanel:AddCheckbox(panel, {
    key = "useBorders",
    label = "Enable Borders",
    default = useBorders,
    onClick = function(val)
        useBorders = val
        SaveSettings()
        ApplyModifications()
    end,
    point = "TOPLEFT",
    anchor = panel.title,
    relativePoint = "BOTTOMLEFT",
    xOffset = 0,
    yOffset = -20
})

-- Center buffs checkbox
OptionsPanel:AddCheckbox(panel, {
    key = "centerBuffs",
    label = "Center Buff Icons",
    default = centerBuffs,
    onClick = function(val)
        centerBuffs = val
        SaveSettings()
        ApplyModifications()
    end,
    point = "TOPLEFT",
    anchor = panel.elements.useBorders,
    relativePoint = "BOTTOMLEFT",
    xOffset = 0,
    yOffset = -10
})

-- Utility bar dropdown
OptionsPanel:AddDropdown(panel, {
    key = "utilityViewer",
    label = "Utility Cooldown Viewer",
    default = viewerSettings.UtilityCooldownViewer and "enabled" or "disabled",
    options = {
        { text = "Enabled", value = "enabled" },
        { text = "Disabled", value = "disabled" }
    },
    onSelect = function(val)
		-- debug
		-- print("Dropdown onSelect called with value:", val, "type:", type(val))
        viewerSettings.UtilityCooldownViewer = (val == "enabled")
        SaveSettings()
        ApplyModifications()
    end,
    point = "TOPLEFT",
    anchor = panel.elements.centerBuffs,
    relativePoint = "BOTTOMLEFT",
	labelOffset = 160,
    xOffset = 0,
    yOffset = -20
})

-- Essential bar dropdown
OptionsPanel:AddDropdown(panel, {
    key = "essentialViewer",
    label = "Essential Cooldown Viewer",
    default = viewerSettings.EssentialCooldownViewer and "enabled" or "disabled",
    options = {
        { text = "Enabled", value = "enabled" },
        { text = "Disabled", value = "disabled" }
    },
    onSelect = function(val)
		-- debug
		-- print("Dropdown onSelect called with value:", val, "type:", type(val))
        viewerSettings.EssentialCooldownViewer = (val == "enabled")
        SaveSettings()
        ApplyModifications()
    end,
    point = "TOPLEFT",
    anchor = panel.elements.utilityViewer.label,
    relativePoint = "BOTTOMLEFT",
	labelOffset = 160,
    xOffset = 0,
    yOffset = -20
})

-- Buff bar dropdown
OptionsPanel:AddDropdown(panel, {
    key = "buffViewer",
    label = "Buff Cooldown Viewer",
    default = viewerSettings.BuffIconCooldownViewer and "enabled" or "disabled",
    options = {
        { text = "Enabled", value = "enabled" },
        { text = "Disabled", value = "disabled" }
    },
    onSelect = function(val)
		-- debug
		-- print("Dropdown onSelect called with value:", val, "type:", type(val))
        viewerSettings.BuffIconCooldownViewer = (val == "enabled")
        SaveSettings()
        ApplyModifications()
    end,
    point = "TOPLEFT",
    anchor = panel.elements.essentialViewer.label,
    relativePoint = "BOTTOMLEFT",
	labelOffset = 160,
    xOffset = 0,
    yOffset = -20
})

OptionsPanel:Register(panel)
