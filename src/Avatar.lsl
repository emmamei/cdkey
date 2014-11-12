//========================================
// Avatar.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 27 October 2014

#include "include/GlobalDefines.lsl"
#include "include/Json.lsl"

#define CHECK_RLV 1
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
#ifndef DEVELOPER_MODE
key mainCreator;
#endif
//key requestLoadData;
key keyAnimationID;
key lastAttachedID;
#ifdef DEVELOPER_MODE
float lastTimerEvent;
float thisTimerEvent;
float timerInterval;
integer timeReporting = 1;
#endif

list rlvSources;
list rlvStatus;

float rlvTimer;

//float baseWindRate;
float afkSlowWalkSpeed = 5;
float animRefreshRate = 8.0;

float nextRLVcheck;
float nextAnimRefresh;

vector carrierPos;
vector lockPos;

list split;
string script;
integer remoteSeq;
integer optHeader;
integer code;

string name;
string value;

string barefeet;
string carrierName;
string keyAnimation;

#ifdef DEVELOPER_MODE
string myPath;
#endif

string pronounHerDoll = "Her";
string pronounSheDoll = "She";
string rlvAPIversion;
//string redirchan;
string userBaseRLVcmd;

integer afk;
//integer isAnimated;
integer isFrozen;
integer isNoScript;
integer hasCarrier;
//integer isPosed; (use cdPosed)
//integer isSelfPosed; (use cdSelfPosed)
integer i;
key animKey;
list animList;

key grantorID;
integer permMask;

integer carryMoved;
integer rlvChannel;
integer clearAnim = 1;
integer collapsed;
//integer configured;
integer dialogChannel;
//integer haveControls;
integer rlvHandle;
integer locked;
#ifdef SIM_FRIENDLY
integer lowScriptMode;
#endif
integer poseSilence;
//integer refreshControls;
#ifdef CHECK_RLV
integer RLVck = 0;
integer RLVstarted;
#endif
integer RLVok = UNSET;
//integer startup = 1;
integer targetHandle;
//integer ticks;
integer wearLock;
integer newAttach = 1;
//integer creatorNoteDone;
integer chatChannel = 75;

//========================================
// FUNCTIONS
//========================================

key animStart(string animation) {
    debugSay(2,"DEBUG-AVATAR","animStart");
    if ((llGetPermissionsKey() != dollID) || (!(llGetPermissions() & PERMISSION_TRIGGER_ANIMATION)))
        return NULL_KEY;

    list oldList = llGetAnimationList(dollID);
    i = llGetListLength(oldList);

    debugSay(2,"DEBUG-AVATAR","animStart");
    // Stop all animations
    while (i--)
        llStopAnimation(llList2Key(oldList, i));

    oldList = llGetAnimationList(dollID);

    //key animID = llGetInventoryKey(animation); // Only works on full perm animations
    llStartAnimation(animation);

    list newList = llGetAnimationList(dollID);
    integer j = llGetListLength(newList);

    // This section not only grabs the ID of the running
    // animation, but also checks to see that all former
    // animations were stopped... if we shortcut, we
    // lose that capability
    //
    // We test for three possibilities:
    //    1. There's only one animation currently running
    //    2. There's no animations running (error)
    //    3. There's two animations running: one failed to stop
    //    4. There's only one animation running that wasn't before

    // only one animation running: assume its ours and return its ID
    if (j == 1) return llList2Key(newList, 0);

    // NO animations are running: stopping animations succeeded
    // but animation start failed
    else if (j == 0)
        llSay(DEBUG_CHANNEL,"Animation start failed!");

    // Couldn't stop all animations - which should only
    // happen if the last and only animation was a looped animation...
    // We've started another animation so it won't be the only one:
    // so try again...
    else if (j == 2) {

        // The old list doesn't have the new animation in it - so iterate
        // over it and kill that last animation...

        i = llGetListLength(oldList);
        if (i == 1) {
            // oldList contains one animation we couldn't stop...
            // After trying to stop it again, we check the running animations
            // again to see if we have just the one (presumably) ours:
            // if so, we can return it immediately

            llStopAnimation(llList2Key(oldList, 0));
            j = llGetListLength(newList = llGetAnimationList(dollID));
            if (j == 1) return llList2Key(newList, 0);
        }
        else {
            // old list is not 1: several animations did not stop
            llSay(DEBUG_CHANNEL,"Animation stop failed: " + (string)i + "animations were still running; start failed");
        }
    }
    else if (j - i == 1) {
        // Several animations other than ours are still running, not just one
        llSay(DEBUG_CHANNEL,"Animation stop failed: " + (string)i + "animations are still running");

        // At this point we have multiple animations that did not stop;
        // so iterate over the list and try to stop them all again
        //
        // Note that if some animations have started in the meantime
        // other than ours, they won't be stopped either...

        // We have two lists, one of which is one longer than the other...
        // we want to find the ONE key which is different

        // Starting from the end is faster because we can imply a
        // test against zero - but also because that is likely
        // where the difference is... but can't assume that is true
        while(i--) {
            animKey = llList2Key(oldList, i);

            if (llListFindList(newList, [ animKey ]) == NOT_FOUND)
                // There's only one element different between the two...
                // or should be - we could have a situation where
                // one animation was stopped and another started
                // "behind our backs" on top of what we did - but
                // we consider this unlikely
                return animKey;
        }
    }

    return NULL_KEY;
}

