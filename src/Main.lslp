// Main.lsl
//
// vim:sw=4 et nowrap:
//
// DATE: 22 March 2013
#include "include/GlobalDefines.lsl"

// Note that some doll types are special....
//    - regular: used for standard Dolls, including non-transformable
//    - slut: can be stripped (like Pleasure Dolls)
//    - Display: poses dont time out
//    - Key: doesnt wind down - Doll can be worn by other Dolly as Key
//    - Builder: doesnt wind down

//========================================
// VARIABLES
//========================================

// Transforming Keys:
//
// A TransformingKey is - or was - set by the presence of a
// Transform.lsl script in the Key. It makes a call into this
// script, thus:
//
//     llMessageLinked(LINK_THIS, 18, "here");
//
// and triggers a setting of the following variable,
// making this a transforming key:
//
// All other settings of this variable have been removed,
// including the SetDefaults and the NCPrefs.

integer minsLeft;
//integer canPose;

float lastEmergencyTime;
#define EMERGENCY_LIMIT_TIME 43200.0 // 12 Hours = 43200 Seconds

string rlvAPIversion;

// Current Controller - or Mistress
key MistressID = NULL_KEY;
key carrierID = NULL_KEY;
key dresserID = NULL_KEY;
key dollID = NULL_KEY;

integer dialogChannel;
integer chatChannel = 75;
integer chatHandle;
integer targetHandle;
#ifdef SIM_FRIENDLY
integer lowScriptMode;
#endif
integer busyIsAway;
integer ticks;

integer afk;
integer autoAFK = 1;
integer autoTP;
integer canAFK = 1;
integer canCarry = 1;
integer canDress = 1;
integer canFly = 1;
integer canSit = 1;
integer canStand = 1;
//integer canWear;
//integer canUnwear;
integer clearAnim;
integer collapsed;
integer configured;
integer demoMode;
integer detachable = 1;
integer doWarnings;
integer helpless;
integer pleasureDoll;
integer isTransformingKey;
integer visible = 1;
integer quiet;
integer RLVok;
integer signOn;
integer takeoverAllowed;
integer timerStarted;
integer warned;
integer wearLock;

integer carryMoved;

#ifdef DEVELOPER_MODE
integer timeReporting;
#endif

// If the key is a Transforming Key - one that can transform from one
// type of Doll to another - this tracks the current type of doll.
string dollType = "Regular";

float wearLockExpire;
float poseExpire;
float carryExpire;
float lastRandomTime;
float menuSleep;
float lastTickTime;
float windamount      = 1800.0; // 30 * SEC_TO_MIN;    // 30 minutes
float defaultwind     = windamount;
float keyLimit        = 10800.0;
float windRate;
float timeLeftOnKey   = windamount;

vector carrierPos;
vector lockPos;
string keyAnimation;
string dollName;
string carrierName;
string mistressName;
key mistressQuery;

#ifdef ADULT_MODE
string simRating;
key simRatingQuery;
#endif

//========================================
// FUNCTIONS
//========================================

//---------------------------------------
// Configuration Functions
//---------------------------------------
setDollType(string choice) {
    // Pre-conversion... restore settings as needed

    // change to new Doll Type
    dollType = llGetSubString(llToUpper(choice), 0, 0) + llGetSubString(llToLower(choice), 1, -1);
    
    #ifdef ADULT_MODE
    // new type is slut Doll
    if (dollType == "Slut") llOwnerSay("As a slut Doll, you can be stripped.");
    #endif
    
    // new type is builder or key doll
    if (dollType == "Builder" || dollType == "Key")
        llOwnerSay("You are a " + llToLower(dollType) + " doll so you do not wind down");
}

