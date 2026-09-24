---@class CraftSim
local CraftSim = select(2, ...)
local CraftSimAddonName = select(1, ...)

---@class CraftSim.SPECIALIZATION_DATA
CraftSim.SPECIALIZATION_DATA = {}
CraftSim.SPECIALIZATION_DATA.DRAGONFLIGHT = {}
CraftSim.SPECIALIZATION_DATA.THE_WAR_WITHIN = {}
CraftSim.SPECIALIZATION_DATA.MIDNIGHT = {}

local GUTIL = CraftSim.GUTIL

local f = GUTIL:GetFormatter()
local L = CraftSim.LOCAL:GetLocalizer()

---@class CraftSim.INIT : Frame
local initEvents = {
	"ADDON_LOADED",
	"PLAYER_LOGIN",
	"PLAYER_ENTERING_WORLD",
	"TRADE_SKILL_FAVORITES_CHANGED",
	"TRADE_SKILL_DATA_SOURCE_CHANGED",
	"TRADE_SKILL_SHOW",
	"CRAFTING_DETAILS_UPDATE",
}
if CraftSim.CONST.WORK_ORDERS_ENABLED then
	tinsert(initEvents, "CRAFTINGORDERS_CAN_REQUEST")
end
CraftSim.INIT = GUTIL:CreateRegistreeForEvents(CraftSim.UTIL:FilterKnownEvents(initEvents))

GUTIL:RegisterCustomEvents(CraftSim.INIT, {
	"CRAFTSIM_OPEN_RECIPE_INFO_UPDATED",
	"CRAFTSIM_PROFESSION_INITIALIZED",
	"CRAFTSIM_RECIPE_INFO_INITIALIZED",
	"CRAFTSIM_PROFESSION_OPENED",
	"CRAFTSIM_PROFESSION_TAB_CLICKED",
	"CRAFTSIM_ORDER_VIEW_CLOSED",
	"CRAFTSIM_CRAFT_BUFFS_UPDATED",
	"CRAFTSIM_AUCTIONATOR_DB_UPDATED",
})

---@type number?
CraftSim.INIT.initialRecipeID = nil
CraftSim.INIT.initialLogin = false
CraftSim.INIT.isReloadingUI = false
--- Shared GGUI frame registry used to reset/restore window positions.
---@type table<string, GGUI.Frame>
CraftSim.INIT.FRAMES = {}

local Logger = CraftSim.DEBUG:RegisterLogger("Init")

local professionFrameHooked = false
local craftingOrdersPreloadedThisSession = {}
---@type number?
local craftingOrdersPreloadPendingProfessionID = nil
local craftingOrdersCanRequest = false
---@type table?
local craftingOrdersPreloadFallbackTimer = nil

local function cancelCraftingOrdersPreloadFallback()
	if craftingOrdersPreloadFallbackTimer then
		craftingOrdersPreloadFallbackTimer:Cancel()
		craftingOrdersPreloadFallbackTimer = nil
	end
end

local function emitCraftingOrdersPreloaded()
	cancelCraftingOrdersPreloadFallback()
	craftingOrdersPreloadPendingProfessionID = nil
	local ms = CraftSim.DEBUG:StopProfiling("Preload Crafting Orders")
	Logger:LogDebug("Crafting orders preload ready in " .. tostring(ms) .. " ms")
	-- Let Blizzard's in-flight preload callback finish before CraftSim queues work orders.
	RunNextFrame(function()
		RunNextFrame(function()
			if ProfessionsFrame and ProfessionsFrame:IsVisible() then
				GUTIL:TriggerCustomEvent("CRAFTSIM_CRAFTING_ORDERS_PRELOADED")
			end
		end)
	end)
end

local function tryEmitCraftingOrdersPreloaded()
	local professionID = craftingOrdersPreloadPendingProfessionID
	if not professionID then
		return
	end
	if not ProfessionsFrame or not ProfessionsFrame:IsVisible() then
		craftingOrdersPreloadPendingProfessionID = nil
		cancelCraftingOrdersPreloadFallback()
		return
	end
	if not craftingOrdersCanRequest then
		return
	end
	if not CraftSim.INIT:IsProfessionReady() then
		return
	end
	emitCraftingOrdersPreloaded()
end

function CraftSim.INIT:CRAFTINGORDERS_CAN_REQUEST()
	craftingOrdersCanRequest = true
	tryEmitCraftingOrdersPreloaded()
end

