/*
 * Copyright 2020-2026. Huawei Technologies Co., Ltd. All rights reserved.
 * Licensed under the Apache License, Version 2.0.
 */

import {
  FlutterPlugin,
  FlutterPluginBinding
} from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import MethodChannel, {
  MethodCallHandler,
  MethodResult
} from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import StandardMessageCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/StandardMessageCodec';
import StandardMethodCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/StandardMethodCodec';
import { map, mapCommon } from '@kit.MapKit';
import HmsMapViewFactory from './HmsMapViewFactory';

const MAP_VIEW_TYPE: string = 'com.huawei.hms.flutter.map/map';
const MAP_UTIL_CHANNEL: string = 'com.huawei.hms.flutter.map/mapUtils';

export default class HmsMapPlugin implements FlutterPlugin, MethodCallHandler {
  private utilityChannel: MethodChannel | null = null;

  getUniqueClassName(): string {
    return 'HmsMapPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    binding.getPlatformViewRegistry()?.registerViewFactory(
      MAP_VIEW_TYPE,
      new HmsMapViewFactory(
        binding.getBinaryMessenger(),
        StandardMessageCodec.INSTANCE
      )
    );
    this.utilityChannel = new MethodChannel(
      binding.getBinaryMessenger(),
      MAP_UTIL_CHANNEL,
      StandardMethodCodec.INSTANCE
    );
    this.utilityChannel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(_binding: FlutterPluginBinding): void {
    this.utilityChannel?.setMethodCallHandler(null);
    this.utilityChannel = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    try {
      switch (call.method) {
        case '[MapUtil]distanceCalculator': {
          const points: Array<ESObject> = call.args as Array<ESObject>;
          result.success(map.calculateDistance(
            this.toLatLng(points[0]),
            this.toLatLng(points[1])
          ));
          return;
        }
        case '[MapUtil]convertCoordinate':
          result.success(this.fromLatLng(this.convertCoordinate(call.args)));
          return;
        case '[MapUtil]convertCoordinates': {
          const source: Array<ESObject> = call.args as Array<ESObject>;
          const converted: Array<Array<number>> = new Array<Array<number>>();
          source.forEach((value: ESObject) => {
            converted.push(this.fromLatLng(this.convertCoordinate(value)));
          });
          result.success(converted);
          return;
        }
        case '[MapUtil]initializeMap':
        case '[MapUtil]setApiKey':
        case '[MapUtil]setAccessToken':
        case '[MapUtil]enableLogger':
        case '[MapUtil]disableLogger':
          // HarmonyOS Map Kit reads identity and credentials from the signed
          // application profile, so these Android compatibility calls are no-ops.
          result.success(null);
          return;
        default:
          result.notImplemented();
      }
    } catch (error) {
      result.error(
        'HUAWEI_MAP_OHOS_UTIL',
        (error as Error).message,
        null
      );
    }
  }

  private convertCoordinate(value: ESObject): mapCommon.LatLng {
    return map.convertCoordinateSync(
      mapCommon.CoordinateType.WGS84,
      mapCommon.CoordinateType.GCJ02,
      this.toLatLng(value)
    );
  }

  private toLatLng(value: ESObject): mapCommon.LatLng {
    const coordinate: Array<number> = value as Array<number>;
    return {
      latitude: Number(coordinate[0]),
      longitude: Number(coordinate[1])
    };
  }

  private fromLatLng(value: mapCommon.LatLng): Array<number> {
    return [value.latitude, value.longitude];
  }
}
