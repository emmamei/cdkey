// Main.lsl
//
// vim:sw=4 et nowrap:
//
// DATE: 22 March 2013

string optiondate = "6 December 2013";

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
integer isTransformingKey = FALSE;
//
// All other settings of this variable have been removed,
// including the SetDefaults and the NCPrefs.

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
integer RLVck = 1;

key ncPrefsKey;
string ncName = "Preferences";
integer ncLine;
//string cmdPrefix;

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
integer cd6012;
integer cd4667;
integer cd5666;

// If the key is a Transforming Key - one that can transform from one
// type of Doll to another - this tracks the current type of doll.
string dollType = "regular";

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


string wwGetSLUrl() {
    string globe = "http://maps.secondlife.com/secondlife";
    string region = llGetRegionName();
    vector pos = llGetPos();
    string posx = (string)llRound(pos.x);
    string posy = (string)llRound(pos.y);
    string posz = (string)llRound(pos.z);

    return (globe + "/" + llEscapeURL(region) +"/" + posx + "/" + posy + "/" + posz);
}

initConfiguration() {
    // Check to see if the file exists and is a notecard
    if (llGetInventoryType(ncName) == INVENTORY_NOTECARD) {

        // Start reading from first line (which is 0)
        ncLine = 0;
        ncPrefsKey = llGetNotecardLine(ncName, ncLine);

    } else {

        // File missing - report for debugging only
        llOwnerSay("No configuration found (" + ncName + ")");
    }
}

// This code assumes a human-generated config file
processConfiguration(string data) {

    // Return if done
    if (data == EOF) {
        llOwnerSay("Key configuration completed.");
        return;
    }

    if(data != "") {
        // Ignore comments
        if(llSubStringIndex(data, "#") != 0) {
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
                    dollType = (string) value;
                }
                else if (name == "wind time") {
                    windamount = (integer) value * ticks;
                }
                else if (name == "max time") {
                    deflimit = (integer) value * ticks;
                    keylimit = deflimit;
                }
                else if (name == "helpless dolly") {
                    helpless = (integer) value;
                    if (RLVok) {
                        if (helpless) {
                            llOwnerSay("@tplm=n,tploc=n");
                        } else {
                            llOwnerSay("@tplm=y,tploc=y");
                        }
                    }
                }
                else if (name == "controller") {
                    MistressID = (key) value;
                    hasController = TRUE;
                    takeoverAllowed = FALSE; // there is a Mistress; takeover is irrelevant
                    mistressQuery = llRequestAgentData(MistressID, DATA_NAME);
                }
                else if (name == "auto tp") {
                    autoTP = (integer) value;
                    if (autoTP) {
                        llOwnerSay("@accepttp=add");            // Allow auto TP
                    } else {
                        llOwnerSay("@accepttp=rem");            // Disallow auto TP
                    }
                }
                else if (name == "pleasure doll") {
                    pleasureDoll = (integer) value;
                }
                else if (name == "detachable") {
                    detachable = (integer) value;
                }
                else {
                    // Unknown configuration
                    llSay(DEBUG_CHANNEL,"Unknown configuration value: " + name + " on line " + (string)ncLine);
                }
            }
        }
    }

    // Read the next configuration line
    ncPrefsKey = llGetNotecardLine(ncName, ++ncLine);
}

stopAnimations() {
    list anims = llGetAnimationList(dollID);
    integer n;
    string anim;

    for ( n = 0; n < llGetListLength(anims); n++ ) {
        anim = llList2String(anims, n);

        llStopAnimation(anim);
        //llSleep(0.2);
        llSleep(5);
    }
    llSetColor( <0,1,0>, ALL_SIDES );
}

// Only useful if @tplure and @accepttp are off and denied by default...
autoTPAllowed(key userID) {
    if (RLVok) {
        llOwnerSay("@tplure:"   + (string) userID + "=add");
        llOwnerSay("@accepttp:" + (string) userID + "=add");
    }
}

