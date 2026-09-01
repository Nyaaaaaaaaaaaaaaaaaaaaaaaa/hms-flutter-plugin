/*
 * Copyright 2026 The huawei_map OHOS compatibility contributors.
 * Licensed under the Apache License, Version 2.0.
 */

library huawei_map_ohos;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:huawei_map/huawei_map.dart';

/// Installs the OHOS-only `OhosView` builder into the app-facing package.
class HuaweiMapOhos {
  static void registerWith() {
    HuaweiMapPlatformViewRegistry.registerOhos((
      Map<String, dynamic> creationParams,
      Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
      PlatformViewCreatedCallback onPlatformViewCreated,
    ) {
      return OhosView(
        viewType: 'com.huawei.hms.flutter.map/map',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        gestureRecognizers: gestureRecognizers,
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        onPlatformViewCreated: onPlatformViewCreated,
      );
    });
  }
}
