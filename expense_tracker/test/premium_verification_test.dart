import 'dart:async';

import 'package:finance_tracker/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

void main() {
  group('BackendApiPremiumVerificationService', () {
    test('returns a verified entitlement when the backend confirms an active purchase', () async {
      final service = BackendApiPremiumVerificationService(
        apiClient: _FakePremiumBackendApiClient(
          onVerify: (_) async => PremiumBackendEntitlementStatus(
            isVerified: true,
            isActive: true,
            productId: PremiumService.productId,
            expiryDate: DateTime.utc(2030, 1, 1),
            message: 'Verified',
          ),
        ),
      );

      final result = await service.verifyPremiumPurchase(
        _buildPayload(),
      );

      expect(result.isVerified, isTrue);
      expect(result.isActive, isTrue);
      expect(result.mode, PremiumVerificationMode.backend);
      expect(result.purchasedProductId, PremiumService.productId);
      expect(result.expiryDate, DateTime.utc(2030, 1, 1));
    });

    test('rejects access when the backend reports an inactive entitlement', () async {
      final service = BackendApiPremiumVerificationService(
        apiClient: _FakePremiumBackendApiClient(
          onVerify: (_) async => const PremiumBackendEntitlementStatus(
            isVerified: true,
            isActive: false,
            productId: PremiumService.productId,
            message: 'Subscription canceled',
          ),
        ),
      );

      final result = await service.verifyPremiumPurchase(
        _buildPayload(),
      );

      expect(result.isVerified, isFalse);
      expect(result.isActive, isFalse);
      expect(result.message, 'Subscription canceled');
    });

    test('fails closed when backend verification times out', () async {
      final service = BackendApiPremiumVerificationService(
        apiClient: _FakePremiumBackendApiClient(
          onVerify: (_) => Future<PremiumBackendEntitlementStatus>.error(
            TimeoutException('timed out'),
          ),
        ),
      );

      final result = await service.verifyPremiumPurchase(
        _buildPayload(),
      );

      expect(result.isVerified, isFalse);
      expect(result.isActive, isFalse);
      expect(result.message, 'Premium verification timed out.');
    });
  });

  group('purchase verification repositories', () {
    test('backend repository rejects an unexpected product id', () async {
      const repository = BackendPremiumPurchaseVerificationRepository(
        backendVerificationService: _FakeBackendVerificationService(
          result: PremiumVerificationResult.verified(
            mode: PremiumVerificationMode.backend,
          ),
        ),
      );

      final result = await repository.verifyPurchase(
        purchase: _buildPurchase(productId: 'wrong_product'),
        expectedProductId: PremiumService.productId,
      );

      expect(result.isVerified, isFalse);
      expect(result.message, 'Unexpected premium product ID.');
    });

    test('backend repository rejects a purchase with no receipt data', () async {
      const repository = BackendPremiumPurchaseVerificationRepository(
        backendVerificationService: _FakeBackendVerificationService(
          result: PremiumVerificationResult.verified(
            mode: PremiumVerificationMode.backend,
          ),
        ),
      );

      final result = await repository.verifyPurchase(
        purchase: _buildPurchase(
          serverReceipt: '',
          localReceipt: '',
        ),
        expectedProductId: PremiumService.productId,
      );

      expect(result.isVerified, isFalse);
      expect(result.message, 'Purchase receipt data is missing.');
    });

    test('local stub verification can be disabled for release-safe behavior', () async {
      const repository = LocalStubPremiumPurchaseVerificationRepository(
        allowVerification: false,
      );

      final result = await repository.verifyPurchase(
        purchase: _buildPurchase(),
        expectedProductId: PremiumService.productId,
      );

      expect(result.isVerified, isFalse);
      expect(
        result.message,
        'Local premium verification is unavailable outside debug builds.',
      );
    });
  });
}

PremiumBackendVerificationPayload _buildPayload() {
  return const PremiumBackendVerificationPayload(
    productId: PremiumService.productId,
    purchaseToken: 'server-token',
    localReceipt: 'local-receipt',
    verificationSource: 'google_play',
    purchaseStatus: 'purchased',
    purchaseId: 'purchase-1',
    transactionDateMillis: 1718409600000,
  );
}

PurchaseDetails _buildPurchase({
  String productId = PremiumService.productId,
  String serverReceipt = 'server-token',
  String localReceipt = 'local-receipt',
  PurchaseStatus status = PurchaseStatus.purchased,
}) {
  return PurchaseDetails(
    purchaseID: 'purchase-1',
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: localReceipt,
      serverVerificationData: serverReceipt,
      source: 'google_play',
    ),
    transactionDate: '1718409600000',
    status: status,
  );
}

class _FakePremiumBackendApiClient implements PremiumBackendApiClient {
  final Future<PremiumBackendEntitlementStatus> Function(
    PremiumBackendVerificationPayload payload,
  ) onVerify;

  _FakePremiumBackendApiClient({
    required this.onVerify,
  });

  @override
  bool get isConfigured => true;

  @override
  String get unavailableMessage => 'Unavailable';

  @override
  Future<PremiumBackendEntitlementStatus> verifyEntitlement(
    PremiumBackendVerificationPayload payload,
  ) {
    return onVerify(payload);
  }
}

class _FakeBackendVerificationService
    implements PremiumBackendVerificationService {
  final PremiumVerificationResult result;

  const _FakeBackendVerificationService({
    required this.result,
  });

  @override
  bool get isAvailableForVerification => true;

  @override
  String get unavailableMessage => 'Unavailable';

  @override
  Future<PremiumVerificationResult> verifyPremiumPurchase(
    PremiumBackendVerificationPayload payload,
  ) async {
    return result;
  }
}
