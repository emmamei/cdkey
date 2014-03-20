#ifndef LINK_MSG_LIB
#define LINK_MSG_LIB

#include "Json.lsl"
#define RECORD_DELETE ""

string seqStatus;
integer mySeqNum;

integer cdCheckSeqNum(string script, integer seqNum) {
    integer last = (integer)cdGetValue(seqStatus,[script]);
    integer ret;

    if ((last == 0) || (seqNum == (last + 1))) ret = 1;
    else {
        
        llOwnerSay("Missing or out of order link message from '" + script + "' just recieved sequence number #" + (string)seqNum + " but there was no #" + (string)(last + 1));
        ret = 0;
    }

    if (seqNum > last) seqStatus = cdSetValue(seqStatus,[script],(string)seqNum);
    return ret;
}

cdLinkMessage(integer target, integer opt, integer code, string data, key id) {
    ++mySeqNum;
    llMessageLinked(target, ((mySeqNum << 16) | (opt << 10) | code), cdMyScriptName() + "|" + data, id);
}

#define cdLinkCode(a,b,c) (((a & 0xFFFF) << 16) | (b << 10) | c)
#define cdInitializeSeq() mySeqNum = llRound(llFrand(1<<15))

// Link messages
#define lmSendToAgent(msg, id)                          cdLinkMessage(LINK_THIS,0,11,msg,id)
#define lmSendToAgentPlusDoll(msg,id)                   cdLinkMessage(LINK_THIS,0,12,msg,id)
#define lmSendToController(msg)                         cdLinkMessage(LINK_THIS,0,15,msg,NULL_KEY)
#define lmConfigComplete(count)                         cdLinkMessage(LINK_THIS,0,102,(string)(count),NULL_KEY)
#define lmInitState(num)                                cdLinkMessage(LINK_THIS,0,(num),(string)(num),NULL_KEY)
#define lmMemReport(delay,user)                         cdLinkMessage(LINK_THIS,0,135,(string)delay+"|"+(string)user,NULL_KEY)
#define lmMemReply(json)                                cdLinkMessage(LINK_THIS,0,136,json,NULL_KEY)
#define lmRating(simrating)                             cdLinkMessage(LINK_THIS,0,150,simrating, NULL_KEY)
#define lmSendConfig(name,value)                        cdLinkMessage(LINK_THIS,0,300,name+"|"+value,NULL_KEY)
#define lmInternalCommand(command,parameter,id)         cdLinkMessage(LINK_THIS,0,305,command+"|"+parameter,id)
#define lmStrip(part)                                   cdLinkMessage(LINK_THIS,0,305,"strip"+"|"+part,id)
#define lmRunRLV(command)                               cdLinkMessage(LINK_THIS,0,315,"|"+command,NULL_KEY)
#define lmRunRLVas(vmodule,command)                     cdLinkMessage(LINK_THIS,0,315,vmodule+"|"+command,NULL_KEY)
#define lmConfirmRLV(forscript,command)                 cdLinkMessage(LINK_THIS,0,320,forscript+"|"+command,NULL_KEY)
#define lmRLVreport(active,apistring,apiversion)        cdLinkMessage(LINK_THIS,0,350,(string)active+"|"+apistring+"|"+(string)apiversion,NULL_KEY)
//#define lmUpdateStatistic(name,value)                 cdLinkMessage(LINK_THIS,0,399,name+"|"+value,NULL_KEY)
#define lmMenuReply(choice,name,id)                     cdLinkMessage(LINK_THIS,0,500,choice+"|"+name,id)
#define lmTextboxReply(type,name,choice,id)             cdLinkMessage(LINK_THIS,0,501,(string)type+"|"+name+"|"+choice,id)
#define lmBroadcastReceived(name,msg,id)                cdLinkMessage(LINK_THIS,0,800,name+"|"+llGetOwnerKey(id)+"|"+msg,id)
#define lmServiceMessage(type,data,id)			cdLinkMessage(LINK_THIS,0,850,type+"|"+data,id)

// Virtual function style new link commands
#define cdCarry(id)             lmInternalCommand("carry", (carrierName = llGetDisplayName(id)), (carrierID = id))
#define cdUncarry()             lmInternalCommand("uncarry", carrierName, carrierID)


#endif
