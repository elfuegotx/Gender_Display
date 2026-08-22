# Gender Display

A mod for [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp) that adds
a male/female symbol (♂/♀) to the level display, matching how Gold/Silver/
Crystal show gender info — something the original Gen 1 games never did at
all.

## What it does

- **Battle HUD** (both the classic and wide screen layouts): shows the
  symbol right before the level on both your Pokemon and the opponent's.
- **Summary/stats screen**: shows the symbol right before the level for
  the Pokemon you're viewing.
- **Level 100 fix**: normally the game hides the "LV" tile at level 100 to
  make room for the third digit. This mod keeps showing it on the summary
  screen at level 100 too (see [DIFFERENCES.md](DIFFERENCES.md)).

Genderless species (Magnemite, legendaries, Ditto, etc.) show nothing, and
Nidoran♂/Nidoran♀ — whose names already include the symbol — aren't given
a second one.

Gender itself is computed the same way Generation 2 computed it: each
species has a threshold, and a Pokemon's Attack DV (stored in every save
already) determines which side of that threshold it falls on. Nothing
about how a Pokemon is stored changes — this is purely a display feature.

## Installing

1. Download the latest release (or clone this repo).
2. Copy the `gender_display` folder into your Gen1Recomp `mods/` folder.
   See [Getting Started](https://github.com/bryanthaboi/gen1recomp/wiki/Getting-Started)
   on the Gen1Recomp wiki for exactly where that is on your OS.
3. Launch the game, open **Options → MODS**, and make sure Gender Display
   is turned on.

## Compatibility

Built and tested against Gen1Recomp's Yellow support specifically; should
work fine for Red/Blue too since it only reads standard Pokemon data. No
known conflicts with other mods.

## Credits

Gender-ratio data adapted from the real Generation 2 games' own tables.
