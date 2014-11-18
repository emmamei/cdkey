//========================================
// CheckRLV.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 27 October 2014

#include "include/GlobalDefines.lsl"
//#include "include/Json.lsl"

//#define DEBUG_BADRLV
#define cdSayQuietly(x) { string z = x; if (quiet) llOwnerSay(z); else llSay(0,z); }
#define NOT_IN_REGION ZERO_VECTOR
#define cdLockMeisterCmd(a) llWhisper(LOCKMEISTER_CHANNEL,(string)dollID+a)
#define MAX_RLVCHECK_TRIES 5
#define RLV_TIMEOUT 20.0
#define UNSET -1

#define cdListenerDeactivate(a) llListenControl(a, 0)
#define cdListenerActivate(a) llListenControl(a, 1)
#define cdResetKey() llResetOtherScript("Start")

//key carrierID = NULL_KEY;

// Could set allControls to -1 for quick full bit set - 
// but that would set fields with undefined values: this is more
// accurate
//#define ALL_CONTROLS (CONTROL_FWD|CONTROL_BACK|CONTROL_LEFT|CONTROL_RIGHT|CONTROL_ROT_LEFT|CONTROL_ROT_RIGHT|CONTROL_UP|CONTROL_DOWN|CONTROL_LBUTTON|CONTROL_ML_LBUTTON)
//integer allControls = ALL_CONTROLS;

//key rlvTPrequest;
#ifndef DEVELOPER_MODE
key mainCreator;
#endif
//key requestLoadData;
//key keyAnimationID;
//key lastAttachedID;
#ifdef DEVELOPER_MODE
float lastTimerEvent;
float thisTimerEvent;
float timerInterval;
integer timeReporting = 1;
#endif

//list rlvSources;
//list rlvStatus;

float rlvTimer;

//float baseWindRate;
//float afkSlowWalkSpeed = 5;
//float animRefreshRate = 8.0;

float nextRLVcheck;
//float nextAnimRefresh;

//vector carrierPos;
//vector lockPos;

list split;
string script;
integer remoteSeq;
integer optHeader;
integer code;

string name;
string value;

//string barefeet;
//string carrierName;
//string keyAnimation;

#ifdef DEVELOPER_MODE
string myPath;
#endif

//string pronounHerDoll = "Her";
//string pronounSheDoll = "She";
string rlvAPIversion;
//string redirchan;
string userBaseRLVcmd;

//integer afk;
//integer isAnimated;
//integer isFrozen;
//integer isNoScript;
//integer hasCarrier;
//integer isPosed; (use cdPosed)
//integer isSelfPosed; (use cdSelfPosed)
integer i;
//key animKey;
//list animList;

//key grantorID;
//integer permMask;

//integer carryMoved;
integer rlvChannel;
//integer clearAnim = 1;
//integer collapsed;
//integer dialogChannel;
//integer haveControls;
integer rlvHandle;
//integer locked;
#ifdef SIM_FRIENDLY
integer lowScriptMode;
#endif
//integer poseSilence;
//integer refreshControls;
integer RLVck = 0;
integer RLVok = UNSET;
integer RLVstarted;
//integer startup = 1;
//integer targetHandle;
//integer ticks;
//integer wearLock;
//integer newAttach = 1;
//integer creatorNoteDone;
integer chatChannel = 75;

//========================================
// FUNCTIONS
//========================================

//----------------------------------------
// RLV Initialization Functions

// Check for RLV support from user's viewer
//
// This is the starter function

doCheckRLV() {
    rlvTimer = llGetTime();
    RLVck = 0;
    RLVok = UNSET;
    rlvAPIversion = "";
    RLVstarted = 0;

#ifdef DEVELOPER_MODE
    myPath = "";
#endif

    debugSay(2,"DEBUG-RLV","starting a check for RLV");
    checkRLV();
}

// This the actual check - and is run multiple times
// to check for RLV
//
// Currently runs on init 110 - button press - and timer

