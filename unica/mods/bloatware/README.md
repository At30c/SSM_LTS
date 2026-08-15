# Samsung Bloatware

This module is automatically applied only to the Galaxy S20+ `y2s` and
`y2s4g` target profiles. It installs Samsung Clock and Samsung Calendar as
system apps. Both APKs are placed in `/system/app` without modification or
re-signing, preserving the original Samsung signatures required by their
privileged integrations.

## Included apps

| App | Package | Version | Minimum Android version |
| --- | --- | --- | --- |
| Samsung Clock | `com.sec.android.app.clockpackage` | 12.4.07.23 (`1240723100`) | Android 15 / API 35 |
| Samsung Calendar | `com.samsung.android.calendar` | 12.7.06.13 (`1270613000`) | Android 15 / API 35 |

## Integrated artifacts

- `system/system/app/ClockPackage/ClockPackage.apk`
  - SHA-256: `f15e7f0e3f20b899b368454eff88687165b47deb6bb3c35f2468083218c18a07`
  - Source: [APKMirror](https://www.apkmirror.com/apk/samsung-electronics-co-ltd/samsung-clock/samsung-clock-12-4-07-23-release/samsung-clock-12-4-07-23-android-apk-download/)
- `system/system/app/SamsungCalendar/SamsungCalendar.apk`
  - SHA-256: `0dcef47b25f44c3aa9adc0a1488f273f8667a067616223fe0982698da1af5458`
  - Source: [APKMirror](https://www.apkmirror.com/apk/samsung-electronics-co-ltd/calendar-samsung-2/samsung-calendar-12-7-06-13-release/samsung-calendar-12-7-06-13-android-apk-download/)

The filesystem ownership, permissions, and SELinux labels match Samsung's
original layout for both apps.
