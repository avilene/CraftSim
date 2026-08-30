---@class CraftSim
local CraftSim = select(2, ...)

local GUTIL = CraftSim.GUTIL
local L = CraftSim.LOCAL:GetLocalizer()

---@class CraftSim.SalvageStatsDropResult : CraftSim.SalvageStatsDrop
---@field expectedQty number
---@field price number
---@field expectedValue number

---@class CraftSim.SalvageStatsCalculationResult
---@field inputCount number
---@field inputUnitPrice number
---@field inputCost number
---@field totalValue number
---@field saleValue number
---@field profit number
---@field drops CraftSim.SalvageStatsDropResult[]

---@class CraftSim.SalvageStatsProspectingSession
---@field tracking boolean
---@field itemID number?
---@field crafts number
---@field oreConsumed number
---@field observedQty table<number, number>

---@class CraftSim.SalvageStatsDropComparison
---@field observedQty number
---@field observedRate number
---@field sessionExpectedQty number
---@field matchStatus "ok" | "close" | "off" | "low"

---@class CraftSim.SALVAGE_STATS : CraftSim.Module
CraftSim.SALVAGE_STATS = GUTIL:CreateRegistreeForEvents({
    "TRADE_SKILL_ITEM_CRAFTED_RESULT",
    "TRADE_SKILL_CRAFT_BEGIN",
    "UNIT_SPELLCAST_SUCCEEDED",
})

CraftSim.MODULES:RegisterModule("MODULE_SALVAGE_STATS", CraftSim.SALVAGE_STATS, {
    label = L("CONTROL_PANEL_MODULES_SALVAGE_STATS_LABEL"),
    tooltip = L("CONTROL_PANEL_MODULES_SALVAGE_STATS_TOOLTIP"),
})

GUTIL:RegisterCustomEvents(CraftSim.SALVAGE_STATS, {
    "CRAFTSIM_RECIPE_DATA_UPDATED",
    "CRAFTSIM_RECIPE_DATA_MODIFIED",
    "CRAFTSIM_CRAFT_RECIPE_DATA_PREPARED",
})

---@type GGUI.Frame
CraftSim.SALVAGE_STATS.frame = nil

local Logger = CraftSim.DEBUG:RegisterLogger("SalvageStats")

---@type CraftSim.RecipeData?
CraftSim.SALVAGE_STATS.lastCraftRecipeData = nil

---@return CraftSim.SalvageStatsProspectingSession
function CraftSim.SALVAGE_STATS:CreateEmptyProspectingSession()
    return {
        tracking = false,
        itemID = nil,
        crafts = 0,
        oreConsumed = 0,
        observedQty = {},
    }
end

---@type CraftSim.SalvageStatsProspectingSession
CraftSim.SALVAGE_STATS.prospectingSession = CraftSim.SALVAGE_STATS:CreateEmptyProspectingSession()

---@param itemID number
---@return CraftSim.SalvageStatsInputData?
function CraftSim.SALVAGE_STATS:GetProspectingDataByItemID(itemID)
    for _, data in ipairs(CraftSim.SALVAGE_STATS_DATA.PROSPECTING) do
        for _, id in ipairs(data.itemIDs) do
            if id == itemID then
                return data
            end
        end
    end
end

---@param itemID number
---@return CraftSim.SalvageStatsInputData?
function CraftSim.SALVAGE_STATS:GetDisenchantDataByItemID(itemID)
    for _, data in ipairs(CraftSim.SALVAGE_STATS_DATA.DISENCHANT_SHUFFLE) do
        for _, id in ipairs(data.itemIDs) do
            if id == itemID then
                return data
            end
        end
    end
end

---@param itemID number
---@return CraftSim.SalvageStatsInputData?
function CraftSim.SALVAGE_STATS:GetMillingDataByItemID(itemID)
    for _, data in ipairs(CraftSim.SALVAGE_STATS_DATA.MILLING) do
        for _, id in ipairs(data.itemIDs) do
            if id == itemID then
                return data
            end
        end
    end
