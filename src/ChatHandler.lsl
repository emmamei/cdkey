//========================================
// ChatHandler.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 7 March 2014

#include "include/GlobalDefines.lsl"
#define cdGetFirstChar(a) llGetSubString(a,0,0)
#define NOT_FOUND -1
#define STRING_END -1
#define cdMenuInject(a,b,c) lmMenuReply(a,b,c)

#define TESTING
// FIXME: Depends on a variable s
#define cdCapability(c,p,u) { s += p; if (!(c)) { s += " not"; }; s += " " + u + ".\n"; }

key keyHandler              = NULL_KEY;
key listID                  = NULL_KEY;

list windTimes              = [30];

float collapseTime          = 0.0;
float currentLimit          = 10800.0;
float wearLockExpire        = 0.0;

string dollGender           = "Female";
string chatPrefix           = "";
string RLVver               = "";
string pronounHerDoll       = "Her";
string dollName             = "";
string blockedControlName   = "";
string blockedControlUUID   = "";

integer autoAFK             = 1;
integer broadcastOn         = -1873418555;
integer broadcastHandle     = 0;
integer busyIsAway          = 0;
integer chatChannel         = 75;
integer chatHandle          = 0;
#ifdef DEVELOPER_MODE
integer timeReporting       = 0;
integer debugLevel          = DEBUG_LEVEL;
#endif
integer RLVok               = -1;
integer blockedControlTime  = 0;
integer blacklistMode       = 0;

