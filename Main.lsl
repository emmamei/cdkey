// Main.lsl
//
// vim:sw=4 et nowrap:
//
// DATE: 22 March 2013

string optiondate = "12 December 2013";

string ZWSP = "​"; // This is not an empty string it's a Zero Width Space Character
                  // used for a safe parameter seperator in messages.

// Note that some doll types are special....
//    - regular: used for standard Dolls, including non-transformable
//    - slut: can be stripped (like Pleasure Dolls)
//    - Display: poses dont time out
//    - Key: doesnt wind down - Doll can be worn by other Dolly as Key
//    - Builder: doesnt wind down

//========================================
// VARIABLES
//========================================

// Transforming Keys:
//
// A TransformingKey is - or was - set by the presence of a
// Transform.lsl script in the Key. It makes a call into this
// script, thus:
//
//     llMessageLinked(LINK_THIS, 18, "here", dollID);
//
// and triggers a setting of the following variable,
// making this a transforming key:
//
integer isTransformingKey = 0;
//
// All other settings of this variable have been removed,
// including the SetDefaults and the NCPrefs.

integer configured;

integer channel_chat = 75;
integer visible = 1;
string dollName;
integer permissionsGranted;
integer signOn;
integer detachable = 1;
integer autoTP;
integer pleasureDoll;
integer helpless;
integer canFly = 1;
integer hasController;
integer windDown = 1;
integer afk;
integer warned;
integer doWarnings;
integer canSit = 1;
integer canAFK = 1;
integer canStand = 1;
integer canCarry = 1;
//integer canPose;
integer ticks = 2;   // ticks per minute
float lastEmergencyTime;
integer emergencyLimitHours = 12;
integer emergencyLimitTime = 43200; // (60 * 60 * emergencyLimitHours) // measured in seconds
integer RLVok;
integer RLVck;

key ncPrefsKey;
string ncName = "Preferences";
integer ncLine;
//string cmdPrefix;

key lmHomeDataRequest;
key lmHomeLoadedUUID = NULL_KEY;
string lmHomeName = "Home";
vector lmHomeGlobal;

key msgTarget;
key stringRequest;

string rlvAPIversion;

// This variable is used to set the collapse animation - and documentation
string collapseAnim = "collapse";

// Keys of important people in life of the Key:
key MasterBuilder = "42c7aaec-38bc-4b0c-94dd-ae562eb67e6d";   // Christina Halpin
key  MasterWinder = "64d26535-f390-4dc4-a371-a712b946daf8";   // GreigHighland
key        DevOne = "c5e11d0a-694f-46cc-864b-e42340890934";   // MayStone
key        DevTwo = "2fff40f0-ea4a-4b52-abb8-d4bf6b1c98c9";   // Silky Mesmeriser

// Current Controller - or Mistress
key MistressID = MasterBuilder;
list rescuerList = [ MasterBuilder, MasterWinder ];
list developerList = [ DevOne, DevTwo ];

integer canDress = 1;
integer takeoverAllowed;

key dollID;
key carrierID;
key dresserID;
key toucherID;

// use these to redisplay the Main Touch Menu over and over
key mainToucherID;
list mainMenu;
string mainMessage;

string httpstart = "http://communitydolls.com/";
integer channel_dialog;
//integer cd3666;
//integer cd6012;
integer cd4667;
integer cd5666;

// If the key is a Transforming Key - one that can transform from one
// type of Doll to another - this tracks the current type of doll.
string dollType = "Regular";

// these are measured in timer tics - not minutes or seconds
// assuming a clock interval of 10 seconds -
// so multiply by 6 for factors
integer windamount   = 60; // 30 * ticks;    // 30 minutes
integer deflimit     = 360; // 180 * ticks;   // 180 minutes - worksafe (3h)
integer keylimit     = deflimit;
//integer poselimit    = 30;     // 5 minutes
integer hackLimit    = 720; // 6 * 60 * ticks;   // 6 hours

integer tok; // time factor
integer tokFactor = 2; // time factor: for slowdowns: measures ticks
integer timeLeftOnKey = windamount;
//integer posetime;
integer pose;
integer carried;
integer collapsed;
string currentAnimation;
string newAnimation;
string carriername;
string mistressname;
key mistressQuery;
string newState;
integer listen_id_mainmenu;
integer listen_id_stripmenu;
integer listen_id_controllermenu;
integer listen_id_optionmenu;
integer listen_id_commands;
integer controlLock;


//========================================
// FUNCTIONS
//========================================

//----------------------------------------
// Utility Functions
//----------------------------------------
string wwGetSLUrl() {
    string globe = "http://maps.secondlife.com/secondlife";
    string region = llGetRegionName();
    vector pos = llGetPos();
    string posx = (string)llRound(pos.x);
    string posy = (string)llRound(pos.y);
    string posz = (string)llRound(pos.z);

    return (globe + "/" + llEscapeURL(region) +"/" + posx + "/" + posy + "/" + posz);
}

string FormatFloat(float val, integer dp)
{
    string out = "ERROR";
    if (dp == 0) {
        out = (string)llRound(val);
    } else if (dp > 0 && dp <= 6) {
        val = llRound(val * llPow(10.0, dp)) / llPow(10.0, dp);
        out = llGetSubString((string)val, 0, -7 + dp);
    }
    return out;
}

memReport() {
    integer free_memory = llGetFreeMemory();
    integer used_memory = llGetUsedMemory();
    
    llOwnerSay("Main: Using " + FormatFloat(used_memory/1024.0, 2) + " of " + FormatFloat((used_memory + free_memory)/1024.0, 2) + " kB script memory, " + 
               FormatFloat(free_memory/1024.0, 2) + " kBytes free");
}

