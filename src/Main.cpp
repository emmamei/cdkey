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
#ifdef LOW_SCRIPT_MODE
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
integer warned;

#ifdef DEVELOPER_MODE
integer timeReporting = 1;
#endif

// If the key is a Transforming Key - one that can transform from one
// type of Doll to another - this tracks the current type of doll.
string dollType = "Regular";

float poseExpire;
float menuSleep;
float carryExpire;
float windamount   = 1800.0; // 30 * SEC_TO_MIN;    // 30 minutes
float keyLimit     = 10800.0;
float windRate;
float timeLeftOnKey = windamount;

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
    else if (windLimit >= windamount) {
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
    }

    if (timeLeftOnKey == keyLimit) {
        if (!quiet) llSay(0, dollName + " has been fully wound by " + name + ".");
        else lmSendToAgent(dollName + " is now fully wound.", id);
    } else {
        lmSendToAgent("Doll is now at " + formatFloat((float)timeLeftOnKey * 100.0 / (float)keyLimit, 2) + "% of capacity.", id);
    }
    // Is this too spammy?
    llOwnerSay("Have you remembered to thank " + name + " for winding you?");
    
    if (collapsed) uncollapse();
    else lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey, NULL_KEY);

    llSleep(0.1);
    lmInternalCommand("mainMenu", name, id);
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
    llOwnerSay("You have " + (string)llRound(timeLeftOnKey / 60.0) + " minutes of life remaning.");
    lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey, NULL_KEY);

    // 
    // When rezzed.... if currently being carried, drop..
    if (carrierID) uncarry();

    // When rezzed.... if collapsed... no escape!
    if (collapsed) lmInternalCommand("collapse", wwGetSLUrl(), NULL_KEY);
    
    if (!canDress) llOwnerSay("Other people cannot outfit you.");
    if (hasController && mistressName != "") llOwnerSay("Your Mistress is " + mistressName);
    
    if (hasController) {
        lmSendToAgent(dollName + " has logged in without RLV at " + wwGetSLUrl(), MistressID);
        string msg = dollName + " has logged in with";
        if (RLVok) msg += "out";
        msg += " RLV at " + wwGetSLUrl();
        lmSendToAgent(msg, MistressID);
    }
    
    setWindRate();
    
    clearAnim = 1;
    ifPermissions();
    
    lmInitializationCompleted(105);
    llSleep(0.5);
    llSetTimerEvent(1.0);
#ifdef LOW_SCRIPT_MODE
    if (lowScriptMode) llSetTimerEvent(10.0);
#endif
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
                llWhisper(LockMeisterChannel, (string)dollID + "bootoff");
                
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
                llWhisper(LockMeisterChannel, (string)dollID + "booton");
            }
        }
        
        if (perm & PERMISSION_TAKE_CONTROLS && isAttached) {
            if (lockPos != ZERO_VECTOR) {
                if (llVecDist(llGetPos(), lockPos) > 1.0) {
                    llTargetRemove(targetHandle);
                    targetHandle = llTarget(lockPos, 1.0);
                    llMoveToTarget(lockPos, 0.7);
                }
                llTakeControls(CONTROL_ALL, 1, 0);
            }
            else {
                llTargetRemove(targetHandle);
                llStopMoveToTarget();
                llTakeControls(CONTROL_MOVE, 1, 1);
            }
        }
        
#ifndef DEVELOPER_MODE
        if (perm & PERMISSION_ATTACH && !llGetAttached()) llAttachToAvatar(ATTACH_BACK);
#endif
    }
}

turnToTarget(vector target) {
    vector pointTo = target - llGetPos();
    float  turnAngle = llAtan2(pointTo.x, pointTo.y);
    lmRunRLV("setrot:" + (string)(turnAngle) + "=force");
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

uncarry() {
    carrierID = NULL_KEY;
    carrierName = "";
    
    if (lockPos == ZERO_VECTOR) {
        // We were following carrier so we clear the target
        llTargetRemove(targetHandle);
        llStopMoveToTarget();
    }
}

uncollapse() {
    clearAnim = 1;
    collapsed = 0;
    keyAnimation = "";
    lockPos = ZERO_VECTOR;
    lmSendConfig("keyAnimation", keyAnimation, NULL_KEY);
    setWindRate();
    lmInternalCommand("restore", "", NULL_KEY);
    lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey, NULL_KEY);
    ifPermissions();
}

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
        
        ifPermissions();
        if (ticks % 30 == 0) {
            lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey, NULL_KEY);
