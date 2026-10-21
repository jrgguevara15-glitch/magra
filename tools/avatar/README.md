# Avatar y demostraciones de ejercicios

Maniquí 3D sin rostro (gris, con camiseta, calzas o jogger y zapatillas)
construido a partir de **MakeHuman** (malla, morfologías, esqueleto y pesos
publicados como **CC0**, de uso libre comercial) y renderizado en
**Blender** (módulo `bpy`). Genera las hojas de cuadros que usa la app en
`apps/mobile/assets/demos/`.

## Preparar (una vez)

```bash
# Datos de MakeHuman (solo lectura; los archivos LFS no hacen falta)
GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 https://github.com/makehumancommunity/makehuman ~/makehuman
export MH_DATA=~/makehuman/makehuman/data

python3 -m venv venv
venv/bin/pip install bpy==5.2.2 pillow
```

## Generar

1. Exportar los movimientos de la app (poses, fases, implementos, músculos):

   ```bash
   cd apps/mobile
   flutter test test/tool/export_demos_test.dart \
     --dart-define=DEMO_EXPORT=$PWD/../../tools/avatar/anims.json
   ```

2. Vista previa del avatar (opcional): `venv/bin/python avatar.py salida.png`
   (`VIEW=0|90|180`).

3. Renderizar (se puede cortar y retomar; salta lo que ya existe):

   ```bash
   venv/bin/python render_demos.py /tmp/demos --sex f
   venv/bin/python render_demos.py /tmp/demos --sex m
   # un ejercicio: --only sentadilla-con-barra   revisión rápida: --preview
   ```

4. Copiar a la app: `cp /tmp/demos/*.webp apps/mobile/assets/demos/` y
   `cp /tmp/demos/thumbs/*.webp apps/mobile/assets/demos/thumbs/`.

Cada hoja es `<slug>_<f|m>_<f|l|b>.webp` (mujer/hombre; frente, lado ¾ y
espalda): 4 columnas de cuadros de 384 px con transparencia. Los cuadros
recorren la ida del movimiento (12) o la vuelta completa en los ejercicios
en bucle (16); la app arma el ciclo (pausas, vuelta, fases) y funde un
cuadro con el siguiente. Los músculos del ejercicio van teñidos (rojo:
trabaja más; naranja: ayuda).
