# Diseños

Un diseño por pantalla o flujo, en una carpeta: `disenos/<slug>/`, con
`diseno.md` (estado, repos, qué resuelve) y una carpeta por versión (`v1/`,
`v2/`…) con los archivos locales: HTML, PNG, SVG.

**Sólo se programa la versión aprobada de un diseño aprobado.** Los borradores,
los diseños en revisión y los descartados se guardan para tener historia, pero
no son referencia para implementar.

- [Por estado](../_generado/disenos.md): aprobados (con la versión que se
  programa), en revisión, borradores y descartados.

Diseño nuevo: `make nuevo TIPO=diseno TITULO="..." [REPOS=<front>]`. Cómo se
trabaja: [Cómo documentar](../plataforma/como-documentar.md#disenos).
