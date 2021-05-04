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
#define cdAOoff() llWhisper(LOCKMEISTER_CHANNEL,(string)dollID+"bootoff")
#define cdAOon()  llWhisper(LOCKMEISTER_CHANNEL,(string)dollID+"booton")
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
#define cdMenuInject(a,b,c) lmMenuReply((a),b,c);

key rlvTPrequest;
#ifdef LOCKON
key mainCreator;
#endif
key lastAttachedID;

// Note that this is not the "speed" nor is it a slowing factor
// This is a vector of force applied against Dolly: headwind speed
// is a good way to think of it
float afkSlowWalkSpeed = 30;

// Note that this is just a starting point; timerRate is adaptive
float timerRate = 30.0;

string msg;
string name;
string value;

#ifdef DEVELOPER_MODE
string myPath;
#endif

integer i;
integer posePage;
integer timerMark;
integer lastTimerMark;
integer carryExpire;
integer timeMark;
integer reachedTarget = FALSE;
integer hasCarrier;
integer nearCarrier;

// This acts as a cache of
// current poses in inventory
list poseBufferedList;
integer poseCount;

integer poseChannel;

key grantorID;
integer permMask;

integer locked;
integer targetHandle;
integer newAttach = 1;

//========================================
// FUNCTIONS [CARRY]
//========================================
//
// Because of the importance of these, and the possibility of different methods
// of performing these functions, these have been separated out.
//
// Functions:
//     * startFollow(id)
//     * keepFollow(id)
//     * stopFollow(id)
//     * drunkardsWalk()
//     * dropCarrier(id)
//
// Follow is begun either by the setting of the Carrier ID or by the Dolly
// being unposed. The latter is because Dolly could be carried and posed;
// when put down, Dolly follows. Before that, Dolly is static and in pose.

#define TURN_TOWARDS

#include "include/Follow.inc" // Uses timer + llMoveToTarget()
//#include "include/Follow2.inc" // Uses llTarget and llMoveToTarget

//========================================
// FUNCTIONS
//========================================

float adjustTimer() {
    float x;

    if (hasCarrier) {
        if (nearCarrier) x = 2.0;
        else x = 0.5;
    }
    else {
        if (lowScriptMode) x = 60.0;
        else x = 30.0;
    }

    return x;
}

posePageN(string choice, key id) {
    integer poseIndex;
    list tmpList;
    integer isDoll = cdIsDoll(id);
    integer isController = cdIsController(id);
    string poseEntry;
    integer foundCollapse;

    poseCount = llGetInventoryNumber(INVENTORY_ANIMATION);
    if (poseCount < 2) {
        // we need at least 2 animations:
        // collapse + pose
        llSay(DEBUG_CHANNEL,"No animations!");
        return;
    }

    // Create the poseBufferedList and tmpList... tmpList is for the dialog
    if (poseBufferedList == []) {

        i = poseCount; // loopIndex

        while (i--) {
            // Build list of poses
            poseEntry = llGetInventoryName(INVENTORY_ANIMATION, i);

            if (poseEntry != ANIMATION_COLLAPSED) {
                poseBufferedList += poseEntry;
                if (poseEntry != poseAnimation) tmpList += poseEntry;
            }
            else {
                foundCollapse = TRUE;
            }
        }

        if (foundCollapse) poseCount--;
        else llSay(DEBUG_CHANNEL,"No collapse animation found!");
    }
    else {
        // since we dont have to build the poseBufferedList, remove the current
        // pose if any to create tmpList
        if (poseAnimation != ANIMATION_NONE) {
            if (~(i = llListFindList(poseBufferedList, [ poseAnimation ]))) {
                tmpList = llDeleteSubList(poseBufferedList, i, i);
            }
        }
        else {
            poseBufferedList = tmpList;
        }
    }


    // Now handle the specific dialog choice made, using tmpList
    //
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

    debugSay(4,"DEBUG-AVATAR","Found " + (string)poseCount + " poses");
    debugSay(4,"DEBUG-AVATAR","tmpList = " + llDumpList2String(tmpList,","));

    tmpList = llListSort(tmpList, 1, 1);
    if (poseCount > 9) {
        // Get a 9-count slice from tmpList for dialog
        tmpList = llList2List(tmpList, poseIndex, poseIndex + 8) + [ "Poses Prev", "Poses Next" ];
    }
    else {
        tmpList += [ "-", "-" ];
    }

    debugSay(4,"DEBUG-AVATAR","tmpList (revised) = " + llDumpList2String(tmpList,","));

    lmSendConfig("backMenu",(backMenu = MAIN));
    tmpList += [ "Back..." ];

    msg = "Select the pose to put dolly into";
    if (poseAnimation) msg += " (current pose is " + poseAnimation + ")";

    llDialog(id, msg, dialogSort(tmpList), poseChannel);
}

