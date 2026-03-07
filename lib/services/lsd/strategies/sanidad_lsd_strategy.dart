
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';

import '../../../services/lsd_engine.dart';
import '../../../services/sanidad_omni_engine.dart';
import '../../../utils/file_saver.dart';
import '../lsd_export_strategy.dart';
import '../../lsd_mapping_service.dart';

/// Implementación de la estrategia de exportación de LSD para el convenio de Sanidad.
///
/// Esta clase encapsula la lógica que estaba originalmente en `sanidad_lsd_export.dart`,
/// adaptándola al nuevo contrato `LsdExportStrategy` sin alterar el comportamiento
/// de la generación de archivos.
class SanidadLsdExportStrategy implements LsdExportStrategy<LiquidacionSanidadResult> {
  @override
  Future<String> generarLsdTxt({
    required List<LiquidacionSanidadResult> liquidaciones,
    required Map<String, String> empresaData,
  }) async {
    final sb = StringBuffer();
    for (final liquidacion in liquidaciones) {
      final contenido = await _sanidadLiquidacionToLsdTxt(
        liquidacion: liquidacion,
        cuitEmpresa: empresaData['cuit']!,
        razonSocial: empresaData['razonSocial']!,
        domicilio: empresaData['domicilio']!,
      );
      sb.write(contenido);
    }
    return sb.toString();
  }

