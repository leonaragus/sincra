
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/lsd_parsed_data.dart';
import '../services/lsd_parser_service.dart';
import '../services/lsd_validator_helper.dart';

import '../services/validador_lsd_update_service.dart';

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
  // String? _fileName;

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
          'El robot BAT ha detectado cambios legales:\n\n$msg',
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
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
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

        setState(() {
          _parsedFile = parsed;
          _validationResults = validations;
          // _fileName = result.files.single.name; // Unused
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importando archivo: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = true); // Mantener cargando un momento para procesar errores
      
      // Si hay errores de parsing, mostrarlos inmediatamente
      if (_parsedFile != null && _parsedFile!.erroresParsing.isNotEmpty) {
        _showParsingErrorsDialog();
      }
      
      setState(() => _isLoading = false);
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

    try {
      final sb = StringBuffer();
      // Header
      if (_parsedFile!.header != null) {
        sb.writeln(_parsedFile!.header!.toLine());
      }
      
      // We need to reconstruct the file respecting the order:
      // Employee 1 -> Reg 2 -> Reg 3 (concepts) -> Reg 4 (bases) -> Reg 5 (compl)
      // Employee 2 -> ...
      // This is implicit in the lists if we group them by CUIL.
      
      // Grouping logic (similar to ValidatorHelper)
      final employees = <String, Map<String, dynamic>>{};
      
      // Initialize with refs
      for (var ref in _parsedFile!.referencias) {
        employees[ref.cuil] = {'ref': ref, 'conceptos': <LSDConcepto>[], 'bases': null, 'compl': null};
      }

      // Add concepts
      for (var conc in _parsedFile!.conceptos) {
         if (!employees.containsKey(conc.cuil)) {
           // Orphan concept, add to a temp list or handle?
           // For now, if no ref, we might skip or append at end. 
           // Let's assume structure is valid enough or we just append orphan concepts at the end (bad for LSD).
           // Better to create a dummy entry if needed.
           employees[conc.cuil] = {'ref': null, 'conceptos': <LSDConcepto>[], 'bases': null, 'compl': null};
         }
         (employees[conc.cuil]!['conceptos'] as List<LSDConcepto>).add(conc);
      }
      
      // Add bases
      for (var base in _parsedFile!.bases) {
        if (!employees.containsKey(base.cuil)) {
           employees[base.cuil] = {'ref': null, 'conceptos': <LSDConcepto>[], 'bases': null, 'compl': null};
        }
        employees[base.cuil]!['bases'] = base;
      }
      
      // Add compl
      for (var compl in _parsedFile!.complementarios) {
        if (!employees.containsKey(compl.cuil)) {
           employees[compl.cuil] = {'ref': null, 'conceptos': <LSDConcepto>[], 'bases': null, 'compl': null};
        }
        employees[compl.cuil]!['compl'] = compl;
      }
      
      // Write to buffer
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

      // Save file
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar Archivo LSD Corregido',
        fileName: 'LSD_Corregido.txt',
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(latin1.encode(sb.toString()));
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Archivo exportado correctamente'), backgroundColor: Colors.green),
          );
        }
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
    return Column(
      children: [
        _buildUpdateStatusInfo(),
        _buildInstructionsButton(),
        if (_parsedFile?.header != null) ...[
          _buildSummaryCard(),
        ]
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.razonSocial.trim(), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('CUIT: ${h.cuitEmpresa} | Periodo: ${h.periodo}', style: GoogleFonts.poppins(color: Colors.grey)),
                  ],
                ),
                Row(
                  children: [
                    _buildStatusChip(errorCount, Colors.red, 'Errores'),
                    const SizedBox(width: 8),
                    _buildStatusChip(warningCount, Colors.orange, 'Advertencias'),
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
      padding: const EdgeInsets.all(16.0),
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
                if (hasError) Text(res.errors.first.message, style: const TextStyle(color: Colors.red, fontSize: 12)),
                if (!hasError && hasWarning) Text(res.warnings.first.message, style: const TextStyle(color: Colors.orange, fontSize: 12)),
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
    // Find references in parsed file
    try {
      _basesRef = widget.parsedFile.bases.firstWhere((b) => b.cuil == widget.result.cuil);
    } catch (e) {
      _basesRef = null;
    }

    _conceptosRef = widget.parsedFile.conceptos.where((c) => c.cuil == widget.result.cuil).toList();

    // Init Bases Controllers
    if (_basesRef != null) {
      for (var i = 0; i < 10; i++) {
        final val = _basesRef!.getBaseAsDouble(i);
        _basesControllers.add(TextEditingController(text: val.toStringAsFixed(2)));
      }
    }

    // Init Conceptos Controllers
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

  void _saveChanges() {
    // Save Bases
    if (_basesRef != null) {
      final newBases = <String>[];
      for (var c in _basesControllers) {
        final val = double.tryParse(c.text) ?? 0.0;
        final valInt = (val * 100).round();
        final valStr = valInt.toString().padLeft(15, '0');
        // Ensure 15 chars max
        final finalStr = valStr.length > 15 ? valStr.substring(valStr.length - 15) : valStr;
        newBases.add(finalStr);
      }
      _basesRef!.bases = newBases;
    }

    // Save Conceptos
    for (var i = 0; i < _conceptosRef.length; i++) {
      final c = _conceptosRef[i];
      final ctrls = _conceptosControllers[i];
      
      // Update Importe
      final imp = double.tryParse(ctrls['importe']!.text) ?? 0.0;
      final impInt = (imp * 100).round();
      final impStr = impInt.toString().padLeft(15, '0');
      c.importe = impStr.length > 15 ? impStr.substring(impStr.length - 15) : impStr;

      // Update Cantidad
      final cant = int.tryParse(ctrls['cantidad']!.text) ?? 0;
      final cantStr = cant.toString().padLeft(4, '0');
      c.cantidad = cantStr.length > 4 ? cantStr.substring(cantStr.length - 4) : cantStr;
      
      // Update Codigo (if needed, usually fixed but allow edit)
      final cod = ctrls['codigo']!.text.padRight(10, ' ');
      c.codigo = cod.substring(0, 10);
    }

    widget.onSave();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cambios aplicados. Validando...'), backgroundColor: Colors.green),
    );
  }

  void _applyAutoFix(ValidationIssue issue) {
    if (issue.type == ValidationIssueType.base4Inconsistent) {
      final base8 = issue.data['base8'] as double?;
      if (base8 != null) {
        // Find index 3 (Base 4) and update it to Base 8
        setState(() {
          _basesControllers[3].text = base8.toStringAsFixed(2);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Corrección aplicada: Base 4 igualada a Base 8. Guarde para confirmar.'), backgroundColor: Colors.blue),
        );
      }
    } else if (issue.type == ValidationIssueType.aporteJubilacionDiff || 
               issue.type == ValidationIssueType.aporteLeyDiff || 
               issue.type == ValidationIssueType.aporteOSDiff) {
       // Fix for contributions: find concept and update amount
       final teorico = issue.data['teorico'] as double?;
       if (teorico == null) return;
       
       String searchKey = '';
       if (issue.type == ValidationIssueType.aporteJubilacionDiff) searchKey = 'JUB';
       if (issue.type == ValidationIssueType.aporteLeyDiff) searchKey = '19032';
       if (issue.type == ValidationIssueType.aporteOSDiff) searchKey = 'OBRA';

       // Find best match concept
       int bestMatchIndex = -1;
       for (var i = 0; i < _conceptosRef.length; i++) {
         final c = _conceptosRef[i];
         if (c.tipo == 'D' && (c.codigo.contains(searchKey) || c.descripcion.toUpperCase().contains(searchKey))) {
           bestMatchIndex = i;
           break; 
         }
       }

       if (bestMatchIndex != -1) {
          setState(() {
            _conceptosControllers[bestMatchIndex]['importe']!.text = teorico.toStringAsFixed(2);
          });
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Corrección aplicada: Concepto ajustado a \$${teorico.toStringAsFixed(2)}. Guarde para confirmar.'), backgroundColor: Colors.blue),
          );
       } else {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('No se encontró un concepto claro para aplicar el ajuste.'), backgroundColor: Colors.orange),
          );
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
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Editar Liquidación: ${widget.result.cuil}', 
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(widget.result.nombre, style: GoogleFonts.poppins(color: Colors.grey)),
                    ],
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            
            // Errors Summary
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

            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'Bases Imponibles (Reg. 04)'),
                Tab(text: 'Conceptos (Reg. 03)'),
              ],
            ),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBasesTab(),
                  _buildConceptosTab(),
                ],
              ),
            ),

            // Footer
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
          const Text('Edite las bases imponibles para corregir inconsistencias.', 
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: List.generate(10, (index) {
              final label = index == 3 ? 'Base 4 (OS)' : (index == 7 ? 'Base 8 (Aporte OS)' : 'Base ${index + 1}');
              return SizedBox(
                width: 200,
                child: TextField(
                  controller: _basesControllers[index],
                  decoration: InputDecoration(
                    labelText: label,
                    border: const OutlineInputBorder(),
                    prefixText: '\$ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                    child: TextField(
                      controller: ctrls['codigo'],
                      decoration: const InputDecoration(labelText: 'Código', isDense: true),
                      style: const TextStyle(fontSize: 12),
                    ),
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
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 150,
              child: TextField(
                controller: ctrls['importe'],
                decoration: const InputDecoration(
                  labelText: 'Importe', 
                  border: OutlineInputBorder(),
                  prefixText: '\$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 16),
            Chip(
              label: Text(c.tipo),
              backgroundColor: c.tipo == 'H' ? Colors.green[100] : Colors.red[100],
            ),
          ],
        );
      },
    );
  }
}
