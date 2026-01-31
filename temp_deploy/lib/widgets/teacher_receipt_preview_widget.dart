import 'package:flutter/material.dart';
import '../services/teacher_omni_engine.dart';
import '../utils/formatters.dart';

class TeacherReceiptPreviewWidget extends StatelessWidget {
  final Map<String, String> empresa;
  final LiquidacionOmniResult liquidacion;

  const TeacherReceiptPreviewWidget({
    super.key,
    required this.empresa,
    required this.liquidacion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      empresa['razonSocial'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text('CUIT: ${empresa['cuit'] ?? ''}', style: const TextStyle(fontSize: 10, color: Colors.black87)),
                    Text(empresa['domicilio'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.black87)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                ),
                child: const Column(
                  children: [
                    Text('RECIBO DE SUELDO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                    Text('LEY 20.744 - ORIGINAL', style: TextStyle(fontSize: 7, color: Colors.black)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          
          // Employee Info
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow('Apellido y Nombre:', liquidacion.input.nombre),
                      _infoRow('CUIL:', liquidacion.input.cuil),
                      _infoRow('Fecha Ingreso:', _formatDate(liquidacion.input.fechaIngreso)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow('Período:', liquidacion.periodo),
                      _infoRow('Fecha Pago:', liquidacion.fechaPago),
                      _infoRow('Lugar Pago:', empresa['domicilio'] ?? ''),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),

          // Table Header
          Container(
            color: Colors.grey.shade200,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: const Row(
              children: [
                Expanded(flex: 4, child: Text(' Concepto', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black))),
                Expanded(flex: 2, child: Text('Remun.', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black))),
                Expanded(flex: 2, child: Text('No Rem.', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black))),
                Expanded(flex: 2, child: Text('Desc. ', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black))),
              ],
            ),
          ),

          // Table Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _conceptRow('Sueldo Básico', liquidacion.sueldoBasico, 0, 0),
                  if (liquidacion.adicionalAntiguedad > 0) _conceptRow('Antigüedad', liquidacion.adicionalAntiguedad, 0, 0),
                  if (liquidacion.adicionalZona > 0) _conceptRow('Adicional Zona', liquidacion.adicionalZona, 0, 0),
                  if (liquidacion.adicionalZonaPatagonica > 0) _conceptRow('Plus Zona Patagónica', liquidacion.adicionalZonaPatagonica, 0, 0),
                  if (liquidacion.plusUbicacion > 0) _conceptRow('Plus Ubicación / Ruralidad', liquidacion.plusUbicacion, 0, 0),
                  if (liquidacion.estadoDocente > 0) _conceptRow('Estado Docente', liquidacion.estadoDocente, 0, 0),
                  if (liquidacion.fonid > 0) _conceptRow('FONID', liquidacion.fonid, 0, 0),
                  if (liquidacion.conectividad > 0) _conceptRow('Conectividad', liquidacion.conectividad, 0, 0),
                  if (liquidacion.horasCatedra > 0) _conceptRow('Horas Cátedra', liquidacion.horasCatedra, 0, 0),
                  if (liquidacion.adicionalGarantiaSalarial > 0) _conceptRow('Garantía Salarial Nacional', liquidacion.adicionalGarantiaSalarial, 0, 0),
                  
                  // Conceptos Propios
                  ...liquidacion.conceptosPropios.map((c) => _conceptRow(
                    c.descripcion,
                    c.esRemunerativo ? c.monto : 0,
                    !c.esRemunerativo ? c.monto : 0,
                    0,
                  )),

                  // Descuentos
                  _conceptRow('Jubilación (11%)', 0, 0, liquidacion.aporteJubilacion),
                  _conceptRow('Obra Social (3%)', 0, 0, liquidacion.aporteObraSocial),
                  _conceptRow('PAMI (3%)', 0, 0, liquidacion.aportePami),
                  if (liquidacion.impuestoGanancias > 0) _conceptRow('Retención Ganancias', 0, 0, liquidacion.impuestoGanancias),
                  
                  ...liquidacion.deduccionesAdicionales.entries.map((e) => _conceptRow(
                    e.key,
                    0,
                    0,
                    e.value,
                  )),
                ],
              ),
            ),
          ),

          // Totals
          const Divider(color: Colors.black, thickness: 1),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Text(
                    'SON: ${AppNumberFormatter.numeroALetras(liquidacion.netoACobrar)}',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, color: Colors.black),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              SizedBox(
                width: 150,
                child: Column(
                  children: [
                    _totalRow('Total Bruto:', liquidacion.totalBrutoRemunerativo),
                    _totalRow('Total No Remun.:', liquidacion.totalNoRemunerativo),
                    _totalRow('Total Deducciones:', liquidacion.totalDescuentos),
                    const Divider(color: Colors.black),
                    _totalRow('NETO A COBRAR:', liquidacion.netoACobrar, isFinal: true),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          const Text(
            'El empleador reconoce la autenticidad, autoría e integridad del presente documento. Referencia Firma Digital Ley 25.506. Último depósito aportes: Diciembre 2025.',
            style: TextStyle(fontSize: 7, fontStyle: FontStyle.italic, color: Colors.grey),
          ),
          
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _signatureBox('Firma del Empleador'),
              _signatureBox('Firma del Empleado'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(fontSize: 8, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _conceptRow(String desc, double rem, double norem, double descMonto) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(desc, style: const TextStyle(fontSize: 8, color: Colors.black))),
          Expanded(flex: 2, child: Text(rem > 0 ? rem.toStringAsFixed(2) : '', textAlign: TextAlign.right, style: const TextStyle(fontSize: 8, color: Colors.black))),
          Expanded(flex: 2, child: Text(norem > 0 ? norem.toStringAsFixed(2) : '', textAlign: TextAlign.right, style: const TextStyle(fontSize: 8, color: Colors.black))),
          Expanded(flex: 2, child: Text(descMonto > 0 ? descMonto.toStringAsFixed(2) : '', textAlign: TextAlign.right, style: const TextStyle(fontSize: 8, color: Colors.black))),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool isFinal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isFinal ? 10 : 8, fontWeight: isFinal ? FontWeight.bold : FontWeight.normal, color: Colors.black)),
          Text('\$${value.toStringAsFixed(2)}', style: TextStyle(fontSize: isFinal ? 10 : 8, fontWeight: isFinal ? FontWeight.bold : FontWeight.normal, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _signatureBox(String label) {
    return Column(
      children: [
        Container(width: 120, height: 1, color: Colors.black),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 8, color: Colors.black)),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }
}
