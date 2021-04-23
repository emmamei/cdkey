//========================================
// Avatar.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 24 November 2020

#include "include/GlobalDefines.lsl"
// #include "include/Json.lsl"

//#define DEBUG_BADRLV
#define NOT_IN_REGION ZERO_VECTOR
#define cdLockMeisterCmd(a) llWhisper(LOCKMEISTER_CHANNEL,(string)dollID+a)
#define MAX_RLVCHECK_TRIES 5
#define RLV_TIMEOUT 20.0
#define POSE_CHANNEL_OFFSET 777
#define UNSET -1
#define ALL_CONTROLS (CONTROL_FWD|CONTROL_BACK|CONTROL_LEFT|CONTROL_RIGHT|CONTROL_ROT_LEFT|CONTROL_ROT_RIGHT|CONTROL_UP|CONTROL_DOWN|CONTROL_LBUTTON|CONTROL_ML_LBUTTON)

#define cdListenerDeactivate(a) llListenControl(a, 0)
#define cdListenerActivate(a) llListenControl(a, 1)
#define cdResetKey() llResetOtherScript("Start")

#define MIN_FRAMES 20
#define ADD_FRAMES 20
#define cdMinRefresh() ((1.0/llGetRegionFPS()) * MIN_FRAMES)
#define cdAddRefresh() ((1.0/llGetRegionFPS()) * ADD_FRAMES)

key rlvTPrequest;
#ifdef LOCKON
key mainCreator;
#endif
key lastAttachedID;

// Note that this is not the "speed" nor is it a slowing factor
// This is a vector of force applied against Dolly: headwind speed
// is a good way to think of it
float afkSlowWalkSpeed = 30;

// Note that this is just a starting point; animRefreshRate is
// adaptive
float animRefreshRate = 8.0;

vector carrierPos;
vector newCarrierPos;

string msg;
string name;
string value;

#ifdef DEVELOPER_MODE
string myPath;
#endif

integer hasCarrier;
integer i;
integer posePage;
integer timerMark;
integer lastTimerMark;

// This acts as a cache of
// current poses in inventory
list poseList;
integer poseCount;

string poseName;
integer poseChannel;
key animKey;
list animList;

key grantorID;
integer permMask;

vector pointTo;
integer clearAnim = 1;
integer locked;
integer targetHandle;
integer newAttach = 1;
integer atTarget;

//========================================
// FUNCTIONS
//========================================

followCarrier(key id) {

    if (!atTarget && hasCarrier && keyAnimation== "") {
        // Dolly is being carried and is movable

        // Get updated position and set target
        newCarrierPos = llList2Vector(llGetObjectDetails(id, [OBJECT_POS]), 0);

        if (newCarrierPos) {
            // Carrier is present
            targetHandle = llTarget(carrierPos, CARRY_RANGE);

            carrierPos = newCarrierPos;

            // Move to and turn toward target
            pointTo = carrierPos - llGetPos();

            lmRunRLV("setrot:" + (string)(llAtan2(pointTo.x, pointTo.y)) + "=force");
            llMoveToTarget(carrierPos, 0.7);
        }
        else {
            // Carrier has disappeared: drop
            hasCarrier = 0;
            newCarrierPos = ZERO_VECTOR;
            carrierPos = ZERO_VECTOR;
            // Full stop: avatar comes to stop
            llTargetRemove(targetHandle);
            llStopMoveToTarget();

            lmSendConfig("carrierID", (string)(carrierID = NULL_KEY));
            lmSendConfig("carrierName", (carrierName = ""));
        }
    }
    else {
        // Dolly either has no carrier, or is frozen in place

        // Full stop: avatar comes to stop
        llTargetRemove(targetHandle);
        llStopMoveToTarget();
    }
}

