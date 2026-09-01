/*
 * Copyright 2020-2026. Huawei Technologies Co., Ltd. All rights reserved.
 * Licensed under the Apache License, Version 2.0.
 */

import { MapComponent, map, mapCommon } from '@kit.MapKit';
import { AsyncCallback } from '@kit.BasicServicesKit';
import { Params } from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';
import HmsMapPlatformView from './HmsMapPlatformView';

@Component
export struct HmsMapComponent {
  @Prop params: Params;
  private platformView: HmsMapPlatformView =
    this.params.platformView as HmsMapPlatformView;
  private mapOptions: mapCommon.MapOptions =
    this.platformView.createMapOptions();
  private mapCallback: AsyncCallback<map.MapComponentController> =
    async (error, controller) => {
      if (error) {
        this.platformView.onMapError(error);
        return;
      }
      await this.platformView.onMapReady(controller);
    };

  aboutToAppear(): void {
    this.platformView.onShown();
  }

  aboutToDisappear(): void {
    this.platformView.onHidden();
  }

  build() {
    MapComponent({
      mapOptions: this.mapOptions,
      mapCallback: this.mapCallback
    })
      .width('100%')
      .height('100%');
  }
}

@Builder
export function HmsMapBuilder(params: Params) {
  HmsMapComponent({ params: params });
}
