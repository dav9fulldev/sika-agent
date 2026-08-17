import 'dart:async';
import 'package:flutter/foundation.dart';
import 'sika_native_service.dart';
import 'api_service.dart';

/// SikaSyncService — Synchronisation des transactions SIKA hors-ligne
class SikaSyncService {
  static bool _isSyncing = false;

  static Future<void> syncPendingTransactions({
    required ApiService apiService,
    int maxRetries = 3,
  }) async {
    if (_isSyncing) {
      debugPrint('[SikaSync] Already syncing, skipping...');
      return;
    }

    _isSyncing = true;

    try {
      debugPrint('[SikaSync] ============ START SYNC ============');

      if (!apiService.hasToken) {
        debugPrint(
            '[SikaSync] ⚠️ Token not available on ApiService, skipping sync');
        return;
      }

      final pending = await SikaNativeService.readPendingTransactions();
      debugPrint('[SikaSync] Found ${pending.length} pending transaction(s)');

      if (pending.isEmpty) {
        debugPrint('[SikaSync] No pending transactions to sync');
        return;
      }

      int syncedCount = 0;
      final List<int> indicesToRemove = [];

      for (int i = 0; i < pending.length; i++) {
        final tx = pending[i];
        final txId = tx['id'] ?? 'unknown';

        try {
          debugPrint('[SikaSync] Syncing transaction #$i (id=$txId)...');

          final double? amount =
              tx['amount'] is num ? (tx['amount'] as num).toDouble() : null;
          final String? category = tx['category']?.toString();
          final String? description = tx['description']?.toString();

          if (amount == null || category == null) {
            debugPrint(
                '[SikaSync] ⚠️ Transaction #$i missing amount or category, skipping');
            continue;
          }

          final response = await apiService
              .createTransaction(
                  amount: amount, category: category, description: description)
              .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                  '[SikaSync] Timeout creating transaction $txId');
            },
          );

          if (response['id'] != null) {
            debugPrint(
                '[SikaSync] ✅ Transaction #$i synced successfully (id=$txId)');
            syncedCount++;
            indicesToRemove.add(i);
          } else {
            debugPrint(
                '[SikaSync] ❌ Failed to sync transaction #$i (response missing id)');
          }
        } catch (e) {
          debugPrint('[SikaSync] ❌ Error syncing transaction #$i: $e');
        }
      }

      for (int i = indicesToRemove.length - 1; i >= 0; i--) {
        await SikaNativeService.removePendingTransaction(indicesToRemove[i]);
      }

      debugPrint(
          '[SikaSync] ============ SYNC FINISHED: $syncedCount/${pending.length} synced ============');
    } catch (e) {
      debugPrint('[SikaSync] ❌ Global sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }
}
