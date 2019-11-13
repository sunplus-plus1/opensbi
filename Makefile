#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2019 Western Digital Corporation or its affiliates.
#
# Authors:
#   Anup Patel <anup.patel@wdc.com>
#

# Select Make Options:
# o  Do not use make's built-in rules
# o  Do not print "Entering directory ...";
MAKEFLAGS += -r --no-print-directory

PLATFORM=sunplus/u54mc
GENFLAGS = 
# Find out source, build, and install directories
src_dir=$(CURDIR)
ifdef O
 build_dir=$(shell readlink -f $(O))
else
 build_dir=$(CURDIR)/build
endif
ifeq ($(build_dir),$(CURDIR))
$(error Build directory is same as source directory.)
endif
ifdef I
 install_dir=$(shell readlink -f $(I))
else
 install_dir=$(CURDIR)/install
endif
ifeq ($(install_dir),$(CURDIR))
$(error Install directory is same as source directory.)
endif
ifeq ($(install_dir),$(build_dir))
$(error Install directory is same as build directory.)
endif
ifdef PLATFORM_DIR
  platform_dir_path=$(shell readlink -f $(PLATFORM_DIR))
  ifdef PLATFORM
    platform_parent_dir=$(platform_dir_path)
  else
    PLATFORM=$(shell basename $(platform_dir_path))
    platform_parent_dir=$(subst $(PLATFORM),,$(platform_dir_path))
  endif
else
 platform_parent_dir=$(src_dir)/platform
endif

# Check if verbosity is ON for build process
CMD_PREFIX_DEFAULT := @
ifeq ($(V), 1)
	CMD_PREFIX :=
else
	CMD_PREFIX := $(CMD_PREFIX_DEFAULT)
endif


# Setup path of directories
export platform_subdir=$(PLATFORM)
export platform_src_dir=$(platform_parent_dir)/$(platform_subdir)
export platform_build_dir=$(build_dir)/platform/$(platform_subdir)
export include_dir=$(CURDIR)/include
export libsbi_dir=$(CURDIR)/lib/sbi
export libsbiutils_dir=$(CURDIR)/lib/utils
export firmware_dir=$(CURDIR)/firmware

# Find library version
OPENSBI_VERSION_MAJOR=`grep "define OPENSBI_VERSION_MAJOR" $(include_dir)/sbi/sbi_version.h | sed 's/.*MAJOR.*\([0-9][0-9]*\)/\1/'`
OPENSBI_VERSION_MINOR=`grep "define OPENSBI_VERSION_MINOR" $(include_dir)/sbi/sbi_version.h | sed 's/.*MINOR.*\([0-9][0-9]*\)/\1/'`
OPENSBI_VERSION_GIT=$(shell if [ -d $(src_dir)/.git ]; then git describe 2> /dev/null; fi)

# Setup compilation commands

ifdef CROSS_COMPILE
CC		=	$(CROSS_COMPILE)gcc
CPP		=	$(CROSS_COMPILE)cpp
AR		=	$(CROSS_COMPILE)ar
LD		=	$(CROSS_COMPILE)ld
OBJCOPY		=	$(CROSS_COMPILE)objcopy
OBJDUMP		=	$(CROSS_COMPILE)objdump
else
CC		?=	gcc
CPP		?=	cpp
AR		?=	ar
LD		?=	ld
OBJCOPY		?=	objcopy
endif
AS		=	$(CC)
DTC		=	dtc

# Guess the compillers xlen
OPENSBI_CC_XLEN := $(shell TMP=`$(CC) -dumpmachine | sed 's/riscv\([0-9][0-9]\).*/\1/'`; echo $${TMP})

# Setup platform XLEN
ifndef PLATFORM_RISCV_XLEN
  ifeq ($(OPENSBI_CC_XLEN), 32)
    PLATFORM_RISCV_XLEN = 32
  else
    PLATFORM_RISCV_XLEN = 64
  endif
