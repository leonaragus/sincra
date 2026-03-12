import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'package:collection/collection.dart';
import '../subscription/subscription_plan.dart';

class PlayBillingService {
  static final InAppPurchase _iap = InAppPurchase.instance;
  
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  
  Future<bool> initialize() async {
    final available = await _iap.isAvailable();
    if (!available) {
      return false;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    }

    _purchaseSubscription = _iap.purchaseStream.listen(_handlePurchaseUpdate);

    return true;
  }

  Future<List<ProductDetails>> getProducts() async {
    final ids = <String>{
      SubscriptionPlan.independent.monthlyId,
      SubscriptionPlan.independent.annualId,
      SubscriptionPlan.accountingFirm.monthlyId,
      SubscriptionPlan.accountingFirm.annualId,
      SubscriptionPlan.corporate.monthlyId,
      SubscriptionPlan.corporate.annualId,
    }.where((e) => e.isNotEmpty).toSet();
    final response = await _iap.queryProductDetails(ids);
    
    return response.productDetails;
  }

  Future<void> purchaseProduct(ProductDetails product, {bool isTrial = false}) async {
    try {
      final purchaseParam = PurchaseParam(
        productDetails: product,
        applicationUserName: null,
      );
      
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      throw Exception('Error al procesar la compra: $e');
    }
  }

  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      throw Exception('Error al restaurar compras: $e');
    }
  }

  void _handlePurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      _handlePurchase(purchase);
    }
  }

  void _handlePurchase(PurchaseDetails purchase) {
    if (purchase.status == PurchaseStatus.purchased) {
      _verifyAndConfirmPurchase(purchase);
    } else if (purchase.status == PurchaseStatus.error) {
      _handlePurchaseError(purchase);
    } else if (purchase.status == PurchaseStatus.pending) {
      _handlePendingPurchase(purchase);
    }
  }

  Future<void> _verifyAndConfirmPurchase(PurchaseDetails purchase) async {
    try {
      await _iap.completePurchase(purchase);
    } catch (e) {
    }
  }

  void _handlePurchaseError(PurchaseDetails purchase) {
  }

  void _handlePendingPurchase(PurchaseDetails purchase) {
  }

  Future<List<PurchaseDetails>> getActivePurchases() async {
    List<PurchaseDetails> purchases = [];
    if (defaultTargetPlatform == TargetPlatform.android) {
      final InAppPurchaseAndroidPlatformAddition androidAddition =
          _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final QueryPurchaseDetailsResponse response = await androidAddition.queryPastPurchases();
      purchases = response.pastPurchases;
    } else {
      purchases = [];
    }
    return purchases.where((purchase) =>
      purchase.status == PurchaseStatus.purchased
    ).toList();
  }

  Future<bool> hasActiveSubscription(String productId) async {
    final purchases = await getActivePurchases();
    return purchases.any((purchase) => 
      purchase.productID == productId &&
      purchase.status == PurchaseStatus.purchased
    );
  }

  void dispose() {
    _purchaseSubscription?.cancel();
  }

  Future<ProductDetails?> getProductForPlan(String planType, {bool isTrial = false}) async {
    final products = await getProducts();
    String? productId;
    if (planType == 'independent_monthly') {
      productId = SubscriptionPlan.independent.monthlyId;
    } else if (planType == 'independent_annual') {
      productId = SubscriptionPlan.independent.annualId;
    } else if (planType == 'accounting_monthly') {
      productId = SubscriptionPlan.accountingFirm.monthlyId;
    } else if (planType == 'accounting_annual') {
      productId = SubscriptionPlan.accountingFirm.annualId;
    } else if (planType == 'corporate_monthly') {
      productId = SubscriptionPlan.corporate.monthlyId;
    } else if (planType == 'corporate_annual') {
      productId = SubscriptionPlan.corporate.annualId;
    }
    
    return products.firstWhereOrNull(
      (product) => product.id == productId,
    );
  }

  Future<bool> hasAnyActiveSubscription() async {
    final ids = <String>{
      SubscriptionPlan.independent.monthlyId,
      SubscriptionPlan.independent.annualId,
      SubscriptionPlan.accountingFirm.monthlyId,
      SubscriptionPlan.accountingFirm.annualId,
      SubscriptionPlan.corporate.monthlyId,
      SubscriptionPlan.corporate.annualId,
    }.where((e) => e.isNotEmpty).toSet();
    final purchases = await getActivePurchases();
    return purchases.any((p) => ids.contains(p.productID) && p.status == PurchaseStatus.purchased);
  }
}