end

---@param inputData CraftSim.SalvageStatsInputData
---@param activeInputItemID number?
---@return CraftSim.SalvageStatsDrop[]
function CraftSim.SALVAGE_STATS:ResolveDrops(inputData, activeInputItemID)
    if inputData.pigmentItemIDs and activeInputItemID then
        for index, itemID in ipairs(inputData.itemIDs) do
            if itemID == activeInputItemID then
                return {
                    {
                        itemID = inputData.pigmentItemIDs[index],
                        dropRate = inputData.pigmentsPerHerb or CraftSim.SALVAGE_STATS_DATA.MILLING_PIGMENTS_PER_HERB,
                    },
                }
            end
        end
    end

    return inputData.drops
end

---@param recipeData CraftSim.RecipeData?
---@return CraftSim.SalvageStatsInputData?
function CraftSim.SALVAGE_STATS:GetMillingDataForRecipe(recipeData)
    if not recipeData or not recipeData.isSalvageRecipe then
        return nil
    end

    local activeItem = recipeData.reagentData.salvageReagentSlot.activeItem
    if not activeItem then
        return nil
    end

    return self:GetMillingDataByItemID(activeItem:GetItemID())
end

---@param entries CraftSim.SalvageStatsInputData[]
---@return number[]
function CraftSim.SALVAGE_STATS:GetAllInputItemIDs(entries)
    local itemIDs = {}
    for _, data in ipairs(entries) do
        for _, itemID in ipairs(data.itemIDs) do
            table.insert(itemIDs, itemID)
        end
    end
    return itemIDs
end

---@param recipeData CraftSim.RecipeData?
---@return CraftSim.SalvageStatsInputData?
function CraftSim.SALVAGE_STATS:GetProspectingDataForRecipe(recipeData)
    if not recipeData or not recipeData.isSalvageRecipe then
        return nil
    end

    local activeItem = recipeData.reagentData.salvageReagentSlot.activeItem
    if not activeItem then
        return nil
    end

    return self:GetProspectingDataByItemID(activeItem:GetItemID())
end

---@param inputData CraftSim.SalvageStatsInputData
---@param inputCount number
---@param inputUnitPrice number?
---@param applyAHCut boolean?
---@param activeInputItemID number?
---@return CraftSim.SalvageStatsCalculationResult
function CraftSim.SALVAGE_STATS:CalculateStats(inputData, inputCount, inputUnitPrice, applyAHCut, activeInputItemID)
    inputCount = math.max(0, math.floor(inputCount or 0))
    applyAHCut = applyAHCut ~= false

    local resolvedInputPrice = inputUnitPrice
    if resolvedInputPrice == nil then
        local priceItemID = activeInputItemID or inputData.itemIDs[1]
        resolvedInputPrice = CraftSim.PRICE_SOURCE:GetMinBuyoutByItemID(priceItemID, true) or 0
    end

    local totalValue = 0
    local dropResults = {}
    local drops = self:ResolveDrops(inputData, activeInputItemID)

    for _, drop in ipairs(drops) do
        local expectedQty = math.floor(inputCount * drop.dropRate)
        local price = CraftSim.PRICE_SOURCE:GetMinBuyoutByItemID(drop.itemID, true) or 0
        local expectedValue = expectedQty * price
        totalValue = totalValue + expectedValue

        table.insert(dropResults, {
            itemID = drop.itemID,
            dropRate = drop.dropRate,
            expectedQty = expectedQty,
            price = price,
            expectedValue = expectedValue,
        })
    end

    local inputCost = inputCount * resolvedInputPrice
    local saleValue = applyAHCut and (totalValue * CraftSim.CONST.AUCTION_HOUSE_CUT) or totalValue
    local profit = saleValue - inputCost

    return {
        inputCount = inputCount,
        inputUnitPrice = resolvedInputPrice,
        inputCost = inputCost,
        totalValue = totalValue,
        saleValue = saleValue,
        profit = profit,
        drops = dropResults,
    }
