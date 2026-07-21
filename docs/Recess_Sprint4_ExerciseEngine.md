# Recess Sprint 4: Exercise Engine

Status: Implemented, pending device validation and release record

Sprint 4 replaces random exercise assignment with a deterministic, offline
selection engine. It extends the existing exercise repository and session
integration without changing scheduling, session lifecycle, history, facts,
insights, or notification behavior.

## Exercise Metadata

Each catalog entry contains an ID, title, concise description, category,
difficulty, estimated duration in minutes, execution type, standing
requirement, and equipment requirement. Supported categories are Stretch,
Mobility, Breathing, Walking, Strength, and Cardio. Supported difficulties are
Easy, Standard, and Challenging.

Execution types separate what an exercise is from how it should be performed:

- `timed` for activities such as walking and breathing
- `repetitions` for movements such as squats, lunges, and pushups
- `hold` for positions such as planks, balances, and stretches
- `sequence` for an explicit ordered mobility flow or compact circuit

## Library Structure

The bundled JSON asset contains 30 curated exercises: 10 Easy, 10 Standard,
and 10 Challenging. The asset repository validates required metadata,
positive durations, enum values, boolean flags, and unique IDs before exposing
the catalog.

## Selection Algorithm

`ExerciseSelector` receives the requested difficulty, immediately previous
exercise ID, and recent completed exercise IDs. It:

1. Removes the immediately previous exercise from consideration.
2. Selects from the requested difficulty when that tier has an alternative.
3. Prefers exercises absent from recent history.
4. When every candidate is recent, selects the least recently used candidate.
5. Uses stable ID ordering to resolve equal candidates deterministically.
6. Falls back to the nearest available difficulty tier when necessary.

An immediate repeat is never returned. A catalog containing no alternative
produces a state error instead of silently repeating an exercise.

## Difficulty Integration

The existing locally persisted Sprint 3 Exercise Difficulty preference is read
when a session receives its exercise. The session service passes that value and
the five most recent completed exercise IDs into the selector. No new
persistence, provider, or settings model was added.

## Prescription Generation

`ExercisePrescriptionService` combines the selected exercise's execution type
with the existing configured session duration. It is pure and deterministic;
it does not participate in exercise selection or session accounting.

- Timed prescriptions use the configured 3, 5, 10, or 15 minutes directly.
- Repetition prescriptions produce 2, 3, 5, or 7 sets of 10 respectively,
  with 30 seconds rest for shorter sessions and 45 seconds for longer ones.
- Hold prescriptions produce 20 seconds x 3, 30 seconds x 4, 45 seconds x 5,
  or 60 seconds x 5 respectively.
- Mobility sequences render every ordered step and scale to 2, 3, 5, or 7
  rounds. Circuits with prescribed recovery scale to 1, 2, 4, or 6 rounds and
  show the rest interval.

The active Recess screen retains the exercise description and presents the
generated prescription in place of the former raw estimated-duration label.

## Catalog Standards

Every entry is written so it can stand alone for a first-time user. Guidance
names the movement, position, direction, or movement order rather than relying
on phrases such as "move around" or "repeat as needed." The challenging tier
uses low-impact jacks, incline mountain climbers, standing burpees, standing
knee drives, desk pushups, and brisk march intervals to remain practical in a
home office, office, or hotel room. Composite exercises provide their full
ordered steps in the catalog and never ask the user to invent a circuit or
mobility flow.

## Bell Sounds

The existing locally persisted Bell Sound preference now controls scheduled,
deferred, and manual Bell notifications. School Bell, Coach Whistle, and
Gentle Chime are bundled as short WAV resources and require no network access.
Android uses sound-specific notification channels and raw resources; iOS uses
the corresponding bundled notification sound filename. Notification IDs,
payloads, timing, and cadence behavior are unchanged.

Choosing a Bell Sound in Settings immediately previews it without a separate
test control. `BellPreviewPlayer` stops any previous preview before using a
small native platform channel backed by Android `MediaPlayer` or iOS
`AVAudioPlayer`. Preview playback uses system audio attributes and treats an
unavailable audio session as a silent, non-blocking failure.

### Bell Sound Playback Repair

Device validation found that the original Coach Whistle and Gentle Chime WAV
containers held only zero-valued PCM samples, while the original School Bell
had a click-like attack and very low average energy. The files were replaced
with trimmed, normalized recordings and validated for duration, leading
silence, peak level, and byte-identical packaging across Flutter, Android, and
iOS.

`BellSoundDefinition` is now the authoritative mapping for display labels,
Flutter preview asset paths, Android raw resource names, Android channel IDs,
and iOS filenames. Preview playback resolves the registered Flutter asset via
the platform Flutter asset lookup. Android uses the stable channels
`recess_school_bell`, `recess_coach_whistle`, and `recess_gentle_chime`, so
older development channels cannot retain a previous default sound.

The replacement recordings were adapted into short notification clips from
the freely downloadable School Bell, Referee Blows Whistle, and Chimes Crystal
Bell Toll source recordings published by SoundCamp. Their source pages remain
the provenance record for the unmodified recordings.

## Completion Voice

The completion transition uses a small curated set of calm, encouraging primary
messages. Selection is deterministic from the completed session ID, with the
formatter able to avoid an immediately repeated message when a previous choice
is supplied. The voice is intentionally that of a quiet coach: warm and human,
without points, streaks, exaggerated praise, guilt, or other gamification.

One supporting line is selected from existing local context. Meaningful facts
about the completion take priority, followed by the next scheduled Recess time,
the final scheduled Recess of the day, a manual-session acknowledgment, and a
quiet fallback. The widget remains responsible only for the centered visual
treatment; `CompletionMessageFormatter` owns the deterministic copy hierarchy.
