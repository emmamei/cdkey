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
#define cdListenMine(a) llListen(a, NO_FILTER, dollID, NO_FILTER)
#define isKnownTypeFolder(a) (llListFindList(typeFolders, [ a ]) != NOT_FOUND)

#define nothingWorn(c,d) ((c) != "0") && ((c) != "1") && ((d) != "0") && ((d) != "1")
#define dressVia(a) listInventoryOn(a)
#define clearDresser() dresserID = NULL_KEY
#define rlvLockKey()    lmRunRLV("detach=n")
#define rlvUnlockKey()  lmRunRLV("detach=y")

//========================================
// VARIABLES
//========================================

// FIXME: This should be in a notecard so it can be changed without mangling the scripts.
string outfitURL = "outfits.htm";
string outfitMessage;
string msg;

string prefix;

integer tempDressingLock = FALSE;  // allow only one dressing going on at a time

string newOutfitName;

// New simple listener setup we only
// listen to rlvChannel directly the
// other we use MenuHandlers link 500's
#define RLV_BASE_CHANNEL 1
#ifdef RLV_BASE_CHANNEL
integer rlvBaseChannel;
#endif
integer outfitChannel;
integer outfitHandle;
integer change;
integer pushRandom;
integer keyLocked = FALSE;

// These are the paths of the outfits relative to #RLV
//string lastFolder;
string newOutfit;
string oldOutfit;
string wearFolder;
string unwearFolder;

list outfitList;

string clothingFolder; // This contains clothing to be worn
string outfitFolder;  // This contains folders of clothing to be worn
string activeFolder; // This is the lookup folder to search
string typeFolder; // This is the folder we want for our doll type
string topFolder; // This is the top folder, usually same as outfitFolder

string normalselfFolder; // This is the ~normalself we are using
string normaloutfitFolder; // This is the ~normaloutfit we are using
string nudeFolder; // This is the ~nude we are using

integer menuDressHandle;
integer menuDressChannel;

integer dressingFailures;

integer outfitPage; // zero-indexed

#define OUTFIT_PAGE_SIZE 9

//========================================
// FUNCTIONS
//========================================

#include "include/Wear.lsl" // Wearing outfits functions

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

        // Cut the button name to the shortest allowable...
        output += (list)llGetSubString(outfitName, 0, 23);
    }

    llRegionSayTo(dresserID, 0, chat);

    return llListSort(output,1,1);
}

retryDirSearch() {

    // Nowhere to retry to
    if (clothingFolder == "") return;

    // Retry at Outfits top level
    // FIXME: what about Type folders?
    clothingFolder = "";
    //lmSendConfig("clothingFolder", clothingFolder);
    dressVia(randomDressChannel); // recursion
}

#ifdef RLV_BASE_CHANNEL
// FUNCTION: rlvRequest - used in only one location
//
// FIXME: can the rlvRequest function be removed or reworked?
rlvRequest(string rlv, integer channel) {

    if (channel < 2670) {

        // FIXME: this should not happen

        if (channel == 0) {
            llSay(DEBUG_CHANNEL,"rlvRequest called with channel zero");
            return;
        }

        llSay(DEBUG_CHANNEL,"rlvRequest called with old channel numbers");
        if (channel == 2666) menuDressHandle = cdListenAll(menuDressChannel);

        lmRunRLV(rlv + (string)(rlvBaseChannel + channel));
    }
    else {

        // FIXME: this block should be executed all the time

        if (channel == menuDressChannel) menuDressHandle = cdListenAll(menuDressChannel);
        lmRunRLV(rlv + (string)channel);
    }

    llSetTimerEvent(30.0);
}
#endif

