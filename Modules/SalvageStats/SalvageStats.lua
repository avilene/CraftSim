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

---@class CraftSim.SALVAGE_STATS : CraftSim.Module
CraftSim.SALVAGE_STATS = {}

CraftSim.MODULES:RegisterModule("MODULE_SALVAGE_STATS", CraftSim.SALVAGE_STATS, {
    label = L("CONTROL_PANEL_MODULES_SALVAGE_STATS_LABEL"),
    tooltip = L("CONTROL_PANEL_MODULES_SALVAGE_STATS_TOOLTIP"),
})

GUTIL:RegisterCustomEvents(CraftSim.SALVAGE_STATS, {
    "CRAFTSIM_RECIPE_DATA_UPDATED",
    "CRAFTSIM_RECIPE_DATA_MODIFIED",
})

---@type GGUI.Frame
CraftSim.SALVAGE_STATS.frame = nil

local Logger = CraftSim.DEBUG:RegisterLogger("SalvageStats")

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

---@param recipeData CraftSim.RecipeData
function CraftSim.SALVAGE_STATS:CRAFTSIM_RECIPE_DATA_UPDATED(recipeData)
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
