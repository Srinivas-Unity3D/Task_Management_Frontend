// // import 'package:googleapis_auth/auth_io.dart';
// //
// // class GetServerKey {
// //   Future<String> getServerKeyToken() async {
// //     final scopes = [
// //       'https://www.googleapis.com/auth/userinfo.email',
// //       'https://www.googleapis.com/auth/firebase.database',
// //       'https://www.googleapis.com/auth/firebase.messaging',
// //     ];
// //     final client = await clientViaServiceAccount(
// //       ServiceAccountCredentials.fromJson({
// //         "type": "service_account",
// //         "project_id": "task-man-srinivas-2",
// //         "private_key_id": "f910cd6819a4aa75d1c5d9e0f35cb3441bf54aff",
// //         "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDtyjCTD1yg2MTY\nXNysNZA0+YaGYU30VFhrAMxeqoZdnZwPgjEWCzVIND/21lLpfCV5mItP/rV7CZMl\nFw7nVvdo8+PVYHhivZvrG5xJv1FRkiV7wYDwUZhthODhMsdr/0D6FxVqV+UpYPNu\nbHoOPy9phB6GSj9RwRES17fueatwsvn4y5tOI77w6JpptGTNtQacJFq/ZKFT7qas\nlPZCj21oVInTnKhrCpM06abk17q4/U6sfLbioLWZEVYx32V9dYFJMyQeHiFugX7S\nMcQDDyB4lmKAFtrt/dqx0HXGilQcIVrplF89mv+dzL2Xzrn0gFlpWvY5nn4BLRoA\nErM2ayszAgMBAAECggEAc0nQ1DQh/lAq3BXl3c6YbL7AJN3/fCL6vWJlM86sl63n\nMLO4Fc54VloS2xvdlhtdVf+KJ84/8ffZ8iUkUjBdgvKgd18u7vysIEjCNRU/mXNo\nngBbAeklpI/Eshq7Clb3C2nutaEI18+MJvEMGmUzGQ7397b+zSX0n7ScFlDCOMB2\nZ24Ye2lbpgwRBYxwjwtgCtmC4caoSv/Xadmzjd3+iPjS7SkBPht5CB7fk0R0pjNt\nefLkhheoQvOs8bJC0voXl7KBrtjZ5xLSsPra1rZXBUF7UyFXRH4cu7/jUpemj8+f\nQunBvKOKS+A6fzhJXQHQbakK0Vab/+s2EcdUvBNXRQKBgQD3iAugBGbMbXf6rgCZ\nPTUgLqsqAhYSrAIB/2IVvPnRRyTCN9B+QfG6vwnpgti4fPRAedsAiLUydl+eERHg\nAb+8zM2pAzlcRhkx6TXSqGrEBjRiC3j4L2R36qiGO187APQdCzF2iagT6054VPPS\nGMxKsAsUx8G4T5MtsbElEUjHrQKBgQD17NMDLPHHdXOe2qYR0M0fpBkQKeNApiSL\nwFpQ0xw/WBQeGzMpzRU6GIE5YzRTOl77ywbSLvnUj3koUdve0JnViSdMthdM29R6\nA3VV7y7wlwl/WU2NbLP4rOTau660Sbs3s3GQJMkszwnHVpRvurWc7RjhmUv/UMoT\nEUFP2teaXwKBgQDSUhk2lKbYCieIqzI9AkHSn3S2E+G3acmm8tzfhZtqk52LHKud\nq+B+AXaln5UPZLSQ2DkaAg6b2vKxtuVORY4qGIailee2HKWpv/MIlCtrda4qpH7b\nukEOlycsLuRimRPSXcFga+SRUD1zhxNIr+NdjqlLtdNHDO4MRFA1I7OIXQKBgQC0\n+UZ/e7+hLImdSQIU8jdBJZ1cC7c0iA802KSd/f03kDWdwh5wkH8idY4DEUIcTURA\nvzOR0QgAqGRci4DmA1Rxk7Db/tQ+tzcxYwIh7xX37u4KTUmI3YnDYlg3rw3tlqSz\nZNYZYTi6RNHJY6lwX1Hu3XwF6K3IgUdzqKsLfNxUuQKBgBPHgVbl2xmvw946fSqU\naY3a6sCEtMl3fB5oLf2QwsuQGLPmrZj1PExoZVBA2vfaucqmdpl48bghOPhLZEtn\nhc4rTjKRtzlKeR9KW4U844AV7Aip6ejbQUJ4EaycS/O3cWrdHF9e9Tdgq1SeCK4t\nrTyQ+rfnLABXQ2S3YdFV80Nn\n-----END PRIVATE KEY-----\n",
// //         "client_email": "firebase-adminsdk-fbsvc@task-man-srinivas-2.iam.gserviceaccount.com",
// //         "client_id": "114346431046495857224",
// //         "auth_uri": "https://accounts.google.com/o/oauth2/auth",
// //         "token_uri": "https://oauth2.googleapis.com/token",
// //         "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
// //         "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40task-man-srinivas-2.iam.gserviceaccount.com",
// //         "universe_domain": "googleapis.com"
// //       }),
// //       scopes,
// //     );
// //     final accessServerKey = client.credentials.accessToken.data;
// //     return accessServerKey;
// //   }
// // }
//
// import 'dart:convert';
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:googleapis_auth/auth_io.dart';
// import 'package:flutter/foundation.dart';
//
// /// A service to obtain OAuth 2.0 access tokens for Firebase Cloud Messaging (FCM) API.
// /// Loads service account credentials securely and caches tokens for efficiency.
// class GetServerKey {
//   static final GetServerKey _instance = GetServerKey._internal();
//   factory GetServerKey() => _instance;
//   GetServerKey._internal();
//
//   // OAuth 2.0 scope for FCM
//   // static const _scope = 'https://www.googleapis.com/auth/firebase.messaging';
//   static const _scope = 'https://fcm.googleapis.com/v1/projects/task-man-srinivas-2/messages:send';
//   // Path to service account JSON in assets
//   static const _serviceAccountPath = 'assets/service-account-key.json';
//   // Token cache
//   AccessToken? _cachedToken;
//
//   /// Retrieves an OAuth 2.0 access token for FCM API authentication.
//   ///
//   /// Returns a [Future<String>] containing the access token.
//   /// Throws an [Exception] if authentication fails.
//   Future<String> getServerKeyToken() async {
//     try {
//       // Check if cached token is valid
//       if (_cachedToken != null && !_isTokenExpired(_cachedToken!)) {
//         debugPrint('🔑 Using cached FCM access token');
//         return _cachedToken!.data;
//       }
//
//       // Load service account credentials from assets
//       final serviceAccountJson = await _loadServiceAccountCredentials();
//       final credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
//
//       // Obtain authenticated client
//       final client = await clientViaServiceAccount(credentials, [_scope]);
//       _cachedToken = client.credentials.accessToken;
//
//       debugPrint('🔑 New FCM access token obtained');
//       return _cachedToken!.data;
//     } catch (e) {
//       debugPrint('❌ Failed to obtain FCM access token: $e');
//       throw Exception('Failed to obtain FCM access token: $e');
//     }
//   }
//
//   /// Loads service account JSON from assets.
//   Future<Map<String, dynamic>> _loadServiceAccountCredentials() async {
//     try {
//       final jsonString = await rootBundle.loadString(_serviceAccountPath);
//       return jsonDecode(jsonString) as Map<String, dynamic>;
//     } catch (e) {
//       debugPrint('❌ Failed to load service account credentials: $e');
//       throw Exception('Failed to load service account credentials: $e');
//     }
//   }
//
//   /// Checks if the token is expired, adding a 60-second buffer.
//   bool _isTokenExpired(AccessToken token) {
//     final now = DateTime.now();
//     final expiry = token.expiry.subtract(const Duration(seconds: 60));
//     return now.isAfter(expiry);
//   }
//
//   /// Clears the cached token (e.g., for testing or logout).
//   void clearCachedToken() {
//     _cachedToken = null;
//     debugPrint('🗑️ Cleared cached FCM access token');
//   }
// }