function CraftSim.INIT:TRADE_SKILL_FAVORITES_CHANGED(isFavoriteNow, recipeID)
	-- adapt cached values
	local crafterUID = CraftSim.UTIL:GetPlayerCrafterUID()
	local professionInfo = C_TradeSkillUI.GetChildProfessionInfo()

	if not professionInfo then return end

	local profession = professionInfo.profession

	if not profession then return end



	CraftSim.DB.CRAFTER:UpdateFavoriteRecipe(crafterUID, profession, recipeID, isFavoriteNow)
end

function CraftSim.INIT:PLAYER_ENTERING_WORLD(initialLogin, isReloadingUI)
	CraftSim.UTIL:InvalidatePlayerCrafterDataCache()
	CraftSim.INIT.initialLogin = initialLogin
	CraftSim.INIT.isReloadingUI = isReloadingUI

	-- for any processes that may only happen once a session e.g.
	if initialLogin then
		-- clear post loaded multicraft professions
		CraftSim.DB.MULTICRAFT_PRELOAD:ClearAll()

		local professionIndices = { GetProfessions() }
		local professions = GUTIL:Map(professionIndices, function(professionIndex)
			local skillLineID = select(7, GetProfessionInfo(professionIndex))
			return CraftSim.UTIL:GetProfessionBySkillLineID(skillLineID)
		end)
		CraftSim.DB.MULTICRAFT_PRELOAD:InitializeRecipes(professions)
	end

	local crafterUID = CraftSim.UTIL:GetPlayerCrafterUID()
	CraftSim.PRE_CRAFT_BUFF_GATE:OnPlayerEnteringWorld(initialLogin, isReloadingUI)

	-- load craft queue
	CraftSim.CRAFTQ:InitializeCraftQueue()
end

function CraftSim.INIT:TRADE_SKILL_SHOW()
	CraftSim.DEBUG:StartProfiling("TradeSkill Opening Load")
end

function CraftSim.INIT:CRAFTING_DETAILS_UPDATE()
	Logger:LogInfo("CRAFTING_DETAILS_UPDATE")
end

function CraftSim.INIT:TRADE_SKILL_DATA_SOURCE_CHANGED()
	-- log what info is available on the first show of the profession frame after login/reload, to better understand when we can trigger our updates without missing info
	local professionInfo = C_TradeSkillUI.GetChildProfessionInfo()
	if professionInfo then
		Logger:LogInfo("TRADE_SKILL_DATA_SOURCE_CHANGED: professionInfo available - {professionInfo}", professionInfo)
	else
		Logger:LogInfo("TRADE_SKILL_DATA_SOURCE_CHANGED: professionInfo not available")
	end

	Logger:LogInfo("TRADE_SKILL_DATA_SOURCE_CHANGED: TradeSkillReady - {tradeSkillReady}",
		C_TradeSkillUI.IsTradeSkillReady())

	local selectedTab = CraftSim.PROFESSIONS_UI:GetSelectedProfessionTab()
		or CraftSim.CONST.PROFESSIONS_TAB.RECIPE

	GUTIL:TriggerCustomEvent("CRAFTSIM_PROFESSION_OPENED", professionInfo, selectedTab, CraftSim.INIT.initialLogin,
		CraftSim.INIT.isReloadingUI)
end

---@param professionInfo ProfessionInfo
---@param selectedTab CraftSim.PROFESSIONS_TAB
function CraftSim.INIT:CRAFTSIM_PROFESSION_OPENED(professionInfo, selectedTab, isLogin, isReload)
	if not professionInfo then return end

	local profession = professionInfo.profession
	Logger:LogInfo(
		"Profession Opened: {profession}, selectedTab: {selectedTab}, isLogin: {isLogin}, isReload: {isReload}",
		profession, selectedTab, isLogin, isReload)

	CraftSim.DEBUG:StopProfiling("TradeSkill Opening Load")
end

---@param recipeInfo TradeSkillRecipeInfo?
function CraftSim.INIT:CRAFTSIM_OPEN_RECIPE_INFO_UPDATED(recipeInfo)
	if recipeInfo and recipeInfo.recipeID then
		Logger:LogDebug("OpenRecipeChanged: {recipeID}", tostring(recipeInfo.recipeID))
		CraftSim.INIT.initialRecipeID = recipeInfo.recipeID
		CraftSim.INIT:InitializeVisibleRecipeID()
	end
end

