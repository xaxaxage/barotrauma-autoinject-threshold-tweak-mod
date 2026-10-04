-- Autoinject Threshold Tweak
--
-- Each item listed in ITEMS has a hidden CustomInterface (see Items/*.xml) with one integer input:
-- the health percentage at which the item auto-injects. The value lives in that component's
-- ManuallySelectedSound property, which the game already saves and syncs in multiplayer.
--
-- This script:
--   * (server + client) copies that percentage into ItemContainer.AutoInjectThreshold. The game doesn't save
--     the threshold itself, so this is also what restores the chosen value after loading a save;
--   * (client) right-clicking one of these items in your own inventory toggles a small settings window for it.
--     The window types the new value into the hidden CustomInterface input, so storing and syncing it stays vanilla.

local ITEMS = {
    autoinjectorheadset = true,
    pucs = true,
}

local MIN_PERCENT = 0
local MAX_PERCENT = 95
local PERCENT_STEP = 5

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

local updateSettingsWindow = function() end
local closeSettingsWindow = function() end

if CLIENT then
    LuaUserData.MakeFieldAccessible(
        LuaUserData.RegisterType("Barotrauma.Items.Components.CustomInterface"), "uiElements")
    LuaUserData.RegisterType("Barotrauma.Inventory+SlotReference")

    local window = nil      -- GUIFrame of the open settings window
    local windowItem = nil  -- item the window belongs to
    local numberInput = nil

    closeSettingsWindow = function()
        window, windowItem, numberInput = nil, nil, nil
    end

    -- Types the value into the item's own (hidden) CustomInterface input: that runs the vanilla code
    -- which stores it in ManuallySelectedSound and, in multiplayer, sends it to the server.
    local function setPercent(item, percent)
        local panel = item.GetComponentString("CustomInterface")
        if panel == nil then return end

        percent = math.max(MIN_PERCENT, math.min(MAX_PERCENT, math.floor(percent + 0.5)))
        if panel.ManuallySelectedSound == percent then return end

        for element in panel.uiElements do
            element.TextBox.Text = tostring(percent)
            break
        end
        applyThreshold(item)
    end

    local function openSettingsWindow(item)
        local panel = item.GetComponentString("CustomInterface")
        if panel == nil then return end

        window = GUI.Frame(GUI.RectTransform(Vector2(0.2, 0.1), nil, GUI.Anchor.CenterRight), "ItemUI")
        window.RectTransform.MinSize = Point(420, 120)
        window.RectTransform.RelativeOffset = Vector2(0.02, 0)

        local content = GUI.LayoutGroup(GUI.RectTransform(Vector2(0.9, 0.8), window.RectTransform, GUI.Anchor.Center))
        content.Stretch = true
        content.RelativeSpacing = 0.05

        local header = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.45), content.RectTransform), true)
        header.Stretch = true
        local title = GUI.TextBlock(GUI.RectTransform(Vector2(0.88, 1), header.RectTransform), item.Name, nil, GUI.Style.SubHeadingFont)
        title.AutoScaleHorizontal = true
        local closeButton = GUI.Button(GUI.RectTransform(Vector2(0.12, 1), header.RectTransform), "", GUI.Alignment.Center, "GUICancelButton")
        closeButton.OnClicked = function()
            closeSettingsWindow()
            return true
        end

        local row = GUI.LayoutGroup(GUI.RectTransform(Vector2(1, 0.45), content.RectTransform), true)
        row.Stretch = true
        local label = GUI.TextBlock(GUI.RectTransform(Vector2(0.55, 1), row.RectTransform), TextManager.Get("autoinjectthresholdtweak.label").Value)
        label.AutoScaleHorizontal = true
        numberInput = GUI.NumberInput(GUI.RectTransform(Vector2(0.45, 1), row.RectTransform), NumberType.Int)
        numberInput.MinValueInt = MIN_PERCENT
        numberInput.MaxValueInt = MAX_PERCENT
        numberInput.ValueStep = PERCENT_STEP
        numberInput.IntValue = panel.ManuallySelectedSound
        numberInput.OnValueChanged = function(input)
            setPercent(item, input.IntValue)
        end

        windowItem = item
    end

    local function isOwnedByControlledCharacter(item)
        local character = Character.Controlled
        return character ~= nil and not character.IsDead and item.GetRootInventoryOwner() == character
    end

    updateSettingsWindow = function()
        -- Right-click on one of the modded items in your inventory opens its window, or closes it if it's already open.
        if PlayerInput.SecondaryMouseButtonClicked() then
            local slot = Inventory.SelectedSlot
            local item = slot ~= nil and slot.Item or nil
            if isModdedItem(item) and isOwnedByControlledCharacter(item) then
                local wasOpen = windowItem ~= nil and windowItem == item
                closeSettingsWindow()
                if not wasOpen then openSettingsWindow(item) end
            end
        end

        if window == nil then return end
        if windowItem.Removed or not isOwnedByControlledCharacter(windowItem) then
            closeSettingsWindow()
            return
        end

        -- Show changes made elsewhere (e.g. by the server), but don't fight the player while they're typing.
        local panel = windowItem.GetComponentString("CustomInterface")
        if panel ~= nil and not numberInput.TextBox.Selected and numberInput.IntValue ~= panel.ManuallySelectedSound then
            numberInput.IntValue = panel.ManuallySelectedSound
        end
    end

    Hook.Patch("Barotrauma.GameScreen", "AddToGUIUpdateList", {}, function()
        if window ~= nil and not GUI.GUI.DisableHUD then
            window.AddToGUIUpdateList()
        end
    end, Hook.HookMethodType.After)
end

local nextSyncTime = 0

Hook.Add("think", "AutoinjectThresholdTweak.think", function()
    if not Game.RoundStarted then
        closeSettingsWindow()
        return
    end

    updateSettingsWindow()

    local now = Timer.GetTime()
    if now >= nextSyncTime then
        nextSyncTime = now + SYNC_INTERVAL
        syncThresholds()
    end
end)
