Magical_Realm
=============
This is a modpack intended to include magical things.


magic_spells
------------

An API for magical spells. See magic_spells/API.txt for more info.

To test spells, you can give yourself a testing wand with
"/give player_name magic_spells:creative_stick". If you are playing on single-player,
the player name will be "singleplayer".

Next, grant yourself the "prepare" privilege ("/grant player_name prepare"). You
can only do this with the proper privileges, which you do get in single-player.

Then you can use "/prepare" to prepare spells, "/unprepare" to release your spell
slots.

To use the wand, first select a spell by right-clicking. Then you can cast the spell
by left-clicking. Note the spell name you input must be the real spell name rather
than the display name.


evocation_spells
----------------

Spells mostly involving destructive or energetic effects.

Current Spells (Display name in parentheses):

summon_tnt (Summon Lit TNT) - Places a lit tnt node where you are looking when your
  casting finishes.
