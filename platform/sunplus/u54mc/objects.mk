#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2019 Western Digital Corporation or its affiliates.
#
# Authors:
#   Atish Patra <atish.patra@wdc.com>
#

platform-objs-y += platform.o
ifdef U54MC_ENABLED_HART_MASK
platform-genflags-y += -DU54MC_ENABLED_HART_MASK=$(U54MC_ENABLED_HART_MASK)
endif