key startAnimation(string anim) {
    list oldAnimList;
    list newAnimList;
    integer oldAnimListLen;
    integer newAnimListLen;
    key animKey;
    integer j;

    if (anim == ANIMATION_NONE) return NULL_KEY;

    if ((llGetPermissionsKey() != dollID) || (!(llGetPermissions() & PERMISSION_TRIGGER_ANIMATION)))
        return NULL_KEY;

#ifdef NOT_USED
    oldAnimList = llGetAnimationList(dollID);
    oldAnimListLen = llGetListLength(oldAnimList);
    i = oldAnimListLen;

    // Stop all animations
    while (i--)
        llStopAnimation(llList2Key(oldAnimList, i));

    i = oldAnimListLen;
#endif

    // We need the key of the animation, but this method only works on full perm animations
    //key animID = llGetInventoryKey(anim);
    llStartAnimation(anim);
    return llList2String(llGetAnimationList(llGetPermissionsKey()), -1);

#ifdef NOT_USED
    // Find the key
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
        llSay(DEBUG_CHANNEL,"Animation (" + anim + ") start failed!");

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
#endif
}

clearAnimation() {
    list animList;
    key animKey;

    // Clear all animations

    // Get list of all current animations
    animList = llGetAnimationList(dollID);
    animKey = NULL_KEY;

    i = llGetListLength(animList);

    // Clear current saved animation if any
    poseAnimation = ANIMATION_NONE;
    poseAnimationID = NULL_KEY;

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

    if (hasCarrier) keepFollow(carrierID);
    llSetTimerEvent(timerRate = adjustTimer());
    cdAOon();
}

