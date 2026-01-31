// =============================================================================
// SEED DE PRUEBA DE ESTRÉS - SANIDAD FATSA CCT 122/75 y 108/75
// =============================================================================
// Ejecutar: await SanidadStressSeed.cargarDatosDePrueba();
// =============================================================================

import '../services/instituciones_service.dart';

class SanidadStressSeed {
  /// Carga datos de prueba de estrés para Sanidad
  /// Crea 1 institución y 5 empleados con casos extremos
  static Future<Map<String, dynamic>> cargarDatosDePrueba() async {
    final resultados = <String, dynamic>{
      'institucion': null,
      'empleados': <String>[],
      'errores': <String>[],
    };

    try {
      // =====================================================================
      // INSTITUCIÓN: Hospital en Neuquén (zona patagónica)
      // =====================================================================
      final institucion = {
        'cuit': '30-71234567-8',
        'razonSocial': 'STRESS TEST - Hospital Patagónico UTI',
        'domicilio': 'Av. Argentina 4500, Neuquén Capital, CP 8300',
        'jurisdiccion': 'neuquen',
        'tipoGestion': 'privada',
        'zonaDefault': 'c',
        'nivelUbicacionDefault': 'inhospita',
        'regimenPrevisional': 'nacional',
        'artPct': 4.5,
        'artCuotaFija': 1500.0,
        'seguroVidaObligatorio': 450.0,
        'zonaPatagonica': true,
        'logoPath': 'No disponible',
        'firmaPath': 'No disponible',
        'listaConceptosPropios': [
          {
            'nombre': 'Plus UTI/Terapia Intensiva',
            'tipo': 'sumaFija',
            'naturaleza': 'remunerativo',
            'codigoAfipArca': '011000',
            'valor': 95000.0,
          },
          {
            'nombre': 'Guardia Activa 24hs',
            'tipo': 'porcentaje',
            'naturaleza': 'remunerativo',
            'codigoAfipArca': '011000',
            'valor': 30.0,
          },
          {
            'nombre': 'Viático Zona Extrema',
            'tipo': 'sumaFija',
            'naturaleza': 'noRemunerativo',
            'codigoAfipArca': '101000',
            'valor': 45000.0,
          },
        ],
      };

      await InstitucionesService.saveInstitucion(institucion);
      resultados['institucion'] = institucion['razonSocial'];

      final cuitLimpio = '30712345678';

      // =====================================================================
      // EMPLEADO 1: Médico UTI - MÁXIMA COMPLEJIDAD
      // 25 años antigüedad, título universitario, tarea crítica, nocturno, etc.
      // =====================================================================
      await InstitucionesService.saveLegajoSanidad(cuitLimpio, {
        'cuil': '20-28456789-3',
        'nombre': 'Dr. MÁXIMO ADICIONALES (UTI)',
        'puesto': 'Médico Intensivista - Jefe UTI', // Puesto específico
        'categoria': 'profesional',
        'nivelTitulo': 'universitario', // +10%
        'fechaIngreso': '2001-02-15', // 25 años = máx antigüedad
        'tareaCriticaRiesgo': true, // +15%
        'cuotaSindicalAtsa': true,
        'manejoEfectivoCaja': true, // +8% fallo caja
        'horasNocturnas': 96, // 96 hs nocturnas
        'codigoRnos': '400307',
        'cantidadFamiliares': 4,
        'horasExtras50': 24,
        'horasExtras100': 16,
        'adelantos': 75000.0,
        'embargos': 0.0,
        'prestamos': 50000.0,
      });
      resultados['empleados'].add('Dr. MÁXIMO ADICIONALES (UTI)');

      // =====================================================================
      // EMPLEADO 2: Enfermera - LIQUIDACIÓN FINAL DESPIDO SIN CAUSA
      // 12 años, con preaviso e integración
      // =====================================================================
      await InstitucionesService.saveLegajoSanidad(cuitLimpio, {
        'cuil': '27-32987654-1',
        'nombre': 'Lic. LIQUIDACIÓN FINAL (Despido)',
        'categoria': 'tecnico',
        'nivelTitulo': 'tecnico', // +7%
        'fechaIngreso': '2014-03-01', // 12 años
        'tareaCriticaRiesgo': true,
        'cuotaSindicalAtsa': true,
        'manejoEfectivoCaja': false,
        'horasNocturnas': 48,
        'codigoRnos': '400307',
        'cantidadFamiliares': 2,
        'fechaEgreso': '2026-01-31',
        'motivoEgreso': 'despido_sin_causa',
        'incluyePreaviso': true,
        'incluyeIntegracionMes': true,
        'diasVacacionesPendientes': 28, // 2 períodos
        'mejorRemuneracion': 1850000.0,
      });
      resultados['empleados'].add('Lic. LIQUIDACIÓN FINAL (Despido)');

      // =====================================================================
      // EMPLEADO 3: Camillero - SAC PROPORCIONAL (ingreso reciente)
      // Solo 4 meses trabajados
      // =====================================================================
      await InstitucionesService.saveLegajoSanidad(cuitLimpio, {
        'cuil': '20-40123456-7',
        'nombre': 'SAC PROPORCIONAL (4 meses)',
        'puesto': 'Camillero - Emergencias', // Puesto específico
        'categoria': 'servicios',
        'nivelTitulo': 'auxiliar', // +5%
        'fechaIngreso': '2025-09-15', // Solo 4 meses
        'tareaCriticaRiesgo': false,
        'cuotaSindicalAtsa': true,
        'manejoEfectivoCaja': false,
        'horasNocturnas': 0,
        'codigoRnos': '400307',
        'cantidadFamiliares': 6, // Muchas cargas
        'horasExtras50': 40,
        'horasExtras100': 8,
      });
      resultados['empleados'].add('SAC PROPORCIONAL (4 meses)');

      // =====================================================================
      // EMPLEADO 4: Administrativo - EMBARGOS AL LÍMITE LEGAL
      // Múltiples embargos que deben respetar el 20% máximo
      // =====================================================================
      await InstitucionesService.saveLegajoSanidad(cuitLimpio, {
        'cuil': '23-35678901-9',
        'nombre': 'EMBARGOS MÚLTIPLES (20% límite)',
        'categoria': 'administrativo',
        'nivelTitulo': 'sinTitulo',
        'fechaIngreso': '2019-07-01',
        'tareaCriticaRiesgo': false,
        'cuotaSindicalAtsa': false,
        'manejoEfectivoCaja': true, // +8%
        'horasNocturnas': 32,
        'codigoRnos': '400307',
        'cantidadFamiliares': 0,
        'embargos': 250000.0, // Excede 20% - debe topearse
        'adelantos': 120000.0,
        'prestamos': 80000.0,
      });
      resultados['empleados'].add('EMBARGOS MÚLTIPLES (20% límite)');

      // =====================================================================
      // EMPLEADO 5: Mucama - SOLO NOCTURNO + JORNADA PARCIAL
      // Caso especial de trabajo 100% nocturno
      // =====================================================================
      await InstitucionesService.saveLegajoSanidad(cuitLimpio, {
        'cuil': '27-45678901-2',
        'nombre': 'NOCTURNO TOTAL (24hs x 30 días)',
        'puesto': 'Mucama - Limpieza Nocturna', // Puesto específico
        'categoria': 'maestranza',
        'nivelTitulo': 'sinTitulo',
        'fechaIngreso': '2023-01-15',
        'tareaCriticaRiesgo': false,
        'cuotaSindicalAtsa': true,
        'manejoEfectivoCaja': false,
        'horasNocturnas': 160, // 160 hs nocturnas (máximo)
        'codigoRnos': '400307',
        'cantidadFamiliares': 3,
        'jornadaParcial': false,
      });
      resultados['empleados'].add('NOCTURNO TOTAL (24hs x 30 días)');

    } catch (e) {
      resultados['errores'].add(e.toString());
    }

    return resultados;
  }

