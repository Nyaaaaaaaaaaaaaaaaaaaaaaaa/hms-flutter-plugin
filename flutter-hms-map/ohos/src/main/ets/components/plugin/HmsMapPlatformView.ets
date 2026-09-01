/*
 * Copyright 2020-2026. Huawei Technologies Co., Ltd. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { BinaryMessenger } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import MethodChannel, {
  MethodCallHandler,
  MethodResult
} from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import StandardMethodCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/StandardMethodCodec';
import PlatformView, {
  Params
} from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';
import { map, mapCommon } from '@kit.MapKit';
import { util } from '@kit.ArkTS';
import { HmsMapBuilder } from './HmsMapComponent';

const CHANNEL_PREFIX: string = 'com.huawei.hms.flutter.map/map_';
const ERROR_CODE: string = 'HUAWEI_MAP_OHOS';
const UNSUPPORTED_CODE: string = 'unsupported_on_ohos';

interface FlutterMapEntry {
  key: string;
  value: ESObject;
}

/**
 * HarmonyOS NEXT implementation of the platform view used by the public
 * huawei_map Dart API. Flutter StandardMessageCodec decodes Dart maps into
 * ArkTS Map instances, so all conversion is kept at this boundary.
 */
export default class HmsMapPlatformView extends PlatformView implements MethodCallHandler {
  private readonly creationParams: Map<string, ESObject>;
  private readonly channel: MethodChannel;
  private controller: map.MapComponentController | null = null;
  private eventManager: map.MapEventManager | null = null;
  private pendingMapResult: MethodResult | null = null;
  private mapError: BusinessError | null = null;
  private trackCameraPosition: boolean = false;

  private readonly markers: Map<string, map.Marker> = new Map();
  private readonly markerIds: Map<string, string> = new Map();
  private readonly polylines: Map<string, map.MapPolyline> = new Map();
  private readonly polylineIds: Map<string, string> = new Map();
  private readonly polygons: Map<string, map.MapPolygon> = new Map();
  private readonly polygonIds: Map<string, string> = new Map();
  private readonly circles: Map<string, map.MapCircle> = new Map();
  private readonly circleIds: Map<string, string> = new Map();

  constructor(
    _context: common.Context,
    viewId: number,
    args: ESObject,
    messenger: BinaryMessenger
  ) {
    super();
    this.creationParams = this.asMap(args);
    this.channel = new MethodChannel(
      messenger,
      `${CHANNEL_PREFIX}${viewId}`,
      StandardMethodCodec.INSTANCE
    );
    this.channel.setMethodCallHandler(this);
  }

  getView(): WrappedBuilder<[Params]> {
    return new WrappedBuilder(HmsMapBuilder);
  }

  createMapOptions(): mapCommon.MapOptions {
    const initialCamera: ESObject | undefined =
      this.creationParams.get('initialCameraPosition');
    const position: mapCommon.CameraPosition = initialCamera === undefined
      ? {
        target: { latitude: 0, longitude: 0 },
        zoom: 2
      }
      : this.toCameraPosition(initialCamera);
    const options: mapCommon.MapOptions = { position: position };
    const value: ESObject | undefined = this.creationParams.get('options');
    if (value === undefined) {
      return options;
    }

    const source: Map<string, ESObject> = this.asMap(value);
    const mapType: ESObject | undefined = source.get('mapType');
    if (mapType !== undefined) {
      options.mapType = this.toMapType(Number(mapType));
    }
    const cameraBounds: ESObject | undefined = source.get('cameraTargetBounds');
    if (cameraBounds !== undefined) {
      const outer: Array<ESObject> = cameraBounds as Array<ESObject>;
      if (outer.length > 0) {
        options.bounds = this.toLatLngBounds(outer[0]);
      }
    }
    const zoomPreference: ESObject | undefined = source.get('minMaxZoomPreference');
    if (zoomPreference !== undefined) {
      const zooms: Array<number> = zoomPreference as Array<number>;
      options.minZoom = this.clampZoom(Number(zooms[0]));
      options.maxZoom = this.clampZoom(Number(zooms[1]));
    }
    this.copyBoolean(source, 'rotateGesturesEnabled', (enabled: boolean) => {
      options.rotateGesturesEnabled = enabled;
    });
    this.copyBoolean(source, 'scrollGesturesEnabled', (enabled: boolean) => {
      options.scrollGesturesEnabled = enabled;
    });
    this.copyBoolean(source, 'tiltGesturesEnabled', (enabled: boolean) => {
      options.tiltGesturesEnabled = enabled;
    });
    this.copyBoolean(source, 'zoomGesturesEnabled', (enabled: boolean) => {
      options.zoomGesturesEnabled = enabled;
    });
    this.copyBoolean(source, 'zoomControlsEnabled', (enabled: boolean) => {
      options.zoomControlsEnabled = enabled;
    });
    this.copyBoolean(source, 'myLocationButtonEnabled', (enabled: boolean) => {
      options.myLocationControlsEnabled = enabled;
    });
    this.copyBoolean(source, 'compassEnabled', (enabled: boolean) => {
      options.compassControlsEnabled = enabled;
    });
    this.copyBoolean(source, 'isDark', (enabled: boolean) => {
      options.dayNightMode = enabled
        ? mapCommon.DayNightMode.NIGHT
        : mapCommon.DayNightMode.DAY;
    });
    const padding: ESObject | undefined = source.get('padding');
    if (padding !== undefined) {
      options.padding = this.toPadding(padding);
    }
    const styleId: ESObject | undefined = source.get('styleId');
    if (styleId !== undefined) {
      options.styleId = String(styleId);
    }
    const track: ESObject | undefined = source.get('trackCameraPosition');
    if (track !== undefined) {
      this.trackCameraPosition = Boolean(track);
    }
    return options;
  }

