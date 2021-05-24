//========================================
// CheckRLV.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 24 November 2020

#include "include/GlobalDefines.lsl"

#define NOT_IN_REGION ZERO_VECTOR
#define MAX_RLVCHECK_TRIES 5
#define RLV_TIMEOUT 10.0
#define UNSET -1

#define cdListenerDeactivate(a) llListenControl(a, 0)
#define cdListenerActivate(a) llListenControl(a, 1)
#define cdResetKey() llResetOtherScript("Start")
#define cdHaltTimer() llSetTimerEvent(0.0);
#define rlvSetIf(a,b) if ((b) == 1) { lmRunRLV((a)+"=y"); } else { lmRunRLV((a)+"=n"); }
#define rlvLockOutfit()   lmRunRLVas("Dress", "unsharedwear=n,unsharedunwear=n,attachallthis:=n,detachallthis:=n");
#define rlvUnlockOutfit() lmRunRLVas("Dress", "unsharedwear=y,unsharedunwear=y,attachallthis:=y,detachallthis:=y");

string name;
string value;

#ifdef DEVELOPER_MODE
string myPath;
#endif

string rlvAPIversion;

integer i;
integer rlvChannel;
integer rlvHandle;
integer rlvCheck = MAX_RLVCHECK_TRIES;
integer rlvStarted;
integer keyInit;
integer isOutfitLocked = FALSE;
integer keyLocked = FALSE;

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

#define NO_CHANNEL 0

// This is the place where the RLV listener is opened,
// and the search for RLV begins.
//
// Note that this now does NOT run automatically on startup,
// but waits for the Start script to activate it.
//
startRlvCheck() {
    // Checking for RLV
    llOwnerSay("Checking for RLV support");
    llResetTime();

    // Set up listener to receive RLV command output
    if (rlvChannel == NO_CHANNEL) {
        // Calculate positive (RLV compatible) rlvChannel
        rlvChannel = MAX_INT - (integer)llFrand(5000);
        rlvHandle = cdListenMine(rlvChannel);

        cdListenerActivate(rlvHandle);
    }

    // Configure variables
    rlvCheck = MAX_RLVCHECK_TRIES;
    RLVok = UNSET;
    RLVsupport = UNSET;
    rlvAPIversion = "";
    rlvStarted = FALSE;

#ifdef DEVELOPER_MODE
    myPath = "";
#endif

    debugSay(2,"DEBUG-CHECKRLV","starting a check for RLV");
    rlvCheckTry();
}

// This the actual check - and is run multiple times
// to check for RLV
//
// We should only be calling checkRLV to begin a test, or in the
// case that the timer expired. Thus, RLVok should be UNSET.
// If RLVok was TRUE, then no more check tries are needed.
// If RLVok is FALSE, then there should be no more tries to make.

rlvCheckTry() {
    // Check RLV: this could be called multiple times (retries)
    debugSay(2,"DEBUG-CHECKRLV","checking for RLV - try " + (string)(MAX_RLVCHECK_TRIES - rlvCheck) + " of " + (string)MAX_RLVCHECK_TRIES);

    // Decrease number of retries - rlvCheck is check counter
    rlvCheck -= 1;

    // Timeout: if no listener reply received, time out
    //
    // Doing it this way means if a quick reply, then we are good to
    // go; if not, we keep upping the timer until we get to the end
         if (rlvCheck == MAX_RLVCHECK_TRIES)      llSetTimerEvent(2);
    else if (rlvCheck == MAX_RLVCHECK_TRIES - 1)  llSetTimerEvent(4);
    else if (rlvCheck == MAX_RLVCHECK_TRIES - 2)  llSetTimerEvent(8);
    else if (rlvCheck == MAX_RLVCHECK_TRIES - 3)  llSetTimerEvent(10);
    else if (rlvCheck == MAX_RLVCHECK_TRIES - 4)  llSetTimerEvent(15);
    else                                          llSetTimerEvent(15);

    // Switch to older command if newer one fails
    if (rlvCheck > 2) llOwnerSay("@versionnew=" + (string)rlvChannel);
    else              llOwnerSay("@version="    + (string)rlvChannel);
}

rlvRestoreRestritions() {
    if (RLVok != TRUE) return;

    string baseRLV;

    // This adjusts the default "base" RLV based on Dolly's settings...
    //
    // In this, defaultBaseRLVcmd is much more flexible than the other defaults
    //
#ifdef EMERGENCY_TP
    if (autoTP)     baseRLV += "accepttp=n,";       else baseRLV += "accepttp=y,";
#endif
    if (!canSelfTP) baseRLV += "tplm=n,tploc=n,";   else baseRLV += "tplm=y,tploc=y,";
    if (!canFly)    baseRLV += "fly=n,";            else baseRLV += "fly=y,";

    lmRunRLVas("Base", baseRLV);
    lmSendConfig("defaultBaseRLVcmd",(string)baseRLV); // save the defaults

    if (keyLocked) lmRunRLVas("Base","detach=n");
    else lmRunRLVas("Base","detach=n");

    rlvOutfitLock();
}

