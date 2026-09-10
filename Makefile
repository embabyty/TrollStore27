TOPTARGETS := all clean update

$(TOPTARGETS): pre_build make_fastPathSign make_roothelper make_trollstore make_trollhelper_embedded make_trollhelper_package assemble_trollstore build_installer15 build_installer64e build_installer27 build_trollinstallerx make_trollstore_lite

pre_build:
	@rm -rf ./_build 2>/dev/null || true
	@mkdir -p ./_build

make_fastPathSign:
	@$(MAKE) -C ./Exploits/fastPathSign $(MAKECMDGOALS)

make_roothelper:
	@$(MAKE) -C ./RootHelper DEBUG=0 $(MAKECMDGOALS)

make_trollstore:
	@$(MAKE) -C ./TrollStore FINALPACKAGE=1 $(MAKECMDGOALS)

ifneq ($(MAKECMDGOALS),clean)

make_trollhelper_package:
	@$(MAKE) clean -C ./TrollHelper
	@cp ./RootHelper/.theos/obj/trollstorehelper ./TrollHelper/Resources/trollstorehelper
	@$(MAKE) -C ./TrollHelper FINALPACKAGE=1 package $(MAKECMDGOALS)
	@$(MAKE) clean -C ./TrollHelper
	@$(MAKE) -C ./TrollHelper THEOS_PACKAGE_SCHEME=rootless FINALPACKAGE=1 package $(MAKECMDGOALS)
	@rm ./TrollHelper/Resources/trollstorehelper

make_trollhelper_embedded:
	@$(MAKE) clean -C ./TrollHelper
	@$(MAKE) -C ./TrollHelper FINALPACKAGE=1 EMBEDDED_ROOT_HELPER=1 $(MAKECMDGOALS)
	@cp ./TrollHelper/.theos/obj/TrollStorePersistenceHelper.app/TrollStorePersistenceHelper ./_build/PersistenceHelper_Embedded
	@$(MAKE) clean -C ./TrollHelper
	@$(MAKE) -C ./TrollHelper FINALPACKAGE=1 EMBEDDED_ROOT_HELPER=1 LEGACY_CT_BUG=1 $(MAKECMDGOALS)
	@cp ./TrollHelper/.theos/obj/TrollStorePersistenceHelper.app/TrollStorePersistenceHelper ./_build/PersistenceHelper_Embedded_Legacy_arm64
	@$(MAKE) clean -C ./TrollHelper
	@$(MAKE) -C ./TrollHelper FINALPACKAGE=1 EMBEDDED_ROOT_HELPER=1 CUSTOM_ARCHS=arm64e $(MAKECMDGOALS)
	@cp ./TrollHelper/.theos/obj/TrollStorePersistenceHelper.app/TrollStorePersistenceHelper ./_build/PersistenceHelper_Embedded_Legacy_arm64e
	@$(MAKE) clean -C ./TrollHelper

assemble_trollstore:
	@cp ./RootHelper/.theos/obj/trollstorehelper ./TrollStore/.theos/obj/TrollStore.app/trollstorehelper
	@cp ./TrollHelper/.theos/obj/TrollStorePersistenceHelper.app/TrollStorePersistenceHelper ./TrollStore/.theos/obj/TrollStore.app/PersistenceHelper
	@export COPYFILE_DISABLE=1
	@tar -czvf ./_build/TrollStore.tar -C ./TrollStore/.theos/obj TrollStore.app

# TrollInstallerX fork with CoreTrust install method for iOS 26.6.1 (23G82) and iOS 27.0 RC - 27.x (24A-24Z)
build_trollinstallerx:
	@bash ./TrollInstallerX/build.sh
	@mkdir -p ./_build
	@cp ./TrollInstallerX/TrollInstallerX27.ipa ./_build/TrollInstallerX27.ipa
	@rm ./TrollInstallerX/TrollInstallerX27.ipa

make_trollstore_lite:
	@$(MAKE) -C ./RootHelper DEBUG=0 TROLLSTORE_LITE=1
	@rm -rf ./TrollStoreLite/Resources/trollstorehelper
	@cp ./RootHelper/.theos/obj/trollstorehelper_lite ./TrollStoreLite/Resources/trollstorehelper
	@$(MAKE) -C ./TrollStoreLite package FINALPACKAGE=1
	@$(MAKE) -C ./RootHelper TROLLSTORE_LITE=1 clean
	@$(MAKE) -C ./TrollStoreLite clean
	@$(MAKE) -C ./RootHelper DEBUG=0 TROLLSTORE_LITE=1 THEOS_PACKAGE_SCHEME=rootless
	@rm -rf ./TrollStoreLite/Resources/trollstorehelper
	@cp ./RootHelper/.theos/obj/trollstorehelper_lite ./TrollStoreLite/Resources/trollstorehelper
	@$(MAKE) -C ./TrollStoreLite package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless

