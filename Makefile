CROSS_COMPILE ?= arm-linux-gnueabi-
SOURCE_DIR ?= $(CURDIR)/ANDROID_2.6.32
KBUILD_IMAGE ?= uImage
BUILD_DIR ?= $(CURDIR)/build
MYCONFIG ?= $(CURDIR)/configs/craig_clp281_wheezy
MYBPCONFIG ?= $(CURDIR)/configs/craig_clp281_wheezy_backports
KARCH=arm
SHELL = /bin/bash
BACKPORTS_SOURCE_DIR ?= $(CURDIR)/backports-3.10.19-1
KCFLAGS = -Wno-unused-but-set-variable -Wno-unused-function -Wno-unused-result -Wno-unused-value -Wno-unused-variable -Wno-declaration-after-statement
KDEB_EXTRAPKGVER = cshored1
KCONFIG_CONFIG ?= $(BUILD_DIR)/.config
BACKPORTS_CONFIG ?= $(BACKPORTS_SOURCE_DIR)/.config

define maybe_update_confnum
	set -e;	\
	oldmd5=$$(cat $(CURDIR)/config_md5sum); \
	newmd5=$$(sed -e 's/\s.*//' $(MYCONFIG) $(MYBPCONFIG) | sed -e 's/\#\s[^C]//' | md5sum); \
	if [ "$${oldmd5}" != "$${newmd5}" ]; then \
		if [ ! -r $(CURDIR)/localversion10confnum ]; then \
			rm -f $(CURDIR)/localversion10confnum; \
			echo .1 > $(CURDIR)/localversion10confnum; \
		else \
		mv $(CURDIR)/localversion10confnum $(CURDIR)/old_localversion10confnum; \
			echo ".""$$(expr $$(expr 0$$(cat $(CURDIR)/old_localversion10confnum) | tr '.' '0') + 1)" >$(CURDIR)/localversion10confnum; \
			rm -f $(BUILD_DIR)/localversion10confnum; \
		fi; \
		echo "$${newmd5}" > $(CURDIR)/config_md5sum; \
		cp -f $(CURDIR)/localversion10confnum $(BUILD_DIR)/localversion10confnum; \
		exit 2; \
	else \
		cp -f $(CURDIR)/localversion10confnum $(BUILD_DIR)/localversion10confnum; \
		exit 0; \
	fi
endef

J ?= X

SUBMAKEFLAGS = CROSS_COMPILE=$(CROSS_COMPILE) KBUILD_IMAGE=$(KBUILD_IMAGE)
CONFIG_SHELL := $(shell if [ -x "$$BASH" ]; then echo $$BASH; \
	else if [ -x /bin/bash ]; then echo /bin/bash; \
	else echo sh; fi ; fi)

srctree = $(SOURCE_DIR)
objtree = $(BUILD_DIR)

export KCFLAGS KDEB_EXTRAPKGVER srctree objtree

all: deb-pkg tarbz2-pkg

debug-mismatch:
	echo "-C $(BACKPORTS_SOURCE_DIR) KLIB_BUILD=$(BUILD_DIR) ARCH=$(KARCH) $(if $(J),-j) $(if $(V),V=$(V))" >$(BUILD_DIR)/pkg-backports-flags
	{ set -o pipefail; time sh -c "KERNELRELEASE=$$(cat $(BUILD_DIR)/include/config/kernel.release|tr -d ' \n') $(shell grep -m1 '^VERSION *= *' $(SOURCE_DIR)/Makefile|tr -d ' \n') $(shell grep -m1 '^PATCHLEVEL *= *' $(SOURCE_DIR)/Makefile|tr -d ' \n') $(shell grep -m1 '^SUBLEVEL *= *' $(SOURCE_DIR)/Makefile|tr -d ' \n') $(shell grep -m1 '^EXTRAVERSION *= *' $(SOURCE_DIR)/Makefile|tr -d ' \n') make -C $(BUILD_DIR) O=$(BUILD_DIR) CROSS_COMPILE=$(CROSS_COMPILE) KBUILD_IMAGE=$(KBUILD_IMAGE) CONFIG_SHELL=$(CONFIG_SHELL) $(if $(V),V=$(V)) ARCH=$(KARCH) $(if $(J),'-j') $(if $(V),V=$(V)) CONFIG_DEBUG_SECTION_MISMATCH=y" 2>&1 | tee build-debug-mismatch-$(shell sh -c "date -Iminutes|tr ':' '-'").log; }

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/include/config/auto.conf: $(BUILD_DIR) oldconfig
	make -C $(SOURCE_DIR) O=$(BUILD_DIR) MAKEFLAGS="$(SUBMAKEFLAGS)" include/config/auto.conf

$(BUILD_DIR)/include/config/kernel.release: $(BUILD_DIR)/include/config/auto.conf
	make -C $(SOURCE_DIR) O=$(BUILD_DIR) MAKEFLAGS="$(SUBMAKEFLAGS)" include/config/kernel.release