becomeController(key ToucherID) {
    takeoverAllowed = FALSE;
    hasController = TRUE;

    MistressID = ToucherID;

    // Mistress is present: use llKey2Name()
    mistressname = llKey2Name(ToucherID);

    llOwnerSay("Your carrier, " + mistressname + ", has become your controller.");
    //llSay(PUBLIC_CHANNEL, mistressname + " has become controller of the doll " + dollName + ".");

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
    string msg = "See " + httpstart + "keychoices.htm for explanation. (" + optiondate + " version)";
    list pluslist;

    toucherID = ToucherID;

    if (!canDress) {
        pluslist += "can outfit";
    }
    else {
        pluslist += "no outfitting";
    }

    if (!canCarry) {
        pluslist += "can carry";
    }
    else {
        pluslist += "no carry";
    }

    // One-way option
    if (detachable) {
        pluslist += "no detaching";
    }

    if (doWarnings) {
        pluslist += "no warnings";
    }
    else {
        pluslist += "warnings";
    }

    if (canSit) {
        pluslist += "no sitting";
    }
    else {
        pluslist += "can sit";
    }

    // One-way option
    if (!autoTP) {
        pluslist += "auto tp";
    }

    // One-way option
    if (!helpless) {
        pluslist += "no self tp";
    }

    // One-way option
    if (canFly) {
        pluslist += "no flying";
    }

    if (pleasureDoll) {
        pluslist += "no pleasure";
    }
    else {
        pluslist += "pleasure doll";
    }

    if (!hasController) {
        if (takeoverAllowed) {
            pluslist += "no takeover";
        }
        else {
            pluslist += "allow takeover";
        }
    }

    if (isTransformingKey) {
        if (signOn) {
            pluslist += "turn off sign";
        }
        else {
            pluslist += "turn on sign";
        }
    }

    llDialog(toucherID, msg, pluslist, cd5666);
}

