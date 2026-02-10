
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/contabilidad/cuenta_contable.dart';
import '../../models/contabilidad/mapeo_contable.dart';
import '../../services/contabilidad_config_service.dart';

class ConfiguracionContableScreen extends StatefulWidget {
  const ConfiguracionContableScreen({super.key});

  @override
  State<ConfiguracionContableScreen> createState() => _ConfiguracionContableScreenState();
}

class _ConfiguracionContableScreenState extends State<ConfiguracionContableScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  PerfilContable? _perfil;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    final p = await ContabilidadConfigService.cargarPerfil();
    setState(() {
      _perfil = p;
      _isLoading = false;
    });
  }

  Future<void> _guardarCambios() async {
    if (_perfil != null) {
      await ContabilidadConfigService.guardarPerfil(_perfil!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración guardada exitosamente')),
      );
    }
  }

  void _agregarCuenta() {
    final codigoCtrl = TextEditingController();
    final nombreCtrl = TextEditingController();
    ImputacionDefecto imputacion = ImputacionDefecto.debe;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Nueva Cuenta Contable'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codigoCtrl,
                decoration: const InputDecoration(labelText: 'Código (ej: 5.1.01)'),
              ),
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 10),
              DropdownButton<ImputacionDefecto>(
                value: imputacion,
                isExpanded: true,
                items: ImputacionDefecto.values.map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e == ImputacionDefecto.debe ? 'Debe (Activo/Gasto)' : 'Haber (Pasivo/Ingreso)'),
                )).toList(),
                onChanged: (v) => setStateDialog(() => imputacion = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (codigoCtrl.text.isNotEmpty && nombreCtrl.text.isNotEmpty) {
                  setState(() {
                    _perfil!.planDeCuentas.add(CuentaContable(
                      codigo: codigoCtrl.text,
                      nombre: nombreCtrl.text,
                      imputacionDefecto: imputacion,
                    ));
                  });
                  _guardarCambios();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _agregarMapeo() {
    final nombreCtrl = TextEditingController();
    final claveCtrl = TextEditingController();
    TipoConceptoContable tipo = TipoConceptoContable.conceptoEspecifico;
    String? cuentaSeleccionada = _perfil!.planDeCuentas.isNotEmpty ? _perfil!.planDeCuentas.first.codigo : null;
    ImputacionDefecto imputacion = ImputacionDefecto.debe;

    if (cuentaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primero cree cuentas contables')));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Nuevo Mapeo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre descriptivo'),
                ),
                const SizedBox(height: 10),
                DropdownButton<TipoConceptoContable>(
                  value: tipo,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: TipoConceptoContable.conceptoEspecifico, child: Text('Concepto Específico')),
                    DropdownMenuItem(value: TipoConceptoContable.agrupacion, child: Text('Agrupación (Total Rem/No Rem)')),
                    DropdownMenuItem(value: TipoConceptoContable.neto, child: Text('Neto a Pagar')),
                  ],
                  onChanged: (v) => setStateDialog(() => tipo = v!),
                ),
                if (tipo != TipoConceptoContable.neto)
                  TextField(
                    controller: claveCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Clave/Código (ej: SUELDO_BASICO)',
                      helperText: 'Para Agrupación usar: TOTAL_REMUNERATIVO, TOTAL_NO_REMUNERATIVO, TOTAL_DESCUENTOS',
                    ),
                  ),
                const SizedBox(height: 10),
                DropdownButton<String>(
                  value: cuentaSeleccionada,
                  isExpanded: true,
                  hint: const Text('Seleccionar Cuenta'),
                  items: _perfil!.planDeCuentas.map((c) => DropdownMenuItem(
                    value: c.codigo,
                    child: Text('${c.codigo} - ${c.nombre}'),
                  )).toList(),
                  onChanged: (v) => setStateDialog(() => cuentaSeleccionada = v),
                ),
                const SizedBox(height: 10),
                DropdownButton<ImputacionDefecto>(
                  value: imputacion,
                  isExpanded: true,
                  items: ImputacionDefecto.values.map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e == ImputacionDefecto.debe ? 'Al Debe' : 'Al Haber'),
                  )).toList(),
                  onChanged: (v) => setStateDialog(() => imputacion = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (nombreCtrl.text.isNotEmpty && cuentaSeleccionada != null) {
                  setState(() {
                    _perfil!.mapeos.add(MapeoContable(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      nombre: nombreCtrl.text,
                      tipo: tipo,
                      claveReferencia: tipo == TipoConceptoContable.neto ? null : claveCtrl.text,
                      cuentaCodigo: cuentaSeleccionada!,
                      imputacion: imputacion,
                    ));
                  });
                  _guardarCambios();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Configuración Contable'),
        backgroundColor: AppColors.surface,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Plan de Cuentas'),
            Tab(text: 'Mapeo de Conceptos'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPlanDeCuentas(),
                _buildMapeos(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            _agregarCuenta();
          } else {
            _agregarMapeo();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPlanDeCuentas() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _perfil!.planDeCuentas.length,
      itemBuilder: (context, index) {
        final cuenta = _perfil!.planDeCuentas[index];
        return Card(
          color: AppColors.surface,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: cuenta.imputacionDefecto == ImputacionDefecto.debe ? Colors.blue[100] : Colors.green[100],
              child: Text(cuenta.imputacionDefecto == ImputacionDefecto.debe ? 'D' : 'H'),
            ),
            title: Text('${cuenta.codigo} - ${cuenta.nombre}'),
            subtitle: Text(cuenta.imputacionDefecto == ImputacionDefecto.debe ? 'Saldo Deudor' : 'Saldo Acreedor'),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                setState(() {
                  _perfil!.planDeCuentas.removeAt(index);
                });
                _guardarCambios();
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapeos() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _perfil!.mapeos.length,
      itemBuilder: (context, index) {
        final mapeo = _perfil!.mapeos[index];
        final cuenta = _perfil!.planDeCuentas.firstWhere(
          (c) => c.codigo == mapeo.cuentaCodigo,
          orElse: () => CuentaContable(codigo: mapeo.cuentaCodigo, nombre: '?', imputacionDefecto: ImputacionDefecto.debe),
        );

        return Card(
          color: AppColors.surface,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(mapeo.nombre),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tipo: ${mapeo.tipo.name} ${mapeo.claveReferencia != null ? '(${mapeo.claveReferencia})' : ''}'),
                Text('Cuenta: ${cuenta.codigo} - ${cuenta.nombre}'),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                setState(() {
                  _perfil!.mapeos.removeAt(index);
                });
                _guardarCambios();
              },
            ),
          ),
        );
      },
    );
  }
}