// Lock the outfit on the wearer
//
rlvOutfitLock() {

    // Lock the current outfit if one of these is true:
    //
    //    * Dolly cannot dress themselves
    //    * Dolly is in hardcore mode
    //    * Dolly is collapsed
    //    * Dolly is in "wear lock"
    //
    // This means Dolly is forbidden to change the current outfit
    //
    if (!canDressSelf || collapsed || wearLock) {
        // Lock outfit down tight
        if (isOutfitLocked == FALSE) rlvLockOutfit();
        isOutfitLocked = TRUE;
    }
    else {
        if (isOutfitLocked == TRUE) rlvUnlockOutfit();
        isOutfitLocked = FALSE;
    }
}

// Activate RLV settings
//
// This is designed to be called repetitively...

rlvActivate() {

    // This only runs if RLV is found and active

    if (!rlvStarted) { // This is the only reason rlvStarted exists

        llOwnerSay("Enabling RLV mode");

        lmSendConfig("RLVok",(string)RLVok); // is this needed or redundant?
        lmSendConfig("RLVsupport",(string)RLVsupport);

        lmRunRLVcmd("clearRLVcmd",""); // Initial clear after RLV activate

        // This generates a 350 link message (RLV_RESET)
        lmRLVreport(RLVok, rlvAPIversion, 0);
    }

    rlvRestoreRestritions();
    if (collapsed)
        lmInternalCommand("collapse", (string)collapsed, NULL_KEY);

    // If we get here - RLVok is already set
    rlvStarted = TRUE;
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
        keyID = llGetKey();
        myName = llGetScriptName();
        keyInit = TRUE;

#ifdef DEVELOPER_MODE
        myPath = "";
#endif
        cdInitializeSeq();
        //startRlvCheck();
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer start) {
        keyInit = FALSE; // we're not activating the full Init Stage sequence here

        // remove rlvHandle in order to set new one later
        llListenRemove(rlvHandle);
        rlvChannel == 0;
    }

    //----------------------------------------
    // ATTACH
    //----------------------------------------
    attach(key id) {

        // Let INIT_STAGE1 activate the RLV check..
        //if (keyInit == TRUE) if (id) startRlvCheck();
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string msg) {

        debugSay(4, "DEBUG-CHECKRLV", "Listener tripped on channel " + (string)channel);
        debugSay(4, "DEBUG-CHECKRLV", "Listener data = " + (string)msg);

        // Initial RLV Check results are being processed here
        //
        if (channel == rlvChannel) {

            // FIXME: We could deactivate, but RLV channel may be used for other things
            //cdListenerDeactivate(rlvChannel); // This prevents a secondary response
            if (RLVok == TRUE) return;

            debugSay(2, "DEBUG-CHECKRLV", "RLV Message received: " + msg);
            llOwnerSay("RLV Check completed in " + formatFloat(llGetTime(), 1) + " seconds");

            // Could be RestrainedLove or RestrainedLife - just
            // check enough letters to account for both
            if (llGetSubString(msg, 0, 10) == "RestrainedL") {
                rlvAPIversion = msg;
                debugSay(2, "DEBUG-CHECKRLV", "RLV Version: " + rlvAPIversion);
            }
#ifdef DEVELOPER_MODE
            else {
                debugSay(2, "DEBUG-CHECKRLV", "Unknown RLV response message: " + msg);
            }
#endif

            cdHaltTimer();
            RLVok = TRUE;
            RLVsupport = TRUE;

            rlvActivate();
        }
    }

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer sender, integer i, string data, key id) {

        // Parse link message header information
        split     = cdSplitArgs(data);
        script    = (string)split[0];
        remoteSeq = (i & 0xFFFF0000) >> 16;
        optHeader = (i & 0x00000C00) >> 10;
        code      =  i & 0x000003FF;
        split     = llDeleteSubList(split, 0, 0 + optHeader);

        //scaleMem();

        if (code == SEND_CONFIG) {
            name = (string)split[0];
            split = llDeleteSubList(split, 0, 0);
            value = (string)split[0];
            string c = llGetSubString(name, 0, 0);

            //if (llListFindList([ "R", "h", "k", "a", "c", "d", "w" ],(list)c) == NOT_FOUND) return;

                 if (name == "keyLocked")         {    keyLocked = (integer)value; }
#ifdef ADULT_MODE
            else if (name == "hardcore")          {     hardcore = (integer)value; rlvOutfitLock(); }
#endif
#ifdef EMERGENCY_TP
            else if (name == "autoTP")            {       autoTP = (integer)value; rlvSetIf("accepttp", !autoTP); }
#endif
            else if (name == "RLVok")             {        RLVok = (integer)value; }
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")        {   debugLevel = (integer)value; }
#endif
            else if (c == "c") {
                     if (name == "canSelfTP")     {    canSelfTP = (integer)value; rlvSetIf("tplm", canSelfTP); rlvSetIf("tploc", canSelfTP); }
                else if (name == "canDressSelf")  { canDressSelf = (integer)value; rlvOutfitLock(); }
                else if (name == "canFly")        {       canFly = (integer)value; rlvSetIf("fly", canFly); }
                else if (name == "collapsed")     {    collapsed = (integer)value; rlvOutfitLock(); }
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
            else if (name == "wearLock") { wearLock = (integer)value; rlvOutfitLock(); }
        }
        else if (code == RLV_RESET) {
            RLVok = (integer)split[0];

            if (RLVok == TRUE) {
                debugSay(4,"DEBUG-CHECKRLV","RLV Reset: Updating exceptions");
                lmInternalCommand("reloadExceptions", script, NULL_KEY);

                // We have to do this in order to set the wearLock (and keyLocked) properly
                // with their RLV components
                lmSetConfig("wearLock",(string)wearLock);
                lmSetConfig("keyLocked",(string)keyLocked);
            }

            if (keyInit) lmInitStage(INIT_STAGE2);
        }
        else if (code == INTERNAL_CMD) {
            string cmd = (string)split[0];
            split = llDeleteSubList(split, 0, 0);

            //debugSay(3,"DEBUG-CHECKRLV","Internal command triggered: " + cmd);

            if (cmd == "startRlvCheck") {
                startRlvCheck();
            }
            else if (cmd == "restoreRestrictions") {
                rlvRestoreRestritions();
            }
            else if (cmd == "addExceptions") {
                string exceptionKey = (string)split[0];

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

                // Add carrier to list of exceptions
                if (cdCarried()) {
                    if (llListFindList(exceptions, (list)carrierID) != NOT_FOUND) exceptions += carrierID;
                }

                // Dolly not allowed to be one of the exceptions
                //
                if ((i = llListFindList(exceptions, (list)dollID)) != NOT_FOUND)
                    llDeleteSubList(exceptions, i, i);

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

                // SELECTIVE clear: exceptions-related restrictions
                llOwnerSay("@clear=tplure:," +  // Clear exceptions only: and directly
                            "clear=accepttp:," +
                            "clear=sendim:," +
                            "clear=recvim:," +
                            "clear=recvchat:," +
                            "clear=recvemote:");

                string exceptionKey;
                i = llGetListLength(exceptions);
                while (i--) {
                    exceptionKey = (string)exceptions[i];

                    // This assumes that exceptions are a block...
                    // for now they are
                    llOwnerSay("@tplure:"    + (string)(exceptionKey) + "=add," + // Readd exceptions
                                "accepttp:"  + (string)(exceptionKey) + "=add," +
                                "sendim:"    + (string)(exceptionKey) + "=add," +
                                "recvim:"    + (string)(exceptionKey) + "=add," +
                                "recvchat:"  + (string)(exceptionKey) + "=add," +
                                "recvemote:" + (string)(exceptionKey) + "=add");
                }
            }
        }
        else if (code < 200) {
                 if (code == INIT_STAGE1) {

                startRlvCheck();  // once RLV is determined, this triggers STAGE2

            }
            else if (code == INIT_STAGE5) {

                keyInit = FALSE;

            }
            else if (code == CONFIG_REPORT) {

                cdConfigureReport();
            }
#ifdef DEVELOPER_MODE
            else if (code == MEM_REPORT) {
                float delay = (float)split[0];
                memReport(myName,delay);
            }
#endif
        }
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------

    // Timer fires for only one reason: RLVcheck timeout

    timer() {
        // RLVok shouldn't be TRUE here: timer would be shut off
        debugSay(2,"DEBUG-CHECKRLV","RLV check #" + (string)rlvCheck + " failed; retry...");

        if (rlvCheck > 0) {
            rlvCheckTry(); // try again
        }
        else {
            llOwnerSay("Did not detect an RLV capable viewer, RLV features disabled.");
            llOwnerSay("RLV Check took " + (string)(llGetTime()) + " seconds");
            cdHaltTimer();
            RLVok = FALSE;
            RLVsupport = FALSE;

            lmRLVreport(RLVok, "", FALSE); // report FALSE
            lmSendConfig("RLVsupport",(string)RLVsupport);
        }
    }
}

//========== CHECKRLV ==========
