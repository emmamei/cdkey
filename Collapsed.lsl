// Collapsed.lsl
//
// DATE: 1 April 2013
//
// Collapsed state

//========================================
// VARIABLES
//========================================
// This variable is used to set the collapse animation - and documentation
string collapseAnim = "collapse";
string stopAnim; // which animation to stop?
integer controlLock;
key dollID;
string dollName;

//========================================
// FUNCTIONS
//========================================

setControlLock(integer lock) {
    controlLock = lock;
    llRequestPermissions(dollID, PERMISSION_TAKE_CONTROLS);
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

// This clears ONLY the collapse animation....
restoreFromCollapse() {
    // Rotate key: around Z access at rate .3 and gain 1
    llTargetOmega(<0,0,1>,.3,1.0);

    // Clear animation
    setControlLock(FALSE);
    aoChange("on");
}

aoChange(string choice) {
    integer g_iAOChannel = -782690;
    integer g_iInterfaceChannel = -12587429;

    if (choice == "off" || choice == "stop") {
        string AO_OFF = "ZHAO_STANDOFF";
        llWhisper(g_iInterfaceChannel, "CollarComand|499|" + AO_OFF);
        llWhisper(g_iAOChannel, AO_OFF);
        llMessageLinked(LINK_SET, 0, "ZHAO_AOON", NULL_KEY);
    }
    else {
        string AO_ON = "ZHAO_STANDON";
        llWhisper(g_iInterfaceChannel, "CollarComand|499|" + AO_ON);
        llWhisper(g_iAOChannel, AO_ON);
        llMessageLinked(LINK_SET, 0, "ZHAO_AOON", NULL_KEY);
    }
}

collapse(string s) {
    // Most restrictions handled by Main (including RLV)
    setControlLock(TRUE);

    // Rotation: all stop
    llTargetOmega(ZERO_VECTOR, 0, 0);

    // Key is made visible again when collapsed
    visible = TRUE;
    llSetLinkAlpha(LINK_SET, 1.0, ALL_SIDES);
}

//========================================
// STATES
//========================================
default {
    state_entry() {
        controlLock = FALSE;
        stopAnim = "";
        dollID = llGetOwner();
        dollName = llGetDisplayName(dollID);
    }

    link_message(integer source, integer num, string choice, key id) {
        if (choice == "collapse") {
            state collapsed;
        }
    }
}

state collapsed {
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
        //
        if (perm & PERMISSION_TRIGGER_ANIMATION) {

            if (stopAnim != "") {
                llStopAnimation(stopAnim);
            } else {
                aoChange("off");
                llStartAnimation(collapseAnim);
            }
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

