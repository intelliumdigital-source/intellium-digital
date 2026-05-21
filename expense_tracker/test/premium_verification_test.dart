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

    test('rejects access when the backend returns the wrong package name', () async {
      final service = BackendApiPremiumVerificationService(
        apiClient: _FakePremiumBackendApiClient(
          onVerify: (_) async => PremiumBackendEntitlementStatus(
            isVerified: true,
            isActive: true,
            productId: PremiumService.productId,
            packageName: 'com.example.other',
            expiryDate: DateTime.utc(2030, 1, 1),
            message: 'Verified',
          ),
        ),
      );

      final result = await service.verifyPremiumPurchase(
        _buildPayload(),
      );

      expect(result.isVerified, isFalse);
      expect(result.isActive, isFalse);
      expect(result.message, 'Receipt rejected.');
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

  group('PremiumBackendEntitlementStatus', () {
    test('accepts common 200 success response formats', () {
      final responses = <Map<String, dynamic>>[
        <String, dynamic>{'premium': true},
        <String, dynamic>{'isPremium': true},
        <String, dynamic>{'active': true},
        <String, dynamic>{'verified': true},
        <String, dynamic>{'entitlement': 'premium'},
        <String, dynamic>{'status': 'active'},
      ];

      for (final response in responses) {
        final status = PremiumBackendEntitlementStatus.fromJson(response);
        expect(status.isVerified, isTrue, reason: 'response=$response');
        expect(status.isActive, isTrue, reason: 'response=$response');
      }
    });
  });

  group('purchase verification repositories', () {
    test('backend repository rejects an unexpected product id', () async {
      final repository = BackendPremiumPurchaseVerificationRepository(
        backendVerificationService: _FakeBackendVerificationService(
          result: const PremiumVerificationResult.verified(
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

    test('backend repository rejects a purchase with no purchase token', () async {
      final repository = BackendPremiumPurchaseVerificationRepository(
        backendVerificationService: _FakeBackendVerificationService(
          result: const PremiumVerificationResult.verified(
            mode: PremiumVerificationMode.backend,
          ),
        ),
      );

      final result = await repository.verifyPurchase(
        purchase: _buildPurchase(
          serverReceipt: '',
          localReceipt: 'local-receipt',
        ),
        expectedProductId: PremiumService.productId,
      );

      expect(result.isVerified, isFalse);
      expect(result.message, 'Google Play purchase token is missing.');
    });

    test('backend repository sends the server purchase token to the verifier', () async {
      final backendVerificationService = _FakeBackendVerificationService(
        result: const PremiumVerificationResult.verified(
          mode: PremiumVerificationMode.backend,
          purchasedProductId: PremiumService.productId,
        ),
      );
      final repository = BackendPremiumPurchaseVerificationRepository(
        backendVerificationService: backendVerificationService,
      );

      final result = await repository.verifyPurchase(
        purchase: _buildPurchase(
          serverReceipt: 'server-token',
          localReceipt: 'local-receipt',
        ),
        expectedProductId: PremiumService.productId,
      );

      expect(result.isVerified, isTrue);
      expect(backendVerificationService.lastPayload, isNotNull);
      expect(
        backendVerificationService.lastPayload!.purchaseToken,
        'server-token',
      );
      expect(
        backendVerificationService.lastPayload!.productId,
        PremiumService.productId,
      );
      expect(
        backendVerificationService.lastPayload!.packageName,
        'com.intelliumdigital.sweldotrack',
      );
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

  group('PremiumBackendVerificationConfig', () {
    test('normalizes duplicate scheme URLs and appends verify route', () {
      const config = PremiumBackendVerificationConfig(
        verificationUrl: 'https://https://example.run.app',
        authToken: 'Bearer test-secret',
      );

      expect(
        config.verificationUri,
        Uri.parse('https://example.run.app/verify-premium'),
      );
      expect(
        config.buildHeaders()['Authorization'],
        'Bearer test-secret',
      );
    });
  });
}

PremiumBackendVerificationPayload _buildPayload() {
  return const PremiumBackendVerificationPayload(
    productId: PremiumService.productId,
    packageName: 'com.intelliumdigital.sweldotrack',
    purchaseToken: 'server-token',
    userId: 'sweldotrack_test_user',
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
  PremiumBackendVerificationPayload? lastPayload;

  _FakeBackendVerificationService({
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
    lastPayload = payload;
    return result;
  }
}