---@param tab CraftSim.PROFESSIONS_TAB
function CraftSim.INIT:CRAFTSIM_PROFESSION_TAB_CLICKED(tab)
	CraftSim.MODULES:UpdateVisibilityByContext()

	-- if recipe/crafting order tab was clicked, the Init hook will trigger and any recipedata update will fire automatically
	-- so we just need to tend to the module visibilities
end

local lastCallTime = 0
function CraftSim.INIT:InitializeVisibleRecipeID()
	local callTime = GetTime()
	if lastCallTime == callTime then
		Logger:LogVerbose("SAME FRAME, RETURN")
		return
	else
		Logger:LogVerbose("NEW FRAME, CONTINUE")
	end

	Logger:LogVerbose("lastCallTime: " .. tostring(lastCallTime))
	Logger:LogVerbose("callTime: " .. tostring(callTime))

	lastCallTime = callTime

	-- Poll until profession data dependencies are ready, then trigger event for all listeners
	GUTIL:WaitFor(function()
		return self:IsProfessionReady()
	end, function()
		GUTIL:TriggerCustomEvent("CRAFTSIM_PROFESSION_INITIALIZED")
	end)
end

function CraftSim.INIT:CRAFTSIM_PROFESSION_INITIALIZED()
	CraftSim.MODULES:UpdateVisibilityByContext()
	tryEmitCraftingOrdersPreloaded()

	-- Poll until current recipe info of RecipeID is available, then trigger event for all listeners
	GUTIL:WaitFor(function()
		local recipeID = CraftSim.INIT.initialRecipeID
		if recipeID then
			local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
			return recipeInfo ~= nil and recipeInfo.categoryID
		end
		return false
	end, function()
		local recipeInfo = C_TradeSkillUI.GetRecipeInfo(CraftSim.INIT.initialRecipeID)
		GUTIL:TriggerCustomEvent("CRAFTSIM_RECIPE_INFO_INITIALIZED", recipeInfo)
	end)
end

function CraftSim.INIT:CRAFTSIM_RECIPE_INFO_INITIALIZED()
	CraftSim.DEBUG:StartProfiling("Build Visible RecipeData")
	local recipeData = CraftSim.MODULES:GetRecipeDataFromVisibleRecipe()
	CraftSim.DEBUG:StopProfiling("Build Visible RecipeData")

	if not recipeData then
		Logger:LogWarning("Failed to build recipe data for visible recipe!")
		return
	end

	CraftSim.MODULES.recipeData = recipeData

	if CraftSim.SIMULATION_MODE.isActive then
		if not recipeData.recipeInfo.isRecraft and not recipeData.recipeInfo.isSalvageRecipe then
			Logger:LogDebug("Simulation Mode Active, using simulated recipe data")
			CraftSim.SIMULATION_MODE.recipeData = recipeData
			GUTIL:TriggerCustomEvent("CRAFTSIM_SIMULATION_MODE_ENABLED")
			return
		else
			-- if sim mode is active on a recraft or salvage, disable it
			CraftSim.SIMULATION_MODE.isActive = false
			GUTIL:TriggerCustomEvent("CRAFTSIM_SIMULATION_MODE_DISABLED")
		end
	end

	CraftSim.MODULES.recipeData = recipeData
	GUTIL:TriggerCustomEvent("CRAFTSIM_RECIPE_DATA_UPDATED", recipeData)
end

