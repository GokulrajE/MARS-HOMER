# Migration coverage and validation

The unified Godot project now contains all nine games and application screens for patient configuration, prescriptions, import, device connection/setup/calibration, training plane, range assessments, arm-weight assessment, diagnostics, trial summaries, and upload/session-service configuration.

## Implemented integration

- Windows serial bridge at 115200 baud, 8N1, DTR enabled; local authenticated transport.
- JEDI frame buffering, fragmentation, checksum validation, sensor/diagnostic decoding, heartbeat and watchdog.
- Device commands and button events; explicit activation, calibration and plane actions.
- Original forward kinematics, handedness mapping, calibrated ranges and telemetry logging.
- Profiles, prescription gates, range and weight recording, legacy-shaped CSVs, patient import, summary and daily stars.
- 60-second trial controller, adaptive reach speed, special Table Wiping scrub-area adaptation, pause and close saving.
- Nine playable games; source artwork reused where available; shared saved-results screen and post-trial Fireworks finale.
- Configurable invocation of the installed AWS uploader and NeuroDash sender; optional local session-agent protocol.
- Portable Windows packaging plus source project and automated tests.

## Verified here

- All nine games launch, pause, save and finish at the trial boundary.
- Added-game success/miss events, duplicate resolution prevention, speed persistence and CSV widths.
- Legacy-game hold resets and thresholds, paddle/opponent returns, matching-colour catches, flight opening, stain-alpha clearing and stationary firing.
- Packet framing/checksum recovery, numeric decoding, command byte layout, kinematics and watchdog hold using synthetic packets.
- Patient/assessment persistence, import-overwrite rejection, device-start gates and measured telemetry columns using test fixtures.
- Windows serial bridge authentication and missing-port reporting through nonexistent COM9999.
- Graphical checks of every game and all workflow screens.

## External verification still required

- No COM port was available: serial streaming from a physical MARS unit, command acknowledgements, actual movement, force behavior and disconnection recovery need device testing.
- Live AWS upload, NeuroDash delivery and agent ownership exchanges need the installed services and credentials. No production upload was performed.
- Clinical equivalence and exact visual/physics parity against Unity are not established by these tests. The Unity scenes remain the reference for acceptance testing.

## Deliberate differences / remaining parity limitations

- Presentation of the six native games was rebuilt with the original Unity sprites plus procedural animation; sprite timing and exact scenery are not frame-matched to Unity.

- Unity's separate calibration, plane-selection and activation scenes are one guided sequence. The plane step uses a slider with move/save instead of Unity's wait-for-horizontal-reach substeps; it is untested against a robot.
- The Choose-movement gate follows Unity on a device, but in simulation a missing assessment is advisory.
- Reference videos are re-encoded to Ogg Theora without audio.
- The summary chart plots minutes per day (31-day window for long prescriptions); the XCharts widget is not reproduced.
- The new screens and the set-up state machine are verified with synthetic packets only; the MARS-button gestures have not been tried on a physical handle.

- All games stop recording at exactly 60 active seconds; some Unity controllers finished the current target after their timer elapsed.
- Raw headers name the four joint-angle values that Unity appended without header names. The first 32 columns keep their existing order.
- Error flags use a standard 16-bit little-endian decode. The Unity implementation used a 255 multiplier for the high byte, which is not a standard uint16 decode.
- Table Wiping uses the source stain alpha image at a fixed logical resolution; Unity sprite scaling and erasure sampling can differ.
- Ping Pong and Tuk Tuk are native Godot implementations, not conversions of Unity physics objects. Collision tolerances, opponent behavior and visual geometry require reference-session comparison.
- Unity animation controllers, all scenery variants, configuration-time S3 patient-ID verification and the original setup-animation sequence are not reproduced one for one. Local patient configuration and explicit setup controls cover the working workflow.
- External AWS/NeuroDash Python programs remain site-installed dependencies. Their credentials and server-side behavior are not part of the Godot project.

These boundaries are intentionally explicit; the package should not be described as physically validated or pixel-identical to the Unity application.