// This is the Menu that the Controller sess
doControlMenu(key ToucherID) {
    list privatemenu = ["drop control"];

    if (detachable) {
        privatemenu += "undetachable";
    }
    else {
        privatemenu += "detachable";
    }

    if (autoTP) {
        privatemenu += "no auto tp";
    }
    else {
        privatemenu += "auto tp";
    }

    if (helpless) {
        privatemenu += "can travel";
    }
    else {
        privatemenu += "no self trav";
    }

    if (pleasureDoll) {
        privatemenu += "no plsr doll";
    }
    else {
        privatemenu += "make plsrdll";
    }

    if (canFly) {
        privatemenu += "no flying";
    }
    else {
        privatemenu += "can fly";
    }

    if (canStand) {
        privatemenu += "no standing";
    }
    else {
        privatemenu += "can stand";
    }

    if (canSit) {
        privatemenu += "no sitting";
    }
    else {
        privatemenu += "can sit";
    }

    if (canCarry) {
        privatemenu += "no carry";
    }
    else {
        privatemenu += "can carry";
    }

    if (canAFK) {
        privatemenu += "no AFK";
    }
    else {
        privatemenu += "can AFK";
    }

    if (doWarnings) {
        privatemenu += "no warnings";
    }
    else {
        privatemenu += "warnings";
    }

    llDialog(ToucherID, "See " + httpstart + "controller.htm. Choose what you want to happen.",  privatemenu, cd6012);
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
        llRegionSayTo(toucherID, PUBLIC_CHANNEL, "You have given " + dollName + " " + (string) (winding) + " more minutes of life.");
    }
    llRegionSayTo(toucherID, PUBLIC_CHANNEL, "Doll is now at " + (string) (llRound(timeLeftOnKey * 1000.0 / keylimit)/10.0) + "% of capacity.");

    if (timeLeftOnKey == keylimit) {
        llSay(PUBLIC_CHANNEL, dollName + " has been fully wound by " + name + ".");
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
        carried = TRUE;
        carriername = name;
        carrierID = ToucherID;

        if (RLVok) {
            // No TP allowed for Doll
            llOwnerSay("@tplm=n,tploc=n,accepttp=rem,tplure=n");

            // Allow carrier to TP: but Doll can deny
            llOwnerSay("@tplure:" + (string) carrierID  + "=add");

            // Allow rescuers to AutoTP
            autoTPAllowed(MistressID);
            autoTPAllowed(DevOne);
        }

        llSay(PUBLIC_CHANNEL, dollName + " has been picked up by " + carriername);
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
        pose = FALSE;
        aoChange("on");
    }
    else if (choice == "Allow Takeover") {
        takeoverAllowed = TRUE;
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
    else if (choice == "Use Control") {
        doControlMenu(ToucherID);
    }
    else if (choice == "Options") {
        doOptionsMenu(ToucherID);
    }
    else if (choice == "Detach") {
        aoChange("on");
        if (RLVok) llOwnerSay("@clear,detachme=force");
    }
    else if (choice == "Invisible") {
        visible = FALSE;
        llSetLinkAlpha(LINK_SET, 0, ALL_SIDES);
        llOwnerSay("Your key fades from view...");
        //doFade(LINK_SET, 1.0, 0.0, ALL_SIDES, 0.1);
    }
    else if (choice == "Visible") {
        visible = TRUE;
        llSetLinkAlpha(LINK_SET, 1, ALL_SIDES);
        llOwnerSay("Your key appears magically.");
        //doFade(LINK_SET, 0.0, 1.0, ALL_SIDES, 0.1);
    }
    else if (choice == "Toggle AFK") {
        if (afk) {
            if (dollType == "regular") {
                llSetText("", <1,1,1>, 2);
            }
            else {
                // Change sign to represent Doll Type
                llSetText(dollType, <1,1,1>, 2);
            }

            afk = FALSE;

            if (RLVok) {
                if (canFly) {
                    llOwnerSay("@fly=y"); // restore flying capability
                }

                if (! helpless) {
                    llOwnerSay("@tplm=y,tploc=y"); // restore travel capabilities
                }

                if (autoTP) {
                    llOwnerSay("@accepttp=add"); // restore autoTP
                } else {
                    llOwnerSay("@accepttp=rem"); // remove autoTP
                }

                llOwnerSay("@temprun=y,alwaysrun=y,sendchat=y,tplure=y,sittp=y,standtp=y,unsit=y,sit=y");
            }

            llOwnerSay("You are now no longer away from keyboard (AFK). Movements are unrestricted and winding down proceeds at normal rate.");
            llOwnerSay("You have " + (string)(timeLeftOnKey / ticks) + " minutes of life remaning.");
        }
        else {
            // set sign to "afk"
            llSetText("AFK", <1,1,1>, 2);

            // AFK turns everything off
            if (RLVok) {
                llOwnerSay("@temprun=n,alwaysrun=n,sendchat=n,tplure=n,sittp=n,standtp=n,unsit=n,sit=n");
                llOwnerSay("@fly=n,tplm=n,tploc=n,accepttp=rem");
            }

            afk = TRUE;
            tok = tokFactor;
            llOwnerSay("You are now away from keyboard (AFK). Wind down time has slowed by a factor of " + (string)(tokFactor) + " and movements are restricted.");
            llOwnerSay("You have " + (string)(timeLeftOnKey / ticks) + " minutes of life remaning.");
        }
    }
}

aoChange(string choice) {
    integer g_iAOChannel = -782690;
    integer g_iInterfaceChannel = -12587429;

    if (choice == "off" || choice == "stop") {
        string AO_OFF = "ZHAO_STANDOFF";
        llWhisper(g_iInterfaceChannel, "CollarComand|499|" + AO_OFF);
        llWhisper(g_iAOChannel, AO_OFF);
        llMessageLinked(LINK_SET, 0, "ZHAO_AOON", NULL_KEY);
    }
    else {
        string AO_ON = "ZHAO_STANDON";
        llWhisper(g_iInterfaceChannel, "CollarComand|499|" + AO_ON);
        llWhisper(g_iAOChannel, AO_ON);
        llMessageLinked(LINK_SET, 0, "ZHAO_AOON", NULL_KEY);
    }
}