endif

# Setup list of objects.mk files
ifdef PLATFORM
platform-object-mks=$(shell if [ -d $(platform_src_dir)/ ]; then find $(platform_src_dir) -iname "objects.mk" | sort -r; fi)
endif
libsbi-object-mks=$(shell if [ -d $(libsbi_dir) ]; then find $(libsbi_dir) -iname "objects.mk" | sort -r; fi)
libsbiutils-object-mks=$(shell if [ -d $(libsbiutils_dir) ]; then find $(libsbiutils_dir) -iname "objects.mk" | sort -r; fi)
firmware-object-mks=$(shell if [ -d $(firmware_dir) ]; then find $(firmware_dir) -iname "objects.mk" | sort -r; fi)

# Include platform specifig config.mk

ifdef PLATFORM
include $(platform_src_dir)/config.mk
endif

# Include all object.mk files
ifdef PLATFORM
include $(platform-object-mks)
endif
include $(libsbi-object-mks)
include $(libsbiutils-object-mks)
include $(firmware-object-mks)

# Setup list of objects
libsbi-objs-path-y=$(foreach obj,$(libsbi-objs-y),$(build_dir)/lib/sbi/$(obj))
libsbiutils-objs-path-y=$(foreach obj,$(libsbiutils-objs-y),$(build_dir)/lib/utils/$(obj))
ifdef PLATFORM
platform-objs-path-y=$(foreach obj,$(platform-objs-y),$(platform_build_dir)/$(obj))
platform-dtb-path-y=$(foreach obj,$(platform-dtb-y),$(platform_build_dir)/$(obj))
firmware-bins-path-y=$(foreach bin,$(firmware-bins-y),$(platform_build_dir)/firmware/$(bin))
endif
firmware-elfs-path-y=$(firmware-bins-path-y:.bin=.elf)
firmware-objs-path-y=$(firmware-bins-path-y:.bin=.o)

# Setup list of deps files for objects
deps-y=$(platform-objs-path-y:.o=.dep)
deps-y+=$(libsbi-objs-path-y:.o=.dep)
deps-y+=$(libsbiutils-objs-path-y:.o=.dep)
deps-y+=$(firmware-objs-path-y:.o=.dep)

# Setup platform ABI, ISA and Code Model
ifndef PLATFORM_RISCV_ABI
  ifeq ($(PLATFORM_RISCV_XLEN), 32)
    PLATFORM_RISCV_ABI = ilp$(PLATFORM_RISCV_XLEN)
  else
    PLATFORM_RISCV_ABI = lp$(PLATFORM_RISCV_XLEN)
  endif
endif
ifndef PLATFORM_RISCV_ISA
  PLATFORM_RISCV_ISA = rv$(PLATFORM_RISCV_XLEN)imafdc
endif
ifndef PLATFORM_RISCV_CODE_MODEL
  PLATFORM_RISCV_CODE_MODEL = medany
endif

# Setup compilation commands flags
GENFLAGS	=	-I$(platform_src_dir)/include
GENFLAGS	+=	-I$(include_dir)
ifneq ($(OPENSBI_VERSION_GIT),)
GENFLAGS	+=	-DOPENSBI_VERSION_GIT="\"$(OPENSBI_VERSION_GIT)\""
endif
ifeq ($(FW_PAYLOAD_TYPE), kernel)
GENFLAGS 	+=	-DFW_PAYLOAD_TYPE
endif
GENFLAGS	+=	$(libsbiutils-genflags-y)
GENFLAGS	+=	$(platform-genflags-y)
GENFLAGS	+=	$(firmware-genflags-y)