setAnimation(string anim) {
    key animKey;

    //integer upRefresh;

    // Strip down to a single animation (poseAnimation)

    cdAOoff();

    // Already animated: stop it first
    if (poseAnimationID != NULL_KEY) {
        llStopAnimation(poseAnimationID);
        poseAnimationID = NULL_KEY;
        poseAnimation = ANIMATION_NONE;
    }

    animKey = startAnimation(anim);

    if (animKey != NULL_KEY) {
        // We have an actual pose...
        poseAnimationID = animKey;
        poseAnimation = anim;

        // Stop following carrier if we have one
        if (hasCarrier) {
            // Stop following carrier, and freeze
            stopFollow(carrierID);
        }

        // This adjusts the refresh rate
        llSetTimerEvent(timerRate = adjustTimer());
    }
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
    //   * link_message 300/poseAnimation
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

    //grantorID = llGetPermissionsKey();
    permMask = llGetPermissions();

    // If permissions granted to someone other than Dolly,
    // start over...
    //if (grantorID != dollID) {
    //   if (grantorID) cdResetKey();
    //}

    //if ((permMask & PERMISSION_MASK) != PERMISSION_MASK) {
    //    // llRequestPermissions runs this function: means a double run if PERMISSION_MASK is off-kilter
    //    llRequestPermissions(dollID, PERMISSION_MASK);
    //    return;
    //    }

    //if (grantorID == NULL_KEY) return;

    // only way to get here is grantorID is dollID

    //----------------------------------------
    // PERMISSION_TRIGGER_ANIMATION

    if (permMask & PERMISSION_TRIGGER_ANIMATION) {

        // The big work is done in clearAnimation() and in
        // setAnimation()

        if (poseAnimation == ANIMATION_NONE)
            clearAnimation();
        else
            setAnimation(poseAnimation); 

        llSetTimerEvent(timerRate = adjustTimer());
    }

    //----------------------------------------
    // PERMISSION_TAKE_CONTROLS

    if (permMask & PERMISSION_TAKE_CONTROLS) {

        if (poseAnimation != ANIMATION_NONE)
            // Dolly is "frozen": either collapsed or posed

            // When collapsed or posed the doll should not be able to move at all; so the key will
            // accept their attempts to move, but ignore them
            llTakeControls(ALL_CONTROLS, TRUE, FALSE);

        else {
            // Dolly is not collapsed nor posed

            // We do not want to completely release the controls in case the current sim does not
            // allow scripts. If controls were released, key scripts would stop until entering a
            // script-enabled sim
            llTakeControls(ALL_CONTROLS, FALSE, TRUE);
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
        llRequestPermissions(dollID, PERMISSION_MASK);
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
            llRequestPermissions(dollID, PERMISSION_MASK);
        }
        else if (change & CHANGED_INVENTORY) {
            // Doing this whenever inventory changes is ok: the update process stops this script;
            // otherwise, the only cost is time.
            string poseEntry;
            poseBufferedList = [];
            poseCount = llGetInventoryNumber(INVENTORY_ANIMATION);

            i = poseCount;
            debugSay(4,"DEBUG-AVATAR","Refreshing list of poses on inventory change");

            while (i--) {
                // This takes time:
                poseEntry = llGetInventoryName(INVENTORY_ANIMATION, i);
                //debugSay(6,"DEBUG-AVATAR","Pose #" + (string)(i+1) + " found: " + poseEntry);

                // Collect all viable poses: skip the collapse animation
                if (poseEntry != ANIMATION_COLLAPSED)
                    poseBufferedList += poseEntry;
            }

            poseBufferedList = llListSort(poseBufferedList, 1, 1);
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

        debugSay(2,"DEBUG-FOLLOW","dropCarrier(): from attach");
        dropCarrier(carrierID);

        if (id) {
#ifdef DEVELOPER_MODE
            debugSay(2,"DEBUG-AVATAR","Region FPS: " + formatFloat(llGetRegionFPS(),1) + "; Region Time Dilation: " + formatFloat(llGetRegionTimeDilation(),3));
            debugSay(5,"DEBUG-AVATAR","ifPermissions (attach)");
#endif
            llRequestPermissions(dollID, PERMISSION_MASK);
        }

        newAttach = (lastAttachedID != dollID);
        lastAttachedID = id;

        debugSay(4,"DEBUG-AVATAR","Checking poses on attach");

        string poseEntry;
        poseBufferedList = [];
        poseCount = llGetInventoryNumber(INVENTORY_ANIMATION);
        i = poseCount;
        while (i--) {
            // This takes time:
            poseEntry = llGetInventoryName(INVENTORY_ANIMATION, i + 1);
            debugSay(6,"DEBUG-AVATAR","Adding pose #" + (string)i + ": " + poseEntry);

            // Collect all viable poses: skip the collapse animation
            if (poseEntry != ANIMATION_COLLAPSED)
                poseBufferedList += poseEntry;
        }
        poseBufferedList = llListSort(poseBufferedList, 1, 1);

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

                 if (name == "collapsed") {
                    collapsed = (integer)value;

                    debugSay(5,"DEBUG-AVATAR","ifPermissions (link_message 300/collapsed)");
                    llRequestPermissions(dollID, PERMISSION_MASK);
            }
            else if (name == "poseSilence")         poseSilence = (integer)value;
            else if (name == "carryExpire")         carryExpire = (integer)value;
            else if (name == "hardcore")               hardcore = (integer)value;
#ifdef DEVELOPER_MODE
            else if (name == "timeReporting")     timeReporting = (integer)value;
#endif
            else if (name == "poseAnimation") {
                // Note that poses are handled as a choice... not here
                poseAnimation = value;
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

                return;
            }

            //debugSay(5,"DEBUG-AVATAR","ifPermissions (link_message 300)");
            llRequestPermissions(dollID, PERMISSION_MASK);
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
                setCarrier(id);
                llSay(PUBLIC_CHANNEL, "Dolly " + dollName + " has been picked up by " + carrierName);
                startFollow(carrierID);
            }
            else if (choice == "Uncarry") {
                llSay(PUBLIC_CHANNEL, "Dolly " + dollName + " has been placed down by " + carrierName);

                debugSay(2,"DEBUG-FOLLOW","dropCarrier(): from Uncarry button");
                dropCarrier(carrierID);
            }

            // Unpose: remove animation and poser
            else if (choice == "Unpose") {
                lmSendConfig("poseAnimation", (string)(poseAnimation = ANIMATION_NONE));
                lmSendConfig("poserID", (string)(poserID = NULL_KEY));

                // poseExpire is being set elsewhere
                lmSetConfig("poseExpire", "0");

                llRequestPermissions(dollID, PERMISSION_MASK); // animates
                if (poseSilence || hardcore) lmRunRLV("sendchat=y");

                // if we have carrier, start following them again
                debugSay(2,"DEBUG-FOLLOW","startFollow(): from Unpose button");
                if (hasCarrier) startFollow(carrierID);
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
                // None of the other choices are valid: it's a pose
                string expire;

                llSay(PUBLIC_CHANNEL,"Pose " + choice + " selected.");

                if (poseAnimationID != NULL_KEY) {
                    llStopAnimation(poseAnimationID);
                    debugSay(4,"DEBUG-AVATAR","Stopping old animation " + poseAnimation + " (" + (string)poseAnimationID + ")");
                }

                // The Real Meat: We have an animation (pose) name
                lmSendConfig("poseAnimation", (string)(poseAnimation = choice));
                lmSendConfig("poserID", (string)(poserID = id));

                debugSay(5,"DEBUG-AVATAR","ifPermissions (link_message 300/poseAnimation)");
                llRequestPermissions(dollID, PERMISSION_MASK); // starts animations

                if (dollType == "Display" || hardcore) expire = "0";
                else expire = (string)(llGetUnixTime() + POSE_TIMEOUT);
                lmSetConfig("poseExpire", expire);

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
                setAnimation("");
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

        if (hasCarrier) keepFollow(carrierID);
        llRequestPermissions(dollID, PERMISSION_MASK); // animates

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
