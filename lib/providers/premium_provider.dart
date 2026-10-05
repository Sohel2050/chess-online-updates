import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/services/in_app_purchase_service.dart';
import 'package:logger/logger.dart';

class PremiumProvider with ChangeNotifier {
  final Logger _logger = Logger();
  final InAppPurchaseService _purchaseService = InAppPurchaseService();

  bool _isPremium = false;
  bool _isPremiumLoading = false;
  List<PremiumProduct> _availableProducts = [];
  ChessUser? _currentUser;
  final StreamController<bool> _purchaseStatusController =
      StreamController<bool>.broadcast();

  // Premium features
  bool get isPremium => _isPremium;
  bool get isPremiumLoading => _isPremiumLoading;
  List<PremiumProduct> get availableProducts => _availableProducts;
  ChessUser? get currentUser => _currentUser;
  Stream<bool> get purchaseStatusStream => _purchaseStatusController.stream;

  // Initialize the premium provider
  Future<void> init(ChessUser user) async {
    _logger.i('Initializing PremiumProvider for user: ${user.uid}');
    _currentUser = user;
    _isPremium = user.removeAds ?? false;

    // Initialize the in-app purchase service
    await _purchaseService.init();

    // Listen to product updates
    _purchaseService.productsStream.listen(_handleProductsUpdate);

    // Listen to purchase status updates
    _purchaseService.purchaseStatusStream.listen(_handlePurchaseStatusUpdate);

    notifyListeners();
  }

  // Handle product updates from the purchase service
  void _handleProductsUpdate(List<PremiumProduct> products) {
    _logger.i('📦 Received product update with ${products.length} products');
    for (final product in products) {
      _logger.i(
        '  - Product: ${product.id} - ${product.title} - ${product.price} ${product.currencyCode}',
      );
    }

    // sort the products by price
    products.sort((a, b) => a.price.compareTo(b.price));
    _availableProducts = products;
    _logger.i('✅ Available products updated, notifying listeners');
    notifyListeners();
  }

  // Handle purchase status updates
  void _handlePurchaseStatusUpdate(bool success) {
    _logger.i('Received purchase status update: success=$success');
    _isPremiumLoading = false;
    _purchaseStatusController.add(success);

    if (success) {
      _isPremium = true;
    }
    // The user's premium status is already updated in Firestore by InAppPurchaseService
    // We just need to update the local state
    notifyListeners();
  }

  // Purchase a premium product
  Future<void> purchaseProduct(String productId) async {
    _logger.i('Initiating purchase for product: $productId');

    if (!_purchaseService.isAvailable) {
      _logger.w('In-App Purchases not available');
      throw Exception('In-App Purchases are not available on this device.');
    }

    _isPremiumLoading = true;
    notifyListeners();

    try {
      await _purchaseService.purchaseProduct(productId);
    } catch (e) {
      _logger.e('Error purchasing product: $e');
      _isPremiumLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Restore previous purchases
  Future<void> restorePurchases() async {
    _logger.i('Restoring previous purchases');

    _isPremiumLoading = true;
    notifyListeners();

    try {
      await _purchaseService.restorePurchases();
    } catch (e) {
      _logger.e('Error restoring purchases: $e');
    } finally {
      _isPremiumLoading = false;
      notifyListeners();
    }
  }

  // Manually refresh products (useful if products failed to load)
  Future<void> refreshProducts() async {
    _logger.i('🔄 Manually refreshing products');
    _isPremiumLoading = true;
    notifyListeners();

    try {
      await _purchaseService.refreshProducts();
    } catch (e) {
      _logger.e('Error refreshing products: $e');
    } finally {
      _isPremiumLoading = false;
      notifyListeners();
    }
  }

  // Update the current user
  void updateCurrentUser(ChessUser user) {
    _currentUser = user;
    _isPremium = user.removeAds ?? false;
    notifyListeners();
  }

  @override
  void dispose() {
    _purchaseService.dispose();
    _purchaseStatusController.close();
    super.dispose();
  }
}