CFLAGS		=	-g -Wall -Werror -nostdlib -fno-strict-aliasing -O2
CFLAGS		+=	-fno-omit-frame-pointer -fno-optimize-sibling-calls
CFLAGS		+=	-mno-save-restore -mstrict-align
CFLAGS		+=	-mabi=$(PLATFORM_RISCV_ABI) -march=$(PLATFORM_RISCV_ISA)
CFLAGS		+=	-mcmodel=$(PLATFORM_RISCV_CODE_MODEL)
CFLAGS		+=	$(GENFLAGS)
CFLAGS		+=	$(platform-cflags-y)
CFLAGS		+=	$(firmware-cflags-y)
CFLAGS		+=	-fno-pie -no-pie

CPPFLAGS	+=	$(GENFLAGS)
CPPFLAGS	+=	$(platform-cppflags-y)
CPPFLAGS	+=	$(firmware-cppflags-y)

ASFLAGS		=	-g -Wall -nostdlib -D__ASSEMBLY__
ASFLAGS		+=	-fno-omit-frame-pointer -fno-optimize-sibling-calls
ASFLAGS		+=	-mno-save-restore -mstrict-align
ASFLAGS		+=	-mabi=$(PLATFORM_RISCV_ABI) -march=$(PLATFORM_RISCV_ISA)
ASFLAGS		+=	-mcmodel=$(PLATFORM_RISCV_CODE_MODEL)
ASFLAGS		+=	$(GENFLAGS)
ASFLAGS		+=	$(platform-asflags-y)
ASFLAGS		+=	$(firmware-asflags-y)

ARFLAGS		=	rcs

ELFFLAGS	+=	-Wl,--build-id=none -N -static-libgcc -lgcc
ELFFLAGS	+=	$(platform-ldflags-y)
ELFFLAGS	+=	$(firmware-ldflags-y)

MERGEFLAGS	+=	-r
MERGEFLAGS	+=	-b elf$(PLATFORM_RISCV_XLEN)-littleriscv
MERGEFLAGS	+=	-m elf$(PLATFORM_RISCV_XLEN)lriscv

DTCFLAGS	=	-O dtb

# Setup functions for compilation
define dynamic_flags
-I$(shell dirname $(2)) -D__OBJNAME__=$(subst -,_,$(shell basename $(1) .o))
endef
merge_objs = $(CMD_PREFIX)mkdir -p `dirname $(1)`; \
	     echo " MERGE     $(subst $(build_dir)/,,$(1))"; \
	     $(LD) $(MERGEFLAGS) $(2) -o $(1)
merge_deps = $(CMD_PREFIX)mkdir -p `dirname $(1)`; \
	     echo " MERGE-DEP $(subst $(build_dir)/,,$(1))"; \
	     cat $(2) > $(1)
copy_file =  $(CMD_PREFIX)mkdir -p `dirname $(1)`; \
	     echo " COPY      $(subst $(build_dir)/,,$(1))"; \
	     cp -f $(2) $(1)
inst_file =  $(CMD_PREFIX)mkdir -p `dirname $(1)`; \
	     echo " INSTALL   $(subst $(install_dir)/,,$(1))"; \
	     cp -f $(2) $(1)
inst_file_list = $(CMD_PREFIX)if [ ! -z "$(4)" ]; then \
	     mkdir -p $(1)/$(3); \
	     for file in $(4) ; do \
	     rel_file=`echo $$file | sed -e 's@$(2)/$(3)/@@'`; \
	     dest_file=$(1)"/"$(3)"/"`echo $$rel_file`; \
	     dest_dir=`dirname $$dest_file`; \
	     echo " INSTALL   "$(3)"/"`echo $$rel_file`; \
	     mkdir -p $$dest_dir; \
	     cp -f $$file $$dest_file; \
	     done \
	     fi
inst_header_dir =  $(CMD_PREFIX)mkdir -p $(1); \
	     echo " INSTALL   $(subst $(install_dir)/,,$(1))"; \
	     cp -rf $(2) $(1)
compile_cpp = $(CMD_PREFIX)mkdir -p `dirname $(1)`; \
	     echo " CPP       $(subst $(build_dir)/,,$(1))"; \
	     $(CPP) $(CPPFLAGS) -x c $(2) | grep -v "\#" > $(1)
