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

//========================================
// VARIABLES
//========================================
                  
string bigsubfolder = "Dressup"; //name of subfolder in RLV to always use if available. But also checks for outfits.

// FIXME: This should be in a notecard so it can be changed without mangling the scripts.
string outfits_url = "http://communitydolls.com/outfits.htm";

integer candresstemp;
integer candresstimeout;

key dollID;
key dresserID;
key setupID;

integer lockTime = 300;
integer listen_id_outfitrequest3;
string newoutfitname;
string oldoutfitpath;

integer channel_dialog;
integer cd2667;
integer cd2668;
integer cd2669;
integer cd2670;

// These are the paths of the outfits relative to #RLV
string newoutfit;
string oldoutfit;
string xfolder;

string oldoutfitname;
list outfitsList;
string msgx; // could be "msg" but that is used elsewhere?

string clothingFolder; // This contains clothing to be worn
string outfitsFolder;  // This contains folders of clothing to be worn

integer listen_id_outfitrequest;
integer listen_id_2555;
integer listen_id_2667;
integer listen_id_2668;
integer listen_id_2669;
integer listen_id_2670;

integer outfitPage;

string oldattachmentpoints;
string oldclothespoints;
integer newoutfitwordend;
integer outfitPageSize = 9;

// Keys of important people in life of the Key:
key MasterBuilder = "42c7aaec-38bc-4b0c-94dd-ae562eb67e6d";   // Christina Halpin
key  MasterWinder = "64d26535-f390-4dc4-a371-a712b946daf8";   // GreigHighland
key        DevOne = "c5e11d0a-694f-46cc-864b-e42340890934";   // MayStone
key        DevTwo = "2fff40f0-ea4a-4b52-abb8-d4bf6b1c98c9";   // Silky Mesmeriser

list rescuerList = [ MasterBuilder, MasterWinder ];
list developerList = [ DevOne, DevTwo ];

string scriptName;

//========================================
// FUNCTIONS
//========================================

integer devKey() {
    if (dollID != llGetOwner()) dollID = llGetOwner();
    return llListFindList(developerList, [ dollID ]) != -1;
}

string FormatFloat(float val, integer dp)
{
    string out = "ERROR";
    if (dp == 0) {
        out = (string)llRound(val);
    } else if (dp > 0 && dp <= 6) {
        val = llRound(val * llPow(10.0, dp)) / llPow(10.0, dp);
        out = llGetSubString((string)val, 0, -7 + dp);
    }
    return out;
}

memReport() {
    float free_memory = (float)llGetFreeMemory();
    float used_memory = (float)llGetUsedMemory();
    
    if (devKey()) llOwnerSay(scriptName + ": Memory " + FormatFloat(used_memory/1024.0, 2) + "/" + (string)llRound((used_memory + free_memory)/1024.0) + "kB, " + FormatFloat(free_memory/1024.0, 2) + " kB free");
}

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

integer isClothingItem (string folder) {
    string prefix = llGetSubString(folder,0,0);

    // Folders that start with "~" are hidden and
    // those that start with "*" are actually outfit folders
    return (prefix == "~" || prefix == "*");
}

integer isGroupItem (string f) {
    string prefix = llGetSubString(f,0,0);

    return (prefix == "#");
}

integer isHiddenItem (string f) {
    string prefix = llGetSubString(f,0,0);

    // Items that start with "~" are hidden
    return (prefix == "~" || prefix == ">");
}

integer isTransformingItem (string f) {
    string prefix = llGetSubString(f,0,0);

    // Items that start with "*" are Transforming folders
    return (prefix == "*");
}

integer isPlusItem (string f) {
    string prefix = llGetSubString(f,0,0);

    // Items that start with "+" are self-contained outfits;
    // make no assumptions when restoring to "normal" outfit
    return (prefix == "+");
}