//---------------------------------------
// Configuration Functions
//---------------------------------------
// This code assumes a human-generated config file
processConfiguration(string data) {

    // Notecard done
    if (data == EOF) {
        configured = 1;
        listenerStart();
        llSetTimerEvent(60 / ticks);
        return;
    }
    integer i = llSubStringIndex(data, "=");

    // Configuration lines contain equals sign
    if (i != -1) {

        // Get parts of configuration: name and value
        string name = llGetSubString(data, 0, i - 1);
        string value = llGetSubString(data, i + 1, -1);

        // Trim input and lowercase name
        name = llStringTrim(llToLower(name), STRING_TRIM);
        value = llStringTrim(value, STRING_TRIM);

        //----------------------------------------
        // Assign values to program variables

        if (name == "doll type") {
            // Ensure proper capitalization for matching or display
            dollType = llGetSubString(llToUpper(value), 0, 0) + llGetSubString(llToLower(value), 1, -1);
        }
        else if (name == "wind time") {
            windamount = (integer)value * ticks;
        }
        else if (name == "max time") {
            deflimit = (integer)value * ticks;
            keylimit = deflimit;
        }
        else if (name == "helpless dolly") {
            helpless = (integer)value;
        }
        else if (name == "controller") {
            MistressID = (key)value;
            hasController = 1;
            llMessageLinked(LINK_SET, 100, "MistressID", MistressID);
            takeoverAllowed = 0; // there is a Mistress; takeover is irrelevant
            mistressQuery = llRequestAgentData(MistressID, DATA_NAME);
        }
        else if (name == "auto tp") {
            autoTP = (integer)value;
        }
        else if (name == "pleasure doll") {
            pleasureDoll = (integer)value;
        }
        else if (name == "detachable") {
            detachable = (integer)value;
        }
        else {
            // Unknown configuration
            llSay(DEBUG_CHANNEL,"Unknown configuration value: " + name + " on line " + (string)ncLine);
        }
    }
}

stopAnimations() {
    list anims = llGetAnimationList(dollID);
    integer n;
    string anim;
    integer animCount = llGetListLength(anims);

    for ( n = 0; n < animCount; n++ ) {
        anim = llList2String(anims, n);

        llStopAnimation(anim);
        llSleep(0.5);
    }
    llSetColor( <0,1,0>, ALL_SIDES );
}

becomeController(key ToucherID) {
    takeoverAllowed = 0;
    hasController = 1;

    MistressID = ToucherID;

    // Mistress is present: use llKey2Name()
    mistressname = llKey2Name(ToucherID);

    llOwnerSay("Your carrier, " + mistressname + ", has become your controller.");
    //llSay(0, mistressname + " has become controller of the doll " + dollName + ".");

    // Note that the response goes to 9999 - a nonsense channel
    string msg = "You are now controller of " + dollName + ". See " + httpstart + "controller.htm for more information.";
    llDialog(ToucherID, msg, ["OK"], 9999);
}

// doOptionsMenu() for all of the options related to the Key
//
//    * can outfit
//    * can carry
//    * detachable
//    * warnings
//    * sitting
//    * auto TP
//    * self TP
//    * flying
//    * "pleasure doll"
//    * takeover
//    * remove sign

doOptionsMenu(key ToucherID) {
    integer controller;
    if (isMistress(ToucherID)) controller = 1;
    
    string msg = "See " + httpstart + "keychoices.htm for explanation. (" + optiondate + " version)";
    list pluslist;
    
    if (controller) {
        msg = "See " + httpstart + "controller.htm. Choose what you want to happen. (" + optiondate + " version)";
        pluslist += "drop control";
    }
    
    if (!canDress) pluslist += "can outfit";
    else pluslist += "no outfitting";

    if (!canCarry) pluslist += "can carry";
    else pluslist += "no carry";

    // One-way option
    if (detachable) pluslist += "no detaching";
    else if (controller) pluslist += "detachable";

    if (doWarnings) pluslist += "no warnings";
    else pluslist += "warnings";

    if (canSit) pluslist += "no sitting";
    else pluslist += "can sit";

    // One-way option
    if (!autoTP) pluslist += "auto tp";
    else if (controller) pluslist += "no auto tp";

    // One-way option
    if (!helpless) pluslist += "no self tp";
    else if (controller) pluslist += "self tp";

    // One-way option
    if (canFly) pluslist += "no flying";
    else if (controller) pluslist += "can fly";

    if (pleasureDoll) pluslist += "no pleasure";
    else pluslist += "pleasure doll";

    if (!hasController) {
        if (takeoverAllowed) pluslist += "no takeover";
        else pluslist += "allow takeover";
    }

    if (isTransformingKey) {
        if (signOn) pluslist += "turn off sign";
        else pluslist += "turn on sign";
    }

    llDialog(toucherID, msg, pluslist, cd5666);
}

integer windKey() {
    integer winding = windamount;

    // Return if winding is irrelevant
    if (timeLeftOnKey >= keylimit)
        return 0;

    // Winding...
    timeLeftOnKey += windamount;

    // Is key overwound?
    if (timeLeftOnKey > keylimit) {

        // Compute actual amount of time wound
        winding = windamount - (timeLeftOnKey - keylimit);

        // Clip time left on key
        timeLeftOnKey = keylimit;
        llOwnerSay("You have been fully wound - " + (string) (keylimit / ticks) + " minutes remaining.");
    }
    return (winding);
}

doWind(string name) {
    integer winding = windKey() / ticks;

    if (winding > 0) {
        llRegionSayTo(toucherID, 0, "You have given " + dollName + " " + (string)winding + " more minutes of life.");
    }
    llRegionSayTo(toucherID, 0, "Doll is now at " + FormatFloat(((float)timeLeftOnKey / (float)keylimit) / 100.0, 2) + "% of capacity.");

    if (timeLeftOnKey == keylimit) {
        llSay(0, dollName + " has been fully wound by " + name + ".");
    }
    // Is this too spammy?
    llOwnerSay("Have you remembered to thank " + name + " for winding you?");
}

integer isMistress(key id) {
    list mastersList = [ MistressID, MasterBuilder, MasterWinder ];
    return (llListFindList(mastersList, [ id ]) != -1);
}

