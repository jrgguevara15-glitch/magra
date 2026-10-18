/// Configuración del backend.
///
/// La publishable key de Supabase es pública por diseño: la seguridad la
/// ponen las reglas RLS de la base de datos. La clave secreta nunca va aquí.
/// Se pueden reemplazar al compilar con `--dart-define`.
abstract final class MagraConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://twtkxvbnkxuggsnkihlb.supabase.co',
  );

  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_NVNvBwgL-yBhYzmugHAtxw_4qR2xRS9',
  );
}
