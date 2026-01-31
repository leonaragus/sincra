// ========================================================================
// MODELO COMPLETO DE EMPLEADO
// Centraliza todos los datos del empleado para gestión unificada
// Compatible con Supabase y almacenamiento local
// ========================================================================

class EmpleadoCompleto {
  // Identificación
  String cuil;
  String nombreCompleto;
  String? apellido;
  String? nombre;
  
  // Datos personales
  DateTime? fechaNacimiento;
  String? domicilio;
  String? localidad;
  String? codigoPostal;
  String? telefono;
  String? email;
  
  // Datos laborales
  DateTime fechaIngreso;
  String categoria;
  String? categoriaDescripcion;
  int antiguedadAnios;
  int antiguedadMeses;
  String? sector; // sanidad, docente, cct_generico
  String? subsector; // fatsa, enfermeria, docente_primario, etc
  
  // Ubicación y jurisdicción
  String provincia;
  String? jurisdiccion; // provincial, municipal, nacional, privado
  
  // CCT aplicable
  String? cctCodigo; // "122/75", "130/75", etc
  String? cctNombre;
  
  // Datos bancarios
  String? cbu;
  String? banco;
  String? tipoCuenta; // CA, CC
  
  // Obra social y sindicato
  String? codigoRnos; // 6 dígitos
  String? obraSocialNombre;
  double? aporteSindical; // % o monto fijo
  
  // Modalidad de contratación (para F931)
  int modalidadContratacion; // 1=Permanente, 2=Temporario, 3=Eventual, etc
  
  // Estado del empleado
  String estado; // activo, suspendido, de_baja, licencia
  DateTime? fechaBaja;
  String? motivoBaja;
  
  // Vinculación empresa/institución
  String? empresaCuit; // CUIT de la empresa/institución
  String? empresaNombre;
  
  // Metadata
  String? notas;
  List<String>? tags; // ej: ["tiempo_completo", "zona_desfavorable"]
  
  // Auditoría
  DateTime? createdAt;
  DateTime? updatedAt;
  String? creadoPor;
  String? modificadoPor;
  
  EmpleadoCompleto({
    required this.cuil,
    required this.nombreCompleto,
    this.apellido,
    this.nombre,
    this.fechaNacimiento,
    this.domicilio,
    this.localidad,
    this.codigoPostal,
    this.telefono,
    this.email,
    required this.fechaIngreso,
    required this.categoria,
    this.categoriaDescripcion,
    this.antiguedadAnios = 0,
    this.antiguedadMeses = 0,
    this.sector,
    this.subsector,
    required this.provincia,
    this.jurisdiccion,
    this.cctCodigo,
    this.cctNombre,
    this.cbu,
    this.banco,
    this.tipoCuenta,
    this.codigoRnos,
    this.obraSocialNombre,
    this.aporteSindical,
    this.modalidadContratacion = 1, // Default: Permanente
    this.estado = 'activo',
    this.fechaBaja,
    this.motivoBaja,
    this.empresaCuit,
    this.empresaNombre,
    this.notas,
    this.tags,
    this.createdAt,
    this.updatedAt,
    this.creadoPor,
    this.modificadoPor,
  });
  
  /// Calcula antigüedad automáticamente desde fecha de ingreso
  void calcularAntiguedad() {
    final ahora = DateTime.now();
    final diff = ahora.difference(fechaIngreso);
    
    final anios = (diff.inDays / 365).floor();
    final meses = ((diff.inDays % 365) / 30).floor();
    
    antiguedadAnios = anios;
    antiguedadMeses = meses;
  }
  
  /// Convierte a Map para guardar en Supabase/local
  Map<String, dynamic> toMap() {
    return {
      'cuil': cuil,
      'nombre_completo': nombreCompleto,
      'apellido': apellido,
      'nombre': nombre,
      'fecha_nacimiento': fechaNacimiento?.toIso8601String(),
      'domicilio': domicilio,
      'localidad': localidad,
      'codigo_postal': codigoPostal,
      'telefono': telefono,
      'email': email,
      'fecha_ingreso': fechaIngreso.toIso8601String(),
      'categoria': categoria,
      'categoria_descripcion': categoriaDescripcion,
      'antiguedad_anios': antiguedadAnios,
      'antiguedad_meses': antiguedadMeses,
      'sector': sector,
      'subsector': subsector,
      'provincia': provincia,
      'jurisdiccion': jurisdiccion,
      'cct_codigo': cctCodigo,
      'cct_nombre': cctNombre,
      'cbu': cbu,
      'banco': banco,
      'tipo_cuenta': tipoCuenta,
      'codigo_rnos': codigoRnos,
      'obra_social_nombre': obraSocialNombre,
      'aporte_sindical': aporteSindical,
      'modalidad_contratacion': modalidadContratacion,
      'estado': estado,
      'fecha_baja': fechaBaja?.toIso8601String(),
      'motivo_baja': motivoBaja,
      'empresa_cuit': empresaCuit,
      'empresa_nombre': empresaNombre,
      'notas': notas,
      'tags': tags,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'creado_por': creadoPor,
      'modificado_por': modificadoPor,
    };
  }
  
