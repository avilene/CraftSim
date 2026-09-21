---
name: Open issues triage
overview: Triage of all 173 open issues on derfloh205/CraftSim (v27.0.5). About 15–20 are duplicates of a handful of roots, ~10 are already fixed in main but never closed, and ~12 are small confirmed bugs with ready patches.
todos: []
isProject: false
---

# Open issues triage: derfloh205/CraftSim

Source: [github.com/derfloh205/CraftSim/issues](https://github.com/derfloh205/CraftSim/issues) — 173 open issues, current addon version **27.0.5**. Code checked against `origin/main` (`1eb7fdff`) plus this worktree.

This is a report only. No code or GitHub comments unless you ask later.

---

## Snapshot

- **173 open** (mix of bugs, features, and owner-filed research tickets going back to 2024)
- **~70+ are feature requests / research**, not active bugs
- **~15–20 are duplicate reports** of ~8 root causes
- **~10 are already fixed in 27.0.x** and can be closed
- **~12 are easy confirmed bugs** (nil guards, one missed option check, one dead API call)

Open PRs already covering issues:

- [#1506](https://github.com/derfloh205/CraftSim/pull/1506) → [#1505](https://github.com/derfloh205/CraftSim/issues/1505) (order reagent quantity 50/25)
- [#1504](https://github.com/derfloh205/CraftSim/pull/1504) (draft Copilot) → [#1503](https://github.com/derfloh205/CraftSim/issues/1503) / [#1481](https://github.com/derfloh205/CraftSim/issues/1481)
- [#1508](https://github.com/derfloh205/CraftSim/pull/1508) DB2 data update (may close missing concentration-curve recipes)

---

## Already fixed — issues still open

These landed on main; the GitHub tickets were never closed.

| Issue | What it was | Fix |
|---|---|---|
| [#1459](https://github.com/derfloh205/CraftSim/issues/1459) Reset Frame Positions `pairs` nil | `Util/Frames.lua` now uses `INIT.FRAMES or {}` + `pcall` | [#1470](https://github.com/derfloh205/CraftSim/pull/1470) |
| [#1468](https://github.com/derfloh205/CraftSim/issues/1468) / [#1477](https://github.com/derfloh205/CraftSim/issues/1477) ReagentOptimization `recipeData` nil | UI compares against live recipe only if non-nil | [#1470](https://github.com/derfloh205/CraftSim/pull/1470) / later UI fix |
| [#1473](https://github.com/derfloh205/CraftSim/issues/1473) / [#1450](https://github.com/derfloh205/CraftSim/issues/1450) / [#1443](https://github.com/derfloh205/CraftSim/issues/1443) M+/login `isFullUpdate` secret boolean | `UNIT_AURA` returns early when `C_Secrets.ShouldAurasBeSecret()` | [#1472](https://github.com/derfloh205/CraftSim/pull/1472) |
| [#1494](https://github.com/derfloh205/CraftSim/issues/1494) Recipe Info blank | Frame ID collision with old Average Profit frame | [#1496](https://github.com/derfloh205/CraftSim/pull/1496) (`2cef0a32`) |
| [#1484](https://github.com/derfloh205/CraftSim/issues/1484) CustomerHistory `GetQualityIDFromLink` nil | Call site now checks `itemLink` | [#1490](https://github.com/derfloh205/CraftSim/pull/1490) (helper itself still unguarded) |
| [#1471](https://github.com/derfloh205/CraftSim/issues/1471) item 1 `GetRecipeInfo(nil)` | `Modules.lua` now guards `if recipeID then` | in tree |
| [#1450](https://github.com/derfloh205/CraftSim/issues/1450) CraftListsDB migration fail | `NormalizeCrafterUIDKey` | [#1464](https://github.com/derfloh205/CraftSim/pull/1464) |
| [#801](https://github.com/derfloh205/CraftSim/issues/801) New Shopping module | Module exists; TSM variant still missing | implemented |

[#1494](https://github.com/derfloh205/CraftSim/issues/1494) may still have a leftover “stuck until Delete all Overrides” report in comments — worth a quick in-game check before closing.

---

## Duplicate clusters (keep one, close the rest)

### 1. Stale `MODULES.recipeData` / concentration toggle (keep [#1503](https://github.com/derfloh205/CraftSim/issues/1503))

`QueueOpenRecipe()` copies cached `MODULES.recipeData` and returns silently if nil. Concentration OnClick rebroadcasts without `SetConcentrationBySchematicForm()`.

Duplicates:

- [#1481](https://github.com/derfloh205/CraftSim/issues/1481) queue ignores Concentration (reporter posted the exact local patch)
- [#1492](https://github.com/derfloh205/CraftSim/issues/1492) / [#1455](https://github.com/derfloh205/CraftSim/issues/1455) expected profit does not update on Concentration
- [#1457](https://github.com/derfloh205/CraftSim/issues/1457) / [#1489](https://github.com/derfloh205/CraftSim/issues/1489) “cooking won’t queue” — comment on 1457 is the same bug: it queues the *previous profession’s* recipe

Draft PR: [#1504](https://github.com/derfloh205/CraftSim/pull/1504)

### 2. `ITEM_COUNT:Save` does not exist (keep [#1386](https://github.com/derfloh205/CraftSim/issues/1386))

[`Classes/ReagentData.lua`](Classes/ReagentData.lua) still calls removed `CraftSim.DB.ITEM_COUNT:Save()` (there is even a TODO on the line). Fires after every craft via CraftLog.

Duplicates: [#1343](https://github.com/derfloh205/CraftSim/issues/1343), [#1408](https://github.com/derfloh205/CraftSim/issues/1408)

Ready patch in comments: delegate to `CraftSim.ITEM_COUNT:UpdateAllCountsForItemID`.

### 3. Missing `concentrationCurveData` (keep [#1441](https://github.com/derfloh205/CraftSim/issues/1441))

`GetConcentrationCostForSkill` indexes `self.concentrationCurveData` with no nil check. Alluring Nostrum `271889` is still absent from `Data/ConcentrationCurveData.lua`.

Duplicate: [#1442](https://github.com/derfloh205/CraftSim/issues/1442)

Fix is two parts: nil-guard + merge DB2 PR [#1508](https://github.com/derfloh205/CraftSim/pull/1508).

### 4. `concentrationData` nil in `CanCraft` (keep [#1454](https://github.com/derfloh205/CraftSim/issues/1454))

```2588:2591:Classes/RecipeData.lua
    if self.concentrating and self.concentrationCost > 0 then
        local cost = self.concentrationCost * amount
        concentrationAmount = self.concentrationData:GetQueueableAmount(cost)
    end
```

Also listed as item 3 in [#1471](https://github.com/derfloh205/CraftSim/issues/1471).

### 5. Multicraft tools on non-MC crafts (keep [#1286](https://github.com/derfloh205/CraftSim/issues/1286))

`ShouldAvoidMulticraftOnlyTools` already skips MC-only tools for work orders / `not supportsMulticraft`. Gear enchants that still report `supportsMulticraft` can still pick MC tools.

Duplicates: [#1476](https://github.com/derfloh205/CraftSim/issues/1476), [#1361](https://github.com/derfloh205/CraftSim/issues/1361), [#1362](https://github.com/derfloh205/CraftSim/issues/1362), related [#1385](https://github.com/derfloh205/CraftSim/issues/1385), feature [#694](https://github.com/derfloh205/CraftSim/issues/694) / [#1390](https://github.com/derfloh205/CraftSim/issues/1390)

### 6. MoneyFrame / secret-value taint (keep owner [#1271](https://github.com/derfloh205/CraftSim/issues/1271))

Same Midnight secret-value taint, different stacks:

- MoneyFrame: [#1245](https://github.com/derfloh205/CraftSim/issues/1245), [#1255](https://github.com/derfloh205/CraftSim/issues/1255), [#1283](https://github.com/derfloh205/CraftSim/issues/1283), [#1298](https://github.com/derfloh205/CraftSim/issues/1298), [#1342](https://github.com/derfloh205/CraftSim/issues/1342), [#1369](https://github.com/derfloh205/CraftSim/issues/1369), [#1374](https://github.com/derfloh205/CraftSim/issues/1374)
- CastingBar forbidden table: [#1295](https://github.com/derfloh205/CraftSim/issues/1295), [#1347](https://github.com/derfloh205/CraftSim/issues/1347)
- Cooldown secret number: [#1498](https://github.com/derfloh205/CraftSim/issues/1498), [#1257](https://github.com/derfloh205/CraftSim/issues/1257) — Cooldowns module still has **no** `ShouldCooldownsBeSecret()` guard (unlike CraftBuffs)
- Bag use taint: [#1502](https://github.com/derfloh205/CraftSim/issues/1502)
- OpenRecipe protected: [#1212](https://github.com/derfloh205/CraftSim/issues/1212)

Hard. Not a one-liner except the cooldown early-return, which is easy.

### 7. TSM shopping list (keep [#863](https://github.com/derfloh205/CraftSim/issues/863))

Triplicate feature: [#1084](https://github.com/derfloh205/CraftSim/issues/1084), [#1214](https://github.com/derfloh205/CraftSim/issues/1214). Shopping module only talks to Auctionator.

### 8. Customer History search (keep [#544](https://github.com/derfloh205/CraftSim/issues/544))

Duplicate: [#565](https://github.com/derfloh205/CraftSim/issues/565). Related bigger features: [#1230](https://github.com/derfloh205/CraftSim/issues/1230), [#514](https://github.com/derfloh205/CraftSim/issues/514). Crash: [#1507](https://github.com/derfloh205/CraftSim/issues/1507) (GGUI GetWidth recursion — not a dup, real bug).

### 9. Recipe Scan all qualities (keep [#635](https://github.com/derfloh205/CraftSim/issues/635))

Duplicates: [#820](https://github.com/derfloh205/CraftSim/issues/820), related [#1319](https://github.com/derfloh205/CraftSim/issues/1319), [#927](https://github.com/derfloh205/CraftSim/issues/927).

### 10. Non-enUS profit = 0 (keep [#1272](https://github.com/derfloh205/CraftSim/issues/1272), owner-filed)

Duplicate: [#1170](https://github.com/derfloh205/CraftSim/issues/1170) (Spanish client). Cooking/decor/bags show 0 until language is English.

### 11. UI docking / window layout (keep [#1285](https://github.com/derfloh205/CraftSim/issues/1285) or owner [#1086](https://github.com/derfloh205/CraftSim/issues/1086))

Related: [#1463](https://github.com/derfloh205/CraftSim/issues/1463), [#880](https://github.com/derfloh205/CraftSim/issues/880), [#869](https://github.com/derfloh205/CraftSim/issues/869), [#444](https://github.com/derfloh205/CraftSim/issues/444). Bug from the rework: [#1467](https://github.com/derfloh205/CraftSim/issues/1467) (anchor-to-center vs work-order frame).

---

## Easy to fix (ranked)

All of these are small, localized, and either have a posted patch or a one-line guard.

1. **[#1482](https://github.com/derfloh205/CraftSim/issues/1482) Auto shopping list setting ignored** — easiest. `CRAFTSIM_CRAFTQUEUE_QUEUE_PROCESS_FINISHED` always creates an Auctionator list. Reporter posted the exact 4-line guard *today*. Confirmed in [`Modules/Shopping/Shopping.lua`](Modules/Shopping/Shopping.lua) lines 783–785.

2. **[#1386](https://github.com/derfloh205/CraftSim/issues/1386) / [#1343](https://github.com/derfloh205/CraftSim/issues/1343) / [#1408](https://github.com/derfloh205/CraftSim/issues/1408) dead `ITEM_COUNT:Save`** — replace loop body with `UpdateAllCountsForItemID`. TODO already on the line.

3. **[#1454](https://github.com/derfloh205/CraftSim/issues/1454) `concentrationData` nil** — `if self.concentrationData then` in `CanCraft`.

4. **[#1441](https://github.com/derfloh205/CraftSim/issues/1441) / [#1442](https://github.com/derfloh205/CraftSim/issues/1442) `concentrationCurveData` nil** — early return 0 (or API cost) in `GetConcentrationCostForSkill`; then merge DB2.

5. **[#1471](https://github.com/derfloh205/CraftSim/issues/1471) leftover nils** — `SalvageReagentSlot:SetItem(nil)` early-return; `GetQualityIDFromLink` nil-check (hardens [#1490](https://github.com/derfloh205/CraftSim/pull/1490)).

6. **[#1503](https://github.com/derfloh205/CraftSim/issues/1503) cluster** — apply/finish [#1504](https://github.com/derfloh205/CraftSim/pull/1504): fallback to visible recipe + refresh concentration before queue/UI update. Also fixes cooking “queues copper / previous recipe”.

7. **[#1505](https://github.com/derfloh205/CraftSim/issues/1505)** — review/merge existing [#1506](https://github.com/derfloh205/CraftSim/pull/1506). Do not reimplement.

8. **[#1498](https://github.com/derfloh205/CraftSim/issues/1498) / [#1257](https://github.com/derfloh205/CraftSim/issues/1257)** — add `C_Secrets.ShouldCooldownsBeSecret()` to `COOLDOWNS:PeriodicTimerUpdate` (same pattern as the aura fix already in tree).

9. **[#807](https://github.com/derfloh205/CraftSim/issues/807) Concentration Tracker A→Z** — CHARACTER sort uses `>` (Z→A). Flip to `<`.

10. **[#882](https://github.com/derfloh205/CraftSim/issues/882) name overlaps conc value** — truncate `crafterUID` in the 160px column.

11. **[#840](https://github.com/derfloh205/CraftSim/issues/840) Options FontString globals** — pass `nil` name to `CreateFontString`.

12. **[#1497](https://github.com/derfloh205/CraftSim/issues/1497) missing Simulate button** — toggle exists but is likely clipped: 160px button inside a 180px Control Panel frame. Widen or re-anchor.

13. **[#564](https://github.com/derfloh205/CraftSim/issues/564) Recipe Scan Select All / None** — small UI feature, checkboxes already exist per row.

---

## Real bugs that are not easy

- **[#1507](https://github.com/derfloh205/CraftSim/issues/1507)** CustomerHistory stack overflow (GGUI Backdrop `GetWidth` recursion) — crash, needs GGUI work
- **[#1467](https://github.com/derfloh205/CraftSim/issues/1467)** window anchoring vs work-order frame
- **[#1486](https://github.com/derfloh205/CraftSim/issues/1486)** PvP gear (venomous heraldry) does not decrement queue
- **[#1487](https://github.com/derfloh205/CraftSim/issues/1487)** TSM restock expression wrong
- **[#1430](https://github.com/derfloh205/CraftSim/issues/1430)** Lumber counted in Resourcefulness
- **[#1431](https://github.com/derfloh205/CraftSim/issues/1431)** Personal orders animate but do not complete
- **[#1403](https://github.com/derfloh205/CraftSim/issues/1403)** all work orders queued as rank 2
- **[#1371](https://github.com/derfloh205/CraftSim/issues/1371)** Craft List settings saved to the wrong list
- **[#1326](https://github.com/derfloh205/CraftSim/issues/1326)** AH prices wildly stale for some materials
- **[#1272](https://github.com/derfloh205/CraftSim/issues/1272)** localization profit 0
- **[#1340](https://github.com/derfloh205/CraftSim/issues/1340)** Disenchant Next no-op
- **[#1474](https://github.com/derfloh205/CraftSim/issues/1474)** EllesmereUI Personal Aura Bars
- **MoneyFrame / combat taint family** under [#1271](https://github.com/derfloh205/CraftSim/issues/1271)

---

## Feature backlog (not bugs)

Owner-filed research (leave unless derfloh asks): [#936](https://github.com/derfloh205/CraftSim/issues/936), [#935](https://github.com/derfloh205/CraftSim/issues/935), [#873](https://github.com/derfloh205/CraftSim/issues/873), [#655](https://github.com/derfloh205/CraftSim/issues/655), [#338](https://github.com/derfloh205/CraftSim/issues/338), [#273](https://github.com/derfloh205/CraftSim/issues/273), [#254](https://github.com/derfloh205/CraftSim/issues/254), [#358](https://github.com/derfloh205/CraftSim/issues/358), [#383](https://github.com/derfloh205/CraftSim/issues/383), [#396](https://github.com/derfloh205/CraftSim/issues/396), [#412](https://github.com/derfloh205/CraftSim/issues/412), [#414](https://github.com/derfloh205/CraftSim/issues/414), [#444](https://github.com/derfloh205/CraftSim/issues/444), [#471](https://github.com/derfloh205/CraftSim/issues/471), [#604](https://github.com/derfloh205/CraftSim/issues/604), [#651](https://github.com/derfloh205/CraftSim/issues/651), [#708](https://github.com/derfloh205/CraftSim/issues/708), [#730](https://github.com/derfloh205/CraftSim/issues/730), [#736](https://github.com/derfloh205/CraftSim/issues/736), [#754](https://github.com/derfloh205/CraftSim/issues/754).

High-interest community features: TSM shopping ([#863](https://github.com/derfloh205/CraftSim/issues/863)), salvage queueing ([#1350](https://github.com/derfloh205/CraftSim/issues/1350) — overlaps current salvage-stats work), KP/concentration gold value ([#1410](https://github.com/derfloh205/CraftSim/issues/1410)/[#1411](https://github.com/derfloh205/CraftSim/issues/1411)), customer search ([#544](https://github.com/derfloh205/CraftSim/issues/544)).

---

## Suggested close list (no code)

If you later want GitHub hygiene: close as completed [#1459](https://github.com/derfloh205/CraftSim/issues/1459), [#1468](https://github.com/derfloh205/CraftSim/issues/1468), [#1477](https://github.com/derfloh205/CraftSim/issues/1477), [#1473](https://github.com/derfloh205/CraftSim/issues/1473), [#1443](https://github.com/derfloh205/CraftSim/issues/1443), [#1494](https://github.com/derfloh205/CraftSim/issues/1494) (after verify), [#1484](https://github.com/derfloh205/CraftSim/issues/1484), [#801](https://github.com/derfloh205/CraftSim/issues/801); close as duplicate the clusters above pointing at the keep-issue.

Highest-value first code batch if you change your mind: **1482 → 1386 → 1454 → 1441 nil-guard → 1471 leftovers → 1504/1506 review**.
