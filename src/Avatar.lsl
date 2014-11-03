//========================================
// Avatar.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 27 October 2014

#include "include/GlobalDefines.lsl"
#include "include/Json.lsl"

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

key carrierID = NULL_KEY;

// Could set allControls to -1 for quick full bit set - 
// but that would set fields with undefined values: this is more
// accurate
#define ALL_CONTROLS (CONTROL_FWD|CONTROL_BACK|CONTROL_LEFT|CONTROL_RIGHT|CONTROL_ROT_LEFT|CONTROL_ROT_RIGHT|CONTROL_UP|CONTROL_DOWN|CONTROL_LBUTTON|CONTROL_ML_LBUTTON)
integer allControls = ALL_CONTROLS;

key rlvTPrequest;
key requestLoadData;
key keyAnimationID;
key lastAttachedID;

list rlvSources;
list rlvStatus;

float rlvTimer;

float baseWindRate;
float afkSlowWalkSpeed = 5;
float animRefreshRate = 8.0;

float nextRLVcheck;
float nextAnimRefresh;

vector carrierPos;
vector lockPos;

string barefeet;
string carrierName;
string keyAnimation;

#ifdef DEVELOPER_MODE
string myPath;
#endif

string pronounHerDoll = "Her";
string pronounSheDoll = "She";
string rlvAPIversion;
string redirchan;
string userBaseRLVcmd;

integer afk;
integer isAnimated;
integer hasCarrier;
//integer isPosed; (use cdPosed)
//integer isSelfPosed; (use cdSelfPosed)

integer carryMoved;
integer rlvChannel;
integer clearAnim = 1;
integer collapsed;
integer confgured;
integer dialogChannel;
integer haveControls;
integer rlvHandle;
integer locked;
#ifdef SIM_FRIENDLY
integer lowScriptMode;
#endif
integer poseSilence;
integer refreshControls;
integer RLVck = 0;
integer RLVok = UNSET;
integer RLVstarted;
integer startup = 1;
integer targetHandle;
integer ticks;
integer wearLock;
integer newAttach = 1;
integer creatorNoteDone;
integer chatChannel = 75;

//integer dollState;
//#define cdXorSet(a,b,c)         a = ((a ^ (a & b)) | (c))
//#define cdXorSetDollState(a,b)  cdXorSet(dollState,a,b)
//#define cdSetDollState(a)       cdXorSetDollState(a,a)
//#define cdUnsetDollState(a)     cdXorSetDollState(a,0)
//#define cdSetDollStateIf(a,b)   cdXorSet(dollState,a,a*((b)!=0))
//#define DOLL_AFK                0x01
//#define DOLL_ANIMATED           0x02
//#define DOLL_CARRIED            0x04
//#define DOLL_COLLAPSED          0x08
//#define DOLL_POSED              0x10
//#define DOLL_POSER_IS_SELF      0x20

//========================================
// FUNCTIONS
//========================================
key animStart(string animation) {
    if ((llGetPermissionsKey() != dollID) || ((llGetPermissions() & PERMISSION_TRIGGER_ANIMATION) == 0)) return NULL_KEY;

    while (llGetListLength(llGetAnimationList(dollID))) llStopAnimation(llList2Key(llGetAnimationList(dollID), 0));

    integer i; key animID = llGetInventoryKey(animation);
    list oldList = llGetAnimationList(dollID);
    llStartAnimation(animation);
    list newList = llGetAnimationList(dollID);

    while (llGetListLength(oldList)) {
        key animKey = llList2Key(oldList, 0); integer index;
        while ((index = llListFindList(newList, [ animKey ])) != -1) newList = llDeleteSubList(newList, index, index);

        oldList = llDeleteSubList(oldList, 0, 0);
    }

    if (animID) return animID;
    else if (llGetListLength(newList) == 1) return llList2Key(newList, 0);
    else return NULL_KEY;
}

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
        llSetTimerEvent(60.0);
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

#ifdef DEVELOPER_MODE
        // if Doll is one of the developers... dont lock:
        // prevents inadvertent lock-in during development

        cdSayQuietly("Developer Key not locked");

        baseRLV += "attachallthis_except:" + myPath + "=add,detachallthis_except:" + myPath + "=add,";
