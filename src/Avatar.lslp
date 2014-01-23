#include "include/GlobalDefines.lsl"

key carrierID = NULL_KEY;

key rlvTPrequest;

list rlvSources;
list rlvStatus;

float baseWindRate;
float carryExpire;
float poseExpire;
float timeToJamRepair;

vector carrierPos;
vector lockPos;

string barefeet;
string carrierName;
string keyAnimation;
string myPath;
string pronounHerDoll;
string pronounSheDoll;
string rlvAPIversion;
string scriptName;
string userBaseRLVcmd;
string userCollapseRLVcmd;

integer afk;
integer badAttach;
integer carryMoved;
integer channel;
integer clearAnim = 1;
integer collapsed;
integer confgured;
integer dialogChannel;
integer initComplete;
integer initState = 104;
integer listenHandle;
integer locked;
integer lowScriptMode;
integer RLVck;
integer RLVok;
integer RLVstarted;
integer startup = 1;
integer targetHandle;
integer ticks;
integer wearLock;

//========================================
// FUNCTIONS
//========================================

listenerStart() {
    // Get a unique number
    channel = (integer)("0x" + llGetSubString((string)llGenerateKey(),-7,-1)) + 3467;
    listenHandle = llListen(channel, "", "", "");
    llListenControl(listenHandle, 0);
}

//----------------------------------------
// RLV Initialization Functions
//----------------------------------------
checkRLV()
{ // Run RLV viewer check
    locked = 0;
    if (!RLVok && isAttached) {
        #ifndef DEBUG_BADRLV
        // Setting the above debug flag causes the listener to not be open for the check
        // In effect the same as the viewer having no RLV support as no reply will be heard
        // all other code works as normal.
        llListenControl(listenHandle, 1);
        #endif
        llSetTimerEvent(5.0);
        RLVck = 1;
        
        llOwnerSay("@clear,versionnew=" + (string)channel);
    }
    else processRLVResult(); // Attachment precondition failed procceed with negative result
}

processRLVResult()
{ // Handle RLV check result
    llSetTimerEvent(0.0);
    if (RLVok) llOwnerSay("Logged with Community Doll Key and " + rlvAPIversion + " active...");
    else if (isAttached && !RLVok) llOwnerSay("Did not detect an RLV capable viewer, RLV features disabled.");
    
    // Mark RLV check completed
    RLVck = 0;
    
    if (configured) initializeRLV(0);
}

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
                if (!afk) llTakeControls(CONTROL_ALL, 0, 1);
                else llTakeControls(CONTROL_MOVE, 1, 1);
            }
        }
    }
}

