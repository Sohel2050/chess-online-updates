import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/user_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:logger/logger.dart';

/// Product IDs for premium subscriptions
class ProductIds {
  static const String monthly = 'chess30d'; // 'premium_subscription_monthly';
  static const String sixMonths =
      'chess180days'; // 'premium_subscription_6months';
  static const String yearly = 'chess365days'; // 'premium_subscription_yearly';

  static List<String> all = [monthly, sixMonths, yearly];
}

/// Represents a premium subscription product
class PremiumProduct {
  final String id;
  final String title;
  final String description;
  final double price;
  final String currencyCode;
  final String period;

  PremiumProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.currencyCode,
    required this.period,
  });

  @override
  String toString() {
    return 'PremiumProduct(id: $id, title: $title, price: $price $currencyCode)';
  }
}

/// Service to handle in-app purchases for premium subscriptions
class InAppPurchaseService {
  static final InAppPurchaseService _instance =
      InAppPurchaseService._internal();
  factory InAppPurchaseService() => _instance;
  InAppPurchaseService._internal();

  final Logger _logger = Logger();
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  final StreamController<List<PremiumProduct>> _productsController =
      StreamController<List<PremiumProduct>>.broadcast();
  final StreamController<bool> _purchaseStatusController =
      StreamController<bool>.broadcast();

  bool _isAvailable = false;
  bool _isInitialized = false;

  /// Stream of available premium products
  Stream<List<PremiumProduct>> get productsStream => _productsController.stream;

  /// Stream of purchase status updates
  Stream<bool> get purchaseStatusStream => _purchaseStatusController.stream;

  /// Whether in-app purchases are available on this device
  bool get isAvailable => _isAvailable;

  /// Initialize the in-app purchase service
  Future<void> init() async {
    if (_isInitialized) {
      _logger.i('In-App Purchase service already initialized');
      return;
    }

    _logger.i('🚀 Initializing In-App Purchase service');

    // Check if in-app purchases are available
    _isAvailable = await InAppPurchase.instance.isAvailable();

    if (!_isAvailable) {
      _logger.w('⚠️ In-App Purchases are not available on this device');
      _logger.w(
        'This may be because: 1) Running on emulator, 2) Google Play Services not available, 3) Device restrictions',
      );
      // Emit empty list so UI knows products are not available
      _productsController.add([]);
      _isInitialized = true;
      return;
    }

    _logger.i('✅ In-App Purchases are available on this device');

    // Listen to purchase updates
    _subscription = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () {
        _logger.i('Purchase stream closed');
        _subscription.cancel();
      },
      onError: (error) {
        _logger.e('❌ Error in purchase stream: $error');
      },
    );

    // Load available products
    await _loadProducts();

