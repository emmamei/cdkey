//========================================
// Dress.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 27 October 2014

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
#define dressViaMenu() listInventoryOn("2666")
#define dressViaRandom() listInventoryOn("2665")

//========================================
// VARIABLES
//========================================

//string bigsubfolder = "dressup"; //name of subfolder in RLV to always use if available. But also checks for outfits.

// FIXME: This should be in a notecard so it can be changed without mangling the scripts.
string outfitsURL = "outfits.htm";
string outfitsMessage;

string prefix;

integer tempDressingLock = FALSE;  // allow only one dressing going on at a time
integer canDressTimeout;
integer dressingSteps;             // are all attempts to dress complete?

//key setupID = NULL_KEY;

string newOutfitName;
string newOutfitFolder;
string newOutfitPath;

string oldOutfitName;
string oldOutfitFolder;
string oldOutfitPath;

// New simple listener setup we only
// listen to rlvChannel directly the
// other we use MenuHandlers link 500's
integer rlvBaseChannel;
integer outfitsChannel;
integer outfitsHandle;
integer change;
integer pushRandom;

#ifdef WEAR_AT_LOGIN
integer wearAtLogin;
#endif

// These are the paths of the outfits relative to #RLV
//string lastFolder;
string newOutfit;
string oldOutfit;
string xFolder;
string yFolder;

list outfitsList;
integer useTypeFolder;

string clothingFolder; // This contains clothing to be worn
string outfitsFolder;  // This contains folders of clothing to be worn
string activeFolder; // This is the lookup folder to search
string typeFolder; // This is the folder we want for our doll type
string normalselfFolder = "~normalself"; // This is the ~normalself we are using
string nudeFolder = "~nude"; // This is the ~nude we are using

integer randomDressHandle;
integer randomDressChannel;
integer menuDressHandle;
integer menuDressChannel;
integer listen_id_2668;
integer listen_id_2669;

//integer fallbackFolder;

//integer startup = 1;
integer dressingFailures;

integer outfitPage;

//string oldattachmentpoints;
//string oldclothespoints;
//integer newOutfitWordEnd;
integer outfitPageSize = 9;

//========================================
// FUNCTIONS
//========================================
list outfitsPage(list outfitList) {
    integer newOutfitCount = llGetListLength(outfitList) - 1;

    // GLOBAL: outfitPage

    // compute indexes
    integer currentIndex = outfitPage * outfitPageSize;
    integer endIndex = currentIndex + outfitPageSize - 1;

    // If reaching beyond the end...
    if (currentIndex > newOutfitCount) {
        // Wrap to start...
        outfitPage = 0;
        currentIndex = 0;

        // Halt at end
        //outfitPage--;
        //currentIndex = outfitPage * outfitPageSize;
    }
    // If reaching beyond the beginning...
    else if (currentIndex < 0) {
        // Wrap to end
        currentIndex = newOutfitCount % outfitPageSize;
        outfitPage = currentIndex % outfitPageSize;

        // Halt at start
        //outfitPage = 0;
        //currentIndex = 0;
    }

    if (endIndex > newOutfitCount) {
        endIndex = newOutfitCount;
    }

    // Print the page contents - note that this happens even before
    // any dialog is put up
    list pageOutfits = llList2List(outfitsList, currentIndex, endIndex);
    integer n = currentIndex; string chat; list output;
    string itemName;

    while (n++ <= endIndex) {
        itemName = (string)(n) + ". " + cdListElement(outfitsList, n - 1);
        chat += "\n" + itemName;
        output += [ llGetSubString(itemName, 0, 23) ];
    }

    llRegionSayTo(dresserID, 0, chat);

    return output;
}

// Set the folder to use for clothing attach and detach
// Should be current clothing folder

setActiveFolder() {

    // activeFolder is the folder (full path) we are looking at with our Menu
    // outfitsFolder is where all outfits are stored, including
    //     ~normalself, ~nude, and all the type folders
    // clothingFolder is the current folder for clothing, relative
    //     to the outfitsFolder

    // set activeFolder
    if (clothingFolder == "") activeFolder = outfitsFolder;
    else activeFolder = outfitsFolder + "/" + clothingFolder;

    lmSendConfig("activeFolder", activeFolder);
}

rlvRequest(string rlv, integer channel) {
    canDressTimeout = 1;

         if (channel == 2665) randomDressHandle = cdListenMine(randomDressChannel);
    else if (channel == 2666)   menuDressHandle = cdListenMine(menuDressChannel);
    else if (channel == 2668)    listen_id_2668 = cdListenMine(rlvBaseChannel + 2668);
    else if (channel == 2669)    listen_id_2669 = cdListenMine(rlvBaseChannel + 2669);

    lmRunRLV(rlv + (string)(rlvBaseChannel + channel));
    llSetTimerEvent(30.0);
}

listInventoryOn(string channel) {

    setActiveFolder();
#ifdef DEVELOPER_MODE
    doDebug(channel);
#endif

    if (outfitsFolder == "") {
        llOwnerSay("No suitable outfits folder found, so unfortunately you will not be able to be dressed");
    }
    else {
        setActiveFolder();
        rlvRequest("getinv:" + activeFolder + "=", (integer)channel);
    }
}

