import { ChangeDetectionStrategy, Component, computed, input, output } from '@angular/core';

export type ButtonVariant = 'primary' | 'secondary' | 'outline' | 'ghost' | 'danger';
export type ButtonSize = 'sm' | 'md' | 'lg';

/**
 * Botón con las clases `vrb-button` del design system vrb (con estado de carga).
 * Componente de `ui/`: sin lógica de negocio,
 * sin inyectar stores ni clientes; todo entra por inputs y sale por outputs.
 *
 *   <ui-button variant="secondary" (pressed)="retry()">Reintentar</ui-button>
 */
@Component({
  selector: 'ui-button',
  templateUrl: './button.html',
  styleUrl: './button.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Button {
  readonly variant = input<ButtonVariant>('primary');
  readonly size = input<ButtonSize>('md');
  readonly type = input<'button' | 'submit'>('button');
  readonly disabled = input(false);
  readonly loading = input(false);
  readonly fullWidth = input(false);

  readonly pressed = output<MouseEvent>();

  protected readonly isDisabled = computed(() => this.disabled() || this.loading());
  /** Clases de vrb (`md` es el tamaño por defecto, sin modificador). */
  protected readonly classes = computed(() =>
    [
      'vrb-button',
      `vrb-button--${this.variant()}`,
      this.size() === 'md' ? '' : `vrb-button--${this.size()}`,
      this.fullWidth() ? 'ui-button--full' : '',
    ]
      .filter(Boolean)
      .join(' '),
  );

  protected onClick(event: MouseEvent): void {
    if (this.isDisabled()) return;
    this.pressed.emit(event);
  }
}
