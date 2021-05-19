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
#define notCurrentAnimation(p) ((p) != poseAnimation)
#define getAnimationName(n) llGetInventoryName(INVENTORY_ANIMATION, (n));
#define getAnimationCount() llGetInventoryNumber(INVENTORY_ANIMATION);

#define MIN_FRAMES 20
#define ADD_FRAMES 20
#define cdMinRefresh() ((1.0/llGetRegionFPS()) * MIN_FRAMES)
#define cdAddRefresh() ((1.0/llGetRegionFPS()) * ADD_FRAMES)
#define cdMenuInject(a,b,c) lmMenuReply((a),b,c);
#define currentlyPosed(p) ((p) != ANIMATION_NONE)
#define notCurrentlyPosed(p) ((p) == ANIMATION_NONE)
#define poseChanged (currentAnimation != poseAnimation)
#define keyDetached(id) (id == NULL_KEY)

key rlvTPrequest;

// Note that this is not the "speed" nor is it a slowing factor
// This is a vector of force applied against Dolly: headwind speed
// is a good way to think of it
float afkSlowWalkSpeed = 30;

// Note that this is just a starting point; timerRate is adaptive
float timerRate = 30.0;

string msg;
string name;
string value;
string currentAnimation;

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
//integer newAttach = 1;

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

#define LOW_SPEED_CARRY_RATE 15.0
#define HI_SPEED_CARRY_RATE 0.5
#define LOW_SCRIPT_RATE 60.0
#define NORMAL_RATE 30.0

    if (hasCarrier) {
        if (nearCarrier) return LOW_SPEED_CARRY_RATE;
        else return HI_SPEED_CARRY_RATE;
    }
    else {
        if (lowScriptMode) return LOW_SCRIPT_RATE;
        else return NORMAL_RATE;
    }
}

bufferPoses() {
    string poseEntry;
    integer foundCollapse;

    poseCount = getAnimationCount();

    if (arePosesPresent() == FALSE) {
        llSay(DEBUG_CHANNEL,"No animations! (must have collapse animation and one pose minimum)");
        return;
    }

    i = poseCount; // loopIndex

    while (i--) {
        // Build list of poses
        poseEntry = getAnimationName(i);

        if (poseEntry != ANIMATION_COLLAPSED) poseBufferedList += poseEntry;
        else foundCollapse = TRUE;
    }

    if (foundCollapse == FALSE) {
        llSay(DEBUG_CHANNEL,"No collapse animation (\"" + (string)(ANIMATION_COLLAPSED) + "\") found!");
        return;
    }

    poseBufferedList = llListSort(poseBufferedList,1,1);
}

