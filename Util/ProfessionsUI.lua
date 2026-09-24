---@class CraftSim
local CraftSim = select(2, ...)

--- Version-specific ProfessionsFrame shell. Recipe/queue internals stay on C_TradeSkillUI;
--- this layer maps those actions onto retail TabSystem vs Forever (Camelot) BookPage/CraftingPage.
---@class CraftSim.PROFESSIONS_UI
CraftSim.PROFESSIONS_UI = {}

local Logger = CraftSim.DEBUG:RegisterLogger("ProfessionsUI")

---@class CraftSim.PROFESSIONS_UI.AnchorPoint
---@field anchorParent Frame
---@field anchorA FramePoint
---@field anchorB FramePoint
---@field offsetX number?
---@field offsetY number?

---@class CraftSim.PROFESSIONS_UI.Handler
---@field GetSelectedProfessionTab fun(self: CraftSim.PROFESSIONS_UI.Handler): CraftSim.PROFESSIONS_TAB?
---@field ShowCraftingPage fun(self: CraftSim.PROFESSIONS_UI.Handler)
---@field ShowSpecPage fun(self: CraftSim.PROFESSIONS_UI.Handler)
---@field ShowOrdersPage fun(self: CraftSim.PROFESSIONS_UI.Handler)
---@field GetQueueRecipeButtonAnchorPoints fun(self: CraftSim.PROFESSIONS_UI.Handler): CraftSim.PROFESSIONS_UI.AnchorPoint[]?
---@field HookContextChanges fun(self: CraftSim.PROFESSIONS_UI.Handler, onTab: fun(tab: CraftSim.PROFESSIONS_TAB))

---@type CraftSim.PROFESSIONS_UI.Handler
local Retail = {}
---@type CraftSim.PROFESSIONS_UI.Handler
local Forever = {}

---@return Frame?
function CraftSim.PROFESSIONS_UI:GetFrame()
    return ProfessionsFrame
end

---@return boolean
function CraftSim.PROFESSIONS_UI:IsVisible()
    local frame = self:GetFrame()
    return frame ~= nil and frame:IsVisible()
end

---@return Frame?
function CraftSim.PROFESSIONS_UI:GetCraftingPage()
    local frame = self:GetFrame()
    return frame and frame.CraftingPage or nil
end

---@return Frame?
function CraftSim.PROFESSIONS_UI:GetBookPage()
    local frame = self:GetFrame()
    return frame and frame.BookPage or nil
end

---@return Frame?
function CraftSim.PROFESSIONS_UI:GetSpecPage()
    local frame = self:GetFrame()
    return frame and frame.SpecPage or nil
end

---@return Frame?
function CraftSim.PROFESSIONS_UI:GetOrdersPage()
    local frame = self:GetFrame()
    return frame and frame.OrdersPage or nil
end

---@return Frame?
function CraftSim.PROFESSIONS_UI:GetOrdersView()
    local ordersPage = self:GetOrdersPage()
    return ordersPage and ordersPage.OrderView or nil
end

---@return Frame?
function CraftSim.PROFESSIONS_UI:GetSchematicForm()
    local craftingPage = self:GetCraftingPage()
    return craftingPage and craftingPage.SchematicForm or nil
end

---@return Frame?
function CraftSim.PROFESSIONS_UI:GetTrackRecipeCheckbox()
    local schematicForm = self:GetSchematicForm()
    return schematicForm and schematicForm.TrackRecipeCheckbox or nil
end

---@return Frame?
function CraftSim.PROFESSIONS_UI:GetConcentrationDisplay()
    local craftingPage = self:GetCraftingPage()
    return craftingPage and craftingPage.ConcentrationDisplay or nil
end

---@return boolean
function CraftSim.PROFESSIONS_UI:IsCraftingPageVisible()
    local craftingPage = self:GetCraftingPage()
    return craftingPage ~= nil and craftingPage:IsVisible()
end

---@return boolean
function CraftSim.PROFESSIONS_UI:IsBookPageVisible()
    local bookPage = self:GetBookPage()
    return bookPage ~= nil and bookPage:IsShown()
