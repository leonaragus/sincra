import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'purchase_handler.dart';
import 'subscription_plan.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  bool _isAnnual = false;

  // --- Estado para In-App Purchase ---
  late final PurchaseHandler _purchaseHandler;
  late final Stream<List<ProductDetails>> _productsStream;
  StreamSubscription<PurchaseDetails>? _purchaseStatusSubscription;
  bool _isPurchaseInProgress = false;

  @override
  void initState() {
    super.initState();
    _purchaseHandler = PurchaseHandler();
    _purchaseHandler.initialize();
    _productsStream = _purchaseHandler.productsStream;

    // Escuchamos las actualizaciones de las compras para dar feedback al usuario.
    _purchaseStatusSubscription = _purchaseHandler.purchaseStatusStream.listen((purchaseDetails) {
      _handlePurchaseUpdate(purchaseDetails);
    });
  }

  void _handlePurchaseUpdate(PurchaseDetails purchaseDetails) {
    if (!mounted) return;
    setState(() {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _isPurchaseInProgress = true;
      } else {
        _isPurchaseInProgress = false;
        
        if (purchaseDetails.status == PurchaseStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error en la compra: ${purchaseDetails.error?.message ?? 'Ocurrió un error.'} '))
          );
        } else if (purchaseDetails.status == PurchaseStatus.purchased) {
            // El PurchaseHandler se encargará de la verificación y guardado.
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('¡Gracias por tu compra! Activando tu plan...'), backgroundColor: Colors.green)
            );
            // Cerramos la pantalla de precios después de un momento.
            Future.delayed(const Duration(seconds: 3), () {
               if(mounted) Navigator.of(context).pop();
            });
        }
      }
    });
  }

  @override
  void dispose() {
    _purchaseStatusSubscription?.cancel();
    _purchaseHandler.dispose();
    super.dispose();
  }

  ProductDetails? _findProductDetails(List<ProductDetails> products, String productId) {
    try {
      return products.firstWhere((p) => p.id == productId);
    } catch (e) {
      return null; // Producto no encontrado en la tienda
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planes Premium'),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          StreamBuilder<List<ProductDetails>>(
            stream: _productsStream,
            builder: (context, snapshot) {
              // 1. Manejo de errores del Stream
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Error al cargar los planes desde la tienda.\n(${snapshot.error})',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => _purchaseHandler.loadProducts(),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // 2. Estado de carga inicial
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // 3. Mostrar contenido (con o sin productos de la tienda)
              final products = snapshot.data ?? [];
              return _buildPricingContent(products);
            },
          ),
          
          // Overlay de carga durante el proceso de compra
          if (_isPurchaseInProgress)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 20),
                    Text('Procesando compra...', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('Por favor, esperá un momento.', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPricingContent(List<ProductDetails> products) {
    final independentProduct = _isAnnual ? _findProductDetails(products, SubscriptionPlan.independent.annualId) : _findProductDetails(products, SubscriptionPlan.independent.monthlyId);
    final firmProduct = _isAnnual ? _findProductDetails(products, SubscriptionPlan.accountingFirm.annualId) : _findProductDetails(products, SubscriptionPlan.accountingFirm.monthlyId);
    final corporateProduct = _isAnnual ? _findProductDetails(products, SubscriptionPlan.corporate.annualId) : _findProductDetails(products, SubscriptionPlan.corporate.monthlyId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildBillingToggle(),
          const SizedBox(height: 24),
          _buildPlanCard(
            plan: SubscriptionPlan.independent,
            productDetails: independentProduct,
            isRecommended: false,
          ),
          const SizedBox(height: 16),
          _buildPlanCard(
            plan: SubscriptionPlan.accountingFirm,
            productDetails: firmProduct,
            isRecommended: true,
          ),
          const SizedBox(height: 16),
          _buildPlanCard(
            plan: SubscriptionPlan.corporate,
            productDetails: corporateProduct,
            isRecommended: false,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  String formatCurrency(String amount) {
    final double val = double.tryParse(amount) ?? 0.0;
    return '\$${AppNumberFormatter.format(val)}';
  }

  Widget _buildPlanCard({
    required SubscriptionPlan plan,
    required ProductDetails? productDetails,
    required bool isRecommended,
  }) {
    final String price = productDetails?.price ?? formatCurrency(_isAnnual ? plan.annualPrice : plan.monthlyPrice);
    final bool isAvailable = productDetails != null;

    return Card(
      elevation: isRecommended ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isRecommended ? AppColors.accentBlue : AppColors.glassBorder,
          width: isRecommended ? 2 : 1,
        ),
      ),
      color: AppColors.glassFill,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(plan.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isRecommended ? AppColors.accentBlue : AppColors.textPrimary)),
            if (isRecommended) ...[
              const SizedBox(height: 4),
              const Text('RECOMENDADO', style: TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(price, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(_isAnnual ? '/ año' : '/ mes', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                ),
              ],
            ),
            if (!isAvailable)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Precio estimado (Sincronizando con tienda...)', 
                  style: TextStyle(color: AppColors.textSecondary.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            if (_isAnnual) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('AHORRÁS 2 MESES GRATIS', textAlign: TextAlign.center, style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
              )
            ],
            const SizedBox(height: 24),
            _buildFeatureItem(Icons.business, plan.isUnlimited ? 'Empresas Ilimitadas' : 'Hasta ${plan.maxCompanies} empresas'),
            _buildFeatureItem(Icons.people, plan.isUnlimited ? 'Empleados Ilimitados' : 'Hasta ${plan.maxEmployeesPerCompany} empleados por empresa'),
            _buildFeatureItem(Icons.local_fire_department_rounded, plan.unlimitedClaudeCalls ? 'Llamadas a IA Ilimitadas' : '${plan.claudeCallsPerMonth} llamadas a IA por mes'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isAvailable && !_isPurchaseInProgress 
                  ? () => _purchaseHandler.buyProduct(productDetails)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isRecommended ? AppColors.accentBlue : AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                disabledForegroundColor: Colors.white.withOpacity(0.7),
              ),
              child: const Text('Suscribirse', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          'Elegí el plan que se ajuste a tus necesidades.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 16, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildBillingToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton(label: 'Mensual', active: !_isAnnual, onTap: () => setState(() => _isAnnual = false)),
          _buildToggleButton(label: 'Anual', active: _isAnnual, onTap: () => setState(() => _isAnnual = true)),
        ],
      ),
    );
  }

  Widget _buildToggleButton({required String label, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.accentBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppColors.textSecondary,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.accentBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