checkRLV() {
    if (RLVok == 1) {
        RLVck = 0;
        llSetTimerEvent(0.0);
        return;
    }

    debugSay(2,"DEBUG-RLV","checking for RLV - try " + (string)RLVck + " of " + (string)MAX_RLVCHECK_TRIES);

    // rlvAPIversion is set by the listener when a message is received
    // myPath is set by the listener if a message is received that is not
    // a RestrainedLove or RestrainedLife message

    if (RLVck < MAX_RLVCHECK_TRIES) {
        // Check RLV again: give it several tries

        // Setting the DEBUG_BADRLV flag causes the listener to not be open for the check
        // This makes the viewer appear to have no RLV support as no reply will be heard
        // from the check; all other code works normally.

        // Increase number of check - RLVck is check number
        if (RLVck <= 0) {
            RLVck = 1;
#ifdef WAKESCRIPT
            cdWakeScript("StatusRLV");
            cdWakeScript("Transform");
#endif
        }
        else RLVck++;

#ifdef DEBUG_BADRLV
        // Make viewer act is if there is no RLV support
        cdListenerDeactivate(rlvHandle);
#else
        cdListenerActivate(rlvHandle);
#endif

        // Get RLV API version if we don't have it already
        if (rlvAPIversion == "") {
            if (RLVck > 2) llOwnerSay("@version=" + (string)rlvChannel);
            else llOwnerSay("@versionnew=" + (string)rlvChannel);
        }
#ifdef DEVELOPER_MODE
        else {
            // We got a positive RLV response - so try the path
            llOwnerSay("@getpathnew=" + (string)rlvChannel);
        }
#endif
        // Set next RLV check in 20s
        llSetTimerEvent(RLV_TIMEOUT);
        nextRLVcheck = llGetTime() + RLV_TIMEOUT;
    }
    else {
        // RLVck reached max
        debugSay(2,"DEBUG-RLV","RLV check failed...");

        // RLVstarted implies RLVok: if RLV has been activated in
        // the key code, then RLVstarted is set - or does it?

        if (!RLVstarted) {
            if (RLVok) llOwnerSay("Reattached Community Doll Key with " + rlvAPIversion + " active...");
            else llOwnerSay("Did not detect an RLV capable viewer, RLV features disabled.");
            debugSay(5,"DEBUG-RLV","myPath = " + (string)myPath + " and rlvAPIversion = " + rlvAPIversion);
            nextRLVcheck = 0.0;
        }

#ifdef DEVELOPER_MODE
        if ((rlvAPIversion != "") && (myPath == "")) { // Dont enable RLV on devs if @getpath is returning no usable result to avoid lockouts.
            llSay(DEBUG_CHANNEL, "WARNING: Sanity check failure developer key not found in #RLV see README.dev for more information.");
            return;
        }
#endif
    }
}

// Activate RLV settings

activateRLV() {
    if (!RLVok) {
        RLVstarted = 0;
        return;
    }

    string baseRLV;

    if (!RLVstarted) {
        llOwnerSay("@clear");

#ifndef LOCKON
        // if Doll is one of the developers... dont lock:
        // prevents inadvertent lock-in during development

        cdSayQuietly("Developer Key not locked");

        baseRLV += "attachallthis_except:" + myPath + "=add,detachallthis_except:" + myPath + "=add,";
#endif
        llOwnerSay("Enabling RLV mode");

        cdListenerDeactivate(rlvHandle);
        lmSendConfig("RLVok",(string)RLVok); // is this needed or redundant?
        lmRLVreport(RLVok, rlvAPIversion, 0);
    }

#ifdef LOCKON
    mainCreator = llGetInventoryCreator("Main");

    // We lock the key on here - but in the menu system, it appears
    // unlocked and detachable: this is because it can be detached
    // via the menu. To make the key truly "undetachable", we get
    // rid of the menu item to unlock it

    if (mainCreator != dollID) {
        lmRunRLVas("Base", "detach=n,permissive=n");  //locks key

        locked = 1; // Note the locked variable also remains false for developer mode keys
                    // This way controllers are still informed of unauthorized detaching so developer dolls are still accountable
                    // With this is the implicit assumption that controllers of developer dolls will be understanding and accepting of
                    // the occasional necessity of detaching during active development if this proves false we may need to fudge this
                    // in the section below.
    }
    else {
        if (!RLVstarted) llSay(DEBUG_CHANNEL, "Backup protection mechanism activated not locking on creator");
        lmRunRLVas("Base", "clear=unshared,clear=attachallthis");
    }
#endif

    if (userBaseRLVcmd != "") lmRunRLVas("UserBase", userBaseRLVcmd);

    //lmRunRLVas("Core", baseRLV + restrictionList + "sendchannel:" + (string)chatChannel + "=rem");
    lmRunRLVas("Core", baseRLV + ",sendchannel:" + (string)chatChannel + "=rem");

    // If we get here - RLVok is already set
    //RLVstarted = (RLVstarted | RLVok);
    RLVstarted = 1;
}

