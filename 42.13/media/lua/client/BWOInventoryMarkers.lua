require("ISUI/ISInventoryPane")

BWOInventoryMarkers = BWOInventoryMarkers or {}

local function getContainerCustomName(object)
    if not object then return nil end
    local sprite = object:getSprite()
    if not sprite then return nil end
    local props = sprite:getProperties()
    if not props or not props:Is("CustomName") then return nil end
    return props:Val("CustomName")
end

BWOInventoryMarkers.GetItemPrefix = function(container, item)
    if not BWOScheduler or not BWOScheduler.Anarchy or not BWOScheduler.Anarchy.Transactions then
        return ""
    end

    if not container or not item then return "" end

    local object = container:getParent()
    if not object then return "" end

    local square = object:getSquare()
    if not square then return "" end

    local room = square:getRoom()
    if not room then return "" end

    local customName = getContainerCustomName(object)
    local canTake, shouldPay = BWORooms.TakeIntention(room, customName)

    if item:getType() == "Money" then
        canTake = false
        shouldPay = false
    end

    if shouldPay then
        return "$"
    end

    if not canTake then
        return "#"
    end

    return ""
end

BWOInventoryMarkers.ApplyToPane = function(pane)
    if not pane or not pane.items then return end

    local container = pane.inventory
    for _, entry in ipairs(pane.items) do
        local item = entry.items and entry.items[1] or entry.item
        if item then
            if not entry.bwoBaseText then
                entry.bwoBaseText = entry.text or entry.name or item:getDisplayName()
            end

            local prefix = BWOInventoryMarkers.GetItemPrefix(container, item)
            if prefix ~= "" then
                entry.text = prefix .. " " .. entry.bwoBaseText
            else
                entry.text = entry.bwoBaseText
            end
        end
    end
end

local function wrapInventoryPaneMethod(methodName)
    local original = ISInventoryPane[methodName]
    if not original then
        return false
    end

    ISInventoryPane[methodName] = function(self, ...)
        local result = original(self, ...)
        BWOInventoryMarkers.ApplyToPane(self)
        return result
    end

    return true
end

local hooked = wrapInventoryPaneMethod("refresh")
if not hooked then
    hooked = wrapInventoryPaneMethod("refreshContainer")
end
if not hooked then
    wrapInventoryPaneMethod("refreshContainerItems")
end
