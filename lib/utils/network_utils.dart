import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

class NetworkUtilsOld {
  static Future<bool> hasInternetConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    print("Connectivity result1: $connectivityResult");
    var c = ConnectivityResult.none.toString();
    print("Connectivity result2: $c");
    return connectivityResult.toString() != ConnectivityResult.none.toString();
  }
}

class NetworkUtils {
  static Future<bool> hasInternetConnection() async {
    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      if (connectivityResults.every(
        (result) => result == ConnectivityResult.none,
      )) {
        return false;
      }

      final lookupResult = await InternetAddress.lookup('example.com');
      return lookupResult.isNotEmpty && lookupResult[0].rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    }
  }

  /// Listens for internet availability and triggers [onConnected] callback
  static StreamSubscription<List<ConnectivityResult>> onInternetReconnect(
    Future<void> Function() onConnected,
  ) {
    final subscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      if (results.any((r) => r != ConnectivityResult.none)) {
        bool hasInternet = await hasInternetConnection();
        if (hasInternet) {
          print("Internet reconnected, executing callback...");
          await onConnected();
        }
      }
    });
    return subscription;
  }
}
