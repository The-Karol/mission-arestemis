# Launch cinematic

Mission Control launches the saved, verified cartridge. A separate, quality-scaled
SubViewport renders the cinematic without replacing or modifying the facility.
Return restores the original terminal camera and player controls. Results are
stored in GameState.flight_results and included in the existing save snapshot.

Timeline after the countdown (12–30 seconds, matched to the recorded audio):
- 0–22 s: ignition, tower clearance, pitch programme, ground / chase cameras.
- 22–30 s: core cutoff and close separation shot with venting and sound.
  A single-stage design coasts without showing a fictitious separation.
- 30–42 s: two fairing halves drift away, upper-stage burn.
- 42–61 s: illustrative parking-orbit trajectory map.
- 61–78 s: payload release and animated array deployment.
- 78–103 s: destination transfer map, compressed time.
- 103–124 s: arrival / target acquisition.
- 124–154 s: mission operations and visible outcome.
- Debrief waits for the player; playback itself is at most 184 seconds.

Ten missions select five vehicle families and different outcomes: Mars geology,
lunar polar sampling, exoplanet spectroscopy, galaxy survey, asteroid mapping,
comet measurements, station refueling, atmosphere science, Earth imaging and
navigation constellation commissioning. A lander carries the rover to touchdown;
the rover then drives down the ramp. Navigation joins an existing constellation;
a single satellite does not magically create a complete global network.

This is an edited educational visualization, not an n-body trajectory solver or
science simulator. The trajectory overlay explicitly says NOT TO SCALE. Coast
periods represent hours to months. Scene geometry is scaled for camera framing.
The 0–100 engineering rating uses validated design issues, power reserve and
velocity reserve, rather than random mission success. Science captions describe
the intended illustrative outcome, not a quantitative scientific discovery.

Sequence references:
- https://science.nasa.gov/blogs/sentinel-6/2020/11/21/launch-and-separation-events/
- https://science.nasa.gov/learn/basics-of-space-flight/chapter14-1/
- https://www.jpl.nasa.gov/news/press_kits/insight/launch/mission/

Focused checks: tests/flight_review.tscn renders the main shots and runs all ten
mission endpoints; tests/flight_integration.tscn exercises the launch button,
cartridge handoff, debrief and return to walking. Run with -- --test to avoid
writing player saves.

Retro broadcast revision: 4:3 frame, CRT scanlines / grain / colour fringing,
four countdown cameras including the remote flight controller. First 22 seconds
show ascent; then orbital tracking, close staging and fairing release. Orbital
tracks are illustrative ellipses with focus / Ap / Pe, not a numerical simulator.
Celestial GLBs are included in the web export. Short Space advances a segment;
holding Space accelerates fourfold. Results render above the filter before saving.
KSP reference: https://www.kerbalspaceprogram.com/files/KSPedia-XB1.pdf

3D trajectory revision: the sole tracking overview uses the actual Earth mesh,
a focus-centred inclined ellipse, a 3D vehicle, planned amber path and cyan flown
path. Earth occludes the far side. The second map is replaced by payload checkout
or destination coast. The visual orbit is illustrative, not an orbital solver.

Playback now uses monotonic wall time (not Godot frame delta, which may be clamped
when rendering stalls). Debrief follows 142 seconds of flight plus the countdown;
last operations shot displays seconds until debrief. Automatic processing is
checked by tests/orbit_video.tscn -- --test --automatic-check without Space.
For video capture use --fixed-fps 30 --write-movie build/trajectory_capture.avi
--scene res://tests/orbit_video.tscn -- --test. This records only the orbit overview.
Package browser demo with tools/package_launch_demo.py; never pass a scene path
in HTML args because the web release template disables path overrides.

Ascent clarity revision: the tracking shot now covers only 0.58 radians (33 degrees)
of powered ascent. Earth and camera are stationary. Solid cyan is flown ascent;
short amber dashes are the future upper-stage path, not a completed orbit. The
endpoint says STAGING NEXT, with PLANNED INSERTION farther ahead. No Ap/Pe labels
are attached to the launch site. After separation the upper-stage burn precedes
an explicit insertion-complete caption. Mission coast captions distinguish Earth
orbit from departure towards the Moon, Mars, L2 or small bodies.
