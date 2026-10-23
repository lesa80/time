# G-Shock DW-5600 — controls

[Русский](GSHOCK.md) · [English](GSHOCK.en.md)

Vremya 2.9.2. Select **Theme → Legendary models → Casio G-Shock DW-5600**.

The **Interaction** menu appears immediately below the watch name. It works in dial-only mode too. Use **Mode** to go directly to a function.

| Case button | Action |
|---|---|
| A, upper left | Adjust, split, or reset, depending on the mode |
| B, upper right | Start/stop, increment the selected value, or cycle alarm signals |
| C, lower left | Next mode or next setting field |
| D, lower right | Backlight; while editing, time format or auto-repeat |

After an operation in a mode, C returns to Timekeeping, following the Casio guide. Without an operation, C cycles through Timekeeping, Alarm, Countdown, and Stopwatch.

## Timekeeping

Time and date follow macOS. Press A, then D to change 12/24-hour format, then A to finish. The theme does not change the system clock.

D turns on the blue-green backlight for two seconds. Hold B for two seconds to toggle Flash Alert. These options are also available in G-Shock settings under Interaction.

## Alarm

Use **Interaction → G-Shock settings → Set alarm…** to choose the hour, minute, and optional month/day. Zero means any month or day:

- Both zero: daily alarm.
- Day only: monthly alarm.
- Month only: daily during that month.
- Both set: alarm on that date.

A begins and ends editing in Alarm mode. C selects the field; B increments it. Outside editing, B cycles through off → alarm → alarm and hourly signal → hourly signal only → off.

The alarm sounds for up to 20 seconds. Any case button or **Stop alarm sound** in Interaction silences it. The stop command is available even when another theme is selected.

## Countdown timer

The range is 1 second to 24 hours. Use **Interaction → G-Shock settings → Set countdown…** for exact entry. A setting of 00:00:00 represents 24 hours.

B starts, pauses, and resumes. After pausing, A restores the starting value; another A enters editing. C selects hours, minutes, or seconds; B increments the value; D toggles auto-repeat. A finishes editing.

At zero, the signal lasts up to 10 seconds. With auto-repeat enabled, the next cycle starts automatically. Pausing and Mac sleep preserve the countdown phase.

## Stopwatch

B starts, pauses, and resumes. While running, A freezes a split time; another A returns to the live result. Internal timing continues.

For two finishes: B starts; A records the first finish; B records the second finish; A displays the second result; A resets.

The first 60 minutes show minutes, seconds, and hundredths. Later, the display shows hours, minutes, and seconds. At 24 hours it wraps to zero. Changing mode or theme does not interrupt timing.

## Persistence and sound

Short electronic button feedback is enabled by default. Turn it off in **Interaction → G-Shock settings → Button sound**. Set the volume from 0 to 100% in **Interaction → G-Shock settings → Button volume…**. Volume and mute choices persist between launches and do not mute alarms, the countdown, or the hourly signal. Hovering stays silent; a long press gives one beep.

Alarm settings, time format, initial countdown, and signal options persist between launches. In version 2.9.1, the stopwatch also saves its start time, running/paused state and split reading. A running stopwatch includes time while the app is closed; manual pause and reset are preserved. In version 2.9.2, the countdown also saves its remaining time, running/paused state, auto-repeat and selected Countdown mode. A running countdown deducts the interval while the app is closed, including a Mac reboot. Pause and reset persist; changing its duration clears the old measurement.

If it expires while the app is closed, one signal sounds on the next launch. A consumed deadline is saved, so it does not sound again on every relaunch. Auto-repeat preserves the current cycle phase without replaying missed signals. The app does not launch itself or wake the Mac to deliver a sound.

Sound requires the app to remain running and system volume to be audible. Signals work with another theme selected or the clock window hidden. The app does not wake a sleeping Mac: overdue countdowns and alarms are checked after wake. Missed hourly signals are not replayed in a burst.

With Reduce Motion enabled in macOS, setting fields do not blink and Flash Alert stays steadily lit during a signal.

[Official Casio guide, module 3229/3421/3489](https://www.casio.com/content/dam/casio/global/support/manuals/watches/pdf/32/3229/qw3229_EN.pdf)
