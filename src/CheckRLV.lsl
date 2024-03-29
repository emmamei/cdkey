//========================================
// CheckRLV.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 24 November 2020

#include "include/GlobalDefines.lsl"
#include "include/Listeners.lsl"

#define NOT_IN_REGION ZERO_VECTOR
#define MAX_RLVCHECK_TRIES 5
#define RLV_TIMEOUT 10.0
#define UNSET -1

#define cdResetKey() llResetOtherScript("Start")
#define cdHaltTimer() llSetTimerEvent(0.0);
#define rlvSetIf(a,b) if ((b) == 1) { lmRunRlv((a)+"=y"); } else { lmRunRlv((a)+"=n"); }
#define rlvLockOutfit()   lmRunRlvAs("Dress", "unsharedwear=n,unsharedunwear=n,attachallthis:=n,detachallthis:=n");
#define rlvUnlockOutfit() lmRunRlvAs("Dress", "unsharedwear=y,unsharedunwear=y,attachallthis:=y,detachallthis:=y");

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
    if (!rlvChannel) rlvChannel = listenerGetChannel();
    rlvHandle = cdListenMine(rlvChannel);

    // Configure variables
    rlvCheck = MAX_RLVCHECK_TRIES;
    rlvOk = UNSET;
    rlvSupport = UNSET;
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
// case that the timer expired. Thus, rlvOk should be UNSET.
// If rlvOk was TRUE, then no more check tries are needed.
// If rlvOk is FALSE, then there should be no more tries to make.

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

    debugSay(4, "DEBUG-CHECKRLV", "Testing for RLV...");

    // Switch to older command if newer one fails
    if (rlvCheck > 2) llOwnerSay("@versionnew=" + (string)rlvChannel);
    else              llOwnerSay("@version="    + (string)rlvChannel);
}

rlvRestoreRestrictions() {
    if (rlvOk != TRUE) return;

    string rlvBase;

    // This adjusts the default "base" RLV based on Dolly's settings...
    //
    // In this, rlvDefaultBaseCmd is much more flexible than the other defaults
    //
    if (canRejectTP) rlvBase += "accepttp=y,";       else rlvBase += "accepttp=n,";
    if (canSelfTP)   rlvBase += "tplm=y,tploc=y,";   else rlvBase += "tplm=n,tploc=n,";
    if (canFly)      rlvBase += "fly=y,";            else rlvBase += "fly=n,";

    // rlvBase could theoretically be nil
    if (rlvBase != "")
        lmRunRlvAs("Base", rlvBase);

    lmSendConfig("rlvDefaultBaseCmd",(string)rlvBase); // save the defaults

    if (keyLocked) lmRunRlvAs("Base","detach=n");
    else lmRunRlvAs("Base","detach=y");

    manageOutfitLock();
}

