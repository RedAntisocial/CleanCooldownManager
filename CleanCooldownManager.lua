-- CleanCooldownManager.lua
local addon = CreateFrame("Frame")

addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")

local function RemovePadding(viewer)
    -- If we don't do this bit right here, it breaks your ability to move the Cooldown Manager stuff in edit mode
    if EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() then
        return
    end
    
    local children = {viewer:GetChildren()}
    
    -- Get the visible icons (because they're fully dynamic)
    local visibleChildren = {}
    for _, child in ipairs(children) do
        if child:IsShown() then
            table.insert(visibleChildren, child)
        end
    end
    
    if #visibleChildren == 0 then return end
    
    -- Scale the icons to overlap and hide borders.
    --[[ Small rant at the ridiculousness of this. 
    Spent hours digging through /framestack trying to figure out what element was controlling the padding that blizzard only lets you set to 2.
    It turns out there is _no_ actual padding in place, the icons themselves have a 1px transparent edge, which is why they won't let you set
    the padding below 2.
    ]]
    for _, child in ipairs(visibleChildren) do
        if child.Icon then
            child.Icon:ClearAllPoints()
            child.Icon:SetPoint("CENTER", child, "CENTER", 0, 0)
            child.Icon:SetSize(child:GetWidth() * 1.15, child:GetHeight() * 1.15)
        end
    end
    
    -- Reposition buttons with overlap
    local xOffset = 0
    local overlap = -3 -- This is the value you adjust for the overlap.
    
    for i, child in ipairs(visibleChildren) do
        child:ClearAllPoints()
        child:SetPoint("LEFT", viewer, "LEFT", xOffset, 0)
        xOffset = xOffset + child:GetWidth() + overlap
    end
end

local function ApplyModifications()
    print("Applying modifications")
    
    local viewers = {
        _G.UtilityCooldownViewer,
        _G.EssentialCooldownViewer,
        _G.BuffCoolDownViewer
    }
    
    for _, viewer in ipairs(viewers) do
        if viewer then
            print("Processing:", viewer:GetName())
            
            RemovePadding(viewer)
            
            -- Hook Layout to reapply
            if viewer.Layout then
                hooksecurefunc(viewer, "Layout", function()
                    C_Timer.After(0, function()
                        RemovePadding(viewer)
                    end)
                end)
            end
            
            -- Hook Show/Hide
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
    
    -- Listen for edit mode changes
    if EditModeManagerFrame then
        EditModeManagerFrame:HookScript("OnEditModeEnter", function()
            print("Edit mode entered - modifications disabled")
        end)
        
        EditModeManagerFrame:HookScript("OnEditModeExit", function()
            print("Edit mode exited - reapplying modifications")
            C_Timer.After(0.1, ApplyModifications)
        end)
    end
    
    print("Done")
end

addon:SetScript("OnEvent", function(self, event, arg)
    if event == "ADDON_LOADED" and arg == "Blizzard_CooldownManager" then
        C_Timer.After(0.5, ApplyModifications)
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(2, ApplyModifications)
    end
end)
