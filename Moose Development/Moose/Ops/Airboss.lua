--- **Ops** - (R2.5) - Manages aircraft operations on carriers.
-- 
-- The AIRBOSS class manages recoveries of human pilots and AI aircraft on aircraft carriers.
--
-- **Main Features:**
--
--    * CASE I, II and III recoveries.
--    * Supports human pilots as well as AI flight groups.
--    * Automatic LSO grading.
--    * Different skill levels from on-the-fly tips for flight students to ziplip for pros.
--    * Define recovery time windows with individual recovery cases.
--    * Automatic TACAN and ICLS channel setting of carrier.
--    * Separate radio channels for LSO and Marshal transmissions.
--    * Voice over support for LSO and Marshal radio transmissions.
--    * F10 radio menu including carrier info (weather, radio frequencies, TACAN/ICLS channels), player LSO grades,
--    help function (player aircraft attitude, marking of pattern zones etc).
--    * Recovery tanker and refueling option via integration of @{#Ops.RecoveryTanker} class.
--    * Rescue helo option via @{#Ops.RescueHelo} class.
--    * Many parameters customizable by convenient user API functions. 
--    * Multiple carrier support due to object oriented approach.
--    * Finite State Machine (FSM) implementation.
-- 
-- Supported Carriers:
-- 
--    * USS John C. Stennis
--    
-- Supported Player and AI Aircraft:
-- 
--    * F/A-18C Hornet Lot 20 (player+AI)
--    * A-4E-C Skyhawk Community Mod (player+AI)
--    * F/A-18C Hornet (AI)
--    * F-14A Tomcat (AI)
--    * E-2D Hawkeye (AI)
--    * S-3B Viking & tanker version (AI)
-- 
-- At the moment, optimized parameters are available for the F/A-18C Hornet (Lot 20) as aircraft and the USS John C. Stennis as carrier.
-- The community A-4E mod is also supported in priciple but may needs further tweaking of parameters such as on speed AoA values.
-- 
-- The implemenation is kept very general. So other including other aircraft and carriers in future is possible. (*Winter is coming!*)
-- But each aircraft or carrier needs a different set of optimized individual parameters. 
--
-- **PLEASE NOTE** that his class is work in progress and in an **alpha** stage and very much **work in progress**.
-- Your constructive feedback is both necessary and highly appreciated.
--
-- ===
--
-- ### Author: **funkyfranky**
-- ### Special thanks to
-- **Bankler** for his great [Recovery Trainer](https://forums.eagle.ru/showthread.php?t=221412) mission and script!
-- His work was the initial inspiration for this class. Also note that this class uses some routines for determining the player position in Case I recoveries developed by Bankler.
--
-- @module Ops.Airboss
-- @image MOOSE.JPG

--- AIRBOSS class.
-- @type AIRBOSS
-- @field #string ClassName Name of the class.
-- @field #boolean Debug Debug mode. Messages to all about status.
-- @field #string lid Class id string for output to DCS log file.
-- @field Wrapper.Unit#UNIT carrier Aircraft carrier unit on which we want to practice.
-- @field #string carriertype Type name of aircraft carrier.
-- @field #AIRBOSS.CarrierParameters carrierparam Carrier specifc parameters.
-- @field #string alias Alias of the carrier.
-- @field Wrapper.Airbase#AIRBASE airbase Carrier airbase object.
-- @field #table waypoints Waypoint coordinates of carrier.
-- @field #number currentwp Current waypoint, i.e. the one that has been passed last.
-- @field Core.Radio#BEACON beacon Carrier beacon for TACAN and ICLS.
-- @field #boolean TACANon Automatic TACAN is activated.
-- @field #number TACANchannel TACAN channel.
-- @field #string TACANmode TACAN mode, i.e. "X" or "Y".
-- @field #string TACANmorse TACAN morse code, e.g. "STN".
-- @field #boolean ICLSon Automatic ICLS is activated.
-- @field #number ICLSchannel ICLS channel.
-- @field #string ICLSmorse ICLS morse code, e.g. "STN".
-- @field Core.Radio#RADIO LSORadio Radio for LSO calls.
-- @field #number LSOFreq LSO radio frequency in MHz.
-- @field #string LSOModu LSO radio modulation "AM" or "FM".
-- @field Core.Radio#RADIO MarshalRadio Radio for carrier calls.
-- @field #number MarshalFreq Marshal radio frequency in MHz.
-- @field #string MarshalModu Marshal radio modulation "AM" or "FM".
-- @field Core.Scheduler#SCHEDULER radiotimer Radio queue scheduler.
-- @field Core.Zone#ZONE_UNIT zoneCCA Carrier controlled area (CCA), i.e. a zone of 50 NM radius around the carrier.
-- @field Core.Zone#ZONE_UNIT zoneCCZ Carrier controlled zone (CCZ), i.e. a zone of 5 NM radius around the carrier.
-- @field Core.Zone#ZONE_UNIT zoneInitial Zone usually 3 NM astern of carrier where pilots start their CASE I pattern.
-- @field #table players Table of players. 
-- @field #table menuadded Table of units where the F10 radio menu was added.
-- @field #AIRBOSS.Checkpoint BreakEntry Break entry checkpoint.
-- @field #AIRBOSS.Checkpoint BreakEarly Early break checkpoint.
-- @field #AIRBOSS.Checkpoint BreakLate Late brak checkpoint.
-- @field #AIRBOSS.Checkpoint Abeam Abeam checkpoint.
-- @field #AIRBOSS.Checkpoint Ninety At the ninety checkpoint.
-- @field #AIRBOSS.Checkpoint Wake Checkpoint right behind the carrier.
-- @field #AIRBOSS.Checkpoint Final Checkpoint when turning to final.
-- @field #AIRBOSS.Checkpoint Groove In the groove checkpoint.
-- @field #AIRBOSS.Checkpoint Platform Case II/III descent at 2000 ft/min at 5000 ft platform.
-- @field #AIRBOSS.Checkpoint DirtyUp Case II/III dirty up and on speed position at 1200 ft and 10-12 NM from the carrier.
-- @field #AIRBOSS.Checkpoint Bullseye Case III intercept glideslope and follow ICLS aka "bullseye".
-- @field #number defaultcase Default recovery case. This is the case used if not specified otherwise.
-- @field #number case Recovery case I, II or III currently in progress.
-- @field #table recoverytimes List of time windows when aircraft are recovered including the recovery case and holding offset.
-- @field #number defaultoffset Default holding pattern update if not specified otherwise.
-- @field #number holdingoffset Offset [degrees] of Case II/III holding pattern.
-- @field #table flights List of all flights in the CCA.
-- @field #table Qmarshal Queue of marshalling aircraft groups.
-- @field #table Qpattern Queue of aircraft groups in the landing pattern.
-- @field #table RQMarshal Radio queue of marshal.
-- @field #table RQLSO Radio queue of LSO.
-- @field #number Nmaxpattern Max number of aircraft in landing pattern.
-- @field #boolean handleai If true (default), handle AI aircraft.
-- @field Ops.RecoveryTanker#RECOVERYTANKER tanker Recovery tanker flying overhead of carrier.
-- @field Functional.Warehouse#WAREHOUSE warehouse Warehouse object of the carrier.
-- @field DCS#Vec3 Corientation Carrier orientation in space.
-- @field DCS#Vec3 Corientlast Last known carrier orientation.
-- @field Core.Point#COORDINATE Cposition Carrier position.
-- @field #string defaultskill Default player skill @{#AIRBOSS.Difficulty}.
-- @extends Core.Fsm#FSM

--- The boss!
--
-- ===
--
-- ![Banner Image](..\Presentations\AIRBOSS\Airboss_Main.jpg)
--
-- # The AIRBOSS Concept
--
-- On a carrier, the AIRBOSS is guy who is really in charge - don't mess with him!
-- 
-- # Recovery Cases
-- 
-- The AIRBOSS class supports all three commonly used recovery cases, i.e.
-- 
--    * **CASE I** during daytime and good weather, 
--    * **CASE II** during daytime with poor visibility conditions,
--    * **CASE III** during nighttime recoveries.
--    
-- That being said, this script allows you to use any of the three cases to be used at any time. Or, in other words, *you* need to specify when which case is safe and appropriate.
-- 
-- This is a lot of responsability. *You* are the boss, but *you* need to make the right decisions or things will go terribly wrong!
-- 
-- Recovery windows can be set up via the @{#AIRBOSS.AddRecoveryWindow} function as explained below. With this it is possible to seamlessly switch recovery cases even in the same mission.
--     
-- ## CASE I
-- 
-- As mentioned before, Case I recovery is the standard procedure during daytime and good visibility conditions.
-- 
-- ### Holding Pattern
--  
-- ![Banner Image](..\Presentations\AIRBOSS\Airboss_Case1_Holding.png)
-- 
-- The graphic depicts a the standard holding pattern during a Case I recovery. Incoming aircraft enter the holding pattern, which is a counter clockwise turn with a
-- diameter of 5 NM, at their assigned altiude. The holding altitude of the first stack is 2000 ft. The inverval between stacks is 1000 ft.
-- 
-- Once a recovery window opens, the aircraft of the lowest stack commence their landing approach and the rest of the Marshal stack collapses, i.e. aircraft switch from
-- their current stack to the next lower stack.
-- 
-- The flight that transitions form the holding pattern to the landing approach, it should leave the Marshal stack at the 3 position and make a left hand turn to the *Initial*
-- position, which is 3 NM astern of the boat.
-- 
-- ### Landing Pattern
-- 
-- ![Banner Image](..\Presentations\AIRBOSS\Airboss_Case1_Landing.png)
-- 
-- Once the aircraft reaches the Inital, the landing pattern begins. The important steps of the pattern are shown in the image above.
-- 
-- ## CASE III
-- 
-- ![Banner Image](..\Presentations\AIRBOSS\Airboss_Case3.png)
-- 
-- A Case III recovery is conducted during nighttime. The holding positon and the landing pattern are rather different from a Case I recovery as can be seen in the image above.
-- 
-- The first holding zone starts 21 NM astern the carrier at angels 6. The interval between the stacks is 1000 ft just like in Case I. However, the distance to the boat
-- increases by 1 NM with each stack. The general form can be written as D=15+6+(N-1), where D is the distance to the boat in NM and N the number of the stack starting at N=1.
-- 
-- Once the aircraft of the lowest stack is allowed to commence to the landing pattern, it starts a descent at 4000 ft/min until it reaches the "*Platform*" at 5000 ft and
-- ~19 NM DME. From there a shallower descent at 2000 ft/min should be performed. At an altitude of 1200 ft the aircraft should level out and "*Dirty Up*" (gear & hook down).
-- 
-- At 3 NM distance to the carrier, the aircraft should intercept the 3.5 degrees glide slope at the "*Bullseye*". From there the pilot should "follow the needes" of the ICLS. 
-- 
-- ## CASE II
-- 
-- ![Banner Image](..\Presentations\AIRBOSS\Airboss_Case2.png)
-- 
-- Case II is the common recovery procedure at daytime if visibilty conditions are poor. It can be viewed as hybrid between Case I and III.
-- The holding pattern is very similar to that of the Case III recovery with the difference the the radial is the inverse of the BRC instead of the FB.
-- From the holding zone aircraft are follow the Case III path until they reach the Initial position 3 NM astern the boat. From there a standard Case I recovery procedure is
-- in place.
-- 
-- Note that the image depicts the case, where the holding zone has an angle offset of 30 degrees with respect to the BRC. This is optional. Commonly used offset angles
-- are 0 (no offset), +-15 or +-30 degrees. The AIRBOSS class supports all these scenarios which are used during Case II and III recoveries.
-- 
-- 
-- # Scripting
-- 
-- Writing a basic script is easy and can be done in two lines.
-- 
--     local airbossStennis=AIRBOSS:New("USS Stennis", "Stennis")
--     airbossStennis:Start()
--     
-- The first line creates and AIRBOSS object via the @{#AIRBOSS.New}(*carriername*, *alias*) constructor. The first parameter *carriername* is name of the carrier unit as
-- defined in the mission editor. The second parameter *alias* is optional. This name will, e.g., be used for the F10 radio menu entry. If not given, the alias is identical
-- to the carriername of the first parameter.
-- 
-- This simple script initializes a lot of parameters with default values:
-- 
--    * TACAN channel is set to 74X, see @{#AIRBOSS.SetTACAN}
--    * ICSL channel is set to 1, see @{#AIRBOSS.SetICLS}
--    * LSO radio is set to 264 MHz FM, see @{#AIRBOSS.SetLSORadio}
--    * Marshal radio is set to 305 MHz FM, see @{#AIRBOSS.SetMarshalRadio}
--    * Default recovery case is set to 1, see @{#AIRBOSS.SetRecoveryCase}
--
-- ## Recovery Windows
-- 
-- Recovery of aircraft is only allowed during defined time slots. You can define these slots via the @{#AIRBOSS.AddRecoveryWindow}(*start*, *stop*, *case*, *holdingoffset*) function.
-- The parameters are:
-- 
--   * *start*: The start time as a string. For example "8:00" for a window opening at 8 am. Or "13:30+1" for half past one on the next day. Default (nil) is ASAP.
--   * *stop*: Time when the window closes as a string. Same format as *start*. Default is 90 minutes after start time.
--   * *case*: The recovery case during that window (1, 2 or 3). Default 1.
--   * *holdingoffset*: Holding offset angle in degrees. Only for Case II or III recoveries. Default 0 deg. Common +-15 deg or +-30 deg.
--   
-- If recovery is closed, AI flights will be send to marshal stacks and orbit there until the next window opens.
-- Players can request marshal via the F10 menu and will also be given a marshal stack. Currently, human players can request commence via the F10 radio regarless of
-- whether a window is open or not and will be alowed to enter the pattern (if not already full). This will probably change in the future.
-- 
-- At the moment there is no autmatic recovery case set depending on weather or daytime. So it is the AIRBOSS (you) who needs to make that descision.
-- It is probably a good idea to synchronize the timing with the waypoints of the carrier. For example, setting up the waypoints such that the carrier
-- already has turning into the wind, when a recovery window opens.
-- 
-- The code for setting up multiple recovery windows could look like this
--     local airbossStennis=AIRBOSS:New("USS Stennis", "Stennis")
--     airbossStennis:AddRecoveryWindow("8:30", "9:30", 1)
--     airbossStennis:AddRecoveryWindow("12:00", "13:15", 2, 15)
--     airbossStennis:AddRecoveryWindow("23:30", "00:30+1", 3, -30)
--     airbossStennis:Start()
--   
-- This will open a Case I recovery window from 8:30 to 9:30. Then a Case II recovery from 12:00 to 13:15, where the holing offset is +15 degrees wrt BRC.
-- Finally, a Case III window opens 23:30 on the day the mission starts and closes 0:30 on the following day. The holding offset is -30 degrees wrt FB.
-- 
-- Note that incoming flights will be assigned a holding pattern for the next opening window case if no window is open at the moment. So in the above example,
-- all flights incoming after 13:15 will be assigned to a Case III marshal stack. Therefore, you should make sure that no flights are incoming long before the
-- next window opens or adjust the recovery planning accordingly.
-- 
-- # The F10 Radio Menu
-- 
-- The F10 radio menu can be used to post requests to Marshal but also provides information about the player and carrier status. Additionally, helper functions
-- can be called.
-- 
-- ## Main Menu
-- 
-- The general structure
-- 
--    * **F1 Help...**: Help submenu, see below.
--    * **F2 Kneeboard...**: Kneeboard submenu, see below. Carrier information, weather report, player status.
--    * **F3 Request Marshal**
--    * **F4 Request Commence**
--    * **F5 Request Refueling**
-- 
-- ### Request Marshal
-- 
-- This radio command can be used to request a stack in the holding pattern from Marshal. Necessary conditions are that the flight is inside the CCZ.
-- Marshal will assign an individual stack for each player group depending on the current or next open recovery case window.
-- If multiple players have registered as a section, the section lead will be assigned a stack and is responsible to guide his section to the assigned holding position.
-- 
-- ### Request Commence
-- 
-- This command can be used to request commencing from the marshal stack to the landing pattern. Necessary condition is that the player is in the lowest marshal stack
-- and that the number of aircraft in the landing pattern is smaller than four.
-- 
-- A player can also request commencing if he is not registered in a marshal stack yet. If the pattern is free, Marshal will allow him to directly enter the landing pattern.
-- 
-- ### Request Refueling
-- 
-- If a recovery tanker was setup via the @{#AIRBOSS.SetRecoveryTanker} function, the player can request refueling. If the tanker is ready, refueling is granted and the player
-- can leave the marshal stack for refueling. The stack will collapse and the player needs to request marshal again, when refueling is finished.
-- 
-- ## Help Menu
-- 
-- This menu provides commands to help the player. 
-- 
-- ### Skill Level Submenu
-- 
-- The player can choose between three skill or difficulty levels.
-- 
--    * **Flight Student**: The player receives tips at certain stages of the pattern, e.g. if he is at the right altitude, speed, etc.
--    * **Naval Aviator**: Less tips are show. Player should be familiar with the procedures and its aircraft parameters. 
--    * **TOPGUN Graduate**: Only very few information is provided to the player. This is for pros.
--    
-- ### Mark Zones Submenu
-- 
-- These commands can be used to mark marshal or landing pattern zones.
-- 
--    * **Smoke My Marshal Zone** This smokes the the surrounding area of the currently assigned marshal zone of the player. Player has to be registered for marshal.
--    * **Flare My Marshal Zone** Similar to smoke but uses flares to mark the marshal zone.
--    * **Smoke Pattern Zones** Smoke is used to mark the landing pattern zone of the player depending on his recovery case.
--    For Case I this is the initial zone. For Case II/III and three these are the Platform, Arc turn, Dirty Up, Bullseye/Initial zones as well as the approach corridor.
--    * **Flare Pattern Zones** Similar to smoke but uses flares to mark the pattern zones.
--    
-- ### My Status
-- 
-- This command provides information about the current player status. For example, his current step in the pattern.
-- 
-- ### Attitude Monitor
-- 
-- This command displays the current aircraft attitude of the player in short intervals as message on the screen.
-- It provides information about current pitch, roll, yaw, lineup and glideslope error, orientation of the plane wrt to carrier etc.
-- 
-- ### LSO Radio Check
-- 
-- LSO will transmit a short message on his radio frequency. See @{#AIRBOSS.SetLSORadio}.
-- 
-- ### Marshal Radio Check
-- 
-- Marshal will transmit a short message on his radio frequency. See @{#AIRBOSS.SetMarshalRadio}.
-- 
-- ### [Reset My Status]
-- 
-- This will reset the current player status. If player is currently in a marshal stack, he will be removed from the marshal queue and the stack will collapse.
-- The player needs to re-register later if desired. If player is currently in the landing pattern, he will be removed from the pattern queue.
-- 
-- ## Kneeboard Menu
-- 
-- The Kneeboard menu provides information about the carrier, weather and player results.
-- 
-- ### Results Submenu
-- 
-- Here you find your LSO grading results as well as scores of other players.
-- 
--    * **Greenie Board** lists average scores of all players obtained during landing approaches.
--    * **My LSO Grades** lists all grades the player has received for his approaches in this mission.
--    * **Last Debrief** shows the detailed debriefing of the player's last approach. 
-- 
-- ### Carrier Info
-- 
-- Information about the current carrier status is displayed. This includes current BRC, FB, LSO and Marshal frequences, list of next recovery windows.
-- 
-- ### Weather Report
-- 
-- Displays information about the current weather at the carrier such as QFE, wind and temperature.
-- 
-- ### Set Section
-- 
-- With this command, you can define a section of human flights. The player how issues the command becomes the section lead and all other human players
-- within a radius of 200 meters become members of the section.
-- 
-- # Landing Signal Officer (LSO)
-- 
-- The LSO will first contact you on his radio channel when you are at the the abeam position (Case I) with the phrase "Paddles, contact.".
-- Once you are in the groove the LSO will ask you to "Call the ball." and then acknoledge your ball call by "Roger Ball."
-- 
-- During the groove the LSO will give you advice if you deviate from the correct landing path. These advices will be given when you are
-- 
--    * too low or too high with respect to the glideslope, 
--    * too fast or too slow with respect to the optimal AoA,
--    * too far left or too far right wirth respect to the lineup of the (angled) runway.
-- 
-- ## LSO Grading
-- 
-- LSO grading starts when the player enters the groove. The flight path and aircraft attitude is evaluated at certain steps
-- 
--    * **X** At the Start
--    * **IM** In the Middle
--    * **IC** In Close
--    * **AR** At the Ramp
--    * **IW** In the Wiress
--    
-- Grading at each step includes the above calls, i.e.
--
--    * Linup: (LUL), LUL, _LUL_, (RUL), RUL, \_RUL\_
--    * Alitude: (H), H, _H_, (L), L, \_L\_
--    * Speed: (F), F, _F_, (SLO), SLO, \_SLO\_
--    
-- The position at the landing event is analyzed and the corresponding trapped wire calculated. If no wire was caught, the LSO will give the bolter call.
-- 
-- If a player is sigifiantly off from the ideal parameters in close or at the ramp, the LSO will wave the player off.
-- 
-- ## Pattern Wave Off
-- 
-- The player's aircraft position is evaluated at certain critical locations in the landing pattern. If the player is far off from the ideal approach, the LSO will
-- issue a pattern wave off. Currently, this is only implemented for Case I recoveries and the Case I part in the Case II recovery, i.e.
-- 
--    * Break Entry
--    * Early Break
--    * Late Break
--    * Abeam
--    * Ninety
--    * Wake
--    * Groove
--    
-- At these points it is also checked if a player comes too close to another aircraft ahead of him in the pattern.
-- 
-- # AI Handling
-- 
-- The implementation allows to handle incoming AI units and integrate them into the marshal and landing pattern.
-- 
-- By default, incoming carrier capable aircraft which are detecting inside the CCZ and approach the carrier by more than 5 NM are automatically guided to the holding zone.
-- Each AI group gets its own marshal stack in the holding pattern. Once a recovery window opens, the AI group of the lowest stack is transitioning to the landing pattern
-- and the Marshal stack collapses.
-- 
-- If no AI handling is desired, this can be turned off via the @{#AIRBOSS.SetHandleAIOFF} function.
-- 
-- ## Known Issues
-- 
-- The holding position of the AI is updated regularly when the carrier has changed its position by more then 2.5 NM or changed its course significantly.
-- The patterns are realized by orbit or racetrack patterns of the DCS scripting API.
-- However, when the position is updated or the marshal stack collapses, it comes to disruptions of the regular orbit becase a new waypoint with a new 
-- orbit task needs to be created.
-- 
-- # Debugging
-- 
-- In case you have problems, it is always a good idea to have a look at your DCS log file. You find it in your "Saved Games" folder, so for example in
--     C:\Users\<yourname>\Saved Games\DCS\Logs\dcs.log
-- All output concerning the @{#AIRBOSS} class should have the string "AIRBOSS" in the corresponding line.
-- Searching for lines that contain the string "error" or "nil" can also give you a hint what's wrong.
-- 
-- The verbosity of the output can be increased by adding the following lines to your script:
-- 
--     BASE:TraceOnOff(true)
--     BASE:TraceLevel(1)
--     BASE:TraceClass("AIRBOSS")
-- 
-- To get even more output you can increase the trace level to 2 or even 3, c.f. @{Core.Base#BASE} for more details.
-- 
-- ## Debug Mode
-- 
-- You have the option to enable the debug mode for this class via the @{#AIRBOSS.SetDebugModeON} function.
-- If enabled, status and debug text messages will be displayed on the screen. Also informative marks on the F10 map are created.
--
-- @field #AIRBOSS
AIRBOSS = {
  ClassName     = "AIRBOSS",
  Debug         = true,
  lid           = nil,
  carrier       = nil,
  carriertype   = nil,
  carrierparam  =  {},
  alias         = nil,
  airbase       = nil,
  waypoints     =  {},
  currentwp     = nil,
  beacon        = nil,
  TACANon       = nil,
  TACANchannel  = nil,
  TACANmode     = nil,
  TACANmorse    = nil,
  ICLSon        = nil,
  ICLSchannel   = nil,
  ICLSmorse     = nil,
  LSORadio      = nil,
  LSOFreq       = nil,
  LSOModu       = nil,
  MarshalRadio  = nil,
  MarshalFreq   = nil,
  MarshalModu   = nil,
  radiotimer    = nil,
  zoneCCA       = nil,
  zoneCCZ       = nil,
  zoneInitial   = nil,
  players       =  {},
  menuadded     =  {},
  BreakEntry    =  {},
  BreakEarly    =  {},
  BreakLate     =  {},
  Abeam         =  {},  
  Ninety        =  {},
  Wake          =  {},
  Final         =  {},  
  Groove        =  {},
  Platform      =  {},
  DirtyUp       =  {},
  Bullseye      =  {},
  defaultcase   = nil,
  case          = nil,
  defaultoffset = nil,
  holdingoffset = nil,  
  recoverytimes =  {},
  flights       =  {},
  Qpattern      =  {},
  Qmarshal      =  {},
  RQMarshal     =  {},
  RQLSO         =  {},
  Nmaxpattern   = nil,
  handleai      = nil,
  tanker        = nil,
  warehouse     = nil,
  Corientation  = nil,
  Corientlast   = nil,
  Cposition     = nil,
  defaultskill  = nil,
}

--- Player aircraft types capable of landing on carriers.
-- @type AIRBOSS.AircraftPlayer
-- @field #string AV8B AV-8B Night Harrier (not yet supported).
-- @field #string HORNET F/A-18C Lot 20 Hornet.
-- @field #string A4EC Community A-4E-C mod.
AIRBOSS.AircraftPlayer={
  --AV8B="AV8BNA",
  HORNET="FA-18C_hornet",
  A4EC="A-4E-C",
}

--- Aircraft types capable of landing on carrier (human+AI).
-- @type AIRBOSS.AircraftCarrier
-- @field #string AV8B AV-8B Night Harrier (not yet supported).
-- @field #string HORNET F/A-18C Lot 20 Hornet.
-- @field #string A4EC Community A-4E mod.
-- @field #string S3B Lockheed S-3B Viking.
-- @field #string S3BTANKER Lockheed S-3B Viking tanker.
-- @field #string E2D Grumman E-2D Hawkeye AWACS.
-- @field #string FA18C F/A-18C Hornet (AI).
-- @field #string F14A F-14A Tomcat (AI).
AIRBOSS.AircraftCarrier={
  --AV8B="AV8BNA",
  HORNET="FA-18C_hornet",
  A4EC="A-4E-C",
  S3B="S-3B",
  S3BTANKER="S-3B Tanker",
  E2D="E-2C",
  FA18C="F/A-18C",
  F14A="F-14A",
}

--- Carrier types.
-- @type AIRBOSS.CarrierType
-- @field #string STENNIS USS John C. Stennis (CVN-74)
-- @field #string VINSON USS Carl Vinson (CVN-70)
-- @field #string TARAWA USS Tarawa (LHA-1)
-- @field #string KUZNETSOV Admiral Kuznetsov (CV 1143.5)
AIRBOSS.CarrierType={
  STENNIS="Stennis",
  VINSON="Vinson",
  TARAWA="LHA_Tarawa",
  KUZNETSOV="KUZNECOW",
}

--- Carrier specific parameters.
-- @type AIRBOSS.CarrierParameters
-- @field #number rwyangle Runway angle in degrees. for carriers with angled deck. For USS Stennis -9 degrees.
-- @field #number sterndist Distance in meters from carrier position to stern of carrier. For USS Stennis -150 meters.
-- @field #number deckheight Height of deck in meters. For USS Stennis ~22 meters.
-- @field #number wire1 Distance in meters from carrier position to first wire.
-- @field #number wire2 Distance in meters from carrier position to second wire.
-- @field #number wire3 Distance in meters from carrier position to third wire.
-- @field #number wire4 Distance in meters from carrier position to fourth wire.
-- @field #number wireoffset Offset in meters for wire calculation.

--- Aircraft specific Angle of Attack (AoA) (or alpha) parameters.
-- @type AIRBOSS.AircraftAoA
-- @field #number OnSpeedMin Minimum on speed AoA. Values below are fast
-- @field #number OnSpeedMax Maximum on speed AoA. Values above are slow.
-- @field #number OnSpeed Optimal on-speed AoA.
-- @field #number Fast Fast AoA threshold. Smaller means faster.
-- @field #number Slow Slow AoA threshold. Larger means slower.
-- @field #number FAST Really fast AoA threshold.
-- @field #number SLOW Really slow AoA threshold.

--- Pattern steps.
-- @type AIRBOSS.PatternStep
AIRBOSS.PatternStep={
  UNDEFINED="Undefined",
  REFUELING="Refueling",
  SPINNING="Spinning",
  COMMENCING="Commencing",
  HOLDING="Holding",
  PLATFORM="Platform",
  ARCIN="Arc Turn In",
  ARCOUT="Arc Turn Out",
  DIRTYUP="Dirty Up",
  BULLSEYE="Bullseye",
  INITIAL="Initial",
  BREAKENTRY="Break Entry",
  EARLYBREAK="Early Break",
  LATEBREAK="Late Break",
  ABEAM="Abeam",
  NINETY="Ninety",
  WAKE="Wake",
  FINAL="Turn Final",
  GROOVE_XX="Groove X",
  GROOVE_RB="Groove Roger Ball",
  GROOVE_IM="Groove In the Middle",
  GROOVE_IC="Groove In Close",
  GROOVE_AR="Groove At the Ramp",
  GROOVE_IW="Groove In the Wires",
  DEBRIEF="Debrief",
}

--- Radio sound file and subtitle.
-- @type AIRBOSS.RadioCall
-- @field #string file Sound file name without suffix.
-- @field #string suffix File suffix/extention, e.g. "ogg".
-- @field #boolean loud Loud version of sound file available.
-- @field #string subtitle Subtitle displayed during transmission.
-- @field #number duration Duration of the sound in seconds. This is also the duration the subtitle is displayed.

--- LSO radio calls.
-- @type AIRBOSS.LSOCall
-- @field #AIRBOSS.RadioCall RADIOCHECK "Paddles, radio check" call.
-- @field #AIRBOSS.RadioCall RIGHTFORLINEUP "Right for line up" call.
-- @field #AIRBOSS.RadioCall COMELEFT "Come left" call.
-- @field #AIRBOSS.RadioCall HIGH "You're high" call.
-- @field #AIRBOSS.RadioCall LOW "You're low" call.
-- @field #AIRBOSS.RadioCall POWER "Power" call.
-- @field #AIRBOSS.RadioCall FAST "You're fast" call.
-- @field #AIRBOSS.RadioCall SLOW "You're slow" call.
-- @field #AIRBOSS.RadioCall PADDLESCONTACT "Paddles, contact" call.
-- @field #AIRBOSS.RadioCall CALLTHEBALL "Call the Ball" 
-- @field #AIRBOSS.RadioCall ROGERBALL "Roger ball" call.
-- @field #AIRBOSS.RadioCall WAVEOFF "Wave off" call
-- @field #AIRBOSS.RadioCall BOLTER "Bolter, Bolter" call
-- @field #AIRBOSS.RadioCall LONGINGROOVE "You're long in the groove. Depart and re-enter." call.
-- @field #AIRBOSS.RadioCall DEPARTANDREENTER "Depart and re-enter" call.
-- @field #AIRBOSS.RadioCall N0 "Zero" call.
-- @field #AIRBOSS.RadioCall N1 "One" call.
-- @field #AIRBOSS.RadioCall N2 "Two" call.
-- @field #AIRBOSS.RadioCall N3 "Three" call.
-- @field #AIRBOSS.RadioCall N4 "Four" call.
-- @field #AIRBOSS.RadioCall N5 "Five" call.
-- @field #AIRBOSS.RadioCall N6 "Six" call.
-- @field #AIRBOSS.RadioCall N7 "Seven" call.
-- @field #AIRBOSS.RadioCall N8 "Eight" call.
-- @field #AIRBOSS.RadioCall N9 "Nine" call.
AIRBOSS.LSOCall={
  RADIOCHECK={
    file="LSO-RadioCheck",
    suffix="ogg",
    loud=false,
    subtitle="Paddles, radio check",
    duration=1.1,
  },
  RIGHTFORLINEUP={
    file="LSO-RightForLineup",
    suffix="ogg",
    loud=true,
    subtitle="Right for line up",
    duration=0.80,
  },
  COMELEFT={
    file="LSO-ComeLeft",
    suffix="ogg",
    loud=true,
    subtitle="Come left",
    duration=0.60,
  },
  HIGH={
    file="LSO-High",
    suffix="ogg",
    loud=true,
    subtitle="You're high",
    duration=0.65,
  },
  LOW={
    file="LSO-Low",
    suffix="ogg",
    loud=true,
    subtitle="You're low",
    duration=0.50,
  },
  POWER={
    file="LSO-Power",
    suffix="ogg",    
    loud=true,
    subtitle="Power",
    duration=0.50,  --0.45 was too short
  },
  SLOW={
    file="LSO-Slow",
    suffix="ogg",
    loud=true,
    subtitle="You're slow",
    duration=0.65,
  },
  FAST={
    file="LSO-Fast",
    suffix="ogg",
    loud=true,
    subtitle="You're fast",
    duration=0.7,
  },
  CALLTHEBALL={
    file="LSO-CallTheBall",
    suffix="ogg",    
    loud=false,
    subtitle="Call the ball",
    duration=0.6,
  },
  ROGERBALL={
    file="LSO-RogerBall",
    suffix="ogg",    
    loud=false,    
    subtitle="Roger ball",
    duration=0.7,
  },  
  WAVEOFF={
    file="LSO-WaveOff",
    suffix="ogg",
    loud=false,
    subtitle="Wave off",
    duration=0.6,
  },  
  BOLTER={
    file="LSO-BolterBolter",
    suffix="ogg",
    loud=false,
    subtitle="Bolter, Bolter",
    duration=0.75,
  },
  LONGINGROOVE={
    file="LSO-LongInTheGroove",
    suffix="ogg",
    loud=false,
    subtitle="You're long in the groove",
    duration=1.2,
  },
  DEPARTANDREENTER={
    file="LSO-DepartAndReenter",
    suffix="ogg",
    loud=false,
    subtitle="Depart and re-enter",
    duration=1.1,
  },
  PADDLESCONTACT={
    file="LSO-PaddlesContact",
    suffix="ogg",
    loud=false,
    subtitle="Paddles, contact",
    duration=1.0,
  },
  N0={
    file="LSO-N0",
    suffix="ogg",
    loud=false,
    subtitle="",
    duration=0.40,
  },
  N1={
    file="LSO-N1",
    suffix="ogg",
    loud=false,
    subtitle="",
    duration=0.25,
  },
  N2={
    file="LSO-N2",
    suffix="ogg",
    loud=false,
    subtitle="",
    duration=0.37,
  },
  N3={
    file="LSO-N3",
    suffix="ogg",
    loud=false,
    subtitle="",
    duration=0.37,
  },
  N4={
    file="LSO-N4",
    suffix="ogg",
    loud=false,
    subtitle="",
    duration=0.39,
  },
  N5={
    file="LSO-N5",
    suffix="ogg",
    loud=false,
    subtitle="",
    duration=0.38,
  },
  N6={
    file="LSO-N6",
    suffix="ogg",
    loud=false,
    subtitle="",
    duration=0.40,
  },
  N7={
    file="LSO-N7",
    suffix="ogg",
    loud=false,
    subtitle="",
    duration=0.40,
  },
  N8={
    file="LSO-N8",
    suffix="ogg",
    loud=false,
    subtitle="",
    duration=0.37,
  },
  N9={
    file="LSO-N9",
    suffix="ogg",
    loud=false,
    subtitle="",
    duration=0.40,  --0.38 too short
  },
}

--- Marshal radio calls.
-- @type AIRBOSS.MarshalCall
-- @field #AIRBOSS.RadioCall RADIOCHECK "Marshal, radio check" call.
-- @field #AIRBOSS.RadioCall N0 "Zero" call.
-- @field #AIRBOSS.RadioCall N1 "One" call.
-- @field #AIRBOSS.RadioCall N2 "Two" call.
-- @field #AIRBOSS.RadioCall N3 "Three" call.
-- @field #AIRBOSS.RadioCall N4 "Four" call.
-- @field #AIRBOSS.RadioCall N5 "Five" call.
-- @field #AIRBOSS.RadioCall N6 "Six" call.
-- @field #AIRBOSS.RadioCall N7 "Seven" call.
-- @field #AIRBOSS.RadioCall N8 "Eight" call.
-- @field #AIRBOSS.RadioCall N9 "Nine" call.
AIRBOSS.MarshalCall={
  RADIOCHECK={
    file="MARSHAL-RadioCheck",
    suffix="ogg",
    loud=false,
    subtitle="Marshal, radio check",
    duration=1.0,
  },
  -- TODO: Other voice overs for marshal.
  N0={
    file="LSO-N0",
    suffix="ogg",
    loud=false,
    subtitle="",
    duration=0.40,
  },
  N1={
    file="LSO-N1",
    suffix="ogg",
    loud=false,
    subtitle="",
    duration=0.25,
  },
  N2={
    file="LSO-N2",
    suffix="ogg",
    loud=false,
    subtitle="",
    duration=0.37,
  },
  N3={
    file="LSO-N3",
    suffix="ogg",
    loud=false,
    subtitle="",
    duration=0.37,
  },
  N4={
    file="LSO-N4",
    suffix="ogg",
    loud=false,
    subtitle="",
    duration=0.39,
  },
  N5={
    file="LSO-N5",
    suffix="ogg",
    loud=false,
    subtitle="",
    duration=0.38,
  },
  N6={
    file="LSO-N6",
    suffix="ogg",
    loud=false,
    subtitle="",
    duration=0.40,
  },
  N7={
    file="LSO-N7",
    suffix="ogg",
    loud=false,
    subtitle="",
    duration=0.40,
  },
  N8={
    file="LSO-N8",
    suffix="ogg",
    loud=false,
    subtitle="",
    duration=0.37,
  },
  N9={
    file="LSO-N9",
    suffix="ogg",
    loud=false,
    subtitle="",
    duration=0.40,  --0.38 too short
  },
}

--- Difficulty level.
-- @type AIRBOSS.Difficulty
-- @field #string EASY Flight Stutdent. Shows tips and hints in important phases of the approach.
-- @field #string NORMAL Naval aviator. Moderate number of hints but not really zip lip.
-- @field #string HARD TOPGUN graduate. For people who know what they are doing. Nearly ziplip.
AIRBOSS.Difficulty={
  EASY="Flight Student",
  NORMAL="Naval Aviator",
  HARD="TOPGUN Graduate",
}

--- Recovery window parameters.
-- @type AIRBOSS.Recovery
-- @field #number START Start of recovery in seconds of abs mission time.
-- @field #number STOP End of recovery in seconds of abs mission time.
-- @field #number CASE Recovery case (1-3) of that time slot.
-- @field #number OFFSET Angle offset of the holding pattern in degrees. Usually 0, +-15, or +-30 degrees.
-- @field #boolean OPEN Recovery window is currently open.
-- @field #boolean OVER Recovery window is over and closed.

--- Groove position.
-- @type AIRBOSS.GroovePos
-- @field #string X0 Entering the groove.
-- @field #string XX At the start, i.e. 3/4 from the run down.
-- @field #string RB Roger ball.
-- @field #string IM In the middle.
-- @field #string IC In close.
-- @field #string AR At the ramp.
-- @field #string IW In the wires.
AIRBOSS.GroovePos={
  X0="X0",
  XX="X",
  RB="RB",
  IM="IM",
  IC="IC",
  AR="AR",
  IW="IW",
}

--- Groove data.
-- @type AIRBOSS.GrooveData
-- @field #number Step Current step.
-- @field #number AoA Angle of Attack.
-- @field #number Alt Altitude in meters.
-- @field #number GSE Glide slope error in degrees.
-- @field #number LUE Lineup error in degrees.
-- @field #number Roll Roll angle.
-- @field #number Rhdg Relative heading player to carrier. 0=parallel, +-90=perpendicular.
-- @field #number TGroove Time stamp when pilot entered the groove.

--- LSO grade
-- @type AIRBOSS.LSOgrade
-- @field #string grade LSO grade, i.e. _OK_, OK, (OK), --, CUT
-- @field #number points Points received.
-- @field #string details Detailed flight analysis.
-- @field #number wire Wire caught.
-- @field #number Tgroove Time in the groove in seconds.

--- Checkpoint parameters triggering the next step in the pattern.
-- @type AIRBOSS.Checkpoint
-- @field #string name Name of checkpoint.
-- @field #number Xmin Minimum allowed longitual distance to carrier.
-- @field #number Xmax Maximum allowed longitual distance to carrier.
-- @field #number Zmin Minimum allowed latitudal distance to carrier.
-- @field #number Zmax Maximum allowed latitudal distance to carrier.
-- @field #number LimitXmin Latitudal threshold for triggering the next step if X<Xmin.
-- @field #number LimitXmax Latitudal threshold for triggering the next step if X>Xmax.
-- @field #number LimitZmin Latitudal threshold for triggering the next step if Z<Zmin.
-- @field #number LimitZmax Latitudal threshold for triggering the next step if Z>Zmax.

--- Parameters of a flight group.
-- @type AIRBOSS.FlightGroup
-- @field Wrapper.Group#GROUP group Flight group.
-- @field #string groupname Name of the group.
-- @field #number nunits Number of units in group.
-- @field #number dist0 Distance to carrier in meters when the group was first detected inside the CCA.
-- @field #number time Time the flight was added to the queue.
-- @field Core.UserFlag#USERFLAG flag User flag for triggering events for the flight.
-- @field #boolean ai If true, flight is AI.
-- @field #boolean player If true, flight is a human player.
-- @field #string actype Aircraft type name.
-- @field #table onboardnumbers Onboard numbers of aircraft in the group.
-- @field #string onboard Onboard number of player or first unit in group.
-- @field #number case Recovery case of flight.
-- @field #string seclead Name of section lead.
-- @field #table section Other human flight groups belonging to this flight. This flight is the lead.
-- @field #boolean holding If true, flight is in holding zone.
-- @field #boolean ballcall If true, flight called the ball in the groove.
-- @field #table elements Flight group elements.

--- Parameters of an element in a flight group.
-- @type AIRBOSS.FlightElement
-- @field Wrapper.Unit#UNIT unit Aircraft unit.
-- @field #boolean ai If true, AI sits inside. If false, human player is flying.
-- @field #string onboard Onboard number of the aircraft.
-- @field #boolean ballcall If true, flight called the ball in the groove.

--- Player data table holding all important parameters of each player.
-- @type AIRBOSS.PlayerData
-- @field Wrapper.Unit#UNIT unit Aircraft of the player.
-- @field #string name Player name. 
-- @field Wrapper.Client#CLIENT client Client object of player.
-- @field #string callsign Callsign of player.
-- @field #string difficulty Difficulty level.
-- @field #string step Current/next pattern step.
-- @field #boolean warning Set true once the player got a warning.
-- @field #number passes Number of passes.
-- @field #boolean attitudemonitor If true, display aircraft attitude and other parameters constantly.
-- @field #table debrief Debrief analysis of the current step of this pass.
-- @field #table grades LSO grades of player passes.
-- @field #boolean landed If true, player landed or attempted to land.
-- @field #boolean boltered If true, player boltered.
-- @field #boolean waveoff If true, player was waved off during final approach.
-- @field #boolean patternwo If true, player was waved of during the pattern.
-- @field #boolean lig If true, player was long in the groove.
-- @field #number Tlso Last time the LSO gave an advice.
-- @field #number Tgroove Time in the groove in seconds.
-- @field #number wire Wire caught by player when trapped.
-- @field #AIRBOSS.GroovePos groove Data table at each position in the groove. Elemets are of type @{#AIRBOSS.GrooveData}.
-- @field #table menu F10 radio menu
-- @extends #AIRBOSS.FlightGroup

--- Main radio menu.
-- @field #table MenuF10
AIRBOSS.MenuF10={}

--- Airboss class version.
-- @field #string version
AIRBOSS.version="0.5.5"

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- TODO list
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- TODO: 
-- TODO: Subtitles off options on player level.
-- TODO: PWO during case 2/3. Also when too close to other player.
-- TODO: Option to filter AI groups for recovery.
-- TODO: Spin pattern. Add radio menu entry. Not sure what to add though?!
-- TODO: Foul deck check.
-- TODO: Persistence of results.
-- DONE: First send AI to marshal and then allow them into the landing pattern ==> task function when reaching the waypoint.
-- DONE: Extract (static) weather from mission for cloud covery etc.
-- DONE: Check distance to players during approach.
-- DONE: Option to turn AI handling off.
-- DONE: Add user functions.
-- DONE: Update AI holding pattern wrt to moving carrier.
-- DONE: Generalize parameters for other carriers.
-- DONE: Generalize parameters for other aircraft.
-- DONE: Add radio check (LSO, AIRBOSS) to F10 radio menu.
-- DONE: Right pattern step after bolter/wo/patternWO? Guess so.
-- DONE: Set case II and III times (via recovery time).
-- DONE: Get correct wire when trapped. DONE but might need further tweaking.
-- DONE: Add radio transmission queue for LSO and airboss.
-- TONE: CASE II.
-- DONE: CASE III.
-- NOPE: Strike group with helo bringing cargo etc. Not yet.
-- DONE: Handle crash event. Delete A/C from queue, send rescue helo.
-- DONE: Get fuel state in pounds. (working for the hornet, did not check others)
-- DONE: Add aircraft numbers in queue to carrier info F10 radio output.
-- DONE: Monitor holding of players/AI in zoneHolding.
-- DONE: Transmission via radio.
-- DONE: Get board numbers.
-- DONE: Get an _OK_ pass if long in groove. Possible other pattern wave offs as well?!
-- DONE: Add scoring to radio menu.
-- DONE: Optimized debrief.
-- DONE: Add automatic grading.
-- DONE: Fix radio menu.

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constructor
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Create a new AIRBOSS class object for a specific aircraft carrier unit.
-- @param #AIRBOSS self
-- @param carriername Name of the aircraft carrier unit as defined in the mission editor.
-- @param alias (Optional) Alias for the carrier. This will be used for radio messages and the F10 radius menu. Default is the carrier name as defined in the mission editor.
-- @return #AIRBOSS self or nil if carrier unit does not exist.
function AIRBOSS:New(carriername, alias)

  -- Inherit everthing from FSM class.
  local self=BASE:Inherit(self, FSM:New()) -- #AIRBOSS
  
  -- Debug.
  self:F2({carriername=carriername, alias=alias})

  -- Set carrier unit.
  self.carrier=UNIT:FindByName(carriername)
  
  -- Check if carrier unit exists.
  if self.carrier==nil then
    -- Error message.
    local text=string.format("ERROR: Carrier unit %s could not be found! Make sure this UNIT is defined in the mission editor and check the spelling of the unit name carefully.", carriername)
    MESSAGE:New(text, 120):ToAll()
    self:E(text)
    return nil
  end
      
  -- Set some string id for output to DCS.log file.
  self.lid=string.format("AIRBOSS %s | ", carriername)
  
  -- Get carrier type.
  self.carriertype=self.carrier:GetTypeName()
  
  -- Set alias.
  self.alias=alias or carriername
  
  -- Set carrier airbase object.
  self.airbase=AIRBASE:FindByName(carriername)
  
  -- Create carrier beacon.
  self.beacon=BEACON:New(self.carrier)
    
  -- Defaults:

  -- Set up Airboss radio.  
  self.MarshalRadio=RADIO:New(self.carrier)
  self.MarshalRadio:SetAlias("MARSHAL")
  self:SetMarshalRadio()
  
  -- Set up LSO radio.  
  self.LSORadio=RADIO:New(self.carrier)
  self.LSORadio:SetAlias("LSO")
  self:SetLSORadio()
  
  -- Radio scheduler.
  self.radiotimer=SCHEDULER:New()
  
  -- Set ICSL to channel 1.
  self:SetICLS()
  
  -- Set TACAN to channel 74X.
  self:SetTACAN()

  -- Set max aircraft in landing pattern.
  self:SetMaxLandingPattern()
  
  -- Set AI handling On.
  self:SetHandleAION()
  
  -- Default recovery case. This sets self.defaultcase and self.case.
  self:SetRecoveryCase(1)

  -- Set holding offset to 0 degrees. This set self.defaultoffset and self.holdingoffset.
  self:SetHoldingOffsetAngle()
  
  -- Default player skill EASY.
  self:SetDefaultPlayerSkill(AIRBOSS.Difficulty.EASY)
    
  -- CCA 50 NM radius zone around the carrier.
  self:SetCarrierControlledArea()
  
  -- CCZ 5 NM radius zone around the carrier.
  self:SetCarrierControlledZone() 
  
  -- Init carrier parameters.
  if self.carriertype==AIRBOSS.CarrierType.STENNIS then
    self:_InitStennis()
  elseif self.carriertype==AIRBOSS.CarrierType.VINSON then
    -- TODO: Carl Vinson parameters.
    self:_InitStennis()
  elseif self.carriertype==AIRBOSS.CarrierType.TARAWA then
    -- TODO: Tarawa parameters.
    self:_InitStennis()
  elseif self.carriertype==AIRBOSS.CarrierType.KUZNETSOV then
    -- Kusnetsov parameters - maybe...
    self:_InitStennis()
  else
    self:E(self.lid.."ERROR: Unknown carrier type!")
    return nil
  end
  
  -- CASE I/II moving zone: Zone 2.75 NM astern and 0.1 NM starboard of the carrier with a diameter of 1 NM.
  self.zoneInitial=ZONE_UNIT:New("Initial Zone", self.carrier, UTILS.NMToMeters(0.5), {dx=-UTILS.NMToMeters(2.75), dy=UTILS.NMToMeters(0.1), relative_to_unit=true})
    
  -- Smoke zones.
  if self.Debug and false then
    local case=2
    self:_GetZoneBullseye(case):SmokeZone(SMOKECOLOR.White, 45)
    self:_GetZoneDirtyUp(case):SmokeZone(SMOKECOLOR.Orange, 45)
    self:_GetZoneArcIn(case):SmokeZone(SMOKECOLOR.Blue, 45)
    self:_GetZoneArcOut(case):SmokeZone(SMOKECOLOR.Blue, 45)
    self:_GetZonePlatform(case):SmokeZone(SMOKECOLOR.Red, 45)
    self:_GetZoneCorridor(case):SmokeZone(SMOKECOLOR.Green, 45)
  end

  -- If calls should be part of self and individual for different carriers.  
  --[[  
  -- Init default sound files.
  for _name,_sound in pairs(AIRBOSS.LSOCall) do
    local sound=_sound --#AIRBOSS.RadioCall
    local text=string.format()
    sound.subtitle=1
    sound.loud=1
    --self.radiocall[_name]=sound
  end
  ]]
  
  -- Debug:
  if false then
    local text="Playing default sound files:"
    for _name,_call in pairs(AIRBOSS.LSOCall) do
      local call=_call --#AIRBOSS.RadioCall
      
      -- Debug text.
      text=text..string.format("\nFile=%s.%s, duration=%.2f sec, loud=%s, subtitle=\"%s\".", call.file, call.suffix, call.duration, tostring(call.loud), call.subtitle)
      
      -- Radio transmission to queue.
      self:RadioTransmission(self.LSORadio, call, false, 10)
      
      -- Also play the loud version.
      if call.loud then
        self:RadioTransmission(self.LSORadio, call, true, 10)
      end
    end
    self:I(self.lid..text)
  end

  
  -----------------------
  --- FSM Transitions ---
  -----------------------
  
  -- Start State.
  self:SetStartState("Stopped")

  -- Add FSM transitions.
  --                 From State  -->   Event      -->     To State
  self:AddTransition("Stopped",       "Start",           "Idle")        -- Start AIRBOSS script.
  self:AddTransition("*",             "Idle",            "Idle")        -- Carrier is idling.
  self:AddTransition("Idle",          "RecoveryStart",   "Recovering")  -- Start recovering aircraft.
  self:AddTransition("Recovering",    "RecoveryStop",    "Idle")        -- Stop recovering aircraft.
  self:AddTransition("*",             "Status",          "*")           -- Update status of players and queues.
  self:AddTransition("*",             "RecoveryCase",    "*")           -- Switch to another case recovery.
  self:AddTransition("*",             "Stop",            "Stopped")     -- Stop AIRBOSS FMS.


  --- Triggers the FSM event "Start" that starts the airboss. Initializes parameters and starts event handlers.
  -- @function [parent=#AIRBOSS] Start
  -- @param #AIRBOSS self

  --- Triggers the FSM event "Start" that starts the airboss after a delay. Initializes parameters and starts event handlers.
  -- @function [parent=#AIRBOSS] __Start
  -- @param #AIRBOSS self
  -- @param #number delay Delay in seconds.


  --- Triggers the FSM event "Idle" that puts the carrier into state "Idle" where no recoveries are carried out.
  -- @function [parent=#AIRBOSS] Idle
  -- @param #AIRBOSS self

  --- Triggers the FSM delayed event "Idle" that puts the carrier into state "Idle" where no recoveries are carried out.
  -- @function [parent=#AIRBOSS] __Idle
  -- @param #AIRBOSS self
  -- @param #number delay Delay in seconds.


  --- Triggers the FSM event "RecoveryStart" that starts the recovery of aircraft. Marshalling aircraft are send to the landing pattern.
  -- @function [parent=#AIRBOSS] RecoveryStart
  -- @param #AIRBOSS self
  -- @param #number Case Recovery case (1, 2 or 3) that is started.
  -- @param #number Offset Holding pattern offset angle in degrees for CASE II/III recoveries.

  --- Triggers the FSM delayed event "RecoveryStart" that starts the recovery of aircraft. Marshalling aircraft are send to the landing pattern.
  -- @function [parent=#AIRBOSS] __RecoveryStart
  -- @param #number delay Delay in seconds.
  -- @param #AIRBOSS self
  -- @param #number Case Recovery case (1, 2 or 3) that is started.
  -- @param #number Offset Holding pattern offset angle in degrees for CASE II/III recoveries.


  --- Triggers the FSM event "RecoveryStop" that stops the recovery of aircraft.
  -- @function [parent=#AIRBOSS] RecoveryStop
  -- @param #AIRBOSS self

  --- Triggers the FSM delayed event "RecoveryStop" that stops the recovery of aircraft.
  -- @function [parent=#AIRBOSS] __RecoveryStop
  -- @param #AIRBOSS self
  -- @param #number delay Delay in seconds.


  --- Triggers the FSM event "RecoveryCase" that switches the aircraft recovery case.
  -- @function [parent=#AIRBOSS] RecoveryCase
  -- @param #AIRBOSS self
  -- @param #number Case The new recovery case (1, 2 or 3).
  -- @param #number Offset Holding pattern offset angle in degrees for CASE II/III recoveries.

  --- Triggers the delayed FSM event "RecoveryCase" that sets the used aircraft recovery case.
  -- @function [parent=#AIRBOSS] __Case
  -- @param #AIRBOSS self
  -- @param #number delay Delay in seconds.
  -- @param #number Case The new recovery case (1, 2 or 3).
  -- @param #number Offset Holding pattern offset angle in degrees for CASE II/III recoveries.


  --- Triggers the FSM event "Stop" that stops the airboss. Event handlers are stopped.
  -- @function [parent=#AIRBOSS] Stop
  -- @param #AIRBOSS self

  --- Triggers the FSM event "Stop" that stops the airboss after a delay. Event handlers are stopped.
  -- @function [parent=#AIRBOSS] __Stop
  -- @param #AIRBOSS self
  -- @param #number delay Delay in seconds.
  
  return self
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- USER API Functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Set carrier controlled area (CCA).
-- This is a large zone around the carrier, which is constantly updated wrt the carrier position.
-- @param #AIRBOSS self
-- @param #number radius Radius of zone in nautical miles (NM). Default 50 NM.
-- @return #AIRBOSS self
function AIRBOSS:SetCarrierControlledArea(radius)

  radius=UTILS.NMToMeters(radius or 50)

  self.zoneCCA=ZONE_UNIT:New("Carrier Controlled Area",  self.carrier, radius)

  return self
end

--- Set carrier controlled zone (CCZ).
-- This is a small zone (usually 5 NM radius) around the carrier, which is constantly updated wrt the carrier position.
-- @param #AIRBOSS self
-- @param #number radius Radius of zone in nautical miles (NM). Default 5 NM.
-- @return #AIRBOSS self
function AIRBOSS:SetCarrierControlledZone(radius)

  radius=UTILS.NMToMeters(radius or 5)

  self.zoneCCZ=ZONE_UNIT:New("Carrier Controlled Zone",  self.carrier, radius)

  return self
end

--- Set the default recovery case.
-- @param #AIRBOSS self
-- @param #number case Case of recovery. Either 1, 2 or 3. Default 1.
-- @return #AIRBOSS self
function AIRBOSS:SetRecoveryCase(case)

  -- Set default case or 1.
  self.defaultcase=case or 1
  
  -- Current case init.
  self.case=self.defaultcase
  
  return self
end

--- Set holding pattern offset from final bearing for Case II/III recoveries.
-- Usually, this is +-15 or +-30 degrees. You should not use and offet angle >= 90 degrees, because this will cause a devision by zero in some of the equations used to calculate the approach corridor.
-- So best stick to the defaults up to 30 degrees.
-- @param #AIRBOSS self
-- @param #number offset Offset angle in degrees. Default 0.
-- @return #AIRBOSS self
function AIRBOSS:SetHoldingOffsetAngle(offset)

  -- Set default angle or 0. 
  self.defaultoffset=offset or 0
  
  -- Current offset init.
  self.holdingoffset=self.defaultoffset
  
  return self
end

--- Add aircraft recovery time window and recovery case.
-- @param #AIRBOSS self
-- @param #string starttime Start time, e.g. "8:00" for eight o'clock. Default now.
-- @param #string stoptime Stop time, e.g. "9:00" for nine o'clock. Default 90 minutes after start time.
-- @param #number case Recovery case for that time slot. Number between one and three.
-- @param #number holdingoffset Only for CASE II/III: Angle in degrees the holding pattern is offset.
-- @return #AIRBOSS self
function AIRBOSS:AddRecoveryWindow(starttime, stoptime, case, holdingoffset)

  -- Absolute mission time in seconds.
  local Tnow=timer.getAbsTime()
  
  -- Input or now.
  starttime=starttime or UTILS.SecondsToClock(Tnow)

  -- Set start time.
  local Tstart=UTILS.ClockToSeconds(starttime)
  
  -- Set stop time.
  local Tstop=UTILS.ClockToSeconds(stoptime or Tstart+90*60)
  
  -- Consistancy check for timing.
  if Tstart>Tstop then
    self:E(string.format("ERROR: Recovery stop time %s lies before recovery start time %s! Recovery windows rejected.", UTILS.SecondsToClock(Tstart), UTILS.SecondsToClock(Tstop)))
    return self
  end
  if Tstop<=Tnow then
    self:E(string.format("ERROR: Recovery stop time %s already over. Tnow=%s! Recovery windows rejected.", UTILS.SecondsToClock(Tstop), UTILS.SecondsToClock(Tnow)))
    return self
  end
  
  -- Case or default value.
  case=case or self.defaultcase
  
  -- Holding offset or default value.
  holdingoffset=holdingoffset or self.defaultoffset
  
  -- Offset zero for case I.
  if case==1 then
    holdingoffset=0
  end  
  
  -- Recovery window.
  local recovery={} --#AIRBOSS.Recovery
  recovery.START=Tstart
  recovery.STOP=Tstop
  recovery.CASE=case
  recovery.OFFSET=holdingoffset
  recovery.OPEN=false
  recovery.OVER=false
  
  -- Add to table
  table.insert(self.recoverytimes, recovery)
  
  return self
end

--- Disable automatic TACAN activation
-- @param #AIRBOSS self
-- @return #AIRBOSS self
function AIRBOSS:SetTACANoff()
  self.TACANon=false
end

--- Set TACAN channel of carrier.
-- @param #AIRBOSS self
-- @param #number channel TACAN channel. Default 74.
-- @param #string mode TACAN mode, i.e. "X" or "Y". Default "X".
-- @param #string morsecode Morse code identifier. Three letters, e.g. "STN".
-- @return #AIRBOSS self
function AIRBOSS:SetTACAN(channel, mode, morsecode)

  self.TACANchannel=channel or 74
  self.TACANmode=mode or "X"
  self.TACANmorse=morsecode or "STN"
  self.TACANon=true
  
  return self
end

--- Disable automatic ICLS activation.
-- @param #AIRBOSS self
-- @return #AIRBOSS self
function AIRBOSS:SetICLSoff()
  self.ICLSon=false
end

--- Set ICLS channel of carrier.
-- @param #AIRBOSS self
-- @param #number channel ICLS channel. Default 1.
-- @param #string morsecode Morse code identifier. Three letters, e.g. "STN". Default "STN".
-- @return #AIRBOSS self
function AIRBOSS:SetICLS(channel, morsecode)

  self.ICLSchannel=channel or 1
  self.ICLSmorse=morsecode or "STN"
  self.ICLSon=true

  return self
end


--- Set LSO radio frequency and modulation. Default frequency is 264 MHz AM.
-- @param #AIRBOSS self
-- @param #number frequency Frequency in MHz. Default 264 MHz.
-- @param #string modulation Modulation, i.e. "AM" (default) or "FM". 
-- @return #AIRBOSS self
function AIRBOSS:SetLSORadio(frequency, modulation)

  self.LSOFreq=frequency or 264
  self.LSOModu=modulation or "AM"
  
  if modulation=="FM" then
    self.LSOModu=radio.modulation.FM
  else
    self.LSOModu=radio.modulation.AM
  end
  
  self.LSORadio:SetFrequency(self.LSOFreq)
  self.LSORadio:SetModulation(self.LSOModu)

  return self
end

--- Set carrier radio frequency and modulation. Default frequency is 305 MHz AM.
-- @param #AIRBOSS self
-- @param #number frequency Frequency in MHz. Default 305 MHz.
-- @param #string modulation Modulation, i.e. "AM" (default) or "FM".
-- @return #AIRBOSS self
function AIRBOSS:SetMarshalRadio(frequency, modulation)

  self.MarshalFreq=frequency or 305
  self.MarshalModu=modulation or "AM"
  
  if modulation=="FM" then
    self.MarshalModu=radio.modulation.FM
  else
    self.MarshalModu=radio.modulation.AM
  end
  
  self.MarshalRadio:SetFrequency(self.MarshalFreq)
  self.MarshalRadio:SetModulation(self.MarshalModu)

  return self
end

--- Set number of aircraft units which can be in the landing pattern before the pattern is full.
-- @param #AIRBOSS self
-- @param #number nmax Max number. Default 4.
-- @return #ARIBOSS self
function AIRBOSS:SetMaxLandingPattern(nmax)
  self.Nmaxpattern=nmax or 4
  return self
end

--- Handle AI aircraft.
-- @param #AIRBOSS self
-- @return #ARIBOSS self
function AIRBOSS:SetHandleAION()
  self.handleai=true
  return self
end

--- Do not handle AI aircraft.
-- @param #AIRBOSS self
-- @return #ARIBOSS self
function AIRBOSS:SetHandleAIOFF()
  self.handleai=false
  return self
end


--- Define recovery tanker associated with the carrier.
-- @param #AIRBOSS self
-- @param Ops.RecoveryTanker#RECOVERYTANKER recoverytanker Recovery tanker object.
-- @return #ARIBOSS self
function AIRBOSS:SetRecoveryTanker(recoverytanker)
  self.tanker=recoverytanker
  return self
end

--- Define warehouse associated with the carrier.
-- @param #AIRBOSS self
-- @param Functional.Warehouse#WAREHOUSE warehouse Warehouse object of the carrier.
-- @return #ARIBOSS self
function AIRBOSS:SetWarehouse(warehouse)
  self.warehouse=warehouse
  return self
end

--- Set default player skill. New players will be initialized with this skill.
-- 
-- * "Flight Student" = @{#AIRBOSS.Difficulty.Easy}
-- * "Naval Aviator" = @{#AIRBOSS.Difficulty.Normal}
-- * "TOPGUN Graduate" = @{#AIRBOSS.Difficulty.Hard}
-- @param #AIRBOSS self
-- @param #string skill Player skill. Default "Naval Aviator".
-- @return #ARIBOSS self
function AIRBOSS:SetDefaultPlayerSkill(skill)
  self.defaultskill=skill or AIRBOSS.Difficulty.NORMAL
  -- Check that defualt skill is valid.
  local gotit=false
  for _,_skill in pairs(AIRBOSS.Difficulty) do
    if _skill==self.defaultskill then
      gotit=true
    end
  end
  if not gotit then
    self.defaultskill=AIRBOSS.Difficulty.NORMAL
    self:E(self.lid..string.format("ERROR: Invalid default skill = %s. Resetting to Naval Aviator.", tostring(skill)))
  end
  return self
end

--- Activate debug mode. Display debug messages on screen.
-- @param #AIRBOSS self
-- @return #AIRBOSS self
function AIRBOSS:SetDebugModeON()
  self.Debug=true
  return self
end

--- Deactivate debug mode. This is also the default setting.
-- @param #AIRBOSS self
-- @return #AIRBOSS self
function AIRBOSS:SetDebugModeOFF()
  self.Debug=false
  return self
end

--- Check if carrier is recovering aircraft.
-- @param #AIRBOSS self
-- @return #boolean If true, time slot for recovery is open.
function AIRBOSS:IsRecovering()
  return self:is("Recovering")
end

--- Check if carrier is idle, i.e. no operations are carried out.
-- @param #AIRBOSS self
-- @return #boolean If true, carrier is in idle state. 
function AIRBOSS:IsIdle()
  return self:is("Idle")
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- FSM event functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- On after Start event. Starts the warehouse. Addes event handlers and schedules status updates of reqests and queue.
-- @param #AIRBOSS self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function AIRBOSS:onafterStart(From, Event, To)

  -- Events are handled my MOOSE.
  self:I(self.lid..string.format("Starting AIRBOSS v%s for carrier unit %s of type %s.", AIRBOSS.version, self.carrier:GetName(), self.carriertype))
  
  -- Current map.
  local theatre=env.mission.theatre  
  self:I(self.lid..string.format("Theatre = %s", tostring(theatre)))
  
  -- Activate TACAN.
  if self.TACANon then
    self.beacon:ActivateTACAN(self.TACANchannel, self.TACANmode, self.TACANmorse, true)
  end
  
  -- Activate ICLS.
  if self.ICLSon then
    self.beacon:ActivateICLS(self.ICLSchannel, self.ICLSmorse)
  end
    
  -- Handle events.
  self:HandleEvent(EVENTS.Birth)
  self:HandleEvent(EVENTS.Land)
  self:HandleEvent(EVENTS.Crash)
  self:HandleEvent(EVENTS.Ejection)
  
  -- Time stamp for checking queues. 
  self.Tqueue=timer.getTime()
  
  -- Schedule radio queue checks.
  -- TODO: id's to self to be able to stop the scheduler.
  local RQLid=self.radiotimer:Schedule(self, self._CheckRadioQueue, {self.RQLSO,     "LSO"},     1, 0.01)
  local RQMid=self.radiotimer:Schedule(self, self._CheckRadioQueue, {self.RQMarshal, "MARSHAL"}, 1, 0.01)
    
  -- Initial carrier position and orientation.
  self.Cposition=self:GetCoordinate()
  self.Corientation=self.carrier:GetOrientationX()
  self.Corientlast=self.Corientation
  self.Tpupdate=timer.getTime()
  
  -- Init patrol route of carrier.
  self:_PatrolRoute()

  -- Start status check in 1 second.
  self:__Status(1)
end

--- On after Status event. Checks for new flights, updates queue and checks player status.
-- @param #AIRBOSS self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function AIRBOSS:onafterStatus(From, Event, To)

  -- Get current time.
  local time=timer.getTime()
    
  -- Update marshal and pattern queue every 30 seconds.
  if time-self.Tqueue>30 then
  
    -- Get time.
    local clock=UTILS.SecondsToClock(timer.getAbsTime())

    -- Debug info.
    local text=string.format("Time %s - Status %s (case=%d) - Speed=%.1f kts - Heading=%d - WP=%d - ETA=%s",
    clock, self:GetState(), self.case, self.carrier:GetVelocityKNOTS(), self:GetHeading(), self.currentwp, UTILS.SecondsToClock(self:_GetETAatNextWP()))
    self:I(self.lid..text)
    
    -- Check recovery times and start/stop recovery mode if necessary.
    self:_CheckRecoveryTimes()
  
    -- Scan carrier zone for new aircraft.
    self:_ScanCarrierZone()
    
    -- Check marshal and pattern queues.
    self:_CheckQueue()
    
    -- Check if marshal pattern of AI needs an update.
    self:_CheckPatternUpdate()
    
    -- Time stamp.
    self.Tqueue=time
  end
  
  -- Check player status.
  self:_CheckPlayerStatus()
  
  -- Check AI landing pattern status
  self:_CheckAIStatus()

  -- Call status every 0.5 seconds.
  self:__Status(-0.5)
end

--- Get aircraft nickname.
-- @param #AIRBOSS self
-- @param #string actype Aircraft type name.
-- @return #string Aircraft nickname. E.g. "Hornet" for the F/A-18C or "Tomcat" For the F-14A.
function AIRBOSS:_GetACNickname(actype)

  local nickname="unknown"
  if actype==AIRBOSS.AircraftCarrier.A4EC then
    nickname="Skyhawk"
  elseif actype==AIRBOSS.AircraftCarrier.AV8B then
    nickname="Harrier"
  elseif actype==AIRBOSS.AircraftCarrier.E2D then
    nickname="Hawkeye"
  elseif actype==AIRBOSS.AircraftCarrier.F14A then
    nickname="Tomcat"
  elseif actype==AIRBOSS.AircraftCarrier.FA18C or actype==AIRBOSS.AircraftCarrier.HORNET then
    nickname="Hornet"
  elseif actype==AIRBOSS.AircraftCarrier.S3B or actype==AIRBOSS.AircraftCarrier.S3BTANKER then
    nickname="Viking"
  end
  
  return nickname
end

--- Check AI status. Pattern queue AI in the groove? Marshal queue AI arrived in holding zone?
-- @param #AIRBOSS self
function AIRBOSS:_CheckAIStatus()

  -- Loop over all flights in landing pattern.
  for _,_flight in pairs(self.Qpattern) do
    local flight=_flight --#AIRBOSS.FlightGroup
    
    -- Only AI!
    if flight.ai then
        
      -- Loop over all units in AI flight.
      for _,_element in pairs(flight.elements) do
        local element=_element --#AIRBOSS.FlightElement
        
        -- Unit
        local unit=element.unit
        
        -- Get lineup and distance to carrier.
        local lineup=self:_Lineup(unit, true)
        
        -- Distance in NM.
        local distance=UTILS.MetersToNM(unit:GetCoordinate():Get2DDistance(self:GetCoordinate()))
        
        -- Altitude in ft.
        local alt=UTILS.MetersToFeet(unit:GetAltitude())
        
        -- Check if parameters are right and flight is in the groove.
        if lineup<2 and distance<=0.75 and alt<500 and not element.ballcall then
        
          -- Paddles: Call the ball!
          self:RadioTransmission(self.LSORadio, AIRBOSS.LSOCall.CALLTHEBALL, false, 0)

          -- Pilot: "405, Hornet Ball, 3.2"
          -- TODO: Voice over.
          local text=string.format("%s Ball, %.1f.", self:_GetACNickname(unit:GetTypeName()), self:_GetFuelState(unit)/1000)          
          self:MessageToPattern(text, element.onboard, "", 3, false, 0, true)
          MESSAGE:New(text, 15):ToAll()
          
          -- Paddles: Roger ball after 3 seconds.
          self:RadioTransmission(self.LSORadio, AIRBOSS.LSOCall.ROGERBALL, false, 3)
          
          -- Flight element called the ball.
          element.ballcall=true
          
          -- This is for the whole flight. Maybe we need it.
          flight.ballcall=true
        end
        
      end
    end
  end

end

--- Check if player in the landing pattern is too close to another aircarft in the pattern.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData player Player data.
function AIRBOSS:_CheckPlayerPatternDistance(player)

  -- Nothing to do since we check only in the pattern.
  if #self.Qpattern==0 then 
    return
  end

  --- Function that checks if unit1 is too close to unit2.  
  local function _checkclose(_unit1, _unit2)
  
    local unit1=_unit1 --Wrapper.Unit#UNIT
    local unit2=_unit2 --Wrapper.Unit#UNIT
    
    if (not unit1) or (not unit2) then
      return false
    end
    
    -- Check that this is not the same unit.
    if unit1:GetName()==unit2:GetName() then
      return false
    end
    
    -- Return false when unit2 is not in air? Could be on the carrier.
    if not unit2:InAir() then
      return false
    end
    
    -- Positions of units.
    local c1=unit1:GetCoordinate()
    local c2=unit2:GetCoordinate()
    
    -- Vector from unit1 to unit2
    local vec12={x=c2.x-c1.x, y=0, z=c2.z-c1.z} --DCS#Vec3
    
    -- Distance between units.
    local dist=UTILS.VecNorm(vec12)
    
    -- Orientation of unit 1 in space.
    local vec1=unit1:GetOrientationX()
    vec1.y=0
    
    -- Get angle between the two orientation vectors. Does the player aircraft nose point into the direction of the other aircraft? (Could be behind him!)
    local rhdg=math.deg(math.acos(UTILS.VecDot(vec12,vec1)/UTILS.VecNorm(vec12)/UTILS.VecNorm(vec1)))
    
    -- Check altitude difference?
    local dalt=math.abs(c2.y-c1.y)
    
    -- Direction in 30 degrees cone and distance < 200 meters and altitude difference <50
    -- TODO: Test parameter values.
    if math.abs(rhdg)<30 and dist<200 and dalt<50 then  
      return true
    else
      return false
    end
  end
  
  -- Loop over all other flights in pattern.
  for _,_flight in pairs(self.Qpattern) do
    local flight=_flight --#AIRBOSS.FlightGroup
    
    -- Now we still need to loop over all units in the flight.
    for _,_element in pairs(flight.elements) do
      local element=_element --#AIRBOSS.FlightElement
      
      -- Check if player is too close to another aircraft in the pattern.
      local tooclose=_checkclose(player.unit, element.unit)
      
      if tooclose then
        local text=string.format("Player %s too close (<200 meters) to aircraft %s!", player.name, element.unit:GetName())
        MESSAGE:New(text, 20, "DEBUG"):ToAllIf(self.Debug)
        -- TODO: AIRBOSS call ==> Pattern wave off.
      end
                
    end
  end
    
end

--- Check recovery times and start/stop recovery mode of aircraft.
-- @param #AIRBOSS self
function AIRBOSS:_CheckRecoveryTimes()

  -- Get current abs time.
  local time=timer.getAbsTime()
  local Cnow=UTILS.SecondsToClock(time)
  
  -- Debug output:
  local text=string.format(self.lid.."Recovery time windows:")
  
  -- Handle case with no recoveries.
  if #self.recoverytimes==0 then
    text=" none!"
  end
  
  -- Sort windows wrt to start time.
  local _sort=function(a, b) return a.START<b.START end
  table.sort(self.recoverytimes,_sort)
  
  -- Next recovery case in the future.
  local nextwindow=nil  --#AIRBOSS.Recovery
  
  -- Loop over all slots.
  for _,_recovery in pairs(self.recoverytimes) do
    local recovery=_recovery --#AIRBOSS.Recovery
        
    -- Get start/stop clock strings.
    local Cstart=UTILS.SecondsToClock(recovery.START)
    local Cstop=UTILS.SecondsToClock(recovery.STOP)
    
    -- Status info.
    local state=""
    
    -- Check if start time passed.
    if time>=recovery.START then
      -- Start time has passed.
      
      if time<recovery.STOP then
        -- Stop time has not passed        
        
        if self:IsRecovering() then
          -- Carrier is already recovering.
          state="in progress"
        else
          -- Start recovery.
          self:RecoveryStart(recovery.CASE, recovery.OFFSET)
          state="starting now"
          recovery.OPEN=true
        end
        
      else -- Stop time has passed.
      
        if self:IsRecovering() and not recovery.OVER then
        
          -- Set carrier to idle.
          self:RecoveryStop()
          state="closing now"
          
          -- Closed.
          recovery.OPEN=false
          
          -- Window just closed.
          recovery.OVER=true
        else
        
          -- Carrier is already idle.
          state="closed"
        end
        
      end
      
    else
      -- This recovery is in the future.
      state="in the future"
      
      -- This is the next to come.
      if nextwindow==nil then
        nextwindow=recovery
        state="next in line"
      end
    end
    
    -- Debug text.
    text=text..string.format("\n- Start=%s Stop=%s Case=%d Offset=%d Open=%s Closed=%s Status=\"%s\"", Cstart, Cstop, recovery.CASE, recovery.OFFSET, tostring(recovery.OPEN), tostring(recovery.OVER), state)
  end
  
  -- Debug output.
  self:I(self.lid..text)
  
  -- Carrier is idle. We need to make sure that incoming flights get the correct recovery info of the next window.
  if self:IsIdle() then
    -- Check if there is a next windows defined.
    if nextwindow then
      -- Set case and offset of the next window.
      self.case=nextwindow.CASE
      self.holdingoffset=nextwindow.OFFSET
    else
      -- No next window. Set default values.
      self.case=self.defaultcase
      self.holdingoffset=self.defaultoffset
    end
  end
end


--- On after "RecoveryCase" event. Sets new aircraft recovery case.
-- @param #AIRBOSS self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param #number Case The recovery case (1, 2 or 3) to switch to.
-- @param #number Offset Holding pattern offset angle in degrees for CASE II/III recoveries.
function AIRBOSS:onafterRecoveryCase(From, Event, To, Case, Offset)

  -- Input or default value.
  Case=Case or self.defaultcase
  
  -- Input or default value
  Offset=Offset or self.defaultoffset

  -- Debug output.
  local text=string.format("Switching to recovery case %d.", Case)
  if Case>1 then
    text=text..string.format(" Holding offset angle %d degrees.", Offset)
  end
  MESSAGE:New(text, 20, self.alias):ToAllIf(self.Debug)
  self:I(self.lid..text)
  
  -- Set new recovery case.
  self.case=Case
  
  -- Set holding offset.
  self.holdingoffset=Offset
end

--- On after "RecoveryStart" event. Recovery of aircraft is started and carrier switches to state "Recovering".
-- @param #AIRBOSS self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param #number Case The recovery case (1, 2 or 3) to start.
-- @param #number Offset Holding pattern offset angle in degrees for CASE II/III recoveries.
function AIRBOSS:onafterRecoveryStart(From, Event, To, Case, Offset)

  -- Input or default value.
  Case=Case or self.defaultcase
  
  -- Input or default value.
  Offset=Offset or self.defaultoffset

  -- Debug output.
  local text=string.format("Starting aircraft recovery case %d.", Case)
  if Case>1 then
    text=text..string.format(" Holding offset angle %d degrees.", Offset)
  end
  MESSAGE:New(text, 20, self.alias):ToAllIf(self.Debug)
  self:I(self.lid..text)
  
  -- Switch to case.
  self:RecoveryCase(Case, Offset)
    
end

--- On after "RecoveryStop" event. Recovery of aircraft is stopped and carrier switches to state "Idle".
-- @param #AIRBOSS self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function AIRBOSS:onafterRecoveryStop(From, Event, To)
  -- Debug output.
  self:I(self.lid..string.format("Stopping aircraft recovery. Carrier goes to state idle.")) 
end

--- On after "Idle" event. Carrier goes to state "Idle".
-- @param #AIRBOSS self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function AIRBOSS:onafterIdle(From, Event, To)
  -- Debug output.
  self:I(self.lid..string.format("Carrier goes to idle."))
end

--- On after Stop event. Unhandle events. 
-- @param #AIRBOSS self
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function AIRBOSS:onafterStop(From, Event, To)
  self:UnHandleEvent(EVENTS.Birth)
  self:UnHandleEvent(EVENTS.Land)
  self:UnHandleEvent(EVENTS.Crash)
  self:UnHandleEvent(EVENTS.Ejection)
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Parameter initialization
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Function called when a group is passing a waypoint.
--@param Wrapper.Group#GROUP group Group that passed the waypoint
--@param #AIRBOSS airboss Airboss object.
--@param #number i Waypoint number that has been reached.
--@param #number final Final waypoint number.
function AIRBOSS._PassingWaypoint(group, airboss, i, final)

  -- Debug message.
  local text=string.format("Group %s passing waypoint %d of %d.", group:GetName(), i, final)
  
  -- Debug smoke and marker.
  if airboss.Debug and false then
    local pos=group:GetCoordinate()
    pos:SmokeRed()
    local MarkerID=pos:MarkToAll(string.format("Group %s reached waypoint %d", group:GetName(), i))
  end
  
  -- Debug message.
  MESSAGE:New(text,10):ToAllIf(airboss.Debug)
  airboss:T(airboss.lid..text)
  
  -- Set current waypoint.
  airboss.currentwp=i
  
  -- If final waypoint reached, do route all over again.
  if i==final and final>1 then
    -- TODO: set task to call this routine again when carrier reaches final waypoint if user chooses to.
    -- SetPatrolAdInfinitum user function
    airboss:_PatrolRoute()
  end
end

--- Function called when a group has reached the holding zone.
--@param Wrapper.Group#GROUP group Group that reached the holding zone.
--@param #AIRBOSS airboss Airboss object.
--@param #AIRBOSS.FlightGroup flight Flight group that has reached the holding zone.
function AIRBOSS._ReachedHoldingZone(group, airboss, flight)

  -- Debug message.
  local text=string.format("Group %s has reached the holding zone.", group:GetName())
  
  -- Debug mark.
  if airboss.Debug and false then
    local pos=group:GetCoordinate()  
    local MarkerID=pos:MarkToAll(string.format("Flight group %s reached holding zone.", group:GetName()))
  end
      
  -- Message output
  MESSAGE:New(text,10):ToAllIf(airboss.Debug)
  airboss:T(airboss.lid..text)
  
  -- Set holding flag true and set timestamp for marshal time check.
  if flight then
    flight.holding=true
    flight.time=timer.getAbsTime()
  end
end


--- Patrol carrier
-- @param #AIRBOSS self
-- @return #AIRBOSS self
function AIRBOSS:_PatrolRoute()

  -- Get carrier group.
  local CarrierGroup=self.carrier:GetGroup()
  
  -- Waypoints of group.
  local Waypoints = CarrierGroup:GetTemplateRoutePoints()
  
  -- NOTE: This is only necessary, if the first waypoint would already be far way, i.e. when the script is started with a large delay.
  -- Calculate the new Route.
  --local wp0=CarrierGroup:GetCoordinate():WaypointGround(5.5*3.6) 
  -- Insert current coordinate as first waypoint
  --table.insert(Waypoints, 1, wp0)
  
  for n=1,#Waypoints do
  
    -- Passing waypoint taskfunction
    local TaskPassingWP=CarrierGroup:TaskFunction("AIRBOSS._PassingWaypoint", self, n, #Waypoints)
    
    -- Call task function when carrier arrives at waypoint.
    CarrierGroup:SetTaskWaypoint(Waypoints[n], TaskPassingWP)
  end

  -- Set waypoint table.
  local i=1
  for _,point in ipairs(Waypoints) do
  
    -- Coordinate of the waypoint
    local coord=COORDINATE:New(point.x, point.alt, point.y)
    
    -- Set velocity of the coordinate.
    coord:SetVelocity(point.speed)
    
    -- Add to table.
    table.insert(self.waypoints, coord)
    
    -- Debug info.
    if self.Debug then
      coord:MarkToAll(string.format("Carrier Waypoint %d, Speed=%.1f knots", i, UTILS.MpsToKnots(point.speed)))
    end
    
    -- Increase counter.
    i=i+1  
  end
  
  -- Current waypoint is 1.
  self.currentwp=1

  -- Route carrier group.
  CarrierGroup:Route(Waypoints)
end

--- Estimated the carrier position at some point in the future given the current waypoints and speeds.
-- @param #AIRBOSS self
-- @return DCS#time ETA abs. time in seconds.
function AIRBOSS:_GetETAatNextWP()

  -- Current waypoint
  local cwp=self.currentwp
  
  -- Current abs. time.
  local tnow=timer.getAbsTime()

  -- Current position.
  local p=self:GetCoordinate()
  
  -- Current velocity [m/s].
  local v=self.carrier:GetVelocityMPS()
  
  -- Distance to next waypoint.
  local s=0
  if #self.waypoints>cwp then
    s=p:Get2DDistance(self.waypoints[cwp+1])
  end
  
  -- v=s/t <==> t=s/v
  local t=s/v
  
  -- ETA
  local eta=t+tnow
  
  return eta
end


--- Estimated the carrier position at some point in the future given the current waypoints and speeds.
-- @param #AIRBOSS self
-- @param #number time Absolute mission time at which the carrier position is requested.
-- @return Core.Point#COORDINATE Coordinate of the carrier at the given time.
function AIRBOSS:_GetCarrierFuture(time)

  local nwp=self.currentwp
  
  local waypoints={}
  local lastwp=nil --Core.Point#COORDINATE
  for i=1,#self.waypoints do
    
    if i>nwp then
      table.insert(waypoints, self.waypoints[i])
    elseif i==nwp then
      lastwp=self.waypoints[i]
    end
  
  end
  
  -- Current abs. time.
  local tnow=timer.getAbsTime()

  local p=self:GetCoordinate()
  local v=self.carrier:GetVelocityMPS()
  
  local s=p:Get2DDistance(self.waypoints[nwp+1])
  
  -- v=s/t <==> t=s/v
  local t=s/v
  
  local eta=UTILS.SecondsToClock(t+tnow)
  
  
  for _,_wp in ipairs(waypoints) do
    local wp=_wp --Core.Point#COORDINATE
    
  end

end

--- Init parameters for USS Stennis carrier.
-- @param #AIRBOSS self
function AIRBOSS:_InitStennis()

  -- Carrier Parameters.
  self.carrierparam.rwyangle   =  -9
  self.carrierparam.sterndist  =-150
  self.carrierparam.deckheight =  22
  
  --[[
  self.carrierparam.wire1      =-104
  self.carrierparam.wire2      = -92
  self.carrierparam.wire3      = -80
  self.carrierparam.wire4      = -68
  self.carrierparam.wireoffset =  30
  ]]
  
  self.carrierparam.wire1      =   0
  self.carrierparam.wire2      =  12
  self.carrierparam.wire3      =  24
  self.carrierparam.wire4      =  36
  self.carrierparam.wireoffset =  50

 
  -- Platform at 5k. Reduce descent rate to 2000 ft/min to 1200 dirty up level flight.
  self.Platform.name="Platform 5k"
  self.Platform.Xmin=-UTILS.NMToMeters(22)  -- Not more than 22 NM behind the boat. Last check was at 21 NM.
  self.Platform.Xmax =nil
  self.Platform.Zmin=-UTILS.NMToMeters(30)  -- Not more than 30 NM port of boat.
  self.Platform.Zmax= UTILS.NMToMeters(30)  -- Not more than 30 NM starboard of boat.
  self.Platform.LimitXmin=nil               -- Limits via zone
  self.Platform.LimitXmax=nil
  self.Platform.LimitZmin=nil
  self.Platform.LimitZmax=nil 
  
  -- Level out at 1200 ft and dirty up.
  self.DirtyUp.name="Dirty Up"
  self.DirtyUp.Xmin=-UTILS.NMToMeters(21)        -- Not more than 21 NM behind the boat.
  self.DirtyUp.Xmax= nil
  self.DirtyUp.Zmin=-UTILS.NMToMeters(30)        -- Not more than 30 NM port of boat.
  self.DirtyUp.Zmax= UTILS.NMToMeters(30)        -- Not more than 30 NM starboard of boat.
  self.DirtyUp.LimitXmin=nil                     -- Limits via zone
  self.DirtyUp.LimitXmax=nil
  self.DirtyUp.LimitZmin=nil
  self.DirtyUp.LimitZmax=nil 
  
  -- Intercept glide slope and follow bullseye.
  self.Bullseye.name="Bullseye"
  self.Bullseye.Xmin=-UTILS.NMToMeters(11)       -- Not more than 11 NM behind the boat. Last check was at 10 NM.
  self.Bullseye.Xmax= nil
  self.Bullseye.Zmin=-UTILS.NMToMeters(30)       -- Not more than 30 NM port.
  self.Bullseye.Zmax= UTILS.NMToMeters(30)       -- Not more than 30 NM starboard.
  self.Bullseye.LimitXmin=nil                    -- Limits via zone.
  self.Bullseye.LimitXmax=nil
  self.Bullseye.LimitZmin=nil
  self.Bullseye.LimitZmax=nil
 
  -- Break entry.
  self.BreakEntry.name="Break Entry"
  self.BreakEntry.Xmin=-UTILS.NMToMeters(4)          -- Not more than 4 NM behind the boat. Check for initial is at 3 NM with a radius of 500 m and 100 m starboard.
  self.BreakEntry.Xmax= nil
  self.BreakEntry.Zmin=-400                          -- Not more than  400 m port of boat. Otherwise miss the zone.
  self.BreakEntry.Zmax=1000                          -- Not more than 1000 m starboard of boat. Otherwise miss the zone.
  self.BreakEntry.LimitXmin=0                        -- Check and next step when at carrier and starboard of carrier.
  self.BreakEntry.LimitXmax=nil
  self.BreakEntry.LimitZmin=nil
  self.BreakEntry.LimitZmax=nil

  -- Early break.
  self.BreakEarly.name="Early Break"
  self.BreakEarly.Xmin=-UTILS.NMToMeters(1)         -- Not more than 1 NM behind the boat. Last check was at 0.
  self.BreakEarly.Xmax= UTILS.NMToMeters(5)         -- Not more than 5 NM in front of the boat. Enough for late breaks?
  self.BreakEarly.Zmin=-UTILS.NMToMeters(2)         -- Not more than 2 NM port.
  self.BreakEarly.Zmax= UTILS.NMToMeters(1)         -- Not more than 1 NM starboard.
  self.BreakEarly.LimitXmin= 0                      -- Check and next step 0.2 NM port and in front of boat.
  self.BreakEarly.LimitXmax= nil
  self.BreakEarly.LimitZmin=-UTILS.NMToMeters(0.2)  -- -370 m port
  self.BreakEarly.LimitZmax= nil
  
  -- Late break.
  self.BreakLate.name="Late Break"
  self.BreakLate.Xmin=-UTILS.NMToMeters(1)         -- Not more than 1 NM behind the boat. Last check was at 0.
  self.BreakLate.Xmax= UTILS.NMToMeters(5)         -- Not more than 5 NM in front of the boat. Enough for late breaks?
  self.BreakLate.Zmin=-UTILS.NMToMeters(2)         -- Not more than 2 NM port.
  self.BreakLate.Zmax= UTILS.NMToMeters(1)         -- Not more than 1 NM starboard.
  self.BreakLate.LimitXmin= 0                      -- Check and next step 0.8 NM port and in front of boat.
  self.BreakLate.LimitXmax= nil
  self.BreakLate.LimitZmin=-UTILS.NMToMeters(0.8)  -- -1470 m port
  self.BreakLate.LimitZmax= nil
  
  -- Abeam position.
  self.Abeam.name="Abeam Position"
  self.Abeam.Xmin= nil
  self.Abeam.Xmax= nil
  self.Abeam.Zmin=-UTILS.NMToMeters(3)            -- Not more than 3 NM port.
  self.Abeam.Zmax= 0                              -- Must be port!
  self.Abeam.LimitXmin=-200                       -- Check and next step 200 meters behind the ship.
  self.Abeam.LimitXmax= nil
  self.Abeam.LimitZmin= nil
  self.Abeam.LimitZmax= nil

  -- At the Ninety.
  self.Ninety.name="Ninety"
  self.Ninety.Xmin=-UTILS.NMToMeters(4)           -- Not more than 4 NM behind the boat. LIG check anyway.
  self.Ninety.Xmax= 0                             -- Must be behind the boat.
  self.Ninety.Zmin=-UTILS.NMToMeters(2)           -- Not more than 2 NM port of boat.
  self.Ninety.Zmax= nil
  self.Ninety.LimitXmin=nil
  self.Ninety.LimitXmax=nil
  self.Ninety.LimitZmin=nil
  self.Ninety.LimitZmax=-UTILS.NMToMeters(0.6)    -- Check and next step when 0.6 NM port. 

  -- At the Wake.
  self.Wake.name="Wake"
  self.Wake.Xmin=-UTILS.NMToMeters(4)           -- Not more than 4 NM behind the boat.
  self.Wake.Xmax= 0                             -- Must be behind the boat.
  self.Wake.Zmin=-2000                          -- Not more than 2 km port of boat.
  self.Wake.Zmax= nil
  self.Wake.LimitXmin=nil
  self.Wake.LimitXmax=nil
  self.Wake.LimitZmin=0                         -- Check and next step when directly behind the boat.
  self.Wake.LimitZmax=nil

  -- Turn to final.
  self.Final.name="Final"
  self.Final.Xmin=-UTILS.NMToMeters(4)           -- Not more than 4 NM behind the boat.
  self.Final.Xmax= 0                             -- Must be behind the boat.
  self.Final.Zmin=-1000                          -- Not more than 1 km port.
  self.Final.Zmax= nil
  self.Final.LimitXmin=nil                       -- No limits. Check is carried out differently.
  self.Final.LimitXmax=nil
  self.Final.LimitZmin=nil
  self.Final.LimitZmax=nil
  
  -- In the Groove.
  self.Groove.name="Groove"
  self.Groove.Xmin=-UTILS.NMToMeters(4)           -- Not more than 4 NM behind the boat.
  self.Groove.Xmax= nil
  self.Groove.Zmin=-UTILS.NMToMeters(2)           -- Not more than 2 NM port
  self.Groove.Zmax= UTILS.NMToMeters(2)           -- Not more than 2 NM starboard.
  self.Groove.LimitXmin=nil                       -- No limits. Check is carried out differently.
  self.Groove.LimitXmax=nil
  self.Groove.LimitZmin=nil
  self.Groove.LimitZmax=nil

end

--- Get optimal aircraft AoA parameters..
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data table.
-- @return #AIRBOSS.AircraftAoA AoA parameters for the given aircraft type.
function AIRBOSS:_GetAircraftAoA(playerData)

  -- Get AC type.
  local hornet=playerData.actype==AIRBOSS.AircraftCarrier.HORNET
  local skyhawk=playerData.actype==AIRBOSS.AircraftCarrier.A4EC
  local harrier=playerData.actype==AIRBOSS.AircraftCarrier.AV8B
  
  -- Table with AoA values.
  local aoa={} -- #AIRBOSS.AircraftAoA
  
  if hornet then
    -- F/A-18C Hornet parameters
    aoa.SLOW=9.8
    aoa.Slow=9.3
    aoa.OnSpeedMax=8.8
    aoa.OnSpeed=8.1
    aoa.OnSpeedMin=7.4
    aoa.Fast=6.9
    aoa.FAST=6.3
  elseif skyhawk then
    -- A-4E-C parameters from https://forums.eagle.ru/showpost.php?p=3703467&postcount=390
    aoa.SLOW=19.0
    aoa.Slow=18.5
    aoa.OnSpeedMax=18.0
    aoa.OnSpeed=17.5
    aoa.OnSpeedMin=17.0
    aoa.Fast=16.5
    aoa.FAST=16.0
  elseif harrier then
    -- TODO: AV-8B parameters! On speed AoA?
    aoa.SLOW=14.0
    aoa.Slow=13.0
    aoa.OnSpeedMax=12.0
    aoa.OnSpeed=11.0
    aoa.OnSpeedMin=10.0
    aoa.Fast=9.0
    aoa.FAST=8.0
  end

  return aoa
end

--- Get optimal aircraft flight parameters at checkpoint.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data table.
-- @param #string step Pattern step.
-- @return #number Altitude in meters or nil.
-- @return #number Angle of Attack or nil.
-- @return #number Distance to carrier in meters or nil.
-- @return #number Speed in m/s or nil.
function AIRBOSS:_GetAircraftParameters(playerData, step)

  -- Get parameters depended on step.
  step=step or playerData.step
  
  -- Get AC type.
  local hornet=playerData.actype==AIRBOSS.AircraftCarrier.HORNET
  local skyhawk=playerData.actype==AIRBOSS.AircraftCarrier.A4EC
  
  -- Return values.
  local alt
  local aoa
  local dist  
  local speed

  -- Aircraft specific AoA.  
  local aoaac=self:_GetAircraftAoA(playerData)
  
  if step==AIRBOSS.PatternStep.PLATFORM then
  
   alt=UTILS.FeetToMeters(5000)
   
   dist=UTILS.NMToMeters(20)
   
   speed=UTILS.KnotsToMps(250)
   
 elseif step==AIRBOSS.PatternStep.ARCIN then
 
  speed=UTILS.KnotsToMps(250) 
 
 elseif step==AIRBOSS.PatternStep.ARCOUT then
 
  speed=UTILS.KnotsToMps(250)
  
 elseif step==AIRBOSS.PatternStep.DIRTYUP then
  
    alt=UTILS.FeetToMeters(1200)
    
    dist=UTILS.NMToMeters(12)
    
    speed=UTILS.KnotsToMps(250)
  
  elseif step==AIRBOSS.PatternStep.BULLSEYE then

    alt=UTILS.FeetToMeters(1200)
    
    dist=-UTILS.NMToMeters(3)
    
    aoa=aoaac.OnSpeed
  
  elseif step==AIRBOSS.PatternStep.INITIAL then

    if hornet then     
      alt=UTILS.FeetToMeters(800)
      speed=UTILS.KnotsToMps(350)
    elseif skyhawk then
      alt=UTILS.FeetToMeters(600)
      speed=UTILS.KnotsToMps(250)
    end
    
  elseif step==AIRBOSS.PatternStep.BREAKENTRY then

    if hornet then     
      alt=UTILS.FeetToMeters(800)
      speed=UTILS.KnotsToMps(350)
    elseif skyhawk then
      alt=UTILS.FeetToMeters(600)
      speed=UTILS.KnotsToMps(250)
    end
  
  elseif step==AIRBOSS.PatternStep.EARLYBREAK then

    if hornet then     
      alt=UTILS.FeetToMeters(800)
    elseif skyhawk then
      alt=UTILS.FeetToMeters(600)  
    end  
    
  elseif step==AIRBOSS.PatternStep.LATEBREAK then

    if hornet then     
      alt=UTILS.FeetToMeters(800)
    elseif skyhawk then
      alt=UTILS.FeetToMeters(600)  
    end  
    
  elseif step==AIRBOSS.PatternStep.ABEAM then
  
    if hornet then     
      alt=UTILS.FeetToMeters(600)
    elseif skyhawk then
      alt=UTILS.FeetToMeters(500)  
    end
    
    aoa=aoaac.OnSpeed
    
    dist=UTILS.NMToMeters(1.2)
    
  elseif step==AIRBOSS.PatternStep.NINETY then

    if hornet then     
      alt=UTILS.FeetToMeters(500)
    elseif skyhawk then
      alt=UTILS.FeetToMeters(500)  
    end
    
    aoa=aoaac.OnSpeed
  
  elseif step==AIRBOSS.PatternStep.WAKE then
  
    if hornet then     
      alt=UTILS.FeetToMeters(370)
    elseif skyhawk then
      alt=UTILS.FeetToMeters(370) --?
    end
    
    aoa=aoaac.OnSpeed
    
  elseif step==AIRBOSS.PatternStep.FINAL then

    if hornet then     
      alt=UTILS.FeetToMeters(300)
    elseif skyhawk then
      alt=UTILS.FeetToMeters(300) --?  
    end
    
    aoa=aoaac.OnSpeed
  
  end

  return alt, aoa, dist, speed
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- QUEUE Functions
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Get next marshal flight which is ready to enter the landing pattern.
-- @param #AIRBOSS self
-- @return #AIRBOSS.FlightGroup Marshal flight next in line and ready to enter the pattern. Or nil if no flight is ready.
function AIRBOSS:_GetNextMarshalFight()

  -- Min 5 min in marshal before send to landing pattern.
  local TmarshalMin=5*60

  for _,_flight in pairs(self.Qmarshal) do
    local flight=_flight --#AIRBOSS.FlightGroup
    
    -- Current stack.
    local stack=flight.flag:Get()
    
    -- Marshal time.
    local Tmarshal=timer.getAbsTime()-flight.time
    
    -- Check if conditions are right.
    if stack==1 and flight.holding and Tmarshal>=TmarshalMin then
      return flight
    end
  end

  return nil
end


--- Check marshal and pattern queues.
-- @param #AIRBOSS self
function AIRBOSS:_CheckQueue()
  
  -- Print queues.
  self:_PrintQueue(self.flights,  "All Flights")
  self:_PrintQueue(self.Qmarshal, "Marshal")
  self:_PrintQueue(self.Qpattern, "Pattern")
  
  -- Get number of aircraft units(!) currently in pattern.
  local _,npattern=self:_GetQueueInfo(self.Qpattern)
  
  -- Get number of flight groups(!) in marshal pattern.
  local nmarshal,_=self:_GetQueueInfo(self.Qmarshal)
  
  local marshalflight=self:_GetNextMarshalFight()
  
  -- Check if there are flights in marshal strack and if the pattern is free.
  if marshalflight and npattern<self.Nmaxpattern then
  
    -- Time flight is marshaling.
    local Tmarshal=timer.getAbsTime()-marshalflight.time
    self:I(self.lid..string.format("Marshal time of next group %s = %d seconds", marshalflight.groupname, Tmarshal))
    
    -- Time (last) flight has entered landing pattern.
    local Tpattern=9999
    local npunits=1
    local pcase=1
    if npattern>0 then
    
      -- Last flight group send to pattern.
      local patternflight=self.Qpattern[#self.Qpattern] --#AIRBOSS.FlightGroup
      
      -- Recovery case of pattern flight.
      pcase=patternflight.case
      
      -- Number of aircraft in this group.
      local npunits=patternflight.nunits
      
      -- Get time in pattern.
      Tpattern=timer.getAbsTime()-patternflight.time
      self:I(self.lid..string.format("Pattern time of last group %s = %d seconds. # of units=%d.", patternflight.groupname, Tpattern, npunits))
    end
    
    -- Min time in pattern before next aircraft is allowed.
    local TpatternMin
    if pcase==1 then
      TpatternMin=3*60*npunits --45*npunits   --  45 seconds interval per plane!
    else
      TpatternMin=6*60*npunits --120*npunits  -- 120 seconds interval per plane!
    end
    
    -- Check recovery window open and enough space to last pattern flight.
    if self:IsRecovering() and Tpattern>TpatternMin then
      self:_CheckCollapseMarshalStack(marshalflight)
    end
    
  end
end

--- Scan carrier zone for (new) units.
-- @param #AIRBOSS self
function AIRBOSS:_ScanCarrierZone()
  self:T(self.lid.."Scanning Carrier Zone")

  -- Carrier position.
  local coord=self:GetCoordinate()
  
  -- Scan radius.
  local Rout=UTILS.NMToMeters(50)
  
  -- Scan units in carrier zone.
  local _,_,_,unitscan=coord:ScanObjects(Rout, true, false, false)

  
  -- Make a table with all groups currently in the CCA zone.
  local insideCCA={}  
  for _,_unit in pairs(unitscan) do
    local unit=_unit --Wrapper.Unit#UNIT
    
    -- Necessary conditions to be met:
    local airborn=unit:IsAir() and unit:InAir()
    local inzone=unit:IsInZone(self.zoneCCA)
    local friendly=self:GetCoalition()==unit:GetCoalition()
    local carrierac=self:_IsCarrierAircraft(unit)
    
    -- Check if this an aircraft and that it is airborn and closing in.
    if airborn and inzone and friendly and carrierac then
    
      local group=unit:GetGroup()
      local groupname=group:GetName()
      
      if insideCCA[groupname]==nil then
        insideCCA[groupname]=group
      end
      
    end
  end

  
  -- Find new flights that are inside CCA.
  for groupname,_group in pairs(insideCCA) do
    local group=_group --Wrapper.Group#GROUP
    
    -- Get flight group if possible.
    local knownflight=self:_GetFlightFromGroupInQueue(group, self.flights)
    
    -- Get aircraft type name.
    local actype=group:GetTypeName()
    
    -- Create a new flight group
    if knownflight then
    
      -- Debug output.
      self:T2(self.lid..string.format("Known flight group %s of type %s in CCA.", groupname, actype))
      
      -- Check if flight is AI and if we want to handle it at all.
      if knownflight.ai and self.handleai then
      
        -- Get distance to carrier.
        local dist=knownflight.group:GetCoordinate():Get2DDistance(self:GetCoordinate())
        
        -- Close in distance. Is >0 if AC comes closer wrt to first detected distance d0.
        local closein=knownflight.dist0-dist
        
        -- Debug info.
        self:T3(self.lid..string.format("Known AI flight group %s closed in by %.1f NM", knownflight.groupname, UTILS.MetersToNM(closein)))
        
        -- Send AI flight to marshal stack if group closes in more than 2.5 and has initial flag value.
        if closein>UTILS.NMToMeters(2.5) and knownflight.flag:Get()==-100 then
        
          -- Check that we do not add a recovery tanker for marshaling.
          if self.tanker and self.tanker.tanker:GetName()==groupname then
          
            -- Don't touch the recovery thanker!
            
          else
          
            -- Get the next free stack for current recovery case.
            local stack=self:_GetFreeStack(self.case)
            
            -- Send AI to marshal stack.
            self:_MarshalAI(knownflight, stack)
            
            -- Add group to marshal stack queue.
            self:_AddMarshalGroup(knownflight, stack)
            
          end -- Tanker          
        end   -- Closed in
      end     -- AI
    else
      -- Unknown new flight. Create a new flight group.
      self:_CreateFlightGroup(group)
    end
      
  end

  
  -- Find flights that are not in CCA.
  local remove={}
  for _,_flight in pairs(self.flights) do
    local flight=_flight --#AIRBOSS.FlightGroup
    if insideCCA[flight.groupname]==nil then
      table.insert(remove, flight.group)
    end
  end
  
  -- Remove flight groups. 
  for _,group in pairs(remove) do
    self:_RemoveFlightGroup(group)
  end
  
end


--- Orbit at a specified position at a specified alititude with a specified speed.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data.
function AIRBOSS:_MarshalPlayer(playerData)
  
  -- Check if flight is known to the airboss already.
  if playerData then

    -- Get free stack.  
    local mystack=self:_GetFreeStack(self.case)
    
    -- Add group to marshal stack.
    self:_AddMarshalGroup(playerData, mystack)
    
    -- Set step to holding.
    playerData.step=AIRBOSS.PatternStep.HOLDING
    playerData.warning=nil
    
    -- Holding switch to nil until player arrives in the holding zone.
    playerData.holding=nil
    
    -- Set same stack for all flights in section.
    for _,_flight in pairs(playerData.section) do
      local flight=_flight --#AIRBOSS.PlayerData
      flight.step=AIRBOSS.PatternStep.HOLDING
      flight.holding=nil
      flight.flag:Set(mystack)
    end
    
  else
  
    -- Flight is not registered yet.
    local text="you are not yet registered inside the CCA. Marshal request denied!"
    self:MessageToPlayer(playerData, text, "MARSHAL")
    
  end  
  
end

--- Tell AI to orbit at a specified position at a specified alititude with a specified speed.
-- @param #AIRBOSS self
-- @param #AIRBOSS.FlightGroup flight Flight group.
-- @param #number nstack Stack number of group. (Should be #self.Qmarshal+1 for new flight groups.)
function AIRBOSS:_MarshalAI(flight, nstack)

  -- Flight group name.
  local group=flight.group
  local groupname=flight.groupname

  -- Debug info.
  self:I(self.lid..string.format("Sending AI group %s to marshal stack %d. Current stack/flag value=%d.", groupname, nstack, flight.flag:Get()))
  
  -- Set flag/stack value.
  flight.flag:Set(nstack)
  
  -- Current carrier position.
  local Carrier=self:GetCoordinate()
  
  -- Carrier heading.
  local hdg=self:GetHeading()
    
  -- Aircraft speed 272 knots when orbiting the pattern. (Orbit expects m/s.)
  local SpeedOrbit=UTILS.KnotsToMps(272)
  
  -- Aircraft speed 400 knots when transiting to holding zone. (Waypoint expects km/h.)
  local SpeedTransit=UTILS.KnotsToKmph(400)
  
  --- Create a DCS task to orbit at a certain altitude.
  local function _taskorbit(p1, alt, speed, stopflag, p2)
    local DCSTask={}
    DCSTask.id="ControlledTask"
    DCSTask.params={}
    DCSTask.params.task=group:TaskOrbit(p1, alt, speed, p2)
    DCSTask.params.stopCondition={userFlag=groupname, userFlagValue=stopflag}
    return DCSTask
  end

  -- Waypoints array.
  local wp={}
  
  -- Current position. Not sure if necessary but might be. Need to test if it hurts or not.
  wp[1]=group:GetCoordinate():WaypointAirTurningPoint(nil, SpeedTransit, {}, "Current Position")
  
  -- If flight has not arrived in the holding zone, we guide it there.
  if not flight.holding then

    -- Get altitude and positions.  
    local Altitude, p1, p2=self:_GetMarshalAltitude(nstack, flight.case)
    
    -- Task function when arriving at the holding zone. This will set flight.holding=true.
    local TaskArrivedHolding=flight.group:TaskFunction("AIRBOSS._ReachedHoldingZone", self, flight)
   
    if flight.case==1 then
      -- Waypoint "north" of carrier's holding zone.
      --wp[2]=p1:Translate(UTILS.NMToMeters(10), hdg):WaypointAirTurningPoint(nil, SpeedTransit, {}, "Prepare Entering Case I Marshal Pattern")
      -- Enter pattern from "north" to "south".
      wp[2]=Carrier:Translate(UTILS.NMToMeters(10), hdg-30):WaypointAirTurningPoint(nil, SpeedTransit, {TaskArrivedHolding}, "Entering Case I Marshal Pattern")
    else
      -- TODO: Test and tune!
      wp[2]=p1:WaypointAirTurningPoint(nil, SpeedTransit, {TaskArrivedHolding}, "Entering Marshal Pattern")
    end
    
  end
   
  -- Set up waypoints including collapsing the stack.
  for stack=nstack, 1, -1 do
  
    -- TODO: skip stack 6 if recoverytanker (or at whatever angels the tanker orbits).
  
    -- Get altitude and positions.  
    local Altitude, p1, p2=self:_GetMarshalAltitude(stack, flight.case)
    
    -- Correct CCW pattern for CASE II/III.
    local c1=nil  --Core.Point#COORDINATE
    local c2=nil  --Core.Point#COORDINATE
    local p0=nil  --Core.Point#COORDINATE
    if flight.case==1 then
      c1=p1
      c2=p2
      p0=p1 --self:GetCoordinate():Translate(UTILS.NMToMeters(5), -90):SetAltitude(Altitude)
      p0=self:GetCoordinate():Translate(UTILS.NMToMeters(2.5/math.sqrt(2)), 225):SetAltitude(Altitude)
      --p0=self:GetCoordinate():Translate(UTILS.NMToMeters(2), hdg+190):SetAltitude(Altitude)
    else
      c1=p2
      c2=p1
      p0=c2
    end
    
    -- Distance to the boat.
    local Dist=p1:Get2DDistance(self:GetCoordinate())
    
    -- Task: orbit at specified position, altitude and speed until flag=stack-1
    local TaskOrbit=_taskorbit(c1, Altitude, SpeedOrbit, stack-1, c2)
     
    -- Waypoint description.    
    local text=string.format("Flight %s: Marshal stack %d: alt=%d, dist=%.1f, speed=%d", flight.groupname, stack, UTILS.MetersToFeet(Altitude), UTILS.MetersToNM(Dist), UTILS.MpsToKnots(SpeedOrbit))
    
    -- Debug mark.
    if self.Debug or true then
      --c1:MarkToAll(text)
      if c2 then
        --c2:MarkToAll(text)
      end
    end
    p0:MarkToAll("p0")
    p1:MarkToAll("p1")
    p2:MarkToAll("p2")
    
    -- Waypoint.
    -- TODO: p0?
    wp[#wp+1]=p0:WaypointAirTurningPoint(nil, SpeedTransit, {TaskOrbit}, text)
    
  end  
  
  -- Landing waypoint. (Done separately now).
  --wp[#wp+1]=Carrier:SetAltitude(250):WaypointAirLanding(Speed, self.airbase, nil, "Landing")
      
  -- Reinit waypoints.
  group:WayPointInitialize(wp)
  
  -- Route group.
  group:Route(wp, 0)
end

--- Tell AI to land on the carrier.
-- @param #AIRBOSS self
-- @param #AIRBOSS.FlightGroup flight Flight group.
function AIRBOSS:_LandAI(flight)

  -- Aircraft speed when flying the pattern.
  local Speed=UTILS.KnotsToKmph(272)
  
  local Carrier=self:GetCoordinate()
  local hdg=self:GetHeading()

  -- Waypoints array.
  local wp={}

  wp[#wp+1]=flight.group:GetCoordinate():WaypointAirTurningPoint(nil, Speed, {}, "Current position")

  -- Landing waypoint 5 NM behind carrier at 250 ASL.
  wp[#wp+1]=self:GetCoordinate():Translate(-UTILS.NMToMeters(5), hdg):SetAltitude(250):WaypointAirLanding(Speed, self.airbase, nil, "Landing")
      
  -- Reinit waypoints.
  flight.group:WayPointInitialize(wp)
  
  -- Route group.
  flight.group:Route(wp, 0)
end

--- Get marshal altitude and position.
-- @param #AIRBOSS self
-- @param #number stack Assigned stack number. Counting starts at one, i.e. stack=1 is the first stack.
-- @param #number case Recovery case. Default is self.case.
-- @return #number Holding altitude in meters.
-- @return Core.Point#COORDINATE Holding position coordinate.
-- @return Core.Point#COORDINATE Second holding position coordinate of racetrack pattern for CASE II/III recoveries.
function AIRBOSS:_GetMarshalAltitude(stack, case)

  -- Stack <= 0.
  if stack<=0 then
    return 0,nil,nil
  end
  
  -- Recovery case.
  case=case or self.case

  -- Carrier position.
  local Carrier=self:GetCoordinate()
  
  -- Altitude of first stack. Depends on recovery case.
  local angels0
  local Dist
  local p1=nil  --Core.Point#COORDINATE
  local p2=nil  --Core.Point#COORDINATE
  
  if case==1 then
    -- CASE I: Holding at 2000 ft on a circular pattern port of the carrier. Interval +1000 ft for next stack.
    angels0=2
    
    -- Distance 2.5 NM.
    Dist=UTILS.NMToMeters(2.5*math.sqrt(2))
    
    -- Get true heading of carrier.
    local hdg=self.carrier:GetHeading()
    
    -- Center of holding pattern point. We give it a little head start -70 instead of -90 degrees.
    p1=Carrier:Translate(Dist, hdg-45)
    
    p1=Carrier:Translate(UTILS.NMToMeters(1.0), hdg)
    p2=Carrier:Translate(UTILS.NMToMeters(3.5), hdg)
  else
    -- CASE II/III: Holding at 6000 ft on a racetrack pattern astern the carrier.
    angels0=6
    
    -- Distance: d=n*angles0+15 NM, so first stack is at 15+6=21 NM
    Dist=UTILS.NMToMeters((stack-1)+angels0+15)
    
    -- Get correct radial depending on recovery case including offset.
    local radial
    if case==2 then
      radial=self:GetRadialCase2(false, true)
    elseif case==3 then
      radial=self:GetRadialCase3(false, true)
    end
    
    -- First point of race track pattern
    p1=Carrier:Translate(Dist, radial)
    
    -- Second point which is 10 NM further behind.
    --TODO: check if 10 NM is okay.
    p2=Carrier:Translate(Dist+UTILS.NMToMeters(10), radial)
  end

  -- Pattern altitude.
  local altitude=UTILS.FeetToMeters(((stack-1)+angels0)*1000)
  
  -- Set altitude of coordinate.
  p1:SetAltitude(altitude, true)
  if p2 then
    p2:SetAltitude(altitude, true)
  end
  
  return altitude, p1, p2
end

--- Add a flight group to a specific marshal stack and to the marshal queue.
-- @param #AIRBOSS self
-- @param #AIRBOSS.FlightGroup flight Flight group.
-- @param #number stack Marshal stack. This (re-)sets the flag value.
function AIRBOSS:_AddMarshalGroup(flight, stack)

  -- Set flag value. This corresponds to the stack number which starts at 1.
  flight.flag:Set(stack)
  
  -- Set recovery case.
  flight.case=self.case
  
  -- Pressure.
  local P=UTILS.hPa2inHg(self:GetCoordinate():GetPressure())

  -- Stack altitude.  
  local alt=UTILS.MetersToFeet(self:_GetMarshalAltitude(stack, flight.case))
  local brc=self:GetBRC()
  
  -- Marshal message.
  -- TODO: Get charlie time estimate.
  local text=string.format("Case %d, BRC is %03d, hold at %d. Expected Charlie Time XX.\n", flight.case, brc, alt)
  text=text..string.format("Altimeter %.2f. Report see me.", P)

  -- Message to all players.
  self:MessageToAll(text, "MARSHAL", flight.onboard)
   
  -- Add to marshal queue.
  table.insert(self.Qmarshal, flight)
end

--- Check if marshal stack can be collapsed.
-- If next in line is an AI flight, this is done. If human player is next, we wait for "Commence" via F10 radio menu command.
-- @param #AIRBOSS self
-- @param #AIRBOSS.FlightGroup flight Flight to go to pattern.
function AIRBOSS:_CheckCollapseMarshalStack(flight)

  -- Check if flight is AI or human. If AI, we collapse the stack and commence. If human, we suggest to commence.
  if flight.ai then
    -- Collapse stack and send AI to pattern.
    self:_CollapseMarshalStack(flight)
    self:_LandAI(flight)
  end

  -- Inform all flights.
  local text=string.format("You are cleared for Case %d recovery.", flight.case)
  self:MessageToAll(text, "MARSHAL", flight.onboard)
  
  -- Hint for human players.
  if not flight.ai then
    local playerData=flight --#AIRBOSS.PlayerData
    
    -- Hint for easy skill.
    if playerData.difficulty==AIRBOSS.Difficulty.EASY then
      self:MessageToPlayer(flight, string.format("Use F10 radio menu \"Request Commence\" command when ready!"), nil, "", 5)
    end
  end
 
end

--- Collapse marshal stack.
-- @param #AIRBOSS self
-- @param #AIRBOSS.FlightGroup flight Flight that left the marshal stack.
-- @param #boolean nopattern If true, flight does not go to pattern.
function AIRBOSS:_CollapseMarshalStack(flight, nopattern)
  self:F2({flight=flight, nopattern=nopattern})

  -- Recovery case of flight.
  local case=flight.case
  
  -- Stack of flight.
  local stack=flight.flag:Get()

  -- Decrease flag values of all flight groups in marshal stack.
  for _,_flight in pairs(self.Qmarshal) do
    local mflight=_flight --#AIRBOSS.PlayerData
    
    -- Only collaps stack of which the flight left. CASE II/III stack is the same.
    if (case==1 and mflight.case==1) or (case>1 and mflight.case>1) then
    
      -- Get current flag/stack value.
      local mstack=mflight.flag:Get()
      
      -- Only collapse stacks above the new pattern flight.
      -- This will go wrong, if patternflight is not in marshal stack because it will have value -100 and all mstacks will be larger!
      -- Maybe need to set the initial value to 1000? Or check stack>0 of pattern flight?
      if stack>0 and mstack>stack then
      
        -- Decrease stack/flag by one ==> AI will go lower.
        -- TODO: If we include the recovery tanker, this needs to be generalized.
        mflight.flag:Set(mstack-1)
        
        -- Inform players.
        if mflight.ai==false and mflight.difficulty~=AIRBOSS.Difficulty.HARD then
          local alt=UTILS.MetersToFeet(self:_GetMarshalAltitude(mstack-1, case))
          local text=string.format("descent to next lower stack at %d ft", alt)
          self:MessageToPlayer(mflight, text, "MARSHAL")
        end
        
        -- Debug info.
        self:I(string.format("Flight %s case %d is changing marshal stack %d --> %d.", mflight.groupname, mflight.case, mstack, mstack-1))
        
        -- Loop over section members.
        for _,_sec in pairs(mflight.section) do
          local sec=_sec --#AIRBOSS.PlayerData
          
          -- Also decrease flag for section members of flight.
          sec.flag:Set(mstack-1)
          
          -- Inform section member.
          if sec.difficulty~=AIRBOSS.Difficulty.HARD then
            local alt=UTILS.MetersToFeet(self:_GetMarshalAltitude(mstack-1,case))
            local text=string.format("follow your lead to next lower stack at %d ft", alt)
            self:MessageToPlayer(sec, text, "MARSHAL")
          end                    
        end
        
      end
      
    end    
  end
  
  
  if nopattern then
  
    -- Debug
    self:I(self.lid..string.format("Flight %s is leaving stack but not going to pattern.", flight.groupname))

    -- Set flag to -1. -1 is rather arbitrary. Should not be -100 or positive.
    flight.flag:Set(-1)
      
  else

    -- Debug
    local Tmarshal=UTILS.SecondsToClock(timer.getAbsTime()-flight.time)
    self:I(self.lid..string.format("Flight %s is leaving marshal after %s and going pattern.", flight.groupname, Tmarshal))
    
    -- Decrease flag.
    flight.flag:Set(stack-1)
    
    -- Add flight to pattern queue.
    table.insert(self.Qpattern, flight)
        
  end

  -- New time stamp for time in pattern.
  flight.time=timer.getAbsTime()

  
  -- Remove flight from marshal queue.
  self:_RemoveGroupFromQueue(self.Qmarshal, flight.group)
  
end

--- Get next free stack depending on recovery case. Note that here we assume one flight group per stack!
-- @param #AIRBOSS self
-- @param #number case Recovery case. Default current (self) case in progress.
-- @return #number Lowest free stack available for the given case.
function AIRBOSS:_GetFreeStack(case)
  
  -- Recovery case.
  case=case or self.case
  
  -- Get stack 
  local nfull
  if case==1 then
    -- Lowest Case I stack.
    nfull=self:_GetQueueInfo(self.Qmarshal, 1)
  else
    -- Lowest Case II or III stack.
    nfull=self:_GetQueueInfo(self.Qmarshal, 23)
  end
  
  -- Simple case without a recovery tanker for now.
  local nfree=nfull+1

  --[[
  -- Get recovery tanker stack.
  local tankerstack=9999
  if self.tanker and case==1 then
    tankerstack=self:_GetAngels(self.tanker.altitude)
  end
  
  if nfull<tankerstack-1 then
    -- Free stack is simply the next.
    nfree=nfull+1
  else
    -- Here one more because of the tanker.
    nfree=nfull+2
  end
  ]]
  
  return nfree
end


--- Get number of groups and units in queue.
-- @param #AIRBOSS self
-- @param #table queue The queue. Can be self.flights, self.Qmarshal or self.Qpattern.
-- @param #number case (Optional) Only count flights, which are in a specific recovery case. Note that you can use case=23 for flights that are either in Case II or III. By default all groups/units regardless of case are counted.
-- @return #number Total number of flight groups in queue.
-- @return #number Total number of aircraft in queue since each flight group can contain multiple aircraft.
function AIRBOSS:_GetQueueInfo(queue, case)

  local ngroup=0
  local nunits=0
  
  -- Loop over flight groups.
  for _,_flight in pairs(queue) do
    local flight=_flight --#AIRBOSS.FlightGroup
    
    -- Check if a specific case was requested.
    if case then
    
      -- Only count specific case with special 23 = CASE II and III combined.
      if (flight.case==case) or (case==23 and (flight.case==2 or flight.case==3)) then
        ngroup=ngroup+1
        nunits=nunits+flight.nunits
      end
      
    else
    
      -- No specific case requested. Count all groups & units in selected queue.
      ngroup=ngroup+1
      nunits=nunits+flight.nunits
      
    end
    
  end

  return ngroup, nunits
end

--- Print holding queue.
-- @param #AIRBOSS self
-- @param #table queue Queue to print.
-- @param #string name Queue name.
function AIRBOSS:_PrintQueue(queue, name)

  local nqueue=#queue

  local text=string.format("%s Queue N=%d:", name, nqueue)
  if nqueue==0 then
    text=text.." empty."
  else
    for i,_flight in pairs(queue) do
      local flight=_flight --#AIRBOSS.FlightGroup
      
      -- Timestamp.
      --local clock=UTILS.SecondsToClock(timer.getAbsTime()-flight.time)
      local clock=timer.getAbsTime()-flight.time
      -- Recovery case of flight.
      local case=flight.case
      -- Stack and stack alt.
      local stack=flight.flag:Get()
      local alt=UTILS.MetersToFeet(self:_GetMarshalAltitude(stack, case))
      -- Fuel %.
      local fuel=flight.group:GetFuelMin()*100
      --local fuelstate=self:_GetFuelState(unit) 
      local ai=tostring(flight.ai)
      --flight.onboard
      local lead=flight.seclead
      local nsec=#flight.section
      local actype=flight.actype
      local onboard=flight.onboard
      local holding="false"
      if flight.holding then
        holding="true"
      end
      
      -- TODO: Include player data.
      --[[
      if not flight.ai then
        local playerData=_flight --#AIRBOSS.PlayerData
        e=playerData.name
        c=playerData.difficulty        
        f=playerData.passes
        g=playerData.step
        j=playerData.warning                        
        a=playerData.holding
        b=playerData.landed
        d=playerData.boltered        
        h=playerData.lig
        i=playerData.patternwo        
        k=playerData.waveoff
      end
      ]]
      text=text..string.format("\n[%d] %s*%d (%s): lead=%s (%d), onboard=%s, flag=%d, case=%d, time=%d, fuel=%d, ai=%s, holding=%s",
                                 i, flight.groupname, flight.nunits, actype, lead, nsec, onboard, stack, case, clock, fuel, ai, holding)
      if flight.holding then
        text=text..string.format(" stackalt=%d ft", alt)
      end
    end
  end
  self:I(self.lid..text)
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- FLIGHT & PLAYER functions
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Create a new flight group. Usually when a flight appears in the CCA.
-- @param #AIRBOSS self
-- @param Wrapper.Group#GROUP group Aircraft group.
-- @return #AIRBOSS.FlightGroup Flight group.
function AIRBOSS:_CreateFlightGroup(group)

  -- Debug info.
  self:I(self.lid..string.format("Creating new flight for group %s of aircraft type %s.", group:GetName(), group:GetTypeName()))
  
  -- New flight.
  local flight={} --#AIRBOSS.FlightGroup
  
  -- Check if not already in flights
  if not self:_InQueue(self.flights, group) then

    -- Flight group name
    local groupname=group:GetName()
    local human, playername=self:_IsHuman(group)
    
    -- Queue table item.    
    flight.group=group
    flight.groupname=group:GetName()
    flight.nunits=#group:GetUnits()
    flight.time=timer.getAbsTime()
    flight.dist0=group:GetCoordinate():Get2DDistance(self:GetCoordinate())
    flight.flag=USERFLAG:New(groupname)
    flight.flag:Set(-100)
    flight.ai=not human
    flight.actype=group:GetTypeName()
    flight.onboardnumbers=self:_GetOnboardNumbers(group)
    flight.seclead=flight.group:GetUnit(1):GetName()  -- Sec lead is first unitname of group but player name for players.
    flight.section={}
    flight.ballcall=false
    flight.holding=nil
    
    -- Note, this should be re-set elsewhere!
    flight.case=self.case
    
    -- Flight elements.
    local text=string.format("Flight elemets of group %s:", flight.groupname)
    flight.elements={}
    local units=group:GetUnits()
    for i,_unit in pairs(units) do
      local unit=_unit --Wrapper.Unit#UNIT
      local name=unit:GetName()
      local element={} --#AIRBOSS.FlightElement
      element.unit=unit
      element.onboard=flight.onboardnumbers[name]
      element.ballcall=false
      --element.ai=
      text=text..string.format("\n[%d] %s onboard #%s", i, name, tostring(element.onboard))
      table.insert(flight.elements, element)
    end
    self:I(self.lid..text)  
    
    -- Onboard
    if flight.ai then
      local onboard=flight.onboardnumbers[flight.seclead]
      flight.onboard=onboard
    else
      flight.onboard=self:_GetOnboardNumberPlayer(group)
    end
      
    -- Add to known flights.
    table.insert(self.flights, flight)
    
  else
    self:E(self.lid..string.format("ERROR: Flight group %s already exists in self.flights!", group:GetName()))
    return nil
  end

  return flight
end


--- Initialize player data after birth event of player unit.
-- @param #AIRBOSS self
-- @param #string unitname Name of the player unit.
-- @return #AIRBOSS.PlayerData Player data.
function AIRBOSS:_NewPlayer(unitname)

  -- Get player unit and name.
  local playerunit, playername=self:_GetPlayerUnitAndName(unitname)
  
  if playerunit and playername then
  
    local group=playerunit:GetGroup()

    -- Player data.
    local playerData --#AIRBOSS.PlayerData
    
    -- Create a flight group for the player.
    playerData=self:_CreateFlightGroup(group)
    
    -- Player unit, client and callsign.
    playerData.unit     = playerunit
    playerData.name     = playername
    playerData.callsign = playerData.unit:GetCallsign()
    playerData.client   = CLIENT:FindByName(unitname, nil, true)
    playerData.seclead  = playername
        
    -- Number of passes done by player.
    playerData.passes=playerData.passes or 0
      
    -- LSO grades.
    playerData.grades=playerData.grades or {}
    
    -- Attitude monitor.
    playerData.attitudemonitor=false
    
    -- Set difficulty level.
    playerData.difficulty=playerData.difficulty or AIRBOSS.Difficulty.EASY
  
    -- Init stuff for this round.
    playerData=self:_InitPlayer(playerData)
    
    -- Return player data table.
    return playerData    
  end
  
  return nil
end

--- Initialize player data by (re-)setting parmeters to initial values.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data.
-- @return #AIRBOSS.PlayerData Initialized player data.
function AIRBOSS:_InitPlayer(playerData)
  self:I(self.lid..string.format("Initializing player data for %s callsign %s.", playerData.name, playerData.callsign))
  
  playerData.step=AIRBOSS.PatternStep.UNDEFINED  
  playerData.groove={}
  playerData.debrief={}
  playerData.warning=nil
  playerData.holding=nil
  playerData.lig=false
  playerData.patternwo=false
  playerData.waveoff=false
  playerData.boltered=false
  playerData.landed=false
  playerData.Tlso=timer.getTime()
  playerData.Tgroove=nil
  playerData.wire=nil
  playerData.ballcall=false
  
  -- Set us up on final if group name contains "Groove". But only for the first pass.
  if playerData.group:GetName():match("Groove") and playerData.passes==0 then
    self:MessageToPlayer(playerData, "Group name contains \"Groove\". Happy groove testing.")
    playerData.step=AIRBOSS.PatternStep.FINAL
  end
  
  return playerData
end


--- Get flight from group. 
-- @param #AIRBOSS self
-- @param Wrapper.Group#GROUP group Group that will be removed from queue.
-- @param #table queue The queue from which the group will be removed.
-- @return #AIRBOSS.FlightGroup Flight group.
-- @return #number Queue index.
function AIRBOSS:_GetFlightFromGroupInQueue(group, queue)

  -- Group name
  local name=group:GetName()
  
  -- Loop over all flight groups in queue
  for i,_flight in pairs(queue) do
    local flight=_flight --#AIRBOSS.FlightGroup
    
    if flight.groupname==name then
      return flight, i
    end
  end

  self:T2(self.lid..string.format("WARNING: Flight group %s could not be found in queue.", name))
  return nil, nil
end

--- Get element in flight. 
-- @param #AIRBOSS self
-- @param #string unitname Name of the unit.
-- @param #AIRBOSS.FlightGroup flight Flight group.
-- @return #AIRBOSS.FlightElement Flight element.
-- @return #number Element index.
function AIRBOSS:_GetFlightElement(unitname, flight)

  -- Loop over all elements in flight group.
  for i,_element in pairs(flight.elements) do
    local element=_element --#AIRBOSS.FlightElement
    
    if element.unit:GetName()==unitname then
      return element, i
    end
  end
  
  self:T2(self.lid..string.format("WARNING: Flight element %s could not be found in flight group.", unitname, flight.groupname))
  return nil, nil
end

--- Get element in flight. 
-- @param #AIRBOSS self
-- @param #string unitname Name of the unit.
-- @param #AIRBOSS.FlightGroup flight Flight group.
function AIRBOSS:_RemoveFlightElement(unitname, flight)

  -- Get table index.
  local element,idx=self:_GetFlightElement(unitname,flight)

  if idx then
    table.remove(flight.elements, idx)
  else
    self:E("ERROR: Flight element could not be removed from flight group. Index=nil!")
  end
end

--- Check if a group is in a queue.
-- @param #AIRBOSS self
-- @param #table queue The queue to check.
-- @param Wrapper.Group#GROUP group The group to be checked.
-- @return #boolean If true, group is in the queue. False otherwise.
function AIRBOSS:_InQueue(queue, group)
  local name=group:GetName()
  for _,_flight in pairs(queue) do
    local flight=_flight  --#AIRBOSS.FlightGroup
    if name==flight.groupname then
      return true
    end
  end
  return false
end


--- Remove a flight group.
-- @param #AIRBOSS self
-- @param Wrapper.Group#GROUP group Aircraft group.
-- @return #AIRBOSS.FlightGroup Flight group.
function AIRBOSS:_RemoveFlightGroup(group)
  local groupname=group:GetName()
  for i,_flight in pairs(self.flights) do
    local flight=_flight --#AIRBOSS.FlightGroup
    if flight.groupname==groupname then
      self:I(string.format("Removing flight group %s (not in CCA).", groupname))
      table.remove(self.flights, i)
      return
    end
  end
end

--- Remove a flight group from a queue.
-- @param #AIRBOSS self
-- @param #table queue The queue from which the group will be removed.
-- @param #AIRBOSS.FlightGroup flight Flight group that will be removed from queue.
function AIRBOSS:_RemoveFlightFromQueue(queue, flight)

  -- Loop over all flights in group.
  for i,_flight in pairs(queue) do
    local qflight=_flight --#AIRBOSS.FlightGroup
    
    -- Check for name.
    if qflight.groupname==flight.groupname then
      self:I(self.lid..string.format("Removing flight group %s from queue.", flight.groupname))
      table.remove(queue, i)
      return
    end
  end
  
end


--- Remove a group from a queue.
-- @param #AIRBOSS self
-- @param #table queue The queue from which the group will be removed.
-- @param Wrapper.Group#GROUP group Group that will be removed from queue.
function AIRBOSS:_RemoveGroupFromQueue(queue, group)

  -- Group name.
  local name=group:GetName()
    
  -- Loop over all flights in group.
  for i,_flight in pairs(queue) do
    local flight=_flight --#AIRBOSS.FlightGroup
    
    -- Check for name.
    if flight.groupname==name then
      self:I(self.lid..string.format("Removing group %s from queue.", name))
      table.remove(queue, i)
      return
    end
  end
  
end

--- Remove a unit from a flight group (e.g. when landed) and update all queues if the whole flight group is gone.
-- @param #AIRBOSS self
-- @param Wrapper.Unit#UNIT unit The unit to be removed.
function AIRBOSS:_RemoveUnitFromFlight(unit)

  -- Check if unit exists.
  if unit then

    -- Get group.
    local group=unit:GetGroup()
    
    -- Check if group exists.
    if group then
    
      -- Get flight.
      local flight=self:_GetFlightFromGroupInQueue(group, self.flights)
      
      -- Check if flight exists.
      if flight then

        -- Remove element from flight group.
        self:_RemoveFlightElement(unit:GetName(), flight)
        
        -- Decrease number of units in group.
        flight.nunits=flight.nunits-1
        
        -- Check if numbers still match.
        if #flight.elements~=flight.nunits then
          self:E("ERROR: Number of elements != number of units in flight!")
        end
                
        -- Check if no units are left.
        if flight.nunits==0 then
          -- Remove flight from all queues.
          self:_RemoveFlight(flight)
        end
              
      end    
    end
  end
  
end

--- Remove a flight from all queues. Also set player step to undefined if applicable.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData flight The flight to be removed.
function AIRBOSS:_RemoveFlight(flight)

  -- Remove flight from all queues.
  self:_RemoveFlightFromQueue(self.Qmarshal, flight)
  self:_RemoveFlightFromQueue(self.Qpattern, flight)
  
  -- Check if player or AI
  if flight.ai then  
    -- Remove AI flight completely.
    self:_RemoveFlightFromQueue(self.flights, flight)
  else
    -- Set Playerstep to undefined.
    flight.step=AIRBOSS.PatternStep.UNDEFINED
  end
  
end

--- Check if heading or position of carrier have changed significantly.
-- @param #AIRBOSS self
function AIRBOSS:_CheckPatternUpdate()

  -- TODO: Make parameters input values.

  -- Min 10 min between pattern updates.
  local dTPupdate=10*60
  
  -- Update if carrier moves by more than 2.5 NM.
  local Dupdate=UTILS.NMToMeters(2.5)
  
  -- Update if carrier turned by more than 5 degrees.
  local Hupdate=5
  
  -- Time since last pattern update
  local dt=timer.getTime()-self.Tpupdate
  
  -- At least 10 min between updates. Not yet...
  if dt<dTPupdate then
    return
  end

  -- Get current position and orientation of carrier.
  local pos=self:GetCoordinate()
  
  -- Current orientation of carrier.
  local vNew=self.carrier:GetOrientationX()
  
  -- Reference orientation of carrier after the last update.
  local vOld=self.Corientation
  
  -- Last orientation from 30 seconds ago.
  local vLast=self.Corientlast
  
  -- We only need the X-Z plane.
  vNew.y=0 ; vOld.y=0 ; vLast.y=0
  
  -- Get angle between old and new orientation vectors in rad and convert to degrees.
  local deltaHeading=math.deg(math.acos(UTILS.VecDot(vNew,vOld)/UTILS.VecNorm(vNew)/UTILS.VecNorm(vOld)))
  
  -- Angle between current heading and last time we checked ~30 seconds ago.
  local deltaLast=math.deg(math.acos(UTILS.VecDot(vNew,vLast)/UTILS.VecNorm(vNew)/UTILS.VecNorm(vLast)))
  
  -- Last orientation becomes new orientation
  self.Corientlast=vNew
  
  -- Carrier is turning when its heading changed by at least one degree since last check.
  local turning=deltaLast>=1
  
  -- No update if carrier is turning!
  if turning then
    self:T2(self.lid..string.format("Carrier is turning. Delta Heading = %.1f", deltaLast))
    return
  end

  -- Check if orientation changed.
  local Hchange=false
  if math.abs(deltaHeading)>=Hupdate then
    self:T(self.lid..string.format("Carrier heading changed by %d degrees. Turning=%s.", deltaHeading, tostring(turning)))
    Hchange=true
  end
  
  -- Get distance to saved position.
  local dist=pos:Get2DDistance(self.Cposition)
  
  -- Check if carrier moved more than ~10 km.
  local Dchange=false
  if dist>=Dupdate then
    self:T(self.lid..string.format("Carrier position changed by %.1f NM. Turning=%s.", UTILS.MetersToNM(dist), tostring(turning)))
    Dchange=true
  end

  -- If heading or distance changed ==> update marshal AI patterns.
  if Hchange or Dchange then
      
    -- Loop over all marshal flights
    for _,_flight in pairs(self.Qmarshal) do
      local flight=_flight --#AIRBOSS.FlightGroup
      
      -- Update marshal pattern of AI keeping the same stack.
      if flight.ai then
        self:_MarshalAI(flight, flight.flag:Get())
      end
      
    end
    
    -- Reset parameters for next update check.
    self.Corientation=vNew
    self.Cposition=pos
    self.Tpupdate=timer.getTime()        
  end

end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Player Status
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Check current player status.
-- @param #AIRBOSS self
function AIRBOSS:_CheckPlayerStatus()

  -- Loop over all players.
  for _playerName,_playerData in pairs(self.players) do  
    local playerData=_playerData --#AIRBOSS.PlayerData
    
    if playerData then
    
      -- Player unit.
      local unit=playerData.unit
      
      -- Check if unit is alive and in air.
      if unit:IsAlive() then
      
        -- Display aircraft attitude and other parameters as message text.
        if playerData.attitudemonitor then
          self:_DetailedPlayerStatus(playerData)
        end

        -- Check if player is in carrier controlled area (zone with R=50 NM around the carrier).
        if unit:IsInZone(self.zoneCCA) then
        
          -- Check if player is too close to another aircraft in the pattern.
          -- TODO: At which steps is the really necessary. Case II/III?
          if  playerData.step==AIRBOSS.PatternStep.INITIAL or
              playerData.step==AIRBOSS.PatternStep.BREAKENTRY or
              playerData.step==AIRBOSS.PatternStep.EARLYBREAK or              
              playerData.step==AIRBOSS.PatternStep.LATEBREAK or
              playerData.step==AIRBOSS.PatternStep.ABEAM or
              playerData.step==AIRBOSS.PatternStep.GROOVE_XX or
              playerData.step==AIRBOSS.PatternStep.GROOVE_IM then
            self:_CheckPlayerPatternDistance(playerData)
          end
                 
          if playerData.step==AIRBOSS.PatternStep.UNDEFINED then
            
            -- Status undefined.
            local time=timer.getAbsTime()
            local clock=UTILS.SecondsToClock(time)
            self:T3(string.format("Player status undefined. Waiting for next step. Time %s", clock))

          elseif playerData.step==AIRBOSS.PatternStep.REFUELING then
          
            -- Nothing to do here at the moment.
            
          elseif playerData.step==AIRBOSS.PatternStep.SPINNING then
          
            -- Might still be better to stay in commencing?

          elseif playerData.step==AIRBOSS.PatternStep.HOLDING then
          
            -- CASE I/II/III: In holding pattern.
            self:_Holding(playerData)
          
          elseif playerData.step==AIRBOSS.PatternStep.COMMENCING then
          
            -- CASE I/II/III: New approach.
            self:_Commencing(playerData)
          
          elseif playerData.step==AIRBOSS.PatternStep.PLATFORM then
          
            -- CASE II/III: Player has reached 5k "Platform".
            self:_Platform(playerData)
            
          elseif playerData.step==AIRBOSS.PatternStep.ARCIN then

            -- Case II/III if offset.          
            self:_ArcInTurn(playerData)
          
          elseif playerData.step==AIRBOSS.PatternStep.ARCOUT then
          
            -- Case II/III if offset.
            self:_ArcOutTurn(playerData)          
          
          elseif playerData.step==AIRBOSS.PatternStep.DIRTYUP then
          
            -- CASE III: Player has descended to 1200 ft and is going level from now on.
            self:_DirtyUp(playerData)
          
          elseif playerData.step==AIRBOSS.PatternStep.BULLSEYE then
          
            -- CASE III: Player has intercepted the glide slope and should follow "Bullseye" (ICLS).
            self:_Bullseye(playerData)
          
          elseif playerData.step==AIRBOSS.PatternStep.INITIAL then
          
            -- CASE I/II: Player is at the initial position entering the landing pattern.
            self:_Initial(playerData)
            
          elseif playerData.step==AIRBOSS.PatternStep.BREAKENTRY then
          
            -- CASE I/II: Break entry.
            self:_BreakEntry(playerData)
            
          elseif playerData.step==AIRBOSS.PatternStep.EARLYBREAK then
          
            -- CASE I/II: Early break.
            self:_Break(playerData, AIRBOSS.PatternStep.EARLYBREAK)
            
          elseif playerData.step==AIRBOSS.PatternStep.LATEBREAK then
          
            -- CASE I/II: Late break.
            self:_Break(playerData, AIRBOSS.PatternStep.LATEBREAK)
            
          elseif playerData.step==AIRBOSS.PatternStep.ABEAM then
          
            -- CASE I/II: Abeam position.
            self:_Abeam(playerData)
            
          elseif playerData.step==AIRBOSS.PatternStep.NINETY then
          
            -- CASE:I/II: Check long down wind leg.
            self:_CheckForLongDownwind(playerData)
            
            -- At the ninety.
            self:_Ninety(playerData)
            
          elseif playerData.step==AIRBOSS.PatternStep.WAKE then
          
            -- CASE I/II: In the wake.
            self:_Wake(playerData)
            
          elseif playerData.step==AIRBOSS.PatternStep.FINAL then
          
            -- CASE I/II: Turn to final and enter the groove.
            self:_Final(playerData)
            
          elseif playerData.step==AIRBOSS.PatternStep.GROOVE_XX or
                 playerData.step==AIRBOSS.PatternStep.GROOVE_RB or
                 playerData.step==AIRBOSS.PatternStep.GROOVE_IM or
                 playerData.step==AIRBOSS.PatternStep.GROOVE_IC or
                 playerData.step==AIRBOSS.PatternStep.GROOVE_AR or
                 playerData.step==AIRBOSS.PatternStep.GROOVE_IW then
          
            -- CASE I/II: In the groove.
            self:_Groove(playerData)
            
          elseif playerData.step==AIRBOSS.PatternStep.DEBRIEF then
          
            -- Debriefing in 10 seconds.
            SCHEDULER:New(nil, self._Debrief, {self, playerData}, 10)
            
            -- Undefined status.
            playerData.step=AIRBOSS.PatternStep.UNDEFINED
            
          else
          
            self:E(self.lid..string.format("ERROR: Unknown player step %s. Please report!", tostring(playerData.step)))
            
          end
          
        else
          self:E(self.lid.."WARNING: Player left the CCA!")
        end
        
      else
        -- Unit not alive.
        self:E(self.lid.."WARNING: Player unit is not alive!")
      end
    end
  end
  
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- EVENT functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Airboss event handler for event birth.
-- @param #AIRBOSS self
-- @param Core.Event#EVENTDATA EventData
function AIRBOSS:OnEventBirth(EventData)
  self:F3({eventbirth = EventData})
  
  local _unitName=EventData.IniUnitName
  local _unit, _playername=self:_GetPlayerUnitAndName(_unitName)
  
  self:T3(self.lid.."BIRTH: unit   = "..tostring(EventData.IniUnitName))
  self:T3(self.lid.."BIRTH: group  = "..tostring(EventData.IniGroupName))
  self:T3(self.lid.."BIRTH: player = "..tostring(_playername))
      
  if _unit and _playername then
  
    local _uid=_unit:GetID()
    local _group=_unit:GetGroup()
    local _callsign=_unit:GetCallsign()
    
    -- Debug output.
    local text=string.format("AIRBOSS: Pilot %s, callsign %s entered unit %s of group %s.", _playername, _callsign, _unitName, _group:GetName())
    self:T(self.lid..text)
    MESSAGE:New(text, 5):ToAllIf(self.Debug or true)
    
    -- Check if aircraft type the player occupies is carrier capable.
    local rightaircraft=self:_IsCarrierAircraft(_unit)
    if rightaircraft==false then
      local text=string.format("Player aircraft type %s not supported by AIRBOSS class.", _unit:GetTypeName())
      MESSAGE:New(text, 30):ToAllIf(self.Debug)
      self:T(self.lid..text)
      return
    end
        
    -- Add Menu commands.
    self:_AddF10Commands(_unitName)
    
    -- Init player data.
    self.players[_playername]=self:_NewPlayer(_unitName)
    
    -- Debug.    
    if self.Debug and false then
      self:_Number2Sound(self.LSORadio,     "0123456789", 10)
      self:_Number2Sound(self.MarshalRadio, "0123456789", 20)
    end
    
  end 
end

--- Airboss event handler for event land.
-- @param #AIRBOSS self
-- @param Core.Event#EVENTDATA EventData
function AIRBOSS:OnEventLand(EventData)
  self:F3({eventland = EventData})
  
  -- Get unit name that landed.
  local _unitName=EventData.IniUnitName
  
  -- Check if this was a player.
  local _unit, _playername=self:_GetPlayerUnitAndName(_unitName)
  
  -- Debug output.
  self:T3(self.lid.."LAND: unit   = "..tostring(EventData.IniUnitName))
  self:T3(self.lid.."LAND: group  = "..tostring(EventData.IniGroupName))
  self:T3(self.lid.."LAND: player = "..tostring(_playername))
      
  -- Check if player or AI landed.
  if _unit and _playername then
    -- Human Player landed.
  
    local _uid=_unit:GetID()
    local _group=_unit:GetGroup()
    local _callsign=_unit:GetCallsign()
    
    -- This would be the closest airbase.
    local airbase=EventData.Place
    local airbasename=tostring(airbase:GetName())
    
    -- TODO: also check distance to airbase since landing "in the water" also trigger a landing event!
    
    -- Check if player landed on the right airbase.
    if airbasename==self.airbase:GetName() then
    
      -- Debug output.
      local text=string.format("Player %s, callsign %s unit %s (ID=%d) of group %s landed at airbase %s", _playername, _callsign, _unitName, _uid, _group:GetName(), airbasename)
      self:I(self.lid..text)
      MESSAGE:New(text, 5, "DEBUG"):ToAllIf(self.Debug)
      
      -- Player data.
      local playerData=self.players[_playername] --#AIRBOSS.PlayerData
      
      -- Coordinate at landing event
      local coord=playerData.unit:GetCoordinate()
            
      -- Get distances relative to
      local X,Z,rho,phi=self:_GetDistances(_unit)
      
      -- Landing distance to carrier position.
      local dist=coord:Get2DDistance(self:GetCoordinate())
      
      -- Correct sign if necessary.
      if X<0 then
        dist=-dist
      end
      
      -- Debug output
      if self.Debug then
        local hdg=self.carrier:GetHeading()+self.carrierparam.rwyangle
        
        -- Debug marks of wires.
        local w1=self:GetCoordinate():Translate(self.carrierparam.wire1, hdg):MarkToAll("Wire 1a")
        local w2=self:GetCoordinate():Translate(self.carrierparam.wire2, hdg):MarkToAll("Wire 2a")
        local w3=self:GetCoordinate():Translate(self.carrierparam.wire3, hdg):MarkToAll("Wire 3a")
        local w4=self:GetCoordinate():Translate(self.carrierparam.wire4, hdg):MarkToAll("Wire 4a")
        
        -- Debug mark of player landing coord.
        local lp=coord:MarkToAll("Landing coord.")
        coord:SmokeGreen()        
      end
      
      -- Get wire.
      local wire=self:_GetWire(self:GetCoordinate(), coord)
      
      -- No wire ==> Bolter, Bolter radio call.
      if wire>4 then
        self:RadioTransmission(self.LSORadio, AIRBOSS.LSOCall.BOLTER)
      end
      
      -- Get time in the groove.
      local gdataX0=playerData.groove.X0 --#AIRBOSS.GrooveData
      playerData.Tgroove=timer.getTime()-gdataX0.TGroove
      
      -- Set player wire
      playerData.wire=wire      
      
      -- Aircraft type.
      local _type=EventData.IniUnit:GetTypeName()
      
      -- Debug text.
      local text=string.format("Player %s AC type %s landed at dist=%.1f m (+offset=%.1f). Trapped wire=%d.", EventData.IniUnitName, _type, dist, self.carrierparam.wireoffset, wire)
      text=text..string.format("X=%.1f m, Z=%.1f m, rho=%.1f m, phi=%.1f deg.", X, Z, rho, phi)
      self:I(self.lid..text)      
      
      -- We did land.
      playerData.landed=true
      
      -- Unkonwn step until we now more.
      playerData.step=AIRBOSS.PatternStep.UNDEFINED

      -- Call trapped function in 3 seconds to make sure we did not bolter.
      SCHEDULER:New(nil, self._Trapped,{self, playerData}, 3) 
    end
    
  else
    -- AI unit landed.
    
    -- Coordinate at landing event
    local coord=EventData.IniUnit:GetCoordinate()
    
    -- Debug mark of player landing coord.
    local dist=coord:Get2DDistance(self:GetCoordinate())
    
    -- Get wire
    local wire=self:_GetWire(self:GetCoordinate(), coord, 0)
    
    -- Aircraft type.
    local _type=EventData.IniUnit:GetTypeName()
    
    -- Debug text.
    local text=string.format("AI %s of type %s landed at dist=%.1f m. Trapped wire=%d.", EventData.IniUnitName, _type, dist, wire)
    self:I(self.lid..text)
    
    -- AI always lands ==> remove unit from flight group and queues.
    self:_RemoveUnitFromFlight(EventData.IniUnit) 
  end
    
end

--- Airboss event handler for event crash.
-- @param #AIRBOSS self
-- @param Core.Event#EVENTDATA EventData
function AIRBOSS:OnEventCrash(EventData)
  self:F3({eventland = EventData})

  local _unitName=EventData.IniUnitName
  local _unit, _playername=self:_GetPlayerUnitAndName(_unitName)
  
  self:T3(self.lid.."CRASH: unit   = "..tostring(EventData.IniUnitName))
  self:T3(self.lid.."CRASH: group  = "..tostring(EventData.IniGroupName))
  self:T3(self.lid.."CARSH: player = "..tostring(_playername))
  
  if _unit and _playername then
    self:I(self.lid..string.format("Player %s crashed!",_playername))
  else
    self:I(self.lid..string.format("AI unit %s crashed!", EventData.IniUnitName)) 
  end
  
  -- Remove unit from flight and queues.
  self:_RemoveUnitFromFlight(EventData.IniUnit)
end

--- Airboss event handler for event Ejection.
-- @param #AIRBOSS self
-- @param Core.Event#EVENTDATA EventData
function AIRBOSS:OnEventEjection(EventData)
  self:F3({eventland = EventData})

  local _unitName=EventData.IniUnitName
  local _unit, _playername=self:_GetPlayerUnitAndName(_unitName)
  
  self:T3(self.lid.."EJECT: unit   = "..tostring(EventData.IniUnitName))
  self:T3(self.lid.."EJECT: group  = "..tostring(EventData.IniGroupName))
  self:T3(self.lid.."EJECT: player = "..tostring(_playername))
  
  if _unit and _playername then
    self:I(self.lid..string.format("Player %s ejected!",_playername))
  else
    self:I(self.lid..string.format("AI unit %s ejected!", EventData.IniUnitName)) 
  end
  
  -- Remove unit from flight and queues.
  self:_RemoveUnitFromFlight(EventData.IniUnit)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- PATTERN functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Holding.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data.
function AIRBOSS:_Holding(playerData)

  -- Player unit and flight.
  local unit=playerData.unit
  
  -- Current stack.
  local stack=playerData.flag:Get()
  
  -- Pattern alitude.
  local patternalt=self:_GetMarshalAltitude(stack, playerData.case)
  
  -- Player altitude.
  local playeralt=unit:GetAltitude()
  
  -- Get holding zone of player.
  local zoneHolding=self:_GetZoneHolding(playerData.case, stack)
    
  -- Check if player is in holding zone.
  local inholdingzone=unit:IsInZone(zoneHolding)
  
  -- Check player alt is +-500 feet of assigned pattern alt.
  local altdiff=playeralt-patternalt
  local goodalt=math.abs(altdiff)<UTILS.MetersToFeet(500)
  
  -- TODO: check if player is flying counter clockwise. AOB<0.

  local text=""
  
  -- Different cases
  if playerData.holding==true then
    -- Player was in holding zone last time we checked.
    
    if inholdingzone then
      -- Player is still in holding zone.
      self:I("Player is still in the holding zone. Good job.")
    else
      -- Player left the holding zone.
      self:I("Player just left the holding zone. Come back!")
      text=text..string.format("You just left the holding zone. Watch your numbers!")
      playerData.holding=false
    end
    
  elseif playerData.holding==false then
  
    -- Player left holding zone
    if inholdingzone then
      -- Player is back in the holding zone.
      self:I("Player is back in the holding zone after leaving it.")
      text=text..string.format("You are back in the holding zone. Now stay there!")
      playerData.holding=true
    else
      -- Player is still outside the holding zone.
      self:I("Player still outside the holding zone. What are you doing man?!")
    end
    
  elseif playerData.holding==nil then
    -- Player did not entered the holding zone yet.
    
    if inholdingzone then
    
      -- Player arrived in holding zone.
      playerData.holding=true
      
      -- Debug output.
      self:I("Player entered the holding zone for the first time.")
      
      -- Inform player.
      text=text..string.format("You arrived at the holding zone.")
      
      -- Feedback on altitude.
      if goodalt then
        text=text..string.format(" Now stay at that altitude.")
      else
        if altdiff<0 then
          text=text..string.format(" But you are too low.")
        else
          text=text..string.format(" But you are too high.")
        end
        text=text..string.format(" Currently assigned altitude is %d ft.", UTILS.MetersToFeet(patternalt))
      end
    else
      -- Player did not yet arrive in holding zone.
      self:I("Waiting for player to arrive in the holding zone.")
    end
    
  end
  
  -- Send message.  
  self:MessageToPlayer(playerData, text, "MARSHAL", nil, 5)
end


--- Commence approach.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data.
function AIRBOSS:_Commencing(playerData) 
  
  -- Initialize player data for new approach.
  self:_InitPlayer(playerData)
    
  -- Commence
  local text=string.format("Commencing. (Case %d)", playerData.case)
  
  -- Message to all players.
  self:MessageToAll(text, playerData.onboard, "", 5)
  
  -- Next step: depends on case recovery.
  if playerData.case==1 then
    -- CASE I: Player has to fly to the initial which is 3 NM DME astern of the boat.
    playerData.step=AIRBOSS.PatternStep.INITIAL
  else
    -- CASE II/III: Player has to start the descent at 4000 ft/min to the platform at 5k ft.
    playerData.step=AIRBOSS.PatternStep.PLATFORM
  end
end

--- Start pattern when player enters the initial zone in case I/II recoveries.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data table.
function AIRBOSS:_Initial(playerData)

  -- Check if player is in initial zone and entering the CASE I pattern.
  if playerData.unit:IsInZone(self.zoneInitial) then
  
    -- Inform player.
    local hint=string.format("Initial")
    if playerData.difficulty==AIRBOSS.Difficulty.EASY then
      local alt,aoa,dist,speed=self:_GetAircraftParameters(playerData, AIRBOSS.PatternStep.BREAKENTRY)
      hint=hint..string.format("\nOptimal setup at the break entry is %d feet and %d kts.", UTILS.MetersToFeet(alt), UTILS.MpsToKnots(speed))
    end
    
    -- Send message for normal and easy difficulty.
    if playerData.difficulty~=AIRBOSS.Difficulty.HARD then
      self:MessageToPlayer(playerData, hint, "MARSHAL")
    end
  
    -- Next step: Break entry.
    playerData.step=AIRBOSS.PatternStep.BREAKENTRY
  end
  
end

--- Check if player is in CASE II/III approach corridor.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data table.
function AIRBOSS:_CheckCorridor(playerData)

  -- Check if player is in valid zone
  local validzone=self:_GetZoneCorridor(playerData.case)
  
  -- Check if we are inside the moving zone.
  local invalid=playerData.unit:IsNotInZone(validzone)
  
  -- Issue warning.
  if invalid and not playerData.warning then
    self:MessageToPlayer(playerData, "You left the valid approach corridor!", "MARSHAL")
    playerData.warning=true  
  end
  
  -- Back in zone.
  if not invalid and playerData.warning then
    self:MessageToPlayer(playerData, "You're back in the approach corridor. Now stay there!", "MARSHAL")
    playerData.warning=false
  end  

end

--- Platform at 5k ft for case II/III recoveries. Descent at 2000 ft/min.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data table.
function AIRBOSS:_Platform(playerData)
  
  -- Check if player left or got back to the approach corridor.
  self:_CheckCorridor(playerData)
    
  -- Check if we are inside the moving zone.
  local inzone=playerData.unit:IsInZone(self:_GetZonePlatform(playerData.case))
  
  -- Check if we are in zone.
  if inzone then
  
    -- Debug message.
    MESSAGE:New("Platform step reached", 5, "DEBUG"):ToAllIf(self.Debug)
  
    -- Get optimal altitiude.
    local altitude, aoa, distance, speed =self:_GetAircraftParameters(playerData)
  
    -- Get altitude hint.
    local hintAlt=self:_AltitudeCheck(playerData, altitude)
    
    -- Get altitude hint.
    local hintSpeed=self:_SpeedCheck(playerData, speed)    
    
    -- Message to player.
    if playerData.difficulty~=AIRBOSS.Difficulty.HARD then
      local hint=string.format("%s\n%s\n%s", playerData.step, hintAlt, hintSpeed)
      self:MessageToPlayer(playerData, hint, "MARSHAL", "")
    end
        
    -- Next step: depends.
    if math.abs(self.holdingoffset)>0 then
      -- Turn to BRC (case II) or FB (case III).
      playerData.step=AIRBOSS.PatternStep.ARCIN
    else
      if playerData.case==2 then
        -- Case II: Initial zone then Case I recovery.
        playerData.step=AIRBOSS.PatternStep.INITIAL
      elseif playerData.case==3 then
        -- CASE III: Dirty up.
        playerData.step=AIRBOSS.PatternStep.DIRTYUP
      end
    end
    playerData.warning=nil
  end
end


--- Arc in turn for case II/III recoveries.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data table.
function AIRBOSS:_ArcInTurn(playerData)

  -- Check if player left or got back to the approach corridor.
  self:_CheckCorridor(playerData)
  
  -- Check if we are inside the moving zone.
  local inzone=playerData.unit:IsInZone(self:_GetZoneArcIn(playerData.case))
  
  if inzone then
    
    -- Debug message.
    MESSAGE:New("Arc Turn In step reached", 5, "DEBUG"):ToAllIf(self.Debug)
  
    -- Get optimal altitiude.
    local altitude, aoa, distance, speed=self:_GetAircraftParameters(playerData)
  
    -- Get speed hint.
    local hintSpeed=self:_SpeedCheck(playerData, speed)        

    -- Message to player.
    if playerData.difficulty~=AIRBOSS.Difficulty.HARD then
      local hint=string.format("%s\n%s", playerData.step, hintSpeed)
      self:MessageToPlayer(playerData, hint, "MARSHAL", "")
    end
        
    -- Next step: Arc Out Turn.
    playerData.step=AIRBOSS.PatternStep.ARCOUT   
    playerData.warning=nil
  end
end

--- Arc out turn for case II/III recoveries.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data table.
function AIRBOSS:_ArcOutTurn(playerData)

  -- Check if player left or got back to the approach corridor.
  self:_CheckCorridor(playerData)
  
  -- Check if we are inside the moving zone.
  local inzone=playerData.unit:IsInZone(self:_GetZoneArcOut(playerData.case))
  
  --if self:_CheckLimits(X, Z, self.DirtyUp) then
  if inzone then
    
    -- Debug message.
    MESSAGE:New("Arc Turn Out step reached", 5, "DEBUG"):ToAllIf(self.Debug)
  
    -- Get optimal altitiude.
    local altitude, aoa, distance, speed=self:_GetAircraftParameters(playerData)
  
    -- Get speed hint.
    local hintSpeed=self:_SpeedCheck(playerData, speed)        

    -- Message to player.
    if playerData.difficulty~=AIRBOSS.Difficulty.HARD then
      local hint=string.format("%s\n%s", playerData.step, hintSpeed)
      self:MessageToPlayer(playerData, hint, "MARSHAL", "")
    end
        
    -- Next step:
    if playerData.case==2 then
      -- Case II: Initial.
      playerData.step=AIRBOSS.PatternStep.INITIAL
    elseif playerData.case==3 then
      -- Case III: Dirty up.
      playerData.step=AIRBOSS.PatternStep.DIRTYUP
    else
      -- ERROR!
    end    
    playerData.warning=nil
  end
end

--- Dirty up and level out at 1200 ft for case III recovery.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data table.
function AIRBOSS:_DirtyUp(playerData)

  -- Check if player left or got back to the approach corridor.
  self:_CheckCorridor(playerData)

  -- Check if we are inside the moving zone.
  local inzone=playerData.unit:IsInZone(self:_GetZoneDirtyUp(playerData.case))  
  
  if inzone then
    
    -- Debug message.
    MESSAGE:New("Dirty up step reached", 5, "DEBUG"):ToAllIf(self.Debug)
  
    -- Get optimal altitiude.
    local altitude, aoa, distance, speed=self:_GetAircraftParameters(playerData)
  
    -- Get altitude hint.
    local hintAlt, debrief=self:_AltitudeCheck(playerData, altitude)

    -- Get speed hint.
    -- TODO: Not sure if we already need to be onspeed AoA at this point?
    local hintSpeed=self:_SpeedCheck(playerData, speed)        

    -- Message to player.
    if playerData.difficulty~=AIRBOSS.Difficulty.HARD then
      local hint=string.format("%s\n%s\n%s", playerData.step, hintAlt, hintSpeed)
      self:MessageToPlayer(playerData, hint, "MARSHAL", "")
    end
        
    -- Next step: CASE III: Intercept glide slope and follow bullseye (ICLS).
    playerData.step=AIRBOSS.PatternStep.BULLSEYE    
    playerData.warning=nil
  end
end

--- Intercept glide slop and follow ICLS, aka Bullseye for case III recovery.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data table.
function AIRBOSS:_Bullseye(playerData)

  -- Check if player left or got back to the approach corridor.
  self:_CheckCorridor(playerData)

  -- Check if we are inside the moving zone.
  local inzone=playerData.unit:IsInZone(self:_GetZoneBullseye(playerData.case))
  
  -- Check that we reached the position.
  --if self:_CheckLimits(X, Z, self.Bullseye) then
  if inzone then
    
    -- Debug message.
    MESSAGE:New("Bullseye step reached", 5, "DEBUG"):ToAllIf(self.Debug)
  
    -- Get optimal altitiude.
    local altitude, aoa, distance, speed=self:_GetAircraftParameters(playerData)
  
    -- Get altitude hint.
    local hintAlt=self:_AltitudeCheck(playerData, altitude)

    -- Get altitude hint.
    local hintAoA=self:_AoACheck(playerData, aoa)
    
    -- Message to player.
    if playerData.difficulty~=AIRBOSS.Difficulty.HARD then
      local hint=string.format("%s\n%s\n%s", playerData.step, hintAlt, hintAoA)
      self:MessageToPlayer(playerData, hint, "MARSHAL", "")
    end
    
    -- Next step: Groove Call the ball.
    playerData.step=AIRBOSS.PatternStep.GROOVE_XX  
    playerData.warning=nil
  end
end
 

--- Break entry for case I/II recoveries.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data table.
function AIRBOSS:_BreakEntry(playerData)

  -- Get distances between carrier and player unit (parallel and perpendicular to direction of movement of carrier)
  local X, Z, rho, phi=self:_GetDistances(playerData.unit)
  
  -- Abort condition check.
  if self:_CheckAbort(X, Z, self.BreakEntry) then
    self:_AbortPattern(playerData, X, Z, self.BreakEntry, true)
    return
  end
  
  -- Check if we are in front of the boat (diffX > 0).
  if self:_CheckLimits(X, Z, self.BreakEntry) then
  
    -- Get optimal altitude, distance and speed.
    local alt, aoa, dist, speed=self:_GetAircraftParameters(playerData)
  
    -- Get altitude hint.
    local hintAlt=self:_AltitudeCheck(playerData, alt)
    
    -- Get speed hint.
    local hintSpeed=self:_SpeedCheck(playerData,speed)
    
    -- Message to player.
    if playerData.difficulty~=AIRBOSS.Difficulty.HARD then
      local hint=string.format("%s\n%s\n%s", playerData.step, hintAlt, hintSpeed)
      self:MessageToPlayer(playerData, hint, "MARSHAL", "")
    end

    -- Next step: Early Break.
    playerData.step=AIRBOSS.PatternStep.EARLYBREAK
    playerData.warning=nil
  end
end


--- Break.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data table.
-- @param #string part Part of the break.
function AIRBOSS:_Break(playerData, part)

  -- Get distances between carrier and player unit (parallel and perpendicular to direction of movement of carrier)
  local X, Z, rho, phi=self:_GetDistances(playerData.unit)
  
  -- Early or late break.  
  local breakpoint = self.BreakEarly
  if part==AIRBOSS.PatternStep.LATEBREAK then
    breakpoint = self.BreakLate
  end
    
  -- Check abort conditions.
  if self:_CheckAbort(X, Z, breakpoint) then
    self:_AbortPattern(playerData, X, Z, breakpoint, true)
    return
  end

  -- Check limits.
  if self:_CheckLimits(X, Z, breakpoint) then
  
    -- Get optimal altitude, distance and speed.
    local altitude=self:_GetAircraftParameters(playerData)
  
    -- Grade altitude.
    local hint, debrief=self:_AltitudeCheck(playerData, altitude)
    
    -- Message to player.
    if playerData.difficulty~=AIRBOSS.Difficulty.HARD then
      local hint=string.format("%s %s", playerData.step, hint)
      self:MessageToPlayer(playerData, hint, "MARSHAL", "")
    end

    -- Debrief
    self:_AddToDebrief(playerData, debrief)

    -- Next step: Late Break or Abeam.
    if part==AIRBOSS.PatternStep.EARLYBREAK then
      playerData.step=AIRBOSS.PatternStep.LATEBREAK
    else
      playerData.step=AIRBOSS.PatternStep.ABEAM
    end
    playerData.warning=nil
  end
end

--- Long downwind leg check.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data table.
function AIRBOSS:_CheckForLongDownwind(playerData)
  
  -- Get distances between carrier and player unit (parallel and perpendicular to direction of movement of carrier)
  local X, Z=self:_GetDistances(playerData.unit)

  -- One NM from carrier is too far.  
  local limit=UTILS.NMToMeters(-1.5)
  
  -- Check we are not too far out w.r.t back of the boat.
  if X<limit then --and relhead<45 then
    
    -- Sound output.
    self:RadioTransmission(self.LSORadio, AIRBOSS.LSOCall.LONGINGROOVE)
    self:RadioTransmission(self.LSORadio, AIRBOSS.LSOCall.DEPARTANDREENTER)
    
    -- Debrief.
    self:_AddToDebrief(playerData, "Long in the groove - Pattern Wave Off!")
    
    --grade="LIG PATTERN WAVE OFF - CUT 1 PT"
    playerData.lig=true
    playerData.patternwo=true
    
    -- Next step: Debriefing.
    playerData.step=AIRBOSS.PatternStep.DEBRIEF
    playerData.warning=nil
  end
  
end

--- Abeam position.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data table.
function AIRBOSS:_Abeam(playerData)

  -- Get distances between carrier and player unit (parallel and perpendicular to direction of movement of carrier)
  local X, Z = self:_GetDistances(playerData.unit)
  
  -- Check abort conditions.
  if self:_CheckAbort(X, Z, self.Abeam) then
    self:_AbortPattern(playerData, X, Z, self.Abeam, true)
    return
  end

  -- Check nest step threshold.  
  if self:_CheckLimits(X, Z, self.Abeam) then

    -- Get optimal altitude, distance and speed.
    local alt, aoa, dist, speed=self:_GetAircraftParameters(playerData)
    
    -- Grade Altitude.
    local hintAlt, debriefAlt=self:_AltitudeCheck(playerData, alt)
    
    -- Grade AoA.
    local hintAoA, debriefAoA=self:_AoACheck(playerData, aoa)    
    
    -- Grade distance to carrier.
    local hintDist, debriefDist=self:_DistanceCheck(playerData, dist) --math.abs(Z)
    
    -- Paddles contact.
    self:RadioTransmission(self.LSORadio, AIRBOSS.LSOCall.PADDLESCONTACT)
    
    -- Message to player.
    if playerData.difficulty~=AIRBOSS.Difficulty.HARD then
      local hint=string.format("%s\n%s\n%s\n%s", playerData.step, hintAlt, hintAoA, hintDist)
      self:MessageToPlayer(playerData, hint, "LSO", "")
    end

    -- Compile full hint.    
    local debrief=string.format("%s\n%s\n%s", debriefAlt, debriefAoA, debriefDist)

    -- Add to debrief.
    self:_AddToDebrief(playerData, debrief)
    
    -- Next step: ninety.
    playerData.step=AIRBOSS.PatternStep.NINETY
    playerData.warning=nil
  end
end

--- At the Ninety.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data table.
function AIRBOSS:_Ninety(playerData) 
  
  -- Get distances between carrier and player unit (parallel and perpendicular to direction of movement of carrier)
  local X, Z = self:_GetDistances(playerData.unit)
  
  -- Check abort conditions.
  if self:_CheckAbort(X, Z, self.Ninety) then
    self:_AbortPattern(playerData, X, Z, self.Ninety, true)
    return
  end
  
  -- Get Realtive heading player to carrier.
  local relheading=self:_GetRelativeHeading(playerData.unit, false)
  
  -- At the 90, i.e. 90 degrees between player heading and BRC of carrier.
  if relheading<=90 then
  
    -- Get optimal altitude, distance and speed.
    local alt, aoa, dist, speed=self:_GetAircraftParameters(playerData)
    
    -- Grade altitude.
    local hintAlt, debriefAlt=self:_AltitudeCheck(playerData, alt)
    
    -- Grade AoA.
    local hintAoA, debriefAoA=self:_AoACheck(playerData, aoa)

    -- Message to player.
    if playerData.difficulty~=AIRBOSS.Difficulty.HARD then
      local hint=string.format("%s\n%s\n%s", playerData.step, hintAlt, hintAoA)
      self:MessageToPlayer(playerData, hint, "LSO", "")
    end
    
    -- Debrief.
    local debrief=string.format("%s\n%s", debriefAlt, debriefAoA)
    
    -- Add to debrief.
    self:_AddToDebrief(playerData, debrief)
    
    -- Next step: wake.
    playerData.step=AIRBOSS.PatternStep.WAKE
    playerData.warning=nil
    
  elseif relheading>90 and self:_CheckLimits(X, Z, self.Wake) then
    -- Message to player.
    self:MessageToPlayer(playerData, "You are already at the wake and have not passed the 90. Turn faster next time!", "LSO")
    --TODO: pattern WO?
  end
end

--- At the Wake.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data table.
function AIRBOSS:_Wake(playerData) 

  -- Get distances between carrier and player unit (parallel and perpendicular to direction of movement of carrier)
  local X, Z = self:_GetDistances(playerData.unit)
    
  -- Check abort conditions.
  if self:_CheckAbort(X, Z, self.Wake) then
    self:_AbortPattern(playerData, X, Z, self.Wake, true)
    return
  end
  
  -- Right behind the wake of the carrier dZ>0.
  if self:_CheckLimits(X, Z, self.Wake) then
      
    -- Get optimal altitude, distance and speed.
    local alt, aoa, dist, speed=self:_GetAircraftParameters(playerData)
  
    -- Grade altitude.
    local hintAlt, debriefAlt=self:_AltitudeCheck(playerData, alt)
    
    -- Grade AoA.
    local hintAoA, debriefAoA=self:_AoACheck(playerData, aoa)

    -- Message to player.
    if playerData.difficulty~=AIRBOSS.Difficulty.HARD then
      local hint=string.format("%s\n%s\n%s", playerData.step, hintAlt, hintAoA)
      self:MessageToPlayer(playerData, hint, "LSO", "")
    end    
    
    -- Debrief.
    local debrief=string.format("%s\n%s", debriefAlt, debriefAoA)
    
    -- Add to debrief.
    self:_AddToDebrief(playerData, debrief)

    -- Next step: Final.
    playerData.step=AIRBOSS.PatternStep.FINAL
    playerData.warning=nil
  end
end

--- Turn to final.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data table.
function AIRBOSS:_Final(playerData)

  -- Get distances between carrier and player unit (parallel and perpendicular to direction of movement of carrier)
  local X, Z, rho, phi = self:_GetDistances(playerData.unit)

  -- In front of carrier or more than 4 km behind carrier. 
  if self:_CheckAbort(X, Z, self.Final) then
    self:_AbortPattern(playerData, X, Z, self.Final, true)
    return
  end
   
  -- Relative heading 0=fly parallel +-90=fly perpendicular
  local relhead=self:_GetRelativeHeading(playerData.unit, true)
  
  -- Line up wrt runway.
  local lineup=self:_Lineup(playerData.unit, true)
  
  -- Player's angle of bank.
  local roll=playerData.unit:GetRoll()
  
  -- Check if player is in +-5 deg cone and flying towards the runway.
  if math.abs(lineup)<5 then --and math.abs(relhead)<5 then

    -- Get optimal altitude, distance and speed.
    local alt, aoa, dist, speed=self:_GetAircraftParameters(playerData)

    -- Grade altitude.
    local hintAlt, debriefAlt=self:_AltitudeCheck(playerData, alt)

    -- AoA feed back 
    local hintAoA, debriefAoA=self:_AoACheck(playerData, aoa)
    
    -- Message to player.
    if playerData.difficulty~=AIRBOSS.Difficulty.HARD then
      local hint=string.format("%s\n%s\n%s", playerData.step, hintAlt, hintAoA)
      self:MessageToPlayer(playerData, hint, "LSO", "")
    end        

    -- Add to debrief.
    local debrief=string.format("%s\n%s", debriefAlt, debriefAoA)
    self:_AddToDebrief(playerData, debrief)
    
    -- Gather pilot data.
    local groovedata={} --#AIRBOSS.GrooveData
    groovedata.Step=playerData.step
    groovedata.Alt=alt
    groovedata.AoA=aoa
    groovedata.GSE=self:_Glideslope(playerData.unit, 3.5)
    groovedata.LUE=self:_Lineup(playerData.unit, true)
    groovedata.Roll=roll
    groovedata.Rhdg=relhead
    groovedata.TGroove=timer.getTime()
    
    -- TODO: could add angled approach if lineup<5 and relhead>5. This would mean the player has not turned in correctly!
        
    -- Groove data.
    playerData.groove.X0=groovedata
    
    -- Next step: X start & call the ball.
    playerData.step=AIRBOSS.PatternStep.GROOVE_XX
    playerData.warning=nil
  end

end


--- In the groove.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data table.
function AIRBOSS:_Groove(playerData)

  -- Get distances between carrier and player unit (parallel and perpendicular to direction of movement of carrier)
  local X, Z, rho, phi = self:_GetDistances(playerData.unit)
  
  -- Player altitude
  local alt=playerData.unit:GetAltitude()
  
  -- Player group.
  local player=playerData.unit:GetGroup()

  -- Check abort conditions.
  if self:_CheckAbort(X, Z, self.Groove) then
    self:_AbortPattern(playerData, X, Z, self.Groove, true)
    return
  end

  -- Lineup with runway centerline.
  local lineupError=self:_Lineup(playerData.unit, true)
  
  -- Glide slope.
  local glideslopeError=self:_Glideslope(playerData.unit, 3.5)
  
  -- Get AoA.
  local AoA=playerData.unit:GetAoA()
  
  -- Ranges in the groove.
  local RXX=UTILS.NMToMeters(0.750)+math.abs(self.carrierparam.sterndist) -- Start of groove.      0.75  = 1389 m
  local RRB=UTILS.NMToMeters(0.500)+math.abs(self.carrierparam.sterndist) -- Roger Ball! call.     0.5   =  926 m
  local RIM=UTILS.NMToMeters(0.375)+math.abs(self.carrierparam.sterndist) -- In the Middle 0.75/2. 0.375 =  695 m 
  local RIC=UTILS.NMToMeters(0.100)+math.abs(self.carrierparam.sterndist) -- In Close.             0.1   =  185 m
  local RAR=UTILS.NMToMeters(0.000)+math.abs(self.carrierparam.sterndist) -- At the Ramp.

  -- Data  
  local groovedata={} --#AIRBOSS.GrooveData
  groovedata.Step=playerData.step  
  groovedata.Alt=alt
  groovedata.AoA=AoA
  groovedata.GSE=glideslopeError
  groovedata.LUE=lineupError
  groovedata.Roll=playerData.unit:GetRoll()
  groovedata.Rhdg=self:_GetRelativeHeading(playerData.unit, true)
  
  if rho<=RXX and playerData.step==AIRBOSS.PatternStep.GROOVE_XX then
  
    -- LSO "Call the ball" call.
    self:RadioTransmission(self.LSORadio, AIRBOSS.LSOCall.CALLTHEBALL)
    playerData.Tlso=timer.getTime()
    
    -- Pilot "405, Hornet Ball, 3.2"
    -- TODO: Pilot output should come from pilot in MP.
    local text=string.format("Hornet Ball, %.1f", self:_GetFuelState(playerData.unit)/1000)
    self:MessageToPlayer(playerData, text, playerData.onboard, "", 3, false, 3)
            
    -- Store data.
    playerData.groove.XX=groovedata
    
    -- Next step: roger ball.
    playerData.step=AIRBOSS.PatternStep.GROOVE_RB
    playerData.warning=nil
  
  elseif rho<=RRB and playerData.step==AIRBOSS.PatternStep.GROOVE_RB then

    -- LSO "Roger ball" call.
    self:RadioTransmission(self.LSORadio, AIRBOSS.LSOCall.ROGERBALL)
    playerData.Tlso=timer.getTime()+1
    
    -- Store data.
    playerData.groove.RB=groovedata
    
    -- Next step: in the middle.
    playerData.step=AIRBOSS.PatternStep.GROOVE_IM
    playerData.warning=nil
    
  elseif rho<=RIM and playerData.step==AIRBOSS.PatternStep.GROOVE_IM then
  
    -- Debug.
    local text=string.format("Groove IM=%d m", rho)
    MESSAGE:New(text, 5):ToAllIf(self.Debug)
    self:I(self.lid..text)
    
    -- Store data.
    playerData.groove.IM=groovedata    
    
    -- Next step: in close.
    playerData.step=AIRBOSS.PatternStep.GROOVE_IC
    playerData.warning=nil
  
  elseif rho<=RIC and playerData.step==AIRBOSS.PatternStep.GROOVE_IC then

    -- Check if player was already waved off.
    if playerData.waveoff==false then

      -- Debug
      local text=string.format("Groove IC=%d m", rho)
      MESSAGE:New(text, 5):ToAllIf(self.Debug)
      self:I(self.lid..text)
      
      -- Store data.
      playerData.groove.IC=groovedata
      
      -- Check if player should wave off.
      local waveoff=self:_CheckWaveOff(glideslopeError, lineupError, AoA, playerData)
      
      -- Let's see..
      if waveoff then
              
        -- LSO Wave off!
        self:RadioTransmission(self.LSORadio, AIRBOSS.LSOCall.WAVEOFF)
        playerData.Tlso=timer.getTime()
        
        -- Player was waved off!
        playerData.waveoff=true
              
        return
      else
        -- Next step: AR at the ramp.      
        playerData.step=AIRBOSS.PatternStep.GROOVE_AR
        playerData.warning=nil
      end
      
    end
    
  elseif rho<=RAR and playerData.step==AIRBOSS.PatternStep.GROOVE_AR then
  
    -- Debug.
    local text=string.format("Groove AR=%d m", rho)
    MESSAGE:New(text, 5):ToAllIf(self.Debug)
    self:I(self.lid..text)
        
    -- Store data.
    playerData.groove.AR=groovedata
    
    -- Next step: in the wires.
    playerData.step=AIRBOSS.PatternStep.GROOVE_IW
    playerData.warning=nil
  end
  
  -- Time since last LSO call.
  local time=timer.getTime()
  local deltaT=time-playerData.Tlso
  
  -- Check if we are beween 3/4 NM and end of ship.
  if X<0 and rho>=RAR and rho<RXX and deltaT>=3 and playerData.waveoff==false then

    -- LSO call if necessary.
    self:_LSOadvice(playerData, glideslopeError, lineupError)

  elseif X>100 then
           
    if playerData.landed then
      
      -- Add to debrief.
      if playerData.waveoff then
        self:_AddToDebrief(playerData, "You were waved off but landed anyway. Airboss wants to talk to you!")
      else
        self:_AddToDebrief(playerData, "You boltered.")
      end
            
    else
      
      -- Add to debrief.
      self:_AddToDebrief(playerData, "You were waved off.")
      
      -- Next step: debrief.
      playerData.step=AIRBOSS.PatternStep.DEBRIEF
      playerData.warning=nil
    end
  end 
end

--- LSO check if player needs to wave off.
-- Wave off conditions are:
-- 
-- * Glide slope error > 3 degrees.
-- * Line up error > 3 degrees.
-- * AoA check but only for TOPGUN graduates.
-- @param #AIRBOSS self
-- @param #number glideslopeError Glide slope error in degrees.
-- @param #number lineupError Line up error in degrees.
-- @param #number AoA Angle of attack of player aircraft.
-- @param #AIRBOSS.PlayerData playerData Player data.
-- @return #boolean If true, player should wave off!
function AIRBOSS:_CheckWaveOff(glideslopeError, lineupError, AoA, playerData)

  -- Assume we're all good.
  local waveoff=false
  
  -- Too high or too low?
  if math.abs(glideslopeError)>1 then
    self:I(self.lid..string.format("%s: Wave off due to glide slope error |%.1f| > 1 degree!", playerData.name, glideslopeError))
    waveoff=true
  end

  -- Too far from centerline?
  if math.abs(lineupError)>3 then
    self:I(self.lid..string.format("%s: Wave off due to line up error |%.1f| > 3 degrees!", playerData.name, lineupError))
    waveoff=true
  end
  
  -- Too slow or too fast? Only for pros.
  if playerData.difficulty==AIRBOSS.Difficulty.HARD then
    -- Get aircraft specific AoA values
    local aoaac=self:_GetAircraftAoA(playerData)    
    -- Check too slow or too fast. 
    if AoA<aoaac.Fast then
      self:I(self.lid..string.format("%s: Wave off due to AoA %.1f < %.1f!", playerData.name, AoA, aoaac.Fast))
      waveoff=true
    elseif AoA>aoaac.Slow then
      self:I(self.lid..string.format("%s: Wave off due to AoA %.1f > %.1f!", playerData.name, AoA, aoaac.Slow))
      waveoff=true
    end
  end

  return waveoff
end

--- Get wire from landing position.
-- @param #AIRBOSS self
-- @param Core.Point#COORDINATE Ccoord Carrier position.
-- @param Core.Point#COORDINATE Lcoord Landing position.
-- @param #number dx Correction.
function AIRBOSS:_GetWire(Ccoord, Lcoord, dx)

  local hdg=self.carrier:GetHeading()
  
  -- Stern coordinate (sterndist<0)
  local Scoord=Ccoord:Translate(self.carrierparam.sterndist, hdg)
  
  -- Distance to landing coord
  local Ldist=Lcoord:Get2DDistance(Scoord)

  -- Little offset for the exact wire positions.
  dx=dx or self.carrierparam.wireoffset
  
  dx=self.carrierparam.wireoffset
  
  -- Corrected distance.
  local d=Ldist-dx

  -- Which wire was caught? X>0 since calculated as distance!
  local wire
  if d<self.carrierparam.wire1 then           -- 0
    wire=1
  elseif d<self.carrierparam.wire2 then       -- 12
    wire=2
  elseif d<self.carrierparam.wire3 then       -- 24
    wire=3
  elseif d<self.carrierparam.wire4 then       -- 36
    wire=4
  else
    wire=99
  end
  
  if self.Debug then
    local FB=self:GetFinalBearing(false)
    
    local w1=Scoord:Translate(self.carrierparam.wire1+self.carrierparam.wireoffset, FB)
    local w2=Scoord:Translate(self.carrierparam.wire2+self.carrierparam.wireoffset, FB)
    local w3=Scoord:Translate(self.carrierparam.wire3+self.carrierparam.wireoffset, FB)
    local w4=Scoord:Translate(self.carrierparam.wire4+self.carrierparam.wireoffset, FB)
    
    w1:MarkToAll("Wire 1")
    w2:MarkToAll("Wire 2")
    w3:MarkToAll("Wire 3")
    w4:MarkToAll("Wire 4")
    
    Scoord:MarkToAll("Stern")
    Lcoord:MarkToAll(string.format("Landing Point wire=%s", wire))
    
    Scoord:SmokeGreen()
    Lcoord:SmokeGreen()
    w1:SmokeBlue()
    w2:SmokeOrange()
    w3:SmokeRed()
    w4:SmokeWhite()
  end
  
  -- Debug output.
  self:I(string.format("GetWire: L=%.1f m, dx=%.1f m, d=L-dx=%.1f m ==> wire=%d.", Ldist, dx, d, wire))

  return wire
end

--- Get wire from landing position.
-- @param #AIRBOSS self
-- @param #number d Distance in meters wrt carrier position where player landed.
-- @param #number dx Correction.
function AIRBOSS:_GetWire2(d, dx)

  -- Little offset for the exact wire positions.
  dx=dx or self.carrierparam.wireoffset

  -- Which wire was caught? X>0 since calculated as distance!
  local wire
  if d-dx<self.carrierparam.wire1 then           -- < -104
    wire=1
  elseif d-dx<self.carrierparam.wire2 then       -- < -92
    wire=2
  elseif d-dx<self.carrierparam.wire3 then       -- < -80
    wire=3
  elseif d-dx<self.carrierparam.wire4 then       -- < -68
    wire=4
  else
    wire=99
  end
  
  -- Debug output.
  self:I(string.format("GetWire: d=%.1f m, dx=%.1f m, d-dx=%.1f m ==> wire=%d.", d, dx, d-dx, wire))

  return wire
end

--- Trapped? Check if in air or not after landing event.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data table.
function AIRBOSS:_Trapped(playerData)
  
  if playerData.unit:InAir()==false then
    -- Seems we have successfully landed.
    
    local wire=playerData.wire

    -- Message to player.    
    local text=string.format("Trapped %d-wire.", wire)
    if wire==3 then
      text=text.." Well done!"
    elseif wire==2 then
      text=text.." Not bad, maybe you even get the 3rd next time."
    elseif wire==4 then
     text=text.." That was scary. You can do better than this!"
    elseif wire==1 then
      text=text.." Try harder next time!"
    end
    self:MessageToPlayer(playerData, text, "LSO", "")
    
    -- Debrief.
    local hint = string.format("Trapped %d-wire.", wire)
    self:_AddToDebrief(playerData, hint, "Groove: IW")
    
  else
  
    --Still in air ==> Boltered!
    MESSAGE:New("Player boltered in trapped", 5, "DEBUG")
    playerData.boltered=true
    
  end
  
  -- Next step: debriefing.
  playerData.step=AIRBOSS.PatternStep.DEBRIEF
  playerData.warning=nil
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ZONE functions
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Get Bullseye zone with radius 1 NM and DME 3 NM from the carrier. Radial depends on recovery case.
-- @param #AIRBOSS self
-- @param #number case Recovery case.
-- @return Core.Zone#ZONE_RADIUS Arc in zone.
function AIRBOSS:_GetZoneBullseye(case)

  -- Radius = 1 NM.
  local radius=UTILS.NMToMeters(1)
  
  -- Distance = 3 NM
  local distance=UTILS.NMToMeters(3)
  
  -- Zone depends on Case recovery.
  local radial
  if case==2 then
  
    radial=self:GetRadialCase2(false, false)
  
  elseif case==3 then
  
    radial=self:GetRadialCase3(false, false)
  
  else
  
    self:E(self.lid.."ERROR: Bullseye zone only for CASE II or III recoveries!")
    return nil
  
  end
  
  -- Get coordinate and vec2.
  local coord=self:GetCoordinate():Translate(distance, radial)
  local vec2=coord:GetVec2()

  -- Create zone.
  local zone=ZONE_RADIUS:New("Zone Bullseye", vec2, radius)
  
  return zone
end

--- Get dirty up zone with radius 1 NM and DME 9 NM from the carrier. Radial depends on recovery case.
-- @param #AIRBOSS self
-- @param #number case Recovery case.
-- @return Core.Zone#ZONE_RADIUS Arc in zone.
function AIRBOSS:_GetZoneDirtyUp(case)

  -- Radius = 1 NM.
  local radius=UTILS.NMToMeters(1)
  
  -- Distance = 9 NM
  local distance=UTILS.NMToMeters(9)
  
  -- Zone depends on Case recovery.
  local radial
  if case==2 then
  
    radial=self:GetRadialCase2(false, false)
  
  elseif case==3 then
  
    radial=self:GetRadialCase3(false, false)
  
  else
  
    self:E(self.lid.."ERROR: Dirty Up zone only for CASE II or III recoveries!")
    return nil
  
  end
  
  -- Get coordinate and vec2.
  local coord=self:GetCoordinate():Translate(distance, radial)
  local vec2=coord:GetVec2()

  -- Create zone.
  local zone=ZONE_RADIUS:New("Zone Dirty Up", vec2, radius)
  
  return zone
end

--- Get arc out zone with radius 1 NM and DME 12 NM from the carrier. Radial depends on recovery case.
-- @param #AIRBOSS self
-- @param #number case Recovery case.
-- @return Core.Zone#ZONE_RADIUS Arc in zone.
function AIRBOSS:_GetZoneArcOut(case)

  -- Radius = 1 NM.
  local radius=UTILS.NMToMeters(1)
  
  -- Distance = 12 NM
  local distance=UTILS.NMToMeters(12)
  
  -- Zone depends on Case recovery.
  local radial
  if case==2 then
  
    radial=self:GetRadialCase2(false, false)
  
  elseif case==3 then
  
    radial=self:GetRadialCase3(false, false)
  
  else
  
    self:E(self.lid.."ERROR: Arc out zone only for CASE II or III recoveries!")
    return nil
  
  end
  
  -- Get coordinate of carrier and translate.
  local coord=self:GetCoordinate():Translate(distance, radial)
  
  -- Create zone.
  local zone=ZONE_RADIUS:New("Zone Arc Out", coord:GetVec2(), radius)
  
  return zone
end

--- Get arc in zone with radius 1 NM and DME 14 NM from the carrier. Radial depends on recovery case.
-- @param #AIRBOSS self
-- @param #number case Recovery case.
-- @return Core.Zone#ZONE_RADIUS Arc in zone.
function AIRBOSS:_GetZoneArcIn(case)

  -- Radius = 1 NM.
  local radius=UTILS.NMToMeters(1)
  
  -- Zone depends on Case recovery.
  local radial
  if case==2 then
  
    radial=self:GetRadialCase2(false, true)
  
  elseif case==3 then
  
    radial=self:GetRadialCase3(false, true)
  
  else
  
    self:E(self.lid.."ERROR: Arc in zone only for CASE II or III recoveries!")
    return nil
  
  end
  
  -- Angle between FB/BRC and holding zone.
  local alpha=math.rad(self.holdingoffset)
  
  -- 12+x NM from carrier
  local x=12/math.cos(alpha)
  
  -- Distance = 14 NM
  local distance=UTILS.NMToMeters(x)
  
  -- Get coordinate.
  local coord=self:GetCoordinate():Translate(distance, radial)

  -- Create zone.
  local zone=ZONE_RADIUS:New("Zone Arc In", coord:GetVec2(), radius)
  
  return zone
end

--- Get platform zone with radius 1 NM and DME 19 NM from the carrier. Radial depends on recovery case.
-- @param #AIRBOSS self
-- @param #number case Recovery case.
-- @return Core.Zone#ZONE_RADIUS Circular platform zone.
function AIRBOSS:_GetZonePlatform(case)

  -- Radius = 1 NM.
  local radius=UTILS.NMToMeters(1)
    
  -- Zone depends on Case recovery.
  local radial
  if case==2 then
  
    radial=self:GetRadialCase2(false, true)
  
  elseif case==3 then
  
    radial=self:GetRadialCase3(false, true)
  
  else
  
    self:E(self.lid.."ERROR: Platform zone only for CASE II or III recoveries!")
    return nil
  
  end

  -- Angle between FB/BRC and holding zone.
  local alpha=math.rad(self.holdingoffset)

  -- Distance = 19 NM
  local distance=UTILS.NMToMeters(19)/math.cos(alpha)
  
  -- Get coordinate.
  local coord=self:GetCoordinate():Translate(distance, radial)

  -- Create zone.
  local zone=ZONE_RADIUS:New("Zone Platform", coord:GetVec2(), radius)
  
  return zone
end


--- Get approach corridor zone. Shape depends on recovery case.
-- @param #AIRBOSS self
-- @param #number case Recovery case.
-- @return Core.Zone#ZONE_POLYGON_BASE Box zone.
function AIRBOSS:_GetZoneCorridor(case)

  -- Radial and offset.
  local radial
  local offset
  
  -- Select case.
  if case==2 then
    radial=self:GetRadialCase2(false, false)
    offset=self:GetRadialCase2(false, true)
  elseif case==3 then
    radial=self:GetRadialCase3(false, false)
    offset=self:GetRadialCase3(false, true)  
  else
    radial=self:GetRadialCase3(false, false)
    offset=self:GetRadialCase3(false, true)    
  end

  -- Angle between radial and offset in rad.
  local alpha=math.rad(self.holdingoffset)
   
  -- Width of the box in NM.
  local w=2
  local w2=w/2
  
  -- Length of the box in NM.
  local l=10/math.cos(alpha)
    
  -- Distance from carrier to arc out zone.
  local d=12
  
  -- Some math...
  local y1=d-w2
  local x1=y1*math.tan(alpha)
  local y2=d+w2
  local x2=y2*math.tan(alpha)  
  local b=w2*(1/math.cos(alpha)-1)
  
  -- This is what we need.
  local P=x1+b
  local Q=x2-b
  
  -- Debug output.
  self:T3(string.format("FF case %d radial = %d", case, radial))
  self:T3(string.format("FF case %d offset = %d", case, offset))
  self:T3(string.format("FF w  = %.1f NM", w))
  self:T3(string.format("FF l  = %.1f NM", l))
  self:T3(string.format("FF d  = %.1f NM", d))
  self:T3(string.format("FF y1 = %.1f NM", y1))
  self:T3(string.format("FF x1 = %.1f NM", x1))
  self:T3(string.format("FF y2 = %.1f NM", y2))
  self:T3(string.format("FF x2 = %.1f NM", x2))
  self:T3(string.format("FF b  = %.1f NM", b))
  self:T3(string.format("FF P  = %.1f NM", P))
  self:T3(string.format("FF Q  = %.1f NM", Q))

  local c={}
  c[1]=self:GetCoordinate() --Carrier coordinate
  
  if math.abs(self.holdingoffset)>1 then
    -- Complicated case with an angle.
    c[2]=c[1]:Translate( UTILS.NMToMeters(w2),     radial-90)     -- 1 Right of carrier CORRECT!  
    c[3]=c[2]:Translate( UTILS.NMToMeters(d+w2),   radial)        -- 13 "south" @ 1 right
    c[4]=c[3]:Translate( UTILS.NMToMeters(Q),      radial+90)     -- 
    c[5]=c[4]:Translate( UTILS.NMToMeters(l),      offset)
    c[6]=c[5]:Translate( UTILS.NMToMeters(w),      offset+90)     -- Back wall (angled)  
    c[9]=c[1]:Translate( UTILS.NMToMeters(w2),     radial+90)     -- 1 left of carrier CORRECT!
    c[8]=c[9]:Translate( UTILS.NMToMeters(d-w2),   radial)        -- 1 left and 11 behind of carrier CORRECT!
    c[7]=c[8]:Translate( UTILS.NMToMeters(P),      radial+90)
  else  
    -- Easy case of a long box.
    c[2]=c[1]:Translate( UTILS.NMToMeters(w2),       radial-90)
    c[3]=c[2]:Translate( UTILS.NMToMeters(d+w2+l),   radial)
    c[4]=c[3]:Translate( UTILS.NMToMeters(w),        radial+90)
    c[5]=c[1]:Translate( UTILS.NMToMeters(w2),       radial+90)
  end

  
  -- Create an array of a square!
  local p={}
  for _i,_c in ipairs(c) do
    if self.Debug then
      --_c:SmokeBlue()
    end
    p[_i]=_c:GetVec2()
  end

  -- Square zone length=10NM width=6 NM behind the carrier starting at angels+15 NM behind the carrier.
  -- So stay 0-5 NM (+1 NM error margin) port of carrier.
  local zone=ZONE_POLYGON_BASE:New("CASE II/III Approach Corridor", p)

  return zone
end

--- Get holding zone of player.
-- @param #AIRBOSS self
-- @param #number case Recovery case.
-- @param #number stack Marshal stack number.
-- @return Core.Zone#ZONE Holding zone.
function AIRBOSS:_GetZoneHolding(case, stack)

  -- Holding zone.
  local zoneHolding=nil  --Core.Zone#ZONE

  -- Stack is <= 0 ==> no marshal zone.
  if stack<=0 then
    return nil
  end    
  
  -- Pattern alitude.
  local patternalt, c1, c2=self:_GetMarshalAltitude(stack, case)
  
  if case==1 then
    -- CASE I
    
    -- Zone 2.5 NM port of carrier with a radius of 3 NM (holding pattern should be < 5 NM). 
    local R=UTILS.MetersToNM(2.5)
    local coord=self:GetCoordinate():Translate(R, 270)
    
    zoneHolding=ZONE_RADIUS:New("CASE I Holding Zone", coord:GetVec2(), R)
  
  else  
    -- CASE II/II
          
    -- Get radial.
    local hdg      
    if case==2 then
      hdg=self:GetRadialCase2(false, true)
    else
      hdg=self:GetRadialCase3(false, true)
    end
    
    -- Create an array of a square!
    local p={}
    p[1]=c1:Translate(UTILS.NMToMeters(1), hdg-90):GetVec2()  --c1 is at (angels+15) NM directly behind the carrier. We translate it 1 NM starboard.
    p[2]=c2:Translate(UTILS.NMToMeters(1), hdg-90):GetVec2()  --c2 is 10 NM further behind. Also translated 1 NM starboard.
    p[3]=c2:Translate(UTILS.NMToMeters(7), hdg+90):GetVec2()  --p3 6 NM port of carrier.
    p[4]=c1:Translate(UTILS.NMToMeters(7), hdg+90):GetVec2()  --p4 6 NM port of carrier.
    
    -- Square zone length=10NM width=6 NM behind the carrier starting at angels+15 NM behind the carrier.
    -- So stay 0-5 NM (+1 NM error margin) port of carrier.
    zoneHolding=ZONE_POLYGON_BASE:New("CASE II/III Holding Zone", p)
  end
  
  return zoneHolding
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ORIENTATION functions
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Provide info about player status on the fly.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data.
function AIRBOSS:_DetailedPlayerStatus(playerData)

  -- Player unit.
  local unit=playerData.unit
  
  -- Aircraft attitude.
  local aoa=unit:GetAoA()
  local yaw=unit:GetYaw()
  local roll=unit:GetRoll()
  local pitch=unit:GetPitch()
 
  -- Distance to the boat.
  local dist=playerData.unit:GetCoordinate():Get2DDistance(self:GetCoordinate())
  local dx,dz,rho,phi=self:_GetDistances(unit)

  -- Wind vector.
  local wind=unit:GetCoordinate():GetWindWithTurbulenceVec3()
  
  -- Aircraft veloecity vector.
  local velo=unit:GetVelocityVec3()
  local vabs=UTILS.VecNorm(velo)
  
  -- Relative heading Aircraft to Carrier.
  local relhead=self:_GetRelativeHeading(playerData.unit)
 
  -- Output
  local text=string.format("Pattern step: %s\n", playerData.step) 
  text=text..string.format("AoA=%.1f | |V|=%.1f knots\n", aoa, UTILS.MpsToKnots(vabs))
  text=text..string.format("Vx=%.1f Vy=%.1f Vz=%.1f m/s\n", velo.x, velo.y, velo.z)  
  text=text..string.format("Pitch=%.1f° | Roll=%.1f° | Yaw=%.1f°\n", pitch, roll, yaw)
  text=text..string.format("Climb Angle=%.1f° | Rate=%d ft/min\n", unit:GetClimbAngle(), velo.y*196.85) 
  text=text..string.format("R=%.1f NM | X=%d Z=%d m\n", UTILS.MetersToNM(rho), dx, dz)
  text=text..string.format("Phi=%.1f° | Rel=%.1f°", phi, relhead)
  -- If in the groove, provide line up and glide slope error.
  if playerData.step==AIRBOSS.PatternStep.GROOVE_XX or
     playerData.step==AIRBOSS.PatternStep.GROOVE_RB or
     playerData.step==AIRBOSS.PatternStep.GROOVE_IM or
     playerData.step==AIRBOSS.PatternStep.GROOVE_IC or
     playerData.step==AIRBOSS.PatternStep.GROOVE_AR or
     playerData.step==AIRBOSS.PatternStep.GROOVE_IW then
    local lineup=self:_Lineup(playerData.unit, true)
    local glideslope=self:_Glideslope(playerData.unit, 3.5)
    text=text..string.format("\nLU Error = %.1f° (line up)", lineup)
    text=text..string.format("\nGS Error = %.1f° (glide slope)", glideslope)
  end
  
  -- Wind (for debugging).
  --text=text..string.format("Wind Vx=%.1f Vy=%.1f Vz=%.1f\n", wind.x, wind.y, wind.z)

  MESSAGE:New(text, 1, nil , true):ToClient(playerData.client)
end

--- Get glide slope of aircraft unit.
-- @param #AIRBOSS self
-- @param Wrapper.Unit#UNIT unit Aircraft unit.
-- @param #number optangle (Optional) Return glide slope relative to this angle, i.e. the error from the optimal glide slope.
-- @return #number Glide slope angle in degrees measured from the deck of the carrier and third wire.
function AIRBOSS:_Glideslope(unit, optangle)

  -- Default is 0.
  optangle=optangle or 0

 -- Get distances between carrier and player unit (parallel and perpendicular to direction of movement of carrier)
  local X, Z, rho, phi = self:_GetDistances(unit)

  -- Glideslope. Wee need to correct for the height of the deck. The ideal glide slope is 3.5 degrees.
  local h=unit:GetAltitude()-self.carrierparam.deckheight
  
  -- Distance correction.
  local offx=self.carrierparam.wire3 or self.carrierparam.sterndist
  local x=math.abs(self.carrierparam.wire3-X)
  
  -- Glide slope.
  local glideslope=math.atan(h/x)  

  return math.deg(glideslope)-optangle
end

--- Get line up of player wrt to carrier. 
-- @param #AIRBOSS self
-- @param Wrapper.Unit#UNIT unit Aircraft unit.
-- @param #boolean runway If true, include angled runway.
-- @return #number Line up with runway heading in degrees. 0 degrees = perfect line up. +1 too far left. -1 too far right.
-- @return #number Distance from carrier tail to player aircraft in meters.
function AIRBOSS:_Lineup(unit, runway) 

 -- Get distances between carrier and player unit (parallel and perpendicular to direction of movement of carrier)
  local X, Z, rho, phi = self:_GetDistances(unit)
  
  -- Position at the end of the deck. From there we calculate the angle.
  local b={x=self.carrierparam.sterndist, z=0}
  
  -- Position of the aircraft wrt carrier coordinates.
  local a={x=X, z=Z}

  -- Vector from plane to ref point on boad.
  local c={x=b.x-a.x, y=0, z=b.z-a.z}
  
  -- Current line up and error wrt to final heading of the runway.
  local lineup=math.deg(math.atan2(c.z, c.x))
  
  -- Include runway.
  if runway then
    lineup=lineup-self.carrierparam.rwyangle
  end

  return lineup, UTILS.VecNorm(c)
end

--- Get true (or magnetic) heading of carrier.
-- @param #AIRBOSS self
-- @param #boolean magnetic If true, calculate magnetic heading. By default true heading is returned.
-- @return #number Carrier heading in degrees.
function AIRBOSS:GetHeading(magnetic) 
  self:F3({magnetic=magnetic})
  
  -- Carrier heading
  local hdg=self.carrier:GetHeading()
    
  -- Include magnetic declination.
  if magnetic then
    hdg=hdg-UTILS.GetMagneticDeclination()
  end
  
  -- Adjust negative values.
  if hdg<0 then
    hdg=hdg+360
  end  
  
  return hdg
end

--- Get base recovery course (BRC) of carrier.
-- The is the magnetic heading of the carrier.
-- @param #AIRBOSS self
-- @return #number BRC in degrees.
function AIRBOSS:GetBRC()
  return self:GetHeading(true)
end


--- Get final bearing (FB) of carrier.
-- By default, the routine returns the magnetic FB depending on the current map (Caucasus, NTTR, Normandy, Persion Gulf etc).
-- The true bearing can be obtained by setting the *TrueNorth* parameter to true. 
-- @param #AIRBOSS self
-- @param #boolean magnetic If true, magnetic FB is returned.
-- @return #number FB in degrees.
function AIRBOSS:GetFinalBearing(magnetic)

  -- First get the heading.  
  local fb=self:GetHeading(magnetic)  
  
  -- Final baring = BRC including angled deck.
  fb=fb+self.carrierparam.rwyangle
  
  -- Adjust negative values.
  if fb<0 then
    fb=fb+360
  end
  
  return fb
end

--- Get radial with respect to carrier heading and (optionally) holding offset. This is used in Case II recoveries.
-- @param #AIRBOSS self
-- @param #boolean magnetic If true, magnetic radial is returned. Default is true radial.
-- @param #boolean offset If true, inlcude holding offset.
-- @return #number Radial in degrees.
function AIRBOSS:GetRadialCase2(magnetic, offset) 

  -- Radial wrt to heading of carrier.  
  local radial=self:GetHeading(magnetic)-180
  
  -- Holding offset angle (+-15 or 30 degrees usually)
  if offset then
    radial=radial+self.holdingoffset
  end
  
  -- Adjust for negative values.
  if radial<0 then
    radial=radial+360
  end
  
  return radial
end

--- Get radial with respect to angled runway and (optionally) holding offset. This is used in Case III recoveries.
-- @param #AIRBOSS self
-- @param #boolean magnetic If true, magnetic radial is returned. Default is true radial.
-- @param #boolean offset If true, inlcude holding offset.
-- @return #number Radial in degrees.
function AIRBOSS:GetRadialCase3(magnetic, offset) 

  -- Radial wrt angled runway.
  local radial=self:GetFinalBearing(magnetic)-180
  
  -- Holding offset angle (+-15 or 30 degrees usually)
  if offset then
    radial=radial+self.holdingoffset
  end
  
  -- Adjust for negative values.
  if radial<0 then
    radial=radial+360
  end
  
  return radial
end

--- Get radial, i.e. the final bearing FB-180 degrees.
-- @param #AIRBOSS self
-- @param #boolean magnetic If true, magnetic radial is returned. Default is true radial.
-- @return #number Radial in degrees.
function AIRBOSS:GetRadial(magnetic) 

  -- Get radial.
  local radial=self:GetFinalBearing(magnetic)-180
  
  -- Adjust for negative values.
  if radial<0 then
    radial=radial+360
  end
  
  return radial
end

--- Get relative heading of player wrt carrier.
-- This is the angle between the direction vector of the carrier and the direction vector of the provided unit.
-- Note that this is calculated in the X-Z plane, i.e. the altitude Y is not taken into account.
-- @param #AIRBOSS self
-- @param Wrapper.Unit#UNIT unit Player unit.
-- @param #boolean runway (Optional) If true, return relative heading of unit wrt to angled runway of the carrier.
-- @return #number Relative heading in degrees. An angle of 0 means, unit fly parallel to carrier. An angle of + or - 90 degrees means, unit flies perpendicular to carrier. 
function AIRBOSS:_GetRelativeHeading(unit, runway)

  -- Direction vector of the carrier.
  local vC=self.carrier:GetOrientationX()
  
  -- Direction vector of the unit.
  local vP=unit:GetOrientationX()
  
  -- We only want the X-Z plane. Aircraft could fly parallel but ballistic and we dont want the "pitch" angle. 
  vC.y=0 ; vP.y=0
  
  -- Get angle between the two orientation vectors in rad.
  local rhdg=math.deg(math.acos(UTILS.VecDot(vC,vP)/UTILS.VecNorm(vC)/UTILS.VecNorm(vP)))  
  
  -- Include runway angle.
  if runway then
    rhdg=rhdg-self.carrierparam.rwyangle
  end
  
  -- Return heading in degrees.
  return rhdg
end

--- Calculate distances between carrier and aircraft unit.
-- @param #AIRBOSS self 
-- @param Wrapper.Unit#UNIT unit Aircraft unit.
-- @return #number Distance [m] in the direction of the orientation of the carrier.
-- @return #number Distance [m] perpendicular to the orientation of the carrier.
-- @return #number Distance [m] to the carrier.
-- @return #number Angle [Deg] from carrier to plane. Phi=0 if the plane is directly behind the carrier, phi=90 if the plane is starboard, phi=180 if the plane is in front of the carrier.
function AIRBOSS:_GetDistances(unit)

  -- Vector to carrier
  local a=self.carrier:GetVec3()
  
  -- Vector to player
  local b=unit:GetVec3()
  
  -- Vector from carrier to player.
  local c={x=b.x-a.x, y=0, z=b.z-a.z}
  
  -- Orientation of carrier.
  local x=self.carrier:GetOrientationX()
  
  -- Projection of player pos on x component.
  local dx=UTILS.VecDot(x,c)
  
  -- Orientation of carrier.
  local z=self.carrier:GetOrientationZ()
  
  -- Projection of player pos on z component.  
  local dz=UTILS.VecDot(z,c)
  
  -- Polar coordinates
  local rho=math.sqrt(dx*dx+dz*dz)
  local phi=math.deg(math.atan2(dz,dx))
  if phi<0 then
    phi=phi+360
  end
  
  -- phi=0 if the plane is directly behind the carrier, phi=180 if the plane is in front of the carrier
  phi=phi-180

  if phi<0 then
    phi=phi+360
  end
  
  return dx,dz,rho,phi
end

--- Check limits for reaching next step.
-- @param #AIRBOSS self
-- @param #number X X position of player unit.
-- @param #number Z Z position of player unit.
-- @param #AIRBOSS.Checkpoint check Checkpoint.
-- @return #boolean If true, checkpoint condition for next step was reached.
function AIRBOSS:_CheckLimits(X, Z, check)

  -- Limits
  local nextXmin=check.LimitXmin==nil or (check.LimitXmin and (check.LimitXmin<0 and X<=check.LimitXmin or check.LimitXmin>=0 and X>=check.LimitXmin))
  local nextXmax=check.LimitXmax==nil or (check.LimitXmax and (check.LimitXmax<0 and X>=check.LimitXmax or check.LimitXmax>=0 and X<=check.LimitXmax))
  local nextZmin=check.LimitZmin==nil or (check.LimitZmin and (check.LimitZmin<0 and Z<=check.LimitZmin or check.LimitZmin>=0 and Z>=check.LimitZmin))
  local nextZmax=check.LimitZmax==nil or (check.LimitZmax and (check.LimitZmax<0 and Z>=check.LimitZmax or check.LimitZmax>=0 and Z<=check.LimitZmax))
  
  -- Proceed to next step if all conditions are fullfilled.
  local next=nextXmin and nextXmax and nextZmin and nextZmax
  
  -- Debug info.
  local text=string.format("step=%s: next=%s: X=%d Xmin=%s Xmax=%s | Z=%d Zmin=%s Zmax=%s", 
  check.name, tostring(next), X, tostring(check.LimitXmin), tostring(check.LimitXmax), Z, tostring(check.LimitZmin), tostring(check.LimitZmax))
  self:T(self.lid..text)
  --MESSAGE:New(text, 1):ToAllIf(self.Debug)

  return next
end


-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- LSO functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- LSO advice radio call.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data table.
-- @param #number glideslopeError Error in degrees.
-- @param #number lineupError Error in degrees.
function AIRBOSS:_LSOadvice(playerData, glideslopeError, lineupError)

  -- Advice time.
  local advice=0
  
  -- Glideslope high/low calls.
  local text=""
  if glideslopeError>1 then
    -- "You're high!"
    self:RadioTransmission(self.LSORadio, AIRBOSS.LSOCall.HIGH, true)
    advice=advice+AIRBOSS.LSOCall.HIGH.duration
  elseif glideslopeError>0.5 then
    -- "You're a little high."
    self:RadioTransmission(self.LSORadio, AIRBOSS.LSOCall.HIGH, false)
    advice=advice+AIRBOSS.LSOCall.HIGH.duration
  elseif glideslopeError<-1.0 then
    -- "Power!"
    self:RadioTransmission(self.LSORadio, AIRBOSS.LSOCall.POWER, true)
    advice=advice+AIRBOSS.LSOCall.POWER.duration
  elseif glideslopeError<-0.5 then
    -- "You're a little low."
    self:RadioTransmission(self.LSORadio, AIRBOSS.LSOCall.POWER, false)
    advice=advice+AIRBOSS.LSOCall.POWER.duration
  else
    text="Good altitude."
  end

  text=text..string.format(" Glideslope Error = %.2f°", glideslopeError)
  text=text.."\n"
  
  -- Lineup left/right calls.
  if lineupError<-3 then
    -- "Come left!"
    self:RadioTransmission(self.LSORadio, AIRBOSS.LSOCall.COMELEFT, true)
    advice=advice+AIRBOSS.LSOCall.COMELEFT.duration
  elseif lineupError<-1 then
    -- "Come left."
    self:RadioTransmission(self.LSORadio, AIRBOSS.LSOCall.COMELEFT, false)
    advice=advice+AIRBOSS.LSOCall.COMELEFT.duration    
  elseif lineupError>3 then
    -- "Right for lineup!"
    self:RadioTransmission(self.LSORadio, AIRBOSS.LSOCall.RIGHTFORLINEUP, true)
    advice=advice+AIRBOSS.LSOCall.RIGHTFORLINEUP.duration    
  elseif lineupError>1 then
    -- "Right for lineup."
    self:RadioTransmission(self.LSORadio, AIRBOSS.LSOCall.RIGHTFORLINEUP, false)
    advice=advice+AIRBOSS.LSOCall.RIGHTFORLINEUP.duration
  else
    text=text.."Good lineup."
  end
  
  text=text..string.format(" Lineup Error = %.1f°\n", lineupError)
  
  -- Get current AoA.
  local aoa=playerData.unit:GetAoA()
  
  -- Get aircraft AoA parameters.
  local aircraftaoa=self:_GetAircraftAoA(playerData)
  
  -- Rate aoa.
  if aoa>=aircraftaoa.Slow then
    -- "Your're slow!"
    self:RadioTransmission(self.LSORadio, AIRBOSS.LSOCall.SLOW, true)
    advice=advice+AIRBOSS.LSOCall.SLOW.duration
  elseif aoa>=aircraftaoa.OnSpeedMax and aoa<aircraftaoa.Slow then
    -- "Your're a little slow."
    self:RadioTransmission(self.LSORadio, AIRBOSS.LSOCall.SLOW, false)
    advice=advice+AIRBOSS.LSOCall.SLOW.duration              
  elseif aoa>=aircraftaoa.OnSpeedMin and aoa<aircraftaoa.OnSpeedMax then
    text=text.."You're on speed."
  elseif aoa>=aircraftaoa.Fast and aoa<aircraftaoa.OnSpeedMin then
    -- "You're a little fast."
    self:RadioTransmission(self.LSORadio, AIRBOSS.LSOCall.FAST, false)
    advice=advice+AIRBOSS.LSOCall.FAST.duration
  elseif aoa<aircraftaoa.Fast then
    -- "You're fast!"
    self:RadioTransmission(self.LSORadio, AIRBOSS.LSOCall.FAST, true)
    advice=advice+AIRBOSS.LSOCall.FAST.duration
  else
    text=text.."Unknown AoA state."
  end
  
  -- Text not used.
  text=text..string.format(" AoA = %.1f", aoa)
   
  -- Set last time.
  playerData.Tlso=timer.getTime()
end

--- Grade approach.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data table.
-- @return #string LSO grade, i.g. _OK_, OK, (OK), --, etc.
-- @return #number Points.
-- @return #string LSO analysis of flight path.
function AIRBOSS:_LSOgrade(playerData)
  
  --- Count
  local function count(base, pattern)
    return select(2, string.gsub(base, pattern, ""))
  end

  -- Analyse flight data and conver to LSO text.
  local GXX,nXX=self:_Flightdata2Text(playerData, AIRBOSS.GroovePos.XX) --playerData.groove.XX)
  local GIM,nIM=self:_Flightdata2Text(playerData, AIRBOSS.GroovePos.IM) --playerData.groove.IM)
  local GIC,nIC=self:_Flightdata2Text(playerData, AIRBOSS.GroovePos.IC) --playerData.groove.IC)
  local GAR,nAR=self:_Flightdata2Text(playerData, AIRBOSS.GroovePos.AR) --playerData.groove.AR)
  
  -- Put everything together.
  local G=GXX.." "..GIM.." ".." "..GIC.." "..GAR
  
  -- Count number of minor, normal and major deviations.
  local N=nXX+nIM+nIC+nAR
  local nL=count(G, '_')/2
  local nS=count(G, '%(')
  local nN=N-nS-nL
  
  local grade
  local points
  if N==0 then
    -- No deviations, should be REALLY RARE!
    grade="_OK_"
    points=5.0
  else
    if nL>0 then
      -- Larger deviations ==> "No grade" 2.0 points.
      grade="--" 
      points=2.0
    elseif nN>0 then
      -- No larger but average deviations ==>  "Fair Pass" Pass with average deviations and corrections.
      grade="(OK)"
      points=3.0
    else
      -- Only minor corrections
      grade="OK"
      points=4.0
    end
  end
  
  -- Replace" )"( and "__" 
  G=G:gsub("%)%(", "")
  G=G:gsub("__","")  
  
  -- Debug info
  local text="LSO grade:\n"
  text=text..G.."\n"
  text=text.."Grade = "..grade.." points = "..points.."\n"
  text=text.."# of total deviations   = "..N.."\n"
  text=text.."# of large deviations _ = "..nL.."\n"
  text=text.."# of normal deviations  = "..nN.."\n"
  text=text.."# of small deviations ( = "..nS.."\n"
  self:I(self.lid..text)

  --[[  
  <9 seconds: No Grade
  9-11 seconds: Fair
  12-21 seconds(15-18 is ideal): OK
  22-24 seconds: Fair
  >24 seconds: No Grade  
  ]]
  
  if playerData.patternwo or playerData.waveoff then
    grade="CUT"
    points=1.0
    if playerData.lig then
      G="LIG PWO"
    elseif playerData.patternwo then
      G="PWO "..G
    end
    if playerData.landed then
      --AIRBOSS wants to talk to you!
    end
  elseif playerData.boltered then
    grade="-- (BOLTER)"
    points=2.5 
  end

  return grade, points, G
end

--- Grade flight data.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data.
-- @param #string groovestep Step in the groove.
-- @param #AIRBOSS.GrooveData fdata Flight data in the groove.
-- @return #string LSO grade or empty string if flight data table is nil.
-- @return #number Number of deviations from perfect flight path.
function AIRBOSS:_Flightdata2Text(playerData, groovestep)

  local function little(text)
    return string.format("(%s)",text)
  end
  local function underline(text)
    return string.format("_%s_", text)
  end
  
  -- Data.
  local fdata=playerData.groove[groovestep]

  -- No flight data ==> return empty string.
  if fdata==nil then
    self:E(self.lid.."Flight data is nil.")
    return "", 0
  end

  -- Flight data.
  local step=fdata.Step
  local AOA=fdata.AoA
  local GSE=fdata.GSE
  local LUE=fdata.LUE
  local ROL=fdata.Roll
  
  -- Aircraft specific AoA values.
  local acaoa=self:_GetAircraftAoA(playerData)

  -- Speed.
  local S=nil
  if AOA>acaoa.SLOW then
    S=underline("SLO")
  elseif AOA>acaoa.Slow then
    S="SLO"
  elseif AOA>acaoa.OnSpeedMax then
    S=little("SLO")
  elseif AOA<acaoa.FAST then
    S=underline("F")
  elseif AOA<acaoa.Fast then
    S="F"
  elseif AOA<acaoa.OnSpeedMin then
    S=little("F")
  end
  
  -- Glideslope/altitude. Good [-0.25, 0.25]
  local A=nil
  if GSE>1 then
    A=underline("H")
  elseif GSE>0.5 then
    A="H"
  elseif GSE>0.25 then
    A=little("H")
  elseif GSE<-1 then
    A=underline("LO")
  elseif GSE<-0.5 then
    A="LO"
  elseif GSE<-0.25 then
    A=little("LO")
  end
  
  -- Line up. Good [-0.5, 0.5]
  local D=nil
  if LUE>3 then
    D=underline("LUL")
  elseif LUE>1 then
    D="LUL"
  elseif LUE>0.5 then
    D=little("LUL")
  elseif LUE<-3 then
    D=underline("LUR")
  elseif LUE<-1 then
    D="LUR"
  elseif LUE<-0.5 then
    D=little("LUR")
  end
  
  -- Compile.
  local G=""
  local n=0
  if S then
    G=G..S
    n=n+1
  end
  if A then
    G=G..A
    n=n+1
  end
  if D then
    G=G..D
    n=n+1
  end
  
  -- Add current step.
  local step=self:_GS(step)
  step=step:gsub("XX","X")
  if G~="" then
    G=G..step
  end
  
  -- Debug info.
  local text=string.format("LSO Grade at %s:\n", step)
  text=text..string.format("AOA=%.1f\n",AOA)
  text=text..string.format("GSE=%.1f\n",GSE)
  text=text..string.format("LUE=%.1f\n",LUE)
  text=text..string.format("ROL=%.1f\n",ROL)    
  text=text..G
  self:T3(self.lid..text)
  
  return G,n
end

--- Get short name of the grove step.
-- @param #AIRBOSS self
-- @param #number step Step
-- @return #string Shortcut name "X", "RB", "IM", "AR", "IW".
function AIRBOSS:_GS(step)
  local gp
  if step==AIRBOSS.PatternStep.FINAL then
    gp="X0"  -- Entering the groove.
  elseif step==AIRBOSS.PatternStep.GROOVE_XX then
    gp="X"  -- Starting the groove.
  elseif step==AIRBOSS.PatternStep.GROOVE_RB then
    gp="RB"  -- Roger ball call.
  elseif step==AIRBOSS.PatternStep.GROOVE_IM then
    gp="IM"  -- In the middle.
  elseif step==AIRBOSS.PatternStep.GROOVE_IC then
    gp="IC"  -- In close.
  elseif step==AIRBOSS.PatternStep.GROOVE_AR then
    gp="AR"  -- At the ramp.
  elseif step==AIRBOSS.PatternStep.GROOVE_IW then
    gp="IW"  -- In the wires.
  end
  return gp
end

--- Check if a player is within the right area.
-- @param #AIRBOSS self
-- @param #number X X distance player to carrier.
-- @param #number Z Z distance player to carrier.
-- @param #AIRBOSS.Checkpoint pos Position data limits.
-- @return #boolean If true, approach should be aborted.
function AIRBOSS:_CheckAbort(X, Z, pos)

  local abort=false
  if pos.Xmin and X<pos.Xmin then
    self:E(string.format("Xmin: X=%d < %d=Xmin", X, pos.Xmin))
    abort=true
  elseif pos.Xmax and X>pos.Xmax then
    self:E(string.format("Xmax: X=%d > %d=Xmax", X, pos.Xmax))
    abort=true
  elseif pos.Zmin and Z<pos.Zmin then
    self:E(string.format("Zmin: Z=%d < %d=Zmin", Z, pos.Zmin))
    abort=true
  elseif pos.Zmax and Z>pos.Zmax then
    self:E(string.format("Zmax: Z=%d > %d=Zmax", Z, pos.Zmax))
    abort=true
  end
  
  return abort
end

--- Generate a text if a player is too far from where he should be.
-- @param #AIRBOSS self
-- @param #number X X distance player to carrier.
-- @param #number Z Z distance player to carrier.
-- @param #AIRBOSS.Checkpoint posData Checkpoint data.
function AIRBOSS:_TooFarOutText(X, Z, posData)

  -- Intro.
  local text="you are too "
  
  -- X text.
  local xtext=nil
  if posData.Xmin and X<posData.Xmin then
    if posData.Xmin<=0 then
      xtext="far behind "
    else
      xtext="close to "
    end
  elseif posData.Xmax and X>posData.Xmax then
    if posData.LimitXmax>=0 then
      xtext="far ahead of "
    else
      xtext="close to "
    end
  end
  
  -- Z text.
  local ztext=nil
  if posData.Zmin and Z<posData.Zmin then
    if posData.Zmin<=0 then
      ztext="far port of "
    else
      ztext="close to "
    end
  elseif posData.Zmax and Z>posData.Zmax then
    if posData.Zmax>=0 then
      ztext="far starboard of "
    else
      ztext="too close to "
    end
  end
  
  -- Combine X-Z text.
  if xtext and ztext then
    text=text..xtext.." and "..ztext
  elseif xtext then
    text=text..xtext
  elseif ztext then
    text=text..ztext
  end
  
  -- Complete the sentence
  text=text.."the carrier."
  
  -- If no case could be identified.
  if xtext==nil and ztext==nil then
    text="you are too far from where you should be!"
  end
  
  return text
end

--- Pattern aborted.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data.
-- @param #number X X distance player to carrier.
-- @param #number Z Z distance player to carrier.
-- @param #AIRBOSS.Checkpoint posData Checkpoint data.
-- @param #boolean patternwo (Optional) Pattern wave off.
function AIRBOSS:_AbortPattern(playerData, X, Z, posData, patternwo)

  -- Text where we are wrong.
  local text=self:_TooFarOutText(X, Z, posData)
  
  -- Debug.
  local dtext=string.format("Abort: X=%d Xmin=%s, Xmax=%s | Z=%d Zmin=%s Zmax=%s", X, tostring(posData.Xmin), tostring(posData.Xmax), Z, tostring(posData.Zmin), tostring(posData.Zmax))
  self:E(self.lid..dtext)
  --MESSAGE:New(text, 60):ToAllIf(self.Debug)
  
  if patternwo then
  
    -- Pattern wave off!
    playerData.patternwo=true
  
    -- Tell player to depart.
    text=text.." Depart and re-enter!"
  
    -- Add to debrief.
    self:_AddToDebrief(playerData, string.format("Pattern wave off: %s", text))

    -- Next step debrief.  
    playerData.step=AIRBOSS.PatternStep.DEBRIEF
    playerData.warning=nil
  end

  -- Message to player.
  self:MessageToPlayer(playerData, text, "LSO", nil, 20)
end


--- Evaluate player's altitude at checkpoint.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data table.
-- @return #number Low score.
-- @return #number Bad score.
function AIRBOSS:_GetGoodBadScore(playerData)

  local lowscore
  local badscore
  if playerData.difficulty==AIRBOSS.Difficulty.EASY then
    lowscore=10
    badscore=20    
  elseif playerData.difficulty==AIRBOSS.Difficulty.NORMAL then
    lowscore=5
    badscore=10     
  elseif playerData.difficulty==AIRBOSS.Difficulty.HARD then
    lowscore=2.5
    badscore=5
  end
  
  return lowscore, badscore
end



--- Evaluate player's altitude at checkpoint.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data table.
-- @param #number altopt Optimal alitude in meters.
-- @return #string Feedback text.
-- @return #string Debriefing text.
function AIRBOSS:_AltitudeCheck(playerData, altopt)

  if altopt==nil then
    return nil, nil
  end

  -- Player altitude.
  local altitude=playerData.unit:GetAltitude()
  
  -- Get relative score.
  local lowscore, badscore=self:_GetGoodBadScore(playerData)
  
  -- Altitude error +-X%
  local _error=(altitude-altopt)/altopt*100
  
  local radiocall={} --#AIRBOSS.RadioCall
 
  local hint
  if _error>badscore then
    hint=string.format("You're high.")
    radiocall=AIRBOSS.LSOCall.HIGH
    radiocall.loud=true
    radiocall.subtitle=""
  elseif _error>lowscore then
    hint= string.format("You're slightly high.")
    radiocall=AIRBOSS.LSOCall.HIGH
    radiocall.loud=false
    radiocall.subtitle=""
  elseif _error<-badscore then
    hint=string.format("You're low. ")
    radiocall=AIRBOSS.LSOCall.LOW
    radiocall.loud=true
    radiocall.subtitle=""
  elseif _error<-lowscore then
    hint=string.format("You're slightly low.")
    radiocall=AIRBOSS.LSOCall.LOW
    radiocall.loud=false
    radiocall.subtitle=""
  else
    hint=string.format("Good altitude.")
  end
  
  -- Extend or decrease depending on skill.
  if playerData.difficulty==AIRBOSS.Difficulty.EASY then
    hint=hint..string.format(" Optimal altitude is %d ft.", UTILS.MetersToFeet(altopt))
  elseif playerData.difficulty==AIRBOSS.Difficulty.NORMAL then
    --hint=hint.."\n"
  elseif playerData.difficulty==AIRBOSS.Difficulty.HARD then
    hint=""
  end
  
  -- Debrief text.
  local debrief=string.format("Altitude %d ft = %d%% deviation from %d ft.", UTILS.MetersToFeet(altitude), _error, UTILS.MetersToFeet(altopt))
  
  return hint, debrief
end

--- Evaluate player's distance to the boat at checkpoint.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data table.
-- @param #number optdist Optimal distance in meters.
-- @return #string Feedback message text.
-- @return #string Debriefing text.
function AIRBOSS:_DistanceCheck(playerData, optdist)

  if optdist==nil then
    return nil, nil
  end
  
  -- Distance to carrier.
  local distance=playerData.unit:GetCoordinate():Get2DDistance(self:GetCoordinate())

  -- Get relative score.
  local lowscore, badscore = self:_GetGoodBadScore(playerData)
  
  -- Altitude error +-X%
  local _error=(distance-optdist)/optdist*100
  
  local hint
  if _error>badscore then
    hint=string.format("You're too far from the boat!")
  elseif _error>lowscore then 
    hint=string.format("You're slightly too far from the boat.")
  elseif _error<-badscore then
    hint=string.format( "You're too close to the boat!")
  elseif _error<-lowscore then
    hint=string.format("You're slightly too far from the boat.")
  else
    hint=string.format("Good distance to the boat.")
  end
  
  -- Extend or decrease depending on skill.
  if playerData.difficulty==AIRBOSS.Difficulty.EASY then
    hint=hint..string.format(" Optimal distance is %.1f NM.", UTILS.MetersToNM(optdist))
  elseif playerData.difficulty==AIRBOSS.Difficulty.NORMAL then
    --hint=hint.."\n"
  elseif playerData.difficulty==AIRBOSS.Difficulty.HARD then
    hint=""
  end

  -- Debriefing text.
  local debrief=string.format("Distance %.1f NM = %d%% deviation from %.1f NM.",UTILS.MetersToNM(distance), _error, UTILS.MetersToNM(optdist))
   
  return hint, debrief
end

--- Score for correct AoA.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data.
-- @param #number optaoa Optimal AoA.
-- @return #string Feedback message text or easy and normal difficulty level or nil for hard.
-- @return #string Debriefing text.
function AIRBOSS:_AoACheck(playerData, optaoa)

  if optaoa==nil then
    return nil, nil
  end

  -- Get relative score.
  local lowscore, badscore = self:_GetGoodBadScore(playerData)
  
  -- Player AoA
  local aoa=playerData.unit:GetAoA()
  
  -- Altitude error +-X%
  local _error=(aoa-optaoa)/optaoa*100

  local hint
  if _error>badscore then --Slow
    hint="You're slow. "
  elseif _error>lowscore then --Slightly slow
    hint="You're slightly slow. "
  elseif _error<-badscore then --Fast
    hint="You're fast. "
  elseif _error<-lowscore then --Slightly fast
    hint="You're slightly fast. "
  else --On speed
    hint="You're on speed. "
  end

  -- Extend or decrease depending on skill.
  if playerData.difficulty==AIRBOSS.Difficulty.EASY then
    hint=hint..string.format(" Optimal AoA is %.1f.", optaoa)
  elseif playerData.difficulty==AIRBOSS.Difficulty.NORMAL then
    --hint=hint.."\n"
  elseif playerData.difficulty==AIRBOSS.Difficulty.HARD then
    hint=""
  end
  
  -- Debriefing text.
  local debrief=string.format("AoA %.1f = %d%% deviation from %.1f.", aoa, _error, optaoa)
  
  return hint, debrief
end

--- Evaluate player's speed.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data table.
-- @param #number speedopt Optimal speed.
-- @return #string Feedback text.
-- @return #string Debriefing text.
function AIRBOSS:_SpeedCheck(playerData, speedopt)

  if speedopt==nil then
    return nil, nil
  end

  -- Player altitude.
  local speed=playerData.unit:GetVelocityMPS()
  
  -- Get relative score.
  local lowscore, badscore=self:_GetGoodBadScore(playerData)
  
  -- Altitude error +-X%
  local _error=(speed-speedopt)/speedopt*100
  
  local hint
  if _error>badscore then
    hint=string.format("You're fast.")
  elseif _error>lowscore then
    hint= string.format("You're slightly fast.")
  elseif _error<-badscore then
    hint=string.format("You're low.")
  elseif _error<-lowscore then
    hint=string.format("You're slightly slow.")
  else
    hint=string.format("Good speed.")
  end
  
  -- Extend or decrease depending on skill.
  if playerData.difficulty==AIRBOSS.Difficulty.EASY then
    hint=hint..string.format(" Optimal altitude is %d ft.", UTILS.MetersToFeet(speedopt))
  elseif playerData.difficulty==AIRBOSS.Difficulty.NORMAL then
    --hint=hint.."\n"
  elseif playerData.difficulty==AIRBOSS.Difficulty.HARD then
    hint=""
  end
  
  -- Debrief text.
  local debrief=string.format("Speed %d knots = %d%% deviation from %d knots optimum.", UTILS.MpsToKnots(speed), _error, UTILS.MpsToKnots(speedopt))
  
  return hint, debrief
end

--- Append text to debriefing.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data.
-- @param #string hint Debrief text of this step.
-- @param #string step (Optional) Current step in the pattern. Default from playerData.
function AIRBOSS:_AddToDebrief(playerData, hint, step)
  step=step or playerData.step
  table.insert(playerData.debrief, {step=step, hint=hint})
end

--- Debrief player and set next step.
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data.
function AIRBOSS:_Debrief(playerData)
  self:F2(self.lid..string.format("Debriefing of player %s.", playerData.name))

  -- LSO grade, points, and flight data analyis.
  local grade, points, analysis=self:_LSOgrade(playerData)
    
  -- My grade.
  local mygrade={} --#AIRBOSS.LSOgrade  
  mygrade.grade=grade
  mygrade.points=points
  mygrade.details=analysis
  mygrade.wire=playerData.wire
  mygrade.Tgroove=playerData.Tgroove
  
  -- Add grade to table.
  table.insert(playerData.grades, mygrade)
  
  -- LSO grade message.
  local text=string.format("%s %.1f PT - %s", grade, points, analysis)
  if playerData.wire then
    text=text..string.format(" %d-wire", playerData.wire)
  end
  text=text..string.format("\nYour detailed debriefing can be found via the F10 radio menu.")
  self:MessageToPlayer(playerData, text, "LSO", "", 30, true)

  -- Check if boltered or waved off?
  if playerData.boltered or playerData.waveoff or playerData.patternwo then
  
    -- Next step?
    -- TODO: CASE I: After bolter/wo turn left and climb to 600 ft and re-enter the pattern. But do not go to initial but reenter earlier?
    -- TODO: CASE I: After pattern wo? go back to initial, I guess?
    -- TODO: CASE III: After bolter/wo turn left and climb to 1200 ft and re-enter pattern?
    -- TODO: CASE III: After pattern wo? No idea...  
  
    -- Can become nil when I crashed and changed to observer. Which events are captured? Nil check for unit?
  
    if playerData.unit:IsAlive() then
    
      -- TODO: handle case where player landed even though he was waved off!
      
      if playerData.unit:InAir()==true then
    
        -- Heading and distance tip.
        local heading, distance
        
        if playerData.case==1 or playerData.case==2 then
        
          -- Get heading and distance to initial zone ~3 NM astern.
          heading=playerData.unit:GetCoordinate():HeadingTo(self.zoneInitial:GetCoordinate())
          distance=playerData.unit:GetCoordinate():Get2DDistance(self.zoneInitial:GetCoordinate())
        
        elseif playerData.case==3 then
    
          -- Get heading and distance to bullseye zone ~3 NM astern.
          local zone=self:_GetZoneBullseye(playerData.case)
          
          heading=playerData.unit:GetCoordinate():HeadingTo(zone:GetCoordinate())
          distance=playerData.unit:GetCoordinate():Get2DDistance(zone:GetCoordinate())
        
        end
          
        -- Re-enter message.
        local text=string.format("fly heading %d for %d NM to re-enter the pattern.", heading, UTILS.MetersToNM(distance))
        self:MessageToPlayer(playerData, text, "LSO", nil, 10, false, 5)
        
  
        -- Commencing again.      
        playerData.step=AIRBOSS.PatternStep.COMMENCING
        playerData.warning=nil
        
      else
      
        if playerData.waveoff then

          -- Airboss talkto!
          local text=string.format("you were waved off but landed anyway. Airboss wants to talk to you!")
          self:MessageToPlayer(playerData, text, "LSO", nil, 10, false, 2)
          
          -- Next step undefined. Player landed.
          playerData.step=AIRBOSS.PatternStep.UNDEFINED
          playerData.warning=nil
        
        end
      
      end
      
    else
      -- Unit does not seem to be alive!
      -- TODO: What now?
      self:I(self.lid..string.format("Player unit not alive!"))    
    end
        
  elseif playerData.landed and not playerData.unit:InAir() then
  
    -- Remove player unit from flight and all queues.
    self:_RemoveUnitFromFlight(playerData.unit)
  
    -- Message to player.
    self:MessageToPlayer(playerData, string.format("Welcome aboard, %s!", playerData.name), "LSO", "", 10)
    
  else

    -- Message to player.
    self:MessageToPlayer(playerData, "Undefined state after landing! Please report.", "ERROR", nil, 10)

    -- Next step.
    playerData.step=AIRBOSS.PatternStep.UNDEFINED
    playerData.warning=nil
  end
  
  -- Increase number of passes.
  playerData.passes=playerData.passes+1
  
  -- Debug message.
  MESSAGE:New(string.format("Player step %s.", playerData.step), 5, "DEBUG"):ToAllIf(self.Debug)
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- MISC functions
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Get onboard number of player or client.
-- @param #AIRBOSS self
-- @param Wrapper.Group#GROUP group Aircraft group.
-- @return #string Onboard number as string.
function AIRBOSS:_GetOnboardNumberPlayer(group)
  return self:_GetOnboardNumbers(group, true)
end

--- Get onboard numbers of all units in a group.
-- @param #AIRBOSS self
-- @param Wrapper.Group#GROUP group Aircraft group.
-- @param #boolean playeronly If true, return the onboard number for player or client skill units.
-- @return #table Table of onboard numbers.
function AIRBOSS:_GetOnboardNumbers(group, playeronly)
  --self:F({groupname=group:GetName})
  
  -- Get group name.
  local groupname=group:GetName()
  
  -- Debug text.
  local text=string.format("Onboard numbers of group %s:", groupname)
  
  -- Units of template group.
  local units=group:GetTemplate().units
  
  -- Get numbers.
  local numbers={}
  for _,unit in pairs(units) do
  
    -- Onboard number and unit name.
    local n=tostring(unit.onboard_num)
    local name=unit.name
    local skill=unit.skill

    -- Debug text.
    text=text..string.format("\n- unit %s: onboard #=%s  skill=%s", name, n, skill)

    if playeronly and skill=="Client" or skill=="Player" then
      -- There can be only one player in the group, so we skip everything else.
      return n
    end
    
    -- Table entry.
    numbers[name]=n
  end
  
  -- Debug info.
  self:T2(self.lid..text)
  
  return numbers
end

--- Check if aircraft is capable of landing on an aircraft carrier.
-- @param #AIRBOSS self
-- @param Wrapper.Unit#UNIT unit Aircraft unit. (Will also work with groups as given parameter.)
-- @return #boolean If true, aircraft can land on a carrier.
function AIRBOSS:_IsCarrierAircraft(unit)
  local carrieraircraft=false
  local aircrafttype=unit:GetTypeName()
  for _,actype in pairs(AIRBOSS.AircraftCarrier) do
    if actype==aircrafttype then
      return true
    end
  end
  return false
end

--- Checks if a human player sits in the unit.
-- @param #AIRBOSS self
-- @param Wrapper.Unit#UNIT unit Aircraft unit.
-- @return #boolean If true, human player inside the unit.
function AIRBOSS:_IsHumanUnit(unit)
  
  -- Get player unit or nil if no player unit.
  local playerunit=self:_GetPlayerUnitAndName(unit:GetName())
  
  if playerunit then
    return true
  else
    return false
  end
end

--- Checks if a group has a human player.
-- @param #AIRBOSS self
-- @param Wrapper.Group#GROUP group Aircraft group.
-- @return #boolean If true, human player inside group.
function AIRBOSS:_IsHuman(group)

  -- Get all units of the group.
  local units=group:GetUnits()
  
  -- Loop over all units.
  for _,_unit in pairs(units) do
    -- Check if unit is human.
    local human=self:_IsHumanUnit(_unit)
    if human then
      return true
    end
  end

  return false
end

--- Get fuel state in pounds.
-- @param #AIRBOSS self
-- @param Wrapper.Unit#UNIT unit The unit for which the mass is determined.
-- @return #number Fuel state in pounds.
function AIRBOSS:_GetFuelState(unit)

  -- Get relative fuel [0,1].
  local fuel=unit:GetFuel()
  
  -- Get max weight of fuel in kg.
  local maxfuel=self:_GetUnitMasses(unit)
  
  -- Fuel state, i.e. what let's 
  local fuelstate=fuel*maxfuel
  
  -- Debug info.
  self:T2(self.lid..string.format("Unit %s fuel state = %.1f kg = %.1f lbs", unit:GetName(), fuelstate, UTILS.kg2lbs(fuelstate)))
  
  return UTILS.kg2lbs(fuelstate)
end

--- Convert altitude from meters to angels (thousands of feet).
-- @param #AIRBOSS self
-- @param alt Alitude in meters.
-- @return #number Altitude in Anglels = thousands of feet using math.floor().
function AIRBOSS:_GetAngels(alt)

  local angels=math.floor(UTILS.MetersToFeet(alt)/1000)

  return angels
end

--- Get unit masses especially fuel from DCS descriptor values.
-- @param #AIRBOSS self
-- @param Wrapper.Unit#UNIT unit The unit for which the mass is determined.
-- @return #number Mass of fuel in kg.
-- @return #number Empty weight of unit in kg.
-- @return #number Max weight of unit in kg.
-- @return #number Max cargo weight in kg.
function AIRBOSS:_GetUnitMasses(unit)

  -- Get DCS descriptors table.
  local Desc=unit:GetDesc()

  -- Mass of fuel in kg.
  local massfuel=Desc.fuelMassMax or 0
  
  -- Mass of empty unit in km.
  local massempty=Desc.massEmpty or 0
  
  -- Max weight of unit in kg.
  local massmax=Desc.massMax or 0
  
  -- Rest is cargo.
  local masscargo=massmax-massfuel-massempty
  
  -- Debug info.
  self:T2(self.lid..string.format("Unit %s mass fuel=%.1f kg, empty=%.1f kg, max=%.1f kg, cargo=%.1f kg", unit:GetName(), massfuel, massempty, massmax, masscargo))
  
  return massfuel, massempty, massmax, masscargo
end

--- Get player data from unit object
-- @param #AIRBOSS self
-- @param Wrapper.Unit#UNIT unit Unit in question.
-- @return #AIRBOSS.PlayerData Player data or nil if not player with this name or unit exists.
function AIRBOSS:_GetPlayerDataUnit(unit)
  if unit:IsAlive() then
    local unitname=unit:GetName()
    local playerunit,playername=self:_GetPlayerUnitAndName(unitname)
    if playerunit and playername then
      return self.players[playername]
    end
  end
  return nil
end


--- Get player data from group object.
-- @param #AIRBOSS self
-- @param Wrapper.Group#GROUP group Group in question.
-- @return #AIRBOSS.PlayerData Player data or nil if not player with this name or unit exists.
function AIRBOSS:_GetPlayerDataGroup(group)
  local units=group:GetUnits()
  for _,unit in pairs(units) do
    local playerdata=self:_GetPlayerDataUnit(unit)
    if playerdata then
      return playerdata
    end
  end
  return nil
end

--- Returns the unit of a player and the player name. If the unit does not belong to a player, nil is returned. 
-- @param #AIRBOSS self
-- @param #string _unitName Name of the player unit.
-- @return Wrapper.Unit#UNIT Unit of player or nil.
-- @return #string Name of the player or nil.
function AIRBOSS:_GetPlayerUnitAndName(_unitName)
  self:F2(_unitName)

  if _unitName ~= nil then
  
    -- Get DCS unit from its name.
    local DCSunit=Unit.getByName(_unitName)
    
    if DCSunit then
    
      local playername=DCSunit:getPlayerName()
      local unit=UNIT:Find(DCSunit)
    
      self:T2({DCSunit=DCSunit, unit=unit, playername=playername})
      if DCSunit and unit and playername then
        return unit, playername
      end
      
    end
    
  end
  
  -- Return nil if we could not find a player.
  return nil,nil
end

--- Get carrier coalition.
-- @param #AIRBOSS self
-- @return #number Coalition side of carrier.
function AIRBOSS:GetCoalition()
  return self.carrier:GetCoalition()
end

--- Get carrier coordinate.
-- @param #AIRBOSS self
-- @return Core.Point#COORDINATE Carrier coordinate.
function AIRBOSS:GetCoordinate()
  return self.carrier:GetCoordinate()
end


--- Get mission weather.
-- @param #AIRBOSS self
function AIRBOSS:_MissionWeather()

  -- Weather data from mission file.
  local weather=env.mission.weather


  --[[
  ["clouds"] = 
  {
      ["thickness"] = 430,
      ["density"] = 7,
      ["base"] = 0,
      ["iprecptns"] = 1,
  }, -- end of ["clouds"]
  ]]  
  local clouds=weather.clouds

  --[[  
  ["fog"] = 
  {
      ["thickness"] = 0,
      ["visibility"] = 25,
  }, -- end of ["fog"]
  ]]  
  local fog=weather.fog
  
  -- Visibilty distance in meters.
  local vis=weather.visibility.distance

end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- RADIO MESSAGE Functions
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Radio queue item.
-- @type AIRBOSS.Radioitem
-- @field #number Tplay Abs time when transmission should be played.
-- @field #number Tstarted Abs time when transmission began to play.
-- @field #number prio Priority 0-100.
-- @field #boolean isplaying Currently playing.
-- @field Core.Beacon#RADIO radio Radio object.
-- @field #AIRBOSS.RadioCall call Radio call.
-- @field #boolean loud If true, play loud version of file.

--- Check radio queue for transmissions to be broadcasted.
-- @param #AIRBOSS self
-- @param #table radioqueue The radio queue.
-- @param #string name Name of the queue.
function AIRBOSS:_CheckRadioQueue(radioqueue, name)
  --env.info(string.format("FF: check radio queue %s: n=%d", name, #radioqueue))

  -- Check if queue is empty.
  if #radioqueue==0 then
    return
  end

  -- Get current abs time.
  local time=timer.getAbsTime()
  
  -- Sort results table wrt times they have already been engaged.
  local function _sort(a, b)
    return (a.Tplay < b.Tplay) or (a.Tplay==b.Tplay and a.prio < b.prio)
  end
  --table.sort(radioqueue, _sort)
  
  local playing=false
  local next=nil  --#AIRBOSS.Radioitem
  local remove=nil
  for i,_transmission in ipairs(radioqueue) do
    local transmission=_transmission  --#AIRBOSS.Radioitem
    
    -- Check if transmission time has passed.
    if time>transmission.Tplay then
      
      -- Check if transmission is currently playing.
      if transmission.isplaying then
      
        -- Check if transmission is finished.
        if time>=transmission.Tstarted+transmission.call.duration then
          
          -- Transmission over.
          transmission.isplaying=false
          remove=i
          --table.insert(remove, i)
          
        else -- still playing
        
          -- Transmission is still playing.
          playing=true
          
        end
      
      else -- not playing yet
      
        -- Not playing ==> this will be next.
        if next==nil then
          next=transmission
        end
             
      end
      
    else
      
        -- Transmission not due yet.
      
    end  
  end
  
  -- Found a new transmission.
  if next~=nil and not playing then
    self:RadioTransmit(next.radio, next.call, next.loud)
    next.isplaying=true
    next.Tstarted=time
  end
  
  -- Remove completed calls from queue.
  --for _,idx in pairs(remove) do
  if remove then
    table.remove(radioqueue, remove)
  end
  --end

end

--- Add Radio transmission to radio queue
-- @param #AIRBOSS self
-- @param Core.Radio#RADIO radio sending transmission.
-- @param #AIRBOSS.RadioCall call Radio sound files and subtitles.
-- @param #boolean loud If true, play loud sound file version.
-- @param #number delay Delay in seconds, before the message is broadcasted.
function AIRBOSS:RadioTransmission(radio, call, loud, delay)
  self:F2({radio=radio, call=call, loud=loud, delay=delay})
  
  -- Create a new radio transmission item.
  local transmission={} --#AIRBOSS.Radioitem
  
  transmission.radio=radio
  transmission.call=call
  transmission.Tplay=timer.getAbsTime()+(delay or 0)
  transmission.prio=50
  transmission.isplaying=false
  transmission.Tstarted=nil
  transmission.loud=loud and call.loud
  
  -- Add transmission to the right queue.
  if radio:GetAlias()=="LSO" then
  
    table.insert(self.RQLSO, transmission)
  
  elseif radio:GetAlias()=="MARSHAL" then
  
    table.insert(self.RQMarshal, transmission)
  
  end
end

--- Transmission radio message.
-- @param #AIRBOSS self
-- @param Core.Radio#RADIO radio sending transmission.
-- @param #AIRBOSS.RadioCall call Radio sound files and subtitles.
-- @param #boolean loud If true, play loud sound file version.
-- @param #number delay Delay in seconds, before the message is broadcasted.
function AIRBOSS:RadioTransmit(radio, call, loud, delay)
  self:E({radio=radio, call=call, loud=loud, delay=delay})  

  if (delay==nil) or (delay and delay==0) then

    -- Construct file name and subtitle.
    local filename=call.file
    local subtitle=call.subtitle
    if loud then
      if call.loud then
        filename=filename.."_Loud"
      end
      if subtitle and subtitle~="" then
        subtitle=subtitle.."!"
      end
    else
      if subtitle and subtitle~="" then
        subtitle=subtitle.."."
      end
    end
    filename=filename.."."..(call.suffix or "ogg")
      
    -- New transmission.
    radio:NewUnitTransmission(filename, call.subtitle, call.duration, radio.Frequency/1000000, radio.Modulation, false)
    
    -- Broadcast message.
    radio:Broadcast(true)
    
    -- Message "Subtitle" to all players.
    self:MessageToAll(subtitle, radio:GetAlias(), "", call.duration)
    
  else
  
    -- Scheduled transmission.
    SCHEDULER:New(nil, self.RadioTransmission, {self, radio, call, loud}, delay)
    
  end
end

--- Send text message to player client.
-- Message format will be "SENDER: RECCEIVER, MESSAGE".
-- @param #AIRBOSS self
-- @param #AIRBOSS.PlayerData playerData Player data.
-- @param #string message The message to send.
-- @param #string sender The person who sends the message or nil.
-- @param #string receiver The person who receives the message. Default player's onboard number. Set to "" for no receiver.
-- @param #number duration Display message duration. Default 10 seconds.
-- @param #boolean clear If true, clear screen from previous messages.
-- @param #number delay Delay in seconds, before the message is displayed.
-- @param #boolean soundoff If true, do not play boad number message.
function AIRBOSS:MessageToPlayer(playerData, message, sender, receiver, duration, clear, delay, soundoff)

  if playerData and message and message~="" then
  
    -- Default duration.
    duration=duration or 10

    -- Format message.          
    local text
    if receiver and receiver=="" then
      -- No (blank) receiver.
      text=string.format("%s", message)      
    else
      -- Default "receiver" is onboard number of player.
      receiver=receiver or playerData.onboard
      text=string.format("%s, %s", receiver, message)
    end
    self:I(self.lid..text)
      
    if delay and delay>0 then
      -- Delayed call.
      SCHEDULER:New(self, self.MessageToPlayer, {playerData, message, sender, receiver, duration, clear, 0, soundoff}, delay)
    else
    
      -- Send onboard number so that player is alerted about the text message.
      if receiver==playerData.onboard and not soundoff then
        if sender then
          if sender=="LSO" then
            self:_Number2Sound(self.LSORadio, receiver, delay)
          elseif sender=="MARSHAL" then
            self:_Number2Sound(self.MarshalRadio, receiver, delay)
          end
        end      
      end    
    
      -- Text message to player client.
      if playerData.client then
        MESSAGE:New(text, duration, sender, clear):ToClient(playerData.client)
      end
      
    end
    
  end
  
end

--- Send text message to all players in the CCA.
-- Message format will be "SENDER: RECCEIVER, MESSAGE".
-- @param #AIRBOSS self
-- @param #string message The message to send.
-- @param #string sender The person who sends the message or nil.
-- @param #string receiver The person who receives the message. Default player's onboard number. Set to "" for no receiver.
-- @param #number duration Display message duration. Default 10 seconds.
-- @param #boolean clear If true, clear screen from previous messages.
-- @param #number delay Delay in seconds, before the message is displayed.
-- @param #boolean soundoff If true, do not play boad number message.
function AIRBOSS:MessageToAll(message, sender, receiver, duration, clear, delay, soundoff)

  -- Make sure the onboard number sound is played only once.
  local soundoff=false
  
  for _,_player in pairs(self.players) do
    local playerData=_player --#AIRBOSS.PlayerData
    
    -- Message to all players in CCA.
    if playerData.unit:IsInZone(self.zoneCCA) then
      
      -- Message to player.
      self:MessageToPlayer(playerData, message, sender, receiver, duration, clear, delay, soundoff)
      
      -- Disable sound play of onboard number.
      soundoff=true      
    end
  end
end


--- Send text message to all players in the pattern queue.
-- Message format will be "SENDER: RECCEIVER, MESSAGE".
-- @param #AIRBOSS self
-- @param #string message The message to send.
-- @param #string sender The person who sends the message or nil.
-- @param #string receiver The person who receives the message. Default player's onboard number. Set to "" for no receiver.
-- @param #number duration Display message duration. Default 10 seconds.
-- @param #boolean clear If true, clear screen from previous messages.
-- @param #number delay Delay in seconds, before the message is displayed.
-- @param #boolean soundoff If true, do not play boad number message.
function AIRBOSS:MessageToPattern(message, sender, receiver, duration, clear, delay, soundoff)

  -- Make sure the onboard number sound is played only once.
  local soundoff=false
  
  -- Loop over all flights in the pattern queue.
  for _,_player in pairs(self.Qpattern) do
    local playerData=_player --#AIRBOSS.PlayerData
    
    -- Message only to human pilots.
    if not playerData.ai then
      
      -- Message to player.
      self:MessageToPlayer(playerData, message, sender, receiver, duration, clear, delay, soundoff)
      
      -- Disable sound play of onboard number.
      soundoff=true      
    end     
  end
end

--- Send text message to all players in the marshal queue.
-- Message format will be "SENDER: RECCEIVER, MESSAGE".
-- @param #AIRBOSS self
-- @param #string message The message to send.
-- @param #string sender The person who sends the message or nil.
-- @param #string receiver The person who receives the message. Default player's onboard number. Set to "" for no receiver.
-- @param #number duration Display message duration. Default 10 seconds.
-- @param #boolean clear If true, clear screen from previous messages.
-- @param #number delay Delay in seconds, before the message is displayed.
-- @param #boolean soundoff If true, do not play boad number message.
function AIRBOSS:MessageToMarshal(message, sender, receiver, duration, clear, delay, soundoff)

  -- Make sure the onboard number sound is played only once.
  local soundoff=false
  
  -- Loop over all flights in the marshal queue.
  for _,_player in pairs(self.Qmarshal) do
    local playerData=_player --#AIRBOSS.PlayerData
    
    -- Message only to human pilots.
    if not playerData.ai then
      
      -- Message to player.
      self:MessageToPlayer(playerData, message, sender, receiver, duration, clear, delay, soundoff)
      
      -- Disable sound play of onboard number.
      soundoff=true
    end     
  end
end


--- Convert a number (as string) into a radio message.
-- E.g. for board number or headings.
-- @param #AIRBOSS self
-- @param Core.Radio#RADIO radio Radio used for transmission.
-- @param #string number Number string, e.g. "032" or "183".
-- @param #number delay Delay before transmission in seconds.
function AIRBOSS:_Number2Sound(radio, number, delay)

  --- Split string into characters.
  local function _split(str)
    local chars={}
    for i=1,#str do
      local c=str:sub(i,i)
      table.insert(chars, c)
    end
    return chars
  end
  
  -- Get radio alias.
  local alias=radio:GetAlias()
  
  local sender=""
  if alias=="LSO" then
    sender="LSOCall"
  elseif alias=="MARSHAL" then
    sender="MarshalCall"
  --elseif alias=="AIRBOSS" then
  --  sender="AirbossCall"
  else
    self:E(self.lid.."ERROR: Unknown radio alias!")
  end
  
  -- Split string into characters.
  local numbers=_split(number)
  
  for i=1,#numbers do
  
    -- Current number
    local n=numbers[i]
    
    if n=="0" then
      self:RadioTransmission(radio, AIRBOSS[sender].N0, false, delay)
    elseif n=="1" then
      self:RadioTransmission(radio, AIRBOSS[sender].N1, false, delay)
    elseif n=="2" then
      self:RadioTransmission(radio, AIRBOSS[sender].N2, false, delay)
    elseif n=="3" then
      self:RadioTransmission(radio, AIRBOSS[sender].N3, false, delay)
    elseif n=="4" then
      self:RadioTransmission(radio, AIRBOSS[sender].N4, false, delay)
    elseif n=="5" then
      self:RadioTransmission(radio, AIRBOSS[sender].N5, false, delay)
    elseif n=="6" then
      self:RadioTransmission(radio, AIRBOSS[sender].N6, false, delay)
    elseif n=="7" then
      self:RadioTransmission(radio, AIRBOSS[sender].N7, false, delay)    
    elseif n=="8" then
      self:RadioTransmission(radio, AIRBOSS[sender].N8, false, delay)    
    elseif n=="9" then
      self:RadioTransmission(radio, AIRBOSS[sender].N9, false, delay)
    else
      self:E(self.lid..string.format("ERROR: Unknown number %s!", tostring(n)))
    end
  end

end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- RADIO MENU Functions
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Add menu commands for player.
-- @param #AIRBOSS self
-- @param #string _unitName Name of player unit.
function AIRBOSS:_AddF10Commands(_unitName)
  self:F(_unitName)
  
  -- Get player unit and name.
  local _unit, playername = self:_GetPlayerUnitAndName(_unitName)
  
  -- Check for player unit.
  if _unit and playername then

    -- Get group and ID.
    local group=_unit:GetGroup()
    local gid=group:GetID()
    
    -- Player Data.
    local playerData=self.players[playername]    
  
    if group and gid and playerData then
  
      if not self.menuadded[gid] then
      
        -- Enable switch so we don't do this twice.
        self.menuadded[gid]=true
  
        -- Main F10 menu: F10/Airboss/<Carrier Name>/
        if AIRBOSS.MenuF10[gid]==nil then
          AIRBOSS.MenuF10[gid]=missionCommands.addSubMenuForGroup(gid, "Airboss")
        end
        
        -- F10/Airboss/<Carrier>
        local _rootPath=missionCommands.addSubMenuForGroup(gid, self.alias, AIRBOSS.MenuF10[gid])
        
        --------------------------------        
        -- F10/Airboss/<Carrier>/F1 Help
        --------------------------------
        local _helpPath=missionCommands.addSubMenuForGroup(gid, "Help", _rootPath)
        -- F10/Airboss/<Carrier>/F1 Help/F1 Skill Level
        local _skillPath=missionCommands.addSubMenuForGroup(gid, "Skill Level", _helpPath)
        -- F10/Airboss/<Carrier>/F1 Help/F1 Skill Level/
        missionCommands.addCommandForGroup(gid, "Flight Student",  _skillPath, self._SetDifficulty, self, playername, AIRBOSS.Difficulty.EASY)   -- F1
        missionCommands.addCommandForGroup(gid, "Naval Aviator",   _skillPath, self._SetDifficulty, self, playername, AIRBOSS.Difficulty.NORMAL) -- F2
        missionCommands.addCommandForGroup(gid, "TOPGUN Graduate", _skillPath, self._SetDifficulty, self, playername, AIRBOSS.Difficulty.HARD)   -- F3
        -- F10/Airboss/<Carrier>/F1 Help/F2 Mark Zones
        local _markPath=missionCommands.addSubMenuForGroup(gid, "Mark Zones", _helpPath)
        -- F10/Airboss/<Carrier>/F1 Help/F3 Mark Zones/
        missionCommands.addCommandForGroup(gid, "Smoke Pattern Zones",   _markPath, self._MarkCaseZones,   self, _unitName, false)  -- F1
        missionCommands.addCommandForGroup(gid, "Flare Pattern Zones",   _markPath, self._MarkCaseZones,   self, _unitName, true)   -- F2        
        missionCommands.addCommandForGroup(gid, "Smoke My Marshal Zone", _markPath, self._MarkMarshalZone, self, _unitName, false)  -- F3
        missionCommands.addCommandForGroup(gid, "Flare My Marshal Zone", _markPath, self._MarkMarshalZone, self, _unitName, true)   -- F4
        -- F10/Airboss/<Carrier>/F1 Help/
        missionCommands.addCommandForGroup(gid, "My Status",           _helpPath, self._DisplayPlayerStatus, self, _unitName)   -- F4
        missionCommands.addCommandForGroup(gid, "Attitude Monitor",    _helpPath, self._AttitudeMonitor,     self,  playername) -- F5
        missionCommands.addCommandForGroup(gid, "Radio Check LSO",     _helpPath, self._LSORadioCheck,       self, _unitName)   -- F6
        missionCommands.addCommandForGroup(gid, "Radio Check Marshal", _helpPath, self._MarshalRadioCheck,   self, _unitName)   -- F7
        missionCommands.addCommandForGroup(gid, "[Reset My Status]",   _helpPath, self._ResetPlayerStatus,   self, _unitName)   -- F8

        -------------------------------------
        -- F10/Airboss/<Carrier>/F2 Kneeboard
        -------------------------------------
        local _kneeboardPath=missionCommands.addSubMenuForGroup(gid, "Kneeboard", _rootPath)        
        -- F10/Airboss/<Carrier>/F2 Kneeboard/F1 Results
        local _resultsPath=missionCommands.addSubMenuForGroup(gid, "Results", _kneeboardPath)
        -- F10/Airboss/<Carrier>/F2 Kneeboard/F1 Results/
        missionCommands.addCommandForGroup(gid, "Greenie Board", _resultsPath, self._DisplayScoreBoard,   self, _unitName) -- F1
        missionCommands.addCommandForGroup(gid, "My LSO Grades", _resultsPath, self._DisplayPlayerGrades, self, _unitName) -- F2
        missionCommands.addCommandForGroup(gid, "Last Debrief",  _resultsPath, self._DisplayDebriefing,   self, _unitName) -- F3
        -- F10/Airboss/<Carrier/F2 Kneeboard/
        missionCommands.addCommandForGroup(gid, "Carrier Info",   _kneeboardPath, self._DisplayCarrierInfo,    self, _unitName) -- F2
        missionCommands.addCommandForGroup(gid, "Weather Report", _kneeboardPath, self._DisplayCarrierWeather, self, _unitName) -- F3
        missionCommands.addCommandForGroup(gid, "Set Section",    _kneeboardPath, self._SetSection,            self, _unitName) -- F4

        -------------------------
        -- F10/Airboss/<Carrier>/
        -------------------------
        missionCommands.addCommandForGroup(gid, "Request Marshal",    _rootPath, self._RequestMarshal,   self, _unitName) -- F3
        missionCommands.addCommandForGroup(gid, "Request Commence",   _rootPath, self._RequestCommence,  self, _unitName) -- F4
        missionCommands.addCommandForGroup(gid, "Request Refueling",  _rootPath, self._RequestRefueling, self, _unitName) -- F5
      end
    else
      self:T(self.lid.."Could not find group or group ID in AddF10Menu() function. Unit name: ".._unitName)
    end
  else
    self:T(self.lid.."Player unit does not exist in AddF10Menu() function. Unit name: ".._unitName)
  end

end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ROOT MENU
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Reset player status. Player is removed from all queues and its status is set to undefined.
-- @param #AIRBOSS self
-- @param #string _unitName Name fo the player unit.
function AIRBOSS:_ResetPlayerStatus(_unitName)
  self:F(_unitName)
  
  -- Get player unit and name.
  local _unit, _playername = self:_GetPlayerUnitAndName(_unitName)
    
  -- Check if we have a unit which is a player.
  if _unit and _playername then
    local playerData=self.players[_playername] --#AIRBOSS.PlayerData
        
    if playerData then
      
      -- Inform player.
      local text="Status reset executed! You have been removed from all queues."
      self:MessageToPlayer(playerData, text, nil, "")
      
      -- Remove from marhal stack can collapse stack if necessary.
      if self:_InQueue(self.Qmarshal, playerData.group) then
        self:_CollapseMarshalStack(playerData, true)
      end 
      
      -- Remove flight from queues.
      self:_RemoveFlight(playerData)
      
      -- Initialize player data.
      self:_InitPlayer(playerData)
        
    end
  end
end

--- LSO radio check. Will broadcase LSO message at given LSO frequency.
-- @param #AIRBOSS self
-- @param #string _unitName Name fo the player unit.
function AIRBOSS:_LSORadioCheck(_unitName)
  self:F(_unitName)
  
  -- Get player unit and name.
  local _unit, _playername = self:_GetPlayerUnitAndName(_unitName)
    
  -- Check if we have a unit which is a player.
  if _unit and _playername then
    local playerData=self.players[_playername] --#AIRBOSS.PlayerData        
    if playerData then    
      -- Broadcase LSO radio check message on LSO radio.
      self:RadioTransmission(self.LSORadio, AIRBOSS.LSOCall.RADIOCHECK)
    end
  end
end

--- Marshal radio check. Will broadcase Marshal message at given Marshal frequency.
-- @param #AIRBOSS self
-- @param #string _unitName Name fo the player unit.
function AIRBOSS:_MarshalRadioCheck(_unitName)
  self:F(_unitName)
  
  -- Get player unit and name.
  local _unit, _playername = self:_GetPlayerUnitAndName(_unitName)
    
  -- Check if we have a unit which is a player.
  if _unit and _playername then
    local playerData=self.players[_playername] --#AIRBOSS.PlayerData        
    if playerData then    
      -- Broadcase Marshal radio check message on Marshal radio.
      self:RadioTransmission(self.MarshalRadio, AIRBOSS.MarshalCall.RADIOCHECK)
    end
  end
end

--- Request marshal.
-- @param #AIRBOSS self
-- @param #string _unitName Name fo the player unit.
function AIRBOSS:_RequestMarshal(_unitName)
  self:F(_unitName)
  
  -- Get player unit and name.
  local _unit, _playername = self:_GetPlayerUnitAndName(_unitName)
    
  -- Check if we have a unit which is a player.
  if _unit and _playername then
    local playerData=self.players[_playername] --#AIRBOSS.PlayerData
        
    if playerData then
    
      -- Check if player is in CCA
      local inCCA=playerData.unit:IsInZone(self.zoneCCA)
      
      if inCCA then
      
        if self:_InQueue(self.Qmarshal, playerData.group) then
        
          -- Flight group is already in marhal queue.
          local text=string.format("you are already in the Marshal queue. New marshal request denied!")
          self:MessageToPlayer(playerData, text, "MARSHAL")       
        
        elseif self:_InQueue(self.Qpattern, playerData.group) then
          
          -- Flight group is already in pattern queue.
          local text=string.format("you are already in the Pattern queue. Marshal request denied!")
          self:MessageToPlayer(playerData, text, "MARSHAL")       
          
        elseif not _unit:InAir() then 

          -- Flight group is already in pattern queue.
          local text=string.format("you are not airborn. Marshal request denied!")
          self:MessageToPlayer(playerData, text, "MARSHAL")       
        
        else
        
          -- TODO: check if recovery window is open.
      
          -- Add flight to marshal stack.
          self:_MarshalPlayer(playerData)
          
        end
        
      else
      
        -- Flight group is not in CCA yet.
        local text=string.format("you are not inside CCA yet. Marshal request denied!")
        self:MessageToPlayer(playerData, text, "MARSHAL")
        
      end
    end
  end
end

--- Request to commence approach.
-- @param #AIRBOSS self
-- @param #string _unitName Name fo the player unit.
function AIRBOSS:_RequestCommence(_unitName)
  self:F(_unitName)
  
  -- Get player unit and name.
  local _unit, _playername = self:_GetPlayerUnitAndName(_unitName)
  
  -- Check if we have a unit which is a player.
  if _unit and _playername then
    local playerData=self.players[_playername] --#AIRBOSS.PlayerData
    
    if playerData then

      -- Check if unit is in CCA.
      local text      
      if _unit:IsInZone(self.zoneCCA) then
      
        if self:_InQueue(self.Qmarshal, playerData.group) then
        
          -- Flight group is already in marhal queue.
          text=string.format("%s, you are already in the Marshal queue. Commence request denied!", playerData.name)        
        
        elseif self:_InQueue(self.Qpattern, playerData.group) then
          
          -- Flight group is already in pattern queue.
          text=string.format("%s, you are already in the Pattern queue. Commence request denied!", playerData.name)
          
        elseif not _unit:InAir() then 

          -- Flight group is already in pattern queue.
          text=string.format("%s, you are not airborn. Commence request denied!", playerData.name)
        
        else      
      
          -- Get stack value.
          local stack=playerData.flag:Get()
          
          -- Check if player is in the lowest stack.
          if stack>1 then
            -- We are in a higher stack.
            text="Negative ghostrider, it's not your turn yet!"
          else
          
            -- Number of aircraft currently in pattern.
            local _,npattern=self:_GetQueueInfo(self.Qpattern)
                
            -- Check if pattern is already full.
            if npattern>=self.Nmaxpattern then  
              -- Patern is full!
              text=string.format("Negative ghostrider, pattern is full!\nThere are %d aircraft currently in the pattern.", npattern)
            else
              -- Positive response.
              if playerData.case==1 then
                text="Proceed to initial."
              else
                text="Descent at 4k ft/min to platform at 5000 ft."
              end
              
              -- Set player step.
              playerData.step=AIRBOSS.PatternStep.COMMENCING
              playerData.warning=nil
              
              -- Collaps marshal stack.
              self:_CollapseMarshalStack(playerData, false)
            end
          
          end
          
        end
      else
        -- This flight is not yet registered!
        text="Negative ghostrider, you are not inside the CCA yet!"
      end
      
      -- Debug
      self:I(self.lid..text)
      
      -- Send message.
      self:MessageToPlayer(playerData, text, "MARSHAL") 
    end
  end
end

--- Player requests refueling. 
-- @param #AIRBOSS self
-- @param #string _unitName Name of the player unit.
function AIRBOSS:_RequestRefueling(_unitName)

  -- Get player unit and name.
  local _unit, _playername = self:_GetPlayerUnitAndName(_unitName)
  
  -- Check if we have a unit which is a player.
  if _unit and _playername then
    local playerData=self.players[_playername] --#AIRBOSS.PlayerData
    
    if playerData then
    
      -- Check if there is a recovery tanker defined.
      local text
      if self.tanker then
          
        -- Check if player is in CCA.
        if _unit:IsInZone(self.zoneCCA) then
              
          -- Check if tanker is running or refueling or returning.
          if self.tanker:IsRunning() or self.tanker:IsRefueling() then
          
            -- Get alt of tanker in angels.
            local angels=UTILS.Round(UTILS.MetersToFeet(self.tanker.altitude)/1000, 0)
          
            -- Tanker is up and running.
            text=string.format("Proceed to tanker at angels %d.", angels)
            
            -- State TACAN channel of tanker if defined.
            if self.tanker.TACANon then
              text=text..string.format("\nTanker TACAN channel %d%s (%s)", self.tanker.TACANchannel, self.tanker.TACANmode, self.tanker.TACANmorse)
            end
            
            -- Tanker is currently refueling. Inform player.
            if self.tanker:IsRefueling() then
              text=text.."\nTanker is currently refueling. You might have to queue up."
            end
            
            -- Collapse marshal stack if player is in queue.
            if self:_InQueue(self.Qmarshal, playerData.group) then
              -- TODO: What if only the player and not his section wants to refuel?!
              self:_CollapseMarshalStack(playerData, true)
            end
          elseif self.tanker:IsReturning() then
            -- Tanker is RTB.
            text="Tanker is RTB. Request denied!\nWait for the tanker to be back on station if you can."
          end
          
        else
          text="You are not registered inside the CCA yet. Request denied!"
        end
      else
        text="No refueling tanker available. Request denied!"
      end
      
      -- Send message.
      self:MessageToPlayer(playerData, text, "MARSHAL")      
    end
  end
end

--- Set all flights within 200 meters to be part of my section.
-- @param #AIRBOSS self
-- @param #string _unitName Name of the player unit.
function AIRBOSS:_SetSection(_unitName)

  -- Get player unit and name.
  local _unit, _playername = self:_GetPlayerUnitAndName(_unitName)
  
  -- Check if we have a unit which is a player.
  if _unit and _playername then
    local playerData=self.players[_playername] --#AIRBOSS.PlayerData
    
    if playerData then

      -- Coordinate of flight lead.
      local mycoord=_unit:GetCoordinate()
      
      -- Check if player is in Marshal or pattern queue already.
      local text      
      if self:_InQueue(self.Qmarshal,playerData.group) then
        text=string.format("You are already in the Marshal queue. Setting section no possible any more!")
      elseif self:_InQueue(self.Qpattern, playerData.group) then
        text=string.format("You are already in the Pattern queue. Setting section no possible any more!")
      else
      
        -- Init array
        playerData.section={}
      
        -- Loop over all registered flights.
        for _,_flight in pairs(self.flights) do
          local flight=_flight --#AIRBOSS.FlightGroup
          
          -- Only human flight groups excluding myself.
          if flight.ai==false and flight.groupname~=playerData.groupname then
          
            -- Distance to other group.
            local distance=flight.group:GetCoordinate():Get2DDistance(mycoord)
            
            if distance<200 then
              table.insert(playerData.section, flight)
            end
            
          end
        end
          
        -- Info on section members.
        if #playerData.section>0 then
          text=string.format("Registered flight section:")
          text=text..string.format("- %s (lead)", playerData.name)
          for _,_flight in paris(playerData.section) do
            local flight=_flight --#AIRBOSS.PlayerData
            text=text..string.format("- %s", flight.name)
            flight.seclead=playerData.name
            
            -- Inform player that he is now part of a section.
            self:MessageToPlayer(flight, string.format("Your section lead is now %s.", playerData.name), "MARSHAL")
          end
        else
          text="No other human flights found within radius of 200 meters!"
        end
      end
      
      -- Message to section lead.
      self:MessageToPlayer(playerData, text, "MARSHAL")
    end
  end

end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- RESULTS MENU
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Display top 10 player scores.
-- @param #AIRBOSS self
-- @param #string _unitName Name fo the player unit.
function AIRBOSS:_DisplayScoreBoard(_unitName)
  self:F(_unitName)
  
  -- Get player unit and name.
  local _unit, _playername = self:_GetPlayerUnitAndName(_unitName)
  
  -- Check if we have a unit which is a player.
  if _unit and _playername then
  
    -- Results table.
    local _playerResults={}
    
    -- Player data of requestor.
    local playerData=self.players[_playername]  --#AIRBOSS.PlayerData
  
    -- Message text.
    local text = string.format("Greenie Board:")
    
    for _playerName,_playerData in pairs(self.players) do
    
      local Paverage=0
      for _,_grade in pairs(_playerData.grades) do
        Paverage=Paverage+_grade.points
      end
      _playerResults[_playerName]=Paverage
    
    end
    
    --Sort list!
    local _sort=function(a, b) return a>b end
    table.sort(_playerResults,_sort)
    
    local i=1
    for _playerName,_points in pairs(_playerResults) do
      text=text..string.format("\n[%d] %.1f %s", i,_points,_playerName)
      i=i+1
    end
    
    --env.info("FF:\n"..text)

    -- Send message.
    if playerData.client then
      MESSAGE:New(text, 30, nil, true):ToClient(playerData.client)
    end
  
  end
end

--- Display top 10 player scores.
-- @param #AIRBOSS self
-- @param #string _unitName Name fo the player unit.
function AIRBOSS:_DisplayPlayerGrades(_unitName)
  self:F(_unitName)
  
  -- Get player unit and name.
  local _unit, _playername = self:_GetPlayerUnitAndName(_unitName)
  
  -- Check if we have a unit which is a player.
  if _unit and _playername then
    local playerData=self.players[_playername] --#AIRBOSS.PlayerData
    
    if playerData then
    
      -- Grades of player:
      local text=string.format("Your grades, %s:", _playername)
      
      local p=0
      for i,_grade in pairs(playerData.grades) do
        local grade=_grade --#AIRBOSS.LSOgrade
        
        text=text..string.format("\n[%d] %s %.1f PT - %s", i, grade.grade, grade.points, grade.details)
        p=p+grade.points
      end
      
      -- Number of grades.
      local n=#playerData.grades
      
      if n>0 then
        text=text..string.format("\nAverage points = %.1f", p/n)
      else
        text=text..string.format("\nNo data available.")
      end
      
      --env.info("FF:\n"..text)
      
      -- Send message.
      if playerData.client then
        MESSAGE:New(text, 30, nil, true):ToClient(playerData.client)
      end
    end
  end
end

--- Display last debriefing.
-- @param #AIRBOSS self
-- @param #string _unitName Name fo the player unit.
function AIRBOSS:_DisplayDebriefing(_unitName)
  self:F(_unitName)
  
  -- Get player unit and name.
  local _unit, _playername = self:_GetPlayerUnitAndName(_unitName)
  
  -- Check if we have a unit which is a player.
  if _unit and _playername then
    local playerData=self.players[_playername] --#AIRBOSS.PlayerData
    
    if playerData then
        
      -- Debriefing text.
      local text=string.format("Debriefing:")
     
      -- Check if data is present. 
      if #playerData.debrief>0 then      
        text=text..string.format("\n================================\n")
        for _,_data in pairs(playerData.debrief) do
          local step=_data.step
          local comment=_data.hint
          text=text..string.format("* %s:\n",step)
          text=text..string.format("%s\n", comment)
        end
      else
        text=text.." Nothing to show yet."
      end
      
      -- Send debrief message to player
      self:MessageToPlayer(playerData, text, nil , "", 30, true)
      
    end
  end
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- SKIL LEVEL MENU
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Set difficulty level.
-- @param #AIRBOSS self
-- @param #string playername Player name.
-- @param #AIRBOSS.Difficulty difficulty Difficulty level.
function AIRBOSS:_SetDifficulty(playername, difficulty)
  self:E({difficulty=difficulty, playername=playername})
  
  local playerData=self.players[playername]  --#AIRBOSS.PlayerData
  
  if playerData then
    playerData.difficulty=difficulty
    local text=string.format("your difficulty level is now: %s.", difficulty)
    self:MessageToPlayer(playerData, text, nil, playerData.name, 5)
  else
    self:E(self.lid..string.format("ERROR: Could not get player data for player %s.", playername))
  end
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- KNEEBOARD MENU
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Turn player's aircraft attitude display on or off.
-- @param #AIRBOSS self
-- @param #string playername Player name.
function AIRBOSS:_AttitudeMonitor(playername)
  self:E({playername=playername})
  
  local playerData=self.players[playername]  --#AIRBOSS.PlayerData
  
  if playerData then
    playerData.attitudemonitor=not playerData.attitudemonitor
  end
end


--- Report information about carrier.
-- @param #AIRBOSS self
-- @param #string _unitname Name of the player unit.
function AIRBOSS:_DisplayCarrierInfo(_unitname)
  self:E(_unitname)
  
  -- Get player unit and player name.
  local unit, playername = self:_GetPlayerUnitAndName(_unitname)
  
  -- Check if we have a player.
  if unit and playername then
  
    -- Player data.  
    local playerData=self.players[playername]  --#AIRBOSS.PlayerData
    
    if playerData then
       
      -- Current coordinates.
      local coord=self:GetCoordinate()    
    
      -- Carrier speed and heading.
      local carrierheading=self.carrier:GetHeading()
      local carrierspeed=UTILS.MpsToKnots(self.carrier:GetVelocityMPS())
        
      -- Tacan/ICLS.
      local tacan="unknown"
      local icls="unknown"
      if self.TACANon and self.TACANchannel~=nil then
        tacan=string.format("%d%s (%s)", self.TACANchannel, self.TACANmode, self.TACANmorse)
      end
      if self.ICLSon and self.ICLSchannel~=nil then
        icls=string.format("%d (%s)", self.ICLSchannel, self.ICLSmorse)
      end
      
      -- Get groups, units in queues.
      local Nmarshal,nmarshal=self:_GetQueueInfo(self.Qmarshal, playerData.case)
      local Npattern,npattern=self:_GetQueueInfo(self.Qpattern)
      
      -- Current abs time.
      local Tabs=timer.getAbsTime()
      
      -- Get recovery times of carrier.
      local recoverytext="Recovery time windows (max 5):"
      if #self.recoverytimes==0 then
        recoverytext=recoverytext.." none!"
      else
        -- Loop over recovery windows.
        local rw=0
        for _,_recovery in pairs(self.recoverytimes) do
          local recovery=_recovery --#AIRBOSS.Recovery
          -- Only include current and future recovery windows.
          if Tabs<recovery.STOP then
            -- Output text.
            recoverytext=recoverytext..string.format("\n- %s - %s: Case %d", UTILS.SecondsToClock(recovery.START), UTILS.SecondsToClock(recovery.STOP), recovery.CASE)
            rw=rw+1
            if rw>=5 then
              -- Break the loop after 5 recovery times.
              break
            end
          end
        end
      end
      
      -- Message text.
      local text=string.format("%s info:\n", self.alias)
      text=text..string.format("=============================================\n")      
      text=text..string.format("Carrier state %s\n", self:GetState())
      text=text..string.format("Case %d recovery\n", self.case)
      text=text..string.format("BRC %03d°\n", self:GetBRC())
      text=text..string.format("FB %03d°\n", self:GetFinalBearing(true))           
      text=text..string.format("Speed %d kts\n", carrierspeed)
      text=text..string.format("Marshal radio %.3f MHz\n", self.MarshalFreq) --TODO: add modulation
      text=text..string.format("LSO radio %.3f MHz\n", self.LSOFreq)
      text=text..string.format("TACAN Channel %s\n", tacan)
      text=text..string.format("ICLS Channel %s\n", icls)
      text=text..string.format("# A/C total %d\n", #self.flights)
      text=text..string.format("# A/C marshal %d (%d)\n", Nmarshal, nmarshal)
      text=text..string.format("# A/C pattern %d (%d)\n", Npattern, npattern)
      text=text..string.format(recoverytext)
      self:T2(self.lid..text)
            
      -- Send message.
      self:MessageToPlayer(playerData, text, nil, "", 20, true)
      
    else
      self:E(self.lid..string.format("ERROR: Could not get player data for player %s.", playername))
    end   
  end  
  
end


--- Report weather conditions at the carrier location. Temperature, QFE pressure and wind data.
-- @param #AIRBOSS self
-- @param #string _unitname Name of the player unit.
function AIRBOSS:_DisplayCarrierWeather(_unitname)
  self:E(_unitname)

  -- Get player unit and player name.
  local unit, playername = self:_GetPlayerUnitAndName(_unitname)
  self:E({playername=playername})
  
  -- Check if we have a player.
  if unit and playername then
  
    -- Message text.
    local text=""
   
    -- Current coordinates.
    local coord=self:GetCoordinate()
    
    -- Get atmospheric data at carrier location.
    local T=coord:GetTemperature()
    local P=coord:GetPressure()
    local Wd,Ws=coord:GetWind()
    
    -- Get Beaufort wind scale.
    local Bn,Bd=UTILS.BeaufortScale(Ws)
    
    local WD=string.format('%03d°', Wd)
    local Ts=string.format("%d°C",T)
    
    local settings=_DATABASE:GetPlayerSettings(playername) or _SETTINGS --Core.Settings#SETTINGS
    
    local tT=string.format("%d°C",T)
    local tW=string.format("%.1f m/s", Ws)
    local tP=string.format("%.1f mmHg", UTILS.hPa2mmHg(P))
    if settings:IsImperial() then
      tT=string.format("%d°F", UTILS.CelciusToFarenheit(T))
      tW=string.format("%.1f knots", UTILS.MpsToKnots(Ws))
      tP=string.format("%.2f inHg", UTILS.hPa2inHg(P))      
    end
              
    -- Report text.
    text=text..string.format("Weather Report at Carrier %s:\n", self.alias)
    text=text..string.format("=============================================\n")      
    text=text..string.format("Temperature %s\n", tT)
    text=text..string.format("Wind from %s at %s (%s)\n", WD, tW, Bd)
    text=text..string.format("QFE %.1f hPa = %s", P, tP)
       
    -- Debug output.
    self:T2(self.lid..text)
    
    -- Send message to player group.
    self:MessageToPlayer(self.players[playername], text, nil, "", 30, true)
    
  else
    self:E(self.lid..string.format("ERROR! Could not find player unit in CarrierWeather! Unit name = %s", _unitname))
  end      
end



--- Display player status.
-- @param #AIRBOSS self
-- @param #string _unitName Name of the player unit.
function AIRBOSS:_DisplayPlayerStatus(_unitName)

  -- Get player unit and name.
  local _unit, _playername = self:_GetPlayerUnitAndName(_unitName)
  
  -- Check if we have a unit which is a player.
  if _unit and _playername then
    local playerData=self.players[_playername] --#AIRBOSS.PlayerData
    
    if playerData then
    
      -- Stack and stack altitude.
      local stack=playerData.flag:Get()
      local stackalt=UTILS.MetersToFeet(self:_GetMarshalAltitude(stack))
      
      -- Fuel and fuel state.
      local fuel=playerData.unit:GetFuel()*100
      local fuelstate=self:_GetFuelState(playerData.unit)      
       
      -- Player data.
      local text=string.format("Status of player %s (%s)\n", playerData.name, playerData.callsign)
      text=text..string.format("=============================================\n")      
      text=text..string.format("Current step: %s\n", playerData.step)
      text=text..string.format("Skil level: %s\n", playerData.difficulty)
      text=text..string.format("Aircraft: %s\n", playerData.actype)
      text=text..string.format("Board number: %s\n", playerData.onboard)
      text=text..string.format("Fuel state: %.1f lbs/1000 (%.1f %%)\n", fuelstate/1000, fuel)
      text=text..string.format("Stack: %d alt=%d ft\n", stack, stackalt)
      text=text..string.format("Group: %s\n", playerData.group:GetName())
      text=text..string.format("# units: %d (n=%d)\n", #playerData.group:GetUnits(), playerData.nunits)
      text=text..string.format("Section Lead: %s\n", tostring(playerData.seclead))
      text=text..string.format("# section: %d", #playerData.section)
      for _,_sec in pairs(playerData.section) do
        local sec=_sec --#AIRBOSS.PlayerData
        text=text..string.format("\n- %s", sec.name)
      end
      
      if playerData.step==AIRBOSS.PatternStep.INITIAL then
      
        -- Heading and distance to initial zone.
        local flyhdg=playerData.unit:GetCoordinate():HeadingTo(self.zoneInitial:GetCoordinate())
        local flydist=UTILS.MetersToNM(playerData.unit:GetCoordinate():Get2DDistance(self.zoneInitial:GetCoordinate()))
        local brc=self:GetBRC()

        -- Help player to find its way to the initial zone.                
        text=text..string.format("\nFly heading %03d° for %.1f NM and turn to BRC %03d°.", flyhdg, flydist, brc)
                
      elseif playerData.step==AIRBOSS.PatternStep.PLATFORM then

        -- Heading and distance to platform zone.
        local flyhdg=playerData.unit:GetCoordinate():HeadingTo(self:_GetZonePlatform(playerData.case):GetCoordinate())
        local flydist=UTILS.MetersToNM(playerData.unit:GetCoordinate():Get2DDistance(self.zoneInitial:GetCoordinate()))
        local fb=self:GetFinalBearing(true)

        -- Help player to find its way to the initial zone.                
        text=text..string.format("\nFly heading %03d° for %.1f NM and turn to FB %03d°.", flyhdg, flydist, fb)
              
      end
      
      -- Send message.
      self:MessageToPlayer(playerData, text, nil, "", 30, true)
    end
  end
  
end

--- Mark current marshal zone of player by either smoke or flares.
-- @param #AIRBOSS self
-- @param #string _unitName Name of the player unit.
-- @param #boolean flare If true, flare the zone. If false, smoke the zone.
function AIRBOSS:_MarkMarshalZone(_unitName, flare)

  -- Get player unit and name.
  local _unit, _playername = self:_GetPlayerUnitAndName(_unitName)
  
  -- Check if we have a unit which is a player.
  if _unit and _playername then
    local playerData=self.players[_playername] --#AIRBOSS.PlayerData
    
    if playerData then
    
      -- Get player stack and recovery case.
      local stack=playerData.flag:Get()
      local case=playerData.case
      
      local text=""
      if stack>0 then
    
        -- Get current holding zone.
        local zone=self:_GetZoneHolding(case, stack)
        
        -- Pattern alitude.
        local patternalt=self:_GetMarshalAltitude(stack, case)
        
        patternalt=0
        
        if flare then
          text="Marking marshal zone with WHITE flares."
          zone:FlareZone(FLARECOLOR.White, 45, nil, patternalt)
        else
          text="Marking marshal zone with WHITE smoke."
          zone:SmokeZone(SMOKECOLOR.White, 45, patternalt)
        end
        
      else
        text="You are currently not in a marshal stack. No zone to mark!"
      end
      
      -- Send message to player.
      self:MessageToPlayer(playerData, text, "MARSHAL")
    end
  end
  
end


--- Mark CASE I or II/II zones by either smoke or flares.
-- @param #AIRBOSS self
-- @param #string _unitName Name of the player unit.
-- @param #boolean flare If true, flare the zone. If false, smoke the zone.
function AIRBOSS:_MarkCaseZones(_unitName, flare)

  -- Get player unit and name.
  local _unit, _playername = self:_GetPlayerUnitAndName(_unitName)
  
  -- Check if we have a unit which is a player.
  if _unit and _playername then
    local playerData=self.players[_playername] --#AIRBOSS.PlayerData
    
    if playerData then

      -- Player's recovery case.
      local case=playerData.case
      
      -- Initial 
      local text=string.format("Marking CASE %d zones\n", case)
      
      -- Flare or smoke?
      if flare then

        -- Case I/II: Initial
        if case==1 or case==2 then
          text=text.."* initial with WHITE flares\n"
          self.zoneInitial:FlareZone(FLARECOLOR.White, 45)
        end
      
        -- Case II/III: approach corridor
        if case==2 or case==3 then
          text=text.."* approach corridor with GREEN flares\n"
          self:_GetZoneCorridor(case):FlareZone(FLARECOLOR.Green, 45)
        end
        
        -- Case II/III: platform
        if case==2 or case==3 then
          text=text.."* platform with RED flares\n"
          self:_GetZonePlatform(case):FlareZone(FLARECOLOR.Red, 45)
        end
        
        -- Case III: dirty up
        if case==3 then
          text=text.."* dirty up with YELLOW flares\n"
          self:_GetZoneDirtyUp(case):FlareZone(FLARECOLOR.Yellow, 45)
        end
        
        -- Case II/III: arc in/out
        if case==2 or case==3 then
          if math.abs(self.holdingoffset)>0 then
            self:_GetZoneArcIn(case):FlareZone(FLARECOLOR.Yellow, 45)
            text=text.."* arc turn in with YELLOW flares\n"
            self:_GetZoneArcOut(case):FlareZone(FLARECOLOR.White, 45)
           text=text.."* arc trun out with WHITE flares\n"
          end
        end
        
        -- Case III: bullseye
        if case==3 then
          text=text.."* bullseye with WHITE flares\n"
          self:_GetZoneBullseye(case):FlareZone(FLARECOLOR.White, 45)
        end
        
      else

        -- Case I/II: Initial      
        if case==1 or case==2 then
          text=text.."* initial with WHITE smoke\n"
          self.zoneInitial:SmokeZone(SMOKECOLOR.White, 45)
        end
        
        -- Case II/III: Approach Corridor
        if case==2 or case==3 then
          text=text.."* approach corridor with GREEN smoke\n"
          self:_GetZoneCorridor(case):SmokeZone(SMOKECOLOR.Green, 45)
        end

        -- Case II/III: platform
        if case==2 or case==3 then
          text=text.."* platform with RED smoke\n"
          self:_GetZonePlatform(case):SmokeZone(SMOKECOLOR.Red, 45)
        end

        -- Case II/III: arc in/out if offset>0.
        if case==2 or case==3 then
          if math.abs(self.holdingoffset)>0 then
            self:_GetZoneArcIn(case):SmokeZone(SMOKECOLOR.Blue, 45)
            text=text.."* arc turn in with BLUE smoke\n"
            self:_GetZoneArcOut(case):SmokeZone(SMOKECOLOR.Blue, 45)
            text=text.."* arc trun out with BLUE smoke\n"
          end
        end

        -- Case III: dirty up
        if case==3 then
          text=text.."* dirty up with ORANGE smoke\n"
          self:_GetZoneDirtyUp(case):SmokeZone(SMOKECOLOR.Orange, 45)
        end

        -- Case III: bullseye
        if case==3 then                
          text=text.."* bullseye with WHITE smoke\n"
          self:_GetZoneBullseye(case):SmokeZone(SMOKECOLOR.White, 45)
        end
        
      end
      
      -- Send message to player.
      self:MessageToPlayer(playerData, text, "MARSHAL")
    end
  end
  
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
