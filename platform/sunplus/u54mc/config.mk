#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2019 Western Digital Corporation or its affiliates.
#
# Authors:
#   Atish Patra <atish.patra@wdc.com>
#

# Compiler flags
platform-cppflags-y =
platform-cflags-y =
platform-asflags-y =
platform-ldflags-y =


# Blobs to build
# needs to be 2MB align for 64-bit system 
FW_TEXT_START=0xA01D0000
FW_PAYLOAD=y
#next stage start addr, uboot addr is 0xA0100000, kernel addr is 0xA0200000,kernel addr need to 2M align
FW_PAYLOAD_OFFSET=-0xD0000  

#for xboot boot kernel,provide the FW_PAYLOAD_TYPE=kernel parameter to select this. 
FW_TEXT_START_KERNEL=0xA0200000

#used for kernel, uboot not used it
FW_PAYLOAD_FDT_ADDR=0xA01F0040

