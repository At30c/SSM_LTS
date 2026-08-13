# Galaxy S20+ target profile backup

Created before separating the Galaxy S20+ 4G (`SM-G985F`) and 5G
(`SM-G986B`) targets. The current `y2s` profile is unchanged at this point.

Restore the original profile with:

```bash
git restore --source=9c294ce353b3e88bfe612c11cc9d19eab6097a57 -- target/y2s
```

The original tree is recorded by these Git blobs:

| File | Blob |
| --- | --- |
| `target/y2s/config.sh` | `f6ee79d75b21974fc165b53ac68a46bd5c7d9aa3` |
| `target/y2s/overlay/values/arrays.xml` | `821fb6a05d253e62fd4f5e6c7aac626915d3b8dc` |
| `target/y2s/overlay/values/bools.xml` | `774ff9b58d829d4e3b761b142606645d2a2b134c` |
| `target/y2s/overlay/values/dimens.xml` | `4e8b0a5f31bcca86f074f8c566cb91b6eb0fc375` |
| `target/y2s/overlay/values/integers.xml` | `7d6fa65d314a85906ae6c5085fc5861c7dd4d1c3` |
| `target/y2s/overlay/values/strings.xml` | `a833124b2b742a5f2f598cafd5471c93c3a049d4` |
| `target/y2s/patches/camera/module.prop` | `67e890d8f3c99a57fa153005bd6c6eaa03996a15` |
| `target/y2s/patches/camera/system/cameradata/camera-feature.xml` | `b6e3890a3d6f8266799afb21a50e3967cb9242c9` |
| `target/y2s/postinstall.edify` | `d4ebaadb6bb5497dedde3d3a1c9b9f1010e3c745` |
| `target/y2s/sff.sh` | `4f1253f4a15f449ebc4743493c32854b465a1c60` |