end

---@return boolean
function CraftSim.PROFESSIONS_UI:IsOrdersViewVisible()
    local orderView = self:GetOrdersView()
    return orderView ~= nil and orderView:IsVisible()
end

---@return boolean
function CraftSim.PROFESSIONS_UI:HasTabSystem()
    local frame = self:GetFrame()
    return frame ~= nil and frame.TabSystem ~= nil
end

---@return boolean
function CraftSim.PROFESSIONS_UI:HasSpecPage()
    return not CraftSim.CONST.GAME.isForever and self:GetSpecPage() ~= nil
end

---@return boolean
function CraftSim.PROFESSIONS_UI:HasOrdersPage()
    return CraftSim.CONST.WORK_ORDERS_ENABLED and self:GetOrdersPage() ~= nil
end

---@return boolean
function CraftSim.PROFESSIONS_UI:HasBookPage()
    return CraftSim.CONST.GAME.isForever and self:GetBookPage() ~= nil
end

---@return ProfessionInfo?
function CraftSim.PROFESSIONS_UI:GetProfessionInfo()
    local frame = self:GetFrame()
    if frame and frame.GetProfessionInfo then
        return frame:GetProfessionInfo()
    end
    return C_TradeSkillUI.GetChildProfessionInfo()
end

---@param tabID number
local function ClickRetailTab(tabID)
    local frame = CraftSim.PROFESSIONS_UI:GetFrame()
    if not frame or not frame.TabSystem then
        return
    end
    if frame.SetTab then
        frame:SetTab(tabID)
        return
    end
    if frame.GetTabButton then
        local button = frame:GetTabButton(tabID)
        if button then
            button:Click()
        end
    end
end

function Retail:GetSelectedProfessionTab()
    if not CraftSim.PROFESSIONS_UI:IsVisible() then
        return nil
    end

    local frame = CraftSim.PROFESSIONS_UI:GetFrame()
    local selectedTabID = frame and frame.TabSystem and frame.TabSystem.selectedTabID
    if selectedTabID == 1 then
        return CraftSim.CONST.PROFESSIONS_TAB.RECIPE
    elseif selectedTabID == 2 then
        return CraftSim.CONST.PROFESSIONS_TAB.SPEC_INFO
    elseif selectedTabID == 3 then
        return CraftSim.CONST.PROFESSIONS_TAB.CRAFTING_ORDERS
    end
    -- First open after login/reload is often nil; retail defaults to the recipe tab.
    return CraftSim.CONST.PROFESSIONS_TAB.RECIPE
end

function Retail:ShowCraftingPage()
    if CraftSim.PROFESSIONS_UI:IsCraftingPageVisible() then
        return
    end
    ClickRetailTab(1)
end

function Retail:ShowSpecPage()
    local frame = CraftSim.PROFESSIONS_UI:GetFrame()
    if not frame or not frame.TabSystem then
        return
    end
    local tabID = frame.specializationsTabID or 2
    if frame.SetTab then
        frame:SetTab(tabID, true)
        return
    end
    ClickRetailTab(tabID)
end

function Retail:ShowOrdersPage()
    if not CraftSim.PROFESSIONS_UI:HasOrdersPage() then
        return
    end
    if CraftSim.PROFESSIONS_UI:GetOrdersPage():IsVisible() then
        return
    end
    ClickRetailTab(3)
end

function Retail:GetQueueRecipeButtonAnchorPoints()
    local checkbox = CraftSim.PROFESSIONS_UI:GetTrackRecipeCheckbox()
    if not checkbox then
        local schematicForm = CraftSim.PROFESSIONS_UI:GetSchematicForm()
        if not schematicForm then
            return nil
        end
        return { {
            anchorParent = schematicForm,
            anchorA = "TOPRIGHT",
            anchorB = "TOPRIGHT",
            offsetX = -20,
            offsetY = -20,
        } }
    end
    return { {
        anchorParent = checkbox,
        anchorA = "RIGHT",
        anchorB = "LEFT",
        offsetX = -18,
        offsetY = -19,
    } }
