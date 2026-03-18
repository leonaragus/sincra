import 'package:flutter_test/flutter_test.dart';
import 'package:syncra_arg/services/sanidad_omni_engine.dart';
import 'package:syncra_arg/services/teacher_omni_engine.dart';
import 'package:syncra_arg/models/teacher_types.dart';
import 'package:syncra_arg/models/teacher_constants.dart';
import 'package:syncra_arg/models/sanidad_empleado_model.dart';
import 'package:intl/intl.dart';

void main() {
  group('Pruebas Complejas de Liquidación - Sanidad (CCT 122/75)', () {
    test('Liquidación Técnico Sanidad en Río Negro con Horas Extras y Tarea Crítica', () {
      final input = SanidadEmpleadoInput(
        nombre: "MARIA PATAGONIA",
        cuil: "27258889994",
        fechaIngreso: DateTime(2015, 2, 20),
        categoria: CategoriaSanidad.tecnico,
        nivelTitulo: NivelTituloSanidad.tecnico,
        tareaCriticaRiesgo: true,
        aplicarCuotaSindicalAtsa: true,
        manejoEfectivoCaja: false,
        horasNocturnas: 10,
        horasExtras50: 5.0,
        horasExtras100: 2.0,
        adelantos: 20000.0,
        embargos: 0.0,
        prestamos: 0.0,
        codigoRnos: "126205",
      );

      final result = SanidadOmniEngine.liquidar(
        input,
        periodo: "202603",
        fechaPago: "05/04/2026",
        jurisdiccion: "rioNegro",
        modo: ModoLiquidacionSanidad.mensual,
      );

      print('--- Auditoría Sanidad (Río Negro) ---');
      print('Sueldo Básico: ${result.sueldoBasico}');
      print('Antigüedad (11 años): ${result.adicionalAntiguedad}');
      print('Título Técnico: ${result.adicionalTitulo}');
      print('Tarea Crítica: ${result.adicionalTareaCriticaRiesgo}');
      print('Plus Zona Patagónica: ${result.adicionalZonaPatagonica}');
      print('Horas Extras 50%: ${result.horasExtras50Monto}');
      print('Horas Extras 100%: ${result.horasExtras100Monto}');
      print('Horas Nocturnas: ${result.nocturnidad}');
      print('Total Bruto: ${result.totalBrutoRemunerativo}');
      print('Total Descuentos: ${result.totalDescuentos}');
      print('Neto a Cobrar: ${result.netoACobrar}');

      // Verificaciones de lógica
      expect(result.sueldoBasico, greaterThan(0));
      expect(result.adicionalAntiguedad, greaterThan(0));
      expect(result.adicionalTareaCriticaRiesgo, greaterThan(0));
      expect(result.adicionalZonaPatagonica, greaterThan(0));
      expect(result.horasExtras50Monto, greaterThan(0));
      expect(result.horasExtras100Monto, greaterThan(0));
      expect(result.nocturnidad, greaterThan(0));
      
      // Verificación de montos específicos (ejemplos)
      expect(result.adicionalZonaPatagonica, equals(result.totalBrutoRemunerativo * 0.20));
      expect(result.adicionalTareaCriticaRiesgo, equals(result.sueldoBasico * 0.10));
      expect(result.netoACobrar, equals(result.totalBrutoRemunerativo + result.totalNoRemunerativo - result.totalDescuentos));
    });

    test('Liquidación Administrativo Sanidad con Fallo de Caja y Título Universitario', () {
      final input = SanidadEmpleadoInput(
        nombre: "CARLOS CAJERO",
        cuil: "20223334441",
        fechaIngreso: DateTime(2020, 1, 1),
        categoria: CategoriaSanidad.administrativo,
        nivelTitulo: NivelTituloSanidad.universitario,
        tareaCriticaRiesgo: false,
        aplicarCuotaSindicalAtsa: false,
        manejoEfectivoCaja: true,
        horasNocturnas: 0,
      );

      final result = SanidadOmniEngine.liquidar(
        input,
        periodo: "202603",
        fechaPago: "05/04/2026",
        jurisdiccion: "buenosAires",
        modo: ModoLiquidacionSanidad.mensual,
      );

      print('--- Auditoría Sanidad (CABA/PBA) ---');
      print('Fallo de Caja: ${result.falloCaja}');
      print('Título Universitario: ${result.adicionalTitulo}');
      
      expect(result.falloCaja, greaterThan(0));
      expect(result.falloCaja, equals(20000.0)); // Monto fijo 2026
      expect(result.adicionalTitulo, greaterThan(0));
    });
  });

  group('Pruebas Complejas de Liquidación - Docentes (Nomenclador Federal)', () {
    test('Liquidación Docente Primario en Neuquén (Caja ISSN) con 40% Zona Inhóspita', () {
      final input = DocenteOmniInput(
        nombre: "PROFESORA NEUQUEN",
        cuil: "27334445552",
        jurisdiccion: Jurisdiccion.neuquen,
        tipoGestion: TipoGestion.publica,
        cargoNomenclador: TipoNomenclador.maestroGrado,
        nivelEducativo: NivelEducativo.primario,
        fechaIngreso: DateTime(2010, 3, 15),
        zona: ZonaDesfavorable.c, // 40% aprox o según tabla
        nivelUbicacion: NivelUbicacion.inhospita,
        horasCatedra: 0,
      );

      final result = TeacherOmniEngine.liquidar(
        input,
        periodo: "202603",
        fechaPago: "01/04/2026",
      );

      print('--- Auditoría Docente (Neuquén) ---');
      print('Básico (Pts x VI): ${result.sueldoBasico}');
      print('Antigüedad (16 años): ${result.adicionalAntiguedad}');
      print('Plus Ubicación (Cascada F): ${result.plusUbicacion}');
      print('Estado Docente: ${result.estadoDocente}');
      print('Aporte Jubilatorio (ISSN 14.5%): ${result.aporteJubilacion}');
      print('Neto a Cobrar: ${result.netoACobrar}');

      // Verificaciones
      expect(result.config.cajaPrevisional, equals(TipoCajaPrevisional.issn));
      expect(result.plusUbicacion, greaterThan(0));
      expect(result.aporteJubilacion, closeTo(result.totalBrutoRemunerativo * 0.145, 1.0));
    });

    test('Liquidación Docente Terciario con Horas Cátedra y Override de Índice Paritario', () {
      final input = DocenteOmniInput(
        nombre: "PROFESOR TERCIARIO",
        cuil: "20112223334",
        jurisdiccion: Jurisdiccion.buenosAires,
        tipoGestion: TipoGestion.privada,
        cargoNomenclador: TipoNomenclador.profesor,
        nivelEducativo: NivelEducativo.terciario,
        fechaIngreso: DateTime(2022, 1, 1),
        horasCatedra: 15,
        esHoraCatedraSecundaria: false, // Terciaria 72 pts
        valorIndiceOverride: 350.50, // Paritaria específica
      );

      final result = TeacherOmniEngine.liquidar(
        input,
        periodo: "202603",
        fechaPago: "01/04/2026",
      );

      print('--- Auditoría Docente (Terciario Privado) ---');
      print('Horas Cátedra (15 x 72 pts x 350.50): ${result.horasCatedra}');
      print('FONID: ${result.fonid}');
      print('Conectividad: ${result.conectividad}');

      // 15 horas * 72 puntos * 350.50 valor índice = 378,540
      expect(result.horasCatedra, closeTo(15 * 72 * 350.50, 0.1));
    });
  });
}
