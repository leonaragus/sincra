import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../services/paritarias_service.dart';
import '../services/sanidad_paritarias_service.dart';
import '../services/cct_cloud_service.dart';
import '../services/parametros_legales_service.dart';

class ServiceStatusScreen extends StatefulWidget {
  const ServiceStatusScreen({super.key});

  @override
  State<ServiceStatusScreen> createState() => _ServiceStatusScreenState();
}

class _ServiceStatusScreenState extends State<ServiceStatusScreen> {
  bool _loading = false;
  Map<String, dynamic> _statusDocentes = {};
  Map<String, dynamic> _statusSanidad = {};
  Map<String, dynamic> _statusCCT = {};

  @override
  void initState() {
    super.initState();
    _checkAllServices();
  }

  Future<void> _checkAllServices() async {
    setState(() => _loading = true);

    // 1. Docentes
    try {
      final res = await ParitariasService.sincronizarParitarias();
      _statusDocentes = res;
    } catch (e) {
      _statusDocentes = {'success': false, 'error': e.toString(), 'modo': 'error'};
    }

    // 2. Sanidad
    try {
      final res = await SanidadParitariasService.sincronizarParitarias();
      _statusSanidad = res;
    } catch (e) {
      _statusSanidad = {'success': false, 'error': e.toString(), 'modo': 'error'};
    }

    // 3. CCT General
    try {
      final res = await CCTCloudService.sincronizarCCT();
      _statusCCT = res;
    } catch (e) {
      _statusCCT = {'success': false, 'error': e.toString(), 'modo': 'error'};
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Estado de Servicios (Robots)', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.accentEmerald),
            onPressed: _loading ? null : _checkAllServices,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Diagnóstico de Conectividad y Sincronización',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 20),
                _buildServiceCard(
                  'Robot Paritarias Docentes',
                  Icons.school,
                  _statusDocentes,
                  'Tabla: maestro_paritarias',
                ),
                const SizedBox(height: 16),
                _buildServiceCard(
                  'Robot Paritarias Sanidad',
                  Icons.local_hospital,
                  _statusSanidad,
                  'Tabla: maestro_paritarias_sanidad',
                ),
                const SizedBox(height: 16),
                _buildServiceCard(
                  'Robot CCT General',
                  Icons.gavel,
                  _statusCCT,
                  'Tabla: cct_master',
                ),
              ],
            ),
    );
  }

  Widget _buildServiceCard(String title, IconData icon, Map<String, dynamic> status, String details) {
    final bool success = status['success'] == true;
    final String modo = status['modo']?.toString() ?? 'unknown';
    final DateTime? fecha = status['fecha'] as DateTime?;
    final String error = status['error']?.toString() ?? '';
    final List? data = status['data'] as List?;
    final int count = data?.length ?? 0;

    Color color;
    IconData statusIcon;
    String statusText;

    if (success) {
      color = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'OPERATIVO ($modo)';
    } else if (modo == 'offline') {
      color = Colors.orange;
      statusIcon = Icons.wifi_off;
      statusText = 'OFFLINE (Usando caché)';
    } else {
      color = Colors.red;
      statusIcon = Icons.error;
      statusText = 'ERROR';
    }

    return Card(
      color: AppColors.glassFillStrong,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.textPrimary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: color, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: AppColors.glassBorder, height: 24),
            _buildInfoRow('Fuente', details),
            _buildInfoRow('Registros obtenidos', count.toString()),
            _buildInfoRow('Última actualización', fecha != null ? DateFormat('dd/MM/yyyy HH:mm:ss').format(fecha) : 'Nunca'),
            if (error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Error: $error',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