end

function Retail:HookContextChanges(onTab)
    local frame = CraftSim.PROFESSIONS_UI:GetFrame()
    local tabs = frame and frame.TabSystem and frame.TabSystem.tabs
    if not tabs then
        return
    end
    if tabs[1] then
        tabs[1]:HookScript("OnClick", function()
            onTab(CraftSim.CONST.PROFESSIONS_TAB.RECIPE)
        end)
    end
    if tabs[2] then
        tabs[2]:HookScript("OnClick", function()
            onTab(CraftSim.CONST.PROFESSIONS_TAB.SPEC_INFO)
        end)
    end
    if CraftSim.CONST.WORK_ORDERS_ENABLED and tabs[3] then
        tabs[3]:HookScript("OnClick", function()
            onTab(CraftSim.CONST.PROFESSIONS_TAB.CRAFTING_ORDERS)
        end)
    end
end

function Forever:GetSelectedProfessionTab()
    if not CraftSim.PROFESSIONS_UI:IsVisible() then
        return nil
    end
    if CraftSim.PROFESSIONS_UI:IsBookPageVisible() then
        return CraftSim.CONST.PROFESSIONS_TAB.BOOK
    end
    if CraftSim.PROFESSIONS_UI:IsCraftingPageVisible() then
        return CraftSim.CONST.PROFESSIONS_TAB.RECIPE
    end
    return CraftSim.CONST.PROFESSIONS_TAB.BOOK
end

function Forever:ShowCraftingPage()
    if CraftSim.PROFESSIONS_UI:IsCraftingPageVisible() then
        return
    end

    local frame = CraftSim.PROFESSIONS_UI:GetFrame()
    if not frame then
        return
    end

    local professionInfo = C_TradeSkillUI.GetChildProfessionInfo()
    local skillLineID = professionInfo and (professionInfo.parentProfessionID or professionInfo.professionID)
    if skillLineID and frame.rightProfessionTabs then
        for _, tab in ipairs(frame.rightProfessionTabs) do
            if tab.skillLine == skillLineID and tab.OnClick then
                tab:OnClick()
                return
            end
        end
    end

    if frame.BookPage then
        frame.BookPage:Hide()
    end
    if frame.CraftingPage then
        frame.CraftingPage:Show()
    end
end

function Forever:ShowSpecPage()
    -- Camelot has no SpecPage / specializations tab.
end

function Forever:ShowOrdersPage()
    -- Camelot has no OrdersPage.
end

function Forever:GetQueueRecipeButtonAnchorPoints()
    -- TrackRecipeCheckbox is BOTTOMLEFT of the schematic; sit to its right instead of retail's top-right left-of-checkbox.
    local checkbox = CraftSim.PROFESSIONS_UI:GetTrackRecipeCheckbox()
    if not checkbox then
        local schematicForm = CraftSim.PROFESSIONS_UI:GetSchematicForm()
        if not schematicForm then
            return nil
        end
        return { {
            anchorParent = schematicForm,
            anchorA = "BOTTOMLEFT",
            anchorB = "BOTTOMLEFT",
            offsetX = 17,
            offsetY = 40,
        } }
    end
    return { {
        anchorParent = checkbox,
        anchorA = "LEFT",
        anchorB = "RIGHT",
        offsetX = 8,
        offsetY = 0,
    } }
end

function Forever:HookContextChanges(onTab)
    local craftingPage = CraftSim.PROFESSIONS_UI:GetCraftingPage()
    if craftingPage then
        craftingPage:HookScript("OnShow", function()
            onTab(CraftSim.CONST.PROFESSIONS_TAB.RECIPE)
        end)
    end
    local bookPage = CraftSim.PROFESSIONS_UI:GetBookPage()
    if bookPage then
        bookPage:HookScript("OnShow", function()
            onTab(CraftSim.CONST.PROFESSIONS_TAB.BOOK)
        end)
    end
end

---@type CraftSim.PROFESSIONS_UI.Handler
local Handler = CraftSim.CONST.GAME.isForever and Forever or Retail

