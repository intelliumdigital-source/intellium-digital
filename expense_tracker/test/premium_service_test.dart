import 'dart:async';

import 'package:finance_tracker/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('PremiumService', () {
    test('uses fallback premium price until store pricing is loaded', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final gateway = _FakePremiumBillingGateway();
      final service = PremiumService(
        verificationRepository: const _FakePremiumPurchaseVerificationRepository(
          result: PremiumVerificationResult.verified(
            mode: PremiumVerificationMode.backend,
          ),
        ),
        billingGateway: gateway,
        allowNonBackendVerification: true,
      );

      expect(service.premiumDisplayPriceLabel, '\u20B1120/month');
      expect(
        service.premiumPrimaryActionLabel,
        'Purchase Premium - \u20B1120/month',
      );
      expect(
        service.premiumSecondaryActionLabel,
        'Unlock Premium - \u20B1120/month',
      );

      await service.initialize();

      expect(service.premiumDisplayPriceLabel, 'PHP 120/month');
      expect(
        service.premiumPrimaryActionLabel,
        'Purchase Premium - PHP 120/month',
      );
      expect(
        service.premiumSecondaryActionLabel,
        'Unlock Premium - PHP 120/month',
      );

      service.dispose();
      await gateway.close();
    });

    test('does not unlock premium from cached local state alone', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppKeys.premiumActive: true,
        AppKeys.premiumLastVerifiedAt:
            DateTime.utc(2029, 1, 1).toIso8601String(),
        AppKeys.premiumLastVerificationMode:
            PremiumVerificationMode.backend.name,
      });

      final gateway = _FakePremiumBillingGateway();
      final service = PremiumService(
        verificationRepository: const _FakePremiumPurchaseVerificationRepository(
          result: PremiumVerificationResult.verified(
            mode: PremiumVerificationMode.backend,
          ),
        ),
        billingGateway: gateway,
        allowNonBackendVerification: true,
      );

      await service.initialize();

      expect(service.hasCachedPremiumState, isTrue);
      expect(service.isPremium, isFalse);

      service.dispose();
      await gateway.close();
    });

    test('restorePurchases verifies a restored purchase and completes it', () async {
      final gateway = _FakePremiumBillingGateway();
      gateway.onRestorePurchases = () async {
        gateway.emit(<PurchaseDetails>[
          _buildPurchase(
            status: PurchaseStatus.restored,
            pendingCompletePurchase: true,
          ),
        ]);
      };

      final service = PremiumService(
        verificationRepository: const _FakePremiumPurchaseVerificationRepository(
          result: PremiumVerificationResult.verified(
            mode: PremiumVerificationMode.backend,
            purchasedProductId: PremiumService.productId,
          ),
        ),
        billingGateway: gateway,
        allowNonBackendVerification: true,
      );

      await service.initialize();
      await service.restorePurchases();

      expect(service.isPremium, isTrue);
      expect(service.errorMessage, isNull);
      expect(gateway.completePurchaseCalls, 1);

      service.dispose();
      await gateway.close();
    });

    test('restorePurchases removes premium access when verification is rejected', () async {
      final gateway = _FakePremiumBillingGateway();
      gateway.onRestorePurchases = () async {
        gateway.emit(<PurchaseDetails>[
          _buildPurchase(
            status: PurchaseStatus.restored,
            pendingCompletePurchase: true,
          ),
        ]);
      };

      final service = PremiumService(
        verificationRepository: const _FakePremiumPurchaseVerificationRepository(
          result: PremiumVerificationResult.rejected(
            mode: PremiumVerificationMode.backend,
            message: 'Premium entitlement is no longer active.',
          ),
        ),
        billingGateway: gateway,
        allowNonBackendVerification: true,
      );

      await service.initialize();
      await service.restorePurchases();

      final prefs = await SharedPreferences.getInstance();
      expect(service.isPremium, isFalse);
      expect(service.errorMessage, 'Premium entitlement is no longer active.');
      expect(prefs.getBool(AppKeys.premiumActive), isFalse);
      expect(gateway.completePurchaseCalls, 1);

      service.dispose();
      await gateway.close();
    });

    test('pending purchases stay pending and are not completed early', () async {
      final gateway = _FakePremiumBillingGateway();
      final service = PremiumService(
        verificationRepository: const _FakePremiumPurchaseVerificationRepository(
          result: PremiumVerificationResult.verified(
            mode: PremiumVerificationMode.backend,
          ),
        ),
        billingGateway: gateway,
        allowNonBackendVerification: true,
      );

      await service.initialize();
      gateway.emit(<PurchaseDetails>[
        _buildPurchase(
          status: PurchaseStatus.pending,
          pendingCompletePurchase: true,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(service.isPurchasePending, isTrue);
      expect(service.isPremium, isFalse);
      expect(gateway.completePurchaseCalls, 0);

      service.dispose();
      await gateway.close();
    });

    test('purchase error keeps premium locked and completes the purchase when required', () async {
      final gateway = _FakePremiumBillingGateway();
      final service = PremiumService(
        verificationRepository: const _FakePremiumPurchaseVerificationRepository(
          result: PremiumVerificationResult.verified(
            mode: PremiumVerificationMode.backend,
          ),
        ),
        billingGateway: gateway,
        allowNonBackendVerification: true,
      );

      await service.initialize();
      gateway.emit(<PurchaseDetails>[
        _buildPurchase(
          status: PurchaseStatus.error,
          pendingCompletePurchase: true,
          error: IAPError(
            source: 'google_play',
            code: 'network_error',
            message: 'Network error',
          ),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(service.isPremium, isFalse);
      expect(service.isPurchasePending, isFalse);
      expect(
        service.errorMessage,
        'Purchase could not be confirmed because the network is unavailable.',
      );
      expect(gateway.completePurchaseCalls, 1);

      service.dispose();
      await gateway.close();
    });

    test('backend verification failures keep restore available without completing the purchase', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final gateway = _FakePremiumBillingGateway();
      gateway.onRestorePurchases = () async {
        gateway.emit(<PurchaseDetails>[
          _buildPurchase(
            status: PurchaseStatus.restored,
            pendingCompletePurchase: true,
          ),
        ]);
      };

      final service = PremiumService(
        verificationRepository: const _FakePremiumPurchaseVerificationRepository(
          result: PremiumVerificationResult.rejected(
            mode: PremiumVerificationMode.backend,
            message: 'Verification server timed out.',
          ),
        ),
        billingGateway: gateway,
        allowNonBackendVerification: true,
      );

      await service.initialize();
      await service.restorePurchases();

      expect(service.premiumStatusLabel, 'Payment Detected');
      expect(
        service.premiumStatusDetail,
        'Your payment was detected, but premium verification could not be completed. Tap Restore Purchase to try again.',
      );
      expect(service.hasRecoverablePremiumVerificationIssue, isTrue);
      expect(service.hasPaymentDetectedButNotVerified, isTrue);
      expect(service.canRestorePremium, isTrue);
      expect(service.restoreUnavailableReason, isNull);
      expect(
        service.premiumPrimaryActionLabel,
        'Restore Purchase',
      );
      expect(
        service.premiumSecondaryActionLabel,
        'Restore Purchase',
      );
      expect(
        service.premiumRestoreAvailabilityMessage,
        'Your payment was detected, but premium verification could not be completed. Tap Restore Purchase to try again.',
      );
      expect(gateway.completePurchaseCalls, 0);

      service.dispose();
      await gateway.close();
    });

    test('restorePurchases retries verification after a recoverable backend failure', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final gateway = _FakePremiumBillingGateway();
      gateway.onRestorePurchases = () async {
        gateway.emit(<PurchaseDetails>[
          _buildPurchase(
            status: PurchaseStatus.restored,
            pendingCompletePurchase: true,
          ),
        ]);
      };
      final verificationRepository =
          _CountingPremiumPurchaseVerificationRepository(
        results: <PremiumVerificationResult>[
          const PremiumVerificationResult.rejected(
            mode: PremiumVerificationMode.backend,
            message: 'Verification server timed out.',
          ),
          const PremiumVerificationResult.verified(
            mode: PremiumVerificationMode.backend,
            purchasedProductId: PremiumService.productId,
          ),
        ],
      );

      final service = PremiumService(
        verificationRepository: verificationRepository,
        billingGateway: gateway,
        allowNonBackendVerification: true,
      );

      await service.initialize();
      await service.restorePurchases();

      expect(verificationRepository.verifyCalls, 1);
      expect(service.isPremium, isFalse);
      expect(gateway.completePurchaseCalls, 0);

      await service.restorePurchases();

      expect(verificationRepository.verifyCalls, 2);
      expect(service.isPremium, isTrue);
      expect(gateway.completePurchaseCalls, 1);

      service.dispose();
      await gateway.close();
    });

    test('restorePurchases fails closed on timeout with a clear message', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppKeys.premiumActive: true,
      });

      final gateway = _FakePremiumBillingGateway();
      gateway.onRestorePurchases = () async {};

      final service = PremiumService(
        verificationRepository: const _FakePremiumPurchaseVerificationRepository(
          result: PremiumVerificationResult.verified(
            mode: PremiumVerificationMode.backend,
          ),
        ),
        billingGateway: gateway,
        allowNonBackendVerification: true,
        restoreTimeout: const Duration(milliseconds: 10),
      );

      await service.initialize();
      await service.restorePurchases();

      final prefs = await SharedPreferences.getInstance();
      expect(service.isPremium, isFalse);
      expect(
        service.errorMessage,
        'We could not confirm your previous premium purchase right now. Please try Restore again.',
      );
      expect(prefs.getBool(AppKeys.premiumActive), isFalse);

      service.dispose();
      await gateway.close();
    });
  });
}