compile_cc_dep = $(CMD_PREFIX)mkdir -p `dirname $(1)`; \
	     echo " CC-DEP    $(subst $(build_dir)/,,$(1))"; \
	     printf %s `dirname $(1)`/  > $(1) && \
	     $(CC) $(CFLAGS) $(call dynamic_flags,$(1),$(2))   \
	       -MM $(2) >> $(1) || rm -f $(1)
compile_cc = $(CMD_PREFIX)mkdir -p `dirname $(1)`; \
	     echo " CC        $(subst $(build_dir)/,,$(1))"; \
	     $(CC) $(CFLAGS) $(call dynamic_flags,$(1),$(2)) -c $(2) -o $(1)
compile_as_dep = $(CMD_PREFIX)mkdir -p `dirname $(1)`; \
	     echo " AS-DEP    $(subst $(build_dir)/,,$(1))"; \
	     printf %s `dirname $(1)`/ > $(1) && \
	     $(AS) $(ASFLAGS) $(call dynamic_flags,$(1),$(2)) \
	       -MM $(2) >> $(1) || rm -f $(1)
compile_as = $(CMD_PREFIX)mkdir -p `dirname $(1)`; \
	     echo " AS        $(subst $(build_dir)/,,$(1))"; \
	     $(AS) $(ASFLAGS) $(call dynamic_flags,$(1),$(2)) -c $(2) -o $(1)
compile_elf = $(CMD_PREFIX)mkdir -p `dirname $(1)`; \
	     echo " ELF       $(subst $(build_dir)/,,$(1))"; \
	     $(CC) $(CFLAGS) $(3) $(ELFFLAGS) -Wl,-T$(2) -o $(1)
compile_ar = $(CMD_PREFIX)mkdir -p `dirname $(1)`; \
	     echo " AR        $(subst $(build_dir)/,,$(1))"; \
	     $(AR) $(ARFLAGS) $(1) $(2)
compile_objcopy = $(CMD_PREFIX)mkdir -p `dirname $(1)`; \
	     echo " OBJCOPY   $(subst $(build_dir)/,,$(1))"; \
	     $(OBJCOPY) -S -O binary $(2) $(1)
compile_dts = $(CMD_PREFIX)mkdir -p `dirname $(1)`; \
	     echo " DTC       $(subst $(build_dir)/,,$(1))"; \
	     $(DTC) $(DTCFLAGS) -o $(1) $(2)

targets-y  = $(build_dir)/lib/libsbi.a
targets-y  += $(build_dir)/lib/libsbiutils.a
ifdef PLATFORM
targets-y += $(platform_build_dir)/lib/libplatsbi.a
targets-y += $(platform-dtb-path-y)
endif
targets-y += $(firmware-bins-path-y)

