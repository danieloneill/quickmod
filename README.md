# quickmod
Basic mod manager for Fallout 4, Fallout 4 VR, Skyrim SE/AE, and Skyrim VR on **Linux**

**This app is ragged-edge at the moment, and this project is published because it finally works at all.**

*There is no warranty if it messes up your Steam installation, or your entire PC*

What I'm trying to say is: **This probably isn't the app you want.**

---
To install this on a Steam Deck, I made a little installer... thing.

To use it, download this installer file: [http://dawnnest.com/~doneill/Install%20Quickmod.desktop](http://dawnnest.com/~doneill/Install%20Quickmod.desktop)

In your Downloads directory, run it. It'll ask if you trust it (and by proxy, me) to execute this possibly damaging and malicious script on your incredibly expensive luxury game consolehmmuahAHAHAHAhahaHAHA... I mean, click Continue.

Theoretically, that's basically it. Just open it from the desktop icon and proceed to the **Setup** instructions below.

Remember: You need to **open the manager** and **select the correct game** before clicking those NexusMods links.

(Skyrim VR and Skyrim SE both use basically the same mods, and at least, the same NexusMods section. The same is true for Fallout 4 and Fallout 4 VR. While I could check to see if the currently loaded game profile matches the link *roughly*, I think it's better to not open that can of worms and pass the responsibility on to You, the Customer.)

*What does this installer actually install?*

I couldn't be messed with doing anything TOO complex, so it just downloads an archive containing a prebuilt binary, a new .desktop for your actual desktop mode Desktop, various sizes of the ugly icon, and another .desktop which should automatically associate nxm links. (Also hosted on my server.)

You can see for yourself by just downloading and opening [the archive in question](http://dawnnest.com/~doneill/quickmod-steamdeck.tar.xz).

---

## Building

### Requirements

 * Qt 5.12+
 * libarchive 3.6.0+

### Building

```
leetguy@gibson:~$ git clone --depth 1 "https://github.com/danieloneill/quickmod.git"
leetguy@gibson:~$ cd quickmod
leetguy@gibson:~/quickmod$ mkdir build
leetguy@gibson:~/quickmod$ cd build
leetguy@gibson:~/quickmod/build$ qmake ..
Info: creating stash file /home/leetguy/quickmod/build/.qmake.stash
leetguy@gibson:~/quickmod/build$ make -j6
<CPU FAN GOES BRRRRRRR>
leetguy@gibson:~/quickmod/build$ ./quickmod
```

### Usage

This is rather important because at this point in development there is barely any error checking. It's assumed you have everything **just right**.

#### Setup

*(Screenshots are from earlier Qt6 development build so yours may look slightly different, but the steps are the same.)*

In the *File* menu open *Settings*:

![quickmod1](https://user-images.githubusercontent.com/10540429/212122709-0d3ca494-a9bd-493f-a320-90b6b04bc592.png)

From the *General* tab you can enter your personal Nexusmods API key, if you're willing to risk that. This key is stored in plaintext at **~/.config/Quickmod/quickmod.conf**

![quickmod2](https://user-images.githubusercontent.com/10540429/212122741-fde97024-bc99-4df9-8060-800c308cec47.png)

Click the tab of the game you'd like to manage mods for. Each path must be specified:

 * **Mod Storage Directory** - Where the mod archive file is stored. I put mine in the game directory so it follows the game when it's installed on a microsd.
 * **Game Data Directory** - Where the actual game lives. Usually something like */DATA/SteamLibrary/steamapps/common/Skyrim Special Edition* or */home/leetguy/.steam/debian-installation/steamapps/common/Skyrim Special Edition*
 * **User Data Directory** - This should be your compatdata user's account (usually *steamuser*). Something like */DATA/SteamLibrary/steamapps/compatdata/489830/pfx/drive_c/users/steamuser* or */home/leetguy/.steam/debian-installation/steamapps/compatdata/489830/pfx/drive_c/users/steamuser*
 
![quickmod3](https://user-images.githubusercontent.com/10540429/212122774-09a89b3b-80a0-47ff-998d-235a200d836b.png)

Click *Save* and then select that game in the *Games* menu at the top.

![quickmod4](https://user-images.githubusercontent.com/10540429/212122780-8300cba7-965c-45b2-944e-cfbe22b31526.png)

Finally, you probably need to enable mods for the game by clicking *Enable mods in game* in the *File* menu. This is also known as "archive invalidation".

![quickmod5](https://user-images.githubusercontent.com/10540429/212122797-d0f9aef5-45b9-42ed-a3be-c02eac862daa.png)

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
 
![nxm](https://user-images.githubusercontent.com/10540429/212124402-1aa24108-7658-45b4-86d2-c5360c6af049.png)

#### Notes

* If your installation already has mods installed by some other means, they ... will just stay there and on unless you manually remove them (or do so via a different manager), so for best results start from a *clean* installation.

* Quickmod must be open *and* have the correct target game selected for Nexusmods (NXM) links to work. **If you try to install a mod for Fallout 4 while you have Skyrim AE selected, it'll just blindly install the mod into your Skyrim AE data, which probably isn't what you want.**

* Mods like F4SE/SKSE themselves won't install correctly, you gotta set all that up yourself. This app isn't currently capable of doing it, but luckily it's a well-documented process which isn't difficult to do manually.

* At present, this has been tested with a handful of mods, and it correctly functions with those. YMMV with whatever mod, but if it fails to install (or something breaks) please create a ticket with the mod name as the title.

* ~~Mods are installed in order, and loaded in that order. This isn't what anybody wants, but for now there is no load order manager. You'll have to manually edit your loadorder.txt because of this (for now).~~

* There currently is no overwrite protection: the latest mod will simply overwrite any other files (including masters).

* File tracking is VERY crude: if a new mod overwrites files in a different mod, that file will simply be deleted when either mod is uninstalled.


I view this version (in its current state) as more of a learning exercise. Having written it to this stage (which actually works) I can see what I would change in a rewrite, which is my next big plan.
