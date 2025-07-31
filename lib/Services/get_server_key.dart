import 'dart:io';
import 'package:googleapis_auth/auth_io.dart';

class GetServerKey {
  Future<String> getServerKeyToken() async {
    final scopes = [
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/firebase.database',
      'https://www.googleapis.com/auth/firebase.messaging',
    ];
    // Load the service account credentials from a local file
    final jsonString = await File('serviceAccountKey.json').readAsString();
    final client = await clientViaServiceAccount(
      ServiceAccountCredentials.fromJson(jsonString),
      scopes,
    );
    final accessServerKey = client.credentials.accessToken.data;
    return accessServerKey;
  }
}
