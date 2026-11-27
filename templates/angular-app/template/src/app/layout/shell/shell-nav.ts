import { Injectable, signal } from '@angular/core';

/** Un paso de las migas de pan. Sin `link` = la página actual. */
export interface Crumb {
  /** Clave de i18n (con `translate: true`) o texto ya resuelto (p. ej. el nombre de un ítem). */
  label: string;
  translate?: boolean;
  link?: readonly unknown[];
}

/**
 * Lo que cada página le cuenta al shell: sus migas de pan. Las páginas las fijan
 * al cargar (`nav.set([...])`); el shell sólo las lee.
 */
@Injectable({ providedIn: 'root' })
export class ShellNav {
  private readonly _crumbs = signal<readonly Crumb[]>([]);

  readonly crumbs = this._crumbs.asReadonly();

  set(crumbs: readonly Crumb[]): void {
    this._crumbs.set(crumbs);
  }

  /** Al salir del shell (logout): la próxima sesión no ve las migas anteriores. */
  clear(): void {
    this.set([]);
  }
}
