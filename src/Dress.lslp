// Dress.lsl
//
// vim: et sw=4
//
// DATE: 26 February 2013
//
// HISTORY:
//   Oct. 1   Adds everything in ~normalself folder, if oldoutfit begins with a +.
//            Adds channel dialog or id to screen listen
//   Nov. 17  moves listen to cd2667 so it gets turned off
//   Nov. 25  puts in dress menu
//   Aug 1    redoes closing
#include "include/GlobalDefines.lsl"

//========================================
// VARIABLES
//========================================
                  
string bigsubfolder = "Dressup"; //name of subfolder in RLV to always use if available. But also checks for outfits.

// FIXME: This should be in a notecard so it can be changed without mangling the scripts.
string outfits_url = "http://communitydolls.com/outfits.htm";

string prefix;

integer candresstemp;
integer candresstimeout;

key dollID = NULL_KEY;
key dresserID = NULL_KEY;
key setupID = NULL_KEY;

string newoutfitname;
string newoutfitpath;
string oldoutfitpath;

// New simple listener setup we only
// listen to rlvChannel directly the
// other we use MenuHandlers link 500's
integer dialogChannel;
integer rlvBaseChannel;

integer wearLock;

// These are the paths of the outfits relative to #RLV
string newoutfit;
string oldoutfit;
string xfolder;
string yfolder;

string oldoutfitname;
list outfitsList;
string msgx; // could be "msg" but that is used elsewhere?

string avatarFolder; // Stores the chrooted directory path for the current self
string clothingFolder; // This contains clothing to be worn
string outfitsFolder;  // This contains folders of clothing to be worn
string activeFolder; // This is the lookup folder to search 

integer listen_id_2555;
integer listen_id_2665;
integer listen_id_2666;
integer listen_id_2668;
integer listen_id_2669;

integer afk;
integer canWear;
integer collapsed;

integer startup = 1;
integer RLVok;

integer outfitPage;

string oldattachmentpoints;
string oldclothespoints;
integer newoutfitwordend;
integer outfitPageSize = 9;

//========================================
// FUNCTIONS
//========================================

list outfitsPage(list outfitList) {
    integer newOutfitCount = llGetListLength(outfitList);

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

    // Use sort function to reverse order: this makes the sort
    // read top to bottom in dialog
    return (llListSort(llList2List(outfitsList, currentIndex, endIndex),3,FALSE));
    //return (llList2List(outfitsList, currentIndex, endIndex));
}

/* Turns out this one is unused.
integer isClothingItem(string folder) {
    string prefix = llGetSubString(folder,0,0);

    // Folders that start with "~" are hidden and
    // those that start with "*" are actually outfit folders
    return (prefix == "~" || prefix == "*");
}*/

/*integer isGroupItem(string f) {
    string prefix = llGetSubString(f,0,0);

    return (prefix == "#");
}

integer isHiddenItem(string f) {
    string prefix = llGetSubString(f,0,0);

    // Items that start with "~" or ">" are hidden
    // Lets not hide > folders instead lets browse them.
    //return (prefix == "~" || prefix == ">");
    return (prefix == "~");
}

integer isParentFolder(string f) {
    string prefix = llGetSubString(f,0,0);

    // This is a parent folder if selected we do not wear it
    // instead we recurse inside it.
    return (prefix == ">");
}

integer isTransformingItem(string f) {
    string prefix = llGetSubString(f,0,0);

    // Items that start with "*" are Transforming folders
    return (prefix == "*");
}

integer isPlusItem(string f) {
    string prefix = llGetSubString(f,0,0);

    // Items that start with "+" are self-contained outfits;
    // make no assumptions when restoring to "normal" outfit
    return (prefix == "+");
}*/

setActiveFolder() {
    if (outfitsFolder == "" && clothingFolder == "") activeFolder = "";
    else if (outfitsFolder != "" && clothingFolder != "") activeFolder = outfitsFolder + "/" + clothingFolder;
    else if (outfitsFolder != "") activeFolder = outfitsFolder;
    else activeFolder = clothingFolder;
}

