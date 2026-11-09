---
name: esperando
description: Marca en la barra lateral de herdr por qué esta sesión queda quieta (le pregunta algo a la persona, espera a otra sesión o espera un CI o un merge). Usar dentro de herdr (HERDR_ENV=1) justo antes de terminar un turno en el que quedás esperando; no hace falta si terminaste y no esperás nada.
---

# Marcar la espera en herdr

Sólo dentro de herdr (`HERDR_ENV=1` y `HERDR_PANE_ID` definidos); si no, no
hagas nada. La marca se limpia sola cuando la sesión vuelve a recibir trabajo
(hook `herdr.sh` de dev-agentes). Los pedidos de permiso y las preguntas con
opciones herdr ya los muestra solo (`⚠ TU DECISIÓN`): esto es para cuando
terminás el turno en texto. `docs/03` §13 de dev-plantillas.

Elegí una y correla como último paso del turno:

```bash
# Terminás con una pregunta o una decisión para la persona
herdr pane report-metadata "$HERDR_PANE_ID" --source dev-espera \
  --token "espera=🙋 te pregunta" --token "espera_tipo=persona" --clear-token espera_a

# Esperás a otra sesión
herdr pane report-metadata "$HERDR_PANE_ID" --source dev-espera \
  --token "espera=⏳ espera a <sesión>" --token "espera_tipo=sesion" --token "espera_a=<sesión>"

# Esperás algo que no es una sesión (un CI, un merge, un deploy)
herdr pane report-metadata "$HERDR_PANE_ID" --source dev-espera \
  --token "espera=⏳ espera a <qué>" --token "espera_tipo=otro" --token "espera_a=<qué>"

# Quitar la marca a mano
herdr pane report-metadata "$HERDR_PANE_ID" --source dev-espera \
  --clear-token espera --clear-token espera_tipo --clear-token espera_a
```

Los tokens de la fuente `dev-espera` son un contrato para quien los lea (la
barra lateral, un tracker): `espera` es el texto visible y puede cambiar;
`espera_tipo` es `persona`, `sesion` u `otro`; `espera_a` dice a quién o a qué
se espera (vacío si es la persona).
