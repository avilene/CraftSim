---@class CraftSim
local CraftSim = select(2, ...)

local GGUI = CraftSim.GGUI
local GUTIL = CraftSim.GUTIL

local L = CraftSim.LOCAL:GetLocalizer()

---@class CraftSim.SALVAGE_STATS : CraftSim.Module
CraftSim.SALVAGE_STATS = CraftSim.SALVAGE_STATS

---@class CraftSim.SALVAGE_STATS.UI : CraftSim.Module.UI
CraftSim.SALVAGE_STATS.UI = {}

local LIST_HEADER_SCALE = 0.85
local TAB_CONTENT_SIZE_X = 520
local TAB_CONTENT_SIZE_Y = 480
local LIST_PAD_X = 10
local LIST_PAD_Y = 10
local LIST_ROW_HEIGHT = 20
local COLUMN_WIDTHS = {
    item = 210,
    rate = 58,
    expected = 58,
    price = 78,
    value = 86,
}
local LIST_SIZE_X = COLUMN_WIDTHS.item + COLUMN_WIDTHS.rate + COLUMN_WIDTHS.expected
    + COLUMN_WIDTHS.price + COLUMN_WIDTHS.value + 24
local LIST_SIZE_Y = 165
local ITEM_TEXT_WIDTH = COLUMN_WIDTHS.item - 10
local LIST_LAYOUT_VERSION = "V2"

---@param itemID number
---@return string
local function getFallbackItemLabel(itemID)
    return C_Item.GetItemNameByID(itemID) or ("Item " .. itemID)
end

---@param itemIDs number[]
---@return GGUI.DropdownData[]
local function buildItemDropdownData(itemIDs)
    local data = {}
    for _, itemID in ipairs(itemIDs) do
        table.insert(data, {
            label = getFallbackItemLabel(itemID),
            value = itemID,
        })
    end
    return data
end

---@param tabContent Frame
---@param summaryPrefix string
---@param itemID number
local function syncInputDropdown(tabContent, summaryPrefix, itemID)
    local dropdown = tabContent[summaryPrefix .. "InputDropdown"]
    local dropdownData = tabContent[summaryPrefix .. "InputDropdownData"]
    if not dropdown or not dropdownData or not itemID then
        return
    end

    local label = getFallbackItemLabel(itemID)
    for _, entry in ipairs(dropdownData) do
        if entry.value == itemID then
            label = entry.label
            break
        end
    end

    dropdown:SetData({
        data = dropdownData,
        initialValue = itemID,
        initialLabel = label,
    })
end

---@param tabContent Frame
---@param summaryPrefix string
---@param itemIDs number[]
---@param onSelect fun()
local function createInputDropdown(tabContent, summaryPrefix, itemIDs, onSelect)
    tabContent[summaryPrefix .. "InputDropdownData"] = buildItemDropdownData(itemIDs)
    tabContent[summaryPrefix .. "SelectedInputItemID"] = itemIDs[1]

    tabContent[summaryPrefix .. "InputDropdown"] = GGUI.Dropdown({
        parent = tabContent,
        anchorParent = tabContent[summaryPrefix .. "InputTitle"].frame,
        anchorA = "TOPLEFT",
        anchorB = "BOTTOMLEFT",
        offsetY = -4,
        width = 280,
        clickCallback = function(_, _, value)
            tabContent[summaryPrefix .. "SelectedInputItemID"] = value
            onSelect()
        end,
    })

    syncInputDropdown(tabContent, summaryPrefix, itemIDs[1])

    local batchInputFrame = tabContent[summaryPrefix .. "BatchInput"].textInput.frame
    batchInputFrame:ClearAllPoints()
    batchInputFrame:SetPoint(
        "TOPLEFT", tabContent[summaryPrefix .. "InputDropdown"].frame, "BOTTOMLEFT", 0, -8)
    tabContent[summaryPrefix .. "BatchLabel"].frame:ClearAllPoints()
    tabContent[summaryPrefix .. "BatchLabel"].frame:SetPoint(
        "LEFT", batchInputFrame, "RIGHT", 25, 0)

    local items = GUTIL:Map(itemIDs, function(itemID)
        return Item:CreateFromItemID(itemID)
    end)
    GUTIL:ContinueOnAllItemsLoaded(items, function()
        for index, entry in ipairs(tabContent[summaryPrefix .. "InputDropdownData"]) do
            entry.label = items[index]:GetItemLink() or entry.label
        end
        syncInputDropdown(tabContent, summaryPrefix, tabContent[summaryPrefix .. "SelectedInputItemID"])
    end)
