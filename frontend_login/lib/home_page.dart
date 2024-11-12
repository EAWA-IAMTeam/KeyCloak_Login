// //**latest successful 121124 3.59pm */
// import 'package:flutter/material.dart';

// class HomePage extends StatelessWidget {
//   final String googleAccessToken;
//   final String keycloakAccessToken;
//   final String keycloakRefreshToken;
//   final String email;

//   const HomePage({
//     Key? key,
//     required this.googleAccessToken,
//     required this.keycloakAccessToken,
//     required this.keycloakRefreshToken,
//     required this.email,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Home')),
//       body: Padding(
//         padding: EdgeInsets.all(20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Email: $email'),
//             SizedBox(height: 10),
//             Text('Google Access Token: $googleAccessToken'),
//             SizedBox(height: 10),
//             Text('Keycloak Access Token: $keycloakAccessToken'),
//             SizedBox(height: 10),
//             Text('Keycloak Refresh Token: $keycloakRefreshToken'),
//           ],
//         ),
//       ),
//     );
//   }
// }

// //**latest successful 121124 5.58pm */
// import 'package:flutter/material.dart';
// import 'package:frontend_login/login_page.dart';  // Import the LoginPage to navigate back
// import 'dart:html' as html;

// class HomePage extends StatelessWidget {
//   final String googleAccessToken;
//   final String keycloakAccessToken;
//   final String keycloakRefreshToken;
//   final String email;

//   const HomePage({
//     Key? key,
//     required this.googleAccessToken,
//     required this.keycloakAccessToken,
//     required this.keycloakRefreshToken,
//     required this.email,
//   }) : super(key: key);

//   void _logout(BuildContext context) {
//     html.window.localStorage.remove('googleAccessToken');
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (context) => const LoginPage()),  // Redirect to login page
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Home')),
//       body: Padding(
//         padding: const EdgeInsets.all(20),
//         child: googleAccessToken.isNotEmpty ? Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Email: $email'),
//             SizedBox(height: 10),
//             Text('Google Access Token: $googleAccessToken'),
//             SizedBox(height: 10),
//             Text('Keycloak Access Token: $keycloakAccessToken'),
//             SizedBox(height: 10),
//             Text('Keycloak Refresh Token: $keycloakRefreshToken'),
//             SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: () => _logout(context),
//               child: Text('Logout'),
//             ),
//           ],
//         ) : Column(
//           children: [
//             Text('Login failed. Please try again.'),
//             SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: () => Navigator.pushReplacement(
//                 context,
//                 MaterialPageRoute(builder: (context) => const LoginPage()),
//               ),
//               child: Text('Login'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:frontend_login/login_page.dart';  // Import the LoginPage to navigate back
import 'dart:html' as html;

class HomePage extends StatelessWidget {
  final String googleAccessToken;
  final String keycloakAccessToken;
  final String keycloakRefreshToken;
  final String email;

  const HomePage({
    Key? key,
    required this.googleAccessToken,
    required this.keycloakAccessToken,
    required this.keycloakRefreshToken,
    required this.email,
  }) : super(key: key);