OUT = out
# Default rule "make" should always be first rule
.PHONY: all
all:   $(targets-y) 
	$(CMD_PREFIX)rm -rf $(OUT) 
	$(CMD_PREFIX)mkdir $(OUT)
	$(CMD_PREFIX)cp $(platform_build_dir)/firmware/* $(OUT) -rf

# Preserve all intermediate files
.SECONDARY:

$(build_dir)/%.bin: $(build_dir)/%.elf
	$(call compile_objcopy,$@,$<)

$(build_dir)/%.elf: $(build_dir)/%.o $(build_dir)/%.elf.ld $(platform_build_dir)/lib/libplatsbi.a
	$(call compile_elf,$@,$@.ld,$< $(platform_build_dir)/lib/libplatsbi.a)

$(platform_build_dir)/%.ld: $(src_dir)/%.ldS
	$(call compile_cpp,$@,$<)

$(build_dir)/lib/libsbi.a: $(libsbi-objs-path-y)
	$(call compile_ar,$@,$^)

$(build_dir)/lib/libsbiutils.a: $(libsbi-objs-path-y) $(libsbiutils-objs-path-y)
	$(call compile_ar,$@,$^)

$(platform_build_dir)/lib/libplatsbi.a: $(libsbi-objs-path-y) $(libsbiutils-objs-path-y) $(platform-objs-path-y)
	$(call compile_ar,$@,$^)

$(build_dir)/%.dep: $(src_dir)/%.c
	$(call compile_cc_dep,$@,$<)

$(build_dir)/%.o: $(src_dir)/%.c
	$(call compile_cc,$@,$<)

$(build_dir)/%.dep: $(src_dir)/%.S
	$(call compile_as_dep,$@,$<)

$(build_dir)/%.o: $(src_dir)/%.S
	$(call compile_as,$@,$<)

$(platform_build_dir)/%.dep: $(platform_src_dir)/%.c
	$(call compile_cc_dep,$@,$<)

$(platform_build_dir)/%.o: $(platform_src_dir)/%.c
	$(call compile_cc,$@,$<)

$(platform_build_dir)/%.dep: $(platform_src_dir)/%.S
	$(call compile_as_dep,$@,$<)

$(platform_build_dir)/%.o: $(platform_src_dir)/%.S
	$(call compile_as,$@,$<)

$(platform_build_dir)/%.dep: $(src_dir)/%.c
	$(call compile_cc_dep,$@,$<)

$(platform_build_dir)/%.o: $(src_dir)/%.c
	$(call compile_cc,$@,$<)

$(platform_build_dir)/%.dep: $(src_dir)/%.S
	$(call compile_as_dep,$@,$<)

$(platform_build_dir)/%.o: $(src_dir)/%.S
	$(call compile_as,$@,$<)

$(build_dir)/%.dtb: $(src_dir)/%.dts
	$(call compile_dts,$@,$<)


# Rule for "make docs"
$(build_dir)/docs/latex/refman.pdf: $(build_dir)/docs/latex/refman.tex
	$(CMD_PREFIX)mkdir -p $(build_dir)/docs
	$(CMD_PREFIX)$(MAKE) -C $(build_dir)/docs/latex
$(build_dir)/docs/latex/refman.tex: $(build_dir)/docs/doxygen.cfg
	$(CMD_PREFIX)mkdir -p $(build_dir)/docs
	$(CMD_PREFIX)doxygen $(build_dir)/docs/doxygen.cfg
$(build_dir)/docs/doxygen.cfg: $(src_dir)/docs/doxygen.cfg
	$(CMD_PREFIX)mkdir -p $(build_dir)/docs
	$(CMD_PREFIX)cat docs/doxygen.cfg | sed -e "s#@@SRC_DIR@@#$(src_dir)#" -e "s#@@BUILD_DIR@@#$(build_dir)#" -e "s#@@OPENSBI_MAJOR@@#$(OPENSBI_VERSION_MAJOR)#" -e "s#@@OPENSBI_MINOR@@#$(OPENSBI_VERSION_MINOR)#" > $(build_dir)/docs/doxygen.cfg
.PHONY: docs
docs: $(build_dir)/docs/latex/refman.pdf

# Dependency files should only be included after default Makefile rules
# They should not be included for any "xxxconfig" or "xxxclean" rule
all-deps-1 = $(if $(findstring config,$(MAKECMDGOALS)),,$(deps-y))
all-deps-2 = $(if $(findstring clean,$(MAKECMDGOALS)),,$(all-deps-1))
-include $(all-deps-2)

# Include external dependency of firmwares after default Makefile rules
include $(src_dir)/firmware/external_deps.mk

# Convenient "make run" command for emulated platforms
.PHONY: run
run: all
ifneq ($(platform-runcmd),)
	$(platform-runcmd) $(RUN_ARGS)
else
ifdef PLATFORM
	@echo "Platform $(PLATFORM) doesn't specify a run command"
	@false
else
	@echo Run command only available when targeting a platform
	@false
endif
endif

install_targets-y  = install_libsbi
install_targets-y  += install_libsbiutils
ifdef PLATFORM
install_targets-y += install_libplatsbi
install_targets-y += install_firmwares
endif

.PHONY: dump
dump:
	    @$(OBJDUMP) -d -S out/fw_payload.elf>out/fw_payload.dis
# Rule for "make install"
.PHONY: install
install: $(install_targets-y)

.PHONY: install_libsbi
install_libsbi: $(build_dir)/lib/libsbi.a
	$(call inst_header_dir,$(install_dir)/include,$(include_dir)/sbi)
	$(call inst_file,$(install_dir)/lib/libsbi.a,$(build_dir)/lib/libsbi.a)

.PHONY: install_libsbiutils
install_libsbiutils: $(build_dir)/lib/libsbiutils.a
	$(call inst_header_dir,$(install_dir)/include,$(include_dir)/sbi_utils)
	$(call inst_file,$(install_dir)/lib/libsbiutils.a,$(build_dir)/lib/libsbiutils.a)

.PHONY: install_libplatsbi
install_libplatsbi: $(platform_build_dir)/lib/libplatsbi.a $(build_dir)/lib/libsbi.a $(build_dir)/lib/libsbiutils.a
	$(call inst_file,$(install_dir)/platform/$(platform_subdir)/lib/libplatsbi.a,$(platform_build_dir)/lib/libplatsbi.a)

.PHONY: install_firmwares
install_firmwares: $(platform_build_dir)/lib/libplatsbi.a $(build_dir)/lib/libsbi.a $(build_dir)/lib/libsbiutils.a $(firmware-bins-path-y)
	$(call inst_file_list,$(install_dir),$(build_dir),platform/$(platform_subdir)/firmware,$(firmware-elfs-path-y))
	$(call inst_file_list,$(install_dir),$(build_dir),platform/$(platform_subdir)/firmware,$(firmware-bins-path-y))

.PHONY: install_docs
install_docs: $(build_dir)/docs/latex/refman.pdf
	$(call inst_file,$(install_dir)/docs/refman.pdf,$(build_dir)/docs/latex/refman.pdf)

# Rule for "make clean"
.PHONY: clean
clean:
	$(CMD_PREFIX)rm -rf $(OUT) 
	$(CMD_PREFIX)mkdir -p $(build_dir)
	$(if $(V), @echo " RM        $(build_dir)/*.o")
	$(CMD_PREFIX)find $(build_dir) -type f -name "*.o" -exec rm -rf {} +
	$(if $(V), @echo " RM        $(build_dir)/*.a")
	$(CMD_PREFIX)find $(build_dir) -type f -name "*.a" -exec rm -rf {} +
	$(if $(V), @echo " RM        $(build_dir)/*.elf")
	$(CMD_PREFIX)find $(build_dir) -type f -name "*.elf" -exec rm -rf {} +
	$(if $(V), @echo " RM        $(build_dir)/*.bin")
	$(CMD_PREFIX)find $(build_dir) -type f -name "*.bin" -exec rm -rf {} +

# Rule for "make distclean"
.PHONY: distclean
distclean: clean
	$(CMD_PREFIX)mkdir -p $(build_dir)
	$(if $(V), @echo " RM        $(build_dir)/*.dep")
	$(CMD_PREFIX)find $(build_dir) -type f -name "*.dep" -exec rm -rf {} +
ifeq ($(build_dir),$(CURDIR)/build)
	$(if $(V), @echo " RM        $(build_dir)")
	$(CMD_PREFIX)rm -rf $(build_dir)
endif
ifeq ($(install_dir),$(CURDIR)/install)
	$(if $(V), @echo " RM        $(install_dir)")
	$(CMD_PREFIX)rm -rf $(install_dir)
endif
