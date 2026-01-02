require("ISUI/ISInventoryPane")

BWOInventoryMarkers = BWOInventoryMarkers or {}
BWOInventoryMarkers.DEBUG = true --BWOInventoryMarkers.DEBUG or false

local function bwoLog(msg)
    if not BWOInventoryMarkers.DEBUG then return end
    print("[BWOInventoryMarkers] " .. tostring(msg))
end

local function safeCall(fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    if not ok then
        bwoLog("ERROR: " .. tostring(a))
        return nil
    end
    return a, b, c
end

local function getContainerCustomName(object)
        bwoLog("getContainerCustomName start " .. tostring(object))
    if not object then return nil end

        bwoLog("getContainerCustomName LOG1 " )
    local sprite = (object.getSprite and object:getSprite()) or nil
    if not sprite then return nil end

        bwoLog("getContainerCustomName LOG2 ")
    local props = (sprite.getProperties and sprite:getProperties()) or nil
    if not props then return nil end

        bwoLog("getContainerCustomName LOG3 ")
    local val = safeCall(function()
        if props.Val then
            return props:Val("CustomName")
        end
        return nil
    end)

        bwoLog("getContainerCustomName LOG4 ")
    if val and val ~= "" then
        bwoLog("getContainerCustomName LOG5 "..tostring(val))
        return val
    end

        bwoLog("getContainerCustomName LOG6 (nil)")
    return nil
end

BWOInventoryMarkers.GetItemPrefix = function(container, item)
    -- Не убиваемся, если зависимости не готовы.
    bwoLog("BWOInventoryMarkers.GetItemPrefix start " .. tostring(container) .. tostring(item))
    if not container or not item then return "" end
    if not BWORooms or not BWORooms.TakeIntention then return "" end

    -- Важно: раньше ты гейтил через BWOScheduler.Anarchy.Transactions, но это может быть не готово
    -- в момент первого открытия контейнера → в итоге маркеры никогда не ставятся.
    -- Поэтому не гейтим. Если хочешь — включай обратно, но только вместе с повторным apply на тик.
    -- if not BWOScheduler or not BWOScheduler.Anarchy or not BWOScheduler.Anarchy.Transactions then return "" end

    bwoLog("BWOInventoryMarkers.GetItemPrefix LOG1 ")
    local object = (container.getParent and container:getParent()) or nil
    if not object then return "" end

    bwoLog("BWOInventoryMarkers.GetItemPrefix LOG2 ")
    local square = (object.getSquare and object:getSquare()) or nil
    if not square then return "" end

    bwoLog("BWOInventoryMarkers.GetItemPrefix LOG3 ")
    local room = (square.getRoom and square:getRoom()) or nil
    if not room then
        -- Вне комнат (улица/часть зданий/особые контейнеры) пока просто не маркируем.
        return ""
    end

    bwoLog("BWOInventoryMarkers.GetItemPrefix LOG4 ")
    local customName = getContainerCustomName(object)

    bwoLog("BWOInventoryMarkers.GetItemPrefix LOG5 ")
    local canTake, shouldPay = safeCall(function()
        return BWORooms.TakeIntention(room, customName)
    end)

    -- Если функция вернула nil/nil — не гадим маркерами “по умолчанию”
    if canTake == nil and shouldPay == nil then
        return ""
    end

    bwoLog("BWOInventoryMarkers.GetItemPrefix LOG6 ")
    -- Деньги никогда не маркируем
    if item.getType and item:getType() == "Money" then
        canTake = false
        shouldPay = false
    end

    if shouldPay then
		bwoLog("BWOInventoryMarkers.GetItemPrefix LOG7 ($) ")
        return "$"
    end

    if canTake == false then
		bwoLog("BWOInventoryMarkers.GetItemPrefix LOG7 (#) ")
        return "#"
    end
    bwoLog("BWOInventoryMarkers.GetItemPrefix LOG8 (nothing) ")

    return ""
end

local function hookPaneListbox(pane)
    if not pane or pane.__bwoHookedListbox then return end
    if not pane.items or not pane.items.doDrawItem then return end

    pane.__bwoHookedListbox = true
    local origDoDrawItem = pane.items.doDrawItem

    pane.items.doDrawItem = function(listbox, y, entry, alt)
        -- НАРИСОВАТЬ МАРКЕР (можно до или после orig)
        local item = entry and ((entry.items and entry.items[1]) or entry.item)
        if item and pane.inventory then
            local prefix = BWOInventoryMarkers.GetItemPrefix(pane.inventory, item)
            if prefix ~= "" then
                local font = listbox.font or UIFont.Small
                local fh = getTextManager():getFontHeight(font)
                local x = 6
                local yy = y + math.max(0, (listbox.itemheight - fh) / 2)
                listbox:drawText(prefix, x, yy, 1, 1, 1, 1, font)
            end
        end

        return origDoDrawItem(listbox, y, entry, alt)
    end

    bwoLog("hooked pane.items.doDrawItem")
end

if ISInventoryPane and ISInventoryPane.createChildren then
    local origCreateChildren = ISInventoryPane.createChildren
    ISInventoryPane.createChildren = function(self, ...)
        origCreateChildren(self, ...)
        hookPaneListbox(self)
    end
    bwoLog("hooked ISInventoryPane.createChildren")
end

if ISInventoryPane and ISInventoryPane.render then
    local origRender = ISInventoryPane.render
    ISInventoryPane.render = function(self, ...)
        hookPaneListbox(self)
        return origRender(self, ...)
    end
    bwoLog("hooked ISInventoryPane.render (fallback)")
end

bwoLog("BWOInventoryMarkers loaded OK")