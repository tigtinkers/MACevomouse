#include "MACEvoHIDBridge.h"
#include <dlfcn.h>
#include <pthread.h>

typedef CFTypeRef (*CopyHIDEvent)(CGEventRef);
typedef uint64_t (*SenderID)(CFTypeRef);
static CopyHIDEvent copyEvent;
static SenderID senderID;
static pthread_once_t once = PTHREAD_ONCE_INIT;
static void resolveOnce(void) {
    copyEvent = (CopyHIDEvent)dlsym(RTLD_DEFAULT, "CGEventCopyIOHIDEvent");
    senderID = (SenderID)dlsym(RTLD_DEFAULT, "IOHIDEventGetSenderID");
}
static void resolve(void) { pthread_once(&once, resolveOnce); }
bool MACEvoHasSenderAttribution(void) { resolve(); return copyEvent && senderID; }
uint64_t MACEvoEventSender(CGEventRef event) {
    if (!event || !MACEvoHasSenderAttribution()) return 0;
    CFTypeRef hid = copyEvent(event);
    if (!hid) return 0;
    uint64_t result = senderID(hid);
    CFRelease(hid);
    return result;
}
