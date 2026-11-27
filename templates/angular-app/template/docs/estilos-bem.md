# Estilos: design system vrb + SCSS/BEM para acomodar

**Toda interfaz usa el design system vrb; lo que falte se agrega a vrb, no CSS
suelto en el proyecto.** Botones, campos, tarjetas, insignias, avisos, diálogos,
sidebar, migas de pan… son clases `vrb-*` (`@vrojas1015/vrb/dist/vrb.css`, cargado
en `angular.json`; catálogo en `node_modules/@vrojas1015/vrb/design-system/scss/`).
El SCSS del componente sólo acomoda (grilla, separación, ancho) y lee variables:
nunca define colores, fuentes ni componentes visuales propios. Si vrb no trae algo
que la pantalla necesita, se agrega al repo de vrb (PR + versión nueva) y aquí se
sube la dependencia.

## Capas

| Dónde | Qué |
|---|---|
| `@vrojas1015/vrb` | Componentes (`vrb-*`) y variables (`--vrb-*`): colores, tipografía, radios, sombras. |
| `src/styles/_fonts.scss` | IBM Plex del paquete (los `.woff2` se copian a `/fonts`). |
| `src/styles/_tokens.scss` | Alias a `--vrb-*` (`--color-*`, `--space-*`, `--radius-*`…) para el SCSS de acomodo. |
| `src/styles/_reset.scss`, `_typography.scss` | Base global mínima. |
| `src/styles/_mixins.scss` | Mixins compartidos (`@use 'mixins' as m;`). |
| `src/styles/_utilities.scss` | Muy pocas utilidades globales, prefijo `u-`. |
| `<componente>.scss` | Todo lo demás. Encapsulado por Angular. |

`src/styles` está en `includePaths`, así que desde cualquier componente se importa
con `@use 'mixins' as m;` sin rutas relativas.

## BEM

- **Bloque** = el componente: `.item-list`. Un bloque por archivo `.scss`.
- **Elemento** = parte del bloque: `.item-list__row`, `.item-list__link`.
- **Modificador** = variante o estado: `.item-list__row--active`, `.ui-button--full`.

```scss
.item-list {
  &__rows { ... }
  &__row {
    ...
    &--active { ... }
  }
}
```

## Reglas

1. Nada de hex, px de color ni tamaños mágicos: `var(--vrb-*)` o su alias de `_tokens.scss`. Si
   falta un valor o un componente, se agrega a vrb, no aquí.
2. Sin anidar elementos dentro de elementos (`.a__b__c` no existe): si hace falta, es otro bloque
   o un componente nuevo.
3. Sin selectores de etiqueta ni de id para estilar (`.item-list li` no; `.item-list__row` sí).
4. Componentes de `ui/` usan el prefijo `ui-` (`.ui-button`); los de features/layout, el nombre
   del componente (`.item-list`, `.shell`).
5. Estados con modificadores o atributos (`--active`, `:disabled`, `[aria-busy]`), no con clases
   sueltas tipo `.active`.
6. `::ng-deep` prohibido. Si un hijo necesita variantes, se le agrega un input.