%-pkg: $(BUILD_DIR)/include/config/kernel.release $(KBUILD_IMAGE)
	cp $(CURDIR)/ANDROID_2.6.32_Driver_Obj/* $(BUILD_DIR)/. -arf
	{ set -o pipefail; time sh -c "KERNELRELEASE=$$(cat $(BUILD_DIR)/include/config/kernel.release|tr -d ' \n') $(shell grep -m1 '^VERSION *= *' $(SOURCE_DIR)/Makefile|tr -d ' \n') $(shell grep -m1 '^PATCHLEVEL *= *' $(SOURCE_DIR)/Makefile|tr -d ' \n') $(shell grep -m1 '^SUBLEVEL *= *' $(SOURCE_DIR)/Makefile|tr -d ' \n') $(shell grep -m1 '^EXTRAVERSION *= *' $(SOURCE_DIR)/Makefile|tr -d ' \n') make -C $(BUILD_DIR) -f $(SOURCE_DIR)/scripts/package/Makefile O=$(BUILD_DIR) CROSS_COMPILE=$(CROSS_COMPILE) KBUILD_IMAGE=$(KBUILD_IMAGE) CONFIG_SHELL=$(CONFIG_SHELL) $(if $(V),V=$(V)) ARCH=$(KARCH) $(if $(J),'-j') $(if $(V),V=$(V)) $@" 2>&1 | tee build-package-$@-$(shell sh -c "date -Iminutes|tr ':' '-'").log; }
	if [ -d $(BUILD_DIR) ] && [ -r $(BUILD_DIR)/.version ]; then cp -f $(BUILD_DIR)/.version $(CURDIR)/buildnum; fi

%config: $(BUILD_DIR)
	if [ -r $(BUILD_DIR)/.version ]; then cp -f $(BUILD_DIR)/.version $(CURDIR)/buildnum; fi
	if [ -r $(CURDIR)/buildnum ]; then cp -f $(CURDIR)/buildnum $(BUILD_DIR)/.version; fi
	echo "-wm8650" >$(BUILD_DIR)/localversion50platform
	cp -f $(MYCONFIG) $(BUILD_DIR)/.config
	make -C $(SOURCE_DIR) O=$(BUILD_DIR) MAKEFLAGS="$(SUBMAKEFLAGS)" $@
	$(call maybe_update_confnum) ; RET=$$? ; \
		if [ "$${RET}" = "2" ]; then \
			cp -f $(CURDIR)/localversion10confnum $(BUILD_DIR)/localversion10confnum; \
			cp -f $(BUILD_DIR)/.config $(MYCONFIG); \
		elif [ "$${RET}" != "0" ]; then \
			false; \
		fi

# The .config logic is 'borrowed' from the kernel source
# Without this unnecesary building occurs.
# To avoid any implicit rule to kick in, define an empty command
$(BUILD_DIR)/.config include/config/auto.conf.cmd: ;
# we execute the config step to be sure to catch updated Kconfig files
$(BUILD_DIR)/include/config/%.conf: $(BUILD_DIR)/.config $(BUILD_DIR)/include/config/auto.conf.cmd

# If .config is newer than include/config/auto.conf, someone tinkered
# with it and forgot to run make oldconfig.
# if auto.conf.cmd is missing then we are probably in a cleaned tree so
	make silentoldconfig

$(KCONFIG_CONFIG): oldconfig

$(BACKPORTS_CONFIG): $(KCONFIG_CONFIG) backports-oldconfig

$(KBUILD_IMAGE): $(KCONFIG_CONFIG) $(BACKPORTS_CONFIG)
	echo "-C $(BACKPORTS_SOURCE_DIR) KLIB_BUILD=$(BUILD_DIR) ARCH=$(KARCH) $(if $(J),-j) $(if $(V),V=$(V))" >$(BUILD_DIR)/pkg-backports-flags
	cp $(CURDIR)/ANDROID_2.6.32_Driver_Obj/* $(BUILD_DIR)/. -arf
	{ set -o pipefail; time sh -c "KERNELRELEASE=$$(cat $(BUILD_DIR)/include/config/kernel.release|tr -d ' \n') $(shell grep -m1 '^VERSION *= *' $(SOURCE_DIR)/Makefile|tr -d ' \n') $(shell grep -m1 '^PATCHLEVEL *= *' $(SOURCE_DIR)/Makefile|tr -d ' \n') $(shell grep -m1 '^SUBLEVEL *= *' $(SOURCE_DIR)/Makefile|tr -d ' \n') $(shell grep -m1 '^EXTRAVERSION *= *' $(SOURCE_DIR)/Makefile|tr -d ' \n') make -C $(BUILD_DIR) O=$(BUILD_DIR) CROSS_COMPILE=$(CROSS_COMPILE) KBUILD_IMAGE=$(KBUILD_IMAGE) CONFIG_SHELL=$(CONFIG_SHELL) $(if $(V),V=$(V)) ARCH=$(KARCH) $(if $(J),'-j') $(if $(V),V=$(V)) $@" 2>&1 | tee build-kernel-$@-$(shell sh -c "date -Iminutes|tr ':' '-'").log; }
	if [ -d $(BUILD_DIR) ] && [ -r $(BUILD_DIR)/.version ]; then cp -f $(BUILD_DIR)/.version $(CURDIR)/buildnum; fi

modules:
	cp $(CURDIR)/ANDROID_2.6.32_Driver_Obj/* $(BUILD_DIR)/. -arf
	{ set -o pipefail; time sh -c "KERNELRELEASE=$$(cat $(BUILD_DIR)/include/config/kernel.release|tr -d ' \n') $(shell grep -m1 '^VERSION *= *' $(SOURCE_DIR)/Makefile|tr -d ' \n') $(shell grep -m1 '^PATCHLEVEL *= *' $(SOURCE_DIR)/Makefile|tr -d ' \n') $(shell grep -m1 '^SUBLEVEL *= *' $(SOURCE_DIR)/Makefile|tr -d ' \n') $(shell grep -m1 '^EXTRAVERSION *= *' $(SOURCE_DIR)/Makefile|tr -d ' \n') make -C $(BUILD_DIR) O=$(BUILD_DIR) CROSS_COMPILE=$(CROSS_COMPILE) KBUILD_IMAGE=$(KBUILD_IMAGE) CONFIG_SHELL=$(CONFIG_SHELL) $(if $(V),V=$(V)) ARCH=$(KARCH) $(if $(J),'-j') $(if $(V),V=$(V)) $@" 2>&1 | tee build-modules-$@-$(shell sh -c "date -Iminutes|tr ':' '-'").log; }

backports-%config:
	if [ ! -r $(BUILD_DIR)/.config ]; then exit 1; fi # Error config if we haven't used main kernel %config already
	cp -f $(MYBPCONFIG) $(BACKPORTS_SOURCE_DIR)/.config
	make -C $(BACKPORTS_SOURCE_DIR) KLIB_BUILD=$(BUILD_DIR) CROSS_COMPILE=$(CROSS_COMPILE) ARCH=$(KARCH) MAKEFLAGS="$(SUBMAKEFLAGS) $(BPSUB)" $(subst backports-,,$@)
	$(call maybe_update_confnum) ; RET=$$? ; \
		if [ "${RET}" = "1" ]; then \
			false; \
		elif [ "${RET}" = "2" ]; then \
			cp -f $(CURDIR)/localversion10confnum $(BUILD_DIR)/localversion10confnum; \
			cp -f $(BACKPORTS_SOURCE_DIR)/.config $(MYBPCONFIG); \
		fi

backports:
	make -C $(BACKPORTS_SOURCE_DIR) KLIB_BUILD=$(BUILD_DIR) CROSS_COMPILE=$(CROSS_COMPILE) ARCH=$(KARCH) MAKEFLAGS="$(SUBMAKEFLAGS) $(BPSUB)" modules

backports-clean:
	-make -C $(BACKPORTS_SOURCE_DIR) KLIB_BUILD=$(BUILD_DIR) CROSS_COMPILE=$(CROSS_COMPILE) ARCH=$(KARCH) MAKEFLAGS="$(SUBMAKEFLAGS) $(BPSUB)" clean

backports-distclean:
	-make -C $(BACKPORTS_SOURCE_DIR) KLIB_BUILD=$(BUILD_DIR) CROSS_COMPILE=$(CROSS_COMPILE) ARCH=$(KARCH) MAKEFLAGS="$(SUBMAKEFLAGS) $(BPSUB)" distclean

backports-mrproper:
	make -C $(BACKPORTS_SOURCE_DIR) KLIB_BUILD=$(BUILD_DIR) CROSS_COMPILE=$(CROSS_COMPILE) ARCH=$(KARCH) MAKEFLAGS="$(SUBMAKEFLAGS) $(BPSUB)" mrproper

clean: backports-clean
	rm -f *.log
	rm -f *.deb
	rm -f *.tar.*
	if [ -r $(BUILD_DIR)/.version ]; then cp -f $(BUILD_DIR)/.version $(CURDIR)/buildnum; fi
	rm -rf $(BUILD_DIR)

mrproper: backports-mrproper
	make -C $(SOURCE_DIR) CROSS_COMPILE=$(CROSS_COMPILE) ARCH=$(KARCH) MAKEFLAGS="$(SUBMAKEFLAGS)" mrproper
	make -C $(BACKPORTS_SOURCE_DIR) KLIB_BUILD=$(BUILD_DIR) CROSS_COMPILE=$(CROSS_COMPILE) ARCH=$(KARCH) MAKEFLAGS="$(SUBMAKEFLAGS) $(BPSUB)" mrproper

distclean: clean backports-distclean
	make -C $(SOURCE_DIR) CROSS_COMPILE=$(CROSS_COMPILE) ARCH=$(KARCH) MAKEFLAGS="$(SUBMAKEFLAGS)" distclean

