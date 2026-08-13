# Media

Swift media infrastructure for inspecting, timing, remuxing, and preparing media assets.

The current primary workflow is recovering Linear Timecode (LTC) recorded into an audio track and materializing it as native source timecode in a MOV container without re-encoding the existing video or audio essence.

Media is built around AVFoundation and Core Media, with `libltc` used for LTC decoding.

## Primary workflow

A camera or recorder may receive LTC as an analog audio signal.

For example:

```text
camera
├── video
├── audio 1
├── audio 2  ← LTC waveform
├── audio 3
└── audio 4
```

The source file contains the LTC signal, but an NLE such as Final Cut Pro generally wants native container timecode rather than an audio waveform.

Media performs:

```text
embedded LTC audio
        ↓
decode LTC
        ↓
detect LTC frame rate and DF/NDF mode
        ↓
fit LTC time against media time
        ↓
recover source-timecode frame + fractional phase
        ↓
write native MOV tmcd track
        ↓
preserve existing video/audio essence
```

For the normal case, this is not a creative retiming operation.

The capture settings should already be correct. `media ltc remux` recovers the timecode that was recorded into the media and represents it properly as native source timecode.

## CLI

### Inspect a media file

```sh
swift run media inspect "/path/to/input.MP4"
```

Inspection reports the asset duration, track layout, media formats, frame rates, timescales, and native timecode-track information.

### Probe LTC and native timecode

```sh
swift run media ltc probe "/path/to/input.MP4"
```

The probe compares information available from the container with LTC decoded from the audio tracks.

Typical information includes:

```text
video_fps 25.0

native_tmcd
    frame=132102
    value=01:13:23:12
    rate=30000/1001
    nominal=30
    drop_frame=false

ltc
    track=3
    channel=0
    rate=30000/1001
    drop_frame=false

anchor
    containing_frame=132102
    estimated=132102.489760...
    phase=0.489760...
```

### Remux LTC as native source timecode

```sh
swift run media ltc remux \
    "/path/to/input.MP4" \
    "/path/to/ltc-input.mov"
```

The output is currently MOV because the workflow writes a native QuickTime timecode track.

The source file is not modified.

The remuxer:

```text
1. finds the embedded LTC signal
2. determines its actual signal rate
3. resolves the source timecode at media start
4. preserves fractional LTC phase where representable
5. writes a native tmcd track
6. associates that track with the video
7. copies the existing video/audio streams without re-encoding them
8. reads the result back and verifies it
```

The CLI also verifies that the encoded video and audio essence remains unchanged.

## Timecode and video frame rate

Video frame rate and LTC frame rate are related capture settings, but they are not the same property.

Normally they should be configured consistently before recording.

For example:

```text
camera video    25 fps
LTC generator   25 fps
```

This is the simplest configuration because picture-frame and timecode-frame boundaries naturally share the same cadence.

Media nevertheless keeps the two timing systems distinct.

A video track has its own frame rate and media timescale. LTC has its own signal rate, nominal frame numbering, and drop-frame mode.

The library does not infer the LTC rate from the video rate.

## Example: 25 fps video with 29.97 NDF LTC

A useful edge case occurred with a camera recording:

```text
video           25 fps
LTC             30000/1001 fps
nominal LTC     30
drop frame      false
```

The incorrect solution would be to reinterpret the recorded LTC as 25 fps merely because the video is 25 fps.

Media instead preserves both facts:

```text
picture clock
    25 fps

LTC clock
    30000/1001
    nominal 30
    NDF
```

The resulting MOV can therefore contain:

```text
video
    nominal frame rate: 25
    media timescale:    25000

timecode
    frame duration:     1001/30000
    frame quanta:       30
    drop frame:         false
    media timescale:    25000
```

The shared media timescale provides a precise movie-time coordinate system without changing the meaning of the LTC clock.

This mixed-rate representation has been tested successfully with Final Cut Pro: the clip imports with source timecode and advances coherently on the 25 fps picture timeline.

The important rule is:

```text
do not coerce LTC to the video frame rate

preserve the recorded LTC clock
and map it accurately onto movie time
```

## Fractional LTC phase

Movie time zero does not necessarily coincide with an LTC frame boundary.

For example, decoding may determine:

