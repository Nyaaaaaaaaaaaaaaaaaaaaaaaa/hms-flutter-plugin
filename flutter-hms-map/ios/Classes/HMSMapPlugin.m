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

#import "HMSMapPlugin.h"
#import "HMSMapPlatformView.h"

#import <CoreLocation/CoreLocation.h>
#import <math.h>

static NSString *const HMSMapViewChannel = @"com.huawei.hms.flutter.map/map";
static NSString *const HMSMapUtilChannel = @"com.huawei.hms.flutter.map/mapUtils";
static NSString *HMSRoutePolicy;

NSString *HMSMapRoutePolicy(void) {
  return HMSRoutePolicy;
}

void HMSSetMapRoutePolicy(NSString *routePolicy) {
  HMSRoutePolicy = [routePolicy.uppercaseString copy];
}

static id HMSNonNull(id value) {
  return value == (id)[NSNull null] ? nil : value;
}

static CLLocationCoordinate2D HMSCoordinateFromValue(id value, BOOL *valid) {
  NSArray *items = [HMSNonNull(value) isKindOfClass:[NSArray class]] ? value : nil;
  if (items.count < 2 || ![items[0] isKindOfClass:[NSNumber class]] ||
      ![items[1] isKindOfClass:[NSNumber class]]) {
    if (valid != NULL) {
      *valid = NO;
    }
    return kCLLocationCoordinate2DInvalid;
  }
  CLLocationCoordinate2D coordinate =
      CLLocationCoordinate2DMake([items[0] doubleValue], [items[1] doubleValue]);
  BOOL isValid = CLLocationCoordinate2DIsValid(coordinate);
  if (valid != NULL) {
    *valid = isValid;
  }
  return coordinate;
}

static NSArray<NSNumber *> *HMSValueFromCoordinate(CLLocationCoordinate2D coordinate) {
  return @[ @(coordinate.latitude), @(coordinate.longitude) ];
}

static double HMSDegreesToRadians(double degrees) {
  return degrees * M_PI / 180.0;
}

static double HMSDistance(CLLocationCoordinate2D start, CLLocationCoordinate2D end) {
  const double earthRadius = 6371009.0;
  double latitudeDelta = HMSDegreesToRadians(end.latitude - start.latitude);
  double longitudeDelta = HMSDegreesToRadians(end.longitude - start.longitude);
  double startLatitude = HMSDegreesToRadians(start.latitude);
  double endLatitude = HMSDegreesToRadians(end.latitude);
  double a = sin(latitudeDelta / 2.0) * sin(latitudeDelta / 2.0) +
             cos(startLatitude) * cos(endLatitude) *
                 sin(longitudeDelta / 2.0) * sin(longitudeDelta / 2.0);
  return earthRadius * 2.0 * atan2(sqrt(a), sqrt(1.0 - a));
}

static BOOL HMSCoordinateIsOutsideMainlandChina(double latitude, double longitude) {
  return longitude < 72.004 || longitude > 137.8347 || latitude < 0.8293 ||
         latitude > 55.8271;
}

static double HMSLatitudeTransform(double x, double y) {
  double result = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y +
                  0.1 * x * y + 0.2 * sqrt(fabs(x));
  result += (20.0 * sin(6.0 * x * M_PI) + 20.0 * sin(2.0 * x * M_PI)) *
            2.0 / 3.0;
  result += (20.0 * sin(y * M_PI) + 40.0 * sin(y / 3.0 * M_PI)) * 2.0 / 3.0;
  result += (160.0 * sin(y / 12.0 * M_PI) +
             320.0 * sin(y * M_PI / 30.0)) *
            2.0 / 3.0;
  return result;
}

static double HMSLongitudeTransform(double x, double y) {
  double result = 300.0 + x + 2.0 * y + 0.1 * x * x +
                  0.1 * x * y + 0.1 * sqrt(fabs(x));
  result += (20.0 * sin(6.0 * x * M_PI) + 20.0 * sin(2.0 * x * M_PI)) *
            2.0 / 3.0;
  result += (20.0 * sin(x * M_PI) + 40.0 * sin(x / 3.0 * M_PI)) * 2.0 / 3.0;
  result += (150.0 * sin(x / 12.0 * M_PI) +
             300.0 * sin(x / 30.0 * M_PI)) *
            2.0 / 3.0;
  return result;
}

/// Matches HCoordinateConverter: WGS84 is converted to GCJ02 inside mainland
/// China and is returned unchanged elsewhere.
static CLLocationCoordinate2D HMSConvertWGS84ToGCJ02(CLLocationCoordinate2D input) {
  if (HMSCoordinateIsOutsideMainlandChina(input.latitude, input.longitude)) {
    return input;
  }
  const double semiMajorAxis = 6378245.0;
  const double eccentricitySquared = 0.00669342162296594323;
  double latitudeOffset = HMSLatitudeTransform(input.longitude - 105.0,
                                                input.latitude - 35.0);
  double longitudeOffset = HMSLongitudeTransform(input.longitude - 105.0,
                                                  input.latitude - 35.0);
  double latitudeRadians = HMSDegreesToRadians(input.latitude);
  double magic = sin(latitudeRadians);
  magic = 1.0 - eccentricitySquared * magic * magic;
  double sqrtMagic = sqrt(magic);
  latitudeOffset =
      (latitudeOffset * 180.0) /
      ((semiMajorAxis * (1.0 - eccentricitySquared)) /
       (magic * sqrtMagic) * M_PI);
  longitudeOffset =
      (longitudeOffset * 180.0) /
      (semiMajorAxis / sqrtMagic * cos(latitudeRadians) * M_PI);
  return CLLocationCoordinate2DMake(input.latitude + latitudeOffset,
                                    input.longitude + longitudeOffset);
}