integer isDresser(key id) {
    if (dresserID == NULL_KEY) {
        // check if id is something other than an avatar: and fake up TRUE val if so
        if (llGetAgentSize(id) == ZERO_VECTOR) return TRUE;

        dresserID = id;
        dresserName = llGetDisplayName(dresserID);
        //debugSay(4, "DEBUG-DRESS", "looking at dress menu: " + (string)dresserID);

        if (!cdIsDoll(dresserID))
            llOwnerSay("secondlife:///app/agent/" + (string)dresserID + "/about is looking at your dress menu");
    }
    else if (dresserID != id) {
        lmSendToAgent("You look in Dolly's closet for clothes, and notice that " + dresserName + " is already there looking", id);
        return FALSE;
    }

    return TRUE;
}

changeComplete(integer success) {
    // And remove the temp locks we used
    // RLV.lsl knows which are ours and that is all this clears
#ifdef DEVELOPER_MODE
    llOwnerSay("Your key is now unlocked again as you are a developer.");
    lmRunRLV("clear");
#else
    // if we used "detach" then the Key would be unlocked
    lmRunRLV("clear=attach,clear=detachall");
#endif

    if (success) {
        if (change) lmSendToAgentPlusDoll("Change to new outfit " + newOutfitName + " complete.", dresserID);

        // Note: if wearLock is already set, it STAYS set with this setting
        //
        // This triggers Main and sets wearLockExpire
        //
        // This setting is thus: if dresser is anyone except Dolly, wearLock is set.
        // If wearLock is already set, it stays set..
        wearLock = (wearLock || ((dresserID != NULL_KEY) && (dresserID != dollID)));
    }
    else {
        if (dressingFailures > MAX_DRESS_FAILURES)
            llOwnerSay("Too many dressing failures.");

        if (canDressTimeout)
            llSay(DEBUG_CHANNEL,"Dressing sequence (with outfit " + newOutfitName + ") timed out.");

        lmSendToAgentPlusDoll("Change to new outfit " + newOutfitName + " unsuccessful.", dresserID);
        wearLock = 0;
    }

    lmSetConfig("wearLock", (string)wearLock);

    canDressTimeout = 0;
    change = 0;

    tempDressingLock = FALSE;
    llSetTimerEvent(0.0);

    dresserID = NULL_KEY;
}

#ifdef DEVELOPER_MODE
doDebug(string src) {
    //integer level = 5;
    //if (startup != 0) level = 6;

    string exists = "not found";
    if (useTypeFolder) exists = "found";

    //debugSay(5, "DEBUG-DRESS", ">  on " + src);
    //debugSay(5, "DEBUG-DRESS", ">> outfitsFolder = " + outfitsFolder);
    //debugSay(5, "DEBUG-DRESS", ">> clothingFolder = " + clothingFolder);
    //debugSay(5, "DEBUG-DRESS", ">> typeFolder = " + typeFolder + " (" + exists + ")");

    //setActiveFolder();

    //debugSay(5, "DEBUG-DRESS", ">> activeFolder = " + activeFolder);
    //debugSay(5, "DEBUG-DRESS", ">> normalselfFolder = " + normalselfFolder);
    //debugSay(5, "DEBUG-DRESS", ">> nudeFolder = " + nudeFolder);
}