  async onMapReady(controller: map.MapComponentController): Promise<void> {
    this.controller = controller;
    this.eventManager = controller.getEventManager();
    this.registerEvents();
    const options: ESObject | undefined = this.creationParams.get('options');
    if (options !== undefined) {
      await this.applyOptions(this.asMap(options));
    }
    await this.applyInitialOverlays();
    controller.show();
    if (this.pendingMapResult !== null) {
      this.pendingMapResult.success(null);
      this.pendingMapResult = null;
    }
  }

  onMapError(error: BusinessError): void {
    this.mapError = error;
    if (this.pendingMapResult !== null) {
      this.pendingMapResult.error(ERROR_CODE, error.message, error.code);
      this.pendingMapResult = null;
    }
  }

  onShown(): void {
    this.controller?.show();
  }

  onHidden(): void {
    this.controller?.hide();
  }

  dispose(): void {
    this.channel.setMethodCallHandler(null);
    this.pendingMapResult = null;
    this.eventManager?.off('cameraMoveStart');
    this.eventManager?.off('cameraMove');
    this.eventManager?.off('cameraIdle');
    this.eventManager?.off('cameraMoveCancel');
    this.eventManager?.off('mapClick');
    this.eventManager?.off('mapLongClick');
    this.eventManager?.off('poiClick');
    this.eventManager?.off('myLocationClick');
    this.eventManager?.off('myLocationButtonClick');
    this.eventManager?.off('markerClick');
    this.eventManager?.off('markerDragStart');
    this.eventManager?.off('markerDrag');
    this.eventManager?.off('markerDragEnd');
    this.eventManager?.off('infoWindowClick');
    this.eventManager?.off('infoWindowClose');
    this.eventManager?.off('polylineClick');
    this.eventManager?.off('polygonClick');
    this.eventManager?.off('circleClick');
    this.eventManager = null;
    this.controller?.clear();
    this.controller = null;
    this.markers.clear();
    this.markerIds.clear();
    this.polylines.clear();
    this.polylineIds.clear();
    this.polygons.clear();
    this.polygonIds.clear();
    this.circles.clear();
    this.circleIds.clear();
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    this.dispatchMethod(call, result).catch((error: Error) => {
      result.error(ERROR_CODE, error.message, null);
    });
  }

  private async dispatchMethod(call: MethodCall, result: MethodResult): Promise<void> {
    const controller: map.MapComponentController | null = this.controller;
    if (call.method === '[Map]waitForMap') {
      if (controller !== null) {
        result.success(null);
      } else if (this.mapError !== null) {
        result.error(ERROR_CODE, this.mapError.message, this.mapError.code);
      } else {
        this.pendingMapResult = result;
      }
      return;
    }
    if (controller === null) {
      result.error(ERROR_CODE, 'MapComponent is not ready.', null);
      return;
    }

    switch (call.method) {
      case '[Map]update': {
        const args: Map<string, ESObject> = this.asMap(call.args);
        const options: ESObject | undefined = args.get('options');
        if (options !== undefined) {
          await this.applyOptions(this.asMap(options));
        }
        result.success(this.fromCameraPosition(controller.getCameraPosition()));
        return;
      }
      case '[Map]getVisibleRegion': {
        const bounds: mapCommon.LatLngBounds =
          controller.getProjection().getVisibleRegion().bounds;
        result.success(this.fromBounds(bounds));
        return;
      }
      case '[Map]getScreenCoordinate': {
        const point: mapCommon.MapPoint =
          controller.getProjection().toScreenLocation(this.toLatLng(call.args));
        result.success(this.mapOf([
          { key: 'x', value: Math.round(point.positionX) },
          { key: 'y', value: Math.round(point.positionY) }
        ]));
        return;
      }
      case '[Map]getLatLng': {
        const pointMap: Map<string, ESObject> = this.asMap(call.args);
        const point: mapCommon.MapPoint = {
          positionX: Number(pointMap.get('x')),
          positionY: Number(pointMap.get('y'))
        };
        result.success(this.fromLatLng(
          controller.getProjection().fromScreenLocation(point)
        ));
        return;
      }
      case '[Camera]move': {
        const args: Map<string, ESObject> = this.asMap(call.args);
        controller.moveCamera(this.toCameraUpdate(args.get('cameraUpdate') as ESObject));
        result.success(null);
        return;
      }
      case '[Camera]animate': {
        const args: Map<string, ESObject> = this.asMap(call.args);
        controller.animateCamera(this.toCameraUpdate(args.get('cameraUpdate') as ESObject));
        result.success(null);
        return;
      }
      case '[Map]stopAnimation':
        controller.stopAnimation();
        result.success(null);
        return;
      case '[Map]takeSnapshot':
        result.success(await this.takeSnapshot(controller));
        return;
      case '[Markers]update':
        await this.updateMarkers(this.asMap(call.args));
        result.success(true);
        return;
      case '[Polylines]update':
        await this.updatePolylines(this.asMap(call.args));
        result.success(true);
        return;
      case '[Polygons]update':
        await this.updatePolygons(this.asMap(call.args));
        result.success(true);
        return;
      case '[Circles]update':
        await this.updateCircles(this.asMap(call.args));
        result.success(true);
        return;
      case '[Markers]showInfoWindow':
        this.markerFor(call.args).setInfoWindowVisible(true);
        result.success(null);
        return;
      case '[Markers]hideInfoWindow':
        this.markerFor(call.args).setInfoWindowVisible(false);
        result.success(null);
        return;
      case '[Markers]isInfoWindowShown':
        result.success(this.markerFor(call.args).isInfoWindowVisible());
        return;
      case '[Map]isCompassEnabled':
        result.success(controller.isCompassControlsEnabled());
        return;
      case '[Map]isDark':
        result.success(controller.getDayNightMode() === mapCommon.DayNightMode.NIGHT);
        return;
      case '[Map]isMapToolbarEnabled':
        result.success(false);
        return;
      case '[Map]getMinMaxZoomLevels':
        result.success([controller.getMinZoom(), controller.getMaxZoom()]);
        return;
      case '[Map]isZoomGesturesEnabled':
        result.success(controller.isZoomGesturesEnabled());
        return;
      case '[Map]isZoomControlsEnabled':
        result.success(controller.isZoomControlsEnabled());
        return;
      case '[Map]isScrollGesturesEnabled':
        result.success(controller.isScrollGesturesEnabled());
        return;
      case '[Map]isTiltGesturesEnabled':
        result.success(controller.isTiltGesturesEnabled());
        return;
      case '[Map]isRotateGesturesEnabled':
        result.success(controller.isRotateGesturesEnabled());
        return;
      case '[Map]isMyLocationButtonEnabled':
        result.success(controller.isMyLocationControlsEnabled());
        return;
      case '[Map]isTrafficEnabled':
        result.success(controller.isTrafficEnabled());
        return;
      case '[Map]isBuildingsEnabled':
        result.success(controller.isBuildingEnabled());
        return;
      case '[Map]getZoomLevel':
        result.success(controller.getCameraPosition().zoom);
        return;
      case '[Map]getScalePerPixel':
        result.success(controller.getScalePerPixel());
        return;
      case '[Map]setStyle': {
        const style: string = String(call.args);
        await controller.setCustomMapStyle({ styleContent: style });
        result.success(null);
        return;
      }
      case '[Markers]isMarkerClusterable':
        result.success(false);
        return;
      case '[GroundOverlays]update':
      case '[TileOverlays]update':
      case '[HeatMap]update':
      case 'clearTileCache':
      case 'MarkerStartAnimation':
      case 'CircleStartAnimation':
      case '[Map]setLocationSource':
      case '[Map]setLocation':
      case '[Map]deactivateLocationSource':
        result.error(
          UNSUPPORTED_CODE,
          `${call.method} is not available in the OHOS compatibility layer.`,
          'Check HuaweiMapPlatformCapabilities before invoking this API.'
        );
        return;
      default:
        result.notImplemented();
    }
  }