handlemenuchoices(string choice, string name, key ToucherID) {
    toucherID = ToucherID;

    if (choice == "Carry") {
        // Doll has been picked up...
        carried = 1;
        carriername = name;
        carrierID = ToucherID;

        llMessageLinked(LINK_SET, 305, "carried", carrierID);

        llSay(0, dollName + " has been picked up by " + carriername);
    }
    else if (choice == "Place Down") {
        uncarry();
    }
    else if (choice == "Type of Doll") {
        llMessageLinked(LINK_THIS, 17, name, ToucherID);
    }
    else if (choice == "Pose") {
        llMessageLinked(LINK_THIS, 22, "menu", ToucherID);
    }
    else if (choice == "Unpose") {
        //doUnpose(ToucherID);
        pose = 0;
        aoChange("on");
    }
    else if (choice == "Allow Takeover") {
        takeoverAllowed = 1;
    }
    else if (choice == "Wind") {
        if (collapsed) {  //uncollapsing
            llSay(DEBUG_CHANNEL, "+> Restore from collapse");
            restoreFromCollapse();
            llSay(DEBUG_CHANNEL, "+> Done restore from collapse");
        }
        llSay(DEBUG_CHANNEL, "+> Wind");
        doWind(name);
        llSay(DEBUG_CHANNEL, "+> Done Wind");
        // FIXME: mainMessage is wrong at this point...
        llDialog(mainToucherID, mainMessage, mainMenu, channel_dialog);
    }
    else if (choice == "Dress") {
        llMessageLinked(LINK_THIS, 1, "start", ToucherID);
        if (!(ToucherID == dollID)) {
            llOwnerSay(name + " is looking at your dress menu");
        }
    }
    else if (choice == "Strip") {
        llDialog(ToucherID, "Take off:",
            ["Top", "Bra", "Bottom", "Panties", "Shoes"],
            cd4667);
    }
    else if (choice == "Be Controller") {
        becomeController(ToucherID);
    }
    else if (choice == "Use Control" || choice == "Options") {
        doOptionsMenu(ToucherID);
    }
    else if (choice == "Detach") {
        aoChange("on");
        if (RLVok) llOwnerSay("@clear,detachme=force");
    }
    else if (choice == "Invisible") {
        visible = 0;
        llSetLinkAlpha(LINK_SET, 0, ALL_SIDES);
        llOwnerSay("Your key fades from view...");
        //doFade(LINK_SET, 1.0, 0.0, ALL_SIDES, 0.1);
    }
    else if (choice == "Visible") {
        visible = 1;
        llSetLinkAlpha(LINK_SET, 1, ALL_SIDES);
        llOwnerSay("Your key appears magically.");
        //doFade(LINK_SET, 0.0, 1.0, ALL_SIDES, 0.1);
    }
    else if (choice == "Reload Config") {
        llResetScript();
    }
    else if (choice == "TP Home") {
        if (ToucherID != dollID) llRegionSayTo(ToucherID, 0, "Teleporting dolly " + dollName + " to their home landmark.");
        rlvTeleportDoll(lmHomeGlobal);
    }
    else if (choice == "Toggle AFK") {
        if (afk) {
            if (dollType == "Regular" || !signOn) llSetText("", <1,1,1>, 1);
            else llSetText(dollType, <1,1,1>, 1);

            afk = 0;
            llMessageLinked(LINK_SET, 305, "unsetAFK" + ZWSP + (string)(timeLeftOnKey / ticks), NULL_KEY);
        }
        else {
            afk = 1;
            tok = tokFactor;
            
            llMessageLinked(LINK_SET, 305, "setAFK" + ZWSP + (string)(tokFactor) + ZWSP + (string)(timeLeftOnKey / ticks), NULL_KEY);
        }
    }
}

rlvTeleportDoll(vector global) {
    string locx = (string)llFloor(global.x);
    string locy = (string)llFloor(global.y);
    string locz = (string)llFloor(global.z);
    
    llOwnerSay("Dolly will now teleport home.");
    
    if (RLVok) {
        llOwnerSay("@tpto:" + locx + "/" + locy + "/" + locz + "=force");
    }
}

aoChange(string choice) {
    integer g_iAOChannel = -782690;
    integer g_iInterfaceChannel = -12587429;
    integer LockMeisterChannel = -8888;

    if (choice == "off" || choice == "stop") {
        string AO_OFF = "ZHAO_STANDOFF";
        llWhisper(g_iInterfaceChannel, "CollarComand|499|" + AO_OFF);
        llWhisper(LockMeisterChannel, (string)dollID + "bootoff");
        llWhisper(g_iAOChannel, AO_OFF);
        llMessageLinked(LINK_SET, 0, "ZHAO_AOON", NULL_KEY);
    }
    else {
        string AO_ON = "ZHAO_STANDON";
        llWhisper(g_iInterfaceChannel, "CollarComand|499|" + AO_ON);
        llWhisper(LockMeisterChannel, (string)dollID + "booton");
        llWhisper(g_iAOChannel, AO_ON);
        llMessageLinked(LINK_SET, 0, "ZHAO_AOON", NULL_KEY);
    }
}

uncarry() {
    // Doll already not being carried...
    if (!carried)
        return;

    carried = 0;

    if (RLVok) {
        llOwnerSay("@accepttp:" + (string) carrierID + "=rem");
        llOwnerSay("@tplure:"   + (string) carrierID + "=rem");
        llOwnerSay("@showinv=y");

        // If not collapsed, enable TP abilities
        if (!collapsed) {
            llOwnerSay("@tplure=y");

            if (!helpless) {
                llOwnerSay("@tplm=y,tploc=y");
            }
        }

        // If autoTP is enabled, set it
        if (autoTP) {
            llOwnerSay("@accepttp=add");
        }
    }

    llSay(0, dollName + " was being carried by " + carriername + " and has been set down.");
    carrierID = NULL_KEY;
}

