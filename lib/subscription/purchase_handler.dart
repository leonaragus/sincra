
import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'subscription_plan.dart';
import 'subscription_service.dart'; // Importamos el servicio

class PurchaseHandler {
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  final Set<String> _productIds = {
    SubscriptionPlan.independent.monthlyId,
    SubscriptionPlan.independent.annualId,
    SubscriptionPlan.accountingFirm.monthlyId,
    SubscriptionPlan.accountingFirm.annualId,
    SubscriptionPlan.corporate.monthlyId,
    SubscriptionPlan.corporate.annualId,
  };

  final StreamController<List<ProductDetails>> _productsController = StreamController<List<ProductDetails>>.broadcast();
  Stream<List<ProductDetails>> get productsStream => _productsController.stream;

  final StreamController<PurchaseDetails> _purchaseStatusController = StreamController<PurchaseDetails>.broadcast();
  Stream<PurchaseDetails> get purchaseStatusStream => _purchaseStatusController.stream;

  void initialize() {
    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      print("Error en el stream de compras: $error");
    });

    loadProducts();
  }

  Future<void> loadProducts() async {
    try {
      final bool available = await _iap.isAvailable();
      if (!available) {
        _productsController.add([]); // Emitir lista vacía si no hay tienda
        return;
      }

      final ProductDetailsResponse response = await _iap.queryProductDetails(_productIds);
      
      if (response.notFoundIDs.isNotEmpty) {
        print('Productos no encontrados: ${response.notFoundIDs}');
      }

      _productsController.add(response.productDetails);
    } catch (e) {
      print('Error al cargar productos de la tienda: $e');
      _productsController.addError(e); // Emitir el error al stream
    }
  }
  Future<void> buyProduct(ProductDetails productDetails) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    
    try {
      // Intentamos una compra de suscripción (non-consumable)
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      print('Error al iniciar compra: $e');
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      _purchaseStatusController.add(purchaseDetails);

      if (purchaseDetails.status == PurchaseStatus.purchased) {
        // La compra fue exitosa, ahora la verificamos y activamos.
        _handleSuccessfulPurchase(purchaseDetails);
      }
      if (purchaseDetails.pendingCompletePurchase) {
        _iap.completePurchase(purchaseDetails);
      }
      if (purchaseDetails.status == PurchaseStatus.error) {
        print("Error en la compra: ${purchaseDetails.error?.message}");
      }
    }
  }

  // --- MÉTODO CLAVE ACTUALIZADO ---
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) async {
    print('Compra exitosa para el producto: ${purchaseDetails.productID}. Procediendo a activar...');

    // 1. Llamamos al SubscriptionService para que valide y guarde en Supabase
    final bool success = await SubscriptionService.activateSubscription(purchaseDetails);

    if (success) {
      // 2. Solo si la activación fue exitosa, marcamos la compra como completada.
      // Esto asegura que si falla la activación, Google Play intentará entregar la compra de nuevo más tarde.
      await _iap.completePurchase(purchaseDetails);
      print('Compra completada y marcada en la tienda.');
    } else {
      // Si la activación falló, no completamos la compra para que el sistema reintente más tarde.
      print('La activación de la suscripción falló. La compra no se marcará como completada para permitir reintentos.');
    }
  }

  void dispose() {
    _subscription.cancel();
    _productsController.close();
    _purchaseStatusController.close();
  }
}
