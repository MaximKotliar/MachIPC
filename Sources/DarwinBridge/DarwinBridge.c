//
//  DarwinBridge.c
//  SubProcess
//
//  Created by Maxim Kotliar on 12.11.2025.
//

#include "include/DarwinBridge.h"
#include <mach/mach.h>
#include <mach/message.h>


// Bridge function implementations
mach_msg_bits_t MACH_MSGH_BITS_REMOTE_BRIDGE(mach_msg_type_name_t remote) {
    return MACH_MSGH_BITS_REMOTE(remote);
}

mach_msg_bits_t MACH_MSGH_BITS_LOCAL_BRIDGE(mach_msg_type_name_t local) {
    return MACH_MSGH_BITS_LOCAL(local);
}

mach_msg_bits_t MACH_MSGH_BITS_BRIDGE(mach_msg_type_name_t remote, mach_msg_type_name_t local) {
    return MACH_MSGH_BITS(remote, local);
}
