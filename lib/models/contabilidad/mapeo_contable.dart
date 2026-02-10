
import 'cuenta_contable.dart';

enum TipoConceptoContable {
  conceptoEspecifico, // Mapeo por código de concepto (ej: SUELDO_BASICO)
  agrupacion,         // Mapeo por grupo (ej: TOTAL_REMUNERATIVO)
  impuesto,           // Mapeo de contribuciones (ej: JUBILACION_PATRONAL)
  neto,               // Neto a pagar
}

class MapeoContable {
  final String id; // UUID
  final String nombre;
  final TipoConceptoContable tipo;
  final String? claveReferencia; // Código del concepto o agrupador
  final String cuentaCodigo; // Código de la cuenta contable
  final ImputacionDefecto imputacion; // Debe o Haber forzado (opcional)

  const MapeoContable({
    required this.id,
    required this.nombre,
    required this.tipo,
    this.claveReferencia,
    required this.cuentaCodigo,
    required this.imputacion,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'tipo': tipo.name,
      'claveReferencia': claveReferencia,
      'cuentaCodigo': cuentaCodigo,
      'imputacion': imputacion.name,
    };
  }

  factory MapeoContable.fromMap(Map<String, dynamic> map) {
    return MapeoContable(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      tipo: TipoConceptoContable.values.firstWhere(
        (e) => e.name == map['tipo'],
        orElse: () => TipoConceptoContable.conceptoEspecifico,
      ),
      claveReferencia: map['claveReferencia'],
      cuentaCodigo: map['cuentaCodigo'] ?? '',
      imputacion: ImputacionDefecto.values.firstWhere(
        (e) => e.name == map['imputacion'],
        orElse: () => ImputacionDefecto.debe,
      ),
    );
  }
}

class PerfilContable {
  final String id;
  final String nombre;
  final List<CuentaContable> planDeCuentas;
  final List<MapeoContable> mapeos;

  const PerfilContable({
    required this.id,
    required this.nombre,
    required this.planDeCuentas,
    required this.mapeos,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'planDeCuentas': planDeCuentas.map((x) => x.toMap()).toList(),
      'mapeos': mapeos.map((x) => x.toMap()).toList(),
    };
  }

  factory PerfilContable.fromMap(Map<String, dynamic> map) {
    return PerfilContable(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      planDeCuentas: List<CuentaContable>.from(
        (map['planDeCuentas'] as List? ?? []).map<CuentaContable>(
          (x) => CuentaContable.fromMap(x as Map<String, dynamic>),
        ),
      ),
      mapeos: List<MapeoContable>.from(
        (map['mapeos'] as List? ?? []).map<MapeoContable>(
          (x) => MapeoContable.fromMap(x as Map<String, dynamic>),
        ),
      ),
    );
  }
}
