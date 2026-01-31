import 'package:flutter/material.dart';
import '../models/concepto.dart';
import '../models/empresa.dart';
import '../models/empleado.dart';

class ReciboWidget extends StatelessWidget {
  final Empresa empresa;
  final Empleado empleado;
  final List<Concepto> conceptos;

  const ReciboWidget({
    super.key,
    required this.empresa,
    required this.empleado,
    required this.conceptos,
  });

  @override
  Widget build(BuildContext context) {
    double bruto = empleado.sueldoBasico;

    double totalRem = 0;
    double totalNoRem = 0;
    double totalDesc = 0;

    for (final c in conceptos) {
      final importe = c.calcular(bruto);
      if (c.tipo == TipoConcepto.remunerativo) totalRem += importe;
      if (c.tipo == TipoConcepto.noRemunerativo) totalNoRem += importe;
      if (c.tipo == TipoConcepto.descuento) totalDesc += importe;
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(empresa.razonSocial, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('CUIT: ${empresa.cuit}'),
            const Divider(),

            Text('Empleado: ${empleado.nombre}'),
            Text('Categoría: ${empleado.categoria}'),
            Text('Periodo: ${empleado.periodo}'),
            const Divider(),

            _tabla(bruto),

            const Divider(),
            Text('Total remunerativo: \$${totalRem.toStringAsFixed(2)}'),
            Text('Total no remunerativo: \$${totalNoRem.toStringAsFixed(2)}'),
            Text('Descuentos: \$${totalDesc.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text(
              'NETO A COBRAR: \$${(totalRem + totalNoRem - totalDesc).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabla(double bruto) {
    return Table(
      border: TableBorder.all(),
      children: [
        const TableRow(children: [
          Padding(padding: EdgeInsets.all(4), child: Text('Concepto')),
          Padding(padding: EdgeInsets.all(4), child: Text('Rem.')),
          Padding(padding: EdgeInsets.all(4), child: Text('No Rem.')),
          Padding(padding: EdgeInsets.all(4), child: Text('Desc.')),
        ]),
        ...conceptos.map((c) {
          final imp = c.calcular(bruto).toStringAsFixed(2);
          return TableRow(children: [
            Padding(padding: const EdgeInsets.all(4), child: Text(c.descripcion)),
            Padding(padding: const EdgeInsets.all(4), child: Text(c.tipo == TipoConcepto.remunerativo ? imp : '')),
            Padding(padding: const EdgeInsets.all(4), child: Text(c.tipo == TipoConcepto.noRemunerativo ? imp : '')),
            Padding(padding: const EdgeInsets.all(4), child: Text(c.tipo == TipoConcepto.descuento ? imp : '')),
          ]);
        }),
      ],
    );
  }
}