/* These would be overkill now we are using just
   a single listener.
   
removeListeners() {
    llListenRemove(listen_id_2555);
    llListenRemove(listen_id_outfitrequest3);
    llListenRemove(listen_id_outfitrequest);
    llListenRemove(listen_id_2668);
    llListenRemove(listen_id_2669);
    llListenRemove(listen_id_2670);
//    llListenRemove(listen_id_9001);
//    llListenRemove(listen_id_9002);
//    llListenRemove(listen_id_9003);
//    llListenRemove(listen_id_9005);
//    llListenRemove(listen_id_9007);
//    llListenRemove(listen_id_9011);
//    llListenRemove(listen_id_9012);
//    llListenRemove(listen_id_9013);
//    llListenRemove(listen_id_9014);
}

addListeners(string dollID) {
    listen_id_2555           = llListen(2555, "", dollID, "");
    listen_id_outfitrequest3 = llListen(2665, "", dollID, "");
    listen_id_outfitrequest  = llListen(2666, "", dollID, "");
    listen_id_2668           = llListen(2668, "", dollID, "");
    listen_id_2669           = llListen(2669, "", dollID, "");
    listen_id_2670           = llListen(2670, "", dollID, "");

//    listen_id_9001           = llListen(9001, "", dollID, "");
//    listen_id_9002           = llListen(9002, "", dollID, "");
//    listen_id_9003           = llListen(9003, "", dollID, "");
//    listen_id_9005           = llListen(9005, "", dollID, "");
//    listen_id_9007           = llListen(9007, "", dollID, "");
//    listen_id_9011           = llListen(9011, "", dollID, "");
//    listen_id_9012           = llListen(9012, "", dollID, "");
//    listen_id_9013           = llListen(9013, "", dollID, "");
//    listen_id_9014           = llListen(9014, "", dollID, "");
}*/

rlvRequest(string rlv, integer channel) {
    candresstimeout = 3;
    if (channel == 2555) listen_id_2555 = llListen(rlvBaseChannel - 2555, "", llGetOwner(), "");
    if (channel == 2665) listen_id_2665 = llListen(rlvBaseChannel - 2665, "", llGetOwner(), "");
    if (channel == 2666) listen_id_2666 = llListen(rlvBaseChannel - 2666, "", llGetOwner(), "");
    if (channel == 2668) listen_id_2668 = llListen(rlvBaseChannel - 2668, "", llGetOwner(), "");
    if (channel == 2669) listen_id_2669 = llListen(rlvBaseChannel - 2669, "", llGetOwner(), "");
    if (RLVok) {
        debugSay(5, "cmd = " + rlv + (string)(rlvBaseChannel - channel));
        lmRunRLV(rlv + (string)(rlvBaseChannel - channel));
    }
}

listInventoryOn(string channel) {
    integer level = 5;
    if (startup != 0) level = 7;
    debugSay(level, ">> clothingFolder = " + clothingFolder);
    debugSay(level, ">> outfitsFolder = " + outfitsFolder);
    setActiveFolder();
    debugSay(level, ">> activeFolder = " + activeFolder);
    
    rlvRequest("getinv:" + activeFolder + "=", (integer)channel);
}

setup()  {
    dollID = llGetOwner();
    candresstemp = TRUE;

//from dollkey36

    dialogChannel = 0x80000000 | (integer)("0x" + llGetSubString((string)llGetLinkKey(2), -8, -1));
    rlvBaseChannel = dialogChannel ^ 0x80000000; // Xor with the sign bit forcing the positive channel needed by RLV spec.

    outfitsFolder = "";
    clothingFolder = "";
    activeFolder = "";
    avatarFolder = "";
    
    llSetTimerEvent(10.0);  //clock is accessed every ten seconds;
}

