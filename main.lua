-- gender_display: shows a Male/Female symbol next to a Pokemon's level
-- ("LV:") in the battle HUD (both sides, both classic and wide layout)
-- and on the individual Pokemon status/summary screen -- per direct user
-- request (2026-08-23), matching real Gold/Silver/Crystal's own layout
-- (confirmed against real mGBA screenshots the user provided: "DONPHAN
-- :L42[gender]" in battle, "No. 157 :L71 [gender]" on the stats screen --
-- the symbol sits immediately after the level number in both, no space),
-- moved off this mod's earlier position (right after the name).
--
-- Same idea as Feature 21 in the pokeyellow-master + ROM hack: Attack DV
-- vs. a per-species threshold (real Gen 2 gender ratios), a species
-- absent from the table is genderless (no symbol). Table ported directly
-- from engine/battle/gender.asm's GenderRatioList in that project.
-- NIDORAN_M/NIDORAN_F are explicitly excluded even though they DO have
-- real (fixed) threshold entries in that table: their own species NAME
-- already ends in the symbol (a real Gen 1 quirk -- they're effectively
-- separate, always-one-gender species), so drawing it again next to
-- their level would double it up.
--
-- MECHANISM, redesigned from scratch for this move (the earlier "next to
-- name" design's own header comment documents several failed attempts at
-- an external, hand-computed overlay -- wrong position under the WIDE
-- layout, drift from real hudShake, an ink color that "never fully
-- matched" under OG YELLOW -- before landing on "append the symbol onto
-- the name string so the engine's OWN Font.draw call renders it,
-- inheriting position/color/shake for free." That trick doesn't carry
-- over to the level number: unlike battler.name, nothing exposes a
-- settable "level display string" -- BattleState:drawHUDs, WideBattle's
-- own levelAt, and SummaryMenu's own printLevel all compute
-- `tostring(mon.level)` fresh, inline, every frame, with no field to
-- pre-append to.
--
-- Instead of reconstructing any of those (all either module-local
-- functions this project can't require, or large shared methods that
-- depend on further module-local helpers -- reproducing them whole,
-- the "copy the function, change one thing" pattern used elsewhere in
-- this project's mods, isn't viable here without duplicating private
-- internals that would drift out of sync with the real engine), this
-- hooks the two real, EXPORTED, shared functions every one of those call
-- sites already goes through for exactly this content:
--   HudTiles.tile / HudTiles.statusTile(0x6E, x, y, ...) -- the "<LV>"
--     glyph tile, always drawn (classic/wide battle) or drawn only below
--     level 100 (SummaryMenu -- level 100 overwrites the tile with the
--     3rd digit) immediately before the level number itself.
--   Font.draw(text, x, y) -- draws the level number right after it.
-- Both are real module tables (require("src.render.HudTiles") /
-- require("src.render.Font")), not module-local upvalues, so wrapping
-- them is the same legitimate, already-established technique used
-- throughout this project's mods (reassign a function on a shared
-- table). The "<LV>" tile's own (x, y) is checked against every real,
-- known coordinate those 5 call sites actually use (read directly from
-- source, not guessed) to identify which HUD slot is about to draw a
-- level number and for which mon -- then, immediately after Font.draw
-- draws that number, this draws the gender glyph right after it, via
-- the SAME already-real Font.draw call chain, in whatever color/
-- transform/shake state is ALREADY active at that exact point (nothing
-- here calls love.graphics.setColor or push/translate/scale itself) --
-- so it inherits the correct look automatically, the same way the
-- earlier name-based fix did, just generalized to any text-draw site
-- instead of only the name field.
--
-- WIDE SCREEN / VOXEL SAFETY, per explicit user request ("Make sure it
-- is fixed instead to account for voxel, wide screen etc. otherwise the
-- gender symbol will end up in an unusual position"). Wide layout is
-- covered directly -- its own real coordinates (88,8 / 264,64, derived
-- from WideBattle.lua's own drawStatusPanel/levelAt call sites, see the
-- table below) are matched the same way classic layout's are.
--
-- The "voxel" 3D battle-staging mod (installed on disk as `BATTLE_ART_
-- VOXEL_FORK`) was checked directly, not assumed safe -- a first pass
-- only searched its top-level main.lua and found nothing, which was
-- INCOMPLETE: its real ~90-file `lib/` folder does contain one real HUD
-- hook, `lib/OverworldBattle.lua` wrapping `BattleState.drawHUDs`
-- itself, used for its own 3D-overworld-battle presentation (recoloring
-- HUD glyphs for readability against a busy background, and/or
-- relocating the whole HUD block to a screen edge). Traced both paths
-- this wrap can take, in full, before trusting it:
--   1. `flipGlyphs`: redirects the REAL, unmodified `innerHUDs(battle,
--      slide)` call into an offscreen canvas sized to the same native
--      HUD dimensions, with NO translate/scale applied around it --
--      only the CANVAS TARGET changes, never the (x, y) arguments this
--      mod's own HudTiles.tile/Font.draw wraps see. The captured layer
--      is then recomposited with a color-flip shader. Since this mod's
--      own symbol draw happens synchronously from inside that same
--      `innerHUDs` call, it lands in the SAME captured layer and
--      inherits the SAME color-flip automatically -- no separate
--      handling needed, by construction.
--   2. `snapHUDs`: captures the whole real HUD render into a texture,
--      then blits that ONE texture, repositioned/rescaled as a single
--      unit, to a screen-edge "band." Because this mod's own gender
--      symbol was drawn as an inseparable part of that same original
--      capture (not a separate later draw), it moves WITH the level
--      number wherever the band placement puts it -- this mod's own
--      fixed-coordinate table never needs to know about the relocation
--      at all.
-- Verified beyond static reading: mounted the REAL, currently-installed
-- BATTLE_ART_VOXEL_FORK mod (v1.9.6) alongside this one through the real
-- src.mods.Loader -- both report state=loaded, `BattleState.drawHUDs`
-- remains callable after both mods' wraps compose, and a real end-to-end
-- draw sequence (HudTiles.tile(0x6E, 32, 8) then Font.draw("25", 40, 8))
-- still produces the correct ♂ symbol at the exact correct position with
-- the real voxel mod loaded.
--
-- More generally: since this mechanism reads the LIVE (x, y) arguments
-- HudTiles.tile/Font.draw are actually called with (never an
-- independently guessed position), any mod that relocates the HUD would
-- just make this mod's coordinate table stop matching -- the symbol
-- would silently not show in that exotic case, never draw in a wrong
-- spot, since a non-match means "do nothing," not "guess."
return function(mod)
  local GENDER_THRESHOLD = {}
  do
    local TIERS = {
      { thresh = 0, species = {
        "NIDORAN_M", "NIDORINO", "NIDOKING", "HITMONLEE", "HITMONCHAN", "TAUROS",
      } },
      { thresh = 2, species = {
        "BULBASAUR", "IVYSAUR", "VENUSAUR", "CHARMANDER", "CHARMELEON", "CHARIZARD",
        "SQUIRTLE", "WARTORTLE", "BLASTOISE", "EEVEE", "VAPOREON", "JOLTEON", "FLAREON",
        "OMANYTE", "OMASTAR", "KABUTO", "KABUTOPS", "AERODACTYL", "SNORLAX",
      } },
      { thresh = 4, species = {
        "GROWLITHE", "ARCANINE", "ABRA", "KADABRA", "ALAKAZAM", "MACHOP", "MACHOKE",
        "MACHAMP", "ELECTABUZZ", "MAGMAR",
      } },
      { thresh = 8, species = {
        "CATERPIE", "METAPOD", "BUTTERFREE", "WEEDLE", "KAKUNA", "BEEDRILL", "PIDGEY",
        "PIDGEOTTO", "PIDGEOT", "RATTATA", "RATICATE", "SPEAROW", "FEAROW", "EKANS",
        "ARBOK", "PIKACHU", "RAICHU", "SANDSHREW", "SANDSLASH", "ZUBAT", "GOLBAT",
        "ODDISH", "GLOOM", "VILEPLUME", "PARAS", "PARASECT", "VENONAT", "VENOMOTH",
        "DIGLETT", "DUGTRIO", "MEOWTH", "PERSIAN", "PSYDUCK", "GOLDUCK", "MANKEY",
        "PRIMEAPE", "POLIWAG", "POLIWHIRL", "POLIWRATH", "BELLSPROUT", "WEEPINBELL",
        "VICTREEBEL", "TENTACOOL", "TENTACRUEL", "GEODUDE", "GRAVELER", "GOLEM",
        "PONYTA", "RAPIDASH", "SLOWPOKE", "SLOWBRO", "FARFETCHD", "DODUO", "DODRIO",
        "SEEL", "DEWGONG", "GRIMER", "MUK", "SHELLDER", "CLOYSTER", "GASTLY", "HAUNTER",
        "GENGAR", "ONIX", "DROWZEE", "HYPNO", "KRABBY", "KINGLER", "EXEGGCUTE",
        "EXEGGUTOR", "CUBONE", "MAROWAK", "LICKITUNG", "KOFFING", "WEEZING", "RHYHORN",
        "RHYDON", "TANGELA", "HORSEA", "SEADRA", "GOLDEEN", "SEAKING", "MR_MIME",
        "SCYTHER", "PINSIR", "MAGIKARP", "GYARADOS", "LAPRAS", "DRATINI", "DRAGONAIR",
        "DRAGONITE",
      } },
      { thresh = 12, species = {
        "CLEFAIRY", "CLEFABLE", "VULPIX", "NINETALES", "JIGGLYPUFF", "WIGGLYTUFF",
      } },
      { thresh = 16, species = {
        "NIDORAN_F", "NIDORINA", "NIDOQUEEN", "CHANSEY", "KANGASKHAN", "JYNX",
      } },
    }
    for _, tier in ipairs(TIERS) do
      for _, species in ipairs(tier.species) do
        GENDER_THRESHOLD[species] = tier.thresh
      end
    end
  end

  local MALE_SYM, FEMALE_SYM = "♂", "♀"
  local NO_SYMBOL_SPECIES = { NIDORAN_M = true, NIDORAN_F = true }

  -- true = male, false = female, nil = genderless / already shown in name
  local function isMaleFor(species, dvs)
    if not species or NO_SYMBOL_SPECIES[species] then return nil end
    local threshold = GENDER_THRESHOLD[species]
    if threshold == nil then return nil end
    local atk = (dvs and dvs.attack) or 0
    return atk >= threshold
  end

  local Font = require("src.render.Font")
  local HudTiles = require("src.render.HudTiles")
  local Game = require("src.core.Game")

  local LV_GLYPH = 0x6E

  -- Every real call site that draws a level number, and how to resolve
  -- which mon's gender applies there. Coordinates read directly from
  -- source, not guessed:
  --   classic battle (src/battle/BattleState.lua, DrawEnemyHUDAndHPBar /
  --     DrawPlayerHUDAndHPBar): tile at (32,8)/(112,64), level TEXT at
  --     Font.draw(tostring(level), 40, 8) / (..., 120, 64) -- always
  --     8px right of the tile, unconditional (no level<100 check here).
  --   wide battle (src/battle/WideBattle.lua, levelAt via
  --     drawStatusPanel(battle, battle.enemy, 0, 0, false) and
  --     drawStatusPanel(battle, battle.player, 184, 56, true)):
  --     tile x = x + tw*8 - 40 -> enemy 0+16*8-40=88, player 184+15*8-40=264;
  --     tile y = y + 8 -> enemy 0+8=8, player 56+8=64; text is tile+8,
  --     same y -> enemy (96,8), player (272,64).
  --   summary screen (src/ui/SummaryMenu.lua, printLevel(14, 2, mon.level)):
  --     tile x,y = 14*8, 2*8 = 112, 16 -- only drawn when level < 100,
  --     text at (120,16) then; level 100 skips the tile and draws the
  --     text at the tile's own (112,16) instead.
  --
  -- REAL BUG, found live 2026-08-24: `BattleState.lua` captures
  -- `local hudTile = HudTiles.tile` as a plain local ALIAS the moment the
  -- engine itself loads that file -- long before any mod's main.lua ever
  -- runs. That capture is permanent: this mod's own later
  -- `HudTiles.tile = ...` reassignment creates a NEW function value on
  -- the shared table, but `BattleState.lua`'s own `hudTile(...)` calls
  -- keep calling the ORIGINAL one forever, since a captured local doesn't
  -- re-read the table. So the classic battle HUD's own `<LV>` TILE draw
  -- was never actually visible to this mod at all -- confirmed directly
  -- (`local hudTile = HudTiles.tile` at BattleState.lua:5274). WideBattle.
  -- lua only captures `local HudTiles = require(...)` (the whole table,
  -- not one function), so its own `HudTiles.tile(0x6E, x, y)` calls ARE
  -- live field lookups and would have seen this mod's wrap correctly --
  -- classic layout specifically was broken, which is exactly the layout
  -- (`battleLayout = "og"`) the report came in on. `SummaryMenu.lua`'s
  -- own `printLevel` does `local HudTiles = require(...)` FRESH inside
  -- the function body on every call (not cached anywhere), so IT also
  -- correctly saw the wrap -- matching the reported "party/summary
  -- works, battle doesn't" split exactly.
  --
  -- Neither file caches `Font.draw` as a local function alias anywhere
  -- (both only capture `local Font = require("src.render.Font")`, the
  -- whole table -- a live lookup on every `Font.draw(...)` call), so
  -- this mod's own Font.draw wrap was never the problem.
  --
  -- POSITION, redesigned again 2026-08-24 per direct user feedback after
  -- live-testing the "right after the level number" version ("Honestly
  -- doesn't look the best... leaning toward... before the Level, like
  -- Shin Red had it... In RBY, the formatting is really to the right").
  -- Checked Shin Red's own real source directly (shinpokered-master,
  -- the reference repo already on disk) rather than guess at what "like
  -- Shin Red had it" means: `engine/battle/draw_hud_pokeball_gfx.asm`
  -- (its only real battle-HUD gender call site -- enemy only, Shin Red
  -- has no player-side battle gender display at all) does
  -- `coord hl, 3, 1` -- a genuinely FIXED tile position, one whole tile
  -- column to the LEFT of the "<LV>" tile itself (real vanilla/this
  -- project's own enemy "<LV>" tile sits at column 4), completely
  -- independent of how many digits the level has. `engine/menu/
  -- status_screen.asm` (its only other real call site) does
  -- `coord hl, 9, 3` for the summary screen -- which is EXACTLY this
  -- mod's own original, pre-any-redesign position (see this mod's own
  -- history: "Fixed slot, matching our ROM hack's real status_screen.asm
  -- exactly: hlcoord 9,3"), confirming that position was already
  -- Shin-Red-accurate and this redesign's earlier move of it to "next to
  -- the level" was the one actual regression from Shin Red's own real
  -- layout -- reverted back to (9,3) here.
  --
  -- Since the draw position is now a genuinely FIXED spot (not "right
  -- after however wide the level text turned out to be"), each table
  -- entry below carries its own real target (x, y) alongside the mon
  -- resolver, computed the same way Shin Red's own `coord hl, 3, 1`
  -- was: one tile (8px) to the left of the real "<LV>" tile's own
  -- position (already confirmed directly from source for every layout
  -- -- see the coordinate comment further up). Player-side battle
  -- gender is kept (Shin Red itself doesn't have it, but nothing here
  -- asked to drop it, and showing it symmetrically for both sides is a
  -- deliberate, reasonable extension of the same real logic, not a
  -- guess at unrelated new coordinates).
  local function battleMon(side)
    local battle = Game.stack and Game.stack:top()
    if not battle then return nil end
    local battler = side == "enemy" and battle.enemy or battle.player
    return battler and battler.mon
  end

  local function summaryMon()
    local top = Game.stack and Game.stack:top()
    if not top or top.screenId ~= "SummaryMenu" or top.page ~= 1 then return nil end
    return top.mon
  end

  -- Tile-triggered (secondary/backup): fires wherever HudTiles.tile/
  -- statusTile is genuinely reached through a live table lookup, not a
  -- cached local alias -- currently that's the summary screen and, if
  -- the engine ever stops aliasing it, classic battle too.
  local LV_TILE_SPOTS = {
    [32 .. "," .. 8] = { mon = function() return battleMon("enemy") end, x = 24, y = 8 },
    [112 .. "," .. 64] = { mon = function() return battleMon("player") end, x = 104, y = 64 },
    [88 .. "," .. 8] = { mon = function() return battleMon("enemy") end, x = 80, y = 8 },
    [264 .. "," .. 64] = { mon = function() return battleMon("player") end, x = 256, y = 64 },
    [112 .. "," .. 16] = { mon = summaryMon, x = 104, y = 16 },
  }

  -- Direct text-position matching (primary for battle HUD, and the only
  -- path for the summary screen's own level-100 edge case, where
  -- printLevel skips the tile entirely since the 3rd digit overwrites
  -- where it would go). Keyed by the real level-TEXT position (always
  -- 8px right of the tile, or -- for the summary level-100 case -- the
  -- tile's own position, since no tile drew there at all), but the draw
  -- target itself is still the same fixed "one tile left of <LV>" spot.
  --
  -- SUMMARY SCREEN TARGET CORRECTED 2026-08-24, per direct user report
  -- ("a bit awkward" on the party/summary screen). The (72,24) value
  -- ported here from Shin Red's own real `status_screen.asm`
  -- (`coord hl, 9, 3`) was a genuine bug, not just a taste mismatch:
  -- Gen1Recomp's own SummaryMenu.lua draws the level at a DIFFERENT row
  -- than Shin Red's real vanilla layout does -- `printLevel(14, 2,
  -- mon.level)` = pixel (112,16), confirmed directly in source -- so
  -- (72,24) landed in disconnected empty space one row below and several
  -- tiles left of the actual level text, between it and the HP bar, not
  -- actually next to anything. Fixed to (104,16): one tile (8px) left of
  -- Gen1Recomp's own real "<LV>" tile position, same rule already used
  -- correctly for every battle-HUD spot above.
  local LV_TEXT_ONLY_SPOTS = {
    [40 .. "," .. 8] = { mon = function() return battleMon("enemy") end, x = 24, y = 8 },   -- classic
    [120 .. "," .. 64] = { mon = function() return battleMon("player") end, x = 104, y = 64 }, -- classic
    [96 .. "," .. 8] = { mon = function() return battleMon("enemy") end, x = 80, y = 8 },   -- wide
    [272 .. "," .. 64] = { mon = function() return battleMon("player") end, x = 256, y = 64 }, -- wide
    [112 .. "," .. 16] = { mon = summaryMon, x = 104, y = 16 },                               -- summary, level 100
  }

  local pendingResolver = nil

  local function checkLvTile(code, x, y)
    pendingResolver = (code == LV_GLYPH) and LV_TILE_SPOTS[x .. "," .. y] or nil
  end

  local realHudTile = HudTiles.tile
  function HudTiles.tile(code, x, y, tint)
    checkLvTile(code, x, y)
    return realHudTile(code, x, y, tint)
  end

  local realStatusTile = HudTiles.statusTile
  function HudTiles.statusTile(code, x, y, tint)
    checkLvTile(code, x, y)
    return realStatusTile(code, x, y, tint)
  end

  local realFontDraw = Font.draw
  function Font.draw(text, x, y)
    local width = realFontDraw(text, x, y)

    local spot = pendingResolver
    pendingResolver = nil
    if not spot and type(text) == "string" and text:match("^%d+$") then
      spot = LV_TEXT_ONLY_SPOTS[x .. "," .. y]
    end
    if spot and type(text) == "string" and text:match("^%d+$") then
      local mon = spot.mon()
      if mon then
        local isMale = isMaleFor(mon.species, mon.dvs)
        if isMale ~= nil then
          realFontDraw(isMale and MALE_SYM or FEMALE_SYM, spot.x, spot.y)
        end
      end
    end

    return width
  end

  ------------------------------------------------------------------
  -- Always show the "<LV>" tile, even at level 100 -- on the INDIVIDUAL
  -- Pokemon summary screen only. Per direct user request (2026-08-24),
  -- an explicit experiment/deviation from real vanilla design, NOT a bug
  -- fix -- real Gen 1 Pokemon games (confirmed via the real assembly
  -- routine cited directly in this engine's own src/ui/PartyMenu.lua and
  -- src/ui/SummaryMenu.lua comments, home/pokemon.asm:335-345
  -- PrintLevel) deliberately drop the tile at level 100 and let the
  -- third digit take its place, since there is only room for either
  -- "L:99" or "100" -- not "L:100". Battle HUD is untouched: both
  -- src/battle/BattleState.lua and src/battle/WideBattle.lua already
  -- draw the "<LV>" tile unconditionally regardless of level, confirmed
  -- directly (no `if level < 100` gate exists in either), so this
  -- experiment has nothing to add there.
  --
  -- SCOPE: originally also covered PARTY LIST rows, but that half was
  -- dropped the same day per direct live feedback ("You can leave the
  -- party list alone... I do not want that tight/overlapping") -- the
  -- party list rows end flush against the status/FNT text column with
  -- zero gap once the tile is added (104 + 8 tile + 24 text = 136,
  -- landing exactly at the status column's own start), which read as
  -- too cramped in practice. SummaryMenu page 1 is kept, since it has
  -- plenty of spare room either way (its own level column's neighbor, a
  -- box border, sits well clear at column 19 = x152).
  --
  -- LIVES HERE (not a separate mod), per direct user correction --
  -- briefly split into a standalone `lv100_tile_display` mod, then
  -- folded back in: "I meant the LV should live within the gender_display."
  --
  -- Mechanism: SummaryMenu.lua's own level-100 branch is inline in a
  -- private, non-exported local function (`printLevel`), so it can't be
  -- wrapped/patched directly. Instead this hooks the same real, exported
  -- Font.draw this mod already wraps above, matched against the exact,
  -- known, real "no tile, level==100" position (read directly from
  -- source, not guessed): SummaryMenu's page-1 level slot (112,16). On a
  -- match, draws the "<LV>" tile at the ORIGINAL position first, then
  -- redraws the level text shifted 8px right instead of letting the
  -- original, un-shifted draw stand -- reproducing exactly what
  -- printLevel itself already does for level<100, just also for
  -- level==100.
  --
  -- ORDER MATTERS: this wraps Font.draw a SECOND time, installed AFTER
  -- (so OUTER than) the gender-symbol wrap above. A real engine call now
  -- hits THIS wrap first: it draws the "<LV>" tile (a live HudTiles.tile
  -- call, which the ABOVE checkLvTile/pendingResolver mechanism reacts
  -- to) before calling down into the gender-symbol wrap for the actual
  -- level-text draw -- reproducing the same real, verified synergy this
  -- had as a standalone mod: a level-100 Pokemon on the summary screen
  -- now shows BOTH the shifted level text AND its gender symbol,
  -- correctly positioned, in one pass.
  do
    local NO_TILE_LV_SPOTS = {
      [112 .. "," .. 16] = true, -- SummaryMenu page 1
    }

    local realFontDraw2 = Font.draw
    function Font.draw(text, x, y)
      if text == "100" and NO_TILE_LV_SPOTS[x .. "," .. y] then
        HudTiles.tile(LV_GLYPH, x, y)
        return realFontDraw2(text, x + 8, y)
      end
      return realFontDraw2(text, x, y)
    end
  end
end