posePageN(string choice, key id) {
    // posePage is the number of the page of poses;
    // poseIndex is a direct index into the list of
    // poses
    //
    integer poseIndex;

    list poseDialogButtons;
    integer isDoll = cdIsDoll(id);
    integer isController = cdIsController(id);

    debugSay(4,"DEBUG-AVATAR","poseBufferedList = " + llDumpList2String(poseBufferedList,","));
    debugSay(4,"DEBUG-AVATAR","poseCount = " + (string)poseCount);

    // Create the poseBufferedList and poseDialogButtons...
    if (poseBufferedList == []) bufferPoses();

    // remove the current pose if any to create poseDialogButtons
    if (currentlyPosed(poseAnimation)) {

        // If this was false, it would mean we have a poseAnimation that is
        // not in the Key's inventory...
        if (~(i = llListFindList(poseBufferedList, [ poseAnimation ]))) {

            poseDialogButtons = llDeleteSubList(poseBufferedList, i, i);

        }
    }
    else {
        poseDialogButtons = poseBufferedList;
    }

#define MAX_DIALOG_BUTTONS 9
#define numberOfDialogPages(p) (llFloor((p) / MAX_DIALOG_BUTTONS) + 1)
#define indexOfPage(p) (((p) - 1) * MAX_DIALOG_BUTTONS)

    list bottomDialogLine;

#ifdef ROLLOVER
    bottomDialogLine = [ "Poses Prev", "Poses Next" ];
#endif

    // Now select the appropriate slice of the total list, showing nine buttons
    // at a time
    //
    if (choice == "Poses Next") {
        posePage++;
        poseIndex = indexOfPage(posePage);

        if (poseIndex > poseCount) {
            // We've gone past the end of the list of poses...
#ifdef ROLLOVER
            // Reset to page one and continue
            posePage = 1;
            poseIndex = 0;
#else
            posePage--; // backtrack
            poseIndex = indexOfPage(posePage); // recompute
            bottomDialogLine = [ "Poses Prev", "-" ];
#endif
        }
    }
    else if (choice == "Poses Prev") {
        posePage--;

        if (posePage == 0) {
            // We've gone past the first entry in the list of poses
#ifdef ROLLOVER
            // Reset to the last page and continue
            posePage = numberOfDialogPages(poseCount);
            poseIndex = indexOfPage(posePage);
#else
            posePage = 1;
            poseIndex = 0;
            bottomDialogLine = [ "-", "Poses Next" ];
#endif
        }
    }

    debugSay(4,"DEBUG-AVATAR","Found " + (string)poseCount + " poses");
    debugSay(4,"DEBUG-AVATAR","Page = " + (string)posePage + "; Index = " + (string)poseIndex);
    debugSay(4,"DEBUG-AVATAR","poseDialogButtons = " + llDumpList2String(poseDialogButtons,","));

    poseDialogButtons = llListSort(poseDialogButtons, 1, 1);

    if (poseCount > MAX_DIALOG_BUTTONS) {
        // Get a 9-count slice from poseDialogButtons for dialog
        poseDialogButtons = (list)poseDialogButtons[poseIndex, poseIndex + 8] + bottomDialogLine + [ "Back..." ];
    }
    else {
        // Can display all poses on one page
        //
        // Note that if we get here, it is impossible for the Next and Prev sections to run: first time around,
        // they aren't options; second time around, we get here and don't offer the options.
        //
        // Note too, that even with ROLLOVER nothing other than ignoring Forward and Backwards makes sense.
        //
        poseDialogButtons += [ "-", "-", "Back..." ];
    }

    debugSay(4,"DEBUG-AVATAR","poseDialogButtons (revised) = " + llDumpList2String(poseDialogButtons,","));

    lmSendConfig("backMenu",(backMenu = MAIN));

    msg = "Select the pose to put dolly into";
    if (poseAnimation) msg += " (current pose is " + poseAnimation + ")";

    llDialog(id, msg, dialogSort(poseDialogButtons), poseChannel);
}

clearPoseAnimation() {
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
        animKey = (key)animList[i];
        if (animKey) llStopAnimation(animKey);
    }

    llSay(99,"stop"); // Turns off dances: customarily on channel 99

    // Reset current animations
    llStartAnimation("Stand");

    if (hasCarrier) keepFollow(carrierID);
    llSetTimerEvent(timerRate = adjustTimer());
    cdAOon();
}

