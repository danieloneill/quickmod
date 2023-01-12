# quickmod
Basic mod manager for Fallout 4, Fallout 4 VR, Skyrim SE/AE, and Skyrim VR on Linux

## Building

### Requirements

 * Qt 6.2+
 * libarchive 3.6.0+

### Building

```
leetguy@gibson:~$ git clone --depth 1 "https://github.com/danieloneill/quickmod.git"
leetguy@gibson:~$ cd quickmod
leetguy@gibson:~/quickmod$ mkdir build
leetguy@gibson:~/quickmod$ cd build
leetguy@gibson:~/quickmod/build$ qmake-qt6 ..
Info: creating stash file /home/leetguy/quickmod/build/.qmake.stash
leetguy@gibson:~/quickmod/build$ make -j6
<CPU FAN GOES BRRRRRRR>
leetguy@gibson:~/quickmod/build$ ./quickmod
```

### Usage

This is rather important because at this point in development there is barely any error checking. It's assumed you have everything **just right**.

#### Setup

In the *File* menu open *Settings*:

From the *General* tab you can enter your personal Nexusmods API key, if you're willing to risk that. This key is stored in plaintext at **~/.config/Quickmod/quickmod.conf**

Click the tab of the game you'd like to manage mods for. Each path must be specified:

 * **Mod Storage Directory** - Where the mod archive file is stored. I put mine in the game directory so it follows the game when it's installed on a microsd.
 * **Game Data Directory** - Where the actual game lives. Usually something like */DATA/SteamLibrary/steamapps/common/Skyrim Special Edition* or */home/leetguy/.steam/debian-installation/steamapps/common/Skyrim Special Edition*
 * **User Data Directory** - This should be your compatdata user's account (usually *steamuser*). Something like */DATA/SteamLibrary/steamapps/compatdata/489830/pfx/drive_c/users/steamuser* or */home/leetguy/.steam/debian-installation/steamapps/compatdata/489830/pfx/drive_c/users/steamuser*

Click *Save* and then select that game in the *Games* menu at the top.

Finally, you probably need to enable mods for the game by clicking *Enable mods in game* in the *File* menu. This is also known as "archive invalidation".

#### Handling nexusmods.com links

The simplest way is via Plasma's system settings, found in "Desktop Mode" on SteamOS:

 * Open System Settings
 * Select *Applications*
 * Select *File Associations*
 * Expand *x-scheme-handler*
  * If no entry for **nxm** exists, create it by clicking *Add* at the bottom
 * In *Application Preference Order* (on the right side) click *Add*
 * In the now opened *Choose Application* window, click the browse button in the top-right
 * Browse to and select the **quickmod** binary. (Should be at *~/quickmod/build/quickmod* if you build with my directions above.)
 * Click *Apply* in the bottom right of *System Settings* and now you can close it

#### Notes

If your installation already has mods installed by some other means, they ... will just stay there and on unless you manually remove them (or do so via a different manager), so for best results start from a *clean* installation.

Quickmod must be open AND have the correct target game selected for Nexusmods (NXM) links to work. If you try to install a mod for Fallout 4 while you have Skyrim AE selected, it'll just blindly install the mod into your Skyrim AE data, which probably isn't what you want.

Mods like F4SE/SKSE themselves probably won't install correctly, you gotta set all that crap up yourself. This app isn't currently capable of doing it.

At present, this has been tested with 6 different mods and correctly functions with those 6. YMMV with whatever mod, but if it fails to install (or something breaks) please create a ticket with the mod name as the title.


