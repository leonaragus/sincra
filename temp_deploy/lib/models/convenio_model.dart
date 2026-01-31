/// Modelo profesional para convenios sincronizables desde la nube.
/// Usado por ApiService y almacenamiento local.
class ConvenioModel {
  final String id;
  final String nombreCCT;
  final String categoria;
  final double sueldoBasico;
  final Map<String, double> adicionales;
  final DateTime ultimaActualizacion;

  const ConvenioModel({
    required this.id,
    required this.nombreCCT,
    required this.categoria,
    required this.sueldoBasico,
    required this.adicionales,
    required this.ultimaActualizacion,
  });

  factory ConvenioModel.fromJson(Map<String, dynamic> json) {
    final adicionalesRaw = json['adicionales'] as Map<String, dynamic>? ?? {};
    final adicionales = <String, double>{};
    for (final e in adicionalesRaw.entries) {
      final v = e.value;
      if (v is num) {
        adicionales[e.key] = v.toDouble();
      }
    }
    return ConvenioModel(
      id: json['id'] as String? ?? '',
      nombreCCT: json['nombreCCT'] as String? ?? '',
      categoria: json['categoria'] as String? ?? '',
      sueldoBasico: (json['sueldoBasico'] as num?)?.toDouble() ?? 0.0,
      adicionales: adicionales,
      ultimaActualizacion: json['ultimaActualizacion'] != null
          ? DateTime.tryParse(json['ultimaActualizacion'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombreCCT': nombreCCT,
      'categoria': categoria,
      'sueldoBasico': sueldoBasico,
      'adicionales': adicionales,
      'ultimaActualizacion': ultimaActualizacion.toIso8601String(),
    };
  }

  ConvenioModel copyWith({
    String? id,
    String? nombreCCT,
    String? categoria,
    double? sueldoBasico,
    Map<String, double>? adicionales,
    DateTime? ultimaActualizacion,
  }) {
    return ConvenioModel(
      id: id ?? this.id,
      nombreCCT: nombreCCT ?? this.nombreCCT,
      categoria: categoria ?? this.categoria,
      sueldoBasico: sueldoBasico ?? this.sueldoBasico,
      adicionales: adicionales ?? Map<String, double>.from(this.adicionales),
      ultimaActualizacion: ultimaActualizacion ?? this.ultimaActualizacion,
    );
  }
}
