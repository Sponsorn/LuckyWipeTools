# LuckyWipeTools Changelog

## [0.2.0] - 2026-04-04
- Add: Vantus Rune distribution — request runes with `/lwt vantus`, distributors see a roster and click to trade, auto-removes on trade complete or buff detected, clears on boss kill
- Add: Item Splitter quantity option — limit how many stacks to split instead of always splitting all
- Add: Module enable/disable toggles for all features (Gateway, Summon Helper, Combat Log, Item Splitter)
- Add: Description text on all settings pages
- Add: Roster frame position saving and mover for Summon Helper
- Add: Independent alert display settings (font, size, sound, position) per feature — Gateway, Summon Helper, and Vantus each have their own
- Change: Summon Helper notifications now use on-screen alerts instead of chat messages
- Change: Removed redundant "summon started" notification — roster already shows pending status
- Change: Gateway alert now stays visible while item is usable, hides when on cooldown
- Change: Gateway settings warns if player doesn't have the Gateway Shard
- Change: Splitter popup now always closes when guild bank closes
- Change: Item Splitter shows "Split to Bags" / "Split in Bank" buttons when guild bank is open
- Change: Renamed combat log difficulties — Mythic Keystone to Mythic+, Mythic Dungeon to Mythic0
- Change: Combat log defaults to Heroic Raid, Mythic Raid, and Mythic+ only
- Add: Font color picker for all alert display settings
- Add: Bundled Roboto fonts (Regular, SemiBold, Bold) — default alert font is Roboto Bold
- Change: All UI fonts switched from Friz Quadrata to Roboto to match Lantern's style
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