initializeRLV(integer refresh) {
    if ((refresh && !RLVok) || (!refresh && RLVstarted)) return;
    #ifdef DEVELOPER_MODE
    if (myPath == "") return; // Dont enable RLV on devs if @getpathnew is returning no usable result to avoid lockouts.
    #endif
    if (RLVok && isAttached) {
        if (!RLVstarted) {
            llOwnerSay("Enabling RLV mode");
            rlvSources = [];
            rlvStatus = [];
        }
        
        if (!RLVstarted) {
            llMessageLinked(LINK_SET, 350, (string)RLVok + "|" + rlvAPIversion, NULL_KEY);
        }
        
        // if Doll is one of the developers... dont lock:
        // prevents inadvertent lock-in during development
        #ifndef DEVELOPER_MODE
        // We lock the key on here - but in the menu system, it appears
        // unlocked and detachable: this is because it can be detached 
        // via the menu. To make the key truly "undetachable", we get
        // rid of the menu item to unlock it
        doRLV("Base", "detach=n,editobj:" + (string)llGetKey() + "=add");  //locks key
        locked = 1; // Note the locked variable also remains false for developer mode keys
                    // This way controllers are still informed of unauthorized detaching so developer dolls are still accountable
                    // With this is the implicit assumption that controllers of developer dolls will be understanding and accepting of
                    // the occasional necessity of detaching during active development if this proves false we may need to fudge this
                    // in the section bellow the #else preprocessor directive.
        #else
        if (myPath != "") {
            doRLV("Base", "attachallthis_except:" + myPath + "=add,detachallthis_except:" + myPath + "=add");
            llListenControl(listenHandle, 0);
        }
        if (!RLVstarted) {
            if (!quiet) llSay(0, "Developer Key not locked.");
            else llOwnerSay("Developer key not locked.");
        }
        
        if (myPath != "") {
        #endif
            if (userBaseRLVcmd != "")
                doRLV("User:Base", userBaseRLVcmd);
            
            string baseRLV = "accepttp=";
            if (autoTP) baseRLV += "add,";
            else baseRLV += "rem,";
            if (helpless) baseRLV += "tplm=n,tploc=n,";
            else baseRLV += "tplm=y,tploc=y,";
            if (!canFly) baseRLV += "fly=n,";
            else baseRLV += "fly=y,";
            if (!canStand) baseRLV += "unsit=n,";
            else baseRLV += "unsit=y,";
            if (!canSit) baseRLV += "sit=n,";
            else baseRLV += "sit=y,";
            
            if (!collapsed && carrierID != NULL_KEY) doRLV("Carry", "tplm=n,tploc=n,accepttp=rem,tplure=n,showinv=n," + getAutoTPList());
            else doRLV("Carry", "clear");
            
            if (!collapsed && keyAnimation != "") doRLV("Pose", "fartouch=n,fly=n,showinv=n,sit=n,sittp=n,standtp=n,touchattachother=n,tplm=n,tploc=n,unsit=n");
            else doRLV("Pose", "clear");
            
            if (afk || !canWear || collapsed || wearLock) doRLV("Dress", "unsharedwear=n,unsharedunwear=n,attachallthis:=n,detachallthis:=n");
            else doRLV("Dress", "clear");
            
            doRLV("Base", baseRLV);
            
            if (afk || collapsed) {
                afkOrCollapse("Power", 1);
                if (collapsed && userCollapseRLVcmd != "") doRLV("UserCollapsed", userCollapseRLVcmd);
            }
            else {
                afkOrCollapse("Power", 0);
            }
            if (!collapsed) doRLV("Power:User", "clear");
        #ifdef DEVELOPER_MODE
        }
        #endif
        
        if (!RLVstarted) RLVstarted = 1;
    }
    
    startup = 0;
}

afkOrCollapse(string type, integer set) {
    string RLV;
    
    if (set) {
        RLV = "fly=n,tplm=n,tploc=n,temprun=n,alwaysrun=n,sendchat=n,";
        RLV += "sittp=n,standtp=n,shownames=n,";
        if (collapsed) {
            RLV += "sit=n,unsit=n,showhovertextall=n,redirchat:999=add,rediremote:999=add,";
            RLV += "tplure=n,";
        }
        RLV += getAutoTPList();
    }
    else RLV = "clear";
    
    doRLV(type, RLV);
}

// Only useful if @tplure and @accepttp are off and denied by default...
string getAutoTPList() {
    list allow = [ AGENT_CHRISTINA_HALPIN, AGENT_GREIGHIGHLAND_RESIDENT, AGENT_MAYSTONE_RESIDENT, AGENT_SILKY_MESMERISER ];
    if (MistressList != []) allow += llList2ListStrided(MistressList, 0, -1, 2);
    if (carrierID != NULL_KEY) allow += carrierID;
    integer loop; key userID;
    string RLV = "tplure:" + llDumpList2String(allow, "=add,tplure:") + "=add,";
    RLV += "accepttp:" + llDumpList2String(allow, "=add,accepttp:") + "=add";
    return RLV;
}

rlvTeleportToVector(vector global) {
    string locx = (string)llFloor(global.x);
    string locy = (string)llFloor(global.y);
    string locz = (string)llFloor(global.z);
    
    llOwnerSay("Dolly is now teleporting.");
    
    llOwnerSay("@tpto:" + locx + "/" + locy + "/" + locz + "=force");
}