function CraftSim.INIT:HookToEvents()
	local function OpenRecipeAllocationUpdated(self)
		if CraftSim.SIMULATION_MODE.isActive then
			Logger:LogWarning("Simulation Mode Active, skip default ui allocation update")
			return
		end

		if not CraftSim.INIT.initialRecipeID then
			Logger:LogWarning("OpenRecipeAllocationUpdated: No visible recipe ID, return")
			return
		end
		if not CraftSim.MODULES.recipeData then
			Logger:LogWarning("OpenRecipeAllocationUpdated: No recipe data, return")
			return
		end

		if CraftSim.MODULES.recipeData.recipeID ~= CraftSim.INIT.initialRecipeID then
			Logger:LogWarning("OpenRecipeAllocationUpdated: recipeData not matching visible recipe ID, return")
			return
		end


		local recipeData = CraftSim.MODULES:GetRecipeDataFromVisibleRecipe()
		if recipeData then
			CraftSim.MODULES.recipeData = recipeData
			GUTIL:TriggerCustomEvent("CRAFTSIM_RECIPE_DATA_UPDATED", recipeData)
		end
	end

	local function OpenRecipeInfoUpdated(self, recipeInfo)
		if not self:IsVisible() then
			Logger:LogDebug("not visible, return")
			return
		end

		GUTIL:TriggerCustomEvent("CRAFTSIM_OPEN_RECIPE_INFO_UPDATED", recipeInfo)
	end

	if not ProfessionsFrame then
		Logger:LogDebug("HookToEvents skipped: no ProfessionsFrame")
		return
	end

	local hookFrame = ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SchematicForm
	if hookFrame then
		hooksecurefunc(hookFrame, "Init", OpenRecipeInfoUpdated)
		if ProfessionsRecipeSchematicFormMixin and ProfessionsRecipeSchematicFormMixin.Event then
			hookFrame:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified, OpenRecipeAllocationUpdated)
			hookFrame:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.UseBestQualityModified,
				OpenRecipeAllocationUpdated)
		end
	end

	if CraftSim.CONST.WORK_ORDERS_ENABLED and ProfessionsFrame.OrdersPage
		and ProfessionsFrame.OrdersPage.OrderView and ProfessionsFrame.OrdersPage.OrderView.OrderDetails then
		local hookFrame2 = ProfessionsFrame.OrdersPage.OrderView.OrderDetails.SchematicForm
		if hookFrame2 then
			hooksecurefunc(hookFrame2, "Init", OpenRecipeInfoUpdated)
			if ProfessionsRecipeSchematicFormMixin and ProfessionsRecipeSchematicFormMixin.Event then
				hookFrame2:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified,
					OpenRecipeAllocationUpdated)
				hookFrame2:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.UseBestQualityModified,
					OpenRecipeAllocationUpdated)
			end
		end
	end

	CraftSim.RECIPE_ACQUISITION:Init()

	CraftSim.PROFESSIONS_UI:HookContextChanges(function(tab)
		GUTIL:TriggerCustomEvent("CRAFTSIM_PROFESSION_TAB_CLICKED", tab)
	end)
end

function CraftSim.INIT:InitStaticPopups()
	StaticPopupDialogs["CRAFT_SIM_ACCEPT_NO_PRICESOURCE_WARNING"] = {
		text = "Are you sure you do not want to be reminded to get a price source?",
		button1 = "Yes",
		button2 = "No",
		OnAccept = function(self, data1, data2)
			CraftSim.DB.OPTIONS:Save("PRICE_SOURCE_REMINDER_DISABLED", true)
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3, -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
	}
end