  // Function to handle logout
  void _logout(BuildContext context) {
    // Clear all tokens from localStorage
    html.window.localStorage.remove('googleAccessToken');
    html.window.localStorage.remove('keycloakAccessToken');
    html.window.localStorage.remove('keycloakRefreshToken');
    
    // Navigate back to the Login page
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),  // Redirect to login page
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Home')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            keycloakAccessToken.isNotEmpty
                ? Column(
                    children: [
                      Text('Email: $email'),
                      SizedBox(height: 10),
                      Text('Keycloak Access Token: $keycloakAccessToken'),
                      SizedBox(height: 10),
                      Text('Keycloak Refresh Token: $keycloakRefreshToken'),
                      SizedBox(height: 20),
                      // Add the Logout Button
                      ElevatedButton(
                        onPressed: () => _logout(context),
                        child: Text('Logout'),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Text('Login failed. Please try again.'),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const LoginPage()),
                          );
                        },
                        child: Text('Login'),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// class HomePage extends StatefulWidget {
//   final String googleAccessToken;
//   const HomePage({Key? key, required this.googleAccessToken}) : super(key: key);

//   @override
//   _HomePageState createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   String _accessToken = "";
//   String _refreshToken = "";
//   String _expiresIn = "";

//   @override
//   void initState() {
//     super.initState();
//     _exchangeGoogleTokenForKeycloakTokens(widget.googleAccessToken);
//   }

//   Future<void> _exchangeGoogleTokenForKeycloakTokens(String googleAccessToken) async {
//     final String keycloakUrl = 'http://localhost:8080/realms/G-SSO-Connect/protocol/openid-connect/token';

//     final response = await http.post(
//       Uri.parse(keycloakUrl),
//       body: {
//         'grant_type': 'authorization_code',
//         'code': googleAccessToken,
//         'client_id': 'frontend-login',
//         'client_secret': '', // Replace with actual client secret
//         'redirect_uri': 'http://localhost:8080/realms/G-SSO-Connect/broker/google/endpoint',
//       },
//       headers: {
//         'Content-Type': 'application/x-www-form-urlencoded',
//       },
//     );

//     if (response.statusCode == 200) {
//       var data = json.decode(response.body);
//       setState(() {
//         _accessToken = data['access_token'];
//         _refreshToken = data['refresh_token'];
//         _expiresIn = DateTime.now().add(Duration(seconds: data['expires_in'])).toString();
//       });
//     } else {
//       throw Exception('Failed to exchange Google token for Keycloak tokens');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Home')),
//       body: Padding(
//         padding: EdgeInsets.all(20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Access Token: $_accessToken'),
//             Text('Refresh Token: $_refreshToken'),
//             Text('Expires In: $_expiresIn'),
//           ],
//         ),
//       ),
//     );
//   }
// }

//2. FedCM ERROR -latest successful
// import 'package:flutter/material.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// class HomePage extends StatefulWidget {
//   @override
//   _HomePageState createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   GoogleSignIn _googleSignIn = GoogleSignIn(
//     scopes: <String>[
//       'email', // standard scope for access to user's email
//       'profile', // User profile data
//     ],
//   );

//   String _email = "";
//   String _accessToken = "";
//   String _refreshToken = "";
//   String _expiresIn = "";

//   @override
//   void initState() {
//     super.initState();
//     _initializeUserInfo();
//   }

//   // Trigger the Google sign-in process
//   Future<void> handleSignIn() async {
//     try {
//       GoogleSignInAccount? user = await _googleSignIn.signIn();

//       if (user != null) {
//         // Get the authentication details from the signed-in user
//         GoogleSignInAuthentication auth = await user.authentication;

//         // Now you can access the Google access token (for use in Keycloak)
//         String? googleAccessToken = auth.accessToken;

//         // Send the Google token to Keycloak to exchange it for Keycloak tokens
//         await _exchangeGoogleTokenForKeycloakTokens(googleAccessToken!);
//       }
//     } catch (error) {
//       print('Error during sign-in: $error');
//     }
//   }

//   // Exchange the Google token for Keycloak access and refresh tokens
//   Future<void> _exchangeGoogleTokenForKeycloakTokens(String googleAccessToken) async {
//     final String keycloakUrl = 'http://localhost:8080/realms/G-SSO-Connect/protocol/openid-connect/token';
    
//     // Prepare the data to send to Keycloak (OAuth2 Token Exchange)
//     final response = await http.post(
//       Uri.parse(keycloakUrl),
//       body: {
//         'grant_type': 'authorization_code', // Token exchange grant type
//         'code': googleAccessToken, // Pass the Google access token to Keycloak
//         'client_id': 'frontend-login', // Keycloak client ID
//         'client_secret': '', // Keycloak client secret if needed
//         'redirect_uri': 'http://localhost:8080/realms/G-SSO-Connect/broker/google/endpoint', // The redirect URI used for OAuth
//       },
//       headers: {
//         'Content-Type': 'application/x-www-form-urlencoded',
//       },
//     );

//     if (response.statusCode == 200) {
//       var data = json.decode(response.body);
//       setState(() {
//         _accessToken = data['access_token'];
//         _refreshToken = data['refresh_token'];
//         _expiresIn = DateTime.now().add(Duration(seconds: data['expires_in'])).toString();
//       });
//       print('Keycloak Access Token: $_accessToken');
//       print('Keycloak Refresh Token: $_refreshToken');
//       print('Expires In: $_expiresIn');
//     } else {
//       throw Exception('Failed to exchange Google token for Keycloak tokens');
//     }
//   }

//   // Initialize user info if already signed in
//   Future<void> _initializeUserInfo() async {
//     GoogleSignInAccount? user = _googleSignIn.currentUser;
//     if (user != null) {
//       setState(() {
//         _email = user.email;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Home')),
//       body: Padding(
//         padding: EdgeInsets.all(20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             if (_email.isNotEmpty) ...[
//               Text('Email: $_email'),
//               SizedBox(height: 20),
//               Text('Access Token: $_accessToken'),
//               Text('Refresh Token: $_refreshToken'),
//               Text('Expires In: $_expiresIn'),
//             ],
//             SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: handleSignIn,
//               child: Text('Sign In with Google'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// class HomePage extends StatefulWidget {
//   @override
//   _HomePageState createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   GoogleSignIn _googleSignIn = GoogleSignIn(
//     scopes: <String>[
//       'email', // standard scope for access to user's email
//       'profile', // User profile data
//     ],
//   );

//   String _email = "";
//   String _accessToken = "";
//   String _refreshToken = "";
//   String _expiresIn = "";

//   @override
//   void initState() {
//     super.initState();
//     _initializeUserInfo();
//   }

//   // Trigger the Google sign-in process
//   Future<void> handleSignIn() async {
//     try {
//       GoogleSignInAccount? user = await _googleSignIn.signIn();

//       if (user != null) {
//         // Get the authentication details from the signed-in user
//         GoogleSignInAuthentication auth = await user.authentication;

//         // Now you can access the Google access token (for use in Keycloak)
//         String? googleAccessToken = auth.accessToken;

//         // Send the Google token to Keycloak to exchange it for Keycloak tokens
//         await _exchangeGoogleTokenForKeycloakTokens(googleAccessToken!);
//       }
//     } catch (error) {
//       print('Error during sign-in: $error');
//     }
//   }

//   // Exchange the Google token for Keycloak access and refresh tokens
//   Future<void> _exchangeGoogleTokenForKeycloakTokens(String googleAccessToken) async {
//     final String keycloakUrl = 'http://localhost:8080/realms/G-SSO-Connect/protocol/openid-connect/token';
    
//     // Prepare the data to send to Keycloak (OAuth2 Token Exchange)
//     final response = await http.post(
//       Uri.parse(keycloakUrl),
//       body: {
//         'grant_type': 'authorization_code', // Token exchange grant type
//         'code': googleAccessToken, // Pass the Google access token to Keycloak
//         'client_id': 'frontend-login', // Keycloak client ID
//         'client_secret': '', // Keycloak client secret if needed
//         'redirect_uri': 'http://localhost:8080/realms/G-SSO-Connect/broker/google/endpoint', // The redirect URI used for OAuth
//       },
//       headers: {
//         'Content-Type': 'application/x-www-form-urlencoded',
//       },
//     );

//     if (response.statusCode == 200) {
//       var data = json.decode(response.body);
//       setState(() {
//         _accessToken = data['access_token'];
//         _refreshToken = data['refresh_token'];
//         _expiresIn = DateTime.now().add(Duration(seconds: data['expires_in'])).toString();
//       });
//       print('Keycloak Access Token: $_accessToken');
//       print('Keycloak Refresh Token: $_refreshToken');
//       print('Expires In: $_expiresIn');
//     } else {
//       throw Exception('Failed to exchange Google token for Keycloak tokens');
//     }
//   }

//   // Initialize user info if already signed in
//   Future<void> _initializeUserInfo() async {
//     GoogleSignInAccount? user = _googleSignIn.currentUser;
//     if (user != null) {
//       setState(() {
//         _email = user.email;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Home')),
//       body: Padding(
//         padding: EdgeInsets.all(20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             if (_email.isNotEmpty) ...[
//               Text('Email: $_email'),
//               SizedBox(height: 20),
//               Text('Access Token: $_accessToken'),
//               Text('Refresh Token: $_refreshToken'),
//               Text('Expires In: $_expiresIn'),
//             ],
//             SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: handleSignIn,
//               child: Text('Sign In with Google'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }