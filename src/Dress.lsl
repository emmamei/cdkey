//========================================
// Dress.lsl
//========================================
//
// vim:sw=4 et nowrap filetype=lsl
//
// DATE: 27 October 2014

// HISTORY:
//   Oct. 1   Adds everything in ~normalself folder, if oldoutfit begins with a +.
//            Adds channel dialog or id to screen listen
//   Nov. 17  moves listen to cd2667 so it gets turned off
//   Nov. 25  puts in dress menu
//   Aug 1    redoes closing

#include "include/GlobalDefines.lsl"

#define NO_FILTER ""
#define cdListenMine(a) llListen(a, NO_FILTER, dollID, NO_FILTER)
#define isKnownTypeFolder(a) (llListFindList(typeFolders, [ a ]) != NOT_FOUND)

//========================================
// VARIABLES
//========================================

string bigsubfolder = "dressup"; //name of subfolder in RLV to always use if available. But also checks for outfits.

// FIXME: This should be in a notecard so it can be changed without mangling the scripts.
string outfits_url = "outfits.htm";

string prefix;

integer tempWearLock = FALSE;
integer candresstimeout;
integer dressTries;

key dollID = NULL_KEY;
key dresserID = NULL_KEY;
key setupID = NULL_KEY;

string newoutfitname;
string newoutfitpath;
string oldoutfitpath;

string newoutfitfolder;
string oldoutfitfolder;

// New simple listener setup we only
// listen to rlvChannel directly the
// other we use MenuHandlers link 500's
integer dialogChannel;
integer rlvBaseChannel;
integer change;
integer pushRandom;

integer wearLock;
#ifdef WEAR_AT_LOGIN
integer wearAtLogin;
#endif

// These are the paths of the outfits relative to #RLV
string lastfolder;
string newoutfit;
string oldoutfit;
string xfolder;
string yfolder;

string oldoutfitname;
list outfitsList;
integer useTypeFolder;
string msgx; // could be "msg" but that is used elsewhere?

string clothingFolder; // This contains clothing to be worn
string outfitsFolder;  // This contains folders of clothing to be worn
string activeFolder; // This is the lookup folder to search
string typeFolder; // This is the folder we want for our doll type
string normalselfFolder = "~normalself"; // This is the ~normalself we are using
string nudeFolder = "~nude"; // This is the ~nude we are using

//integer listen_id_2555;
integer listen_id_2665;
integer listen_id_2666;
integer listen_id_2668;
integer listen_id_2669;

integer afk;
integer canDressSelf;
integer collapsed;
integer fallbackFolder;

//integer startup = 1;
integer dressingFailures;
integer RLVok;

integer outfitPage;

string oldattachmentpoints;
string oldclothespoints;
integer newoutfitwordend;
integer outfitPageSize = 9;
string pronounSheDoll = "She";
string pronounHerDoll = "Her";

//========================================
// FUNCTIONS
//========================================
list outfitsPage(list outfitList) {
    integer newOutfitCount = llGetListLength(outfitList) - 1;

    // GLOBAL: outfitPage

    // compute start index
    integer currentIndex = outfitPage * outfitPageSize;

    // If reaching beyond the end...
    if (currentIndex > newOutfitCount) {
        // Wrap to start...
        //outfitPage = 0;
        //currentIndex = 0;

        // Halt at end
        outfitPage--;
        currentIndex = outfitPage * outfitPageSize;
    }
    // If reaching beyond the beginning...
    else if (currentIndex < 0) {
        // Wrap to end
        //currentIndex = newOutfitCount % outfitPageSize;
        //outfitPage = currentIndex % outfitPageSize;

        // Halt at start
        outfitPage = 0;
        currentIndex = 0;
    }

    integer endIndex = currentIndex + outfitPageSize - 1;
    if (endIndex > newOutfitCount) {
        endIndex = newOutfitCount;
    }

    list pageOutfits = llList2List(outfitsList, currentIndex, endIndex);
    integer n; string chat; list output;
    string itemname;
    for (n = currentIndex; n <= endIndex; n++) {
        itemname = (string)(n + 1) + ". " + cdListElement(outfitsList, n);
        chat += "\n" + itemname;
        output += [ llGetSubString(itemname, 0, 23) ];
    }

    llRegionSayTo(dresserID, 0, chat);

    // Use sort function to reverse order: this makes the sort
    // read top to bottom in dialog
    return llListSort(output, 3, 0);
    //return (llList2List(outfitsList, currentIndex, endIndex));
}