end

---@param itemIDA number?
---@param itemIDB number?
---@return boolean
function CraftSim.SALVAGE_STATS:IsSameProspectingInput(itemIDA, itemIDB)
    if not itemIDA or not itemIDB then
        return false
    end
    local dataA = self:GetProspectingDataByItemID(itemIDA)
    local dataB = self:GetProspectingDataByItemID(itemIDB)
    return dataA ~= nil and dataA == dataB
end

---@param session CraftSim.SalvageStatsProspectingSession?
---@param selectedItemID number?
---@return boolean
function CraftSim.SALVAGE_STATS:SessionMatchesSelectedOre(session, selectedItemID)
    if not session or not session.itemID or not selectedItemID then
        return false
    end
    return self:IsSameProspectingInput(session.itemID, selectedItemID)
end

---@param dropRate number
---@param observedQty number
---@param oreConsumed number
---@return CraftSim.SalvageStatsDropComparison
function CraftSim.SALVAGE_STATS:GetDropComparison(dropRate, observedQty, oreConsumed)
    oreConsumed = oreConsumed or 0
    observedQty = observedQty or 0
    dropRate = dropRate or 0

    local sessionExpectedQty = oreConsumed * dropRate
    local observedRate = oreConsumed > 0 and (observedQty / oreConsumed) or 0
    local matchStatus = "low"

    if oreConsumed > 0 then
        local sd = math.sqrt(math.max(sessionExpectedQty, 0.25))
        local z = math.abs(observedQty - sessionExpectedQty) / sd

        if sessionExpectedQty < 2 then
            if observedQty >= 5 then
                matchStatus = "off"
            else
                matchStatus = "low"
            end
        elseif z <= 1.5 then
            matchStatus = "ok"
        elseif z <= 2.5 then
            matchStatus = "close"
        else
            matchStatus = "off"
        end
    end

    return {
        observedQty = observedQty,
        observedRate = observedRate,
        sessionExpectedQty = sessionExpectedQty,
        matchStatus = matchStatus,
    }
end

---@param itemID number?
function CraftSim.SALVAGE_STATS:ToggleProspectingTracking(itemID)
    local session = self.prospectingSession
    if session.tracking then
        session.tracking = false
        Logger:LogDebug("Stopped prospecting tracking")
    else
        if not itemID or not self:GetProspectingDataByItemID(itemID) then
            return
        end
        if session.itemID and not self:IsSameProspectingInput(session.itemID, itemID) then
            self.prospectingSession = self:CreateEmptyProspectingSession()
            session = self.prospectingSession
        end
        session.tracking = true
        session.itemID = itemID
        Logger:LogDebug("Started prospecting tracking for itemID {itemID}", itemID)
    end

    if self.UI then
        self.UI:Update(CraftSim.MODULES.recipeData)
    end
end

function CraftSim.SALVAGE_STATS:ResetProspectingTracking()
    local wasTracking = self.prospectingSession.tracking
    local itemID = self.prospectingSession.itemID
    self.prospectingSession = self:CreateEmptyProspectingSession()
    if wasTracking then
        self.prospectingSession.tracking = true
        self.prospectingSession.itemID = itemID
    end
    Logger:LogDebug("Reset prospecting tracking")
    if self.UI then
        self.UI:Update(CraftSim.MODULES.recipeData)
    end
end

---@param recipeData CraftSim.RecipeData
function CraftSim.SALVAGE_STATS:CRAFTSIM_CRAFT_RECIPE_DATA_PREPARED(recipeData)
    self.lastCraftRecipeData = recipeData
end

---@param recipeData CraftSim.RecipeData
function CraftSim.SALVAGE_STATS:CRAFTSIM_RECIPE_DATA_UPDATED(recipeData)
    if recipeData then
        self.lastCraftRecipeData = recipeData
    end
    if not CraftSim.DB.OPTIONS:IsModuleEnabled(self.moduleID) then
        return
    end
    self.UI:Update(recipeData)
