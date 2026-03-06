
/// Define los posibles roles que un usuario puede asumir en la aplicación,
/// especialmente después de que el período de prueba inicial ha terminado.
enum UserRole {
  /// El estado inicial. El usuario aún no ha decidido qué tipo de perfil es.
  /// La app le mostrará la pantalla de selección de rol.
  undecided,

  /// Un usuario casual que solo quiere analizar sus propios recibos.
  /// Tiene acceso a un plan gratuito y limitado.
  information,

  /// Un profesional (contador, RRHH) que usará la app para trabajar.
  /// Se le dirigirá hacia los planes de suscripción de pago.
  professional,
}