```text
media PTS 0
    =
LTC frame 132102.489760...
```

This means media time zero occurs partway through LTC frame `132102`.

A simple timecode track could write:

```text
PTS 0
└── frame 132102
```

but that quantizes away the fractional phase.

Media can instead preserve the boundary:

```text
PTS 0
│
│ frame 132102
│ partial first span
│
├── actual LTC boundary
│
└── frame 132103
```

For a tested source with a video media timescale of `25000`, the resolved boundary was represented as:

```text
sample 0
    frame     132102
    pts       0/25000
    duration  426/25000

sample 1
    frame     132103
    pts       426/25000
```

or approximately:

```text
17.040 ms
```

after media start.

This preserves sub-frame timing information that would otherwise be lost while remaining on the video's movie-time grid.

## Why fit multiple LTC frames?

The decoder does not rely on a single LTC edge to establish the complete mapping.

A run of decoded LTC frames can be used to estimate the relationship between:

```text
audio sample position
        ↕
continuous LTC frame position
```

This provides a stable media-start anchor and exposes:

```text
containing frame
fractional phase
fit residual
frames used
```

The resulting continuous anchor is the timing truth from which the native container representation is derived.

## Existing native camera timecode

A source may already contain a native `tmcd` track.

That track is not automatically assumed to be authoritative when the purpose of the operation is to recover separately supplied LTC from an audio input.

The LTC remux path carries forward the video and audio media tracks and writes the LTC-derived source-timecode track into the new MOV.

Use `media ltc probe` when comparing existing native timecode against decoded audio LTC.

## Media integrity

Timecode remuxing should not require video or audio transcoding.

Media uses passthrough AVFoundation reader/writer paths for existing media tracks.

The verification path compares the encoded bytes of source and candidate video/audio tracks and fails when the preserved media essence differs.

This allows changes to container timing metadata while protecting the original recorded media.

## Audio tracks

The architecture is not based on a four-audio-track limit.

The current LTC remux operation preserves the video and audio tracks already present in the source asset.

A later workflow may also add independently recorded audio tracks to the output container before editing, provided their timing is resolved onto the same media clock.

That is separate from the current LTC remux operation: today the command preserves existing media tracks and adds or replaces source-timecode information.

## Package structure

```text
MediaCore
    shared media primitives

MediaAV
    AVFoundation/Core Media integration
    media inspection
    audio reading
    native timecode
    passthrough remuxing
    essence verification

MediaLTC
    libltc integration
    LTC decoding
    signal-rate detection
    LTC anchor fitting
    LTC → native media-timecode mapping

MediaPath
    media discovery
    output-path and render-layout infrastructure

Media
    umbrella library

media
    command-line interface

mediatest
    integration and regression flows
```

The AV layer intentionally owns generic media/timecode machinery.

LTC-specific interpretation lives in `MediaLTC` and maps into the generic `MediaAV` representation.

## Requirements

The package currently targets macOS 26 for the current Homebrew `libltc` integration.

Install `libltc` with:

```sh
brew install libltc
```

SwiftPM resolves the remaining package dependencies from their repositories.

## Testing

Run the complete Media flow suite with:

```sh
swift run mediatest --verbose --plain
```

and validate whitespace and patch integrity with:

```sh
git diff --check
```

Current coverage includes:

```text
audio-buffer primitives
media discovery and output layout
AV asset inspection
native tmcd creation
timecode-track association
passthrough video/audio remuxing
encoded essence verification
phase-aware timecode samples
audio reading
LTC decoding
29.97 vs 30 rate detection
rational NDF timecode formats
continuous LTC anchors
audio-track/channel LTC selection
```

## Intended capture practice

The repair and mixed-rate machinery exists so that Media represents what was actually recorded rather than silently inventing a simpler clock.

It is still preferable to configure the capture system correctly:

```text
camera frame rate
LTC generator rate
DF/NDF mode
clock configuration
```

should be intentionally chosen before recording.

When those settings are correct, the workflow remains simple:

```text
record LTC into camera audio
        ↓
media ltc remux
        ↓
native source timecode
        ↓
import into the editor
```

The more detailed rate detection, fitting, and phase preservation are there to make that conversion accurate and to behave sensibly when real-world capture conditions are less tidy.
