# Prevent the module framework from adding this payload to every target.
SKIPUNZIP=1

# The source firmware lacks these apps only on the Galaxy S20+ ports.
case "$TARGET_ASSET_PROFILE" in
    y2s|y2slte)
        LOG "- Adding required Samsung Clock and Calendar apps"
        ADD_TO_WORK_DIR "$MODPATH" "system" "system/app/ClockPackage" || exit 1
        ADD_TO_WORK_DIR "$MODPATH" "system" "system/app/SamsungCalendar" || exit 1
        ;;
    *)
        LOG "- Skipping Galaxy S20+-specific bloatware"
        ;;
esac