removeListeners () {
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

addListeners (string dollID) {
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
}

listInventoryOn (string channel) {
    candresstimeout = 8;

    llSay(DEBUG_CHANNEL,">> clothingFolder = " + (string)clothingFolder);
    llSay(DEBUG_CHANNEL,">> outfitsFolder = " + (string)outfitsFolder);
                
    if (clothingFolder == "") {
        llMessageLinked(LINK_SET, 315, scriptName + "|getinv=" + channel, NULL_KEY);
    }
    else {
        llSay(DEBUG_CHANNEL,"cmd = getinv:" + clothingFolder + "=" + channel);
        llMessageLinked(LINK_SET, 315, scriptName + "|getinv:" + clothingFolder + "=" + channel, NULL_KEY);
    }
}

setup ()  {
    dollID = llGetOwner();
    candresstemp = TRUE;

//from dollkey36

    integer ncd = ( -1 * (integer)("0x" + llGetSubString((string)llGetKey(),-5,-1) ) ) - 1;

    if (channel_dialog != ncd) {
        llListenRemove(listen_id_2667);
        channel_dialog = ncd;
        cd2667 = channel_dialog - 2667;
        llListenRemove(listen_id_2667);
        listen_id_2667 = llListen( cd2667, "", "", "");
    }

    if (dollID != setupID) {
        removeListeners();
        llSleep(2.0);
        addListeners(dollID);

        setupID = dollID;
    }
    
    listInventoryOn("2555");
    
    llSetTimerEvent(10.0);  //clock is accessed every ten seconds;
    
    llMessageLinked(LINK_SET, 103, scriptName, NULL_KEY);
}

//========================================
// STATES
//========================================
default {
    state_entry() { scriptName = llGetScriptName(); llMessageLinked(LINK_SET, 999, scriptName, NULL_KEY); }
    
    //----------------------------------------
    // TIMER
    //----------------------------------------
    timer() {   //called everytimeinterval
        if (candresstimeout-- == 0) {
            candresstemp = TRUE;
        }
    }

    //----------------------------------------
    // LINK_MESSAGE
    //----------------------------------------
    link_message(integer source, integer num, string choice, key id) {

        // need to disallow dressing while dressing is happening

        // Choice #1: Dress Dolly
        if (num == 500)  {
            if (candresstemp == FALSE) {
                llRegionSayTo(dresserID, PUBLIC_CHANNEL, "Dolly cannot be dressed right now; she is already dressing");
            }
            // If this code is linked with an argument of "start", then
            // act normally
            else if (choice == "Dress") {
                dresserID = id;
                listInventoryOn("2666");
            }
            // If this code is linked with an argument of "random", then
            // choose random outfit and be done
            //
            // This is used on style change
            else if (choice == "random") {
                //candresstemp = FALSE;
                listInventoryOn("2665");
            }
        }
        // Choice #2: ...
        else if (num == 2)  {  //probably should have been in transformer

            string oldclothingprefix = clothingFolder;
            llSay(DEBUG_CHANNEL,">on link #2");
            llSay(DEBUG_CHANNEL,">>oldclothingprefix = " + oldclothingprefix);
            llSay(DEBUG_CHANNEL,">>outfitsFolder = " + outfitsFolder);
            llSay(DEBUG_CHANNEL,">>clothingFolder = " + clothingFolder);
            llSay(DEBUG_CHANNEL,">>choice = " + choice);

            if (outfitsFolder != "") {
                clothingFolder = outfitsFolder + "/" +  choice;
            }
            else {
                clothingFolder = choice;
            }

            llSay(DEBUG_CHANNEL,">>clothingFolder = " + clothingFolder);

            if (clothingFolder != oldclothingprefix) {

                xfolder = "~normalself";
                //llMessageLinked(LINK_SET, 315, scriptName + "|attach:" + clothingFolder + "/~normalself=force", NULL_KEY);
                llMessageLinked(LINK_SET, 315, scriptName + "|attach:~normalself=force", NULL_KEY);
                llMessageLinked(LINK_SET, 315, scriptName + "|getinvworn:~normalself=2668", NULL_KEY);

                // FIXME: Make sure...
                //llSleep(2.0);
                //llMessageLinked(LINK_SET, 315, scriptName + "|attach:~normalself=force", NULL_KEY);
            }
        }
        else if (num == 104) {
            llSleep(1);
            
            clothingFolder = "";
            channel_dialog = 0;
        }
        else if (num == 135) memReport();
        else if (num == 350) {
            setup();
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
        if (channel == 2555) { // looks for one folder at start
            list Outfits = llParseString2List(choice, [","], []); //what are brackets at end?
            integer iStop = llGetListLength(Outfits);
            string oldbigprefix = outfitsFolder;
            integer n;
            string itemname;

            llSay(DEBUG_CHANNEL,">on channel 2555");
            outfitsFolder = "";

            // Looks for a folder that may contain outfits - folders such
            // as Dressup/, or outfits/, or Outfits/ ...
            for (n = 0; n < iStop; n++) {
                itemname = llList2String(Outfits, n);

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
            }

            // if prefix changes, change clothingFolder to match
            if (outfitsFolder != oldbigprefix) {  //outfits-don't-match-type bug only occurs when big prefix is changed
                clothingFolder = outfitsFolder;
            }

            llSay(DEBUG_CHANNEL,">oldbigprefix = " + oldbigprefix);
            llSay(DEBUG_CHANNEL,">outfitsFolder = " + outfitsFolder);
            llSay(DEBUG_CHANNEL,">clothingFolder = " + clothingFolder);
        }

        //----------------------------------------
        // Channel: 2665
        //
        // Switched doll types: grab a new (appropriate) outfit at random and change to it
        //
        else if (channel == 2665) { // list of inventory items from the current prefix
            list Outfits = llParseString2List(choice, [","], []); //what are brackets at end?
            integer iStop = llGetListLength(Outfits);

            integer n;

            // May never occur: other directories, hidden directories and files,
            // and hidden UNIX files all take up space here.

            if (iStop == 0) {   // folder is bereft of files, switching to regular folder

                // No files found; leave the prefix alone and don't change
                llOwnerSay("There are no outfits in your " + clothingFolder + " folder.");
                llSay(DEBUG_CHANNEL,"There are no outfits in your " + clothingFolder + " folder.");

                // Didnt find any outfits in the standard folder, try the
                // "extended" folder containing (we hope) outfits....

                if (outfitsFolder) {
                    clothingFolder = outfitsFolder + "/";
                    llOwnerSay("Trying the " + clothingFolder + " folder.");
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

                    llSay(DEBUG_CHANNEL,">itemname = " + itemname);
                    llSay(DEBUG_CHANNEL,">prefix = " + prefix);

                    // skip hidden files/directories and skip
                    // Doll Type (Transformation) folders...
                    //
                    // Note this skips *Regular too

                    if (!isHiddenItem(itemname) && !isTransformingItem(itemname) && !isGroupItem(itemname)) {
                        total += 1;
                        outfitsList += itemname;
                    }
                }

                // Pick outfit at random
                integer i = (integer) llFrand(total);
                string nextoutfitname = llList2String(outfitsList, i);
                llSay(DEBUG_CHANNEL,">nextoutfitname = " + nextoutfitname);

                // the dialog not only OKs things - but fires off the dressing process
                llDialog(dollID, "You are being dressed in this outfit.",[nextoutfitname], cd2667);
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
        else if (channel == 2666) {
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

            msgx = "You may choose any outfit.";

            if (dresserID == dollID) {
                msgx = "See " + outfits_url + " for more information on outfits.";
            }

            // Provide a dialog to user to choose new outfit
            llDialog(dresserID, msgx, newoutfits2, cd2667);
        }

        //----------------------------------------
        // Channel: 2667
        //
        // Handle a newly chosen outfit: outfit path relative to clothingFolder is the choice.
        // The original random code could also return a "OK" as choice, and this was filtered for.
        //
        else if (channel == cd2667) {
            llMessageLinked(LINK_SET, 305, scriptName + "|wearClear", NULL_KEY);
                                    
            llSay(DEBUG_CHANNEL,">>> channel 2667: " + choice);
            if (choice == "OK") {
                ; // No outfits: only OK is available
            } else if (choice == "Next") {
                outfitPage++;
                llDialog(dresserID, msgx, ["Prev", "Next", "Page " + (string)(outfitPage+1)] + outfitsPage(outfitsList), cd2667);
            } else if (choice == "Prev") {
                outfitPage--;
                llDialog(dresserID, msgx, ["Prev", "Next", "Page " + (string)(outfitPage+1)] + outfitsPage(outfitsList), cd2667);
            } else if (choice == "Page " + (string)(outfitPage+1)) {
                ; // Do nothing
            } else {
                candresstemp = FALSE;
                newoutfitname = choice;

                if (clothingFolder == "") {
                    newoutfit = choice;
                }
                else {
                    newoutfit = clothingFolder + "/" + choice;
                }

                newoutfitwordend = llStringLength(newoutfit)  - 1;
                llSay(DEBUG_CHANNEL,">>>newoutfit = " + newoutfit);

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
                llMessageLinked(LINK_SET, 315, scriptName + "|getpathnew:pants=2670", NULL_KEY);
                llMessageLinked(LINK_SET, 315, scriptName + "|getpathnew:shirt=2670", NULL_KEY);
                llMessageLinked(LINK_SET, 315, scriptName + "|getpathnew:jacket=2670", NULL_KEY);
                llMessageLinked(LINK_SET, 315, scriptName + "|getpathnew:skirt=2670", NULL_KEY);
                llMessageLinked(LINK_SET, 315, scriptName + "|getpathnew:underpants=2670", NULL_KEY);
                llMessageLinked(LINK_SET, 315, scriptName + "|getpathnew:undershirt=2670", NULL_KEY);

                // Original outfit was a complete avi reset....
                // Restore our usual look from the ~normalself
                // folder...

                if ( isPlusItem(oldoutfitname) &&
                    !isPlusItem(newoutfitname)) {  // only works well assuming in regular

                    llMessageLinked(LINK_SET, 315, scriptName + "|attach:~normalself=force", NULL_KEY);
                    llSleep(4.0);
                }

                // First, replace current outfit with new (or replace)
                llMessageLinked(LINK_SET, 315, scriptName + "|attach:" + newoutfit + "=force", NULL_KEY);
                llSleep(4.0);

                // Add items that cant replace what is already there
                llMessageLinked(LINK_SET, 315, scriptName + "|attachallover:" + newoutfit + "=force", NULL_KEY);
                llSleep(4.0);

                // Remove rest of old outfit (using memorized former outfit)
                if (oldoutfit != "") {
                    if (oldoutfit != newoutfit) {
                        llMessageLinked(LINK_SET, 315, scriptName + "|detachall:" + oldoutfit + "=force", NULL_KEY);
                        llSleep(4.0);
                    }
                }

                // Remove rest of old outfit (using path from attachments)
                if (oldoutfitpath != "") {
                    llMessageLinked(LINK_SET, 315, scriptName + "|detachall:" + oldoutfitpath + "=force", NULL_KEY);
                    llSleep(4.0);
                    oldoutfitpath = "";
                }

                if (!isPlusItem(newoutfit)) {
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
                    llMessageLinked(LINK_SET, 315, scriptName + "|attach:~nude=force", NULL_KEY);
                    llSleep(4.0);
                }

                oldoutfit = newoutfit;
                oldoutfitname = newoutfitname;
                candresstimeout = 2;

                llOwnerSay("Change to new outfit " + newoutfitname + " complete.");
                
                if (id != dollID) llMessageLinked(LINK_SET, 305, scriptName + "|wearLock", NULL_KEY);
            }
        }

        //----------------------------------------
        // Channel: 2668
        //
        // Check to see if all items are fully worn; if not, try again
        //
        else if (channel == cd2668) {
            llSay(DEBUG_CHANNEL,">> @getinvworn:" + xfolder);
            if ((llGetSubString(choice,2,2)) != "3") {
                llSleep(4.0);
                llMessageLinked(LINK_SET, 315, scriptName + "|attach:" + xfolder + "=force", NULL_KEY);
                llMessageLinked(LINK_SET, 315, scriptName + "|getinvworn:" + xfolder + "=2668", NULL_KEY);
            }
        }

        //----------------------------------------
        // Channel: 2669
        //
        // Check to see if all items are fully removed; if not, try again
        //
        else if (channel == cd2669) {
            llSay(DEBUG_CHANNEL,">> @getinvworn:" + xfolder);
            if ((llGetSubString(choice,2,2)) != "1") {
                llSleep(4.0);
                llMessageLinked(LINK_SET, 315, scriptName + "|detach:" + xfolder + "=force", NULL_KEY);
                llMessageLinked(LINK_SET, 315, scriptName + "|getinvworn:" + xfolder + "=2669", NULL_KEY);
            }
        }

        //----------------------------------------
        // Channel: 2670
        //
        // Grab a path for an outfit, and save it for later
        //
        else if (channel == cd2670) {
            llSay(DEBUG_CHANNEL,"<< choice = " + choice);

            // When do we override the old outfit path - and with what?
            if (oldoutfitpath == "") {
                oldoutfitpath = choice;
                llSay(DEBUG_CHANNEL,"<< oldoutfitpath = " + oldoutfitpath);
            }
        }
    }
}