FROSTMOURNE UPGRADED GEAR v0.4.0
==================================

Standalone addon for Whitemane Frostmourne/Rebuffed (WoW 3.3.5a).
No Carbonite dependency and no PTR route/navigation code.

FEATURES
- Two preview styles: separate Rare/Epic cards or one compact section inside the original item tooltip.
- Preview trigger: always, Alt + hover, or disabled.
- Inline previews show the current and projected Frostmourne upgrade level (1/2, 2/2, 1/3, 2/3 or 3/3).
- Upgrade-level values use quality colors: 1/3 green, 2/3 blue, 3/3 purple; 1/2 blue, 2/2 purple.
- DPS and stat changes are color-coded green for gains and red for losses.
- Lower-tier variants are hidden by default and can be enabled in Settings.
- In inline mode, the current upgrade level is inserted below the item name when the native tooltip layout allows it.
- Upgrade projections are hidden by default for owned items in bags, equipment and banks; quest and profession previews remain visible.
- Official quest rates shown for quest rewards.
- Observed personal rates kept separate for Quest / Drop / Craft.
- Rare, Epic and failed-roll notifications can each be enabled independently.
- Overlay and sound can be enabled independently.
- Neutral gray "PAS D'UPGRADE" notification for confirmed eligible quest/drop rolls that stay normal.
- Tooltip layout avoids Blizzard equipment-comparison tooltips.
- Import/export of local observations. Legacy WUI1/WUI2 exports are accepted directly.
- WUI imports accept tabs or spaces as separators, matching WoW EditBox behavior.
- Restore replaces existing observations only after explicit confirmation.
- French and English interface, French by default.
- Settings page uses a unified custom UI, custom dropdowns and contextual ? help tooltips in both languages.
- Scrollable overview at every supported UI scale.
- Automatic tracking is always enabled; data can be cleared from Settings with confirmation.
- Optional soft minimap icon plus permanent access through /ful and Interface > AddOns.
- All alert and preview options remain controllable in-game.

IMPORTANT ABOUT DROP STATS
Drop eligibility is still being investigated. The addon only records drops that match a known variant family and occur inside a real loot session, but some world-drop families may not actually roll upgrades server-side. Treat Drop rates as experimental for now. Quest and Craft samples stay separated from Drop samples.

INSTALL
Delete the former FrostmourneUpgradedLook addon folder, then copy the
FrostmourneUpgradedGear folder into Interface/AddOns/.
It can coexist with the older WhitemaneUpgradeIntel / Carbonite: Rebuffed Edition because it uses its own namespace and SavedVariables.

The SavedVariables name remains FrostmourneUpgradedLookDB so existing personal
statistics and settings survive the display/folder rename.

COMMANDS
/ful
/frostlook
/ful status
/ful stats
/ful export
/ful import
/ful minimap on
/ful minimap off

FIRST START
Tracking is automatic and always active. It has no OFF state.

MIGRATION
Open Data, choose Restore, paste the complete FUL1/FUL2/WUI1/WUI2 export and confirm.
Imported statistics stay personal and are never included in the distributed addon.
