//========================================
// CheckRLV.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 24 November 2020

#include "include/GlobalDefines.lsl"

#define NOT_IN_REGION ZERO_VECTOR
#define cdLockMeisterCmd(a) llWhisper(LOCKMEISTER_CHANNEL,(string)dollID+a)
#define MAX_RLVCHECK_TRIES 5
#define RLV_TIMEOUT 30.0
#define UNSET -1

#define cdListenerDeactivate(a) llListenControl(a, 0)
#define cdListenerActivate(a) llListenControl(a, 1)
#define cdResetKey() llResetOtherScript("Start")
#define cdHaltTimer() llSetTimerEvent(0.0);
#define lmRunRLVBoolean(a,b) if ((b) == 1) { lmRunRLV((a)+"=y"); } else { lmRunRLV((a)+"=n"); }

// Note we bypass this, and call the routine directly
#define lmDoCheckRLV() lmInternalCommand("doCheckRLV","",NULL_KEY)

string name;
string value;

#ifdef DEVELOPER_MODE
string myPath;
#endif

string rlvAPIversion;
//string userBaseRLVcmd;

integer i;
integer rlvChannel;
integer rlvHandle;
integer RLVck = MAX_RLVCHECK_TRIES;
integer RLVstarted;

list rlvExceptions;

#define MAX_INT DEBUG_CHANNEL

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

// This is the main place where the RLV listener is opened.

doCheckRLV() {
    // Checking for RLV
    llOwnerSay("Checking for RLV support");

    // Set up RLV listener
    if (rlvChannel == 0) { // rlvChannel should be zero only when unset
        // Calculate positive (RLV compatible) rlvChannel
        rlvChannel = MAX_INT - (integer)llFrand(5000);
        rlvHandle = cdListenMine(rlvChannel);

        cdListenerActivate(rlvHandle);
    }

    // Configure variables
    RLVck = MAX_RLVCHECK_TRIES;
    RLVok = UNSET;
    RLVsupport = UNSET;
    rlvAPIversion = "";
    RLVstarted = FALSE;

#ifdef DEVELOPER_MODE
    myPath = "";
#endif

    debugSay(2,"DEBUG-RLV","starting a check for RLV");
    checkRLVcore();
}

// This the actual check - and is run multiple times
// to check for RLV
//
// We should only be calling checkRLV to begin a test, or in the
// case that the timer expired. Thus, RLVok should be UNSET.
// If RLVok was TRUE, then no more check tries are needed.
// If RLVok is FALSE, then there should be no more tries to make.

checkRLVcore() {
    // Check RLV: this could be called multiple times (retries)
    debugSay(2,"DEBUG-RLV","checking for RLV - try " + (string)(MAX_RLVCHECK_TRIES - RLVck) + " of " + (string)MAX_RLVCHECK_TRIES);

    // Decrease number of retries - RLVck is check counter
    RLVck -= 1;

    // Timeout: if no listener reply received, time out
    llSetTimerEvent(RLV_TIMEOUT);

    // Switch to older command if newer one fails
    if (RLVck > 2) llOwnerSay("@versionnew=" + (string)rlvChannel);
    else           llOwnerSay("@version="    + (string)rlvChannel);
}

activateRLVBase() {
    if (RLVok != TRUE) return;

#ifdef DEVELOPER_MODE
    string baseRLV;
#else
    string baseRLV = "detach=n,";
#endif

    if (autoTP)     baseRLV += "accepttp=n,";       else baseRLV += "accepttp=y,";
    if (!canSelfTP) baseRLV += "tplm=n,tploc=n,";   else baseRLV += "tplm=y,tploc=y,";
    if (!canFly)    baseRLV += "fly=n,";            else baseRLV += "fly=y,";
    if (!canStand)  baseRLV += "unsit=n,";          else baseRLV += "unsit=y,";
    if (!canSit)    baseRLV += "sit=n";             else baseRLV += "sit=y";

    lmRunRLVas("Base", baseRLV);
    lmSendConfig("defaultBaseRLVcmd",(string)baseRLV); // save the defaults
    outfitRLVLock();

    // Add users choice of extended base RLV restrictions
    //
    // Normally, this wouldn't be run - but if prefs have
    // already been run, and this is called, set the user
    // base too...
    //
    //if (userBaseRLVcmd != "")
    //    lmRunRLVas("UserBase", userBaseRLVcmd);
}

outfitRLVLock() {
#ifdef LOCKON
    if (!canDressSelf || hardcore || collapsed || wearLock) {
        // Lock outfit down tight
        lmRunRLVas("Dress", "unsharedwear=n,unsharedunwear=n,attachallthis:=n,detachallthis:=n");
    }
    else {
        lmRunRLVas("Dress", "unsharedwear=y,unsharedunwear=y,attachallthis:=y,detachallthis:=y");
    }
#else
    // Don't lock on developers
    lmRunRLVas("Dress", "unsharedwear=y,unsharedunwear=y,attachallthis:=y,detachallthis:=y");
#endif
}

