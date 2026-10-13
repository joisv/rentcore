import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import 'api_client.dart';

enum NetworkStatus {
  online,
  offline,
  checking,
}

class NetworkStatusNotifier extends Notifier<NetworkStatus> {
  @override
  NetworkStatus build() {
    // Hook up ApiClient connectivity callback
    ApiClient().onConnectivityChanged = (bool isConnected) {
      if (isConnected && state != NetworkStatus.online) {
        state = NetworkStatus.online;
      } else if (!isConnected && state != NetworkStatus.offline) {
        state = NetworkStatus.offline;
      }
    };
    return NetworkStatus.online;
  }

  void setOffline() {
    state = NetworkStatus.offline;
  }

  void setOnline() {
    state = NetworkStatus.online;
  }

  Future<bool> checkConnectivity() async {
    state = NetworkStatus.checking;
    try {
      final response = await ApiClient().dio.get(
        ApiConstants.dashboardKpi,
      );
      if (response.statusCode != null && response.statusCode! < 500) {
        state = NetworkStatus.online;
        return true;
      }
    } catch (_) {
      // Any network error confirms offline state
    }
    state = NetworkStatus.offline;
    return false;
  }
}

final networkStatusProvider =
    NotifierProvider<NetworkStatusNotifier, NetworkStatus>(NetworkStatusNotifier.new);