uncarry() {
    // Doll already not being carried...
    if (!carried)
        return;

    carried = FALSE;

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

    llSay(PUBLIC_CHANNEL, dollName + " was being carried by " + carriername + " and has been set down.");
    carrierID = NULL_KEY;
}

initializeStart ()  {
    dollID = llGetOwner();
    llSetText("", <1,1,1>, 1);
    
    // Stop all current animations: that means if you
    // attach the key when dancing - dancing will stop
    //restoreFromCollapse();
    aoChange("on");

    //llRequestPermissions(dollID, PERMISSION_TRIGGER_ANIMATION);
    llSetLinkAlpha(LINK_SET, 1, ALL_SIDES);

    dollName = llGetDisplayName(dollID);
    llSay(PUBLIC_CHANNEL, dollName + " is now a dolly - anyone may play with their Key.");

    // This hack makes Key work on no-script land
    llTakeControls( CONTROL_FWD   |
                    CONTROL_BACK  |
                    CONTROL_LEFT  |
                    CONTROL_RIGHT |
                    0, TRUE, TRUE);
}

listenerStart () {
    // Get a unique number
    integer ncd = ( -1 * (integer)("0x" + llGetSubString((string)llGetKey(),-7,-1)) ) - 1;

    if (channel_dialog != ncd) {
        llListenRemove(listen_id_mainmenu);
        llListenRemove(listen_id_stripmenu);
        llListenRemove(listen_id_optionmenu);
        llListenRemove(listen_id_controllermenu);
        llListenRemove(listen_id_commands);

        // channel_dialog = Main key menu
        //         cd6012 = Controller menu
        //         cd4667 = Strip clothing menu
        //         cd5666 = Dolly options menu
        //   channel_chat = Chat commands

        channel_dialog = ncd;
        cd6012 = channel_dialog - 6012;
        cd4667 = channel_dialog - 4667;
        cd5666 = channel_dialog - 5666;

        // Create Listeners
        listen_id_mainmenu       = llListen(channel_dialog, "", "", "");
        listen_id_controllermenu = llListen(cd6012,         "", "", "");
        listen_id_stripmenu      = llListen(cd4667,         "", "", "");
        listen_id_optionmenu     = llListen(cd5666,         "", "", "");
        listen_id_commands       = llListen(channel_chat,   "", llGetOwner(), "");

    }
}

configureStart () {
    //if (RLVok) llOwnerSay("@acceptpermission=add,accepttp=rem");
    if (RLVok) llOwnerSay("@accepttp=rem");

    aoChange("on");

    if (!canDress) {
        llOwnerSay("Other people cannot dress you.");
    }

    if (RLVok) {
        if (autoTP) {
            llOwnerSay("@accepttp=add");
        }

        if (helpless) {
            llOwnerSay("@tplm=n,tploc=n");
        }

        if (!canFly) {
            llOwnerSay("@fly=n");
        }

        if (!canStand) {
            llOwnerSay("@stand=n");
        }

        if (!canSit) {
            llOwnerSay("@sit=n");
        }
    }

    {
        integer freemem = llGetFreeMemory();
        llOwnerSay(((string)(freemem/1024.0)) + " kbytes of free memory available for allocation.");
    }

    // Intro hypno text - long
    //llMessageLinked(LINK_THIS, 200, "start", dollID);
}

//----------------------------------------
// Collapse functions / data
//----------------------------------------