listInventoryOn(integer channel) {

    if (outfitFolder == "") {
        llOwnerSay("No suitable outfits folder found, so unfortunately you will not be able to be dressed");
        return;
    }

    // activeFolder is the folder (full path) we are looking at with our Menu
    // outfitFolder is where all outfits are stored, including
    //     ~normalself, ~normaloutfit, ~nude, and all the type folders
    // clothingFolder is the current folder for clothing, relative
    //     to the outfitFolder
    // topFolder is the current top level for all outfits, not including system
    //     folders: it incorporates the type folder

    activeFolder = topFolder;
    if (clothingFolder != "") activeFolder += "/" + clothingFolder;

#ifdef DEVELOPER_MODE
    //llSay(DEBUG_CHANNEL,"listing inventory on " + (string)channel + " with active folder " + activeFolder);
    debugSay(4, "DEBUG-DRESS", "clothingFolder is " + clothingFolder);
    debugSay(4, "DEBUG-DRESS", "typeFolder is " + typeFolder);
    debugSay(4, "DEBUG-DRESS", "Setting activeFolder (in listInventory) to " + activeFolder);
#endif
    lmSendConfig("activeFolder", activeFolder);

    if (channel == menuDressChannel) {
        menuDressHandle =  cdListenAll(menuDressChannel);
        lmRunRLV("getinv:" + activeFolder + "=" + (string)(channel));

        llSetTimerEvent(30.0);
    }
    else {
        llSay(DEBUG_CHANNEL,"Erroneous inventory channel requested! (" + (string)(channel) + ")");
    }
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

changeComplete(integer success) {
    integer wearLock;

    // And remove the temp locks we used

    // If we used "detach" as the pattern then the Key would be unlocked
    lmRunRLV("clear=attach,clear=detachall");

    if (success) {
        if (change) {
            string s = "Change to new outfit " + newOutfitName + " complete.";

            cdSayToAgentPlusDoll(s,dresserID);
        }

        // Note: if wearLock is already set, it STAYS set with this setting
        //
        // This triggers Main and sets wearLockExpire
        //
        // This setting is thus: if dresser is anyone except Dolly, wearLock is set.
        // If wearLock is already set, it stays set..
        wearLock = ((wearLockExpire > 0) || ((dresserID != NULL_KEY) && (dresserID != dollID)));
    }
    else {
        if (dressingFailures > MAX_DRESS_FAILURES)
            llOwnerSay("Too many dressing failures.");

        string s = "Change to new outfit " + newOutfitName + " unsuccessful.";

        cdSayToAgentPlusDoll(s,dresserID);

        wearLock = 0;
    }

    // Note that if wearLock is already in place, this will bump the time up
    lmInternalCommand("wearLock", (string)wearLock, dollID);

    change = 0;

    tempDressingLock = FALSE;
    llSetTimerEvent(0.0);
}

#ifdef DEVELOPER_MODE
string folderStatus() {

    return "Outfits Folder: " + outfitFolder +
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

    return "Outfits Folder: " + outfitFolder +
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
    link_message(integer source, integer i, string data, key id) {

        parseLinkHeader(data,i);

        if (code == SEND_CONFIG) {

            // Configuration settings

            string name = (string)split[0];
            list cmdList = [
                            "dialogChannel",
                            "isAFK",
                            "RLVok",
                            "keyLocked",
                            "hovertextOn",
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

                            "outfitFolder",
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
            if (llListFindList(cmdList, (list)name) == NOT_FOUND)
                return;

            string value = (string)split[1];

            if (name == "dialogChannel") {
                dialogChannel = (integer)value;
#ifdef RLV_BASE_CHANNEL
                rlvBaseChannel = dialogChannel ^ 0x80000000; // Xor with the sign bit forcing the positive channel needed by RLV spec.
#endif
                menuDressChannel = (dialogChannel ^ 0x80000000) + 2666; // Xor with the sign bit forcing the positive channel needed by RLV spec.
                outfitChannel = dialogChannel + 15; // arbitrary offset
                debugSay(6, "DEBUG-DRESS", "outfits Channel set to " + (string)outfitChannel);

            }
            else if (name == "isAFK")                              isAFK = (integer)value;
            else if (name == "RLVok")                              RLVok = (integer)value;
            else if (name == "keyLocked")                      keyLocked = (integer)value;
            else if (name == "hovertextOn")                  hovertextOn = (integer)value;
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

            else if (name == "outfitFolder") {
                outfitFolder = value;

                if (typeFolder != "") topFolder = outfitFolder + "/" + typeFolder;
                else topFolder = outfitFolder;
            }
            else if (name == "typeFolder") {
                typeFolder = value;
                topFolder = outfitFolder + "/" + typeFolder;
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

                wearOutfitCore((string)split[0]);

                debugSay(2,"DEBUG-DRESS","keyLocked = " + (string)keyLocked);
                if (keyLocked == FALSE) rlvUnlockKey();
                changeComplete(TRUE);
                clearDresser();
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

                     if (collapsed)   { cdSetHovertext("Disabled Dolly!\nWind Me!",  ( DISABLED_DOLLY_COLOR )); }
                else if (isAFK)       { cdSetHovertext(dollType + " Doll (AFK)",     (      AFK_DOLLY_COLOR )); }
                else if (hovertextOn) { cdSetHovertext(dollType + " Doll",           (     TYPE_DOLLY_COLOR )); }
                else if (!isVisible)  { cdSetHovertext("",                           (  DEFAULT_DOLLY_COLOR )); }
                else                  { cdSetHovertext("Wind Me!",                   (  DEFAULT_DOLLY_COLOR )); }
            }
            else if (cmd == "carriedMenu") {
                key id = (string)split[0];
                string carrierName = (string)split[1];

                lmDialogListen();
                llSleep(0.5);

                debugSay(2, "DEBUG-CARRIED", "Menu activated...");
                if (cdIsDoll(id)) {
                    msg = "You are being carried by " + carrierName + ". ";
                }
                else msg = dollName + " is currently being carried by " + carrierName + ". They have full control over this doll. ";

                debugSay(2, "DEBUG-CARRIED", "id = " + (string)id + "; dialogChannel = " + (string)dialogChannel);
                debugSay(2, "DEBUG-CARRIED", "msg = " + msg);
                llDialog(id, msg, [ "OK" ], dialogChannel);
            }
        }
        else if (code == RLV_RESET) {

            // RLV check is resetting values

            RLVok = (integer)split[0];
        }
        else if (code == MENU_SELECTION)  {

            // Selection from menu

            string choice = (string)split[0];
            string name = (string)split[1];

            if (choice == "Outfits..." && !tempDressingLock) {
                // Check for dresser lockout
                if (!isDresser(id)) {
                    cdSayTo("You go to look in Dolly's closet for clothes, and find that " + llGetDisplayName(dresserID) + " is already there looking", id);
                    return;
                }

                debugSay(2, "DEBUG-DRESS", "Outfit menu; outfit Folder = " + outfitFolder);

                // Check to see if clothing has been worn long enough before changing (wearLock)
                if (wearLockExpire > 0) {
                    clearDresser();
                    lmDialogListen();
                    llDialog(dresserID, "Clothing was just changed; cannot change right now.", ["OK"], dialogChannel);
                    return;
                }

                if (outfitFolder != "") {
                    debugSay(2, "DEBUG-DRESS", "Outfit menu; outfit Folder is not empty");

#ifndef PRESERVE_DIRECTORY
                    // This resets the current directory location for the menu
                    //
                    // Note if typeFolder is unset, then clothingFolder will be too
                    clothingFolder = typeFolder;
#endif
                    dressVia(menuDressChannel);
                }
                else {
                    clearDresser();
                    if (RLVok == TRUE) llSay(DEBUG_CHANNEL,"outfitFolder is unset.");
                    else llSay(DEBUG_CHANNEL,"You cannot be dressed without RLV active.");
                    return;
                }
            }
            else if (choice == UPMENU) {
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

                dressVia(menuDressChannel); // recursion: put up a new Primary menu
                llSetTimerEvent(60.0);
            }
        }
        else if (code < 200) {
            if (code == SIM_RATING_CHG) {
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
    listen(integer channel, string name, key id, string choice) {
        // We have our answer so now we can turn the listener off until our next request

        // Request max memory to avoid constant having to bump things up and down
        //llSetMemoryLimit(65536);

        debugSay(6, "DEBUG-DRESS", "Listener called[" + (string)channel + "]: " + name + "|" + choice);

        //----------------------------------------
        // CHANNELS

        if (channel == outfitChannel) {
            // This channel handles the responses from the Outfits menus,
            // including all outfits, Next, Prev, and Back...
            // are done by listener2665); we get here after the first menu
            // sends back a response.
            //
            // We just got a selected Outfit or new folder to go into

            // Build outfit menu: note it is using the number before the period here
            integer select = (integer)llGetSubString(choice, 0, llSubStringIndex(choice, ".") - 1);
            if (select != 0) choice = (string)outfitList[select - 1];
            // else we have a normal selection, not a numeric one

            debugSay(6, "DEBUG-DRESS", "Secondary outfits menu: choice = " + choice + "; select = " + (string)select);

            if (llGetSubString(choice, 0, 6) == "Outfits") {

                // Choice was one of:
                //
                // - Outfits Next
                // - Outfits Prev

                if (!isDresser(id)) {
                    outfitList = [];
                    return;
                }

                if (choice == "Outfits Next") {
#ifdef ROLLOVER
                    outfitPage++;
                    if ((outfitPage - 1) * OUTFIT_PAGE_SIZE > llGetListLength(outfitList))
                        outfitPage = 1;
#else
                    if (outfitPage * OUTFIT_PAGE_SIZE < llGetListLength(outfitList))
                        outfitPage++;
#endif
                }
                else if (choice == "Outfits Prev") {
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
                // going back to the Main menu or one directory up is appropriate
                //
                //backMenu = MAIN;
                //lmSendConfig("backMenu",(backMenu = MAIN));
                //dialogItems += "Back...";

                // We only get here if we are wandering about in the same directory...
                lmDialogListen();
                outfitHandle = cdListenAll(outfitChannel);
                // outfitMessage was built by the initial call to listener2666
                llDialog(dresserID, outfitMessage, dialogSort(outfitPageN(outfitList) + dialogItems), outfitChannel);
                llSetTimerEvent(60.0);

            }
            else if (choice == "Back...") {
                outfitList = [];
                lmMenuReply(backMenu, llGetDisplayName(id), id);

                // Reset to Main Menu
                //lmSendConfig("backMenu",(backMenu = MAIN));
            }
            else {
                if (cdListElementP(outfitList, choice) != NOT_FOUND) {
                    // This is the actual processing of an Outfit Menu entry -
                    // either a folder or a single outfit item.
                    //
                    // This could be entered via a menu injection by a random dress choice
                    // No standard user should be entering this way anyway
                    //if (!isDresser(id)) return;

                    outfitList = [];
                    string c = cdGetFirstChar(choice);

                    if (isTypeFolder(c) || isParentFolder(c)) {

                        // if a Folder was chosen, we have to descend into it by
                        // adding the choice to the currently active folder

                        if (clothingFolder == "") clothingFolder = choice;
                        else clothingFolder += ("/" + choice);

                        debugSay(6, "DEBUG-DRESS", "Generating new list of outfits...");
                        lmSendConfig("backMenu",(backMenu = UPMENU));
                        dressVia(menuDressChannel); // recursion: put up a new Primary menu

                        llSetTimerEvent(60.0);
                    }
                    else {
                        debugSay(3, "DEBUG-DRESS", "Calling wearOutfit with " + choice + " in the active folder " + activeFolder);
                        lmInternalCommand("wearOutfit", choice, NULL_KEY);
                    }
                }
#ifdef DEVELOPER_MODE
                else {
                    llSay(DEBUG_CHANNEL,"Received unknown outfit! (" + choice + ")");
                }
#endif
            }
        }

        //----------------------------------------
        // Channel: menuDressChannel
        //
        // Choosing a new outfit normally and manually: create a paged dialog with an
        // alphabetical list of available outfits, and let the user choose one
        //
        else if (channel == menuDressChannel) {

            // Choose an outfit
            //
            // This is the first menu presented upon the activation
            // of a new folder to choose outfits from.

            llListenRemove(menuDressHandle);

            if (choice == "") {

                // No outfits available in this directory
                lmDialogListen();
                cdListenAll(outfitChannel);

                backMenu = UPMENU;
                llDialog(dresserID, "No outfits to wear in this directory.", [ "Back..." ], outfitChannel);

                llSetTimerEvent(60.0);
                return;
            }

            outfitList = llParseString2List(choice, [","], []);

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

            // we've gone through and cleaned up the list - but is anything left?
            if (outfitList == []) {
                outfitList = []; // free memory
                lmDialogListen();
                cdListenAll(outfitChannel);

                backMenu = UPMENU;
                llDialog(dresserID, "No wearable outfits in this directory.", [ "Back..." ], outfitChannel);

                llSetTimerEvent(60.0);

                return;
            }

            // Sort: slow bubble sort
            outfitList = llListSort(outfitList, 1, TRUE);

            // Now create appropriate menu page from full outfits list
            outfitPage = 1;

            list newOutfitList = outfitPageN(outfitList);

            if (llGetListLength(outfitList) < 10) newOutfitList += [ "-", "-" ];
            else newOutfitList += [ "Outfits Prev", "Outfits Next" ];
            newOutfitList += [ "Back..." ];

            if (dresserID == dollID) outfitMessage = "You may choose any outfit to wear. See the help file for more detailed information on outfits.";
            else outfitMessage = "You may choose any outfit for dolly to wear. ";

            outfitMessage += "\n\n" + folderStatus();

            // Provide a dialog to user to choose new outfit
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
            newOutfitList = [];
        }
    }
}

//========== DRESS ==========
