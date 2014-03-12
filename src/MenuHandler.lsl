//========================================
// MenuHandler.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 28 February 2014

#include "include/GlobalDefines.lsl"

#define LISTENER_ACTIVE 1
#define LISTENER_INACTIVE 0
#define NO_FILTER ""
#define cdListenAll(a)    llListen(a, NO_FILTER, NO_FILTER, NO_FILTER)
#define cdListenUser(a,b) llListen(a, NO_FILTER,         b, NO_FILTER)
#define cdListenMine(a)   llListen(a, NO_FILTER,    dollID, NO_FILTER)
#define cdListenerDeactivate(a) llListenControl(a, 0)
#define cdListenerActivate(a) llListenControl(a, 1)

// Current Controller - or Mistress
//key MistressID = NULL_KEY;
key poserID = NULL_KEY;
key dollID = NULL_KEY;
key menuID = NULL_KEY;
key uniqueID = NULL_KEY;

list windTimes = [ 30 ];

float timeLeftOnKey;
float windDefault = 1800.0;
float collapseTime;

integer afk;
integer autoAFK = 1;
//integer autoTP;
//integer canAFK = 1;
integer canCarry = 1;
integer canDress = 1;
//integer canFly = 1;
//integer canSit = 1;
//integer canStand = 1;
integer canRepeat = 1;
//integer poseSilence;
//integer canWear;
//integer canUnwear;
integer carryMoved;
integer primLight = 1;
integer clearAnim;
integer collapsed;
integer configured;
integer demoMode;
//integer detachable = 1;
//integer doWarnings;
//integer helpless;
//integer pleasureDoll;
integer isTransformingKey;
integer visible = 1;
//integer quiet;
integer RLVok = -1;
//integer signOn;
//integer takeoverAllowed;
//integer warned;
//integer offlineMode;
integer wearLock;
integer dbConfig;
integer textboxType;
//integer debugLevel = DEBUG_LEVEL;
integer startup = 1;

integer blacklistChannel;
integer controlChannel;
integer dialogChannel;
integer blacklistHandle;
integer controlHandle;
integer dialogHandle;
string isDollName;
string dollType = "Regular";
string pronounHerDoll = "Her";
string pronounSheDoll = "She";
string marketplaceURL = "";

vector gemColour;

string carrierName;
string mistressName;
string keyAnimation;
//string dollyName;
string nextMenu;
string menuName;

float winderRechargeTime;

list blacklist;
list dialogKeys;
list dialogNames;
list dialogButtons;

doDialogChannel() {
    // If no uniqueID has been generated for dolly generate a new one now
    if (uniqueID == NULL_KEY) lmSendConfig("uniqueID", (string)(uniqueID = llGenerateKey()));

    integer generateChannel = 0x80000000 | (integer)("0x" + llGetSubString((string)uniqueID, -7, -1));
    if (dialogChannel != generateChannel) lmSendConfig("dialogChannel", (string)(dialogChannel = generateChannel));

    debugSay(2, "DEBUG-MENU", "Your unique key is " + (string)uniqueID + " primary dialogChannel is " + (string)dialogChannel);

    blacklistChannel = dialogChannel - 666;
    controlChannel = dialogChannel - 888;

    llListenRemove(dialogHandle);
    dialogHandle = cdListenAll(dialogChannel);
    cdListenerDeactivate(dialogHandle);
}