// This clears ONLY the collapse animation....
restoreFromCollapse() {
    // Rotate key: around Z access at rate .3 and gain 1
    llTargetOmega(<0,0,1>, .3, 1);
    llSetText("", <1,1,1>, 2);

    if (RLVok) {
        // Clear restrictions
        if (canFly) {
            llOwnerSay("@fly=y");
        }

        if (! helpless) {
            llOwnerSay("@tplm=y,tploc=y");
        }

        llOwnerSay("@accepttp=rem,temprun=y,alwaysrun=y,sendchat=y,tplure=y,sittp=y,standtp=y,unsit=y,sit=y,shownames=y,showhovertextall=y,rediremote:999=rem");
    }

    // Clear animation
    newState = "nothing";
    collapsed = FALSE;
    controlLock = FALSE;

    // Remove this eventually
    llRequestPermissions(dollID, PERMISSION_TAKE_CONTROLS|PERMISSION_TRIGGER_ANIMATION);

    // This hack makes Key work on no-script land
    llTakeControls( CONTROL_FWD   |
                    CONTROL_BACK  |
                    CONTROL_LEFT  |
                    CONTROL_RIGHT |
                    0, TRUE, TRUE);

    aoChange("on");
}

collapse(string s) {
    visible = TRUE;

    if (hasController) {
        llMessageLinked(LINK_THIS, 11, (dollName + " has collapsed at this location: " + wwGetSLUrl()), MistressID);
    }

    // Set this so an "animated" but disabled dolly can be identified
    llSetText("Dolly needs winding up!", <1,1,1>, 2);

    // Turn everything off: Dolly is down
    if (RLVok) {
        llOwnerSay("@fly=n,temprun=n,alwaysrun=n,sendchat=n,tplm=n,tploc=n,sittp=n,standtp=n,accepttp=rem," +
            "unsit=n,sit=n,shownames=n,showhovertextall=n");

        // Only the carrier and the General Dolly Rescuers can
        // AutoTP someone who is collapsed...
        //
        llOwnerSay("@accepttp=rem,tplure=n");

        autoTPAllowed(MistressID);
        autoTPAllowed(MasterBuilder);
        autoTPAllowed(MasterWinder);
        autoTPAllowed(DevOne);

        if (carried) {
            autoTPAllowed(carrierID);
        }

        llOwnerSay("@unsit=force");
    }

    newAnimation = collapseAnim;
    newState = "collapsed";
    pose = FALSE;
    collapsed = TRUE;
    controlLock = TRUE;

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
                    0, TRUE, FALSE);

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

        //----------------------------------------
        // FIXME: Much of the following is included in initializeStart
        key owner = llGetOwner();

        dollID = owner;
        //setDefaults();

        // Rotate self: around Z access at rate .3 and gain 1
        llTargetOmega(<0,0,1>, .3, 1);

        // set controls so we work in no-script land
        // FIXME: this could be a "set and forget" permission request for the entire script
        controlLock = FALSE;
        llRequestPermissions(dollID, PERMISSION_TAKE_CONTROLS);

        //----------------------------------------
        initializeStart();
        //----------------------------------------

        initConfiguration();
        listenerStart();

    }

    //----------------------------------------
    // INITIAL REZ
    //----------------------------------------
    // This takes place when a user logs back in....

    on_rez(integer iParam) {  //when key is put on, or when logging back on
        // Test to see if RLV is active
        llOwnerSay("@versionnew=" + (string)channel_chat);
        llSetTimerEvent(30);  // Access timer in 30s...
        llSleep(35);

        do
            llSleep(5);
        while (RLVck);

        configureStart();
    }

    //----------------------------------------
    // ATTACH
    //----------------------------------------
    attach(key id) {
        if (id) { // valid key
            integer attachPoint = llGetAttached();

            // Key being attached to Spine?
            if (attachPoint == ATTACH_BACK) { //the proper location for the key

                // if Doll is one of the developers... dont lock:
                // prevents inadvertent lock-in during development

                if (dollID != DevOne && dollID != DevTwo) {
                    if (RLVok) {

                        // We lock the key on here - but in the menu system, it appears
                        // unlocked and detachable: this is because it can be detached 
                        // via the menu. To make the key truly "undetachable", we get
                        // rid of the menu item to unlock it
                        llOwnerSay("@detach=n");  //locks key
                    }
                } else {
                    llSay(PUBLIC_CHANNEL, "Developer Key not locked.");
                }
                windDown = TRUE;
            }

            // Key attached elsewhere...
            else {
                // Key can be removed...
                if (RLVok) llOwnerSay("@detach=y");

                // Words are erroneous: attaches anyway
                llOwnerSay("Your key stubbornly refuses to attach itself, and you " +
                           "belatedly realize that it must be attached to your spine.");
                //llOwnerSay("Attach Point: " + (string) llGetAttached());
                windDown = FALSE;
            }

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

        } else { // NULL_KEY = detach
            llOwnerSay("The key is wrenched from your back, and you double over at the " +
                       "unexpected pain as the tendrils are ripped out. You feel an emptiness, " +
                       "as if some beautiful presence has been removed.");
        }
    }

    //----------------------------------------
    // DATASERVER
    //----------------------------------------
    dataserver(key query_id, string data) {

        if (query_id == ncPrefsKey) {
            processConfiguration(data);
        } else if (query_id == mistressQuery) {
            mistressname = data;
            llOwnerSay("Your mistress is " + mistressname);
        }
    }

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    changed(integer change) {

        if (change & CHANGED_INVENTORY)  {
            // Update Dress script if inventory changes
            llResetOtherScript("Dress");

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
                if ((pleasureDoll > 0 || dollType == "slut") && RLVok) {
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

        // Checking for RLV?
        if (RLVck) {
           if (hasController && !RLVok) {
              llMessageLinked(LINK_THIS, 11, (dollName + " has logged in without RLV!"), MistressID);
           }

           RLVck = FALSE;
        }

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
                // set sign to "afk"
                llSetText("Away", <1,1,1>, 2);

                // AFK turns everything off
                if (RLVok) {
                    llOwnerSay("@temprun=n,alwaysrun=n,sendchat=n,tplure=n,sittp=n,standtp=n,unsit=n,sit=n");
                    llOwnerSay("@fly=n,tplm=n,tploc=n,accepttp=rem");
                }

                afk = TRUE;
                tok = tokFactor;
                //llOwnerSay("Automatically entering AFK mode. Wind down time has slowed by a factor of " + (string)(tokFactor) + " and movements are restricted.");
                //llOwnerSay("You have " + (string)(timeLeftOnKey / ticks) + " minutes of life remaning.");
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
                        llSay(PUBLIC_CHANNEL, dollName + " has " + (string) minLeftOnKey + " minutes left before they run down!");
                        warned = TRUE; // have warned now: dont repeat same warning
                    }
                    else {
                        warned = FALSE;
                    }
                }

                // Dolly is DONE! Go down... and yell for help.
                if (timeLeftOnKey < 0) {
                    collapse("out");
                    //llSay(PUBLIC_CHANNEL, dollName + " has run out of life. Dolly will have to be wound. (Click on the key.)");
                    llSay(PUBLIC_CHANNEL, "Oh dear. The pretty Dolly " + dollName + " has run out of energy. Now if someone were to wind them... (Click on their key.)");
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

            // reset key to start winding down
            //windDown = (dollType == "Key"|| dollType == "Builder");

            // change to new Doll Type
            dollType = choice;

            // new type is slut Doll
            if (dollType == "slut") {
                llOwnerSay("As a slut Doll, you can be stripped.");
            }

            // Unless doll is a "Builder" or a "Key" it will start winding down
            windDown = !(dollType == "Builder" ||  dollType == "Key");
        }

        // 18: Convert to Transforming Key
        else if (num == 18) {
            isTransformingKey = TRUE;
        }
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

        // Dolly options menu (self)
        else if (channel == cd5666) {
            if (id == dollID) {
                if (choice == "no detaching") {
                    detachable = FALSE;
                    llOwnerSay( "Your key is now a permanent part of you.");
                }
                else if (choice == "auto tp") {
                    llOwnerSay("You will now be automatically teleported.");
                    autoTP = TRUE;
                    if (RLVok) llOwnerSay("@accepttp=add");
                }
                else if (choice == "pleasure doll") {
                    llOwnerSay("You are now a pleasure doll.");
                    pleasureDoll = TRUE;
                }
                else if (choice == "not pleasure") {
                    llOwnerSay("You are no longer a pleasure doll.");
                    pleasureDoll = FALSE;

                    if (dollType == "slut") {
                        llOwnerSay("As a Slut Dolly, you can still be stripped.");
                    }
                }
                else if (choice == "no self tp") {
                    llOwnerSay("You can no longer teleport yourself. You are a Helpless Dolly.");
                    helpless = TRUE;
                    if (RLVok) llOwnerSay("@tplm=n,tploc=n");
                }
                else if (choice == "can carry") {
                    llOwnerSay("Other people can now carry you.");
                    canCarry = TRUE;
                }
                else if (choice == "no carry") {
                    llOwnerSay("Other people can no longer carry you.");
                    canCarry = FALSE;
                }

                else if (choice == "can outfit") {
                    llOwnerSay("Other people can now outfit you.");
                    canDress = TRUE;
                }
                else if (choice == "no outfitting") {
                    llOwnerSay("Other people can no longer outfit you.");
                    canDress = FALSE;
                }

                else if (choice == "no takeover") {
                    llOwnerSay("There is now no way for someone to become your controller.");
                    takeoverAllowed = FALSE;
                }
                else if (choice == "allow takeover") {
                    llOwnerSay( "Anyone carrying you may now choose to be your controller.");
                    takeoverAllowed = TRUE;
                }
                else if (choice == "take off now") {
                    aoChange("on");
                    if (RLVok) llOwnerSay("@clear,detachme=force");
                }
                else if (choice == "no warnings") {
                    llOwnerSay( "No warnings will be given when time remaining is low.");
                    doWarnings = FALSE;
                }
                else if (choice == "warnings") {
                    llOwnerSay( "Warnings will now be given when time remaining is low.");
                    doWarnings = TRUE;
                }
                else if (choice == "no flying") {
                    canFly = FALSE;
                    if (RLVok) llOwnerSay("@fly=n");
                    llOwnerSay("You can no longer fly. Helpless Dolly!");
                }
                else if (choice == "turn off sign") {
                    // erase sign
                    llSetText("", <1,1,1>, 2);
                    signOn = FALSE;
                }
                else if (choice == "turn on sign") {
                    // erase sign
                    llSetText(dollType, <1,1,1>, 2);
                    signOn = TRUE;
                }
            }
        }

        // Controller menu....
        else if (channel == cd6012) {
            if (isMistress(id) && !(id == dollID)) {

                if (choice == "detachable") {
                    detachable = TRUE;
                }
                else if (choice == "undetachable") {
                    detachable = FALSE;
                }
                else if (choice == "no auto tp") {
                    autoTP = FALSE;
                    if (RLVok) llOwnerSay("@accepttp=rem");
                }
                else if (choice == "auto tp") {
                    autoTP = TRUE;
                    if (RLVok) llOwnerSay("@accepttp=add");
                }
                else if (choice == "no standing") {
                    canStand = FALSE;
                    if (RLVok) llOwnerSay("@unsit=n");
                }
                else if (choice == "can stand") {
                    canStand = TRUE;
                    if (RLVok) llOwnerSay("@unsit=y");
                }
                else if (choice == "no sitting") {
                    canSit = FALSE;
                    if (RLVok) llOwnerSay("@sit=n");
                }
                else if (choice == "can sit") {
                    canSit = TRUE;
                    if (RLVok) llOwnerSay("@sit=y");
                }
                else if (choice == "no AFK") {
                    canAFK = FALSE;
                }
                else if (choice == "can AFK") {
                    canAFK = TRUE;
                }
                else if (choice == "can travel") {
                    helpless = FALSE;
                    if (RLVok) llOwnerSay("@tplm=y,tploc=y");
                    //llRegionSayTo(id, PUBLIC_CHANNEL, dollName + " may travel on their own.");
                }
                else if (choice == "no self trav") {
                    //llRegionSayTo(id, PUBLIC_CHANNEL, dollName + " is now a Helpless Dolly and cannot travel on their own.");
                    if (RLVok) llOwnerSay("@tplm=n,tploc=n");
                    helpless = TRUE;
                }
                else if (choice == "drop control") {
                    //llRegionSayTo(id, PUBLIC_CHANNEL, dollName + " now has no controller.");
                    MistressID = MasterBuilder;
                    hasController = FALSE;
                }
                else if (choice == "no plsr doll") {
                    pleasureDoll = FALSE;
                    if (dollType == "slut") {
                        llOwnerSay("As a Slut Dolly, you can still be stripped.");
                    }
                }
                else if (choice == "make plsrdll") {
                    pleasureDoll = 2;
                }
                else if (choice == "can fly") {
                    canFly = TRUE;
                    if (RLVok) llOwnerSay("@fly=y");
                }
                else if (choice == "no warnings") {
                    doWarnings = FALSE;
                }
                else if (choice == "warnings") {
                    doWarnings = TRUE;
                }
                else if (choice == "no flying") {
                    canFly = FALSE;
                    if (RLVok) llOwnerSay("@fly=n");
                }
            }
        }

        // Text commands
        else if (channel == channel_chat) {

            // Normal user commands
            if (choice == "detach") {
                if (detachable) {
                    aoChange("on");
                    if (RLVok) llOwnerSay("@clear,detachme=force");
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
                    if (ch != PUBLIC_CHANNEL && ch != DEBUG_CHANNEL) {
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
                integer p = t1 * 100 / t2;

                string s = "Time: " + (string)t1 + "/" +
                            (string)t2 + " min (" + (string)p + "% capacity)";
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

                {
                    integer free_memory = llGetFreeMemory();
                    llOwnerSay((string)(free_memory/1024.0) + " kbytes of free memory available for allocation.");
                    integer used_memory = llGetUsedMemory();
                    llOwnerSay((string)(used_memory/1024.0) + " kbytes of memory currently used.");
                }
            }
            else if (llGetSubString(choice,0,13) == "RestrainedLove") {
                // RLV has been verified and is available to us
                RLVok = TRUE;
                llOwnerSay("Logged with Community Doll Key and RLV active...");
            }
        }

        // Strip items... only for Pleasure Doll and Slut Doll Types...
        else if (channel == cd4667) {
            if (id == carrierID) {
                if (choice == "Top") {
                    llOwnerSay("@detach:stomach=force,detach:left shoulder=force,detach:right shoulder=force,detach:left hand=force,detach:right hand=force,detach:r upper arm=force,detach:r forearm=force,detach:l upper arm=force,detach:l forearm=force,detach:chest=force,detach:left pec=force,detach:right pec=force");
                    llOwnerSay("@remoutfit:gloves=force,remoutfit:jacket=force,remoutfit:shirt=force");
                }
                else if (choice == "Bra") {
                    llOwnerSay("@remoutfit:undershirt=force");
                }
                else if (choice == "Bottom") {
                    llOwnerSay("@detach:chin=force,detach:r upper leg=force,detach:r lower leg=force,detach:l upper loge=force,detach:l lower leg=force,detach:pelvis=force,detach:right hip=force,detach:left hip=force,detach");
                    llOwnerSay("@remoutfit:pants=force,remoutfit:skirt=force");
                }
                else if (choice == "Panties") {
                    llOwnerSay("@remoutfit:underpants=force");
                }
                else if (choice == "Shoes") {
                    llOwnerSay("@detach:right foot=force,detach:left foot=force");
                    llOwnerSay("@remoutfit:shoes=force,remoutfit:socks=force");
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

                llSay(PUBLIC_CHANNEL, "Dolly " + dollName + " has now collapsed.");
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
        if (permissionsGranted == FALSE) {
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
                                    0, TRUE, FALSE);
                } else {
                    //llReleaseControls( );
                    llTakeControls( CONTROL_FWD   |
                                    CONTROL_BACK  |
                                    CONTROL_LEFT  |
                                    CONTROL_RIGHT |
                                    0, TRUE, TRUE);
                }
            }

            // This is only reasonable first time this runs...
            permissionsGranted = TRUE;
        }
    }
}

