#!/usr/bin/env bash
#
# Copyright (C) 2026 Salvo Giangreco
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# [
source "$SRC_DIR/scripts/utils/log_utils.sh" || exit 1
source "$SRC_DIR/scripts/utils/build_utils.sh" || exit 1

INPUT_APK=""
OUTPUT_APK=""
PATCH_MODEL=""
INSTALL=false
TEMP_DIR=""
REMOTE_APK=""

PRINT_USAGE()
{
    echo "Usage: gl_patch [options]" >&2
    echo "" >&2
    echo "Patch Good Lock so its catalog is requested with the source firmware model." >&2
    echo "Without --apk, the command pulls the currently installed Good Lock APK" >&2
    echo "from the connected rooted device. The patched APK is written to out/goodlock." >&2
    echo "" >&2
    echo "Options:" >&2
    echo " --apk <file>       Patch a local Good Lock APK instead of pulling it from a device" >&2
    echo " --model <model>    Override the source firmware model used by the catalog request" >&2
    echo " --output <file>    Set the patched APK output path" >&2
    echo " --install           Uninstall the current Good Lock app and install the patched APK" >&2
}

CLEANUP()
{
    [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"

    if [ -n "$REMOTE_APK" ] && command -v adb &> /dev/null; then
        adb shell "su -c 'rm -f \"$REMOTE_APK\"'" &> /dev/null || true
    fi
}

GET_SOURCE_MODEL()
{
    PATCH_MODEL="$(cut -d "/" -f 1 -s <<< "$SOURCE_FIRMWARE")"

    if [ -z "$PATCH_MODEL" ]; then
        LOGE "Could not read the source firmware model from SOURCE_FIRMWARE"
        LOGE "Use --model <model> or source buildenv.sh with a target first"
        return 1
    fi
}

PULL_INSTALLED_GOOD_LOCK()
{
    local DEVICE_APK

    command -v adb &> /dev/null || {
        LOGE "adb is required when --apk is not supplied"
        return 1
    }

    adb get-state &> /dev/null || {
        LOGE "No authorized Android device found"
        return 1
    }

    adb shell "su -c true" &> /dev/null || {
        LOGE "Root access through adb shell is required to pull the installed Good Lock APK"
        return 1
    }

    DEVICE_APK="$(adb shell pm path com.samsung.android.goodlock | tr -d "\r" | sed -n "s/^package://p" | grep "/base.apk$" | head -n 1)"
    if [ -z "$DEVICE_APK" ]; then
        LOGE "Good Lock is not installed on the connected device"
        return 1
    fi

    REMOTE_APK="/sdcard/Download/.unica-goodlock-${RANDOM}.apk"
    adb shell "su -c 'cp \"$DEVICE_APK\" \"$REMOTE_APK\" && chmod 0644 \"$REMOTE_APK\"'" || return 1

    INPUT_APK="$TEMP_DIR/GoodLock.apk"
    adb pull "$REMOTE_APK" "$INPUT_APK" &> /dev/null || return 1
}

PATCH_MODEL_LOOKUPS()
{
    local SMALI_FILE="$1"
    local REGISTER="$2"
    local LOOKUP="sget-object $REGISTER, Landroid/os/Build;->MODEL:Ljava/lang/String;"

    if [ "$(grep -F -c "$LOOKUP" "$SMALI_FILE")" -ne 1 ]; then
        LOGE "Unexpected Good Lock code in ${SMALI_FILE##*/}; the model lookup could not be patched safely"
        return 1
    fi

    sed -i "s@${LOOKUP}@const-string ${REGISTER}, \"${PATCH_MODEL}\"@" "$SMALI_FILE"
}

PATCH_GOOD_LOCK()
{
    # Good Lock 3.x centralizes the model used by all Galaxy Store requests.
    if [ -f "$DECODED_APK/smali/cf/h0.smali" ]; then
        PATCH_MODEL_LOOKUPS "$DECODED_APK/smali/cf/h0.smali" "p0" || return 1
        return 0
    fi

    # Good Lock 2.x builds the catalog and update requests in separate classes.
    if [ -f "$DECODED_APK/smali/h1/e.smali" ] && [ -f "$DECODED_APK/smali/h1/g.smali" ]; then
        PATCH_MODEL_LOOKUPS "$DECODED_APK/smali/h1/e.smali" "v3" || return 1
        PATCH_MODEL_LOOKUPS "$DECODED_APK/smali/h1/g.smali" "p2" || return 1
        return 0
    fi

    LOGE "This Good Lock version is not supported by gl_patch"
    return 1
}
# ]

while [ "$#" -ne 0 ]; do
    case "$1" in
        "--apk"|"--model"|"--output")
            if [ "$#" -lt 2 ] || [[ "$2" == "--"* ]]; then
                LOGE "Option $1 requires a value"
                exit 1
            fi

            case "$1" in
                "--apk") INPUT_APK="$2" ;;
                "--model") PATCH_MODEL="$2" ;;
                "--output") OUTPUT_APK="$2" ;;
            esac
            shift
            ;;
        "--install")
            INSTALL=true
            ;;
        "--help"|"-h")
            PRINT_USAGE
            exit 0
            ;;
        *)
            LOGE "Unknown option: $1"
            PRINT_USAGE
            exit 1
            ;;
    esac

    shift
