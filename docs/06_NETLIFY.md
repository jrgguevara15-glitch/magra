# 06 — Publicar MAGRA web en Netlify

Con https la app funciona igual en el celular (cámara en vivo para el
código de barras, fotos, dictado) y se puede agregar a la pantalla de
inicio del iPhone como una app.

## Publicar o actualizar (manual)

1. Desde `apps/mobile`: `flutter build web --release`.
2. Primera vez: app.netlify.com → **Add new site** → **Deploy manually** →
   arrastrar la carpeta `apps/mobile/build/web`.
   Actualizar: el sitio → **Deploys** → arrastrar de nuevo `build/web`.
3. `web/_headers` evita que el navegador se quede con una versión vieja.

## Seguridad mientras está en desarrollo

La dirección es pública: cualquiera podría crear una cuenta y usar la IA
(con costo). Mientras no se venda:

- Supabase → Authentication → **Sign In / Providers** → desactivar
  **Allow new users to sign up** (las cuentas existentes siguen entrando).
- Los límites diarios por usuario de la IA siguen activos.

## iPhone

Safari → la dirección `https://<sitio>.netlify.app` → **Compartir** →
**Agregar a inicio**.
