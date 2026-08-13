# Do not inject this module's bundled CSC payload. The target firmware's CSC
# is copied below instead, then only the tweaks in this script are applied.
SKIPUNZIP=1

# SET_CSC_FEATURE_CONFIG "<config>" "<value>"
# Sets the supplied config to the desidered value.
# "-d" or "--delete" can be passed as value to delete the config.
SET_CSC_FEATURE_CONFIG()
{
    local CONFIG="$1"
    local VALUE="$2"

    if grep -q "$CONFIG" "$FILE"; then
        if [[ "$VALUE" == "-d" ]] || [[ "$VALUE" == "--delete" ]]; then
            sed -i "/$CONFIG/d" "$FILE"
        else
            sed -i "/$CONFIG/c\    <$CONFIG>$VALUE<\/$CONFIG>" "$FILE"
        fi
    elif [[ "$VALUE" != "-d" ]] && [[ "$VALUE" != "--delete" ]]; then
        if ! grep -q "Added by " "$FILE"; then
            sed -i "/<\/FeatureSet>/i \    <!-- Added by unica/mods/csc/customize.sh -->" "$FILE"
        fi
        sed -i "/<\/FeatureSet>/i \    <$CONFIG>$VALUE</$CONFIG>" "$FILE"
    fi

    return 0
}

TARGET_MODEL=$(echo -n "$TARGET_FIRMWARE" | cut -d "/" -f 1)
TARGET_REGION=$(echo -n "$TARGET_FIRMWARE" | cut -d "/" -f 2)
TARGET_CSC_DIR="$FW_DIR/${TARGET_MODEL}_${TARGET_REGION}"

LOG_STEP_IN "- Using target firmware CSC"
for PARTITION in optics prism; do
    if [ ! -d "$TARGET_CSC_DIR/$PARTITION" ]; then
        LOGE "Target CSC partition not found: /$PARTITION"
        exit 1
    fi

    LOG "- Copying /$PARTITION from target firmware"
    if [[ "$PARTITION" == "prism" ]]; then
        # Debloat runs before modules. Do not reintroduce the target CSC's
        # carrier/preload packages after unica/patches/debloat removes them.
        EVAL "rsync -a --delete --delete-excluded --exclude='/app/' --exclude='/preload/' --exclude='/priv-app/' \"$TARGET_CSC_DIR/$PARTITION/\" \"$WORK_DIR/$PARTITION/\"" || exit 1
    else
        # optics/configs contains the cscfeature.xml files patched below.
        EVAL "rsync -a --delete \"$TARGET_CSC_DIR/$PARTITION/\" \"$WORK_DIR/$PARTITION/\"" || exit 1
    fi
    EVAL "cp -a \"$TARGET_CSC_DIR/file_context-$PARTITION\" \"$WORK_DIR/configs/file_context-$PARTITION\"" || exit 1
    EVAL "cp -a \"$TARGET_CSC_DIR/fs_config-$PARTITION\" \"$WORK_DIR/configs/fs_config-$PARTITION\"" || exit 1
done
LOG_STEP_OUT

PATCH_DEFAULT_WORKSPACE_HOTSEAT()
{
    local FILE="$1"
    local TEMP_FILE

    # Keep the existing workspace intact and replace only the hotseat block.
    # Some carrier workspaces have no hotseat, and are intentionally skipped.
    grep -q '<hotseat>' "$FILE" || return 0

    TEMP_FILE="${FILE}.unica-hotseat"
    awk '
        /<hotseat>/ {
            print "    <hotseat>"
            print "        <!-- Phone -->"
            print "        <favorite"
            print "            screen=\"0\""
            print "            packageName=\"com.samsung.android.dialer\""
            print "            className=\"com.samsung.android.dialer.DialtactsActivity\" />"
            print ""
            print "        <!-- Messages -->"
            print "        <favorite"
            print "            screen=\"1\""
            print "            packageName=\"com.samsung.android.messaging\""
            print "            className=\"com.android.mms.ui.ConversationComposer\" />"
            print ""
            print "        <!-- Chrome -->"
            print "        <favorite"
            print "            screen=\"2\""
            print "            className=\"com.google.android.apps.chrome.Main\""
            print "            packageName=\"com.android.chrome\" />"
            print ""
            print "        <!-- Camera -->"
            print "        <favorite"
            print "            screen=\"3\""
            print "            packageName=\"com.sec.android.app.camera\""
            print "            className=\"com.sec.android.app.camera.Camera\" />"
            print ""
            print "    </hotseat>"
            in_hotseat = 1
            next
        }
        in_hotseat && /<\/hotseat>/ {
            in_hotseat = 0
            next
        }
        !in_hotseat { print }
    ' "$FILE" > "$TEMP_FILE" || return 1

    chmod --reference="$FILE" "$TEMP_FILE" || return 1
    mv -f "$TEMP_FILE" "$FILE" || return 1
}

