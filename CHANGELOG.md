# LuckyWipeTools Changelog

## [0.2.4] - 2026-04-16
- Change: Consumable alerts now use addon communication (shared with Lantern) — each player broadcasts their own consumable placements to the group instead of relying on spell event detection. All group members need LWT or Lantern for full coverage.
- Add: Consumable alerts now track repair bots (Auto-Hammer, Jeeves) and all feast variants
- Change: Consumable alerts now work in any group (party or raid), not just raid instances
- Change: Focus Cast Bar defers to Lantern's FocusCastBar when Lantern is loaded and the module is enabled — avoids duplicate cast bars
- Change: Gateway alert defers to Lantern's GatewayReady when Lantern is loaded and the module is enabled — avoids duplicate gateway alerts
- Change: All modules are now off by default on fresh installs — open `/lwt` and toggle the features you want. Existing installs are unaffected (your saved settings are preserved).

## [0.2.3] - 2026-04-05
- Add: Focus Cast Bar — shows focus target casts with interrupt tracking, color-coded kick availability, and interrupt cooldown tick marker
- Add: Instance filter — only show focus cast bar in selected content types (dungeons, raids, arenas, etc.)
- Add: Full color customization for all bar elements (ready, on CD, non-interruptible, background, tick)
- Fix: Summon roster no longer shows bench players (groups 5+) in mythic raids
- Fix: Consumable notifications no longer trigger when crafting cauldrons outside the raid instance
- Fix: Roster event handler no longer processes events outside of raid instances
- Fix: Summoning portal spell ID comparison handles secret values
- Fix: Vantus buff scanning and addon messages no longer run during combat
- Fix: Secret value guards added to class color lookups in roster and vantus displays
- Fix: Secret value guard on player name lookup in vantus buff scanning

## [0.2.2] - 2026-04-05
- Add: Version checker — notifies once per day if guild members have a newer version
- Add: Soulwell notification with flavor text ("Come get your cookies!")
- Add: Flavor text for all consumable notifications (feast, cauldron, soulwell)
- Add: Consumable notifications stack when multiple are placed in quick succession
- Change: Default notification color changed to white
- Fix: Summon roster only shows inside raid instances
- Fix: Summon portal event no longer shows roster outside raid instances

## [0.2.1] - 2026-04-04
- Add: Consumables module — notifies when a raid member places a feast or cauldron (Harandar Celebration, Voidlight Potion Cauldron, Cauldron of Sin'dorei Flasks)
- Add: `/lwt send vantus` — raid leaders/assistants can notify the raid to request vantus runes, opens roster with everyone's buff status
- Add: Vantus roster now restricted to raid leaders and assistants only
- Add: Bundled Roboto fonts registered with LibSharedMedia for font dropdown
- Change: Vantus roster only populates missing-buff players after `/lwt send vantus` is used
- Change: Summon roster only shows inside raid instances
- Change: Roster frames use flat dark style matching settings window
- Change: All UI fonts switched to Roboto (Regular, SemiBold, Bold)
- Fix: Combat log module no longer runs checks when disabled
- Fix: Consumables handles secret spell IDs without errors
- Fix: Vantus buff detection uses localized spell name (C_Spell.GetSpellInfo)
- Fix: Vantus buff scan checks C_Secrets.ShouldAurasBeSecret() before reading auras

## [0.2.0] - 2026-04-04
- Add: Vantus Rune distribution — request runes with `/lwt vantus`, distributors see a roster and click to trade, auto-removes on trade complete or buff detected, clears on boss kill
- Add: Item Splitter quantity option — limit how many stacks to split instead of always splitting all
- Add: Module enable/disable toggles for all features (Gateway, Summon Helper, Combat Log, Item Splitter)
- Add: Description text on all settings pages
- Add: Roster frame position saving and mover for Summon Helper
- Add: Independent alert display settings (font, size, sound, position) per feature — Gateway, Summon Helper, and Vantus each have their own
- Add: Font color picker for all alert display settings
- Add: Bundled Roboto fonts (Regular, SemiBold, Bold) — default alert font is Roboto Bold
- Change: Summon Helper notifications now use on-screen alerts instead of chat messages
- Change: Removed redundant "summon started" notification — roster already shows pending status
- Change: Gateway alert now stays visible while item is usable, hides when on cooldown
- Change: Gateway settings warns if player doesn't have the Gateway Shard
- Change: Splitter popup now always closes when guild bank closes
- Change: Item Splitter shows "Split to Bags" / "Split in Bank" buttons when guild bank is open
- Change: Renamed combat log difficulties — Mythic Keystone to Mythic+, Mythic Dungeon to Mythic0
- Change: Combat log defaults to Heroic Raid, Mythic Raid, and Mythic+ only
- Remove: Alert Style settings page — display settings moved into Gateway and Summon Helper pages
- Fix: Settings sliders now respond to mouse drag
- Fix: Roster frame no longer errors on position restore
- Fix: Color picker no longer errors at load time before DB is ready

## [0.1.0] - 2026-03-28
- Add: Gateway Shard ready alert with configurable sound, font, and position
- Add: Summon Helper — tracks summoning portal and summon status in raid
- Add: Outside roster — shows raid members not in your zone
- Add: Combat Log — auto-start/stop logging per instance type and difficulty
- Add: Item Splitter — split stacks in bags or guild bank, with guild bank button
- Add: Configurable alert style — duration, font, font size, sound, position
- Add: Settings panel with sidebar navigation