PurchaseDetails _buildPurchase({
  PurchaseStatus status = PurchaseStatus.purchased,
  bool pendingCompletePurchase = false,
  IAPError? error,
}) {
  final purchase = PurchaseDetails(
    purchaseID: 'purchase-1',
    productID: PremiumService.productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local-receipt',
      serverVerificationData: 'server-token',
      source: 'google_play',
    ),
    transactionDate: '1718409600000',
    status: status,
  );
  purchase.pendingCompletePurchase = pendingCompletePurchase;
  purchase.error = error;
  return purchase;
}

class _FakePremiumBillingGateway implements PremiumBillingGateway {
  final StreamController<List<PurchaseDetails>> _controller =
      StreamController<List<PurchaseDetails>>.broadcast();

  Future<void> Function()? onRestorePurchases;
  int completePurchaseCalls = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    return ProductDetailsResponse(
      productDetails: <ProductDetails>[
        ProductDetails(
          id: PremiumService.productId,
          title: 'SweldoTrack Premium',
          description: 'Premium subscription',
          price: 'PHP 120/month',
          rawPrice: 120,
          currencyCode: 'PHP',
        ),
      ],
      notFoundIDs: const <String>[],
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completePurchaseCalls++;
  }

  @override
  Future<void> restorePurchases() async {
    if (onRestorePurchases != null) {
      await onRestorePurchases!();
    }
  }

  void emit(List<PurchaseDetails> purchases) {
    _controller.add(purchases);
  }

  Future<void> close() async {
    await _controller.close();
  }
}

class _FakePremiumPurchaseVerificationRepository
    implements PremiumPurchaseVerificationRepository {
  final PremiumVerificationResult result;

  const _FakePremiumPurchaseVerificationRepository({
    required this.result,
  });

  @override
  Future<PremiumVerificationResult> verifyPurchase({
    required PurchaseDetails purchase,
    required String expectedProductId,
  }) async {
    return result;
  }
}

class _CountingPremiumPurchaseVerificationRepository
    implements PremiumPurchaseVerificationRepository {
  final List<PremiumVerificationResult> results;
  int verifyCalls = 0;

  _CountingPremiumPurchaseVerificationRepository({
    required this.results,
  }) : assert(results.isNotEmpty);

  @override
  Future<PremiumVerificationResult> verifyPurchase({
    required PurchaseDetails purchase,
    required String expectedProductId,
  }) async {
    final index = verifyCalls < results.length ? verifyCalls : results.length - 1;
    verifyCalls++;
    return results[index];
  }
}