//========================================
// STATES
//========================================
default {
    state_entry() {
        lmScriptReset();
    }
    
    on_rez(integer start) {
        startup = 2;
    }

    //----------------------------------------
    // LINK_MESSAGE
    //----------------------------------------
    link_message(integer source, integer code, string data, key id) {
        list split = llParseString2List(data, [ "|" ], []);
        
        scaleMem();
        
        if (code == 104) {
            if (llList2String(split, 0) != "Start") return;
            startup = 1;
            setup();
            lmInitState(104);
        }
        else if (code == 105) {
            if (llList2String(split, 0) != "Start") return;
            startup = 2;
            lmInitState(105);
        }
        else if (code == 135) {
            float delay = llList2Float(split, 1);
            memReport(delay);
        }
        else if (code == 300) {
            string script = llList2String(split, 0);
            string name = llList2String(split, 1);
            string value = llList2String(split, 2);
            
            if (name == "clothingFolder") {
                string oldclothingprefix = activeFolder;
                clothingFolder = value;
                setActiveFolder();
                
                if (activeFolder != oldclothingprefix) {
                    integer level = 5;
                    if (startup != 0) level = 7;
                    debugSay(level, ">on link #2");
                    debugSay(level, ">>oldActiveFolder = " + oldclothingprefix);
                    debugSay(level, ">>outfitsFolder = " + outfitsFolder);
                    debugSay(level, ">>clothingFolder = " + clothingFolder);
                    debugSay(level, ">>activeFolder = " + activeFolder);
                }
            }
            else if (name == "newoutfitname") newoutfitname = value;
            else if (name == "newoutfitpath") newoutfitpath = value;
            else if (name == "newoutfit") newoutfit = value;
            else if (name == "oldoutfitpath") oldoutfitpath = value;
            else if (name == "oldoutfitname") oldoutfitname = value;
            else if (name == "oldoutfit") oldoutfit = value;
            else if (name == "outfitsFolder") outfitsFolder = value;
            else if (name == "avatarFolder") avatarFolder = value;
            else if (name == "afk") afk = (integer)value;
            else if (name == "canWear") canWear = (integer)value;
            else if (name == "collapsed") collapsed = (integer)value;
            else if (name == "wearLock") wearLock = (integer)value;
            else if (name == "timeLeftOnKey") {
                // Hooking into the link broadcast from Main and using that
                // as a trigger for this saves us also running a local timer
                // for this simple task 
                if (candresstimeout-- == 0) {
                    candresstemp = TRUE;
                    llListenRemove(listen_id_2555);
                    llListenRemove(listen_id_2665);
                    llListenRemove(listen_id_2666);
                    llListenRemove(listen_id_2668);
                    llListenRemove(listen_id_2669);
                }
                //debugSay(5, "candresstimeout = " + (string)candresstimeout);
            }
        }
        else if (code == 305) {
            string cmd = llList2String(split, 0);
            
            // If this code is linked with an argument of "random", then
            // choose random outfit and be done
            //
            // This is used on style change
            if (cmd == "randomDress") {
                if (candresstemp == FALSE)
                    llRegionSayTo(dresserID, 0, "Dolly cannot be dressed right now; she is already dressing");
                //candresstemp = FALSE;
                else {
                    clothingFolder = "";
                    listInventoryOn("2665");
                }
            }
        }
        else if (code == 350) {
            RLVok = llList2Integer(split, 0);
            clothingFolder = "";
            listInventoryOn("2555");
        }
        // Choice #500: (From Main Menu) Dress Dolly
        else if (code == 500)  {
            string choice = llList2String(split, 0);
            
            if (candresstemp == FALSE)
                llRegionSayTo(dresserID, 0, "Dolly cannot be dressed right now; she is already dressing");
            // If this code is linked with an argument of "start", then
            // act normally
            else if (choice == "Dress") {
                dresserID = id;
                avatarFolder = outfitsFolder + "/";
                clothingFolder = "";
                listInventoryOn("2666");
            }
            else {
                msgx = "You may choose any outfit.\n\n";

                if (dresserID == dollID) {
                    msgx = "See " + outfits_url + " for more information on outfits.\n\n";
                }
    
                msgx += "Outfits Folder: " + outfitsFolder + "\n";
                msgx += "Current Folder: " + activeFolder + "\n";
                msgx += "Avatar Folder: " + avatarFolder + "\n";
                
                if (choice == "OK") {
                    ; // No outfits: only OK is available
                } else if (choice == "Next Outfits") {
                    debugSay(5, ">>> Dress Menu: " + choice);
                    outfitPage++;
                    llDialog(dresserID, msgx, ["Prev Outfits", "Next Outfits", "Outfits " + (string)(outfitPage+1)] + outfitsPage(outfitsList), dialogChannel);
                } else if (choice == "Prev Outfits") {
                    debugSay(5, ">>> Dress Menu: " + choice);
                    outfitPage--;
                    llDialog(dresserID, msgx, ["Prev Outfits", "Next Outfits", "Outfits " + (string)(outfitPage+1)] + outfitsPage(outfitsList), dialogChannel);
                } else if (choice == "Outfits " + (string)(outfitPage+1)) {
                    debugSay(5, ">>> Dress Menu: " + choice);
                    ; // Do nothing
                } else if (llListFindList(outfitsList, [ choice ]) != -1) {
                    debugSay(5, ">>> Dress Menu: " + choice);
                    
                    if (isParentFolder(choice)) {
                        if (clothingFolder == "") clothingFolder = choice;
                        else clothingFolder += "/" + choice;
                        setActiveFolder();
                        listInventoryOn("2666"); // recursion
                    }
                    else if (llGetSubString(choice, 0, 1) == "!>") {
                        if (clothingFolder == "") clothingFolder = choice;
                        else clothingFolder += "/" + choice;
                        setActiveFolder();
                        listInventoryOn("2666"); // recursion
                        avatarFolder = activeFolder + "/";
                        lmSendConfig("avatarFolder", avatarFolder);
                    }
                    else {
                        #ifdef DEVELOPER_MODE
                        // If we are in developer mode we are in danger of being ripped
                        // off here.  We therefore will use a temporary @detach=n restriction.
                        lmRunRLV("detach=n");
                        #endif
                        candresstemp = FALSE;
        
                        lmSendConfig("oldoutfitname", (oldoutfitname = newoutfitname));
                        lmSendConfig("oldoutfitpath", (oldoutfitpath = newoutfitpath));
                        lmSendConfig("oldoutfit", (oldoutfit = newoutfit));
                        
                        if (clothingFolder == "") {
                            newoutfit = choice;
                        }
                        else {
                            newoutfit = activeFolder + "/" + choice;
                        }
                        
                        lmSendConfig("newoutfitname", (newoutfitname = choice));
                        lmSendConfig("newoutfitpath", (newoutfitpath = newoutfit));
                        lmSendConfig("newoutfit", newoutfit);
        
                        newoutfitwordend = llStringLength(newoutfit)  - 1;
                        debugSay(5, ">>>newoutfit = " + newoutfit);
        
                        //llOwnerSay("newoutfit is: " + newoutfit);
                        //llOwnerSay("newoutfitname is: " + newoutfitname);
                        //llOwnerSay("choice is: " + choice);
                        //llOwnerSay("clothingFolder is: " + clothingFolder);
        
                        // Four steps to dressing avi:
                        //
                        // 1) Replace every item that can be replaced (using the
                        //    command @attachalloverorreplace)
                        // 2) Add every item that didnt get put on the first time
                        //    (using the @attachallover command)
                        // 3) Remove the remaining portions of the old outfit
                        // 4) Add items that are required for all outfits
                        //    (using the @attach command)
        
                        llOwnerSay("New outfit chosen: " + newoutfit);
        
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
                        /*if (RLVok) llMessageLinked(LINK_THIS, 315, SCRIPT_NAME + "|getpathnew:pants=2670," +
                                                                     "getpathnew:shirt=2670," +
                                                                     "getpathnew:jacket=2670," +
                                                                     "getpathnew:skirt=2670," + 
                                                                     "getpathnew:underpants=2670," +                                                                                                                          "getpathnew:undershirt=2670", NULL_KEY);*/
                            
                            if (RLVok) lmRunRLV("attachallthis:=y,detachallthis:=y,touchall=n,showinv=n");
                            llSleep(1.0);
        
                        // Original outfit was a complete avi reset....
                        // Restore our usual look from the ~normalself
                        // folder...
                        
                        //if (isPlusItem(oldoutfitname) &&
                        //    !isPlusItem(newoutfitname)) {  // only works well assuming in regular
        
                            if (RLVok) lmRunRLV("attachall:" + avatarFolder + "~normalself=force,detachthis:" + avatarFolder + "~normalself=n");
                            llSleep(1.0);
                        //}
                        
                        //if (!isPlusItem(newoutfit)) {
                            // Attach items that should be present when we are nude...
                            // This could include things like (actual) tattoos, piercings,
                            // enhanced feet or lipstick or mascara, rings, etc.
                            //
                            // This is necessary because many items may be considered part
                            // of the "nude" outfit, but will still be removed during an
                            // automated removal process.  There is nothing to determine
                            // which are desired and which are not.
                            //
                            // Perhaps these things should be individually locked.
                            //
                            // This could also be expanded to create a Nude dress selection -
                            // such as for use when going to nude beaches and such.
                            //
                            // Do this right off the bat and also lock it.  This makes more
                            // sense especially with multi layer wearables this makes sure
                            // that the underlayers go in first.
                            if (RLVok) lmRunRLV("attachall:" + avatarFolder + "~nude=force");
                            llSleep(1.0);
                        //}
        
                        // Add items that cant replace what is already there
                        if (RLVok) lmRunRLV("attachalloverorreplace:" + newoutfit + "=force,detachallthis:" + newoutfit + "=n," +
                                 "detachallthis:" + avatarFolder + "~nude=n");
                        llSleep(1.0);
        
                        // Remove rest of old outfit (using path from attachments)
                        if (oldoutfitpath != "") {
                            if (RLVok) lmRunRLV("detachall:" + oldoutfitpath + "=force");
                            llSleep(1.0);
                            oldoutfitpath = "";
                        }
                        
                        if (RLVok) lmRunRLV("detachall:" + outfitsFolder + "=force");
                        llSleep(1.0);
                        
                        lmRunRLV("detachallthis:pants=force,detachallthis:shirt=force,detachallthis:jacket=force,detachallthis:skirt=force," + 
                                 "detachallthis:underpants=force,detachallthis:undershirt=force");
                        llSleep(1.0);
                        
                        if (RLVok) lmRunRLV("attachall:" + newoutfit + "=force");
                        
                        llSleep(2.0);
                        
                        // And now send an attempt to clean up any remaining stray pieces
                        //string parts = "gloves|jacket|pants|shirt|shoes|skirt|socks|underpants|undershirt|alpha|pelvis|left foot|right foot|r lower leg|l lower leg|r forearm|l forearm|r upper arm|l upper arm|r upper leg|l upper leg";
                        //if (RLVok) lmRunRLV("detachallthis:" + llDumpList2String(llParseString2List(parts, [ "|" ], []), "=force,detachallthis:") + "=force");
        
                        candresstimeout = 2;
        
                        llOwnerSay("Change to new outfit " + newoutfitname + " complete.");
                        
                        // And remove the temp locks we used
                        // RLV.lsl knows which are ours and that is all this clears
                        lmRunRLV("clear");
                        
                        xfolder = avatarFolder + "~normalself";
                        rlvRequest("getinvworn:" + xfolder + "=", 2668);
                        
                        yfolder = oldoutfitpath;
                        if (yfolder != "") rlvRequest("getinvworn:" + yfolder + "=", 2669);
                        
                        if (id != dollID) wearLock = 1;
                        
                        lmInternalCommand("wearLock", (string)wearLock, scriptkey);
                        if (afk || !canWear || collapsed || wearLock) lmRunRLV("unsharedwear=n,unsharedunwear=n,attachallthis:=n,detachallthis:=n");
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
        
        //debugSay(5, "Channel: " + (string)channel + "\n" + choice);

        // channels:
        //
        // 2555: list of inventory
        // 2665: random outfit
        // 2666:
        // 2667:
        // 2668:
        // 2669:
        // 2670:
        // 9000+

        //----------------------------------------
        // Channel: 2555
        //
        // Look for a usable outfits directory, or use the root: looks for
        // "Outfits" or "outfits" - results are saved for use later to get
        // at appropriate outfits in folders
        //
        if (channel == (rlvBaseChannel - 2555)) { // looks for one folder at start
            llListenRemove(listen_id_2555);
            list Outfits = llParseString2List(choice, [","], []); //what are brackets at end?
            integer iStop = llGetListLength(Outfits);
            string oldbigprefix = outfitsFolder;
            string oldActiveFolder = activeFolder;
            integer n;
            string itemname;

            debugSay(5, ">RLV message type 2555");
            // Looks for a folder that may contain outfits - folders such
            // as Dressup/, or outfits/, or Outfits/ ...
            for (n = 0; n < iStop; n++) {
                itemname = llList2String(Outfits, n);
                scaleMem();

                // If there are more than one of these folders in #RLV,
                // then the last one read will be used...
                if (itemname == bigsubfolder) {
                    outfitsFolder = bigsubfolder;
                }
                else if (itemname == "outfits") {
                    outfitsFolder = "outfits";
                }
                else if (itemname == "Outfits") {
                    outfitsFolder = "Outfits";
                }
                else if (itemname == "> Outfits") {
                    outfitsFolder = "> Outfits";
                }
            }
            
           lmSendConfig("outfitsFolder", outfitsFolder);

            if (startup == 0) {
                // if prefix changes, change clothingFolder to match
                if (outfitsFolder != oldbigprefix) {  //outfits-don't-match-type bug only occurs when big prefix is changed
                    clothingFolder = "";
                }
            }
            
            if (startup == 2) {
                startup = 0;
            }
            
            integer level = 5;
            if (startup != 0) level = 7;
            debugSay(level, ">oldActiveFolder = " + oldbigprefix);
            debugSay(level, ">outfitsFolder = " + outfitsFolder);
            debugSay(level, ">clothingFolder = " + clothingFolder);
            setActiveFolder();
            debugSay(level, ">activeFolder = " + activeFolder);
        }

        //----------------------------------------
        // Channel: 2665
        //
        // Switched doll types: grab a new (appropriate) outfit at random and change to it
        //
        else if (channel == (rlvBaseChannel - 2665)) { // list of inventory items from the current prefix
            llListenRemove(listen_id_2665);
            list Outfits = llParseString2List(choice, [","], []); //what are brackets at end?
            integer iStop = llGetListLength(Outfits);

            integer n;

            // May never occur: other directories, hidden directories and files,
            // and hidden UNIX files all take up space here.

            if (iStop == 0) {   // folder is bereft of files, switching to regular folder

                // No files found; leave the prefix alone and don't change
                llOwnerSay("There are no outfits in your " + activeFolder + " folder.");
                debugSay(5, "There are no outfits in your " + activeFolder + " folder.");
                // Didnt find any outfits in the standard folder, try the
                // "extended" folder containing (we hope) outfits....

                if (outfitsFolder) {
                    clothingFolder = "";
                    setActiveFolder();
                    llOwnerSay("Trying the " + activeFolder + " folder.");
                    listInventoryOn("2665"); // recursion
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
                integer total = 0;

                outfitsList = [];

                for (n = 0; n < iStop; n++) {
                    itemname = llList2String(Outfits, n);
                    prefix = llGetSubString(itemname,0,0);

                    debugSay(5, ">itemname = " + itemname);
                    debugSay(5, ">prefix = " + prefix);
                    // skip hidden files/directories and skip
                    // Doll Type (Transformation) folders...
                    //
                    // Note this skips *Regular too
                    scaleMem();

                    if (!isHiddenItem(itemname) && !isTransformingItem(itemname) && !isGroupItem(itemname)) {
                        total += 1;
                        outfitsList += itemname;
                    }
                }

                // Pick outfit at random
                integer i = (integer) llFrand(total);
                string nextoutfitname = llList2String(outfitsList, i);
                debugSay(5, ">nextoutfitname = " + nextoutfitname);
                // the dialog not only OKs things - but fires off the dressing process
                llDialog(dollID, "You are being dressed in this outfit.",[nextoutfitname], dialogChannel);
                //llSay(cd2667, nextoutfitname);
                llOwnerSay("You are being dressed in this outfit: " + nextoutfitname);
            }
        }

        //----------------------------------------
        // Channel: 2666
        //
        // Choosing a new outfit normally and manually: create a paged dialog with an
        // alphabetical list of available outfits, and let the user choose one
        //
        else if (channel == (rlvBaseChannel - 2666)) {
            llListenRemove(listen_id_2666);
            list Outfits = llParseString2List(choice, [","], []); //what are brackets at end?
            integer n;
            integer iStop = llGetListLength(Outfits);
            string itemname;
            string prefix;

            // Collect names of possible new outfits, removing folders (items)
            // longer than 23 characters, those that start with "~" (hidden) or
            // with "*" (outfit folder). Also do not count current outfit name

            outfitsList = [];
            for (n = 0; n < iStop; n++) {
                itemname = llList2String(Outfits, n);

                if (llStringLength(itemname) < 24 &&
                    !isHiddenItem(itemname) &&
                    !isGroupItem(itemname) &&
                    !isTransformingItem(itemname) &&
                    itemname != oldoutfitname) {

                    outfitsList += itemname;
                    scaleMem();
                }
            }

            // Sort: slow bubble sort
            outfitsList = llListSort(outfitsList,1,TRUE);

            // Now create appropriate menu page from full outfits list
            integer total = 0;
            outfitPage = 0;
            integer newOutfitCount = llGetListLength(outfitsList);

            list newoutfits2 = outfitsPage(outfitsList);
            if (newOutfitCount > 12) {
                newoutfits2 = ["Prev", "Next", "Page " + (string)(outfitPage+1)] + outfitsPage(outfitsList);
            }

            msgx = "You may choose any outfit.\n\n";

            if (dresserID == dollID) {
                msgx = "See " + outfits_url + " for more information on outfits.\n\n";
            }

            msgx += "Outfits Folder: " + outfitsFolder + "\n";
            msgx += "Current Folder: " + activeFolder + "\n";
            msgx += "Avatar Folder: " + avatarFolder + "\n";
            
            // Provide a dialog to user to choose new outfit
            llDialog(dresserID, msgx, newoutfits2, dialogChannel);
        }

        //----------------------------------------
        // Channel: 2667
        //
        // Handle a newly chosen outfit: outfit path relative to clothingFolder is the choice.
        // The original random code could also return a "OK" as choice, and this was filtered for.
        //
        // Former dialog channel moved to use the main dialog interface
        /*else if (channel == cd2667) {

        }*/

        //----------------------------------------
        // Channel: 2668
        //
        // Check to see if all items are fully worn; if not, try again
        //
        else if (channel == (rlvBaseChannel - 2668)) {
            llListenRemove(listen_id_2668);
            debugSay(5, ">> @getinvworn:" + xfolder);
            debugSay(5, ">>> " + choice);
            if ((llGetSubString(choice,1,1) != "0" && llGetSubString(choice,1,1) != "3") ||
                (llGetSubString(choice,2,2) != "0" && llGetSubString(choice,2,2) != "3")) {
                llSleep(4.0);
                if (RLVok) {
                    if (afk || !canWear || collapsed || wearLock) lmRunRLV("attachallthis:=y,attachallover:" + xfolder + "=force,attachallthis:=n");
                    else lmRunRLV("attachallover:" + yfolder + "=force");
                    rlvRequest("getinvworn:" + xfolder + "=", 2668);
                    candresstimeout++;
                }
            }
            else {
                if (xfolder == avatarFolder + "~normalself") xfolder = avatarFolder + "~nude";
                else if (xfolder == avatarFolder + "~nude" && newoutfitpath != "") xfolder = newoutfitpath;
                else xfolder = "";
                
                if (xfolder != "") rlvRequest("getinvworn:" + xfolder + "=", 2668);
                else {
                    candresstimeout--;
                }
            }
            debugSay(5, "candresstimeout = " + (string)candresstimeout);
        }

        //----------------------------------------
        // Channel: 2669
        //
        // Check to see if all items are fully removed; if not, try again
        //
        else if (channel == (rlvBaseChannel - 2669)) {
            llListenRemove(listen_id_2669);
            debugSay(5, ">> @getinvworn:" + yfolder);
            debugSay(5, ">>> " + choice);
            if ((llGetSubString(choice,1,1) != "0" && llGetSubString(choice,1,1) != "1") ||
                (llGetSubString(choice,2,2) != "0" && llGetSubString(choice,2,2) != "1")) {
                llSleep(4.0);
                if (RLVok) {
                    if (afk || !canWear || collapsed || wearLock) lmRunRLV("detachallthis:=y,detachall:" + yfolder + "=force,detachallthis:=n");
                    else lmRunRLV("detachall:" + yfolder + "=force");
                    rlvRequest("getinvworn:" + yfolder + "=", 2669);
                    candresstimeout++;
                }
            }
            else {
                candresstimeout--;
            }
            debugSay(5, "candresstimeout = " + (string)candresstimeout);
        }

        //----------------------------------------
        // Channel: 2670
        //
        // Grab a path for an outfit, and save it for later
        //
        // Using the @detachallthis command instead avoids a
        // need for this at all
        /*else if (channel == cd2670) {
            debugSay(5, "<< choice = " + choice);
            // When do we override the old outfit path - and with what?
            if (oldoutfitpath == "") {
                oldoutfitpath = choice;
                debugSay(5, "<< oldoutfitpath = " + oldoutfitpath);
            }
        }*/
    }
}


