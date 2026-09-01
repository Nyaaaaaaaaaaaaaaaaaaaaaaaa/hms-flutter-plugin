# huawei_map_ohos

This small Dart adapter keeps the OHOS-only `OhosView` symbol outside the
app-facing `huawei_map` library, so that library remains compatible with the
upstream Flutter SDK. The native ArkTS implementation stays in
`flutter-hms-map/ohos` and is registered by `huawei_map` itself.

An OHOS application must list both repository packages at the same Git ref:

```yaml
dependencies:
  huawei_map:
    git:
      url: https://github.com/Nyaaaaaaaaaaaaaaaaaaaaaaaa/hms-flutter-plugin.git
      ref: feat/ios-ohos-map-kit
      path: flutter-hms-map
  huawei_map_ohos:
    git:
      url: https://github.com/Nyaaaaaaaaaaaaaaaaaaaaaaaa/hms-flutter-plugin.git
      ref: feat/ios-ohos-map-kit
      path: flutter-hms-map-ohos
```

The OpenHarmony Flutter tool invokes `HuaweiMapOhos.registerWith`
automatically. This package is not required by Android or iOS applications.

For a local monorepo consumer, use path dependencies for both packages and
override `huawei_map` to the same local path:

```yaml
dependency_overrides:
  huawei_map:
    path: ../flutter-hms-map
```

See the main package's
[platform support matrix](../flutter-hms-map/PLATFORM_SUPPORT.md) for minimum
SDK levels and unsupported feature groups.
