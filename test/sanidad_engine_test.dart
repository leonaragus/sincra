import 'package:flutter_test/flutter_test.dart';
import 'package:syncra_arg/services/sanidad_omni_engine.dart';
import 'package:syncra_arg/models/empresa.dart';

void main() {
  group('SanidadOmniEngine - Cálculo Sanidad', () {
    test('Cálculo Básico Enfermero (CCT 122/75)', () {
      final input = SanidadEmpleadoInput(
        nombre: 'Nurse Test',
        cuil: '20987654321',
        categoria: CategoriaSanidad.tecnico, // Enfermero Profesional
        nivelTitulo: NivelTituloSanidad.tecnico,
        fechaIngreso: DateTime.now(),
        cantidadFamiliares: 0,
        cbu: '',
      );

      final resultado = SanidadOmniEngine.liquidar(
        input,
        periodo: 'Enero 2026',
        fechaPago: '31/01/2026',
        jurisdiccion: 'Buenos Aires',
        esZonaPatagonica: false,
      );

      expect(resultado.sueldoBasico, greaterThan(0));
      expect(resultado.adicionalTitulo, greaterThan(0), reason: 'Debe pagar título técnico');
      expect(resultado.netoACobrar, greaterThan(0));
    });

    test('Adicional Zona Patagónica', () {
      final input = SanidadEmpleadoInput(
        nombre: 'Patagonian Nurse',
        cuil: '20987654321',
        categoria: CategoriaSanidad.tecnico,
        nivelTitulo: NivelTituloSanidad.tecnico,
        fechaIngreso: DateTime.now(),
        cantidadFamiliares: 0,
        cbu: '',
      );

      final resultado = SanidadOmniEngine.liquidar(
        input,
        periodo: 'Enero 2026',
        fechaPago: '31/01/2026',
        jurisdiccion: 'Neuquén',
        esZonaPatagonica: true, // Activamos zona
      );

      expect(resultado.adicionalZonaPatagonica, greaterThan(0), 
        reason: 'Debe calcular zona patagónica');
    });
  });
}