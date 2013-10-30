//This should recieve a link message saying what animation to do -- or the message ~off, saying to turn the animation off.
//could take permanent control, but I don't think I want this because it would inactivate the other controller
// on start, reactivate collapse


string current;
string newanimation;
integer posing;
integer interfaceChannel;
integer usingOC;
integer listen_id_OC;
key dollID;
integer testing;

setup() {
    usingOC = FALSE;
    dollID = llGetOwner();
    interfaceChannel = (integer)("0x" + llGetSubString(dollID,30,-1));
    if (interfaceChannel > 0) {
        interfaceChannel = -interfaceChannel;
    }
    testing = TRUE;
    llWhisper(interfaceChannel, "OpenCollar?");
       llListenRemove(listen_id_OC); 
    listen_id_OC = llListen( interfaceChannel, "", "", "");
    llSleep(3.0);
    if (current == "collapse") {
        startanimation("collapse");
    }
    else {
        posing = FALSE;
    }
    //timer to turn this off if it isn't being used
}

startanimation(string next) {
    if (next == "~off") {
        if (usingOC == TRUE) {
            llWhisper(interfaceChannel, "499|ZHAO_AOON");    
        }
        llStopAnimation(current);
        llReleaseControls( );
    }
    else {
        if (usingOC == TRUE) {
            llWhisper(interfaceChannel, "499|ZHAO_AOOFF");    
        }
        newanimation = next;
        llRequestPermissions(dollID, PERMISSION_TAKE_CONTROLS | PERMISSION_TRIGGER_ANIMATION);
    }
}

default {
    state_entry() {
        posing = FALSE;
        setup();
    }

        on_rez(integer iParam) {  //when key is put on, or when logging back on
        setup();
     }
    link_message(integer source, integer num, string choice, key id) {
        if (num == 59) {
            startanimation(choice);
        }
    }
    listen(integer channel, string name, key id, string choice) {
        if (channel == interfaceChannel) {
            if (testing == TRUE && choice == "OpenCollar=Yes") {
                usingOC = TRUE;
                llOwnerSay("Debug: Using OC method");
                testing = FALSE;
            }
            else {
                llOwnerSay("Debug: got this msg in listen: " + choice);
            }
        }
    }
    run_time_permissions(integer perm) {
        if (perm & PERMISSION_TRIGGER_ANIMATION) {
            if (posing == TRUE && llStringLength(current) > 0) {
                       llStopAnimation(current);
            }
            llStartAnimation(newanimation);
            current = newanimation;
            posing = TRUE;
        }
        if (PERMISSION_TAKE_CONTROLS & perm) {
            llTakeControls( CONTROL_FWD | CONTROL_BACK | CONTROL_LEFT | CONTROL_RIGHT | CONTROL_ROT_LEFT |
                                 CONTROL_ROT_RIGHT | CONTROL_UP |  CONTROL_DOWN | CONTROL_LBUTTON | CONTROL_ML_LBUTTON , TRUE, FALSE);
        }
    }
    
}