#ifdef DEVELOPER_MODE
            if (timeReporting) llOwnerSay("Script Time: " + formatFloat(llList2Float(llGetObjectDetails(llGetKey(), [ OBJECT_SCRIPT_TIME ]), 0) * 1000000, 2) + "µs");
#endif
        }
        
        // Check if doll is posed
        if (keyAnimation != "" && keyAnimation != ANIMATION_COLLAPSED) { // Doll posed
            if (poseExpire > 0.0 && poseExpire < llGetTime()) { // Pose expire is set and has passed
                keyAnimation = "";
                lockPos = ZERO_VECTOR;
                lmSendConfig("keyAnimation", keyAnimation, NULL_KEY);
                poseExpire = 0.0;
                clearAnim = 1;
            }
        }

        integer dollAway = ((llGetAgentInfo(dollID) & (AGENT_AWAY | (AGENT_BUSY * busyIsAway))) != 0);
        // When Dolly is "away" - enter AFK
        // Also set away when 
        if (autoAFK && (afk != dollAway)) {
            afk = dollAway;
            if (afk) lockPos = llGetPos();
            else lockPos = ZERO_VECTOR;
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
        
        if (windRate != 0.0) {
            float thisTimerEvent;
            timeLeftOnKey -= (((thisTimerEvent = llGetTime()) - lastTimerEvent) * windRate);
            lastTimerEvent = thisTimerEvent;
            
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
		
		// We only collapse when we run out of time on the key so inline the collapse functionality
		collapsed = 1;
		keyAnimation = ANIMATION_COLLAPSED;
		lmInternalCommand("collapse", (string)timeLeftOnKey, NULL_KEY);
		
		// Skip redundant link messages.
		// lmSendConfig("keyAnimation", keyAnimation);			// Inferred and ANIMATION_COLLAPSED is gloabally defined
		// lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);	// Again collapsed = no time inferrable
		
		// Skip call to setWindRate() this function is heavily overused we only make practical use of the
		// value once per tick.  Updating more frequently is at best a waste at worst it's even a bug.
		// setWindRate();
            }
        }
    }
    
    //----------------------------------------
    // AT FOLLOW/MOVELOCK TARGET
    //----------------------------------------
    at_target(integer num, vector target, vector me) {
        // Clear old targets to ensure there is only one
        llTargetRemove(targetHandle);
        llStopMoveToTarget();
        
        if (carrierID != NULL_KEY) {
            if (lockPos == ZERO_VECTOR) {
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
                turnToTarget(carrierPos);
                carryMoved = 0;
            }
        }
    }
    
    //----------------------------------------
    // NOT AT FOLLOW/MOVELOCK TARGET
    //----------------------------------------
    not_at_target() {
        if (lockPos == ZERO_VECTOR) {
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
        else if (lockPos != ZERO_VECTOR) {
            llMoveToTarget(lockPos, 0.7);
        }
    }
    
    //----------------------------------------
    // RECEIVED A LINK MESSAGE
    //----------------------------------------
    // For Transforming Key operations
    link_message(integer source, integer code, string data, key id) {
#ifdef LINK_DEBUG
        string msg = "Link code: " + (string)code + " Data: " + data;
        if (id) msg += " Key: " + (string)id;
        llOwnerSay(msg);
#endif
        list split = llParseString2List(data, [ "|" ], []);
        
        if (code == 102) {
            configured = 1;
        }
        
        else if (code == 104) {
            if (llList2String(split, 0) != "Start") return;
            initializeStart();
            lmInitializationCompleted(104);
        }
        
        else if (code == 105) {
            if (llList2String(split, 0) != "Start") return;
            dialogChannel = 0x80000000 | (integer)("0x" + llGetSubString((string)llGetLinkKey(2), -9, -1));
#ifdef ADULT_MODE
            simRating = "";
            simRatingQuery = llRequestSimulatorData(llGetRegionName(), DATA_SIM_RATING);
#endif
            initFinal();
        }
        
        else if (code == 135) {
            llSleep(0.5);
            memReport();
            llSleep(0.5);
        }
        
        else if (code == 300) {
            string script = llList2String(split, 0);
            string name = llList2String(split, 1);
            string value = llList2String(split, 2);
            
            if (script != SCRIPT_NAME) {
                     if (name == "autoTP")                         autoTP = (integer)value;
                else if (name == "canAFK")                         canAFK = (integer)value;
                else if (name == "canCarry")                     canCarry = (integer)value;
                else if (name == "canDress")                     canDress = (integer)value;
                else if (name == "canFly")                         canFly = (integer)value;
                else if (name == "canSit")                         canSit = (integer)value;
                else if (name == "canStand")                     canStand = (integer)value;
                else if (name == "collapsed")                   collapsed = (integer)value;
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
                else if (name == "windamount")                 windamount = (float)value;
                else if (name == "keyLimit")                     keyLimit = (float)value;
                else if (name == "MistressID")                 MistressID = (key)value;
                else if (name == "mistressName")             mistressName = value;
    #ifdef LOW_SCRIPT_MODE
                else if (name == "lowScriptMode") {
                    lowScriptMode = (integer)value;
                    if (lowScriptMode) llSetTimerEvent(10.0);
                    else llSetTimerEvent(1.0);
                }
    #endif
            }
        }
        
        else if (code == 305) {
            string script = llList2String(split, 0);
            string cmd = llList2String(split, 1);
            split = llList2List(split, 2, -1);
            
            if (cmd == "setAFK") {
                afk = llList2Integer(split, 0);
                
                if (afk) lockPos = llGetPos();
                else lockPos = ZERO_VECTOR;
                
                integer autoSet = llList2Integer(split, 1);
                
                if (!autoSet) {
                    integer agentInfo = llGetAgentInfo(dollID);
                    if (((agentInfo & AGENT_AWAY) != 0) && afk) autoAFK = 1;
                    else if (!((agentInfo & AGENT_AWAY) != 0) && !afk) autoAFK = 1;
                    else autoAFK = 0;
                }
                
                ifPermissions();
            }
            else if (!collapsed && cmd == "setPose") {
                keyAnimation = llList2String(split, 0);
                lockPos = llGetPos();
                
                // If not a display doll set an expire time
                if (dollType != "Display") poseExpire = llGetTime() + POSE_LIMIT;
                
                // Force unsit and block sitting before posing
                lmRunRLV("unsit=force");
                llSleep(0.2);   // delay to let the command execute
                
                // Run ifPermissions to pose the doll
                // This will also prevent movement while posed
                ifPermissions();
            }
            else if (cmd == "doUnpose") {
                keyAnimation = "";
                lockPos = ZERO_VECTOR;
                lmSendConfig("keyAnimation", keyAnimation, NULL_KEY);
                poseExpire = 0.0; // Clear timers
                clearAnim = 1; // Set signal for animation clear
                
                // Run ifPermissions to clear animations
                ifPermissions();
            }
            else if (cmd == "carry") {
                string name = llList2String(split, 1);
                carry(name, id);
            }
            else if (cmd == "uncarry") {
                uncarry();
            }
        }

        else if (code == 350) {
            RLVok = llList2Integer(split, 1);
            rlvAPIversion = llList2String(split, 1);
        }
        else if (code == 500) {
            string choice = llList2String(split, 0);
            string name = llList2String(split, 1);

            if (choice == "Wind") doWind(name, id);
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
                lmSendConfig("autoAFK", (string)(!demoMode), NULL_KEY);
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
                        if (hasController)
                            lmSendToAgent(dollName + " has activated the emergency winder.", MistressID);

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

                if (MistressID) {
                    llOwnerSay("Controller: " + mistressName);
                }
                else {
                    llOwnerSay("Controller: none");
                }

                if (keyAnimation != ANIMATION_COLLAPSED && keyAnimation != "") {
                //    llOwnerSay(dollID, "Current pose: " + currentAnimation);
                //    llOwnerSay(dollID, "Pose time remaining: " + (string)(poseTime / SEC_TO_MIN) + " minutes.");
                    llOwnerSay("Doll is posed.");
                }

                lmMemReport();
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