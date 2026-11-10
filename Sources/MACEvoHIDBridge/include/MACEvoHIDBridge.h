#include <CoreGraphics/CoreGraphics.h>
#include <stdbool.h>
#include <stdint.h>
// Undocumented macOS symbols are optional and resolved at runtime.
bool MACEvoHasSenderAttribution(void);
uint64_t MACEvoEventSender(CGEventRef event);
