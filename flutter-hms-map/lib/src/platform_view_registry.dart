/*
    Copyright 2026. Huawei Map Kit Flutter compatibility contributors.

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

/// Builds a Huawei Map platform view supplied by a Dart platform package.
typedef HuaweiMapPlatformViewBuilder = Widget Function(
  Map<String, dynamic> creationParams,
  Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  PlatformViewCreatedCallback onPlatformViewCreated,
);

/// Registration point used by the optional `huawei_map_ohos` Dart adapter.
///
/// OpenHarmony Flutter adds `OhosView`, which is absent from upstream Flutter.
/// Keeping that symbol in a small companion package lets the app-facing plugin
/// continue to analyze and build with both Flutter distributions.
abstract class HuaweiMapPlatformViewRegistry {
  static HuaweiMapPlatformViewBuilder? _ohosBuilder;

  static bool get isOhos =>
      defaultTargetPlatform.toString() == 'TargetPlatform.ohos';

  static void registerOhos(HuaweiMapPlatformViewBuilder builder) {
    _ohosBuilder = builder;
  }

  static Widget buildOhosView(
    Map<String, dynamic> creationParams,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
    PlatformViewCreatedCallback onPlatformViewCreated,
  ) {
    final HuaweiMapPlatformViewBuilder? builder = _ohosBuilder;
    if (builder == null) {
      throw MissingPluginException(
        'OHOS support requires huawei_map_ohos as a direct dependency.',
      );
    }
    return builder(creationParams, gestureRecognizers, onPlatformViewCreated);
  }
}