default
{
    //----------------------------------------
    // STATE ENTRY
    //----------------------------------------
    state_entry() {
        dollID = llGetOwner();
        dollName = llGetDisplayName(dollID);
        
        // Beware listener is now available to users other than the doll
        // make sure to take this into account within all handlers.
        chatHandle = llListen(chatChannel, "", "", "");
        broadcastHandle = llListen(broadcastOn, "", "", "");
        
        cdInitializeSeq();
    }
    
    //----------------------------------------
    // LINK MESSAGE
    //----------------------------------------
    link_message(integer source, integer i, string data, key id) {
        
        // Parse link message header information
        list split        =     cdSplitArgs(data);
        string script     =     cdListElement(split, 0);
        integer remoteSeq =     (i & 0xFFFF0000) >> 16;
        integer optHeader =     (i & 0x00000C00) >> 10;
        integer code      =      i & 0x000003FF;
        split             =     llDeleteSubList(split, 0, 0 + optHeader);

        if (code == 110) {
            if (chatPrefix == "") {
                // If chat prefix is not configured by DB or prefs we initialize the default prefix
                // using the initials of the dolly's name in legacy name format.
                string key2Name = llKey2Name(dollID);
                integer i = llSubStringIndex(key2Name, " ") + 1;
                chatPrefix = llToLower(llGetSubString(key2Name,0,0) + llGetSubString(key2Name,i,i));
                lmSendConfig("chatPrefix", chatPrefix);
            }
            
            llOwnerSay("Setting up chat listener on channel " + (string)chatChannel + " with prefix " + llToUpper(chatPrefix));
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
            
            if (value == RECORD_DELETE) {
                value = "";
                split = [];
            }

                 if (name == "afk")                               afk = (integer)value;
            else if (name == "listID")                         listID = (key)value;
            else if (name == "blacklistMode")           blacklistMode = (integer)value;
            else if (name == "autoAFK")                       autoAFK = (integer)value;
            else if (name == "autoTP")                         autoTP = (integer)value;
            else if (name == "canAFK")                         canAFK = (integer)value;
            else if (name == "canCarry")                     canCarry = (integer)value;
            else if (name == "canDress")                     canDress = (integer)value;
            else if (name == "canPose")                       canPose = (integer)value;
            else if (name == "canDressSelf")             canDressSelf = (integer)value;
            else if (name == "poseSilence")               poseSilence = (integer)value;
            else if (name == "canFly")                         canFly = (integer)value;
            else if (name == "canSit")                         canSit = (integer)value;
            else if (name == "canStand")                     canStand = (integer)value;
            else if (name == "canRepeat")                   canRepeat = (integer)value;
            else if (name == "configured")                 configured = (integer)value;
            else if (name == "detachable")                 detachable = (integer)value;
            else if (name == "tpLureOnly")                 tpLureOnly = (integer)value;
            else if (name == "pleasureDoll")             pleasureDoll = (integer)value;
            else if (name == "isVisible")                     visible = (integer)value;
            else if (name == "busyIsAway")                 busyIsAway = (integer)value;
            else if (name == "quiet")                           quiet = (integer)value;
            else if (name == "offlineMode")               offlineMode = (integer)value;
            else if (name == "wearLockExpire")         wearLockExpire = (float)value;
            else if (name == "windRate")                     windRate = (float)value;
            else if (name == "displayWindRate")       displayWindRate = (float)value;
            else if (name == "keyLimit")                     keyLimit = (float)value;
            else if (name == "collapsed")                   collapsed = (integer)value;
            else if (name == "collapseTime")             collapseTime = (float)value;
            else if (name == "pronounHerDoll")         pronounHerDoll = value;
            else if (name == "keyAnimation")             keyAnimation = value;
            else if (name == "dollType")                     dollType = value;
            else if (name == "dollGender")                 dollGender = value;
            else if (name == "poserID")                       poserID = (key)value;
            else if (name == "poserName")                   poserName = value;
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")                 debugLevel = (integer)value;
            else if (name == "timeReporting")           timeReporting = (integer)value;
#endif
            else if (name == "blacklist")                   blacklist = llListSort(split, 2, 1);
            else if (name == "controllers")             controllers = llListSort(split, 2, 1);
            else if (name == "windTimes")                   windTimes = llJson2List(value);
            else if (name == "chatChannel") {
                chatChannel = (integer)value;
                dollID = llGetOwner();
                llListenRemove(chatHandle);
                chatHandle = llListen(chatChannel, "", dollID, "");
            }
            else if ((name == "timeLeftOnKey") || (name == "collapsed")) {
                if (name == "timeLeftOnKey")            timeLeftOnKey = (float)value;
                if (name == "collapsed")                    collapsed = (integer)value;
            }
            else if (name == "keyHandler") {
                keyHandler = (key)value;
            }
            else if (name == "keyLimit") {
                keyLimit = (float)value;
                if (!demoMode) currentLimit = keyLimit;
            }
            else if (name == "demoMode") {
                demoMode = (integer)value;
                if (!demoMode) currentLimit = keyLimit;
                else currentLimit = DEMO_LIMIT;
            }
        }
        
        else if (code == 305) {
            string cmd = llList2String(split, 0);

            split = llDeleteSubList(split, 0, 0);
            
            integer i;

            if ((cmd == "addMistress") || (cmd == "addRemBlacklist") || (cmd == "remMistress")) {
                string uuid = llList2String(split, 0);
                string name = llList2String(split, 1);
                integer type; string typeString; string barString; integer mode;
                list tmpList; list barList; // Barlist represents the oppositite (blacklist or controller list) which bars adding.
                if ((id != DATABASE_ID) && (script != "MenuHandler")) id = listID;
                
                // These lists become mangled sometimes for reasons unclear creating a new handler for both here
                // with a more thorough validation process which should also be somewhat more fault tollerant in
                // the event that a list does become corrupted also.
                
                if (llGetSubString(cmd, -8, -1) == "Mistress") {
                    type = 1; typeString = "controller";
                    tmpList = controllers; barList = blacklist;
                    if (llGetSubString(cmd, 0, 2) == "add") mode = 1;
                    else mode = -1;
                }
                else {
                    type = 2; typeString = "blacklist";
                    tmpList = blacklist; barList = controllers;
                    mode = blacklistMode;
                    blacklistMode = 0;
                }

                // First check, test suitability of name for adding send message if not acceptable
                if (llListFindList(barList, [ uuid ]) != -1) {
                    string msg = name + " is listed on your ";
                    if (type == 1) msg += "blacklist you must first remove them before adding as a ";
                    else msg += "controller list they must first remove themselves before you can add them to the ";
                    msg += typeString + ".";
                    
                    if (type == 1) {
                        msg += "\nTo do so type /" + (string)chatChannel + "unblacklist " + name;
                        blockedControlName = name;
                        blockedControlUUID = uuid;
                        blockedControlTime = llGetUnixTime();
                    }
                    
                    lmSendToAgentPlusDoll(msg, id);
                    return;
                }
                
                // First validation: Check for empty values there should be none so delete any that are found
                while ( ( i = llListFindList(tmpList, [""]) ) != -1) tmpList = llDeleteSubList(tmpList,i,i);
                
                // Second validation: Test for the presence of the uuid in the existing list
                i = llListFindList(tmpList, [ uuid ]);
                integer j = llListFindList(tmpList, [ name ]);

                if (mode == 1) {
                    integer load;
                    if (id == DATABASE_ID) load = TRUE;
                    if (load) llOwnerSay("Restoring " + name + " as " + typeString + " from database settings.");
                    if (i == -1) {
                        // Handle adding
                        if (!load) lmSendToAgentPlusDoll("Adding " + name + " as " + typeString, id);
                        tmpList += [ uuid, name ];
                        // Verify that the list doesn't have an uneven count before trying to presort it
                        if ((llGetListLength(tmpList) % 2) == 0) tmpList = llListSort(tmpList, 2, 1);
                    }
                    // Report already found
                    else if (!load) lmSendToAgentPlusDoll(name + " is already found listed as " + typeString, id);
                }
                else {
                    if ((i != -1) || (j != -1)) {
                        // This should be a simple uuid, name strided list but having seend SL corrupt others
                        // in various ways check uuid & name independently and make certain that neither part 
                        // of an entry for this user can remain after being ordered removed!
                        lmSendToAgentPlusDoll("Removing " + name + " from list as " + typeString + ".", id);
                        if (i != -1) {
                            tmpList = llDeleteSubList(tmpList, i, i);
                            if ((j != -1) && (j > i)) j--; // The previous operation may shift one position update if applicable
                        }
                        if (j != -1) llDeleteSubList(tmpList, j, j);
                    }
                    else {
                        lmSendToAgentPlusDoll(name + " is not listed as " + typeString, id);
                    }
                }
                
                if (type == 1) {
                    if (controllers != tmpList) {
                        controllers = tmpList;
                        lmSendConfig("controllers", llDumpList2String(controllers, "|") );
                    }
                }
                else {
                    if (blacklist != tmpList) {
                        blacklist = tmpList;
                        lmSendConfig("blacklist", llDumpList2String(blacklist, "|") );
                    }
                }
                
                if ((type == 2) && (mode == -1) && (name == blockedControlName)) {
                    lmInternalCommand("addMistress", uuid + "|" + name, dollID);
                }
            }
        }
        else if (code == 350) {
            RLVok = llList2Integer(split, 0);
            RLVver = llList2String(split, 1);
        }
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string msg) {
        // channel = chat channel to listen on
        //    name = filter by prim name
        //     key = filter by avatar key
        //  choice = filter by specific message
        
        // This makes chat commands work correctly and be properly identified and tracked
        // back to an actual agent even if an intermediary is used. this prevents such as
        // blacklist circumvention and saves a more complex ifAvatar test being needed.
        //
        // Accepting commands in this way also offers several potential advantages:
        // - Works in the presense of renamers or other scripted chat redirection.
        // - Keeps open the potential ability to extend functionality with other objects
        //   a basic HUD for doll showing basic status info and with quick access menu buttons
        //   for example (Makes a note to github that thought).
        id = llGetOwnerKey(id);
        name = llGetDisplayName(id);
        
        // Deny access to the menus when the command was recieved from blacklisted avatar
        if (!cdIsDoll(id) && (llListFindList(blacklist, [ (string)id ]) != NOT_FOUND)) {
            lmSendToAgent("You are not permitted to access this key.", id);
            return;
        }

        // Text commands
        if (channel == chatChannel) {
            string prefix;
            
            // Before we proceed first verfify the command is for us.
            if (llGetSubString(msg,0,0) == "*") {
                // *prefix is global, strip from choice and continue
                prefix = llGetSubString(msg,0,0);
                msg = llDeleteSubString(msg,0,0);
            }
            else if ((llGetSubString(msg,0,0) == "#") && !cdIsDoll(id)) {
                // #prefix is an all others prefix like with OC etc
                prefix = llGetSubString(msg,0,0);
                msg = llDeleteSubString(msg,0,0);
            }
            else if (llToLower(llGetSubString(msg,0,1)) == chatPrefix) {
                prefix = llGetSubString(msg,0,1);
                msg = llDeleteSubString(msg,0,1);
            }
            else if (cdIsDoll(id)) {
                llOwnerSay("Use of chat commands without a prefix is depreciated and will be removed in a future release.");
            } 
            else return; // For some other doll? noise? matters not it's someone elses problem.
            
            debugSay(2, "CHAT-DEBUG", "On #" + (string)channel + " secondlife:///app/agent/" + (string)id + "/about: pre:" + prefix + "(ok) cmd:" + msg + " id:" + (string)id);
            
            // This is a simpler proceedure with less tests and fiddling with the string
            // Simply this method works favouring the match that requires the most restrictive accesss permission the requesting user possesses when one is not set explitly.
            // When one is specified explicitly including it's prefix then only the animation with the matching prefix is accepted assuming it exists and the user has permissions.
            string poseChoice = msg; integer poseSet = 1;
            string firstChar = cdGetFirstChar(poseChoice);
            if ((firstChar != "!") && (firstChar != ".")) firstChar == "";
            else                                          poseChoice = llDeleteSubString(poseChoice,0,0);
            
                 if (cdIsDoll(id) && (firstChar != ".") && (llGetInventoryType("!"+poseChoice) == 20))                                      cdMenuInject("!"+poseChoice, name, id);
            else if ((cdIsDoll(id) || cdIsController(id)) && (firstChar != "!") && (llGetInventoryType("."+firstChar+poseChoice) == 20))    cdMenuInject("."+poseChoice, name, id);
            else if (llGetInventoryType(poseChoice) == 20)                                                                                  cdMenuInject(poseChoice, name, id);
            else if (firstChar == "") poseSet = 0;          // In the event that firstChar was one of the prefixes and we didn't match we still know it is not a command
            
            // If we found a pose then the rest of the command handlers are a waste of processing
            if (poseSet) return;    // Return we are finished here

// The naming of this define in its current form is confusing parameters exists
// when there is a space not when there is no space, inverting the sense of this
// to match with the wording.
#define PARAMETERS_EXIST (space != NOT_FOUND)

            // Choice is a command, not a pose
            integer space = llSubStringIndex(msg, " ");
            string choice = msg;
            if (!PARAMETERS_EXIST) { // Commands without parameters handled first
                string choice = llToLower(choice);
                if (cdIsDoll(id) || cdIsController(id)) {
                    // Normal user commands
                    if (choice == "detach") {
                        if (detachable || cdIsController(id)) {
                            lmInternalCommand("detach", "", NULL_KEY);
                        }
                        else {
                            lmSendToAgent("Key can't be detached...", id);
                        }
                    }
                    else if (choice == "help") {
                    string help = "Commands:
    Replace the first . with the chat prefix, your personal prefix is
    currently set to " + llToUpper(chatPrefix) + "\n
    .detach ......... detach key if possible
    .stat ........... concise current status
    .stats .......... selected statistics and settings
    .xstats ......... extended statistics and settings
    .poses .......... list all poses
    .wind ........... trigger emergency autowind
    .demo ........... toggle demo mode
    .[posename] ..... activate the named pose if possible
    .release ........ stop the current pose if possible
    .channel ## ..... change channel
    .prefix XX ...... change chat command prefix
    .help ........... this list of commands
    .dumpstate ...... dump all key state to chat history
    .build .......... list build configurations
    .listhelp ....... list controller/blacklist commands
    .recoveryhelp ... some commands that may rescue a key having issues";
                    lmSendToAgent(help, id);

#ifdef DEVELOPER_MODE
                    lmSendToAgent("    devhelp ........ list of developer commands", id);
                    }
                    else if (choice == "devhelp") {
                    string help = "Developer Commands:
    .timereporting .. periodic reporting of script time usage
    .debug # ........ set the debugging message verbosity 0-9
    .inject ......... inject an aribtary link message the format is
                     inte#str#key with all but the first optional.";
                     lmSendToAgent(help, id);
#endif
                    }

                    else if (choice == "listhelp") {
                    string help = "Access Commands:
                     The following commands must be followed by the desired
                     user's username, not display name.
    .controller ..... add the username to the controller list
    .blacklist ...... blacklist the username if not blacklisted
    .unblacklist .... unblacklist the username if they are blacklisted";
                    lmSendToAgent(help, id);
                    }
                    else if (choice == "recoveryhelp") {
                    string help = "Recovery Commandss:
                     These commnds may help to recover a key without a script
                     reset in some cases.
    .wakescript ..... followed by the name of a key script if the named script
                     is not running this will attempt to restart it.
    .refreshvars .... try to refresh all variables from the internal db
    .httpreload ..... reinitialize the services scripts and fully reload all 
                     data from the off world backup storage (OnlineMode only)
    .rlvinit ........ try RLV initialization again";
                    lmSendToAgent(help, id);
                    }
                }
                if (cdIsDoll(id) || cdIsBuiltinController(id)) {
                    // Do an internal resresh of all local variables from local db
                    if (choice == "refreshvars") {
                        cdLinkMessage(LINK_THIS, 0, 301, "", NULL_KEY);
                    }
                    // Request verbose full key state dump to chat
                    else if (choice == "dumpstate") {
                        cdLinkMessage(LINK_THIS, 0, 302, "", NULL_KEY);
                    }
                    // Service reinitialization and remote restore
                    else if (choice == "httpreload") {
                        if (!offlineMode) {
                            llResetOtherScript("ServiceReceiver");
                            llSleep(1.0);
                            llResetOtherScript("ServiceRequester");
                            llSleep(2.0);
                        }
                    }
                    // Try a hard RLV reinitialzation
                    else if (choice == "rlvinit") {
                        llSetScriptState("StatusRLV", 1);
                        llResetOtherScript("StatusRLV");
                        llResetOtherScript("Avatar");
                        llSleep(1.0);
                        cdLinkMessage(LINK_THIS, 0, 301, "", NULL_KEY);
                        llSleep(5.0);
                        // Inject menu click
                        cdMenuInject("*RLV On*",llGetDisplayName(dollID), id);
                    }
                }
                if (cdIsDoll(id) || cdIsController(id)) {
                    // Demo: short time span
                    if (choice == "demo") {
                        // toggles demo mode
                        lmSendConfig("demoMode", (string)(demoMode = !demoMode));
    
                        string s = "Key now ";
                        if (demoMode) {
                            if (timeLeftOnKey > DEMO_LIMIT) {
                                lmSendConfig("timeLeftOnKey", (string)(timeLeftOnKey = DEMO_LIMIT));
                            }
                            s += "in demo mode: " + (string)llRound(timeLeftOnKey / SEC_TO_MIN) + " of " + (string)llRound(DEMO_LIMIT / SEC_TO_MIN) + " minutes remaining.";
                        }
                        else {
                            // FIXME: currentlimit not set until later; how do we tell user what it is?
                            // They are not in demoMode after this so the limit is going to be restored to keyLimit
                            // only execption would be if keyLimit was invalid however there will be a follow up message
                            // from Main stating this and giving the new value so not something we need to do here.
                            
                            s += "running normally: " + (string)(timeLeftOnKey / SEC_TO_MIN) + " of " + (string)llFloor(keyLimit / SEC_TO_MIN) + " minutes remaining.";
                        }
                    }
                    else if (choice == "listposes") {
                        integer n = llGetInventoryNumber(INVENTORY_ANIMATION);
                        integer isDoll = cdIsDoll(id); integer isController = cdIsController(id);
    
                        string thisPose; string thisPrefix;
                        while(n) {
                            thisPose = llGetInventoryName(INVENTORY_ANIMATION, --n);
                            thisPrefix = cdGetFirstChar(thisPose);
                            if ((thisPrefix != "!") && (thisPrefix != "."))     thisPrefix = "";
    
                            if (thisPose != ANIMATION_COLLAPSED) {
                                if (isDoll ||
                                    (isController && (thisPrefix == "!")) ||
                                    (thisPrefix == "")) {
                                        if (keyAnimation == thisPose) {
                                            lmSendToAgent("\t*\t" + thisPose, id);
                                        }
                                        else {
                                            lmSendToAgent("\t\t" + thisPose, id);
                                        }
                                }
                                else if (keyAnimation == thisPose) {
                                    lmSendToAgent("\t*\t{private}", id);
                                }
                            }
                        }
                    }
                }
                if (choice == "wind") {
                    // inject a fake Menu click appropriate to the users access
#ifndef TESTER_MODE
                    if (cdIsDoll(id)) cdMenuInject("Wind Emg", dollName, dollID);
                    else {
#endif
                        cdMenuInject("Wind", name, id);
#ifndef TESTER_MODE
                    }
#endif
                }
                else if (choice == "menu") cdMenuInject(MAIN, name, id);
                else if (choice == "outfits") cdMenuInject("Outfits...", name, id);
                else if (choice == "types") cdMenuInject("Types...", name, id);
                else if (choice == "poses") cdMenuInject("Poses...", name, id);
                else if (choice == "carry") cdMenuInject("Carry", name, id);
                else if (choice == "uncarry") cdMenuInject("Uncarry", name, id);
                if (cdIsDoll(id) || cdIsController(id)) {
                    if (choice == "xstats") {
                        string s = "Extended stats:\n";
    
                        s += "AFK time factor: " + formatFloat(RATE_AFK, 1) + "x\n";
                        s += "Configured wind times: " + llList2CSV(windTimes) + " mins\n";
    
                        if (demoMode) {
                            s += "Demo mode is enabled; times are: 1";
                            if (llGetListLength(windTimes) > 1) s += ", 2";
                            s += " mins.\n";
                        }
                        
                        // Which is the upper bound on the wind times currently? Depeding on the values this could be keyLimit/2 or windLimit
                        s += "Current wind menu: ";
    
                        integer timeLeft = llFloor(timeLeftOnKey / 60.0);
                        float windLimit = currentLimit - timeLeftOnKey;
                        integer timesLimit = llFloor(windLimit / SEC_TO_MIN);
                        integer time; list avail; integer i; integer n = llGetListLength(windTimes);
                        integer maxTime = llRound(currentLimit / 60.0 / 2);
    
                        while ((i <= n) && ( ( time = llList2Integer(windTimes, i++) ) < timesLimit) && (time <= maxTime)) {
                            avail += ["Wind " + (string)time];
                        } 
                        if ((i <= n) && (timesLimit <= maxTime)) {
                            avail += ["Wind Full"];
                            s += " (" + (string)timeLeft  + " of " + (string)maxTime + " minutes left " + (string)timesLimit + " from max)";
                        }
    
                        s += llList2CSV(avail);
                        if (windLimit < (keyLimit / 2)) s += " (Times limited to half max time)";
                        s += "\n";
    
                        string p = llToLower(pronounHerDoll);
#ifdef TESTING
                        cdCapability(autoTP,      "Doll can", "be force teleported");
                        cdCapability(detachable,  "Doll can", "detach " + p + " key");
                        cdCapability(canDress,    "Doll can", "be dressed by the public");
                        cdCapability(canCarry,    "Doll can", "be carried by the public");
                        cdCapability(canAFK,      "Doll can", "go AFK");
                        cdCapability(canFly,      "Doll can", "fly");
                        cdCapability(canPose,     "Doll can", "be posed by the public");
                        cdCapability(canSit,      "Doll can", "sit");
                        cdCapability(canStand,    "Doll can", "stand");
                        cdCapability(canRepeat,   "Doll can", "multiply wound");
                        cdCapability(canDressSelf,     "Doll can", "dress by " + p + "self");
                        cdCapability(poseSilence, "Doll is",  "silenced while posing");
#else
                        list items = [
                            autoTP,             "Doll can? be force teleported",
                            detachable,         "Doll can? detach " + p + " key",
                            canDress,           "Doll can? be dressed by others",
                            canFly,             "Doll can? fly",
                            canPose,            "Doll can? be posed by others",
                            canSit,             "Doll can? sit",
                            canStand,           "Doll can? stand",
                            canDressSelf,            "Doll can? dress by " + p + "self",
                            poseSilence,        "Doll is? silenced while posing"
                        ];
    
                        i=0; n = llGetListLength(items);
    
                        while (i++ < n) {
                            string in = llList2String(items, i--);
                            integer index = llSubStringIndex(in, "?");
    
                            in = llDeleteSubString(in, index, index);
                            if (!llList2Integer(items, i+=2)) in = llInsertString(in, index, " not");
                            s += in + "\n";
                        }

#endif
                        if (windRate == 0.0) { s += "Key is not winding down.\n"; }
                        else { s += "Current wind rate is " + formatFloat(windRate,2) + ".\n"; }
    
                        if (RLVok == -1) { s += "RLV status is unknown.\n"; }
                        else if (RLVok == 1) { s += "RLV is active.\nRLV version: " + RLVver; } 
                        else s += "RLV is not active.\n";
    
                        lmSendToAgent(s, id);
                    }
                    else if (choice == "stat") {
                        debugSay(6, "DEBUG", "timeLeftOnKey = " + (string)timeLeftOnKey);
                        debugSay(6, "DEBUG", "currentLimit = " + (string)currentLimit);
                        debugSay(6, "DEBUG", "displayWindRate = " + (string)displayWindRate);
    
                        float t1 = timeLeftOnKey / (SEC_TO_MIN * displayWindRate);
                        float t2 = currentLimit / (SEC_TO_MIN * displayWindRate);
                        float p = t1 * 100.0 / t2;
    
                        string s = "Time: " + (string)llRound(t1) + "/" +
                                    (string)llRound(t2) + " min (" + formatFloat(p, 2) + "% capacity)";
                        if (afk) {
                            s += " (current wind rate " + formatFloat(displayWindRate, 1) + "x)";
                        }
                        lmSendToAgent(s, id);
                    }
                    else if (choice == "stats") {
                        debugSay(6, "DEBUG", "timeLeftOnKey = " + (string)timeLeftOnKey);
                        debugSay(6, "DEBUG", "currentLimit = " + (string)currentLimit);
                        debugSay(6, "DEBUG", "displayWindRate = " + (string)displayWindRate);
    
                        //displayWindRate;
    
                        lmSendToAgent("Time remaining: " + (string)llRound(timeLeftOnKey / (SEC_TO_MIN * displayWindRate)) + " minutes of " +
                                    (string)llRound(currentLimit / (SEC_TO_MIN * displayWindRate)) + " minutes.", id);
    
                        string msg;
    
                        if (windRate == 0.0) msg = "Key is stopped.";
                        else {
                            msg = "Key is unwinding at a ";
    
                            if (windRate == 1.0) msg += " normal rate.";
                            else {
                                if (windRate < 1.0) msg += " slowed rate of ";
                                else if (windRate > 1.0) msg += " accelerated rate of ";
    
                                msg += " of " + formatFloat(windRate, 1) + "x.";
                            }
    
                        }
    
                        lmSendToAgent(msg, id);
    
                        if (!cdCollapsedAnim() && !cdNoAnim()) {
                        //    llOwnerSay(dollID, "Current pose: " + currentAnimation);
                        //    llOwnerSay(dollID, "Pose time remaining: " + (string)(poseTime / SEC_TO_MIN) + " minutes.");
                            llOwnerSay("Doll is posed.");
                        }
    
                        lmMemReport(1.0, 1);
                    }
                    if (cdIsDoll(id)) {
                        if (choice == "build") {
                            lmConfigReport();
                        }
                    }
                    else if (choice == "release") {
                        if ((poserID != NULL_KEY) && (poserID != dollID)) llOwnerSay("Dolly tries to wrest control of her body from the pose but she is no longer in control of her form.");
                        else lmMenuReply("Unpose", dollName, dollID);
                    }
                }
            }
            else {
                // Command has secondary parameter
                string param =           llStringTrim(llGetSubString(choice, space + 1, STRING_END), STRING_TRIM);
                choice       = llToLower(llStringTrim(llGetSubString(   msg,         0,  space - 1), STRING_TRIM));

                if (cdIsDoll(id) || cdIsBuiltinController(id)) {
                    if (choice == "channel") {
                        string c = param;
    
                        if ((string) ((integer) c) == c) {
                            integer ch = (integer) c;
    
                            if (ch != 0 && ch != DEBUG_CHANNEL) { // FIXME: Sanity checking should be extended
                                chatChannel = ch;
                                llListenRemove(chatHandle);
                                chatHandle = llListen(ch, "", llGetOwner(), "");
                            }
                        }
                    }
                    else if (choice == "controller") {
                        blockedControlName = "";
                        blockedControlUUID = "";
                        blockedControlTime = 0;
                        lmInternalCommand("getMistressKey", param, id);
                    }
                    else if (choice == "blacklist") { 
                        blacklistMode = 1;
                        lmInternalCommand("getBlacklistKey", param, id);
                    }
                    else if (choice == "unblacklist") { 
                        if ((llToLower(blockedControlName) == llToLower(param)) && (llGetUnixTime() < (blockedControlTime + 300))) {
                            llOwnerSay("Adding previously blacklisted user " + blockedControlName + " as controller.");
                            blacklistMode = -1;
                            lmInternalCommand("addRemBlacklist", blockedControlUUID + "|" + blockedControlName, dollID);
                        }
                        blacklistMode = -1;
                        lmInternalCommand("getBlacklistKey", param, id);
                    }
                    else if (choice == "prefix") {
                        string newPrefix = param;
                        string c1 = llGetSubString(newPrefix,0,0);
                        string msg = "The prefix you entered is not valid, the prefix must ";
                        if (llStringLength(newPrefix) == 2) {
                            // Why? Two character user prefixes are standard and familiar too much false +ve with
                            // just 1 letter (~4%) with letter + letter/digit it's (~0.1%) excessive long prefixes
                            // are bad for useability.
                            lmSendToAgent(msg + "be two characters long.", id);
                        }
                        else if (newPrefix != llEscapeURL(newPrefix)) {
                            // Why? Stick to simple ascii compatible alphanumerics that are compatible with
                            // all keyboards and with mobile devices with limited input capabilities etc.
                            lmSendToAgent(msg + "only contain letters and numbers.", id);
                        }
                        else if (((integer)c1) || (c1 == "0")) {
                            // Why? This one is needed to prevent the first char of prefix being merged into
                            // the channel # when commands are typed without the use of the optional space.
                            lmSendToAgent(msg + "start with a letter.", id);
                        }
                        else {
                            chatPrefix = newPrefix;
                            lmSendToAgentPlusDoll("Chat prefix has been changed to " + llToUpper(chatPrefix) + " the new prefix must now be used for all commands.", id);
                        }
                    }
                    else if (choice == "wakescript") {
                        string script;
    
                        if (llGetInventoryType(param) == INVENTORY_SCRIPT) script = param;
                        else {
                            integer i; for (i = 0; i < llGetInventoryNumber(INVENTORY_SCRIPT); i++) {
                                if (llToLower(llGetInventoryName(INVENTORY_SCRIPT, i)) == llToLower(param)) script = param;
                            }
                        }
                        if (llGetScriptState(script)) llOwnerSay("The '" + script + "' script is already in a running state");
                        else if ((RLVok != 1) && (script == "StatusRLV")) 
                            llOwnerSay("StatusRLV will not run until RLV is enabled, this is by design.  Try the rlvinit command instead.");
                        else {
                            string msg = "Trying to wake '" + script + "'";
    
                            llOwnerSay(msg);
                            llResetOtherScript(script);
                            llSetScriptState(script, 1);
                            llSleep(5.0);
                            cdLinkMessage(LINK_THIS, 0, 301, "", NULL_KEY);
                            llSleep(5.0);
                            msg = "Script '" + script + "'";
                            if (llGetScriptState(script)) msg += " seems to be running now.";
                            else msg += " appears to have stopped running again after being restarted.  If you are not getting script errors this may be intentional.";
                            llOwnerSay(msg);
                        }
                    }
                }
                if (cdIsDoll(id)) {
#ifdef DEVELOPER_MODE
                    if (choice == "debug") {
                        lmSendConfig("debugLevel", (string)(debugLevel = (integer)param));
                        llOwnerSay("DEBUG_LEVEL = " + (string)debugLevel);
                    }
                    else if (choice == "inject") {
                        list params = llParseString2List(param, ["#"], []);
                        llOwnerSay("INJECT LINK:\nLink Code: " + (string)llList2Integer(params, 0) + "\n" +
                                   "Data: " + cdMyScriptName() + "|" + llList2String(params, 1) + "\n" +
                                   "Key: " + (string)llList2Key(params, 2));
                        llMessageLinked(LINK_THIS, llList2Integer(params, 0), cdMyScriptName() + "|" + llList2String(params, 1), llList2Key(params, 2));
                    }
                    else if (choice == "timereporting") {
                        lmSendConfig("timeReporting", (string)(timeReporting = (integer)param));
                    }
#else
#ifdef TESTER_MODE
                    else if (choice == "debug") {
                        lmSendConfig("debugLevel", (string)(debugLevel = (integer)param));
                        llOwnerSay("DEBUG_LEVEL = " + (string)debugLevel);
                    }
#endif
#endif
                }
            }
        }
        else if (channel == broadcastOn) {
            if (llGetSubString(msg, 0, 4) == "keys ") {
                string subcommand = llGetSubString(msg, 5, STRING_END);
                debugSay(9, "BROADCAST-DEBUG", "Broadcast recv: From: " + name + " (" + (string)id + ") Owner: " + llGetDisplayName(llGetOwnerKey(id)) + " (" + (string)llGetOwnerKey(id) +  ") " + msg);
                if (subcommand == "claimed") {
                    if (keyHandler == llGetKey()) {
                        llRegionSay(broadcastOn, "keys released");
                        debugSay(9, "BROADCAST-DEBUG", "Broadcast sent: keys released");
                    }
                    lmSendConfig("keyHandler", (string)(keyHandler = id));
                }
                else if ((subcommand == "released") && (keyHandler == id)) {
                    lmSendConfig("keyHandler", (string)(keyHandler = NULL_KEY));
                }
            }
        }
    }
}