posePageN(string choice, key id) {
    string posePrefix;
    integer poseIndex;
    list tmpList;
    integer isDoll = cdIsDoll(id);
    integer isController = cdIsController(id);
    integer buildList;

    poseCount = llGetInventoryNumber(INVENTORY_ANIMATION);

    if (poseList == []) buildList = TRUE;

    i = poseCount; // loopIndex
    while (i--) {
        if (buildList) {
            poseName = llGetInventoryName(INVENTORY_ANIMATION, i);
            if (poseName != ANIMATION_COLLAPSED) {
                if (poseName == "") llSay(DEBUG_CHANNEL,"null pose entry!");
                else poseList += poseName;
            }
        }
        else poseName = llList2String(poseList, i);

        // Is the pose a pose we can show in the menu?
        //
        // * Skip the current animation and the collapse animation
        // * Show all animations to Dolly
        // * Show animations like !foo to Controller
        // * Show animations like .foo to Dolly only
        // * Show animations like foo to all
        //
        if (poseName != ANIMATION_COLLAPSED && poseName != keyAnimation && poseName != "") {
            posePrefix = cdGetFirstChar(poseName);

            if (isDoll ||
               (isController && posePrefix == "!") ||
               (posePrefix != "!" && posePrefix != ".")) {

                debugSay(6,"DEBUG-AVATAR","Pose #" + (string)(i+1) + " added: " + poseName);
                tmpList += poseName;
            }
        }
    }

    if (choice == "Poses Next") {
        posePage++;
        poseIndex = (posePage - 1) * 9;
        if (poseIndex > poseCount) {
#ifdef ROLLOVER
            posePage = 1;
            poseIndex = 0;
#else
            posePage--; // backtrack
            poseIndex = (posePage - 1) * 9; // recompute
#endif
        }
    }
    else if (choice == "Poses Prev") {
        posePage--;
        if (posePage == 0) {
#ifdef ROLLOVER
            posePage = llFloor(poseCount / 9) + 1;
            poseIndex = (posePage - 1) * 9;
#else
            posePage = 1;
            poseIndex = 0;
#endif
        }
    }

    poseCount = llGetListLength(poseList);
    debugSay(4,"DEBUG-AVATAR","Found " + (string)poseCount + " poses");

    tmpList = llListSort(tmpList, 1, 1);
    if (poseCount > 9) {
        // Get a 9-count slice from tmpList for dialog
        tmpList = llList2List(tmpList, poseIndex, poseIndex + 8) + [ "Poses Prev", "Poses Next" ];
    }
    else {
        tmpList += [ "-", "-" ];
    }

    lmSendConfig("backMenu",(backMenu = MAIN));
    tmpList += [ "Back..." ];

    msg = "Select the pose to put dolly into";
    if (keyAnimation) msg += " (current pose is " + keyAnimation + ")";

    llDialog(id, msg, dialogSort(tmpList), poseChannel);
}

