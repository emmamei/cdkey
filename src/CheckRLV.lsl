//========================================
// CheckRLV.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 27 October 2014

#include "include/GlobalDefines.lsl"

#define cdSayQuietly(x) { string z = x; if (quiet) llOwnerSay(z); else llSay(0,z); }
#define NOT_IN_REGION ZERO_VECTOR
#define cdLockMeisterCmd(a) llWhisper(LOCKMEISTER_CHANNEL,(string)dollID+a)
#define MAX_RLVCHECK_TRIES 5
#define RLV_TIMEOUT 20.0
#define UNSET -1

#define cdListenerDeactivate(a) llListenControl(a, 0)
#define cdListenerActivate(a) llListenControl(a, 1)
#define cdResetKey() llResetOtherScript("Start")
#define lmDoCheckRLV() lmInternalCommand("doCheckRLV","",NULL_KEY)

// Could set allControls to -1 for quick full bit set -
// but that would set fields with undefined values: this is more
// accurate
//#define ALL_CONTROLS (CONTROL_FWD|CONTROL_BACK|CONTROL_LEFT|CONTROL_RIGHT|CONTROL_ROT_LEFT|CONTROL_ROT_RIGHT|CONTROL_UP|CONTROL_DOWN|CONTROL_LBUTTON|CONTROL_ML_LBUTTON)
//integer allControls = ALL_CONTROLS;

#ifdef DEVELOPER_MODE
float lastTimerEvent;
float thisTimerEvent;
float timerInterval;
#else
key mainCreator;
integer locked;
#endif

float rlvTimer;

float nextRLVcheck;

string name;
string value;

#ifdef DEVELOPER_MODE
string myPath;
#endif

string rlvAPIversion;
string userBaseRLVcmd;

integer i;
integer rlvChannel;
integer rlvHandle;
integer RLVck = 0;
integer RLVstarted;
integer chatChannel = 75;

//========================================
// FUNCTIONS
//========================================

//----------------------------------------
// RLV Initialization Functions

// Check for RLV support from user's viewer
//
// This is the starter function. Notice that
// even if RLV has already been checked, this WILL
// run again...

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
        lmInternalCommand("refreshRLV","",NULL_KEY);
        return;
    }

    debugSay(2,"DEBUG-RLV","checking for RLV - try " + (string)RLVck + " of " + (string)MAX_RLVCHECK_TRIES);
    //rlvTimer = llGetTime();

    // rlvAPIversion is set by the listener when a message is received
    // myPath is set by the listener if a message is received that is not
    // a RestrainedLove or RestrainedLife message

    if (RLVck < MAX_RLVCHECK_TRIES) {
        // Check RLV again: give it several tries

        // Setting the FAKE_NORLV flag causes the listener to not be open for the check
        // This makes the viewer appear to have no RLV support as no reply will be heard
        // from the check; all other code works normally.

        // Increase number of check - RLVck is check number
        if (RLVck <= 0) {
            RLVck = 1;
        }
        else RLVck++;

#ifdef FAKE_NORLV
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
        RLVok = 0;

        llOwnerSay("Did not detect an RLV capable viewer, RLV features disabled.");
        nextRLVcheck = 0.0;
    }
}

