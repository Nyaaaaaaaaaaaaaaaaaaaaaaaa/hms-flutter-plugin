/*
 * Copyright 2026 The huawei_map iOS compatibility contributors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "HMSMapPlatformView.h"

#import <CoreLocation/CoreLocation.h>
#import <TargetConditionals.h>
#import <UIKit/UIKit.h>
#import <float.h>
#import <math.h>
#import <stdlib.h>

#if !TARGET_OS_SIMULATOR
#if __has_include(<HMapKit/HMapKit.h>)
#import <HMapKit/HMapKit.h>
#else
#import "HMSMapKitCompat.h"
#endif
#endif

static NSString *const HMSPerMapChannel = @"com.huawei.hms.flutter.map/map";

static id HMSMapNonNull(id value) {
  return value == (id)[NSNull null] ? nil : value;
}

static NSDictionary *HMSMapDictionary(id value) {
  value = HMSMapNonNull(value);
  return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

static NSArray *HMSMapArray(id value) {
  value = HMSMapNonNull(value);
  return [value isKindOfClass:[NSArray class]] ? value : nil;
}

static NSString *HMSMapString(id value) {
  value = HMSMapNonNull(value);
  return [value isKindOfClass:[NSString class]] ? value : nil;
}

static NSNumber *HMSMapNumber(id value) {
  value = HMSMapNonNull(value);
  return [value isKindOfClass:[NSNumber class]] ? value : nil;
}

static CLLocationCoordinate2D HMSMapCoordinate(id value, BOOL *valid) {
  NSArray *items = HMSMapArray(value);
  if (items.count < 2 || HMSMapNumber(items[0]) == nil || HMSMapNumber(items[1]) == nil) {
    if (valid != NULL) {
      *valid = NO;
    }
    return kCLLocationCoordinate2DInvalid;
  }
  CLLocationCoordinate2D coordinate =
      CLLocationCoordinate2DMake([items[0] doubleValue], [items[1] doubleValue]);
  BOOL coordinateIsValid = CLLocationCoordinate2DIsValid(coordinate);
  if (valid != NULL) {
    *valid = coordinateIsValid;
  }
  return coordinate;
}

static NSArray<NSNumber *> *HMSMapCoordinateValue(CLLocationCoordinate2D coordinate) {
  return @[ @(coordinate.latitude), @(coordinate.longitude) ];
}

static NSDictionary *HMSMapCameraValue(id mapViewValue) {
#if TARGET_OS_SIMULATOR
  return @{
    @"bearing" : @0,
    @"target" : @[ @0, @0 ],
    @"tilt" : @0,
    @"zoom" : @0,
  };
#else
  HMapView *mapView = (HMapView *)mapViewValue;
  return @{
    @"bearing" : @(mapView.rotation),
    @"target" : HMSMapCoordinateValue(mapView.centerCoordinate),
    @"tilt" : @(mapView.overlooking),
    @"zoom" : @(mapView.zoomLevel),
  };
#endif
}

static FlutterError *HMSMapUnsupported(NSString *feature) {
  return [FlutterError
      errorWithCode:@"unsupported_on_ios"
            message:[NSString stringWithFormat:@"%@ is not exposed by Huawei Map Kit for iOS 6.4.",
                                               feature]
            details:@{ @"feature" : feature, @"platform" : @"ios" }];
}

#if !TARGET_OS_SIMULATOR
static HMapType HMSMapTypeFromDart(NSInteger value) {
  switch (value) {
    case 0:
      return HMapTypeNone;
    case 2:
      return HMapTypeTerrain;
    case 1:
    default:
      return HMapTypeNormal;
  }
}
#endif

@interface HMSMapPlatformView : NSObject <FlutterPlatformView>

- (instancetype)initWithFrame:(CGRect)frame
                viewIdentifier:(int64_t)viewIdentifier
                     arguments:(id _Nullable)arguments
                     messenger:(NSObject<FlutterBinaryMessenger> *)messenger
                     registrar:(NSObject<FlutterPluginRegistrar> *)registrar;

@end


#if TARGET_OS_SIMULATOR

@interface HMSMapPlatformView ()
@property(nonatomic, strong) UIView *container;
@property(nonatomic, strong) FlutterMethodChannel *channel;
@end

@implementation HMSMapPlatformView

- (instancetype)initWithFrame:(CGRect)frame
                viewIdentifier:(int64_t)viewIdentifier
                     arguments:(id)arguments
                     messenger:(NSObject<FlutterBinaryMessenger> *)messenger
                     registrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  self = [super init];
  if (self) {
    _container = [[UIView alloc] initWithFrame:frame];
    _container.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];

    UILabel *message = [[UILabel alloc] initWithFrame:CGRectInset(_container.bounds, 24.0, 24.0)];
    message.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    message.numberOfLines = 0;
    message.textAlignment = NSTextAlignmentCenter;
    message.textColor = [UIColor colorWithWhite:0.32 alpha:1.0];
    message.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    message.text = @"Huawei Map Kit for iOS is available on physical arm64 devices only.";
    [_container addSubview:message];

    NSString *channelName =
        [NSString stringWithFormat:@"%@_%lld", HMSPerMapChannel, viewIdentifier];
    _channel = [FlutterMethodChannel methodChannelWithName:channelName
                                           binaryMessenger:messenger];
    __weak typeof(self) weakSelf = self;
    [_channel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
      __strong typeof(weakSelf) strongSelf = weakSelf;
      if (strongSelf == nil) {
        result([FlutterError errorWithCode:@"map_disposed"
                                   message:@"The map view has already been disposed."
                                   details:nil]);
        return;
      }
      if ([call.method isEqualToString:@"[Map]waitForMap"]) {
        result(nil);
      } else if ([call.method isEqualToString:@"[Map]takeSnapshot"]) {
        UIGraphicsBeginImageContextWithOptions(strongSelf.container.bounds.size, YES, 0.0);
        [strongSelf.container drawViewHierarchyInRect:strongSelf.container.bounds
                                    afterScreenUpdates:YES];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        NSData *data = UIImagePNGRepresentation(image);
        result([FlutterStandardTypedData typedDataWithBytes:data ?: [NSData data]]);
      } else {
        result([FlutterError
            errorWithCode:@"ios_simulator_unavailable"
                  message:@"Huawei Map Kit's published iOS binary has no simulator slice. Use a physical arm64 device."
                  details:nil]);
      }
    }];
  }
  return self;
}

- (UIView *)view {
  return self.container;
}

- (void)dealloc {
  [self.channel setMethodCallHandler:nil];
}

@end

#else

static UIColor *HMSMapColor(id value) {
  uint32_t argb = HMSMapNumber(value).unsignedIntValue;
  CGFloat alpha = ((argb >> 24) & 0xff) / 255.0;
  CGFloat red = ((argb >> 16) & 0xff) / 255.0;
  CGFloat green = ((argb >> 8) & 0xff) / 255.0;
  CGFloat blue = (argb & 0xff) / 255.0;
  return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

static NSData *HMSMapData(id value) {
  value = HMSMapNonNull(value);
  if ([value isKindOfClass:[FlutterStandardTypedData class]]) {
    return ((FlutterStandardTypedData *)value).data;
  }
  return [value isKindOfClass:[NSData class]] ? value : nil;
}

static NSArray<NSNumber *> *HMSMapDashPattern(id value) {
  NSArray *items = HMSMapArray(value);
  if (items.count == 0) {
    return nil;
  }
  NSMutableArray<NSNumber *> *lengths = [NSMutableArray array];
  for (id itemValue in items) {
    NSArray *item = HMSMapArray(itemValue);
    NSString *kind = item.count > 0 ? HMSMapString(item[0]) : nil;
    if ([kind isEqualToString:@"dot"]) {
      [lengths addObject:@1.0];
    } else if (([kind isEqualToString:@"dash"] || [kind isEqualToString:@"gap"]) &&
               item.count > 1 && HMSMapNumber(item[1]) != nil) {
      [lengths addObject:@(MAX(0.5, [item[1] doubleValue]))];
    }
  }
  if (lengths.count == 0) {
    return nil;
  }
  if (lengths.count % 2 != 0) {
    [lengths addObject:lengths.firstObject];
  }
  return lengths;
}

static CLLocationCoordinate2D *HMSMapCoordinates(id value, NSUInteger *count) {
  NSArray *items = HMSMapArray(value);
  if (items.count == 0) {
    *count = 0;
    return NULL;
  }
  CLLocationCoordinate2D *coordinates =
      calloc(items.count, sizeof(CLLocationCoordinate2D));
  NSUInteger written = 0;
  for (id item in items) {
    BOOL valid = NO;
    CLLocationCoordinate2D coordinate = HMSMapCoordinate(item, &valid);
    if (valid) {
      coordinates[written++] = coordinate;
    }
  }
  *count = written;
  return coordinates;
}

static HCoordinateBounds HMSMapBounds(id value, BOOL *valid) {
  NSArray *items = HMSMapArray(value);
  BOOL southwestValid = NO;
  BOOL northeastValid = NO;
  CLLocationCoordinate2D southwest =
      HMSMapCoordinate(items.count > 0 ? items[0] : nil, &southwestValid);
  CLLocationCoordinate2D northeast =
      HMSMapCoordinate(items.count > 1 ? items[1] : nil, &northeastValid);
  if (valid != NULL) {
    *valid = southwestValid && northeastValid;
  }
  return HCoordinateBoundsMake(northeast, southwest);
}

static HCoordinateBounds HMSMapBoundsAroundCoordinate(CLLocationCoordinate2D center,
                                                       double width,
                                                       double height) {
  const double earthRadius = 6378137.0;
  double latitudeDelta = (height / earthRadius) * 180.0 / M_PI;
  double cosine = MAX(0.01, fabs(cos(center.latitude * M_PI / 180.0)));
  double longitudeDelta = (width / (earthRadius * cosine)) * 180.0 / M_PI;
  CLLocationCoordinate2D northeast = CLLocationCoordinate2DMake(
      center.latitude + latitudeDelta / 2.0, center.longitude + longitudeDelta / 2.0);
  CLLocationCoordinate2D southwest = CLLocationCoordinate2DMake(
      center.latitude - latitudeDelta / 2.0, center.longitude - longitudeDelta / 2.0);
  return HCoordinateBoundsMake(northeast, southwest);
}

static UIImage *HMSMapTransparentImage(void) {
  UIGraphicsBeginImageContextWithOptions(CGSizeMake(1.0, 1.0), NO, 1.0);
  [[UIColor clearColor] setFill];
  UIRectFill(CGRectMake(0.0, 0.0, 1.0, 1.0));
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return image;
}

static UIImage *HMSMapTransformImage(UIImage *image, CGFloat alpha, CGFloat degrees) {
  if (image == nil || (fabs(alpha - 1.0) < DBL_EPSILON && fabs(degrees) < DBL_EPSILON)) {
    return image;
  }
  CGSize size = image.size;
  UIGraphicsBeginImageContextWithOptions(size, NO, image.scale);
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextTranslateCTM(context, size.width / 2.0, size.height / 2.0);
  CGContextRotateCTM(context, degrees * M_PI / 180.0);
  [image drawInRect:CGRectMake(-size.width / 2.0, -size.height / 2.0,
                               size.width, size.height)
            blendMode:kCGBlendModeNormal
                alpha:MAX(0.0, MIN(1.0, alpha))];
  UIImage *transformed = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return transformed;
}

@interface HMSMapTileOverlay : HTileOverlay
@property(nonatomic, copy) id provider;
@end

@implementation HMSMapTileOverlay

- (instancetype)initWithProvider:(id)provider {
  self = [super initWithURLTemplate:@""];
  if (self) {
    _provider = [provider copy];
  }
  return self;
}

- (void)loadTileAtPath:(HTileOverlayPath *)path result:(HTileDataCallback)result {
  NSData *data = nil;
  NSDictionary *repetitive = HMSMapDictionary(self.provider);
  if (repetitive != nil) {
    NSArray *zoomLevels = HMSMapArray(repetitive[@"zoom"]);
    if ([zoomLevels containsObject:@(path.z)]) {
      data = HMSMapData(repetitive[@"imageData"]);
    }
  } else {
    for (NSDictionary *tile in HMSMapArray(self.provider)) {
      if ([HMSMapNumber(tile[@"x"]) integerValue] == path.x &&
          [HMSMapNumber(tile[@"y"]) integerValue] == path.y &&
          [HMSMapNumber(tile[@"zoom"]) integerValue] == path.z) {
        data = HMSMapData(tile[@"imageData"]);
        break;
      }
    }
  }
  result(data, nil);
}

@end

@interface HMSMapPlatformView () <HMapViewDelegate>

@property(nonatomic, strong) HMapView *mapView;
@property(nonatomic, strong) FlutterMethodChannel *channel;
@property(nonatomic, weak) NSObject<FlutterPluginRegistrar> *registrar;
@property(nonatomic, assign) int64_t viewIdentifier;
@property(nonatomic, assign) BOOL trackCameraPosition;
@property(nonatomic, assign) BOOL mapReady;
@property(nonatomic, assign) NSInteger pendingCameraReason;
@property(nonatomic, copy, nullable) NSString *suppressedMarkerSelection;
@property(nonatomic, strong) NSMutableArray *pendingMapResults;

@property(nonatomic, strong) NSMutableDictionary<NSString *, HPointAnnotation *> *markers;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *markerOptions;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id<HOverlay>> *polylines;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id<HOverlay>> *polygons;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id<HOverlay>> *circles;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id<HOverlay>> *groundOverlays;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id<HOverlay>> *tileOverlays;
@property(nonatomic, strong) NSMapTable<id, NSDictionary *> *overlayMetadata;
@property(nonatomic, strong) NSMapTable<id, HOverlayView *> *overlayViews;

@end

@implementation HMSMapPlatformView

- (instancetype)initWithFrame:(CGRect)frame
                viewIdentifier:(int64_t)viewIdentifier
                     arguments:(id)arguments
                     messenger:(NSObject<FlutterBinaryMessenger> *)messenger
                     registrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  self = [super init];
  if (self) {
    _viewIdentifier = viewIdentifier;
    _registrar = registrar;
    _pendingCameraReason = 3;
    _pendingMapResults = [NSMutableArray array];
    _markers = [NSMutableDictionary dictionary];
    _markerOptions = [NSMutableDictionary dictionary];
    _polylines = [NSMutableDictionary dictionary];
    _polygons = [NSMutableDictionary dictionary];
    _circles = [NSMutableDictionary dictionary];
    _groundOverlays = [NSMutableDictionary dictionary];
    _tileOverlays = [NSMutableDictionary dictionary];
    _overlayMetadata = [NSMapTable strongToStrongObjectsMapTable];
    _overlayViews = [NSMapTable weakToWeakObjectsMapTable];

    _mapView = [[HMapView alloc] initWithFrame:frame];
    _mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _mapView.delegate = self;

    NSString *channelName =
        [NSString stringWithFormat:@"%@_%lld", HMSPerMapChannel, viewIdentifier];
    _channel = [FlutterMethodChannel methodChannelWithName:channelName
                                           binaryMessenger:messenger];
    __weak typeof(self) weakSelf = self;
    [_channel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
      __strong typeof(weakSelf) strongSelf = weakSelf;
      if (strongSelf == nil) {
        result([FlutterError errorWithCode:@"map_disposed"
                                   message:@"The map view has already been disposed."
                                   details:nil]);
        return;
      }
      [strongSelf handleMethodCall:call result:result];
    }];

    NSDictionary *creation = HMSMapDictionary(arguments) ?: @{};
    [self applyInitialCamera:HMSMapDictionary(creation[@"initialCameraPosition"])];
    [self applyMapOptions:HMSMapDictionary(creation[@"options"])];
    [self replaceMarkers:HMSMapArray(creation[@"markersToAdd"]) removeIDs:nil];
    [self replacePolylines:HMSMapArray(creation[@"polylinesToAdd"]) removeIDs:nil];
    [self replacePolygons:HMSMapArray(creation[@"polygonsToAdd"]) removeIDs:nil];
    [self replaceCircles:HMSMapArray(creation[@"circlesToAdd"]) removeIDs:nil];
    [self replaceGroundOverlays:HMSMapArray(creation[@"groundOverlaysToAdd"]) removeIDs:nil];
    [self replaceTileOverlays:HMSMapArray(creation[@"tileOverlaysToAdd"]) removeIDs:nil];
  }
  return self;
}

- (UIView *)view {
  return self.mapView;
}

- (void)dealloc {
  self.mapView.delegate = nil;
  [self.channel setMethodCallHandler:nil];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  NSString *method = call.method;
  NSDictionary *arguments = HMSMapDictionary(call.arguments);

  if ([method isEqualToString:@"[Map]waitForMap"]) {
    if (self.mapReady) {
      result(nil);
    } else {
      [self.pendingMapResults addObject:[result copy]];
    }
    return;
  }
  if ([method isEqualToString:@"[Map]update"]) {
    [self applyMapOptions:HMSMapDictionary(arguments[@"options"])];
    result(HMSMapCameraValue(self.mapView));
    return;
  }
  if ([method isEqualToString:@"[Camera]move"] ||
      [method isEqualToString:@"[Camera]animate"]) {
    BOOL animated = [method isEqualToString:@"[Camera]animate"];
    BOOL success = [self applyCameraUpdate:HMSMapArray(arguments[@"cameraUpdate"])
                                  animated:animated];
    if (!success) {
      result([FlutterError errorWithCode:@"invalid_camera_update"
                                 message:@"The supplied camera update is invalid or unsupported."
                                 details:arguments[@"cameraUpdate"]]);
    } else {
      result(nil);
    }
    return;
  }
  if ([method isEqualToString:@"[Map]stopAnimation"]) {
    [self.mapView.layer removeAllAnimations];
    [self.channel invokeMethod:@"[Camera]onMoveCancelled"
                     arguments:@{ @"map" : @(self.viewIdentifier) }];
    result(nil);
    return;
  }
  if ([method isEqualToString:@"[Markers]update"]) {
    [self replaceMarkers:HMSMapArray(arguments[@"markersToAdd"])
               removeIDs:HMSMapArray(arguments[@"markerIdsToRemove"])];
    [self replaceMarkers:HMSMapArray(arguments[@"markersToChange"]) removeIDs:nil];
    result(nil);
    return;
  }
  if ([method isEqualToString:@"[Polylines]update"]) {
    [self replacePolylines:HMSMapArray(arguments[@"polylinesToAdd"])
                 removeIDs:HMSMapArray(arguments[@"polylineIdsToRemove"])];
    [self replacePolylines:HMSMapArray(arguments[@"polylinesToChange"]) removeIDs:nil];
    result(nil);
    return;
  }
  if ([method isEqualToString:@"[Polygons]update"]) {
    [self replacePolygons:HMSMapArray(arguments[@"polygonsToAdd"])
                removeIDs:HMSMapArray(arguments[@"polygonIdsToRemove"])];
    [self replacePolygons:HMSMapArray(arguments[@"polygonsToChange"]) removeIDs:nil];
    result(nil);
    return;
  }
  if ([method isEqualToString:@"[Circles]update"]) {
    [self replaceCircles:HMSMapArray(arguments[@"circlesToAdd"])
               removeIDs:HMSMapArray(arguments[@"circleIdsToRemove"])];
    [self replaceCircles:HMSMapArray(arguments[@"circlesToChange"]) removeIDs:nil];
    result(nil);
    return;
  }
  if ([method isEqualToString:@"[GroundOverlays]update"]) {
    [self replaceGroundOverlays:HMSMapArray(arguments[@"groundOverlaysToAdd"])
                      removeIDs:HMSMapArray(arguments[@"groundOverlayIdsToRemove"])];
    [self replaceGroundOverlays:HMSMapArray(arguments[@"groundOverlaysToChange"])
                      removeIDs:nil];
    result(nil);
    return;
  }
  if ([method isEqualToString:@"[TileOverlays]update"]) {
    [self replaceTileOverlays:HMSMapArray(arguments[@"tileOverlaysToAdd"])
                    removeIDs:HMSMapArray(arguments[@"tileOverlayIdsToRemove"])];
    [self replaceTileOverlays:HMSMapArray(arguments[@"tileOverlaysToChange"])
                    removeIDs:nil];
    result(nil);
    return;
  }
  if ([method isEqualToString:@"[HeatMap]update"]) {
    result(HMSMapUnsupported(@"Heat map overlays"));
    return;
  }
  if ([method isEqualToString:@"MarkerStartAnimation"] ||
      [method isEqualToString:@"CircleStartAnimation"]) {
    result(HMSMapUnsupported(@"Marker and circle animation sets"));
    return;
  }
  if ([method isEqualToString:@"[Map]setLocationSource"] ||
      [method isEqualToString:@"[Map]setLocation"] ||
      [method isEqualToString:@"[Map]deactivateLocationSource"]) {
    result(HMSMapUnsupported(@"Custom location sources"));
    return;
  }
  if ([method isEqualToString:@"[Markers]isMarkerClusterable"]) {
    result(@NO);
    return;
  }
  if ([method isEqualToString:@"[Markers]showInfoWindow"] ||
      [method isEqualToString:@"[Markers]hideInfoWindow"] ||
      [method isEqualToString:@"[Markers]isInfoWindowShown"]) {
    [self handleInfoWindowMethod:method arguments:arguments result:result];
    return;
  }
  if ([method isEqualToString:@"clearTileCache"]) {
    NSString *overlayID = HMSMapString(arguments[@"tileOverlayId"]);
    id<HOverlay> overlay = self.tileOverlays[overlayID];
    HOverlayView *view = [self.overlayViews objectForKey:overlay];
    if ([view isKindOfClass:[HTileOverlayView class]]) {
      [(HTileOverlayView *)view reloadData];
    }
    result(nil);
    return;
  }
  if ([method isEqualToString:@"[Map]getVisibleRegion"]) {
    HCoordinateBounds bounds = HCoordinateBoundsForMapRect(self.mapView.visibleMapRect);
    result(@{
      @"southwest" : HMSMapCoordinateValue(bounds.southWest),
      @"northeast" : HMSMapCoordinateValue(bounds.northEast),
    });
    return;
  }
  if ([method isEqualToString:@"[Map]getScreenCoordinate"]) {
    [self getScreenCoordinate:call.arguments result:result];
    return;
  }
  if ([method isEqualToString:@"[Map]getLatLng"]) {
    [self getCoordinateFromScreenPoint:arguments result:result];
    return;
  }
  if ([method isEqualToString:@"[Map]takeSnapshot"]) {
    [self takeSnapshot:result];
    return;
  }
  if ([method isEqualToString:@"[Map]getScalePerPixel"]) {
    CGFloat pixels = CGRectGetWidth(self.mapView.bounds) * UIScreen.mainScreen.scale;
    result(pixels > 0.0 ? @(self.mapView.visibleMapRect.size.width / pixels) : @0.0);
    return;
  }
  if ([method isEqualToString:@"[Map]getZoomLevel"]) {
    result(@(self.mapView.zoomLevel));
    return;
  }
  if ([method isEqualToString:@"[Map]setStyle"]) {
    [self setMapStyle:HMSMapString(call.arguments) result:result];
    return;
  }
  if ([method isEqualToString:@"[Map]isCompassEnabled"]) {
    result(@(self.mapView.showsCompass));
    return;
  }
  if ([method isEqualToString:@"[Map]isDark"] ||
      [method isEqualToString:@"[Map]isMapToolbarEnabled"]) {
    result(@NO);
    return;
  }
  if ([method isEqualToString:@"[Map]getMinMaxZoomLevels"]) {
    result(@[ @(self.mapView.minZoomLevel), @(self.mapView.maxZoomLevel) ]);
    return;
  }
  if ([method isEqualToString:@"[Map]isTiltGesturesEnabled"]) {
    result(@(self.mapView.isOverlookingEnabled));
    return;
  }
  if ([method isEqualToString:@"[Map]isRotateGesturesEnabled"]) {
    result(@(self.mapView.isRotateEnabled));
    return;
  }
  if ([method isEqualToString:@"[Map]isZoomGesturesEnabled"]) {
    result(@(self.mapView.isZoomEnabled));
    return;
  }
  if ([method isEqualToString:@"[Map]isZoomControlsEnabled"]) {
    result(@(self.mapView.showsZoomControl && self.mapView.isZoomControlEnabled));
    return;
  }
  if ([method isEqualToString:@"[Map]isScrollGesturesEnabled"]) {
    result(@(self.mapView.isScrollEnabled));
    return;
  }
  if ([method isEqualToString:@"[Map]isMyLocationButtonEnabled"]) {
    result(@(self.mapView.showsLocationButton && self.mapView.isLocationButtonEnabled));
    return;
  }
  if ([method isEqualToString:@"[Map]isTrafficEnabled"]) {
    result(@(self.mapView.showsTraffic));
    return;
  }
  if ([method isEqualToString:@"[Map]isBuildingsEnabled"]) {
    result(@(self.mapView.shows3DBuildings));
    return;
  }
  result(FlutterMethodNotImplemented);
}

- (void)applyInitialCamera:(NSDictionary *)camera {
  if (camera == nil) {
    return;
  }
  BOOL targetValid = NO;
  CLLocationCoordinate2D target = HMSMapCoordinate(camera[@"target"], &targetValid);
  if (targetValid) {
    self.mapView.centerCoordinate = target;
  }
  NSNumber *zoom = HMSMapNumber(camera[@"zoom"]);
  NSNumber *bearing = HMSMapNumber(camera[@"bearing"]);
  NSNumber *tilt = HMSMapNumber(camera[@"tilt"]);
  if (zoom != nil) {
    self.mapView.zoomLevel = zoom.doubleValue;
  }
  if (bearing != nil) {
    self.mapView.rotation = bearing.doubleValue;
  }
  if (tilt != nil) {
    self.mapView.overlooking = tilt.doubleValue;
  }
}

- (void)applyMapOptions:(NSDictionary *)options {
  if (options == nil) {
    return;
  }
  NSNumber *allGestures = HMSMapNumber(options[@"allGesturesEnabled"]);
  if (allGestures != nil) {
    BOOL enabled = allGestures.boolValue;
    self.mapView.scrollEnabled = enabled;
    self.mapView.zoomEnabled = enabled;
    self.mapView.rotateEnabled = enabled;
    self.mapView.overlookingEnabled = enabled;
  }
  NSNumber *value = nil;
  if ((value = HMSMapNumber(options[@"compassEnabled"]))) {
    self.mapView.showsCompass = value.boolValue;
  }
  if ((value = HMSMapNumber(options[@"mapType"]))) {
    self.mapView.mapType = HMSMapTypeFromDart(value.integerValue);
  }
  if ((value = HMSMapNumber(options[@"rotateGesturesEnabled"]))) {
    self.mapView.rotateEnabled = value.boolValue;
  }
  if ((value = HMSMapNumber(options[@"scrollGesturesEnabled"]))) {
    self.mapView.scrollEnabled = value.boolValue;
  }
  if ((value = HMSMapNumber(options[@"tiltGesturesEnabled"]))) {
    self.mapView.overlookingEnabled = value.boolValue;
  }
  if ((value = HMSMapNumber(options[@"zoomGesturesEnabled"]))) {
    self.mapView.zoomEnabled = value.boolValue;
  }
  if ((value = HMSMapNumber(options[@"zoomControlsEnabled"]))) {
    self.mapView.showsZoomControl = value.boolValue;
    self.mapView.zoomControlEnabled = value.boolValue;
  }
  if ((value = HMSMapNumber(options[@"myLocationEnabled"]))) {
    self.mapView.showsUserLocation = value.boolValue;
  }
  if ((value = HMSMapNumber(options[@"myLocationButtonEnabled"]))) {
    self.mapView.showsLocationButton = value.boolValue;
    self.mapView.locationButtonEnabled = value.boolValue;
  }
  if ((value = HMSMapNumber(options[@"trafficEnabled"]))) {
    self.mapView.showsTraffic = value.boolValue;
  }
  if ((value = HMSMapNumber(options[@"buildingsEnabled"]))) {
    self.mapView.shows3DBuildings = value.boolValue;
  }
  if ((value = HMSMapNumber(options[@"trackCameraPosition"]))) {
    self.trackCameraPosition = value.boolValue;
  }
  if ((value = HMSMapNumber(options[@"gestureScaleByMapCenter"]))) {
    self.mapView.keepCenterDuringZoom = value.boolValue;
  }

  NSArray *zoomRange = HMSMapArray(options[@"minMaxZoomPreference"]);
  CGFloat minimum = zoomRange.count > 0 && HMSMapNumber(zoomRange[0]) != nil
                        ? [zoomRange[0] doubleValue]
                        : self.mapView.minZoomLevel;
  CGFloat maximum = zoomRange.count > 1 && HMSMapNumber(zoomRange[1]) != nil
                        ? [zoomRange[1] doubleValue]
                        : self.mapView.maxZoomLevel;
  if (zoomRange != nil && minimum <= maximum) {
    [self.mapView setMinZoomLevel:minimum maxZoomLevel:maximum];
  }

  NSArray *padding = HMSMapArray(options[@"padding"]);
  if (padding.count >= 4 && CGRectGetWidth(self.mapView.bounds) > 0.0 &&
      CGRectGetHeight(self.mapView.bounds) > 0.0) {
    CGFloat top = [HMSMapNumber(padding[0]) doubleValue];
    CGFloat left = [HMSMapNumber(padding[1]) doubleValue];
    CGFloat bottom = [HMSMapNumber(padding[2]) doubleValue];
    CGFloat right = [HMSMapNumber(padding[3]) doubleValue];
    [self.mapView setCenterOffset:CGPointMake((left - right) /
                                                  (2.0 * CGRectGetWidth(self.mapView.bounds)),
                                              (top - bottom) /
                                                  (2.0 * CGRectGetHeight(self.mapView.bounds)))];
  }

  NSDictionary *pointToCenter = HMSMapDictionary(options[@"pointToCenter"]);
  if (pointToCenter != nil && CGRectGetWidth(self.mapView.bounds) > 0.0 &&
      CGRectGetHeight(self.mapView.bounds) > 0.0) {
    CGFloat scale = UIScreen.mainScreen.scale;
    CGFloat x = [HMSMapNumber(pointToCenter[@"x"]) doubleValue] / scale;
    CGFloat y = [HMSMapNumber(pointToCenter[@"y"]) doubleValue] / scale;
    [self.mapView setCenterOffset:CGPointMake(x / CGRectGetWidth(self.mapView.bounds) - 0.5,
                                              y / CGRectGetHeight(self.mapView.bounds) - 0.5)];
  }

  NSString *styleID = HMSMapString(options[@"styleId"]);
  if (styleID.length > 0) {
    [self.mapView setMapStyleID:styleID];
  }
  NSString *previewID = HMSMapString(options[@"previewId"]);
  if (previewID.length > 0) {
    [self.mapView setMapPreviewID:previewID];
  }

  NSNumber *logoPosition = HMSMapNumber(options[@"logoPosition"]);
  NSArray *logoPadding = HMSMapArray(options[@"logoPadding"]);
  if (logoPosition != nil || logoPadding != nil) {
    NSInteger position = logoPosition != nil ? logoPosition.integerValue : 8388691;
    HMapLogoAnchor anchor = HMapLogoAnchorLeftBottom;
    if (position == 8388693) {
      anchor = HMapLogoAnchorRightBottom;
    } else if (position == 8388659) {
      anchor = HMapLogoAnchorLeftTop;
    } else if (position == 8388661) {
      anchor = HMapLogoAnchorRightTop;
    }
    CGFloat top = logoPadding.count > 0 ? [HMSMapNumber(logoPadding[0]) doubleValue] : 3.0;
    CGFloat left = logoPadding.count > 1 ? [HMSMapNumber(logoPadding[1]) doubleValue] : 6.0;
    CGFloat bottom = logoPadding.count > 2 ? [HMSMapNumber(logoPadding[2]) doubleValue] : 3.0;
    CGFloat right = logoPadding.count > 3 ? [HMSMapNumber(logoPadding[3]) doubleValue] : 6.0;
    BOOL usesRight = anchor == HMapLogoAnchorRightBottom || anchor == HMapLogoAnchorRightTop;
    BOOL usesTop = anchor == HMapLogoAnchorLeftTop || anchor == HMapLogoAnchorRightTop;
    [self.mapView setLogoMargin:CGPointMake(usesRight ? right : left, usesTop ? top : bottom)
                            anchor:anchor];
  }
}

- (BOOL)applyCameraUpdate:(NSArray *)update animated:(BOOL)animated {
  if (update.count == 0) {
    return NO;
  }
  NSString *kind = HMSMapString(update[0]);
  self.pendingCameraReason = 3;
  if ([kind isEqualToString:@"newCameraPosition"]) {
    NSDictionary *camera = update.count > 1 ? HMSMapDictionary(update[1]) : nil;
    if (camera == nil) {
      return NO;
    }
    BOOL targetValid = NO;
    CLLocationCoordinate2D target = HMSMapCoordinate(camera[@"target"], &targetValid);
    if (targetValid) {
      [self.mapView setCenterCoordinate:target animated:animated];
    }
    NSNumber *zoom = HMSMapNumber(camera[@"zoom"]);
    NSNumber *bearing = HMSMapNumber(camera[@"bearing"]);
    NSNumber *tilt = HMSMapNumber(camera[@"tilt"]);
    if (zoom != nil) {
      [self.mapView setZoomLevel:zoom.doubleValue animated:animated];
    }
    if (bearing != nil) {
      [self.mapView setRotation:bearing.doubleValue animated:animated];
    }
    if (tilt != nil) {
      [self.mapView setOverlooking:tilt.doubleValue animated:animated];
    }
    return targetValid;
  }
  if ([kind isEqualToString:@"newLatLng"] || [kind isEqualToString:@"newLatLngZoom"]) {
    BOOL valid = NO;
    CLLocationCoordinate2D coordinate =
        HMSMapCoordinate(update.count > 1 ? update[1] : nil, &valid);
    if (!valid) {
      return NO;
    }
    [self.mapView setCenterCoordinate:coordinate animated:animated];
    if ([kind isEqualToString:@"newLatLngZoom"] && update.count > 2 &&
        HMSMapNumber(update[2]) != nil) {
      [self.mapView setZoomLevel:[update[2] doubleValue] animated:animated];
    }
    return YES;
  }
  if ([kind isEqualToString:@"newLatLngBounds"]) {
    BOOL valid = NO;
    HCoordinateBounds bounds = HMSMapBounds(update.count > 1 ? update[1] : nil, &valid);
    if (!valid) {
      return NO;
    }
    CGFloat padding = update.count > 2 ? [HMSMapNumber(update[2]) doubleValue] : 0.0;
    [self.mapView setVisibleMapRect:HMapRectForCoordinateBounds(bounds)
                       edgePadding:UIEdgeInsetsMake(padding, padding, padding, padding)
                          animated:animated];
    return YES;
  }
  if ([kind isEqualToString:@"scrollBy"]) {
    if (update.count < 3 || CGRectGetWidth(self.mapView.bounds) <= 0.0 ||
        CGRectGetHeight(self.mapView.bounds) <= 0.0) {
      return NO;
    }
    HCoordinateRegion region = self.mapView.region;
    CGFloat x = [HMSMapNumber(update[1]) doubleValue];
    CGFloat y = [HMSMapNumber(update[2]) doubleValue];
    region.center.longitude += x / CGRectGetWidth(self.mapView.bounds) * region.span.longitudeDelta;
    region.center.latitude -= y / CGRectGetHeight(self.mapView.bounds) * region.span.latitudeDelta;
    [self.mapView setRegion:region animated:animated];
    return YES;
  }
  if ([kind isEqualToString:@"zoomBy"]) {
    if (update.count < 2 || HMSMapNumber(update[1]) == nil) {
      return NO;
    }
    [self.mapView setZoomLevel:self.mapView.zoomLevel + [update[1] doubleValue]
                      animated:animated];
    return YES;
  }
  if ([kind isEqualToString:@"zoomIn"]) {
    [self.mapView setZoomLevel:self.mapView.zoomLevel + 1.0 animated:animated];
    return YES;
  }
  if ([kind isEqualToString:@"zoomOut"]) {
    [self.mapView setZoomLevel:self.mapView.zoomLevel - 1.0 animated:animated];
    return YES;
  }
  if ([kind isEqualToString:@"zoomTo"] && update.count > 1 &&
      HMSMapNumber(update[1]) != nil) {
    [self.mapView setZoomLevel:[update[1] doubleValue] animated:animated];
    return YES;
  }
  return NO;
}

- (UIImage *)imageFromDescriptor:(id)value {
  NSArray *descriptor = HMSMapArray(value);
  NSString *kind = descriptor.count > 0 ? HMSMapString(descriptor[0]) : nil;
  if ([kind isEqualToString:@"fromBytes"] && descriptor.count > 1) {
    NSData *data = HMSMapData(descriptor[1]);
    return data != nil ? [UIImage imageWithData:data] : nil;
  }
  if (([kind isEqualToString:@"fromAsset"] ||
       [kind isEqualToString:@"fromAssetImage"]) &&
      descriptor.count > 1) {
    NSString *asset = HMSMapString(descriptor[1]);
    NSString *key = nil;
    if ([kind isEqualToString:@"fromAsset"] && descriptor.count > 2 &&
        HMSMapString(descriptor[2]) != nil) {
      key = [self.registrar lookupKeyForAsset:asset fromPackage:HMSMapString(descriptor[2])];
    } else {
      key = [self.registrar lookupKeyForAsset:asset];
    }
    UIImage *image = [UIImage imageNamed:key];
    if (image == nil) {
      NSString *path = [NSBundle.mainBundle pathForResource:key ofType:nil];
      image = path != nil ? [UIImage imageWithContentsOfFile:path] : nil;
    }
    if ([kind isEqualToString:@"fromAssetImage"] && descriptor.count > 2 &&
        HMSMapNumber(descriptor[2]) != nil && image.CGImage != nil) {
      image = [UIImage imageWithCGImage:image.CGImage
                                  scale:[descriptor[2] doubleValue]
                            orientation:image.imageOrientation];
    }
    return image;
  }
  return nil;
}

- (void)replaceMarkers:(NSArray *)values removeIDs:(NSArray *)removeIDs {
  for (id value in removeIDs) {
    NSString *markerID = HMSMapString(value);
    HPointAnnotation *existing = self.markers[markerID];
    if (existing != nil) {
      [self.mapView removeAnnotation:existing];
      [self.markers removeObjectForKey:markerID];
      [self.markerOptions removeObjectForKey:markerID];
    }
  }
  for (NSDictionary *options in values) {
    NSString *markerID = HMSMapString(options[@"markerId"]);
    BOOL positionValid = NO;
    CLLocationCoordinate2D position = HMSMapCoordinate(options[@"position"], &positionValid);
    if (markerID.length == 0 || !positionValid) {
      continue;
    }
    HPointAnnotation *existing = self.markers[markerID];
    if (existing != nil) {
      [self.mapView removeAnnotation:existing];
    }
    HPointAnnotation *annotation = [[HPointAnnotation alloc] init];
    annotation.coordinate = position;
    NSDictionary *infoWindow = HMSMapDictionary(options[@"infoWindow"]);
    annotation.title = HMSMapString(infoWindow[@"title"]) ?: @"";
    annotation.subtitle = HMSMapString(infoWindow[@"snippet"]) ?: @"";
    annotation.userData = @{ @"kind" : @"marker", @"id" : markerID };
    self.markers[markerID] = annotation;
    self.markerOptions[markerID] = options;
    if (HMSMapNumber(options[@"visible"]) == nil ||
        [HMSMapNumber(options[@"visible"]) boolValue]) {
      [self.mapView addAnnotation:annotation];
    }
  }
}

- (void)removeOverlay:(id<HOverlay>)overlay {
  if (overlay != nil) {
    [self.mapView removeOverlay:overlay];
    [self.overlayMetadata removeObjectForKey:overlay];
    [self.overlayViews removeObjectForKey:overlay];
  }
}

- (void)replacePolylines:(NSArray *)values removeIDs:(NSArray *)removeIDs {
  for (id value in removeIDs) {
    NSString *overlayID = HMSMapString(value);
    [self removeOverlay:self.polylines[overlayID]];
    [self.polylines removeObjectForKey:overlayID];
  }
  for (NSDictionary *options in values) {
    NSString *overlayID = HMSMapString(options[@"polylineId"]);
    if (overlayID.length == 0) {
      continue;
    }
    [self removeOverlay:self.polylines[overlayID]];
    NSUInteger count = 0;
    CLLocationCoordinate2D *coordinates = HMSMapCoordinates(options[@"points"], &count);
    if (count < 2) {
      free(coordinates);
      [self.polylines removeObjectForKey:overlayID];
      continue;
    }
    HPolyline *polyline = [HPolyline polylineWithCoordinates:coordinates count:count];
    free(coordinates);
    polyline.userData = @{ @"kind" : @"polyline", @"id" : overlayID };
    self.polylines[overlayID] = polyline;
    [self.overlayMetadata setObject:@{ @"kind" : @"polyline",
                                      @"id" : overlayID,
                                      @"options" : options }
                            forKey:polyline];
    [self.mapView addOverlay:polyline];
  }
}

- (void)replacePolygons:(NSArray *)values removeIDs:(NSArray *)removeIDs {
  for (id value in removeIDs) {
    NSString *overlayID = HMSMapString(value);
    [self removeOverlay:self.polygons[overlayID]];
    [self.polygons removeObjectForKey:overlayID];
  }
  for (NSDictionary *options in values) {
    NSString *overlayID = HMSMapString(options[@"polygonId"]);
    if (overlayID.length == 0) {
      continue;
    }
    [self removeOverlay:self.polygons[overlayID]];
    NSUInteger count = 0;
    CLLocationCoordinate2D *coordinates = HMSMapCoordinates(options[@"points"], &count);
    if (count < 3) {
      free(coordinates);
      [self.polygons removeObjectForKey:overlayID];
      continue;
    }
    HPolygon *polygon = [HPolygon polygonWithCoordinates:coordinates count:count];
    free(coordinates);
    polygon.userData = @{ @"kind" : @"polygon", @"id" : overlayID };
    self.polygons[overlayID] = polygon;
    [self.overlayMetadata setObject:@{ @"kind" : @"polygon",
                                      @"id" : overlayID,
                                      @"options" : options }
                            forKey:polygon];
    [self.mapView addOverlay:polygon];
  }
}

- (void)replaceCircles:(NSArray *)values removeIDs:(NSArray *)removeIDs {
  for (id value in removeIDs) {
    NSString *overlayID = HMSMapString(value);
    [self removeOverlay:self.circles[overlayID]];
    [self.circles removeObjectForKey:overlayID];
  }
  for (NSDictionary *options in values) {
    NSString *overlayID = HMSMapString(options[@"circleId"]);
    BOOL centerValid = NO;
    CLLocationCoordinate2D center = HMSMapCoordinate(options[@"center"], &centerValid);
    NSNumber *radius = HMSMapNumber(options[@"radius"]);
    if (overlayID.length == 0 || !centerValid || radius == nil) {
      continue;
    }
    [self removeOverlay:self.circles[overlayID]];
    HCircle *circle = [HCircle circleWithCenterCoordinate:center radius:radius.doubleValue];
    circle.userData = @{ @"kind" : @"circle", @"id" : overlayID };
    self.circles[overlayID] = circle;
    [self.overlayMetadata setObject:@{ @"kind" : @"circle",
                                      @"id" : overlayID,
                                      @"options" : options }
                            forKey:circle];
    [self.mapView addOverlay:circle];
  }
}

- (void)replaceGroundOverlays:(NSArray *)values removeIDs:(NSArray *)removeIDs {
  for (id value in removeIDs) {
    NSString *overlayID = HMSMapString(value);
    [self removeOverlay:self.groundOverlays[overlayID]];
    [self.groundOverlays removeObjectForKey:overlayID];
  }
  for (NSDictionary *options in values) {
    NSString *overlayID = HMSMapString(options[@"groundOverlayId"]);
    if (overlayID.length == 0) {
      continue;
    }
    [self removeOverlay:self.groundOverlays[overlayID]];
    BOOL boundsValid = NO;
    HCoordinateBounds bounds;
    if (HMSMapArray(options[@"bounds"]) != nil) {
      bounds = HMSMapBounds(options[@"bounds"], &boundsValid);
    } else {
      BOOL positionValid = NO;
      CLLocationCoordinate2D position = HMSMapCoordinate(options[@"position"], &positionValid);
      NSNumber *width = HMSMapNumber(options[@"width"]);
      NSNumber *height = HMSMapNumber(options[@"height"]);
      if (positionValid && width != nil) {
        bounds = HMSMapBoundsAroundCoordinate(position, width.doubleValue,
                                              height != nil ? height.doubleValue
                                                            : width.doubleValue);
        boundsValid = YES;
      }
    }
    if (!boundsValid) {
      [self.groundOverlays removeObjectForKey:overlayID];
      continue;
    }
    UIImage *image = [self imageFromDescriptor:options[@"imageDescriptor"]] ?: HMSMapTransparentImage();
    HGroundOverlay *ground = [HGroundOverlay groundOverlayWithBounds:bounds icon:image];
    NSNumber *transparency = HMSMapNumber(options[@"transparency"]);
    ground.opacity = transparency != nil ? 1.0 - transparency.floatValue : 1.0;
    ground.userData = @{ @"kind" : @"groundOverlay", @"id" : overlayID };
    self.groundOverlays[overlayID] = ground;
    [self.overlayMetadata setObject:@{ @"kind" : @"groundOverlay",
                                      @"id" : overlayID,
                                      @"options" : options }
                            forKey:ground];
    [self.mapView addOverlay:ground];
  }
}

- (void)replaceTileOverlays:(NSArray *)values removeIDs:(NSArray *)removeIDs {
  for (id value in removeIDs) {
    NSString *overlayID = HMSMapString(value);
    [self removeOverlay:self.tileOverlays[overlayID]];
    [self.tileOverlays removeObjectForKey:overlayID];
  }
  for (NSDictionary *options in values) {
    NSString *overlayID = HMSMapString(options[@"tileOverlayId"]);
    id provider = HMSMapNonNull(options[@"tileProvider"]);
    if (overlayID.length == 0 || provider == nil) {
      continue;
    }
    [self removeOverlay:self.tileOverlays[overlayID]];
    NSDictionary *providerMap = HMSMapDictionary(provider);
    NSString *URLTemplate = HMSMapString(providerMap[@"uri"]);
    HTileOverlay *tile = URLTemplate.length > 0
                             ? [[HTileOverlay alloc] initWithURLTemplate:URLTemplate]
                             : [[HMSMapTileOverlay alloc] initWithProvider:provider];
    self.tileOverlays[overlayID] = tile;
    [self.overlayMetadata setObject:@{ @"kind" : @"tileOverlay",
                                      @"id" : overlayID,
                                      @"options" : options }
                            forKey:tile];
    [self.mapView addOverlay:tile];
  }
}

- (HAnnotationView *)mapView:(HMapView *)mapView
           viewForAnnotation:(id<HAnnotation>)annotationValue {
  if (![annotationValue isKindOfClass:[HPointAnnotation class]]) {
    return nil;
  }
  HPointAnnotation *annotation = (HPointAnnotation *)annotationValue;
  NSDictionary *metadata = HMSMapDictionary(annotation.userData);
  NSString *markerID = HMSMapString(metadata[@"id"]);
  NSDictionary *options = self.markerOptions[markerID] ?: @{};
  NSArray *descriptor = HMSMapArray(options[@"icon"]);
  NSString *descriptorKind = descriptor.count > 0 ? HMSMapString(descriptor[0]) : nil;

  HAnnotationView *view = nil;
  if (descriptor == nil || [descriptorKind isEqualToString:@"defaultMarker"]) {
    HPinAnnotationView *pin = [[HPinAnnotationView alloc] init];
    CGFloat hue = descriptor.count > 1 ? [HMSMapNumber(descriptor[1]) doubleValue] : 0.0;
    if (hue >= 75.0 && hue < 200.0) {
      pin.pinColor = HPinAnnotationColorGreen;
    } else if (hue >= 200.0 && hue < 330.0) {
      pin.pinColor = HPinAnnotationColorPurple;
    } else {
      pin.pinColor = HPinAnnotationColorRed;
    }
    view = pin;
  } else {
    view = [[HAnnotationView alloc] init];
    UIImage *image = [self imageFromDescriptor:descriptor];
    CGFloat alpha = HMSMapNumber(options[@"alpha"]) != nil
                        ? [HMSMapNumber(options[@"alpha"]) doubleValue]
                        : 1.0;
    CGFloat rotation = HMSMapNumber(options[@"rotation"]) != nil
                           ? [HMSMapNumber(options[@"rotation"]) doubleValue]
                           : 0.0;
    view.image = HMSMapTransformImage(image, alpha, rotation);
  }
  view.annotation = annotation;
  NSArray *anchor = HMSMapArray(options[@"anchor"]);
  if (anchor.count >= 2) {
    view.anchorPoint = CGPointMake([HMSMapNumber(anchor[0]) doubleValue],
                                   [HMSMapNumber(anchor[1]) doubleValue]);
  }
  view.zIndex = [HMSMapNumber(options[@"zIndex"]) intValue];
  view.enabled = HMSMapNumber(options[@"clickable"]) == nil ||
                 [HMSMapNumber(options[@"clickable"]) boolValue];
  view.draggable = [HMSMapNumber(options[@"draggable"]) boolValue];
  NSDictionary *infoWindow = HMSMapDictionary(options[@"infoWindow"]);
  view.canShowCallout = HMSMapString(infoWindow[@"title"]).length > 0 ||
                        HMSMapString(infoWindow[@"snippet"]).length > 0;
  return view;
}

- (HOverlayView *)mapView:(HMapView *)mapView viewForOverlay:(id<HOverlay>)overlay {
  NSDictionary *metadata = [self.overlayMetadata objectForKey:overlay];
  NSDictionary *options = HMSMapDictionary(metadata[@"options"]) ?: @{};
  HOverlayView *view = nil;
  if ([overlay isKindOfClass:[HPolyline class]]) {
    HPolylineView *polylineView = [[HPolylineView alloc] initWithPolyline:(HPolyline *)overlay];
    polylineView.strokeColor = HMSMapColor(options[@"color"]);
    polylineView.lineWidth = [HMSMapNumber(options[@"width"]) doubleValue];
    polylineView.lineDashPattern = HMSMapDashPattern(options[@"pattern"]);
    view = polylineView;
  } else if ([overlay isKindOfClass:[HPolygon class]]) {
    HPolygonView *polygonView = [[HPolygonView alloc] initWithPolygon:(HPolygon *)overlay];
    polygonView.fillColor = HMSMapColor(options[@"fillColor"]);
    polygonView.strokeColor = HMSMapColor(options[@"strokeColor"]);
    polygonView.lineWidth = [HMSMapNumber(options[@"strokeWidth"]) doubleValue];
    NSArray *pattern = HMSMapArray(options[@"strokePattern"]);
    NSString *firstKind = pattern.count > 0 && HMSMapArray(pattern[0]).count > 0
                              ? HMSMapString(HMSMapArray(pattern[0])[0])
                              : nil;
    if ([firstKind isEqualToString:@"dot"]) {
      polygonView.lineType = HOverlayStrokeType_Dot;
    } else if (pattern.count > 0) {
      polygonView.lineType = HOverlayStrokeType_Dash;
      polygonView.lineDashPattern = HMSMapDashPattern(pattern);
    }
    view = polygonView;
  } else if ([overlay isKindOfClass:[HCircle class]]) {
    HCircleView *circleView = [[HCircleView alloc] initWithCircle:(HCircle *)overlay];
    circleView.fillColor = HMSMapColor(options[@"fillColor"]);
    circleView.strokeColor = HMSMapColor(options[@"strokeColor"]);
    circleView.lineWidth = [HMSMapNumber(options[@"strokeWidth"]) doubleValue];
    view = circleView;
  } else if ([overlay isKindOfClass:[HGroundOverlay class]]) {
    view = [[HGroundOverlayView alloc] initWithOverlay:(HGroundOverlay *)overlay];
  } else if ([overlay isKindOfClass:[HTileOverlay class]]) {
    view = [[HTileOverlayView alloc] initWithTileOverlay:(HTileOverlay *)overlay];
  }
  if (view != nil) {
    view.zIndex = [HMSMapNumber(options[@"zIndex"]) intValue];
    view.isClickable = [HMSMapNumber(options[@"clickable"]) boolValue];
    view.isVisible = HMSMapNumber(options[@"visible"]) == nil ||
                     [HMSMapNumber(options[@"visible"]) boolValue];
    [self.overlayViews setObject:view forKey:overlay];
  }
  return view;
}

- (void)handleInfoWindowMethod:(NSString *)method
                     arguments:(NSDictionary *)arguments
                        result:(FlutterResult)result {
  NSString *markerID = HMSMapString(arguments[@"markerId"]);
  HPointAnnotation *annotation = self.markers[markerID];
  if (annotation == nil) {
    result([FlutterError errorWithCode:@"unknown_marker"
                               message:@"No marker exists for the supplied markerId."
                               details:markerID]);
    return;
  }
  if ([method isEqualToString:@"[Markers]showInfoWindow"]) {
    self.suppressedMarkerSelection = markerID;
    [self.mapView selectAnnotation:annotation animated:YES];
    result(nil);
  } else if ([method isEqualToString:@"[Markers]hideInfoWindow"]) {
    [self.mapView deselectAnnotation:annotation animated:YES];
    result(nil);
  } else {
    result(@([self.mapView.selectedAnnotations containsObject:annotation]));
  }
}

- (void)getScreenCoordinate:(id)value result:(FlutterResult)result {
  BOOL valid = NO;
  CLLocationCoordinate2D coordinate = HMSMapCoordinate(value, &valid);
  HMapRect rect = self.mapView.visibleMapRect;
  if (!valid || rect.size.width == 0.0 || rect.size.height == 0.0) {
    result([FlutterError errorWithCode:@"projection_unavailable"
                               message:@"The map projection is not ready."
                               details:nil]);
    return;
  }
  HMapPoint point = HMapPointForCoordinate(coordinate);
  CGFloat x = (point.x - rect.origin.x) / rect.size.width * CGRectGetWidth(self.mapView.bounds);
  CGFloat y = (point.y - rect.origin.y) / rect.size.height * CGRectGetHeight(self.mapView.bounds);
  CGFloat scale = UIScreen.mainScreen.scale;
  result(@{ @"x" : @((NSInteger)llround(x * scale)),
            @"y" : @((NSInteger)llround(y * scale)) });
}

- (void)getCoordinateFromScreenPoint:(NSDictionary *)point result:(FlutterResult)result {
  HMapRect rect = self.mapView.visibleMapRect;
  NSNumber *xValue = HMSMapNumber(point[@"x"]);
  NSNumber *yValue = HMSMapNumber(point[@"y"]);
  if (xValue == nil || yValue == nil || CGRectGetWidth(self.mapView.bounds) == 0.0 ||
      CGRectGetHeight(self.mapView.bounds) == 0.0) {
    result([FlutterError errorWithCode:@"projection_unavailable"
                               message:@"A valid screen point and ready map projection are required."
                               details:nil]);
    return;
  }
  CGFloat scale = UIScreen.mainScreen.scale;
  CGFloat x = xValue.doubleValue / scale;
  CGFloat y = yValue.doubleValue / scale;
  HMapPoint mapPoint = HMapPointMake(
      rect.origin.x + x / CGRectGetWidth(self.mapView.bounds) * rect.size.width,
      rect.origin.y + y / CGRectGetHeight(self.mapView.bounds) * rect.size.height);
  result(HMSMapCoordinateValue(HCoordinateForMapPoint(mapPoint)));
}

- (void)takeSnapshot:(FlutterResult)result {
  UIGraphicsBeginImageContextWithOptions(self.mapView.bounds.size, NO, 0.0);
  BOOL drawn = [self.mapView drawViewHierarchyInRect:self.mapView.bounds
                                  afterScreenUpdates:YES];
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  NSData *data = image != nil ? UIImagePNGRepresentation(image) : nil;
  if (!drawn || data == nil) {
    result([FlutterError errorWithCode:@"snapshot_failed"
                               message:@"The native map view could not be captured."
                               details:nil]);
    return;
  }
  result([FlutterStandardTypedData typedDataWithBytes:data]);
}

- (void)setMapStyle:(NSString *)styleJSON result:(FlutterResult)result {
  if (styleJSON.length == 0) {
    result(@[ @NO, @"A non-empty JSON style is required on iOS." ]);
    return;
  }
  NSString *path = [NSTemporaryDirectory()
      stringByAppendingPathComponent:[NSString stringWithFormat:@"huawei-map-style-%@.json",
                                                                 NSUUID.UUID.UUIDString]];
  NSError *writeError = nil;
  BOOL written = [styleJSON writeToFile:path
                              atomically:YES
                                encoding:NSUTF8StringEncoding
                                   error:&writeError];
  BOOL success = written && [self.mapView setMapStyle:path];
  [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
  if (success) {
    result(@[ @YES ]);
  } else {
    result(@[ @NO, writeError.localizedDescription ?: @"Map Kit rejected the style JSON." ]);
  }
}

#pragma mark - HMapViewDelegate

- (void)mapViewInitComplete:(HMapView *)mapView {
  self.mapReady = YES;
  NSArray *results = [self.pendingMapResults copy];
  [self.pendingMapResults removeAllObjects];
  for (FlutterResult result in results) {
    result(nil);
  }
}

- (void)mapView:(HMapView *)mapView
    regionWillChangeAnimated:(BOOL)animated
                     gesture:(BOOL)gesture {
  NSInteger reason = gesture ? 1 : self.pendingCameraReason;
  [self.channel invokeMethod:@"[Camera]onMoveStarted"
                   arguments:@{ @"reason" : @(reason) }];
}

- (void)mapViewRegionChange:(HMapView *)mapView {
  if (self.trackCameraPosition) {
    [self.channel invokeMethod:@"[Camera]onMove"
                     arguments:@{ @"position" : HMSMapCameraValue(mapView) }];
  }
}

- (void)mapView:(HMapView *)mapView
    regionDidChangeAnimated:(BOOL)animated
                    gesture:(BOOL)gesture {
  self.pendingCameraReason = 3;
  [self.channel invokeMethod:@"[Camera]onIdle"
                   arguments:@{ @"map" : @(self.viewIdentifier) }];
}

- (void)mapView:(HMapView *)mapView
    didTapAtCoordinate:(CLLocationCoordinate2D)coordinate {
  [self.channel invokeMethod:@"[Map]click"
                   arguments:@{ @"position" : HMSMapCoordinateValue(coordinate) }];
}

- (void)mapView:(HMapView *)mapView
    didLongGuestureTapAtCoordinate:(CLLocationCoordinate2D)coordinate {
  [self.channel invokeMethod:@"[Map]onLongPress"
                   arguments:@{ @"position" : HMSMapCoordinateValue(coordinate) }];
}

- (void)mapView:(HMapView *)mapView didTapPoi:(HPoiInfo *)poi {
  [self.channel invokeMethod:@"[Map]onPoiClick"
                   arguments:@{
                     @"pointOfInterest" : @{
                       @"latLng" : HMSMapCoordinateValue(poi.coordinate),
                       @"name" : poi.name ?: @"",
                       @"placeId" : poi.uid ?: @"",
                     }
                   }];
}

- (void)mapView:(HMapView *)mapView didTapOverlay:(id<HOverlay>)overlay {
  NSDictionary *metadata = [self.overlayMetadata objectForKey:overlay];
  NSString *kind = HMSMapString(metadata[@"kind"]);
  NSString *overlayID = HMSMapString(metadata[@"id"]);
  NSDictionary *methods = @{
    @"polyline" : @"[Polyline]click",
    @"polygon" : @"[Polygon]click",
    @"circle" : @"[Circle]click",
    @"groundOverlay" : @"[GroundOverlay]click",
  };
  NSDictionary *keys = @{
    @"polyline" : @"polylineId",
    @"polygon" : @"polygonId",
    @"circle" : @"circleId",
    @"groundOverlay" : @"groundOverlayId",
  };
  if (methods[kind] != nil && overlayID != nil) {
    [self.channel invokeMethod:methods[kind] arguments:@{ keys[kind] : overlayID }];
  }
}

- (void)mapView:(HMapView *)mapView didSelectAnnotationView:(HAnnotationView *)view {
  HPointAnnotation *annotation = [view.annotation isKindOfClass:[HPointAnnotation class]]
                                     ? (HPointAnnotation *)view.annotation
                                     : nil;
  NSString *markerID = HMSMapString(HMSMapDictionary(annotation.userData)[@"id"]);
  if (markerID.length == 0) {
    return;
  }
  if ([self.suppressedMarkerSelection isEqualToString:markerID]) {
    self.suppressedMarkerSelection = nil;
    return;
  }
  [self.channel invokeMethod:@"[Marker]click"
                   arguments:@{ @"markerId" : markerID }];
}

- (void)mapView:(HMapView *)mapView didDeselectAnnotationView:(HAnnotationView *)view {
  HPointAnnotation *annotation = [view.annotation isKindOfClass:[HPointAnnotation class]]
                                     ? (HPointAnnotation *)view.annotation
                                     : nil;
  NSString *markerID = HMSMapString(HMSMapDictionary(annotation.userData)[@"id"]);
  if (markerID.length > 0) {
    [self.channel invokeMethod:@"[InfoWindow]close"
                     arguments:@{ @"markerId" : markerID }];
  }
}

- (void)mapView:(HMapView *)mapView annotationViewCalloutTapped:(HAnnotationView *)view {
  HPointAnnotation *annotation = [view.annotation isKindOfClass:[HPointAnnotation class]]
                                     ? (HPointAnnotation *)view.annotation
                                     : nil;
  NSString *markerID = HMSMapString(HMSMapDictionary(annotation.userData)[@"id"]);
  if (markerID.length > 0) {
    [self.channel invokeMethod:@"[InfoWindow]click"
                     arguments:@{ @"markerId" : markerID }];
  }
}

- (void)mapView:(HMapView *)mapView
          annotationView:(HAnnotationView *)view
      didChangeDragState:(HAnnotationViewDragState)newState
            fromOldState:(HAnnotationViewDragState)oldState {
  HPointAnnotation *annotation = [view.annotation isKindOfClass:[HPointAnnotation class]]
                                     ? (HPointAnnotation *)view.annotation
                                     : nil;
  NSString *markerID = HMSMapString(HMSMapDictionary(annotation.userData)[@"id"]);
  if (markerID.length == 0 || annotation == nil) {
    return;
  }
  NSString *method = nil;
  if (newState == HAnnotationViewDragStateStarting) {
    method = @"[Marker]onDragStart";
  } else if (newState == HAnnotationViewDragStateDragging) {
    method = @"[Marker]onDrag";
  } else if (newState == HAnnotationViewDragStateEnding ||
             newState == HAnnotationViewDragStateCanceling) {
    method = @"[Marker]onDragEnd";
  }
  if (method != nil) {
    [self.channel invokeMethod:method
                     arguments:@{ @"markerId" : markerID,
                                  @"position" : HMSMapCoordinateValue(annotation.coordinate) }];
  }
}

- (void)mapView:(HMapView *)mapView didTapMyLocation:(CLLocationCoordinate2D)coordinate {
  CLLocation *location = mapView.userLocation.location;
  NSMutableDictionary *value = [@{
    @"latitude" : @(coordinate.latitude),
    @"longitude" : @(coordinate.longitude),
    @"fromMockProvider" : @NO,
  } mutableCopy];
  if (location != nil) {
    value[@"altitude"] = @(location.altitude);
    value[@"speed"] = @(location.speed);
    value[@"bearing"] = @(location.course);
    value[@"accuracy"] = @(location.horizontalAccuracy);
    value[@"verticalAccuracyMeters"] = @(location.verticalAccuracy);
    value[@"time"] = @((long long)(location.timestamp.timeIntervalSince1970 * 1000.0));
    if (@available(iOS 13.4, *)) {
      value[@"bearingAccuracyDegrees"] = @(location.courseAccuracy);
      value[@"speedAccuracyMetersPerSecond"] = @(location.speedAccuracy);
    }
  }
  [self.channel invokeMethod:@"[Map]onMyLocationClick"
                   arguments:@{ @"location" : value }];
}

@end

#endif

@interface HMSMapPlatformViewFactory ()
@property(nonatomic, strong) NSObject<FlutterBinaryMessenger> *messenger;
@property(nonatomic, weak) NSObject<FlutterPluginRegistrar> *registrar;
@end

@implementation HMSMapPlatformViewFactory

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger
                         registrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  self = [super init];
  if (self) {
    _messenger = messenger;
    _registrar = registrar;
  }
  return self;
}

- (NSObject<FlutterMessageCodec> *)createArgsCodec {
  return [FlutterStandardMessageCodec sharedInstance];
}

- (NSObject<FlutterPlatformView> *)createWithFrame:(CGRect)frame
                                    viewIdentifier:(int64_t)viewId
                                         arguments:(id)args {
  return [[HMSMapPlatformView alloc] initWithFrame:frame
                                   viewIdentifier:viewId
                                        arguments:args
                                        messenger:self.messenger
                                        registrar:self.registrar];
}

@end
