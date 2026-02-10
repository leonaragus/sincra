
import '../models/contabilidad/asiento_item.dart';
import '../models/contabilidad/mapeo_contable.dart';
import '../models/contabilidad/cuenta_contable.dart';
import '../services/teacher_omni_engine.dart'; // For LiquidacionOmniResult
import '../services/sanidad_omni_engine.dart'; // For LiquidacionSanidadResult

class ContabilidadService {
  
  /// Genera un asiento contable resumen para un lote de liquidaciones docentes.
  /// Agrupa los montos por cuenta contable.
  static AsientoResult generarAsientoDocente({
    required List<LiquidacionOmniResult> liquidaciones,
    required PerfilContable perfil,
  }) {
    final Map<String, AsientoItem> itemsMap = {};

    // Helper to add/update item
    void agregarMovimiento(String cuentaCodigo, double monto, ImputacionDefecto tipo) {
      if (monto == 0) return;
      
      // Buscar nombre de cuenta
      final cuenta = perfil.planDeCuentas.firstWhere(
        (c) => c.codigo == cuentaCodigo, 
        orElse: () => CuentaContable(codigo: cuentaCodigo, nombre: 'Cuenta Desconocida', imputacionDefecto: tipo)
      );

      if (!itemsMap.containsKey(cuentaCodigo)) {
        itemsMap[cuentaCodigo] = AsientoItem(
          cuentaCodigo: cuentaCodigo,
          cuentaNombre: cuenta.nombre,
          debe: 0,
          haber: 0,
        );
      }

      final item = itemsMap[cuentaCodigo]!;
      // Crear nuevo item con valores actualizados (inmutabilidad parcial)
      itemsMap[cuentaCodigo] = AsientoItem(
        cuentaCodigo: item.cuentaCodigo,
        cuentaNombre: item.cuentaNombre,
        debe: item.debe + (tipo == ImputacionDefecto.debe ? monto : 0),
        haber: item.haber + (tipo == ImputacionDefecto.haber ? monto : 0),
      );
    }

    for (final liq in liquidaciones) {
      for (final mapeo in perfil.mapeos) {
        double monto = 0.0;

        switch (mapeo.tipo) {
          case TipoConceptoContable.neto:
            monto = liq.netoACobrar;
            break;
            
          case TipoConceptoContable.agrupacion:
            if (mapeo.claveReferencia == 'TOTAL_REMUNERATIVO') {
              monto = liq.totalBrutoRemunerativo;
            } else if (mapeo.claveReferencia == 'TOTAL_NO_REMUNERATIVO') {
              monto = liq.totalNoRemunerativo;
            } else if (mapeo.claveReferencia == 'TOTAL_DESCUENTOS') {
              monto = liq.totalDescuentos;
            } else if (mapeo.claveReferencia == 'CONTRIB_PATRONALES') {
              // Estimación básica o cálculo real si existiera en el modelo
              // Por ahora 0 o lógica futura
              monto = 0.0; 
            }
            break;

          case TipoConceptoContable.conceptoEspecifico:
            // Buscar en conceptos desglosados
            // Primero campos fijos comunes
            if (mapeo.claveReferencia == 'SUELDO_BASICO') monto = liq.sueldoBasico;
            else if (mapeo.claveReferencia == 'ANTIGUEDAD') monto = liq.adicionalAntiguedad;
            else if (mapeo.claveReferencia == 'ZONA') monto = liq.adicionalZona;
            else if (mapeo.claveReferencia == 'JUBILACION') monto = liq.aporteJubilacion;
            else if (mapeo.claveReferencia == 'OBRA_SOCIAL') monto = liq.aporteObraSocial;
            else if (mapeo.claveReferencia == 'LEY_19032') monto = liq.aportePami;
            else {
              // Buscar en lista de conceptos propios o adicionales
              // Nota: LiquidacionOmniResult no tiene un mapa plano fácil de todos los conceptos
              // tendríamos que iterar desgloseBaseBonificable o reconstruir
              // Por simplicidad MVP, asumimos los principales arriba.
            }
            break;
            
          case TipoConceptoContable.impuesto:
            // Lógica de contribuciones
            break;
        }

        if (monto > 0) {
          agregarMovimiento(mapeo.cuentaCodigo, monto, mapeo.imputacion);
        }
      }
    }

    return AsientoResult(items: itemsMap.values.toList());
  }

