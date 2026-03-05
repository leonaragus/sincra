
import 'dart:typed_data';

import '../models/empresa.dart';
import '../models/empleado.dart';
import '../services/sanidad_omni_engine.dart'; // Import para LiquidacionSanidadResult
import '../utils/file_saver.dart';
import '../utils/image_bytes_reader.dart';
import '../utils/pdf_recibo.dart';

/// PdfService - Servicio Inteligente de Generación de Recibos PDF
///
/// Este servicio actúa como un orquestador que genera recibos de sueldo en PDF.
/// Su principal característica es la capacidad de manejar diferentes tipos de
/// resultados de liquidación (de Sanidad, Comercio, etc.) y mapear cada uno
/// de forma precisa a la estructura visual del recibo.
class PdfService {

  /// Genera y guarda un recibo de sueldo en PDF para cualquier tipo de liquidación.
  ///
  /// Este método es el punto de entrada principal. Detecta el tipo de `liquidacion`
  /// y delega el mapeo de conceptos a un método especializado para ese convenio.
  ///
  /// Devuelve la ruta (path) donde se guardó el archivo.
  Future<String?> generarReciboPdf({
    required dynamic liquidacion,
    required Map<String, String> empresaData, // Usamos Map para desacoplar
    required Map<String, dynamic> empleadoData, // Usamos Map para desacoplar
    String? logoPath,
    String? firmaPath,
  }) async {
    
    List<ConceptoParaPDF> conceptosPDF;
    double sueldoBruto, totalDeducciones, totalNoRemunerativo, sueldoNeto, baseImponible;
    int? horas50, horas100;

    // --- LÓGICA DE SELECCIÓN DE ESTRATEGIA DE MAPEO ---
    if (liquidacion is LiquidacionSanidadResult) {
      conceptosPDF = _mapearConceptosSanidadParaPDF(liquidacion);
      
      // Extraer totales directamente del resultado de Sanidad
      sueldoBruto = liquidacion.totalBrutoRemunerativo;
      totalDeducciones = liquidacion.totalDescuentos;
      totalNoRemunerativo = liquidacion.totalNoRemunerativo;
      sueldoNeto = liquidacion.netoACobrar;
      baseImponible = liquidacion.baseImponibleTopeada;
      horas50 = liquidacion.input.horasExtras50;
      horas100 = liquidacion.input.horasExtras100;

    } else {
      // TODO: Añadir bloques `else if (liquidacion is LiquidacionComercioResult)`
      throw UnimplementedError('El tipo de liquidación no está soportado para generar PDF.');
    }

    // Cargar assets (logo y firma) de forma segura
    final logoBytes = await readImageBytes(logoPath);
    final firmaBytes = await readImageBytes(firmaPath);

    // Simular objetos Empresa y Empleado para el generador de PDF
    final empresa = Empresa(cuit: empresaData['cuit']!, razonSocial: empresaData['razonSocial']!, domicilio: empresaData['domicilio']!);
    final empleado = Empleado.fromMap(empleadoData);

    // Generar el archivo PDF en memoria
    final pdfBytes = await PdfRecibo.generarCompleto(
      empresa: empresa,
      empleado: empleado,
      conceptos: conceptosPDF,
      sueldoBruto: sueldoBruto,
      totalDeducciones: totalDeducciones,
      totalNoRemunerativo: totalNoRemunerativo,
      sueldoNeto: sueldoNeto,
      baseImponibleTopeada: baseImponible,
      sueldoBasico: (liquidacion is LiquidacionSanidadResult) ? liquidacion.sueldoBasico : 0,
      cantidadHorasExtras50: horas50,
      cantidadHorasExtras100: horas100,
      logoBytes: logoBytes,
      firmaBytes: firmaBytes,
      bancoAcreditacion: 'Banco Nación Argentina', // TODO: Hacer configurable
      fechaUltimoDepositoAportes: '31/12/2025', // TODO: Hacer configurable
      incluirBloqueFirmaLey25506: true,
    );

    // Guardar el PDF en el dispositivo/disco
    final cuilLimpio = empleado.cuil.replaceAll(RegExp(r'[^\d]'), '');
    final nombreArchivo = 'recibo_${cuilLimpio}_${DateTime.now().millisecondsSinceEpoch}.pdf';

    final pdfFilePath = await saveFile(
      fileName: nombreArchivo,
      bytes: pdfBytes,
      mimeType: 'application/pdf',
    );

    return pdfFilePath ?? nombreArchivo;
  }