function CraftSim.INIT:InitCraftRecipeHooks()
	if not C_TradeSkillUI then
		return
	end
	---@param onCraftData CraftSim.OnCraftData
	local function OnCraft(onCraftData)
		if C_TradeSkillUI.IsNPCCrafting() or C_TradeSkillUI.IsRuneforging() then
			return
		end

		---@type CraftSim.RecipeData
		local recipeData
		-- if craftsim did not call the api and we do not have reagents, use the one from the gui
		-- still need to check if craft comes from different source (other addons for example)
		if not CraftSim.CRAFTQ.CraftSimCalledCraftRecipe and CraftSim.MODULES.recipeData and CraftSim.MODULES.recipeData.recipeID == onCraftData.recipeID then
			-- craft was most probably started via default gui craft button
			Logger:LogDebug("api was called via default gui")
			recipeData = CraftSim.MODULES.recipeData:Copy()
		else
			-- if it does not match with current recipe data, create a new one based on the data forwarded to the crafting api
			recipeData = onCraftData:CreateRecipeData()
			recipeData.craftListID = CraftSim.CRAFTQ.currentlyCraftedCraftListID
		end

		CraftSim.CRAFTQ:SetCraftedRecipeData(recipeData, onCraftData.amount, onCraftData.itemTargetLocation,
			onCraftData.isEnchant)
		GUTIL:TriggerCustomEvent("CRAFTSIM_CRAFT_RECIPE_DATA_PREPARED", recipeData)
	end

	if type(C_TradeSkillUI.CraftRecipe) ~= "function" then
		return
	end
	hooksecurefunc(C_TradeSkillUI, "CraftRecipe",
		function(recipeID, amount, craftingReagentInfoTbl, recipeLevel, orderID, concentrating)
			local orderData = nil
			if orderID and CraftSim.CONST.WORK_ORDERS_ENABLED then
				orderData = C_CraftingOrders.GetClaimedOrder()
			end
			OnCraft(CraftSim.OnCraftData {
				recipeID = recipeID,
				amount = amount or 1,
				craftingReagentInfoTbl = craftingReagentInfoTbl or {},
				recipeLevel = recipeLevel,
				orderData = orderData,
				concentrating = concentrating,
				callerData = {
					api = "CraftRecipe",
					params = { recipeID, amount, craftingReagentInfoTbl, recipeLevel, orderID, concentrating },
				}
			})
		end)
	if type(C_TradeSkillUI.CraftEnchant) == "function" then
	hooksecurefunc(C_TradeSkillUI, "CraftEnchant",
		function(recipeID, amount, craftingReagentInfoTbl, enchantItemLocation, concentrating)
			OnCraft(CraftSim.OnCraftData {
				recipeID = recipeID,
				amount = amount or 1,
				craftingReagentInfoTbl = craftingReagentInfoTbl or {},
				itemTargetLocation = enchantItemLocation,
				isEnchant = true,
				concentrating = concentrating,
				callerData = {
					api = "CraftEnchant",
					params = { recipeID, amount, craftingReagentInfoTbl, enchantItemLocation, concentrating },
				}
			})
		end)
	end
	if type(C_TradeSkillUI.RecraftRecipe) == "function" then
	hooksecurefunc(C_TradeSkillUI, "RecraftRecipe",
		function(itemGUID, craftingReagentTbl, removedModifications, applyConcentration)
			OnCraft(CraftSim.OnCraftData {
				recipeID = select(1, C_TradeSkillUI.GetOriginalCraftRecipeID(itemGUID)),
				amount = 1,
				isRecraft = true,
				itemGUID = itemGUID,
				craftingReagentInfoTbl = craftingReagentTbl or {},
				concentrating = applyConcentration,
				callerData = {
					api = "RecraftRecipe",
					params = { itemGUID, craftingReagentTbl, removedModifications, applyConcentration },
				}
			})
		end)
	end
	if CraftSim.CONST.WORK_ORDERS_ENABLED and C_TradeSkillUI.RecraftRecipeForOrder then
		hooksecurefunc(C_TradeSkillUI, "RecraftRecipeForOrder",
			function(orderID, itemGUID, craftingReagentTbl, removedModifications, applyConcentration)
				local orderData = C_CraftingOrders.GetClaimedOrder()
				OnCraft(CraftSim.OnCraftData {
					recipeID = orderData.spellID,
					amount = 1,
					isRecraft = true,
					itemGUID = itemGUID,
					orderData = orderData,
					craftingReagentInfoTbl = craftingReagentTbl or {},
					concentrating = applyConcentration,
					callerData = {
						api = "RecraftRecipeForOrder",
						params = { orderID, itemGUID, craftingReagentTbl, removedModifications, applyConcentration },
					}
				})
			end)
	end
	if type(C_TradeSkillUI.CraftSalvage) == "function" then
	hooksecurefunc(C_TradeSkillUI, "CraftSalvage",
		---@param recipeID RecipeID
		---@param amount number?
		---@param itemTargetLocation ItemLocationMixin
		---@param craftingReagentTbl CraftingReagentInfo[]?
		---@param applyConcentration boolean
		function(recipeID, amount, itemTargetLocation, craftingReagentTbl, applyConcentration)
			OnCraft(CraftSim.OnCraftData {
				recipeID = recipeID,
				amount = amount or 1,
				itemTargetLocation = itemTargetLocation,
				craftingReagentInfoTbl = craftingReagentTbl or {},
				concentrating = applyConcentration,
				callerData = {
					api = "CraftSalvage",
					params = { recipeID, amount, itemTargetLocation, craftingReagentTbl, applyConcentration },
				}
			})
		end)
	end
end

function CraftSim.INIT:ADDON_LOADED(addon_name)
	if addon_name == CraftSimAddonName then
		if C_AddOns and C_AddOns.LoadAddOn then
			pcall(C_AddOns.LoadAddOn, "Blizzard_Professions")
		end
		CraftSim.DEBUG:Init()
		CraftSim.DB:Init()
		CraftSim.INIT:InitializeMinimapButton()

		CraftSim.GGUI:InitializePopup({
			backdropOptions = CraftSim.CONST.DEFAULT_BACKDROP_OPTIONS,
			sizeX = 300,
			sizeY = 300,
			title = "CraftSim Popup",
		})

		CraftSim.DEBUG.UI:Init()

		CraftSim.PRICE_API:InitPriceSource()
		CraftSim.INVENTORY_API:InitInventorySource()

		-- Modules

		CraftSim.MODULES:Init()

		CraftSim.INIT:HookToEvents()
		CraftSim.INIT:HookToProfessionsFrame()
		CraftSim.INIT:HookToConcentrationButtons()
		CraftSim.INIT:HookToProfessionUnlearnedFunction()
		CraftSim.INIT:HandleAuctionatorHooks()
		CraftSim.INIT:InitCraftRecipeHooks()

		CraftSim.ITEM_TOOLTIPS:HookItemTooltips()

		if ProfessionsFrame then
			CraftSim.CONTROL_PANEL.UI:Init()
		end
		CraftSim.INIT:InitStaticPopups()

		CraftSim.OPTIONS:Init()
	end