//========================================
// STATES
//========================================
default {

    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    state_entry() {
        dollName = llGetDisplayName(dollID = llGetOwner());

        rlvTimer = llGetTime();
        RLVck = 0;
        RLVok = UNSET;
        rlvAPIversion = "";
        RLVstarted = 0;

#ifdef DEVELOPER_MODE
        myPath = "";
#endif

        cdInitializeSeq();
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer start) {

        rlvTimer = llGetTime();
        RLVck = 0;
        RLVok = UNSET;
        rlvAPIversion = "";
        RLVstarted = 0;

#ifdef DEVELOPER_MODE
        myPath = "";
#endif
        //doCheckRLV();
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer chan, string name, key id, string msg) {

        //debugSay(2, "DEBUG-AVATAR", "Listener tripped....");
        if (chan == rlvChannel) {
            //debugSay(2, "DEBUG-RLV", "RLV Message received: " + msg);

            if ((llGetSubString(msg, 0, 13) == "RestrainedLove") ||
                (llGetSubString(msg, 0, 13) == "RestrainedLife")) {

                debugSay(2, "DEBUG-RLV", "RLV Version: " + msg);

                rlvAPIversion = msg;

#ifdef DEVELOPER_MODE
                // We got a positive RLV response - so try the path
                llOwnerSay("@getpathnew=" + (string)rlvChannel);

                llSetTimerEvent(RLV_TIMEOUT);
                nextRLVcheck = llGetTime() + RLV_TIMEOUT;
#else
                nextRLVcheck = 0.0;
                RLVok = 1;
                lmSendConfig("RLVok",(string)RLVok); // is this needed or redundant?
                lmRLVreport(RLVok, rlvAPIversion, 0);
                activateRLV();
#endif
            }
            else {
#ifdef DEVELOPER_MODE
                debugSay(2, "DEBUG-RLV", "RLV Key Path: " + msg);
                myPath = msg;
#endif
                nextRLVcheck = 0.0;
                RLVok = 1;
                lmSendConfig("RLVok",(string)RLVok); // is this needed or redundant?
                //debugSay(2, "DEBUG-RLV", "RLV set to " + (string)RLVok + " and message sent on link channel");
                llOwnerSay("RLV check completed in " + formatFloat((llGetTime() - rlvTimer),1) + "s");
                lmRLVreport(RLVok, rlvAPIversion, 0);
                activateRLV();
            }
        }
    }

    //----------------------------------------
    // ATTACH
    //----------------------------------------
    attach(key id) {

        if (id) doCheckRLV();
    }

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer sender, integer i, string data, key id) {

        // Parse link message header information
        split     = cdSplitArgs(data);
        script    = cdListElement(split, 0);
        remoteSeq = (i & 0xFFFF0000) >> 16;
        optHeader = (i & 0x00000C00) >> 10;
        code      =  i & 0x000003FF;

        split     = llDeleteSubList(split, 0, 0 + optHeader);

        scaleMem();

        if (code == 135) {
            float delay = llList2Float(split, 0);
            memReport(cdMyScriptName(),delay);
        } else

        cdConfigReport();

        else if (code == CONFIG) {
            name = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);
            value = llList2String(split, 0);
            
            // Like to be soemthing here before long... so mark it
            ;
            if (name == "dialogChannel") {
                dialogChannel = (integer)value;

                llListenRemove(rlvHandle);
                // Calculate positive (RLV compatible) rlvChannel
                rlvChannel = ~dialogChannel + 1;
                rlvHandle = llListen(rlvChannel, "", "", "");
                cdListenerDeactivate(rlvHandle);

                // as soon as rlvHandle is valid - we can check for RLV
                //if (RLVok == UNSET) checkRLV();
                if (RLVok == UNSET) lmInternalCommand("doCheckRLV","",NULL_KEY);
            }
        }
        else if (code == INTERNAL_CMD) {
            string cmd = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "doCheckRLV") doCheckRLV();
        }
        else if (code == MENU_SELECTION) {
            string choice = llList2String(split, 0);
            string name = llList2String(split, 1);

            // First: Quick ignores
            if (llGetSubString(choice,0,3) == "Wind") return;
            else if (choice == MAIN) return;

            else if (choice == "RLV Off") {
                RLVck = 0;
                RLVok = 0;
                rlvAPIversion = "";
                RLVstarted = 0;

#ifdef DEVELOPER_MODE
                myPath = "";
#endif
                lmSendConfig("RLVok",(string)RLVok);
            }
            else if (choice == "RLV On") doCheckRLV();
        }
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------

    // Timer fires for only one reason: RLVcheck timeout

    timer() {
#ifdef DEVELOPER_MODE
        thisTimerEvent = llGetTime();

        if (cdAttached()) timerInterval = thisTimerEvent - lastTimerEvent;
        lastTimerEvent = thisTimerEvent;

        if (timeReporting) llOwnerSay("CheckRLV Timer fired, interval " + formatFloat(timerInterval,3) + "s.");
#endif

        // IF RLV is ok we don't have to check it do we?

        if (RLVok == UNSET) {
            // this makes sure that enough time has elapsed - and prevents
            // the check from being missed...
            if (nextRLVcheck < llGetTime()) checkRLV();
        }
        else {
            llSetTimerEvent(0.0);
#ifdef DEVELOPER_MODE
            debugSay(2,"DEBUG-RLV","Stopping RLV Check Timer: RLVok = " + (string)RLVok);
#endif
        }

        // Doesn't matter if RLVok is TRUE, FALSE, or UNSET: propogate the value
        lmSendConfig("RLVok",(string)RLVok);
    }
}
