# Finomiau — logo kit

Una ficha (entre moneda y tarjeta, la superelipse de los íconos de iOS) que se vuelve cara de gato con lo mínimo:
dos orejas en las esquinas y dos ojos redondos. El wordmark es «finomiau» en minúsculas pesadas y compactas, con el
símbolo como la «o». Guía visual: `guia.html` / `guia.png`.

## Archivos

| Archivo | Uso |
|---|---|
| `svg/finomiau-wordmark-on-dark.svg` | Logo principal sobre fondos oscuros (texto blanco, «o» lima) |
| `svg/finomiau-wordmark-on-light.svg` | Logo principal sobre blanco / gris claro (todo tinta) |
| `svg/finomiau-wordmark-black.svg`, `-white.svg` | Una tinta (impresión, sellos, fondos de color) |
| `svg/finomiau-symbol-{lime,ink,black,white}.svg` | Símbolo solo, ≥ 40 px |
| `svg/finomiau-symbol-small-*.svg` | Corte para tamaños chicos (ojos 1,6× más grandes), < 40 px |
| `svg/finomiau-app-icon.svg` | Ícono de app a sangre (iOS / tiendas aplican su máscara) |
| `svg/finomiau-app-icon-rounded.svg` | Ícono con esquinas iOS, para presentaciones y README |
| `svg/finomiau-favicon.svg` | Favicon (corte small, sin brillo) |
| `svg/android-adaptive-*.svg` | Capas del ícono adaptativo de Android (fondo, frente, monocromo) |
| `svg/ios-dark.svg`, `ios-tinted.svg` | Apariencias oscura y tintada de iOS 18 |
| `png/` | Los mismos en PNG: `app-icon-1024`, `play-store-512`, `favicon-{16,32,48,180,192,512}`, `favicon.ico`, símbolos a 512/128, wordmarks a 1200 de ancho |

Wordmark y símbolo son trazos (sin texto vivo, sin efectos). El volumen, brillo y sombra existen solo en el ícono de app.

## Reglas cortas

- **Color**: lima `#C8F04B` (RGB 200 240 75) y tinta `#1C1C1E` (RGB 28 28 30); blanco `#F7F7F8` para el texto sobre oscuro.
  Lima sobre tinta: 13:1. Lima sobre blanco: 1,3:1 → nunca; sobre claro todo va en tinta.
  CMYK aproximado (pide prueba de color): lima 17 0 69 6; tinta como negro enriquecido. Sin Pantone asignado: elegirlo
  con una guía física.
- **Espacio libre**: alrededor del wordmark, la mitad de la altura de la cara de Michi (sin orejas); alrededor del
  símbolo, ¼ de su ancho.
- **Tamaño mínimo**: wordmark 24 px de alto (≈ 133 px de ancho), 30 mm de ancho impreso; más chico, solo el ícono.
  Símbolo: 16 px con el corte small.
- **No**: estirar, rotar, recolorear, añadir sombras/contornos/degradados al logo plano, reescribir el nombre con la
  fuente, cambiar ojos u orejas, ni usar el símbolo grande debajo de 40 px.
- **Tipografía**: el wordmark es Inter Display Black (OFL) convertida a trazos. En la app: Inter / Inter Display
  (`assets/fonts/inter`).

## Regenerar

```bash
python3 -m pip install fonttools        # una vez (en un venv)
python3 branding/build_kit.py           # SVG en branding/svg/
branding/render_kit.sh                  # PNG en branding/png/ (rsvg-convert + ImageMagick)
dart run flutter_launcher_icons         # Android, iOS y web (config en pubspec.yaml)
cp branding/png/favicon-32.png web/favicon.png   # el generador hace el favicon con el ícono grande
```

La geometría del símbolo está en `build_kit.py` (`mark()`); cambiarla ahí actualiza todo el kit.

La marca no tiene búsqueda de registro (trademark): conviene hacerla antes de publicar en tiendas.
