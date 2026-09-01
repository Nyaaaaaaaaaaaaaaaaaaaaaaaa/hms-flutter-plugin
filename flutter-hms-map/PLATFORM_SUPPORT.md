# Platform support

This document is the compatibility contract for the shared
`package:huawei_map/huawei_map.dart` API on this fork.

| Capability | Android | iOS | HarmonyOS NEXT / OHOS |
| --- | :---: | :---: | :---: |
| Native map and camera | Yes | Yes | Yes |
| Map/camera/POI events | Yes | Yes | Yes |
| Markers and info windows | Yes | Yes | Yes |
| Polylines, polygons, circles | Yes | Yes | Yes |
| Ground overlays | Yes | Yes | No |
| URL/repetitive/static tile overlays | Yes | Yes | No |
| Native snapshot | Yes | Yes | Yes |
| My-location layer | Yes | Yes | Yes |
| JSON/style ID | Yes | Yes | Yes |
| Distance and coordinate utilities | Yes | Compatible | Yes |
| Heat maps | Yes | No | No |
| Marker clustering | Yes | No | No |
| Marker/circle animation sets | Yes | No | No |
| Custom location source | Yes | No | No |

`Compatible` means the iOS bridge implements the same Dart contract locally:
Haversine distance and WGS84-to-GCJ02 conversion. Logger and Android credential
setter calls are non-failing compatibility no-ops because iOS credentials come
from `agconnect-services.plist`.

## Runtime behavior

- Unsupported calls return a `PlatformException` whose code is
  `unsupported_on_ios` or `unsupported_on_ohos`.
- `HuaweiMapPlatformCapabilities` exposes guards for optional feature groups.
- The iOS 6.4.x SDK documents overlay click delivery for polylines. Polygon,
  circle, and ground-overlay click callbacks should not be treated as portable.
- Info-window long-click is Android-only. My-location button click is available
  on Android and OHOS, but the iOS SDK does not expose that callback. Basic
  info-window show, hide, click, and close behavior is bridged where the
  platform SDK exposes it.
- The iOS 6.4.x SDK does not expose polygon holes, gradient/per-segment
  polyline colors, or bitmap-backed custom caps. OHOS supports holes and
  gradient colors; a custom cap falls back to a butt cap. Other supported
  styles are translated to their closest native equivalent.
- OHOS uses Map Kit's supported zoom range of 2 through 20. iOS uses the range
  reported by the installed native SDK.

## Minimums and SDK ownership

| Platform | Minimum | SDK integration |
| --- | --- | --- |
| Android | API 20 | Gradle/Maven dependency in the plugin |
| iOS | iOS 11, physical arm64 for a live map | Host embeds Huawei Map Kit iOS 6.4.x frameworks and resources |
| OHOS | compatible SDK API 12 | Host uses a Map Kit-enabled HarmonyOS SDK and a signed AppGallery Connect app |

The repository never vendors Huawei's proprietary iOS frameworks, bundles,
`flutter.har`, signing files, or application credentials.

## OHOS package split

Upstream Flutter does not define `OhosView`, while the OpenHarmony Flutter fork
does. To keep the main Dart package analyzable by both distributions:

- `huawei_map` owns the public API and the native ArkTS plugin.
- `huawei_map_ohos` owns only the Dart `OhosView` builder registration.

OHOS applications must depend on both packages at the same Git ref. Android and
iOS applications need only `huawei_map`.

## References

- [Huawei Map Kit iOS SDK integration](https://developer.huawei.com/consumer/en/doc/HMSCore-Guides/ios-sdk-integrating-sdk-0000001197754692)
- [Huawei HarmonyOS MapComponent guide](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/map-presenting)
- [OpenHarmony Flutter plugin adaptation](https://gitee.com/openharmony-sig/flutter_samples/blob/master/ohos/docs/07_plugin/ohos%E5%B9%B3%E5%8F%B0%E9%80%82%E9%85%8Dflutter%E4%B8%89%E6%96%B9%E5%BA%93%E6%8C%87%E5%AF%BC.md)
- [OpenHarmony Flutter PlatformView guide](https://gitee.com/openharmony-sig/flutter_samples/blob/master/ohos/docs/04_development/%E5%A6%82%E4%BD%95%E4%BD%BF%E7%94%A8PlatformView.md)