float windKey() {
    float windLimit = keyLimit - timeLeftOnKey;
    if (demoMode) windLimit = DEMO_LIMIT - timeLeftOnKey;
    
    // Return if winding is irrelevant
    if (windLimit <= 0) return 0;

    // Return windamount if less than remaining capacity
    else if (windLimit >= (windamount + 60.0)) { // Avoid creating a 0 minute wind situation by treating less than a minute from full as
                                                 // a full wind.
        timeLeftOnKey += windamount;
        return windamount;
    }
        
    // Eles return limit - timeleft
    else {
        // Inform doll of full wind
        llOwnerSay("You have been fully wound - " + (string)llRound(keyLimit / SEC_TO_MIN) + " minutes remaining.");
        timeLeftOnKey += windLimit;
        return windLimit;
    }
}

doWind(string name, key id) {
    integer winding = llFloor(windKey() / SEC_TO_MIN);

    if (winding > 0) {
        lmSendToAgent("You have given " + dollName + " " + (string)winding + " more minutes of life.", id);

        if (timeLeftOnKey == keyLimit) {
            if (!quiet) llSay(0, dollName + " has been fully wound by " + name + ".");
            else lmSendToAgent(dollName + " is now fully wound.", id);
        } else {
            lmSendToAgent("Doll is now at " + formatFloat((float)timeLeftOnKey * 100.0 / (float)keyLimit, 2) + "% of capacity.", id);
        }
        
        if (collapsed) uncollapse();
        else lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
        llSleep(1.0); // Make sure that the uncollapse RLV runs before sending the message containing winder name.
        // Is this too spammy?
        llOwnerSay("Have you remembered to thank " + name + " for winding you?");
    }
    
    if (timeLeftOnKey < keyLimit) { // Reshow the wind menu but only if the doll still needs winding
        lmInternalCommand("windMenu", name, id);
    }
}

initializeStart() {
    dollID = llGetOwner();
    dollName = llGetDisplayName(dollID);
            
    chatHandle = llListen(chatChannel, "", dollID, "");
    #ifdef ADULT_MODE
    simRatingQuery = llRequestSimulatorData(llGetRegionName(), DATA_SIM_RATING);
    #endif

    clearAnim = 1;
    ifPermissions();
    //if (isConfigured) initFinal();
}

initFinal() {
    if (timeLeftOnKey > keyLimit) timeLeftOnKey = keyLimit;
    
    float displayRate = setWindRate();
    llOwnerSay("You have " + (string)llRound(timeLeftOnKey / 60.0 / displayRate) + " minutes of life remaning.");
    lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);

    // When rezzed.... if collapsed... no escape!
    if (collapsed) lmInternalCommand("collapse", wwGetSLUrl(), NULL_KEY);
    
    if (!canDress) llOwnerSay("Other people cannot outfit you.");
    
    string msg = dollName + " has logged in with";
    if (!RLVok) msg += "out";
    msg += " RLV at " + wwGetSLUrl();
    llMessageLinked(LINK_THIS, 15, msg, scriptkey);
}

