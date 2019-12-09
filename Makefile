ifdef DOCROSS
CROSS_COMPILE ?= arm-linux-gnueabi-
endif

KBUILD_IMAGE ?= uImage
BUILD_DIR ?= $(CURDIR)/build
KCONFIG_CONFIG ?= $(CURDIR)/configs/craig_clp281_wheezy_noinitrd
SHELL = /bin/bash

override MAKEFLAGS := CROSS_COMPILE=$(CROSS_COMPILE) KBUILD_IMAGE=$(KBUILD_IMAGE) KCONFIG_CONFIG=$(KCONFIG_CONFIG) SHELL=$(SHELL) $(if $(J),-j)

all: deb-pkg

%config:
	mkdir -p $(BUILD_DIR)
	make -C ANDROID_2.6.32 O=$(BUILD_DIR) MAKEFLAGS="$(MAKEFLAGS)" $@

%-pkg: $(KCONFIG_CONFIG)
	{ set -o pipefail ; time make -C $(BUILD_DIR) O=$(BUILD_DIR) MAKEFLAGS="$(MAKEFLAGS)" $@ 2>&1 | tee build-$@-$(shell sh -c "date -Iminutes|tr ':' '-'").log; }

deb-pkg: tarbz2-pkg

$(KCONFIG_CONFIG): silentoldconfig

$(KBUILD_IMAGE): $(KCONFIG_CONFIG)
	{ set -o pipefail ; time make -C $(BUILD_DIR) MAKEFLAGS="$(MAKEFLAGS)" $@ 2>&1 | tee build-$(BUILD_IMAGE)-$@-$(shell sh -c "date -Iminutes|tr ':' '-'").log; }

modules:
	{ set -o pipefail ; time make -C $(BUILD_DIR) MAKEFLAGS="$(MAKEFLAGS)" $@ 2>&1 | tee build-modules-$@-$(shell sh -c "date -Iminutes|tr ':' '-'").log; }

clean:	
	rm -f *.log
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	cp ANDROID_2.6.32_Driver_Obj/* $(BUILD_DIR)/. -arf

mrproper:
	make -C ANDROID_2.6.32 mrproper

distclean: clean
	make -C ANDROID_2.6.32 distclean