clearAnimations() {
    // Clear all animations

    animList = llGetAnimationList(dollID);
    animKey = NULL_KEY;

    //integer animCount = llGetListLength(animList);
    i = llGetListLength(animList);

    keyAnimation = "";
    lmSendConfig("keyAnimationID", (string)(keyAnimationID = NULL_KEY));

    while (i--) {
        animKey = llList2Key(animList, i);
        if (animKey) llStopAnimation(animKey);
    }

    llStartAnimation("Stand");
    animRefreshRate = 0.0;
    clearAnim = 0;
    cdLockMeisterCmd("booton");
}

oneAnimation() {
    integer upRefresh;
    debugSay(2,"DEBUG-AVATAR","oneAnimation");

    // Strip down to a single animation (keyAnimation)

    cdLockMeisterCmd("bootoff");

    // keyAnimationID is null so grab the real thing. Note that
    // keyAnimationID is expected to match keyAnimation, but does it
    // really?

    if ((animKey = llGetInventoryKey(keyAnimation)) == NULL_KEY) 
        animKey = keyAnimationID;

    animList = llGetAnimationList(dollID);
    if (animKey) {
        // if animKey is running alone - we've nothing to do...
        if (animList != [ animKey ]) {
            // animStart() would stop everything; we only want to
            // stop all the rogue animations OTHER than what we want
            // to keep running
            key animKeyI;

            if (llListFindList(animList, [ animKey ]) == NOT_FOUND) {
                // Animation isn't running currently: let animStart() handle it
                animKey = animStart(keyAnimation);
            }
            else {
                // animKey animation IS running... don't stop it; stop everything else

                debugSay(2,"DEBUG-AVATAR","Running animKey loop");

                // Other animations are trying to "get in"; make note of it
                upRefresh = 1;

                i = llGetListLength(animList);
                while (i--) {
                    animKeyI = llList2Key(animList, i);

                    if (animKeyI != animKey) {
                        debugSay(2,"DEBUG-AVATAR","Stopping animation #" + (string)i + ": " + (string)animKeyI);
                        llStopAnimation(animKeyI);
                    }
                }
            }
        }
    }
    else animKey = animStart(keyAnimation);

    // animKey should now be the key of a running animation - the only animation...
    // keyAnimationID, if not corrupted, is the previous animation...

    if (keyAnimationID == NULL_KEY) {
        if (animKey != NULL_KEY) {
            lmSendConfig("keyAnimationID", (string)(keyAnimationID = animKey));
            animRefreshRate = 4.0;
        }
        else animRefreshRate = 0.0;
    }
    else {
        if (animKey != keyAnimationID)
            lmSendConfig("keyAnimationID", (string)(keyAnimationID = animKey));

        // this makes the refresh rate "adaptive": if nothing happens,
        // another frame's worth is added to the refresh rate each time;
        // if an animation takes over or tries to - the refresh rate is
        // cut in half. There is also clipping at the maximum and minimum times
        //
        // Note that the refresh times are dependent on Frames: the busier a
        // region is, the longer time between refreshes - and vice versa.
        // Helps to keep things accurate and perhaps not be so brutal to
        // a busy region - also keeps us from having two timer events collide

#define MIN_FRAMES 4
#define ADD_FRAMES 5

        if (upRefresh) {
            // We found our animation being interfered with; cut the refreshRate
            // so that we run more often: and "fight back" for our animation
            animRefreshRate /= 2.0;                                     // -50%
            if (animRefreshRate < llGetRegionFPS() * MIN_FRAMES)
                animRefreshRate = llGetRegionFPS() * MIN_FRAMES;        // Minimum amount of time (by Frames)
        }
        else {
            // No interference - so run less often
            animRefreshRate += (1.0/llGetRegionFPS()) * ADD_FRAMES;     // +5 (current) Frame's worth of time
            if (animRefreshRate > 30.0) animRefreshRate = 30.0;         // 30 Second limit
        }
    }

    debugSay(4, "DEBUG", "Animation Refresh Rate: " + formatFloat(animRefreshRate,2));
}

