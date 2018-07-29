### Version 8.0.0.0

* Updated for WoW 8.0

### Version 7.3.5.1

* Favorite mounts can now be saved per-character -- type `/mountme` for options
* Added demon hunter Fel Rush to the list of abilities to use while moving or in combat
* Removed workaround for flyable detection bugs in WoW 7.3.5 (fixed by Blizzard)

### Version 7.3.5.0

* Added workaround for flyable detection bugs in WoW 7.3.5
* Added workaround for WoW wrongly reporting that class order halls are flyable
* Added support for Broken Isles Pathfinder
* Added support for heirloom mounts (Chauffeured Chopper etc.)
* Merged the mount selection logic from my other addon AnyFavoriteMount (which is now discontinued):
   - Flying mounts are not summoned in non-flying areas
   - Underwater and zone-specific mounts are summoned when appropriate even if they aren't marked as favorites
* Split the flyable detection logic to a reusable library component (see LibFlyable)
