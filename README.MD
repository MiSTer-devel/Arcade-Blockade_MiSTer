# Blockade by Sega/Gremlin Industries for [MiSTer](https://github.com/MiSTer-devel/Main_MiSTer/wiki)

An FPGA implementation of Blockade arcade hardware for the MiSTer platform

## Credits
- JimmyStones: Core design and implementation
- Jotego: JTFRAME/jtframe_resync module for analog video H/V re-positioning

## Features
- Modelled using original schematics, logic has been simplified to reduce complexity
- Uses vm80a (https://github.com/1801BM1/vm80a) by Vslav (1801BM1) - an 8080A implementation reverse engineered from a Soviet replica!

## Supported games
- 
- 

## Installation
Place `*.rbf` into the "_Arcade/cores" folder on your SD card.  Then, place `*.mra` into the "_Arcade" folder and ROM files from MAME into "games/mame".

### ****ATTENTION****
ROMs are not included. In order to use this arcade core, you must provide the correct ROMs.

To simplify the process, .mra files are provided in the releases folder that specify the required ROMs along with their checksums.  The ROM's .zip filename refers to the corresponding file in the M.A.M.E. project.

Please refer to https://github.com/MiSTer-devel/Main_MiSTer/wiki/Arcade-Roms for information on how to setup and use the environment.

Quick reference for folders and file placement:

/_Arcade/<game name>.mra
/_Arcade/cores/<game rbf>.rbf
/games/mame/<mame rom>.zip
/games/hbmame/<hbmame rom>.zip

## Known Issues
1) No sound!