  private async applyInitialOverlays(): Promise<void> {
    await this.addMarkerList(this.creationParams.get('markersToAdd'));
    await this.addPolylineList(this.creationParams.get('polylinesToAdd'));
    await this.addPolygonList(this.creationParams.get('polygonsToAdd'));
    await this.addCircleList(this.creationParams.get('circlesToAdd'));
  }

  private async applyOptions(options: Map<string, ESObject>): Promise<void> {
    const controller: map.MapComponentController = this.requireController();
    const mapType: ESObject | undefined = options.get('mapType');
    if (mapType !== undefined) {
      controller.setMapType(this.toMapType(Number(mapType)));
    }
    const targetBounds: ESObject | undefined = options.get('cameraTargetBounds');
    if (targetBounds !== undefined) {
      const outer: Array<ESObject> = targetBounds as Array<ESObject>;
      if (outer.length > 0) {
        controller.setLatLngBounds(this.toLatLngBounds(outer[0]));
      }
    }
    const minMax: ESObject | undefined = options.get('minMaxZoomPreference');
    if (minMax !== undefined) {
      const zooms: Array<number> = minMax as Array<number>;
      controller.setMinZoom(this.clampZoom(Number(zooms[0])));
      controller.setMaxZoom(this.clampZoom(Number(zooms[1])));
    }
    this.copyBoolean(options, 'compassEnabled', (enabled: boolean) => {
      controller.setCompassControlsEnabled(enabled);
    });
    this.copyBoolean(options, 'rotateGesturesEnabled', (enabled: boolean) => {
      controller.setRotateGesturesEnabled(enabled);
    });
    this.copyBoolean(options, 'scrollGesturesEnabled', (enabled: boolean) => {
      controller.setScrollGesturesEnabled(enabled);
    });
    this.copyBoolean(options, 'tiltGesturesEnabled', (enabled: boolean) => {
      controller.setTiltGesturesEnabled(enabled);
    });
    this.copyBoolean(options, 'zoomGesturesEnabled', (enabled: boolean) => {
      controller.setZoomGesturesEnabled(enabled);
    });
    this.copyBoolean(options, 'zoomControlsEnabled', (enabled: boolean) => {
      controller.setZoomControlsEnabled(enabled);
    });
    this.copyBoolean(options, 'myLocationEnabled', (enabled: boolean) => {
      controller.setMyLocationEnabled(enabled);
    });
    this.copyBoolean(options, 'myLocationButtonEnabled', (enabled: boolean) => {
      controller.setMyLocationControlsEnabled(enabled);
    });
    this.copyBoolean(options, 'trafficEnabled', (enabled: boolean) => {
      controller.setTrafficEnabled(enabled);
    });
    this.copyBoolean(options, 'buildingsEnabled', (enabled: boolean) => {
      controller.setBuildingEnabled(enabled);
    });
    this.copyBoolean(options, 'allGesturesEnabled', (enabled: boolean) => {
      controller.setAllGesturesEnabled(enabled);
    });
    this.copyBoolean(options, 'gestureScaleByMapCenter', (enabled: boolean) => {
      controller.setGestureScaleByMapCenter(enabled);
    });
    this.copyBoolean(options, 'isDark', (enabled: boolean) => {
      controller.setDayNightMode(enabled
        ? mapCommon.DayNightMode.NIGHT
        : mapCommon.DayNightMode.DAY);
    });
    const padding: ESObject | undefined = options.get('padding');
    if (padding !== undefined) {
      controller.setPadding(this.toPadding(padding));
    }
    const point: ESObject | undefined = options.get('pointToCenter');
    if (point !== undefined) {
      const pointMap: Map<string, ESObject> = this.asMap(point);
      controller.setPointToCenter({
        positionX: Number(pointMap.get('x')),
        positionY: Number(pointMap.get('y'))
      });
    }
    const logoPosition: ESObject | undefined = options.get('logoPosition');
    if (logoPosition !== undefined) {
      controller.setLogoAlignment(this.toLogoAlignment(Number(logoPosition)));
    }
    const logoPadding: ESObject | undefined = options.get('logoPadding');
    if (logoPadding !== undefined) {
      controller.setLogoPadding(this.toPadding(logoPadding));
    }
    const styleId: ESObject | undefined = options.get('styleId');
    if (styleId !== undefined) {
      await controller.setCustomMapStyle({ styleId: String(styleId) });
    }
    const track: ESObject | undefined = options.get('trackCameraPosition');
    if (track !== undefined) {
      this.trackCameraPosition = Boolean(track);
    }
  }

