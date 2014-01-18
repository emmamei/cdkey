#include "include/GlobalDefines.lsl"

key carrierID = NULL_KEY;

float baseWindRate;
float carryExpire;
float poseExpire;
float timeToJamRepair;

vector carrierPos;
vector lockPos;

string keyAnimation;
string carrierName;

integer afk;
integer carryMoved;
integer clearAnim = 1;
integer collapsed;
integer confgured;
integer dialogChannel;
integer initState = 104;
integer targetHandle;
integer ticks;

rotation lastRotation;

ifPermissions() {
    key grantorID = llGetPermissionsKey();
    integer permMask = llGetPermissions();
    
    if (grantorID != NULL_KEY && grantorID != dollID) {
        llResetOtherScript("Start");
        llSleep(10);
    }
    
    if (!((permMask & PERMISSION_MASK) == PERMISSION_MASK))
        llRequestPermissions(dollID, PERMISSION_MASK);
    
    if (grantorID == dollID) {
        if (permMask & PERMISSION_TRIGGER_ANIMATION && isAttached) {
            if (keyAnimation != "") {
                llWhisper(LOCKMEISTER_CHANNEL, (string)dollID + "bootoff");
                
                list animList; integer i; integer animCount; key animKey = llGetInventoryKey(keyAnimation);
                while ((animList = llGetAnimationList(dollID)) != [ animKey ]) {
                    animCount = llGetListLength(animList);
                    for (i = 0; i < animCount; i++) {
                        if (llList2Key(animList, i) != animKey) llStopAnimation(llList2Key(animList, i));
                    }
                    llStartAnimation(keyAnimation);
                }
            } else if (keyAnimation == "" && clearAnim) {
                list animList = llGetAnimationList(dollID); 
                integer i; integer animCount = llGetInventoryNumber(20);
                for (i = 0; i < animCount; i++) {
                    key animKey = llGetInventoryKey(llGetInventoryName(20, i));
                    if (llListFindList(animList, [ llGetInventoryKey(llGetInventoryName(20, i)) ]) != -1)
                        llStopAnimation(animKey);
                }
                clearAnim = 0;
                llWhisper(LOCKMEISTER_CHANNEL, (string)dollID + "booton");
            }
        }
        
        if (permMask & PERMISSION_TAKE_CONTROLS && isAttached) {
            if (keyAnimation != "") {
                if (lockPos == ZERO_VECTOR) lockPos = llGetPos();
                if (llVecDist(llGetPos(), lockPos) > 1.0) {
                    llTargetRemove(targetHandle);
                    targetHandle = llTarget(lockPos, 1.0);
                    llMoveToTarget(lockPos, 0.7);
                }
                llReleaseControls();
                llTakeControls(CONTROL_ALL, 1, 0);
            }
            else {
                lockPos = ZERO_VECTOR;
                llTargetRemove(targetHandle);
                llStopMoveToTarget();
                if (carrierID != NULL_KEY) {
                    vector carrierPos = llList2Vector(llGetObjectDetails(carrierID, [ OBJECT_POS ]), 0);
                    targetHandle = llTarget(carrierPos, CARRY_RANGE);
                }
                llReleaseControls();
            }
        }
    }
}