initializeStart ()  {
    // Stop all current animations: that means if you
    // attach the key when dancing - dancing will stop
    //restoreFromCollapse();
    aoChange("on");

    //llRequestPermissions(dollID, PERMISSION_TRIGGER_ANIMATION);
    llSetLinkAlpha(LINK_SET, 1, ALL_SIDES);

    dollName = llGetDisplayName(dollID);
    llSay(0, dollName + " is now a dolly - anyone may play with their Key.");

    // This hack makes Key work on no-script land
    llTakeControls(CONTROL_FWD, 1, 1);   
                    
    // Check for home landmark
    if (llGetInventoryType(lmHomeName) == INVENTORY_LANDMARK) {
        lmHomeDataRequest = llRequestInventoryData(lmHomeName);
    }
}

listenerStart () {
    // Get a unique number
    integer ncd = ( -1 * (integer)("0x" + llGetSubString((string)llGetKey(),-7,-1)) ) - 1;

    if (channel_dialog != ncd) {
        llListenRemove(listen_id_mainmenu);
        llListenRemove(listen_id_stripmenu);
        llListenRemove(listen_id_optionmenu);
        llListenRemove(listen_id_commands);

        // channel_dialog = Main key menu
        //         cd6012 = Controller menu
        //         cd4667 = Strip clothing menu
        //         cd5666 = Dolly options menu
        //   channel_chat = Chat commands

        channel_dialog = ncd;
        cd4667 = channel_dialog - 4667;
        cd5666 = channel_dialog - 5666;

        // Create Listeners
        listen_id_mainmenu       = llListen(channel_dialog, "", "", "");
        listen_id_stripmenu      = llListen(cd4667,         "", "", "");
        listen_id_optionmenu     = llListen(cd5666,         "", "", "");
        listen_id_commands       = llListen(channel_chat,   "", llGetOwner(), "");
    }
}

initFinal() {
    llOwnerSay("You have " + (string)(timeLeftOnKey / ticks) + " minutes of life remaning.");

    // When rezzed.... if currently being carried, drop..
    if (carried) {
        uncarry();
    }

    // When rezzed.... if collapsed... no escape!
    if (collapsed) {
        collapse("start");
    }

    // Start clock ticks
    llSetTimerEvent(60 / ticks);
    
    // This is our finial init step report memory
    memReport();
}

//----------------------------------------
// Collapse functions / data
//----------------------------------------

// This clears ONLY the collapse animation....
restoreFromCollapse() {
    // Rotate key: around Z access at rate .3 and gain 1
    llTargetOmega(<0,0,1>, .3, 1);
    llSetText("", <1,1,1>, 1);

    llMessageLinked(LINK_SET, 305, "restore", NULL_KEY);

    // Clear animation
    newState = "nothing";
    collapsed = 0;
    controlLock = 0;

    // Remove this eventually
    llRequestPermissions(dollID, PERMISSION_TAKE_CONTROLS|PERMISSION_TRIGGER_ANIMATION);

    // This hack makes Key work on no-script land
    llTakeControls(CONTROL_FWD, 1, 1);   

    aoChange("on");
}

collapse(string s) {
    visible = 1;
    
    aoChange("off");

    if (hasController) {
        llMessageLinked(LINK_THIS, 11, (dollName + " has collapsed at this location: " + wwGetSLUrl()), MistressID);
    }

    // Set this so an "animated" but disabled dolly can be identified
    llSetText("Disabled Dolly!", <1,1,1>, 1);

    llMessageLinked(LINK_SET, 305, "collapse", NULL_KEY);

    newAnimation = collapseAnim;
    newState = "collapsed";
    pose = 0;
    collapsed = 1;
    controlLock = 1;

    // Remove this eventually
    llRequestPermissions(dollID, PERMISSION_TAKE_CONTROLS|PERMISSION_TRIGGER_ANIMATION);

    // Lock up controls
    llTakeControls( CONTROL_FWD        |
                    CONTROL_BACK       |
                    CONTROL_LEFT       |
                    CONTROL_RIGHT      |
                    CONTROL_ROT_LEFT   |
                    CONTROL_ROT_RIGHT  |
                    CONTROL_UP         |
                    CONTROL_DOWN       |
                    CONTROL_LBUTTON    |
                    CONTROL_ML_LBUTTON |
                    0, 1, 0);

    // No emotes for dolly
    if (RLVok) llOwnerSay("@rediremote:999=add");

    // Rotation: all stop
    llTargetOmega(ZERO_VECTOR, 0, 0);

    // Key is made visible again when collapsed
    llSetLinkAlpha(LINK_SET, 1, ALL_SIDES);
}

//========================================
// STATES
//========================================

// default state should be changed to normal state

