/*
    Copyright 2020-2026. Huawei Technologies Co., Ltd. All rights reserved.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        https://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

part of '../huawei_map.dart';

/// Platform feature availability for code shared by Android, iOS, and OHOS.
///
/// Native Map Kit SDKs do not expose identical feature sets. Query these flags
/// before showing a platform-specific control.
abstract class HuaweiMapPlatformCapabilities {
  /// Whether the app is running on the OpenHarmony Flutter target.
  ///
  /// The string check preserves source compatibility with upstream Flutter,
  /// whose [TargetPlatform] does not declare `ohos`.
  static bool get isOhos =>
      defaultTargetPlatform.toString() == 'TargetPlatform.ohos';

  /// Whether the current platform is supported by this plugin.
  static bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      isOhos;

  /// Heat map overlays are currently available only on Android.
  static bool get supportsHeatMaps =>
      defaultTargetPlatform == TargetPlatform.android;

  /// Marker clustering is currently available only on Android.
  static bool get supportsMarkerClustering =>
      defaultTargetPlatform == TargetPlatform.android;

  /// Marker and circle animation sets are currently available only on Android.
  static bool get supportsOverlayAnimations =>
      defaultTargetPlatform == TargetPlatform.android;

  /// Custom location sources are currently available only on Android.
  static bool get supportsCustomLocationSource =>
      defaultTargetPlatform == TargetPlatform.android;

  /// URL-template tile overlays are currently supported on Android and iOS.
  static bool get supportsUrlTileOverlays =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Tile overlays are currently supported on Android and iOS.
  static bool get supportsTileOverlays => supportsUrlTileOverlays;

  /// Markers, polylines, polygons, and circles are supported everywhere.
  static bool get supportsCoreOverlays => isSupported;

  /// Ground overlays are currently supported on Android and iOS.
  static bool get supportsGroundOverlays =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Native map snapshots are supported everywhere.
  static bool get supportsSnapshots => isSupported;

  /// Info-window long-click callbacks are currently available only on Android.
  static bool get supportsInfoWindowLongClick =>
      defaultTargetPlatform == TargetPlatform.android;

  /// My-location button click callbacks are available on Android and OHOS.
  static bool get supportsMyLocationButtonClick =>
      defaultTargetPlatform == TargetPlatform.android || isOhos;

  /// Polygon and circle click callbacks are available on Android and OHOS.
  static bool get supportsPolygonAndCircleClickEvents =>
      defaultTargetPlatform == TargetPlatform.android || isOhos;

  /// Ground-overlay click callbacks are currently available only on Android.
  static bool get supportsGroundOverlayClickEvents =>
      defaultTargetPlatform == TargetPlatform.android;

  /// Gradient and per-segment polyline colors are available on Android/OHOS.
  static bool get supportsPolylineGradient =>
      defaultTargetPlatform == TargetPlatform.android || isOhos;

  /// Polygon holes are available on Android and OHOS.
  static bool get supportsPolygonHoles =>
      defaultTargetPlatform == TargetPlatform.android || isOhos;

  /// Bitmap-backed custom line caps are currently available only on Android.
  static bool get supportsCustomCaps =>
      defaultTargetPlatform == TargetPlatform.android;
}
