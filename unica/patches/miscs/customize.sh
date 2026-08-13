MODEL=$(echo -n "$TARGET_FIRMWARE" | cut -d "/" -f 1)
REGION=$(echo -n "$TARGET_FIRMWARE" | cut -d "/" -f 2)

# Set build ID
ROM_STATUS=""
$ROM_IS_OFFICIAL || ROM_STATUS=" UNOFFICIAL"
VALUE="$(GET_PROP "$WORK_DIR/system/system/build.prop" "ro.build.display.id")"
SET_PROP "system" "ro.build.display.id" "ExtremeROM$ROM_STATUS $ROM_CODENAME $ROM_VERSION - $TARGET_CODENAME ($VALUE)"

SET_PROP "system" "ro.extremerom.official" "$ROM_IS_OFFICIAL"
SET_PROP "system" "ro.extremerom.version" "$ROM_VERSION"
SET_PROP "system" "ro.extremerom.codename" "$ROM_CODENAME"

# Disable FRP
SET_PROP "vendor" "ro.frp.pst" ""
SET_PROP "product" "ro.frp.pst" ""

# Set Edge Lighting model
MODEL=$(echo "$TARGET_FIRMWARE" | sed -E 's/^([^/]+)\/.*/\1/')
SET_PROP "system" "ro.factory.model" "$MODEL"

# Use the target firmware's build identity so Samsung post-configuration
# services identify the ROM as running on the target device.
TARGET_FW_DIR="$FW_DIR/${MODEL}_${REGION}"

SET_TARGET_PROP()
{
    local PARTITION="$1"
    local PROP="$2"
    local TARGET_PROP_FILE="$3"
    local VALUE

    VALUE="$(GET_PROP "$TARGET_PROP_FILE" "$PROP")"
    if [ -n "$VALUE" ]; then
        SET_PROP "$PARTITION" "$PROP" "$VALUE"
    fi

    # A property may legitimately be absent from a target partition.  This
    # helper is used while the module runs with `set -e`, so it must not turn
    # that normal condition into a build failure.
    return 0
}

TARGET_SYSTEM_PROP_FILE="$TARGET_FW_DIR/system/system/build.prop"
TARGET_PRODUCT_PROP_FILE="$TARGET_FW_DIR/product/etc/build.prop"
TARGET_VENDOR_PROP_FILE="$TARGET_FW_DIR/vendor/build.prop"
TARGET_ODM_PROP_FILE="$TARGET_FW_DIR/odm/etc/build.prop"
TARGET_SYSTEM_EXT_PROP_FILE="$TARGET_FW_DIR/system/system/system_ext/etc/build.prop"

SOURCE_DESCRIPTION="$(GET_PROP "$WORK_DIR/system/system/build.prop" "ro.build.description")"
SOURCE_PRODUCT_NAME="$(GET_PROP "$WORK_DIR/system/system/build.prop" "ro.product.system.name")"
SOURCE_PDA="$(GET_PROP "$WORK_DIR/system/system/build.prop" "ro.build.PDA")"
TARGET_PRODUCT_NAME="$(GET_PROP "$TARGET_SYSTEM_PROP_FILE" "ro.product.system.name")"
TARGET_PDA="$(GET_PROP "$TARGET_SYSTEM_PROP_FILE" "ro.build.PDA")"
SOURCE_SYSTEM_DEVICE="$(GET_PROP "$WORK_DIR/system/system/build.prop" "ro.product.system.device")"
SOURCE_PRODUCT_DEVICE="$(GET_PROP "$WORK_DIR/product/etc/build.prop" "ro.product.product.device")"
SOURCE_VENDOR_DEVICE="$(GET_PROP "$WORK_DIR/vendor/build.prop" "ro.product.vendor.device")"
SOURCE_ODM_DEVICE="$(GET_PROP "$WORK_DIR/odm/etc/build.prop" "ro.product.odm.device")"
SOURCE_SYSTEM_EXT_DEVICE="$(GET_PROP "$WORK_DIR/system/system/system_ext/etc/build.prop" "ro.product.system_ext.device")"
TARGET_SYSTEM_DEVICE="$(GET_PROP "$TARGET_SYSTEM_PROP_FILE" "ro.product.system.device")"
TARGET_PRODUCT_DEVICE="$(GET_PROP "$TARGET_PRODUCT_PROP_FILE" "ro.product.product.device")"
TARGET_VENDOR_DEVICE="$(GET_PROP "$TARGET_VENDOR_PROP_FILE" "ro.product.vendor.device")"
TARGET_ODM_DEVICE="$(GET_PROP "$TARGET_ODM_PROP_FILE" "ro.product.odm.device")"
TARGET_SYSTEM_EXT_DEVICE="$(GET_PROP "$TARGET_SYSTEM_EXT_PROP_FILE" "ro.product.system_ext.device")"