// Set the folder to use for clothing attach and detach
// Should be current clothing folder

setActiveFolder() {
    // outfitsFolder is set by a search in the Transform script
    //
    //if (outfitsFolder == "") {
    //    outfitsFolder = "> Outfits";
    //    lmSendConfig("outfitsFolder", outfitsFolder);
    //}

    // set activeFolder
    if (clothingFolder == "") activeFolder = outfitsFolder;
    else activeFolder = outfitsFolder + "/" + clothingFolder;

    // if activeFolder changed, update configuration
    //if (activeFolder != oldActive) lmSendConfig("activeFolder", activeFolder);
    lmSendConfig("activeFolder", activeFolder);
}

rlvRequest(string rlv, integer channel) {
    candresstimeout = 1;

         if (channel == 2665) listen_id_2665 = cdListenMine(rlvBaseChannel + 2665);
    else if (channel == 2666) listen_id_2666 = cdListenMine(rlvBaseChannel + 2666);
    else if (channel == 2668) listen_id_2668 = cdListenMine(rlvBaseChannel + 2668);
    else if (channel == 2669) listen_id_2669 = cdListenMine(rlvBaseChannel + 2669);

    if (RLVok) {
        debugSay(6, "DEBUG", "cmd = " + rlv + (string)(rlvBaseChannel + channel));
        lmRunRLV(rlv + (string)(rlvBaseChannel + channel));
    }

    llSetTimerEvent(10.0);
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
        debugSay(4, "DEBUG-DRESS", "looking at dress menu: " + (string)dresserID);

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
#endif

    if (change) llOwnerSay("Change to new outfit " + newoutfitname + " complete.");

    // Note: if wearLock is already set, it STAYS set with this setting
    //
    // This triggers Main and sets wearLockExpire
    lmSetConfig("wearLock", (string)(wearLock = (wearLock || ((dresserID != NULL_KEY) && (dresserID != dollID)))));
    //lmSendConfig("wearLock", (string)(wearLock));

    candresstimeout = 0;
    change = 0;

    tempWearLock = FALSE;
    llSetTimerEvent(0.0);

    dresserID = NULL_KEY;
}