end

function CraftSim.INIT:HandleAuctionatorHooks()
	if Auctionator then ---@diagnostic disable-line: undefined-global
		---@diagnostic disable-next-line: undefined-global
		Auctionator.API.v1.RegisterForDBUpdate(CraftSimAddonName, function()
			Logger:LogDebug("Auctionator DB Update")
			GUTIL:TriggerCustomEvent("CRAFTSIM_AUCTIONATOR_DB_UPDATED")
		end)
	end
end

function CraftSim.INIT:HookToProfessionsFrame()
	if professionFrameHooked then
		return
	end
	if not ProfessionsFrame then
		Logger:LogDebug("HookToProfessionsFrame skipped: no ProfessionsFrame")
		return
	end
	professionFrameHooked = true

	ProfessionsFrame:HookScript("OnShow",
		function()
			CraftSim.MODULES:UpdateVisibilityByContext()
			CraftSim.MODULES:ShowRecipeIndependentModules()

			CraftSim.INIT.lastRecipeID = nil
			if CraftSim.DB.OPTIONS:Get("OPEN_LAST_RECIPE") then
				C_Timer.After(1, function()
					local professionInfo = CraftSim.PROFESSIONS_UI:GetProfessionInfo()
					local profession = professionInfo and professionInfo.parentProfessionName
					if profession and CraftSim.OPTIONS.lastOpenRecipeID[profession] then
						CraftSim.PROFESSIONS_UI:OpenRecipe(CraftSim.OPTIONS.lastOpenRecipeID[profession])
					end
				end)
			end

			if not CraftSim.CONST.WORK_ORDERS_ENABLED then
				return
			end

			-- Force-load crafting orders on the first ProfessionFrame open after login.
			-- Blizzard only fetches orders when OrdersPage:OnShow() fires (tab 3 click).
			-- CRAFTSIM_CRAFTING_ORDERS_PRELOADED fires once CRAFTINGORDERS_CAN_REQUEST and profession data are ready.
			RunNextFrame(function()
				local professionInfo = C_TradeSkillUI.GetChildProfessionInfo()
				local professionID = professionInfo and professionInfo.professionID or nil
				if professionID and (not craftingOrdersPreloadedThisSession[professionID]
						and C_CraftingOrders.ShouldShowCraftingOrderTab()
						and ProfessionsFrame.isCraftingOrdersTabEnabled) then
					if CraftSim.PROFESSIONS_UI:IsVisible() and CraftSim.PROFESSIONS_UI:IsCraftingPageVisible() then
						craftingOrdersPreloadedThisSession[professionID] = true
						craftingOrdersPreloadPendingProfessionID = professionID
						craftingOrdersCanRequest = false
						cancelCraftingOrdersPreloadFallback()
						craftingOrdersPreloadFallbackTimer = C_Timer.NewTimer(12, function()
							craftingOrdersPreloadFallbackTimer = nil
							if craftingOrdersPreloadPendingProfessionID == professionID then
								Logger:LogDebug("Crafting orders preload fallback timeout for profession " .. professionID)
								emitCraftingOrdersPreloaded()
							end
						end)
						CraftSim.PROFESSIONS_UI:ShowOrdersPage() -- triggers OrdersPage:OnShow() → order load
						CraftSim.PROFESSIONS_UI:ShowCraftingPage()
						tryEmitCraftingOrdersPreloaded()
					end
				end
			end)
		end)

	local function refreshAddWorkOrdersButtonDeferred()
		RunNextFrame(function()
			if CraftSim.CRAFTQ.frame and CraftSim.CRAFTQ.frame:IsVisible() then
				CraftSim.MODULES:RefreshAddWorkOrdersButtonState()
			end
		end)
	end

	ProfessionsFrame:HookScript("OnHide", function()
		craftingOrdersPreloadPendingProfessionID = nil
		craftingOrdersCanRequest = false
		cancelCraftingOrdersPreloadFallback()
	end)

	if CraftSim.CONST.WORK_ORDERS_ENABLED then
		local ordersPage = CraftSim.PROFESSIONS_UI:GetOrdersPage()
		if ordersPage then
			ordersPage:HookScript("OnShow", refreshAddWorkOrdersButtonDeferred)
			local orderView = CraftSim.PROFESSIONS_UI:GetOrdersView()
			if orderView then
				orderView:HookScript("OnHide", function()
					GUTIL:TriggerCustomEvent("CRAFTSIM_ORDER_VIEW_CLOSED")
				end)
			end
		end
	end
	if CraftSim.CONST.WORK_ORDERS_ENABLED then
		local craftingOrdersTab = ProfessionsFrame.TabSystem and ProfessionsFrame.TabSystem.tabs[3]
		if craftingOrdersTab then
			craftingOrdersTab:HookScript("OnClick", refreshAddWorkOrdersButtonDeferred)
		end
	end

	local craftingPage = CraftSim.PROFESSIONS_UI:GetCraftingPage()
	if craftingPage then
		craftingPage:HookScript("OnHide",
			function()
				local professionInfo = CraftSim.PROFESSIONS_UI:GetProfessionInfo()
				local profession = professionInfo and professionInfo.parentProfessionName
				local schematicForm = CraftSim.PROFESSIONS_UI:GetSchematicForm()
				local recipeInfo = schematicForm and schematicForm.GetRecipeInfo and schematicForm:GetRecipeInfo()
				if profession and recipeInfo then
					CraftSim.OPTIONS.lastOpenRecipeID[profession] = recipeInfo.recipeID
				end
			end)
	end
