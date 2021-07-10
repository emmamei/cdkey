//========================================
// Dress.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 24 November 2020

// HISTORY:
//   Oct. 1   Adds everything in ~normalself folder, if oldOutfit begins with a +.
//            Adds channel dialog or id to screen listen
//   Nov. 17  moves listen to cd2667 so it gets turned off
//   Nov. 25  puts in dress menu
//   Aug 1    redoes closing

#include "include/GlobalDefines.lsl"

#define NO_FILTER ""
#define isKnownTypeFolder(a) (~llListFindList(typeFolders, (list)a))

#define nothingWorn(c,d) ((c) != "0") && ((c) != "1") && ((d) != "0") && ((d) != "1")
#define rlvLockKey()    lmRunRlv("detach=n")
#define rlvUnlockKey()  lmRunRlv("detach=y")

//========================================
// VARIABLES
//========================================

// FIXME: This should be in a notecard so it can be changed without mangling the scripts.
string outfitURL = "outfits.htm";
string outfitMessage;
list outfitNameList;
list outfitDialogList;

string prefix;

integer tempDressingLock = FALSE;  // allow only one dressing going on at a time

integer outfitChannel;
integer outfitHandle;

integer keyLocked = FALSE;

// These are the paths of the outfits relative to #RLV
string wearFolder;
string unwearFolder;

list outfitList;

// Relative to #RLV
string outfitMasterFolder;  // This contains folders of clothing to be worn
string normalselfFolder; // This is the ~normalself we are using
string normaloutfitFolder; // This is the ~normaloutfit we are using
string nudeFolder; // This is the ~nude we are using
string topFolder; // This is the top folder, usually same as outfitMasterFolder
string activeFolder; // This is the current folder displayed in menu: topFolder + "/" + clothingFolder

// Relative to outfitMasterFolder
string typeFolder; // This is the folder for the current type, if any: MUST be in outfitMasterFolder

// Relative to topFolder
string clothingFolder; // This is the current folder displayed in menu (relative to topFolder)

integer dressMenuHandle;
integer dressMenuChannel;

integer dressRandomHandle;
integer dressRandomChannel;

integer outfitPage; // zero-indexed

#define OUTFIT_PAGE_SIZE 9

//========================================
// FUNCTIONS
//========================================

#include "include/Wear.lsl" // Wearing outfits functions
#include "include/Listeners.lsl" // Listener functions

clearDresser() {
    dresserID = NULL_KEY;

    if (typeFolder != "")
        topFolder = outfitMasterFolder + "/" + typeFolder;
    else
        topFolder = outfitMasterFolder;
}

integer uSubStringLastIndex(string hay, string pin) {

    integer index2 = -1;
    integer index;

    if (pin == "") return 0;

    while (~index) {
        index = llSubStringIndex( llGetSubString(hay, ++index2, -1), pin);
        index2 += index;
    }

    return index2;
}

list outfitPageN(list outfitList) {
    integer newOutfitCount = llGetListLength(outfitList) - 1;
    integer currentIndex = (outfitPage - 1) * OUTFIT_PAGE_SIZE;
    integer tmpEnd;

    // Print the page contents - note that this happens even before
    // any dialog is put up
    integer n;
    integer x;
    string chat;
    list output;
    string outfitName;
    list tmpList;

    outfitNameList = [];

    // Take a slice related to the current page
    tmpList = (list)outfitList[currentIndex, currentIndex + 8];

    n = llGetListLength(tmpList);
    tmpEnd = n - 1;

    while (n--) {
        x = tmpEnd - n;

        // The first number (shown to user) has to not only
        // be one indexed, but be offset by the page.
        //
        // x ................ current list index (0 - max)
        // +1 ............... convert to 1-index
        // +currentIndex .... offset by currentPage index
        //
        outfitName = (string)tmpList[x];

        // Prepend a number to the chat entry...
        chat += "\n" + (string)(currentIndex + x + 1) + ". " + outfitName;

        // Add the button name to the full name list
        outfitNameList += (list)outfitName;

        // Cut the button name to the shortest allowable...
        output += (list)llGetSubString(outfitName, 0, 23);
    }

    llRegionSayTo(dresserID, 0, chat);

    return llListSort(output,1,1);
}

