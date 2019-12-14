CROSS_COMPILE ?= arm-linux-gnueabi-

SOURCE_DIR ?= ANDROID_2.6.32
KBUILD_IMAGE ?= uImage
BUILD_DIR ?= $(CURDIR)/build
KCONFIG_CONFIG ?= $(CURDIR)/configs/craig_clp281_wheezy_noinitrd
KARCH=arm
SHELL = /bin/bash
KDEB_PKGVERSION=\$$\$$(KERNELVERSION).\$$\$$(PATCHLEVEL)-\$$\$$(SUBLEVEL)-\$$\$$(KERNELVERSION).\$$\$$(PATCHLEVEL).\$$\$$(SUBLEVEL).\$$\$$(EXTRAVERSION)-\$$\$$(localver)~cshored1

override SUBMAKEFLAGS := CROSS_COMPILE=$(CROSS_COMPILE) KBUILD_IMAGE=$(KBUILD_IMAGE) KCONFIG_CONFIG=$(KCONFIG_CONFIG) SHELL=$(SHELL) $(if $(J),-j) KDEB_PKGVERSION=$(KDEB_PKGVERSION)

all: $(BUILD_DIR) deb-pkg tarbz2-pkg

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

%-pkg:
	make -C $(SOURCE_DIR) O=$(BUILD_DIR) MAKEFLAGS="$(SUBMAKEFLAGS)" $(BUILD_DIR)/include/config/auto.conf
	cp ANDROID_2.6.32_Driver_Obj/* $(BUILD_DIR)/. -arf
	{ set -o pipefail ; time make -C $(BUILD_DIR) O=$(BUILD_DIR) MAKEFLAGS="$(SUBMAKEFLAGS)" $@ 2>&1 | tee build-$@-$(shell sh -c "date -Iminutes|tr ':' '-'").log; }

%config:
	mkdir -p $(BUILD_DIR)
	make -C $(SOURCE_DIR) O=$(BUILD_DIR) MAKEFLAGS="$(SUBMAKEFLAGS)" $@

# The KCONFIG_CONFIG logic is 'borrowed' from the kernel source
# Without this unnecesary building occurs.
# To avoid any implicit rule to kick in, define an empty command
$(KCONFIG_CONFIG) include/config/auto.conf.cmd: ;

# If .config is newer than include/config/auto.conf, someone tinkered
# with it and forgot to run make oldconfig.
# if auto.conf.cmd is missing then we are probably in a cleaned tree so
# we execute the config step to be sure to catch updated Kconfig files
$(BUILD_DIR)/include/config/%.conf: $(KCONFIG_CONFIG) $(BUILD_DIR)/include/config/auto.conf.cmd
	make silentoldconfig

$(KBUILD_IMAGE): $(KCONFIG_CONFIG)
	cp ANDROID_2.6.32_Driver_Obj/* $(BUILD_DIR)/. -arf
	{ set -o pipefail ; time make -C $(BUILD_DIR) MAKEFLAGS="$(SUBMAKEFLAGS)" $@ 2>&1 | tee build-$(BUILD_IMAGE)-$@-$(shell sh -c "date -Iminutes|tr ':' '-'").log; }

modules:
	cp ANDROID_2.6.32_Driver_Obj/* $(BUILD_DIR)/. -arf
	{ set -o pipefail ; time make -C $(BUILD_DIR) MAKEFLAGS="$(SUBMAKEFLAGS)" $@ 2>&1 | tee build-modules-$@-$(shell sh -c "date -Iminutes|tr ':' '-'").log; }

clean:	
	rm -f *.log
	rm -f *.deb
	rm -rf $(BUILD_DIR)

mrproper:
	make -C ANDROID_2.6.32 mrproper

distclean: clean
	make -C ANDROID_2.6.32 distclean