import 'package:googleapis_auth/auth_io.dart';

class GetServerKey {
  Future<String> getServerKeyToken() async {
    final scopes = [
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/firebase.database',
      'https://www.googleapis.com/auth/firebase.messaging',
    ];
    final client = await clientViaServiceAccount(
      ServiceAccountCredentials.fromJson({
        "type": "service_account",
        "project_id": "task-man-srinivas-2",
        "private_key_id": "ecd461f10d0190af1eb705330c5e03a9721d139e",
        "private_key":
            "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDjbXXYuuDDlzcg\nWuK3zEyllE4vaNxuAttYD5BzS0O+kTQK025jtbcStBR+EuUhZNnTWS6r6kZTvDn5\n3EsUhdTN18S17nUoOAPx8jGGWJWbOe1A55zazlAszWTPq1A1rt/gDln7mMQdPmak\nQJVdaKArb3yM7bSVy7mVKp2hyMuIlNknwcoMbsXP5nLt/IEGQ+nCXcff6saHm1PP\nxXXOQFzG5uiXWsxeEXjMV8c8zXyZJ8s+7+d2IDt/VPhEXNjPdKc+Dv8Owr9zMi0a\nyenUmuxGKxGWUlaqAXc/0UtFIBTuDBxOlPSD3HJT/6YMvQopNxCw2/xrtGUFm0W2\ntxaHM28NAgMBAAECggEABybaWMIdSFLmHmPaEx3FeUPnjR3qJ9StXiCn+IaXSK2O\ndxqv/+QafJsu6JbVuSecbyuArrizlNvriZwJiZZhAa1PCv0tMC8WwxIZLmVBvlUw\nTOUbrYiYXj61QVyQE9tK2f2WWDWbhGOBqcxuhgONkEaCVavLjOLDrfLebLrnDGvt\nFYBk/bWvlyQ3hMWZCBXCXIa/YcuG96qVNO+zGFxdW0dYEkck6IIHGAmM3hbzdd23\na7fzwSTdWKv+ExliF6mkcsFxzvpUJ26Y6VOPHMt6FzYxT93lTuEvCzB75xGcqIu4\nT3pH2SH8931062odNx4/W5BmqV7OQtXuy2ZqwHU0MQKBgQD3zwkrK3c2sl/kttph\nZ6Lq+n3/WMtAsHKCIipum4JV0sxKOKb/qO5q8zqTtLOkQkqfBDZqXO9rvoq/8+wG\nd4WvJjGNnyDCskLNbmaypT6dcA3bQtBaFR3BiqzSEEhQf21TlK5++r6TbSzU4Cc7\nZAmpEyfe25EtUHH2lrSV8rE4GQKBgQDq8fVp4xTjBVoaXxeQiRpmVI/V+azpc4sK\njhQP0uaoFUt6x2QXSAUOKbnNQiOqGnjkwBAlbRW4i3IxkfuvfqkCJ7Qh/wMyLzvf\nufGAgQKWX+xUZFNrrCTfFnnWNsdhMAE+jyulJYO3fXi+58Ozz53DNm8ou9dkLCNB\nhOXZ66cdFQKBgFxzTxZd9vHfBkuLtFlWkr9biJo1BE80BORr3qy5M5zVMgYWsKb8\n3UXlTFtCtSp42OIObkasOV5XDeijFdEr0iIP+7i8Pzqjyqxdnc7UO1H9Ng4xFQ4m\nhp1oISWVkYUGpUDjXV5eKa9SscERh1Fu9vOvA9buz3C6bGn0u5adnmQxAoGBAKbG\nNJgCetwf+3LG15pgyF2lXyjb/9MDkspeSn1lDxh3bUntae5g0D3afqrmbRydh/2R\nHKUEhyulyNzJLKjJtzzxZBvRwroH72+DtZureGO4GbFaOiEvZEj70mauId+qTOfU\nh33GYHaK2YBiUng8Q1fENynqFR5lem1S4jpL3id1AoGAUx4yTJWBHG/kw1HrlRPV\nEFbdjgEdQb9/+BPs0vilINqZcskpWXNEUCQnBmh8UqrYxxyeZpDMMDX4lyt8XCA7\ncoPCeMWrjsUUYjMksL21siOMK5mVmt6s+o2HMaAGHBTtXNwr+4mbt+h1jTjlSySg\n73ieQACmLvHeZNncV5DwczE=\n-----END PRIVATE KEY-----\n",
        "client_email":
            "firebase-adminsdk-fbsvc@task-man-srinivas-2.iam.gserviceaccount.com",
        "client_id": "114346431046495857224",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url":
            "https://www.googleapis.com/oauth2/v1/certs",
        "client_x509_cert_url":
            "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40task-man-srinivas-2.iam.gserviceaccount.com",
        "universe_domain": "googleapis.com"
      }),
      scopes,
    );
    final accessServerKey = client.credentials.accessToken.data;
    return accessServerKey;
  }
}
