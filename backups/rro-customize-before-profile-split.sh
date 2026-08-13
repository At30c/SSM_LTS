# Backup of unica/patches/rro/customize.sh before adding target asset profiles.

SOURCE_MODEL="$(echo -n "$SOURCE_FIRMWARE" | cut -d "/" -f 1)"
SOURCE_REGION="$(echo -n "$SOURCE_FIRMWARE" | cut -d "/" -f 2)"
CUSTOM_SYSTEM_NAME="$(GET_PROP "$FW_DIR/${SOURCE_MODEL}_${SOURCE_REGION}/system/system/build.prop" "ro.product.system.name")"
TARGET_SYSTEM_NAME="$(GET_PROP "$WORK_DIR/system/system/build.prop" "ro.product.system.name")"

RENAME_RRO()
{
    local APK_NAME="$1"
    local CUSTOM_APK="overlay/${APK_NAME}__${CUSTOM_SYSTEM_NAME}__auto_generated_rro_product.apk"
    local TARGET_APK="overlay/${APK_NAME}__${TARGET_SYSTEM_NAME}__auto_generated_rro_product.apk"
    local CUSTOM_APK_STEM="${CUSTOM_APK%.apk}"
    local TARGET_APK_STEM="${TARGET_APK%.apk}"

    [ "$CUSTOM_APK" = "$TARGET_APK" ] && return 0
    mv -f "$WORK_DIR/product/$CUSTOM_APK" "$WORK_DIR/product/$TARGET_APK"
    mv -f "$APKTOOL_DIR/product/$CUSTOM_APK" "$APKTOOL_DIR/product/$TARGET_APK"
    sed -i "s/^apkFileName: .*/apkFileName: $(basename "$TARGET_APK")/" "$APKTOOL_DIR/product/$TARGET_APK/apktool.yml"

    # The image builder matches each APK filename against these two metadata
    # files. Keep them in sync with the renamed overlay.
    sed -i "s/${CUSTOM_APK_STEM//\//\\\/}/${TARGET_APK_STEM//\//\\\/}/g" \
        "$WORK_DIR/configs/fs_config-product" \
        "$WORK_DIR/configs/file_context-product"
}

if [[ -d "$SRC_DIR/target/$TARGET_CODENAME/overlay" ]]; then
    DECODE_APK "product" "overlay/framework-res__${CUSTOM_SYSTEM_NAME}__auto_generated_rro_product.apk"

    LOG "- Applying stock overlay configs"
    rm -rf "$APKTOOL_DIR/product/overlay/framework-res__${CUSTOM_SYSTEM_NAME}__auto_generated_rro_product.apk/res"
    cp -a --preserve=all \
        "$SRC_DIR/target/$TARGET_CODENAME/overlay" \
        "$APKTOOL_DIR/product/overlay/framework-res__${CUSTOM_SYSTEM_NAME}__auto_generated_rro_product.apk/res"
fi

# TODO: Add a proper check if we need to remove this
DECODE_APK "product" "overlay/SystemUI__${CUSTOM_SYSTEM_NAME}__auto_generated_rro_product.apk"
sed -i -e "/config_enableDisplayCutoutProtection/d" -e "/config_enableRoundedCorner/d" "$APKTOOL_DIR/product/overlay/SystemUI__${CUSTOM_SYSTEM_NAME}__auto_generated_rro_product.apk/res/values/bools.xml"
rm "$APKTOOL_DIR/product/overlay/SystemUI__${CUSTOM_SYSTEM_NAME}__auto_generated_rro_product.apk/res/values/dimens.xml"
rm "$APKTOOL_DIR/product/overlay/SystemUI__${CUSTOM_SYSTEM_NAME}__auto_generated_rro_product.apk/res/values/public.xml"
rm "$APKTOOL_DIR/product/overlay/SystemUI__${CUSTOM_SYSTEM_NAME}__auto_generated_rro_product.apk/res/drawable/rounded.xml"

[[ -d "$SRC_DIR/target/$TARGET_CODENAME/overlay" ]] && RENAME_RRO "framework-res"
RENAME_RRO "SystemUI"

unset SOURCE_MODEL SOURCE_REGION CUSTOM_SYSTEM_NAME TARGET_SYSTEM_NAME
unset -f RENAME_RRO