  /// Método especializado para mapear un `LiquidacionSanidadResult` a la estructura del PDF.
  ///
  /// Aquí reside la magia. Cada concepto se crea y se asigna a la columna correcta.
  List<ConceptoParaPDF> _mapearConceptosSanidadParaPDF(LiquidacionSanidadResult liq) {
    final List<ConceptoParaPDF> conceptos = [];

    // --- HABERES REMUNERATIVOS ---
    if (liq.sueldoBasico > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Sueldo Básico', remunerativo: liq.sueldoBasico, noRemunerativo: 0, descuento: 0));
    if (liq.adicionalAntiguedad > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Adicional Antigüedad', remunerativo: liq.adicionalAntiguedad, noRemunerativo: 0, descuento: 0));
    if (liq.adicionalTitulo > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Adicional Título', remunerativo: liq.adicionalTitulo, noRemunerativo: 0, descuento: 0));
    if (liq.adicionalTareaCriticaRiesgo > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Tarea Crítica/Riesgo', remunerativo: liq.adicionalTareaCriticaRiesgo, noRemunerativo: 0, descuento: 0));
    if (liq.adicionalZonaPatagonica > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Plus Zona Patagónica', remunerativo: liq.adicionalZonaPatagonica, noRemunerativo: 0, descuento: 0));
    if (liq.nocturnidad > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Horas Nocturnas', remunerativo: liq.nocturnidad, noRemunerativo: 0, descuento: 0));
    if (liq.falloCaja > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Fallo de Caja', remunerativo: liq.falloCaja, noRemunerativo: 0, descuento: 0));
    if (liq.horasExtras50Monto > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Horas Extras 50% (${liq.input.horasExtras50}hs)', remunerativo: liq.horasExtras50Monto, noRemunerativo: 0, descuento: 0));
    if (liq.horasExtras100Monto > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Horas Extras 100% (${liq.input.horasExtras100}hs)', remunerativo: liq.horasExtras100Monto, noRemunerativo: 0, descuento: 0));
    if (liq.sac > 0) conceptos.add(ConceptoParaPDF(descripcion: 'S.A.C. (${liq.diasSACCalculados} días)', remunerativo: liq.sac, noRemunerativo: 0, descuento: 0));
    if (liq.vacaciones > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Vacaciones (${liq.diasVacacionesCalculados} días)', remunerativo: liq.vacaciones, noRemunerativo: 0, descuento: 0));
    if (liq.plusVacacional > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Plus Vacacional', remunerativo: liq.plusVacacional, noRemunerativo: 0, descuento: 0));
    if (liq.sacSobreVacaciones > 0) conceptos.add(ConceptoParaPDF(descripcion: 'SAC s/ Vacaciones', remunerativo: liq.sacSobreVacaciones, noRemunerativo: 0, descuento: 0));
    if (liq.sacSobrePreaviso > 0) conceptos.add(ConceptoParaPDF(descripcion: 'SAC s/ Preaviso', remunerativo: liq.sacSobrePreaviso, noRemunerativo: 0, descuento: 0));
    
    // --- HABERES NO REMUNERATIVOS ---
    if (liq.indemnizacionArt245 > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Indemnización Antigüedad Art. 245', remunerativo: 0, noRemunerativo: liq.indemnizacionArt245, descuento: 0));
    if (liq.preaviso > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Preaviso', remunerativo: 0, noRemunerativo: liq.preaviso, descuento: 0));
    if (liq.integracionMes > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Integración Mes de Despido', remunerativo: 0, noRemunerativo: liq.integracionMes, descuento: 0));
    if (liq.vacacionesNoGozadas > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Vacaciones No Gozadas', remunerativo: 0, noRemunerativo: liq.vacacionesNoGozadas, descuento: 0));

    // --- DEDUCCIONES ---
    if (liq.aporteJubilacion > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Aporte Jubilatorio (11%)', remunerativo: 0, noRemunerativo: 0, descuento: liq.aporteJubilacion));
    if (liq.aporteLey19032 > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Ley 19.032 (PAMI) (3%)', remunerativo: 0, noRemunerativo: 0, descuento: liq.aporteLey19032));
    if (liq.aporteObraSocial > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Aporte Obra Social (3%)', remunerativo: 0, noRemunerativo: 0, descuento: liq.aporteObraSocial));
    if (liq.cuotaSindicalAtsa > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Cuota Sindical ATSA (2.5%)', remunerativo: 0, noRemunerativo: 0, descuento: liq.cuotaSindicalAtsa));
    if (liq.seguroSepelio > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Seguro de Sepelio', remunerativo: 0, noRemunerativo: 0, descuento: liq.seguroSepelio));
    if (liq.aporteSolidarioFatsa > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Aporte Solidario FATSA (1%)', remunerativo: 0, noRemunerativo: 0, descuento: liq.aporteSolidarioFatsa));
    if (liq.adelantos > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Adelantos', remunerativo: 0, noRemunerativo: 0, descuento: liq.adelantos));
    if (liq.embargos > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Embargos Judiciales', remunerativo: 0, noRemunerativo: 0, descuento: liq.embargos));
    if (liq.prestamos > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Préstamos', remunerativo: 0, noRemunerativo: 0, descuento: liq.prestamos));
    if (liq.otrosDescuentos > 0) conceptos.add(ConceptoParaPDF(descripcion: 'Otros Descuentos', remunerativo: 0, noRemunerativo: 0, descuento: liq.otrosDescuentos));

    return conceptos;
  }
}
