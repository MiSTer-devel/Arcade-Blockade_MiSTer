# Blockade by Sega/Gremlin Industries for [MiSTer](https://github.com/MiSTer-devel/Main_MiSTer/wiki)

An FPGA implementation of Blockade arcade hardware by Gremlin Industries for the MiSTer platform.

## Credits
- __JimmyStones__: Core design and implementation
- __Vslav (1801BM1)__: [vm80a](https://github.com/1801BM1/vm80a) CPU (8080A implementation reverse engineered from a Soviet replica!)
- __Jotego__: [jtframe_resync](https://github.com/jotego/jtframe/blob/master/hdl/video/jtframe_resync.v) for analog video H/V re-positioning
- __Soltan_G42__: 1st order low-pass filter for audio circuit - thanks also to __Ace__ for explanations on how to use and tune the filter

## Implementation details
- Built entirely in simulation using original schematics and information from MAME, logic has been simplified where possible
- Supports all Gremlin produced games based on the Blockade hardware
- Monochrome video output with selectable colour overlay (Green,White,Yellow,Red)

## Supported games
- Blockade (1976)
- CoMotion (1977)
- Hustle (1977)
- Blasto (1978)

## Known issues
- Square-wave sound circuit is probably not working at the correct frequency (hard to verify without access to a good recording of original machine)
- Boom sound circuit is not implemented, so it uses a sample (from https://samples.mameworld.info/)
- Coin circuit timing is suspect, but it works!
- Free game on Hustle cannot be disabled in DIPs (limitation of MiSTer DIPs system)

## Installation
Place `*.rbf` into the "_Arcade/cores" folder on your SD card.  Then, place `*.mra` into the "_Arcade" folder and ROM files from MAME into "games/mame".

### ****ATTENTION****
ROMs are not included. In order to use this arcade core, you must provide the correct ROMs.

To simplify the process, .mra files are provided in the releases folder that specify the required ROMs along with their checksums.  The ROM's .zip filename refers to the corresponding file in the M.A.M.E. project.

Please refer to https://github.com/MiSTer-devel/Main_MiSTer/wiki/Arcade-Roms-and-MRA-files for information on how to setup and use the environment.

Quick reference for folders and file placement:

/_Arcade/<game name>.mra
/_Arcade/cores/<game rbf>.rbf
/games/mame/<mame rom>.zip
/games/hbmame/<hbmame rom>.zip
