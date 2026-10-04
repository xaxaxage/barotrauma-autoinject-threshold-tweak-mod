-- Autoinject Threshold Tweak
--
-- Each item listed in ITEMS has a small CustomInterface panel (see Items/*.xml) with a number input:
-- the health percentage at which the item auto-injects. The number is stored in the panel's
-- ManuallySelectedSound property, which the game already saves and syncs in multiplayer.
--
-- This script:
--   * (server + client) copies that percentage into ItemContainer.AutoInjectThreshold. The game doesn't save
--     the threshold itself, so this is also what restores the chosen value after loading a save;
--   * (client) shows the panel only while the item is held in hands, or while it's equipped
--     and the player's own health window is open.

local ITEMS = {
    autoinjectorheadset = true,
    pucs = true,
}

local SYNC_INTERVAL = 0.5 -- seconds

local function isModdedItem(item)
    return item ~= nil and not item.Removed and ITEMS[item.Prefab.Identifier.Value:lower()] == true
end

local function applyThreshold(item)
    local panel = item.GetComponentString("CustomInterface")
    local container = item.GetComponentString("ItemContainer")
    if panel == nil or container == nil then return end

    local threshold = math.max(0, math.min(100, panel.ManuallySelectedSound)) / 100
    if math.abs(container.AutoInjectThreshold - threshold) > 0.001 then
        container.AutoInjectThreshold = threshold
    end
end

-- Auto-injection only happens while the item is equipped, so only character inventories need syncing.
local function syncThresholds()
    for character in Character.CharacterList do
        if character.Inventory ~= nil then
            for item in character.Inventory.AllItems do
                if isModdedItem(item) then applyThreshold(item) end
            end
        end
    end
end

local updatePanelVisibility = function() end

if CLIENT then
    -- DrawHudWhenEquipped has a protected setter.
    LuaUserData.MakePropertyAccessible(
        LuaUserData.RegisterType("Barotrauma.Items.Components.CustomInterface"), "DrawHudWhenEquipped")

    local shown = {} -- item.ID -> item whose panel is currently visible

    local function setPanelVisible(item, visible)
        local panel = item.GetComponentString("CustomInterface")
        if panel ~= nil then panel.DrawHudWhenEquipped = visible end
    end

    updatePanelVisibility = function()
        local wanted = {}
        local character = Character.Controlled
        if character ~= nil and character.Inventory ~= nil then
            for item in character.HeldItems do
                if isModdedItem(item) then wanted[item.ID] = item end
            end

            local healthWindow = CharacterHealth.OpenHealthWindow
            if healthWindow ~= nil and healthWindow == character.CharacterHealth then
                for item in character.Inventory.AllItems do
                    if isModdedItem(item) and character.HasEquippedItem(item) then wanted[item.ID] = item end
                end
            end
        end

        for id, item in pairs(shown) do
            if wanted[id] == nil and not item.Removed then setPanelVisible(item, false) end
        end
        for id, item in pairs(wanted) do
            if shown[id] == nil then setPanelVisible(item, true) end
        end
        shown = wanted
    end
end

local nextSyncTime = 0

Hook.Add("think", "AutoinjectThresholdTweak.think", function()
    if not Game.RoundStarted then return end

    updatePanelVisibility()

    local now = Timer.GetTime()
    if now >= nextSyncTime then
        nextSyncTime = now + SYNC_INTERVAL
        syncThresholds()
    end
end)
