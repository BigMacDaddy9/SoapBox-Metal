CORE SYSTEMS — 
1. *NEW* VEHICLE BUILD SYSTEM (MODULAR + DESTRUCTIBLE)
Heading towards building a modular vehicle system that will allow players to build their soapbox how they choose to. Soapbox parts are connected via joints that give the soapbox a “wobbly, homemade feel.” Parts fall off when these joints break. 
Vehicle Current State:
Vehicles are assembled from:
•	platform (4 wheel, 3 wheel, or 2 wheel)
•	a base (light or heavy)
•	attachable parts via a mount system (seat, nose, etc.) 

The Joint System:
Current System (Multi-Joint Model):

Updated the Joint System so that each mounting point had a different number of joints assigned to it. Parts now connect via multiple joints depending on which mount point it is assigned to. 
Part Type	Joint Count	Layout
Left/Right Mount	3	front / center / rear
Front/Rear Mount	2	left / right
Seat	4	corners
Nose	1	center

I tried to make the joints feel a little like springs so that we had that same wobble feel. This joint structure is also built with the idea in mind that eventually, parts will have a joint between each other which can also snap/break. 
________________________________________
 2. The Tracks
Test Hill 01
Purpose:
•	Basic downhill testing 
Features:
•	procedural generation 
•	finish trigger 
•	win UI 

Test Hill 02
Purpose:
•	Introduce complexity 
Features:
•	angled turns (Y rotation added) 
•	gap in the track for “jumping”
•	extended track flow 

*NEW* Test Hill 03 — “Nurburger Ring”
Purpose:
•	long-term testing , ie more time on the track for testing
•	repeated laps 
•	stress testing vehicles 
Features:
•	loop track 
•	continuous driving 
•	multiple test scenarios per run 

Track System Notes:

All tracks are procedurally generated in the sense that they are built when the track is loaded, not pre-built and then loaded. The track scripts will always position the segments in the same place, so they procedural generation is not random, nor infinite. 
________________________________________
3. *NEW* MUSIC/PLAYLIST SYSTEM 
There are “two” playlists built into the game. One plays in the menu’s and one plays in game. They are technically the same playlist, but this double playlist system allows for music separation in the future if needed/wanted, and it allows for transitions and fading in the music when transitioning between the menu and the actual game. 

There is a fade out built in when switching from menu to game, and because of this, I added in a “loading screen” which gives the game a bit of time so the fade out doesn’t feel out of place when switching scenes. 
There is a “now playing” pop up which shows you which song is currently playing. The coding allows for a hardcoded track selection from file, and a separate custom name tag. This means you can import “MYMp3.mp3” and name it “That Cool Song” in game. 
________________________________________
4. *UPDATED* UI SYSTEMS
The Main Menu
The home screen or landing page for the game. I updated the Main Menu to launch in full screen now, this gave me a little more screen real estate to play around with the UI. 

The update Main Menu UI now shows a rotating preview of your current soapbox build on the right hand side. 

I have added a “Build Soapbox” option to the main menu, as well as a few labels that show what platform (4 wheel, 3 wheel, or 2 wheel) and what base (light or heavy) is currently being used in the soapbox. 

The other buttons (Arena, AI toggle, Downhill Tracks and Quit) are still in play. 
The In-Game Menu
The in-game menu appears when you are in-game and press Escape. It handles in-game resets, heading back to the main menu, and quitting the game entirely. I made it slightly larger than before. I was also toying with the idea of having the music paused while in game. I have left the music to continue for now, but I think I might muffle the music when using the in-game menu in the future. 

*NEW* The Build Preview
When clicking the “Build Soapbox” button on the main menu, you are taken to the Build Preview. This is where players can build their soapboxes to use in game. 

The Build Preview has three tabs: a Platform Selection Tab, a Base Selection Tab, and a Build Tab. 

Platform Selection allows players to choose a soapbox platform, with simple click buttons. 
Base Selection allows players to choose a base, with simple click buttons. 
The Build Tab allows players to drag and drop parts from the Parts Palette onto mounting points on the vehicle. Any part can be dropped onto any mounting part for a little bit of fun and chaos. 

The Build Preview also updates a live rotating soapbox view so players can see what their soapbox will look like. 
________________________________________
5. OBSTACLE SYSTEM
The obstacle system randomly spawns different objects of different shapes and sizes in the Arena to add for some fun. It is always random, and tries to avoid spawning objects on the player, although will sometimes spawn objects on the AI enemy. 
________________________________________
6. AI SYSTEM
The AI is currently only spawnable in the Arena. 

It’s a quite dumb, but it will try and hunt down the player. It will always use a 4-wheel platform, but will copy the build of the player no matter what platform they use. 

It is also programmed to shoot missiles, but it just fires them randomly. 
There is also a bug that the AI will fire a missile when the player fires a missile, this is probably because the AI was originally built on the players original code, so there’s probably some player code still hanging out in there. 
________________________________________
7. VEHICLE FEEL, BALANCE & FEATURES
Vehicle Speed/Power & Boost: The parts, platform and base selection do play a role on the overall weight of the vehicle at the moment, and this affects both speed and handling. These sorts of details will also affect other things like health, survivability etc in the future once we hone the game a bit more. That means I’ve been playing around with the speed and boost settings a little.

For now 150 on the speed feels decent-ish, but it could go a little higher, especially when the parts get loaded on. I have made the boost 170. This may sound small on paper, but in gameplay it feels like the boost gives the soapbox just enough speed to get you over the hill. Kind of like I peddled real quickly for a bit to get over the jump, then it’s back to gravity taking the wheel (sort of). 

Missile System: BigMacDaddy added missiles in his build, I took those missles, changed the firing button from “M” to “F”, adjusted the timing a little so the missiles don’t collide on themselves or the soapbox they are launched from and this feels pretty good for now. They still need to be tweaked and we could add some sort of aiming system. 
________________________________________
BUGS —
HIGH PRIORITY
1. AI Missile Sync Bug
•	AI fires when player fires 
________________________________________
MEDIUM PRIORITY
1.  Nurburger Ring Generation
•	the track kind of generates a little in the ground and it’s a bit all over the place, bit it works. 
LOW PRIORITY
xxx
________________________________________
OTHER UPDATES —
1. Added comments to all the scripts to try and keep things as understandable as possible. (The comments were added by AI. Yes, I was too lazy to do it myself. Yes, I use AI to assist. Shhh.)
2. Probably some other things I’ve forgotten. 
________________________________________
DESIGN DIRECTION —
Remember we are trying to make an arcade physics racer that’s fun to play and feels a little bit silly. We will constantly need to tweak break points and vehicle speeds and features to keep it exciting.
________________________________________
ROADMAP —
PHASE 1: CORE FEEL
1.	Keep working on the joints system
2.	Force scaling (engine vs mass) 
3.	Fix AI firing bug
PHASE 2: BUILD DEPTH
4.	Part-to-part joints 
5.	Health/Survivability Stats
6.	AI in Track Races
7.	Better AI
PHASE 3: GAMEPLAY LOOP
8.	Scoring system 
9.	Objectives (arena mode) 
PHASE 4: POLISH / CHAOS
10.	Wheel damage affecting steering 
11.	Replay system 
12.	Slow-motion crashes 
13.	Cinematic camera moments 
14.	Actual artwork?
________________________________________