  private registerEvents(): void {
    const events: map.MapEventManager = this.eventManager as map.MapEventManager;
    events.on('cameraMoveStart', (reason: number) => {
      this.channel.invokeMethod('[Camera]onMoveStarted', this.mapOf([
        { key: 'reason', value: reason }
      ]));
    });
    events.on('cameraMove', () => {
      if (this.controller !== null && this.trackCameraPosition) {
        this.channel.invokeMethod('[Camera]onMove', this.mapOf([
          {
            key: 'position',
            value: this.fromCameraPosition(this.controller.getCameraPosition())
          }
        ]));
      }
    });
    events.on('cameraIdle', () => {
      this.channel.invokeMethod('[Camera]onIdle', null);
    });
    events.on('cameraMoveCancel', () => {
      this.channel.invokeMethod('[Camera]onMoveCancelled', null);
    });
    events.on('mapClick', (position: mapCommon.LatLng) => {
      this.channel.invokeMethod('[Map]click', this.mapOf([
        { key: 'position', value: this.fromLatLng(position) }
      ]));
    });
    events.on('mapLongClick', (position: mapCommon.LatLng) => {
      this.channel.invokeMethod('[Map]onLongPress', this.mapOf([
        { key: 'position', value: this.fromLatLng(position) }
      ]));
    });
    events.on('poiClick', (poi: mapCommon.Poi) => {
      const value: Map<string, ESObject> = this.mapOf([
        { key: 'latLng', value: this.fromLatLng(poi.position) },
        { key: 'name', value: poi.name },
        { key: 'placeId', value: poi.id }
      ]);
      this.channel.invokeMethod('[Map]onPoiClick', this.mapOf([
        { key: 'pointOfInterest', value: value }
      ]));
    });
    events.on('myLocationClick', (position: mapCommon.LatLng) => {
      const location: Map<string, ESObject> = this.mapOf([
        { key: 'latitude', value: position.latitude },
        { key: 'longitude', value: position.longitude }
      ]);
      this.channel.invokeMethod('[Map]onMyLocationClick', this.mapOf([
        { key: 'location', value: location }
      ]));
    });
    events.on('myLocationButtonClick', () => {
      this.channel.invokeMethod('[Map]onMyLocationButtonClick', true);
    });
    events.on('markerClick', (marker: map.Marker) => {
      this.sendOverlayEvent('[Marker]click', 'markerId', this.markerIds, marker.getId());
    });
    events.on('markerDragStart', (marker: map.Marker) => {
      this.sendMarkerDragEvent('[Marker]onDragStart', marker);
    });
    events.on('markerDrag', (marker: map.Marker) => {
      this.sendMarkerDragEvent('[Marker]onDrag', marker);
    });
    events.on('markerDragEnd', (marker: map.Marker) => {
      this.sendMarkerDragEvent('[Marker]onDragEnd', marker);
    });
    events.on('infoWindowClick', (marker: map.Marker) => {
      this.sendOverlayEvent('[InfoWindow]click', 'markerId', this.markerIds, marker.getId());
    });
    events.on('infoWindowClose', (marker: map.Marker) => {
      this.sendOverlayEvent('[InfoWindow]close', 'markerId', this.markerIds, marker.getId());
    });
    events.on('polylineClick', (polyline: map.MapPolyline) => {
      this.sendOverlayEvent('[Polyline]click', 'polylineId', this.polylineIds, polyline.getId());
    });
    events.on('polygonClick', (polygon: map.MapPolygon) => {
      this.sendOverlayEvent('[Polygon]click', 'polygonId', this.polygonIds, polygon.getId());
    });
    events.on('circleClick', (circle: map.MapCircle) => {
      this.sendOverlayEvent('[Circle]click', 'circleId', this.circleIds, circle.getId());
    });
  }