Logger:LogDebug("Professions UI handler: {handler}", CraftSim.CONST.GAME.isForever and "forever" or "retail")

---@return CraftSim.PROFESSIONS_TAB?
function CraftSim.PROFESSIONS_UI:GetSelectedProfessionTab()
    return Handler:GetSelectedProfessionTab()
end

function CraftSim.PROFESSIONS_UI:ShowCraftingPage()
    Handler:ShowCraftingPage()
end

function CraftSim.PROFESSIONS_UI:ShowSpecPage()
    Handler:ShowSpecPage()
end

function CraftSim.PROFESSIONS_UI:ShowOrdersPage()
    Handler:ShowOrdersPage()
end

---@return CraftSim.PROFESSIONS_UI.AnchorPoint[]?
function CraftSim.PROFESSIONS_UI:GetQueueRecipeButtonAnchorPoints()
    return Handler:GetQueueRecipeButtonAnchorPoints()
end

---@param onTab fun(tab: CraftSim.PROFESSIONS_TAB)
function CraftSim.PROFESSIONS_UI:HookContextChanges(onTab)
    Handler:HookContextChanges(onTab)
end

---@param recipeID number
function CraftSim.PROFESSIONS_UI:OpenRecipe(recipeID)
    if not recipeID then
        return
    end
    if self:IsCraftingPageVisible() then
        RunNextFrame(function()
            C_TradeSkillUI.OpenRecipe(recipeID)
        end)
        return
    end
    self:ShowCraftingPage()
    C_TradeSkillUI.OpenRecipe(recipeID)
end

---@param order CraftingOrderInfo
---@return boolean
function CraftSim.PROFESSIONS_UI:ViewOrder(order)
    if not order or not self:HasOrdersPage() then
        return false
    end
    self:ShowOrdersPage()
    local ordersPage = self:GetOrdersPage()
    if not ordersPage or not ordersPage.ViewOrder then
        return false
    end
    ordersPage:ViewOrder(order)
    return true
end

---@param region Region?
---@return string
local function DescribeRegion(region)
    if not region then
        return "nil"
    end
    if region.GetName then
        local name = region:GetName()
        if name and name ~= "" then
            return name
        end
    end
    if region.GetDebugName then
        return region:GetDebugName()
    end
    return tostring(region)
end

---@param region Region?
---@return string
local function DescribePoint(region)
    if not region or not region.GetPoint then
        return "nil"
    end
    local point, relativeTo, relativePoint, offsetX, offsetY = region:GetPoint(1)
    return string.format("%s rel=%s relP=%s x=%s y=%s shown=%s",
        tostring(point),
        DescribeRegion(relativeTo),
        tostring(relativePoint),
        tostring(offsetX),
        tostring(offsetY),
        tostring(region.IsShown and region:IsShown()))
end

