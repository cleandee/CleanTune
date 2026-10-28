# CleanTune

Game audio tuning for Call of Duty Warzone and Black Ops 7 on Windows. It routes the game through Equalizer APO and HeSuVi to lift footsteps, tame explosions and give you headphone virtual surround.

## How the audio flows

```
Game  ->  CABLE Input  ->  Equalizer APO chain  ->  CABLE Output  ->  Listen  ->  Headphones
                           pre > HeSuVi > EQ > post > boost
```

## Requirements

- Windows 10 or 11, 64-bit
- Windows PowerShell 5.1 run as administrator. PowerShell 7 will not work
- Internet connection for the tool downloads

## Install

Right-click the Start button, open **Windows PowerShell as Administrator**, then paste this and press Enter:

```
irm https://raw.githubusercontent.com/cleandee/CleanTune/main/Install-CleanTune.ps1 | iex
```

Choose `1` and follow the prompts. When it finishes, do the manual steps it shows, then read `library\WZ-BO7_SETTINGS.md`.

If that line fails with a TLS or connection error, run this version instead:

```
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; irm https://raw.githubusercontent.com/cleandee/CleanTune/main/Install-CleanTune.ps1 | iex
```

### Run it from a downloaded copy

1. Download the repo as a zip from GitHub and extract it
2. Open **Windows PowerShell as Administrator** in that folder
3. Run `powershell -ExecutionPolicy Bypass -File .\Install-CleanTune.ps1`

The downloaded copy uses the library next to the script. The one-line install always pulls the latest library from GitHub.

## Menu

| Option | What it does |
| --- | --- |
| 1 Install | Installs VB-CABLE, Equalizer APO, HeSuVi and ReaPlugs, copies the library, writes config.txt |
| 2 Refresh tune library | Copies the library again, backing up the old one first |
| 3 Switch tune variation | Swap between No Gun, Competitive and Clean without editing files. Your EQ choice is kept |
| 4 Remove CleanTune | Restores your original config.txt and deletes the CleanTune folder |

Every time config.txt is rewritten the old one is backed up as `config.backup-date.txt` in the Equalizer APO config folder.

## Library layout

```
library/
  WZ-BO7_SETTINGS.md          Windows and in-game settings
  WZ-BO7/
    V1/
      Choose a Tune.txt       What each variation does
      WZ-BO7_V1_pre_nogun.txt No Gun pre chain, the default
      WZ-BO7_V1_pre.txt       Competitive pre chain, 7.1, before HeSuVi
      WZ-BO7_V1_pre_clean.txt Clean pre chain
      WZ-BO7_V1_post.txt      Stereo chain after HeSuVi
      WZ-BO7_Target_V1.txt    Target curve for squig.link
      eq/7Hz_G1.txt           Your 7Hz G1 EQ, used by default
      eq/Flat_EQ.txt          Fallback EQ with no headphone correction
```

## Headphone EQ

1. Open squig.link from the shortcut in the CleanTune folder and pick a database that has your headset
2. Upload `WZ-BO7_Target_V1.txt` as the target in the EQ section
3. Pick your headset and press Auto EQ
4. Save the result into `V1\eq\` as something like `HyperX_Cloud3_WZ-BO7_V1.txt`
5. In config.txt, change the EQ Include line from `Flat_EQ.txt` to your file

## Tuning it yourself

Every filter in the tune files has a comment explaining what it does. Equalizer APO reloads files the moment you save them, so you can tweak a value in game and hear it straight away. Change one thing at a time and keep the Preamp low enough that nothing clips.

## Credits

CleanTune downloads these tools from their official sources at install time and does not bundle them.

- Equalizer APO, GPL-2.0
- HeSuVi, GPL-2.0
- VB-CABLE by VB-Audio, donationware
- ReaPlugs by Cockos, freeware

The idea of a multiband compressor on the front channels came from studying ArtTuneDB by ArtIsWar, licensed CC BY-NC-SA 4.0. CleanTune uses its own settings, and is for personal non-commercial use in the same spirit.