#ifdef DEVELOPER_MODE
doDebug(string src) {
    //integer level = 5;
    //if (startup != 0) level = 6;

    string exists = "not found";
    if (useTypeFolder) exists = "found";

    debugSay(5, "DEBUG", ">  on " + src);
    debugSay(5, "DEBUG", ">> outfitsFolder = " + outfitsFolder);
    debugSay(5, "DEBUG", ">> clothingFolder = " + clothingFolder);
    debugSay(5, "DEBUG", ">> typeFolder = " + typeFolder + " (" + exists + ")");

    //setActiveFolder();

    debugSay(5, "DEBUG", ">> activeFolder = " + activeFolder);
    debugSay(5, "DEBUG", ">> normalselfFolder = " + normalselfFolder);
    debugSay(5, "DEBUG", ">> nudeFolder = " + nudeFolder);
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
        if (candresstimeout) {
            candresstimeout = 0;

            //llListenRemove(listen_id_2555);
            llListenRemove(listen_id_2665);
            llListenRemove(listen_id_2666);
            llListenRemove(listen_id_2668);
            llListenRemove(listen_id_2669);

            changeComplete(FALSE);
        }
    }

    //----------------------------------------
    // LINK_MESSAGE
    //----------------------------------------
    link_message(integer source, integer i, string data, key id) {

        // Parse link message header information
        list split        =     cdSplitArgs(data);
        string script     =     cdListElement(split, 0);
        integer remoteSeq =     (i & 0xFFFF0000) >> 16;
        integer optHeader =     (i & 0x00000C00) >> 10;
        integer code      =      i & 0x000003FF;
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
                     if (name == "newoutfitname")              newoutfitname = value;
                else if (name == "newoutfitfolder")          newoutfitfolder = value;
                else if (name == "newoutfitpath")              newoutfitpath = value;
                else if (name == "newoutfit")                      newoutfit = value;
                else if (name == "normalselfFolder")        normalselfFolder = value;
                else if (name == "nudeFolder")                    nudeFolder = value;
            }

            else if (c == "o") {
                     if (name == "oldoutfitfolder")          oldoutfitfolder = value;
                else if (name == "oldoutfitpath")              oldoutfitpath = value;
                else if (name == "oldoutfitname")              oldoutfitname = value;
                else if (name == "oldoutfit")                      oldoutfit = value;
                else if (name == "outfitsFolder")              outfitsFolder = value;
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
#ifdef DEVELOPER_MODE
                llOwnerSay("random dress chosen"); // DEBUG
#endif
                if (tempWearLock) {
                    string s = llToLower(pronounSheDoll);
                    llRegionSayTo(dresserID, 0, "Dolly cannot be dressed right now; " + s + " is already dressing");
                }
                else {
                    if (useTypeFolder) clothingFolder = typeFolder;
                    else clothingFolder = "";

                    lmSendConfig("clothingFolder", clothingFolder);
#ifdef DEVELOPER_MODE
                    llOwnerSay("clothingFolder = " + clothingFolder); // DEBUG
                    llOwnerSay("listing inventory on 2665..."); // DEBUG
#endif
                    listInventoryOn("2665");
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

            //debugSay(6, "DEBUG-DRESS", (string)tempWearLock + " " + choice);

            if (choice == "Outfits..." && !tempWearLock) {
                if (!isDresser(id)) return;

                if (wearLock) {
                    cdDialogListen();
                    llDialog(dresserID, "Clothing was just changed; cannot change right now.", ["OK"], dialogChannel);
                    return;
                }

                if (outfitsFolder != "") {
                    if (useTypeFolder) clothingFolder = typeFolder;
                    else clothingFolder = "";

                    lmSendConfig("clothingFolder", clothingFolder);
                    listInventoryOn("2666");
                }
                else {
                    string msgx = "You look in " + llToLower(pronounHerDoll) + " closet, and see no outfits for Dolly to wear.";
                    cdDialogListen();
                    llDialog(dresserID, msgx, ["OK"], dialogChannel);
                    return;
                }
            }
            else {
                msgx = "You may choose any outfit for " + llToLower(pronounHerDoll) + " to wear.\n\n";
                if (dresserID == dollID) msgx = "See " + WEB_DOMAIN + outfits_url + " for more information on outfits.\n\n";
                msgx += folderStatus();

                integer select = (integer)llGetSubString(choice, 0, llSubStringIndex(choice, ".") - 1);
                if (select != 0) choice = cdListElement(outfitsList, select - 1);

                if (choice == "OK") {
                    ; // No outfits: only OK is available
                }
                else if (llGetSubString(choice, 0, 6) == "Outfits") {
                    if (!isDresser(id)) return;

                    if (choice == "Outfits Next") {
                        debugSay(6, "DEBUG", ">>> Dress Menu: " + choice);
                        outfitPage++;

                    } else if (choice == "Outfits Prev") {
                        debugSay(6, "DEBUG", ">>> Dress Menu: " + choice);
                        outfitPage--;

                    } else if ("Outfits Parent") {
                        debugSay(6, "DEBUG", ">>> Dress Menu: " + choice);

                        if (clothingFolder != "") { // Return to the parent folder
                            list pathParts = llParseString2List(clothingFolder, [ "/" ], []);

                            clothingFolder = llDumpList2String(llDeleteSubList(pathParts, -1, -1), "/");
                            lmSendConfig("clothingFolder", clothingFolder);
                            setActiveFolder();

                            llOwnerSay("Trying the " + activeFolder + " folder.");

                            listInventoryOn("2666");
                            return;
                        }
                        else lmMenuReply(MAIN, name, id); // No parent folder to return to, go to main menu instead
                    }

                    string UpMain = "Outfits Parent";
                    if (outfitsFolder == "") UpMain = MAIN;

                    cdDialogListen();
                    llDialog(dresserID, msgx, ["Outfits Prev", "Outfits Next", UpMain ] + outfitsPage(outfitsList), dialogChannel);
                    llSetTimerEvent(60.0);

                } else if (cdListElementP(outfitsList, choice) != NOT_FOUND) {
                    // This could be entered via a menu injection by a random dress choice
                    // No standard user should be entering this way anyway
                    //if (!isDresser(id)) return;

                    if (isParentFolder(cdGetFirstChar(choice))) {
                        if (clothingFolder == "") clothingFolder = choice;
                        else clothingFolder += "/" + choice;

                        lmSendConfig("clothingFolder", clothingFolder);
                        setActiveFolder();
                        listInventoryOn("2666"); // recursion

                        llSetTimerEvent(60.0);
                        return;
                    }
                    else if ((outfitsFolder != "") && (choice != newoutfitname)) {
#ifdef DEVELOPER_MODE
                        // If we are in developer mode we are in danger of the key being ripped
                        // off here.  We therefore will use a temporary @detach=n restriction.
                        llOwnerSay("Developer key locked in place to prevent accidental detachment during dressing.");
                        lmRunRLV("attachthis=y,detachthis=n,detach=n,touchall=n,showinv=n");
#else
                        lmRunRLV("touchall=n,showinv=n");
#endif
                        tempWearLock = TRUE;

                        dressingFailures = 0;
                        dressTries = 0;
                        change = 1;

                        lmSendConfig("oldoutfitname",   (  oldoutfitname = newoutfitname));
                        lmSendConfig("oldoutfitfolder", (oldoutfitfolder = newoutfitfolder));
                        lmSendConfig("oldoutfitpath",   (  oldoutfitpath = newoutfitpath));
                        lmSendConfig("oldoutfit",       (      oldoutfit = newoutfit));

                          newoutfitname = choice;
                        newoutfitfolder = outfitsFolder;
                          newoutfitpath = clothingFolder;

                        newoutfit = newoutfitfolder + "/";
                        if (clothingFolder != "")
                            newoutfit += clothingFolder + "/";
                        newoutfit += newoutfitname;

                        lmSendConfig("newoutfitname",   (newoutfitname));
                        lmSendConfig("newoutfitfolder", (newoutfitfolder));
                        lmSendConfig("newoutfitpath",   (newoutfitpath));
                        lmSendConfig("newoutfit",       (newoutfit));
                    }

                    newoutfitwordend = llStringLength(newoutfit)  - 1;
                    debugSay(6, "DEBUG", ">>>newoutfit = " + newoutfit);

                    //llOwnerSay("newoutfit is: " + newoutfit);
                    //llOwnerSay("newoutfitname is: " + newoutfitname);
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

                    llOwnerSay("New outfit chosen: " + newoutfitname);

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
                    //
                    // This is unnessary we can do the same job with locking and @detachallthis
                    //if (RLVok) llMessageLinked(LINK_THIS, 315, SCRIPT_NAME + "|getpathnew:pants=2670," +
                    //                                           "getpathnew:shirt=2670," +
                    //                                           "getpathnew:jacket=2670," +
                    //                                           "getpathnew:skirt=2670," +
                    //                                           "getpathnew:underpants=2670," +
                    //                                           "getpathnew:undershirt=2670", NULL_KEY);

                    // Original outfit was a complete avi reset....
                    // Restore our usual look from the ~normalself
                    // folder...

                    if (RLVok) {
                        lmRunRLV("attachallover:" + normalselfFolder + "=force,detachallthis:" + normalselfFolder + "=n");
                        llSleep(1.0);

                        lmRunRLV("attachallover:" + nudeFolder + "=force");
                        llSleep(1.0);

                        lmRunRLV("attachallover:" + newoutfit + "=force,detachallthis:" + newoutfit + "=n," +
                                 "detachallthis:" + nudeFolder + "=n");
                        llSleep(1.0);

                        // Remove rest of old outfit (using path from attachments)
                        if (oldoutfitpath != "") {
                            lmRunRLV("detachall:" + oldoutfitpath + "=force");
                            llSleep(1.0);
                            oldoutfitpath = "";
                        }

                        lmRunRLV("detachall:" + outfitsFolder + "=force");
                        llSleep(1.0);

                        lmRunRLV("attachall:" + newoutfit + "=force");
                        llSleep(2.0);

                        // And now send an attempt to clean up any remaining stray pieces
                        string parts = "gloves|jacket|pants|shirt|shoes|skirt|socks|underpants|undershirt|alpha|pelvis|left foot|right foot|r lower leg|l lower leg|r forearm|l forearm|r upper arm|l upper arm|r upper leg|l upper leg";
                        lmRunRLV("detachallthis:" + llDumpList2String(llParseString2List(parts, [ "|" ], []), "=force,detachallthis:") + "=force");
                    }

                    xfolder = normalselfFolder;
                    rlvRequest("getinvworn:" + xfolder + "=", 2668);

                    yfolder = oldoutfitpath;
                    if (yfolder != "") rlvRequest("getinvworn:" + yfolder + "=", 2669);

                    llSetTimerEvent(10.0);
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
                integer cdOutfitRating = cdOutfitRating(newoutfitname);
                integer regionRating = cdRating2Integer(simRating);

                debugSay(3, "DEBUG", "Region rating " + llToLower(simRating) + " outfit " + newoutfitname + " cdOutfitRating: " + (string)cdOutfitRating +
                            " regionRating: " + (string)regionRating);

                if (RLVok) {
                    if (cdOutfitRating > regionRating) {
                        pushRandom = 1;
                        clothingFolder = newoutfitpath;
                        listInventoryOn("2665");
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

        debugSay(6, "DEBUG", "Channel: " + (string)channel + "\n" + choice);

        // channels:
        //
        // 2665: random outfit
        // 2666:
        // 2668:
        // 2669:

        llSetMemoryLimit(65536);

        //----------------------------------------
        // Channel: 2665
        //
        // Switched doll types: grab a new (appropriate) outfit at random and change to it
        //
        if (channel == (rlvBaseChannel + 2665)) { // list of inventory items from the current prefix

#ifdef DEVELOPER_MODE
            llOwnerSay("inventory listed on 2665..."); // DEBUG
#endif

            llListenRemove(listen_id_2665);
            outfitsList = llParseString2List(choice, [","], []);

            integer iStop = llGetListLength(outfitsList);

            debugSay(6, "DEBUG", "> RLV message type 2665");
            debugSay(6, "DEBUG", ">> " + choice);

            integer n;

            // May never occur: other directories, hidden directories and files,
            // and hidden UNIX files all take up space here.

            if (iStop == 0) {   // folder is bereft of files, switching to regular folder

                // No files found; leave the prefix alone and don't change
                llOwnerSay("There are no outfits in your " + activeFolder + " folder.");

                // Didnt find any outfits in the standard folder, try the
                // "extended" folder containing (we hope) outfits....

                if (outfitsFolder != "" && clothingFolder != "") {
                    list pathParts = llParseString2List(clothingFolder, [ "/" ], []);
                    clothingFolder = llDumpList2String(llList2List(pathParts, 0, -2), "/");
                    lmSendConfig("clothingFolder", clothingFolder);
                    return;
                }
                //else {
                //    clothingFolder = "";
                //    llOwnerSay("Trying the main #RLV folder.");
                //}
            }
            else {
                // Outfits (theoretically) found: change to one

                string itemname;
                string prefix;
                integer total;
                integer simrating = cdRating2Integer(simRating);

                for (n = 0; n < iStop; ++n) {
                    itemname = cdListElement(outfitsList, n);
                    prefix = llGetSubString(itemname,0,0);

                    debugSay(6, "DEBUG", ">itemname = " + itemname);
                    debugSay(6, "DEBUG", ">prefix = " + prefix);

                    // skip hidden files/directories and skip
                    // Doll Type (Transformation) folders...
                    //
                    // Note this skips *Regular too
                    //
                    // This (sort of) odd sequence imposes short-cut operations

                    //     if (llToLower(itemname) == "~normalself") lmSendConfig("normalselfFolder", (normalselfFolder = activeFolder + "/~normalself"));
                    //else if (llToLower(itemname) == "~nude")       lmSendConfig("nudeFolder",       (nudeFolder =       activeFolder + "/~nude"));
                    //else
                    if (!isHiddenItem(prefix)) {
                             if (!isTransformingItem(prefix)) {
                                 if (!isGroupItem(prefix)) {
                                     if (!(cdOutfitRating(itemname) > simrating)) {

                                         ++total;
                                         outfitsList += itemname;
                                }
                            }
                        }
                    }
                }

                if (!total) {

                    if (pushRandom && clothingFolder != "") {

                        list pathParts = llParseString2List(clothingFolder, [ "/" ], []);

                        clothingFolder = llDumpList2String(llDeleteSubList(pathParts, -1, -1), "/");
                        lmSendConfig("clothingFolder", clothingFolder);
                        setActiveFolder();

                        llOwnerSay("Trying the " + activeFolder + " folder.");

                        listInventoryOn("2665"); // recursion
                    }
                    else pushRandom = 0;
                    return;
                }

                // Pick outfit at random
                integer i = (integer) llFrand(total);
                string nextoutfitname = cdListElement(outfitsList, i);

                if (llGetSubString(nextoutfitname, 0, 0) != ">") {

                    debugSay(6, "DEBUG", ">nextoutfitname = " + nextoutfitname);

                    lmMenuReply(nextoutfitname, llGetObjectName(), llGetKey());
                    llOwnerSay("You are being dressed in this outfit: " + nextoutfitname);
                }
                else {
                    clothingFolder += "/" + nextoutfitname;
                    listInventoryOn("2665"); // recursion
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
        else if (channel == (rlvBaseChannel + 2666)) {

            llListenRemove(listen_id_2666);

            fallbackFolder = 0;
            outfitsList = llParseString2List(choice, [","], []); //what are brackets at end?

            integer n;
            integer iStop = llGetListLength(outfitsList);
            string itemname;
            string prefix;

            debugSay(6, "DEBUG", "> RLV message type 2666");
            debugSay(6, "DEBUG", ">> " + choice);

            // Collect names of possible new outfits, removing folders (items)
            // longer than 23 characters, those that start with "~" (hidden) or
            // with "*" (outfit folder). Also do not count current outfit name

            for (n = 0; n < iStop; n++) {
                itemname = cdListElement(outfitsList, n);
                prefix = cdGetFirstChar(itemname);

                //     if (llToLower(itemname) == "~normalself") lmSendConfig("normalselfFolder", (normalselfFolder = activeFolder + "/normalself"));
                //else if (llToLower(itemname) == "~nude")       lmSendConfig("nudeFolder",       (nudeFolder       = activeFolder + "/nude"));

                if (isHiddenItem(prefix) ||
                    isGroupItem(prefix) ||
                    isTransformingItem(prefix) ||
                    (cdOutfitRating(itemname) > cdRating2Integer(simRating)) ||
                    itemname == newoutfitname) {

                    outfitsList = llDeleteSubList(outfitsList, n, n--);
                    iStop--;
                }
            }

            if (!llGetListLength(outfitsList) && clothingFolder != "") {
                list pathParts = llParseString2List(clothingFolder, [ "/" ], []);

                clothingFolder = llDumpList2String(llDeleteSubList(pathParts, -1, -1), "/");
                lmSendConfig("clothingFolder", clothingFolder);
                setActiveFolder();

                llOwnerSay("Trying the " + activeFolder + " folder.");

                listInventoryOn("2666"); // recursion
                return;
            }

            // Sort: slow bubble sort
            outfitsList = llListSort(outfitsList, 1, TRUE);

            // Now create appropriate menu page from full outfits list
            integer total = 0;
            outfitPage = 0;
            integer newOutfitCount = llGetListLength(outfitsList);

            list newoutfits2 = [ MAIN ] + outfitsPage(outfitsList);

            if (llGetListLength(outfitsList) < 10) newoutfits2 = [ "-", "-" ] + newoutfits2;
            else newoutfits2 = [ "Outfits Prev", "Outfits Next" ] + newoutfits2;

            msgx = "You may choose any outfit.\n";
            if (dresserID == dollID) msgx = "See " + WEB_DOMAIN + outfits_url + " for more information on outfits.\n";
#ifdef DEVELOPER_MODE
            msgx += "Numbers match outfit names in chat, using chat history (CTRL+H) may help.\n\n" + folderStatus();
#else
            msgx += "Numbers match outfit names in chat, using chat history (CTRL+H) may help.";
#endif

            // Provide a dialog to user to choose new outfit
            cdDialogListen();
            llDialog(dresserID, msgx, newoutfits2, dialogChannel);
            candresstimeout = 1;
            llSetTimerEvent(60.0);
        }

        //----------------------------------------
        // Channel: 2668
        //
        // Check to see if all items are fully worn; if not, try again
        //
        else if (channel == (rlvBaseChannel + 2668)) {

            llListenRemove(listen_id_2668);

            debugSay(6, "DEBUG", ">> @getinvworn:" + xfolder);
            debugSay(6, "DEBUG", ">>> " + choice);

            string c1 = llGetSubString(choice,1,1);
            string c2 = llGetSubString(choice,2,2);

            if (((c1 != "0" && c1 != "3") ||
                 (c2 != "0" && c2 != "3")) &&
                ++dressingFailures <= MAX_DRESS_FAILURES) {

                llSleep(4.0);

                if (RLVok) {
                    if (!canDressSelf || afk || collapsed || wearLock) lmRunRLV("attachallthis:=y,detachallthis:" + outfitsFolder + "=n,attachallover:" + xfolder + "=force,attachallthis:=n");
                    else lmRunRLV("detachallthis:" + outfitsFolder + "=n,attachallover:" + xfolder + "=force");

                    rlvRequest("getinvworn:" + xfolder + "=", 2668);
                    candresstimeout++;
                }
            }
            else if (dressingFailures > MAX_DRESS_FAILURES) {
                changeComplete(FALSE);
            }
            else {
                dressTries++;
                if (xfolder == normalselfFolder && newoutfitpath != "") xfolder = newoutfit;
                else xfolder = "";

                if (xfolder != "") rlvRequest("getinvworn:" + xfolder + "=", 2668);
                else if (dressTries >= 3) changeComplete(TRUE);
            }
            debugSay(6, "DEBUG", "candresstimeout = " + (string)candresstimeout + ", dressTries = " + (string)dressTries);
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

            debugSay(6, "DEBUG", ">> @getinvworn:" + yfolder);
            debugSay(6, "DEBUG", ">>> " + choice);

            if (((c1 != "0" && c1 != "1") ||
                 (c2 != "0" && c2 != "1")) &&
                ++dressingFailures <= MAX_DRESS_FAILURES) {

                llSleep(4.0);

                if (RLVok) {
                    if (!canDressSelf || afk || collapsed || wearLock) lmRunRLV("detachallthis:=y,attachallthis:" + outfitsFolder + "=n,detachallthis:" + yfolder + "=force,detachallthis:=n");
                    else lmRunRLV("attachallthis:" + outfitsFolder + "=n,detachall:" + yfolder + "=force");

                    rlvRequest("getinvworn:" + yfolder + "=", 2669);
                    candresstimeout++;
                }
            }
            else if (dressingFailures > MAX_DRESS_FAILURES) {
                changeComplete(FALSE);
            }
            else {
                dressTries++;
                if (dressTries >= 3) changeComplete(TRUE);
            }

            debugSay(6, "DEBUG", "candresstimeout = " + (string)candresstimeout + ", dressTries = " + (string)dressTries);
        }

        llSleep(1.0);
        scaleMem();
    }
}