ifPermissions() {
    key grantor = llGetPermissionsKey();
    integer perm = llGetPermissions();
    
    if (grantor != NULL_KEY && grantor != dollID) {
        llResetOtherScript("Start");
        llSleep(10);
    }
    
    if (!((perm & PERMISSION_MASK) == PERMISSION_MASK))
        llRequestPermissions(dollID, PERMISSION_MASK);
    
    if (grantor == dollID) {
        if (perm & PERMISSION_OVERRIDE_ANIMATIONS && isAttached) {
            if (keyAnimation != "") {
                llSetAnimationOverride("Standing", keyAnimation);
            }
            else llResetAnimationOverride("ALL");
        }
        
        if (perm & PERMISSION_TRIGGER_ANIMATION && isAttached) {
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
        
        if (perm & PERMISSION_TAKE_CONTROLS && isAttached) {
            if (keyAnimation != "") {
                if (lockPos == ZERO_VECTOR) lockPos = llGetPos();
                if (llVecDist(llGetPos(), lockPos) > 1.0) {
                    llTargetRemove(targetHandle);
                    targetHandle = llTarget(lockPos, 1.0);
                    llMoveToTarget(lockPos, 0.7);
                }
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
                llTakeControls(CONTROL_MOVE, 1, 1);
            }
        }
        
        #ifndef DEVELOPER_MODE
        if (perm & PERMISSION_ATTACH && !llGetAttached()) llAttachToAvatar(ATTACH_BACK);
        #endif
    }
}

carry(string name, key id) {
    carrierID = id;
    carrierName = name;
    
    // Clear old targets to ensure there is only one
    llTargetRemove(targetHandle);
    llStopMoveToTarget();
    
    // Set updated target
    carrierPos = llList2Vector(llGetObjectDetails(carrierID, [OBJECT_POS]), 0);
    targetHandle = llTarget(carrierPos, CARRY_RANGE);
    
    if (carrierPos != ZERO_VECTOR && (keyAnimation == "")) llMoveToTarget(carrierPos, 0.7);
    
    if (!quiet) llSay(0, "The doll " + dollName + " has been picked up by " + carrierName);
    else {
        llOwnerSay("You have been picked up by " + carrierName);
        llRegionSayTo(carrierID, 0, "You have picked up the doll " + dollName);
    }
}

/*uncarry() {
    carrierID = NULL_KEY;
    carrierName = "";
    
    if (lockPos == ZERO_VECTOR) {
        // We were following carrier so we clear the target
        llTargetRemove(targetHandle);
        llStopMoveToTarget();
    }
}*/

/*uncollapse() {
    clearAnim = 1;
    collapsed = 0;
    keyAnimation = "";
    lockPos = ZERO_VECTOR;
    lmSendConfig("keyAnimation", keyAnimation);
    setWindRate();
    lmInternalCommand("restore", "", NULL_KEY);
    lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
    ifPermissions();
}*/

//========================================
// STATES
//========================================

// default state should be changed to normal state

default {

    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    // This should set up generic defaults
    // not specific to owner
    state_entry() {
        dollID = llGetOwner();
        if (llGetAttached()) llRequestPermissions(dollID, PERMISSION_MASK);
        
        lmScriptReset();
    }
    
    on_rez(integer start) {
        if (lockPos != ZERO_VECTOR) {
            llStopMoveToTarget();
            llTargetRemove(targetHandle);
            lockPos = llGetPos();
            targetHandle = llTarget(lockPos, 1);
        }
    }

    //----------------------------------------
    // DATASERVER
    //----------------------------------------
    dataserver(key query_id, string data) {
        if (query_id == mistressQuery) {
            mistressName = data;
            llOwnerSay("Your Mistress is " + mistressName);
        }
        #ifdef ADULT_MODE
        if (query_id == simRatingQuery) {
            simRating = data;
            llMessageLinked(LINK_SET, 150, simRating, NULL_KEY);
            
            if ((simRating == "MATURE" && simRating == "ADULT") && (pleasureDoll || dollType == "Slut")) {
                llOwnerSay("Entered " + llGetRegionName() + " rating is " + llToLower(simRating) + " stripping disabled.");
            }
        }
        #endif
    }

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    #ifdef ADULT_MODE
    changed(integer change) {
        if (change & CHANGED_REGION) {
            simRatingQuery = llRequestSimulatorData(llGetRegionName(), DATA_SIM_RATING);
        }
        if (change & CHANGED_TELEPORT) {
            if (lockPos != ZERO_VECTOR) {
                llStopMoveToTarget();
                llTargetRemove(targetHandle);
                lockPos = llGetPos();
                targetHandle = llTarget(lockPos, 1);
            }
        }
    }
    #endif

    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {   // called every timeinterval (tick)
        // Doing the following every tick:
        //    1. Are we checking for RLV? Reset...
        //    2. Carrier still present (in region)?
        //    3. Is Doll away?
        //    4. Wind down
        //    5. How far away is carrier? ("follow")
        float displayWindRate;
        
        // Increment a counter
        ticks++;
        
        //debugSay(5, "afk=" + (string)afk + " velocity=" + (string)llGetVel() + " speed=" + formatFloat(llVecMag(llGetVel()), 2) + "m/s (llVecMag(llGetVel()))");
        
        ifPermissions();
        if (ticks % 10 == 0) lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
        if (ticks % 30 == 0) {
            #ifdef DEVELOPER_MODE
            if (timeReporting) llOwnerSay("Script Time: " + formatFloat(llList2Float(llGetObjectDetails(llGetKey(), [ OBJECT_SCRIPT_TIME ]), 0) * 1000000, 2) + "µs");
            #endif
        }

        integer dollAway = ((llGetAgentInfo(dollID) & (AGENT_AWAY | (AGENT_BUSY * busyIsAway))) != 0);
        // When Dolly is "away" - enter AFK
        // Also set away when 
        if (autoAFK && (afk != dollAway)) {
            afk = dollAway;
            lmSendConfig("afk", (string)afk);
            displayWindRate = setWindRate();
            lmInternalCommand("setAFK", (string)afk + "|1|" + formatFloat(windRate, 1) + "|" + (string)llRound(timeLeftOnKey / (SEC_TO_MIN * displayWindRate)), NULL_KEY);
        }
        else displayWindRate = setWindRate();
        
        // Update sign if appropriate
        string primText = llList2String(llGetPrimitiveParams([ PRIM_TEXT ]), 0);
        if (collapsed && primText != "Disabled Dolly!") llSetText("Disabled Dolly!", <1.0, 0.0, 0.0>, 1.0);
        else if (afk && primText != dollType + " Doll (AFK)") llSetText(dollType + " Doll (AFK)", <1.0, 1.0, 0.0>, 1.0);
        else if (signOn && primText != dollType + " Doll") llSetText(dollType + " Doll", <1.0, 1.0, 1.0>, 1.0);
        else if (!signOn && !afk && !collapsed && primText != "") llSetText("", <1.0, 1.0, 1.0>, 1.0);

      /*--------------------------------
        WINDING DOWN.....
        --------------------------------
        A specific test for collapsed status is no longer required here
        as being collapsed is one of several conditions which forces the
        wind rate to be 0.
        Others which cause this effect are not being attached to spine
        and being doll type Builder or Key*/
        float thisTimerEvent = llGetTime();
        if (windRate != 0.0) {
            timeLeftOnKey -= (((thisTimerEvent = llGetTime()) - lastTimerEvent) * windRate);
            if (timeLeftOnKey < 0.0) timeLeftOnKey = 0.0;
            
            debugSay(9, "Timer: Last=" + (string)lastTimerEvent + " This=" + (string)thisTimerEvent + " Delta=" + (string)(thisTimerEvent - lastTimerEvent) + " Rate=" + (string)windRate + " Scaled=" + (string)((thisTimerEvent - lastTimerEvent) * windRate) + " Left=" + (string)timeLeftOnKey);
            
            minsLeft = llRound(timeLeftOnKey / (SEC_TO_MIN * displayWindRate));

            if (doWarnings && (minsLeft == 30 || minsLeft == 15 || minsLeft == 10 || minsLeft ==  5 || minsLeft ==  2) && !warned) {
                // FIXME: This can be seen as a spammy message - especially if there are too many warnings
                // FIXME: What do we think about this being gated by the quiet key option?  Should we just leave it without as
                // it has it's own option, though quiet version still warns the doll so perhaps still of use to some?
                if (!quiet) llSay(0, dollName + " has " + (string)minsLeft + " minutes left before they run down!");
                else llOwnerSay("You have " + (string)minsLeft + " minutes left before winding down!");
                warned = 1; // have warned now: dont repeat same warning
            }
            else warned = 0;

            // Dolly is DONE! Go down... and yell for help.
            if (!collapsed && timeLeftOnKey <= 0) {
                // This message is intentionally excluded from the quiet key setting as it is not good for
                // dolls to simply go down silently.
                llSay(0, "Oh dear. The pretty Dolly " + dollName + " has run out of energy. Now if someone were to wind them... (Click on their key.)");

                lmInternalCommand("collapse", (string)timeLeftOnKey, NULL_KEY);
                
                // Skip call to setWindRate() this function is heavily overused we only make practical use of the
                // value once per tick.  Updating more frequently is at best a waste at worst it's even a bug.
                // setWindRate();
            }
        }
        
        // Check if doll is posed and time is up
        if (keyAnimation != "" && keyAnimation != ANIMATION_COLLAPSED) { // Doll posed
            if (poseExpire != 0.0) {
                poseExpire -= thisTimerEvent - lastTimerEvent;
                if (poseExpire < 0.0) { // Pose expire is set and has passed
                    keyAnimation = "";
                    lockPos = ZERO_VECTOR;
                    lmSendConfig("keyAnimation", keyAnimation);
                    poseExpire = 0.0;
                    clearAnim = 1;
                }
                lmSendConfig("poseExpire", (string)(poseExpire)); // Save as time remaining so it works for other scripts
            }
        }
        
        // Check wearlock timer
        if (wearLockExpire != 0.0) {
            wearLockExpire -= thisTimerEvent - lastTimerEvent;
            if (wearLockExpire < llGetTime()) {
                lmInternalCommand("wearLock", (string)(wearLock = 0), NULL_KEY);
                wearLockExpire = 0.0;
            }
            lmSendConfig("wearLockExpire", (string)(wearLockExpire)); // Save as time remaining so it works for other scripts
        }
        
        lastTimerEvent = thisTimerEvent;
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
            else if (carrierPos == ZERO_VECTOR)
                if (llGetTime() > carryExpire) uncarry();
            else
                carryExpire = llGetTime() + CARRY_TIMEOUT;  // Give a small timeout before uncarrying
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
    
    //----------------------------------------
    // RECEIVED A LINK MESSAGE
    //----------------------------------------
    // For Transforming Key operations
    link_message(integer source, integer code, string data, key id) {
        string msg = "Link code: " + (string)code + " Data: " + data;
        if (id) msg += " Key: " + (string)id;
        debugSay(8, msg);
        list split = llParseString2List(data, [ "|" ], []);
        
        if (code == 102) {
            configured = 1;
        }
        
        else if (code == 104) {
            if (llList2String(split, 0) != "Start") return;
            initializeStart();
            lmInitState(104);
        }
        
        else if (code == 105) {
            if (llList2String(split, 0) != "Start") return;
            llSetTimerEvent(0.0);
            timerStarted = 0;
            dialogChannel = 0x80000000 | (integer)("0x" + llGetSubString((string)llGetLinkKey(2), -8, -1));
            #ifdef ADULT_MODE
            simRating = "";
            simRatingQuery = llRequestSimulatorData(llGetRegionName(), DATA_SIM_RATING);
            #endif
            // When rezzed.... if collapsed... no escape!
            if (collapsed) lmInternalCommand("collapse", wwGetSLUrl(), NULL_KEY);
            
                // When rezzed.... if currently being carried, drop..
            if (carrierID) uncarry();
            
            setWindRate();
            
            clearAnim = 1;
            ifPermissions();
            
            llSetTimerEvent(2.0);
            #ifdef SIM_FRIENDLY
            if (lowScriptMode) llSetTimerEvent(12.0);
            #endif
            timerStarted = 1;
            lmInitState(105);
        }
        
        else if (code == 135) {
            float delay = llList2Float(split, 1);
            memReport(delay);
        }
        
        else if (code == 300) {
            string script = llList2String(split, 0);
            string name = llList2String(split, 1);
            string value = llList2String(split, 2);
            
                 if (name == "afk")                               afk = (integer)value;
            else if (name == "autoAFK")                       autoAFK = (integer)value;
            else if (name == "autoTP")                         autoTP = (integer)value;
            else if (name == "canAFK")                         canAFK = (integer)value;
            else if (name == "canCarry")                     canCarry = (integer)value;
            else if (name == "canDress")                     canDress = (integer)value;
            else if (name == "canFly")                         canFly = (integer)value;
            else if (name == "canSit")                         canSit = (integer)value;
            else if (name == "canStand")                     canStand = (integer)value;
            else if (name == "configured")                 configured = (integer)value;
            else if (name == "detachable")                 detachable = (integer)value;
            else if (name == "helpless")                     helpless = (integer)value;
            else if (name == "pleasureDoll")             pleasureDoll = (integer)value;
            else if (name == "isTransformingKey")   isTransformingKey = (integer)value;
            else if (name == "isVisible")                     visible = (integer)value;
            else if (name == "busyIsAway")                 busyIsAway = (integer)value;
            else if (name == "quiet")                           quiet = (integer)value;
            else if (name == "RLVok")                           RLVok = (integer)value;
            else if (name == "signOn")                         signOn = (integer)value;
            else if (name == "takeoverAllowed")       takeoverAllowed = (integer)value;
            else if (name == "timeLeftOnKey")           timeLeftOnKey = (float)value;
            else if (name == "windRate")                     windRate = (float)value;
            else if (name == "windamount")                 windamount = (float)value;
            else if (name == "defaultwind")               defaultwind = (float)value;
            else if (name == "keyLimit")                     keyLimit = (float)value;
            else if (name == "wearLockExpire")         wearLockExpire = (float)value;
            else if (name == "poseExpire")                 poseExpire = (float)value;
            else if (name == "MistressID")                 MistressID = (key)value;
            else if (name == "mistressName")             mistressName = value;
            else if (name == "dollType")                     dollType = value;
            #ifdef SIM_FRIENDLY
            else if (name == "lowScriptMode") {
                lowScriptMode = (integer)value;
                if (timerStarted) {
                    if (lowScriptMode) llSetTimerEvent(12.0);
                    else llSetTimerEvent(2.0);
                }
            }
            #endif
        }
        
        else if (code == 305) {
            string script = llList2String(split, 0);
            string cmd = llList2String(split, 1);
            split = llList2List(split, 2, -1);
            
            if (cmd == "setAFK") {
                afk = llList2Integer(split, 0);
                
                ifPermissions();
                
                integer autoSet = llList2Integer(split, 1);
                
                if (!autoSet) {
                    integer dollAway = ((llGetAgentInfo(dollID) & (AGENT_AWAY | (AGENT_BUSY * busyIsAway))) != 0);
                    if (dollAway == afk) autoAFK = 1;
                    else autoAFK = 0;
                }
                
                debugSay(5, "setAFK, afk=" + (string)afk + ", autoSet=" + (string)autoSet + ", autoAFK=" + (string)autoAFK);
                
                lmSendConfig("afk", (string)afk);
                lmSendConfig("autoAFK", (string)autoAFK);
            }
            else if (!collapsed && cmd == "setPose") {
                keyAnimation = llList2String(split, 0);
                lockPos = llGetPos();
                lmSendConfig("keyAnimation", keyAnimation);
                
                // If not a display doll set an expire time
                if (dollType != "Display") poseExpire = POSE_LIMIT;
                
                // Force unsit and block sitting before posing
                lmRunRLV("unsit=force");
                
                // Run ifPermissions to pose the doll
                // This will also prevent movement while posed
                ifPermissions();
            }
            else if (cmd == "doUnpose") {
                keyAnimation = "";
                lockPos = ZERO_VECTOR;
                lmSendConfig("keyAnimation", keyAnimation);
                poseExpire = 0.0; // Clear timers
                clearAnim = 1; // Set signal for animation clear
                
                // Run ifPermissions to clear animations
                ifPermissions();
            }
            else if (cmd == "wearLock") {
                if (llList2Integer(split, 0)) wearLockExpire = WEAR_LOCK_TIME;
                else wearLockExpire = 0.0;
            }
            else if (cmd == "carry") {
                string name = llList2String(split, 0);
                carry(name, id);
            }
            else if (cmd == "uncarry") {
                //uncarry();
                carrierID = NULL_KEY;
                carrierName = "";
                
                if (lockPos == ZERO_VECTOR) {
                    // We were following carrier so we clear the target
                    llTargetRemove(targetHandle);
                    llStopMoveToTarget();
                }
            }
            else if (cmd == "collapse") {
                collapsed = 1;
                keyAnimation = ANIMATION_COLLAPSED;
                lmSendConfig("collapsed", (string)collapsed);
                lmSendConfig("keyAnimation", keyAnimation);
                lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
            }
            else if (cmd == "uncollapse") {
                clearAnim = 1;
                collapsed = 0;
                keyAnimation = "";
                setWindRate();
                lmSendConfig("collapsed", (string)collapsed);
                lmSendConfig("keyAnimation", keyAnimation);
                lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
                ifPermissions();
            }
        }

        else if (code == 350) {
            RLVok = llList2Integer(split, 0);
            rlvAPIversion = llList2String(split, 1);
            initFinal();
        }
        else if (code == 500) {
            string choice = llList2String(split, 0);
            string name = llList2String(split, 1);

            if (llGetSubString(choice, 0, 3) == "Wind") {
                if (llStringLength(choice) > 5) {
                    windamount = (float)llGetSubString(choice, 5, -1) * SEC_TO_MIN;
                    doWind(name, id);
                }
            }
        }
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string choice) {
        // channel = chat channel to listen on
        //    name = filter by prim name
        //     key = filter by avatar key
        //  choice = filter by specific message

        // Text commands
        if (channel == chatChannel) {

            // Normal user commands
            if (choice == "detach") {
                if (detachable) {
                    lmInternalCommand("detach", "", NULL_KEY);
                }
                else {
                    llOwnerSay("Key can't be detached...");
                }
            }
            else if (choice == "help") {
                llOwnerSay("%TEXT_HELP%");
            }
            else if (llGetSubString(choice,0,8) == "channel") {
                string c = llStringTrim(llGetSubString(choice,9,llStringLength(choice) - 1),STRING_TRIM);
                if ((string) ((integer) c) == c) {
                    integer ch = (integer) c;
                    if (ch != 0 && ch != DEBUG_CHANNEL) {
                        chatChannel = ch;
                        llListenRemove(chatHandle);
                        chatHandle = llListen(ch, "", llGetOwner(), "");
                    }
                }
            }
            // Demo: short time span
            else if (choice == "demo") {
                lmSendConfig("autoAFK", (string)(!demoMode));
                if (demoMode) {
                    timeLeftOnKey = DEMO_LIMIT;
                    llOwnerSay("Key set to run in demo mode: time limit set to " + (string)llRound((timeLeftOnKey = DEMO_LIMIT) / SEC_TO_MIN) + " minutes.");
                }
                // Note that the LIMIT is restored.... but the time left on key is unchanged
                else {
                    llOwnerSay("Key set to run normally: time limit set to " + (string)llRound(keyLimit / SEC_TO_MIN) + " minutes.");
                }
            }
            else if (choice == "poses") {
                integer  n = llGetInventoryNumber(20);

                // Menu max limit of 11... report error
                if (n > 11) {
                    llOwnerSay("Too many poses! Found " + (string)n + " poses (max is 11)");
                }

                while(n) {
                    string thisPose = llGetInventoryName(20, --n);

                    if (!(thisPose == ANIMATION_COLLAPSED || llGetSubString(thisPose,1,1) == ".")) {
                        if (keyAnimation == thisPose) {
                            llOwnerSay("\t*\t" + thisPose);
                        }
                        else {
                            llOwnerSay("\t\t" + thisPose);
                        }
                    }
                }
            }
            else if (choice == "wind") {
                // Give this a time limit: can only be done once
                // in - say - 6 hours... at least maxwindtime *2 or *3.

                if (lastEmergencyTime == 0 ||
                    (llGetTime() - lastEmergencyTime > EMERGENCY_LIMIT_TIME)) {

                    if (collapsed) {
                        llMessageLinked(LINK_THIS, 15, dollName + " has activated the emergency winder.", scriptkey);
                        
                        windamount = defaultwind;
                        windKey();
                        lastEmergencyTime = llGetTime();

                        uncollapse();

                        llOwnerSay("Emergency self-winder has been triggered by Doll.");
                        llOwnerSay("Emergency circuitry requires recharging and will be available again in " + (string)llRound(EMERGENCY_LIMIT_TIME / 3600.0) + " hours.");
                    } else {
                        llOwnerSay("No emergency exists - emergency self-winder deactivated.");
                    }
                } else {
                   llOwnerSay("Emergency self-winder is not yet recharged.");
                }
            }
            else if (choice == "xstats") {
                llOwnerSay("AFK time factor: " + formatFloat(RATE_AFK, 1) + "x");
                llOwnerSay("Wind amount: " + (string)llRound(windamount / SEC_TO_MIN) + " minutes.");

                {
                    string s;

                    s = "Doll can be teleported ";
                    if (autoTP) {
                        llOwnerSay(s + "without restriction.");
                    }
                    else {
                        llOwnerSay(s + "with confirmation.");
                    }

                    s = "Key is ";
                    if (detachable) {
                        llOwnerSay(s + "detachable.");
                    }
                    else {
                        llOwnerSay(s + "not detachable.");
                    }

                    s = " be dressed by others.";
                    if (canDress) {
                        llOwnerSay("Doll can" + s);
                    }
                    else {
                        llOwnerSay("Doll cannot" + s);
                    }

                    s = "Doll can";
                    if (canFly) {
                        llOwnerSay(s + " fly.");
                    }
                    else {
                        llOwnerSay(s + "not fly.");
                    }

                    s = "RLV is ";
                    if (RLVok) {
                        llOwnerSay(s + "active.");
                    }
                    else {
                        llOwnerSay(s + "not active.");
                    }
                }

                if (windRate == 0.0) {
                    llOwnerSay("Key is not winding down.");
                }

            }
            else if (choice == "stat") {
                float t1 = timeLeftOnKey / SEC_TO_MIN;
                float t2 = keyLimit / SEC_TO_MIN;
                float p = t1 * 100.0 / t2;

                string s = "Time: " + (string)llRound(t1) + "/" +
                            (string)llRound(t2) + " min (" + formatFloat(p, 2) + "% capacity)";
                if (afk) {
                    s += " (current wind rate " + formatFloat(setWindRate(), 1) + "x)";
                }
                llOwnerSay(s);
            }
            else if (choice == "stats") {
                setWindRate();
                llOwnerSay("Time remaining: " + (string)llRound(timeLeftOnKey / SEC_TO_MIN) + " minutes of " +
                            (string)llRound(keyLimit / SEC_TO_MIN) + " minutes.");
                if (windRate < 1.0) {
                    llOwnerSay("Key is unwinding at a slowed rate of " + formatFloat(windRate, 1) + "x.");
                } else if (windRate > 1.0) {
                    llOwnerSay("Key is unwinding at an accelerated rate of " + formatFloat(windRate, 1) + "x.");
                }

                /*if (MistressID) {
                    llOwnerSay("Controller: " + mistressName);
                }
                else {
                    llOwnerSay("Controller: none");
                }*/

                if (keyAnimation != ANIMATION_COLLAPSED && keyAnimation != "") {
                //    llOwnerSay(dollID, "Current pose: " + currentAnimation);
                //    llOwnerSay(dollID, "Pose time remaining: " + (string)(poseTime / SEC_TO_MIN) + " minutes.");
                    llOwnerSay("Doll is posed.");
                }

                lmMemReport(2.0);
            }
            #ifdef DEVELOPER_MODE
            else if (choice == "timereporting") {
                timeReporting = !timeReporting;
            }
            #endif
        }
    }

    run_time_permissions(integer perm) {
        ifPermissions();
    }
}