// Lock the outfit on the wearer
//
manageOutfitLock() {

    // Lock the current outfit if one of these is true:
    //
    //    * Dolly cannot dress themselves
    //    * Dolly is in hardcore mode
    //    * Dolly is collapsed
    //    * Dolly is in "wear lock"
    //
    // This means Dolly is forbidden to change the current outfit
    //
    if (!canDressSelf || collapsed || (wearLockExpire > 0)) {
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

        lmSendConfig("rlvOk",(string)rlvOk); // is this needed or redundant?
        lmSendConfig("rlvSupport",(string)rlvSupport);

        lmRlvInternalCmd("rlvClearCmd",""); // Initial clear after RLV activate

        // This generates a 350 link message (RLV_RESET)
        lmRlvReport(rlvOk, rlvAPIversion, 0);
    }

    rlvRestoreRestrictions();
    if (collapsed)
        lmInternalCommand("collapse", (string)collapsed, NULL_KEY);

    // If we get here - rlvOk is already set
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
    listen(integer listenChannel, string listenName, key listenID, string listenMessage) {

        debugSay(4, "DEBUG-CHECKRLV", "Listener tripped on channel " + (string)listenChannel);
        debugSay(4, "DEBUG-CHECKRLV", "Listener data = " + (string)listenMessage);

        // Initial RLV Check results are being processed here
        //
        if (listenChannel == rlvChannel) {

            // This is a shortcut: if rlvOk is true, then we don't need to check for
            // validation... right? Isn't this almost the same as above?
            if (rlvOk == TRUE) return;

            debugSay(2, "DEBUG-CHECKRLV", "RLV Message received: " + listenMessage);
            llOwnerSay("RLV Check completed in " + formatFloat(llGetTime(), 1) + " seconds");

            // Could be RestrainedLove or RestrainedLife - just
            // check enough letters to account for both
            if (llGetSubString(listenMessage, 0, 10) == "RestrainedL") {
                rlvAPIversion = listenMessage;
                debugSay(2, "DEBUG-CHECKRLV", "RLV Version: " + rlvAPIversion);
            }
#ifdef DEVELOPER_MODE
            else {
                debugSay(2, "DEBUG-CHECKRLV", "Unknown RLV response message: " + listenMessage);
            }
#endif

            cdHaltTimer(); // we succeeded; no more retries
            rlvOk = TRUE;
            rlvSupport = TRUE;

            rlvActivate();
        }
    }

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer lmSource, integer lmInteger, string lmData, key lmID) {

        parseLinkHeader(lmData,lmInteger);

        if (code == SEND_CONFIG) {
            name = (string)split[0];
            split = llDeleteSubList(split, 0, 0);
            value = (string)split[0];
            string c = llGetSubString(name, 0, 0);

                 if (name == "keyLocked")         {    keyLocked = (integer)value; }
            else if (name == "rlvOk")             {        rlvOk = (integer)value; }
#ifdef ADULT_MODE
            else if (name == "hardcore")          {     hardcore = (integer)value; manageOutfitLock(); }
#endif
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")        {   debugLevel = (integer)value; }
#endif
            else if (c == "c") {
                     if (name == "canSelfTP")     {    canSelfTP = (integer)value; rlvSetIf("tplm", canSelfTP); rlvSetIf("tploc", canSelfTP); }
                else if (name == "canRejectTP")   {  canRejectTP = (integer)value; rlvSetIf("accepttp", canRejectTP); }
                else if (name == "canFly")        {       canFly = (integer)value; rlvSetIf("fly", canFly); }
                else if (name == "canDressSelf")  { canDressSelf = (integer)value; manageOutfitLock(); }
                else if (name == "collapsed")     {    collapsed = (integer)value; manageOutfitLock(); }
                else if (name == "controllers") {
                    if (split == [""]) controllerList = [];
                    else controllerList = split;
                }
                else if (name == "chatChannel") { chatChannel = (integer)value; }
            }

            else if (name == "wearLockExpire") {
                wearLockExpire = (integer)value;
                manageOutfitLock();
            }
        }
        else if (code == RLV_RESET) {
            rlvOk = (integer)split[0];

            if (rlvOk == TRUE) {
                debugSay(4,"DEBUG-CHECKRLV","RLV Reset: Updating exceptions");
                lmInternalCommand("reloadExceptions", script, NULL_KEY);

                // We have to do this in order to set the wearLock (and keyLocked) properly
                // with their RLV components
                lmInternalCommand("wearLock",(string)(wearLockExpire > 0), lmID);
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
                rlvRestoreRestrictions();
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
                // VERY IMPORTANT: DO NOT CALL lmRunRlv OR lmRunRlvAs!! THIS WILL SET UP
                // A SCRIPT LOOP THAT WILL BE VERY HARD TO ESCAPE.

                // Exempt builtin or user specified controllers from TP restictions
                if (rlvOk == FALSE) return;

                list exceptions = cdList2ListStrided(controllerList, 0, -1, 2);
                if (exceptions == []) return;

                integer i;

                // Add carrier to list of exceptions
                if (cdCarried()) {
                    if (cdFindInList(exceptions,carrierID)) exceptions += carrierID;
                }

                // Dolly not allowed to be one of the exceptions
                //
                if (~(i = llListFindList(exceptions, (list)dollID)))
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
        // rlvOk shouldn't be TRUE here: timer would be shut off
        debugSay(2,"DEBUG-CHECKRLV","RLV check #" + (string)rlvCheck + " failed; retry...");

        if (rlvCheck > 0) {
            rlvCheckTry(); // try again
        }
        else {
            llOwnerSay("Did not detect an RLV capable viewer, RLV features disabled.");
            llOwnerSay("RLV Check took " + (string)(llGetTime()) + " seconds");
            cdHaltTimer(); // Failed too many times
            rlvOk = FALSE;
            rlvSupport = FALSE;

            lmRlvReport(rlvOk, "", FALSE); // report FALSE
            lmSendConfig("rlvSupport",(string)rlvSupport);
        }
    }
}

//========== CHECKRLV ==========
