# Mission Arestemis - Launch Demo

A separate demonstration of the launch presentation, starting at a prepared launch computer. You do not need to complete the campaign or build a rocket first.

## Start

1. Extract the complete archive.
2. On Windows 10/11, run **Start Demo.bat**.
3. Wait for the computer interface to appear, then select **BEGIN LAUNCH SEQUENCE**.
4. Keep the local server window open until you finish.

Use Chrome or Edge with WebGL 2 and hardware acceleration. No Godot or Python installation is needed on Windows. Do not open `web/index.html` directly.

On macOS/Linux with Python 3, run from the extracted folder:

```sh
python3 -m http.server 8000 --bind 127.0.0.1 --directory web
```

Then open `http://127.0.0.1:8000/`.

## What to expect

The prepared Earth-imaging mission shows a countdown, operator and launch-pad views, lift-off, a 3D trajectory segment, stage separation, spacecraft deployment and mission results. The presentation uses a 4:3 retro broadcast treatment and the main-menu music.

The cyan trajectory is the traveled segment. The dashed amber segment shows the planned continuation. This is accelerated educational staging, not a full real-time orbit or a controllable flight simulator.

Results open automatically at the end, after roughly three minutes without skipping. A successful result includes **SAVE TO WORKSHOP**. The demo does not change campaign progress; saving to Workshop explicitly adds a design to that browser's Workshop.

## Controls

- **Tap Space:** jump to the next sequence.
- **Hold Space:** accelerate playback to 4x.
- **Mouse:** use the launch computer and result buttons.

If sound is silent, click inside the game and check browser audio permissions. Report issues with your browser, the affected sequence and a screenshot.

The full game has a main-menu Workshop with blueprint import and export. This isolated demo is intended for reviewing the computer-to-launch flow and cinematic presentation.