LOG_STEP_IN "- Patching CSC default workspace"
HOTSEAT_FILES=0
while IFS= read -r -d '' FILE; do
    grep -q '<hotseat>' "$FILE" || continue
    PATCH_DEFAULT_WORKSPACE_HOTSEAT "$FILE" || exit 1
    HOTSEAT_FILES=$((HOTSEAT_FILES + 1))
done < <(find "$WORK_DIR/prism" -type f -name "default_workspace.xml" -print0)
LOG "- Updated hotseat in $HOTSEAT_FILES CSC workspace file(s)"
LOG_STEP_OUT

LOG_STEP_IN "- Patching CSC Features"
while read -r FILE; do
    (
        LOG "- Decoding $FILE"
        ! grep -q 'CscFeature' "$FILE" && EVAL "$TOOLS_DIR/bin/cscdecoder --decode --in-place \"$FILE\""

        LOG_STEP_IN "- Applying CSC Tweaks"
        if $SOURCE_IS_ESIM_SUPPORTED && ! $TARGET_IS_ESIM_SUPPORTED; then
            SET_CSC_FEATURE_CONFIG "CscFeature_RIL_SupportEsim" "FALSE"
            SET_CSC_FEATURE_CONFIG "CscFeature_SetupWizard_SupportEsimAsPrimary" --delete
        fi

        SET_CSC_FEATURE_CONFIG "CscFeature_VoiceCall_ConfigRecording" "RecordingAllowed"
        SET_CSC_FEATURE_CONFIG "CscFeature_Setting_SupportRealTimeNetworkSpeed" "TRUE"
        SET_CSC_FEATURE_CONFIG "CscFeature_Setting_EnableHwVersionDisplay" "TRUE"
        SET_CSC_FEATURE_CONFIG "CscFeature_Setting_SupportMenuSmartTutor" "FALSE"
        SET_CSC_FEATURE_CONFIG "CscFeature_Setting_ConfigLongPressType" 1
        SET_CSC_FEATURE_CONFIG "CscFeature_Common_DisableBixby" --delete
        LOG_STEP_OUT

        LOG "- Encoding $FILE"
        EVAL "$TOOLS_DIR/bin/cscdecoder --encode --in-place \"$FILE\""
    ) &
done <<< "$(find "$WORK_DIR/optics" -type f -name "cscfeature.xml")"

# shellcheck disable=SC2046
wait $(jobs -p) || exit 1
LOG_STEP_OUT

unset FILE HOTSEAT_FILES
unset -f PATCH_DEFAULT_WORKSPACE_HOTSEAT

LOG_STEP_IN "- Patching APKs for network speed monitoring"

DECODE_APK "system" "system/priv-app/SecSettings/SecSettings.apk"
DECODE_APK "system_ext" "priv-app/SystemUI/SystemUI.apk"

FTP="
system/priv-app/SecSettings/SecSettings.apk/smali_classes4/com/samsung/android/settings/eternal/provider/items/NotificationsItem.smali
system/priv-app/SecSettings/SecSettings.apk/smali_classes4/com/samsung/android/settings/notification/ConfigureNotificationMoreSettings\$1.smali
system/priv-app/SecSettings/SecSettings.apk/smali_classes4/com/samsung/android/settings/notification/StatusBarNetworkSpeedController.smali
system_ext/priv-app/SystemUI/SystemUI.apk/smali/com/android/systemui/Rune.smali
system_ext/priv-app/SystemUI/SystemUI.apk/smali/com/android/systemui/QpRune.smali
"
for f in $FTP; do
    sed -i "s/CscFeature_Common_SupportZProjectFunctionInGlobal/CscFeature_Setting_SupportRealTimeNetworkSpeed/g" "$APKTOOL_DIR/$f"
done
LOG_STEP_OUT
