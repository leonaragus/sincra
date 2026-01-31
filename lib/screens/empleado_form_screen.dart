// ========================================================================
// FORMULARIO DE EMPLEADO
// Crear/editar empleado completo
// ========================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/empleado_completo.dart';
import '../services/empleados_service.dart';
import '../theme/app_colors.dart';
import '../utils/validaciones_arca.dart';

class EmpleadoFormScreen extends StatefulWidget {
  final EmpleadoCompleto? empleado; // null = crear nuevo
  final String? empresaCuit;
  final String? empresaNombre;
  
  const EmpleadoFormScreen({
    super.key,
    this.empleado,
    this.empresaCuit,
    this.empresaNombre,
  });
  
  @override
  State<EmpleadoFormScreen> createState() => _EmpleadoFormScreenState();
}

class _EmpleadoFormScreenState extends State<EmpleadoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _guardando = false;
  
  // Controllers
  late TextEditingController _cuilController;
  late TextEditingController _nombreCompletoController;
  late TextEditingController _apellidoController;
  late TextEditingController _nombreController;
  late TextEditingController _domicilioController;
  late TextEditingController _localidadController;
  late TextEditingController _codigoPostalController;
  late TextEditingController _telefonoController;
  late TextEditingController _emailController;
  late TextEditingController _categoriaController;
  late TextEditingController _cbuController;
  late TextEditingController _bancoController;
  late TextEditingController _codigoRnosController;
  late TextEditingController _obraSocialController;
  late TextEditingController _notasController;
  
  // Valores
  DateTime? _fechaNacimiento;
  DateTime? _fechaIngreso;
  String _provincia = 'Buenos Aires';
  String _sector = 'sanidad';
  String _jurisdiccion = 'privado';
  String _estado = 'activo';
  int _modalidadContratacion = 1;
  String? _cctCodigo;
  
  final List<String> _provincias = [
    'Buenos Aires', 'CABA', 'Catamarca', 'Chaco', 'Chubut', 'Córdoba',
    'Corrientes', 'Entre Ríos', 'Formosa', 'Jujuy', 'La Pampa', 'La Rioja',
    'Mendoza', 'Misiones', 'Neuquén', 'Río Negro', 'Salta', 'San Juan',
    'San Luis', 'Santa Cruz', 'Santa Fe', 'Santiago del Estero',
    'Tierra del Fuego', 'Tucumán'
  ];
  
  @override
  void initState() {
    super.initState();
    
    // Inicializar controllers
    final emp = widget.empleado;
    
    _cuilController = TextEditingController(text: emp?.cuil ?? '');
    _nombreCompletoController = TextEditingController(text: emp?.nombreCompleto ?? '');
    _apellidoController = TextEditingController(text: emp?.apellido ?? '');
    _nombreController = TextEditingController(text: emp?.nombre ?? '');
    _domicilioController = TextEditingController(text: emp?.domicilio ?? '');
    _localidadController = TextEditingController(text: emp?.localidad ?? '');
    _codigoPostalController = TextEditingController(text: emp?.codigoPostal ?? '');
    _telefonoController = TextEditingController(text: emp?.telefono ?? '');
    _emailController = TextEditingController(text: emp?.email ?? '');
    _categoriaController = TextEditingController(text: emp?.categoria ?? '');
    _cbuController = TextEditingController(text: emp?.cbu ?? '');
    _bancoController = TextEditingController(text: emp?.banco ?? '');
    _codigoRnosController = TextEditingController(text: emp?.codigoRnos ?? '');
    _obraSocialController = TextEditingController(text: emp?.obraSocialNombre ?? '');
    _notasController = TextEditingController(text: emp?.notas ?? '');
    
    // Valores iniciales
    if (emp != null) {
      _fechaNacimiento = emp.fechaNacimiento;
      _fechaIngreso = emp.fechaIngreso;
      _provincia = emp.provincia;
      _sector = emp.sector ?? 'sanidad';
      _jurisdiccion = emp.jurisdiccion ?? 'privado';
      _estado = emp.estado;
      _modalidadContratacion = emp.modalidadContratacion;
      _cctCodigo = emp.cctCodigo;
    } else {
      _fechaIngreso = DateTime.now();
    }
  }
  
  @override
  void dispose() {
    _cuilController.dispose();
    _nombreCompletoController.dispose();
    _apellidoController.dispose();
    _nombreController.dispose();
    _domicilioController.dispose();
    _localidadController.dispose();
    _codigoPostalController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _categoriaController.dispose();
    _cbuController.dispose();
    _bancoController.dispose();
    _codigoRnosController.dispose();
    _obraSocialController.dispose();
    _notasController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final esNuevo = widget.empleado == null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(esNuevo ? 'Nuevo Empleado' : 'Editar Empleado'),
        backgroundColor: AppColors.primary,
        actions: [
          if (!esNuevo)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmarBaja,
              tooltip: 'Dar de baja',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSeccion('Identificación', [
              _buildCuilField(),
              _buildTextField('Nombre completo *', _nombreCompletoController, required: true),
              Row(
                children: [
                  Expanded(child: _buildTextField('Apellido', _apellidoController)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTextField('Nombre', _nombreController)),
                ],
              ),
              _buildDateField('Fecha de nacimiento', _fechaNacimiento, (fecha) {
                setState(() => _fechaNacimiento = fecha);
              }),
            ]),
            
            _buildSeccion('Datos Laborales', [
              _buildDateField('Fecha de ingreso *', _fechaIngreso, (fecha) {
                setState(() => _fechaIngreso = fecha);
              }, required: true),
              _buildTextField('Categoría *', _categoriaController, required: true),
              _buildDropdown('Sector', _sector, ['sanidad', 'docente', 'cct_generico'], (valor) {
                setState(() => _sector = valor!);
              }),
              _buildDropdown('Jurisdicción', _jurisdiccion, 
                ['privado', 'provincial', 'municipal', 'nacional'], (valor) {
                setState(() => _jurisdiccion = valor!);
              }),
              _buildTextField('CCT Código (ej: 122/75)', TextEditingController(text: _cctCodigo),
                onChanged: (v) => _cctCodigo = v),
            ]),
            
            _buildSeccion('Ubicación', [
              _buildDropdown('Provincia *', _provincia, _provincias, (valor) {
                setState(() => _provincia = valor!);
              }),
              _buildTextField('Localidad', _localidadController),
              _buildTextField('Domicilio', _domicilioController),
              _buildTextField('Código Postal', _codigoPostalController),
            ]),
            
            _buildSeccion('Datos Bancarios', [
              _buildCbuField(),
              _buildTextField('Banco', _bancoController),
            ]),
            
            _buildSeccion('Obra Social', [
              _buildRnosField(),
              _buildTextField('Nombre Obra Social', _obraSocialController),
            ]),
            
            _buildSeccion('Contacto', [
              _buildTextField('Teléfono', _telefonoController),
              _buildTextField('Email', _emailController, keyboardType: TextInputType.emailAddress),
            ]),
            
            _buildSeccion('Modalidad y Estado', [
              _buildDropdown('Modalidad Contratación', _modalidadContratacion.toString(),
                ['1', '2', '3', '4'], (valor) {
                setState(() => _modalidadContratacion = int.parse(valor!));
              }),
              _buildDropdown('Estado', _estado, ['activo', 'suspendido', 'de_baja', 'licencia'], (valor) {
                setState(() => _estado = valor!);
              }),
            ]),
            
            _buildSeccion('Notas', [
              _buildTextField('Notas adicionales', _notasController, 
                maxLines: 3),
            ]),
            
            const SizedBox(height: 24),
            
            // Botón guardar
            ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _guardando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(esNuevo ? 'CREAR EMPLEADO' : 'GUARDAR CAMBIOS',
                      style: const TextStyle(fontSize: 16)),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSeccion(String titulo, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const Divider(),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
  
  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator ?? (required 
          ? (value) => value?.isEmpty == true ? 'Campo requerido' : null
          : null),
        onChanged: onChanged,
      ),
    );
  }
  
  Widget _buildCuilField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _cuilController,
        decoration: InputDecoration(
          labelText: 'CUIL / CUIT *',
          border: const OutlineInputBorder(),
          suffixIcon: _cuilController.text.isNotEmpty
              ? Icon(
                  ValidacionesARCA.validarCUIL(_cuilController.text)
                      ? Icons.check_circle
                      : Icons.error,
                  color: ValidacionesARCA.validarCUIL(_cuilController.text)
                      ? Colors.green
                      : Colors.red,
                )
              : null,
        ),
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value == null || value.isEmpty) return 'CUIL requerido';
          if (!ValidacionesARCA.validarCUIL(value)) return 'CUIL inválido (verificar dígitos)';
          return null;
        },
        onChanged: (_) => setState(() {}),
      ),
    );
  }
  
  Widget _buildCbuField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _cbuController,
        decoration: InputDecoration(
          labelText: 'CBU (22 dígitos)',
          border: const OutlineInputBorder(),
          suffixIcon: _cbuController.text.isNotEmpty
              ? Icon(
                  ValidacionesARCA.validarCBU(_cbuController.text)
                      ? Icons.check_circle
                      : Icons.error,
                  color: ValidacionesARCA.validarCBU(_cbuController.text)
                      ? Colors.green
                      : Colors.red,
                )
              : null,
        ),
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value != null && value.isNotEmpty && !ValidacionesARCA.validarCBU(value)) {
            return 'CBU inválido (debe ser 22 dígitos)';
          }
          return null;
        },
        onChanged: (_) => setState(() {}),
      ),
    );
  }
  
  Widget _buildRnosField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _codigoRnosController,
        decoration: InputDecoration(
          labelText: 'Código RNOS (6 dígitos)',
          border: const OutlineInputBorder(),
          suffixIcon: _codigoRnosController.text.isNotEmpty
              ? Icon(
                  ValidacionesARCA.validarCodigoRNOS(_codigoRnosController.text)
                      ? Icons.check_circle
                      : Icons.warning,
                  color: ValidacionesARCA.validarCodigoRNOS(_codigoRnosController.text)
                      ? Colors.green
                      : Colors.orange,
                )
              : null,
        ),
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
      ),
    );
  }
  
  Widget _buildDateField(
    String label,
    DateTime? fecha,
    Function(DateTime) onChanged, {
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(label),
        subtitle: Text(fecha != null 
          ? DateFormat('dd/MM/yyyy').format(fecha)
          : 'No establecida'),
        trailing: const Icon(Icons.calendar_today),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey[400]!),
        ),
        onTap: () async {
          final selected = await showDatePicker(
            context: context,
            initialDate: fecha ?? DateTime.now(),
            firstDate: DateTime(1950),
            lastDate: DateTime(2100),
          );
          if (selected != null) {
            onChanged(selected);
          }
        },
      ),
    );
  }
  
  Widget _buildDropdown(
    String label,
    String valor,
    List<String> opciones,
    Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: valor,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: opciones.map((o) {
          return DropdownMenuItem(value: o, child: Text(o));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
  
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_fechaIngreso == null) {
      _mostrarError('Debe seleccionar una fecha de ingreso');
      return;
    }
    
    setState(() => _guardando = true);
    
    try {
      final empleado = EmpleadoCompleto(
        cuil: _cuilController.text.trim(),
        nombreCompleto: _nombreCompletoController.text.trim(),
        apellido: _apellidoController.text.trim().isEmpty ? null : _apellidoController.text.trim(),
        nombre: _nombreController.text.trim().isEmpty ? null : _nombreController.text.trim(),
        fechaNacimiento: _fechaNacimiento,
        domicilio: _domicilioController.text.trim().isEmpty ? null : _domicilioController.text.trim(),
        localidad: _localidadController.text.trim().isEmpty ? null : _localidadController.text.trim(),
        codigoPostal: _codigoPostalController.text.trim().isEmpty ? null : _codigoPostalController.text.trim(),
        telefono: _telefonoController.text.trim().isEmpty ? null : _telefonoController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        fechaIngreso: _fechaIngreso!,
        categoria: _categoriaController.text.trim(),
        sector: _sector,
        jurisdiccion: _jurisdiccion,
        provincia: _provincia,
        cctCodigo: _cctCodigo,
        cbu: _cbuController.text.trim().isEmpty ? null : _cbuController.text.trim(),
        banco: _bancoController.text.trim().isEmpty ? null : _bancoController.text.trim(),
        codigoRnos: _codigoRnosController.text.trim().isEmpty ? null : _codigoRnosController.text.trim(),
        obraSocialNombre: _obraSocialController.text.trim().isEmpty ? null : _obraSocialController.text.trim(),
        modalidadContratacion: _modalidadContratacion,
        estado: _estado,
        empresaCuit: widget.empresaCuit,
        empresaNombre: widget.empresaNombre,
        notas: _notasController.text.trim().isEmpty ? null : _notasController.text.trim(),
      );
      
      // Calcular antigüedad
      empleado.calcularAntiguedad();
      
      // Guardar
      await EmpleadosService.guardarEmpleado(empleado);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.empleado == null 
              ? 'Empleado creado exitosamente' 
              : 'Empleado actualizado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // true = hubo cambios
      }
    } catch (e) {
      _mostrarError('Error guardando empleado: $e');
    }
    
    setState(() => _guardando = false);
  }
  
  Future<void> _confirmarBaja() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Baja'),
        content: const Text('¿Está seguro de dar de baja a este empleado? Esta acción no eliminará el registro, solo cambiará su estado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Dar de Baja'),
          ),
        ],
      ),
    );
    
    if (confirmar == true) {
      try {
        await EmpleadosService.darDeBajaEmpleado(
          widget.empleado!.cuil,
          empresaCuit: widget.empresaCuit,
          motivo: 'Baja solicitada desde formulario',
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Empleado dado de baja'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        _mostrarError('Error dando de baja: $e');
      }
    }
  }
  
  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
      ),
    );
  }
}
