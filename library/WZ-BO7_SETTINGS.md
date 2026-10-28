# Warzone and Black Ops 7 settings for CleanTune

Apply these before you play. If any of them are wrong the game can bypass the chain completely. Menu names can shift between game updates, so look for the closest match if one has moved.

## Windows

- Playback device **CABLE Input** set to **7.1 Surround** under Configure
- CABLE Input and CABLE Output both set to **24 bit, 48000 Hz** under Properties then Advanced
- CABLE Output has **Listen to this device** ticked, playing back through your headphones
- Spatial sound turned **off** on CABLE Input and on your headphones
- Your headphones should NOT be ticked in the Equalizer APO Configurator. Only CABLE Input should be

## In game, Audio tab

| Setting | Value | Why |
| --- | --- | --- |
| Game sound device | CABLE Input | Sends the game into the chain |
| Speaker Output | Windows Default | Lets the game follow the 7.1 format of CABLE Input |
| Master volume | 100 | Gives the chain the full signal to work with |
| Effects volume | 100 | Same reason |
| Dialog volume | Your choice | Lower it if callouts get in the way |
| Music and Menu Music | 0 | Music masks footsteps |
| Audio Mix | Headphones Bass Cut | Cleanest starting point for competitive play |
| Enhanced Headphone Mode | Off | It does its own surround and fights HeSuVi |
| Asymmetrical Hearing Compensation | Off | Keeps left and right balanced going into the chain |
| Mono Audio | Off | Mono collapses the 7.1 signal and breaks the tune |

Control loudness with Windows volume, the boost file or your headset, not the in-game sliders.

## In game, Voice tab

| Setting | Value | Why |
| --- | --- | --- |
| Voice chat output device | Your normal headphones | Keeps team comms out of the chain so voices sound natural and the No Gun tune does not squash them |

## Quick test

1. Load into a private match or the firing range
2. Open the E-APO Configuration Editor from the CleanTune folder
3. The level meters should move while game audio plays. If they stay flat, the game is not outputting to CABLE Input
4. Turn the chain off and on with the power button in the editor to hear the difference

## Fixes

- **No sound at all**: check Listen to this device is ticked on CABLE Output and pointed at your headphones
- **Sound but no effect**: Equalizer APO is not installed on CABLE Input. Run the Configurator again
- **Only stereo, no surround**: CABLE Input is not set to 7.1, or Speaker Output in game is not Windows Default
- **Crackling**: sample rates do not match. Set everything to 48000 Hz
- **Own gun still too loud**: make sure ReaPlugs is installed in Program Files then VSTPlugins then ReaPlugs, and that the PRE HESUVI line points at the nogun file
- **Too quiet**: raise the value in `CleanTune\boost.txt` by 2 dB at a time
