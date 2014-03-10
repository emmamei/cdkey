//========================================
// Avatar.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 28 February 2014

#include "include/GlobalDefines.lsl"
#include "include/Json.lsl"

//#define DEBUG_BADRLV

key carrierID = NULL_KEY;

key rlvTPrequest;
key requestLoadData;
key keyAnimationID;
key lastAttachedID;

list rlvSources;
list rlvStatus;

float baseWindRate;
float carryExpire;
float poseExpire;
float afkSlowWalkSpeed = 5;
float timeToJamRepair;
float refreshRate = 8.0;

vector carrierPos;
vector lockPos;

string barefeet;
string carrierName;
string keyAnimation;
string myPath;
string pronounHerDoll = "Her";
string pronounSheDoll = "She";
string rlvAPIversion;
string redirchan;
string userBaseRLVcmd;

integer afk;
integer carryMoved;
integer channel;
integer clearAnim = 1;
integer collapsed;
integer confgured;
integer dialogChannel;
integer listenHandle;
integer locked;
integer lowScriptMode;
integer poseSilence;
integer RLVck = -1;
integer RLVrecheck;
integer RLVok;
integer RLVstarted;
integer startup = 1;
integer targetHandle;
integer ticks;
integer timerOn;
integer wearLock;
integer newAttach = 1;
integer creatorNoteDone;
integer lastPostTimestamp;
integer HTTPinterval;

//========================================
// FUNCTIONS
//========================================
key animStart(string animation) {
    if ((llGetPermissionsKey() != dollID) || ((llGetPermissions() & PERMISSION_TRIGGER_ANIMATION) == 0)) return NULL_KEY;

    while (llGetListLength(llGetAnimationList(dollID))) llStopAnimation(llList2Key(llGetAnimationList(dollID), 0));

    integer i; key animID = llGetInventoryKey(animation);
    list oldList = llGetAnimationList(dollID);
    llStartAnimation(animation);
    list newList = llGetAnimationList(dollID);

    while (llGetListLength(oldList)) {
        key animKey = llList2Key(oldList, 0); integer index;
        while ((index = llListFindList(newList, [ animKey ])) != -1) newList = llDeleteSubList(newList, index, index);

        oldList = llDeleteSubList(oldList, 0, 0);
    }

    if (animID) return animID;
    else if (llGetListLength(newList) == 1) return llList2Key(newList, 0);
    else return NULL_KEY;
}
//----------------------------------------
// RLV Initialization Functions
//----------------------------------------
checkRLV()
{ // Run RLV viewer check
    locked = 0;
    if (cdAttached()) {
        if (RLVck == -1) {
            // Setting the above debug flag causes the listener to not be open for the check
            // In effect the same as the viewer having no RLV support as no reply will be heard
            // all other code works as normal.
#ifdef DEBUG_BADRLV
#define LISTEN_OPEN 0
#else
#define LISTEN_OPEN 1
#endif
            llListenControl(listenHandle, LISTEN_OPEN);
            llSetTimerEvent(10.0);
            RLVck = 1;
            RLVok = 0;
            RLVstarted = 0;
    
            rlvAPIversion = "";
            myPath = "";
#ifdef DEVELOPER_MODE
            llOwnerSay("@versionnew=" + (string)channel + ",getpathnew=" + (string)channel);
#else
            llOwnerSay("@versionnew=" + (string)channel);
#endif
        }
        else if ((RLVck != 0) && (RLVck < 5)) {
#ifdef DEVELOPER_MODE
            RLVok = ((rlvAPIversion != "") && (myPath != ""));
#else
            RLVok = (rlvAPIversion != "");
#endif
        }
    }
    
    if (!cdAttached() || (configured && (RLVok || (RLVck == 5)))) {
        if (!RLVstarted && !RLVrecheck) {
            if (RLVok && !newAttach) llOwnerSay("Logged with Community Doll Key and " + rlvAPIversion + " active...");
            else if (RLVok && newAttach) llOwnerSay("Reattached Community Doll Key with " + rlvAPIversion + " active...");
            else if (cdAttached() && !RLVok) llOwnerSay("Did not detect an RLV capable viewer, RLV features disabled.");
        }
    
        initializeRLV(0); // Do RLV report and initialized if appropriate
    }
}

