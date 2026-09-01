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

#import <Flutter/Flutter.h>

NS_ASSUME_NONNULL_BEGIN

/// The route selected by HuaweiMapInitializer before the first map is built.
FOUNDATION_EXPORT NSString *_Nullable HMSMapRoutePolicy(void);
FOUNDATION_EXPORT void HMSSetMapRoutePolicy(NSString *_Nullable routePolicy);

/// Factory for the native Huawei Map Kit platform view.
@interface HMSMapPlatformViewFactory : NSObject <FlutterPlatformViewFactory>

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger
                         registrar:(NSObject<FlutterPluginRegistrar> *)registrar;

@end

NS_ASSUME_NONNULL_END