for PROP_SUFFIX in brand device manufacturer model name; do
    SET_TARGET_PROP "system" "ro.product.system.$PROP_SUFFIX" "$TARGET_SYSTEM_PROP_FILE"
    SET_TARGET_PROP "product" "ro.product.product.$PROP_SUFFIX" "$TARGET_PRODUCT_PROP_FILE"
    SET_TARGET_PROP "vendor" "ro.product.vendor.$PROP_SUFFIX" "$TARGET_VENDOR_PROP_FILE"
    SET_TARGET_PROP "odm" "ro.product.odm.$PROP_SUFFIX" "$TARGET_ODM_PROP_FILE"
    SET_TARGET_PROP "system_ext" "ro.product.system_ext.$PROP_SUFFIX" "$TARGET_SYSTEM_EXT_PROP_FILE"
done

TARGET_BUILD_PROPS=(
    "ro.build.version.incremental"
    "ro.build.version.security_patch"
    "ro.build.version.base_os"
    "ro.build.version.security_index"
    "ro.build.version.min_supported_target_sdk"
    "ro.build.date"
    "ro.build.date.utc"
    "ro.build.host"
    "ro.build.tags"
    "ro.build.flavor"
    "ro.build.system_root_image"
    "ro.build.PDA"
    "ro.build.changelist"
    "ro.product_ship"
    "ro.build.official.release"
    "ro.build.official.developer"
    "ro.build.2ndbrand"
    "ro.config.rm_preload_enabled"
    "ro.build.characteristics"
)

for PROP in "${TARGET_BUILD_PROPS[@]}"; do
    SET_TARGET_PROP "system" "$PROP" "$TARGET_SYSTEM_PROP_FILE"
done

TARGET_PARTITION_BUILD_PROPS=(
    "build.date"
    "build.date.utc"
    "build.id"
    "build.tags"
    "build.type"
    "build.version.incremental"
    "build.version.release"
    "build.version.release_or_codename"
    "build.version.sdk"
)

for PROP_SUFFIX in "${TARGET_PARTITION_BUILD_PROPS[@]}"; do
    SET_TARGET_PROP "system_ext" "ro.system_ext.$PROP_SUFFIX" "$TARGET_SYSTEM_EXT_PROP_FILE"
    SET_TARGET_PROP "odm" "ro.odm.$PROP_SUFFIX" "$TARGET_ODM_PROP_FILE"
done

if [ -n "$SOURCE_DESCRIPTION" ] && [ -n "$SOURCE_PRODUCT_NAME" ] && [ -n "$TARGET_PRODUCT_NAME" ]; then
    TARGET_DESCRIPTION="${SOURCE_DESCRIPTION//$SOURCE_PRODUCT_NAME/$TARGET_PRODUCT_NAME}"
    [ -n "$SOURCE_PDA" ] && [ -n "$TARGET_PDA" ] && TARGET_DESCRIPTION="${TARGET_DESCRIPTION//$SOURCE_PDA/$TARGET_PDA}"
    SET_PROP "system" "ro.build.description" "$TARGET_DESCRIPTION"
fi

SET_TARGET_FINGERPRINT()
{
    local PARTITION="$1"
    local PROP="$2"
    local SOURCE_DEVICE="$3"
    local TARGET_DEVICE="$4"
    local FINGERPRINT

    FINGERPRINT="$(GET_PROP "$PARTITION" "$PROP")"
    [ -z "$FINGERPRINT" ] && return 0

    [ -n "$SOURCE_PRODUCT_NAME" ] && [ -n "$TARGET_PRODUCT_NAME" ] && FINGERPRINT="${FINGERPRINT//$SOURCE_PRODUCT_NAME/$TARGET_PRODUCT_NAME}"
    [ -n "$SOURCE_DEVICE" ] && [ -n "$TARGET_DEVICE" ] && FINGERPRINT="${FINGERPRINT//$SOURCE_DEVICE/$TARGET_DEVICE}"
    [ -n "$SOURCE_PDA" ] && [ -n "$TARGET_PDA" ] && FINGERPRINT="${FINGERPRINT//$SOURCE_PDA/$TARGET_PDA}"
    SET_PROP "$PARTITION" "$PROP" "$FINGERPRINT"
}

