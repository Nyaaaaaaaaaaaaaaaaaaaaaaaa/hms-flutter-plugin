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

// This file contains only the public ABI surface used by the bridge. The host
// application still has to embed Huawei's official HMapKit.framework and its
// resources. Keeping the proprietary SDK out of this pod makes the fork safe
// to distribute and lets simulator CI compile the fallback implementation.

#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef struct {
  CLLocationDegrees latitudeDelta;
  CLLocationDegrees longitudeDelta;
} HCoordinateSpan;

typedef struct {
  CLLocationCoordinate2D center;
  HCoordinateSpan span;
} HCoordinateRegion;

typedef struct {
  CLLocationCoordinate2D northEast;
  CLLocationCoordinate2D southWest;
} HCoordinateBounds;

typedef struct {
  double x;
  double y;
} HMapPoint;

typedef struct {
  double width;
  double height;
} HMapSize;

typedef struct {
  HMapPoint origin;
  HMapSize size;
} HMapRect;

static inline HCoordinateBounds HCoordinateBoundsMake(
    CLLocationCoordinate2D northEast,
    CLLocationCoordinate2D southWest) {
  return (HCoordinateBounds){northEast, southWest};
}

static inline HMapPoint HMapPointMake(double x, double y) {
  return (HMapPoint){x, y};
}

FOUNDATION_EXPORT HMapPoint HMapPointForCoordinate(CLLocationCoordinate2D coordinate);
FOUNDATION_EXPORT CLLocationCoordinate2D HCoordinateForMapPoint(HMapPoint mapPoint);
FOUNDATION_EXPORT HMapRect HMapRectForCoordinateBounds(HCoordinateBounds bounds);
FOUNDATION_EXPORT HCoordinateBounds HCoordinateBoundsForMapRect(HMapRect rect);

typedef NS_ENUM(NSUInteger, HMapType) {
  HMapTypeNone = 0,
  HMapTypeNormal = 1,
  HMapTypeSatellite = 2,
  HMapTypeTerrain = 3,
  HMapTypeHybrid = 4,
};

typedef NS_ENUM(NSUInteger, HMapLogoAnchor) {
  HMapLogoAnchorLeftBottom = 0,
  HMapLogoAnchorRightBottom,
  HMapLogoAnchorLeftTop,
  HMapLogoAnchorRightTop,
};

typedef NS_ENUM(NSUInteger, HOverlayStrokeType) {
  HOverlayStrokeType_Default = 0,
  HOverlayStrokeType_Dash,
  HOverlayStrokeType_Dot,
};

typedef enum {
  HAnnotationViewDragStateNone = 0,
  HAnnotationViewDragStateStarting,
  HAnnotationViewDragStateDragging,
  HAnnotationViewDragStateCanceling,
  HAnnotationViewDragStateEnding,
} HAnnotationViewDragState;

typedef enum {
  HPinAnnotationColorRed = 0,
  HPinAnnotationColorGreen,
  HPinAnnotationColorPurple,
} HPinAnnotationColor;

@protocol HAnnotation <NSObject>
@property(nonatomic, readonly) CLLocationCoordinate2D coordinate;
@end

@protocol HOverlay <NSObject>
@end

@class HAnnotationView;
@class HMapView;
@class HOverlayView;

@protocol HMapViewDelegate <NSObject>
@optional
- (void)mapViewInitComplete:(HMapView *)mapView;
@end

@interface HUserLocation : NSObject
@property(readonly, nonatomic, strong) CLLocation *location;
@end

@interface HMapView : UIView
@property(nonatomic, weak) id<HMapViewDelegate> delegate;
@property(nonatomic, assign) HMapType mapType;
@property(nonatomic, assign) BOOL showsTraffic;
@property(nonatomic, assign) BOOL shows3DBuildings;
@property(nonatomic, assign) BOOL showsLocationButton;
@property(nonatomic, assign, getter=isLocationButtonEnabled) BOOL locationButtonEnabled;
@property(nonatomic, assign) BOOL showsZoomControl;
@property(nonatomic, assign, getter=isZoomControlEnabled) BOOL zoomControlEnabled;
@property(nonatomic, assign) BOOL showsCompass;
@property(nonatomic, assign) BOOL showsUserLocation;
@property(nonatomic, readonly) HUserLocation *userLocation;
@property(nonatomic, assign) CLLocationCoordinate2D centerCoordinate;
@property(nonatomic, assign) CGFloat zoomLevel;
@property(nonatomic, readonly) CGFloat minZoomLevel;
@property(nonatomic, readonly) CGFloat maxZoomLevel;
@property(nonatomic, assign) CGFloat rotation;
@property(nonatomic, assign) CGFloat overlooking;
@property(nonatomic, assign) HMapRect visibleMapRect;
@property(nonatomic, assign) HCoordinateRegion region;
@property(nonatomic, assign, getter=isZoomEnabled) BOOL zoomEnabled;
@property(nonatomic, assign, getter=isKeepCenterDuringZoom) BOOL keepCenterDuringZoom;
@property(nonatomic, assign, getter=isScrollEnabled) BOOL scrollEnabled;
@property(nonatomic, assign, getter=isOverlookingEnabled) BOOL overlookingEnabled;
@property(nonatomic, assign, getter=isRotateEnabled) BOOL rotateEnabled;
@property(nonatomic, readonly) NSArray<id<HAnnotation>> *selectedAnnotations;
- (BOOL)setMapStyle:(NSString *)stylePath;
- (BOOL)setMapStyleID:(NSString *)styleID;
- (BOOL)setMapPreviewID:(NSString *)previewID;
- (void)setCenterOffset:(CGPoint)offset;
- (void)setLogoMargin:(CGPoint)margin anchor:(HMapLogoAnchor)anchor;
- (void)setCenterCoordinate:(CLLocationCoordinate2D)coordinate animated:(BOOL)animated;
- (void)setMinZoomLevel:(CGFloat)minZoomLevel maxZoomLevel:(CGFloat)maxZoomLevel;
- (void)setZoomLevel:(CGFloat)zoomLevel animated:(BOOL)animated;
- (void)setRotation:(CGFloat)rotation animated:(BOOL)animated;
- (void)setOverlooking:(CGFloat)overlooking animated:(BOOL)animated;
- (void)setVisibleMapRect:(HMapRect)mapRect
             edgePadding:(UIEdgeInsets)insets
                animated:(BOOL)animated;
