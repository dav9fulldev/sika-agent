import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// SikaNativeService — MethodChannel Wrapper for native Kotlin Android SIKA services.
class SikaNativeService {
  static const platform = MethodChannel('com.gertonargent/sika');

  static Future<bool> startSikaService() async {
    try {
      final bool result =
          await platform.invokeMethod<bool>('startSikaService') ?? false;
      debugPrint('[SikaNative] Service started: $result');
      return result;
    } catch (e) {
      debugPrint('[SikaNative] Error starting service: $e');
      return false;
    }
  }

  static Future<bool> stopSikaService() async {
    try {
      final bool result =
          await platform.invokeMethod<bool>('stopSikaService') ?? false;
      debugPrint('[SikaNative] Service stopped: $result');
      return result;
    } catch (e) {
      debugPrint('[SikaNative] Error stopping service: $e');
      return false;
    }
  }

  static Future<bool> pauseSikaService() async {
    try {
      final bool result =
          await platform.invokeMethod<bool>('pauseSikaService') ?? false;
      debugPrint('[SikaNative] Service paused: $result');
      return result;
    } catch (e) {
      debugPrint('[SikaNative] Error pausing service: $e');
      return false;
    }
  }

  static Future<bool> resumeSikaService() async {
    try {
      final bool result =
          await platform.invokeMethod<bool>('resumeSikaService') ?? false;
      debugPrint('[SikaNative] Service resumed: $result');
      return result;
    } catch (e) {
      debugPrint('[SikaNative] Error resuming service: $e');
      return false;
    }
  }

  static Future<bool> isSikaServiceRunning() async {
    try {
      final bool result =
          await platform.invokeMethod<bool>('isSikaServiceRunning') ?? false;
      return result;
    } catch (e) {
      debugPrint('[SikaNative] Error checking service status: $e');
      return false;
    }
  }

  static Future<String?> getUserFirstname() async {
    try {
      final String? result =
          await platform.invokeMethod<String>('getUserFirstname');
      debugPrint('[SikaNative] Retrieved firstname: $result');
      return result;
    } catch (e) {
      debugPrint('[SikaNative] Error getting firstname: $e');
      return null;
    }
  }

  static Future<bool> setUserFirstname(String firstname) async {
    try {
      final bool result = await platform.invokeMethod<bool>(
            'setUserFirstname',
            {'firstname': firstname},
          ) ??
          false;
      debugPrint('[SikaNative] Firstname set: $result');
      return result;
    } catch (e) {
      debugPrint('[SikaNative] Error setting firstname: $e');
      return false;
    }
  }

  static Future<String?> getSikaAlias() async {
    try {
      final String? result =
          await platform.invokeMethod<String>('getSikaAlias');
      debugPrint('[SikaNative] Retrieved Sika alias: $result');
      return result;
    } catch (e) {
      debugPrint('[SikaNative] Error getting Sika alias: $e');
      return null;
    }
  }

  static Future<bool> setSikaAlias(String alias) async {
    try {
      final bool result = await platform.invokeMethod<bool>(
            'setSikaAlias',
            {'alias': alias},
          ) ??
          false;
      debugPrint('[SikaNative] Sika alias set: $result');
      return result;
    } catch (e) {
      debugPrint('[SikaNative] Error setting Sika alias: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> readPendingTransactions() async {
    try {
      final String? jsonStr =
          await platform.invokeMethod<String>('readPendingTransactions');
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      debugPrint('[SikaNative] Error reading pending transactions: $e');
      return [];
    }
  }

  static Future<bool> clearPendingTransactions() async {
    try {
      final bool result =
          await platform.invokeMethod<bool>('clearPendingTransactions') ??
              false;
      debugPrint('[SikaNative] Pending transactions cleared: $result');
      return result;
    } catch (e) {
      debugPrint('[SikaNative] Error clearing pending transactions: $e');
      return false;
    }
  }

  static Future<bool> removePendingTransaction(int index) async {
    try {
      final bool result = await platform.invokeMethod<bool>(
            'removePendingTransaction',
            {'index': index},
          ) ??
          false;
      debugPrint('[SikaNative] Pending transaction #$index removed: $result');
      return result;
    } catch (e) {
      debugPrint('[SikaNative] Error removing pending transaction: $e');
      return false;
    }
  }

  static Future<bool> isOverlayPermissionGranted() async {
    try {
      final bool result =
          await platform.invokeMethod<bool>('isOverlayPermissionGranted') ??
              false;
      return result;
    } catch (e) {
      debugPrint('[SikaNative] Error checking overlay permission: $e');
      return false;
    }
  }

  static Future<void> requestOverlayPermission() async {
    try {
      await platform.invokeMethod('requestOverlayPermission');
    } catch (e) {
      debugPrint('[SikaNative] Error requesting overlay permission: $e');
    }
  }

  static Future<bool> showFloatingOverlay() async {
    try {
      final bool result =
          await platform.invokeMethod<bool>('showFloatingOverlay') ?? false;
      return result;
    } catch (e) {
      debugPrint('[SikaNative] Error showing floating overlay: $e');
      return false;
    }
  }

  static Future<bool> hideFloatingOverlay() async {
    try {
      final bool result =
          await platform.invokeMethod<bool>('hideFloatingOverlay') ?? false;
      return result;
    } catch (e) {
      debugPrint('[SikaNative] Error hiding floating overlay: $e');
      return false;
    }
  }
}