end

function CraftSim.INIT:HookToProfessionUnlearnedFunction()
	-- will be base skill line id

	hooksecurefunc("AbandonSkill", function(skilllineID)
		local professionInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skilllineID)
		if professionInfo then
			local crafterUID = CraftSim.UTIL:GetPlayerCrafterUID()
			CraftSim.DEBUG:SystemPrint(f.l("CraftSim: " ..
				"Removing Cached Data for ") .. crafterUID .. " - " .. f.bb(professionInfo.professionName))
			local profession = professionInfo.profession

			CraftSim.DB.CRAFTER:RemoveCrafterProfessionData(crafterUID, profession)
		end
	end)
end

local concentrationButtonHooked = false
function CraftSim.INIT:HookToConcentrationButtons()
	if concentrationButtonHooked then
		return
	end
	if not ProfessionsFrame then
		return
	end
	concentrationButtonHooked = true

	local function OnConcentrationToggle()
		if CraftSim.SIMULATION_MODE.isActive then
			Logger:LogWarning("Simulation Mode Active, skip recipe data update on concentration toggle")
			return
		end
		if not CraftSim.MODULES.recipeData then
			Logger:LogWarning("No recipe data, skip recipe data update on concentration toggle")
			return
		end

		CraftSim.MODULES.recipeData:SyncConcentrationFromSchematicForm()
		GUTIL:TriggerCustomEvent("CRAFTSIM_RECIPE_DATA_UPDATED", CraftSim.MODULES.recipeData)
	end

	local craftingToggle = ProfessionsFrame.CraftingPage
		and ProfessionsFrame.CraftingPage.SchematicForm
		and ProfessionsFrame.CraftingPage.SchematicForm.Details
		and ProfessionsFrame.CraftingPage.SchematicForm.Details.CraftingChoicesContainer
		and ProfessionsFrame.CraftingPage.SchematicForm.Details.CraftingChoicesContainer.ConcentrateContainer
		and ProfessionsFrame.CraftingPage.SchematicForm.Details.CraftingChoicesContainer.ConcentrateContainer.ConcentrateToggleButton
	if craftingToggle then
		craftingToggle:HookScript("OnClick", OnConcentrationToggle)
	end

	if CraftSim.CONST.WORK_ORDERS_ENABLED then
		local orderToggle = ProfessionsFrame.OrdersPage
			and ProfessionsFrame.OrdersPage.OrderView
			and ProfessionsFrame.OrdersPage.OrderView.OrderDetails
			and ProfessionsFrame.OrdersPage.OrderView.OrderDetails.SchematicForm
			and ProfessionsFrame.OrdersPage.OrderView.OrderDetails.SchematicForm.Details
			and ProfessionsFrame.OrdersPage.OrderView.OrderDetails.SchematicForm.Details.CraftingChoicesContainer
			and ProfessionsFrame.OrdersPage.OrderView.OrderDetails.SchematicForm.Details.CraftingChoicesContainer.ConcentrateContainer
			and ProfessionsFrame.OrdersPage.OrderView.OrderDetails.SchematicForm.Details.CraftingChoicesContainer.ConcentrateContainer.ConcentrateToggleButton
		if orderToggle then
			orderToggle:HookScript("OnClick", OnConcentrationToggle)
		end
	end