- (void)setRegion:(HCoordinateRegion)region animated:(BOOL)animated;
- (void)addAnnotation:(id<HAnnotation>)annotation;
- (void)removeAnnotation:(id<HAnnotation>)annotation;
- (void)selectAnnotation:(id<HAnnotation>)annotation animated:(BOOL)animated;
- (void)deselectAnnotation:(id<HAnnotation>)annotation animated:(BOOL)animated;
- (void)addOverlay:(id<HOverlay>)overlay;
- (void)removeOverlay:(id<HOverlay>)overlay;
@end

@interface HPointAnnotation : NSObject <HAnnotation>
@property(nonatomic, strong) id userData;
@property(nonatomic, assign) CLLocationCoordinate2D coordinate;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *subtitle;
@end

@interface HAnnotationView : NSObject
@property(nonatomic, strong) id<HAnnotation> annotation;
@property(nonatomic, assign) CGPoint anchorPoint;
@property(nonatomic, assign) int zIndex;
@property(nonatomic, strong) UIImage *image;
@property(nonatomic, assign, getter=isEnabled) BOOL enabled;
@property(nonatomic, assign) BOOL canShowCallout;
@property(nonatomic, assign, getter=isDraggable) BOOL draggable;
@end

@interface HPinAnnotationView : HAnnotationView
@property(nonatomic, assign) HPinAnnotationColor pinColor;
@end

@interface HPolyline : NSObject <HOverlay>
@property(nonatomic, strong) id userData;
+ (HPolyline *)polylineWithCoordinates:(CLLocationCoordinate2D *)coordinates
                                 count:(NSUInteger)count;
@end

@interface HPolygon : NSObject <HOverlay>
@property(nonatomic, strong) id userData;
+ (HPolygon *)polygonWithCoordinates:(CLLocationCoordinate2D *)coordinates
                               count:(NSUInteger)count;
@end

@interface HCircle : NSObject <HOverlay>
@property(nonatomic, strong) id userData;
+ (HCircle *)circleWithCenterCoordinate:(CLLocationCoordinate2D)coordinate
                                  radius:(double)radius;
@end

@interface HGroundOverlay : NSObject <HOverlay>
@property(nonatomic, strong) id userData;
@property(nonatomic, assign) float opacity;
+ (HGroundOverlay *)groundOverlayWithBounds:(HCoordinateBounds)bounds
                                      icon:(UIImage *)icon;
@end

@interface HTileOverlayPath : NSObject
@property(nonatomic, assign) NSInteger x;
@property(nonatomic, assign) NSInteger y;
@property(nonatomic, assign) NSInteger z;
@end

typedef void (^HTileDataCallback)(NSData *_Nullable tileData,
                                  NSError *_Nullable error);

@interface HTileOverlay : NSObject <HOverlay>
- (instancetype)initWithURLTemplate:(NSString *)URLTemplate;
- (void)loadTileAtPath:(HTileOverlayPath *)path result:(HTileDataCallback)result;
@end

@interface HOverlayView : NSObject
@property(nonatomic, assign) int zIndex;
@property(nonatomic, assign) BOOL isClickable;
@property(nonatomic, assign) BOOL isVisible;
@end

@interface HPolylineView : HOverlayView
@property(nonatomic, strong) UIColor *strokeColor;
@property(nonatomic, assign) CGFloat lineWidth;
@property(nonatomic, copy) NSArray<NSNumber *> *lineDashPattern;
- (instancetype)initWithPolyline:(HPolyline *)polyline;
@end

@interface HPolygonView : HOverlayView
@property(nonatomic, strong) UIColor *fillColor;
@property(nonatomic, strong) UIColor *strokeColor;
@property(nonatomic, assign) CGFloat lineWidth;
@property(nonatomic, assign) HOverlayStrokeType lineType;
@property(nonatomic, copy) NSArray<NSNumber *> *lineDashPattern;
- (instancetype)initWithPolygon:(HPolygon *)polygon;
@end

@interface HCircleView : HOverlayView
@property(nonatomic, strong) UIColor *fillColor;
@property(nonatomic, strong) UIColor *strokeColor;
@property(nonatomic, assign) CGFloat lineWidth;
- (instancetype)initWithCircle:(HCircle *)circle;
@end

@interface HGroundOverlayView : HOverlayView
- (instancetype)initWithOverlay:(HGroundOverlay *)overlay;
@end

@interface HTileOverlayView : HOverlayView
- (instancetype)initWithTileOverlay:(HTileOverlay *)tileOverlay;
- (void)reloadData;
@end

@interface HPoiInfo : NSObject
@property(nonatomic, copy) NSString *uid;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, assign) CLLocationCoordinate2D coordinate;
@end
