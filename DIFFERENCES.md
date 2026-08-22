# Differences from vanilla

This mod is purely cosmetic — it never changes how a Pokemon is stored,
caught, bred, traded, or battled. Everything below is display-only.

## Gender symbol (new)

Vanilla Generation 1 games never display a Pokemon's gender anywhere.
This mod adds a ♂/♀ symbol next to the level number:

- In battle, on both the player's and the opponent's status box.
- On the individual Pokemon summary/stats screen.

Gender is derived from the Pokemon's existing Attack DV using the same
threshold table Generation 2 used, so it's consistent with what a
Generation 2 game would display for the same Pokemon.

## "LV" tile always shown at level 100 (deviation from real vanilla)

Real Game Boy Pokemon games hide the "LV" tile once a Pokemon reaches
level 100 — there's only enough room on screen for either "L:99" or
"100", not "L:100". This mod keeps the tile visible on the summary
screen even at level 100, shifting the level number over to make room.

This is a deliberate stylistic choice, not a bug fix — the party list
(the scrolling list of all 6 Pokemon) is intentionally left alone and
still matches real vanilla behavior, since there wasn't enough spare
room there to add the tile without it looking cramped.