  @override
  Future<String> generarPackARCA({
    required List<LiquidacionSanidadResult> liquidaciones,
    required Map<String, String> empresaData,
    required Future<Uint8List> Function(LiquidacionSanidadResult) generadorReciboPDF,
  }) async {
      final archive = Archive();
      final fechaHoy = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final periodo = liquidaciones.isNotEmpty ? liquidaciones.first.periodo : 'SinPeriodo';
      final periodoLimpio = periodo.replaceAll(RegExp(r'[^\w]'), '_');

      // 1. Generar LSD unificado
      final lsdContenido = await generarLsdTxt(
        liquidaciones: liquidaciones,
        empresaData: empresaData,
      );
      final lsdBytes = latin1.encode(lsdContenido);
      archive.addFile(ArchiveFile(
        'LSD_Sanidad_$periodoLimpio.txt',
        lsdBytes.length,
        lsdBytes,
      ));

      // 2. Generar recibos individuales
      for (final liq in liquidaciones) {
        try {
          final pdfBytes = await generadorReciboPDF(liq);
          final cuilLimpio = liq.input.cuil.replaceAll(RegExp(r'[^\d]'), '');
          final nombreLimpio = liq.input.nombre.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
          archive.addFile(ArchiveFile(
            'Recibos/Recibo_${nombreLimpio}_$cuilLimpio.pdf',
            pdfBytes.length,
            pdfBytes,
          ));
        } catch (e) {
          print('Error generando recibo para ${liq.input.nombre}: $e');
        }
      }
      
      // 3. Generar instructivo de mapeo AFIP
      // (La lógica para obtener los códigos usados se mantiene igual)
      final instructivo = _generarInstructivo(liquidaciones);
      final instructivoBytes = utf8.encode(instructivo);
      archive.addFile(ArchiveFile(
        'INSTRUCTIVO_IMPORTANTE_AFIP.txt',
        instructivoBytes.length,
        instructivoBytes,
      ));

      // 4. Generar resumen TXT
      final resumen = _generarResumenLiquidaciones(liquidaciones, empresaData['razonSocial']!, periodo);
      final resumenBytes = utf8.encode(resumen);
      archive.addFile(ArchiveFile(
        'Resumen_Liquidaciones.txt',
        resumenBytes.length,
        resumenBytes,
      ));

      // 5. Comprimir y guardar
      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);
      if (zipBytes == null) {
        throw Exception('Error al comprimir el pack ARCA');
      }
      final fileName = 'Pack_ARCA_Sanidad_${periodoLimpio}_$fechaHoy.zip';
      final path = await saveFile(
        fileName: fileName,
        bytes: zipBytes,
        mimeType: 'application/zip',
      );
      return path ?? fileName;
  }

  // --- MÉTODOS PRIVADOS (LÓGICA ORIGINAL DE SANIDAD_LSD_EXPORT.DART) ---

  String _sanitizarTextoARCA(String texto) {
    return LSDFormatEngine.limpiarTexto(texto);
  }

  Future<String> _sanidadLiquidacionToLsdTxt({
    required LiquidacionSanidadResult liquidacion,
    required String cuitEmpresa,
    required String razonSocial,
    required String domicilio,
  }) async {
    final sb = StringBuffer();
    final cuil = liquidacion.input.cuil.replaceAll(RegExp(r'[^\d]'), '');
    if (cuil.length != 11) throw ArgumentError('CUIL inválido');

    final razonSocialLimpia = _sanitizarTextoARCA(razonSocial);
    final domicilioLimpio = _sanitizarTextoARCA(domicilio);
    final tipoLiq = liquidacion.modo == ModoLiquidacionSanidad.sac ? 'S' : null;

    final reg1 = LSDGenerator.generateRegistro1(
      cuitEmpresa: cuitEmpresa,
      periodo: liquidacion.periodo,
      fechaPago: liquidacion.fechaPago,
      razonSocial: razonSocialLimpia,
      domicilio: domicilioLimpio,
      tipoLiquidacion: tipoLiq,
    );
    sb.write(latin1.decode(reg1));
    sb.write(LSDGenerator.eolLsd);

    final nombreLimpio = liquidacion.input.nombre.replaceAll(RegExp(r'\s'), '');
    final reg2 = LSDGenerator.generateRegistro2DatosReferenciales(
      cuilEmpleado: cuil,
      legajo: nombreLimpio.substring(0, min(10, nombreLimpio.length)),
      diasBase: 30,
    );
    sb.write(latin1.decode(reg2));
    sb.write(LSDGenerator.eolLsd);

    final conceptos = _mapearConceptos(liquidacion);

    for (final c in conceptos) {
        final codigoLimpio = _sanitizarTextoARCA((c['codigo'] as String).trim().toUpperCase());
        final descripcionLimpia = _sanitizarTextoARCA(c['desc'] as String? ?? '');
        final tipoLsd = (c['tipo'] as String?) == 'N' ? 'H' : c['tipo'] as String?;

        final r3 = LSDGenerator.generateRegistro3Conceptos(
            cuilEmpleado: cuil,
            codigoConcepto: codigoLimpio,
            importe: c['importe'] as double,
            descripcionConcepto: descripcionLimpia,
            tipo: tipoLsd,
        );
        sb.write(latin1.decode(r3));
        sb.write(LSDGenerator.eolLsd);
    }

    final bases = List<double>.filled(10, 0.0);
    final baseCalculada = liquidacion.baseImponibleTopeada;
    for (int i = 0; i < 9; i++) {
        bases[i] = baseCalculada;
    }
    final r4Bases = LSDGenerator.generateRegistro4Bases(
        cuilEmpleado: cuil,
        bases: bases,
    );
    sb.write(latin1.decode(r4Bases));
    sb.write(LSDGenerator.eolLsd);

    final r5 = LSDGenerator.generateRegistro5DatosComplementarios(
        cuilEmpleado: cuil,
        codigoRnos: liquidacion.input.codigoRnos ?? '126205',
        cantidadFamiliares: liquidacion.input.cantidadFamiliares,
        codigoModalidad: liquidacion.codigoModalidadLSD ?? '008',
        codigoCondicion: liquidacion.input.codigoCondicion ?? '01',
        codigoActividad: liquidacion.input.codigoActividad ?? '049',
        codigoPuesto: liquidacion.input.codigoPuesto,
        codigoZona: liquidacion.adicionalZonaPatagonica > 0 ? '1' : '0',
    );
    sb.write(latin1.decode(r5));
    sb.write(LSDGenerator.eolLsd);

    final out = sb.toString();
    LSDFormatEngine.validarLongitud195(out);
    return out;
  }

  List<Map<String, dynamic>> _mapearConceptos(LiquidacionSanidadResult liquidacion) {
      final conceptos = <Map<String, dynamic>>[];
      void addHaber(String codigo, String desc, double monto) {
          if (monto > 0) conceptos.add({'codigo': codigo, 'desc': desc, 'importe': monto, 'tipo': 'H'});
      }
      void addDescuento(String codigo, String desc, double monto) {
          if (monto > 0) conceptos.add({'codigo': codigo, 'desc': desc, 'importe': monto, 'tipo': 'D'});
      }
      void addNoRemunerativo(String codigo, String desc, double monto) {
          if (monto > 0) conceptos.add({'codigo': codigo, 'desc': desc, 'importe': monto, 'tipo': 'N'});
      }

      addHaber(SanidadLsdCodigos.sueldoBasico, 'Sueldo Basico', liquidacion.sueldoBasico);
      addHaber(SanidadLsdCodigos.antiguedad, 'Antiguedad', liquidacion.adicionalAntiguedad);
      addHaber(SanidadLsdCodigos.titulo, 'Adicional Titulo', liquidacion.adicionalTitulo);
      addHaber(SanidadLsdCodigos.tareaCritica, 'Tarea Critica/Riesgo', liquidacion.adicionalTareaCriticaRiesgo);
      addHaber(SanidadLsdCodigos.zonaPatagonica, 'Plus Zona Desfavorable (Patagonia)', liquidacion.adicionalZonaPatagonica);
      addHaber(SanidadLsdCodigos.nocturnidad, 'Horas Nocturnas', liquidacion.nocturnidad);
      addHaber(SanidadLsdCodigos.falloCaja, 'Fallo de Caja', liquidacion.falloCaja);
      addHaber(SanidadLsdCodigos.horasExtras50, 'Horas Extras 50%', liquidacion.horasExtras50Monto);
      addHaber(SanidadLsdCodigos.horasExtras100, 'Horas Extras 100%', liquidacion.horasExtras100Monto);

      if (liquidacion.sac > 0) {
          final codigoSac = liquidacion.diasSACCalculados >= 180 ? SanidadLsdCodigos.sac : SanidadLsdCodigos.sacProp;
          final descSac = liquidacion.diasSACCalculados >= 180 ? 'SAC - Aguinaldo' : 'SAC Proporcional (${liquidacion.diasSACCalculados} dias)';
          addHaber(codigoSac, descSac, liquidacion.sac);
      }

      addHaber(SanidadLsdCodigos.vacaciones, 'Vacaciones (${liquidacion.diasVacacionesCalculados} dias)', liquidacion.vacaciones);
      addHaber(SanidadLsdCodigos.plusVacacional, 'Plus Vacacional', liquidacion.plusVacacional);
      addHaber(SanidadLsdCodigos.vacNoGozadas, 'Vacaciones No Gozadas', liquidacion.vacacionesNoGozadas);
      if (liquidacion.sacSobreVacaciones > 0) addHaber('SAC_S_VAC', 'SAC sobre Vacaciones', liquidacion.sacSobreVacaciones);
      if (liquidacion.sacSobrePreaviso > 0) addHaber('SAC_S_PRE', 'SAC sobre Preaviso', liquidacion.sacSobrePreaviso);

      for (final c in liquidacion.conceptosPropios) {
          if (c['esDescuento'] != true) {
              final codigo = _sanitizarTextoARCA((c['codigo']?.toString() ?? 'CONC_PROP').toUpperCase());
              final desc = _sanitizarTextoARCA(c['descripcion']?.toString() ?? 'Concepto Propio');
              final monto = (c['monto'] as num?)?.toDouble() ?? 0;
              addHaber(codigo.length > 10 ? codigo.substring(0, 10) : codigo, desc, monto);
          }
      }

      addNoRemunerativo(SanidadLsdCodigos.indemnizacion, 'Indemnizacion Art. 245 LCT', liquidacion.indemnizacionArt245);
      addNoRemunerativo(SanidadLsdCodigos.preaviso, 'Preaviso', liquidacion.preaviso);
      addNoRemunerativo(SanidadLsdCodigos.integracionMes, 'Integracion Mes Despido', liquidacion.integracionMes);

      addDescuento(SanidadLsdCodigos.jubilacion, 'Jubilacion', liquidacion.aporteJubilacion);
      addDescuento(SanidadLsdCodigos.ley19032, 'Ley 19.032 (PAMI)', liquidacion.aporteLey19032);
      addDescuento(SanidadLsdCodigos.obraSocial, 'Obra Social', liquidacion.aporteObraSocial);
      addDescuento(SanidadLsdCodigos.cuotaSindical, 'Cuota Sindical ATSA', liquidacion.cuotaSindicalAtsa);
      addDescuento(SanidadLsdCodigos.seguroSepelio, 'Seguro de Sepelio', liquidacion.seguroSepelio);
      addDescuento(SanidadLsdCodigos.aporteSolidario, 'Aporte Solidario FATSA', liquidacion.aporteSolidarioFatsa);

      addDescuento(SanidadLsdCodigos.adelantos, 'Adelantos', liquidacion.adelantos);
      addDescuento(SanidadLsdCodigos.embargos, 'Embargos', liquidacion.embargos);
      addDescuento(SanidadLsdCodigos.prestamos, 'Prestamos', liquidacion.prestamos);
      if (liquidacion.otrosDescuentos > 0) addDescuento('OTROS_DESC', 'Otros Descuentos', liquidacion.otrosDescuentos);

      for (final c in liquidacion.conceptosPropios) {
          if (c['esDescuento'] == true) {
              final codigo = _sanitizarTextoARCA((c['codigo']?.toString() ?? 'DESC_PROP').toUpperCase());
              final desc = _sanitizarTextoARCA(c['descripcion']?.toString() ?? 'Descuento');
              final monto = (c['monto'] as num?)?.toDouble() ?? 0;
              addDescuento(codigo.length > 10 ? codigo.substring(0, 10) : codigo, desc, monto);
          }
      }

      return conceptos;
  }

  String _generarInstructivo(List<LiquidacionSanidadResult> liquidaciones) {
      final codigosUsados = <String>{};
      for (final liq in liquidaciones) {
          final conceptos = _mapearConceptos(liq);
          for (final c in conceptos) {
              final cod = (c['codigo'] as String).trim().toUpperCase();
              if (cod.isNotEmpty) {
                codigosUsados.add(cod.length > 10 ? cod.substring(0, 10) : cod);
              }
          }
      }
      return LsdMappingService.generarInstructivo(codigosUsados.toList());
  }

  String _generarResumenLiquidaciones(
    List<LiquidacionSanidadResult> liquidaciones,
    String razonSocial,
    String periodo,
  ) {
      final sb = StringBuffer();
      final fechaGen = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      sb.writeln('=' * 70);
      sb.writeln('RESUMEN DE LIQUIDACIONES - SANIDAD FATSA');
      sb.writeln('=' * 70);
      sb.writeln('Empresa: $razonSocial');
      sb.writeln('Periodo: $periodo');
      sb.writeln('Generado: $fechaGen');
      sb.writeln('Cantidad de empleados: ${liquidaciones.length}');
      sb.writeln('=' * 70);
      sb.writeln('');
      double totalBrutos = 0, totalNetos = 0, totalDescuentos = 0;
      for (final liq in liquidaciones) {
          totalBrutos += liq.totalBrutoRemunerativo;
          totalNetos += liq.netoACobrar;
          totalDescuentos += liq.totalDescuentos;
          sb.writeln('-' * 50);
          sb.writeln('Empleado: ${liq.input.nombre}');
          sb.writeln('CUIL: ${liq.input.cuil}');
          sb.writeln('Categoria: ${liq.input.categoria.name}');
          sb.writeln('Modo: ${liq.modo.name}');
          sb.writeln('Bruto: \$${liq.totalBrutoRemunerativo.toStringAsFixed(2)}');
          sb.writeln('Descuentos: \$${liq.totalDescuentos.toStringAsFixed(2)}');
          sb.writeln('Neto: \$${liq.netoACobrar.toStringAsFixed(2)}');
          sb.writeln('');
      }
      sb.writeln('=' * 70);
      sb.writeln('TOTALES');
      sb.writeln('=' * 70);
      sb.writeln('Total Brutos: \$${totalBrutos.toStringAsFixed(2)}');
      sb.writeln('Total Descuentos: \$${totalDescuentos.toStringAsFixed(2)}');
      sb.writeln('Total Netos: \$${totalNetos.toStringAsFixed(2)}');
      sb.writeln('=' * 70);
      return sb.toString();
    }
}