ifPermissions() {
    if (cdAttached()) {
        key grantorID = llGetPermissionsKey();
        integer permMask = llGetPermissions();

        if (grantorID != NULL_KEY && grantorID != dollID) {
            llResetOtherScript("Start.lsl");
            llSleep(10.0);
        }

        if (!((permMask & PERMISSION_MASK) == PERMISSION_MASK))
            llRequestPermissions(dollID, PERMISSION_MASK);

        if (grantorID == dollID) {
            if (permMask & PERMISSION_TRIGGER_ANIMATION) {
                key curAnim = llList2Key(llGetAnimationList(dollID), 0);
                
                if (keyAnimationID) {
                    debugSay(7, "DEBUG", "animID=" + (string)keyAnimationID + " curAnim=" + (string)curAnim + " refreshRate=" + (string)refreshRate);
                    if (keyAnimationID == NULL_KEY) refreshRate = 4.0;          // In case anim is no mod use default 4 sec
                    else if (curAnim == keyAnimationID) {
                        refreshRate += (1.0/llGetRegionFPS());                  // +1 Frame
                        if (refreshRate > 30.0) refreshRate = 30.0;             // 30 Second limit
                    }
                    else if (curAnim != keyAnimationID) {
                        refreshRate /= 2.0;                                     // -50%
                        if (refreshRate < 0.022) refreshRate = 0.022;           // Limit once per frame
                    }
                }
                
                if (!clearAnim && (keyAnimation != "")) {
                    llWhisper(LOCKMEISTER_CHANNEL, (string)dollID + "bootoff");

                    list animList; integer i; integer animCount;
                    key animKey = keyAnimationID;
                    if (animKey == NULL_KEY) animKey = llGetInventoryKey(keyAnimation);
                    if (animKey) {
                        while ((animList = llGetAnimationList(dollID)) != [ animKey ]) {
                            animCount = llGetListLength(animList);
                            for (i = 0; i < animCount; i++) {
                                if (llList2Key(animList, i) != animKey) llStopAnimation(llList2Key(animList, i));
                            }
                            llStartAnimation(keyAnimation);
                        }
                    }
                    else animKey = animStart(keyAnimation);
                    if ((keyAnimationID == NULL_KEY) && (animKey != NULL_KEY)) lmSendConfig("keyAnimationID", (string)(keyAnimationID = animKey));
                    if (cdCollapsedAnim()) lmSendConfig("poseExpire", (string)(poseExpire = 0.0));
                } else if (clearAnim) {
                    list animList = llGetAnimationList(dollID);
                    integer i; integer animCount = llGetInventoryNumber(20);
                    for (i = 0; i < animCount; i++) {
                        key animKey = llGetInventoryKey(llGetInventoryName(20, i));
                        if (llListFindList(animList, [ llGetInventoryKey(llGetInventoryName(20, i)) ]) != -1)
                            llStopAnimation(animKey);
                    }
                    clearAnim = 0;
                    llWhisper(LOCKMEISTER_CHANNEL, (string)dollID + "booton");
                    
                    lmSendConfig("keyAnimation", (keyAnimation = ""));
                    lmSendConfig("keyAnimationID", (string)(keyAnimationID = NULL_KEY));
                    lmSendConfig("poserID", (string)(poserID = NULL_KEY));
                    lmSendConfig("poseExpire", (string)(poseExpire = 0.0));
                }
            }

            if (permMask & PERMISSION_OVERRIDE_ANIMATIONS) {
                if (keyAnimation != "") {
                    llSetAnimationOverride("Standing", keyAnimation);
                }
                else llResetAnimationOverride("ALL");
            }

            if (permMask & PERMISSION_TAKE_CONTROLS) {
                llTakeControls(CONTROL_MOVE, 0, 1);

                if (keyAnimation != "") {
                    if (lockPos == ZERO_VECTOR) lmSendConfig("lockPos", (string)(lockPos = llGetPos()));
                    if (llVecDist(llGetPos(), lockPos) > 1.0) {
                        llTargetRemove(targetHandle);
                        targetHandle = llTarget(lockPos, 1.0);
                        llMoveToTarget(lockPos, 0.7);
                    }
                    llTakeControls(CONTROL_ALL, 1, 0);
                }
                else {
                    if (lockPos != ZERO_VECTOR) lmSendConfig("lockPos", (string)(lockPos = ZERO_VECTOR));
                    llTargetRemove(targetHandle);
                    llStopMoveToTarget();
                    if (cdCarried()) {
                        vector carrierPos = llList2Vector(llGetObjectDetails(carrierID, [ OBJECT_POS ]), 0);
                        targetHandle = llTarget(carrierPos, CARRY_RANGE);
                    }
                    if (afk) llTakeControls(CONTROL_SLOW, 1, 1);
                }
            }
        }
    }

    if (!collapsed && (keyAnimation == "") && (timeToJamRepair == 0.0)) {
        if (RLVck == 0) {
            llSetTimerEvent(0.0);
            if (timerOn) debugSay(5, "DEBUG", "Timer suspended, awaiting activity.");
            timerOn = 0;
        }
    }
    else {
        if (RLVck == 0) {
            float interval = refreshRate;
            if (lowScriptMode) interval *= 2;
            llSetTimerEvent(interval);
            if (!timerOn) {
                debugSay(1, "DEBUG", "Timer activated, interval " + formatFloat(interval, 3) + " seconds");
                llResetTime();
                timerOn = 1;
            }
        }
    }
}