  private sendMarkerDragEvent(method: string, marker: map.Marker): void {
    const dartId: string | undefined = this.markerIds.get(marker.getId());
    if (dartId === undefined) {
      return;
    }
    this.channel.invokeMethod(method, this.mapOf([
      { key: 'markerId', value: dartId },
      { key: 'position', value: this.fromLatLng(marker.getPosition()) }
    ]));
  }

  private sendOverlayEvent(
    method: string,
    key: string,
    ids: Map<string, string>,
    nativeId: string
  ): void {
    const dartId: string | undefined = ids.get(nativeId);
    if (dartId !== undefined) {
      this.channel.invokeMethod(method, this.mapOf([
        { key: key, value: dartId }
      ]));
    }
  }

  private async updateMarkers(args: Map<string, ESObject>): Promise<void> {
    this.removeOverlays(args.get('markerIdsToRemove'), this.markers, this.markerIds);
    await this.replaceMarkerList(args.get('markersToChange'));
    await this.addMarkerList(args.get('markersToAdd'));
  }

  private async updatePolylines(args: Map<string, ESObject>): Promise<void> {
    this.removeOverlays(args.get('polylineIdsToRemove'), this.polylines, this.polylineIds);
    await this.replacePolylineList(args.get('polylinesToChange'));
    await this.addPolylineList(args.get('polylinesToAdd'));
  }

  private async updatePolygons(args: Map<string, ESObject>): Promise<void> {
    this.removeOverlays(args.get('polygonIdsToRemove'), this.polygons, this.polygonIds);
    await this.replacePolygonList(args.get('polygonsToChange'));
    await this.addPolygonList(args.get('polygonsToAdd'));
  }

  private async updateCircles(args: Map<string, ESObject>): Promise<void> {
    this.removeOverlays(args.get('circleIdsToRemove'), this.circles, this.circleIds);
    await this.replaceCircleList(args.get('circlesToChange'));
    await this.addCircleList(args.get('circlesToAdd'));
  }

  private async addMarkerList(value: ESObject | undefined): Promise<void> {
    if (value === undefined) {
      return;
    }
    const list: Array<ESObject> = value as Array<ESObject>;
    for (let index: number = 0; index < list.length; index++) {
      await this.addMarker(this.asMap(list[index]));
    }
  }

  private async replaceMarkerList(value: ESObject | undefined): Promise<void> {
    if (value === undefined) {
      return;
    }
    const list: Array<ESObject> = value as Array<ESObject>;
    for (let index: number = 0; index < list.length; index++) {
      const data: Map<string, ESObject> = this.asMap(list[index]);
      this.removeOverlayById(String(data.get('markerId')), this.markers, this.markerIds);
      await this.addMarker(data);
    }
  }

  private async addMarker(data: Map<string, ESObject>): Promise<void> {
    const dartId: string = String(data.get('markerId'));
    const options: mapCommon.MarkerOptions = {
      position: this.toLatLng(data.get('position') as ESObject)
    };
    this.assignNumber(data, 'rotation', (value: number) => {
      options.rotation = value;
    });
    this.assignNumber(data, 'alpha', (value: number) => {
      options.alpha = value;
    });
    this.assignNumber(data, 'zIndex', (value: number) => {
      options.zIndex = value;
    });
    this.assignBoolean(data, 'clickable', (value: boolean) => {
      options.clickable = value;
    });
    this.assignBoolean(data, 'draggable', (value: boolean) => {
      options.draggable = value;
    });
    this.assignBoolean(data, 'flat', (value: boolean) => {
      options.flat = value;
    });
    this.assignBoolean(data, 'visible', (value: boolean) => {
      options.visible = value;
    });
    const anchor: ESObject | undefined = data.get('anchor');
    if (anchor !== undefined) {
      const values: Array<number> = anchor as Array<number>;
      options.anchorU = Number(values[0]);
      options.anchorV = Number(values[1]);
    }
    const info: ESObject | undefined = data.get('infoWindow');
    if (info !== undefined) {
      const infoMap: Map<string, ESObject> = this.asMap(info);
      const title: ESObject | undefined = infoMap.get('title');
      const snippet: ESObject | undefined = infoMap.get('snippet');
      if (title !== undefined) {
        options.title = String(title);
      }
      if (snippet !== undefined) {
        options.snippet = String(snippet);
      }
      const infoAnchor: ESObject | undefined = infoMap.get('anchor');
      if (infoAnchor !== undefined) {
        const values: Array<number> = infoAnchor as Array<number>;
        options.infoWindowAnchorU = Number(values[0]);
        options.infoWindowAnchorV = Number(values[1]);
      }
    }
    const icon: ESObject | undefined = data.get('icon');
    if (icon !== undefined) {
      const converted: string | undefined = this.toIcon(icon);
      if (converted !== undefined) {
        options.icon = converted;
      }
    }
    const marker: map.Marker = await this.requireController().addMarker(options);
    this.markers.set(dartId, marker);
    this.markerIds.set(marker.getId(), dartId);
  }

  private async addPolylineList(value: ESObject | undefined): Promise<void> {
    if (value === undefined) {
      return;
    }
    const list: Array<ESObject> = value as Array<ESObject>;
    for (let index: number = 0; index < list.length; index++) {
      await this.addPolyline(this.asMap(list[index]));
    }
  }

