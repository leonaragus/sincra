
/// Contiene funciones de validación puras y reutilizables sin dependencias externas.
library validation_utils;

/// Valida un CUIT o CUIL usando el algoritmo de Módulo 11 de ARCA/AFIP
///
/// [numero] - CUIT o CUIL con o sin guiones (ej: "20-12345678-9" o "20123456789")
///
/// Retorna `true` si el número es válido matemáticamente, `false` en caso contrario.
bool validarCUITCUIL(String numero) {
  // Limpiar el número (eliminar guiones y espacios)
  final digitsOnly = numero.replaceAll(RegExp(r'[^\d]'), '');
  
  // Verificar que tenga exactamente 11 dígitos
  if (digitsOnly.length != 11) {
    return false;
  }
  
  // Verificar que todos sean dígitos
  if (!RegExp(r'^\d{11}$').hasMatch(digitsOnly)) {
    return false;
  }
  
  // Obtener el dígito verificador (último dígito)
  final digitoVerificador = int.parse(digitsOnly[10]);
  
  // Coeficientes para el algoritmo de Módulo 11
  final coeficientes = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2];
  
  // Multiplicar los primeros 10 dígitos por los coeficientes y sumar
  int suma = 0;
  for (int i = 0; i < 10; i++) {
    final digito = int.parse(digitsOnly[i]);
    suma += digito * coeficientes[i];
  }
  
  // Calcular el resto de la división por 11
  final resto = suma % 11;
  
  // Calcular el dígito verificador esperado según el algoritmo oficial
  int digitoEsperado;
  if (resto == 0) {
    digitoEsperado = 0;
  } else if (resto == 1) {
    // El caso del resto 1 es especial y depende de si se trata de una persona física o jurídica
    // Pero la validación estándar que usa AFIP no hace esta distinción.
    // Para simplificar y seguir el estándar más común, se puede adoptar una de las dos reglas.
    // La más aceptada es que para resto 1, el dígito verificador es 9.
    // Otra regla dice que el CUIT es inválido o se debe verificar el CUIL de la persona.
    // Aquí adoptamos la regla del 9, que es la más común en validadores online.
    digitoEsperado = 9;
  } else {
    digitoEsperado = 11 - resto;
  }
  
  // Comparar el dígito verificador ingresado con el esperado
  return digitoVerificador == digitoEsperado;
}