end

---@param tabContent Frame
---@param summaryPrefix string
---@param recipeData CraftSim.RecipeData?
---@param getDataByItemID fun(itemID: number): CraftSim.SalvageStatsInputData?
---@return number? selectedItemID
---@return CraftSim.SalvageStatsInputData? inputData
local function resolveSelectedInput(tabContent, summaryPrefix, recipeData, getDataByItemID)
    local selectedItemID = tabContent[summaryPrefix .. "SelectedInputItemID"]

    if recipeData and recipeData.isSalvageRecipe then
        local activeItem = recipeData.reagentData.salvageReagentSlot.activeItem
        if activeItem then
            local activeItemID = activeItem:GetItemID()
            if getDataByItemID(activeItemID) then
                selectedItemID = activeItemID
                tabContent[summaryPrefix .. "SelectedInputItemID"] = activeItemID
                syncInputDropdown(tabContent, summaryPrefix, activeItemID)
            end
        end
    end

    if not selectedItemID then
        return nil, nil
    end

    return selectedItemID, getDataByItemID(selectedItemID)
end

---@param tabContent Frame
---@param listName string
---@return GGUI.FrameList
local function createDropList(tabContent, listName)
    return GGUI.FrameList({
        parent = tabContent,
        anchorParent = tabContent,
        anchorA = "BOTTOMLEFT",
        anchorB = "BOTTOMLEFT",
        offsetX = LIST_PAD_X,
        offsetY = LIST_PAD_Y,
        sizeX = LIST_SIZE_X,
        sizeY = LIST_SIZE_Y,
        rowHeight = LIST_ROW_HEIGHT,
        showBorder = true,
        savedVariablesTableLayoutConfig = CraftSim.UTIL:GetFrameListLayoutConfig(listName .. "_" .. LIST_LAYOUT_VERSION),
        columnOptions = {
            {
                label = L("SALVAGE_STATS_ITEM_HEADER"),
                width = COLUMN_WIDTHS.item,
                justifyOptions = { type = "H", align = "LEFT" },
                headerScale = LIST_HEADER_SCALE,
            },
            {
                label = L("SALVAGE_STATS_RATE_HEADER"),
                width = COLUMN_WIDTHS.rate,
                justifyOptions = { type = "H", align = "CENTER" },
                headerScale = LIST_HEADER_SCALE,
            },
            {
                label = L("SALVAGE_STATS_EXPECTED_QTY_HEADER"),
                width = COLUMN_WIDTHS.expected,
                justifyOptions = { type = "H", align = "CENTER" },
                headerScale = LIST_HEADER_SCALE,
            },
            {
                label = L("SALVAGE_STATS_PRICE_HEADER"),
                width = COLUMN_WIDTHS.price,
                justifyOptions = { type = "H", align = "CENTER" },
                headerScale = LIST_HEADER_SCALE,
            },
            {
                label = L("SALVAGE_STATS_VALUE_HEADER"),
                width = COLUMN_WIDTHS.value,
                justifyOptions = { type = "H", align = "CENTER" },
                headerScale = LIST_HEADER_SCALE,
            },
        },
        rowConstructor = function(columns)
            local itemColumn = columns[1]
            itemColumn:SetClipsChildren(true)
            itemColumn.text = GGUI.Text({
                parent = itemColumn,
                anchorParent = itemColumn,
                anchorA = "LEFT",
                anchorB = "LEFT",
                offsetX = 4,
                scale = 0.85,
                fixedWidth = ITEM_TEXT_WIDTH,
                justifyOptions = { type = "H", align = "LEFT" },
            })

            for index = 2, #columns do
                local column = columns[index]
                column:SetClipsChildren(true)
                column.text = GGUI.Text({
                    parent = column,
                    anchorParent = column,
                    justifyOptions = column.justifyOptions,
                    anchorA = "CENTER",
                    anchorB = "CENTER",
                    scale = 0.9,
                })
            end
        end,
    })