  private async replacePolylineList(value: ESObject | undefined): Promise<void> {
    if (value === undefined) {
      return;
    }
    const list: Array<ESObject> = value as Array<ESObject>;
    for (let index: number = 0; index < list.length; index++) {
      const data: Map<string, ESObject> = this.asMap(list[index]);
      this.removeOverlayById(String(data.get('polylineId')), this.polylines, this.polylineIds);
      await this.addPolyline(data);
    }
  }

  private async addPolyline(data: Map<string, ESObject>): Promise<void> {
    const dartId: string = String(data.get('polylineId'));
    const options: mapCommon.MapPolylineOptions = {
      points: this.toLatLngList(data.get('points') as ESObject)
    };
    this.assignBoolean(data, 'clickable', (value: boolean) => {
      options.clickable = value;
    });
    this.assignBoolean(data, 'geodesic', (value: boolean) => {
      options.geodesic = value;
    });
    this.assignBoolean(data, 'visible', (value: boolean) => {
      options.visible = value;
    });
    this.assignBoolean(data, 'gradient', (value: boolean) => {
      options.gradient = value;
    });
    this.assignNumber(data, 'color', (value: number) => {
      options.color = value;
    });
    this.assignNumber(data, 'width', (value: number) => {
      options.width = value;
    });
    this.assignNumber(data, 'zIndex', (value: number) => {
      options.zIndex = value;
    });
    const colors: ESObject | undefined = data.get('colorValues');
    if (colors !== undefined) {
      options.colors = (colors as Array<number>).map((value: number) => Number(value));
    }
    const joint: ESObject | undefined = data.get('jointType');
    if (joint !== undefined) {
      options.jointType = this.toJointType(Number(joint));
    }
    const startCap: ESObject | undefined = data.get('startCap');
    if (startCap !== undefined) {
      options.startCap = this.toCap(startCap);
    }
    const endCap: ESObject | undefined = data.get('endCap');
    if (endCap !== undefined) {
      options.endCap = this.toCap(endCap);
    }
    const patterns: ESObject | undefined = data.get('pattern');
    if (patterns !== undefined) {
      options.patterns = this.toPatterns(patterns);
    }
    const polyline: map.MapPolyline = await this.requireController().addPolyline(options);
    this.polylines.set(dartId, polyline);
    this.polylineIds.set(polyline.getId(), dartId);
  }

  private async addPolygonList(value: ESObject | undefined): Promise<void> {
    if (value === undefined) {
      return;
    }
    const list: Array<ESObject> = value as Array<ESObject>;
    for (let index: number = 0; index < list.length; index++) {
      await this.addPolygon(this.asMap(list[index]));
    }
  }

  private async replacePolygonList(value: ESObject | undefined): Promise<void> {
    if (value === undefined) {
      return;
    }
    const list: Array<ESObject> = value as Array<ESObject>;
    for (let index: number = 0; index < list.length; index++) {
      const data: Map<string, ESObject> = this.asMap(list[index]);
      this.removeOverlayById(String(data.get('polygonId')), this.polygons, this.polygonIds);
      await this.addPolygon(data);
    }
  }

  private async addPolygon(data: Map<string, ESObject>): Promise<void> {
    const dartId: string = String(data.get('polygonId'));
    const options: mapCommon.MapPolygonOptions = {
      points: this.toLatLngList(data.get('points') as ESObject)
    };
    this.assignBoolean(data, 'clickable', (value: boolean) => {
      options.clickable = value;
    });
    this.assignBoolean(data, 'geodesic', (value: boolean) => {
      options.geodesic = value;
    });
    this.assignBoolean(data, 'visible', (value: boolean) => {
      options.visible = value;
    });
    this.assignNumber(data, 'fillColor', (value: number) => {
      options.fillColor = value;
    });
    this.assignNumber(data, 'strokeColor', (value: number) => {
      options.strokeColor = value;
    });
    this.assignNumber(data, 'strokeWidth', (value: number) => {
      options.strokeWidth = value;
    });
    this.assignNumber(data, 'zIndex', (value: number) => {
      options.zIndex = value;
    });
    const holes: ESObject | undefined = data.get('holes');
    if (holes !== undefined) {
      options.holes = this.toHoles(holes);
    }
    const joint: ESObject | undefined = data.get('strokeJointType');
    if (joint !== undefined) {
      options.jointType = this.toJointType(Number(joint));
    }
    const patterns: ESObject | undefined = data.get('strokePattern');
    if (patterns !== undefined) {
      options.patterns = this.toPatterns(patterns);
    }
    const polygon: map.MapPolygon = await this.requireController().addPolygon(options);
    this.polygons.set(dartId, polygon);
    this.polygonIds.set(polygon.getId(), dartId);
  }

  private async addCircleList(value: ESObject | undefined): Promise<void> {
    if (value === undefined) {
      return;
    }
    const list: Array<ESObject> = value as Array<ESObject>;
    for (let index: number = 0; index < list.length; index++) {
      await this.addCircle(this.asMap(list[index]));
    }
  }

  private async replaceCircleList(value: ESObject | undefined): Promise<void> {
    if (value === undefined) {
      return;
    }
    const list: Array<ESObject> = value as Array<ESObject>;
    for (let index: number = 0; index < list.length; index++) {
      const data: Map<string, ESObject> = this.asMap(list[index]);
      this.removeOverlayById(String(data.get('circleId')), this.circles, this.circleIds);
      await this.addCircle(data);
    }
  }

