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
#define STD_RATE 6.0
#define LOW_RATE 12.0

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
integer RLVck = 1;
integer signOn;
integer takeoverAllowed;
integer timerStarted;
integer warned;
integer wearLock;
integer initState = 104;

#ifdef DEVELOPER_MODE
integer timeReporting;
#endif

// If the key is a Transforming Key - one that can transform from one
// type of Doll to another - this tracks the current type of doll.
string dollType = "Regular";

float winderRechargeTime;
float wearLockExpire;
float lastRandomTime;
float menuSleep;
float lastTickTime;
float timeToJamRepair;
float windamount      = 1800.0; // 30 * SEC_TO_MIN;    // 30 minutes
float keyLimit        = 10800.0;
float effectiveLimit  = keyLimit;
float defaultwind     = windamount;
float timeLeftOnKey   = windamount;
float windRate        = 1.0;
float baseWindRate    = 1.0;
list windTimes        = [ 30 ];

vector lockPos;
string keyAnimation;
string dollName;
string mistressName;
string pronounHerDoll = "Her";
string pronounSheDoll = "She";
key mistressQuery;

#ifdef ADULT_MODE
string simRating;
key simRatingQuery;
#endif

//========================================
// FUNCTIONS
//========================================
linkDebug(integer sender, integer code, string data, key id) {
    integer level = 5;
         if (llListFindList([ 102, 305, 399 ], [ code ]) != -1)                 level = 2;
    /*else if (llListFindList([ 105, 110, 320, 350 ], [ code ]) != -1)            level = 4;
    else if (llListFindList([ 9999 ], [ code ]) != -1)                          level = 6;
    else if (llListFindList([ 104, 300, 315, 500 ], [ code ]) != -1)            level = 7;
    else if (llListFindList([ 9999 ], [ code ]) != -1)                          level = 8;
    else if (llListFindList([ 999 ], [ code ]) != -1)                           level = 9;*/
    else level = 1;
    
    string msg = "LM-DEBUG (" + (string)level + "): " + (string)code + ", " + data;
    if (id != NULL_KEY) msg += " - " + (string)id;
    
    if (DEBUG_LEVEL >= level) llOwnerSay(msg);
}

string cannoizeName(string name) {
    // Many new SL users fail to undersand the meaning of "Legacy Name" the name format of the DB
    // and many older SL residents confuse usernames and legasy names.  This function checks for
    // the presence of features inidcating we have been supplied with an invalid name which seems tp
    // be encoded in username format and makes the converstion to the valid legacy name.
    integer index;
    
    if ((index = llSubStringIndex(name, ".")) != -1)
        name = llInsertString(llDeleteSubString(name, index, index), index, " ");
    else if (llSubStringIndex(name, " ") == -1) name += " resident";
    
    return llToLower(name);
}

float windKey() {
    float windLimit = effectiveLimit - timeLeftOnKey;
    float wound;
    
    // Return if winding is irrelevant
    if (windLimit <= 0) return 0;

    // Return windamount if less than remaining capacity
    else if (windLimit >= (windamount + 60.0)) { // Avoid creating a 0 minute wind situation by treating less than a minute from full as
                                                 // a full wind.
        timeLeftOnKey += windamount;
        wound = windamount;
    }
        
    // Eles return limit - timeleft
    else {
        // Inform doll of full wind
        llOwnerSay("You have been fully wound - " + (string)llRound(effectiveLimit / (SEC_TO_MIN * setWindRate())) + " minutes remaining.");
        timeLeftOnKey += windLimit;
        wound = windLimit;
    }
    
    lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
    if (collapsed == 1) uncollapse(1);
    
    return wound;
}