  /// Crea desde Map (desde Supabase/local)
  factory EmpleadoCompleto.fromMap(Map<String, dynamic> map) {
    final emp = EmpleadoCompleto(
      cuil: map['cuil']?.toString() ?? '',
      nombreCompleto: map['nombre_completo']?.toString() ?? '',
      apellido: map['apellido']?.toString(),
      nombre: map['nombre']?.toString(),
      fechaNacimiento: map['fecha_nacimiento'] != null 
          ? DateTime.tryParse(map['fecha_nacimiento'].toString())
          : null,
      domicilio: map['domicilio']?.toString(),
      localidad: map['localidad']?.toString(),
      codigoPostal: map['codigo_postal']?.toString(),
      telefono: map['telefono']?.toString(),
      email: map['email']?.toString(),
      fechaIngreso: map['fecha_ingreso'] != null
          ? DateTime.parse(map['fecha_ingreso'].toString())
          : DateTime.now(),
      categoria: map['categoria']?.toString() ?? '',
      categoriaDescripcion: map['categoria_descripcion']?.toString(),
      antiguedadAnios: (map['antiguedad_anios'] as num?)?.toInt() ?? 0,
      antiguedadMeses: (map['antiguedad_meses'] as num?)?.toInt() ?? 0,
      sector: map['sector']?.toString(),
      subsector: map['subsector']?.toString(),
      provincia: map['provincia']?.toString() ?? 'Buenos Aires',
      jurisdiccion: map['jurisdiccion']?.toString(),
      cctCodigo: map['cct_codigo']?.toString(),
      cctNombre: map['cct_nombre']?.toString(),
      cbu: map['cbu']?.toString(),
      banco: map['banco']?.toString(),
      tipoCuenta: map['tipo_cuenta']?.toString(),
      codigoRnos: map['codigo_rnos']?.toString(),
      obraSocialNombre: map['obra_social_nombre']?.toString(),
      aporteSindical: (map['aporte_sindical'] as num?)?.toDouble(),
      modalidadContratacion: (map['modalidad_contratacion'] as num?)?.toInt() ?? 1,
      estado: map['estado']?.toString() ?? 'activo',
      fechaBaja: map['fecha_baja'] != null
          ? DateTime.tryParse(map['fecha_baja'].toString())
          : null,
      motivoBaja: map['motivo_baja']?.toString(),
      empresaCuit: map['empresa_cuit']?.toString(),
      empresaNombre: map['empresa_nombre']?.toString(),
      notas: map['notas']?.toString(),
      tags: (map['tags'] as List?)?.map((e) => e.toString()).toList(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
      creadoPor: map['creado_por']?.toString(),
      modificadoPor: map['modificado_por']?.toString(),
    );
    
    // Auto-calcular antigüedad si no viene en el map
    if (emp.antiguedadAnios == 0 && emp.antiguedadMeses == 0) {
      emp.calcularAntiguedad();
    }
    
    return emp;
  }
  
  /// Copia con modificaciones
  EmpleadoCompleto copyWith({
    String? cuil,
    String? nombreCompleto,
    String? apellido,
    String? nombre,
    DateTime? fechaNacimiento,
    String? domicilio,
    String? localidad,
    String? codigoPostal,
    String? telefono,
    String? email,
    DateTime? fechaIngreso,
    String? categoria,
    String? categoriaDescripcion,
    int? antiguedadAnios,
    int? antiguedadMeses,
    String? sector,
    String? subsector,
    String? provincia,
    String? jurisdiccion,
    String? cctCodigo,
    String? cctNombre,
    String? cbu,
    String? banco,
    String? tipoCuenta,
    String? codigoRnos,
    String? obraSocialNombre,
    double? aporteSindical,
    int? modalidadContratacion,
    String? estado,
    DateTime? fechaBaja,
    String? motivoBaja,
    String? empresaCuit,
    String? empresaNombre,
    String? notas,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? creadoPor,
    String? modificadoPor,
  }) {
    return EmpleadoCompleto(
      cuil: cuil ?? this.cuil,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      apellido: apellido ?? this.apellido,
      nombre: nombre ?? this.nombre,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      domicilio: domicilio ?? this.domicilio,
      localidad: localidad ?? this.localidad,
      codigoPostal: codigoPostal ?? this.codigoPostal,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      fechaIngreso: fechaIngreso ?? this.fechaIngreso,
      categoria: categoria ?? this.categoria,
      categoriaDescripcion: categoriaDescripcion ?? this.categoriaDescripcion,
      antiguedadAnios: antiguedadAnios ?? this.antiguedadAnios,
      antiguedadMeses: antiguedadMeses ?? this.antiguedadMeses,
      sector: sector ?? this.sector,
      subsector: subsector ?? this.subsector,
      provincia: provincia ?? this.provincia,
      jurisdiccion: jurisdiccion ?? this.jurisdiccion,
      cctCodigo: cctCodigo ?? this.cctCodigo,
      cctNombre: cctNombre ?? this.cctNombre,
      cbu: cbu ?? this.cbu,
      banco: banco ?? this.banco,
      tipoCuenta: tipoCuenta ?? this.tipoCuenta,
      codigoRnos: codigoRnos ?? this.codigoRnos,
      obraSocialNombre: obraSocialNombre ?? this.obraSocialNombre,
      aporteSindical: aporteSindical ?? this.aporteSindical,
      modalidadContratacion: modalidadContratacion ?? this.modalidadContratacion,
      estado: estado ?? this.estado,
      fechaBaja: fechaBaja ?? this.fechaBaja,
      motivoBaja: motivoBaja ?? this.motivoBaja,
      empresaCuit: empresaCuit ?? this.empresaCuit,
      empresaNombre: empresaNombre ?? this.empresaNombre,
      notas: notas ?? this.notas,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      creadoPor: creadoPor ?? this.creadoPor,
      modificadoPor: modificadoPor ?? this.modificadoPor,
    );
  }
  
  @override
  String toString() {
    return 'EmpleadoCompleto(cuil: $cuil, nombre: $nombreCompleto, categoria: $categoria, provincia: $provincia, estado: $estado)';
  }
}
