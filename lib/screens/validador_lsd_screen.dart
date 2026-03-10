
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/lsd_parsed_data.dart';
import '../services/lsd_parser_service.dart';
import '../services/lsd_validator_helper.dart';

import '../services/validador_lsd_update_service.dart';
import '../utils/file_saver.dart' as fs;

class ValidadorLSDScreen extends StatefulWidget {
  const ValidadorLSDScreen({super.key});

  @override
  State<ValidadorLSDScreen> createState() => _ValidadorLSDScreenState();
}

class _ValidadorLSDScreenState extends State<ValidadorLSDScreen> {
  LSDParsedFile? _parsedFile;
  List<ValidationResult> _validationResults = [];
  bool _isLoading = false;
  String _ultimaSincro = "Cargando...";

  @override
  void initState() {
    super.initState();
    _checkRulesUpdate();
  }

  Future<void> _checkRulesUpdate() async {
    // Silent update check in background
    final updated = await ValidadorLSDUpdateService.checkForUpdates();
    final rules = await ValidadorLSDUpdateService.getActiveRules();
    
    if (mounted) {
      setState(() {
        _ultimaSincro = rules['ultima_sincro'] ?? "Desconocida";
      });

      if (updated) {
        _showUpdateNotification(rules['mensaje'] ?? "Reglas actualizadas");
      }
    }
  }