else
make_trollstore_lite:
	@$(MAKE) -C ./TrollStoreLite $(MAKECMDGOALS)

build_trollinstallerx:
	@echo "Skipping build_trollinstallerx during clean"
endif

# The TrollHelper installer IPAs are built from a signed "victim" App Store app
# which is intentionally not stored in the repository (see Victim/README.md).
# If Victim/InstallerVictim.ipa is not present, these targets are skipped.

ifneq ($(wildcard ./Victim/InstallerVictim.ipa),)

build_installer15:
	@mkdir -p ./_build/tmp15
	@unzip ./Victim/InstallerVictim.ipa -d ./_build/tmp15
	@cp ./_build/PersistenceHelper_Embedded_Legacy_arm64 ./_build/TrollStorePersistenceHelperToInject
	@pwnify set-cpusubtype ./_build/TrollStorePersistenceHelperToInject 1
	@ldid -s -K./Victim/victim.p12 ./_build/TrollStorePersistenceHelperToInject
	APP_PATH=$$(find ./_build/tmp15/Payload -name "*" -depth 1) ; \
	APP_NAME=$$(basename $$APP_PATH) ; \
	BINARY_NAME=$$(echo "$$APP_NAME" | cut -f 1 -d '.') ; \
	echo $$BINARY_NAME ; \
	pwnify pwn ./_build/tmp15/Payload/$$APP_NAME/$$BINARY_NAME ./_build/TrollStorePersistenceHelperToInject
	@pushd ./_build/tmp15 ; \
	zip -vrD ../../_build/TrollHelper_iOS15.ipa * ; \
	popd
	@rm ./_build/TrollStorePersistenceHelperToInject
	@rm -rf ./_build/tmp15

build_installer64e:
	@mkdir -p ./_build/tmp64e
	@unzip ./Victim/InstallerVictim.ipa -d ./_build/tmp64e
	APP_PATH=$$(find ./_build/tmp64e/Payload -name "*" -depth 1) ; \
	APP_NAME=$$(basename $$APP_PATH) ; \
	BINARY_NAME=$$(echo "$$APP_NAME" | cut -f 1 -d '.') ; \
	echo $$BINARY_NAME ; \
	pwnify pwn64e ./_build/tmp64e/Payload/$$APP_NAME/$$BINARY_NAME ./_build/PersistenceHelper_Embedded_Legacy_arm64e
	@pushd ./_build/tmp64e ; \
	zip -vrD ../../_build/TrollHelper_arm64e.ipa * ; \
	popd
	@rm -rf ./_build/tmp64e

# Sideloadable TrollHelper for iOS 26.6.1 (23G82) and iOS 27.0 RC - 27.x (24A-24Z), installable via AltStore/SideStore
# Uses the non-legacy (CMS SignerInfo) persistence helper, as the legacy custom root certificate bypass is not supported on these versions
# Note: the helper binary is intentionally not re-signed with the victim certificate, as that would remove the pre-applied CMS SignerInfo CoreTrust bypass
build_installer27:
	@mkdir -p ./_build/tmp27
	@unzip ./Victim/InstallerVictim.ipa -d ./_build/tmp27
	@cp ./_build/PersistenceHelper_Embedded ./_build/TrollStorePersistenceHelperToInject
	@pwnify set-cpusubtype ./_build/TrollStorePersistenceHelperToInject 1
	APP_PATH=$$(find ./_build/tmp27/Payload -name "*" -depth 1) ; \
	APP_NAME=$$(basename $$APP_PATH) ; \
	BINARY_NAME=$$(echo "$$APP_NAME" | cut -f 1 -d '.') ; \
	echo $$BINARY_NAME ; \
	pwnify pwn ./_build/tmp27/Payload/$$APP_NAME/$$BINARY_NAME ./_build/TrollStorePersistenceHelperToInject
	@pushd ./_build/tmp27 ; \
	zip -vrD ../../_build/TrollHelper_iOS27.ipa * ; \
	popd
	@rm ./_build/TrollStorePersistenceHelperToInject
	@rm -rf ./_build/tmp27

else

build_installer15 build_installer64e build_installer27:
	@echo "Skipping $@: Victim/InstallerVictim.ipa not found"

endif

.PHONY: $(TOPTARGETS) pre_build assemble_trollstore make_trollhelper_package make_trollhelper_embedded build_installer15 build_installer64e build_installer27 build_trollinstallerx