import 'package:flutter_test/flutter_test.dart';
import 'package:syncra_arg/services/teacher_omni_engine.dart';
import 'package:syncra_arg/models/teacher_types.dart';
import 'package:syncra_arg/models/teacher_constants.dart';

void main() {
  group('TeacherOmniEngine - Cálculo Docente', () {
    test('Cálculo Básico Maestro de Grado (Sin antigüedad)', () {
      final input = DocenteOmniInput(
        nombre: 'Test Teacher',
        cuil: '20123456789',
        jurisdiccion: Jurisdiccion.neuquen,
        tipoGestion: TipoGestion.privada,
        cargoNomenclador: TipoNomenclador.maestroGrado,
        nivelEducativo: NivelEducativo.primario,
        fechaIngreso: DateTime.now(), // Recién ingresado
        cargasFamiliares: 0,
        horasCatedra: 0,
        zona: ZonaDesfavorable.a,
        nivelUbicacion: NivelUbicacion.urbana,
      );

      final resultado = TeacherOmniEngine.liquidar(
        input,
        periodo: 'Enero 2026',
        fechaPago: '31/01/2026',
      );

      // Verificaciones básicas
      expect(resultado.sueldoBasico, greaterThan(0), reason: 'El básico no puede ser 0');
      expect(resultado.adicionalAntiguedad, equals(0), reason: 'No debería tener antigüedad');
      expect(resultado.netoACobrar, greaterThan(0), reason: 'El neto debe ser positivo');
      
      // Verificar descuentos de ley (11 + 3 + 3 = 17%)
      final brutoRemunerativo = resultado.totalBrutoRemunerativo;
      final descuentosEsperados = brutoRemunerativo * 0.17;
      
      // Permitimos un margen de error pequeño por redondeos
      expect(resultado.totalDescuentos, closeTo(descuentosEsperados, 1.0), 
        reason: 'Los descuentos deberían ser aprox el 17% del bruto remunerativo');
    });

    test('Cálculo Antigüedad (10 años = 60% aprox según escala)', () {
      final input = DocenteOmniInput(
        nombre: 'Senior Teacher',
        cuil: '20123456789',
        jurisdiccion: Jurisdiccion.neuquen,
        tipoGestion: TipoGestion.privada,
        cargoNomenclador: TipoNomenclador.maestroGrado,
        nivelEducativo: NivelEducativo.primario,
        fechaIngreso: DateTime.now().subtract(const Duration(days: 365 * 10)), // 10 años
        cargasFamiliares: 0,
        horasCatedra: 0,
        zona: ZonaDesfavorable.a,
        nivelUbicacion: NivelUbicacion.urbana,
      );

      final resultado = TeacherOmniEngine.liquidar(
        input,
        periodo: 'Enero 2026',
        fechaPago: '31/01/2026',
      );

      expect(resultado.adicionalAntiguedad, greaterThan(0), reason: 'Debe tener antigüedad');
      
      // La antigüedad se calcula sobre el básico (en general)
      // Nota: En Neuquén puede ser sobre básico + otros conceptos, aquí probamos que exista
      expect(resultado.adicionalAntiguedad, greaterThan(resultado.sueldoBasico * 0.30), 
        reason: 'Con 10 años la antigüedad debería ser sustancial');
    });
  });
}