activateRLVBase() {
    if (!RLVok) return;

#ifdef DEVELOPER_MODE
    string baseRLV = "permissive=n";
#else
    string baseRLV = "detach=n,permissive=n";
#endif

    if (userBaseRLVcmd != "") lmRunRLVas("UserBase", userBaseRLVcmd);

    //lmRunRLVas("Core", baseRLV + restrictionList + "sendchannel:" + (string)chatChannel + "=rem");
    baseRLV += ",sendchannel:" + (string)chatChannel + "=rem";

    if (userBaseRLVcmd != "")
        lmRunRLVas("UserBase", userBaseRLVcmd);

    if (autoTP) baseRLV += "accepttp=n,";
    else baseRLV += "accepttp=y,";
    if (!canSelfTP) baseRLV += "tplm=n,tploc=n,";
    else baseRLV += "tplm=y,tploc=y,";
    if (!canFly) baseRLV += "fly=n,";
    else baseRLV += "fly=y,";
    if (!canStand) baseRLV += "unsit=n,";
    else baseRLV += "unsit=y,";
    if (!canSit) baseRLV += "sit=n";
    else baseRLV += "sit=y";

    lmRunRLVas("Base", baseRLV);

    if (!canDressSelf || collapsed || wearLock || afk) {
#ifdef LOCKON
        // Lock outfit down tight
        lmRunRLVas("Dress", "unsharedwear=n,unsharedunwear=n,attachallthis:=n,detachallthis:=n");
#else
        // Don't lock on developers
        lmRunRLVas("Dress", "unsharedwear=y,unsharedunwear=y,attachallthis:=y,detachallthis:=y");
#endif
    }
    else {
        // lmRunRLVas("Dress", "clear");
        lmRunRLVas("Dress", "unsharedwear=y,unsharedunwear=y,attachallthis:=y,detachallthis:=y");
    }
}

// Activate RLV settings
//
// This is designed to be called repetitively...

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

        //cdSayQuietly("Developer Key not locked");

        baseRLV += "attachallthis_except:" + myPath + "=add,detachallthis_except:" + myPath + "=add,";
#endif
        llOwnerSay("Enabling RLV mode");

#ifdef LOCKON
        mainCreator = llGetInventoryCreator("Main");

        // We lock the key on here - but in the menu system, it appears
        // unlocked and detachable: this is because it can be detached
        // via the menu. To make the key truly "undetachable", we get
        // rid of the menu item to unlock it

        if (mainCreator != dollID) {
            if (RLVok)
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
        cdListenerDeactivate(rlvHandle);
        //lmSendConfig("RLVok",(string)RLVok); // is this needed or redundant?

        // This generates a 350 link message
        lmRLVreport(RLVok, rlvAPIversion, 0);
    }

    activateRLVBase();

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

        // Initial RLV Check results are being processed here
        //
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

                //lmSendConfig("RLVok",(string)RLVok); // is this needed or redundant?

                cdListenerDeactivate(rlvHandle);
                activateRLV();
                lmRLVreport(RLVok, rlvAPIversion, 0);
#endif
            }
#ifdef DEVELOPER_MODE
            else {
                debugSay(2, "DEBUG-RLV", "RLV Key Path: " + msg);
                myPath = msg;

                nextRLVcheck = 0.0;
                RLVok = 1;

                //lmSendConfig("RLVok",(string)RLVok); // is this needed or redundant?
                //debugSay(2, "DEBUG-RLV", "RLV set to " + (string)RLVok + " and message sent on link channel");
                llOwnerSay("RLV check completed in " + formatFloat((llGetTime() - rlvTimer),1) + "s");
                rlvTimer = 0;

                cdListenerDeactivate(rlvHandle);
                activateRLV();
                lmRLVreport(RLVok, rlvAPIversion, 0);
            }