string folderStatus() {
    string typeFolderExists;

    if (useTypeFolder) typeFolderExists = typeFolder + " (being used)";
    else typeFolderExists = typeFolder + " (not being used)";

    if (typeFolder == "") typeFolderExists = "";

    return "Outfits Folder: " + outfitsFolder +
           "\nCurrent Folder: " + activeFolder +
           "\nType Folder: " + typeFolderExists +
           "\nUse ~normalself: " + normalselfFolder +
           "\nUse ~nude: " + nudeFolder;
}
#else
string folderStatus() {
    string typeFolderExists;

    if (useTypeFolder) typeFolderExists = typeFolder;
    else typeFolderExists = typeFolder + " (not found)";

    if (typeFolder == "") typeFolderExists = "n/a";

    return "Outfits Folder: " + outfitsFolder +
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

        cdInitializeSeq();
    }


    //----------------------------------------
    // ON_REZ
    //----------------------------------------
    on_rez(integer start) {
        ; //startup = 2;
    }


    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {
        if (canDressTimeout) {

            llListenRemove(randomDressHandle);
            llListenRemove(menuDressHandle);
            llListenRemove(listen_id_2668);
            llListenRemove(listen_id_2669);

            changeComplete(FALSE);
            canDressTimeout = 0;
        }
    }

    //----------------------------------------
    // LINK_MESSAGE
    //----------------------------------------
    link_message(integer source, integer i, string data, key id) {

        // Parse link message header information
        split             =     cdSplitArgs(data);
        script            =     cdListElement(split, 0);
        remoteSeq         =     (i & 0xFFFF0000) >> 16;
        optHeader         =     (i & 0x00000C00) >> 10;
        code              =      i & 0x000003FF;
        split             =     llDeleteSubList(split, 0, 0 + optHeader);

        scaleMem();

        if (code == CONFIG) {
            string name = cdListElement(split, 0);
            string value = cdListElement(split, 1);
            string c = cdGetFirstChar(name);

            //if (value == RECORD_DELETE) {
            //    value = "";
            //    split = [];
            //}

            if (name == "dialogChannel") {
                dialogChannel = (integer)value;
                rlvBaseChannel = dialogChannel ^ 0x80000000; // Xor with the sign bit forcing the positive channel needed by RLV spec.
                outfitsChannel = dialogChannel + 15; // arbitrary offset

                randomDressChannel = rlvBaseChannel + 2665;
                  menuDressChannel = rlvBaseChannel + 2666;
            }
            else if (name == "afk")                                  afk = (integer)value;
            else if (name == "pronounHerDoll")            pronounHerDoll = value;
            else if (name == "pronounSheDoll")            pronounSheDoll = value;
            else if (c == "c") {
                     if (name == "canDressSelf")                canDressSelf = (integer)value;
                else if (name == "collapsed")                      collapsed = (integer)value;
                else if (name == "clothingFolder")            clothingFolder = value;
            }

#ifdef DEVELOPER_MODE
            else if (name == "debugLevel")                        debugLevel = (integer)value;
#endif
            else if (c == "n") {
                     if (name == "normalselfFolder")        normalselfFolder = value;
                else if (name == "nudeFolder")                    nudeFolder = value;
//              else if (name == "newOutfitName")              newOutfitName = value;
//              else if (name == "newOutfitFolder")          newOutfitFolder = value;
//              else if (name == "newOutfitPath")              newOutfitPath = value;
//              else if (name == "newOutfit")                      newOutfit = value;
            }

            else if (c == "o") {
                     if (name == "outfitsFolder")              outfitsFolder = value;
                else if (name == "oldOutfitFolder")          oldOutfitFolder = value;
                else if (name == "oldOutfitPath")              oldOutfitPath = value;
                else if (name == "oldOutfitName")              oldOutfitName = value;
                else if (name == "oldOutfit")                      oldOutfit = value;
            }

            else if (name == "typeFolder")                    typeFolder = value;
            else if (name == "useTypeFolder")              useTypeFolder = (integer)value;
            else if (name == "wearLock")                        wearLock = (integer)value;
        }
        else if (code == INTERNAL_CMD) {
            string cmd = cdListElement(split, 0);

            // Choose an (appropriate) random outfit and put it on
            //
            if (cmd == "randomDress") {
                // this makes it easier, and we don't have to be "afraid" to call the
                // randomDress function.
                if (!RLVok) return;

#ifdef DEVELOPER_MODE
                debugSay(6, "DEBUG-DRESS", "Random dress outfit chosen automatically");
#endif
                if (tempDressingLock) {
                    llRegionSayTo(dresserID, 0, "Dolly cannot be dressed right now; " + pronounSheDoll + " is already dressing");
                }
                else {
                    if (useTypeFolder) clothingFolder = typeFolder;
                    else clothingFolder = "";

                    lmSendConfig("clothingFolder", clothingFolder);
#ifdef DEVELOPER_MODE
                    //debugSay(6, "DEBUG-DRESS", "clothingFolder = " + clothingFolder);
                    //debugSay(6, "DEBUG-DRESS", "listing inventory on 2665...");
#endif
                    dressViaRandom();
                }
            }
        }
        else if (code == RLV_RESET) {
            RLVok = (cdListIntegerElement(split, 0) == 1);
        }
        // Choice #500: (From Main Menu) Dress Dolly
        else if (code == MENU_SELECTION)  {
            string choice = cdListElement(split, 0);
            string name = cdListElement(split, 1);

            debugSay(6, "DEBUG-DRESS", "Menu Selection: " + choice + ": tempDressingLock = " + (string)tempDressingLock);

            if (choice == "Outfits..." && !tempDressingLock) {
                if (id) {
                    if (!isDresser(id)) return;
                }

                if (wearLock) {
                    cdDialogListen();
                    llDialog(dresserID, "Clothing was just changed; cannot change right now.", ["OK"], dialogChannel);
                    return;
                }

                if (outfitsFolder != "") {
                    if (useTypeFolder) clothingFolder = typeFolder;
                    else clothingFolder = "";

                    lmSendConfig("clothingFolder", clothingFolder);
                    dressViaMenu();
                }
                else {
                    cdDialogListen();
                    llDialog(dresserID, "You look in " + llToLower(pronounHerDoll) + " closet, and see no outfits for Dolly to wear.", ["OK"], dialogChannel);
                    return;
                }
            }
        }
        else if (code < 200) {
            if (code == 102) {
                ;
            }

            // else if (code == 104) {
            //     if (script != "Start") return;
            //     startup = 1;
            // }
            // else if (code == 105) {
            //     if (script != "Start") return;
            //     startup = 2;
            // }
            // else if (code == 110) {
            //     initState = 105;
            // }

            else if (code == 135) {
                memReport(cdMyScriptName(),cdListFloatElement(split, 0));
            }
            else if (code == 142) {

                cdConfigureReport();

            }
            else if (code == 150) {
                simRating = cdListElement(split, 0);
                integer outfitRating = cdOutfitRating(newOutfitName);
                integer regionRating = cdRating2Integer(simRating);

                debugSay(3, "DEBUG-DRESS", "Region rating " + llToLower(simRating) + " outfit " + newOutfitName + " outfitRating: " + (string)outfitRating +
                            " regionRating: " + (string)regionRating);

                if (RLVok) {
                    if (outfitRating > regionRating) {
                        pushRandom = 1;
                        clothingFolder = newOutfitPath;
                        dressViaRandom();
                    }
                }
            }
        }
    }

