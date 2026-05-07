# Release y despliegue

Esta página resume el flujo mínimo para pasar de una ejecución validada a una versión publicada.

Sirve para mantener consistencia entre datos, frontend y documentación.

Una release no es solo publicar código. También es publicar una interpretación metodológica concreta: fuentes, alcance, pesos, umbrales y limitaciones.

## Flujo recomendado

1. Regenerar dataset y tiles.
2. Ejecutar QA técnico y metodológico.
3. Compilar frontend y docs.
4. Desplegar con `npm run deploy` en `frontend/`.

## Control de cambios

- Registrar cambios de umbrales y pesos.
- Registrar cambios de alcance analítico.
- Registrar fuentes nuevas y fallback utilizados.
- Registrar cambios visibles en interpretación de indicadores.
- Revisar que la documentación explica esos cambios con lenguaje claro.

## Nota de interpretación

Publicar una nueva versión no implica que el ranking anterior fuera "incorrecto". En muchos casos solo refleja mejor cobertura de datos o ajustes metodológicos explícitos.
