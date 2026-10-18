import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../core/data/providers.dart';

/// Iniciar sesión o crear cuenta con correo y contraseña.
class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final auth = ref.read(authRepositoryProvider);
    final email = _email.text.trim();
    try {
      if (_creating) {
        final pending = await auth.signUp(email, _password.text);
        if (pending && mounted) {
          setState(() {
            _message =
                'Cuenta creada. Revisa tu correo y confirma la cuenta para entrar.';
            _messageIsError = false;
            _creating = false;
          });
        }
      } else {
        await auth.signIn(email, _password.text);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _message = authErrorText(e.message);
          _messageIsError = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'No hay conexión con el servidor. Revisa tu internet.';
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'MAGRA',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pierde grasa. Conserva lo que importa.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v != null && v.contains('@')
                          ? null
                          : 'Escribe un correo válido.',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v != null && v.length >= 8
                          ? null
                          : 'Mínimo 8 caracteres.',
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(_creating ? 'Crear cuenta' : 'Entrar'),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _creating = !_creating;
                                _message = null;
                              }),
                      child: Text(_creating
                          ? 'Ya tengo cuenta: entrar'
                          : 'No tengo cuenta: crear una'),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _messageIsError
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Traduce los errores más comunes de Supabase Auth.
String authErrorText(String message) {
  final m = message.toLowerCase();
  if (m.contains('invalid login')) return 'Correo o contraseña incorrectos.';
  if (m.contains('already registered')) {
    return 'Ese correo ya tiene cuenta. Entra con tu contraseña.';
  }
  if (m.contains('not confirmed')) {
    return 'Falta confirmar la cuenta: revisa tu correo.';
  }
  if (m.contains('rate limit')) {
    return 'Demasiados intentos. Espera unos minutos.';
  }
  return 'No se pudo completar: $message';
}