--- Runtime dump of the Blizzard professions shell vs CraftSim's handler. Opens a copy box.
---@return string
function CraftSim.PROFESSIONS_UI:DumpShell()
    local lines = {}
    local function add(text)
        table.insert(lines, text)
    end

    local version, build, _, tocversion = GetBuildInfo()
    add("== CraftSim professions UI dump ==")
    add("build " .. tostring(version) .. " " .. tostring(build) .. " toc=" .. tostring(tocversion)
        .. " project=" .. tostring(WOW_PROJECT_ID))
    add("GAME isForever=" .. tostring(CraftSim.CONST.GAME.isForever)
        .. " isRetail=" .. tostring(CraftSim.CONST.GAME.isRetail)
        .. " WORK_ORDERS_ENABLED=" .. tostring(CraftSim.CONST.WORK_ORDERS_ENABLED))
    add("handler tab=" .. tostring(self:GetSelectedProfessionTab())
        .. " craftingVisible=" .. tostring(self:IsCraftingPageVisible())
        .. " bookVisible=" .. tostring(self:IsBookPageVisible())
        .. " hasTabSystem=" .. tostring(self:HasTabSystem())
        .. " hasSpecPage=" .. tostring(self:HasSpecPage())
        .. " hasOrdersPage=" .. tostring(self:HasOrdersPage())
        .. " hasBookPage=" .. tostring(self:HasBookPage()))

    local frame = self:GetFrame()
    if not frame then
        add("ProfessionsFrame=nil")
        return table.concat(lines, "\n")
    end

    add("ProfessionsFrame visible=" .. tostring(frame:IsVisible())
        .. " size=" .. tostring(math.floor(frame:GetWidth() + 0.5)) .. "x" .. tostring(math.floor(frame:GetHeight() + 0.5)))
    add("children TabSystem=" .. tostring(frame.TabSystem ~= nil)
        .. " BookPage=" .. tostring(frame.BookPage ~= nil)
        .. " CraftingPage=" .. tostring(frame.CraftingPage ~= nil)
        .. " SpecPage=" .. tostring(frame.SpecPage ~= nil)
        .. " OrdersPage=" .. tostring(frame.OrdersPage ~= nil)
        .. " NineSlice.TopEdge=" .. tostring(frame.NineSlice and frame.NineSlice.TopEdge ~= nil))
    add("methods SelectBookPage=" .. tostring(type(frame.SelectBookPage))
        .. " GetProfessionInfo=" .. tostring(type(frame.GetProfessionInfo))
        .. " SetTab=" .. tostring(type(frame.SetTab))
        .. " GetTabButton=" .. tostring(type(frame.GetTabButton)))
    add("rightProfessionTabs=" .. tostring(frame.rightProfessionTabs and #frame.rightProfessionTabs))
    if frame.BookPage then
        add("BookPage shown=" .. tostring(frame.BookPage:IsShown())
            .. " visible=" .. tostring(frame.BookPage:IsVisible()))
    end

    local craftingPage = self:GetCraftingPage()
    if craftingPage then
        add("CraftingPage shown=" .. tostring(craftingPage:IsShown())
            .. " visible=" .. tostring(craftingPage:IsVisible())
            .. " size=" .. tostring(math.floor(craftingPage:GetWidth() + 0.5))
            .. "x" .. tostring(math.floor(craftingPage:GetHeight() + 0.5)))
        add("ConcentrationDisplay=" .. tostring(craftingPage.ConcentrationDisplay ~= nil)
            .. " CreateAllButton=" .. DescribePoint(craftingPage.CreateAllButton)
            .. " CreateButton=" .. DescribePoint(craftingPage.CreateButton))
    end

    local schematicForm = self:GetSchematicForm()
    if schematicForm then
        add("SchematicForm size=" .. tostring(math.floor(schematicForm:GetWidth() + 0.5))
            .. "x" .. tostring(math.floor(schematicForm:GetHeight() + 0.5))
            .. " visible=" .. tostring(schematicForm:IsVisible()))
        add("TrackRecipeCheckbox " .. DescribePoint(schematicForm.TrackRecipeCheckbox))
    else
        add("SchematicForm=nil")
    end

    local queueButton = CraftSim.CRAFTQ and CraftSim.CRAFTQ.queueRecipeButton
    if queueButton and queueButton.frame then
        add("queueRecipeButton " .. DescribePoint(queueButton.frame))
    else
        add("queueRecipeButton=nil")
    end

    add("C_TradeSkillUI.OpenRecipe=" .. tostring(type(C_TradeSkillUI.OpenRecipe))
        .. " GetChildProfessionInfo=" .. tostring(type(C_TradeSkillUI.GetChildProfessionInfo)))
    local professionInfo = C_TradeSkillUI.GetChildProfessionInfo and C_TradeSkillUI.GetChildProfessionInfo()
    if professionInfo then
        add("profession=" .. tostring(professionInfo.profession)
            .. " professionID=" .. tostring(professionInfo.professionID)
            .. " parentProfessionID=" .. tostring(professionInfo.parentProfessionID)
            .. " parentProfessionName=" .. tostring(professionInfo.parentProfessionName))
    else
        add("GetChildProfessionInfo=nil")
    end

    return table.concat(lines, "\n")
end
