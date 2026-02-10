import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'package:collection/collection.dart';

/// Servicio para gestionar compras in-app a través de Google Play Billing
class PlayBillingService {
  static final InAppPurchase _iap = InAppPurchase.instance;
  
  /// IDs de productos/suscripciones en Google Play Console
  static const Map<String, String> productIds = {
    'premium': 'premium_subscription',
    'professional': 'professional_subscription', 
    'enterprise': 'enterprise_subscription',
  };

  /// IDs de planes de prueba gratuita
  static const Map<String, String> trialProductIds = {
    'premium_trial': 'premium_subscription_trial',
    'professional_trial': 'professional_subscription_trial',
    'enterprise_trial': 'enterprise_subscription_trial',
  };

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  
  /// Inicializar el servicio de billing
  Future<bool> initialize() async {
    // Verificar disponibilidad
    final available = await _iap.isAvailable();
    if (!available) {
      return false;
    }

    // Configurar para Android
    if (defaultTargetPlatform == TargetPlatform.android) {
      // final iapAndroid = InAppPurchase.instance as InAppPurchaseAndroidPlatformAddition;
      // Configurar modo de prueba (solo para desarrollo)
      // iapAndroid.enablePendingPurchases(); // Eliminado: método ya no existe
    }

    // Escuchar actualizaciones de compras
    _purchaseSubscription = _iap.purchaseStream.listen(_handlePurchaseUpdate);

    return true;
  }

  /// Obtener productos disponibles
  Future<List<ProductDetails>> getProducts() async {
    final productIds = [...PlayBillingService.productIds.values, ...trialProductIds.values];
    final response = await _iap.queryProductDetails(productIds.toSet());
    
    return response.productDetails;
  }

  /// Comprar un producto
  Future<void> purchaseProduct(ProductDetails product, {bool isTrial = false}) async {
    try {
      final purchaseParam = PurchaseParam(
        productDetails: product,
        applicationUserName: null,
      );
      
      await _iap.buyConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      throw Exception('Error al procesar la compra: e');
    }
  }

  /// Restaurar compras
  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      throw Exception('Error al restaurar compras: e');
    }
  }

  /// Manejar actualizaciones de compras
  void _handlePurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      _handlePurchase(purchase);
    }
  }

  /// Procesar una compra individual
  void _handlePurchase(PurchaseDetails purchase) {
    if (purchase.status == PurchaseStatus.purchased) {
      // Compra exitosa - verificar y confirmar
      _verifyAndConfirmPurchase(purchase);
    } else if (purchase.status == PurchaseStatus.error) {
      // Error en la compra
      _handlePurchaseError(purchase);
    } else if (purchase.status == PurchaseStatus.pending) {
      // Compra pendiente
      _handlePendingPurchase(purchase);
    }
  }

  /// Verificar y confirmar compra con el servidor
  Future<void> _verifyAndConfirmPurchase(PurchaseDetails purchase) async {
    try {
      // TODO: Integrar con tu backend para verificar el recibo
      // await _verifyPurchaseWithServer(purchase);
      
      // Confirmar la compra con Google Play
      await _iap.completePurchase(purchase);
      
      // TODO: Actualizar estado de suscripción del usuario
    } catch (e) {
      // Manejar error de verificación
    }
  }

  /// Manejar error de compra
  void _handlePurchaseError(PurchaseDetails purchase) {
    // TODO: Mostrar mensaje de error al usuario
  }

  /// Manejar compra pendiente
  void _handlePendingPurchase(PurchaseDetails purchase) {
    // TODO: Mostrar estado pendiente al usuario
  }

  /// Obtener compras activas
  Future<List<PurchaseDetails>> getActivePurchases() async {
    List<PurchaseDetails> purchases = [];
    if (defaultTargetPlatform == TargetPlatform.android) {
      final InAppPurchaseAndroidPlatformAddition androidAddition =
          InAppPurchase.instance as InAppPurchaseAndroidPlatformAddition;
      final QueryPurchaseDetailsResponse response =
          await androidAddition.queryPastPurchases();
      purchases = response.pastPurchases;
    } else {
      // Fallback para otras plataformas si es necesario, o lanzar un error
      // Por ahora, solo devolvemos una lista vacía si no es Android
      purchases = [];
    }
    return purchases.where((purchase) =>
      purchase.status == PurchaseStatus.purchased
    ).toList();
  }

  /// Verificar si usuario tiene suscripción activa
  Future<bool> hasActiveSubscription(String productId) async {
    final purchases = await getActivePurchases();
    return purchases.any((purchase) => 
      purchase.productID == productId &&
      purchase.status == PurchaseStatus.purchased
    );
  }

  /// Liberar recursos
  void dispose() {
    _purchaseSubscription?.cancel();
  }

  /// Obtener producto por tipo de plan
  Future<ProductDetails?> getProductForPlan(String planType, {bool isTrial = false}) async {
    final products = await getProducts();
    final productId = isTrial ? trialProductIds[planType] : productIds[planType];
    
    return products.firstWhereOrNull(
      (product) => product.id == productId,
    );
  }
}