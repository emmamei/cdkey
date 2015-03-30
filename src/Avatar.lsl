//========================================
// Avatar.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 27 October 2014

#include "include/GlobalDefines.lsl"
// #include "include/Json.lsl"

//#define DEBUG_BADRLV
#define cdSayQuietly(x) { string z = x; if (quiet) llOwnerSay(z); else llSay(0,z); }
#define NOT_IN_REGION ZERO_VECTOR
#define cdLockMeisterCmd(a) llWhisper(LOCKMEISTER_CHANNEL,(string)dollID+a)
#define MAX_RLVCHECK_TRIES 5
#define RLV_TIMEOUT 20.0
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
#ifdef DEVELOPER_MODE
float thisTimerEvent;
float timerInterval;
#endif

// Note that this is not the "speed" nor is it a slowing factor
// This is a vector of force applied against Dolly: headwind speed
// is a good way to think of it
float afkSlowWalkSpeed = 30;
float animRefreshRate = 8.0;

vector carrierPos;
vector newCarrierPos;

string msg;
string name;
string value;

//string barefeet;

#ifdef DEVELOPER_MODE
string myPath;
#endif

string userBaseRLVcmd;

integer hasCarrier;
integer i;
integer posePage;

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

    if (poseList == []) {
        buildList = TRUE;
        if (poseCount > 1) cdSayTo("Reading " + (string)poseCount + " poses from Dolly's internal secondary memory...",id);
        else if (poseCount == 1) {
            llSay(DEBUG_CHANNEL, "No poses found!");
            return;
        }
        else if (poseCount == 0) {
            llSay(DEBUG_CHANNEL, "No poses found! Key won't work without collapse animation!");
            return;
        }
    }

    debugSay(6,"DEBUG-AVATAR","Loop index initialized at " + (string)i + " poses");
    debugSay(6,"DEBUG-AVATAR","Current pose list = " + llDumpList2String(poseList, ","));

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

                debugSay(6,"DEBUG-AVATAR","Pose #" + (string)(i+1) + " (" + poseName + ") added: " + llDumpList2String(tmpList, ","));
                tmpList += poseName;
            }
        }
    }

    debugSay(6,"DEBUG-AVATAR","Pose list contains: " + llDumpList2String(tmpList, ","));
    if (buildList)
        cdSayTo("Read complete: found " + (string)llGetListLength(tmpList) + " viable poses.",id);

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

    debugSay(6,"DEBUG-AVATAR","Pose list contains: " + llDumpList2String(tmpList, ","));
    poseCount = llGetListLength(poseList);
    debugSay(4,"DEBUG-AVATAR","Found " + (string)poseCount + " poses");

    debugSay(4,"DEBUG-AVATAR","Now on page " + (string)posePage + " and index " + (string)poseIndex);
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
    debugSay(6,"DEBUG-AVATAR","Pose list contains: " + llDumpList2String(tmpList, ","));

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

            debugSay(2,"DEBUG-ANIM","Animations list not as expected: " + llDumpList2String(animList,","));
            debugSay(2,"DEBUG-ANIM","Animation key = " + (string)animKey);
            debugSay(2,"DEBUG-ANIM","Animation = " + keyAnimation);

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

                // Other animations are trying to "get in"; make note of it
                upRefresh = 1;

                i = llGetListLength(animList);
                while (i--) {
                    animKeyI = llList2Key(animList, i);

                    if (animKeyI != animKey) llStopAnimation(animKeyI);
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

            if (lowScriptMode) animRefreshRate = 10.0;
            else animRefreshRate = 8.0;
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

        if (upRefresh) {
            // We found our animation being interfered with; cut the refreshRate
            // so that we run more often: and "fight back" for our animation
            animRefreshRate /= 2.0;                                     // -50%

            if (animRefreshRate < cdMinRefresh())
                animRefreshRate = cdMinRefresh();                   // Minimum amount of time (by Frames)
            upRefresh = 0;
        }
        else {
            // No interference - so run less often
            if (lowScriptMode) {
                animRefreshRate += cdAddRefresh();
                if (animRefreshRate > 30.0) animRefreshRate = 30.0;
            }
            else {
                animRefreshRate *= 1.3; // Note this converts a linear increase to a geometric increase
                if (animRefreshRate > 60.0) animRefreshRate = 60.0;
            }
        }
    }

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
        // FIXME: llRequestPermissions runs this function: means a double run if PERMISSION_MASK is off-kilter
        llRequestPermissions(dollID, PERMISSION_MASK);
        return;
        }

    if (grantorID == NULL_KEY) return;

    // only way to get here is grantorID is dollID

    //----------------------------------------
    // PERMISSION_TRIGGER_ANIMATION

    if (permMask & PERMISSION_TRIGGER_ANIMATION) {

        //animList = llGetAnimationList(dollID);

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
        llSetStatus(STATUS_PHYSICS,TRUE);

        debugSay(2,"DEBUG-AVATAR","ifPermissions (on_rez)");
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
            if (llGetParcelFlags(llGetPos()) & PARCEL_FLAG_ALLOW_SCRIPTS) msg += "does not allow scripts";
            else msg += "allows scripts";

            debugSay(2,"DEBUG-AVATAR",msg);
            debugSay(2,"DEBUG-AVATAR","Region FPS: " + formatFloat(llGetRegionFPS(),1) + "; Region Time Dilation: " + formatFloat(llGetRegionTimeDilation(),3));
            debugSay(2,"DEBUG-AVATAR","ifPermissions (changed)");
#endif
            ifPermissions();
        }
        else if (change & CHANGED_INVENTORY) {
            poseList = [];
            poseCount = llGetInventoryNumber(INVENTORY_ANIMATION);
            i = poseCount;
            while (i--) {
                // This takes time:
                poseName = llGetInventoryName(INVENTORY_ANIMATION, i);
                debugSay(6,"DEBUG-AVATAR","Pose #" + (string)(i+1) + " (" + poseName + ") found: " + llDumpList2String(poseList, ","));

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

        llStopMoveToTarget();
        llTargetRemove(targetHandle);

        if (id) {
            ifPermissions();

#ifdef DEVELOPER_MODE
            debugSay(2,"DEBUG-AVATAR","Region FPS: " + formatFloat(llGetRegionFPS(),1) + "; Region Time Dilation: " + formatFloat(llGetRegionTimeDilation(),3));
            debugSay(2,"DEBUG-AVATAR","ifPermissions (attach)");
#endif
            ifPermissions();
        }

        newAttach = (lastAttachedID != dollID);
        lastAttachedID = id;

        poseList = [];
        poseCount = llGetInventoryNumber(INVENTORY_ANIMATION);
        i = poseCount;
        while (i--) {
            // This takes time:
            poseName = llGetInventoryName(INVENTORY_ANIMATION, i + 1);
            debugSay(6,"DEBUG-AVATAR","Adding pose #" + (string)i + " (" + poseName + "): " + llDumpList2String(poseList, ","));

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

        scaleMem();

        if (code == CONFIG) {
            name = llList2String(split, 0);
            value = llList2String(split, 1);
            split = llDeleteSubList(split, 0, 0);

            if (name == "carrierID") {
                carrierID = (key)value;
                hasCarrier = cdCarried();
            }
            else if (name == "afk")                         afk = (integer)value;
            else if (name == "collapsed") {
                    collapsed = (integer)value;

                    if (collapsed) keyAnimation = ANIMATION_COLLAPSED;
                    else if (cdCollapsedAnim()) keyAnimation = "";
                    lmSendConfig("keyAnimation", keyAnimation);

                    debugSay(2,"DEBUG-AVATAR","ifPermissions (link_message 300/collapsed)");
                    ifPermissions();
            }
            else if (name == "poseSilence")         poseSilence = (integer)value;
            else if (name == "hardcore")               hardcore = (integer)value;
            else if (name == "userBaseRLVcmd")   userBaseRLVcmd = value;
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

                debugSay(2,"DEBUG-AVATAR","ifPermissions (link_message 300/keyAnimation)");
                ifPermissions();
            }
            else if (name == "poserID")                 poserID = (key)value;
            else {
                     if (name == "detachable")               detachable = (integer)value;
#ifdef DEVELOPER_MODE
                else if (name == "debugLevel")               debugLevel = (integer)value;
#endif
                else if (name == "lowScriptMode")         lowScriptMode = (integer)value;
                else if (name == "quiet")                         quiet = (integer)value;
                else if (name == "allowPose")                 allowPose = (integer)value;
                //else if (name == "barefeet")                   barefeet = value;
                else if (name == "dollType")                   dollType = value;
                else if (name == "controllers") {
                    if (split == [""]) controllers = [];
                    else controllers = split;
                }
                else if (name == "pronounHerDoll")       pronounHerDoll = value;
                else if (name == "pronounSheDoll")       pronounSheDoll = value;
                else if (name == "dialogChannel") {
                    dialogChannel = (integer)value;
                    poseChannel = dialogChannel - 777;
                }
                else if (name == "keyAnimationID")       keyAnimationID = (key)value;

                return;
            }

            debugSay(2,"DEBUG-AVATAR","ifPermissions (link_message 300)");
            ifPermissions();
        }
        else if (code == INTERNAL_CMD) {
            string cmd = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "detach") {
                if (RLVok == TRUE) llOwnerSay("@clear,detachme=force");
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

                // We separate this out for two reasones: a) saves space; b) separates the RLV
                // processes so we can be sure this runs after the stripping process
                //if (barefeet != "") lmRunRLVas("Dress","attachallover:" + barefeet + "=force,");

                lmInternalCommand("strip", "", id);
            }
#endif
            else if (choice == "Carry") {
                lmSendConfig("carrierID", (string)(carrierID = id));
                lmSendConfig("carrierName", (carrierName = name));

                if (!quiet) llSay(0, "Dolly " + dollName + " has been picked up by " + carrierName);
                else {
                    llOwnerSay("You have been picked up by " + carrierName);
                    llRegionSayTo(carrierID, 0, "You have picked up the doll " + dollName);
                }
            }
            else if (choice == "Uncarry") {
                if (cdIsCarrier(id)) {
                    if (quiet) cdSayTo("You were carrying " + dollName + " and have now placed them down.", carrierID);
                    else llSay(0, "Dolly " + dollName + " has been placed down by " + carrierName);
                }
                else {
                    string name = llKey2Name(id);

                    if (name) {
                        if (quiet) cdSayTo("You have wrestled Dolly away from " + carrierName + ".", id);
                        else llSay(0, "Dolly " + dollName + " has been wrestled away from " + carrierName + " by " + llKey2Name(id));
                    }
                    else {
                        if (quiet) cdSayTo("You have wrestled Dolly away from " + carrierName + ".", id);
                        else llSay(0, "Dolly " + dollName + " has been wrestled away from " + carrierName);
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
                debugSay(2,"DEBUG-AVATAR","pose " + choice + " selected...");

                // The Real Meat: We have an animation (pose) name
                lmSendConfig("keyAnimation", (string)(keyAnimation = choice));
                lmSendConfig("poserID", (string)(poserID = id));
                if (dollType != "Display" && !hardcore)
                    lmSetConfig("poseExpire", (string)(llGetUnixTime() + POSE_TIMEOUT));
                else
                    lmSetConfig("poseExpire", "0");

                oneAnimation();
                if (poseSilence || hardcore) lmRunRLV("sendchat=n");
            }
        }
        else if (code == RLV_RESET) {
            RLVok = (llList2Integer(split, 1) == 1);
        }
        else if (code < 200) {
            if (code == 110) {
                debugSay(2,"DEBUG-AVATAR","ifPermissions (link_message 110)");

                ifPermissions();
                oneAnimation();
            }
            else if (code == MEM_REPORT) {
                memReport("Avatar",llList2Float(split,0));
            }
            else if (code == CONFIG_REPORT) {
                cdConfigureReport();
            }
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
        if (clearAnim) clearAnimations();
        else if (cdAnimated()) oneAnimation(); 

        llSetTimerEvent(animRefreshRate);

#ifdef DEVELOPER_MODE
        thisTimerEvent = llGetTime();

        if (lastTimerEvent) {
            timerInterval = thisTimerEvent - lastTimerEvent;
            if (timeReporting) llOwnerSay("Avatar Timer fired, interval " + formatFloat(timerInterval,2) + "s.");
        }
        lastTimerEvent = thisTimerEvent;
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