default
{
    state_entry() {
        dollID = llGetOwner();
        dollName = llGetDisplayName(dollID);
        
        cdInitializeSeq();
    }
    
    on_rez(integer start) {
        RLVok = -1;
    }

    link_message(integer sender, integer i, string data, key id) {
        
        // Parse link message header information
        list split        =     cdSplitArgs(data);
        string script     =     cdListElement(split, 0);
        integer remoteSeq =     (i & 0xFFFF0000) >> 16;
        integer optHeader =     (i & 0x00000C00) >> 10;
        integer code      =      i & 0x000003FF;
        split             =     llDeleteSubList(split, 0, 0 + optHeader);

        if (code == 102) {
            if (script == "ServiceReceiver") {
                dbConfig = 1;
                doDialogChannel();
            }
            else if (data == "Start") configured = 1;
            scaleMem();
        }
        else if (code == 110) {
            startup = 0;
            lmInternalCommand("setGemColour", (string)gemColour, NULL_KEY);
        }
        else if (code == 135) {
            float delay = llList2Float(split, 0);
            memReport(cdMyScriptName(),delay);
        }
        
        cdConfigReport();
        
        else if (code == 150) {
            simRating = llList2String(split, 0);
        }
        else if (code == 300) {
            string name = llList2String(split, 0);
            string value = llList2String(split, 1);
            split = llDeleteSubList(split, 0, 0);

                 if (name == "baseWindRate")             baseWindRate = (float)value;
            else if (name == "keyAnimation")             keyAnimation = value;
            else if (name == "pronounHerDoll")         pronounHerDoll = value;
            else if (name == "pronounSheDoll")         pronounSheDoll = value;
            else if (name == "marketplaceURL")         marketplaceURL = value;
            //else if (name == "dollyName")                   dollyName = value;
            else if (name == "afk")                               afk = (integer)value;
            //else if (name == "autoTP")                         autoTP = (integer)value;
            else if (name == "canAFK")                         canAFK = (integer)value;
            else if (name == "canCarry")                     canCarry = (integer)value;
            else if (name == "canDress")                     canDress = (integer)value;
            else if (name == "canPose")                       canPose = (integer)value;
            else if (name == "canWear")                       canWear = (integer)value;
            else if (name == "wearLock")                     wearLock = (integer)value;
            else if (name == "collapsed")                   collapsed = (integer)value;
            //else if (name == "canFly")                         canFly = (integer)value;
            //else if (name == "canSit")                         canSit = (integer)value;
            //else if (name == "canStand")                     canStand = (integer)value;
            //else if (name == "canRepeat")                   canRepeat = (integer)value;
            //else if (name == "poseSilence")               poseSilence = (integer)value;
            else if (name == "configured")                 configured = (integer)value;
#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")                 debugLevel = (integer)value;
#endif
            else if (name == "detachable")                 detachable = (integer)value;
            else if (name == "demoMode")                     demoMode = (integer)value;
            //else if (name == "helpless")                     helpless = (integer)value;
            //else if (name == "pleasureDoll")             pleasureDoll = (integer)value;
            else if (name == "isTransformingKey")   isTransformingKey = (integer)value;
            else if (name == "quiet")                           quiet = (integer)value;
            //else if (name == "signOn")                         signOn = (integer)value;
            else if (name == "dialogChannel")           dialogChannel = (integer)value;
            else if (name == "poserID")                       poserID = (key)value;
            else if (name == "collapseTime")             collapseTime = (llGetTime() - (float)value);
            else if (name == "winderRechargeTime") winderRechargeTime = (float)value;
            else if (name == "displayWindRate") {
                if ((float)value != 0) displayWindRate = (float)value;
            }
            else if (name == "primLight") {
                primLight = (integer)value;
                lmInternalCommand("setGemColour", (string)gemColour, NULL_KEY);
            }
            else if (name == "uniqueID") {
                if (script != "ServiceReceiver") return;
                uniqueID = (key)value;
            }
            else if (name == "timeLeftOnKey") {
                timeLeftOnKey = (float)value;
            }
            else if (name == "isVisible") {
                visible = (integer)value;
                llSetLinkAlpha(LINK_SET, (float)visible, ALL_SIDES);
            }
            else if (name == "dollType") {
                dollType = llGetSubString(llToUpper(value), 0, 0) + llGetSubString(llToLower(value), 1, -1);
            }
            else if ((name == "MistressList") || (name == "blacklist")) {
                integer i;
                for (i = 0; i < llGetListLength(split); i++) {
                    if (llList2String(split, i) == "") split = llDeleteSubList(split, i, i--);
                }

                if (name == "MistressList") {
                    MistressList = split;
                    if (!startup) lmInternalCommand("updateExceptions", "", NULL_KEY);
                }
                else blacklist = split;
            }
        }
        else if (code == 305) {
            string cmd = llList2String(split, 0);
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "carry") {
                // Doll has been picked up...
                carrierID = id;
                carrierName = llList2String(split, 0);
            }
            else if (cmd == "uncarry") {
                // Doll has been placed down...
                carrierID = NULL_KEY;
                carrierName = "";
            }
            else if (cmd == "setAFK") afk = llList2Integer(split, 0);
            else if (cmd == "collapse") {
                keyAnimation = ANIMATION_COLLAPSED;
                collapsed = 1;
            }
            else if (cmd == "uncollapse") {
                keyAnimation = "";
                collapsed = 0;
            }
            else if (cmd == "dialogListen") {
                cdListenerActivate(dialogHandle);
                llSetTimerEvent(60.0);
            }

            // Deny access to the menus when the command was recieved from blacklisted avatar
            if (llListFindList(blacklist, [ (string)id ]) != -1) {
                lmSendToAgent("You are not permitted to access this key.", id);
                return;
            }
            else if (cmd == "setGemColour") {
                vector newColour = (vector)llList2String(split, 0);
                integer i; integer j; integer s; list params; list colourParams;

                for (i = 1; i < llGetNumberOfPrims(); i++) {
                    params += [ PRIM_LINK_TARGET, i ];
                    if (llGetSubString(llGetLinkName(i), 0, 4) == "Heart") {
                        if (gemColour != newColour) {
                            if (!s) {
                                for (j = 0; j < llGetLinkNumberOfSides(i); j++) {
                                    vector shade = <llFrand(0.2) - 0.1 + newColour.x, llFrand(0.2) - 0.1 + newColour.y, llFrand(0.2) - 0.1 + newColour.z> * (1.0 + (llFrand(0.2) - 0.1));
                                    
                                    if (shade.x < 0.0) shade.x = 0.0;
                                    if (shade.y < 0.0) shade.y = 0.0;
                                    if (shade.z < 0.0) shade.z = 0.0;
                                    
                                    if (shade.x > 1.0) shade.x = 1.0;
                                    if (shade.y > 1.0) shade.y = 1.0;
                                    if (shade.z > 1.0) shade.z = 1.0;
                
                                    colourParams += [ PRIM_COLOR, j, shade, 1.0 ];
                                }
                                params += colourParams;
                                s = 1;
                            }
                            else params += colourParams;
                        }
                    }
                }
                llSetLinkPrimitiveParamsFast(0, params);
                if (gemColour != newColour) {
                    lmSendConfig("gemColour", (string)(gemColour = newColour));
                }
                params = [];
            }
            else if (cmd == "updateExceptions") {

                // Exempt builtin or user specified controllers from TP restictions
    
                list allow = BUILTIN_CONTROLLERS + cdList2ListStrided(MistressList, 0, -1, 2);
    
                // Also exempt the carrier StatusRLV will ignore the duplicate if carrier is a controller so save work
    
                if cdCarried() allow += carrierID;
    
                // Directly dump the list using the static parts of the RLV command as a seperator no looping
    
                lmRunRLVas("Base", "clear=tplure:,tplure:"          + llDumpList2String(allow, "=add,tplure:")    + "=add");
                lmRunRLVas("Base", "clear=accepttp:,accepttp:"      + llDumpList2String(allow, "=add,accepttp:")  + "=add");
                lmRunRLVas("Base", "clear=sendim:,sendim:"          + llDumpList2String(allow, "=add,sendim:")    + "=add");
                lmRunRLVas("Base", "clear=recvim:,recvim:"          + llDumpList2String(allow, "=add,recvim:")    + "=add");
                lmRunRLVas("Base", "clear=recvchat:,recvchat:"      + llDumpList2String(allow, "=add,recvchat:")  + "=add");
                lmRunRLVas("Base", "clear=recvemote:,recvemote:"    + llDumpList2String(allow, "=add,recvemote:") + "=add");
    
                // Apply exemptions to base RLV
            }
            else if (cmd == "mainMenu") {
                string msg; list menu; string manpage; string windButton = llList2String(split, 0);
                
                if (startup) lmSendToAgent("Dolly's key is still establishing connections with " + llToLower(pronounHerDoll) + " systems please try again in a few minutes.", id);
                
                // Cache access test results
                integer hasCarrier      = cdCarried()  ;
                integer isCarrier       = cdIsCarrier(id)       || cdIsBuiltinController(id);
                integer isController    = cdIsController(id);
                integer isDoll          = cdIsDoll(id);
                integer numControllers  = cdControllerCount();

                // Compute "time remaining" message for mainMenu/windMenu
                string timeleft;

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

                // Handle our "special" states first which significantly alter the menu

                // When the doll is carried they have exclusive control
                if (hasCarrier) {
                    // Doll being carried clicked on key
                    if (isDoll) {
                        msg = "You are being carried by " + carrierName + ".";
                        menu = ["Help/Support"];
                    }

                    else if (isCarrier) {
                        msg = "Place Down frees " + dollName + " when you are done with " + pronounHerDoll;

                        menu += "Uncarry";
                    }

                    // Someone else clicked on key
                    else {
                        msg = dollName + " is currently being carried by " + carrierName + ". They have full control over this doll.\n";
                        menu = ["Help/Support"];
                    }
                    if (!isCarrier) {
                        llDialog(id, timeleft + msg, dialogSort(llListSort(menu, 1, 1)) , dialogChannel);
                        return;
                    }
                }
                // When the doll is collapsed they lose their access to most key functions with a few exceptions
                else if (collapsed && isDoll) {
                    msg = "You need winding.";
                    // Only present the TP home option for the doll if they have been collapsed
                    // for at least 900 seconds (15 minutes) - Suggested by Christina
                    if ((collapseTime + 900.0) < llGetTime()) {
                        if (llGetInventoryType(LANDMARK_HOME) == INVENTORY_LANDMARK) {
                            menu = ["TP Home"];
                        }
                        // If the doll is still down after 1800 seconds (30 minutes) and their emergency winder
                        // is recharged add a button for it
                        if (((collapseTime + 1800.0) < llGetTime()) && (winderRechargeTime == 0.0)) {
                            menu += ["Wind Emg"];
                        }
                    }
                }

                if (!collapsed && (!hasCarrier || isCarrier)) {
                    //not  being carried (or for carrier), not collapsed - normal in other words
                    // Toucher could be...
                    //   1. Doll
                    //   2. Carrier
                    //   3. Controller
                    //   4. Someone else

                    // Options only available to dolly
                    if (isDoll) {
                        if (!collapsed) {
                            menu += "Options";
                            if (detachable) menu += "Detach";
    
                            if (canAFK) menu += cdGetButton("AFK", id, afk, 0);
    
                            menu += cdGetButton("Visible", id, visible, 0);
                        }
                    }
                    else {
                        manpage = "communitydoll.htm";

                        // Toucher is not Doll.... could be anyone
                        msg =  dollName + " is a doll and likes to be treated like " +
                               "a doll. So feel free to use these options.\n";
                    }

                    // Can the doll be dressed? Add menu button
                    if ((RLVok == 1) && !collapsed && ((!isDoll && canDress) || (isDoll && canWear && !wearLock))) {
                        menu += "Outfits...";
                    }

                    // Can the doll be transformed? Add menu button
                    if (!collapsed && isTransformingKey) {
                        menu += "Type of Doll";
                    }

                    if (!collapsed) {
                        if (keyAnimation != "") {
                            msg += "Doll is currently posed.\n";
    
                            if ((!isDoll && canPose) || (poserID == dollID)) {
                                menu += ["Pose","Unpose"];
                            }
                        }
                        else {
                            if ((!isDoll && canPose) || isDoll)
                                menu += "Pose";
                        }
                    }

                    if (!collapsed && ((numControllers == 0) || (isController && !isDoll))) {
                        if (canCarry) {
                            msg += "Carry option picks up " + dollName + " and temporarily" +
                                   " makes the Dolly exclusively yours.\n";

                            if (!hasCarrier) menu += "Carry";
                        }
                    }

#ifdef ADULT_MODE
                        // Is doll strippable?
                        if ((RLVok == 1) && !collapsed && (pleasureDoll || dollType == "Slut")) {
#ifdef TESTER_MODE
                            if (isController || isCarrier || ((debugLevel != 0) && isDoll)) {
#else
                            if (isController || isCarrier) {
#endif
                                if (simRating == "MATURE" || simRating == "ADULT") menu += "Strip";
                            }
                        }
#endif
                }

#ifdef TESTER_MODE
                if ((debugLevel != 0) && isDoll) menu += "Wind";
#endif
                if (!isDoll) menu += "Wind";
                menu += "Help/Support";

                // Options only available if controller
                if (isController) {
                    if (!isDoll) menu += [ "Options" ];
                    if (!isDoll || !detachable) menu += [ "Detach" ];
                }
                
                if (!isDoll) {
                    if (marketplaceURL != "") menu += "Get a Key";
                }

                cdListenerActivate(dialogHandle);
                llSetTimerEvent(60.0);

                if (RLVok == -1) msg += "Still checking for RLV support some features unavailable.\n";
                if (RLVok == 0) {
                    msg += "No RLV detected some features unavailable.\n";
                    if (cdIsDoll(id) || cdIsController(id)) menu += "*RLV On*";
                }

                msg += "See " + WEB_DOMAIN + manpage + " for more information." ;
                llDialog(id, timeleft + msg, dialogSort(llListSort(menu, 1, 1)) , dialogChannel);
            }
        }
        else if (code == 350) {
            string script = llList2String(split, 0);
            RLVok = llList2Integer(split, 1);
            
            lmInternalCommand("updateExceptions", "", NULL_KEY);
        }
    }

    timer() {
        if (nextMenu != "") {
            lmInternalCommand(nextMenu, menuName, menuID);
            llSetTimerEvent(30.0);
        }
        else {
            if (blacklistHandle) { llListenRemove(blacklistHandle); blacklistHandle = 0; }
            if (controlHandle)   { llListenRemove(controlHandle);     controlHandle = 0; }

            cdListenerDeactivate(dialogHandle);
            dialogKeys = []; dialogButtons = []; dialogNames = [];
            llSetTimerEvent(0.0);
        }

        nextMenu = "";
        menuName = "";
        menuID = NULL_KEY;
    }

    sensor(integer num) {
        integer i; integer channel = blacklistChannel; string type = "blacklist";
        list current = cdList2ListStrided(blacklist, 0, -1, 2);
        dialogKeys = []; dialogNames = []; dialogButtons = [];
        if (controlHandle) {
            channel = controlChannel;
            type = "controller list";
            current = cdList2ListStrided(MistressList, 0, -1, 2);
        }
        while ((i < num) && (llGetListLength(dialogButtons) < 12)) {
            if (llListFindList(current, [(string)llDetectedKey(i)]) == -1) { // Don't list existing users
                dialogKeys += llDetectedKey(i);
                dialogNames += llDetectedName(i);
                dialogButtons += llGetSubString(llDetectedName(i), 0, 23);
            }
            i++;
        }

        llDialog(dollID, "Select the avatar to be added to the " + type + ".", dialogSort(dialogButtons + MAIN), channel);
    }

    no_sensor() {
        llDialog(dollID, "No avatars detected within chat range", [MAIN], dialogChannel);
    }

    touch_start(integer num) {
        integer i;
        for (i = 0; i < num; i++) {
            key id = llDetectedKey(i);
            if (startup) lmSendToAgent("Dolly's key is still establishing connections with " + llToLower(pronounHerDoll) + " systems please try again in a few minutes.", id);
            else lmInternalCommand("mainMenu", llGetDisplayName(id), id);
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
        if (llListFindList(blacklist, [ (string)id ]) != -1) {
            lmSendToAgent("You are not permitted to access this key.", id);
            return;
        }
        
        // Cache access test results
        integer hasCarrier      = cdCarried();
        integer isCarrier       = cdIsCarrier(id)       || cdIsBuiltinController(id);
        integer isController    = cdIsController(id);
        integer isDoll          = cdIsDoll(id);
        integer numControllers  = cdControllerCount();

        list split = llParseStringKeepNulls(choice, [ " " ], []);

        name = llGetDisplayName(id);

        integer space = llSubStringIndex(choice, " ");
        // 04-03-2014 Dev-Note:
        // Varnames for these two sub strings have changed, current usage makes them misleading.
        string beforeSpace = llStringTrim(llGetSubString(choice, 0, space),STRING_TRIM);
        string afterSpace = llDeleteSubString(choice, 0, space);

        debugSay(3, "DEBUG-MENU", "Button clicked: " + choice + ", afterSpace=\"" + afterSpace + "\", beforeSpace=\"" + beforeSpace + "\"");
        lmMenuReply(choice, name, id);

        menuID = id;
        menuName = name;

        if (channel == dialogChannel) {
            integer isAbility; // Temporary variables used to determine if an option
            integer isFeature; // from the features or abilities menu was clicked that
                               // way we can restore it making setting several choices
                               // much more user friendly.

            if (choice == MAIN) {
                lmInternalCommand("mainMenu", "", id);
                return;
            }

            if (choice == "Get a Key") {
                llLoadURL(id, "To get your own free community doll key from our marketplace store click \"Go to page\"", marketplaceURL);
            }
            else if (choice == "Options") {
                string msg; list pluslist;
                if (isDoll) {
                    msg = "See " + WEB_DOMAIN + "keychoices.htm for explanation.";

                    pluslist += [ "Type...", "Access..." ];

                    if (isController) pluslist += "Abilities...";
                }
                else if (isController) {

                    msg = "See " + WEB_DOMAIN + "controller.htm. Choose what you want to happen.";

                    pluslist += [ "Abilities...", "Drop Control" ];
                    
                    if (llListFindList(BuiltinControllers, [(string)id]) != -1) pluslist += [ "Access..." ];
                }
                else return;

                pluslist += [ "Features...", "Key..." ];

                llDialog(id, msg, dialogSort(pluslist + MAIN), dialogChannel);
            }
            else if (choice == "Detach")
                lmInternalCommand("detach", "", id);
            else if (afterSpace == "Visible") lmSendConfig("isVisible", (string)(visible = (beforeSpace == CROSS)));
            else if (choice == "Reload Config") {
                llResetOtherScript("Start");
            }
            else if (choice == "TP Home") {
                lmInternalCommand("TP", LANDMARK_HOME, id);
            }
            else if (afterSpace == "AFK") {
                lmSendConfig("afk", (string)(afk = (beforeSpace == CROSS)));
                float factor = 2.0;
                if (afk) factor = 0.5;
                displayWindRate *= factor;
                windRate *= factor;
                integer minsLeft = llRound(timeLeftOnKey / (60.0 * displayWindRate));
                lmInternalCommand("setAFK", (string)afk + "|0|" + formatFloat(windRate, 1) + "|" + (string)minsLeft, id);

                string nextMenu = "mainMenu";
                llSetTimerEvent(1.0);
            }
            if ((afterSpace == "Blacklist") || (afterSpace == "Controller")) {
                integer activeChannel; string msg;
                if (afterSpace == "Blacklist") {
                    if (controlHandle) {
                        llListenRemove(controlHandle);
                        controlHandle = 0;
                    }
                    activeChannel = blacklistChannel;
                    msg = "blacklist";
                    dialogKeys  = cdList2ListStrided(blacklist, 0, -1, 2);
                    dialogNames = cdList2ListStrided(blacklist, 1, -1, 2); 
                    blacklistHandle = cdListenUser(blacklistChannel, id);
                }
                else {
                    if (blacklistHandle) {
                        llListenRemove(blacklistHandle);
                        blacklistHandle = 0;
                    }
                    activeChannel = controlChannel;
                    msg = "controller list";
                    dialogKeys  = cdList2ListStrided(MistressList, 0, -1, 2);
                    dialogNames = cdList2ListStrided(MistressList, 1, -1, 2); 
                    controlHandle = cdListenUser(controlChannel, id);
                }
                
                // Only need this once now, make dialogButtons = numbered list of names truncated to 24 char limit
                dialogButtons = []; integer i; integer n = llGetListLength(dialogKeys);
                for (i = 0; i < n; i++) dialogButtons += llGetSubString((string)(i+1) + ". " + llList2String(dialogNames, i), 0, 23);

                if (beforeSpace == "⊕") {
                    if (llGetListLength(dialogKeys) < 11) {
                        llSensor("", "", AGENT, 20.0, PI);
                    }
                    else {
                        msg = "You already have the maximum (11) entries in your " + msg;
                        msg += " please remove one or more entries before attempting to add another.";
                        llRegionSayTo(id, 0, msg);
                    }
                }
                else if (beforeSpace == "⊖") {
                    if (dialogKeys == []) {
                        msg = "You currently have nobody listed in your " + msg;
                        msg += " did you mean to select the add option instead?.";
                        llRegionSayTo(id, 0, msg);
                        return;
                    }
                    else msg = "Choose a person to remove from your " + msg;

                    llDialog(id, msg, dialogSort(llListSort(dialogButtons, 1, 1) + MAIN), activeChannel);
                    llSetTimerEvent(60.0);
                }
                else if (beforeSpace == "List") {
                    if (dialogNames == []) msg = "Your " + msg + " is empty.";
                    else {
                        msg = "Current " + msg + ":";
                        for (i = 0; i < n; i++) msg += "\n" + (string)(i+1) + ". " + llList2String(dialogNames, i);
                    }
                    llOwnerSay(msg);
                }
            }

            // Entering options menu section
            
            // Entering key menu section
                 if (afterSpace == "Gem Light")     lmSendConfig("primLight", (string)(beforeSpace == CROSS));
            else if (afterSpace == "Key Glow")      lmSendConfig("primGlow", (string)(beforeSpace == CROSS));

            // Entering abilities menu section
            isAbility = 1;
            if (afterSpace == "Self TP") lmSendConfig("helpless", (string)(beforeSpace == CHECK));
            else if (afterSpace == "Self Dress") lmSendConfig("canWear", (string)(canWear = (beforeSpace == CROSS)));
            else if (afterSpace == "Detachable") lmSendConfig("detachable", (string)(detachable = (beforeSpace == CROSS)));
            else if (afterSpace == "Flying") lmSendConfig("canFly", (string)(beforeSpace == CROSS));
            else if (afterSpace == "Sitting") lmSendConfig("canSit", (string)(beforeSpace == CROSS));
            else if (afterSpace == "Standing") lmSendConfig("canStand", (string)(beforeSpace == CROSS));
            else if (afterSpace == "Force TP") lmSendConfig("autoTP", (string)(beforeSpace == CROSS));
            else if (afterSpace == "Pose Silence") lmSendConfig("poseSilence", (string)(beforeSpace == CROSS));
            else isAbility = 0; // Not an options menu item after all

            isFeature = 1; // Maybe it'a a features menu item
            if (afterSpace == "Type Text") lmSendConfig("signOn", (string)(beforeSpace == CROSS));
            else if (afterSpace == "Quiet Key") lmSendConfig("quiet", (string)(quiet = (beforeSpace == CROSS)));
            else if (afterSpace == "Rpt Wind") lmSendConfig("canRepeat", (string)(beforeSpace == CROSS));
            else if (afterSpace == "Carryable") lmSendConfig("canCarry", (string)(canCarry = (beforeSpace == CROSS)));
            else if (afterSpace == "Outfitable") lmSendConfig("canDress", (string)(canDress = (beforeSpace == CROSS)));
            else if (afterSpace == "Poseable") lmSendConfig("canPose", (string)(canPose = (beforeSpace == CROSS)));
            else if (afterSpace == "Warnings") lmSendConfig("doWarnings", (string)(beforeSpace == CROSS));
            else if (afterSpace == "Offline") lmSendConfig("offlineMode", (string)(beforeSpace == CROSS));
            else if (afterSpace == "Allow AFK") {
                lmSendConfig("canAFK", (string)(canAFK = (beforeSpace == CROSS)));
                if (!canAFK && afk) {
                    afk = 0;
                    displayWindRate = setWindRate();
                    integer minsLeft = llRound(timeLeftOnKey / (60.0 * displayWindRate));
                    lmInternalCommand("setAFK", (string)afk + "|0|" + formatFloat(windRate, 1) + "|" + (string)minsLeft, id);
                }
            }
#ifdef ADULT_MODE
            else if (afterSpace == "Pleasure Doll") lmSendConfig("pleasureDoll", (string)(beforeSpace == CROSS));
#endif
            else isFeature = 0;

            if (isAbility) {
                lmMenuReply("Abilities...", name, id);
            }
            else if (isFeature) {
                lmMenuReply("Features...", name, id);
            }

            if (isController && choice == "Drop Control") {
                integer index = llListFindList(MistressList, [ (string)id ]);
                if (index != -1) {
                    MistressList = llDeleteSubList(MistressList, index, index + 1);
                    lmSendConfig("MistressList", llDumpList2String(MistressList, "|"));
                }
            }

#ifdef ADULT_MODE
                // Strip items... only for Pleasure Doll and Slut Doll Types...
                list buttons = llListSort(["Top", "Bra", "Bottom", "Panties", "Shoes", "*ALL*"], 1, 1);
                if (choice == "Strip")
                    llDialog(id, "Take off:", dialogSort(buttons + MAIN), dialogChannel); // Do strip menu
                else if (llListFindList(buttons, [ choice ]) != -1)
                    lmStrip(choice);
#endif
        }

        if ((channel == blacklistChannel) || (channel == controlChannel)) {
            if (choice == MAIN) {
                lmInternalCommand("mainMenu", "", id);
                return;
            }
            
            string button = choice;
            integer i = llListFindList(dialogButtons, [ choice ]);
            string name = llList2String(dialogNames, i);
            string uuid = llList2String(dialogKeys, i);

            if (channel == blacklistChannel) {
                if (blacklistHandle) {
                    llListenRemove(blacklistHandle);
                    blacklistHandle = 0;
                }
                lmInternalCommand("addRemBlacklist", (string)uuid + "|" + name, id);
            }
            else {
                if (controlHandle) {
                    llListenRemove(controlHandle);
                    controlHandle = 0;
                }
                if (llListFindList(MistressList, [uuid,name]) == -1)    lmInternalCommand("addMistress", (string)uuid + "|" + name, id);
                else if (cdIsBuiltinController(id))                     lmInternalCommand("remMistress", (string)uuid + "|" + name, id);
            }
        }

        // Ideally the listener should be closing here and only reopened when we spawn another menu
        // other scripts also use the dialog listerner in this script.  Until they are writtent to send
        // a dialogListen command whenever they respawn a dialog we have to keep the listener open
        // at any sign of usage.
        llListenControl(dialogHandle, 1);
        llSetTimerEvent(60.0);
    }
}

