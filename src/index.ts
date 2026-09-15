import { registerPlugin } from '@capacitor/core';

import type { StorefrontPlugin } from './definitions';

const Storefront = registerPlugin<StorefrontPlugin>('Storefront', {
  web: () => import('./web').then((m) => new m.StorefrontWeb()),
});

export * from './definitions';
export { Storefront };