doRLV(string module, string command) {
    llMessageLinked(LINK_THIS, 315, module + "|" + command, NULL_KEY);
}

default {
    state_entry() {
        dollID = llGetOwner();
        scriptName = llGetScriptName();
        if (!isAttached) badAttach = 1;
        lmScriptReset();
        listenerStart();
        checkRLV();
        llRequestPermissions(dollID, PERMISSION_MASK);
        lmScriptReset();
        dialogChannel = 0x80000000 | (integer)("0x" + llGetSubString((string)llGetLinkKey(2), -8, -1));
    }
    
    on_rez(integer start) {
        if (!isAttached) badAttach = 1;
        RLVstarted = 0;
        RLVok = 0;
        locked = 0;
        startup = 0;
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
    
    listen(integer chan, string name, key id, string msg) {
        if (chan == channel) {
            debugSay(5, "RLV Reply: " + msg);
            if (llGetSubString(msg, 0, 13) == "RestrainedLove") {
                RLVok = 1;
                rlvAPIversion = llStringTrim(msg, STRING_TRIM);
                #ifndef DEVELOPER_MODE
                processRLVResult();
                #endif
            }
            else {
                myPath = msg;
                processRLVResult();
            }
        }
    }
    
    link_message(integer sender, integer code, string data, key id) {
        list split = llParseStringKeepNulls(data, [ "|" ], []);
        
        scaleMem();
        
        if (code == 102) {
            string script = llList2String(split, 0);
            configured = 1;
            if (!RLVstarted) initializeRLV(0);
        }
        else if (code == 104) {
            string script = llList2String(split, 0);
            if (script != "Start") return;
            if (initState == 104) lmInitState(initState++);
        }
        else if (code == 105) {
            string script = llList2String(split, 0);
            if (script != "Start") return;
            if (!startup) checkRLV();
            if (initState == 105) lmInitState(initState++);
        }
        else if (code == 106) {
            if (id == NULL_KEY && !detachable && !locked) {
                // Undetachable key with controller is detached while RLV lock
                // is not available inform any key controllers.
                // We send no message if the key is RLV locked as RLV will reattach
                // automatically this prevents neusance messages when defaultwear is
                // permitted.
                // Q: Should that be changed? Not sure the message serves much purpose with *verified* RLV and known lock.
                llMessageLinked(LINK_THIS, 15, dollName + " has detached " + llToLower(pronounHerDoll) + " key while undetachable.", scriptkey);
            }
            else if (id != NULL_KEY && badAttach) llResetOtherScript("Start");
        }
        else if (code == 110) {
            initState = 105;
        }
        else if (code == 135) {
            float delay = llList2Float(split, 1);
            memReport(delay);
        }
        else if (code == 300) { // RLV Config
            string script = llList2String(split, 0);
            string name = llList2String(split, 1);
            split = llList2List(split, 2, -1);
            string value = llList2String(split, 0);
            
            if (llListFindList([ "afk", "autoTP", "canFly", "canSit", "canStand", "canWear", "collapsed", "helpless" ], [ name ]) != -1) {
                     if (name == "autoTP")                       autoTP = (integer)value;
                else if (name == "afk")                             afk = (integer)value;
                else if (name == "collapsed")                 collapsed = (integer)value;
                else if (name == "canFly")                       canFly = (integer)value;
                else if (name == "canSit")                       canSit = (integer)value;
                else if (name == "canStand")                   canStand = (integer)value;
                else if (name == "canWear")                     canWear = (integer)value;
                else if (name == "helpless")                   helpless = (integer)value;
                
                if (RLVstarted) initializeRLV(1);
            } else {            
                     if (name == "detachable")               detachable = (integer)value;
                else if (name == "barefeet")                   barefeet = value;
                else if (name == "dollType")                   dollType = value;
                else if (name == "lowScriptMode")         lowScriptMode = (integer)value;
                else if (name == "MistressList")           MistressList = split;
                else if (name == "pronounHerDoll")       pronounHerDoll = value;
                else if (name == "pronounSheDoll")       pronounSheDoll = value;
                else if (name == "poserID")                     poserID = (key)value;
                else if (name == "poseExpire")               poseExpire = (float)value;
                else if (name == "quiet")                         quiet = (integer)value;
                else if (name == "timeLeftOnKey")         timeLeftOnKey = (float)value;
                else if (name == "userBaseRLVcmd") {
                    if (userBaseRLVcmd == "") userBaseRLVcmd = value;
                    else userBaseRLVcmd += "," +value;
                }
                else if (name == "userCollapseRLVcmd") {
                    if (userCollapseRLVcmd == "") userCollapseRLVcmd = value;
                    else userCollapseRLVcmd += "," +value;
                }
            }
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
                
                // Run ifPermissions to set collapsed anim
                ifPermissions();
            }
            else if (cmd == "doUnpose") {
                if (keyAnimation != ANIMATION_COLLAPSED) {
                    lmSendConfig("lockPos", (string)(lockPos = ZERO_VECTOR));
                    lmSendConfig("keyAnimation", (keyAnimation = ""));
                    lmSendConfig("poserID", (string)(poserID = NULL_KEY));
                }
            }
            if (cmd == "setAFK") {
                afk = llList2Integer(split, 0);
                integer auto = llList2Integer(split, 1);
                string rate = llList2String(split, 2);
                string mins = llList2String(split, 3);
                
                if (afk) {
                    if (auto)
                        llOwnerSay("Automatically entering AFK mode. Wind down rate has slowed to " + rate + "x however and movements and abilities are restricted.");
                    else
                        llOwnerSay("You are now away from keyboard (AFK). Wind down rate has slowed to " + rate + "x however and movements and abilities are restricted.");
                } else {
                    llOwnerSay("You are now no longer away from keyboard (AFK). Movements are unrestricted and winding down proceeds at normal rate.");
                }
                llOwnerSay("You have " + mins + " minutes of life remaning.");
            }
            else if (cmd == "setPose" && !collapsed) { 
                string pose = llList2String(split, 0);
                          
                // Force unsit before posing
                doRLV("Pose", "unsit=force");
                
                // If not a display doll set an expire time
                if (dollType != "Display") lmSendConfig("poseExpire", (string)(poseExpire = POSE_LIMIT));
                // Also include region name with location so we know to reset if changed.
                lmSendConfig("lockPos", llGetRegionName() + "|" + (string)(lockPos = llGetPos()));
                lmSendConfig("keyAnimation", (keyAnimation = pose));
                lmSendConfig("poserID", (string)poserID);
                
                // Run ifPermissions to pose the doll
                // This will also prevent movement while posed
                ifPermissions();
            }
            #ifdef ADULT_MODE
            else if (llGetSubString(cmd, 0, 4) == "strip") {
                string stripped;
                if (cmd == "stripTop") {
                    stripped = "top";
                    doRLV("Dress", "detach:stomach=force,detach:left shoulder=force,detach:right shoulder=force,detach:left hand=force,detach:right hand=force,detach:r upper arm=force,detach:r forearm=force,detach:l upper arm=force,detach:l forearm=force,detach:chest=force,detach:left pec=force,detach:right pec=force,remoutfit:gloves=force,remoutfit:jacket=force,remoutfit:shirt=force");
                }
                else if (cmd == "stripBra") {
                    stripped = "bra";
                    doRLV("Dress", "remoutfit=y,remattach=y,remoutfit:undershirt=force");
                }
                else if (cmd == "stripBottom") {
                    stripped = "bottoms";
                    doRLV("Dress", "detach:chin=force,detach:r upper leg=force,detach:r lower leg=force,detach:l upper leg=force,detach:l lower leg=force,detach:pelvis=force,detach:right hip=force,detach:left hip=force,remoutfit:pants=force,remoutfit:skirt=force");
                }
                else if (cmd == "stripPanties") {
                    stripped = "panties";
                    doRLV("Dress", "remoutfit:underpants=force");
                }
                else if (cmd == "stripShoes") {
                    stripped = "shoes";
                    string attachFeet;
                    if (barefeet != "") attachFeet = "attachallover:" + barefeet + "=force,";
                    doRLV("Dress", "detach:l lower leg=force,detach:r lower leg=force,detach:right foot=force,detach:left foot=force,remoutfit:shoes=force,remoutfit:socks=force," + attachFeet);
                }
                lmInternalCommand("wearLock", (string)(wearLock = 1), NULL_KEY);
                initializeRLV(1);
                if (!quiet) llSay(0, "The dolly " + dollName + " has " + llToLower(pronounHerDoll) + " " + stripped + " stripped off " + llToLower(pronounHerDoll) + " and may not redress for " + (string)llRound(WEAR_LOCK_TIME / 60.0) + " minutes.  (Timer will start over for dolly if " + llToLower(pronounSheDoll) + " is stripped again)");
                else llOwnerSay("You have had your " + stripped + " stripped off you and may not redress for " + (string)llRound(WEAR_LOCK_TIME / 60.0) + " minutes, your time will restart if you are stripped again.");
            }
            #endif
            else if (cmd == "uncarry") {
                carrierID = NULL_KEY;
                carrierName = "";
                
                if (keyAnimation == "") {
                    llTargetRemove(targetHandle);
                    llStopMoveToTarget();
                }
                
                // Clear carry restrictions
                doRLV("Carry", "clear");
                
                string mid = " being carried by " + llList2String(split, 0) + " and ";
                string end = " been set down";
                if (!quiet) llSay(0, dollName + " was" + mid + "has" + end);
                else llOwnerSay("You were" + mid + "have" + end);
            }
            else if (cmd == "uncollapse") {
                debugSay(5, "Restoring from collapse");
                clearAnim = 1;
                lmSendConfig("collapsed", (string)(collapsed = 0));
                lmSendConfig("keyAnimation", (keyAnimation = ""));
                lmSendConfig("timeLeftOnKey", (string)timeLeftOnKey);
                
                ifPermissions();
            }
            else if (cmd == "TP") {
                string lm = llList2String(split, 0);
                llRegionSayTo(id, 0, "Teleporting dolly " + dollName + " to  landmark " + lm + ".");
                rlvTPrequest = llRequestInventoryData(lm);
            }
            else if (cmd == "detach") {
                if (RLVok) llOwnerSay("@clear,detachme=force");
                else llDetachFromAvatar();
            }
            else if (cmd == "wearLock") {
                wearLock = llList2Integer(split, 0);
                lmSendConfig("wearLock", (string)wearLock);
            }
            
            initializeRLV(1);
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
        if (initComplete) {
            float timerInterval = llGetAndResetTime();
            
            // Check if doll is posed and time is up
            if ((keyAnimation != "" && keyAnimation != ANIMATION_COLLAPSED)) { // Doll posed
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
            
            if (ticks++ % 10 == 0) {
                if (poseExpire != 0.0) lmSendConfig("poseExpire", (string)poseExpire);
                if (timeToJamRepair != 0.0) lmSendConfig("timeToJamRepair", (string)timeToJamRepair);
            }
            
            if (lowScriptMode) llSetTimerEvent(5.0);
            else llSetTimerEvent(1.0);
        }
        else {
            if (RLVck != 0 && RLVck <= 6) {
                if (isAttached && !RLVok && RLVck != 6) llOwnerSay("@clear,versionnew=" + (string)channel);
                else if (isAttached && RLVck != 6) llOwnerSay("@getpathnew=" + (string)channel);
                llSetTimerEvent(5.0 * RLVck++);
            } else if (RLVck != 0) {
                processRLVResult();
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
                carryExpire = CARRY_TIMEOUT;
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