initializeRLV(integer refresh) {
    if (refresh && !RLVstarted) return;
#ifdef DEVELOPER_MODE
    if ((rlvAPIversion != "") && (myPath == "")) { // Dont enable RLV on devs if @getpath is returning no usable result to avoid lockouts.
        llSay(DEBUG_CHANNEL, "WARNING: Sanity check failure developer key not found in #RLV see README.dev for more information.");
        return;
    }
#endif
    string baseRLV;
    if (RLVok && !RLVstarted) llOwnerSay("Enabling RLV mode");

    if (!RLVstarted) lmRLVreport(RLVok, rlvAPIversion, 0);

    // if Doll is one of the developers... dont lock:
    // prevents inadvertent lock-in during development
#ifndef DEVELOPER_MODE
    // We lock the key on here - but in the menu system, it appears
    // unlocked and detachable: this is because it can be detached
    // via the menu. To make the key truly "undetachable", we get
    // rid of the menu item to unlock it
    if (llGetInventoryCreator("Main.lsl") != dollID) {
        lmRunRLVas("Base", "detach=n,permissive=n");  //locks key
    
        locked = 1; // Note the locked variable also remains false for developer mode keys
                    // This way controllers are still informed of unauthorized detaching so developer dolls are still accountable
                    // With this is the implicit assumption that controllers of developer dolls will be understanding and accepting of
                    // the occasional necessity of detaching during active development if this proves false we may need to fudge this
                    // in the section below.
    }
    else if (RLVok && !RLVstarted) llSay(DEBUG_CHANNEL, "Backup protection mechanism activated not locking on creator");
#else
    if (RLVok && !RLVstarted) {
        if (!quiet) llSay(0, "Developer Key not locked.");
        else llOwnerSay("Developer key not locked.");
    }
    baseRLV += "attachallthis_except:" + myPath + "=add,detachallthis_except:" + myPath + "=add,";
#endif
    llListenControl(listenHandle, 0);

    integer posed = (cdPosed() && !cdSelfPosed());
    integer carried = cdCarried();

    if (userBaseRLVcmd != "") lmRunRLVas("User:Base", userBaseRLVcmd);

    string command; integer i;

    cdLoadData(RLV_NC, RLV_BASE_RESTRICTIONS);

    RLVstarted = (RLVstarted | RLVok);
    if (!refresh) {
        RLVck = 0;
        startup = 0;
    }

#ifndef DEVELOPER_MODE
    if (llGetInventoryCreator("Main.lsl") == dollID) lmRunRLVas("Base", "clear=unshared,clear=achallthis");
#endif
}

