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
local TAB_CONTENT_SIZE_Y = 400

---@param tabContent Frame
---@param listName string
---@param anchorParent Region
---@param offsetY number
---@return GGUI.FrameList
local function createDropList(tabContent, listName, anchorParent, offsetY)
    return GGUI.FrameList({
        parent = tabContent,
        anchorParent = anchorParent,
        anchorA = "TOP",
        anchorB = "BOTTOM",
        offsetY = offsetY,
        sizeX = TAB_CONTENT_SIZE_X - 20,
        sizeY = 200,
        showBorder = true,
        savedVariablesTableLayoutConfig = CraftSim.UTIL:GetFrameListLayoutConfig(listName),
        columnOptions = {
            {
                label = L("SALVAGE_STATS_ITEM_HEADER"),
                width = 180,
                justifyOptions = { type = "H", align = "LEFT" },
                resizable = true,
                headerScale = LIST_HEADER_SCALE,
            },
            {
                label = L("SALVAGE_STATS_RATE_HEADER"),
                width = 70,
                justifyOptions = { type = "H", align = "RIGHT" },
                resizable = true,
                headerScale = LIST_HEADER_SCALE,
            },
            {
                label = L("SALVAGE_STATS_EXPECTED_QTY_HEADER"),
                width = 70,
                justifyOptions = { type = "H", align = "RIGHT" },
                resizable = true,
                headerScale = LIST_HEADER_SCALE,
            },
            {
                label = L("SALVAGE_STATS_PRICE_HEADER"),
                width = 80,
                justifyOptions = { type = "H", align = "RIGHT" },
                resizable = true,
                headerScale = LIST_HEADER_SCALE,
            },
            {
                label = L("SALVAGE_STATS_VALUE_HEADER"),
                width = 90,
                justifyOptions = { type = "H", align = "RIGHT" },
                resizable = true,
                headerScale = LIST_HEADER_SCALE,
            },
        },
        rowConstructor = function(columns)
            for _, column in ipairs(columns) do
                column.text = GGUI.Text({
                    parent = column,
                    anchorParent = column,
                    justifyOptions = column.justifyOptions,
                    anchorA = "LEFT",
                    anchorB = "LEFT",
                    offsetX = 5,
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
        offsetX = 8,
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
        scale = 0.9,
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

    for _, drop in ipairs(result.drops) do
        local item = Item:CreateFromItemID(drop.itemID)
        local itemLink = item:GetItemLink()
        local itemText = itemLink or ("item:" .. drop.itemID)
        local rateText = GUTIL:Round(drop.dropRate * 100, 2) .. "%"
        local qtyText = tostring(drop.expectedQty)
        local priceText = CraftSim.UTIL:FormatMoney(drop.price, true)
        local valueText = CraftSim.UTIL:FormatMoney(drop.expectedValue, true)

        dropList:Add(function(_, columns)
            columns[1].text:SetText(itemText)
            columns[2].text:SetText(rateText)
            columns[3].text:SetText(qtyText)
            columns[4].text:SetText(priceText)
            columns[5].text:SetText(valueText)
        end)
    end

    dropList:UpdateDisplay()
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

        local prospectingContent = parentFrame.content.prospectingTab.content
        initSummarySection(prospectingContent, "prospecting")
        prospectingContent.prospectingDropList = createDropList(
            prospectingContent, "SALVAGE_STATS_PROSPECTING_LIST", prospectingContent.prospectingNote.frame, -10)

        local disenchantContent = parentFrame.content.disenchantTab.content
        initSummarySection(disenchantContent, "disenchant")

        disenchantContent.disenchantVariantTitle = GGUI.Text({
            parent = disenchantContent,
            anchorParent = disenchantContent.disenchantNote.frame,
            anchorA = "TOPLEFT",
            anchorB = "BOTTOMLEFT",
            offsetY = -8,
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
                offsetY = index == 1 and -8 or 0,
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

        local variantButton = disenchantContent.disenchantVariantButtons[1]
        disenchantContent.disenchantDropList = createDropList(
            disenchantContent, "SALVAGE_STATS_DISENCHANT_LIST", variantButton.frame, -10)

        GGUI.BlizzardTabSystem { parentFrame.content.prospectingTab, parentFrame.content.disenchantTab }
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

    local prospectingData = CraftSim.SALVAGE_STATS:GetProspectingDataForRecipe(recipeData)
    local prospectingBatchSize = prospectingContent.prospectingBatchInput.currentValue
        or CraftSim.SALVAGE_STATS_DATA.PROSPECTING_DEFAULT_BATCH_SIZE

    if prospectingData and recipeData then
        local activeItem = recipeData.reagentData.salvageReagentSlot.activeItem
        local inputUnitPrice = CraftSim.PRICE_SOURCE:GetMinBuyoutByItemID(activeItem:GetItemID(), true) or 0
        local prospectingResult = CraftSim.SALVAGE_STATS:CalculateStats(prospectingData, prospectingBatchSize, inputUnitPrice)
        local inputLabel = (activeItem:GetItemLink() or prospectingData.label) ..
            " x" .. tostring(prospectingBatchSize)

        updateSummary(prospectingContent, "prospecting", prospectingResult, inputLabel,
            L("SALVAGE_STATS_PROSPECTING_NOTE"))
        updateDropList(prospectingContent.prospectingDropList, prospectingResult)
    else
        updateSummary(prospectingContent, "prospecting", nil, L("SALVAGE_STATS_NO_PROSPECTING_DATA"),
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
        local inputUnitPrice = CraftSim.PRICE_SOURCE:GetMinBuyoutByItemID(disenchantData.itemIDs[1], true) or 0
        local disenchantResult = CraftSim.SALVAGE_STATS:CalculateStats(disenchantData, disenchantBatchSize, inputUnitPrice)
        local inputItem = Item:CreateFromItemID(disenchantData.itemIDs[1])
        local inputLabel = (inputItem:GetItemLink() or disenchantData.label) ..
            " x" .. tostring(disenchantBatchSize)

        updateSummary(disenchantContent, "disenchant", disenchantResult, inputLabel,
            L("SALVAGE_STATS_DISENCHANT_NOTE"))
        updateDropList(disenchantContent.disenchantDropList, disenchantResult)
    end
end

function CraftSim.SALVAGE_STATS.UI:RestoreFrameConfig()
    CraftSim.SALVAGE_STATS.frame:RestoreSavedConfig(ProfessionsFrame)
end

function CraftSim.SALVAGE_STATS.UI:VisibleByContext()
    if not CraftSim.DB.OPTIONS:IsModuleEnabled(self.module.moduleID) then
        return false
    end

    if not CraftSim.UTIL:GetSchematicFormByContext() then
        return false
    end

    local selectedTab = CraftSim.UTIL:GetSelectedProfessionTab()
    local isRecipeTab = selectedTab == CraftSim.CONST.PROFESSIONS_TAB.RECIPE
    if not isRecipeTab then
        return false
    end

    local recipeData = CraftSim.MODULES.recipeData
    return recipeData ~= nil and recipeData.isSalvageRecipe
end
