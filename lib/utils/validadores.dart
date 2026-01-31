/// Utilidades de validación para la aplicación
/// 
/// Contiene funciones de validación matemática para CUIT/CUIL
/// según el algoritmo oficial de ARCA/AFIP (Módulo 11)
library validadores;

/// Valida un CUIT o CUIL usando el algoritmo de Módulo 11 de ARCA/AFIP
/// 
/// [numero] - CUIT o CUIL con o sin guiones (ej: "20-12345678-9" o "20123456789")
/// 
/// Retorna `true` si el número es válido matemáticamente, `false` en caso contrario
/// 
/// Algoritmo:
/// 1. Multiplicar los primeros 10 dígitos por la serie: 5, 4, 3, 2, 7, 6, 5, 4, 3, 2
/// 2. Sumar los resultados
/// 3. Calcular el resto de la división por 11
/// 4. El dígito verificador (último número) debe coincidir con:
///    - Si resto = 0: dígito = 0
///    - Si resto = 1: dígito = 9
///    - Si resto >= 2: dígito = 11 - resto
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
    digitoEsperado = 9; // Caso especial: si resto es 1, dígito es 9
  } else {
    digitoEsperado = 11 - resto;
  }
  
  // Comparar el dígito verificador ingresado con el esperado
  return digitoVerificador == digitoEsperado;
}

/// Valida un CUIT o CUIL y retorna un mensaje de error descriptivo si es inválido
/// 
/// [numero] - CUIT o CUIL con o sin guiones
/// 
/// Retorna `null` si es válido, o un mensaje de error si es inválido
String? validarCUITCUILConMensaje(String? numero) {
  if (numero == null || numero.trim().isEmpty) {
    return 'Ingrese el CUIT/CUIL';
  }
  
  final digitsOnly = numero.replaceAll(RegExp(r'[^\d]'), '');
  
  if (digitsOnly.length != 11) {
    return 'El CUIT/CUIL debe tener 11 dígitos';
  }
  
  if (!validarCUITCUIL(numero)) {
    return 'CUIT/CUIL inválido: Verifique los dígitos';
  }
  
  return null;
}

/// Valida múltiples CUILs y retorna una lista de errores
/// 
/// [cuils] - Lista de CUILs a validar (con o sin guiones)
/// 
/// Retorna una lista de mensajes de error. Si la lista está vacía, todos los CUILs son válidos
List<String> validarListaCUILs(List<String> cuils) {
  final errores = <String>[];
  
  for (int i = 0; i < cuils.length; i++) {
    final cuil = cuils[i];
    final digitsOnly = cuil.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.length != 11) {
      errores.add('CUIL en posición ${i + 1}: Debe tener 11 dígitos');
      continue;
    }
    
    if (!validarCUITCUIL(cuil)) {
      errores.add('CUIL en posición ${i + 1}: Número inválido (verifique los dígitos)');
    }
  }
  
  return errores;
}