done

if [ -z "$PATCH_MODEL" ]; then
    GET_SOURCE_MODEL || exit 1
fi

if ! [[ "$PATCH_MODEL" =~ ^[A-Za-z0-9._-]+$ ]]; then
    LOGE "Model value is not valid: $PATCH_MODEL"
    exit 1
fi

mkdir -p "${TMP_DIR:-/tmp}"
TEMP_DIR="$(mktemp -d "${TMP_DIR:-/tmp}/gl_patch.XXXXXX")" || exit 1
trap CLEANUP EXIT

if [ -z "$INPUT_APK" ]; then
    LOG "- Pulling the installed Good Lock APK..."
    PULL_INSTALLED_GOOD_LOCK || exit 1
elif [ ! -f "$INPUT_APK" ]; then
    LOGE "APK not found: $INPUT_APK"
    exit 1
fi

if [ -z "$OUTPUT_APK" ]; then
    OUTPUT_APK="$OUT_DIR/goodlock/GoodLock-${PATCH_MODEL}-patched.apk"
fi

FRAMEWORK_DIR="$TOOLS_DIR/apktool/framework"
DECODED_APK="$TEMP_DIR/GoodLock"
BUILT_APK="$DECODED_APK/dist/$(basename "$INPUT_APK")"

LOG "- Decoding Good Lock..."
apktool d -f -p "$FRAMEWORK_DIR" -o "$DECODED_APK" "$INPUT_APK" || exit 1

PATCH_GOOD_LOCK || exit 1

LOG "- Building Good Lock with $PATCH_MODEL catalog compatibility..."
apktool b -p "$FRAMEWORK_DIR" "$DECODED_APK" || exit 1

mkdir -p "$(dirname "$OUTPUT_APK")"
LOG "- Signing patched Good Lock..."
signapk "$SRC_DIR/security/aosp_platform.x509.pem" "$SRC_DIR/security/aosp_platform.pk8" "$BUILT_APK" "$OUTPUT_APK" || exit 1

LOG "- Patched APK: ${OUTPUT_APK//$SRC_DIR\//}"

if $INSTALL; then
    command -v adb &> /dev/null || {
        LOGE "adb is required with --install"
        exit 1
    }

    adb get-state &> /dev/null || {
        LOGE "No authorized Android device found"
        exit 1
    }

    LOGW "- Removing the current Good Lock app and its data..."
    adb uninstall com.samsung.android.goodlock || exit 1
    LOG "- Installing patched Good Lock..."
    adb install "$OUTPUT_APK" || exit 1
fi

exit 0
