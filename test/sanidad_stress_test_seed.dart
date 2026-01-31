// =============================================================================
// PRUEBA DE ESTRÉS - SANIDAD FATSA CCT 122/75 y 108/75
// =============================================================================
// Este script crea datos de prueba complejos para verificar:
// - Generación de recibos PDF
// - Exportación LSD ARCA 2026
// - Cálculos con múltiples adicionales y deducciones
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/services/hybrid_store.dart';
import '../lib/services/instituciones_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sanidad Stress Test - Seed Data', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('Crear institución y empleados de prueba de estrés', () async {
      // =====================================================================
      // INSTITUCIÓN DE PRUEBA - Hospital complejo en zona patagónica
      // =====================================================================
      final institucion = {
        'cuit': '30-71234567-8',
        'razonSocial': 'Hospital Regional Patagónico Dr. Stress Test',
        'domicilio': 'Av. San Martín 4500, Neuquén Capital',
        'jurisdiccion': 'neuquen', // Zona patagónica
        'tipoGestion': 'privada',
        'zonaDefault': 'c', // Zona C - 40% adicional
        'nivelUbicacionDefault': 'inhospita', // 40% adicional
        'regimenPrevisional': 'nacional',
        'artPct': 4.2, // ART más alta
        'artCuotaFija': 1200.0,
        'seguroVidaObligatorio': 350.0,
        'zonaPatagonica': true,
        'logoPath': 'No disponible',
        'firmaPath': 'No disponible',
        'listaConceptosPropios': [
          {
            'nombre': 'Plus Terapia Intensiva',
            'tipo': 'sumaFija',
            'naturaleza': 'remunerativo',
            'codigoAfipArca': '011000',
            'valor': 85000.0,
          },
          {
            'nombre': 'Adicional Guardia Activa 24hs',
            'tipo': 'porcentaje',
            'naturaleza': 'remunerativo',
            'codigoAfipArca': '011000',
            'valor': 25.0, // 25% del básico
          },
        ],
      };

      await InstitucionesService.saveInstitucion(institucion);
      print('✓ Institución creada: ${institucion['razonSocial']}');

      // =====================================================================
      // EMPLEADO 1: Profesional con TODOS los adicionales posibles
      // =====================================================================
      final empleado1 = {
        'cuil': '20-28456789-3',
        'nombre': 'Dr. Máximo Estrés González',
        'categoria': 'profesional', // Categoría más alta
        'nivelTitulo': 'universitario', // 10% adicional
        'fechaIngreso': '2000-03-15', // 25+ años de antigüedad
        'tareaCriticaRiesgo': true, // 15% adicional
        'cuotaSindicalAtsa': true, // Descuento sindical
        'manejoEfectivoCaja': true, // 8% fallo de caja
        'horasNocturnas': 80, // 80 horas nocturnas (50% extra)
        'codigoRnos': '400307', // OSECAC
        'cantidadFamiliares': 3, // Cargas de familia
        // Horas extras
        'horasExtras50': 20,
        'horasExtras100': 12,
        // Descuentos adicionales
        'adelantos': 50000.0,
        'embargos': 25000.0,
        'prestamos': 30000.0,
      };

      await InstitucionesService.saveLegajoSanidad(
        '30712345678', // CUIT limpio
        empleado1,
      );
      print('✓ Empleado 1 creado: ${empleado1['nombre']}');

      // =====================================================================
      // EMPLEADO 2: Técnico con situación de liquidación final
      // =====================================================================
      final empleado2 = {
        'cuil': '27-32987654-1',
        'nombre': 'María Despido Forzoso',
        'categoria': 'tecnico',
        'nivelTitulo': 'tecnico', // 7% adicional
        'fechaIngreso': '2015-06-01', // ~10 años antigüedad
        'tareaCriticaRiesgo': true,
        'cuotaSindicalAtsa': true,
        'manejoEfectivoCaja': false,
        'horasNocturnas': 40,
        'codigoRnos': '400307',
        'cantidadFamiliares': 2,
        // Para liquidación final
        'fechaEgreso': '2026-01-31',
        'motivoEgreso': 'despido_sin_causa',
        'incluyePreaviso': true,
        'incluyeIntegracionMes': true,
        'diasVacacionesPendientes': 21,
      };

      await InstitucionesService.saveLegajoSanidad(
        '30712345678',
        empleado2,
      );
      print('✓ Empleado 2 creado: ${empleado2['nombre']}');

      // =====================================================================
      // EMPLEADO 3: Servicios con SAC proporcional
      // =====================================================================
      final empleado3 = {
        'cuil': '20-40123456-7',
        'nombre': 'Juan SAC Proporcional',
        'categoria': 'servicios',
        'nivelTitulo': 'auxiliar', // 5% adicional
        'fechaIngreso': '2025-09-15', // Ingreso reciente - SAC proporcional
        'tareaCriticaRiesgo': false,
        'cuotaSindicalAtsa': true,
        'manejoEfectivoCaja': false,
        'horasNocturnas': 0,
        'codigoRnos': '400307',
        'cantidadFamiliares': 5, // Muchas cargas
        'horasExtras50': 30,
        'horasExtras100': 0,
      };

      await InstitucionesService.saveLegajoSanidad(
        '30712345678',
        empleado3,
      );
      print('✓ Empleado 3 creado: ${empleado3['nombre']}');

      // =====================================================================
      // EMPLEADO 4: Administrativo con embargos múltiples
      // =====================================================================
      final empleado4 = {
        'cuil': '23-35678901-9',
        'nombre': 'Roberto Embargo Total',
        'categoria': 'administrativo',
        'nivelTitulo': 'sinTitulo',
        'fechaIngreso': '2018-02-01',
        'tareaCriticaRiesgo': false,
        'cuotaSindicalAtsa': false,
        'manejoEfectivoCaja': true, // Fallo de caja
        'horasNocturnas': 20,
        'codigoRnos': '400307',
        'cantidadFamiliares': 0,
        // Múltiples embargos (límite legal 20% del neto)
        'embargos': 150000.0,
        'adelantos': 80000.0,
        'prestamos': 60000.0,
      };

      await InstitucionesService.saveLegajoSanidad(
        '30712345678',
        empleado4,
      );
      print('✓ Empleado 4 creado: ${empleado4['nombre']}');

      // =====================================================================
      // EMPLEADO 5: Maestranza con jornada parcial
      // =====================================================================
      final empleado5 = {
        'cuil': '27-45678901-2',
        'nombre': 'Ana Jornada Parcial',
        'categoria': 'maestranza',
        'nivelTitulo': 'sinTitulo',
        'fechaIngreso': '2022-11-01',
        'tareaCriticaRiesgo': false,
        'cuotaSindicalAtsa': true,
        'manejoEfectivoCaja': false,
        'horasNocturnas': 60, // Muchas nocturnas
        'codigoRnos': '400307',
        'cantidadFamiliares': 4,
        'jornadaParcial': true,
        'horasSemanales': 24, // Jornada reducida
      };

      await InstitucionesService.saveLegajoSanidad(
        '30712345678',
        empleado5,
      );
      print('✓ Empleado 5 creado: ${empleado5['nombre']}');

      // =====================================================================
      // VERIFICACIÓN
      // =====================================================================
      final instituciones = await InstitucionesService.getInstituciones();
      final legajos = await InstitucionesService.getLegajosSanidad('30712345678');
      
      print('\n========================================');
      print('RESUMEN DATOS DE ESTRÉS CREADOS');
      print('========================================');
      print('Instituciones totales: ${instituciones.length}');
      print('Legajos sanidad: ${legajos.length}');
      print('----------------------------------------');
      print('CUIT Institución: 30-71234567-8');
      print('Razón Social: Hospital Regional Patagónico Dr. Stress Test');
      print('----------------------------------------');
      print('EMPLEADOS:');
      for (final l in legajos) {
        print('  - ${l['nombre']} (${l['cuil']}) - ${l['categoria']}');
      }
      print('========================================');
      print('\nPara probar en la web:');
      print('1. Ir a la sección SANIDAD');
      print('2. Seleccionar "Hospital Regional Patagónico Dr. Stress Test"');
      print('3. Seleccionar cada empleado y calcular liquidación');
      print('4. Descargar PDF y LSD para verificar');
      print('========================================');

      expect(instituciones.isNotEmpty, true);
      expect(legajos.length, 5);
    });
  });
}
