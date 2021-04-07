#ifndef LINK_MSG_LIB
#define LINK_MSG_LIB
float LinkMessage_version=1.0;

// Used as the ID field in link messages to indicate the remote database
// as the triggering source.
#define DATABASE_ID (key)"951dc8dd-430b-7192-d8a0-7b140f2ff692"

#include "Json.lsl"
#define RECORD_DELETE ""

string seqStatus;
integer mySeqNum;

// Not yet being used
//
//integer cdCheckSeqNum(string script, integer seqNum) {
//    integer last = (integer)cdGetValue(seqStatus,[script]);
//    integer ret;
//
//    if ((last == 0) || (seqNum == (last + 1))) ret = 1;
//    else {
//        
//        llOwnerSay("Missing or out of order link message from '" + script + "' just recieved sequence number #" + (string)seqNum + " but there was no #" + (string)(last + 1));
//        ret = 0;
//    }
//
//    if (seqNum > last) seqStatus = cdSetValue(seqStatus,[script],(string)seqNum);
//    return ret;
//}

cdLinkMessage(integer target, integer opt, integer code, string data, key id) {
    llMessageLinked(target, (((++mySeqNum) << 16) | (opt << 10) | code), cdMyScriptName() + "|" + data, id);
}

// #define cdLinkMessage(target,opt,code,data,id) llMessageLinked(target, (((mySeqNum++) << 16) | (opt << 10) | code), cdMyScriptName() + "|" + data, id)

#define cdLinkCode(a,b,c) (((a & 0xFFFF) << 16) | (b << 10) | c)
#define cdInitializeSeq() mySeqNum = llRound(llFrand(1<<15))

// Link messages
#define lmSendToAgent(msg, id)                          cdLinkMessage(LINK_THIS,0,11,msg,id)
#define lmSendToAgentPlusDoll(msg,id)                   cdLinkMessage(LINK_THIS,0,12,msg,id)
#define lmSendToController(msg)                         cdLinkMessage(LINK_THIS,0,15,msg,llGetKey())
//#define lmConfigComplete(count)                         cdLinkMessage(LINK_THIS,0,102,(string)(count),llGetKey())
#define lmInitState(num)                                cdLinkMessage(LINK_THIS,0,(num),(string)(num),llGetKey())
#define lmMemReport(delay,id)                           cdLinkMessage(LINK_THIS,0,135,(string)delay,id)
#define lmMemReply(s)                                   cdLinkMessage(LINK_THIS,0,136,s,llGetKey())
#define lmRating(simrating)                             cdLinkMessage(LINK_THIS,0,150,simrating,llGetKey())
#define lmSendConfig(name,value)                        cdLinkMessage(LINK_THIS,0,300,name+"|"+value,llGetKey())
#define lmSetConfig(name,value)                         cdLinkMessage(LINK_THIS,0,301,name+"|"+value,llGetKey())
#define lmSanityConfig(name,value)                      cdLinkMessage(LINK_THIS,0,301,name+"|"+value,llGetKey())
#define lmInternalCommand(command,parameter,id)         cdLinkMessage(LINK_THIS,0,305,command+"|"+parameter,id)
#define lmStrip(part)                                   cdLinkMessage(LINK_THIS,0,305,"strip|"+part,id)
#define lmTimePulse()                                   cdLinkMessage(LINK_THIS,0,310,"getTimeUpdates",llGetKey())
#define lmTimeConfig(name,value)                        cdLinkMessage(LINK_THIS,0,310,name+"|"+value,llGetKey())

#define lmRunRLV(command)                               cdLinkMessage(LINK_THIS,0,315,__SHORTFILE__+"|runRLVcmd|"+command,llGetKey())
#define lmRunRLVcmd(cmd,command)                        cdLinkMessage(LINK_THIS,0,315,__SHORTFILE__+"|"+cmd+"|"+command,llGetKey())
#define lmRestrictRLV(command)                          cdLinkMessage(LINK_THIS,0,315,__SHORTFILE__+"|restrictRLVcmd|"+command,llGetKey())
#define lmRunRLVas(vmodule,command)                     cdLinkMessage(LINK_THIS,0,315,vmodule+"|runRLVcmd|"+command,llGetKey())

#define lmConfirmRLV(forscript,command)                 cdLinkMessage(LINK_THIS,0,320,forscript+"|"+command,llGetKey())
#define lmRLVreport(active,apistring,apiversion)        cdLinkMessage(LINK_THIS,0,350,(string)active+"|"+apistring+"|"+(string)apiversion,llGetKey())
#define lmMenuReply(choice,name,id)                     cdLinkMessage(LINK_THIS,0,500,choice+"|"+name,id)
#define lmTextboxReply(type,name,choice,id)             cdLinkMessage(LINK_THIS,0,501,(string)type+"|"+name+"|"+choice,id)
#define lmPoseReply(choice,name,id)                     cdLinkMessage(LINK_THIS,0,502,choice+"|"+name,id)
#define lmTypeReply(choice,name,id)                     cdLinkMessage(LINK_THIS,0,503,choice+"|"+name,id)
#define lmBroadcastReceived(name,msg,id)                cdLinkMessage(LINK_THIS,0,800,name+"|"+llGetOwnerKey(id)+"|"+msg,id)
#define lmPluginSend(msg)                               cdLinkMessage(LINK_THIS,0,307,msg,NULL_KEY)

// Virtual function style new link commands
#define cdCarry(id)             lmInternalCommand("carry", (carrierName = llGetDisplayName(id)), (carrierID = id))
#define cdUncarry()             lmInternalCommand("uncarry", carrierName, carrierID)
#define cdDialogListen()        lmInternalCommand("dialogListen", "", NULL_KEY)


#endif