end

---@param tabContent Frame
---@param summaryPrefix string
local function initSummarySection(tabContent, summaryPrefix)
    tabContent[summaryPrefix .. "InputTitle"] = GGUI.Text({
        parent = tabContent,
        anchorParent = tabContent,
        anchorA = "TOPLEFT",
        anchorB = "TOPLEFT",
        offsetX = 10,
        offsetY = -10,
        text = L("SALVAGE_STATS_INPUT_LABEL"),
    })

    tabContent[summaryPrefix .. "InputValue"] = GGUI.Text({
        parent = tabContent,
        anchorParent = tabContent[summaryPrefix .. "InputTitle"].frame,
        anchorA = "LEFT",
        anchorB = "RIGHT",
        offsetX = 5,
        text = "-",
    })

    tabContent[summaryPrefix .. "BatchInput"] = GGUI.NumericInput({
        parent = tabContent,
        anchorParent = tabContent[summaryPrefix .. "InputTitle"].frame,
        anchorA = "TOPLEFT",
        anchorB = "BOTTOMLEFT",
        offsetY = -8,
        sizeX = 80,
        sizeY = 25,
        initialValue = 2000,
        allowDecimals = false,
        minValue = 1,
        incrementOneButtons = true,
        borderAdjustWidth = 1.15,
        borderAdjustHeight = 1.05,
        onNumberValidCallback = function()
            CraftSim.SALVAGE_STATS.UI:Update(CraftSim.MODULES.recipeData)
        end,
    })

    tabContent[summaryPrefix .. "BatchLabel"] = GGUI.Text({
        parent = tabContent,
        anchorParent = tabContent[summaryPrefix .. "BatchInput"].textInput.frame,
        anchorA = "LEFT",
        anchorB = "RIGHT",
        offsetX = 25,
        text = L("SALVAGE_STATS_BATCH_LABEL"),
    })

    tabContent[summaryPrefix .. "CostTitle"] = GGUI.Text({
        parent = tabContent,
        anchorParent = tabContent[summaryPrefix .. "BatchInput"].textInput.frame,
        anchorA = "TOPLEFT",
        anchorB = "BOTTOMLEFT",
        offsetY = -12,
        text = L("SALVAGE_STATS_COST_LABEL"),
    })

    tabContent[summaryPrefix .. "CostValue"] = GGUI.Text({
        parent = tabContent,
        anchorParent = tabContent[summaryPrefix .. "CostTitle"].frame,
        anchorA = "LEFT",
        anchorB = "RIGHT",
        offsetX = 5,
        text = "-",
    })

    tabContent[summaryPrefix .. "TotalValueTitle"] = GGUI.Text({
        parent = tabContent,
        anchorParent = tabContent[summaryPrefix .. "CostTitle"].frame,
        anchorA = "TOPLEFT",
        anchorB = "BOTTOMLEFT",
        offsetY = -8,
        text = L("SALVAGE_STATS_TOTAL_VALUE_LABEL"),
    })

    tabContent[summaryPrefix .. "TotalValueValue"] = GGUI.Text({
        parent = tabContent,
        anchorParent = tabContent[summaryPrefix .. "TotalValueTitle"].frame,
        anchorA = "LEFT",
        anchorB = "RIGHT",
        offsetX = 5,
        text = "-",
    })

    tabContent[summaryPrefix .. "ProfitTitle"] = GGUI.Text({
        parent = tabContent,
        anchorParent = tabContent[summaryPrefix .. "TotalValueTitle"].frame,
        anchorA = "TOPLEFT",
        anchorB = "BOTTOMLEFT",
        offsetY = -8,
        text = L("SALVAGE_STATS_PROFIT_LABEL"),
    })

    tabContent[summaryPrefix .. "ProfitValue"] = GGUI.Text({
        parent = tabContent,
        anchorParent = tabContent[summaryPrefix .. "ProfitTitle"].frame,
        anchorA = "LEFT",
        anchorB = "RIGHT",
        offsetX = 5,
        text = "-",
    })

    tabContent[summaryPrefix .. "Note"] = GGUI.Text({
        parent = tabContent,
        anchorParent = tabContent[summaryPrefix .. "ProfitTitle"].frame,
        anchorA = "TOPLEFT",
        anchorB = "BOTTOMLEFT",
        offsetY = -10,
        text = "",
        scale = 0.8,
        wrap = true,
        fixedWidth = TAB_CONTENT_SIZE_X - 40,
        justifyOptions = { type = "H", align = "LEFT" },
    })
