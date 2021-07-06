#ifndef LINK_MSG_LIB
#define LINK_MSG_LIB
float LinkMessage_version=1.0;

string seqStatus;
integer mySeqNum;

#define cdLinkMessage(a,b,c,d,e) llMessageLinked((a), (((++mySeqNum) << 16) | (b << 10) | c), myName + "|" + d, e)

#define parseLinkHeader(a,i) \
        split     = cdSplitArgs(a); \
        script    = (string)split[0]; \
        remoteSeq = (i & 0xFFFF0000) >> 16; \
        optHeader = (i & 0x00000C00) >> 10; \
        code      =  i & 0x000003FF; \
        split     = llDeleteSubList(split, 0, 0 + optHeader)

#define cdLinkCode(a,b,c) (((a & 0xFFFF) << 16) | (b << 10) | c)
#define cdInitializeSeq() mySeqNum = llRound(llFrand(1<<15))

// Link messages
#define lmSendToAgent(msg, id)                          cdLinkMessage(LINK_THIS,0,11,msg,id)
#define lmSendToAgentPlusDoll(msg,id)                   cdLinkMessage(LINK_THIS,0,12,msg,id)
#define lmSendToController(msg)                         cdLinkMessage(LINK_THIS,0,15,msg,keyID)
#define lmInitStage(num)                                cdLinkMessage(LINK_THIS,0,(num),(string)(num),keyID)
#define lmMemReport(delay,id)                           cdLinkMessage(LINK_THIS,0,135,(string)delay,id)
#define lmMemReply(s)                                   cdLinkMessage(LINK_THIS,0,136,s,keyID)
#define lmRating(simrating)                             cdLinkMessage(LINK_THIS,0,150,simrating,keyID)
#define lmSendConfig(name,value)                        cdLinkMessage(LINK_THIS,0,300,name+"|"+value,keyID)
#define lmSetConfig(name,value)                         cdLinkMessage(LINK_THIS,0,301,name+"|"+value,keyID)
//#define lmSanityConfig(name,value)                      cdLinkMessage(LINK_THIS,0,301,name+"|"+value,keyID)
#define lmInternalCommand(command,parameter,id)         cdLinkMessage(LINK_THIS,0,305,command+"|"+parameter,id)
//#define lmStrip(part)                                   cdLinkMessage(LINK_THIS,0,305,"strip|"+part,id)
//#define lmTimePulse()                                   cdLinkMessage(LINK_THIS,0,310,"getTimeUpdates",keyID)
//#define lmTimeConfig(name,value)                        cdLinkMessage(LINK_THIS,0,310,name+"|"+value,keyID)

#define lmRunRlv(command)                               cdLinkMessage(LINK_THIS,0,315,__SHORTFILE__+"|rlvRunCmd|"+command,keyID)
#define lmRlvInternalCmd(cmd,command)                        cdLinkMessage(LINK_THIS,0,315,__SHORTFILE__+"|"+cmd+"|"+command,keyID)
//#define lmRestrictRLV(command)                          cdLinkMessage(LINK_THIS,0,315,__SHORTFILE__+"|restrictRLVcmd|"+command,keyID)
#define lmRunRlvAs(vmodule,command)                     cdLinkMessage(LINK_THIS,0,315,vmodule+"|rlvRunCmd|"+command,keyID)

//#define lmConfirmRLV(forscript,command)                 cdLinkMessage(LINK_THIS,0,320,forscript+"|"+command,keyID)
#define lmRlvReport(active,apistring,apiversion)        cdLinkMessage(LINK_THIS,0,350,(string)active+"|"+apistring+"|"+(string)apiversion,keyID)
#define lmMenuReply(choice,name,id)                     cdLinkMessage(LINK_THIS,0,500,choice+"|"+name,id)
#define lmTextboxReply(type,name,choice,id)             cdLinkMessage(LINK_THIS,0,501,(string)type+"|"+name+"|"+choice,id)
#define lmPoseSelected(choice,name,id)                     cdLinkMessage(LINK_THIS,0,502,choice+"|"+name,id)
#define lmTypeChange(choice,name,id)                    cdLinkMessage(LINK_THIS,0,503,choice+"|"+name,id)
//#define lmBroadcastReceived(name,msg,id)                cdLinkMessage(LINK_THIS,0,800,name+"|"+llGetOwnerKey(id)+"|"+msg,id)
//#define lmPluginSend(msg)                               cdLinkMessage(LINK_THIS,0,307,msg,NULL_KEY)

// Virtual function style new link commands
#define lmCarry(id)             lmInternalCommand("carry", (carrierName = llGetDisplayName(id)), (carrierID = id))
#define lmUncarry()             lmInternalCommand("uncarry", carrierName, carrierID)
#define lmDialogListen()        lmInternalCommand("dialogListen", "", NULL_KEY)


#endif