default {
    state_entry() {
        dollID = llGetOwner();
        dollName = llGetDisplayName(dollID);

        // Get a unique number
        channel = (integer)("0x" + llGetSubString((string)llGenerateKey(),-7,-1)) + 3467;
        listenHandle = llListen(channel, "", "", "");
        llListenControl(listenHandle, 0);

        llRequestPermissions(dollID, PERMISSION_MASK);
    }

    on_rez(integer start) {
        locked = 0;
        startup = 0;
        
        RLVck = -1;

        rlvAPIversion = "";

        if (lockPos != ZERO_VECTOR) {
            llStopMoveToTarget();
            llTargetRemove(targetHandle);
            lockPos = llGetPos();
            targetHandle = llTarget(lockPos, 1);
        }
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
        if (change & CHANGED_OWNER) {
            llSleep(60);
        }
    }

    listen(integer chan, string name, key id, string msg) {
        if (chan == channel) {
            msg = llStringTrim(msg, STRING_TRIM);
            if (llGetSubString(msg, 0, 13) == "RestrainedLove") {
                if (rlvAPIversion == "") debugSay(4, "DEBUG-RLV", "RLV Version: " + msg);
                rlvAPIversion = msg; 
            }
            else {
                if (myPath == "") debugSay(4, "DEBUG-RLV", "RLV Key Path: " + msg);
                myPath = msg;
            }
            checkRLV();
        }
        //if (!RLVok && !RLVstarted) llOwnerSay("@clear,versionnew=" + (string)channel);
        //else if (RLVok && myPath == "") llOwnerSay("@getpathnew=" + (string)channel);
    }

    attach(key id) {
        if (id == NULL_KEY && !detachable && !locked) {
            // Undetachable key with controller is detached while RLV lock
            // is not available inform any key controllers.
            // We send no message if the key is RLV locked as RLV will reattach
            // automatically this prevents neusance messages when defaultwear is
            // permitted.
            // Q: Should that be changed? Not sure the message serves much purpose with *verified* RLV and known lock.
            lmSendToController(dollName + " has bypassed the key attachment lock and removed " + llToLower(pronounHerDoll) + " key. Appropriate authorities have been notified of this breach of security.");
        }

        locked = 0;

        if (lockPos != ZERO_VECTOR) {
            llStopMoveToTarget();
            llTargetRemove(targetHandle);
            lockPos = llGetPos();
            targetHandle = llTarget(lockPos, 1);
        }

        if (id) checkRLV();

        newAttach = (lastAttachedID != dollID);
        lastAttachedID = id;
    }

    link_message(integer sender, integer code, string data, key id) {
        list split =        llParseString2List(data, ["|"], []);
        string script =     llList2String(split,0);
        integer line  =     llList2Integer(split, 1);
        integer seq =       (code & 0xFFFF0000) >> 16;
        integer opt =       (code & 0x00000D00) >> 10;
        integer code =      (code & 0x000002FF);
             split   =      llDeleteSubList(split,0,1+opt);
        
        integer posed = cdPosed();

        scaleMem();

        if (code == 102) {
            configured = 1;
            return;
        }
        else if (code == 110) {
            ifPermissions();
            RLVrecheck = 0;
            checkRLV();
            return;
        }
        else if (code == 135) {
            float delay = llList2Float(split, 0);
            memReport(cdMyScriptName(),delay);
            return;
        }
        
        cdConfigReport();
        
        else if (code == 300) {
            string name = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);
            string value = llList2String(split, 0);

                 if (name == "autoTP")                       autoTP = (integer)value;
            else if (name == "afk")                             afk = (integer)value;
            else if (name == "collapsed") {
                collapsed = (integer)value;
                if (collapsed && !cdNoAnim()) lmInternalCommand("doUnpose", "", NULL_KEY);
                if (!collapsed && cdCollapsedAnim()) lmSendConfig("keyAnimation", (keyAnimation = ""));
            }
            else if (name == "canFly")                       canFly = (integer)value;
            else if (name == "canSit")                       canSit = (integer)value;
            else if (name == "canStand")                   canStand = (integer)value;
            else if (name == "canWear")                     canWear = (integer)value;
            else if (name == "helpless")                   helpless = (integer)value;
            else if (name == "poseSilence")             poseSilence = (integer)value;
            else if (name == "userBaseRLVcmd") {
                if (userBaseRLVcmd == "") userBaseRLVcmd = value;
                else userBaseRLVcmd += "," +value;
            }
            else if (name == "keyAnimation") {
                keyAnimation = value;

                if (collapsed && !cdNoAnim()) lmInternalCommand("doUnpose", "", NULL_KEY);
                if (!collapsed && cdCollapsedAnim()) lmSendConfig("keyAnimation", (keyAnimation = ""));

                if (keyAnimation == "") lmSendConfig("keyAnimationID", (string)(keyAnimationID = NULL_KEY));
                else lmSendConfig("keyAnimationID", (string)(keyAnimationID = animStart(keyAnimation)));
            }
            else {
                     if (name == "detachable")               detachable = (integer)value;
                else if (name == "barefeet")                   barefeet = value;
#ifdef DEVELOPER_MODE
                else if (name == "debugLevel")               debugLevel = (integer)value;
#endif
                else if (name == "lowScriptMode")         lowScriptMode = (integer)value;
                else if (name == "MistressList")           MistressList = split;
                else if (name == "pronounHerDoll")       pronounHerDoll = value;
                else if (name == "pronounSheDoll")       pronounSheDoll = value;
                else if (name == "poserID")                     poserID = (key)value;
                else if (name == "poseExpire")               poseExpire = (float)value;
                else if (name == "quiet")                         quiet = (integer)value;
                else if (name == "dialogChannel")         dialogChannel = (integer)value;
                else if (name == "timeLeftOnKey") {
                    if ((collapsed == 1) && ((float)value > 0.0)) {
                        lmInternalCommand("uncollapse", "", NULL_KEY);
                    }
                }
                else if (name == "keyAnimationID") {
                    keyAnimationID = (key)value;
                    ifPermissions();
                }
                else if (name == "dollType") {
                    if (dollType == value) return;
                    else {
                        if (configured && posed && (poserID != dollID)) {
                            if (value == "Display")
                                llOwnerSay("As you feel yourself become a display doll you feel a sense of helplessness knowing you will remain posed until released.");
                            else if (dollType == "Display")
                                llOwnerSay("You feel yourself transform to a " + value + " doll and know you will soon be free of your pose when the timer ends.");
                            dollType = value;
                            lmInternalCommand("setPose", keyAnimation, NULL_KEY);
                        }
                        else dollType = value;
                    }
                }
                return;
            }
        }
        else if (code == 305) {
            string cmd = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "carry") {
                string name = llList2String(split, 0);

                carrierID = id;
                carrierName = name;
            }
            else if (cmd == "doUnpose") {
                if (!cdCollapsedAnim()) clearAnim = 1;
            }
            else if (cmd == "setPose" && !collapsed) {
                string pose = llList2String(split, 0);

                // Force unsit before posing
                lmRunRLV("unsit=force");

                // Set pose expire timeourt unless we are a display doll or are self posed
                if ((dollType != "Display") && (poserID != dollID)) lmSendConfig("poseExpire", (string)(poseExpire = POSE_LIMIT));
                lmSendConfig("keyAnimation", (keyAnimation = pose));
                lmSendConfig("poserID", (string)(poserID = id));
            }
#ifdef ADULT_MODE
            else if (cmd == "strip") {
                string choice = llList2String(split, 0);
                if (choice == "Top") cdLoadData(RLV_NC, RLV_STRIP_TOP);
                else if (choice == "Bra") cdLoadData(RLV_NC, RLV_STRIP_BRA);
                else if (choice == "Bottom") cdLoadData(RLV_NC, RLV_STRIP_BOTTOM);
                else if (choice == "Panties") cdLoadData(RLV_NC, RLV_STRIP_PANTIES);
                else if (choice == "Shoes") {
                    cdLoadData(RLV_NC, RLV_STRIP_SHOES);
                    if (barefeet != "") lmRunRLVas("Dress.lsl","attachallover:" + barefeet + "=force");
                }
            }
#endif
            else if (cmd == "uncarry") {
                carrierID = NULL_KEY;
                carrierName = "";
            }
            else if (llGetSubString(cmd, 2, -1) == "collapse") {
                collapsed = llList2Integer(split, 0);
                if (!collapsed) clearAnim = 1;
                else lmSendConfig("keyAnimation", (keyAnimation = ANIMATION_COLLAPSED));
            }
            else if (cmd == "TP") {
                string lm = llList2String(split, 0);
                llRegionSayTo(id, 0, "Teleporting dolly " + dollName + " to  landmark " + lm + ".");
                rlvTPrequest = llRequestInventoryData(lm);
                return;
            }
            else if (cmd == "detach") {
                if (RLVok || RLVstarted) llOwnerSay("@clear,detachme=force");
                else llDetachFromAvatar();
                return;
            }
            else if (cmd == "getTimeUpdates") {
                if (poseExpire != 0.0) lmSendConfig("poseExpire", (string)poseExpire);
                if (timeToJamRepair != 0.0) lmSendConfig("timeToJamRepair", (string)timeToJamRepair);
                return;
            }
            else if (cmd == "wearLock") lmSendConfig("wearLock", (string)(wearLock = llList2Integer(split, 0)));
            else return;
        }
        else if (code == 500) {
            string choice = llList2String(split,0);
            string name = llList2String(split, 1);

            if ((choice == "Carry") && !cdIsDoll(id)) {
                // Doll has been picked up...
                carrierID = id;
                carrierName = name;
                lmInternalCommand("carry", carrierName, carrierID);
                lmInternalCommand("mainMenu", "", id);
            }
            else if ((choice == "Uncarry") && cdIsCarrier(id)) {
                // Doll has been placed down...
                llMessageLinked(LINK_THIS, 305, llGetScriptName() + "|uncarry|" + carrierName, carrierID);
                carrierID = NULL_KEY;
                carrierName = "";
                lmInternalCommand("mainMenu", "", id);
            }
            else if (choice == "*RLV On*") {
                if (RLVok == 0) {
                    llOwnerSay("Trying to enable RLV, you must have a compatible viewer and the RLV setting enabled for this to work.");
                    RLVck = -1;
                    lmRLVreport(-1,"",0);
                    RLVrecheck = 1;
                    checkRLV();
                }
                else checkRLV();
            }
            else if ((!cdIsDoll(id) || cdSelfPosed()) && choice == "Unpose") {
                lmInternalCommand("doUnpose", "", id);
            }
            else if ((keyAnimation == "" || (!cdIsDoll(id) || cdSelfPosed())) && llGetInventoryType(choice) == 20) {
                keyAnimation = choice;
                lmInternalCommand("setPose", choice, id);
                poserID = id;
            }
            else if ((keyAnimation == "" || (!cdIsDoll(id) || cdSelfPosed())) && llGetInventoryType(llGetSubString(choice, 2, -1)) == 20) {
                keyAnimation = llGetSubString(choice, 2, -1);
                lmInternalCommand("setPose", llGetSubString(choice, 2, -1), id);
                poserID = id;
            }
            
            return;
        }
        else if (code == 850) {
            string type = llList2String(split, 0);
            string value = llList2String(split, 1);

            if (type == "HTTPinterval")             HTTPinterval = (integer)value;
            if (type == "lastPostTimestamp")        lastPostTimestamp = (integer)value;
            
            return;
        }
        else return;
        
        ifPermissions();
        initializeRLV(1);
    }

    timer() {
        if (RLVck == 0) {
            float timerInterval = llGetAndResetTime();

            if (poseExpire != 0.0) poseExpire -= timerInterval;
            if (timeToJamRepair != 0) timeToJamRepair -= timerInterval;

            if (ticks % llRound(60.0 / refreshRate) == 0) {
                // Check if doll is posed and time is up
                if (poseExpire != 0.0) {
                    if (poseExpire < 0.0) { // Pose expire is set and has passed
                        lmSendConfig("poseExpire", (string)(poseExpire = 0.0));
                        lmInternalCommand("doUnpose", "", NULL_KEY);
                    }
                }
    
                // Check if jam time passes
                if (timeToJamRepair != 0.0) {
                    if (timeToJamRepair < 0.0) {
                        timeToJamRepair = 0.0;
                        lmInternalCommand("uncollapse", "", NULL_KEY);
                    }
                    lmSendConfig("timeToJamRepair", (string)timeToJamRepair);
                }
            }
        }
        else {
            if (!RLVok) {
                string check;
                if (rlvAPIversion == "") check += "versionnew=" + (string)channel;
#ifdef DEVELOPER_MODE
                if (myPath == "") {
                    if (check != "") check += ",";
                    check += "getpathnew=" + (string)channel;
                }
#endif
                llOwnerSay("@"+check);
            }
            checkRLV();
            llSetTimerEvent(10.0 * (float)(RLVck++));
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

        if (cdCarried()) {
            if (keyAnimation == "") {
                // Get updated position and set target
                carrierPos = llList2Vector(llGetObjectDetails(carrierID, [OBJECT_POS]), 0);
                targetHandle = llTarget(carrierPos, CARRY_RANGE);
            }
            else {
                if (lockPos != ZERO_VECTOR) lockPos = llGetPos();
                targetHandle = llTarget(lockPos, 0.5);
            }
        }

        if (carryMoved) {
            vector pointTo = target - llGetPos();
            float  turnAngle = llAtan2(pointTo.x, pointTo.y);
            lmRunRLV("setrot:" + (string)(turnAngle) + "=force");
            carryMoved = 0;
        }
    }

    //----------------------------------------
    // NOT AT FOLLOW/MOVELOCK TARGET
    //----------------------------------------
    not_at_target() {
        if (cdNoAnim() && cdCarried()) {
            vector newCarrierPos = llList2Vector(llGetObjectDetails(carrierID,[OBJECT_POS]),0);
            llStopMoveToTarget();

            if (carrierPos != newCarrierPos) {
                llTargetRemove(targetHandle);
                carrierPos = newCarrierPos;
                targetHandle = llTarget(carrierPos, CARRY_RANGE);
            }
            if (carrierPos != ZERO_VECTOR) {
                llMoveToTarget(carrierPos, 0.7);
                carryExpire = CARRY_TIMEOUT;
                carryMoved = 1;
            }
            else if (cdCarried() && llGetTime() > carryExpire) uncarry();
        }
        else if (!cdNoAnim()) {
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
        if (!(llGetAgentInfo(llGetOwner())&AGENT_WALKING)) {
            llApplyImpulse(<0, 0, 0>, TRUE);
        }
        else {
            if (afk && (keyAnimation == "")  && (id == dollID)) {
                if (level & ~edge & CONTROL_FWD) llApplyImpulse(<-1, 0, 0> * afkSlowWalkSpeed, TRUE);
                if (level & ~edge & CONTROL_BACK) llApplyImpulse(<1, 0, 0> * afkSlowWalkSpeed, TRUE);
            }
        }
    }

    dataserver(key request, string data) {
        if (request == rlvTPrequest) {
            vector global = llGetRegionCorner() + (vector)data;

            string locx = (string)llFloor(global.x);
            string locy = (string)llFloor(global.y);
            string locz = (string)llFloor(global.z);

            llOwnerSay("Dolly is now teleporting.");

            lmRunRLVas("TP", "tpto:" + locx + "/" + locy + "/" + locz + "=force");
        }
        if (request == requestLoadData) {
            integer dataType = (integer)cdGetValue(data, [0]);

            if (dataType == RLV_STRIP) {
                string part = cdGetValue(data, [1]);
                string value; integer i;
                while ( ( value = cdGetValue(data, ([2,"attachments",i++])) ) != JSON_INVALID ) lmRunRLV("remattach:" + value + "=force");
                i = 0;
                while ( ( value = cdGetValue(data, ([2,"layers",i++])) ) != JSON_INVALID ) lmRunRLV("remoutfit:" + value + "=force");

                initializeRLV(1);
            }
            else if (dataType == RLV_RESTRICT) {
                string restrictions;
                integer group = -1; integer setState;
                integer posed = (cdPosed() && (poserID != dollID));
                list states = [ (autoTP), (!canFly || posed || collapsed || afk), (collapsed), (!canSit || collapsed || posed), (!canStand || collapsed || posed), (collapsed || (posed && poseSilence) ), (helpless || afk || cdCarried() || collapsed || posed), (afk || cdCarried() || collapsed || posed), (!canWear || collapsed || wearLock || afk) ];
                integer index;

                while ( ( index = llSubStringIndex(data, "$C") ) != -1) {
                    if (redirchan == "") redirchan = (string)llRound(llFrand(0x7fffffff));
                    data = llInsertString(llDeleteSubString(data, index, index + 1), index, redirchan);
                }

                //cdRlvSay("@clear=redir");
                while (cdGetElementType(data, ([1,++group])) != JSON_INVALID) {
                    setState = llList2Integer(states, group);
                    cdSetRestrictionsList(data,setState);
                }
            }
        }
    }

    run_time_permissions(integer perm) {
        ifPermissions();
    }
}