  /// Limpia los datos de prueba de estrés
  static Future<void> limpiarDatosDePrueba() async {
    const cuitLimpio = '30712345678';
    
    // Eliminar legajos
    final cuils = [
      '20-28456789-3',
      '27-32987654-1',
      '20-40123456-7',
      '23-35678901-9',
      '27-45678901-2',
    ];
    
    for (final cuil in cuils) {
      final cuilLimpio = cuil.replaceAll(RegExp(r'[^\d]'), '');
      await InstitucionesService.removeLegajoSanidad(cuitLimpio, cuilLimpio);
    }
    
    // Eliminar institución
    await InstitucionesService.removeInstitucion(cuitLimpio);
  }

  /// ==========================================================================
  /// PRUEBA DE ESTRÉS ESPECÍFICA: EMPLEADO MADERERA - 2 AÑOS ANTIGÜEDAD
  /// ==========================================================================
  static Future<Map<String, dynamic>> cargarDatosMadereraStressTest() async {
    final resultados = <String, dynamic>{
      'institucion': null,
      'empleados': <String>[],
      'errores': <String>[],
    };

    try {
      // =====================================================================
      // INSTITUCIÓN: Maderera Patagónica (zona fría con convenio maderero)
      // =====================================================================
      final institucion = {
        'cuit': '30-76543210-9',
        'razonSocial': 'STRESS TEST - Maderera Patagónica S.A.',
        'domicilio': 'Ruta 259 Km 45, El Bolsón, Río Negro, CP 8430',
        'jurisdiccion': 'rio_negro',
        'tipoGestion': 'privada',
        'zonaDefault': 'c', // Zona fría
        'nivelUbicacionDefault': 'rural',
        'regimenPrevisional': 'nacional',
        'artPct': 6.0, // Mayor riesgo por actividad maderera
        'artCuotaFija': 2500.0,
        'seguroVidaObligatorio': 600.0,
        'zonaPatagonica': true,
        'logoPath': 'No disponible',
        'firmaPath': 'No disponible',
        'listaConceptosPropios': [
          {
            'nombre': 'Plus Riesgo Maderero',
            'tipo': 'porcentaje',
            'naturaleza': 'remunerativo',
            'codigoAfipArca': '012500',
            'valor': 12.0, // 12% adicional por riesgo
          },
          {
            'nombre': 'Viático Zona Rural',
            'tipo': 'sumaFija',
            'naturaleza': 'noRemunerativo',
            'codigoAfipArca': '101500',
            'valor': 35000.0,
          },
          {
            'nombre': 'Adicional Frío Extremo',
            'tipo': 'porcentaje',
            'naturaleza': 'remunerativo',
            'codigoAfipArca': '012600',
            'valor': 8.0, // 8% por frío
          },
        ],
      };

      await InstitucionesService.saveInstitucion(institucion);
      resultados['institucion'] = institucion['razonSocial'];

      final cuitLimpio = '30765432109';

      // =====================================================================
      // EMPLEADO MADERERA: Operario con 2 años antigüedad - CASO COMPLETO
      // =====================================================================
      await InstitucionesService.saveLegajoSanidad(cuitLimpio, {
        'cuil': '20-50123456-8',
        'nombre': 'OPERARIO MADERERA - 2 AÑOS',
        'puesto': 'Operario de Sierra Principal',
        'categoria': 'operario',
        'nivelTitulo': 'sinTitulo',
        'fechaIngreso': '2024-01-15', // Exactamente 2 años
        'tareaCriticaRiesgo': true, // +15% por riesgo
        'cuotaSindicalMadereros': true,
        'manejoMaquinariaPesada': true, // +8%
        'horasNocturnas': 64, // Trabajo por turnos
        'codigoActividad': '102500', // Código maderero
        'cantidadFamiliares': 3, // Esposa + 2 hijos
        'horasExtras50': 36,
        'horasExtras100': 12,
        'diasEnfermedad': 8, // 8 días de enfermedad
        'diasVacacionesGozadas': 14, // 14 días de vacaciones tomadas
        'adelantos': 45000.0,
        'embargos': 28000.0, // Embargo por deuda
        'prestamos': 35000.0,
        'sueldoBasico': 580000.0, // Sueldo base convenio maderero
        'plusPresentismo': true, // Cobra presentismo
        'plusAntiguedad': true, // Cobra antigüedad (2% por año)
        'zonaRural': true, // Trabaja en zona rural
        'horasTrabajadasMes': 180, // Jornada completa + extras
      });
      resultados['empleados'].add('OPERARIO MADERERA - 2 AÑOS');

      resultados['exito'] = true;
      resultados['mensaje'] = 'Prueba de estrés maderera cargada exitosamente';
    } catch (e) {
      resultados['exito'] = false;
      resultados['errores'].add('Error al cargar datos maderera: e');
    }

    return resultados;
  }
}