#ifdef CHECK_RLV
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
#endif // CHECK_RLV

ifPermissions() {
    // This is repeatedly and frequently called - pays to be fast
    //
    // ifPermissions is called in these locations at writing:
    //   * on_rez
    //   * changed
    //   * attach
    //   * link_message 110
    //   * link_message 300/collapsed
    //   * link_message 300/keyAnimation
    //   * link_message 300
    //   * link_message 500
    //   * timer
    //   * run_time_permissions
    //
    // Note especially the call during run_time_permissions:
    // that section is called by llRequestPermissions() and
    // similar functions - from within this function...

    // Don't do anything unless attached
    if (!llGetAttached()) return;

    grantorID = llGetPermissionsKey();
    permMask = llGetPermissions();

    // If permissions granted to someone other than Dolly,
    // start over...
     if (grantorID != dollID) {
        if (grantorID) cdResetKey();
    }

    if ((permMask & PERMISSION_MASK) != PERMISSION_MASK) {
        // FIXME: llRequestPermissions runs this function: means a double run if PERMISSION_MASK is off-kilter
        llRequestPermissions(dollID, PERMISSION_MASK);
        return;
        }

    if (grantorID == NULL_KEY) return;

    // only way to get here is grantorID is dollID

    //----------------------------------------
    // PERMISSION_TRIGGER_ANIMATION

    if (permMask & PERMISSION_TRIGGER_ANIMATION) {

        animList = llGetAnimationList(dollID);

        if (clearAnim) clearAnimations();
        else if (!cdNoAnim()) oneAnimation(); 

        if (animRefreshRate) nextAnimRefresh = llGetTime() + animRefreshRate;
        llSetTimerEvent(animRefreshRate);
    }

    debugSay(2,"DEBUG-AVATAR","animRefreshRate = " + (string)animRefreshRate + "; keyAnimation = " + keyAnimation);
    //----------------------------------------
    // PERMISSION_TAKE_CONTROLS

    isFrozen = (collapsed || keyAnimation != "");

    if (permMask & PERMISSION_TAKE_CONTROLS) {

        //debugSay(2,"DEBUG-COLLAPSE","haveControls = " + (string)haveControls + "; collapsed = " + (string)collapsed);
        debugSay(2,"DEBUG-AVATAR","Taking controls...");

        if (isFrozen)
            // Dolly is "frozen": either collapsed or posed

            // When collapsed or posed the doll should not be able to move at all; so the key will
            // accept their controls, but no need to pass on: ignore all input.
            llTakeControls(ALL_CONTROLS, TRUE, FALSE);
#ifdef SLOW_WALK
        else if (afk)
            // Dolly is AFK

            // To slow movement during AFK, we do not want to lock the doll's controls completely; we
            // want to instead respond to the input, so we need ACCEPT=TRUE, PASS_ON=TRUE
            llTakeControls(ALL_CONTROLS, TRUE, TRUE);
#endif
        else {
            // Dolly is not AFK nor collapsed nor posed

#ifdef NO_RELEASECONTROLS
            if (isNoScript)
#endif
                // We do not want to release the controls if the land is noScript; doing so
                // would effectively shut down the key until one entered Script-enabled
                // land again

                // Dont release controls... we're in a NoScript zone...
                llTakeControls(ALL_CONTROLS, FALSE, TRUE);

#ifdef NO_RELEASECONTROLS
            else {

                // Release controls drops the PERMISSIONS_TAKE_CONTROLS flag and permissions
                // so we have to ask for them again

                llReleaseControls();

                //haveControls = 0;
                //refreshControls = 0;

                // This code is contained in the run_event - so this function
                // repeats the function we are in.
                llRequestPermissions(dollID, PERMISSION_MASK); // get TAKE_CONTROLS perm back
            }
#endif
        }
    }

    //----------------------------------------
    // Moving to Target

    debugSay(2,"DEBUG-AVATAR","Moving to target");
    if (isFrozen) {

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

        if (carrierPos) {
            targetHandle = llTarget(carrierPos, CARRY_RANGE);
            llMoveToTarget(carrierPos, 0.7);
        }
        else
            llOwnerSay("Carrier is out of region?!");
    }
    else {
        // Stop moving to Target
        llTargetRemove(targetHandle);
        llStopMoveToTarget();
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

        isNoScript = llGetParcelFlags(llGetPos()) & PARCEL_FLAG_ALLOW_SCRIPTS;
        llRequestPermissions(dollID, PERMISSION_MASK);
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer start) {

#ifdef CHECK_RLV
        rlvTimer = llGetTime();
        RLVck = 0;
        RLVok = -1;
        rlvAPIversion = "";
        RLVstarted = 0;

#ifdef DEVELOPER_MODE
        myPath = "";
#endif
#endif // CHECK_RLV

        llStopMoveToTarget();
        llTargetRemove(targetHandle);

        debugSay(2,"DEBUG-COLLAPSE","ifPermissions (on_rez)");
        isNoScript = llGetParcelFlags(llGetPos()) & PARCEL_FLAG_ALLOW_SCRIPTS;
        ifPermissions();
    }

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    changed(integer change) {
        if (change & (CHANGED_REGION | CHANGED_TELEPORT)) {
            llStopMoveToTarget();
            llTargetRemove(targetHandle);

            debugSay(2,"DEBUG-COLLAPSE","ifPermissions (changed)");
            isNoScript = llGetParcelFlags(llGetPos()) & PARCEL_FLAG_ALLOW_SCRIPTS;
            ifPermissions();
        }
    }

#ifdef CHECK_RLV
    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer chan, string name, key id, string msg) {

        //debugSay(2, "DEBUG-AVATAR", "Listener tripped....");
        if (chan == rlvChannel) {
            //debugSay(2, "DEBUG-RLV", "RLV Message received: " + msg);

            // Could be "RestrainedLove" or "RestrainedLife" but we
            // can test for both this way - and the likelihood that
            // a false positive will come through is pretty minimal.
            if (llGetSubString(msg, 0, 10) == "RestrainedL") {

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
#endif //CHECK_RLV

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
            debugSay(2,"DEBUG-COLLAPSE","ifPermissions (attach)");
            ifPermissions();
#ifdef CHECK_RLV
            doCheckRLV();
#endif
        }

        newAttach = (lastAttachedID != dollID);
        lastAttachedID = id;
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

        if (code == 110) {
            //configured = 1;
            //doCheckRLV();

            debugSay(2,"DEBUG-COLLAPSE","ifPermissions (link_message 110)");
            ifPermissions();
        }
        else if (code == 135) {
            float delay = llList2Float(split, 0);
            memReport(cdMyScriptName(),delay);
        } else

        cdConfigReport();

        else if (code == 300) {
            name = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);
            value = llList2String(split, 0);

// CHANGED_OTHER bit used to indicate changes of RLV status that
// would not normally be reflected as a doll state.
//#define CHANGED_OTHER 0x80000000

            //integer oldState = dollState;              // Used to determine if a refresh of RLV state is needed

            // if (name == "autoTP")                        autoTP = (integer)value;
            if (name == "carrierID") {
                carrierID = (key)value;
                hasCarrier = cdCarried();
            }
            else if (name == "afk")                         afk = (integer)value;
            //else if (name == "canFly")                   canFly = (integer)value;
            //else if (name == "canSit")                   canSit = (integer)value;
            //else if (name == "canStand")               canStand = (integer)value;
            //else if (name == "canDressSelf")       canDressSelf = (integer)value;
            else if (name == "collapsed") {
                    collapsed = (integer)value;

                    if (collapsed) lmSendConfig("keyAnimation", (keyAnimation = ANIMATION_COLLAPSED));
                    else if (cdCollapsedAnim()) lmSendConfig("keyAnimation", (keyAnimation = ""));

                    debugSay(2,"DEBUG-COLLAPSE","ifPermissions (link_message 300/collapsed)");
                    ifPermissions();
            }
            //else if (name == "tpLureOnly")           tpLureOnly = (integer)value;
            //else if (name == "poseSilence")         poseSilence = (integer)value;
            else if (name == "userBaseRLVcmd")   userBaseRLVcmd = value;
#ifdef DEVELOPER_MODE
            else if (name == "timeReporting")     timeReporting = (integer)value;
#endif
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

                //isAnimated = (keyAnimation != "");

                if cdNoAnim() clearAnim = 1;
                else {
                    if ((oldanim != "") && (keyAnimation != oldanim)) {    // Issue #139 Moving directly from one animation to another make certain keyAnimationID does not holdover to the new animation.
                        keyAnimationID = NULL_KEY;
                    }
                    lmSendConfig("keyAnimationID", (string)(keyAnimationID = animStart(keyAnimation)));
                }

                debugSay(2,"DEBUG-COLLAPSE","ifPermissions (link_message 300/keyAnimation)");
                ifPermissions();
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
                //else if (name == "dollType")                   dollType = value;
                //else if (name == "controllers")             controllers = split;
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
            debugSay(2,"DEBUG-COLLAPSE","ifPermissions (link_message 300)");
            ifPermissions();
        }
        else if (code == 305) {
            string cmd = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "detach") {
                if (RLVok || RLVstarted) llOwnerSay("@clear,detachme=force");
                else llDetachFromAvatar();
            }
#ifdef CHECK_RLV
            else if (cmd == "doCheckRLV") {
                doCheckRLV();
                lmSendConfig("RLVok",(string)RLVok);
            }
#endif
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

#ifdef CHECK_RLV
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
#endif // CHECK_RLV
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

                i = 0;

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
                list poseList;
                i = poseCount;
                string poseName;
                string prefix;

                while (i--) {
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

                if (poseCount > 9) {
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

            debugSay(2,"DEBUG-COLLAPSE","ifPermissions (link_message 500)");
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
        thisTimerEvent = llGetTime();

#ifdef DEVELOPER_MODE
        if (cdAttached()) timerInterval = thisTimerEvent - lastTimerEvent;
        lastTimerEvent = thisTimerEvent;

        if (timeReporting) llOwnerSay("Avatar Timer fired, interval " + formatFloat(timerInterval,3) + "s.");
#endif

        // IF RLV is ok we don't have to check it do we?

        if (RLVok == UNSET) {
            // this makes sure that enough time has elapsed - and prevents
            // the check from being missed...

            if (nextRLVcheck < llGetTime()) checkRLV();
            lmSendConfig("RLVok",(string)RLVok);
        }

        debugSay(2,"DEBUG-COLLAPSE","ifPermissions (timer)");
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
    // doll is in RLV or not though RLV is a bonus as it allows us to prevent
    // running.

    control(key id, integer level, integer edge) {

        // Event params are key avatar id, integer level representing keys
        // currently held and integer edge representing keys which have
        // been pressed or released in this period (Since last control event).

        if (llGetAgentInfo(llGetOwner()) & AGENT_WALKING) {
            if (afk) {
                if ((keyAnimation == "") && (id == dollID)) {
                         if (level & ~edge & CONTROL_FWD)  llApplyImpulse(<-1, 0, 0> * afkSlowWalkSpeed, TRUE);
                    else if (level & ~edge & CONTROL_BACK) llApplyImpulse(< 1, 0, 0> * afkSlowWalkSpeed, TRUE);
                }
            }
        }
        else
            llApplyImpulse(<0, 0, 0>, TRUE);
    }
#endif

    //----------------------------------------
    // DATASERVER
    //----------------------------------------
    dataserver(key request, string data) {

        if (request == rlvTPrequest) {
            vector global = llGetRegionCorner() + (vector)data;

            llOwnerSay("Dolly is now teleporting.");

            // Note this will be rejected if @unsit=n or @tploc=n are active
            lmRunRLVas("TP", "tpto:" +
                    (string) llFloor( global.x ) + "/" +
                    (string) llFloor( global.y ) + "/" +
                    (string) llFloor( global.z ) + "=force");
        }
    }

    //----------------------------------------
    // RUN TIME PERMISSIONS
    //----------------------------------------
    run_time_permissions(integer perm) {
        debugSay(2,"DEBUG-COLLAPSE","ifPermissions (run_time_permissions)");
        ifPermissions();
    }
}
