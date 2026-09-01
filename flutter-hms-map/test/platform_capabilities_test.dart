/*
 * Copyright 2026 The huawei_map compatibility contributors.
 * Licensed under the Apache License, Version 2.0.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huawei_map/huawei_map.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('Android exposes the complete optional feature surface', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(HuaweiMapPlatformCapabilities.isSupported, isTrue);
    expect(HuaweiMapPlatformCapabilities.supportsCoreOverlays, isTrue);
    expect(HuaweiMapPlatformCapabilities.supportsGroundOverlays, isTrue);
    expect(HuaweiMapPlatformCapabilities.supportsTileOverlays, isTrue);
    expect(HuaweiMapPlatformCapabilities.supportsUrlTileOverlays, isTrue);
    expect(HuaweiMapPlatformCapabilities.supportsHeatMaps, isTrue);
    expect(HuaweiMapPlatformCapabilities.supportsMarkerClustering, isTrue);
    expect(HuaweiMapPlatformCapabilities.supportsOverlayAnimations, isTrue);
    expect(HuaweiMapPlatformCapabilities.supportsCustomLocationSource, isTrue);
    expect(HuaweiMapPlatformCapabilities.supportsSnapshots, isTrue);
    expect(HuaweiMapPlatformCapabilities.supportsInfoWindowLongClick, isTrue);
    expect(HuaweiMapPlatformCapabilities.supportsMyLocationButtonClick, isTrue);
    expect(
      HuaweiMapPlatformCapabilities.supportsPolygonAndCircleClickEvents,
      isTrue,
    );
    expect(
      HuaweiMapPlatformCapabilities.supportsGroundOverlayClickEvents,
      isTrue,
    );
    expect(HuaweiMapPlatformCapabilities.supportsPolylineGradient, isTrue);
    expect(HuaweiMapPlatformCapabilities.supportsPolygonHoles, isTrue);
    expect(HuaweiMapPlatformCapabilities.supportsCustomCaps, isTrue);
  });

  test(
    'iOS exposes native Map Kit features and rejects Android-only groups',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      expect(HuaweiMapPlatformCapabilities.isSupported, isTrue);
      expect(HuaweiMapPlatformCapabilities.supportsCoreOverlays, isTrue);
      expect(HuaweiMapPlatformCapabilities.supportsGroundOverlays, isTrue);
      expect(HuaweiMapPlatformCapabilities.supportsTileOverlays, isTrue);
      expect(HuaweiMapPlatformCapabilities.supportsUrlTileOverlays, isTrue);
      expect(HuaweiMapPlatformCapabilities.supportsHeatMaps, isFalse);
      expect(HuaweiMapPlatformCapabilities.supportsMarkerClustering, isFalse);
      expect(HuaweiMapPlatformCapabilities.supportsOverlayAnimations, isFalse);
      expect(
        HuaweiMapPlatformCapabilities.supportsCustomLocationSource,
        isFalse,
      );
      expect(HuaweiMapPlatformCapabilities.supportsSnapshots, isTrue);
      expect(
        HuaweiMapPlatformCapabilities.supportsInfoWindowLongClick,
        isFalse,
      );
      expect(
        HuaweiMapPlatformCapabilities.supportsMyLocationButtonClick,
        isFalse,
      );
      expect(
        HuaweiMapPlatformCapabilities.supportsPolygonAndCircleClickEvents,
        isFalse,
      );
      expect(
        HuaweiMapPlatformCapabilities.supportsGroundOverlayClickEvents,
        isFalse,
      );
      expect(HuaweiMapPlatformCapabilities.supportsPolylineGradient, isFalse);
      expect(HuaweiMapPlatformCapabilities.supportsPolygonHoles, isFalse);
      expect(HuaweiMapPlatformCapabilities.supportsCustomCaps, isFalse);
    },
  );

  test('unsupported upstream Flutter targets report no capabilities', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    expect(HuaweiMapPlatformCapabilities.isSupported, isFalse);
    expect(HuaweiMapPlatformCapabilities.supportsCoreOverlays, isFalse);
    expect(HuaweiMapPlatformCapabilities.supportsGroundOverlays, isFalse);
    expect(HuaweiMapPlatformCapabilities.supportsTileOverlays, isFalse);
    expect(HuaweiMapPlatformCapabilities.supportsUrlTileOverlays, isFalse);
    expect(HuaweiMapPlatformCapabilities.supportsSnapshots, isFalse);
    expect(HuaweiMapPlatformCapabilities.supportsInfoWindowLongClick, isFalse);
    expect(
      HuaweiMapPlatformCapabilities.supportsMyLocationButtonClick,
      isFalse,
    );
    expect(
      HuaweiMapPlatformCapabilities.supportsPolygonAndCircleClickEvents,
      isFalse,
    );
    expect(
      HuaweiMapPlatformCapabilities.supportsGroundOverlayClickEvents,
      isFalse,
    );
    expect(HuaweiMapPlatformCapabilities.supportsPolylineGradient, isFalse);
    expect(HuaweiMapPlatformCapabilities.supportsPolygonHoles, isFalse);
    expect(HuaweiMapPlatformCapabilities.supportsCustomCaps, isFalse);
  });
}
