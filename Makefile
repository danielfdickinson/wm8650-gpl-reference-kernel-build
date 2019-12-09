ifdef DOCROSS
CROSS_COMPILE ?= arm-linux-gnueabi-
endif

KBUILD_IMAGE ?= uImage
BUILD_DIR ?= $(CURDIR)/build
KCONFIG_CONFIG ?= $(CURDIR)/configs/craig_clp281_wheezy_noinitrd
SHELL = /bin/bash

export KCONFIG_CONFIG KBUILD_IMAGE CROSS_COMPILE

all: tarbz2-pkg deb-pkg

%config:
	mkdir -p $(BUILD_DIR)
	make -C ANDROID_2.6.32 O=$(BUILD_DIR) $@
	
%pkg: modules
	{ set -o pipefail ; make -C $(BUILD_DIR) $@ 2>&1 | tee build-$@-$(shell sh -c "date -Iminutes|tr ':' '-'").log; }

$(KBUILD_IMAGE): silentoldconfig
	cp ANDROID_2.6.32_Driver_Obj/* $(BUILD_DIR)/. -arf
	{ set -o pipefail; make -C $(BUILD_DIR) $@ 2>&1 | tee build-$(KBUILD_IMAGE)-$(shell sh -c "date -Iminutes|tr ':' '-'").log; }

modules: $(KBUILD_IMAGE)
	{ set -o pipefail; make -C $(BUILD_DIR) $@ 2>&1 | tee build-modules-$(shell sh -c "date -Iminutes|tr ':' '-'").log; }

clean:	
	rm -f *.log
	rm -rf $(BUILD_DIR)

mrproper:
	make -C ANDROID_2.6.32 mrproper

distclean: clean
	make -C ANDROID_2.6.32 distclean

