### Version 7.3.5.0

* Added workaround for flyable detection bugs in WoW 7.3.5
* Added workaround for WoW wrongly reporting that class order halls are flyable
* Added support for Broken Isles Pathfinder
* Added support for heirloom mounts (Chauffeured Chopper etc.)
* Merged the mount selection logic from my other addon AnyFavoriteMount (which is now discontinued):
   - Flying mounts are not summoned in non-flying areas
   - Underwater and zone-specific mounts are summoned when appropriate even if they aren't marked as favorites
* Split the flyable detection logic to a reusable library component (see LibFlyable)

### Version 7.0.3.0

* Updated for WoW 7.0 (Legion)
* Fixed support for AQ40 and Vashj'ir special mounts

### Version 6.2.2.9

* Fixed: Nagrand garrison mounts will no longer take priority over normal mounts with Draenor Pathfinder

### Version 6.2.2.8

* Updated for WoW 6.2 and Draenor Pathfinder
* Fixed support for Hallow's End Magic Broom

### Version 6.1.0.7

* Updated for WoW 6.1

### Version 6.0.3.6

* Added support for mounting while moving while Aspect of the Fox, Ice Floes, Kil'jaeden's Cunning, or Spiritwalker's Grace is active
* Added support for casting Aspect of the Cheetah, Blazing Speed, Chi Torpedo, Death's Advance, Roll, Speed of Light, or Sprint while moving or in combat

### Version 6.0.3.5

* Added support for Nagrand garrison zone mounts
* Don't cancel Moonkin Form when mounting

### Version 6.0.3.4

* Added Ashran to the list of zones that aren't really flyable even though WoW says they are

### Version 6.0.3.3

* Fixed druid Cat Form fallback when indoors or when Travel Form is unknown

### Version 6.0.3.2

* Cancel warlock Metamorphosis when mounting
* Workaround for WoW API wrongly reporting garrisons as a flyable area

### Version 6.0.3.1

* First public release