#endif
    }

#ifndef DEVELOPER_MODE
    key mainCreator;
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
    else if (RLVok && !RLVstarted) llSay(DEBUG_CHANNEL, "Backup protection mechanism activated not locking on creator");
#endif

    if (!RLVstarted) {
        if (RLVok) llOwnerSay("Enabling RLV mode");

        cdListenerDeactivate(rlvHandle);
        lmSendConfig("RLVok",(string)RLVok); // is this needed or redundant?
        lmRLVreport(RLVok, rlvAPIversion, 0);
    }

    if (userBaseRLVcmd != "") lmRunRLVas("UserBase", userBaseRLVcmd);

    //lmRunRLVas("Core", baseRLV + restrictionList + "sendchannel:" + (string)chatChannel + "=rem");
    lmRunRLVas("Core", baseRLV + "sendchannel:" + (string)chatChannel + "=rem");

    // If we get here - RLVok is already set
    //RLVstarted = (RLVstarted | RLVok);
    RLVstarted = 1;

#ifndef DEVELOPER_MODE
    if (mainCreator == dollID) lmRunRLVas("Base", "clear=unshared,clear=attachallthis");
#endif
}

ifPermissions() {

    debugSay(2,"DEBUG-COLLAPSE","Looking at permissions");

    // Don't do anything unless attached
    if (llGetAttached()) {
        key grantorID = llGetPermissionsKey();
        integer permMask = llGetPermissions();

        debugSay(2,"DEBUG-COLLAPSE","Permission processing begun");

        // If permissions granted to someone other than Dolly,
        // start over...
        if (grantorID != NULL_KEY && grantorID != dollID) {
            cdResetKey();
        }

        if ((permMask & PERMISSION_MASK) != PERMISSION_MASK) {
            // FIXME: llRequestPermissions runs this function: means a double run if PERMISSION_MASK is off-kilter
            llRequestPermissions(dollID, PERMISSION_MASK);
            return;
            }

        // only way to get here is grantorID is dollID or NULL_KEY
        if (grantorID == dollID) {

            //----------------------------------------
            // PERMISSION_TRIGGER_ANIMATION

            if ((permMask & PERMISSION_TRIGGER_ANIMATION) != 0) {

                debugSay(2,"DEBUG-COLLAPSE","Animation trigger being processed");

                list animList = llGetAnimationList(dollID);
                key curAnim = llList2Key(animList, 0);
                integer animCount = llGetListLength(animList);
                integer i = animCount;
                key animKey;

                if (clearAnim) {
                    keyAnimation = "";
                    lmSendConfig("keyAnimationID", (string)(keyAnimationID = NULL_KEY));

                    i++;
                    for (; i; i--) {
                        animKey = llList2Key(animList, i);
                        debugSay(2,"DEBUG-AVATAR",">Stopping animation #" + (string)i + ": " + (string)animKey);
                        if (animKey) llStopAnimation(animKey);
                    }

                    llStartAnimation("Stand");
                    animRefreshRate = 0.0;
                    clearAnim = 0;
                    cdLockMeisterCmd("booton");
                } else if (!cdNoAnim()) {
                    cdLockMeisterCmd("bootoff");

                    animKey = keyAnimationID;

                    if (animKey == NULL_KEY) animKey = llGetInventoryKey(keyAnimation);

                    if (animKey) {
                        key animKeyI;

                        while ((animList = llGetAnimationList(dollID)) != [ animKey ]) {
                            //animCount = llGetListLength(animList);

                            i++;
                            for (; i; i--) {

                                animKeyI = llList2Key(animList, i);
                                debugSay(2,"DEBUG-AVATAR","Stopping animation #" + (string)i + ": " + (string)animKeyI);
                                if (animKeyI != animKey) llStopAnimation(animKeyI);
                            }

                            llStartAnimation(keyAnimation);
                        }
                    }
                    else animKey = animStart(keyAnimation);

                    if (keyAnimationID == NULL_KEY) {
                        if (animKey != NULL_KEY) lmSendConfig("keyAnimationID", (string)(keyAnimationID = animKey));
                        animRefreshRate = 4.0;
                    }
                    else {
                        debugSay(7, "DEBUG", "animID=" + (string)keyAnimationID + " curAnim=" + (string)curAnim + " animRefreshRate=" + (string)animRefreshRate);

                        if (curAnim == keyAnimationID) {
                            animRefreshRate += (1.0/llGetRegionFPS());                  // +1 Frame
                            if (animRefreshRate > 30.0) animRefreshRate = 30.0;             // 30 Second limit
                        }
                        else {
                            animRefreshRate /= 2.0;                                     // -50%
                            if (animRefreshRate < 0.022) animRefreshRate = 0.022;           // Limit once per frame
                        }
                    }
                }

                if (animRefreshRate) nextAnimRefresh = llGetTime() + animRefreshRate;
                llSetTimerEvent(nextAnimRefresh);
            }

            //----------------------------------------
            // PERMISSION_TAKE_CONTROLS

            if (permMask & PERMISSION_TAKE_CONTROLS) {

                debugSay(2,"DEBUG-COLLAPSE","Take Controls being processed");
                debugSay(2,"DEBUG-COLLAPSE","haveControls = " + (string)haveControls + "; collapsed = " + (string)collapsed);
                //debugSay(2,"DEBUG-COLLAPSE","afk = " + (string)afk);
                //debugSay(2,"DEBUG-COLLAPSE","cdSelfPosed() = " + (string)cdSelfPosed());
                //debugSay(2,"DEBUG-COLLAPSE","cdPosed() = " + (string)cdPosed());

                if (!haveControls && (afk || collapsed || cdSelfPosed())) {
                    // No reason for us to be locking the controls and we do not already have them
                    // This just serves to get us treated as a vehicle to run on NoScript land
                    llTakeControls(ALL_CONTROLS, FALSE, TRUE);
                }
                else if (collapsed || cdPosed()) {
                    // When collapsed or posed the doll should not be able to move at all; so the key will
                    // accept their controls, but no need to pass on: ignore all input.
                    llTakeControls(ALL_CONTROLS, TRUE, FALSE);
                    haveControls = 1;
                }
                else if (afk) {
                    // To slow movement during AFK, we do not want to lock the doll's controls completely; we
                    // want to instead respond to the input, so we need ACCEPT=TRUE, PASS_ON=TRUE
                    llTakeControls(ALL_CONTROLS, TRUE, TRUE);
                    haveControls = 1;
                }
                else if (haveControls) {
                    // We don't need to grab the dolls controls, we already have them.
                    //
                    // I (Silky) have grounds to suspect there may be a Second Life bug where taking controls
                    // and then trying to let go to do ACCEPT=FALSE, PASS_ON=TRUE may not always
                    // work reliably to release and regrab

                    refreshControls = 1;

                    if ((llGetParcelFlags(llGetPos()) & PARCEL_FLAG_ALLOW_SCRIPTS) != 0) {

                        // We do not want to release the controls if the land is noScript; doing so
                        // would effectively shut down the key until one entered Script-enabled
                        // land again

                        llReleaseControls();

                        haveControls = 0;
                        refreshControls = 0;

                        // This code is contained in the run_event - so this function
                        // repeats the function we are in.
                        llRequestPermissions(dollID, PERMISSION_MASK);  // Releasing controls drops the permissions
                                                                        // get them back.
                    }
                    else llTakeControls(ALL_CONTROLS, FALSE, TRUE);
                }
            }

            //----------------------------------------
            // Moving to Target

            if (collapsed || cdPosed()) {

                if (lockPos == ZERO_VECTOR) lmSendConfig("lockPos", (string)(lockPos = llGetPos()));

                llTargetRemove(targetHandle);
                targetHandle = llTarget(lockPos, 1.0);
                llMoveToTarget(lockPos, 0.7);
            }
            else if (hasCarrier) {

                if (lockPos) lmSendConfig("lockPos", (string)(lockPos = ZERO_VECTOR));

                // Stop moving to Target
                llTargetRemove(targetHandle);
                llStopMoveToTarget();

                // Re-enable with new target
                vector carrierPos = llList2Vector(llGetObjectDetails(carrierID, [ OBJECT_POS ]), 0);

                if (carrierPos) targetHandle = llTarget(carrierPos, CARRY_RANGE);
            }
            else {
                // Stop moving to Target
                llTargetRemove(targetHandle);
                llStopMoveToTarget();
            }
        }
    }
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

        llRequestPermissions(dollID, PERMISSION_MASK);
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer start) {

        rlvTimer = llGetTime();
        RLVck = 0;
        RLVok = -1;
        rlvAPIversion = "";
        RLVstarted = 0;

#ifdef DEVELOPER_MODE
        myPath = "";
#endif

        llStopMoveToTarget();
        llTargetRemove(targetHandle);

        ifPermissions();
    }

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    changed(integer change) {
        if (change & (CHANGED_REGION | CHANGED_TELEPORT)) {
            llStopMoveToTarget();
            llTargetRemove(targetHandle);

            ifPermissions();
        }

        if (change & CHANGED_OWNER) {
            llStopMoveToTarget();
            llTargetRemove(targetHandle);

            llResetScript();
        }
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer chan, string name, key id, string msg) {

        debugSay(2, "DEBUG-AVATAR", "Listener tripped....");
        if (chan == rlvChannel) {
            debugSay(2, "DEBUG-RLV", "RLV Message received: " + msg);

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
#ifdef DEVELOPER_MODE
            else {
                debugSay(2, "DEBUG-RLV", "RLV Key Path: " + msg);
                myPath = msg;

                nextRLVcheck = 0.0;
                RLVok = 1;
                lmSendConfig("RLVok",(string)RLVok); // is this needed or redundant?
                debugSay(2, "DEBUG-RLV", "RLV set to " + (string)RLVok + " and message sent on link channel");
                debugSay(2,"DEBUG-RLV","RLV check completed in " + formatFloat((llGetTime() - rlvTimer),1) + "s");
                lmRLVreport(RLVok, rlvAPIversion, 0);
                activateRLV();
            }
#endif
        }
    }

    //----------------------------------------
    // ATTACH
    //----------------------------------------
    attach(key id) {
        if (id == NULL_KEY && !detachable && !locked) {
            // Undetachable key with controller is detached while RLV lock
            // is not available inform any key controllers.
            // We send no message if the key is RLV locked as RLV will reattach
            // automatically this prevents neusance messages when defaultwear is
            // permitted.
            // Q: Should that be changed? Not sure the message serves much purpose with *verified* RLV and known lock.
            lmSendToController(dollName + " has bypassed the key attachment lock and removed " + llToLower(pronounHerDoll) + " key. Appropriate authorities have been notified of this breach of security.");
        }

        locked = 0;

        llStopMoveToTarget();
        llTargetRemove(targetHandle);

        if (id) {
            ifPermissions();
            doCheckRLV();
        }

        newAttach = (lastAttachedID != dollID);
        lastAttachedID = id;
    }

    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer sender, integer i, string data, key id) {

        // Parse link message header information
        list split        =     cdSplitArgs(data);
        string script     =     cdListElement(split, 0);
        integer remoteSeq =     (i & 0xFFFF0000) >> 16;
        integer optHeader =     (i & 0x00000C00) >> 10;
        integer code      =      i & 0x000003FF;
        split             =     llDeleteSubList(split, 0, 0 + optHeader);

        scaleMem();

        if (code == 110) {
            configured = 1;
            //doCheckRLV();

            ifPermissions();
        }
        else if (code == 135) {
            float delay = llList2Float(split, 0);
            memReport(cdMyScriptName(),delay);
        } else

        cdConfigReport();

        else if (code == 300) {
            string name = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);
            string value = llList2String(split, 0);

// CHANGED_OTHER bit used to indicate changes of RLV status that
// would not normally be reflected as a doll state.
//#define CHANGED_OTHER 0x80000000

            //integer oldState = dollState;              // Used to determine if a refresh of RLV state is needed

            if (name == "autoTP")                        autoTP = (integer)value;
            else if (name == "carrierID") {
                carrierID = (key)value;
                hasCarrier = cdCarried();
            }
            else if (name == "afk")                         afk = (integer)value;
            else if (name == "canFly")                   canFly = (integer)value;
            else if (name == "canSit")                   canSit = (integer)value;
            else if (name == "canStand")               canStand = (integer)value;
            else if (name == "canDressSelf")       canDressSelf = (integer)value;
            else if (name == "collapsed") {
                    collapsed = (integer)value;

                    if (collapsed) lmSendConfig("keyAnimation", (keyAnimation = ANIMATION_COLLAPSED));
                    else if (cdCollapsedAnim()) lmSendConfig("keyAnimation", (keyAnimation = ""));

                    debugSay(2,"DEBUG-COLLAPSE","Asking for permissions");
                    ifPermissions();
            }
            else if (name == "tpLureOnly")           tpLureOnly = (integer)value;
            else if (name == "poseSilence")         poseSilence = (integer)value;
            else if (name == "userBaseRLVcmd")   userBaseRLVcmd = value;
            else if (name == "keyAnimation") {
                string oldanim = keyAnimation;
                keyAnimation = value;

                // Purpose of this code is unknown: it appears
                // to de-animate a collapsed dolly when the animation
                // is set to collapse... say What?
                //
                //if (cdCollapsedAnim() && collapsed) {
                //    lmSendConfig("keyAnimation", "");
                //    ifPermissions();
                //}

                isAnimated = (keyAnimation != "");

                if cdNoAnim() clearAnim = 1;
                else {
                    if ((oldanim != "") && (keyAnimation != oldanim)) {    // Issue #139 Moving directly from one animation to another make certain keyAnimationID does not holdover to the new animation.
                        keyAnimationID = NULL_KEY;
                    }
                    lmSendConfig("keyAnimationID", (string)(keyAnimationID = animStart(keyAnimation)));
                }
            }
            else if (name == "poserID")                 poserID = (key)value;
            else {
                // These are segregated so they won't execute the ifPermissions() at the
                // end... why is that?

                     if (name == "detachable")               detachable = (integer)value;
#ifdef DEVELOPER_MODE
                else if (name == "debugLevel")               debugLevel = (integer)value;
#endif
#ifdef SIM_FRIENDLY
                else if (name == "lowScriptMode")         lowScriptMode = (integer)value;
#endif
                else if (name == "quiet")                         quiet = (integer)value;
                else if (name == "chatChannel")             chatChannel = (integer)value;
                else if (name == "canPose")                     canPose = (integer)value;
                else if (name == "barefeet")                   barefeet = value;
                else if (name == "wearLock")                   wearLock = (integer)value;
                else if (name == "dollType")                   dollType = value;
                else if (name == "controllers")             controllers = split;
                else if (name == "pronounHerDoll")       pronounHerDoll = value;
                else if (name == "pronounSheDoll")       pronounSheDoll = value;
                else if (name == "dialogChannel") {
                    dialogChannel = (integer)value;

                    llListenRemove(rlvHandle);
                    // Calculate positive (RLV compatible) rlvChannel
                    rlvChannel = ~dialogChannel + 1;
                    rlvHandle = llListen(rlvChannel, "", "", "");
                    cdListenerDeactivate(rlvHandle);

                    // as soon as rlvHandle is valid - we can check for RLV
                    if (RLVok == UNSET) checkRLV();
                }
                else if (name == "keyAnimationID") {
                    keyAnimationID = (key)value;
                }

                return;
            }

            //if (RLVstarted) cdLoadData(RLV_NC, RLV_BASE_RESTRICTIONS);
            ifPermissions();
        }
        else if (code == 305) {
            string cmd = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "detach") {
                if (RLVok || RLVstarted) llOwnerSay("@clear,detachme=force");
                else llDetachFromAvatar();
            }
            else if (cmd == "doCheckRLV") {
                doCheckRLV();
                lmSendConfig("RLVok",(string)RLVok);
            }
            else if (cmd == "TP") {
                string lm = llList2String(split, 0);
                llRegionSayTo(id, 0, "Teleporting dolly " + dollName + " to  landmark " + lm + ".");
                rlvTPrequest = llRequestInventoryData(lm);
            }
            else if (cmd == "wearLock") {
                // WearLockExpire is set by Main.lsl...

                lmSendConfig("wearLock", (string)(wearLock = llList2Integer(split, 0)));
            }
        }
        else if (code == 500) {
            string choice = llList2String(split, 0);
            string name = llList2String(split, 1);

            string subchoice = llGetSubString(choice,0,4);
            integer dollIsPoseable = ((!cdIsDoll(id) && canPose) || cdSelfPosed());
            integer dollNotPosed = (keyAnimation == "");
            //debugSay(5,"500","dollIsPoseable = " + (string)dollIsPoseable);
            //debugSay(5,"500","dollNotPosed = " + (string)dollNotPosed);
            //debugSay(5,"500","choice = " + choice);

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
            else if (choice == "RLV On") {
                doCheckRLV();
                lmSendConfig("RLVok",(string)RLVok);
            }
#ifdef ADULT_MODE
            else if (subchoice == "Strip") {
                if (choice == "Strip...") {
                    list buttons = llListSort(["Strip Top", "Strip Bra", "Strip Bottom", "Strip Panties", "Strip Shoes", "Strip ALL"], 1, 1);
                    cdDialogListen();
                    llDialog(id, "Take off:", dialogSort(buttons + MAIN), dialogChannel); // Do strip menu
                    return;
                }

                string part = llGetSubString(choice,6,-1);
                list parts = [
                    "Top",      RLV_STRIP_TOP,
                    "Bra",      RLV_STRIP_BRA,
                    "Bottom",   RLV_STRIP_BOTTOM,
                    "Panties",  RLV_STRIP_PANTIES,
                    "Shoes",    RLV_STRIP_SHOES
                ];
                integer i;

                // This allows an avi to have "barefeet" and "shoes" simultaneously:
                // removing shoes puts on barefeet
                if ((part == "Shoes") || (part == "ALL")) {
                    if (barefeet != "") lmRunRLVas("Dress","attachallover:" + barefeet + "=force");
                }
            }
#endif
            else if (choice == "Carry") {
                if (!collapsed && !cdIsDoll(id) && (cdControllerCount() || cdIsController(id))) {
                    lmSendConfig("carrierID", (string)(carrierID = id));
                    lmSendConfig("carrierName", (carrierName = name));

                    if (!quiet) llSay(0, "The doll " + dollName + " has been picked up by " + carrierName);
                    else {
                        llOwnerSay("You have been picked up by " + carrierName);
                        llRegionSayTo(carrierID, 0, "You have picked up the doll " + dollName);
                    }
                }
            }
            else if (choice == "Uncarry") {
                if (cdIsCarrier(id)) {
                    if (quiet) lmSendToAgent("You were carrying " + dollName + " and have now placed them down.", carrierID);
                    else llSay(0, "Dolly " + dollName + " has been placed down by " + carrierName);
                    lmSendConfig("carrierID", (string)(carrierID = NULL_KEY));
                    lmSendConfig("carrierName", (carrierName = ""));
                }
            }

            // Unpose: remove animation and poser
            else if (dollIsPoseable && choice == "Unpose") {
                lmSendConfig("keyAnimation", (string)(keyAnimation = ""));
                lmSendConfig("poserID", (string)(poserID = NULL_KEY));
            }

            // choice is Inventory Animation Item
            else if ((keyAnimation == "" || dollIsPoseable) && llGetInventoryType(choice) == 20) {
                lmSendConfig("keyAnimation", (string)(keyAnimation = choice));
                lmSendConfig("poserID", (string)(poserID = id));
            }

            // choice is Inventory Animation Item with prefix
            else if ((keyAnimation == "" || dollIsPoseable) && llGetInventoryType(llGetSubString(choice, 2, -1)) == 20) {
                lmSendConfig("keyAnimation", (string)(keyAnimation = llGetSubString(choice, 2, -1)));
                lmSendConfig("poserID", (string)(poserID = id));
            }

//            else if (keyAnimation == "" || ((!cdIsDoll(id) && canPose) || cdSelfPosed())) {
//                if (((!cdIsDoll(id) && canPose) || cdSelfPosed()) && choice == "Unpose") {
//                    lmSendConfig("keyAnimation", (string)(keyAnimation = ""));
//                    lmSendConfig("poserID", (string)(poserID = NULL_KEY));
//                }
//                else {
//                    string anim = "";
//
//                    if (llGetInventoryType(choice) == 20) anim = choice;
//                    else if (llGetInventoryType(llGetSubString(choice, 2, -1)) == 20) anim = llGetSubString(choice, 2, -1);
//
//                    if (anim != "") {
//                        lmSendConfig("keyAnimation", (string)(keyAnimation = anim));
//                        lmSendConfig("poserID", (string)(poserID = id));
//                    }
//                }
//            }

            // choice is menu of Poses
            else if ((keyAnimation == "" || dollIsPoseable) && subchoice == "Poses") {
                poserID = id;

                integer page = (integer)llStringTrim(llGetSubString(choice, 5, -1), STRING_TRIM);
                integer isController;
                integer isDoll;

                isController = cdIsController(id);
                isDoll = cdIsDoll(id);

                if (!page) {
                    page = 1;
                    if (!isDoll) llOwnerSay(cdUserProfile(id) + " is looking at your poses menu.");
                }

                integer poseCount = llGetInventoryNumber(20);
                list poseList; integer i = poseCount;
                string poseName;
                string prefix;

                for (; i; i--) {
                    poseName = llGetInventoryName(20, i);
                    prefix = cdGetFirstChar(poseName);

                    // Is the pose a pose we can show in the menu?
                    //
                    if (poseName != ANIMATION_COLLAPSED) {
                        if (prefix != "!" && prefix != ".") prefix = "";

                        if (isDoll ||
                           (isController && prefix == "!") ||
                           (prefix == "")) {

                            // add a star to active animation
                            if (poseName != keyAnimation) poseList += poseName;
                            else poseList += [ "* " + poseName ];
                        }
                    }
                }

                poseCount = llGetListLength(poseList);
                integer pages = 1;

                if (poseCount > 11) {
                    pages = llCeil((float)poseCount / 9.0);
                    poseList = llList2List(poseList, (page - 1) * 9, page * 9 - 1);

                    integer prevPage = page - 1;
                    integer nextPage = page + 1;

                    if (prevPage == 0) prevPage = 1;
                    if (nextPage > pages) nextPage = pages;

                    poseList = [ "Poses " + (string)prevPage, "Poses " + (string)nextPage, MAIN ] + poseList;
                }
                else poseList = dialogSort(poseList + [ MAIN ]);

                cdDialogListen();
                llDialog(id, "Select the pose to put Dolly into", poseList, dialogChannel);
            }
            ifPermissions();
        }
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------

    // Timer fires for three reasons:
    //
    //    1. RLV check timeout
    //    2. Animation refresh
    //    3. ifPermissions check
    //
    // Is it really necessary to do ifPermissions repeatedly?

    timer() {
        // IF RLV is ok we don't have to check it do we?

        //debugSay(2,"DEBUG-AVATAR","timer tripped...");
        if (RLVok == UNSET) {
            // this makes sure that enough time has elapsed - and prevents
            // the check from being missed...

            debugSay(2,"DEBUG-RLV","nextRLVcheck = " + (string)nextRLVcheck);
            if (nextRLVcheck < llGetTime()) {
                debugSay(2,"DEBUG-RLV","performing next try of RLVcheck...");
                checkRLV();
            }

            lmSendConfig("RLVok",(string)RLVok);
        }

        ifPermissions();

#ifdef PREDICTIVE_TIMER
        // This takes the next possible RLV check and animation refresh,
        // computes the time until that happens, then calculates the miniumum...
        // This is the amount of time until the next thing happens - and adds one
        // frame's worth of time.

        list possibleEvents =       [60.0];
        float t = llGetTime();
        if (nextRLVcheck > 0.0)     possibleEvents += nextRLVcheck - t;
        if (nextAnimRefresh > 0.0)  possibleEvents += nextAnimRefresh - t;
        llSetTimerEvent(llListStatistics(LIST_STAT_MIN,possibleEvents) + 0.022); // Not 0
#endif
    }

    //----------------------------------------
    // AT TARGET
    //----------------------------------------
    at_target(integer num, vector target, vector me) {
        // Clear old targets to ensure there is only one
        llTargetRemove(targetHandle);
        llStopMoveToTarget();

        if (hasCarrier) {
            if (keyAnimation == "") {
                // Get updated position and set target
                carrierPos = llList2Vector(llGetObjectDetails(carrierID, [OBJECT_POS]), 0);
                targetHandle = llTarget(carrierPos, CARRY_RANGE);
            }
            else {
                if (lockPos) lockPos = llGetPos();
                targetHandle = llTarget(lockPos, 0.5);
            }
        }

        if (carryMoved) {
            vector pointTo = target - llGetPos();
            float  turnAngle = llAtan2(pointTo.x, pointTo.y);

            lmRunRLV("setrot:" + (string)(turnAngle) + "=force");
            carryMoved = 0;
        }
    }

    //----------------------------------------
    // NOT AT TARGET
    //----------------------------------------
    not_at_target() {

        if (cdNoAnim() && cdCarried()) {
            vector newCarrierPos = llList2Vector(llGetObjectDetails(carrierID,[OBJECT_POS]),0);
            llStopMoveToTarget();

            if (carrierPos != newCarrierPos) {
                llTargetRemove(targetHandle);
                carrierPos = newCarrierPos;
                targetHandle = llTarget(carrierPos, CARRY_RANGE);
            }
            if (carrierPos) {
                llMoveToTarget(carrierPos, 0.7);
                carryMoved = 1;
            }
        }
        else if (!cdNoAnim()) {
            llMoveToTarget(lockPos, 0.7);
        }
    }