integer dressVia(integer channel) {

    integer dressHandle;

#ifdef DEVELOPER_MODE
    if (channel == 0) {
        llSay(DEBUG_CHANNEL,"Dressing channel not set!");
    }
#endif

    // activeFolder is the folder (full path) we are looking at with our Menu
    // outfitMasterFolder is where all outfits are stored, including
    //     ~normalself, ~normaloutfit, ~nude, and all the type folders
    // clothingFolder is the current folder for clothing, relative
    //     to the outfitMasterFolder
    // topFolder is the current top level for all outfits, not including system
    //     folders: it incorporates the type folder

    activeFolder = topFolder;
    if (clothingFolder != "") activeFolder += "/" + clothingFolder;

#ifdef DEVELOPER_MODE
    //llSay(DEBUG_CHANNEL,"listing inventory on " + (string)channel + " with active folder " + activeFolder);
    debugSay(4, "DEBUG-DRESS", "clothingFolder is " + clothingFolder);
    debugSay(4, "DEBUG-DRESS", "typeFolder is " + typeFolder);
    debugSay(4, "DEBUG-DRESS", "Setting activeFolder (in dressVia) to " + activeFolder);
#endif
    //lmSendConfig("activeFolder", activeFolder);

    dressHandle =  cdListenAll(channel);
    lmRunRlv("getinv:" + activeFolder + "=" + (string)(channel));

    llSetTimerEvent(30.0);

    return dressHandle;
}

// This function serves as a lock of sorts
//
// If there is already a dresser in progress, then
// it returns false. If not, then the dresser is assigned
// and the function returns TRUE.
//
// This also presumes that the dresser is cleared when
// necessary, and all exits from dressing must be accounted
// for. Use the clearDresser() macro to reset the lock.
//
integer isDresser(key id) {
    if (dresserID == NULL_KEY) {
        dresserID = id;
        return TRUE;
    }
    else return (dresserID == id);
}

changeComplete(string newOutfitName, integer success) {
    integer wearLock;
    string msg;

    // And remove the temp locks we used

    lmRunRlv("clear=attach,clear=detach");

    if (success) {
        cdSayToAgentPlusDoll("Change to new outfit " + newOutfitName + " complete.",dresserID);

        // Note: if wearLock is already set, it STAYS set with this setting
        //
        // This triggers Main and sets wearLockExpire
        //
        // This setting is thus: if dresser is anyone except Dolly, wearLock is set.
        // If wearLock is already set, it stays set..
        wearLock = ((wearLockExpire > 0) || ((dresserID != NULL_KEY) && (dresserID != dollID)));
    }
    else {

        cdSayToAgentPlusDoll("Change to new outfit " + newOutfitName + " unsuccessful.",dresserID);

        wearLock = 0;
    }

    // Note that if wearLock is already in place, this will bump the time up
    lmInternalCommand("wearLock", (string)wearLock, dollID);

    tempDressingLock = FALSE;
    llSetTimerEvent(0.0);
}

#ifdef DEVELOPER_MODE
string folderStatus() {

    return "Outfits Folder: " + outfitMasterFolder +
           "\nCurrent Folder: " + activeFolder +
           "\nType Folder: " + typeFolder +
           "\nUse ~normalself: " + normalselfFolder +
           "\nUse ~normaloutfit: " + normaloutfitFolder +
           "\nUse ~nude: " + nudeFolder;
}
#else
string folderStatus() {
    string typeFolderExists;

    if (typeFolder == "") typeFolderExists = "n/a";

    return "Outfits Folder: " + outfitMasterFolder +
           "\nType Folder: " + typeFolderExists;
}
#endif

