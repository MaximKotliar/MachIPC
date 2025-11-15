//
//  DarwinBridge.h
//  SubProcess
//
//  Created by Maxim Kotliar on 12.11.2025.
//

#include <mach/mach.h>
#include <mach/message.h>

// Bridge functions for Mach IPC macros that aren't directly available in Swift

// MACH_MSGH_BITS_REMOTE macro wrapper
mach_msg_bits_t MACH_MSGH_BITS_REMOTE_BRIDGE(mach_msg_type_name_t remote);

// MACH_MSGH_BITS_LOCAL macro wrapper
mach_msg_bits_t MACH_MSGH_BITS_LOCAL_BRIDGE(mach_msg_type_name_t local);

// MACH_MSGH_BITS macro wrapper
mach_msg_bits_t MACH_MSGH_BITS_BRIDGE(mach_msg_type_name_t remote, mach_msg_type_name_t local);

// MACH_MSG_SIZE_MIN constant
extern const mach_msg_size_t MACH_MSG_SIZE_MIN_BRIDGE;

