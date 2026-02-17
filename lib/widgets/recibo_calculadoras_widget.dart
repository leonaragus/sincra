import 'package:flutter/material.dart';
import 'package:syncra_arg/models/recibo_model.dart';

class ReciboCalculadorasWidget extends StatefulWidget {
  final ReciboModel recibo;

  const ReciboCalculadorasWidget({super.key, required this.recibo});

  @override
  State<ReciboCalculadorasWidget> createState() =>
      _ReciboCalculadorasWidgetState();
}

class _ReciboCalculadorasWidgetState extends State<ReciboCalculadorasWidget> {
  // Estado para SAC
  final TextEditingController _sacMejorRemuneracionController = TextEditingController();
  final TextEditingController _sacDiasTrabajadosController = TextEditingController();
  double _sacResultado = 0.0;

  // Estado para Vacaciones
  final TextEditingController _vacSueldoBrutoController = TextEditingController();
  final TextEditingController _vacAntiguedadAniosController = TextEditingController();
  final TextEditingController _vacDiasCorrespondenController = TextEditingController();
  double _vacResultadoBruto = 0.0;
  double _vacResultadoPlus = 0.0;

  // Estado para Indemnización
  final TextEditingController _indemMejorRemuneracionController = TextEditingController();
  final TextEditingController _indemAntiguedadAniosController = TextEditingController();
  bool _indemPreaviso = true;
  double _indemResultadoTotal = 0.0;
  Map<String, double> _indemDetalle = {};

  @override
  void initState() {
    super.initState();
    _inicializarDatos();
  }

  void _inicializarDatos() {
    // 1. Obtener Sueldo Bruto del recibo
    double bruto = 0.0;
    // Intentar sacar del total bruto si existe, sino sumar haberes remunerativos
    if (widget.recibo.totales.totalBruto > 0) {
      bruto = widget.recibo.totales.totalBruto;
    } else {
      for (var h in widget.recibo.liquidacionDetallada.haberes) {
        if (h.esRemunerativo) bruto += h.monto;
      }
    }
    
    // 2. Calcular Antigüedad en años
    int antiguedadAnios = 0;
    DateTime? fechaIngreso;
    try {
      if (widget.recibo.cabecera.fechaIngreso.isNotEmpty) {
        // Formatos posibles: dd/MM/yyyy, yyyy-MM-dd
        String f = widget.recibo.cabecera.fechaIngreso.replaceAll('-', '/');
        List<String> parts = f.split('/');
        if (parts.length == 3) {
          // Asumimos dd/MM/yyyy si el primero es <= 31
          if (int.parse(parts[0]) <= 31) {
             fechaIngreso = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          } else {
             fechaIngreso = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          }
        }
      }
    } catch (_) {}

    if (fechaIngreso != null) {
      final now = DateTime.now();
      antiguedadAnios = now.year - fechaIngreso.year;
      if (now.month < fechaIngreso.month || (now.month == fechaIngreso.month && now.day < fechaIngreso.day)) {
        antiguedadAnios--;
      }
    }

    // --- Pre-fill SAC ---
    _sacMejorRemuneracionController.text = bruto.toStringAsFixed(2);
    // Días trabajados en el semestre actual
    final now = DateTime.now();
    final inicioSemestre = now.month <= 6 ? DateTime(now.year, 1, 1) : DateTime(now.year, 7, 1);
    final inicioCalculo = (fechaIngreso != null && fechaIngreso.isAfter(inicioSemestre)) ? fechaIngreso : inicioSemestre;
    final diasTrabajados = now.difference(inicioCalculo).inDays + 1; // Aproximado
    _sacDiasTrabajadosController.text = (diasTrabajados > 180 ? 180 : diasTrabajados).toString();

    // --- Pre-fill Vacaciones ---
    _vacSueldoBrutoController.text = bruto.toStringAsFixed(2);
    _vacAntiguedadAniosController.text = antiguedadAnios.toString();
    _vacDiasCorrespondenController.text = _calcularDiasVacacionesSegunLCT(antiguedadAnios).toString();

    // --- Pre-fill Indemnización ---
    _indemMejorRemuneracionController.text = bruto.toStringAsFixed(2);
    _indemAntiguedadAniosController.text = antiguedadAnios.toString();
  }

  int _calcularDiasVacacionesSegunLCT(int anios) {
    if (anios < 5) return 14;
    if (anios < 10) return 21;
    if (anios < 20) return 28;
    return 35;
  }

