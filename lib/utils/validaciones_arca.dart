// ========================================================================
// VALIDACIONES ARCA 2026
// Validaciones para garantizar cumplimiento con formatos ARCA/AFIP
// ========================================================================

/// Valida formato de CBU (22 dígitos)
class ValidacionesARCA {
  /// Valida que un CBU tenga exactamente 22 dígitos
  static bool validarCBU(String cbu) {
    if (cbu.isEmpty) return true; // CBU es opcional
    
    // Eliminar espacios y guiones
    final cbuLimpio = cbu.replaceAll(RegExp(r'[\s\-]'), '');
    
    // Debe tener exactamente 22 dígitos
    if (cbuLimpio.length != 22) return false;
    
    // Debe ser numérico
    if (!RegExp(r'^\d+$').hasMatch(cbuLimpio)) return false;
    
    // Validación adicional: dígitos verificadores
    return _validarDigitosVerificadores(cbuLimpio);
  }
  
  /// Valida los dígitos verificadores del CBU
  static bool _validarDigitosVerificadores(String cbu) {
    if (cbu.length != 22) return false;
    
    try {
      // Primer bloque: primeros 8 dígitos (entidad + sucursal + dígito verificador)
      final bloque1 = cbu.substring(0, 8);
      final dv1 = int.parse(bloque1[7]);
      final entidadSucursal = bloque1.substring(0, 7);
      final dv1Calculado = _calcularDigitoVerificadorBloque1(entidadSucursal);
      
      if (dv1 != dv1Calculado) return false;
      
      // Segundo bloque: dígitos 9-21 (número de cuenta + dígito verificador)
      final bloque2 = cbu.substring(8, 22);
      final dv2 = int.parse(bloque2[13]);
      final numeroCuenta = bloque2.substring(0, 13);
      final dv2Calculado = _calcularDigitoVerificadorBloque2(numeroCuenta);
      
      if (dv2 != dv2Calculado) return false;
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Calcula el dígito verificador del primer bloque (entidad + sucursal)
  static int _calcularDigitoVerificadorBloque1(String entidadSucursal) {
    final pesos = [7, 1, 3, 9, 7, 1, 3];
    int suma = 0;
    
    for (int i = 0; i < 7; i++) {
      suma += int.parse(entidadSucursal[i]) * pesos[i];
    }
    
    final diferencia = 10 - (suma % 10);
    return diferencia == 10 ? 0 : diferencia;
  }
  
  /// Calcula el dígito verificador del segundo bloque (número de cuenta)
  static int _calcularDigitoVerificadorBloque2(String numeroCuenta) {
    final pesos = [3, 9, 7, 1, 3, 9, 7, 1, 3, 9, 7, 1, 3];
    int suma = 0;
    
    for (int i = 0; i < 13; i++) {
      suma += int.parse(numeroCuenta[i]) * pesos[i];
    }
    
    final diferencia = 10 - (suma % 10);
    return diferencia == 10 ? 0 : diferencia;
  }
  
  /// Formatea CBU con guiones para mejor legibilidad
  static String formatearCBU(String cbu) {
    final cbuLimpio = cbu.replaceAll(RegExp(r'[\s\-]'), '');
    
    if (cbuLimpio.length != 22) return cbu;
    
    // Formato: XXXX-XXXX-XXXX-XXXX-XXXX-XX
    return '${cbuLimpio.substring(0, 4)}-'
           '${cbuLimpio.substring(4, 8)}-'
           '${cbuLimpio.substring(8, 12)}-'
           '${cbuLimpio.substring(12, 16)}-'
           '${cbuLimpio.substring(16, 20)}-'
           '${cbuLimpio.substring(20, 22)}';
  }
  
  /// Valida código postal argentino
  static bool validarCodigoPostal(String? cp) {
    if (cp == null || cp.isEmpty) return true; // Opcional
    
    // Código postal argentino: 4 dígitos o letra + 4 dígitos
    return RegExp(r'^[A-Z]?\d{4}$', caseSensitive: false).hasMatch(cp.trim());
  }
  
  /// Valida código RNOS (6 dígitos)
  static bool validarCodigoRNOS(String? rnos) {
    if (rnos == null || rnos.isEmpty) return true; // Opcional
    
    final rnosLimpio = rnos.replaceAll(RegExp(r'[\s\-]'), '');
    
    // 6 dígitos numéricos
    return RegExp(r'^\d{6}$').hasMatch(rnosLimpio);
  }
  
  /// Valida CUIL/CUIT (11 dígitos con dígito verificador)
  static bool validarCUIL(String cuil) {
    final cuilLimpio = cuil.replaceAll(RegExp(r'[\s\-]'), '');
    
    if (cuilLimpio.length != 11) return false;
    if (!RegExp(r'^\d+$').hasMatch(cuilLimpio)) return false;
    
    // Validar dígito verificador con algoritmo módulo 11
    final digitos = cuilLimpio.split('').map((d) => int.parse(d)).toList();
    final multiplicadores = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2];
    
    int suma = 0;
    for (int i = 0; i < 10; i++) {
      suma += digitos[i] * multiplicadores[i];
    }
    
    int verificador = 11 - (suma % 11);
    if (verificador == 11) verificador = 0;
    if (verificador == 10) verificador = 9; // Caso especial
    
    return verificador == digitos[10];
  }
  
  /// Formatea CUIL/CUIT con guiones
  static String formatearCUIL(String cuil) {
    final cuilLimpio = cuil.replaceAll(RegExp(r'[\s\-]'), '');
    
    if (cuilLimpio.length != 11) return cuil;
    
    // Formato: XX-XXXXXXXX-X
    return '${cuilLimpio.substring(0, 2)}-'
           '${cuilLimpio.substring(2, 10)}-'
           '${cuilLimpio.substring(10, 11)}';
  }
  
  /// Valida que un campo numérico no sea negativo
  static bool validarNoNegativo(double? valor) {
    if (valor == null) return true;
    return valor >= 0;
  }
  
  /// Valida que un porcentaje esté entre 0 y 100
  static bool validarPorcentaje(double? valor) {
    if (valor == null) return true;
    return valor >= 0 && valor <= 100;
  }
}