setPoseAnimation(string anim) {
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

    if (notCurrentlyPosed(anim)) return;

    //if ((llGetPermissionsKey() != dollID) || (!(llGetPermissions() & PERMISSION_TRIGGER_ANIMATION)))
    //    return NULL_KEY;

    // We need the key of the animation, but this method only works on full perm animations
    //key animID = llGetInventoryKey(anim);
    llStartAnimation(anim);

    // We cant use lazy lists here, as this is a *generated* list not a named list
    list animList = llGetAnimationList(llGetPermissionsKey());
    animKey = (string)animList[-1];

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
        myName = llGetScriptName();
    }

    //----------------------------------------
    // ON REZ
    //----------------------------------------
    on_rez(integer start) {
        // Set up key when rezzed

        //RLVok = UNSET;
        //llStopMoveToTarget();
        //llTargetRemove(targetHandle);

        //debugSay(5,"DEBUG-AVATAR","ifPermissions (on_rez)");
        //llRequestPermissions(dollID, PERMISSION_MASK);
    }

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    changed(integer change) {
        if (change & CHANGED_INVENTORY) {
            poseBufferedList = [];
            bufferPoses();
        }
#ifdef DEVELOPER_MODE
        else if (change & (CHANGED_REGION | CHANGED_TELEPORT)) {
            // related to follow
            //llStopMoveToTarget();
            //llTargetRemove(targetHandle);

            msg = "Region ";
            if (llGetParcelFlags(llGetPos()) & PARCEL_FLAG_ALLOW_SCRIPTS) msg += "allows scripts";
            else msg += "does not allow scripts";

            debugSay(3,"DEBUG-AVATAR",msg);
            debugSay(3,"DEBUG-AVATAR","Region FPS: " + formatFloat(llGetRegionFPS(),1) + "; Region Time Dilation: " + formatFloat(llGetRegionTimeDilation(),3));
            //debugSay(5,"DEBUG-AVATAR","ifPermissions (changed)");
            //llRequestPermissions(dollID, PERMISSION_MASK);
        }
#endif
    }

    //----------------------------------------
    // ATTACH
    //----------------------------------------
    // During attach, we perform:
    //
    //     * drop carrier
    //     * read poses into buffered List
    //
    attach(key id) {

        if (keyDetached(id)) return;

        RLVok = UNSET;

        debugSay(2,"DEBUG-FOLLOW","dropCarrier(): from attach");
        dropCarrier(carrierID);

        if (id) {
#ifdef DEVELOPER_MODE
            debugSay(2,"DEBUG-AVATAR","Region FPS: " + formatFloat(llGetRegionFPS(),1) + "; Region Time Dilation: " + formatFloat(llGetRegionTimeDilation(),3));
            debugSay(5,"DEBUG-AVATAR","ifPermissions (attach)");
#endif
            llRequestPermissions(dollID, PERMISSION_MASK);
        }

        //newAttach = (lastAttachedID != dollID);
        //lastAttachedID = id;

        debugSay(4,"DEBUG-AVATAR","Checking poses on attach");

        poseBufferedList = [];
        bufferPoses();
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
            value = (string)split[1];
            split = llDeleteSubList(split, 0, 0);

                 if (name == "collapsed") {
                    collapsed = (integer)value;

                    // Reset pose?
                    llRequestPermissions(dollID, PERMISSION_MASK);

                    llSetTimerEvent(timerRate = adjustTimer());
            }
            else if (name == "poseSilence")         poseSilence = (integer)value;
            else if (name == "carryExpire")         carryExpire = (integer)value;
            else if (name == "carrierID")             carrierID = value;
            else if (name == "RLVok")                     RLVok = (integer)value;
            else if (name == "carrierName")         carrierName = value;
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
                     //if (name == "detachable")               detachable = (integer)value;
                     if (name == "lowScriptMode")         lowScriptMode = (integer)value;
#ifdef DEVELOPER_MODE
                else if (name == "debugLevel")               debugLevel = (integer)value;
#endif
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
            //llRequestPermissions(dollID, PERMISSION_MASK);
        }
        else if (code == INTERNAL_CMD) {
            string cmd = (string)split[0];
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "detach") {
                if (RLVok == TRUE) { lmRunRLVcmd("clearRLVcmd","detachme=force"); }
                else llDetachFromAvatar();
            }
            else if (cmd == "teleport") {
                string lm = (string)split[0];
                llRegionSayTo(id, 0, "Teleporting dolly " + dollName + " to  landmark " + lm + ".");
                rlvTPrequest = llRequestInventoryData(lm);
            }
            else if (cmd == "posePageN") {
                string choice = (string)split[0];
                posePageN(choice,id);
            }
            else if (cmd == "startFollow") {
                startFollow(carrierID);
            }
            else if (cmd == "stopFollow") {
                stopFollow(carrierID);
            }
        }
        else if (code == MENU_SELECTION) {
            string choice = (string)split[0];
            string choice5 = llGetSubString(choice,0,4);
            string name = (string)split[1];

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

                clearPoseAnimation();

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
                lmDialogListen();
                lmInternalCommand("posePageN",choice, id);
            }
        }
        else if (code == POSE_SELECTION) {
            string choice = (string)split[0];

            // it could be Poses Next or Poses Prev instead of an Anim
            if (choice == "Poses Next" || choice == "Poses Prev") {
                lmDialogListen();
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

                //debugSay(5,"DEBUG-AVATAR","ifPermissions (link_message 300/poseAnimation)");
                setPoseAnimation(poseAnimation); 

                if (dollType == "Display" || hardcore) expire = "0";
                else expire = (string)(llGetUnixTime() + POSE_TIMEOUT);
                lmSetConfig("poseExpire", expire);

                if (poseSilence || hardcore) lmRunRLV("sendchat=n");
            }
        }
        else if (code == RLV_RESET) {
            RLVok = (integer)split[0];
        }
        else if (code < 200) {
            if (code == INIT_STAGE5) {
                //debugSay(5,"DEBUG-AVATAR","ifPermissions (link_message 110)");

                poseAnimation = ANIMATION_NONE;
                poseAnimationID = NULL_KEY;
                clearPoseAnimation();
            }
#ifdef DEVELOPER_MODE
            else if (code == MEM_REPORT) {
                memReport("Avatar",(float)split[0]);
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
        //llRequestPermissions(dollID, PERMISSION_MASK); // animates

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

#define getRegionLocation(d) (llGetRegionCorner() + ((vector)data))
#define locationToString(d) ((string)(llFloor(d.x)) + "/" + ((string)(llFloor(d.y))) + "/" + ((string)(llFloor(d.z))))

        if (request == rlvTPrequest) {
            vector global = getRegionLocation(data);

            llOwnerSay("Dolly is now teleporting.");

            // Note this will be rejected if @unsit=n or @tploc=n are active
            lmRunRLVas("TP", "tpto:" + locationToString(global) + "=force");
        }
    }

    //----------------------------------------
    // RUN TIME PERMISSIONS
    //----------------------------------------
    run_time_permissions(integer perm) {
        debugSay(2,"DEBUG-AVATAR","ifPermissions (run_time_permissions)");

        // Don't do anything unless attached
        if (!llGetAttached()) return;

        permMask = perm;

        //----------------------------------------
        // PERMISSION_TRIGGER_ANIMATION

        if (permMask & PERMISSION_TRIGGER_ANIMATION) {

            // The big work is done in clearPoseAnimation() and setPoseAnimation()

            if (poseChanged) {
                if (notCurrentlyPosed(poseAnimation)) clearPoseAnimation();
                else setPoseAnimation(poseAnimation); 
                currentAnimation = poseAnimation;
            }

            llSetTimerEvent(timerRate = adjustTimer());
        }

        //----------------------------------------
        // PERMISSION_TAKE_CONTROLS

#define disableMovementControl() llTakeControls(ALL_CONTROLS, TRUE, FALSE)
#define enableMovementControl() llTakeControls(ALL_CONTROLS, FALSE, TRUE)

        if (permMask & PERMISSION_TAKE_CONTROLS) {

            if (currentlyPosed(poseAnimation))
                // Dolly is "frozen": either collapsed or posed

                // When collapsed or posed the doll should not be able to move at all; so the key will
                // accept their attempts to move, but ignore them
                disableMovementControl();

            else {
                // Dolly is not collapsed nor posed

                // We do not want to completely release the controls in case the current sim does not
                // allow scripts. If controls were released, key scripts would stop until entering a
                // script-enabled sim
                enableMovementControl();
            }
        }
    }
}

//========== AVATAR ==========
