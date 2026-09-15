import { WebPlugin } from '@capacitor/core';

import type { StorefrontInfo, StorefrontPlugin } from './definitions';

export class StorefrontWeb extends WebPlugin implements StorefrontPlugin {
  async getStorefront(): Promise<StorefrontInfo> {
    throw this.unimplemented('Storefront is only available on iOS and Android.');
  }
}
