# CleanCooldownManager

A simple & minimalist add-on for World of Warcraft that tweaks the look of Blizzard’s built-in Cooldown Manager until Blizzard implements these changes themselves.

- Zero padding  
- No borders/Black borders
- Minimalist, no overhead 

## About

CleanCooldownManager focuses purely on aesthetics and cleanliness of the built-in cooldown UI. It does **not** add new features, change gameplay, or alter configuration options.  
It simply refines the look of the existing cooldown manager.

## Installation

1. Download or clone the repository.  
2. Copy the `CleanCooldownManager` folder into your WoW `Interface/AddOns/` directory.  
3. Enable the add-on in the Add-Ons list (in-game).  
4. Reload UI (e.g., `/reload`) or restart the game client.

## Usage

No configuration is required for the visual cleanup. Once the addon is enabled the cooldown visuals will be adjusted automatically. You may need to scooch your bars closer to each other if you want them touching.

## Slash Commands

- `/ccm`  
  Displays brief usage help for the addon in chat.

- `/ccm rant`  
 Get my thoughts on the necessity for this addon.

- `/ccm borders`  
 Toggle the black borders ON or OFF.

- `/ccm centerbuffs`  
Toggle buff icon centering ON or Off.

- `/ccm utility`  
 Toggle modifications to the Utility bar ON or OFF.

- `/ccm essential`  
 Toggle modifications to the Essentials bar ON or OFF.

- `/ccm buff`  
 Toggle modifications to the Buffs bar ON or OFF.

- `/ccm settings`  
 Open Advanced Cooldown Manager settings (no jumping through hoops).

- `/ccm reload`  
 Reapply the clean modifications.

## Files

- `CleanCooldownManager.toc` — AddOn manifest for WoW.  
- `CleanCooldownManager.lua` — The core Lua script implementing the tweaks.
- `OptionsPanel.lua` - The modular options panel.
- `LICENSE` — This project is licensed under the GNU General Public License v3.0.  
- `README.md` — This documentation file.

## License

This project is open source under the GNU General Public License v3.0 (GPL-3.0). You are free to use, modify, and redistribute this code under the terms of that license.
