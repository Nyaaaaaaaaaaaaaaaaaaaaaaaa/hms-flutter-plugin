<p align="center">
  <h1 align="center">Huawei Map Flutter Plugin</h1>
</p>



<p align="center">
  <a href="https://pub.dev/packages/huawei_map"><img src="https://img.shields.io/pub/v/huawei_map?style=for-the-badge" alt="pub.dev version"></a>
</p>


----

Huawei Map Kit, provides standard maps as well as UI elements such as markers, shapes, and layers for you to customize maps that better meet service scenarios. Enables users to interact with a map in your app through gestures and buttons in different scenarios.

Huawei Map Kit provides the following core capabilities:

- **Huawei Map**: Core map component with tons of features.
- **My Location**: Your location on the map.
- **Markers**: Adding markers on the map with tons of modifications with their InfoWindow component.
- **Polylines**: Adding polylines on the map with tons of modifications.
- **Polygons**: Adding polygons on the map with tons of modifications.
- **Circles**: Adding circles on the map with tons of modifications.
- **Ground Overlays**: Adding ground overlays on the map with tons of modifications.
- **Tile Overlays**: Adding tile overlays on the map with tons of modifications.

This fork adds native iOS and HarmonyOS NEXT/OHOS bridges while preserving the
existing Android Dart API. Platform SDKs do not expose identical feature sets,
so shared applications should consult
`HuaweiMapPlatformCapabilities` before calling an optional feature. See the
[platform support matrix](PLATFORM_SUPPORT.md) for the exact compatibility
contract.

[Learn More](https://developer.huawei.com/consumer/en/doc/HMS-Plugin-Guides/introduction-0000001050296908-V1?ha_source=hms1)

## Installation

### Android

Use the package as before and complete the
[AppGallery Connect configuration](https://developer.huawei.com/consumer/en/doc/HMS-Plugin-Guides/config-agc-0000001050296920-V1?ha_source=hms1).

### iOS

The proprietary Huawei Map Kit iOS SDK is intentionally not redistributed by
this repository.

1. Download the latest 6.4.x Map Kit iOS SDK from Huawei and add
   `agconnect-services.plist` to the Runner target.
2. Link `HMapKit.framework`, `AGConnectCore.framework`, `GRS.framework`,
   `HAFormalAnalytics.framework`, `HMFoundation.framework`, and
   `ZipArchive.framework`.
3. Copy `HMapKit.bundle` and `HAFormal.bundle` into the Runner resources.
4. Add `-ObjC` to Other Linker Flags. Link `GLKit.framework`,
   `libbz2.tbd`, `libc++.tbd`, and `libz.tbd`.
5. When using the location layer, add the appropriate `NSLocation*UsageDescription`
   keys to the application `Info.plist` and request permission in the app.
6. Run `pod install` and test on a physical arm64 device.

Huawei's published iOS SDK has no simulator slice. Simulator builds remain
available for Flutter/Xcode CI and render a diagnostic placeholder instead of
a live map.

Follow Huawei's
[official iOS integration guide](https://developer.huawei.com/consumer/en/doc/HMSCore-Guides/ios-sdk-integrating-sdk-0000001197754692).

### HarmonyOS NEXT / OHOS

Use the
[OpenHarmony Flutter distribution](https://gitee.com/openharmony-sig/flutter_flutter)
and declare both packages from the same commit:

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

The companion package contains only the OHOS-specific `OhosView` registration;
the native ArkTS Map Kit bridge remains in this package. Configure Map Kit for
the signed HarmonyOS application and use `compatibleSdkVersion >= 12`. The
Flutter tool generates the native plugin registration automatically. The host
application must declare `ohos.permission.INTERNET`; location-layer users must
also declare and request the HarmonyOS location permissions required by their
target API level.

For plugin layout and platform-view background, see the official
[OHOS plugin adaptation guide](https://gitee.com/openharmony-sig/flutter_samples/blob/master/ohos/docs/07_plugin/ohos%E5%B9%B3%E5%8F%B0%E9%80%82%E9%85%8Dflutter%E4%B8%89%E6%96%B9%E5%BA%93%E6%8C%87%E5%AF%BC.md)
and
[platform-view guide](https://gitee.com/openharmony-sig/flutter_samples/blob/master/ohos/docs/04_development/%E5%A6%82%E4%BD%95%E4%BD%BF%E7%94%A8PlatformView.md).

### Capability guards

```dart
if (HuaweiMapPlatformCapabilities.supportsHeatMaps) {
  // Add or update heat maps.
}

if (HuaweiMapPlatformCapabilities.supportsGroundOverlays) {
  // Add or update ground overlays.
}

if (HuaweiMapPlatformCapabilities.supportsTileOverlays) {
  // Add or update tile overlays.
}
```

## Documentation

- [Quick Start](https://developer.huawei.com/consumer/en/doc/HMS-Plugin-Guides/createmap-0000001050190759-V1?ha_source=hms1)
- [Reference](https://developer.huawei.com/consumer/en/doc/HMS-Plugin-References/overview-0000001051586849-V1?ha_source=hms1)
- [iOS SDK integration](https://developer.huawei.com/consumer/en/doc/HMSCore-Guides/ios-sdk-integrating-sdk-0000001197754692)
- [HarmonyOS map display](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/map-presenting)
- [Platform support matrix](PLATFORM_SUPPORT.md)

## Questions or Issues

If you have questions about how to use HMS samples, try the following options:

- [Stack Overflow](https://stackoverflow.com/questions/tagged/huawei-mobile-services) is the best place for any programming questions. Be sure to tag your question with
  **huawei-mobile-services**.
- [Github](https://github.com/HMS-Core/hms-flutter-plugin) is the official repository for these plugins, You can open an issue or submit your ideas.
- [Huawei Developer Forum](https://forums.developer.huawei.com/forumPortal/en/home?fid=0101187876626530001&ha_source=hms1) HMS Core Module is great for general questions, or seeking recommendations and opinions.
- [Huawei Developer Docs](https://developer.huawei.com/consumer/en/doc/overview/HMS-Core-Plugin?ha_source=hms1) is place to official documentation for all HMS Core Kits, you can find detailed documentations in there.

If you run into a bug in our samples, please submit an issue to the [GitHub repository](https://github.com/HMS-Core/hms-flutter-plugin).

## License

Huawei Map Kit Flutter Plugin is licensed under [Apache 2.0 license](LICENSE)
