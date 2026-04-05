-- InterruptSpells.lua
-- Factual WoW game data: class/spec interrupt spell IDs
-- Shared between Lantern and LuckyWipeTools (embedded copy in each)
-- specID → spellID. nil = spec has no interrupt.

local _, ns = ...

ns.INTERRUPT_SPELLS = {
    DEATHKNIGHT = { [250] = 47528, [251] = 47528, [252] = 47528 },          -- Mind Freeze
    DEMONHUNTER = { [577] = 183752, [581] = 183752, [1480] = 183752 },      -- Disrupt
    DRUID       = { [102] = 78675, [103] = 106839, [104] = 106839 },        -- Solar Beam / Skull Bash (no Resto)
    EVOKER      = { [1467] = 351338, [1468] = 351338, [1473] = 351338 },    -- Quell
    HUNTER      = { [253] = 147362, [254] = 147362, [255] = 187707 },       -- Counter Shot / Muzzle
    MAGE        = { [62] = 2139, [63] = 2139, [64] = 2139 },               -- Counterspell
    MONK        = { [268] = 116705, [269] = 116705 },                       -- Spear Hand Strike (no Mistweaver)
    PALADIN     = { [66] = 96231, [70] = 96231 },                           -- Rebuke (no Holy)
    PRIEST      = { [258] = 15487 },                                         -- Silence (Shadow only)
    ROGUE       = { [259] = 1766, [260] = 1766, [261] = 1766 },            -- Kick
    SHAMAN      = { [262] = 57994, [263] = 57994, [264] = 57994 },          -- Wind Shear
    WARLOCK     = { [265] = 19647, [266] = 119914, [267] = 19647 },         -- Spell Lock / Axe Toss
    WARRIOR     = { [71] = 6552, [72] = 6552, [73] = 6552 },               -- Pummel
};
