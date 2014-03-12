//========================================
// Main.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 28 February 2014

#define MAIN_LSL
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
#define EMERGENCY_LIMIT_TIME 43200.0 // 12 (RL) Hours = 43200 Seconds

string rlvAPIversion;

// Current Controller - or Mistress
key winderID = NULL_KEY;
key dollID = NULL_KEY;
key keyHandler = NULL_KEY;

integer dialogChannel;
integer targetHandle;
#ifdef SIM_FRIENDLY
integer lowScriptMode;
#endif
integer busyIsAway;
integer ticks;

integer afk;
integer autoAFK = 1;
//integer autoTP;
integer canAFK = 1;
//integer canCarry = 1;
//integer canDress = 1;
//integer canFly = 1;
//integer canSit = 1;
//integer canStand = 1;
//integer canRepeat = 1;
//integer canWear;
//integer canUnwear;
integer clearAnim;
integer collapsed;
integer configured;
integer demoMode;
//integer detachable = 1;
//integer doWarnings;
//integer helpless;
//integer pleasureDoll;
integer isTransformingKey;
//integer visible = 1;
integer quiet;
integer RLVok;
integer RLVck = 1;
integer signOn;
//integer takeoverAllowed;
//integer timerStarted;
integer warned;
integer wearLock;
integer timeReporting = 1;

integer debugLevel = DEBUG_LEVEL;

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
float timeLeftOnKey   = windamount;
float baseWindRate    = windRate;
float displayWindRate = windRate;
integer HTTPinterval  = 60;
integer HTTPthrottle  = 10;
integer lastPostTimestamp;
integer lastSendTimestamp;
float collapseTime;
list windTimes        = [ 30 ];
list blacklist;

string keyAnimation;
string dollName;
string mistressName;
string pronounHerDoll = "Her";
string pronounSheDoll = "She";
key mistressQuery;

key simRatingQuery;

//========================================
// FUNCTIONS
//========================================
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

    if (perm & PERMISSION_ATTACH && !cdAttached()) llAttachToAvatar(ATTACH_BACK);
    else if (!cdAttached() && llGetTime() > 120.0) {
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
        
        cdInitializeSeq();
    }

    on_rez(integer start) {
        llSetTimerEvent(0.0);
        timerStarted = 0;
        configured = 0;
    }

    //----------------------------------------
    // DATASERVER
    //----------------------------------------
    dataserver(key query_id, string data) {
        if (query_id == mistressQuery) {
            mistressName = data;
            llOwnerSay("Your Mistress is " + mistressName);
        }

        if (query_id == simRatingQuery) {
            simRating = data;
            lmRating(simRating);

            string msg = "Entered " + llGetRegionName() + " rating is " + llToLower(simRating);
#ifdef ADULT_MODE
            if (pleasureDoll || (dollType == "Slut")) {
                if (cdRating2Integer(simRating) < 2) msg += " stripping disabled.";
                else msg += " stripping enabled.";
            }
#endif
            llOwnerSay(msg);
        }
    }

    //----------------------------------------
    // CHANGED
    //----------------------------------------
    changed(integer change) {
        if (change & CHANGED_REGION) {
            simRatingQuery = llRequestSimulatorData(llGetRegionName(), DATA_SIM_RATING);
            lmSendConfig("keyHandler", (string)(keyHandler = NULL_KEY));
        }
        if (change & CHANGED_OWNER) {
            llSleep(60);
        }
    }
    
    //----------------------------------------
    // TOUCH START
    //----------------------------------------
    touch_start(integer num) {
        string windButton = "Wind...";
        float windLimit = (float)(DEMO_LIMIT * demoMode + keyLimit * !demoMode) - timeLeftOnKey;
        if ((llGetListLength(windTimes) == 1) || ((llListStatistics(LIST_STAT_MIN, windTimes) * SEC_TO_MIN) < windLimit)) windButton = "Wind";
        
        integer i;
        for (i = 0; i < num; i++) {
            key id = llDetectedKey(i);
    
            lmInternalCommand("mainMenu", windButton + "|" + llGetDisplayName(id), id);
        }
    }

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
        displayWindRate = setWindRate();
        float timerInterval;
        if (cdAttached()) timerInterval = llGetAndResetTime();

        // Increment a counter
        ticks++;

        //debugSay(5, "afk=" + (string)afk + " velocity=" + (string)llGetVel() + " speed=" + formatFloat(llVecMag(llGetVel()), 2) + "m/s (llVecMag(llGetVel()))");

        timeLeftOnKey -= timerInterval * windRate;
        if (timeLeftOnKey < 0) timeLeftOnKey = 0.0;

        if (collapsed) collapseTime += timerInterval;
        if (wearLock) wearLockExpire -= timerInterval;

        // False collapse? Collapsed = 1 while timeLeftOnKey is positive is an invalid condition
        if ((collapsed == 1) && (timeLeftOnKey > 0.0)) {
            uncollapse(0);
        }

        if (ticks % 2 == 0) {
#ifndef DEVELOPER_MODE
                ifPermissions();
#endif

            if (canAFK) {
                integer dollAway = ((llGetAgentInfo(dollID) & (AGENT_AWAY | (AGENT_BUSY * busyIsAway))) != 0);
                // When Dolly is "away" - enter AFK
                // Also set away when
                if (autoAFK && (afk != dollAway)) {
                    afk = dollAway;
                    lmSendConfig("afk", (string)afk);
                    displayWindRate = setWindRate();
                    lmInternalCommand("setAFK", (string)afk + "|1|" + formatFloat(windRate, 1) + "|" + (string)llRound(timeLeftOnKey / (SEC_TO_MIN * displayWindRate)), NULL_KEY);
                }
            }

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

            if (ticks % 10 == 0) {
                // Check post interval
                if (((lastPostTimestamp + (HTTPinterval - HTTPthrottle)) < llGetUnixTime()) && (lastSendTimestamp <= lastPostTimestamp)) {
                    // Check wearlock timer
                    if (wearLock) {
                        if (wearLockExpire <= 0.0) {
                            wearLockExpire = 0.0;
                            lmInternalCommand("wearLock", (string)(wearLock = 0), NULL_KEY);
                        }
                    }
    
                    lmInternalCommand("getTimeUpdates", "", NULL_KEY);
                }
            }

            if (ticks % 30 == 0) {
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
                        lmInternalCommand("collapse", "1", NULL_KEY);
                    }
                }