// First, all clothes are taken off except for skull and anything that might be revealing.
//
// Then the new outfit is put on. It uses replace, so it should take off any old clothes.
//
// Then there is an 8 second wait and then the new outfit is put on again! In case something
// was locked. This I think explains the double put-on.
//
// Then the places are checked where there could be old clothes still on. If anything is there,
// according to whatever is returned, the id is checked and it is taken off if they are old.
//
// This last step takes off all the clothes that weren't replaced.

// There is one place where the old outfit is removed.

    //----------------------------------------
    // LISTEN
    //----------------------------------------
    listen(integer channel, string name, key id, string choice) {
        // We have our answer so now we can turn the listener off until our next request

        //debugSay(6, "DEBUG-DRESS", "Channel: " + (string)channel + "\n" + choice);

        // Request max memory to avoid constant having to bump things up and down
        llSetMemoryLimit(65536);

        if (channel == outfitsChannel) {
            // The first menu is generated by listener2666 (randome outfits
            // are done by listener2665); we get here after the first menu
            // sends back a response.
            //
            // We just got a selected Outfit or new folder to go into

            //outfitsMessage = "You may choose any outfit for " + llToLower(pronounHerDoll) + " to wear. ";
            //if (dresserID == dollID) outfitsMessage += "See " + WEB_DOMAIN + outfitsURL + " for more information on outfits. ";
            //outfitsMessage += "\n\n" + folderStatus();

            // Build outfit menu: note it is using the number before the period here
            integer select = (integer)llGetSubString(choice, 0, llSubStringIndex(choice, ".") - 1);
            if (select != 0) choice = cdListElement(outfitsList, select - 1);
            // if (select == 0) then what?
            debugSay(6, "DEBUG-DRESS", "Secondary outfits menu: choice = " + choice + "; select = " + (string)select);

            if (llGetSubString(choice, 0, 6) == "Outfits") {
                // Choice was one of:
                //
                // Outfits Next
                // Outfits Prev
                // Outfits Parent

                if (!isDresser(id)) return;

                if (choice == "Outfits Next") {
                    //debugSay(6, "DEBUG-DRESS", ">>> Dress Menu: " + choice);
                    outfitPage++;

                }
                else if (choice == "Outfits Prev") {
                    //debugSay(6, "DEBUG-DRESS", ">>> Dress Menu: " + choice);
                    outfitPage--;

                }
#ifdef PARENT
                else if ("Outfits Parent") {
                    //debugSay(6, "DEBUG-DRESS", ">>> Dress Menu: " + choice);

                    // Strip off the end of clothingFolder and update everyone
                    //
                    // This is complicated because there is no "search from end" function
                    // in LSL. So we hack it.
                    list pathParts = llParseString2List(clothingFolder, [ "/" ], []);

                    if (llGetListLength(pathParts) > 1)
                        clothingFolder = llDumpList2String(llList2List(pathParts, 0, -2), "/");
                    else
                        clothingFolder = "";

                    lmSendConfig("clothingFolder", clothingFolder);

#ifdef DEVELOPER_MODE
                    setActiveFolder();
                    debugSay(6, "DEBUG-DRESS", "Moving up to the " + activeFolder + " folder.");
#endif
                    dressViaMenu();
                    return;
                }

                string UpMain = "Outfits Parent";
#endif
                list dialogItems = [ "Outfits Prev", "Outfits Next" ];
#ifdef PARENT
                if (clothingFolder != "")
                    dialogItems += "Outfits Parent";
#endif
                backMenu = MAIN;
                dialogItems += "Back...";

                // We only get here if we are wandering about in the same directory...
                cdDialogListen();
                outfitsHandle = cdListenMine(outfitsChannel);
                // outfitsMessage was built by the initial call to listener2666
                debugSay(6, "DEBUG-DRESS", "Secondary outfits menu invoked.");
                llDialog(dresserID, outfitsMessage, dialogSort(outfitsPage(outfitsList) + dialogItems), outfitsChannel);
                llSetTimerEvent(60.0);

            }
            else if (choice == "Back...") {
                lmMenuReply(backMenu, llGetDisplayName(id), id);
                lmSendConfig("backMenu",(backMenu = MAIN));
            }
            else if (choice == MAIN) {
                lmMenuReply(MAIN,"",id);
            }
            else if (cdListElementP(outfitsList, choice) != NOT_FOUND) {
                // This is the actual processing of an Outfit Menu entry -
                // either a folder or a single outfit item.
                //
                // This could be entered via a menu injection by a random dress choice
                // No standard user should be entering this way anyway
                //if (!isDresser(id)) return;

                debugSay(6, "DEBUG-DRESS", "choice = " + choice + "; isParent = " + (string)(isParentFolder(cdGetFirstChar(choice))));
                if (isParentFolder(cdGetFirstChar(choice))) {

                    // if a Folder was chosen, we have to descend into it by
                    // adding the choice to the currently active folder

                    if (clothingFolder == "") clothingFolder = choice;
                    else clothingFolder += ("/" + choice);

                    lmSendConfig("clothingFolder", clothingFolder);
                    dressViaMenu(); // recursion: put up a new Primary menu

                    llSetTimerEvent(60.0);
                    return;
                }
                else if ((outfitsFolder != "") && (choice != newOutfitName)) {
#ifdef DEVELOPER_MODE
                    // If we are in developer mode we are in danger of the key being ripped
                    // off here.  We therefore will use a temporary @detach=n restriction.
                    llOwnerSay("Developer key locked in place to prevent accidental detachment during dressing.");
                    lmRunRLV("attachthis=y,detachthis=n,detach=n,touchall=n,showinv=n");

#else
                    // This locks down a (Normal) Dolly's touch and inventory - but
                    // there is no restore from this setting
//                  lmRunRLV("touchall=n,showinv=n");
#endif
                    tempDressingLock = TRUE;

                    // dressingSteps is used to track whether all listener code paths
                    // for dressing have been done: that is, normalself attached,
                    // new outfit attached, and old outfit removed. (It does NOT include
                    // nude folder.)
                    dressingSteps = 0;

                    dressingFailures = 0;
                    change = 1;

                    // Send a message to ourself, generate an event, and save the
                    // previous values of newOutfit* into oldOutfit* - can we do
                    // this without using a link message?
                    //
                    // *OutfitName       choice           - name of outfit
                    // *OutfitFolder     outfitsFolder    - name of main outfits folder
                    // *OutfitPath       clothingFolder   - name of folder with outfit, relative to outfitsFolder
                    // *Outfit           -new-            - full path of outfit (outfitsFolder + "/" + clothingFolder + "/" + choice)

                    lmSendConfig("oldOutfitName",   (  oldOutfitName = newOutfitName));
                    lmSendConfig("oldOutfitFolder", (oldOutfitFolder = newOutfitFolder));
                    lmSendConfig("oldOutfitPath",   (  oldOutfitPath = newOutfitPath));
                    lmSendConfig("oldOutfit",       (      oldOutfit = newOutfit));

                    // Build the newOutfit* variables - but do they get used?

                      newOutfitName = choice;
                    newOutfitFolder = outfitsFolder;
                      newOutfitPath = clothingFolder;

                    newOutfit = newOutfitFolder + "/";
                    if (clothingFolder != "")
                        newOutfit += clothingFolder + "/";
                    newOutfit += newOutfitName;

//                  lmSendConfig("newOutfitName",   (newOutfitName));
//                  lmSendConfig("newOutfitFolder", (newOutfitFolder));
//                  lmSendConfig("newOutfitPath",   (newOutfitPath));
//                  lmSendConfig("newOutfit",       (newOutfit));
                }

                //newOutfitWordEnd = llStringLength(newOutfit)  - 1;

                //llOwnerSay("newOutfit is: " + newOutfit);
                //llOwnerSay("newOutfitName is: " + newOutfitName);
                //llOwnerSay("choice is: " + choice);
                //llOwnerSay("clothingFolder is: " + clothingFolder);

                // Four steps to dressing avi:
                //
                // 1) Replace every item that can be replaced (using the
                //    command @attachall)
                // 2) Add every item that didnt get put on the first time
                //    (using the @attachallover command)
                // 3) Remove the remaining portions of the old outfit
                // 4) Add items that are required for all outfits
                //    (using the @attach command)

                llOwnerSay("New outfit chosen: " + newOutfitName);

                // Get the path of whatever outfit is being worn, and save
                // it for later to be able to remove an outfit - not just
                // one we know about
                //
                // Go through a litany of clothing, in order to find the path
                // to the clothing worn. If there is no clothing on these points
                // for this outift, then this does not work.
                //
                // This also assumes that a complete outfit is being used,
                // and that all parts are contained in a single folder.
                // This also assumes that the new outfit does not also
                // exist in this folder - such as one outfit using certain
                // items and another outfit using other items - such as
                // one outfit using a miniskirt and one a long dress.

                // Original outfit was a complete avi reset....
                // Restore our usual look from the ~normalself
                // folder...

                // This attaches ~normalself and locks it
                lmRunRLV("attachallover:" + normalselfFolder + "=force,detachallthis:" + normalselfFolder + "=n");

                if (nudeFolder != "") {
                    // this attaches the ~nude folder
                    lmRunRLV("attachallover:" + nudeFolder + "=force,detachallthis:" + nudeFolder + "=n");
                }
                    
                // attach the new folder and lock it down - and prevent nude
                lmRunRLV("attachallover:" + newOutfit + "=force,detachallthis:" + newOutfit + "=n");
                llSleep(2.0);

                // At this point, all of ~normalself, ~nude, and newOutfit have been added and locked
                // We should be fully clothed and set with every thing we need - BUT we have to
                // remove the old...

                // Remove rest of old outfit (using saved path)
                if (oldOutfitPath != "") {
                    lmRunRLV("detachall:" + oldOutfitPath + "=force");
                    oldOutfitPath = "";
                }

                // Now remove everything in the outfits folder (typeically "> Outfits") except
                // that which is locked down - and then attach everything in the new outfit
                // again
                lmRunRLV("detachall:" + outfitsFolder + "=force");
                lmRunRLV("attachall:" + newOutfit + "=force");
                llSleep(2.0);

                // And now send an attempt to clean up any remaining stray pieces: remove rest of
                // clothing not otherwise locked
                string parts = "gloves|jacket|pants|shirt|shoes|skirt|socks|underpants|undershirt|alpha|pelvis|left foot|right foot|r lower leg|l lower leg|r forearm|l forearm|r upper arm|l upper arm|r upper leg|l upper leg";
                lmRunRLV("detachallthis:" + llDumpList2String(llParseString2List(parts, [ "|" ], []), "=force,detachallthis:") + "=force");

                // check to see that everything in the ~normalself folder is
                // actually worn
                xFolder = normalselfFolder;
                rlvRequest("getinvworn:" + xFolder + "=", 2668);

                // check to see that everything in the old Outfit folder is
                // actually removed
                yFolder = oldOutfitPath;
                if (yFolder != "") rlvRequest("getinvworn:" + yFolder + "=", 2669);

                llSetTimerEvent(15.0);
            }
        }

        // channels:
        //
        // 2665: choose outfit at Random
        // 2666: choose outfit Manually (by user)
        // 2668:
        // 2669:

        //----------------------------------------
        // Channel: 2665
        //
        // Switched doll types: grab a new (appropriate) outfit at random and change to it
        //
        else if (channel == randomDressChannel) { // list of inventory items from the current prefix

            llListenRemove(randomDressHandle);
            outfitsList = llParseString2List(choice, [","], []);
            debugSay(6, "DEBUG-CLOTHING", "Choosing random outfit (from: " + choice + ")");

            integer n;

            // May never occur: other directories, hidden directories and files,
            // and hidden UNIX files all take up space here.

            if (outfitsList == []) {   // folder is bereft of files, switching to regular folder

                // No files found; leave the prefix alone and don't change
                llOwnerSay("There are no outfits in your " + activeFolder + " folder.");

                // Didnt find any outfits in the standard folder, try the
                // "extended" folder containing (we hope) outfits....

                if (outfitsFolder != "" && clothingFolder != "") {

                    // Go up one folder: this assumes there is a valid folder to go up to
                    list pathParts = llParseString2List(clothingFolder, [ "/" ], []);
                    clothingFolder = llDumpList2String(llList2List(pathParts, 0, -2), "/");
                    lmSendConfig("clothingFolder", clothingFolder);
                    return;
                }
            }
            else {
                // Outfits (theoretically) found: change to one

                string itemName;
                string prefix;
                integer total;
                integer simrating = cdRating2Integer(simRating);
                list tmpList;

                // Filter directory contents
                //
                // Rule out the following:
                //     ~item - Hidden item (including ~nude and ~normalself)
                //     *item - Clothing for transformed doll of a particular type
                //     #item - Group items
                //     {x}item - Rated item: filter by rating
                //
                n = llGetListLength(outfitsList);
                debugSay(6, "DEBUG-CLOTHING", "Length of parsed outfits list is " + (string)n);
                while (n--) {
                    itemName = cdListElement(outfitsList, n);
                    prefix = llGetSubString(itemName,0,0);
                    debugSay(6, "DEBUG-CLOTHING", "Checking prefix #" + (string)n + ": " + prefix + " with " + itemName);

                    // skip hidden files/directories and skip
                    // Doll Type (Transformation) folders...
                    //
                    // Note this skips *Regular too
                    //
                    // This (sort of) odd sequence imposes short-cut operations

                    if (!isHiddenItem(prefix)) {            // ~foo
                        if (!isTransformingItem(prefix)) { // *foo
                            if (!isGroupItem(prefix)) {    // #foo
                                if (isRated(prefix)) {     // {x}foo -- this test avoids function call
                                    if (!(cdOutfitRating(itemName) > simrating)) {
                                        tmpList += itemName;
                                    }
                                }
                                else {
                                    tmpList += itemName;
                                }
                            }
                        }
                    }
                }

                outfitsList = tmpList;
                tmpList = []; // free memory
                debugSay(6, "DEBUG-CLOTHING", "Outfit list selected and filtered...");
                debugSay(6, "DEBUG-CLOTHING", "Outfits List: " + llDumpList2String(outfitsList, ",") + " (" + (string)llGetListLength(outfitsList) + ")");

                // check the filtered list...
                if (outfitsList == []) {
                    // Nothing received (total == 0); try another
                    // folder, if any; note that the total includes
                    // "marked" folders (with ">") as well as "normal"
                    // folders (containing clothing)

                    if (pushRandom && clothingFolder != "") {

                        list pathParts = llParseString2List(clothingFolder, [ "/" ], []);

                        // This sequence takes the clothingFolder, and "goes up" one level
                        clothingFolder = llDumpList2String(llDeleteSubList(pathParts, -1, -1), "/");
                        lmSendConfig("clothingFolder", clothingFolder);
                        setActiveFolder();

                        debugSay(6, "DEBUG-DRESS", "Trying the " + activeFolder + " folder.");

                        dressViaRandom(); // recursion
                    }
                    else pushRandom = 0;
                    return;
                }

                //if (outfitsList == []) {
                //    debugSay(6, "DEBUG-CLOTHING","No outfits found!");
                //    llOwnerSay("There are no outfits in your closet to wear! Time to go shopping!");
                //    return;
                //}

                // Pick outfit (or directory) at random
                string nextOutfitName;

                nextOutfitName = cdListElement(outfitsList, (integer)llFrand(total));

                debugSay(5,"DEBUG-CLOTHING","Chosen item (outfit?): " + nextOutfitName);
                //debugSay(5,"DEBUG-CLOTHING","Outfits to choose from randomly: " + llDumpList2String(outfitsList, ","));

                // Folders are NOT filtered out; this is so we can descend into sub-directories
                // and select items within them. Directories are marked with an initial ">" character
                if (llGetSubString(nextOutfitName, 0, 0) != ">") {

                    // The (randomly) chosen outfit is pushed as a menu reply
                    //lmMenuReply(nextOutfitName, llGetObjectName(), llGetKey());
                    outfitsHandle = cdListenMine(outfitsChannel);
                    llSay(outfitsChannel,nextOutfitName);
                    llOwnerSay("You are being dressed in this outfit: " + nextOutfitName);
                }
                else {
                    clothingFolder += "/" + nextOutfitName;
                    dressViaRandom(); // recursion
                }

                pushRandom = 0;
            }
        }

        //----------------------------------------
        // Channel: 2666
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

            // Did we get anything at all?
            if (choice == "") {
                cdDialogListen();
                llDialog(dresserID, "You gaze into " + llToLower(pronounHerDoll) + " closet, and see no outfits for Dolly to wear.", ["OK"], dialogChannel);
                return;
            }

            //fallbackFolder = 0;
            outfitsList = llParseString2List(choice, [","], []);

            integer n;
            string itemName;
            string prefix;
            list tmpList;

            // Filter list of outfits (directories) to choose
            n = llGetListLength(outfitsList);
            while (n--) {
                itemName = cdListElement(outfitsList, n);
                prefix = cdGetFirstChar(itemName);

                if (itemName != newOutfitName) {
                    if (!isHiddenItem(prefix) &&
                        !isGroupItem(prefix) &&
                        !isTransformingItem(prefix)) {

                        if (isRated(prefix)) {
                            if (cdOutfitRating(itemName) <= cdRating2Integer(simRating)) {
                                tmpList += itemName;
                            }
                        }
                        else {
                            tmpList += itemName;
                        }
                    }
                }
            }

            outfitsList = tmpList;

            // we've gone through and cleaned up the list - but is anything left?
            if (outfitsList == []) {
                cdDialogListen();
                llDialog(dresserID, "You look in " + llToLower(pronounHerDoll) + " closet, and see nothing for Dolly to wear.", ["OK"], dialogChannel);
                return;
            }
#ifdef PARENT
            // This looks like a complete bug but just comment it out for now
            else {
                if (clothingFolder != "") {
                    list pathParts = llParseString2List(clothingFolder, [ "/" ], []);

                    clothingFolder = llDumpList2String(llDeleteSubList(pathParts, -1, -1), "/");
                    lmSendConfig("clothingFolder", clothingFolder);
                    setActiveFolder();

                    debugSay(5,"DEBUG-CLOTHING","Trying the " + activeFolder + " folder.");

                    dressViaRandom(); // recursion
                    return;
                }
            }
#endif
            // Sort: slow bubble sort
            outfitsList = llListSort(outfitsList, 1, TRUE);

            // Now create appropriate menu page from full outfits list
            integer total = 0;
            outfitPage = 0;

            list newOutfitsList = outfitsPage(outfitsList);

            if (llGetListLength(outfitsList) < 10) newOutfitsList += [ "-", "-" ];
            else newOutfitsList += [ "Outfits Prev", "Outfits Next" ];
            newOutfitsList += [ "Back..." ];

            outfitsMessage = "You may choose any outfit for dolly to wear. ";
            if (dresserID == dollID) outfitsMessage = "See " + WEB_DOMAIN + outfitsURL + " for more detailed information on outfits. ";
            outfitsMessage += "\n\n" + folderStatus();

            // Build outfit menu
            integer select = (integer)llGetSubString(choice, 0, llSubStringIndex(choice, ".") - 1);
            if (select != 0) choice = cdListElement(outfitsList, select - 1);

#ifdef NO_PAGER
            if (llGetSubString(choice, 0, 6) == "Outfits") {
                // Choice was one of:
                //
                // Outfits Next
                // Outfits Prev
                // Outfits Parent

                if (id) {
                    if (!isDresser(id)) return;
                }

                if (choice == "Outfits Next") {
                    outfitPage++;

                }
                else if (choice == "Outfits Prev") {
                    outfitPage--;

                }
#ifdef PARENT
                else if ("Outfits Parent") {

                    if (clothingFolder != "") { // Return to the parent folder
                        list pathParts = llParseString2List(clothingFolder, [ "/" ], []);

                        clothingFolder = llDumpList2String(llDeleteSubList(pathParts, -1, -1), "/");
                        lmSendConfig("clothingFolder", clothingFolder);
                        setActiveFolder();

                        debugSay(6, "DEBUG-DRESS", "Trying the " + activeFolder + " folder.");

                        dressViaMenu();
                        return;
                    }
                    else {
                        lmMenuReply(MAIN, name, id); // No parent folder to return to, go to main menu instead
                    }
                }
#endif
            }
#endif

#ifdef PARENT
            string UpMain = "Outfits Parent";
#endif
            // Provide a dialog to user to choose new outfit
            debugSay(3, "DEBUG-CLOTHING", "Putting up Primary Menu in new directory");
            cdListenMine(outfitsChannel);
            lmSendConfig("backMenu",(backMenu = MAIN));
            llDialog(dresserID, outfitsMessage, dialogSort(newOutfitsList), outfitsChannel);
            canDressTimeout = 1;
            llSetTimerEvent(60.0);
        }

        //----------------------------------------
        // Channel: 2668
        //
        // Check to see if all items are fully worn; if not, try again
        //
        else if (channel == (rlvBaseChannel + 2668)) {

            llListenRemove(listen_id_2668);

            debugSay(6, "DEBUG", ">> @getinvworn:" + xFolder);
            debugSay(6, "DEBUG", ">>> " + choice);

            string c1 = llGetSubString(choice,1,1);
            string c2 = llGetSubString(choice,2,2);

            if (((c1 != "0" && c1 != "3") ||
                 (c2 != "0" && c2 != "3")) &&
                ++dressingFailures <= MAX_DRESS_FAILURES) {

                // Try to attach again
                string rlvCmd = "detachallthis:" + outfitsFolder + "=n,attachallover:" + xFolder + "=force";
                if (!canDressSelf || afk || collapsed || wearLock) rlvCmd = "attachallthis:=y," + rlvCmd + ",attachallthis:=n";
                lmRunRLV(rlvCmd);

                rlvRequest("getinvworn:" + xFolder + "=", 2668);
                canDressTimeout++;
            }
            else if (dressingFailures > MAX_DRESS_FAILURES) {
                llSay(DEBUG_CHANNEL,"Some things in " + xFolder + " failed to attach");
                changeComplete(FALSE);
            }
            else {
                // Everything was attached successfully...
                dressingSteps++;

                // If we just attached all our normalself, then attach all of our
                // new outfit
                if (xFolder == normalselfFolder && newOutfitPath != "") xFolder = newOutfit;
                else xFolder = "";

                // Do the new outfit folder (with full path)
                if (xFolder != "") rlvRequest("getinvworn:" + xFolder + "=", 2668);
                else if (dressingSteps >= 3) changeComplete(TRUE);
            }
            debugSay(6, "DEBUG", "canDressTimeout = " + (string)canDressTimeout + ", dressingSteps = " + (string)dressingSteps);
        }

        //----------------------------------------
        // Channel: 2669
        //
        // Check to see if all items are fully removed; if not, try again
        //
        else if (channel == (rlvBaseChannel + 2669)) {
            string c1 = llGetSubString(choice,1,1);
            string c2 = llGetSubString(choice,2,2);

            llListenRemove(listen_id_2669);

            debugSay(6, "DEBUG", ">> @getinvworn:" + yFolder);
            debugSay(6, "DEBUG", ">>> " + choice);

            // @getinv worn returns a coded message: test to see that
            // nothing in the folder or any subfolders is being worn:
            // that is, ALL have been removed...

            if (((c1 != "0" && c1 != "1") ||
                 (c2 != "0" && c2 != "1")) &&
                ++dressingFailures <= MAX_DRESS_FAILURES) {

                string rlvCmd = "attachallthis:" + outfitsFolder + "=n,detachall:" + yFolder + "=force";
                // Try again: attach stuff in the outfitsFolder, and remove things in yFolder
                if (!canDressSelf || afk || collapsed || wearLock) rlvCmd = "detachallthis:=y," + rlvCmd + "detachallthis:=n";
                lmRunRLV(rlvCmd);

                rlvRequest("getinvworn:" + yFolder + "=", 2669);
                canDressTimeout++;
            }
            else if (dressingFailures > MAX_DRESS_FAILURES) {
                llSay(DEBUG_CHANNEL,"Some things in " + yFolder + " failed to remove");
                changeComplete(FALSE);
            }
            else {
                // all items successfully removed
                dressingSteps++;
                if (dressingSteps >= 3) changeComplete(TRUE);
            }

            debugSay(6, "DEBUG", "canDressTimeout = " + (string)canDressTimeout + ", dressingSteps = " + (string)dressingSteps);
        }

        scaleMem();
    }
}

//========== DRESS ==========