default {
    state_entry() {
        dollID = llGetOwner();
        dollName = llGetDisplayName(dollID);
        lmScriptReset();
        dialogChannel = 0x80000000 | (integer)("0x" + llGetSubString((string)llGetLinkKey(2), -8, -1));
    }
    
    on_rez(integer start) {
        if (lockPos != ZERO_VECTOR) {
            llStopMoveToTarget();
            llTargetRemove(targetHandle);
            lockPos = llGetPos();
            targetHandle = llTarget(lockPos, 1);
        }
        configured = 0;
    }
    changed(integer change) {
        if (change & CHANGED_TELEPORT) {
            if (lockPos != ZERO_VECTOR) {
                llStopMoveToTarget();
                llTargetRemove(targetHandle);
                lockPos = llGetPos();
                targetHandle = llTarget(lockPos, 1);
            }
        }
    }
    
    link_message(integer sender, integer code, string data, key id) {
        list split = llParseStringKeepNulls(data, [ "|" ], []);
        
        if (code == 102) {
            string script = llList2String(split, 0);
            
            if (script == "Start") configured = 1;
        }
        else if (code == 104) {
            string script = llList2String(split, 0);
            if (script != "Start") return;
            if (initState == 104) lmInitState(initState++);
        }
        else if (code == 105) {
            string script = llList2String(split, 0);
            if (script != "Start") return;
            if (initState == 105) lmInitState(initState++);
        }
        else if (code == 110) {
            initState = 105;
            llSetTimerEvent(1.0);
        }
        else if (code == 135) {
            float delay = llList2Float(split, 1);
            memReport(delay);
        }
        else if (code == 300) {
            string script = llList2String(split, 0);
            string name = llList2String(split, 1);
            string value = llList2String(split, 2);
            
            if (name == "keyAnimation") keyAnimation = value;
            else if (name == "poseExpire") poseExpire = (float)value;
            else if (name == "afk") afk = (integer)value;
            else if (name == "collapsed") collapsed = (integer)value;
        }
        else if (code == 305) {
            string script = llList2String(split, 0);
            string cmd = llList2String(split, 1);
            split = llList2List(split, 2, -1);
            
            if (cmd == "carry") {
                string name = llList2String(split, 0);
                
                carrierID = id;
                carrierName = name;
                
                // Clear old targets to ensure there is only one
                llTargetRemove(targetHandle);
                llStopMoveToTarget();
                
                // Set updated target
                carrierPos = llList2Vector(llGetObjectDetails(carrierID, [OBJECT_POS]), 0);
                targetHandle = llTarget(carrierPos, CARRY_RANGE);
                
                if (carrierPos != ZERO_VECTOR && keyAnimation == "") llMoveToTarget(carrierPos, 0.7);
                
                if (!quiet) llSay(0, "The doll " + dollName + " has been picked up by " + carrierName);
                else {
                    llOwnerSay("You have been picked up by " + carrierName);
                    llRegionSayTo(carrierID, 0, "You have picked up the doll " + dollName);
                }
            }
            else if (cmd == "collapse") {
                integer collapseType = llList2Integer(split, 0);
                if (collapseType == 0) { // Normal (original) collapse, sending this command with timeLeftOnKey > 0.0 is an illegal operation.
                    if (timeLeftOnKey > 0.0) {
                        debugSay(5, "Ignored illegal collapse type 0 while timeLeftOnKey is positive, use collapse type 1 to force or 2 for temporary hold key.");
                        if (collapsed != 2) lmInternalCommand("uncollapse", "", NULL_KEY); // We have time left and not type 2 collapse make sure doll is uncollapsed
                        return; // Return from collapse function doll will not collapse from invalid command.
                    }
                    collapsed = 1;
                }
                else if (collapseType == 1) { // Immidiate forced collapse NOW! If issued while timeLeftOnKey is positive triggers a *complete* unwind of all remaining time
                                              // When timeLeftOnKey has run down to 0.0 a type 1 collapse is functionally synomous with type 0.
                    if (timeLeftOnKey > 0.0) timeLeftOnKey = 0.0; // Forced unwind if there was time left before
                    collapsed = 1; // Always end collapsed
                    llOwnerSay("Your key has been forcably unwound leaving you collapsed completely out of time.");
                }
                else if (collapseType == 2) { // Type 2 collapse also forces an immidiate collapse no matter if the doll has time left however there is no unwind this is
                                         // Effectively like jamming or holding of dolly's key preventing it turning even though the spring has time
                    collapsed = 2; // Collapse type 2 forced collapse with timeLeftOnKey unchanged such as temporarily holding dolly's key still
                    if (llGetListLength(split) != 1) { // Optional timer value is specified, use this in place of the default repair timer.
                        timeToJamRepair = llList2Float(split, 2);
                    }
                    else timeToJamRepair = JAM_DEFAULT_TIME; // If non is specified default it is
                    string msg = " key ceases suddenly stopping the flow of life giving energy.";
                    if (!quiet) llSay(0, "The dolly's" + msg);
                    else llOwnerSay("Your" + msg);
                }
                lmSendConfig("collapsed", (string)collapsed);
                lmSendConfig("keyAnimation", (keyAnimation = ANIMATION_COLLAPSED));
                lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
            }
            else if (cmd == "doUnpose") {
                lmSendConfig("lockPos", (string)(lockPos = ZERO_VECTOR));
                lmSendConfig("keyAnimation", (keyAnimation = ""));
                clearAnim = 1; // Set signal for animation clear
                lmSendConfig("poseExpire", (string)(poseExpire = 0.0));
                
                // Run ifPermissions to clear animations
                ifPermissions();
            }
            else if (cmd == "setPose" && !collapsed) {                
                // Force unsit and block sitting before posing
                lmRunRLV("unsit=force");
                
                // If not a display doll set an expire time
                if (dollType != "Display") lmSendConfig("poseExpire", (string)(poseExpire = POSE_LIMIT));
                // Also include region name with location so we know to reset if changed.
                lmSendConfig("lockPos", llGetRegionName() + "|" + (string)(lockPos = llGetPos()));
                lmSendConfig("keyAnimation", (keyAnimation = llList2String(split, 0)));
                
                // Run ifPermissions to pose the doll
                // This will also prevent movement while posed
                ifPermissions();
            }
            else if (cmd == "uncarry") {
                carrierID = NULL_KEY;
                carrierName = "";
                
                if (keyAnimation == "") {
                    llTargetRemove(targetHandle);
                    llStopMoveToTarget();
                }
            }
            else if (cmd == "uncollapse") {
                debugSay(5, "Restoring from collapse");
                clearAnim = 1;
                collapsed = 0;
                keyAnimation = "";
                lmSendConfig("collapsed", (string)collapsed);
                lmSendConfig("keyAnimation", keyAnimation);
                lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
                ifPermissions();
            }
        }
        else if (code == 500) {
            string choice = llList2String(split, 0);
            string name = llList2String(split, 1);
            
            if (llGetSubString(choice, 0, 4) == "Poses" && (keyAnimation == ""  || (!isDoll || poserID == dollID))) {
                integer page = 1; integer len = llStringLength(choice);
                if (len > 5) page = (integer)llGetSubString(choice, 6 - len, -1);
                integer poseCount = llGetInventoryNumber(20);
                list poseList; integer i;
                
                llListenControl(dialogHandle, 1);
                llSetTimerEvent(60.0);
                
                for (i = 0; i < poseCount; i++) {
                    string poseName = llGetInventoryName(20, i);
                    if (poseName != ANIMATION_COLLAPSED &&
                        llGetSubString(poseName, 0, 0) != ".") {
                        if (poseName != keyAnimation) poseList += poseName;
                        else poseList += "* " + poseName;
                    }
                }
                poseCount = llGetListLength(poseList);
                if (poseCount > 12) {
                    poseList = llList2List(poseList, page * 9, (page + 1) * 9 - 1);
                    integer prevPage = page - 1;
                    integer nextPage = page + 1;
                    if (prevPage == 0) prevPage = llFloor((float)poseCount / 9.0);
                    if (nextPage > llFloor((float)poseCount / 9.0)) nextPage = 1;
                    poseList = [ "Poses " + (string)prevPage, "Main Menu", "Poses " + (string)nextPage ] + poseList;
                }
                
                llDialog(id, "Select the pose to put the doll into", poseList, dialogChannel);
            }
            else if ((!isDoll || poserID == dollID) && choice == "Unpose") {
                keyAnimation = "";
                lmInternalCommand("doUnpose", "", id);
            }
            else if ((keyAnimation == "" || (!isDoll || poserID == dollID)) && llGetInventoryType(choice) == 20) {
                keyAnimation = choice;
                lmInternalCommand("setPose", choice, id);
                poserID = id;
            }
            else if ((keyAnimation == "" || (!isDoll || poserID == dollID)) && llGetInventoryType(llGetSubString(choice, 2, -1)) == 20) {
                keyAnimation = llGetSubString(choice, 2, -1);
                lmInternalCommand("setPose", llGetSubString(choice, 2, -1), id);
                poserID = id;
            }
        }
    }
    
    timer() {
        float timerInterval = llGetAndResetTime();
        if (ticks++ % 60 == 0) 
            if (poseExpire != 0.0) lmSendConfig("poseExpire", (string)(poseExpire));
        
        // Check if doll is posed and time is up
        if (keyAnimation != "" && keyAnimation != ANIMATION_COLLAPSED) { // Doll posed
            if (poseExpire != 0.0) {
                poseExpire -= timerInterval;
                if (poseExpire < 0.0) { // Pose expire is set and has passed
                    lmInternalCommand("doUnpose", "", NULL_KEY);
                }
            }
        }
        
        // Check if jam time passes
        if (timeToJamRepair != 0) {
            timeToJamRepair -= timerInterval;
            if (timeToJamRepair < 0.0) {
                timeToJamRepair = 0.0;
                lmInternalCommand("uncollapse", "", NULL_KEY);
            }
            lmSendConfig("timeToJamRepair", (string)timeToJamRepair);
        }
        
        ifPermissions();
    }
    
    //----------------------------------------
    // AT FOLLOW/MOVELOCK TARGET
    //----------------------------------------
    at_target(integer num, vector target, vector me) {
        // Clear old targets to ensure there is only one
        llTargetRemove(targetHandle);
        llStopMoveToTarget();
        
        if (carrierID != NULL_KEY) {
            if (keyAnimation == "") {
                // Get updated position and set target
                carrierPos = llList2Vector(llGetObjectDetails(carrierID, [OBJECT_POS]), 0);
                targetHandle = llTarget(carrierPos, CARRY_RANGE);
            }
            else
                carryExpire = CARRY_TIMEOUT;  // Give a small timeout before uncarrying
                                              // this way carry can continue through a TP
            if (carryMoved) {
                vector pointTo = target - llGetPos();
                float  turnAngle = llAtan2(pointTo.x, pointTo.y);
                lmRunRLV("setrot:" + (string)(turnAngle) + "=force");
                carryMoved = 0;
            }
        }
    }
    
    //----------------------------------------
    // NOT AT FOLLOW/MOVELOCK TARGET
    //----------------------------------------
    not_at_target() {
        if (keyAnimation == "" && carrierID != NULL_KEY) {
            vector newCarrierPos = llList2Vector(llGetObjectDetails(carrierID,[OBJECT_POS]),0);
            llStopMoveToTarget();
            
            if (carrierPos != newCarrierPos) {
                llTargetRemove(targetHandle);
                carrierPos = newCarrierPos;
                targetHandle = llTarget(carrierPos, CARRY_RANGE);
            }
            if (carrierPos != ZERO_VECTOR) {
                llMoveToTarget(carrierPos, 0.7);
                carryExpire = llGetTime() + CARRY_TIMEOUT;
                carryMoved = 1;
            }
            else if (carrierID != NULL_KEY && llGetTime() > carryExpire) uncarry();
        }
        else if (keyAnimation != "") {
            llMoveToTarget(lockPos, 0.7);
        }
    }
    
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
    control(key id, integer level, integer edge) { // Event params are key avatar id, integer level representing keys currently held and integer edge
                                                   // representing keys which have been pressed or released in this period (Since last control event).
        
        if (llGetCameraRot() != lastRotation) {                               
            vector pointTo = llRot2Axis(llGetCameraRot());
            float  turnAngle = llAtan2(pointTo.x, pointTo.y);
            lmRunRLV("setrot:" + (string)(turnAngle) + "=force");
            lastRotation = llGetCameraRot();
        }
                                                   
        if (afk && id == dollID) {                                      // Test input it actually from the doll and afk is active
            if (edge & (CONTROL_FWD | CONTROL_BACK) != 0)
                llRotLookAt(llGetCameraRot(), 0.2, 0.5);
            if ((level & edge) & CONTROL_FWD)                           // When the doll begins holding the forward control (arrow or W both count)
                llSetForce(<-1.0, 0.0, 0.0> * 115.0 * llGetMass(), 1);  // Set a physical force to resist but not prevent forward movement (+ve local x axis)
            else if ((level & edge) & CONTROL_BACK)                     // When the doll begins holding the backward arrow or S key
                llSetForce(<1.0, 0.0, 0.0> * 115.0 * llGetMass(), 1);   // Set a physical force to resist but not prevent backwards movement (-ve local x axis)
            else if ((~level & edge) & (CONTROL_FWD | CONTROL_BACK)) {  // Where the doll releases the forward/backward arrows W or S keys
                if ((level & (CONTROL_FWD | CONTROL_BACK)) == 0)        // Confirm that they are not holding any other forward or backward control also
                    llSetForce(ZERO_VECTOR, 1);                         // If not cancel the force immidiately to prevent them being thrown accross sim
            }
        }
    }
    
    run_time_permissions(integer perm) {
        ifPermissions();
    }
}