end

function CraftSim.INIT:PLAYER_LOGIN()
	CraftSim.SLASH:Init()
end

function CraftSim_OnAddonCompartmentClick()
	Settings.OpenToCategory(CraftSim.OPTIONS.category:GetID())
end

function CraftSim.INIT:InitializeMinimapButton()
	local ldb = LibStub("LibDataBroker-1.1"):NewDataObject("CraftSimLDB", {
		type = "data source",
		--tooltip = "CraftSim",
		label = "CraftSim",
		tocname = "CraftSim",
		icon = "Interface\\Addons\\CraftSim\\Media\\Images\\craftsim",
		OnClick = function(_, button)
			if button == "RightButton" then
				CraftSim.WIDGETS.ContextMenu.Open(UIParent, function(ownerRegion, rootDescription)
					rootDescription:CreateTitle("CraftSim")
					rootDescription:CreateButton(L("CONTROL_PANEL_MODULES_SHOPPING_LIST_LABEL"), function()
						if CraftSim.SHOPPING and CraftSim.SHOPPING.ToggleShoppingListView then
							CraftSim.SHOPPING:ToggleShoppingListView()
						end
					end)
					rootDescription:CreateButton("Disenchanting", function()
						if CraftSim.DISENCHANT and CraftSim.DISENCHANT.UI and CraftSim.DISENCHANT.UI.ShowAndLoad then
							CraftSim.DISENCHANT.UI:ShowAndLoad()
						end
					end)
				end)
			else
				Settings.OpenToCategory(CraftSim.OPTIONS.category:GetID())
			end
		end,
	})

	CraftSim.LibIcon:Register("CraftSim", ldb, CraftSim.DB.OPTIONS:Get("LIB_ICON_DB"))

	RunNextFrame(function()
		if CraftSim.DB.OPTIONS:Get("MINIMAP_BUTTON_HIDE") then
			CraftSim.LibIcon:Hide("CraftSim")
		end
	end)
end

function CraftSim.INIT:IsProfessionReady()
	local professionInfo = C_TradeSkillUI.GetChildProfessionInfo()
	local profession = professionInfo and professionInfo.profession or nil
	local profession_available = profession ~= nil
	local tradeSkillRdy = C_TradeSkillUI.IsTradeSkillReady()
	local operationInfosPreloaded = profession_available and CraftSim.DB.MULTICRAFT_PRELOAD:Get(profession)
	return profession_available and tradeSkillRdy and operationInfosPreloaded
end

function CraftSim.INIT:CRAFTSIM_ORDER_VIEW_CLOSED()
	CraftSim.MODULES:UpdateVisibilityByContext()
end

function CraftSim.INIT:UpdateRecipeData()
	if not CraftSim.PROFESSIONS_UI:IsVisible() then
		return
	end

	if CraftSim.SIMULATION_MODE.isActive then
		return
	end

	local selectedTab = CraftSim.UTIL:GetSelectedProfessionTab()
	if not selectedTab or selectedTab == CraftSim.CONST.PROFESSIONS_TAB.SPEC_INFO then return end
	if selectedTab == CraftSim.CONST.PROFESSIONS_TAB.CRAFTING_ORDERS then
		if not CraftSim.CONST.WORK_ORDERS_ENABLED then
			return
		end
		if not CraftSim.PROFESSIONS_UI:IsOrdersViewVisible() then
			return
		end
	end
	if selectedTab == CraftSim.CONST.PROFESSIONS_TAB.BOOK then
		return
	end

	local recipeData = CraftSim.MODULES:GetRecipeDataFromVisibleRecipe()
	if not recipeData then return end

	CraftSim.MODULES.recipeData = recipeData
	GUTIL:TriggerCustomEvent("CRAFTSIM_RECIPE_DATA_UPDATED", recipeData)
end

function CraftSim.INIT:CRAFTSIM_CRAFT_BUFFS_UPDATED()
	self:UpdateRecipeData()
end

function CraftSim.INIT:CRAFTSIM_AUCTIONATOR_DB_UPDATED()
	self:UpdateRecipeData()
end
