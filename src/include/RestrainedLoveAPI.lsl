#ifndef RLV_API_LSL
#define RLV_API_LSL
#define VERSIONNEW_PREFIX "RestrainedLove"
// The latest RLV api version in versionnum format
#define RLV_NUM_CURRENT 2080100
// The lowest version of the RLV api that supports all features in core
#define RLV_NUM_SUPPORTED 2070000

// RLV command filters for old implementations of the specification commands starting with strings in this list should not be forwarded to older clients.
// Do not send these commands to viewers we know cannot possibly handle then.
#define RLV_PRE_2080000 [ "versionnumbl", "getblacklist" ]
#define RLV_PRE_2070000 [ "allwaysrun", "temprun" ] + RLV_PRE_2080000
#define RLV_PRE_2060100 [ "addoutfit:physics" ] + RLV_PRE_2070000
#define RLV_PRE_2060000 [ "startim", "startimto", "startim_sec", "touchme" ] + RLV_PRE_2060000
#define RLV_PRE_2050000 [ "attachallthisoverorreplace", "attachthisoverorreplace", "attachalloverorreplace", "attachoverorreplace", "detachthis_except", "detachallthis_except", "attachthis_except", "attachallthis_except", "setgroup", "getgroup", "touchworld:", "touchthis:" "unsharedwear", "unsharedunwear" ] + RLV_PRE_2060000
#define RLV_PRE_2040000 [ "touchfar", "touchall", "touchworld", "touchattach", "touchattachself", "touchattachother" ] + RLV_PRE_2050000

// Attachment point list
#define RLV_ATTACH_POINTS [ "chest", "skull", "left shoulder", "right shoulder", "left hand", "right hand", "left foot", "right foot", "spine", "pelvis", "mouth", "chin", "left ear", "right ear", "left eyeball", "right eyeball", "nose", "r upper arm", "r forearm", "l upper arm", "l forearm", "right hip", "r upper leg", "r lower leg", "left hip", "l upper leg", "l lower leg", "stomach", "left pec", "right pec", "center 2", "top right", "top", "top left", "center", "bottom left", "bottom", "bottom right", "neck", "root" ]
#define RLV_STRIP_TOP_POINTS [ "stomach", "left shoulder", "right shoulder", "left hand", "right hand", "r upper arm", "r forearm", "l upper arm", "l forearm", "chest", "left pec", "right pec" ]
#define RLV_STRIP_BOTTOM_POINTS [ "chin", "r upper leg", "r lower leg", "l upper leg", "l lower leg", "pelvis", "right hip", "left hip" ]
#define RLV_STRIP_SHOES_POINTS [ "l lower leg", "r lower leg", "right foot", "left foot" ]
#define RLV_STRIP_TOP_OUTFIT "remoutfit:gloves=force,remoutfit:jacket=force,remoutfit:shirt=force"
#define RLV_STRIP_BRA_OUTFIT "remoutfit:undershirt=force"
#define RLV_STRIP_BOTTOM_OUTFIT "remoutfit:skirt=force,remoutfit:pants=force"
#define RLV_STRIP_PANTIES_OUTFIT "remoutfit:underpants=force"
#define RLV_STRIP_SHOES_OUTFIT "remoutfit:shoes=force,remoutfit:socks=force"

#endif // RLV_API_LSL