end

---@param dropList GGUI.FrameList
---@param result CraftSim.SalvageStatsCalculationResult?
local function updateDropList(dropList, result)
    dropList:Remove()
    if not result then
        dropList:UpdateDisplay()
        return
    end

    local items = GUTIL:Map(result.drops, function(drop)
        return Item:CreateFromItemID(drop.itemID)
    end)

    GUTIL:ContinueOnAllItemsLoaded(items, function()
        for index, drop in ipairs(result.drops) do
            local item = items[index]
            local itemName = item:GetItemName() or getFallbackItemLabel(drop.itemID)
            local itemLink = item:GetItemLink()
            local rateText = GUTIL:Round(drop.dropRate * 100, 2) .. "%"
            local qtyText = tostring(drop.expectedQty)
            local priceText = CraftSim.UTIL:FormatMoney(drop.price, true)
            local valueText = CraftSim.UTIL:FormatMoney(drop.expectedValue, true)

            dropList:Add(function(row, columns)
                local itemIcon = GUTIL:IconToText(item:GetItemIcon(), 16, 16, 0, -2)
                columns[1].text:SetText(itemIcon .. " " .. itemName)
                columns[2].text:SetText(rateText)
                columns[3].text:SetText(qtyText)
                columns[4].text:SetText(priceText)
                columns[5].text:SetText(valueText)

                if itemLink then
                    row.tooltipOptions = {
                        anchor = "ANCHOR_RIGHT",
                        owner = row.frame,
                        itemLink = itemLink,
                    }
                end
            end)
        end

        dropList:UpdateDisplay()
    end)
end

---@param tabContent Frame
---@param summaryPrefix string
---@param result CraftSim.SalvageStatsCalculationResult?
---@param inputLabel string?
---@param note string?
local function updateSummary(tabContent, summaryPrefix, result, inputLabel, note)
    tabContent[summaryPrefix .. "InputValue"]:SetText(inputLabel or "-")
    tabContent[summaryPrefix .. "Note"]:SetText(note or "")

    if not result then
        tabContent[summaryPrefix .. "CostValue"]:SetText("-")
        tabContent[summaryPrefix .. "TotalValueValue"]:SetText("-")
        tabContent[summaryPrefix .. "ProfitValue"]:SetText("-")
        return
    end

    tabContent[summaryPrefix .. "CostValue"]:SetText(CraftSim.UTIL:FormatMoney(result.inputCost, true))
    tabContent[summaryPrefix .. "TotalValueValue"]:SetText(CraftSim.UTIL:FormatMoney(result.saleValue, true))

    local profitColor = result.profit >= 0 and GUTIL.COLORS.GREEN or GUTIL.COLORS.RED
    tabContent[summaryPrefix .. "ProfitValue"]:SetText(GUTIL:ColorizeText(
        CraftSim.UTIL:FormatMoney(result.profit, true), profitColor))
end