@implementation HMSMapPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  HMSMapPlatformViewFactory *factory =
      [[HMSMapPlatformViewFactory alloc] initWithMessenger:registrar.messenger
                                                 registrar:registrar];
  [registrar registerViewFactory:factory withId:HMSMapViewChannel];

  FlutterMethodChannel *utilityChannel =
      [FlutterMethodChannel methodChannelWithName:HMSMapUtilChannel
                                  binaryMessenger:registrar.messenger];
  [utilityChannel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
    [self handleUtilityCall:call result:result];
  }];
}

+ (void)handleUtilityCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  if ([call.method isEqualToString:@"[MapUtil]distanceCalculator"]) {
    NSArray *coordinates = [HMSNonNull(call.arguments) isKindOfClass:[NSArray class]]
                               ? call.arguments
                               : nil;
    BOOL startValid = NO;
    BOOL endValid = NO;
    CLLocationCoordinate2D start =
        HMSCoordinateFromValue(coordinates.count > 0 ? coordinates[0] : nil, &startValid);
    CLLocationCoordinate2D end =
        HMSCoordinateFromValue(coordinates.count > 1 ? coordinates[1] : nil, &endValid);
    if (!startValid || !endValid) {
      result([FlutterError errorWithCode:@"invalid_argument"
                                 message:@"Two valid latitude/longitude pairs are required."
                                 details:nil]);
      return;
    }
    result(@(HMSDistance(start, end)));
    return;
  }

  if ([call.method isEqualToString:@"[MapUtil]convertCoordinate"]) {
    BOOL valid = NO;
    CLLocationCoordinate2D coordinate = HMSCoordinateFromValue(call.arguments, &valid);
    if (!valid) {
      result([FlutterError errorWithCode:@"invalid_argument"
                                 message:@"A valid latitude/longitude pair is required."
                                 details:nil]);
      return;
    }
    result(HMSValueFromCoordinate(HMSConvertWGS84ToGCJ02(coordinate)));
    return;
  }

  if ([call.method isEqualToString:@"[MapUtil]convertCoordinates"]) {
    NSArray *values = [HMSNonNull(call.arguments) isKindOfClass:[NSArray class]]
                          ? call.arguments
                          : nil;
    if (values == nil || values.count > 512) {
      result([FlutterError errorWithCode:@"invalid_argument"
                                 message:@"At most 512 valid coordinates can be converted at once."
                                 details:nil]);
      return;
    }
    NSMutableArray *converted = [NSMutableArray arrayWithCapacity:values.count];
    for (id value in values) {
      BOOL valid = NO;
      CLLocationCoordinate2D coordinate = HMSCoordinateFromValue(value, &valid);
      if (!valid) {
        result([FlutterError errorWithCode:@"invalid_argument"
                                   message:@"Every item must be a valid latitude/longitude pair."
                                   details:nil]);
        return;
      }
      [converted addObject:HMSValueFromCoordinate(HMSConvertWGS84ToGCJ02(coordinate))];
    }
    result(converted);
    return;
  }

  if ([call.method isEqualToString:@"[MapUtil]enableLogger"] ||
      [call.method isEqualToString:@"[MapUtil]disableLogger"]) {
    // The 6.4 iOS SDK does not expose the Android HMSLogger control surface.
    result(nil);
    return;
  }

  if ([call.method isEqualToString:@"[MapUtil]initializeMap"]) {
    NSString *policy = [HMSNonNull(call.arguments) isKindOfClass:[NSString class]]
                           ? call.arguments
                           : nil;
    HMSSetMapRoutePolicy(policy);
    Class serviceClass = NSClassFromString(@"HMapService");
    SEL sharedSelector = NSSelectorFromString(@"shared");
    if ([serviceClass respondsToSelector:sharedSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
      id service = [serviceClass performSelector:sharedSelector];
#pragma clang diagnostic pop
      if ([service respondsToSelector:NSSelectorFromString(@"setCountryCode:")]) {
        [service setValue:HMSMapRoutePolicy() forKey:@"countryCode"];
      }
    }
    result(@YES);
    return;
  }

  if ([call.method isEqualToString:@"[MapUtil]setApiKey"] ||
      [call.method isEqualToString:@"[MapUtil]setAccessToken"]) {
    // Map Kit for iOS obtains credentials from agconnect-services.plist. Keep
    // these Android compatibility calls non-failing for shared Dart code.
    result(@YES);
    return;
  }

  result(FlutterMethodNotImplemented);
}

@end