default {

    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    // This should set up generic defaults
    // not specific to owner
    state_entry() {
        dollID = llGetOwner();
        
        llSetText("", <1,1,1>, 1);

        // If Transform script present reset to ensure registration
        if (llGetInventoryType("Transform") == INVENTORY_SCRIPT) llResetOtherScript("Transform");
    
        // Rotate self: around Z access at rate .3 and gain 1
        llTargetOmega(<0,0,1>, .3, 1);

        // set controls so we work in no-script land
        // FIXME: this could be a "set and forget" permission request for the entire script
        controlLock = 0;
        llRequestPermissions(dollID, PERMISSION_TAKE_CONTROLS|PERMISSION_TRIGGER_ANIMATION);

        //----------------------------------------
        initializeStart();
        //----------------------------------------

        llResetOtherScript("RLV");
        llSleep(0.5);
        llResetOtherScript("Start");
    }

    //----------------------------------------
    // INITIAL REZ
    //----------------------------------------
    // This takes place when a user logs back in....

    on_rez(integer iParam) {  //when key is put on, or when logging back on
        // Reset RLV script
        llResetOtherScript("RLV");
    }

    //----------------------------------------
    // ATTACH
    //----------------------------------------
    attach(key id) {
        if (id == NULL_KEY) { // NULL_KEY = detach
            llOwnerSay("The key is wrenched from your back, and you double over at the " +
                       "unexpected pain as the tendrils are ripped out. You feel an emptiness, " +
                       "as if some beautiful presence has been removed.");
        }
    }

    //----------------------------------------
    // DATASERVER
    //----------------------------------------
    dataserver(key query_id, string data) {
        if (query_id == mistressQuery) {
            mistressname = data;
            llOwnerSay("Your mistress is " + mistressname);
        } else if (query_id == lmHomeDataRequest) {
            if ((vector)data != ZERO_VECTOR) {
                lmHomeGlobal = llGetRegionCorner() + (vector)data;
                lmHomeLoadedUUID = llGetInventoryKey(lmHomeName);
            }
        }
    }

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    changed(integer change) {
        if (change & CHANGED_INVENTORY)  {
            // Update Dress script if inventory changes
            // Why? This is the keys inventory not the avatars
            //llResetOtherScript("Dress");
            
            if (llGetInventoryKey(lmHomeName) != lmHomeLoadedUUID) {
                lmHomeDataRequest = llRequestInventoryData(lmHomeName);
                lmHomeLoadedUUID = llGetInventoryKey(lmHomeName);
            }

            // Reset configuration if inventory changes... but...
            // Do we want to allow updating info -- on the fly -- through
            // simple change of notecard?
            //initConfiguration();
        }

        // Reset if owner chaned
        if (change & CHANGED_OWNER) {
            llResetScript();
        }
    }

    //----------------------------------------
    // KEY TOUCHED
    //----------------------------------------
    touch_start(integer total_number) {
        key ToucherID = llDetectedKey(0);  //detects user UUID
        string ToucherName = llDetectedName(0);  //detects user UUID
        string msg;
        list menu =  ["Wind"];

        toucherID = ToucherID;

        // Compute "time remaining" message
        string timeleft;

        {
            integer minsleft = timeLeftOnKey / ticks;

            if (minsleft > 0) {
                timeleft = "Dolly has " + (string)minsleft + " minutes remaining. ";

                timeleft += " Key is ";
                if (!windDown) {
                    timeleft += "not ";
                }
                timeleft += "winding down";
                if (afk && windDown) {
                    timeleft += " but at reduced rate (by a factor of " + (string)tokFactor + ")";
                }

                timeleft += ". ";
            }
            else {
                timeleft = "Dolly has no time left.";
                uncarry();
            }
        }

        // Can the doll be dressed? Add menu button
        if (canDress) {
            menu += "Dress";
        }

        // Can the doll be transformed? Add menu button
        if (isTransformingKey) {
            menu += "Type of Doll";
        }

        // Is the doll being carried? ...and who clicked?
        if (carried) {
            // Three possibles:
            //   1. Doll
            //   2. Carrier
            //   3. Someone else

            // Doll being carried clicked on key
            if (ToucherID == dollID) {
                msg = "You are being carried by " + carriername + ".";
                menu = ["OK"];

                // Allows user to permit current carrier to take over and become Mistress
                if (!hasController) {
                    if (!takeoverAllowed) {
                        menu += "Allow Takeover";
                    }
                }
            }

            // Doll's carrier clicked on key
            else if (ToucherID == carrierID) {
                msg = "Place Down frees " + dollName + " when you are done with her";
                menu += ["Place Down","Pose"];
                if (pose) {
                    menu += "Unpose";
                }

                if (!hasController) {
                    if (takeoverAllowed) {
                        menu += "Be Controller";
                    }
                }

                // Is doll strippable?
                if ((pleasureDoll || dollType == "Slut") && RLVok) {
                    menu += "Strip";
                }
            }

            // Someone else clicked on key
            else {
                msg = dollName + " is currently being carried by " + carriername + ". They have full control over this doll.";
                menu = ["OK"];
            }
        }
        else if (collapsed) {
            if (ToucherID == dollID) {
                msg = "You need winding.";
                menu = ["OK"];
            }
        }
        else {    //not  being carried, not collapsed - normal in other words
            // Toucher could be...
            //   1. Doll
            //   2. Someone else

            // Is toucher the Doll?
            if (ToucherID == dollID) {
                msg = "See " + httpstart + "dollkeyselfinfo.htm for more information.";
                menu = ["Dress","Options"];

                if (pose) {
                    menu += "Unpose";
                }

                menu += "Pose";

                if (canAFK) {
                    menu += "Toggle AFK";
                }

                if (detachable) {
                    menu += "Detach";
                }

                if (visible) {
                    menu += "Invisible";
                }
                else {
                    menu += "Visible";
                }
                
                if (lmHomeLoadedUUID != NULL_KEY) {
                   menu += "TP Home";
                }

                if (isTransformingKey) {
                    menu += "Type of Doll";
                }
            }
            // Toucher is not Doll.... could be anyone
            else {
                msg =  dollName + " is a doll and likes to be treated like " +
                       "a doll. So feel free to use these options. ";

                // Hide the general "Carry" option for all but Mistress when one exists
                if (isMistress(ToucherID) || (!hasController)) {
                    if (canCarry) {
                        msg =  msg +
                               "Carry option picks up " + dollName + " and temporarily" +
                               " makes the Dolly exclusively yours. ";

                        menu += "Carry";
                    }
                }

                if (pose) {
                    //msg += "Doll is currently in the " + currentAnimation + " pose. ";
                    msg += "Doll is currently posed. ";
                }

                msg += "See " + httpstart + "communitydoll.htm for more information. " ;

                if (pose) {
                    menu += "Unpose";
                }

                menu += "Pose";
            }
        }

        // If toucher is Mistress and NOT self...
        //
        // That is, you can't be your OWN Mistress...
        if ((isMistress(ToucherID)) &&
           !(ToucherID == dollID)) {
            menu += "Use Control";
        }

        mainToucherID = ToucherID;
        mainMessage = timeleft + " " + msg;
        mainMenu = menu;

        llDialog(mainToucherID, mainMessage, mainMenu, channel_dialog);
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {   // called every timeinterval (tick)
        // Doing the following every tick:
        //    1. Are we checking for RLV? Reset...
        //    2. Carrier still present (in region)?
        //    3. Is Doll away?
        //    4. Wind down
        //    5. How far away is carrier? ("follow")

        if (collapsed) {
            // nothing
        } else {

            // Is carrier still around?
            if (carried) {
                if(llGetAgentSize(carrierID)) {
                    //uuid is an avatar in the region: OK
                } else {
                    uncarry();
                }
            }

            // When Dolly is "away" - enter AFK
            if (llGetAgentInfo(dollID) & AGENT_AWAY) {
                afk = 1;
                tok = tokFactor;
                llMessageLinked(LINK_SET, 305, "autoSetAFK" + ZWSP + (string)(tokFactor) + ZWSP + (string)(timeLeftOnKey / ticks), NULL_KEY);
            }

            // wind down only if not collapsed

            //--------------------------------
            // WINDING DOWN..... tic by tic
            if (windDown) {
                //timex = llGetAndResetTime();
                // AFK: Away From Keyboard
                if (afk) {
                    tok -= 1;
                    if (tok < 1) {
                        timeLeftOnKey -= 1;
                        tok = tokFactor;
                    }
                }
                else {
                    // timeLeftOnKey -= timex
                    timeLeftOnKey -= 1;
                }

                integer minLeftOnKey = timeLeftOnKey / ticks;

                if (doWarnings) {
                    if ((minLeftOnKey == 30  ||
                         minLeftOnKey == 15  ||
                         minLeftOnKey == 10  ||
                         minLeftOnKey ==  5  ||
                         minLeftOnKey ==  2) && !warned) {
                        // FIXME: This can be seen as a spammy message - especially if there are too many warnings
                        llSay(0, dollName + " has " + (string) minLeftOnKey + " minutes left before they run down!");
                        warned = 1; // have warned now: dont repeat same warning
                    }
                    else {
                        warned = 0;
                    }
                }

                // Dolly is DONE! Go down... and yell for help.
                if (timeLeftOnKey < 0) {
                    collapse("out");
                    //llSay(0, dollName + " has run out of life. Dolly will have to be wound. (Click on the key.)");
                    llSay(0, "Oh dear. The pretty Dolly " + dollName + " has run out of energy. Now if someone were to wind them... (Click on their key.)");
                }
            }

            //-------------------------------
            // CHECK DISTANCE FROM CARRIER
            if (carried && !pose) {
                // This means we can (temporarily) stop a carry by posing!

                // Current position of Carrier
                vector carrierposition = llList2Vector(llGetObjectDetails(carrierID, [OBJECT_POS]), 0);

                if (carrierposition) {
                    // Current position of Doll
                    vector dollposition = llList2Vector(llGetObjectDetails(dollID, [OBJECT_POS]), 0);
                    float d = llFabs(carrierposition.x - dollposition.x) +
                              llFabs(carrierposition.y - dollposition.y) +
                              llFabs(carrierposition.z - dollposition.z);

                    if (d > 8) {
                        llMoveToTarget(<0, 1, 0> + carrierposition, 1);
                        llSleep(2);
                        llStopMoveToTarget( );
                    }
                }
            }
        }
    }

    //----------------------------------------
    // RECEIVED A LINK MESSAGE
    //----------------------------------------
    // For Transforming Key operations
    link_message(integer source, integer num, string choice, key id) {
        // 16: Change Key Type: transforming: choice = Doll Type
        if (num == 16) {
            // Pre-conversion... restore settings as needed

            // change to new Doll Type
            dollType = choice;
            
            // Update sign if turned on
            if (dollType == "Regular" || !signOn) {
               llSetText("", <1,1,1>, 1);
            } else {
               llSetText(dollType, <1,1,1>, 1);
            }

            // new type is slut Doll
            if (dollType == "Slut") {
                llOwnerSay("As a slut Doll, you can be stripped.");
            }

            // Unless doll is a "Builder" or a "Key" it will start winding down
            windDown = !(dollType == "Builder" ||  dollType == "Key");
        }

        // 18: Convert to Transforming Key
        else if (num == 18) {
            isTransformingKey = 1;
        }
        
        else if (num == 101) {
            if (!configured) processConfiguration(choice);
        }
        
        else if (num == 310) {
            RLVck = 0;
            RLVok = 1;
            rlvAPIversion = choice;
            initFinal();
        }
        
        else if (num == 311) {
            RLVck = 0;
            RLVok = 0;
            initFinal();
        }
        
        else if (num == 312) windDown = 1;
        else if (num == 313) windDown = 0;
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string choice) {
        // channel = chat channel to listen on
        //    name = filter by prim name
        //     key = filter by avatar key
        //  choice = filter by specific message

        // Main Menu
        if (channel == channel_dialog) {
            handlemenuchoices(choice, name, id);
        }

        // Options menu
        else if (channel == cd5666) {
            integer controller = isMistress(id);

            if (id == dollID) {
                if (choice == "no detaching") {
                    detachable = 0;
                    llOwnerSay( "Your key is now a permanent part of you.");
                }
                else if (choice == "auto tp") {
                    autoTP = 1;
                    llMessageLinked(LINK_SET, 300, "autoTP" + ZWSP + "1", NULL_KEY);
                }
                else if (choice == "pleasure doll") {
                    llOwnerSay("You are now a pleasure doll.");
                    pleasureDoll = 1;
                }
                else if (choice == "not pleasure") {
                    llOwnerSay("You are no longer a pleasure doll.");
                    pleasureDoll = 0;

                    if (dollType == "Slut") {
                        llOwnerSay("As a Slut Dolly, you can still be stripped.");
                    }
                }
                else if (choice == "no self tp") {
                    helpless = 1;
                    llMessageLinked(LINK_SET, 300, "helpless" + ZWSP + "1", NULL_KEY);
                }
                else if (choice == "can carry") {
                    llOwnerSay("Other people can now carry you.");
                    canCarry = 1;
                }
                else if (choice == "no carry") {
                    llOwnerSay("Other people can no longer carry you.");
                    canCarry = 0;
                }
                else if (choice == "can outfit") {
                    llOwnerSay("Other people can now outfit you.");
                    canDress = 1;
                }
                else if (choice == "no outfitting") {
                    llOwnerSay("Other people can no longer outfit you.");
                    canDress = 0;
                }
                else if (choice == "no takeover") {
                    llOwnerSay("There is now no way for someone to become your controller.");
                    takeoverAllowed = 0;
                }
                else if (choice == "allow takeover") {
                    llOwnerSay( "Anyone carrying you may now choose to be your controller.");
                    takeoverAllowed = 1;
                }
                else if (choice == "no warnings") {
                    llOwnerSay( "No warnings will be given when time remaining is low.");
                    doWarnings = 0;
                }
                else if (choice == "warnings") {
                    llOwnerSay( "Warnings will now be given when time remaining is low.");
                    doWarnings = 1;
                }
                else if (choice == "no flying") {
                    canFly = 0;
                    llMessageLinked(LINK_SET, 300, "canFly" + ZWSP + "0", NULL_KEY);
                }
                else if (choice == "turn off sign") {
                    // erase sign
                    llSetText("", <1,1,1>, 1);
                    signOn = 0;
                }
                else if (choice == "turn on sign") {
                    // erase sign
                    llSetText(dollType, <1,1,1>, 1);
                    signOn = 1;
                }
            } else if (controller && !(id == dollID)) {
                if (choice == "detachable") {
                    detachable = 1;
                } else if (choice == "no auto tp") {
                    autoTP = 0;
                    llMessageLinked(LINK_SET, 300, "autoTP" + ZWSP + "0", NULL_KEY);
                } else if (choice == "no AFK") {
                    canAFK = 0;
                } else if (choice == "can AFK") {
                    canAFK = 1;
                } else if (choice == "can travel") {
                    helpless = 0;
                    llMessageLinked(LINK_SET, 300, "helpless" + ZWSP + "0", NULL_KEY);
                } else if (choice == "drop control") {
                    MistressID = MasterBuilder;
                    hasController = 0;
                } else if (choice == "can fly") {
                    canFly = 1;
                    llMessageLinked(LINK_SET, 300, "canFly" + ZWSP + "1", NULL_KEY);
                }
            }
        }

        // Text commands
        else if (channel == channel_chat) {

            // Normal user commands
            if (choice == "detach") {
                if (detachable) {
                    aoChange("on");
                    llMessageLinked(LINK_SET, 305, "detach", NULL_KEY);
                }
                else {
                    llOwnerSay("Key can't be detached...");
                }
            }
            else if (choice == "help") {
                llOwnerSay("Commands:\n\n
    detach ......... detach key if possible\n
    stat ........... concise current status\n
    stats .......... selected statistics and settings\n
    xstats ......... extended statistics and settings\n
    poses .......... list all poses\n
    help ........... this list of commands\n
    wind ........... trigger emergency autowind\n
    demo ........... toggle demo mode\n
    channel ........ change channel\n\n");
            }
            else if (llGetSubString(choice,0,8) == "channel") {
                string c = llStringTrim(llGetSubString(choice,9,llStringLength(choice) - 1),STRING_TRIM);
                if ((string) ((integer) c) == c) {
                    integer ch = (integer) c;
                    if (ch != 0 && ch != DEBUG_CHANNEL) {
                        channel_chat = ch;
                        llListenRemove(listen_id_commands);
                        listen_id_commands = llListen(ch, "", llGetOwner(), "");
                    }
                }
            }
            // Demo: short time span
            else if (choice == "demo") {
                if (keylimit > 30) {
                    keylimit = 5 * ticks;   // 5 minutes
                    timeLeftOnKey = keylimit;
                    llOwnerSay("Key set to run in demo mode: time limit set to 5 minutes.");
                } else {
                    // Note that the LIMIT is restored.... but the time left on key is unchanged
                    keylimit = deflimit; // restore default
                    llOwnerSay("Key set to run normally: time limit set to " + (string) (deflimit / ticks) + " minutes.");
                }
            }
            else if (choice == "poses") {
                integer  n = llGetInventoryNumber(20);

                // Menu max limit of 11... report error
                if (n > 11) {
                    llOwnerSay("Too many poses! Found " + (string)n + " poses (max is 11)");
                }

                while(n) {
                    string thisPose = llGetInventoryName(20, --n);

                    if (thisPose == collapseAnim || llGetSubString(thisPose,1,1) == ".") { // flag pose
                        // nothing
                    }
                    else {
                        if (currentAnimation == thisPose) {
                            llOwnerSay("\t*\t" + thisPose);
                        }
                        else {
                            llOwnerSay("\t\t" + thisPose);
                        }
                    }
                }
            }
            else if (choice == "wind") {
                // Give this a time limit: can only be done once
                // in - say - 6 hours... at least maxwindtime *2 or *3.

                if (lastEmergencyTime == 0 ||
                    (llGetTime() - lastEmergencyTime > emergencyLimitTime)) {

                   if (collapsed) {
                       if (hasController) {
                           llMessageLinked(LINK_THIS, 11, (dollName + " has activated the emergency winder."), MistressID);
                       }

                       windKey();
                       lastEmergencyTime = llGetTime();

                       restoreFromCollapse();

                       llOwnerSay("Emergency self-winder has been triggered by Doll.");
                       llOwnerSay("Emergency circuitry requires recharging and will be available again in " + (string)emergencyLimitHours + " hours.");
                   } else {
                       llOwnerSay("No emergency exists - emergency self-winder deactivated.");
                   }
                } else {
                   llOwnerSay("Emergency self-winder is not yet recharged.");
                }
            }
            else if (choice == "xstats") {
                llOwnerSay("AFK time factor: " + (string)(tokFactor) + "x");
                llOwnerSay("Wind amount: " + (string)(windamount / ticks) + " minutes.");

                {
                    string s;

                    s = "Doll can be teleported ";
                    if (autoTP) {
                        llOwnerSay(s + "without restriction.");
                    }
                    else {
                        llOwnerSay(s + "with confirmation.");
                    }

                    s = "Key is ";
                    if (detachable) {
                        llOwnerSay(s + "detachable.");
                    }
                    else {
                        llOwnerSay(s + "not detachable.");
                    }

                    s = " be dressed by others.";
                    if (canDress) {
                        llOwnerSay("Doll can" + s);
                    }
                    else {
                        llOwnerSay("Doll cannot" + s);
                    }

                    s = "Doll can";
                    if (canFly) {
                        llOwnerSay(s + " fly.");
                    }
                    else {
                        llOwnerSay(s + "not fly.");
                    }

                    s = "RLV is ";
                    if (RLVok) {
                        llOwnerSay(s + "active.");
                    }
                    else {
                        llOwnerSay(s + "not active.");
                    }
                }

                if (!windDown) {
                    llOwnerSay("Key is not winding down.");
                }

            }
            else if (choice == "stat") {
                integer t1 = timeLeftOnKey / ticks;
                integer t2 = keylimit / ticks;
                float p = (float)t1 * 100.0 / (float)t2;

                string s = "Time: " + (string)t1 + "/" +
                            (string)t2 + " min (" + FormatFloat(p, 2) + "% capacity)";
                if (afk) {
                    s += " (rate slowed by " + (string)tokFactor + "x)";
                }
                llOwnerSay(s);
            }
            else if (choice == "stats") {
                llOwnerSay("Time remaining: " + (string)(timeLeftOnKey / ticks) + " minutes of " +
                            (string)(keylimit / ticks) + " minutes.");
                if (afk) {
                    llOwnerSay("Key is unwinding at a slowed rate of " + (string)tokFactor + "x.");
                    llOwnerSay("Doll is AFK.");
                }

                if (hasController) {
                    llOwnerSay("Controller: " + mistressname);
                }
                else {
                    llOwnerSay("Controller: none");
                }

                if (pose) {
                //    llOwnerSay("Current pose: " + currentAnimation);
                //    llOwnerSay("Pose time remaining: " + (string)(posetime / ticks) + " minutes.");
                    llOwnerSay("Doll is posed.");
                }

                memReport();
            }
        }

        // Strip items... only for Pleasure Doll and Slut Doll Types...
        else if (channel == cd4667) {
            if (id == carrierID) {
                if (choice == "Top") {
                    llMessageLinked(LINK_SET, 305, "stripTop", NULL_KEY);
                }
                else if (choice == "Bra") {
                    llMessageLinked(LINK_SET, 305, "stripBra", NULL_KEY);
                }
                else if (choice == "Bottom") {
                    llMessageLinked(LINK_SET, 305, "stripBottom", NULL_KEY);
                }
                else if (choice == "Panties") {
                    llMessageLinked(LINK_SET, 305, "stripPanties", NULL_KEY);
                }
                else if (choice == "Shoes") {
                    llMessageLinked(LINK_SET, 305, "stripShoes", NULL_KEY);
                }

                // Do strip menu
                llDialog(toucherID, "Take off:",
                    ["Top", "Bra", "Bottom", "Panties", "Shoes"],
                    cd4667);
            }
        }
    }

    //----------------------------------------
    // PERMISSION GRANTED
    //----------------------------------------
    // This occurs when a permission is accepted
    //
    // The permission may be granted - or denied - but it is
    // not known until we get here
    run_time_permissions(integer perm) {

        //----------------------------------------
        // Permission granted: TRIGGER_ANIMATION
        //
        // We have an animation we want to trigger... so we need to analyze
        // what it is. We might also be stopping an animation instead
        // of starting one...
        //
        // Two main animation possibilities: poses and collapsed.
        // Poses can be one after the other as well. Being collapsed
        // is "semi-final"; once collapsed, only possibility is "uncollapse".
        if (perm & PERMISSION_TRIGGER_ANIMATION) {

            //----------------------------------------
            // Step #1: Stop any animations we need to stop
            //
            if (newState == "collapsed") {
                // Before collapsing, stop all animations
                stopAnimations();

                // Next animation: collapse
                newAnimation = collapseAnim;

                llSay(0, "Dolly " + dollName + " has now collapsed.");
            } else if (newState == "nothing") {
                // If either collapsed or posed: stop all
                stopAnimations();

                // Next animation: standup - internal
                newAnimation = "";

            }


            //----------------------------------------
            // Step #2: Start new animation
            //
            if (newAnimation == "") {
                llStartAnimation("sit_to_stand");
            } else {
                // There is a new animation: trigger it
                aoChange("off");

                llStartAnimation(newAnimation);
                currentAnimation = newAnimation;

                llOwnerSay("Dolly has now taken on the " + newAnimation + " pose.");
                newAnimation = ""; // clear it
            }
            newState = "";
        }

        // PERMISSION_TAKE_CONTROLS is activated in the very beginning....
        // thereafter, it is always active... so...
        //
        // This only happens the first time; the rest of the time, the actions
        // happen directly in the code.
        //
        if (permissionsGranted == 0) {
            // Permission granted: TAKE_CONTROLS
            if (perm & PERMISSION_TAKE_CONTROLS) {
                if (controlLock) {
                    llTakeControls( CONTROL_FWD        |
                                    CONTROL_BACK       |
                                    CONTROL_LEFT       |
                                    CONTROL_RIGHT      |
                                    CONTROL_ROT_LEFT   |
                                    CONTROL_ROT_RIGHT  |
                                    CONTROL_UP         |
                                    CONTROL_DOWN       |
                                    CONTROL_LBUTTON    |
                                    CONTROL_ML_LBUTTON |
                                    0, 1, 0);
                } else {
                    //llReleaseControls( );

                    // This is a hack to allow working in no-script areas
                    llTakeControls(CONTROL_FWD, 1, 1);   
                }
            }

            // This is only reasonable first time this runs...
            permissionsGranted = 1;
        }
    }
}