// Activate RLV settings
//
// This is designed to be called repetitively...

activateRLV() {

    // At this point RLVok is TRUE

    if (!RLVstarted) { // This is the only reason RLVstarted exists
        lmRunRLVcmd("clearRLVcmd","");

        llOwnerSay("Enabling RLV mode");

#ifdef LOCKON
        // We lock the key on here - but in the menu system, it appears
        // unlocked and detachable: this is because it can be detached
        // via the menu. To make the key truly "undetachable", we get
        // rid of the menu item to unlock it

        if (RLVok == TRUE)
            lmRunRLVas("Base", "detach=n");  //locks key
#else
        // if Doll is one of the developers... dont lock:
        // prevents inadvertent lock-in during development
#endif
        lmSendConfig("RLVok",(string)RLVok); // is this needed or redundant?
        lmSendConfig("RLVsupport",(string)RLVsupport);

        // This generates a 350 link message (RLV_RESET)
        lmRLVreport(RLVok, rlvAPIversion, 0);
    }

    activateRLVBase();

    // If we get here - RLVok is already set
    RLVstarted = TRUE;
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

#ifdef DEVELOPER_MODE
        myPath = "";
#endif
        cdInitializeSeq();
        doCheckRLV();
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer start) {

        // IF RLVok is TRUE, then check to see that RLV is
        // actually available on the viewer

#ifdef DEVELOPER_MODE
        myPath = "";
#endif
        llListenRemove(rlvHandle);
        rlvChannel == 0;

        // Note this happens only at the very beginning
        doCheckRLV();
    }

    //----------------------------------------
    // ATTACH
    //----------------------------------------
    attach(key id) {

        if (id) doCheckRLV();
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer chan, string name, key id, string msg) {

        debugSay(2, "DEBUG-AVATAR", "Listener tripped on channel " + (string)chan);
        debugSay(2, "DEBUG-AVATAR", "Listener data = " + (string)msg);

        // Initial RLV Check results are being processed here
        //
        if (chan == rlvChannel) {
            debugSay(2, "DEBUG-RLV", "RLV Message received: " + msg);

            if ((llGetSubString(msg, 0, 13) == "RestrainedLove") ||
                (llGetSubString(msg, 0, 13) == "RestrainedLife")) {

                rlvAPIversion = msg;
                debugSay(2, "DEBUG-RLV", "RLV Version: " + rlvAPIversion);
            }
            else {
                debugSay(2, "DEBUG-RLV", "Unknown RLV response message: " + msg);
            }

            cdHaltTimer();
            RLVok = TRUE;
            RLVsupport = TRUE;

            activateRLV();
        }
#ifdef DEVELOPER_MODE
        else {
            llSay(DEBUG_CHANNEL,"Received RLV response data on wrong channel! (" + (string)chan +
                ") - msg = " + msg);
        }
#endif
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

        if (code == SEND_CONFIG) {
            name = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);
            value = llList2String(split, 0);
            string c = llGetSubString(name, 0, 0);

            if (llListFindList([ "a", "c", "d", "w" ],(list)c) == NOT_FOUND) return;

                 if (name == "autoTP")        {       autoTP = (integer)value; lmRunRLVBoolean("accepttp", !autoTP); }
            else if (name == "hardcore")      {     hardcore = (integer)value; outfitRLVLock(); }
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")    {   debugLevel = (integer)value; }
#endif
            else if (c == "c") {
                     if (name == "canSelfTP")     {    canSelfTP = (integer)value; lmRunRLVBoolean("tplm", canSelfTP); lmRunRLVBoolean("tploc", canSelfTP); }
                else if (name == "canDressSelf")  { canDressSelf = (integer)value; outfitRLVLock(); }
                else if (name == "canFly")        {       canFly = (integer)value; lmRunRLVBoolean("fly", canFly); }
                else if (name == "canStand")      {     canStand = (integer)value; lmRunRLVBoolean("unsit", canStand); }
                else if (name == "canSit")        {       canSit = (integer)value; lmRunRLVBoolean("sit", canSit); }
                else if (name == "collapsed")     {    collapsed = (integer)value; outfitRLVLock(); }
                else if (name == "controllers") {
                    if (split == [""]) controllers = [];
                    else controllers = split;
                }
                else if (name == "chatChannel") { chatChannel = (integer)value; }
            }

            else if (name == "dialogChannel") {
                dialogChannel = (integer)value;

                llListenRemove(rlvHandle);

                // Calculate positive (RLV compatible) rlvChannel
                rlvChannel = ~dialogChannel + 1;
                rlvHandle = cdListenMine(rlvChannel);
                cdListenerActivate(rlvHandle);
            }
            else if (name == "wearLock") { wearLock = (integer)value; outfitRLVLock(); }
        }
        else if (code == RLV_RESET) {
            RLVok = llList2Integer(split, 0);

            debugSay(4,"DEBUG-MENU","RLV Reset: Updating exceptions");
            if (RLVok == TRUE)
                lmInternalCommand("reloadExceptions", script, NULL_KEY);
        }
        else if (code == INTERNAL_CMD) {
            string cmd = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);

            //debugSay(3,"DEBUG-CHECKRLV","Internal command triggered: " + cmd);

            if (cmd == "doCheckRLV") {
                doCheckRLV();
            }
            else if (cmd == "addExceptions") {
                string exceptionKey = llList2String(split, 0);

                llOwnerSay("@tplure:"    + (string)(exceptionKey) + "=add," +
                            "accepttp:"  + (string)(exceptionKey) + "=add," +
                            "sendim:"    + (string)(exceptionKey) + "=add," +
                            "recvim:"    + (string)(exceptionKey) + "=add," +
                            "recvchat:"  + (string)(exceptionKey) + "=add," +
                            "recvemote:" + (string)(exceptionKey) + "=add");
            }
            else if (cmd == "reloadExceptions") {
                // VERY IMPORTANT: DO NOT CALL lmRunRLV OR lmRunRLVas!! THIS WILL SET UP
                // A SCRIPT LOOP THAT WILL BE VERY HARD TO ESCAPE.

                // Exempt builtin or user specified controllers from TP restictions
                if (RLVok == FALSE) return;

                list exceptions = cdList2ListStrided(controllers, 0, -1, 2);
                if (exceptions == []) return;

                integer i;

                if cdCarried() {
                    if (llListFindList(exceptions, (list)carrierID) != NOT_FOUND) exceptions += carrierID;
                }

                // Dolly not allowed to be on this list
                //
                // Most likely, Dolly might be in Builtin Controllers list...

                if ((i = llListFindList(exceptions, (list)dollID)) != NOT_FOUND)
                    llDeleteSubList(exceptions, i, i);

                //debugSay(5,"DEBUG-CHECKRLV","Checking to see if exceptions have changed");
                // Goal is to check and see if the exceptions have changed...
                // If we make it through here, they have changed.
                //if (rlvExceptions == exceptions) { // compares item count only
                //    if (rlvExceptions == []) return; // compares list to null
                //    if (!llListFindList(rlvExceptions, exceptions)) return;
                //}
                //debugSay(5,"DEBUG-CHECKRLV","Exceptions have changed");

                rlvExceptions = exceptions; // save current exceptions

                // Restrictions (and exceptions)
                //
                //    TPLure: being transported to a TP sent by a friend
                //  AcceptTP: being able to accept a TP
                //    SendIM: being able to send an IM to someone
                //    RecvIM: being able to recieve an IM from someone
                //  RecvChat: being able to recieve a chat message from someone
                // RecvEmote: being able to recieve an emote from someone

                debugSay(5,"DEBUG-CHECKRLV","Reloading RLV exceptions");
                // SELECTIVE clear: exceptions only
                llOwnerSay("@clear=tplure:,clear=accepttp:");
                llOwnerSay("@clear=sendim:,clear=recvim:");
                llOwnerSay("@clear=recvchat:,clear=recvemote:");

                string exceptionKey;
                i = llGetListLength(exceptions);
                while (i--) {
                    exceptionKey = llList2String(exceptions, i);

                    // This assumes that exceptions are a block...
                    // for now they are
                    llOwnerSay("@tplure:"    + (string)(exceptionKey) + "=add," +
                                "accepttp:"  + (string)(exceptionKey) + "=add," +
                                "sendim:"    + (string)(exceptionKey) + "=add," +
                                "recvim:"    + (string)(exceptionKey) + "=add," +
                                "recvchat:"  + (string)(exceptionKey) + "=add," +
                                "recvemote:" + (string)(exceptionKey) + "=add");
                }
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

        if (timeReporting)
            debugSay(5,"DEBUG-CHECKRLV","CheckRLV Timer fired, interval " + formatFloat(timerInterval,3) + "s.");
#endif

        // RLVok shouldn't be TRUE here: timer would be shut off
        debugSay(2,"DEBUG-RLV","RLV check failed...");

        if (RLVck > 0) {
            checkRLVcore(); // try again
        }
        else {
            llOwnerSay("Did not detect an RLV capable viewer, RLV features disabled.");
            cdHaltTimer();
            RLVok = FALSE;
            RLVsupport = FALSE;

            lmRLVreport(RLVok, "", 0); // report FALSE
            lmSendConfig("RLVsupport",(string)RLVsupport);
        }
    }
}

//========== CHECKRLV ==========
