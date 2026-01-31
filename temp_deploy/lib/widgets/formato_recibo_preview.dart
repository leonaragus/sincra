import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/formato_recibo.dart';

/// Widget que muestra un preview visual del formato de recibo.
class FormatoReciboPreview extends StatelessWidget {
  final FormatoRecibo formato;
  final bool isSelected;

  const FormatoReciboPreview({
    super.key,
    required this.formato,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.pastelBlue : AppColors.glassBorder,
          width: isSelected ? 3 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildPreviewContent(),
      ),
    );
  }

  Widget _buildPreviewContent() {
    switch (formato.id) {
      case 'clasico_lct':
        return _buildClasicoLCT();
      case 'administrativo_a4':
        return _buildAdministrativoA4();
      case 'digital_moderno':
        return _buildDigitalModerno();
      default:
        return const SizedBox();
    }
  }

  Widget _buildClasicoLCT() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header empresa
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.pastelBlue.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.business, size: 16, color: AppColors.pastelBlue),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 8,
                        width: 80,
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 6,
                        width: 60,
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Tabla conceptos
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.glassFillStrong,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: const BoxDecoration(
                      color: AppColors.glassFill,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _buildBar(40, 6)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildBar(30, 6)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildBar(30, 6)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildBar(90, 4),
                          _buildBar(85, 4),
                          _buildBar(75, 4),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Footer empleado
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                _buildBar(50, 5),
                const SizedBox(width: 8),
                _buildBar(40, 5),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdministrativoA4() {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          // Original
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.glassFillStrong,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.pastelOrange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'ORIGINAL',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: AppColors.pastelOrange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildBar(60, 6),
                  const SizedBox(height: 4),
                  _buildBar(45, 5),
                  const Spacer(),
                  Container(
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.glassFill,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _buildBar(25, 4)),
                        const SizedBox(width: 4),
                        Expanded(child: _buildBar(25, 4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Duplicado
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.glassFillStrong,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'DUPLICADO',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildBar(60, 6),
                  const SizedBox(height: 4),
                  _buildBar(45, 5),
                  const Spacer(),
                  Container(
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.glassFill,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _buildBar(25, 4)),
                        const SizedBox(width: 4),
                        Expanded(child: _buildBar(25, 4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalModerno() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header moderno
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.pastelMint.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.business, size: 20, color: AppColors.pastelMint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBar(70, 8),
                    const SizedBox(height: 4),
                    _buildBar(50, 6),
                  ],
                ),
              ),
              // QR Code placeholder
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: AppColors.glassFill,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: const Icon(Icons.qr_code, size: 20, color: AppColors.pastelMint),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Tabla limpia
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.glassFillStrong,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildBar(40, 5)),
                        const SizedBox(width: 6),
                        Expanded(child: _buildBar(30, 5)),
                        const SizedBox(width: 6),
                        Expanded(child: _buildBar(30, 5)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildBar(85, 4),
                          _buildBar(80, 4),
                          _buildBar(75, 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Firma digital
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 25,
                  decoration: BoxDecoration(
                    color: AppColors.glassFill,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.pastelMint.withValues(alpha: 0.5)),
                  ),
                  child: const Center(
                    child: Icon(Icons.draw, size: 14, color: AppColors.pastelMint),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 35,
                height: 25,
                decoration: BoxDecoration(
                  color: AppColors.pastelMint.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.verified, size: 16, color: AppColors.pastelMint),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBar(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