key animStart(string animation) {
    list oldAnimList;
    list newAnimList;
    integer oldAnimListLen;
    integer newAnimListLen;
    integer j;

    if (animation == "") return NULL_KEY;

    if ((llGetPermissionsKey() != dollID) || (!(llGetPermissions() & PERMISSION_TRIGGER_ANIMATION)))
        return NULL_KEY;

    oldAnimList = llGetAnimationList(dollID);
    oldAnimListLen = llGetListLength(oldAnimList);
    i = oldAnimListLen;

    // Stop all animations
    while (i--)
        llStopAnimation(llList2Key(oldAnimList, i));

    //oldAnimList = llGetAnimationList(dollID);
    i = oldAnimListLen;

    //key animID = llGetInventoryKey(animation); // Only works on full perm animations
    llStartAnimation(animation);

    newAnimList = llGetAnimationList(dollID);
    newAnimListLen = llGetListLength(newAnimList);
    j = newAnimListLen;

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
    if (j == 1) return llList2Key(newAnimList, 0);

    // NO animations are running: stopping animations succeeded
    // but animation start failed
    else if (j == 0)
        llSay(DEBUG_CHANNEL,"Animation (" + animation + ") start failed!");

    // Couldn't stop all animations - which should only
    // happen if the last and only animation was a looped animation...
    // We've started another animation so it won't be the only one:
    // so try again...
    else if (j == 2) {

        // The old list doesn't have the new animation in it - so iterate
        // over it and kill that last animation...

        i = llGetListLength(oldAnimList);
        if (i == 1) {
            // oldAnimList contains one animation we couldn't stop...
            // After trying to stop it again, we check the running animations
            // again to see if we have just the one (presumably) ours:
            // if so, we can return it immediately

            llStopAnimation(llList2Key(oldAnimList, 0));
            j = llGetListLength(newAnimList = llGetAnimationList(dollID));
            if (j == 1) return llList2Key(newAnimList, 0);
        }
        else {
            // old list is not 1: several animations did not stop
            llSay(DEBUG_CHANNEL,"Animation stop failed: " + (string)i + " animations were still running; start failed");
        }
    }
    else if (j - i == 1) {
        // Several animations other than ours are still running, not just one
        llSay(DEBUG_CHANNEL,"Animation stop failed: " + (string)i + " animations are still running");

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
            animKey = llList2Key(oldAnimList, i);

            if (llListFindList(newAnimList, [ animKey ]) == NOT_FOUND)
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

    // Get list of all current animations
    animList = llGetAnimationList(dollID);
    animKey = NULL_KEY;

    i = llGetListLength(animList);

    // Clear current saved animation if any
    keyAnimation = "";
    if (keyAnimationID != NULL_KEY) lmSendConfig("keyAnimationID", (string)(keyAnimationID = NULL_KEY));

    // Stop all currently active animations
    //
    // Note that this will stop current system animations, but they
    // will not "stay down" and will return, although will not be playing
    //
    while (i--) {
        animKey = llList2Key(animList, i);
        if (animKey) llStopAnimation(animKey);
    }

    llSay(99,"stop"); // Turns off dances: customarily on channel 99

    // Reset current animations
    llStartAnimation("Stand");
    animRefreshRate = 0.0;
    clearAnim = 0;
    cdLockMeisterCmd("booton");
}

oneAnimation() {
    //integer upRefresh;

    // Strip down to a single animation (keyAnimation)

    cdLockMeisterCmd("bootoff");

    // keyAnimationID is null so grab the real thing. Note that
    // keyAnimationID is expected to match keyAnimation, but does it
    // really?

    if ((animKey = llGetInventoryKey(keyAnimation)) == NULL_KEY) 
        animKey = keyAnimationID;

    animKey = animStart(keyAnimation);

    if (animKey != NULL_KEY) {
        lmSendConfig("keyAnimationID", (string)(keyAnimationID = animKey));

        // This adjusts the refresh rate for lowscript mode
        if (lowScriptMode) animRefreshRate = 60.0;
        else animRefreshRate = 30.0;
    }
    else animRefreshRate = 0.0;

    debugSay(4, "DEBUG-ANIM", "Animation Refresh Rate: " + formatFloat(animRefreshRate,2));
}

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
        // llRequestPermissions runs this function: means a double run if PERMISSION_MASK is off-kilter
        llRequestPermissions(dollID, PERMISSION_MASK);
        return;
        }

    if (grantorID == NULL_KEY) return;

    // only way to get here is grantorID is dollID

    //----------------------------------------
    // PERMISSION_TRIGGER_ANIMATION

    if (permMask & PERMISSION_TRIGGER_ANIMATION) {

        // The big work is done in clearAnimations() and in
        // oneAnimation

        if (clearAnim) clearAnimations();
        else if (cdAnimated()) oneAnimation(); 

        llSetTimerEvent(animRefreshRate);
    }

    //----------------------------------------
    // PERMISSION_TAKE_CONTROLS

    if (permMask & PERMISSION_TAKE_CONTROLS) {

        if (keyAnimation != "")
            // Dolly is "frozen": either collapsed or posed

            // When collapsed or posed the doll should not be able to move at all; so the key will
            // accept their controls, but no need to pass on: ignore all input.
            llTakeControls(ALL_CONTROLS, TRUE, FALSE);

#ifdef SLOW_WALK
        else if (afk) {
            // Dolly is AFK

            // To slow movement during AFK, we do not want to lock the doll's controls completely; we
            // want to instead respond to the input, so we need ACCEPT=TRUE, PASS_ON=TRUE
            //debugSay(2,"DEBUG-AVATAR","Controls taken for AFK Dolly");
            llTakeControls(ALL_CONTROLS, TRUE, TRUE);
        }
#endif
        else {
            // Dolly is not AFK nor collapsed nor posed

            // We do not want to release the controls if the land is noScript; doing so
            // would effectively shut down the key until one entered Script-enabled
            // land again
#ifdef SLOW_WALK
            llSetForce(<0, 0, 0>, TRUE);
#endif
            llTakeControls(ALL_CONTROLS, FALSE, TRUE);
        }
    }

    //----------------------------------------
    // Moving to Target

    followCarrier(carrierID);
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

        RLVok = UNSET;
        cdInitializeSeq();

        llRequestPermissions(dollID, PERMISSION_MASK);
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer start) {
        // Set up key when rezzed

        RLVok = UNSET;
        //llStopMoveToTarget();
        //llTargetRemove(targetHandle);

        debugSay(5,"DEBUG-AVATAR","ifPermissions (on_rez)");
        ifPermissions();
    }

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    changed(integer change) {
        if (change & (CHANGED_REGION | CHANGED_TELEPORT)) {
            llStopMoveToTarget();
            llTargetRemove(targetHandle);


#ifdef DEVELOPER_MODE
            msg = "Region ";
            if (llGetParcelFlags(llGetPos()) & PARCEL_FLAG_ALLOW_SCRIPTS) msg += "allows scripts";
            else msg += "does not allow scripts";

            debugSay(3,"DEBUG-AVATAR",msg);
            debugSay(3,"DEBUG-AVATAR","Region FPS: " + formatFloat(llGetRegionFPS(),1) + "; Region Time Dilation: " + formatFloat(llGetRegionTimeDilation(),3));
            debugSay(5,"DEBUG-AVATAR","ifPermissions (changed)");
#endif
            ifPermissions();
        }
        else if (change & CHANGED_INVENTORY) {
            // Doing this whenever inventory changes is ok: the update process stops this script;
            // otherwise, the only cost is time.
            poseList = [];
            poseCount = llGetInventoryNumber(INVENTORY_ANIMATION);

            i = poseCount;
            debugSay(4,"DEBUG-AVATAR","Refreshing list of poses on inventory change");

            while (i--) {
                // This takes time:
                poseName = llGetInventoryName(INVENTORY_ANIMATION, i);
                //debugSay(6,"DEBUG-AVATAR","Pose #" + (string)(i+1) + " found: " + poseName);

                // Collect all viable poses: skip the collapse animation
                if (poseName != ANIMATION_COLLAPSED)
                    poseList += poseName;
            }

            poseList = llListSort(poseList, 1, 1);
        }
    }

    //----------------------------------------
    // ATTACH
    //----------------------------------------
    attach(key id) {
        if (id == NULL_KEY && (!detachable || hardcore) && !locked) {
            // Detaching key somehow...

            // As the id is NULL_KEY, this is a detach: and an illegal
            // one at that (not detachable, hardcore, and not locked).
            lmSendToController(dollName + " has bypassed the Key's bio-lock and detached the Key.");
            llOwnerSay("You have bypassed your Key's bio-lock systems and your controllers have been notified.");
        }

        locked = 0;

        //llSetStatus(STATUS_PHYSICS,TRUE);
        llStopMoveToTarget();
        llTargetRemove(targetHandle);

        if (id) {
            ifPermissions();

#ifdef DEVELOPER_MODE
            debugSay(2,"DEBUG-AVATAR","Region FPS: " + formatFloat(llGetRegionFPS(),1) + "; Region Time Dilation: " + formatFloat(llGetRegionTimeDilation(),3));
            debugSay(5,"DEBUG-AVATAR","ifPermissions (attach)");
#endif
            ifPermissions();
        }

        newAttach = (lastAttachedID != dollID);
        lastAttachedID = id;

        debugSay(4,"DEBUG-AVATAR","Checking poses on attach");

        poseList = [];
        poseCount = llGetInventoryNumber(INVENTORY_ANIMATION);
        i = poseCount;
        while (i--) {
            // This takes time:
            poseName = llGetInventoryName(INVENTORY_ANIMATION, i + 1);
            debugSay(6,"DEBUG-AVATAR","Adding pose #" + (string)i + ": " + poseName);

            // Collect all viable poses: skip the collapse animation
            if (poseName != ANIMATION_COLLAPSED)
                poseList += poseName;
        }
        poseList = llListSort(poseList, 1, 1);

        // Note: this is initial, before receiving any new config events
        //lmInternalCommand("setWindRate","",NULL_KEY);
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

        //scaleMem();

        if (code == SEND_CONFIG) {
            name = llList2String(split, 0);
            value = llList2String(split, 1);
            split = llDeleteSubList(split, 0, 0);

            if (name == "carrierID") {
                carrierID = (key)value;
                hasCarrier = cdCarried();
            }
            else if (name == "collapsed") {
                    collapsed = (integer)value;

                    if (collapsed) keyAnimation = ANIMATION_COLLAPSED;
                    else if (cdCollapsedAnim()) keyAnimation = "";
                    lmSendConfig("keyAnimation", keyAnimation);

                    debugSay(5,"DEBUG-AVATAR","ifPermissions (link_message 300/collapsed)");
                    ifPermissions();
            }
            else if (name == "poseSilence")         poseSilence = (integer)value;
            else if (name == "hardcore")               hardcore = (integer)value;
#ifdef DEVELOPER_MODE
            else if (name == "timeReporting")     timeReporting = (integer)value;
#endif
            else if (name == "keyAnimation") {
                string oldanim = keyAnimation;
                keyAnimation = value;

                if cdNoAnim() clearAnim = 1;
                else {
                    if ((oldanim != "") && (keyAnimation != oldanim)) {    // Issue #139 Moving directly from one animation to another make certain keyAnimationID does not holdover to the new animation.
                        keyAnimationID = NULL_KEY;
                    }
                    lmSendConfig("keyAnimationID", (string)(keyAnimationID = animStart(keyAnimation)));
                }

                debugSay(5,"DEBUG-AVATAR","ifPermissions (link_message 300/keyAnimation)");
                ifPermissions();
            }
            else if (name == "poserID")                 poserID = (key)value;
            else {
                     if (name == "detachable")               detachable = (integer)value;
#ifdef DEVELOPER_MODE
                else if (name == "debugLevel")               debugLevel = (integer)value;
#endif
                else if (name == "lowScriptMode")         lowScriptMode = (integer)value;
                else if (name == "allowPose")                 allowPose = (integer)value;
                else if (name == "dollType")                   dollType = value;
                else if (name == "controllers") {
                    if (split == [""]) controllers = [];
                    else controllers = split;
                }
                else if (name == "pronounHerDoll")       pronounHerDoll = value;
                else if (name == "pronounSheDoll")       pronounSheDoll = value;
                else if (name == "dialogChannel") {
                    dialogChannel = (integer)value;
                    poseChannel = dialogChannel - POSE_CHANNEL_OFFSET;
                }
                else if (name == "keyAnimationID")       keyAnimationID = (key)value;

                return;
            }

            debugSay(5,"DEBUG-AVATAR","ifPermissions (link_message 300)");
            ifPermissions();
        }
        else if (code == INTERNAL_CMD) {
            string cmd = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "detach") {
                if (RLVok == TRUE) { lmRunRLVcmd("clearRLVcmd","detachme=force"); }
                else llDetachFromAvatar();
            }
            else if (cmd == "teleport") {
                string lm = llList2String(split, 0);
                llRegionSayTo(id, 0, "Teleporting dolly " + dollName + " to  landmark " + lm + ".");
                rlvTPrequest = llRequestInventoryData(lm);
            }
            else if (cmd == "posePageN") {
                string choice = llList2String(split, 0);
                posePageN(choice,id);
            }
        }
        else if (code == MENU_SELECTION) {
            string choice = llList2String(split, 0);
            string choice5 = llGetSubString(choice,0,4);
            string name = llList2String(split, 1);

            // Dolly is poseable:
            //    * by members of the Public IF allowed
            //    * by herself
            //    * by Controllers
            integer dollIsPoseable = ((!cdIsDoll(id) && (allowPose || hardcore)) || cdIsController(id) || cdSelfPosed());

            // First: Quick ignores
            if (llGetSubString(choice,0,3) == "Wind") return;
            else if (choice == MAIN) return;

#ifdef ADULT_MODE
            else if (choice == "Strip") {
                lmInternalCommand("strip", "", id);
            }
#endif
            else if (choice == "Carry") {
                lmSendConfig("carrierID", (string)(carrierID = id));
                lmSendConfig("carrierName", (carrierName = name));

                llSay(PUBLIC_CHANNEL, "Dolly " + dollName + " has been picked up by " + carrierName);
            }
            else if (choice == "Uncarry") {
                if (cdIsCarrier(id)) {
                    llSay(PUBLIC_CHANNEL, "Dolly " + dollName + " has been placed down by " + carrierName);
                }
                else {
                    string name = llKey2Name(id);

                    if (name) {
                        llSay(PUBLIC_CHANNEL, "Dolly " + dollName + " has been wrestled away from " + carrierName + " by " + llKey2Name(id));
                    }
                    else {
                        llSay(PUBLIC_CHANNEL, "Dolly " + dollName + " has been wrestled away from " + carrierName);
                    }
                }

                lmSendConfig("carrierID", (string)(carrierID = NULL_KEY));
                lmSendConfig("carrierName", (carrierName = ""));
            }

            // Unpose: remove animation and poser
            else if (choice == "Unpose") {
                lmSendConfig("keyAnimation", (string)(keyAnimation = ""));
                lmSendConfig("poserID", (string)(poserID = NULL_KEY));

                // poseExpire is being set elsewhere
                lmSetConfig("poseExpire", "0");

                clearAnimations();
                if (poseSilence || hardcore) lmRunRLV("sendchat=y");
                ifPermissions();
            }

            else if (choice == "Poses...") {
                if (!cdIsDoll(id))
                    if (!hardcore)
                        llOwnerSay(cdUserProfile(id) + " is looking at your poses menu.");

                posePage = 1;
                cdDialogListen();
                lmInternalCommand("posePageN",choice, id);
            }
        }
        else if (code == POSE_SELECTION) {
            string choice = llList2String(split, 0);

            // it could be Poses Next or Poses Prev instead of an Anim
            if (choice == "Poses Next" || choice == "Poses Prev") {
                cdDialogListen();
                llSleep(0.5);
                lmInternalCommand("posePageN",choice, id);
            }

            // could have been "Back..."
            else if (choice == "Back...") {
                lmMenuReply(backMenu, llGetDisplayName(id), id);
                lmSendConfig("backMenu",(backMenu = MAIN));
            }

            else {
                llSay(PUBLIC_CHANNEL,"Pose " + choice + " selected.");

                // The Real Meat: We have an animation (pose) name
                lmSendConfig("keyAnimation", (string)(keyAnimation = choice));
                lmSendConfig("poserID", (string)(poserID = id));

                if (dollType == "Display" || hardcore)
                    lmSetConfig("poseExpire", "0");
                else
                    lmSetConfig("poseExpire", (string)(llGetUnixTime() + POSE_TIMEOUT));

                oneAnimation();
                if (poseSilence || hardcore) lmRunRLV("sendchat=n");
            }
        }
        else if (code == RLV_RESET) {
            RLVok = llList2Integer(split, 0);
        }
        else if (code < 200) {
            if (code == 110) {
                debugSay(5,"DEBUG-AVATAR","ifPermissions (link_message 110)");

                ifPermissions();
                oneAnimation();
            }
#ifdef DEVELOPER_MODE
            else if (code == MEM_REPORT) {
                memReport("Avatar",llList2Float(split,0));
            }
#endif
            else if (code == CONFIG_REPORT) {
                cdConfigureReport();
            }
        }
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------

    // Timer is used solely to check for animations and to
    // compute the animation refresh time

    timer() {

        // The big work is done in clearAnimations() and in
        // oneAnimation

        if (clearAnim) clearAnimations();
        else if (cdAnimated()) oneAnimation(); 

        llSetTimerEvent(animRefreshRate);

#ifdef DEVELOPER_MODE
        if (timeReporting) {
            timerMark = llGetUnixTime();

            if (lastTimerMark) {
                debugSay(5,"DEBUG-AVATAR","Avatar Timer fired, interval " + formatFloat(timerMark - lastTimerMark,2) + "s.");
            }

            lastTimerMark = timerMark;
        }
#endif
    }

    //----------------------------------------
    // AT TARGET
    //----------------------------------------
    at_target(integer num, vector target, vector me) {

        atTarget = TRUE;
        followCarrier(carrierID);

        // Full stop: avatar comes to stop
        llTargetRemove(targetHandle);
        llStopMoveToTarget();
    }

    //----------------------------------------
    // NOT AT TARGET
    //----------------------------------------
    not_at_target() {

        atTarget = FALSE;
        followCarrier(carrierID);
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
    //
    // In any case, the slowdown will affect running as much as walking,
    // if running is allowed.
    //
    // If there is a way to slow down flying, we'd have to know these
    // things: 1) is the agent moving? 2) what direction is the agent moving
    // in? 3) is the agent falling? There doesn't seem to be any way to
    // get all of that. The reason for the last is that a free fall should
    // not be slowed down except by Dolly flying - it is Dolly's exertions
    // that are slowed, not gravity.

    control(key id, integer level, integer edge) {

        // Event params are key avatar id, integer level representing keys
        // currently held and integer edge representing keys which have
        // been pressed or released in this period (Since last control event).

        //debugSay(2,"DEBUG-AVATAR","Control hit for AFK Dolly");
        if (id == dollID) {

            // If a key was just pressed, stop: we could be going in a different
            // direction.   If a key was released, then no going anywhere: full stop.
            // This relates to the force against Dolly - NOT Dolly herself.
            if (edge & (CONTROL_FWD | CONTROL_BACK | CONTROL_RIGHT | CONTROL_LEFT | CONTROL_UP | CONTROL_DOWN))
                llSetForce(<0, 0, 0>, TRUE);

            if (afk) {
                if (keyAnimation == "") {
                    if (llGetAgentInfo(dollID) & (AGENT_WALKING | AGENT_ALWAYS_RUN | AGENT_FLYING)) {
                        // This will run the appropriate llSetForce command repeatedly as long as
                        // the key is held down. This may or may not be desired, but it should not
                        // lead to erroneous operation.

                             if (level & CONTROL_FWD)   llSetForce(<-1, 0, 0> * afkSlowWalkSpeed, TRUE);
                        else if (level & CONTROL_BACK)  llSetForce(< 1, 0, 0> * afkSlowWalkSpeed, TRUE);
                        else if (level & CONTROL_RIGHT) llSetForce(< 0, 1, 0> * afkSlowWalkSpeed, TRUE);
                        else if (level & CONTROL_LEFT)  llSetForce(< 0,-1, 0> * afkSlowWalkSpeed, TRUE);
                        else if (level & CONTROL_UP)    llSetForce(< 0, 0, 1> * afkSlowWalkSpeed, TRUE);
                        else if (level & CONTROL_DOWN)  llSetForce(< 0, 0,-1> * afkSlowWalkSpeed, TRUE);
                    }
                }
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
        debugSay(2,"DEBUG-AVATAR","ifPermissions (run_time_permissions)");
        ifPermissions();
    }
}

//========== AVATAR ==========
