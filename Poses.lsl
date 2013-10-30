// Poses.lsl
//
// vim:sw=4 et nowrap:
//
// DATE: 7 February 2013
//
// 7 Feb 2013 - First created

//========================================
// VARIABLES
//========================================
// Key for Christina Halpin
key MasterBuilder = "42c7aaec-38bc-4b0c-94dd-ae562eb67e6d";

// Key for GreigHighland
key MasterWinder = "64d26535-f390-4dc4-a371-a712b946daf8";

// Key for MayStone
key DevOne = "c5e11d0a-694f-46cc-864b-e42340890934";

string pose = "beautyStand";
key dollID;
list poses;
integer poselimit = 30;
integer posetime;
string dollType;
integer cd3666;
key toucherId;


//========================================
// FUNCTIONS
//========================================

setControlLock(integer lock) {
    controlLock = lock;
    llRequestPermissions(dollID, PERMISSION_TAKE_CONTROLS|PERMISSION_TRIGGER_ANIMATION);
}

stopAnimation(anim) {

    stopAnim = anim;
    llRequestPermissions(dollID, PERMISSION_TRIGGER_ANIMATION);
}

stopAnimations() {
    list anims = llGetAnimationList(dollID);
    integer len = llGetListLength(anims);
    integer n;
    string anim;

    for ( n = 0; n < len; n++ ) {
        anim = llList2String(anims, n);

        stopAnimation(anim);
        llSleep(0.2);
    }
    llSetColor( <0,1,0>, ALL_SIDES );
}

reloadPoses() {
    integer n = llGetInventoryNumber(20);

    // Max limit of 11...
    //
    // We could expand the limit of 11 - but what for?
    if (n > 11) {
        llOwnerSay("Too many poses! Found " + (string)n + " poses (max is 11)");
        n = 11;
    }

    while(n) {
        string thisPose = llGetInventoryName(20, --n);

        if (thisPose == collapseAnim || llGetSubString(thisPose,1,1) == ".") { // flag pose
            ; // Nothing
        } else {
            poses += thisPose;
        }
    }
}

enterPose() {
    // By requesting permissions, we are activating the Pose
    setControlLock(TRUE);
    enterState("pose");

    setControlLock(TRUE);
    posetime = poselimit;
    pose = TRUE;
    llOwnerSay("You are being posed. Pose will expire in " + (string)(posetime / 6)+ " minutes.");
}

//========================================
// STATES
//========================================
state default {
    state_entry() {
        pose = "";
        dollID = llGetOwner();

        integer ncd = ( -1 * (integer)("0x" + llGetSubString((string)llGetKey(),-5,-1)) ) - 1;

        cd3666 = ncd - 3666;
    }

    link_message(integer source, integer num, string choice, key id) {
        if (num == 16) {
            // stop posing
            stopAnimation(currentAnimation);
            setControlLock(FALSE);

            pose = FALSE;
            aoChange("on");

            // change to new Doll Type
            dollType = choice;

            // new type is Display Doll: select pose and report limits on pose time
            if (dollType == "Display") {
                state posed;
            }

        }
        else if (choice == "pose") {
            state posed;
        }
        else if (num == 22) {
            listen_id_poses = llListen(cd3666,"","","");
            toucherID = id;
            llDialog(toucherID, "Choose a pose", poses, cd3666);
        }
    }
}

state posed {
    //----------------------------------------
    // STATE_ENTRY
    //----------------------------------------
    state_entry () {
        setControlLock(TRUE);
        posetime = poselimit;
        pose = TRUE;
        llOwnerSay("You are being posed. Pose will expire in " + (string)(posetime / 6)+ " minutes.");
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string choice) {
        // channel = chat channel to listen on
        //    name = filter by prim name
        //     key = filter by avatar key
        //  choice = filter by specific message

        if (channel == cd3666) {
            // By requesting permissions, we are activating the Pose
            setControlLock(TRUE);
            posetime = poselimit;
            pose = choice;

            llRequestPermissions(dollID, PERMISSION_TRIGGER_ANIMATION);
            llOwnerSay("You are being posed. Pose will expire in " + (string)(posetime / 6)+ " minutes.");
        }
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {   // called every timeinterval (10s)
        // Display Doll always poses: no pose timeouts for Display Dolls
        if (dollType != "Display") {
            posetime--;

            // When posetime is zero, pose is expired
            if (posetime <= 0) {
                llOwnerSay("Pose " + pose + " has timed out...");
                pose = "";
                posetime = 0;

                stopAnimation(currentAnimation);
                setControlLock(FALSE);

                aoChange("on");
                state default;
            }
        }
    }

    //----------------------------------------
    // PERMISSION GRANTED
    //----------------------------------------
    // This occurs when a permission is accepted
    //
    // The permission may be granted - or denied - but it is
    // not known until we get here
    run_time_permissions(integer perm) {

        //----------------------------------------
        // Permission granted: TRIGGER_ANIMATION
        if (perm & PERMISSION_TRIGGER_ANIMATION) {

            stopAnimations();

            aoChange("off");

            llStartAnimation(pose);
            llOwnerSay("Dolly has now taken on the " + pose + " pose.");
            posetime = poselimit;
        }

        // Permission granted: TAKE_CONTROLS
        else if (perm & PERMISSION_TAKE_CONTROLS) {
            if (controlLock == TRUE) {
                llTakeControls( CONTROL_FWD      | CONTROL_BACK       |
                                CONTROL_LEFT     | CONTROL_RIGHT      |
                                CONTROL_ROT_LEFT | CONTROL_ROT_RIGHT  |
                                CONTROL_UP       | CONTROL_DOWN       |
                                CONTROL_LBUTTON  | CONTROL_ML_LBUTTON,  TRUE, FALSE);
            } else {
                llReleaseControls( );
            }
        }
    }
}

