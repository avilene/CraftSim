---
name: Headless Lua test CI
overview: "DEFERRED. Pick this up after the current CraftSim bugfix branch ships. Headless Lua 5.1 tests + CI for restock/inventory and nil-guard regressions."
todos:
  - id: runner-stub
    content: Add Tests/run.lua, wowstub.lua, loader.lua (Lua 5.1, no TOC)
    status: pending
  - id: inventory-tests
    content: Export GetOwnedCountForRecipeEntry; tests for Q4/Q5 link vs bank-closed cache
    status: pending
  - id: nilguard-tests
    content: Tests for SetItem(nil), CanCraft, concentration curve, ITEM_COUNT, shopping option, cooldown secrets
    status: pending
  - id: ci-docs
    content: Add test.yml workflow and Dev.md how-to-run
    status: pending
isProject: false
---

# Headless Lua tests in CI

**Status: deferred.** Do not implement in the current bugfix session. Resume after `fix/high-impact-easy-bugs` ships. A copy also lives in the user personal store as `craftsim-headless-lua-test-ci.md`.

Yes. Almost every issue we just closed or patched is logic that never had a regression check: restock owned-counts, `ITEM_COUNT:Save`, nil `concentrationData`, shopping-list option. Those should fail in GitHub Actions, not after a `/reload`.

WoW Lua cannot run as-is (`select(2, ...)` addon table, `C_Item`, frames). Do **not** try to boot the full UI. Load a stub environment and only the data-layer files.

```mermaid
flowchart LR
  CI[GitHub Action] --> Runner[Tests/run.lua]
  Runner --> Stub[wowstub + CraftSim table]
  Stub --> Loader[loadfile with addon args]
  Loader --> Suites[inventory and nil-guard tests]
```



## Approach

Zero extra LuaRocks/busted. One runner, Lua 5.1 (matches WoW). Tests stay **out of** [CraftSim.toc](CraftSim.toc) so they never load in-game.

Layout:

- [Tests/wowstub.lua](Tests/wowstub.lua) — `C_Item`, `C_Container`, `C_Secrets`, `Enum.BagIndex`, `ItemLocation`, `Item`, `GetTime`, `LibStub` (enough to load GUTIL)
- [Tests/loader.lua](Tests/loader.lua) — `loadfile(path)("CraftSim", CraftSim)` so existing `local CraftSim = select(2, ...)` works
- [Tests/run.lua](Tests/run.lua) — discover `Tests/*_test.lua`, run, print failures, `os.exit(1)`
- [Tests/helpers.lua](Tests/helpers.lua) — tiny `assertEqual` / `assertNil` / fixtures (fake item mixin with link + quality)

Do not load GGUI, profession frames, or Slash. Stub `CraftSim.DEBUG:RegisterLogger` to a no-op.

## First suites (the bugs we just hit)

**1. Inventory / craft-list restock** — [DataSource/InventorySource.lua](DataSource/InventorySource.lua), [Modules/CraftQueue/CraftLists.lua](Modules/CraftQueue/CraftLists.lua)

Public API is enough if we stub containers:

- Gear Q5 link vs Q4 in bank: `GetTradableInventoryCount(q5Link)` is 0, Q4 link is 1
- Passing **itemID only** used to collapse qualities; keep a test that a Q5 **link** does not count Q4 stacks
- Bank UI closed (`GetContainerNumSlots(CharacterBankTab_1) == 0`) still counts Syndicator/TSM cached Q5 in bank
- BoP treatise path still uses `C_Item.GetItemCount` (bags+bank)

Promote `GetOwnedCountForRecipeEntry` from a local in CraftLists.lua to `CraftSim.CRAFT_LISTS.GetOwnedCountForRecipeEntry` so restock math is callable without scanning a whole list. Same logic, just named.

**2. Nil-guard / option fixes** (thin loads of the changed functions)

- [Classes/SalvageReagentSlot.lua](Classes/SalvageReagentSlot.lua) `SetItem(nil)` does not `error()`
- [Classes/RecipeData.lua](Classes/RecipeData.lua) `CanCraft` with `concentrating` and nil `concentrationData` does not index nil
- `GetConcentrationCostForSkill` with nil `concentrationCurveData` returns 0 / cached cost, no crash
- [Classes/ReagentData.lua](Classes/ReagentData.lua) `UpdateItemCountCacheForAllocatedReagents` calls `ITEM_COUNT:UpdateAllCountsForItemID`, never `:Save`
- [Modules/Shopping/Shopping.lua](Modules/Shopping/Shopping.lua) `CRAFTSIM_CRAFTQUEUE_QUEUE_PROCESS_FINISHED` is a no-op when `CRAFTQUEUE_AUTO_SHOPPING_LIST` is false
- [Classes/CooldownData.lua](Classes/CooldownData.lua) `Update()` returns immediately when `C_Secrets.ShouldCooldownsBeSecret()` is true

RecipeData.lua is large and pulls many modules. For that file, either load a **minimal stub** of `CraftSim.RecipeData` methods under test (copy is wrong) or load RecipeData with stubs for `PRICE_SOURCE`, `UTIL`, `CONCENTRATION_CURVE_DATA`. Prefer loading the real file with stubs over duplicating methods.

Skip `QueueOpenRecipe` in this slice (needs schematic frames). That stays an in-game check.

## CI

Add `.github/workflows/test.yml` on pull_request and push:

```yaml
runs-on: ubuntu-22.04
- uses: actions/checkout@v4
  with: { submodules: recursive }
- run: sudo apt-get install -y lua5.1
- run: lua5.1 Tests/run.lua
```

Document in [Dev.md](Dev.md): `lua5.1 Tests/run.lua` (or `lua Tests/run.lua` locally if 5.1).

## Out of scope for v1

- In-game `/craftsim test`
- UI / GGUI / profession-frame tests
- Full TOC load
- Snapshotting real `RecipeData` from the game

## Implementation order

1. Runner + wowstub + loader, one smoke test that GUTIL loads
2. Inventory/restock tests (the Q4/Q5 bank bug)
3. Nil-guard / shopping-list / cooldown tests
4. GitHub Action + Dev.md

