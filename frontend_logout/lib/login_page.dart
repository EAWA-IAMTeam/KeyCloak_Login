import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:frontend_login/config.dart';
import 'package:frontend_login/home_page.dart';
import 'package:http/http.dart' as http;

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  @override
  void initState() {
    //html.window.localStorage['logoutBool'] = "true";
  }
  var logoutBool = "true";
  
  // Function to check if the token is expired
  bool isTokenExpired(String token) {
    List<String> parts = token.split('.');
    if (parts.length == 3) {
      String payload = parts[1];
      String decoded = utf8.decode(base64Url.decode(base64Url.normalize(payload)));
      Map<String, dynamic> decodedMap = json.decode(decoded);
      int exp = decodedMap['exp'];
      DateTime expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiryDate);
    }
    return true;
  }

  // Check if the Keycloak token exists and is not expired
  Future<void> _checkForKeycloakToken() async {
  // Retrieve necessary data from localStorage
  var keycloakAccessToken = html.window.localStorage['keycloakAccessToken'];
  var keycloakemail = html.window.localStorage['email'];
  logoutBool = html.window.localStorage['logoutBool'] ?? "true"; // Default to "true" if not set
  print("KCAT: $keycloakAccessToken, Email: $keycloakemail");
  print("logoutBool: $logoutBool");

  // Check the value of logoutBool
  if (logoutBool == "true") {
    html.window.localStorage.remove('googleAccessToken');
    print("Redirecting to Google sign-in due to logoutBool.");
    await handleSignIn(); // Redirect to Google sign-in page
  } else if (keycloakAccessToken != null &&
      keycloakemail != null &&
      !isTokenExpired(keycloakAccessToken)) {
    // If valid token and logoutBool is false, navigate to HomePage
    print("Redirecting to HomePage.");
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(
          keycloakAccessToken: keycloakAccessToken,
          googleAccessToken: html.window.localStorage['googleAccessToken'] ?? '',
          keycloakRefreshToken: html.window.localStorage['keycloakRefreshToken'] ?? '',
          email: keycloakemail,
        ),
      ),
    );
  } else {
    // If token is missing or expired, redirect to Google sign-in
    print("Keycloak token invalid or missing. Redirecting to Google sign-in.");
    await handleSignIn();
  }
}

  Future<void> handleSignIn() async {
    try {
      var googleAccessToken = await _getGoogleAccessToken();
      print(googleAccessToken.toString());

      if (googleAccessToken != null) {
        var keycloakTokens = await _exchangeGoogleTokenForKeycloakTokens(googleAccessToken);

        if (keycloakTokens != null && keycloakTokens['access_token'] != null && keycloakTokens['refresh_token'] != null && keycloakTokens['email'] != null) {
          // Store Keycloak tokens in localStorage
          html.window.localStorage['keycloakAccessToken'] = keycloakTokens['access_token'];
          html.window.localStorage['keycloakRefreshToken'] = keycloakTokens['refresh_token'];
          html.window.localStorage['googleAccessToken'] = googleAccessToken;
          html.window.localStorage['email'] = keycloakTokens['email'];
          html.window.localStorage['logoutBool'] = "false";
          await Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(
                googleAccessToken: googleAccessToken,
                keycloakAccessToken: keycloakTokens['access_token'],
                keycloakRefreshToken: keycloakTokens['refresh_token'],
                email: keycloakTokens['email'],
              ),
            ),
          );
        }
      }
    } catch (error) {
      print('Error during sign-in: $error');
    }
  }

 Future<String?> _getGoogleAccessToken() async {
  // Open the Google Sign-In popup
  html.window.open(
    'https://accounts.google.com/o/oauth2/v2/auth?'
    'client_id=950385657379-k0kk7l3nvdm8cbgp31fjvet0c5neluc7.apps.googleusercontent.com&'
    'redirect_uri=${Config.server}:3001/callback.html&'
    'response_type=token&'
    'scope=email profile openid',
    'google_sign_in_popup',
    'width=500,height=600'
  );

  // Wait for the message from the popup window with the token
  return await _waitForGoogleToken();
}

Future<String?> _waitForGoogleToken() async {
  // Listen for messages from the popup
  return await html.window.onMessage.firstWhere((event) {
    // Check if the message contains the Google access token
    if (event.data != null && event.data['googleAccessToken'] != null) {
      return true; // Message contains the token
    }
    return false;
  }).then((event) {
    // Return the Google Access Token
    return event.data['googleAccessToken'];
  });
}

  Future<Map<String, dynamic>?> _exchangeGoogleTokenForKeycloakTokens(String googleAccessToken) async {
    final String keycloakUrl = '${Config.server}:8080/realms/G-SSO-Connect/protocol/openid-connect/token';
    
    final response = await http.post(
      Uri.parse(keycloakUrl),
      body: {
        'grant_type': 'urn:ietf:params:oauth:grant-type:token-exchange',
        'subject_token': googleAccessToken,
        'client_id': 'frontend-login',
        'client_secret': '0SSZj01TDs7812fLBxgwTKPA74ghnLQM',
        'subject_issuer': 'google',
      },
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    );
    print(response.statusCode);
    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      data['email'] = await _getUserEmail(data['access_token']);
      html.window.localStorage['logoutBool'] = "false";
      return data;
    } else {
      print('Failed to exchange token with Keycloak');
      print(response.body);
      return null;
    }
  }

  Future<String?> _getUserEmail(String keycloakAccessToken) async {
    List<String> parts = keycloakAccessToken.split('.');
    if (parts.length == 3) {
      String payload = parts[1];
      String decoded = utf8.decode(base64Url.decode(base64Url.normalize(payload)));
      Map<String, dynamic> decodedMap = json.decode(decoded);
      return decodedMap['email'];
    }
    return null;
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login Page')),
      body: Center(
        child: ElevatedButton(
          onPressed: _checkForKeycloakToken, // Now only triggered when user clicks the button
          child: Text('Sign in with Google'),
        ),
      ),
    );
  }
}