#ifdef DEVELOPER_MODE
                if (timeReporting) llOwnerSay("Script Time: " + formatFloat(llList2Float(llGetObjectDetails(llGetKey(), [ OBJECT_SCRIPT_TIME ]), 0) * 1000000, 2) + "µs");
#endif

                scaleMem();
            }
        }
    }

    //----------------------------------------
    // RECEIVED A LINK MESSAGE
    //----------------------------------------
    // For Transforming Key operations
    link_message(integer source, integer i, string data, key id) {
        
        // Parse link message header information
        list split        =     cdSplitArgs(data);
        string script     =     cdListElement(split, 0);
        integer remoteSeq =     (i & 0xFFFF0000) >> 16;
        integer optHeader =     (i & 0x00000C00) >> 10;
        integer code      =      i & 0x000003FF;
        split             =     llDeleteSubList(split, 0, 0 + optHeader);

        if (code == 102) {
            if (script == "ServiceReceiver") {
                lmMenuReply("Wind", "", NULL_KEY);

                float displayRate = setWindRate();
                llOwnerSay("You have " + (string)llRound(timeLeftOnKey / 60.0 / displayRate) + " minutes of life remaning.");
                lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
            }
            
            configured = 1;
            
            llSetTimerEvent(STD_RATE);
            if (lowScriptMode) llSetTimerEvent(LOW_RATE);
            timerStarted = 1;

            if (!cdAttached()) llSetTimerEvent(60.0);
        }

        else if (code == 104) {
            if (script != "Start") return;
            dollID = llGetOwner();
            dollName = llGetDisplayName(dollID);

            clearAnim = 1;
        }

        else if (code == 105) {
            if (script != "Start") return;
            clearAnim = 1;

            llSetTimerEvent(STD_RATE);
            if (lowScriptMode) llSetTimerEvent(LOW_RATE);
            timerStarted = 1;

            if (!cdAttached()) llSetTimerEvent(60.0);
        }

        else if (code == 135) {
            float delay = llList2Float(split, 0);
            scaleMem();
            memReport(cdMyScriptName(),delay);
        }
        
        cdConfigReport();

        else if (code == 300) {
            string name = llList2String(split, 0);
            string value = llList2String(split, 1);
            split = llDeleteSubList(split, 0, 0);

                 if (name == "afk")                               afk = (integer)value;
            else if (name == "autoAFK")                       autoAFK = (integer)value;
            //else if (name == "autoTP")                         autoTP = (integer)value;
            else if (name == "canAFK") {
                canAFK = (integer)value;
                if (afk) { // If doll is already AFK bring them out of it so they are not stuck
                    lmSendConfig("afk", (string)afk);
                    displayWindRate = setWindRate();
                    lmInternalCommand("setAFK", (string)afk + "|1|" + formatFloat(windRate, 1) + "|" + (string)llRound(timeLeftOnKey / (SEC_TO_MIN * displayWindRate)), NULL_KEY);
                }
            }
            else if (name == "canRepeat")                   canRepeat = (integer)value;
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")                 debugLevel = (integer)value;
#endif
            else if (name == "configured")                 configured = (integer)value;
            else if (name == "busyIsAway")                 busyIsAway = (integer)value;
            else if (name == "quiet")                           quiet = (integer)value;
            else if (name == "signOn")                         signOn = (integer)value;
            else if (name == "windamount")                 windamount = (float)value;
            else if (name == "wearLockExpire")         wearLockExpire = (float)value;
            else if (name == "baseWindRate")             baseWindRate = (float)value;
            else if (name == "collapsed")                   collapsed = (integer)value;
            else if (name == "collapseTime")             collapseTime = llGetTime() - (float)collapseTime;
            else if (name == "keyAnimation")             keyAnimation = value;
            else if (name == "dollType")                     dollType = value;
            else if (name == "pronounHerDoll")         pronounHerDoll = value;
            else if (name == "pronounSheDoll")         pronounSheDoll = value;
            else if (name == "blacklist")                   blacklist = split;
            else if (name == "dialogChannel")           dialogChannel = (integer)value;
            else if (name == "debugLevel")                 debugLevel = (integer)value;
            else if (name == "windTimes") {
                // If we see wind times sent as a config and not by this script then we pass the input through or
                // setWindTimes handler to make sure that it has been properly processed and all invalids cleaned.
                if (script != "Main") lmInternalCommand("setWindTimes", llDumpList2String(llJson2List(value),"|"), id);
            }
            else if (name == "displayWindRate") {
                if ((float)value != 0) displayWindRate = (float)value;
            }
            else if ((name == "timeLeftOnKey") || (name == "collapsed")) {
                if (name == "timeLeftOnKey")            timeLeftOnKey = (float)value;
                if (name == "collapsed")                    collapsed = (integer)value;
                if ((collapsed == 1) && (timeLeftOnKey > 0.0)) uncollapse(0);
            }
            else if (name == "keyHandler") {
                keyHandler = (key)value;
            }
            else if (name == "keyLimit") {
                keyLimit = (float)value;
                lmMenuReply("Wind", "", NULL_KEY);
            }
            else if (name == "demoMode") {
                demoMode = (integer)value;
            }
#ifdef DEVELOPER_MODE
            else if (llToLower(name) == "timereporting")           timeReporting = (integer)value;
#endif
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
            string cmd = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "setAFK") {
                afk = llList2Integer(split, 0);

                integer autoSet = llList2Integer(split, 1);

                if (!autoSet) {
                    integer dollAway = ((llGetAgentInfo(dollID) & (AGENT_AWAY | (AGENT_BUSY * busyIsAway))) != 0);
                    if (dollAway == afk) autoAFK = 1;
                    else autoAFK = 0;
                }

                debugSay(5,"DEBUG", "setAFK, afk=" + (string)afk + ", autoSet=" + (string)autoSet + ", autoAFK=" + (string)autoAFK);

                lmSendConfig("afk", (string)afk);
                lmSendConfig("autoAFK", (string)autoAFK);
            }
            
            else if (cmd == "getTimeUpdates") {
                if (timeLeftOnKey != 0.0) lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
                if (wearLockExpire != 0.0) lmSendConfig("wearLockExpire", (string)wearLockExpire);
                if (collapseTime != 0.0) lmSendConfig("collapseTime", (string)(collapseTime = (collapseTime * (collapsed != 0))));
                lastSendTimestamp = llGetUnixTime();
                
                // In offline mode we update the timer locally
                if (offlineMode) lastPostTimestamp = lastSendTimestamp;
            }

            else if (cmd == "setWindTimes") {
                split = llDeleteSubList(llParseString2List(data, [","," ","|"], []), 0, 1);
                integer i; integer start = llGetListLength(split);

                windTimes = [];

                for (i = 0; i < start; i++) {
                    integer value = (integer)llStringTrim(llList2String(split, i), STRING_TRIM);
                    if ((value > 0) && (value <= 240) && (llListFindList(windTimes, [ value ]) == -1)) windTimes += value;
                }
                
                integer l = llGetListLength(windTimes); i = l;
                while (l > 11) llDeleteSubList(llListSort(windTimes,1,--l&1),i-=2,i);
                windTimes = llListSort(windTimes,1,1);
                
                if (start > l) lmSendToAgent("One or more times were filtered, accepted list is " + llList2CSV(windTimes), id);
                if (script != "ServiceReceiver") lmSendConfig("windTimes", llList2Json(JSON_ARRAY, windTimes));
            }

            else if (cmd == "wearLock") {
                wearLockExpire = WEAR_LOCK_TIME;
                if (llList2Integer(split, 0)) {
                    lmSendConfig("wearLockExpire", (string)(wearLockExpire - WEAR_LOCK_TIME));
                    displayWindRate = setWindRate();
                }
                else lmSendConfig("wearLockExpire", (string)(wearLockExpire = 0.0));
            }

            else if (llGetSubString(cmd,-8,-1) == "collapse") {
                displayWindRate = setWindRate();
                if (cmd == "collapse") {
                    integer collapseType = llList2Integer(split, 0);
                    if (collapseType < 2) {
                        if (collapseType == 1) timeLeftOnKey = 0.0;
                        collapsed = 1;
                    }
                    else collapsed = 2;
                } else if (timeLeftOnKey >= 0.0) {
                    timeLeftOnKey = 0.0;
                    collapsed = 0;
                }
                lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
                lmSendConfig("collapseTime", (string)(collapseTime = 0.0));
                lmSendConfig("collapsed", (string)collapsed);
            }
            else if (cmd == "windMenu") {
                // Compute "time remaining" message for windMenu
                if (id == NULL_KEY) return;
                
                string name = llList2String(split, 0);
                float windLimit = llList2Float(split, 1);
                
                integer n = llGetListLength(windTimes);
                
                if (demoMode) {
                    if ((n == 1) || (windLimit < 120.0)) {
                        lmMenuReply("Wind 1", name, id);
                        return;
                    }
                    else split = [1,2];
                } else {
                    integer i = 0; float time; split = [];
                    while ((i <= n) && ( ( time = (llList2Float(windTimes, i++) * SEC_TO_MIN) ) < (windLimit - 60.0)) && (time <= (keyLimit / 2))) {
                        split += ["Wind " + (string)llFloor(time / SEC_TO_MIN)];
                    }
                    if ((i <= n) && (windLimit <= (keyLimit / 2))) split += ["Wind Full"];
                    
                    llOwnerSay(llList2CSV(split));
                }
                
                string timeleft;

                displayWindRate = setWindRate();
                integer minsLeft = llRound(timeLeftOnKey / (60.0 * displayWindRate));

                if (minsLeft > 0) {
                    timeleft = "Dolly has " + (string)minsLeft + " minutes remaining.\n";

                    timeleft += "Key is ";
                    if (windRate == 0.0) timeleft += "not ";
                    timeleft += "winding down";

                    if (windRate == 0.0) timeleft += ".";
                    else timeleft += " at " + formatFloat(displayWindRate, 1) + "x rate.";

                    timeleft += ". ";
                }
                else timeleft = "Dolly has no time left.";
                timeleft += "\n";

                string msg = "How many minutes would you like to wind?";

                llDialog(id, timeleft + msg, dialogSort(split + MAIN), dialogChannel);
            }
        }

        else if (code == 350) {
            RLVok = (llList2Integer(split, 0) == 1);
            rlvAPIversion = llList2String(split, 1);
            // When rlv confirmed....vefify collapse state... no escape!
            if (collapsed == 1 && timeLeftOnKey > 0) uncollapse(0);
            else if (!collapsed && timeLeftOnKey <= 0) lmInternalCommand("collapse", "0", NULL_KEY);

            if (!canDress) llOwnerSay("Other people cannot outfit you.");

            simRating = "";
            simRatingQuery = llRequestSimulatorData(llGetRegionName(), DATA_SIM_RATING);
        }

        else if (code == 500) {
            string choice = llList2String(split, 0);
            string name = llList2String(split, 1);
            
            if ((keyLimit < 1800.0) || (keyLimit > 25200.0)) {
                llOwnerSay("Max time setting " + (string)llRound(keyLimit / SEC_TO_MIN) + " mins is invalid must be between 30 and 420 mins resetting to 180 min default.");
                lmSendConfig("keyLimit", (string)(keyLimit = 10800.0));
            }
            float effectiveLimit = (DEMO_LIMIT * demoMode + keyLimit * !demoMode);
            if (timeLeftOnKey > effectiveLimit) timeLeftOnKey = effectiveLimit;
            
            if (id == NULL_KEY) return;
            
            // Deny access to the menus when the command was recieved from blacklisted avatar
            if (llListFindList(blacklist, [ (string)id ]) != -1) {
                lmSendToAgent("You are not permitted to access this key.", id);
                return;
            }
            
            float windLimit = effectiveLimit - timeLeftOnKey;

            if (choice == MAIN) {
                string windButton = "Wind...";
                if ((llGetListLength(windTimes) == 1) || ((llListStatistics(LIST_STAT_MIN, windTimes) * SEC_TO_MIN) < windLimit)) windButton = "Wind";
                lmInternalCommand("mainMenu", windButton + "|" + name, id);
            }
            else if (llGetSubString(choice, 0, 3) == "Wind") {
                if (choice == "Wind Times") return; // Handled in MenuHandler
                
                integer i = 0;
                
                if ((collapsed == 1) && (timeLeftOnKey > 0.0)) uncollapse(0);
                
                if (choice == "Wind Emg") {
                    // Give this a time limit: can only be done once
                    // in - say - 6 hours... at least maxwindtime *2 or *3.
                    
                    windamount = 0;

                    if (winderRechargeTime <= llGetUnixTime()) {
                        if (collapsed == 1) {
                            lmSendToController(dollName + " has activated the emergency winder.");

                            windamount = effectiveLimit * 0.2;
                            if (windamount > 3600.0) windamount = 3600.0;
                            lmSendConfig("winderRechargeTime", (string)(winderRechargeTime = (llGetUnixTime() + EMERGENCY_LIMIT_TIME)));
                            
                            llOwnerSay("With an electical sound the motor whirls into life and gives you " + (string)llRound(windamount / SEC_TO_MIN) + " minutes of life before it's battery wears out, it will take " + (string)llRound(EMERGENCY_LIMIT_TIME / 3600.0) + " hours to recharge.");
                        }
                        else if (collapsed == 2) {
                            llOwnerSay("The emergency winder motor whirrs, splutters and then falls silent unable to budge your jammed mechanism.");
                            return;
                        }
                        else {
                            llOwnerSay("The failsafe trigger fires with a soft click preventing the motor engaging while your mechanism is running.");
                            return;
                        }
                    }
                    else {
                       llOwnerSay("Emergency self-winder is not yet recharged there is still " + formatFloat(winderRechargeTime / 3600.0, 2) + " hours before it will be ready again.");
                       return;
                    }
                }
                else if (!canRepeat && (id == winderID) && !((id == NULL_KEY) || cdIsDoll(id) || cdIsController(id))) {
                    lmSendToAgent("Dolly needs to be wound by someone else before you can wind her again.", id);
                    return;
                }
                else if ((choice == "Wind...") || ((choice == "Wind") && (llGetListLength(windTimes) == 1))) {
                    split = windTimes;
                    if (demoMode) split = [1,2];
                    if (llGetListLength(split) == 0) {
                        split = [30];
                        lmSendConfig("windTimes","30");
                    }
                    if (llListStatistics(LIST_STAT_MIN, split) < (windLimit / SEC_TO_MIN)) {
                        lmInternalCommand("windMenu", name + "|" + (string)windLimit, id);
                        return;
                    }
                    windamount = llListStatistics(LIST_STAT_MIN, split) * SEC_TO_MIN;
                }
                else if (llGetListLength(windTimes) == 1) windamount = llList2Float(windTimes, 0) * SEC_TO_MIN;
                else if (choice == "Wind Full") windamount = effectiveLimit - timeLeftOnKey;
                else windamount = (float)llGetSubString(choice, 5, -1) * SEC_TO_MIN;
                
                if (collapsed == 1) uncollapse(0);
                
                if ((windamount + 60.0) > windLimit) {
                    windamount = windLimit;
                }
                
                if (windLimit < SEC_TO_MIN) {
                    lmSendConfig("timeLeftOnKey", (string)(timeLeftOnKey += windLimit));
                    llDialog(id, "Dolly is already fully wound.", [MAIN], dialogChannel);
                    return;
                }
            
                integer winding = llFloor(windamount / SEC_TO_MIN);
                lmSendConfig("timeLeftOnKey", (string)(timeLeftOnKey += windamount));
                
                if (choice != "Wind Emg") {
                    if (winding > 0) {
                        lmSendToAgent("You have given " + dollName + " " + (string)winding + " more minutes of life.", id);
                
                        if (collapsed == 1) uncollapse(0);
                
                        if (timeLeftOnKey == effectiveLimit) { // Fully wound
                            llOwnerSay("You have been fully wound - " + (string)llRound(effectiveLimit / (SEC_TO_MIN * displayWindRate)) + " minutes remaining.");
                            if (!quiet) llSay(0, dollName + " has been fully wound by " + name + ".");
                            else lmSendToAgent(dollName + " is now fully wound.", id);
                        } else {
                            lmSendToAgent("Doll is now at " + formatFloat((float)timeLeftOnKey * 100.0 / (float)effectiveLimit, 2) + "% of capacity.", id);
                            if (canRepeat || cdIsController(id)) {
                                // No menu respawn if no repeat option is enabled!
                                if (llGetListLength(windTimes) > 1) lmInternalCommand("windMenu", name + "|" + (string)(effectiveLimit - timeLeftOnKey), id);
                                else lmInternalCommand("mainMenu", "Wind" + "|" + name, id);
                            }
                        }
                
                        llSleep(1.0); // Make sure that the uncollapse RLV runs before sending the message containing winder name.
                        // Is this too spammy?
                        // As we are storing winderID for repeat wind how about this, give the reminder only when winder is new.
                        if (winderID != id) llOwnerSay("Have you remembered to thank " + name + " for winding you?");
                
                        winderID = id;
                    }
                }
            }
            else if (choice == "Max Time") {
                llDialog(id, "You can set the maximum wind time here.  Dolly cannot be wound beyond this amount of time.\nDolly currently has " + (string)llFloor(timeLeftOnKey / SEC_TO_MIN) + " mins left of " + (string)llFloor(keyLimit / SEC_TO_MIN) + ", if you choose a lower time than this they will lose time immidiately.", dialogSort(["45m", "60m", "75m", "90m", "120m", "150m", "180m", "240m", "300m", "360m", "480m", MAIN]), dialogChannel);
            }
            else if (llGetSubString(choice, -1, -1) == "m") {
                lmSendConfig("keyLimit", (string)(keyLimit = ((float)choice * SEC_TO_MIN)));
            }
        }
        
        else if (code == 501) {
            integer textboxType = llList2Integer(split, 0);
            split = llDeleteSubList(split, 0, 0);
            if (textboxType == 3) {
                split = llParseString2List(llDumpList2String(split, "|"), [" ",",","|"], []);

                lmInternalCommand("setWindTimes", llDumpList2String(split, "|"), id);
            }
        }

        else if (code == 850) {
            string type = llList2String(split, 0);
            string value = llList2String(split, 1);

                 if (type == "HTTPinterval")            HTTPinterval = (integer)value;
            else if (type == "HTTPthrottle")            HTTPthrottle = (integer)value;
            else if (type == "lastPostTimestamp")       lastPostTimestamp = (integer)value;
        }
    }

#ifndef DEVELOPER_MODE
    run_time_permissions(integer perm) {
        if (!llGetAttached()) llOwnerSay("@acceptpermission=rem");
        ifPermissions();
    }
#endif
}
