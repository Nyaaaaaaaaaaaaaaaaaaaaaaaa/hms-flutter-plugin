/*
 * Copyright 2020-2026. Huawei Technologies Co., Ltd. All rights reserved.
 * Licensed under the Apache License, Version 2.0.
 */

import { BinaryMessenger } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';
import MessageCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/MessageCodec';
import PlatformView from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';
import PlatformViewFactory from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformViewFactory';
import { common } from '@kit.AbilityKit';
import HmsMapPlatformView from './HmsMapPlatformView';

export default class HmsMapViewFactory extends PlatformViewFactory {
  private readonly messenger: BinaryMessenger;

  constructor(messenger: BinaryMessenger, creationCodec: MessageCodec<Object>) {
    super(creationCodec);
    this.messenger = messenger;
  }

  create(context: common.Context, viewId: number, args: Object): PlatformView {
    return new HmsMapPlatformView(
      context,
      viewId,
      args as ESObject,
      this.messenger
    );
  }
}