  void _calcularSAC() {
    final mejorRem = double.tryParse(_sacMejorRemuneracionController.text) ?? 0;
    final dias = double.tryParse(_sacDiasTrabajadosController.text) ?? 0;
    setState(() {
      _sacResultado = (mejorRem / 2) * (dias / 180);
    });
  }

  void _calcularVacaciones() {
    final bruto = double.tryParse(_vacSueldoBrutoController.text) ?? 0;
    final dias = double.tryParse(_vacDiasCorrespondenController.text) ?? 0;
    // Divisor 25 por LCT
    setState(() {
      _vacResultadoBruto = (bruto / 25) * dias;
      // Plus vacacional aproximado (diferencia con sueldo normal)
      double sueldoNormalDias = (bruto / 30) * dias;
      _vacResultadoPlus = _vacResultadoBruto - sueldoNormalDias;
    });
  }

  void _calcularIndemnizacion() {
    final mejorRem = double.tryParse(_indemMejorRemuneracionController.text) ?? 0;
    final anios = double.tryParse(_indemAntiguedadAniosController.text) ?? 0;
    
    // Antigüedad (Art 245): 1 sueldo por año o fracción > 3 meses
    // Asumimos que el usuario ingresa años redondeados o decimales (ej 2.5)
    double aniosParaCalculo = anios.floorToDouble();
    double fraccion = anios - aniosParaCalculo;
    if (fraccion > 0.25) aniosParaCalculo += 1; // > 3 meses cuenta como año
    if (aniosParaCalculo < 1) aniosParaCalculo = 1; // Mínimo 1 sueldo

    double rubroAntiguedad = mejorRem * aniosParaCalculo;
    
    // Preaviso (Art 231, 232)
    // < 5 años: 1 mes. > 5 años: 2 meses.
    double montoPreaviso = 0;
    if (_indemPreaviso) {
      montoPreaviso = (anios < 5) ? mejorRem : (mejorRem * 2);
    }

    // Integración mes despido (aproximado 0.5 mes promedio)
    double integracionMes = mejorRem / 2;

    // SAC Proporcional (estimado 3 meses)
    double sacProp = (mejorRem / 2) * (90 / 180);

    // Vacaciones No Gozadas (estimado proporcional)
    double diasVac = _calcularDiasVacacionesSegunLCT(anios.toInt()).toDouble();
    double vacNoGozadas = (mejorRem / 25) * (diasVac * (anios % 1)); // Proporcional al año

    setState(() {
      _indemDetalle = {
        'Antigüedad (Art. 245)': rubroAntiguedad,
        'Preaviso (Art. 232)': montoPreaviso,
        'Integración Mes (Art. 233)': integracionMes,
        'SAC Proporcional': sacProp,
        'Vacaciones No Gozadas': vacNoGozadas,
      };
      _indemResultadoTotal = rubroAntiguedad + montoPreaviso + integracionMes + sacProp + vacNoGozadas;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          children: [
            _buildHeaderConvenio(context),
            const SizedBox(height: 16),
            _buildCalculatorCard(
              context,
              title: 'Calculadora de Aguinaldo (SAC)',
              icon: Icons.savings_outlined,
              color: Colors.teal,
              content: _buildSacContent(),
              onCalculate: _calcularSAC,
              result: _sacResultado > 0 
                ? _buildResultRow('SAC Estimado a Cobrar', _sacResultado) 
                : null,
            ),
            const SizedBox(height: 16),
            _buildCalculatorCard(
              context,
              title: 'Calculadora de Vacaciones',
              icon: Icons.beach_access_outlined,
              color: Colors.orange,
              content: _buildVacacionesContent(),
              onCalculate: _calcularVacaciones,
              result: _vacResultadoBruto > 0 
                ? Column(
                    children: [
                      _buildResultRow('Total Bruto Vacaciones', _vacResultadoBruto),
                      const SizedBox(height: 4),
                      Text(
                        '(Incluye un Plus estimado de \$${_vacResultadoPlus.toStringAsFixed(2)})',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                      )
                    ],
                  )
                : null,
            ),
            const SizedBox(height: 16),
            _buildCalculatorCard(
              context,
              title: 'Calculadora de Despido (Estimación)',
              icon: Icons.gavel_outlined,
              color: Colors.redAccent,
              content: _buildIndemnizacionContent(),
              onCalculate: _calcularIndemnizacion,
              result: _indemResultadoTotal > 0 ? _buildIndemnizacionResult() : null,
            ),
             const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderConvenio(BuildContext context) {
    final cct = widget.recibo.cabecera.cctAplicable;
    final tieneCCT = cct.isNotEmpty && cct.toLowerCase() != 'no especificado';
    final theme = Theme.of(context);
    final colorBase = tieneCCT ? Colors.blue : Colors.grey;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorBase.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorBase.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            tieneCCT ? Icons.verified : Icons.info_outline,
            color: colorBase,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tieneCCT ? 'Convenio Detectado' : 'Sin Convenio Específico',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorBase,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  tieneCCT ? cct : 'Se aplicarán fórmulas generales de LCT (Ley de Contrato de Trabajo).',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textTheme.bodyMedium?.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculatorCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required Widget content,
    required VoidCallback onCalculate,
    Widget? result,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800),
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          content,
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onCalculate,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('CALCULAR AHORA', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          if (result != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: result,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSacContent() {
    return Column(
      children: [
        _buildTextField(
          'Mejor Remuneración del Semestre', 
          _sacMejorRemuneracionController, 
          icon: Icons.attach_money,
          tooltip: 'Es el sueldo bruto más alto que cobraste en los últimos 6 meses (Enero-Junio o Julio-Diciembre).',
          helperText: 'El sueldo más alto del semestre',
        ),
        const SizedBox(height: 12),
        _buildTextField(
          'Días Trabajados en Semestre', 
          _sacDiasTrabajadosController, 
          icon: Icons.calendar_today,
          tooltip: 'Cantidad de días que fuiste empleado en este semestre. Si trabajaste todo el semestre, son 180 días.',
          helperText: 'Días activos (máx 180)',
        ),
      ],
    );
  }

  Widget _buildVacacionesContent() {
    return Column(
      children: [
        _buildTextField(
          'Sueldo Bruto Mensual', 
          _vacSueldoBrutoController, 
          icon: Icons.attach_money,
          tooltip: 'Tu sueldo habitual sin descuentos. Se usa para calcular el valor del día de vacación.',
          helperText: 'Tu sueldo habitual',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField(
              'Antigüedad (Años)', 
              _vacAntiguedadAniosController, 
              icon: Icons.history,
              tooltip: 'Años completos trabajados en la empresa.',
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(
              'Días a Liquidar', 
              _vacDiasCorrespondenController, 
              icon: Icons.beach_access,
              tooltip: 'Días de vacaciones que te vas a tomar o que te deben pagar.',
              helperText: 'Días a pagar',
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildIndemnizacionContent() {
    return Column(
      children: [
        _buildTextField(
          'Mejor Remuneración Mensual', 
          _indemMejorRemuneracionController, 
          icon: Icons.attach_money,
          tooltip: 'El sueldo mensual más alto del último año.',
          helperText: 'Mejor sueldo del último año',
        ),
        const SizedBox(height: 12),
        _buildTextField(
          'Antigüedad (Años)', 
          _indemAntiguedadAniosController, 
          icon: Icons.history,
          tooltip: 'Tiempo total trabajado en años. Si tenés fracción mayor a 3 meses, contalo como un año más.',
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Incluir Indemnización por Preaviso'),
          subtitle: const Text('Activalo si te despidieron sin avisarte con tiempo (1 o 2 meses antes).'),
          value: _indemPreaviso,
          onChanged: (val) => setState(() => _indemPreaviso = val),
          activeColor: Colors.redAccent,
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {IconData? icon, String? tooltip, String? helperText}) {
    return Tooltip(
      message: tooltip ?? label,
      triggerMode: TooltipTriggerMode.tap,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          helperStyle: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          prefixIcon: icon != null ? Icon(icon, size: 20) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          isDense: true,
          suffixIcon: tooltip != null ? const Icon(Icons.info_outline, size: 16, color: Colors.grey) : null,
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
        ),
      ],
    );
  }

  Widget _buildIndemnizacionResult() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Detalle de la Liquidación Final:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const Divider(),
        ..._indemDetalle.entries.map((e) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13))),
              Text('\$${e.value.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        )),
        const Divider(),
        _buildResultRow('TOTAL ESTIMADO', _indemResultadoTotal),
      ],
    );
  }
}