function CraftSim.SALVAGE_STATS.UI:Init()
    local onClose, onMinimize, onMaximize = CraftSim.MODULES:GetModuleFrameStateCallbacks(self.module)

    CraftSim.SALVAGE_STATS.frame = GGUI.Frame({
        parent = ProfessionsFrame,
        sizeX = TAB_CONTENT_SIZE_X,
        sizeY = TAB_CONTENT_SIZE_Y + 30,
        frameID = CraftSim.CONST.FRAMES.SALVAGE_STATS,
        title = L("SALVAGE_STATS_TITLE"),
        collapseable = true,
        closeable = true,
        moveable = true,
        backdropOptions = CraftSim.CONST.DEFAULT_BACKDROP_OPTIONS,
        frameTable = CraftSim.INIT.FRAMES,
        frameConfigTable = CraftSim.DB.OPTIONS:Get("GGUI_CONFIG"),
        onCloseCallback = onClose,
        onCollapseCallback = onMinimize,
        onCollapseOpenCallback = onMaximize,
        frameStrata = CraftSim.CONST.MODULES_FRAME_STRATA,
        raiseOnInteraction = true,
        frameLevel = CraftSim.UTIL:NextFrameLevel(),
    })

    local frame = CraftSim.SALVAGE_STATS.frame

    local function createContent(parentFrame)
        parentFrame:Hide()

        parentFrame.content.prospectingTab = GGUI.BlizzardTab({
            buttonOptions = {
                parent = parentFrame.content,
                anchorParent = parentFrame.content,
                offsetY = -2,
                label = L("SALVAGE_STATS_PROSPECTING_TAB"),
            },
            parent = parentFrame.content,
            anchorParent = parentFrame.content,
            sizeX = TAB_CONTENT_SIZE_X,
            sizeY = TAB_CONTENT_SIZE_Y,
            canBeEnabled = true,
            offsetY = -30,
            initialTab = true,
            top = true,
        })

        parentFrame.content.disenchantTab = GGUI.BlizzardTab({
            buttonOptions = {
                parent = parentFrame.content,
                anchorParent = parentFrame.content.prospectingTab.button,
                anchorA = "LEFT",
                anchorB = "RIGHT",
                label = L("SALVAGE_STATS_DISENCHANT_TAB"),
            },
            parent = parentFrame.content,
            anchorParent = parentFrame.content,
            sizeX = TAB_CONTENT_SIZE_X,
            sizeY = TAB_CONTENT_SIZE_Y,
            canBeEnabled = true,
            offsetY = -30,
            top = true,
        })

        parentFrame.content.millingTab = GGUI.BlizzardTab({
            buttonOptions = {
                parent = parentFrame.content,
                anchorParent = parentFrame.content.disenchantTab.button,
                anchorA = "LEFT",
                anchorB = "RIGHT",
                label = L("SALVAGE_STATS_MILLING_TAB"),
            },
            parent = parentFrame.content,
            anchorParent = parentFrame.content,
            sizeX = TAB_CONTENT_SIZE_X,
            sizeY = TAB_CONTENT_SIZE_Y,
            canBeEnabled = true,
            offsetY = -30,
            top = true,
        })

        local prospectingContent = parentFrame.content.prospectingTab.content
        initSummarySection(prospectingContent, "prospecting")
        prospectingContent.prospectingInputTitle:SetText(L("SALVAGE_STATS_INPUT_SELECT_LABEL"))
        prospectingContent.prospectingInputValue:Hide()
        createInputDropdown(prospectingContent, "prospecting",
            CraftSim.SALVAGE_STATS:GetAllInputItemIDs(CraftSim.SALVAGE_STATS_DATA.PROSPECTING),
            function()
                CraftSim.SALVAGE_STATS.UI:Update(CraftSim.MODULES.recipeData)
            end)
        prospectingContent.prospectingDropList = createDropList(
            prospectingContent, "SALVAGE_STATS_PROSPECTING_LIST")

        local disenchantContent = parentFrame.content.disenchantTab.content
        initSummarySection(disenchantContent, "disenchant")
        disenchantContent.disenchantBatchInput:SetValue(CraftSim.SALVAGE_STATS_DATA.DISENCHANT_DEFAULT_BATCH_SIZE)

        disenchantContent.disenchantVariantTitle = GGUI.Text({
            parent = disenchantContent,
            anchorParent = disenchantContent.disenchantNote.frame,
            anchorA = "TOPLEFT",
            anchorB = "BOTTOMLEFT",
            offsetY = -4,
            text = L("SALVAGE_STATS_VARIANT_LABEL"),
        })

        disenchantContent.disenchantVariantButtons = {}
        for index, shuffleData in ipairs(CraftSim.SALVAGE_STATS_DATA.DISENCHANT_SHUFFLE) do
            local button = GGUI.Button({
                parent = disenchantContent,
                anchorParent = index == 1 and disenchantContent.disenchantVariantTitle.frame
                    or disenchantContent.disenchantVariantButtons[index - 1].frame,
                anchorA = index == 1 and "TOPLEFT" or "LEFT",
                anchorB = index == 1 and "BOTTOMLEFT" or "RIGHT",
                offsetY = index == 1 and -4 or 0,
                offsetX = index == 1 and 0 or 5,
                label = shuffleData.label,
                sizeX = 120,
                sizeY = 20,
                clickCallback = function()
                    disenchantContent.selectedDisenchantIndex = index
                    CraftSim.SALVAGE_STATS.UI:Update(CraftSim.MODULES.recipeData)
                end,
            })
            disenchantContent.disenchantVariantButtons[index] = button
        end
        disenchantContent.selectedDisenchantIndex = 1

        disenchantContent.disenchantDropList = createDropList(
            disenchantContent, "SALVAGE_STATS_DISENCHANT_LIST")

        local millingContent = parentFrame.content.millingTab.content
        initSummarySection(millingContent, "milling")
        millingContent.millingInputTitle:SetText(L("SALVAGE_STATS_INPUT_SELECT_LABEL"))
        millingContent.millingInputValue:Hide()
        millingContent.millingBatchInput:SetValue(CraftSim.SALVAGE_STATS_DATA.MILLING_DEFAULT_BATCH_SIZE)
        millingContent.millingBatchLabel:SetText(L("SALVAGE_STATS_MILLING_BATCH_LABEL"))
        createInputDropdown(millingContent, "milling",
            CraftSim.SALVAGE_STATS:GetAllInputItemIDs(CraftSim.SALVAGE_STATS_DATA.MILLING),
            function()
                CraftSim.SALVAGE_STATS.UI:Update(CraftSim.MODULES.recipeData)
            end)
        millingContent.millingDropList = createDropList(
            millingContent, "SALVAGE_STATS_MILLING_LIST")

        GGUI.BlizzardTabSystem {
            parentFrame.content.prospectingTab,
            parentFrame.content.disenchantTab,
            parentFrame.content.millingTab,
        }
    end

    createContent(frame)
    self.module.frame = frame