SET_TARGET_FINGERPRINT "system" "ro.system.build.fingerprint" "$SOURCE_SYSTEM_DEVICE" "$TARGET_SYSTEM_DEVICE"
SET_TARGET_FINGERPRINT "system_ext" "ro.system_ext.build.fingerprint" "$SOURCE_SYSTEM_EXT_DEVICE" "$TARGET_SYSTEM_EXT_DEVICE"
SET_TARGET_FINGERPRINT "product" "ro.product.build.fingerprint" "$SOURCE_PRODUCT_DEVICE" "$TARGET_PRODUCT_DEVICE"
# ODM must match the target's original vendor/ODM build identity exactly.
SET_TARGET_PROP "odm" "ro.odm.build.fingerprint" "$TARGET_ODM_PROP_FILE"
SET_TARGET_FINGERPRINT "vendor" "ro.vendor.build.fingerprint" "$SOURCE_VENDOR_DEVICE" "$TARGET_VENDOR_DEVICE"
SET_TARGET_FINGERPRINT "vendor" "ro.bootimage.build.fingerprint" "$SOURCE_VENDOR_DEVICE" "$TARGET_VENDOR_DEVICE"

unset PROP PROP_SUFFIX TARGET_BUILD_PROPS TARGET_PARTITION_BUILD_PROPS TARGET_FW_DIR TARGET_DESCRIPTION
unset SOURCE_DESCRIPTION SOURCE_PRODUCT_NAME SOURCE_PDA TARGET_PRODUCT_NAME TARGET_PDA
unset SOURCE_SYSTEM_DEVICE SOURCE_PRODUCT_DEVICE SOURCE_VENDOR_DEVICE SOURCE_ODM_DEVICE SOURCE_SYSTEM_EXT_DEVICE
unset TARGET_SYSTEM_DEVICE TARGET_PRODUCT_DEVICE TARGET_VENDOR_DEVICE TARGET_ODM_DEVICE TARGET_SYSTEM_EXT_DEVICE
unset TARGET_SYSTEM_PROP_FILE TARGET_PRODUCT_PROP_FILE TARGET_VENDOR_PROP_FILE TARGET_ODM_PROP_FILE TARGET_SYSTEM_EXT_PROP_FILE
unset -f SET_TARGET_PROP
unset -f SET_TARGET_FINGERPRINT

if [[ -f "$FW_DIR/${MODEL}_${REGION}/vendor/lib64/liblivefocus_capture_engine.so" ]]; then
    if grep -q "ro.product.name" "$FW_DIR/${MODEL}_${REGION}/vendor/lib64/liblivefocus_capture_engine.so"; then
        # For devices with this lib in system instead of vendor (e.g. S22 and up)
        # we will need to sed this in system lib after replacing with stock blob
        # in a platform patch.
        if [[ -f "$FW_DIR/${MODEL}_${REGION}/vendor/lib64/libDualCamBokehCapture.camera.samsung.so" ]]; then
            sed -i "s/ro.product.name/ro.unica.camera/g" "$WORK_DIR/vendor/lib/libDualCamBokehCapture.camera.samsung.so"
            sed -i "s/ro.product.name/ro.unica.camera/g" "$WORK_DIR/vendor/lib64/libDualCamBokehCapture.camera.samsung.so"
        fi
        sed -i "s/ro.product.name/ro.unica.camera/g" "$WORK_DIR/vendor/lib/liblivefocus_capture_engine.so"
        sed -i "s/ro.product.name/ro.unica.camera/g" "$WORK_DIR/vendor/lib/liblivefocus_preview_engine.so"
        sed -i "s/ro.product.name/ro.unica.camera/g" "$WORK_DIR/vendor/lib64/liblivefocus_capture_engine.so"
        sed -i "s/ro.product.name/ro.unica.camera/g" "$WORK_DIR/vendor/lib64/liblivefocus_preview_engine.so"
        echo -e "\nro.unica.camera u:object_r:build_prop:s0 exact string" >> "$WORK_DIR/system/system/etc/selinux/plat_property_contexts"
        SET_PROP "system" "ro.unica.camera" "$(GET_PROP "$FW_DIR/${MODEL}_${REGION}/system/system/build.prop" "ro.product.system.name")"
    fi
fi
