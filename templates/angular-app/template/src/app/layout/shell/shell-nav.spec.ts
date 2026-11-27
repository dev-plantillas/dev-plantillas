import { describe, expect, it } from 'vitest';

import { ShellNav } from './shell-nav';

describe('ShellNav', () => {
  it('guarda las migas que fija la página', () => {
    const nav = new ShellNav();
    nav.set([
      { label: 'items.list.title', translate: true, link: ['/items'] },
      { label: 'Ítem 1' },
    ]);
    expect(nav.crumbs()).toEqual([
      { label: 'items.list.title', translate: true, link: ['/items'] },
      { label: 'Ítem 1' },
    ]);
  });

  it('clear deja el shell sin migas', () => {
    const nav = new ShellNav();
    nav.set([{ label: 'Ítems' }]);
    nav.clear();
    expect(nav.crumbs()).toEqual([]);
  });
});