end

---@param recipeData CraftSim.RecipeData?
function CraftSim.SALVAGE_STATS.UI:Update(recipeData)
    local frame = CraftSim.SALVAGE_STATS.frame
    if not frame or not frame:IsVisible() then
        return
    end

    local prospectingContent = frame.content.prospectingTab.content
    local disenchantContent = frame.content.disenchantTab.content
    local millingContent = frame.content.millingTab.content

    local prospectingBatchSize = prospectingContent.prospectingBatchInput.currentValue
        or CraftSim.SALVAGE_STATS_DATA.PROSPECTING_DEFAULT_BATCH_SIZE

    local selectedProspectingItemID, resolvedProspectingData = resolveSelectedInput(
        prospectingContent, "prospecting", recipeData, function(itemID)
            return CraftSim.SALVAGE_STATS:GetProspectingDataByItemID(itemID)
        end)

    if resolvedProspectingData and selectedProspectingItemID then
        local inputUnitPrice = CraftSim.PRICE_SOURCE:GetMinBuyoutByItemID(selectedProspectingItemID, true) or 0
        local prospectingResult = CraftSim.SALVAGE_STATS:CalculateStats(
            resolvedProspectingData, prospectingBatchSize, inputUnitPrice, true, selectedProspectingItemID)

        updateSummary(prospectingContent, "prospecting", prospectingResult, nil,
            L("SALVAGE_STATS_PROSPECTING_NOTE"))
        updateDropList(prospectingContent.prospectingDropList, prospectingResult)
    else
        updateSummary(prospectingContent, "prospecting", nil, nil,
            L("SALVAGE_STATS_PROSPECTING_NOTE"))
        updateDropList(prospectingContent.prospectingDropList, nil)
    end

    local disenchantIndex = disenchantContent.selectedDisenchantIndex or 1
    local disenchantData = CraftSim.SALVAGE_STATS_DATA.DISENCHANT_SHUFFLE[disenchantIndex]
    local disenchantBatchSize = disenchantContent.disenchantBatchInput.currentValue
        or CraftSim.SALVAGE_STATS_DATA.DISENCHANT_DEFAULT_BATCH_SIZE

    for index, button in ipairs(disenchantContent.disenchantVariantButtons) do
        button:SetEnabled(index ~= disenchantIndex)
    end

    if disenchantData then
        local inputItemID = disenchantData.itemIDs[1]
        local inputUnitPrice = CraftSim.PRICE_SOURCE:GetMinBuyoutByItemID(inputItemID, true) or 0
        local disenchantResult = CraftSim.SALVAGE_STATS:CalculateStats(
            disenchantData, disenchantBatchSize, inputUnitPrice, true, inputItemID)
        local inputLabel = getFallbackItemLabel(inputItemID) .. " x" .. tostring(disenchantBatchSize)
        updateSummary(disenchantContent, "disenchant", disenchantResult, inputLabel,
            L("SALVAGE_STATS_DISENCHANT_NOTE"))
        updateDropList(disenchantContent.disenchantDropList, disenchantResult)
    end

    local selectedMillingItemID, resolvedMillingData = resolveSelectedInput(
        millingContent, "milling", recipeData, function(itemID)
            return CraftSim.SALVAGE_STATS:GetMillingDataByItemID(itemID)
        end)
    local millingBatchSize = millingContent.millingBatchInput.currentValue
        or CraftSim.SALVAGE_STATS_DATA.MILLING_DEFAULT_BATCH_SIZE

    if resolvedMillingData and selectedMillingItemID then
        local inputUnitPrice = CraftSim.PRICE_SOURCE:GetMinBuyoutByItemID(selectedMillingItemID, true) or 0
        local millingResult = CraftSim.SALVAGE_STATS:CalculateStats(
            resolvedMillingData, millingBatchSize, inputUnitPrice, true, selectedMillingItemID)

        updateSummary(millingContent, "milling", millingResult, nil, L("SALVAGE_STATS_MILLING_NOTE"))
        updateDropList(millingContent.millingDropList, millingResult)
    else
        updateSummary(millingContent, "milling", nil, nil, L("SALVAGE_STATS_MILLING_NOTE"))
        updateDropList(millingContent.millingDropList, nil)
    end
end

function CraftSim.SALVAGE_STATS.UI:RestoreFrameConfig()
    if not CraftSim.SALVAGE_STATS.frame then
        return
    end
    CraftSim.SALVAGE_STATS.frame:RestoreSavedConfig(ProfessionsFrame)
end

function CraftSim.SALVAGE_STATS.UI:VisibleByContext()
    if not self.module or not CraftSim.DB.OPTIONS:IsModuleEnabled(self.module.moduleID) then
        return false
    end

    if not CraftSim.UTIL:GetSchematicFormByContext() then
        return false
    end

    local selectedTab = CraftSim.UTIL:GetSelectedProfessionTab()
    local isRecipeTab = selectedTab == CraftSim.CONST.PROFESSIONS_TAB.RECIPE
    return isRecipeTab
end
