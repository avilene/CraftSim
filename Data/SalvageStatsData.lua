---@class CraftSim
local CraftSim = select(2, ...)

--- Drop rates sourced from Penguinr2gt's Midnight Profession Spreadsheet.
--- Prospecting rates assume ~25% resourcefulness and are per ore unit.
--- Disenchant shuffle rates do not include resourcefulness.

---@class CraftSim.SalvageStatsDrop
---@field itemID number
---@field dropRate number

---@class CraftSim.SalvageStatsInputData
---@field itemIDs number[]
---@field label string
---@field defaultBatchSize number
---@field drops CraftSim.SalvageStatsDrop[]
---@field ratesIncludeResourcefulness boolean?
---@field resourcefulnessNotIncluded boolean?

CraftSim.SALVAGE_STATS_DATA = {
    PROSPECTING_DEFAULT_BATCH_SIZE = 2000,
    DISENCHANT_DEFAULT_BATCH_SIZE = 1000,

    ---@type CraftSim.SalvageStatsInputData[]
    PROSPECTING = {
        {
            label = "Umbral Tin",
            itemIDs = { 237362, 237363 },
            defaultBatchSize = 2000,
            ratesIncludeResourcefulness = true,
            drops = {
                { itemID = 242720, dropRate = 0.0239 }, -- Harandar Peridot
                { itemID = 242726, dropRate = 0.0216 }, -- Flawless Harandar Peridot
                { itemID = 242721, dropRate = 0.0260 }, -- Tenebrous Amethyst
                { itemID = 242725, dropRate = 0.0234 }, -- Flawless Tenebrous Amethyst
                { itemID = 242787, dropRate = 0.1783 }, -- Crystalline Glass
                { itemID = 242789, dropRate = 0.2221 }, -- Dusk-Shrouded Stone
                { itemID = 242712, dropRate = 0.0116 }, -- Eversong Diamond
            },
        },
        {
            label = "Brilliant Silver",
            itemIDs = { 237364, 237365 },
            defaultBatchSize = 2000,
            ratesIncludeResourcefulness = true,
            drops = {
                { itemID = 242723, dropRate = 0.0237 }, -- Sanguine Garnet
                { itemID = 242724, dropRate = 0.0247 }, -- Flawless Sanguine Garnet
                { itemID = 242722, dropRate = 0.0260 }, -- Amani Lapis
                { itemID = 242727, dropRate = 0.0272 }, -- Flawless Amani Lapis
                { itemID = 242787, dropRate = 0.1614 }, -- Crystalline Glass
                { itemID = 242789, dropRate = 0.2472 }, -- Dusk-Shrouded Stone
                { itemID = 242712, dropRate = 0.0112 }, -- Eversong Diamond
            },
        },
    },

    ---@type CraftSim.SalvageStatsInputData[]
    DISENCHANT_SHUFFLE = {
        {
            label = "Evercore (Rank 1)",
            itemIDs = { 243581 },
            defaultBatchSize = 1000,
            resourcefulnessNotIncluded = true,
            drops = {
                { itemID = 243602, dropRate = 0.5111 }, -- Radiant Shard R1
                { itemID = 243603, dropRate = 0.7764 }, -- Radiant Shard R2
                { itemID = 236761, dropRate = 0.0722 }, -- Tranquility Bloom R1
                { itemID = 238513, dropRate = 0.0653 }, -- Void-Tempered Scales R1
                { itemID = 238511, dropRate = 0.0583 }, -- Void-Tempered Leather R1
                { itemID = 236963, dropRate = 0.0611 }, -- Bright Linen R1
                { itemID = 237359, dropRate = 0.0486 }, -- Refulgent Copper Ore R1
            },
        },
        {
            label = "Evercore (Rank 2)",
            itemIDs = { 243582 },
            defaultBatchSize = 1000,
            resourcefulnessNotIncluded = true,
            drops = {
                { itemID = 243602, dropRate = 0.3988 }, -- Radiant Shard R1
                { itemID = 243603, dropRate = 0.8973 }, -- Radiant Shard R2
                { itemID = 236761, dropRate = 0.0559 }, -- Tranquility Bloom R1
                { itemID = 238513, dropRate = 0.0604 }, -- Void-Tempered Scales R1
                { itemID = 238511, dropRate = 0.0544 }, -- Void-Tempered Leather R1
                { itemID = 236963, dropRate = 0.0589 }, -- Bright Linen R1
                { itemID = 237359, dropRate = 0.0574 }, -- Refulgent Copper Ore R1
            },
        },
    },
}