#endif
        }
    }

    //----------------------------------------
    // ATTACH
    //----------------------------------------
    attach(key id) {

        if (id)
            // this triggers a dialogChannel event
            cdDialogListen();
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

        if (code == CONFIG) {
            name = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);
            value = llList2String(split, 0);
            integer c = llGetSubString(name, 0, 0);

            if (llListFindList(c, [ "a", "c", "d", "w" ]) == NOT_FOUND) return;

                 if (name == "autoTP")        {       autoTP = (integer)value; activateRLVBase(); }
            else if (name == "afk")           {          afk = (integer)value; activateRLVBase(); }
            else if (c == "c") {
                     if (name == "canSelfTP")     {    canSelfTP = (integer)value; activateRLVBase(); }
                else if (name == "canDressSelf")  { canDressSelf = (integer)value; activateRLVBase(); }
                else if (name == "canFly")        {       canFly = (integer)value; activateRLVBase(); }
                else if (name == "canStand")      {     canStand = (integer)value; activateRLVBase(); }
                else if (name == "canSit")        {       canSit = (integer)value; activateRLVBase(); }
                else if (name == "collapsed")     {    collapsed = (integer)value; activateRLVBase(); }
                else if (name == "controllers") {
                    if (split == [""]) controllers = [];
                    else controllers = split;
                }
            }

            else if (name == "dialogChannel") {
                dialogChannel = (integer)value;

                if (rlvHandle == 0 || RLVok == UNSET) {
                    llListenRemove(rlvHandle);
                    // Calculate positive (RLV compatible) rlvChannel
                    rlvChannel = ~dialogChannel + 1;
                    rlvHandle = cdListenMine(rlvChannel);
                    cdListenerDeactivate(rlvHandle);

                    // As soon as rlvHandle is valid - we can check for RLV:
                    // Note this puts an event in, but does NOT execute until its turn
                    lmInternalCommand("doCheckRLV","",NULL_KEY);
                }
            }
            else if (name == "wearLock")      {     wearLock = (integer)value; activateRLVBase(); }
        }
        else if (code == INTERNAL_CMD) {
            string cmd = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);

                 if (cmd == "doCheckRLV") doCheckRLV();
            else if (cmd == "updateExceptions") {

                // Exempt builtin or user specified controllers from TP restictions
                if (!RLVok) return;

                list exceptions = BUILTIN_CONTROLLERS + cdList2ListStrided(controllers, 0, -1, 2);
                integer i;

                if cdCarried() {
                    if (llListFindList(exceptions, (list)carrierID) != NOT_FOUND) exceptions += carrierID;
                }

                // Dolly not allowed to be on this list
                //
                // Most likely, Dolly might be in Builtin Controllers list...

                if ((i = llListFindList(exceptions, (list)dollID)) != NOT_FOUND)
                    llDeleteSubList(exceptions, i, i);

                // Directly dump the list using the static parts of the RLV command as a seperator; no looping needed

                lmRunRLVas("Base", "clear=tplure:,tplure:"          + llDumpList2String(exceptions, "=add,tplure:")    + "=add");
                lmRunRLVas("Base", "clear=accepttp:,accepttp:"      + llDumpList2String(exceptions, "=add,accepttp:")  + "=add");
                lmRunRLVas("Base", "clear=sendim:,sendim:"          + llDumpList2String(exceptions, "=add,sendim:")    + "=add");
                lmRunRLVas("Base", "clear=recvim:,recvim:"          + llDumpList2String(exceptions, "=add,recvim:")    + "=add");
                lmRunRLVas("Base", "clear=recvchat:,recvchat:"      + llDumpList2String(exceptions, "=add,recvchat:")  + "=add");
                lmRunRLVas("Base", "clear=recvemote:,recvemote:"    + llDumpList2String(exceptions, "=add,recvemote:") + "=add");
            }
        }
        else if (code < 200) {
            if (code == MEM_REPORT) {
                float delay = llList2Float(split, 0);
                memReport(cdMyScriptName(),delay);
            }
            else if (code == CONFIG_REPORT) {

                cdConfigureReport();
            }
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
            RLVok = FALSE;
            if (nextRLVcheck < llGetTime()) checkRLV();
        }
        else {
            llSetTimerEvent(0.0);
#ifdef DEVELOPER_MODE
            debugSay(2,"DEBUG-RLV","Stopping RLV Check Timer: RLVok = " + (string)RLVok);
#endif
        }

        // Doesn't matter if RLVok is TRUE, FALSE, or UNSET: propogate the value
        //lmSendConfig("RLVok",(string)RLVok);
        lmRLVreport(RLVok, rlvAPIversion, 0);
    }
}

//========== CHECKRLV ==========