    _isInitialized = true;
    _logger.i('✅ In-App Purchase service initialized successfully');
  }

  /// Load available premium subscription products
  Future<void> _loadProducts() async {
    _logger.i('Loading premium subscription products');
    _logger.i('Product IDs to query: ${ProductIds.all}');

    final ProductDetailsResponse response = await InAppPurchase.instance
        .queryProductDetails(ProductIds.all.toSet());

    if (response.notFoundIDs.isNotEmpty) {
      _logger.w('Product IDs not found: ${response.notFoundIDs}');
      _logger.w(
        'This usually means products are not configured in Google Play Console or App Store Connect',
      );
    }

    if (response.error != null) {
      _logger.e('Error loading products: ${response.error}');
      // Emit empty list so UI knows products failed to load
      _productsController.add([]);
      return;
    }

    _logger.i('Found ${response.productDetails.length} product(s) from store');

    final List<PremiumProduct> products = response.productDetails.map((
      details,
    ) {
      // Remove US$ from price
      final priceString = details.price.replaceAll('US\$', '').trim();
      _logger.i('Product: ${details.id} - ${details.title} - ${details.price}');
      return PremiumProduct(
        id: details.id,
        title: details.title,
        description: details.description,
        price: double.tryParse(priceString) ?? 0.0,
        currencyCode: details.currencyCode,
        period: _getPeriodFromProductId(details.id),
      );
    }).toList();

    _productsController.add(products);
    _logger.i('✅ Loaded ${products.length} premium products successfully');
    _logger.i('Products emitted to stream');
  }

  /// Extract period information from product ID
  String _getPeriodFromProductId(String productId) {
    if (productId.contains('chess30d')) return '1 month';
    if (productId.contains('chess180days')) return '6 months';
    if (productId.contains('chess365days')) return '1 year';
    return 'Unknown';
  }

  /// Handle purchase updates from the store
  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    _logger.i('Received purchase updates for ${purchases.length} items');

    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _logger.i('Purchase pending for ${purchase.productID}');
          break;

        case PurchaseStatus.purchased:
          _logger.i('Purchase completed for ${purchase.productID}');
          _handleSuccessfulPurchase(purchase);
          break;

        case PurchaseStatus.error:
          _logger.e(
            'Purchase error for ${purchase.productID}: ${purchase.error}',
          );
          _purchaseStatusController.add(false);
          break;

        case PurchaseStatus.canceled:
          _logger.i('Purchase canceled for ${purchase.productID}');
          _purchaseStatusController.add(false);
          break;

        default:
          _logger.w('Unknown purchase status: ${purchase.status}');
      }
    }
  }

  /// Handle a successful purchase
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    _logger.i('Handling successful purchase for ${purchase.productID}');

    try {
      // Deliver the premium features to the user
      await _deliverPremiumFeatures(purchase);

      // Mark the purchase as completed
      if (Platform.isIOS) {
        // On iOS, complete the transaction
        await InAppPurchase.instance.completePurchase(purchase);
      } else if (Platform.isAndroid) {
        // On Android, acknowledge the purchase
        if (!purchase.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchase);
        }
      }

      // Notify listeners of successful purchase
      _purchaseStatusController.add(true);
    } catch (e) {
      _logger.e('Error handling successful purchase: $e');
      _purchaseStatusController.add(false);
    }
  }

  /// Deliver premium features to the user
  Future<void> _deliverPremiumFeatures(PurchaseDetails purchase) async {
    _logger.i('Delivering premium features for ${purchase.productID}');

    final uid = await ApiClient.instance.currentUserId;
    if (uid == null) {
      _logger.e('Cannot deliver premium features, user is not logged in');
      return;
    }

    final now = DateTime.now();
    DateTime expiryDate;

    switch (purchase.productID) {
      case ProductIds.monthly:
        expiryDate = now.add(const Duration(days: 30));
        break;
      case ProductIds.sixMonths:
        expiryDate = now.add(const Duration(days: 180));
        break;
      case ProductIds.yearly:
        expiryDate = now.add(const Duration(days: 365));
        break;
      default:
        _logger.w('Unknown product ID: ${purchase.productID}');
        return;
    }

    try {
      final userService = UserService();
      await userService.updatePremiumStatus(
        uid,
        true,
        premiumStartDate: now,
        premiumExpiryDate: expiryDate,
      );
      _logger.i('Successfully delivered premium features to user $uid');
    } catch (e) {
      _logger.e('Error delivering premium features to user $uid: $e');
      // Optionally, re-throw the error to be handled by the caller
      rethrow;
    }
  }

  /// Purchase a premium product
  Future<void> purchaseProduct(String productId) async {
    _logger.i('Initiating purchase for product: $productId');

    if (!_isAvailable) {
      _logger.w('In-App Purchases not available, cannot purchase $productId');
      throw Exception('In-App Purchases are not available on this device.');
    }

    final ProductDetailsResponse response = await InAppPurchase.instance
        .queryProductDetails({productId});

    if (response.error != null) {
      _logger.e('Error querying product details: ${response.error}');
      throw Exception(
        'Error querying product details: ${response.error!.message}',
      );
    }

    if (response.productDetails.isEmpty) {
      _logger.w('Product not found: $productId');
      throw Exception('Product not found: $productId');
    }

    final ProductDetails product = response.productDetails.first;
    final currentUserId = await ApiClient.instance.currentUserId;

    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: product,
      applicationUserName: currentUserId,
    );

    try {
      final bool initiated = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      _logger.i('Purchase initiated for ${product.id}, result: $initiated');

      if (!initiated) {
        throw Exception(
          'Purchase could not be initiated. Another purchase may be in progress.',
        );
      }
    } catch (e) {
      _logger.e('Error initiating purchase: $e');
      rethrow;
    }
  }

  /// Restore previous purchases (mainly for iOS)
  Future<void> restorePurchases() async {
    _logger.i('Restoring previous purchases');

    if (!_isAvailable) {
      _logger.w('In-App Purchases not available, cannot restore purchases');
      return;
    }

    try {
      await InAppPurchase.instance.restorePurchases();
      _logger.i('Purchase restoration initiated');
    } catch (e) {
      _logger.e('Error restoring purchases: $e');
    }
  }

  /// Manually refresh products (useful if products failed to load)
  Future<void> refreshProducts() async {
    _logger.i('🔄 Manually refreshing products');

    if (!_isAvailable) {
      _logger.w('⚠️ In-App Purchases not available, cannot refresh products');
      // Still emit empty list to update UI
      _productsController.add([]);
      return;
    }

    try {
      await _loadProducts();
      _logger.i('✅ Products refreshed successfully');
    } catch (e) {
      _logger.e('❌ Error refreshing products: $e');
      // Emit empty list on error so UI knows refresh completed
      _productsController.add([]);
    }
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    _subscription.cancel();
    _productsController.close();
    _purchaseStatusController.close();
    _logger.i('In-App Purchase service disposed');
  }
}
