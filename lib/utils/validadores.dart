/// Utilidades de validación para la aplicación, ahora usando el núcleo de validación centralizado.
library validadores;

import '../core/validation_utils.dart';
export '../core/validation_utils.dart' show validarCUITCUIL;

/// Valida un CUIT o CUIL y retorna un mensaje de error descriptivo si es inválido.
///
/// Utiliza la función `validarCUITCUIL` del core para la lógica de validación.
///
/// [numero] - CUIT o CUIL con o sin guiones.
///
/// Retorna `null` si es válido, o un mensaje de error si es inválido.
String? validarCUITCUILConMensaje(String? numero) {
  if (numero == null || numero.trim().isEmpty) {
    return 'Ingrese el CUIT/CUIL';
  }

  final digitsOnly = numero.replaceAll(RegExp(r'[^\d]'), '');

  if (digitsOnly.length != 11) {
    return 'El CUIT/CUIL debe tener 11 dígitos';
  }

  // REFACTOR: Llama a la función centralizada en el core.
  if (!validarCUITCUIL(numero)) {
    return 'CUIT/CUIL inválido: Verifique los dígitos';
  }

  return null;
}

/// Valida múltiples CUILs y retorna una lista de errores.
///
/// Utiliza la función `validarCUITCUIL` del core para la lógica de validación.
///
/// [cuils] - Lista de CUILs a validar (con o sin guiones).
///
/// Retorna una lista de mensajes de error. Si la lista está vacía, todos los CUILs son válidos.
List<String> validarListaCUILs(List<String> cuils) {
  final errores = <String>[];

  for (int i = 0; i < cuils.length; i++) {
    final cuil = cuils[i];
    final digitsOnly = cuil.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.length != 11) {
      errores.add('CUIL en posición ${i + 1}: Debe tener 11 dígitos');
      continue;
    }

    // REFACTOR: Llama a la función centralizada en el core.
    if (!validarCUITCUIL(cuil)) {
      errores.add('CUIL en posición ${i + 1}: Número inválido (verifique los dígitos)');
    }
  }

  return errores;
}