#ifdef SLOW_WALK
    //----------------------------------------
    // CONTROL
    //----------------------------------------

    // Control event allows us to respond to control inputs made by the
    // avatar which has granted the script PERMISSION_TAKE_CONTROLS.
    //
    // In our case it is used here with physics calls to slow movement for
    // a doll when in AFK mode.  This will work regardless of whether the
    // doll is in RLV or not though RLV is a bonus as it allows preventing
    // running.

    control(key id, integer level, integer edge) {

        // Event params are key avatar id, integer level representing keys
        // currently held and integer edge representing keys which have
        // been pressed or released in this period (Since last control event).

        if (!(llGetAgentInfo(llGetOwner()) & AGENT_WALKING)) {
            llApplyImpulse(<0, 0, 0>, TRUE);
        }
        else {
            if (afk && (keyAnimation == "") && (id == dollID)) {
                if      (level & ~edge & CONTROL_FWD)  llApplyImpulse(<-1, 0, 0> * afkSlowWalkSpeed, TRUE);
                else if (level & ~edge & CONTROL_BACK) llApplyImpulse(< 1, 0, 0>  * afkSlowWalkSpeed, TRUE);
            }
        }
    }
#endif

    //----------------------------------------
    // DATASERVER
    //----------------------------------------
    dataserver(key request, string data) {

        if (request == rlvTPrequest) {
            vector global = llGetRegionCorner() + (vector)data;

            string locx = (string)llFloor(global.x);
            string locy = (string)llFloor(global.y);
            string locz = (string)llFloor(global.z);

            llOwnerSay("Dolly is now teleporting.");

            // Note this will be rejected if @unsit=n or @tploc=n are active
            lmRunRLVas("TP", "tpto:" + locx + "/" + locy + "/" + locz + "=force");
        }
    }

    //----------------------------------------
    // RUN TIME PERMISSIONS
    //----------------------------------------
    run_time_permissions(integer perm) {
        ifPermissions();
    }
}