  private async addCircle(data: Map<string, ESObject>): Promise<void> {
    const dartId: string = String(data.get('circleId'));
    const options: mapCommon.MapCircleOptions = {
      center: this.toLatLng(data.get('center') as ESObject),
      radius: Number(data.get('radius'))
    };
    this.assignBoolean(data, 'clickable', (value: boolean) => {
      options.clickable = value;
    });
    this.assignBoolean(data, 'visible', (value: boolean) => {
      options.visible = value;
    });
    this.assignNumber(data, 'fillColor', (value: number) => {
      options.fillColor = value;
    });
    this.assignNumber(data, 'strokeColor', (value: number) => {
      options.strokeColor = value;
    });
    this.assignNumber(data, 'strokeWidth', (value: number) => {
      options.strokeWidth = value;
    });
    this.assignNumber(data, 'zIndex', (value: number) => {
      options.zIndex = value;
    });
    const patterns: ESObject | undefined = data.get('strokePattern');
    if (patterns !== undefined) {
      options.patterns = this.toPatterns(patterns);
    }
    const circle: map.MapCircle = await this.requireController().addCircle(options);
    this.circles.set(dartId, circle);
    this.circleIds.set(circle.getId(), dartId);
  }

  private removeOverlays<T extends map.BaseOverlay>(
    value: ESObject | undefined,
    overlays: Map<string, T>,
    nativeIds: Map<string, string>
  ): void {
    if (value === undefined) {
      return;
    }
    const ids: Array<ESObject> = value as Array<ESObject>;
    ids.forEach((id: ESObject) => {
      this.removeOverlayById(String(id), overlays, nativeIds);
    });
  }

  private removeOverlayById<T extends map.BaseOverlay>(
    dartId: string,
    overlays: Map<string, T>,
    nativeIds: Map<string, string>
  ): void {
    const overlay: T | undefined = overlays.get(dartId);
    if (overlay !== undefined) {
      nativeIds.delete(overlay.getId());
      overlay.remove();
      overlays.delete(dartId);
    }
  }

  private markerFor(args: ESObject): map.Marker {
    const values: Map<string, ESObject> = this.asMap(args);
    const dartId: string = String(values.get('markerId'));
    const marker: map.Marker | undefined = this.markers.get(dartId);
    if (marker === undefined) {
      throw new Error(`Unknown marker: ${dartId}`);
    }
    return marker;
  }

  private toCameraUpdate(value: ESObject): map.CameraUpdate {
    const data: Array<ESObject> = value as Array<ESObject>;
    const type: string = String(data[0]);
    switch (type) {
      case 'newLatLng':
        return map.newLatLng(this.toLatLng(data[1]));
      case 'newLatLngZoom':
        return map.newLatLng(this.toLatLng(data[1]), Number(data[2]));
      case 'newLatLngBounds':
        return map.newLatLngBounds(this.toLatLngBounds(data[1]), Number(data[2]));
      case 'newCameraPosition':
        return map.newCameraPosition(this.toCameraPosition(data[1]));
      case 'scrollBy':
        return map.scrollBy(Number(data[1]), Number(data[2]));
      case 'zoomBy': {
        if (data.length > 2) {
          const point: Array<number> = data[2] as Array<number>;
          return map.zoomBy(Number(data[1]), {
            positionX: Number(point[0]),
            positionY: Number(point[1])
          });
        }
        return map.zoomBy(Number(data[1]));
      }
      case 'zoomIn':
        return map.zoomIn();
      case 'zoomOut':
        return map.zoomOut();
      case 'zoomTo':
        return map.zoomTo(Number(data[1]));
      default:
        throw new Error(`Unsupported camera update: ${type}`);
    }
  }

  private toCameraPosition(value: ESObject): mapCommon.CameraPosition {
    const source: Map<string, ESObject> = this.asMap(value);
    return {
      target: this.toLatLng(source.get('target') as ESObject),
      zoom: this.clampZoom(Number(source.get('zoom'))),
      bearing: Number(source.get('bearing')),
      tilt: Number(source.get('tilt'))
    };
  }

  private fromCameraPosition(value: mapCommon.CameraPosition): Map<string, ESObject> {
    return this.mapOf([
      { key: 'bearing', value: value.bearing === undefined ? 0 : value.bearing },
      { key: 'target', value: this.fromLatLng(value.target) },
      { key: 'tilt', value: value.tilt === undefined ? 0 : value.tilt },
      { key: 'zoom', value: value.zoom }
    ]);
  }

  private toLatLng(value: ESObject): mapCommon.LatLng {
    const coordinate: Array<number> = value as Array<number>;
    return {
      latitude: Number(coordinate[0]),
      longitude: Number(coordinate[1])
    };
  }

  private toLatLngList(value: ESObject): Array<mapCommon.LatLng> {
    const source: Array<ESObject> = value as Array<ESObject>;
    return source.map((coordinate: ESObject) => this.toLatLng(coordinate));
  }

  private toHoles(value: ESObject): Array<Array<mapCommon.LatLng>> {
    const source: Array<ESObject> = value as Array<ESObject>;
    return source.map((hole: ESObject) => this.toLatLngList(hole));
  }

  private fromLatLng(value: mapCommon.LatLng): Array<number> {
    return [value.latitude, value.longitude];
  }