doWind(string name, key id) {
    float wound = windKey();
    integer winding = llFloor(wound / SEC_TO_MIN);

    if (winding > 0) {
        lmSendToAgent("You have given " + dollName + " " + (string)winding + " more minutes of life.", id);
        
        if (timeLeftOnKey == effectiveLimit) {
            if (!quiet) llSay(0, dollName + " has been fully wound by " + name + ".");
            else lmSendToAgent(dollName + " is now fully wound.", id);
        } else {
            lmInternalCommand("windMenu", name, id);
            lmSendToAgent("Doll is now at " + formatFloat((float)timeLeftOnKey * 100.0 / (float)effectiveLimit, 2) + "% of capacity.", id);
        }
        
        llSleep(1.0); // Make sure that the uncollapse RLV runs before sending the message containing winder name.
        // Is this too spammy?
        llOwnerSay("Have you remembered to thank " + name + " for winding you?");
    }
}

#ifndef DEVELOPER_MODE
ifPermissions() {
    key grantor = llGetPermissionsKey();
    integer perm = llGetPermissions();
    
    if (grantor != NULL_KEY && grantor != dollID) {
        llResetOtherScript("Start");
        llSleep(10);
    }
    
    if (!((perm & PERMISSION_MASK) == PERMISSION_MASK))
        llRequestPermissions(dollID, PERMISSION_MASK);
    
    if (perm & PERMISSION_ATTACH && !isAttached) llAttachToAvatar(ATTACH_BACK);
    else if (!isAttached && llGetTime() > 120.0) {
        llOwnerSay("@acceptpermission=add");
        llRequestPermissions(dollID, PERMISSION_ATTACH);
    }
}
#endif

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
        float timerInterval;
        if (isAttached) timerInterval = llGetAndResetTime();
        
        // Increment a counter
        ticks++;
        
        //debugSay(5, "afk=" + (string)afk + " velocity=" + (string)llGetVel() + " speed=" + formatFloat(llVecMag(llGetVel()), 2) + "m/s (llVecMag(llGetVel()))");

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
        
        timeLeftOnKey -= timerInterval * windRate;
        if (timeLeftOnKey < 0) timeLeftOnKey = 0.0;
        debugSay(9, (string)timerInterval + " * " + (string)windRate + " = " + (string)timeLeftOnKey);
        
        #ifndef DEVELOPER_MODE
        ifPermissions();
        #endif
        
        // Update sign if appropriate
        string primText = llList2String(llGetPrimitiveParams([ PRIM_TEXT ]), 0);
        if (collapsed && primText != "Disabled Dolly!") llSetText("Disabled Dolly!", <1.0, 0.0, 0.0>, 1.0);
        else if (afk && primText != dollType + " Doll (AFK)") llSetText(dollType + " Doll (AFK)", <1.0, 1.0, 0.0>, 1.0);
        else if (signOn && primText != dollType + " Doll") llSetText(dollType + " Doll", <1.0, 1.0, 1.0>, 1.0);
        else if (!signOn && !afk && !collapsed && primText != "") llSetText("", <1.0, 1.0, 1.0>, 1.0);

        if (ticks % 10 == 0) {
            #ifdef DEVELOPER_MODE
            if (timeReporting) llOwnerSay("Script Time: " + formatFloat(llList2Float(llGetObjectDetails(llGetKey(), [ OBJECT_SCRIPT_TIME ]), 0) * 1000000, 2) + "µs");
            #endif
            
            lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
            if (wearLockExpire != 0.0) lmSendConfig("wearLockExpire", (string)(wearLockExpire));
            if (winderRechargeTime != 0.0) lmSendConfig("winderRechargeTime", (string)(winderRechargeTime));
            
            scaleMem();
            
          /*--------------------------------
            WINDING DOWN.....
            --------------------------------
            A specific test for collapsed status is no longer required here
            as being collapsed is one of several conditions which forces the
            wind rate to be 0.
            Others which cause this effect are not being attached to spine
            and being doll type Builder or Key*/
            if (windRate != 0.0) {
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
                if (!collapsed && timeLeftOnKey <= 0.0) {
                    // This message is intentionally excluded from the quiet key setting as it is not good for
                    // dolls to simply go down silently.
                    llSay(0, "Oh dear. The pretty Dolly " + dollName + " has run out of energy. Now if someone were to wind them... (Click on their key.)");
    
                    lmSendConfig("timeLeftOnKey", (string)(timeLeftOnKey = 0.0));
                    lmInternalCommand("collapse", "0", NULL_KEY);
                    
                    // Skip call to setWindRate() this function is heavily overused we only make practical use of the
                    // value once per tick.  Updating more frequently is at best a waste at worst it's even a bug.
                    // setWindRate();
                }
            }
            
            // False collapse? Collapsed = 1 while timeLeftOnKey is positive is an invalid condition
            if (collapsed == 1 && timeLeftOnKey > 0.0) {
                uncollapse(0);
            }
            else if (collapsed == 2) { // Dolly's key is held or jammed count down the automatic restart time
                
            }
            
            // Check wearlock timer
            if (wearLockExpire != 0.0) {
                wearLockExpire -= timerInterval;
                if (wearLockExpire < llGetTime()) {
                    lmInternalCommand("wearLock", (string)(wearLock = 0), NULL_KEY);
                    wearLockExpire = 0.0;
                    lmSendConfig("wearLockExpire", (string)(wearLockExpire));
                }
            }
            
            // Check winder recharge
            if (winderRechargeTime != 0.0) {
                winderRechargeTime -= timerInterval;
                if (winderRechargeTime < 0.0) {
                    winderRechargeTime = 0.0;
                    lmSendConfig("winderRechargeTime", (string)(winderRechargeTime));
                }
            }
        }
    }
    
    //----------------------------------------
    // RECEIVED A LINK MESSAGE
    //----------------------------------------
    // For Transforming Key operations
    link_message(integer source, integer code, string data, key id) {
        linkDebug(source, code, data, id);
        list split = llParseString2List(data, [ "|" ], []);
        
        if (code == 102) {
            if (llList2String(split, 0) == "OnlineServices") {
                if (timeLeftOnKey > effectiveLimit) timeLeftOnKey = effectiveLimit;
                
                float displayRate = setWindRate();
                llOwnerSay("You have " + (string)llRound(timeLeftOnKey / 60.0 / displayRate) + " minutes of life remaning.");
                lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
            }
        }
        
        else if (code == 104) {
            if (llList2String(split, 0) != "Start") return;
            dollID = llGetOwner();
            dollName = llGetDisplayName(dollID);
                    
            chatHandle = llListen(chatChannel, "", dollID, "");
            dialogChannel = 0x80000000 | (integer)("0x" + llGetSubString((string)llGetLinkKey(2), -8, -1));
            
            #ifdef ADULT_MODE
            simRatingQuery = llRequestSimulatorData(llGetRegionName(), DATA_SIM_RATING);
            #endif
            
            clearAnim = 1;
            //if (isConfigured) initFinal();
            if (initState == 104) lmInitState(initState++);
        }
        
        else if (code == 105) {
            if (llList2String(split, 0) != "Start") return;
            llSetTimerEvent(0.0);
            timerStarted = 0;
            #ifdef ADULT_MODE
            simRating = "";
            simRatingQuery = llRequestSimulatorData(llGetRegionName(), DATA_SIM_RATING);
            #endif
            
            if (initState == 105) lmInitState(initState++);
            clearAnim = 1;
            
            llSetTimerEvent(STD_RATE);
            if (lowScriptMode) llSetTimerEvent(LOW_RATE);
            timerStarted = 1;

            if (!isAttached) llSetTimerEvent(60.0);
        }
        
        else if (code == 110) initState = 105;
        
        else if (code == 135) {
            float delay = llList2Float(split, 1);
            scaleMem();
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
            else if (name == "collapsed") {
                collapsed = (integer)value;
                setWindRate();
            }
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
            #ifdef DEVELOPER_MODE
            else if (name == "timeReporting")           timeReporting = (integer)value;
            #endif
            else if (name == "timeLeftOnKey")           timeLeftOnKey = (float)value;
            else if (name == "windamount")                 windamount = (float)value;
            else if (name == "wearLockExpire")         wearLockExpire = (float)value;
            else if (name == "baseWindRate")             baseWindRate = (float)value;
            else if (name == "poserID")                       poserID = (key)value;
            else if (name == "keyAnimation")             keyAnimation = value;
            else if (name == "mistressName")             mistressName = value;
            else if (name == "dollType")                     dollType = value;
            else if (name == "pronounHerDoll")         pronounHerDoll = value;
            else if (name == "pronounSheDoll")         pronounSheDoll = value;
            else if (name == "lockPos") {
                if (value == llGetRegionName()) lockPos = llList2Vector(split, 3);
                else lockPos = llGetPos();
            }
            else if (name == "demoMode") {
                demoMode = (integer)value;
                if (demoMode) {
                    effectiveLimit = DEMO_LIMIT;
                    defaultwind = 120.0;
                }
                else {
                    effectiveLimit = keyLimit;
                    defaultwind = llListStatistics(LIST_STAT_MEDIAN, windTimes) * SEC_TO_MIN;
                }
            }
            else if (name == "keyLimit") {
                keyLimit = (float)value;
                if (demoMode) effectiveLimit = DEMO_LIMIT;
                else effectiveLimit = keyLimit;
            }
            else if (name == "windTimes") {
                split = llList2List(split, 2, -1);
                integer i;
                for (i = 0; i < llGetListLength(split); i++) split = llListReplaceList(split, [ llList2Integer(split, i) ], i ,i);
                split = llListSort(split, 1, 1);
                windTimes = split;
                defaultwind = llListStatistics(LIST_STAT_MEDIAN, windTimes) * SEC_TO_MIN;
            }
            #ifdef SIM_FRIENDLY
            else if (name == "lowScriptMode") {
                lowScriptMode = (integer)value;
                if (timerStarted) {
                    llSetTimerEvent(STD_RATE);
                    if (lowScriptMode) llSetTimerEvent(LOW_RATE);
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

            else if (cmd == "wearLock") {
                if (llList2Integer(split, 0)) lmSendConfig("wearLockExpire", (string)(wearLockExpire = WEAR_LOCK_TIME));
                else lmSendConfig("wearLockExpire", (string)(wearLockExpire = 0.0));
            }
        }

        else if (code == 350) {
            RLVok = llList2Integer(split, 0);
            rlvAPIversion = llList2String(split, 1);
            // When rlv confirmed....vefify collapse state... no escape!
            if (collapsed == 1 && timeLeftOnKey > 0) uncollapse(0);
            else if (!collapsed && timeLeftOnKey <= 0) lmInternalCommand("collapse", "0", NULL_KEY);
            
            if (!canDress) llOwnerSay("Other people cannot outfit you.");
        }
        else if (code == 500) {
            string choice = llList2String(split, 0);
            string name = llList2String(split, 1);

            if (choice == "Wind") {
                if (llGetListLength(windTimes) == 1 || (timeLeftOnKey + llList2Float(windTimes, 0) * SEC_TO_MIN) > keyLimit || timeLeftOnKey + 60.0 > effectiveLimit) {
                    debugSay(5, "Doing default wind");
                    windamount = defaultwind;
                    doWind(name, id);
                }
                else lmInternalCommand("windMenu", "", id);
            }
            else if (llGetSubString(choice, 0, 3) == "Wind") {
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
            
            if (llGetInventoryType(choice) == 20 || llGetSubString(choice, 0, 0) == "." | llGetSubString(choice, 0, 0) == "!") {
                if (llGetInventoryType(choice) != 20) choice = llGetSubString(choice, 1, -1);
                if (keyAnimation == "" || (keyAnimation != ANIMATION_COLLAPSED && poserID == dollID)) {
                    lmInternalCommand("setPose", choice, dollID);
                }
                else llOwnerSay("You try to regain control over your body in an effort to set your own pose but even that is beyond doll's control.");
                return;
            }
            
            integer space = llSubStringIndex(choice, " ");
            if (space == -1) {
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
                    lmSendToAgent("%TEXT_HELP%", dollID);
                }
                // Demo: short time span
                else if (choice == "demo") {
                    lmSendConfig("demoMode", (string)(demoMode = !demoMode));
                    if (demoMode) {
                        effectiveLimit = DEMO_LIMIT;
                        if (timeLeftOnKey > effectiveLimit) timeLeftOnKey = effectiveLimit;
                        llOwnerSay("Key set to run in demo mode: time limit set to " + (string)llRound(DEMO_LIMIT / (SEC_TO_MIN * setWindRate())) + " minutes.");
                    }
                    // Note that the LIMIT is restored.... but the time left on key is unchanged
                    else {
                        effectiveLimit = keyLimit;
                        llOwnerSay("Key set to run normally: time limit set to " + (string)llRound(effectiveLimit / (SEC_TO_MIN * setWindRate())) + " minutes.");
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
    
                    if (winderRechargeTime == 0.0) {
    
                        if (collapsed == 1) {
                            llMessageLinked(LINK_THIS, 15, dollName + " has activated the emergency winder.", scriptkey);
    
                            windKey();
                            winderRechargeTime = EMERGENCY_LIMIT_TIME;
    
                            llOwnerSay("Emergency self-winder has been triggered by Doll.");
                            llOwnerSay("Emergency circuitry requires recharging and will be available again in " + (string)llRound(EMERGENCY_LIMIT_TIME / 3600.0) + " hours.");
                        }
                        else if (collapsed == 2) {
                            llOwnerSay("The emergency winder motor whirrs, splutters and then falls silent unable to budge your jammed mechanism.");
                        }
                        else {
                            llOwnerSay("No emergency exists - emergency self-winder deactivated.");
                        }
                    } 
                    else {
                       llOwnerSay("Emergency self-winder is not yet recharged there is still " + formatFloat(winderRechargeTime / 3600.0, 2) + " hours before it will be ready again.");
                    }
                }
                else if (choice == "xstats") {
                    llOwnerSay("AFK time factor: " + formatFloat(RATE_AFK, 1) + "x");
                    llOwnerSay("Wind amount: " + (string)llRound(windamount / (SEC_TO_MIN * setWindRate())) + " minutes.");
    
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
                    float t1 = timeLeftOnKey / (SEC_TO_MIN * setWindRate());
                    float t2 = effectiveLimit / (SEC_TO_MIN * setWindRate());
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
                    llOwnerSay("Time remaining: " + (string)llRound(timeLeftOnKey / (SEC_TO_MIN * setWindRate())) + " minutes of " +
                                (string)llRound(effectiveLimit / (SEC_TO_MIN * setWindRate())) + " minutes.");
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
            }
            else if (choice == "release") {
                if (poserID != dollID) llOwnerSay("Dolly tries to take control of her body from the pose but she is no longer in control of her form.");
                else lmInternalCommand("doUnpose", "", dollID);
            }
            else {
                string param = llStringTrim(llGetSubString(choice, space + 1, -1), STRING_TRIM);
                choice = llStringTrim(llGetSubString(choice, 0, space - 1), STRING_TRIM);
                
                if (choice == "channel") {
                    string c = param;
                    if ((string) ((integer) c) == c) {
                        integer ch = (integer) c;
                        if (ch != 0 && ch != DEBUG_CHANNEL) {
                            chatChannel = ch;
                            llListenRemove(chatHandle);
                            chatHandle = llListen(ch, "", llGetOwner(), "");
                        }
                    }
                }
                else if (choice == "controller") {
                    lmInternalCommand("getMistressKey", cannoizeName(param), NULL_KEY);
                }
                else if (choice == "blacklist") {
                    lmInternalCommand("getBlacklistKey", cannoizeName(param), NULL_KEY);
                }
                else if (choice == "unblacklist") {
                    lmInternalCommand("getBlacklistKey", cannoizeName(param), NULL_KEY);
                }
                #ifdef DEVELOPER_MODE
                else if (choice == "timereporting") {
                    lmSendConfig("timeReporting", (string)(timeReporting = (integer)param));
                }
                #endif
                else llOwnerSay("Unrecognised command '" + choice + "' recieved on channel " + (string)chatChannel);
            }
        }
    }

    #ifndef DEVELOPER_MODE
    run_time_permissions(integer perm) {
        if (!llGetAttached()) llOwnerSay("@acceptpermission=rem");
        ifPermissions();
    }
    #endif
}
