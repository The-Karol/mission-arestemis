# Audio for Space Mission

Drop licensed audio here; these folders are ready for the Godot AudioStreamPlayer nodes.

- `music/`: menu and in-game music, preferably looping OGG Vorbis.
- `ambience/`: ventilation, assembly hall, laboratories and control-room loops (OGG).
- `sfx/ui/`: buttons, terminal confirmation and error sounds (short WAV/OGG).
- `sfx/world/`: elevator, doors, cartridge insertion/ejection, machines.
- `sfx/player/`: footsteps and handling sounds.
- `voices/`: Engineer dialogue / localized voice-over.

Music and ambience route to the existing `Music` bus, other effects to `SFX`.
Volume sliders already control those buses. There are no bundled music or voice
recordings yet. Keep files small for the browser download and add licensing
credits when adding third-party recordings.