  /// Genera un asiento contable resumen para un lote de liquidaciones SANIDAD.
  /// Agrupa los montos por cuenta contable.
  static AsientoResult generarAsientoSanidad({
    required List<LiquidacionSanidadResult> liquidaciones,
    required PerfilContable perfil,
  }) {
    final Map<String, AsientoItem> itemsMap = {};

    // Helper to add/update item
    void agregarMovimiento(String cuentaCodigo, double monto, ImputacionDefecto tipo) {
      if (monto == 0) return;
      
      // Buscar nombre de cuenta
      final cuenta = perfil.planDeCuentas.firstWhere(
        (c) => c.codigo == cuentaCodigo, 
        orElse: () => CuentaContable(codigo: cuentaCodigo, nombre: 'Cuenta Desconocida', imputacionDefecto: tipo)
      );

      if (!itemsMap.containsKey(cuentaCodigo)) {
        itemsMap[cuentaCodigo] = AsientoItem(
          cuentaCodigo: cuentaCodigo,
          cuentaNombre: cuenta.nombre,
          debe: 0,
          haber: 0,
        );
      }

      final item = itemsMap[cuentaCodigo]!;
      // Crear nuevo item con valores actualizados (inmutabilidad parcial)
      itemsMap[cuentaCodigo] = AsientoItem(
        cuentaCodigo: item.cuentaCodigo,
        cuentaNombre: item.cuentaNombre,
        debe: item.debe + (tipo == ImputacionDefecto.debe ? monto : 0),
        haber: item.haber + (tipo == ImputacionDefecto.haber ? monto : 0),
      );
    }

    for (final liq in liquidaciones) {
      for (final mapeo in perfil.mapeos) {
        double monto = 0.0;

        switch (mapeo.tipo) {
          case TipoConceptoContable.neto:
            monto = liq.netoACobrar;
            break;
            
          case TipoConceptoContable.agrupacion:
            if (mapeo.claveReferencia == 'TOTAL_REMUNERATIVO') {
              monto = liq.totalBrutoRemunerativo;
            } else if (mapeo.claveReferencia == 'TOTAL_NO_REMUNERATIVO') {
              monto = liq.totalNoRemunerativo;
            } else if (mapeo.claveReferencia == 'TOTAL_DESCUENTOS') {
              monto = liq.totalDescuentos;
            } else if (mapeo.claveReferencia == 'CONTRIB_PATRONALES') {
              monto = 0.0; 
            }
            break;

          case TipoConceptoContable.conceptoEspecifico:
            if (mapeo.claveReferencia == 'SUELDO_BASICO') monto = liq.sueldoBasico;
            else if (mapeo.claveReferencia == 'ANTIGUEDAD') monto = liq.adicionalAntiguedad;
            else if (mapeo.claveReferencia == 'ZONA') monto = liq.adicionalZonaPatagonica;
            else if (mapeo.claveReferencia == 'JUBILACION') monto = liq.aporteJubilacion;
            else if (mapeo.claveReferencia == 'OBRA_SOCIAL') monto = liq.aporteObraSocial;
            else if (mapeo.claveReferencia == 'LEY_19032') monto = liq.aporteLey19032;
            else if (mapeo.claveReferencia == 'TITULO') monto = liq.adicionalTitulo;
            else if (mapeo.claveReferencia == 'PRESENTISMO') monto = liq.falloCaja; // Fallo caja como presentismo
            else if (mapeo.claveReferencia == 'SAC') monto = liq.sac;
            else if (mapeo.claveReferencia == 'VACACIONES') monto = liq.vacaciones + liq.plusVacacional;
            else if (mapeo.claveReferencia == 'NOCTURNIDAD') monto = liq.nocturnidad;
            else if (mapeo.claveReferencia == 'TAREA_CRITICA') monto = liq.adicionalTareaCriticaRiesgo;
            else if (mapeo.claveReferencia == 'HORAS_EXTRAS') monto = liq.horasExtras50Monto + liq.horasExtras100Monto;
            break;
            
          case TipoConceptoContable.impuesto:
            break;
        }

        if (monto > 0) {
          agregarMovimiento(mapeo.cuentaCodigo, monto, mapeo.imputacion);
        }
      }
    }

    return AsientoResult(items: itemsMap.values.toList());
  }

  /// Genera archivo CSV formato Holistor
  /// Formato estimado: FECHA;CUENTA;DEBE;HABER;LEYENDA
  static String exportarHolistor(AsientoResult asiento, DateTime fecha) {
    final sb = StringBuffer();
    // Header si es necesario (Holistor suele usar formatos fijos o configurables)
    // sb.writeln('FECHA;CUENTA;DEBE;HABER;LEYENDA'); 
    
    final fechaStr = "${fecha.day.toString().padLeft(2,'0')}/${fecha.month.toString().padLeft(2,'0')}/${fecha.year}";
    
    for (final item in asiento.items) {
      if (item.debe > 0) {
        sb.writeln('$fechaStr;${item.cuentaCodigo};${item.debe.toStringAsFixed(2)};0.00;${item.cuentaNombre}');
      }
      if (item.haber > 0) {
        sb.writeln('$fechaStr;${item.cuentaCodigo};0.00;${item.haber.toStringAsFixed(2)};${item.cuentaNombre}');
      }
    }
    return sb.toString();
  }

  /// Genera archivo formato Tango (Sueldos -> Contabilidad)
  /// Tango suele usar tablas intermedias o archivos ASCII de ancho fijo.
  /// Implementación genérica CSV por ahora.
  static String exportarGenerico(AsientoResult asiento) {
    final sb = StringBuffer();
    sb.writeln('CUENTA,NOMBRE,DEBE,HABER');
    for (final item in asiento.items) {
      sb.writeln('${item.cuentaCodigo},${item.cuentaNombre},${item.debe.toStringAsFixed(2)},${item.haber.toStringAsFixed(2)}');
    }
    return sb.toString();
  }
}