//========================================
// STATES
//========================================
default {

    //----------------------------------------
    // STATE_ENTRY
    //----------------------------------------
    state_entry() {
        dollID = llGetOwner();
        keyID = llGetKey();
        myName = llGetScriptName();

        cdInitializeSeq();
    }

    //----------------------------------------
    // ON_REZ
    //----------------------------------------
    on_rez(integer start) {
        clearDresser();
    }

    //----------------------------------------
    // TIMER
    //----------------------------------------
    // Used for time-outs on menu selections
    timer() {
        llSetTimerEvent(0.0);
        clearDresser();
    }

    //----------------------------------------
    // LINK_MESSAGE
    //----------------------------------------
    link_message(integer lmSource, integer lmInteger, string lmData, key lmID) {

        parseLinkHeader(lmData,lmInteger);

        if (code == SEND_CONFIG) {

            // Configuration settings

            string name = (string)split[0];
            list cmdList = [
                            "dialogChannel",
                            "isAFK",
                            "rlvOk",
                            "keyLocked",
                            "typeHovertext",
                            "dollType",
                            "pronounHerDoll",
                            "pronounSheDoll",
                            "canDressSelf",
                            "collapsed",
#ifdef DEVELOPER_MODE
                            "debugLevel",
#endif
                            "normalselfFolder",
                            "normaloutfitFolder",
                            "nudeFolder",

                            "outfitMasterFolder",
                            "typeFolder",
#ifdef ADULT_MODE
                            "hardcore",
#endif
                            "isVisible",
                            "wearLockExpire"
            ];

            // Commands need to be in the list cmdList in order to be
            // recognized, before testing down below
            //
            if (!cdFindInList(cmdList,name))
                return;

            string value = (string)split[1];

            if (name == "dialogChannel") {
                dialogChannel = (integer)value;

                debugSay(6, "DEBUG-DRESS", "outfits Channel set to " + (string)outfitChannel);

            }
            else if (name == "isAFK")                              isAFK = (integer)value;
            else if (name == "rlvOk")                              rlvOk = (integer)value;
            else if (name == "keyLocked")                      keyLocked = (integer)value;
            else if (name == "typeHovertext")              typeHovertext = (integer)value;
            else if (name == "dollType")                        dollType = value;
            else if (name == "pronounHerDoll")            pronounHerDoll = value;
            else if (name == "pronounSheDoll")            pronounSheDoll = value;
            else if (name == "canDressSelf")                canDressSelf = (integer)value;
            else if (name == "collapsed")                      collapsed = (integer)value;

#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")                        debugLevel = (integer)value;
#endif
            else if (name == "normalselfFolder")        normalselfFolder = value;
            else if (name == "normaloutfitFolder")    normaloutfitFolder = value;
            else if (name == "nudeFolder")                    nudeFolder = value;

            else if (name == "outfitMasterFolder") {
                outfitMasterFolder = value;

                // Even though type folder may be set,
                // it will be invalidated by this process,
                // and should be set a long time after this anyway.
                //
                topFolder = outfitMasterFolder;
            }
            else if (name == "typeFolder") {
                typeFolder = value;
                clothingFolder = "";
                activeFolder = "";
                topFolder = outfitMasterFolder;

                if (typeFolder != "") {
                    topFolder += "/" + typeFolder;
                    dressRandomHandle = dressVia(dressRandomChannel);
                }
                // if typeFolder is blank, that doesn't tell us WHY: could be no type folder
                // was found, or could be that Type ignores type folders (Regular and Builder)
            }
            else if (name == "isVisible") {
                isVisible = (integer)value;
                lmInternalCommand("setHovertext", "", NULL_KEY);
            }
            else if (name == "wearLockExpire")            wearLockExpire = (integer)value;
#ifdef ADULT_MODE
            else if (name == "hardcore")                        hardcore = (integer)value;
#endif
        }
        else if (code == INTERNAL_CMD) {

            // Internal command - one of:
            //
            // * wearOutfit
            // * stripAll
            // * setHovertext
            // * carriedMenu

            string cmd = (string)split[0];
            split = llDeleteSubList(split, 0, 0);

            if (cmd == "wearOutfit") {
                string newOutfitName = (string)split[0];

                wearOutfitCore(newOutfitName);

                debugSay(2,"DEBUG-DRESS","keyLocked = " + (string)keyLocked);
                rlvLockKey();
                changeComplete(newOutfitName,TRUE);
                clearDresser();
                if (keyLocked == FALSE) rlvUnlockKey();
            }
            else if (cmd == "resetBody") {

                resetBodyCore();

                // Clear Key lockon
                if (keyLocked == FALSE) rlvUnlockKey();
            }
#ifdef ADULT_MODE
            else if (cmd == "stripAll") {
                stripCore();
            }
#endif
            else if (cmd == "setHovertext") {
                //list paramList = llGetPrimitiveParams([ PRIM_TEXT ]);
                //string primText = (string)paramList[0];
                debugSay(2, "DEBUG-DRESS", "Hovertext activated");

//#define cdSetHovertext(x,c) if(primText!=x)llSetText(x,c,1.0)
#define cdSetHovertext(x,c) llSetText(x,c,1.0)
#define DISABLED_DOLLY_COLOR RED
#define AFK_DOLLY_COLOR      YELLOW
#define TYPE_DOLLY_COLOR     WHITE
#define DEFAULT_DOLLY_COLOR  WHITE

                     if (collapsed)     { cdSetHovertext("Disabled Dolly!\nWind Me!",  ( DISABLED_DOLLY_COLOR )); }
                else if (isAFK)         { cdSetHovertext(dollType + " Doll (AFK)",     (      AFK_DOLLY_COLOR )); }
                else if (typeHovertext) { cdSetHovertext(dollType + " Doll",           (     TYPE_DOLLY_COLOR )); }
                else if (!isVisible)    { cdSetHovertext("",                           (  DEFAULT_DOLLY_COLOR )); }
                else                    { cdSetHovertext("Wind Me!",                   (  DEFAULT_DOLLY_COLOR )); }
            }
            else if (cmd == "carriedMenu") {
                // This is the menu that activates for a non-carrier when
                // Dolly is being carried. Thus a carrier should never see
                // this menu dialog.

                key menuID = (string)split[0];
                string carrierName = (string)split[1];
                string menuMessage;

                lmDialogListen();
                llSleep(0.5);

                debugSay(2, "DEBUG-CARRIED", "Menu activated...");
                if (cdIsDoll(menuID)) {
                    menuMessage = "You are being carried by " + carrierName + ". ";
                }
                else menuMessage = dollName + " is currently being carried by " + carrierName + ". They have full control over this doll. ";

                debugSay(2, "DEBUG-CARRIED", "menuID = " + (string)menuID + "; dialogChannel = " + (string)dialogChannel);
                debugSay(2, "DEBUG-CARRIED", "menuMessage = " + menuMessage);
                llDialog(menuID, menuMessage, [ "OK" ], dialogChannel);
            }
        }
        else if (code == RLV_RESET) {

            // RLV check is resetting values

            rlvOk = (integer)split[0];
        }
        else if (code == MENU_SELECTION)  {

            // Selection from menu

            string menuChoice = (string)split[0];
            //string name = (string)split[1];

            if (menuChoice == "Outfits..." && !tempDressingLock) {

                // Check for dresser lockout
                if (!isDresser(lmID)) {
                    cdSayTo("You go to look in Dolly's closet for clothes, and find that " + llGetDisplayName(dresserID) + " is already there looking", lmID);
                    return;
                }

                debugSay(2, "DEBUG-DRESS", "Outfit menu; outfit Folder = " + outfitMasterFolder);

                // Check to see if clothing has been worn long enough before changing (wearLock)
                if (wearLockExpire > 0) {
                    clearDresser();

                    lmDialogListen();
                    llDialog(dresserID, "Clothing was just changed; cannot change right now.", ["OK"], dialogChannel);

                    return;
                }

                // If outfitMasterFolder is blank, we SHOULD NOT be here...

#ifndef PRESERVE_FOLDER
                // This resets the current folder location for the menu
                //
                // Note if typeFolder is unset, then clothingFolder will be too
                clothingFolder = typeFolder;
#endif
                dressMenuHandle = dressVia(dressMenuChannel);
            }
            else if (menuChoice == UPMENU) {
                // When we get here, using the Menu Reply to MAIN
                // makes no sense - it's too late for that.
                //
                // Strip out last element from slash forward
                integer lastElement;

                outfitList = [];
                debugSay(6, "DEBUG-DRESS", "Up Menu: clothingFolder = \"" + clothingFolder + "\"");

                lastElement = uSubStringLastIndex(clothingFolder,"/");

                if (lastElement != -1) {
                    debugSay(6, "DEBUG-DRESS", "Up Menu: found separator");
                    clothingFolder = llGetSubString(clothingFolder,0,lastElement - 1);
                    //lmSendConfig("clothingFolder", clothingFolder);
                }
                else {
                    // At this point, either clothingFolder has ONE item in it, or it is null.
                    // It should not be null - because that needs to go up to MAIN menu, not UPMENU.
                    // (Same thing for when clothingFolder equals an in-use typeFolder.)
                    //
                    // Since having one single item means no "/" we need to adjust clothingFolder manually
                    //
                    debugSay(6, "DEBUG-DRESS", "Up Menu: found no separator");
                    clothingFolder = "";
                    //lmSendConfig("clothingFolder", clothingFolder);
                }

                dressMenuHandle = dressVia(dressMenuChannel); // recursion: put up a new Primary menu
                //llSetTimerEvent(60.0);
            }
        }
        else if (code < 200) {
            if (code == INIT_STAGE1) {
                  dressMenuChannel = listenerGetChannel();
                dressRandomChannel = listenerGetChannel();
                     outfitChannel = listenerGetChannel();
            }
            else if (code == SIM_RATING_CHG) {
                simRating = (string)split[0];
                integer regionRating = cdRating2Integer(simRating);
            }
            else if (code == CONFIG_REPORT) {
                cdConfigureReport();
            }
#ifdef DEVELOPER_MODE
            else if (code == MEM_REPORT) {
                memReport(myName,(float)split[0]);
            }
#endif
        }
    }

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer listenChannel, string listenName, key listenID, string listenMessage) {
        // We have our answer so now we can turn the listener off until our next request

        // Request max memory to avoid constant having to bump things up and down
        //llSetMemoryLimit(65536);

        debugSay(6, "DEBUG-DRESS", "Listener called[" + (string)listenChannel + "]: " + listenName + "|" + listenMessage);

        //----------------------------------------
        // CHANNELS

        if (listenChannel == outfitChannel) {
            // This channel handles the responses from the Outfits menus,
            // including all outfits, Next, Prev, and Back...
            // are done by listener2665); we get here after the first menu
            // sends back a response.
            //
            // We just got a selected Outfit or new folder to go into

            // Build outfit menu: note it is using the number before the period here
            integer select = (integer)llGetSubString(listenMessage, 0, llSubStringIndex(listenMessage, ".") - 1);
            if (select != 0) listenMessage = (string)outfitList[select - 1];
            // else we have a normal selection, not a numeric one

            debugSay(6, "DEBUG-DRESS", "Secondary outfits menu: listenMessage = " + listenMessage + "; select = " + (string)select);

            // FIXME: This assumes no one will have a directory like "Outfits Big" or "Back..."
            if (llGetSubString(listenMessage, 0, 6) == "Outfits") {

                // Choice was one of:
                //
                // - Outfits Next
                // - Outfits Prev

                if (!isDresser(listenID)) {
                    outfitList = [];
                    return;
                }

                if (listenMessage == "Outfits Next") {
#ifdef ROLLOVER
                    outfitPage++;
                    if ((outfitPage - 1) * OUTFIT_PAGE_SIZE > llGetListLength(outfitList))
                        outfitPage = 1;
#else
                    if (outfitPage * OUTFIT_PAGE_SIZE < llGetListLength(outfitList))
                        outfitPage++;
#endif
                }
                else if (listenMessage == "Outfits Prev") {
#ifdef ROLLOVER
                    outfitPage--;
                    if (outfitPage < 1)
                        outfitPage = llFloor((llGetListLength(outfitList) + (OUTFIT_PAGE_SIZE / 2)) / (float)OUTFIT_PAGE_SIZE);
#else
                    if (outfitPage != 1)
                        outfitPage--;
#endif
                }

                list dialogItems = [ "Outfits Prev", "Outfits Next", "Back..." ];

                // Setting backMenu in this way is not proper: we don't know if
                // going back to the Main menu or one folder up is appropriate
                //
                //backMenu = MAIN;
                //lmSendConfig("backMenu",(backMenu = MAIN));
                //dialogItems += "Back...";

                // We only get here if we are wandering about in the same folder...
                // FIXME: This is a brute force listener open
                lmDialogListen();
                outfitHandle = cdListenAll(outfitChannel);

                outfitDialogList = outfitPageN(outfitList);

                // outfitMessage was built by the initial call to listener2666
                llDialog(dresserID, outfitMessage, dialogSort(outfitDialogList + dialogItems), outfitChannel);
                llSetTimerEvent(60.0);

            }
            else if (listenMessage == "Back...") {
                outfitList = [];
                lmMenuReply(backMenu, llGetDisplayName(listenID), listenID);

                // Reset to Main Menu
                //lmSendConfig("backMenu",(backMenu = MAIN));
            }
            else {
                integer index;

                if (~(index = llListFindList(outfitDialogList, (list)listenMessage))) {

                    // This is the actual processing of an Outfit Menu entry -
                    // either a folder or a single outfit item.
                    //
                    // This could be entered via a menu injection by a random dress choice
                    // No standard user should be entering this way anyway
                    //if (!isDresser(listenID)) return;

                    string c = cdGetFirstChar(listenMessage);

                    outfitList = [];

                    if (isTypeFolder(c) || isParentFolder(c)) {

                        // listenMessage represents either a Type Folder or a Parent Folder;
                        // recurse into it and display it.

                        if (clothingFolder == "") clothingFolder = listenMessage;
                        else clothingFolder += ("/" + listenMessage);

                        debugSay(6, "DEBUG-DRESS", "Generating new list of outfits...");
                        lmSendConfig("backMenu",(backMenu = UPMENU));
                        dressMenuHandle = dressVia(dressMenuChannel); // recursion: put up a new Primary menu

                        //llSetTimerEvent(60.0);
                    }
                    else {

                        // listenMessage represents an outfit name (possibly an avatar name)

                        string outfitName = (string)outfitNameList[index];

                        debugSay(3, "DEBUG-DRESS", "Calling wearOutfit with " + outfitName + " in the active folder " + activeFolder);
                        lmInternalCommand("wearOutfit", outfitName, NULL_KEY);
                    }
                }
#ifdef DEVELOPER_MODE
                else {
                    llSay(DEBUG_CHANNEL,"Received unknown outfit! (" + listenMessage + ")");
                }
#endif
            }
        }

        //----------------------------------------
        // Channel: dressMenuChannel
        //
        // Choosing a new outfit normally and manually: create a paged dialog with an
        // alphabetical list of available outfits, and let the user choose one
        //
        else if (listenChannel == dressMenuChannel) {

            // Choose an outfit
            //
            // This is the first menu presented upon the activation
            // of a new folder to choose outfits from.

            llListenRemove(dressMenuHandle);

            // Check for an empty (text) list of outfits
            //
            // This is check #1 of an empty list of outfits

            if (listenMessage == "") {

                // No outfits available in this folder
                // FIXME: This is a brute force listener open
                lmDialogListen();
                cdListenAll(outfitChannel);

                // FIXME: What if dolly CANT go "back" up...?
                backMenu = UPMENU;
                llDialog(dresserID, "No outfits to wear in this folder.", [ "Back..." ], outfitChannel);

                llSetTimerEvent(60.0);
                return;
            }

            outfitList = llParseString2List(listenMessage, [","], []);

            integer n;
            string itemName;
            string prefix;
            list tmpList;

            debugSay(6, "DEBUG-DRESS", "Filtering outfit data");

            // Filter list of outfits (directories) to choose
            n = llGetListLength(outfitList);
            while (n--) {
                itemName = (string)outfitList[n];
                prefix = cdGetFirstChar(itemName);

                if (itemName != newOutfitName) {
                    if (!isHiddenFolder(prefix)) {
                        if (!isTypeFolder(prefix) || dollType == "Regular") {
                            tmpList += itemName;
                        }
                    }
                }
            }

            outfitList = tmpList;
            tmpList = [];

            debugSay(6, "DEBUG-DRESS", "Filtered list = " + llDumpList2String(outfitList,","));

            // Check for zero outfits in the list after cleaning it up...
            //
            // This is check #2 for an empty list of outfits

            if (outfitList == []) {
                outfitList = []; // free memory

                // FIXME: This is a brute force listener open
                lmDialogListen();
                cdListenAll(outfitChannel);

                // FIXME: What if dolly CANT go "back" up...?
                backMenu = UPMENU;
                llDialog(dresserID, "No wearable outfits in this folder.", [ "Back..." ], outfitChannel);

                llSetTimerEvent(60.0);
                return;
            }

            // At this point, outfitList is now completely built:
            // if we wanted a random outfit, this is the place for it.

            // Sort: slow bubble sort
            outfitList = llListSort(outfitList, 1, TRUE);

            // Outfits need to be scanned and a menu button list created

            // Now create appropriate menu page from full outfits list
            outfitPage = 1;

            outfitDialogList = outfitPageN(outfitList);
            list newOutfitList = outfitDialogList;

            if (llGetListLength(outfitList) < 10) newOutfitList += [ "-", "-" ];
            else newOutfitList += [ "Outfits Prev", "Outfits Next" ];
            newOutfitList += [ "Back..." ];

            if (dresserID == dollID) outfitMessage = "You may choose any outfit to wear. See the help file for more detailed information on outfits.";
            else outfitMessage = "You may choose any outfit for dolly to wear. ";

            outfitMessage += "\n\n" + folderStatus();

            // Provide a dialog to user to choose new outfit
            // FIXME: This is a brute force listener open
            lmDialogListen();
            cdListenAll(outfitChannel);

            // if clothingFolder is at the top, then go to MAIN... but typeFolder
            // might be active...
            if (clothingFolder == typeFolder)
                backMenu = MAIN;
            else
                backMenu = UPMENU;
            lmSendConfig("backMenu",backMenu);

            llDialog(dresserID, outfitMessage, dialogSort(newOutfitList), outfitChannel);

            llSetTimerEvent(60.0);
        }

        //----------------------------------------
        // Channel: dressRandomChannel
        //
        // Choosing a new outfit automatically: select a random outfit from the
        // type folder.
        //
        else if (listenChannel == dressRandomChannel) {
            // Choose an outfit
            //
            // This is the first menu presented upon the activation
            // of a new folder to choose outfits from.

            llListenRemove(dressRandomHandle);

            // Check for an empty (text) list of outfits
            //
            // This is check #1 of an empty list of outfits

            if (listenMessage == "") {

                // No outfits available in this folder: give message
                llOwnerSay("No outfits available to use for this Doll type.");

                llSetTimerEvent(60.0);
                return;
            }

            outfitList = llParseString2List(listenMessage, [","], []);

            integer n;
            string itemName;
            string prefix;
            list tmpList;

            debugSay(6, "DEBUG-DRESS", "Filtering random outfit data");

            // Filter list of outfits (directories) to choose:
            // remove all non-outfits... Note some of these
            // are currently unused by the code: if the macros
            // are removed, this code will have to be fixed.
            //
            n = llGetListLength(outfitList);
            while (n--) {
                itemName = (string)outfitList[n];
                prefix = cdGetFirstChar(itemName);

                if (!
                   (isGroupFolder(prefix) ||
                    isGroupFolder(prefix) ||
                    isHiddenFolder(prefix) ||
                    isPlusFolder(prefix) ||
                    isAvatarFolder(prefix) ||
                    isTypeFolder(prefix) ||
                    isParentFolder(prefix) ||
                    isRated(prefix))) {

                    tmpList += itemName;
                }
            }

            outfitList = tmpList;
            tmpList = [];

            debugSay(6, "DEBUG-DRESS", "Filtered random list = " + llDumpList2String(outfitList,","));

            // Check for zero outfits in the list after cleaning it up...
            //
            // This is check #2 for an empty list of outfits

            if (outfitList == []) {
                outfitList = []; // free memory

                llOwnerSay("No wearable outfits in Doll type folder.");

                llSetTimerEvent(60.0);
                return;
            }

            string randomOutfit;

            // At this point, outfitList is now completely built:
            // if we wanted a random outfit, this is the place for it.
            randomOutfit = (string)outfitList[ (integer)llFrand(llGetListLength(outfitList)) ];
            llOwnerSay("Dressing Dolly as " + dollType + " doll with " + randomOutfit + " outfit");

            // We can bypass the entire outfit selection process, and call wearOutfit directly,
            // because we know a lot more about the results.
            //
            lmInternalCommand("wearOutfit", randomOutfit, NULL_KEY);

            llSetTimerEvent(60.0);
        }
    }
}

//========== DRESS ==========
