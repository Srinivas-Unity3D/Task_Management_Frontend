// import 'package:googleapis_auth/auth_io.dart';
//
// class GetServerKey {
//   Future<String> getServerKeyToken() async {
//     final scopes = [
//       'https://www.googleapis.com/auth/userinfo.email',
//       'https://www.googleapis.com/auth/firebase.database',
//       'https://www.googleapis.com/auth/firebase.messaging',
//     ];
//     final client = await clientViaServiceAccount(
//       ServiceAccountCredentials.fromJson({
//         "type": "service_account",
//         "project_id": "task-man-srinivas-2",
//         "private_key_id": "f910cd6819a4aa75d1c5d9e0f35cb3441bf54aff",
//         "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDtyjCTD1yg2MTY\nXNysNZA0+YaGYU30VFhrAMxeqoZdnZwPgjEWCzVIND/21lLpfCV5mItP/rV7CZMl\nFw7nVvdo8+PVYHhivZvrG5xJv1FRkiV7wYDwUZhthODhMsdr/0D6FxVqV+UpYPNu\nbHoOPy9phB6GSj9RwRES17fueatwsvn4y5tOI77w6JpptGTNtQacJFq/ZKFT7qas\nlPZCj21oVInTnKhrCpM06abk17q4/U6sfLbioLWZEVYx32V9dYFJMyQeHiFugX7S\nMcQDDyB4lmKAFtrt/dqx0HXGilQcIVrplF89mv+dzL2Xzrn0gFlpWvY5nn4BLRoA\nErM2ayszAgMBAAECggEAc0nQ1DQh/lAq3BXl3c6YbL7AJN3/fCL6vWJlM86sl63n\nMLO4Fc54VloS2xvdlhtdVf+KJ84/8ffZ8iUkUjBdgvKgd18u7vysIEjCNRU/mXNo\nngBbAeklpI/Eshq7Clb3C2nutaEI18+MJvEMGmUzGQ7397b+zSX0n7ScFlDCOMB2\nZ24Ye2lbpgwRBYxwjwtgCtmC4caoSv/Xadmzjd3+iPjS7SkBPht5CB7fk0R0pjNt\nefLkhheoQvOs8bJC0voXl7KBrtjZ5xLSsPra1rZXBUF7UyFXRH4cu7/jUpemj8+f\nQunBvKOKS+A6fzhJXQHQbakK0Vab/+s2EcdUvBNXRQKBgQD3iAugBGbMbXf6rgCZ\nPTUgLqsqAhYSrAIB/2IVvPnRRyTCN9B+QfG6vwnpgti4fPRAedsAiLUydl+eERHg\nAb+8zM2pAzlcRhkx6TXSqGrEBjRiC3j4L2R36qiGO187APQdCzF2iagT6054VPPS\nGMxKsAsUx8G4T5MtsbElEUjHrQKBgQD17NMDLPHHdXOe2qYR0M0fpBkQKeNApiSL\nwFpQ0xw/WBQeGzMpzRU6GIE5YzRTOl77ywbSLvnUj3koUdve0JnViSdMthdM29R6\nA3VV7y7wlwl/WU2NbLP4rOTau660Sbs3s3GQJMkszwnHVpRvurWc7RjhmUv/UMoT\nEUFP2teaXwKBgQDSUhk2lKbYCieIqzI9AkHSn3S2E+G3acmm8tzfhZtqk52LHKud\nq+B+AXaln5UPZLSQ2DkaAg6b2vKxtuVORY4qGIailee2HKWpv/MIlCtrda4qpH7b\nukEOlycsLuRimRPSXcFga+SRUD1zhxNIr+NdjqlLtdNHDO4MRFA1I7OIXQKBgQC0\n+UZ/e7+hLImdSQIU8jdBJZ1cC7c0iA802KSd/f03kDWdwh5wkH8idY4DEUIcTURA\nvzOR0QgAqGRci4DmA1Rxk7Db/tQ+tzcxYwIh7xX37u4KTUmI3YnDYlg3rw3tlqSz\nZNYZYTi6RNHJY6lwX1Hu3XwF6K3IgUdzqKsLfNxUuQKBgBPHgVbl2xmvw946fSqU\naY3a6sCEtMl3fB5oLf2QwsuQGLPmrZj1PExoZVBA2vfaucqmdpl48bghOPhLZEtn\nhc4rTjKRtzlKeR9KW4U844AV7Aip6ejbQUJ4EaycS/O3cWrdHF9e9Tdgq1SeCK4t\nrTyQ+rfnLABXQ2S3YdFV80Nn\n-----END PRIVATE KEY-----\n",
//         "client_email": "firebase-adminsdk-fbsvc@task-man-srinivas-2.iam.gserviceaccount.com",
//         "client_id": "114346431046495857224",
//         "auth_uri": "https://accounts.google.com/o/oauth2/auth",
//         "token_uri": "https://oauth2.googleapis.com/token",
//         "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
//         "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40task-man-srinivas-2.iam.gserviceaccount.com",
//         "universe_domain": "googleapis.com"
//       }),
//       scopes,
//     );
//     final accessServerKey = client.credentials.accessToken.data;
//     return accessServerKey;
//   }
// }

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/foundation.dart';

/// A service to obtain OAuth 2.0 access tokens for Firebase Cloud Messaging (FCM) API.
/// Loads service account credentials securely and caches tokens for efficiency.
class GetServerKey {
  static final GetServerKey _instance = GetServerKey._internal();
  factory GetServerKey() => _instance;
  GetServerKey._internal();

  // OAuth 2.0 scope for FCM
  // static const _scope = 'https://www.googleapis.com/auth/firebase.messaging';
  static const _scope = 'https://fcm.googleapis.com/v1/projects/task-man-srinivas-2/messages:send';
  // Path to service account JSON in assets
  static const _serviceAccountPath = 'assets/service-account-key.json';
  // Token cache
  AccessToken? _cachedToken;

  /// Retrieves an OAuth 2.0 access token for FCM API authentication.
  ///
  /// Returns a [Future<String>] containing the access token.
  /// Throws an [Exception] if authentication fails.
  Future<String> getServerKeyToken() async {
    try {
      // Check if cached token is valid
      if (_cachedToken != null && !_isTokenExpired(_cachedToken!)) {
        debugPrint('🔑 Using cached FCM access token');
        return _cachedToken!.data;
      }

      // Load service account credentials from assets
      final serviceAccountJson = await _loadServiceAccountCredentials();
      final credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);

      // Obtain authenticated client
      final client = await clientViaServiceAccount(credentials, [_scope]);
      _cachedToken = client.credentials.accessToken;

      debugPrint('🔑 New FCM access token obtained');
      return _cachedToken!.data;
    } catch (e) {
      debugPrint('❌ Failed to obtain FCM access token: $e');
      throw Exception('Failed to obtain FCM access token: $e');
    }
  }

  /// Loads service account JSON from assets.
  Future<Map<String, dynamic>> _loadServiceAccountCredentials() async {
    try {
      final jsonString = await rootBundle.loadString(_serviceAccountPath);
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ Failed to load service account credentials: $e');
      throw Exception('Failed to load service account credentials: $e');
    }
  }

  /// Checks if the token is expired, adding a 60-second buffer.
  bool _isTokenExpired(AccessToken token) {
    final now = DateTime.now();
    final expiry = token.expiry.subtract(const Duration(seconds: 60));
    return now.isAfter(expiry);
  }

  /// Clears the cached token (e.g., for testing or logout).
  void clearCachedToken() {
    _cachedToken = null;
    debugPrint('🗑️ Cleared cached FCM access token');
  }
}
