# Moonscarlet's Chat Scanner

![Screenshot](images/0.png)

![Screenshot](images/2.png)

A World of Warcraft addon that watches chat for the words you care about and alerts you when they appear. It works well with spammy channels like Trade, LFG and World.

## Features

- In-game window (`/cs` or the minimap button) with tabs for Keywords, Ignored Players, Chats and Settings
- Match words or phrases, require several words together, or exclude words
- Edit existing keywords in place
- Choose which chats are scanned:
  - **On by default:** Guild, Say, Yell, Channels
  - **Off by default:** Officer, Party, Raid, Battleground / Instance, Whispers
- Per-player ignore list (separate from the game's own ignore list)
- Choose the alert sound from a list (Cat by default), with an optional "play even if game sound is muted"
- Choose the color of the alert text (the original blue by default)
- Send alerts to any of your chat tabs (the first tab by default)
- Optional raid warning style alert: big text in the middle of the screen (off by default)
- Optional taskbar flash when the game is in the background
- Clickable, class-colored player names in alerts
- Skips your own messages and duplicate messages
- Settings and lists are saved between sessions

## Installation

1. Download the latest release.
2. Extract the `MoonscarletsChatScanner` folder into `World of Warcraft/_<version>_/Interface/AddOns/`.
3. Restart the game or type `/reload`.

## Usage

Type `/cs` or click the minimap button, then:

1. Open the **Keywords** tab, type what you're looking for and press Enter.
2. Optionally fill in "...but NOT any of these" to skip unwanted messages.
3. Use the **Chats** tab to choose where to listen.
4. Use the **Settings** tab to choose how you're alerted.

### Alert settings

All of these are on the **Settings** tab:

| Setting | Default | What it does |
|---|---|---|
| Sound | Cat | Pick from the list next to "Play a sound". Each sound plays when you pick it so you can compare them. |
| Play sound even if game sound is muted | Off | Uses the Master volume channel. |
| Raid warning style alert | Off | Also shows the match as big text in the middle of your screen. |
| Show alerts in this chat tab | First tab | Prints the alert in the chat tab you pick. If that tab gets closed, the first tab is used. The Combat Log can't be picked. |
| Alert text color | Blue | Click the swatch to pick a color; **Reset** brings back the default. |
| Flash the WoW icon in the taskbar | Off | Helpful when the game is minimized or in the background. |

Use **Test notification** to preview your alert settings.

### Keyword rules

- Separate words with commas to require **all** of them: `tank,dungeon`
- Use the second box to exclude words: `gold,boost`
- Spaces count exactly as typed, so `" tank "` only matches the whole word.

### Slash commands

| Command | Description |
|---|---|
| `/cs` | Open or close the window |
| `/cs add [text]` | Add a keyword (`_` = space, `\|` = must match all, `-` = exclude) |
| `/cs del [number]` | Remove a keyword |
| `/cs toggle [number] [number] ...` | Turn keywords on/off (e.g. `/cs toggle 1 2 3`) |
| `/cs edit [number] [String]` | Replace a keyword (same format as add) |
| `/cs clear` | Clear all keywords |
| `/cs list` | Print keywords and settings |
| `/cs addplayer [name]` | Ignore a player |
| `/cs delplayer [number]` | Stop ignoring a player |
| `/cs clearplayers` | Clear the ignore list |
| `/cs players` | Print ignored players |
| `/cs enable` / `/cs disable` | Turn scanning on or off |
| `/cs mute` | Toggle notification sound |
| `/cs master` | Play sound even if game sound is muted |
| `/cs flash` | Toggle taskbar flash |
| `/cs help` | Print all commands |

Examples: `/cs add dps|scholo`, `/cs add LFM_Molten_Core|-gold`

# Screenshot
![Screenshot](images/1.png)


![Screenshot](images/3.png)

![Screenshot](images/4.png)

![Screenshot](images/5.png)