  private toLatLngBounds(value: ESObject): mapCommon.LatLngBounds {
    const source: Array<ESObject> = value as Array<ESObject>;
    return {
      southwest: this.toLatLng(source[0]),
      northeast: this.toLatLng(source[1])
    };
  }

  private fromBounds(value: mapCommon.LatLngBounds): Map<string, ESObject> {
    return this.mapOf([
      { key: 'southwest', value: this.fromLatLng(value.southwest) },
      { key: 'northeast', value: this.fromLatLng(value.northeast) }
    ]);
  }

  private toPadding(value: ESObject): mapCommon.Padding {
    const padding: Array<number> = value as Array<number>;
    return {
      top: Number(padding[0]),
      left: Number(padding[1]),
      bottom: Number(padding[2]),
      right: Number(padding[3])
    };
  }

  private toMapType(value: number): mapCommon.MapType {
    switch (value) {
      case 0:
        return mapCommon.MapType.NONE;
      case 2:
        return mapCommon.MapType.TERRAIN;
      case 1:
      default:
        return mapCommon.MapType.STANDARD;
    }
  }

  private toLogoAlignment(value: number): mapCommon.LogoAlignment {
    switch (value) {
      case 8388693:
        return mapCommon.LogoAlignment.BOTTOM_END;
      case 8388659:
        return mapCommon.LogoAlignment.TOP_START;
      case 8388661:
        return mapCommon.LogoAlignment.TOP_END;
      case 8388691:
      default:
        return mapCommon.LogoAlignment.BOTTOM_START;
    }
  }

  private toJointType(value: number): mapCommon.JointType {
    switch (value) {
      case 1:
        return mapCommon.JointType.BEVEL;
      case 2:
        return mapCommon.JointType.ROUND;
      case 0:
      default:
        return mapCommon.JointType.DEFAULT;
    }
  }

  private toCap(value: ESObject): mapCommon.CapStyle {
    const source: Array<ESObject> = value as Array<ESObject>;
    switch (String(source[0])) {
      case 'roundCap':
        return mapCommon.CapStyle.ROUND;
      case 'squareCap':
        return mapCommon.CapStyle.SQUARE;
      case 'buttCap':
      case 'customCap':
      default:
        return mapCommon.CapStyle.BUTT;
    }
  }

  private toPatterns(value: ESObject): Array<mapCommon.PatternItem> {
    const source: Array<ESObject> = value as Array<ESObject>;
    return source.map((item: ESObject) => {
      const values: Array<ESObject> = item as Array<ESObject>;
      const type: string = String(values[0]);
      if (type === 'dot') {
        return { type: mapCommon.PatternItemType.DOT };
      }
      if (type === 'gap') {
        return {
          type: mapCommon.PatternItemType.GAP,
          length: Number(values[1])
        };
      }
      return {
        type: mapCommon.PatternItemType.DASH,
        length: Number(values[1])
      };
    });
  }

  private toIcon(value: ESObject): string | undefined {
    const source: Array<ESObject> = value as Array<ESObject>;
    const type: string = String(source[0]);
    if (type === 'defaultMarker') {
      return undefined;
    }
    if (type === 'fromAsset' || type === 'fromAssetImage') {
      return String(source[1]).replace(/^\//, '');
    }
    if (type === 'fromBytes') {
      const bytes: Uint8Array = source[1] as Uint8Array;
      const helper: util.Base64Helper = new util.Base64Helper();
      return `data:image/png;base64,${helper.encodeToStringSync(bytes)}`;
    }
    return undefined;
  }

  private async takeSnapshot(controller: map.MapComponentController): Promise<Uint8Array> {
    const pixelMap: image.PixelMap = await controller.snapshot();
    const packer: image.ImagePacker = image.createImagePacker();
    try {
      // `packing` is deprecated in API 13 but remains the API 12-compatible
      // overload. MapEventManager already sets this bridge's minimum to API 12.
      const buffer: ArrayBuffer = await packer.packing(pixelMap, {
        format: 'image/png',
        quality: 100
      });
      return new Uint8Array(buffer);
    } finally {
      await packer.release();
      await pixelMap.release();
    }
  }

  private asMap(value: ESObject): Map<string, ESObject> {
    if (!(value instanceof Map)) {
      throw new Error('Expected a StandardMessageCodec map.');
    }
    return value as Map<string, ESObject>;
  }

  private requireController(): map.MapComponentController {
    if (this.controller === null) {
      throw new Error('MapComponent is not ready.');
    }
    return this.controller;
  }

  private clampZoom(value: number): number {
    if (!Number.isFinite(value)) {
      return 2;
    }
    return Math.min(20, Math.max(2, value));
  }

  private copyBoolean(
    source: Map<string, ESObject>,
    key: string,
    setter: (value: boolean) => void
  ): void {
    const value: ESObject | undefined = source.get(key);
    if (value !== undefined) {
      setter(Boolean(value));
    }
  }

  private assignBoolean(
    source: Map<string, ESObject>,
    key: string,
    setter: (value: boolean) => void
  ): void {
    this.copyBoolean(source, key, setter);
  }

  private assignNumber(
    source: Map<string, ESObject>,
    key: string,
    setter: (value: number) => void
  ): void {
    const value: ESObject | undefined = source.get(key);
    if (value !== undefined) {
      setter(Number(value));
    }
  }

  private mapOf(entries: Array<FlutterMapEntry>): Map<string, ESObject> {
    const result: Map<string, ESObject> = new Map();
    entries.forEach((entry: FlutterMapEntry) => {
      result.set(entry.key, entry.value);
    });
    return result;
  }
}