end

function CraftSim.SALVAGE_STATS:CRAFTSIM_RECIPE_DATA_MODIFIED()
    if not CraftSim.DB.OPTIONS:IsModuleEnabled(self.moduleID) then
        return
    end
    self.UI:Update(CraftSim.MODULES.recipeData)
end

local craftSpellIdInProgress = nil
local craftCount = 0
---@type CraftingItemResultData[]
local accumulatingCraftingItemResultData = {}
local isAccumulatingCraftingItemResultData = true

function CraftSim.SALVAGE_STATS:TRADE_SKILL_CRAFT_BEGIN(spellID)
    if not self.prospectingSession.tracking then
        return
    end
    if craftSpellIdInProgress ~= spellID then
        craftCount = 0
    end
    craftSpellIdInProgress = spellID
end

function CraftSim.SALVAGE_STATS:UNIT_SPELLCAST_SUCCEEDED(unit, _, spellID)
    if not self.prospectingSession.tracking then
        return
    end
    if unit ~= "player" then
        return
    end
    if spellID == craftSpellIdInProgress then
        craftCount = craftCount + 1
    end
end

---@param craftingItemResultData CraftingItemResultData
function CraftSim.SALVAGE_STATS:TRADE_SKILL_ITEM_CRAFTED_RESULT(craftingItemResultData)
    if not self.prospectingSession.tracking then
        return
    end
    if not CraftSim.DB.OPTIONS:IsModuleEnabled(self.moduleID) then
        return
    end

    table.insert(accumulatingCraftingItemResultData, craftingItemResultData)

    if isAccumulatingCraftingItemResultData then
        isAccumulatingCraftingItemResultData = false
        C_Timer.After(0.1, function()
            CraftSim.SALVAGE_STATS:AccumulateProspectingResults()
        end)
    end
end

function CraftSim.SALVAGE_STATS:AccumulateProspectingResults()
    isAccumulatingCraftingItemResultData = true

    local collectedCraftingItemResultData = accumulatingCraftingItemResultData
    accumulatingCraftingItemResultData = {}

    local session = self.prospectingSession
    if not session.tracking then
        craftCount = 0
        return
    end

    local recipeData = self.lastCraftRecipeData or CraftSim.CRAFT_LOG.currentRecipeData or CraftSim.MODULES.recipeData
    if not recipeData or not recipeData.isSalvageRecipe then
        craftCount = 0
        return
    end

    local slot = recipeData.reagentData and recipeData.reagentData.salvageReagentSlot
    local salvageItem = slot and slot.activeItem
    local salvageItemID = salvageItem and salvageItem:GetItemID()
    if not salvageItemID or not self:GetProspectingDataByItemID(salvageItemID) then
        craftCount = 0
        return
    end

    if session.itemID and not self:IsSameProspectingInput(session.itemID, salvageItemID) then
        craftCount = 0
        return
    end

    if GUTIL:Find(collectedCraftingItemResultData, function(result) return result.isEnchant end) then
        craftCount = 0
        return
    end

    local crafts = craftCount
    if crafts <= 0 then
        crafts = 1
    end
    craftCount = 0

    session.itemID = session.itemID or salvageItemID
    session.crafts = session.crafts + crafts
    session.oreConsumed = session.oreConsumed + ((slot.requiredQuantity or 0) * crafts)

    for _, craftingItemResult in ipairs(collectedCraftingItemResultData) do
        if craftingItemResult.hyperlink then
            local itemID = C_Item.GetItemInfoInstant(craftingItemResult.hyperlink)
            if itemID and not self:IsSameProspectingInput(itemID, salvageItemID) then
                local quantity = craftingItemResult.quantity or 0
                session.observedQty[itemID] = (session.observedQty[itemID] or 0) + quantity
            end
        end
    end

    Logger:LogDebug("Prospecting session crafts={crafts} ore={ore}", session.crafts, session.oreConsumed)

    if self.UI then
        self.UI:Update(recipeData)
    end
end
