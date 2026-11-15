# Mission Arestemis - Player README

Welcome to Hyperion Spaceport.

## Start the game

### Windows 10 / 11

1. Extract the entire archive into a folder.
2. Run **Start Game.bat**. It starts a local server and opens the game in your browser.
3. Leave the server window open while playing. Close it when you finish.

Godot, Python and a game installation are not required. Use a current Chrome or Edge with WebGL 2 and hardware acceleration enabled. The server listens only on this computer, at `127.0.0.1`.

Do not open `web/index.html` directly: the game must be served over HTTP.

### macOS / Linux

With Python 3 installed, run from the extracted folder:

```sh
python3 -m http.server 8000 --bind 127.0.0.1 --directory web
```

Open `http://127.0.0.1:8000/` and leave the terminal running.

## Controls

| Input | Action |
| --- | --- |
| WASD | Move |
| Mouse | Look around |
| Shift | Run |
| Space | Jump |
| E | Interact with the highlighted object or person |
| Q | Put down the carried data cartridge |
| J | Reopen the selected mission dossier |
| Esc | Pause / leave an interface |
| Space or Enter during dialogue | Reveal text / continue |
| Delete in an assembly editor | Remove the selected component |
| Tap Space during flight | Skip to the next cinematic segment |
| Hold Space during flight | Play at 4x speed |

The former M map shortcut is disabled. Follow the blue guidance line and mission objective instead.

## Your first mission

1. Meet the engineer and choose whether you want tutorial hints.
2. Find the blank cartridge on the desk in Mission Planning, Launch Control Level 01. Return to the engineer.
3. Follow the engineer to choose a mission. Use J to read its requirements again.
4. Insert the cartridge into the Spacecraft Design computer. Fit the required instruments and onboard systems, then save.
5. Carry the cartridge to Rocket Assembly and build a launcher around that payload.
6. Run the pre-launch verification. Read its list of problems; the objective points you toward the station needed to fix them.
7. Bring the verified design to the launch computer and begin the flight sequence.

Hover over categories, components and performance figures for short explanations. Click a fitted component in the drawing to select it; internal spacecraft modules are also shown below the preview. **Remove selected** removes one component; **Clear all** empties the design. Save changes to update the cartridge.

The mission result opens automatically after the flight. Flight presentation is accelerated and simplified; you do not steer the rocket.

## Sandbox

You begin beside the payload scientist and spacecraft computer. The scientist explains how to start. Choose a spacecraft from the picture cards, fit its instruments and systems, then save your concept and visit Rocket Assembly. There is no story cartridge hunt or mission deadline in this mode.

Changing the spacecraft does not erase the launcher. Recheck its performance against the new payload.

## Rocket Workshop and sharing

After a successful mission:

1. Enter a rocket name in the result window.
2. Select **SAVE TO WORKSHOP**.
3. Open **WORKSHOP** from the main menu.

Each saved blueprint includes rocket components, stage assignments, spacecraft type and fitted modules.

- **OPEN IN SANDBOX:** start a Sandbox session with that design loaded.
- **EXPORT FILE:** download a JSON blueprint to send to another player.
- **IMPORT BLUEPRINT:** choose a blueprint file received from another player.
- **DELETE:** remove a saved entry after confirmation.

Imports accept the game's version 1 blueprint format, up to 1 MB. Unknown components and designs exceeding assembly limits are rejected. The Workshop holds up to 100 entries. Blueprints do not include campaign progress, external models or executable scripts.

## Saving and settings

Campaign and Sandbox progress are saved separately. Use **CONTINUE** when returning to a saved session. Workshop entries are kept separately from those sessions.

Browser saves belong to the browser profile and the server address. Another browser, port or website has separate storage. Clearing site data removes local saves. Export important Workshop blueprints as backups; there is no cloud synchronization.

Open **SETTINGS** from the main menu or pause menu to adjust graphics, sound and controls. Try **Low** on weaker computers. Music and sound effects have separate volume controls.

## Troubleshooting and feedback

- Blank page or loading error: use Start Game.bat, check that the local server is still running, and reload the page.
- No sound: click inside the game and check browser/site audio permissions and the game's volume settings.
- Poor performance: enable hardware acceleration, select Low graphics and close other demanding applications.
- Missing saves: return to the same browser profile and server address used previously.
- Import error: use a Workshop-exported blueprint, not a save file, screenshot or model file.

For a bug report, include the mode, mission, browser, graphics preset, steps to reproduce and a screenshot. If relevant, attach the exported blueprint.