  void _showUpdateNotification(String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.blue[50],
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.blueAccent),
            const SizedBox(width: 10),
            Text('¡Sistema Actualizado!', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'El robot BAT ha detectado cambios legales:\\n\\n$msg',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('EXCELENTE'),
          ),
        ],
      ),
    );
  }

  Future<void> _importarArchivo() async {
    setState(() => _isLoading = true);
    
    LSDParsedFile? localParsedFile;
    List<ValidationResult> localValidationResults = [];

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final platformFile = result.files.single;
        final bytes = platformFile.bytes;
        
        if (bytes == null) {
          throw Exception("No se pudieron leer los bytes del archivo");
        }
        
        final contentLatin1 = latin1.decode(bytes);

        final parsed = LSDParserService.parseFileContent(contentLatin1);
        final rules = await ValidadorLSDUpdateService.getActiveRules();
        final topeMin = rules['topes']?['min']?.toDouble();
        final topeMax = rules['topes']?['max']?.toDouble();
        
        final validations = LSDValidatorHelper.validateParsedFile(
          parsed,
          topeMin: topeMin,
          topeMax: topeMax,
        );

        localParsedFile = parsed;
        localValidationResults = validations;
      }
      
      // Success
      if (mounted) {
        setState(() {
          _parsedFile = localParsedFile;
          _validationResults = localValidationResults;
          _isLoading = false;
        });
        if (_parsedFile != null && _parsedFile!.erroresParsing.isNotEmpty) {
          _showParsingErrorsDialog();
        }
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importando archivo: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showParsingErrorsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 10),
            Text('Problemas en el archivo', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'El archivo se cargó, pero tiene errores de formato que ARCA rechazará:',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _parsedFile!.erroresParsing.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '• ${_parsedFile!.erroresParsing[index]}',
                        style: GoogleFonts.robotoMono(fontSize: 12, color: Colors.red[800]),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Puedes revisar los datos importados abajo, pero deberás corregir estos puntos en tu herramienta original.',
                style: GoogleFonts.poppins(fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportarArchivo() async {
    if (_parsedFile == null) return;

    // =======================================================================
    // MEJORA 1: Verificación de integridad estructural PRE-EXPORTACIÓN
    // =======================================================================
    final employees = <String, Map<String, dynamic>>{};
    for (var ref in _parsedFile!.referencias) {
      employees[ref.cuil] = {'ref': ref, 'conceptos': <LSDConcepto>[], 'bases': null, 'compl': null};
    }
    for (var conc in _parsedFile!.conceptos) {
       if (employees.containsKey(conc.cuil)) (employees[conc.cuil]!['conceptos'] as List<LSDConcepto>).add(conc);
    }
    for (var base in _parsedFile!.bases) {
       if (employees.containsKey(base.cuil)) employees[base.cuil]!['bases'] = base;
    }
    for (var compl in _parsedFile!.complementarios) {
       if (employees.containsKey(compl.cuil)) employees[compl.cuil]!['compl'] = compl;
    }
    
    for (final entry in employees.entries) {
        final cuil = entry.key;
        final data = entry.value;
        final ref = data['ref'] as LSDLegajoRef?;
        final bases = data['bases'] as LSDBases?;

        if (ref == null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: Falta registro de Legajo (02) para el CUIL $cuil. Imposible exportar.'), backgroundColor: Colors.red));
            return;
        }
        if (bases == null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: Falta registro de Bases (04) para el CUIL $cuil. Imposible exportar.'), backgroundColor: Colors.red));
            return;
        }
    }

    try {
      final sb = StringBuffer();
      if (_parsedFile!.header != null) {
        sb.writeln(_parsedFile!.header!.toLine());
      }
      
      employees.forEach((cuil, data) {
        final ref = data['ref'] as LSDLegajoRef?;
        if (ref != null) sb.writeln(ref.toLine());
        
        final conceptos = data['conceptos'] as List<LSDConcepto>;
        for (var c in conceptos) sb.writeln(c.toLine());
        
        final bases = data['bases'] as LSDBases?;
        if (bases != null) sb.writeln(bases.toLine());
        
        final compl = data['compl'] as LSDComplementarios?;
        if (compl != null) sb.writeln(compl.toLine());
      });

      final String? savedPath = await fs.saveTextFile(
        fileName: 'LSD_Corregido.txt',
        content: sb.toString(),
      );

      if (savedPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Archivo exportado correctamente'), backgroundColor: Colors.green),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exportando archivo: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Validador Previo LSD ARCA', style: GoogleFonts.poppins()),
        backgroundColor: isDark ? Colors.grey[900] : theme.primaryColor,
        actions: [
          if (_parsedFile != null)
            IconButton(
              icon: const Icon(Icons.save_alt),
              tooltip: 'Exportar Correcciones',
              onPressed: _exportarArchivo,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _parsedFile == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload_file, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Importá tu archivo TXT de LSD',
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _importarArchivo,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Seleccionar Archivo'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildHeaderSummary(),
                    Expanded(child: _buildEmployeeList()),
                  ],
                ),
      floatingActionButton: _parsedFile != null 
          ? FloatingActionButton(
              onPressed: _importarArchivo,
              child: const Icon(Icons.refresh),
              tooltip: 'Importar otro archivo',
            )
          : null,
    );
  }

  Widget _buildHeaderSummary() {
    return SingleChildScrollView( // Changed to allow scrolling for summary
      child: Column(
        children: [
          _buildUpdateStatusInfo(),
          _buildInstructionsButton(),
          if (_parsedFile?.header != null) ...[
            _buildSummaryCard(),
            _buildGlobalSummary(), // MEJORA 3
          ]
        ],
      ),
    );
  }

  // =======================================================================
  // MEJORA 3: "Control de Sumas y Saldos" a Nivel Global
  // =======================================================================
  Widget _buildGlobalSummary() {
    if (_parsedFile == null) return const SizedBox.shrink();

    double totalNeto = 0;
    double totalSUSS = 0;
    double totalOS = 0;
    final totalEmpleados = _parsedFile!.referencias.length;
    final conceptos = _parsedFile!.conceptos;

    for (final ref in _parsedFile!.referencias) {
      final conceptosEmpleado = conceptos.where((c) => c.cuil == ref.cuil).toList();
      double haberes = 0;
      double deducciones = 0;

      LSDConcepto? jubConcept;
      try {
        jubConcept = conceptosEmpleado.firstWhere((c) => c.codigo.trim() == '110001');
      } catch (_) {
        jubConcept = null;
      }
      LSDConcepto? leyConcept;
      try {
        leyConcept = conceptosEmpleado.firstWhere((c) => c.codigo.trim() == '110002');
      } catch (_) {
        leyConcept = null;
      }
      LSDConcepto? osConcept;
      try {
        osConcept = conceptosEmpleado.firstWhere((c) => c.codigo.trim() == '110003');
      } catch (_) {
        osConcept = null;
      }

      totalSUSS += (jubConcept?.importeAsDouble ?? 0.0) + (leyConcept?.importeAsDouble ?? 0.0);
      totalOS += osConcept?.importeAsDouble ?? 0.0;
      
      for (final c in conceptosEmpleado) {
        if (c.tipo == 'H') {
            haberes += c.importeAsDouble;
        } else if (c.tipo == 'D') {
            deducciones += c.importeAsDouble;
        }
      }
      totalNeto += haberes - deducciones;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CIERRE GLOBAL DEL ARCHIVO', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildGlobalStat('Empleados', totalEmpleados.toString(), Icons.people),
                _buildGlobalStat('Neto a Pagar', '\$${totalNeto.toStringAsFixed(2)}', Icons.wallet),
                _buildGlobalStat('Aportes SUSS', '\$${totalSUSS.toStringAsFixed(2)}', Icons.security),
                _buildGlobalStat('Aportes O.S.', '\$${totalOS.toStringAsFixed(2)}', Icons.local_hospital),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blueGrey),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
      ],
    );
  }


  Widget _buildUpdateStatusInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      color: Colors.grey[200],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_user, size: 14, color: Colors.green),
          const SizedBox(width: 8),
          Text(
            'Reglas ARCA verificadas: $_ultimaSincro (Fuente: ANSES/BO)',
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.blueGrey[700], fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final h = _parsedFile!.header!;
    final errorCount = _validationResults.where((r) => r.hasErrors).length;
    final warningCount = _validationResults.where((r) => r.hasWarnings).length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h.razonSocial.trim(), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis,),
                      Text('CUIT: ${h.cuitEmpresa} | Periodo: ${h.periodo}', style: GoogleFonts.poppins(color: Colors.grey)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _buildStatusChip(errorCount, Colors.red, 'Errores'),
                    const SizedBox(width: 8),
                    _buildStatusChip(warningCount, Colors.orange, 'Avisos'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ElevatedButton.icon(
        onPressed: _showUsageInstructions,
        icon: const Icon(Icons.help_outline, color: Colors.white),
        label: const Text('¿CÓMO USAR EL VALIDADOR?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _showUsageInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.blueAccent),
            const SizedBox(width: 10),
            Text('Instrucciones de Uso', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInstructionStep('1', 'Importar Archivo', 'Presiona el botón "Importar" y selecciona tu archivo TXT generado por tu sistema actual.'),
              _buildInstructionStep('2', 'Revisar Formato', 'Si el archivo tiene errores físicos (longitud o tipos de registro), verás un aviso inmediato.'),
              _buildInstructionStep('3', 'Auditar Datos', 'Revisa la lista de empleados. El color rojo indica errores que ARCA rechazará, y el naranja advertencias de cálculo.'),
              _buildInstructionStep('4', 'Corregir y Exportar', 'Si el validador pudo reparar el archivo, puedes usar el botón de exportar para obtener el TXT final corregido.'),
              const Divider(height: 30),
              Text(
                'Nota: El validador detecta automáticamente si el formato es ARCA 2026 (01, 02...) o Legacy (1, 2...).',
                style: GoogleFonts.poppins(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.blueAccent,
            child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(desc, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[800])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(int count, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 12, color: color),
          const SizedBox(width: 8),
          Text('$count $label', style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEmployeeList() {
    return ListView.builder(
      itemCount: _validationResults.length,
      itemBuilder: (context, index) {
        final res = _validationResults[index];
        final hasError = res.hasErrors;
        final hasWarning = res.hasWarnings;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: hasError ? Colors.red[100] : (hasWarning ? Colors.orange[100] : Colors.green[100]),
              child: Icon(
                hasError ? Icons.error : (hasWarning ? Icons.warning : Icons.check_circle),
                color: hasError ? Colors.red : (hasWarning ? Colors.orange : Colors.green),
              ),
            ),
            title: Text(res.nombre, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CUIL: ${res.cuil}'),
                if (hasError) Text(res.errors.first.message, style: const TextStyle(color: Colors.red, fontSize: 12), overflow: TextOverflow.ellipsis,),
                if (!hasError && hasWarning) Text(res.warnings.first.message, style: const TextStyle(color: Colors.orange, fontSize: 12), overflow: TextOverflow.ellipsis),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showEmployeeDetails(res),
          ),
        );
      },
    );
  }

  void _showEmployeeDetails(ValidationResult res) {
    showDialog(
      context: context,
      builder: (context) => _EmployeeDetailDialog(
        result: res,
        parsedFile: _parsedFile!,
        onSave: () async {
          // Re-validate everything
          final rules = await ValidadorLSDUpdateService.getActiveRules();
          final topeMin = rules['topes']?['min']?.toDouble();
          final topeMax = rules['topes']?['max']?.toDouble();
          
          final validations = LSDValidatorHelper.validateParsedFile(
            _parsedFile!,
            topeMin: topeMin,
            topeMax: topeMax,
          );
          setState(() {
            _validationResults = validations;
          });
        },
      ),
    );
  }
}

class _EmployeeDetailDialog extends StatefulWidget {
  final ValidationResult result;
  final LSDParsedFile parsedFile;
  final VoidCallback onSave;

  const _EmployeeDetailDialog({
    required this.result,
    required this.parsedFile,
    required this.onSave,
  });

  @override
  State<_EmployeeDetailDialog> createState() => _EmployeeDetailDialogState();
}

class _EmployeeDetailDialogState extends State<_EmployeeDetailDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _basesControllers = <TextEditingController>[];
  final _conceptosControllers = <Map<String, TextEditingController>>[];
  LSDBases? _basesRef;
  List<LSDConcepto> _conceptosRef = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  void _loadData() {
    try {
      _basesRef = widget.parsedFile.bases.firstWhere((b) => b.cuil == widget.result.cuil);
    } catch (e) {
      _basesRef = null;
    }

    _conceptosRef = widget.parsedFile.conceptos.where((c) => c.cuil == widget.result.cuil).toList();

    if (_basesRef != null) {
      for (var i = 0; i < 10; i++) {
        final val = _basesRef!.getBaseAsDouble(i);
        _basesControllers.add(TextEditingController(text: val.toStringAsFixed(2)));
      }
    }

    for (var c in _conceptosRef) {
      _conceptosControllers.add({
        'codigo': TextEditingController(text: c.codigo.trim()),
        'importe': TextEditingController(text: c.importeAsDouble.toStringAsFixed(2)),
        'cantidad': TextEditingController(text: int.parse(c.cantidad).toString()),
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var c in _basesControllers) c.dispose();
    for (var m in _conceptosControllers) {
      m.values.forEach((c) => c.dispose());
    }
    super.dispose();
  }

  // =======================================================================
  // MEJORA 4: Blindaje de la Edición Manual
  // =======================================================================
  void _saveChanges() {
    // Save Bases
    if (_basesRef != null) {
      final newBases = <String>[];
      for (var i = 0; i < _basesControllers.length; i++) {
        final controller = _basesControllers[i];
        final val = double.tryParse(controller.text);
        if (val == null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: Formato inválido en Base ${i + 1}. Use solo números y punto.'), backgroundColor: Colors.red));
          return;
        }
        final valInt = (val * 100).round();
        final valStr = valInt.toString().padLeft(15, '0');
        newBases.add(valStr.length > 15 ? valStr.substring(valStr.length - 15) : valStr);
      }
      _basesRef!.bases = newBases;
    }

    // Save Conceptos
    for (var i = 0; i < _conceptosRef.length; i++) {
      final c = _conceptosRef[i];
      final ctrls = _conceptosControllers[i];
      
      final imp = double.tryParse(ctrls['importe']!.text);
      if (imp == null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: Formato de importe inválido para "${c.descripcion.trim()}".'), backgroundColor: Colors.red));
          return;
      }
      final impInt = (imp * 100).round();
      c.importe = impInt.toString().padLeft(15, '0');

      final cant = int.tryParse(ctrls['cantidad']!.text);
       if (cant == null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: Formato de cantidad inválido para "${c.descripcion.trim()}".'), backgroundColor: Colors.red));
          return;
      }
      c.cantidad = cant.toString().padLeft(4, '0');
      
      c.codigo = ctrls['codigo']!.text.padRight(10, ' ').substring(0, 10);
    }

    widget.onSave();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cambios guardados. Re-validando...'), backgroundColor: Colors.blue),
    );
  }

  // =======================================================================
  // MEJORA 2: Expansión del Arsenal de "Auto-Corrección"
  // =======================================================================
  void _applyAutoFix(ValidationIssue issue) {
    if (issue.type == ValidationIssueType.base4Inconsistent) {
      final base8 = issue.data['base8'] as double?;
      if (base8 != null) {
        setState(() => _basesControllers[3].text = base8.toStringAsFixed(2));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Corrección aplicada: Base 4 igualada a Base 8. Guarde para confirmar.'), backgroundColor: Colors.blue));
      }
    } else if (issue.type == ValidationIssueType.remunerativoInconsistente) { // NUEVA REGLA
        final teorico = issue.data['remunerativoCalculado'] as double?;
         if (teorico != null) {
            setState(() {
              _basesControllers[0].text = teorico.toStringAsFixed(2); // Base 1
              _basesControllers[1].text = teorico.toStringAsFixed(2); // Base 2
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Corrección aplicada: Base 1 y 2 ajustadas al total remunerativo. Guarde para confirmar.'), backgroundColor: Colors.blue));
        }
    } else if (issue.type == ValidationIssueType.aporteJubilacionDiff || 
               issue.type == ValidationIssueType.aporteLeyDiff || 
               issue.type == ValidationIssueType.aporteOSDiff) {
       final teorico = issue.data['teorico'] as double?;
       if (teorico == null) return;
       
       // Usamos códigos AFIP para buscar el concepto a corregir
       String codigoAFIP = '';
       if (issue.type == ValidationIssueType.aporteJubilacionDiff) codigoAFIP = '110001';
       if (issue.type == ValidationIssueType.aporteLeyDiff) codigoAFIP = '110002';
       if (issue.type == ValidationIssueType.aporteOSDiff) codigoAFIP = '110003';

       int bestMatchIndex = _conceptosRef.indexWhere((c) => c.codigo.trim() == codigoAFIP);

       if (bestMatchIndex != -1) {
          setState(() => _conceptosControllers[bestMatchIndex]['importe']!.text = teorico.toStringAsFixed(2));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Corrección aplicada: Concepto ajustado a \$${teorico.toStringAsFixed(2)}. Guarde para confirmar.'), backgroundColor: Colors.blue));
       } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontró el concepto de descuento para aplicar el ajuste.'), backgroundColor: Colors.orange));
       }
    }
  }

  Widget _buildIssueRow(ValidationIssue issue, bool isError) {
    bool canFix = issue.type != ValidationIssueType.generic;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(isError ? Icons.error : Icons.warning, color: isError ? Colors.red : Colors.orange, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(issue.message, style: TextStyle(color: isError ? Colors.red : Colors.orange, fontSize: 12))),
          if (canFix)
            TextButton.icon(
              icon: const Icon(Icons.auto_fix_high, size: 14),
              label: const Text('Corregir', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _applyAutoFix(issue),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Revisar Liquidación: ${widget.result.cuil}', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis,),
                        Text(widget.result.nombre, style: GoogleFonts.poppins(color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            
            if (widget.result.hasErrors || widget.result.hasWarnings)
              Container(
                color: Colors.grey[100],
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.result.hasErrors)
                      Text('Errores:', style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold)),
                    ...widget.result.errors.map((e) => _buildIssueRow(e, true)),
                    
                    if (widget.result.hasWarnings) ...[
                      const SizedBox(height: 8),
                      Text('Advertencias:', style: GoogleFonts.poppins(color: Colors.orange, fontWeight: FontWeight.bold)),
                      ...widget.result.warnings.map((e) => _buildIssueRow(e, false)),
                    ],
                  ],
                ),
              ),

            TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'Bases Imponibles (Reg. 04)'),
                Tab(text: 'Conceptos (Reg. 03)'),
              ],
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBasesTab(),
                  _buildConceptosTab(),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _saveChanges,
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar Correcciones'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasesTab() {
    if (_basesRef == null) {
      return const Center(child: Text('No hay registro de bases (Reg 04) para este CUIL.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text('Edite las bases imponibles para corregir inconsistencias.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: List.generate(10, (index) {
              final label = LSDValidatorHelper.getBaseLabel(index + 1);
              return SizedBox(
                width: 200,
                child: TextField(
                  controller: _basesControllers[index],
                  decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), prefixText: '\$ '),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))], // MEJORA 4
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildConceptosTab() {
    if (_conceptosRef.isEmpty) {
      return const Center(child: Text('No hay conceptos liquidados.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _conceptosRef.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final c = _conceptosRef[index];
        final ctrls = _conceptosControllers[index];

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.descripcion.trim(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 120,
                    child: TextField(controller: ctrls['codigo'], decoration: const InputDecoration(labelText: 'Código', isDense: true), style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 80,
              child: TextField(
                controller: ctrls['cantidad'],
                decoration: const InputDecoration(labelText: 'Cant.', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly], // MEJORA 4
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 150,
              child: TextField(
                controller: ctrls['importe'],
                decoration: const InputDecoration(labelText: 'Importe', border: OutlineInputBorder(), prefixText: '\$ '),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))], // MEJORA 4
              ),
            ),
            const SizedBox(width: 16),
            Chip(label: Text(c.tipo), backgroundColor: c.tipo == 'H' ? Colors.green[100] : Colors.red[100]),
          ],
        );
      },
    );
  }
}
