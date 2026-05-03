import 'package:finance_tracker/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseSmartExpenseNotification', () {
    test('parses a GCash payment notification into a review draft', () {
      final draft = parseSmartExpenseNotification(
        sourceApp: 'GCash',
        notificationTitle: 'Payment successful',
        notificationBody: 'You paid PHP 145.50 to Jollibee via GCash.',
      );

      expect(draft, isNotNull);
      expect(draft!.amount, closeTo(145.50, 0.001));
      expect(draft.sourceApp, 'GCash');
      expect(draft.title, 'Payment successful');
      expect(draft.shouldSuggest, isTrue);
    });

    test('parses a Maya debit notification into a review draft', () {
      final draft = parseSmartExpenseNotification(
        sourceApp: 'Maya',
        notificationTitle: 'Payment completed',
        notificationBody: 'Your account was debited PHP 399.00 for Netflix.',
      );

      expect(draft, isNotNull);
      expect(draft!.amount, closeTo(399.00, 0.001));
      expect(draft.sourceApp, 'Maya');
      expect(draft.shouldSuggest, isTrue);
    });

    test('parses a Shopee checkout notification into a review draft', () {
      final draft = parseSmartExpenseNotification(
        sourceApp: 'Shopee',
        notificationTitle: 'ShopeePay',
        notificationBody: 'Order total PHP 289.00 paid successfully.',
      );

      expect(draft, isNotNull);
      expect(draft!.amount, closeTo(289.00, 0.001));
      expect(draft.sourceApp, 'Shopee');
      expect(draft.shouldSuggest, isTrue);
    });

    test('parses a Lazada checkout notification into a review draft', () {
      final draft = parseSmartExpenseNotification(
        sourceApp: 'Lazada',
        notificationTitle: 'Lazada',
        notificationBody: 'Checkout total PHP 1,299.00 completed.',
      );

      expect(draft, isNotNull);
      expect(draft!.amount, closeTo(1299.00, 0.001));
      expect(draft.sourceApp, 'Lazada');
      expect(draft.shouldSuggest, isTrue);
    });

    test('parses a Grab ride notification as transport spending', () {
      final draft = parseSmartExpenseNotification(
        sourceApp: 'Grab',
        notificationTitle: 'Grab',
        notificationBody: 'Your ride was paid. PHP 218.00 charged successfully.',
      );

      expect(draft, isNotNull);
      expect(draft!.amount, closeTo(218.00, 0.001));
      expect(draft.category, 'Transport');
      expect(draft.shouldSuggest, isTrue);
    });

    test('parses a Foodpanda order notification as food spending', () {
      final draft = parseSmartExpenseNotification(
        sourceApp: 'Foodpanda',
        notificationTitle: 'foodpanda',
        notificationBody: 'Order total PHP 420.00 paid successfully.',
      );

      expect(draft, isNotNull);
      expect(draft!.amount, closeTo(420.00, 0.001));
      expect(draft.category, 'Food');
      expect(draft.shouldSuggest, isTrue);
    });

    test('ignores OTP notifications', () {
      final draft = parseSmartExpenseNotification(
        sourceApp: 'GCash',
        notificationTitle: 'GCash OTP',
        notificationBody: 'Your one-time password is 123456. Do not share it.',
      );

      expect(draft, isNull);
    });

    test('ignores login notifications', () {
      final draft = parseSmartExpenseNotification(
        sourceApp: 'Maya',
        notificationTitle: 'Login alert',
        notificationBody: 'A new login was detected on your Maya account.',
      );

      expect(draft, isNull);
    });

    test('ignores refund and cashback notifications', () {
      final refundDraft = parseSmartExpenseNotification(
        sourceApp: 'Shopee',
        notificationTitle: 'Refund completed',
        notificationBody: 'PHP 199.00 refund was credited to your wallet.',
      );
      final cashbackDraft = parseSmartExpenseNotification(
        sourceApp: 'Lazada',
        notificationTitle: 'Cashback received',
        notificationBody: 'You received PHP 50.00 cashback from your last order.',
      );

      expect(refundDraft, isNull);
      expect(cashbackDraft, isNull);
    });

    test('ignores promo notifications', () {
      final draft = parseSmartExpenseNotification(
        sourceApp: 'Foodpanda',
        notificationTitle: 'Promo alert',
        notificationBody: 'Use this promo code for your next order and save PHP 100.',
      );

      expect(draft, isNull);
    });

    test('ignores received-money notifications', () {
      final draft = parseSmartExpenseNotification(
        sourceApp: 'GCash',
        notificationTitle: 'Money received',
        notificationBody: 'You received PHP 750.00 from Alex.',
      );

      expect(draft, isNull);
    });
  });
}
