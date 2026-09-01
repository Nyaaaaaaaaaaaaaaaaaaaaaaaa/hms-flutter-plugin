#!/usr/bin/env bash
set -euo pipefail

plugin_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_root="$(cd "$plugin_root/.." && pwd)"

fail() {
  echo "platform contract: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "missing $1"
}

require_text() {
  local needle="$1"
  local file="$2"
  grep -Fq "$needle" "$file" || fail "'$needle' missing from $file"
}

dart_api="$plugin_root/lib/huawei_map.dart"
dart_methods="$plugin_root/lib/src/constants/method.dart"
dart_channel="$plugin_root/lib/src/channel/huawei_map_method_channel.dart"
dart_channel_names="$plugin_root/lib/src/constants/channel.dart"
ios_view="$plugin_root/ios/Classes/HMSMapPlatformView.m"
ios_plugin="$plugin_root/ios/Classes/HMSMapPlugin.m"
ohos_view="$plugin_root/ohos/src/main/ets/components/plugin/HmsMapPlatformView.ets"
ohos_plugin="$plugin_root/ohos/src/main/ets/components/plugin/HmsMapPlugin.ets"
ohos_component="$plugin_root/ohos/src/main/ets/components/plugin/HmsMapComponent.ets"
ohos_adapter="$repo_root/flutter-hms-map-ohos/lib/huawei_map_ohos.dart"

for file in \
  "$dart_api" \
  "$dart_methods" \
  "$dart_channel" \
  "$dart_channel_names" \
  "$plugin_root/ios/huawei_map.podspec" \
  "$ios_view" \
  "$ios_plugin" \
  "$plugin_root/ohos/index.ets" \
  "$plugin_root/ohos/oh-package.json5" \
  "$ohos_view" \
  "$ohos_plugin" \
  "$ohos_component" \
  "$repo_root/flutter-hms-map-ohos/LICENSE" \
  "$repo_root/flutter-hms-map-ohos/pubspec.yaml" \
  "$ohos_adapter"
do
  require_file "$file"
done

require_text "part 'src/platform_capabilities.dart';" "$dart_api"
require_text "part 'src/platform_view_registry.dart';" "$dart_api"
require_text "UiKitView(" "$dart_channel"
require_text "HuaweiMapPlatformViewRegistry.buildOhosView" "$dart_channel"
require_text "pluginClass: HMSMapPlugin" "$plugin_root/pubspec.yaml"
require_text "pluginClass: HmsMapPlugin" "$plugin_root/pubspec.yaml"
require_text "dartPluginClass: HuaweiMapOhos" "$repo_root/flutter-hms-map-ohos/pubspec.yaml"
require_text "OhosView(" "$ohos_adapter"
require_text "HuaweiMapPlatformViewRegistry.registerOhos" "$ohos_adapter"
require_text "MapComponent({" "$ohos_component"
require_text "registerViewFactory(" "$ohos_plugin"
require_text "TARGET_OS_SIMULATOR" "$ios_view"
require_text "unsupported_on_ios" "$ios_view"
require_text "unsupported_on_ohos" "$ohos_view"

view_type="com.huawei.hms.flutter.map/map"
require_text "$view_type" "$dart_channel_names"
require_text "$view_type" "$ios_plugin"
require_text "$view_type" "$ohos_plugin"
require_text "$view_type" "$ohos_adapter"

while IFS= read -r method; do
  [[ -n "$method" ]] || continue
  if ! grep -Fq "$method" "$ios_view" "$ios_plugin"; then
    [[ "$method" == "[InfoWindow]longClick" ||
       "$method" == "[Map]onMyLocationButtonClick" ]] ||
      fail "iOS does not handle Dart method $method"
  fi
  if ! grep -Fq "$method" "$ohos_view" "$ohos_plugin"; then
    [[ "$method" == "[GroundOverlay]click" ||
       "$method" == "[InfoWindow]longClick" ]] ||
      fail "OHOS does not handle Dart method $method"
  fi
done < <(
  rg -o "'(\\[[^']+\\][^']+|clearTileCache|MarkerStartAnimation|CircleStartAnimation)'" \
    "$dart_methods" |
    tr -d "'" |
    sort -u
)

dart_version="$(awk -F': ' '$1 == "version" { print $2; exit }' "$plugin_root/pubspec.yaml")"
adapter_version="$(awk -F': ' '$1 == "version" { print $2; exit }' "$repo_root/flutter-hms-map-ohos/pubspec.yaml")"
pod_version="$(awk -F"'" '/s.version/ { print $2; exit }' "$plugin_root/ios/huawei_map.podspec")"
ohos_version="$(sed -n 's/.*"version": "\([^"]*\)".*/\1/p' "$plugin_root/ohos/oh-package.json5" | head -1)"

[[ "$dart_version" == "$adapter_version" ]] ||
  fail "Dart package versions differ: $dart_version vs $adapter_version"
[[ "$pod_version" == "${dart_version/+/.}" ]] ||
  fail "pod version $pod_version does not match $dart_version"
[[ "$ohos_version" == "${dart_version/+/-}" ]] ||
  fail "OHOS version $ohos_version does not match $dart_version"

forbidden="$(find "$plugin_root/ios" "$plugin_root/ohos" -type f \
  \( -name '*.framework' -o -name '*.xcframework' -o -name '*.bundle' \
     -o -name '*.zip' -o -name 'flutter.har' -o -name 'agconnect-services.*' \) \
  -print)"
[[ -z "$forbidden" ]] ||
  fail "proprietary binary, runtime, or credential was committed: $forbidden"

echo "platform contract: Android/iOS/OHOS bridge checks passed"
