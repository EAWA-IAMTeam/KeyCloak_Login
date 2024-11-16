// //**successful 121124 3.59pm */
// import 'package:flutter/material.dart';
// import 'package:frontend_login/home_page.dart';
// import 'dart:html' as html;
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// class LoginPage extends StatefulWidget {
//   const LoginPage({Key? key}) : super(key: key);

//   @override
//   State<LoginPage> createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginPage> {
//   Future<void> handleSignIn() async {
//     try {
//       var googleAccessToken = await _getGoogleAccessToken();
//       print(googleAccessToken.toString());

//       if (googleAccessToken != null) {
//         var keycloakTokens = await _exchangeGoogleTokenForKeycloakTokens(googleAccessToken);

//         if (keycloakTokens != null && keycloakTokens['access_token'] != null && keycloakTokens['refresh_token'] != null && keycloakTokens['email'] != null && mounted) {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (context) => HomePage(
//                 googleAccessToken: googleAccessToken,
//                 keycloakAccessToken: keycloakTokens['access_token'],
//                 keycloakRefreshToken: keycloakTokens['refresh_token'],
//                 email: keycloakTokens['email'],
//               ),
//             ),
//           );
//         }
//       }
//     } catch (error) {
//       print('Error during sign-in: $error');
//     }
//   }

//   Future<String?> _getGoogleAccessToken() async {
//     html.window.open(
//       'https://accounts.google.com/o/oauth2/v2/auth?'
//       'client_id=950385657379-k0kk7l3nvdm8cbgp31fjvet0c5neluc7.apps.googleusercontent.com&'
//       'redirect_uri=http://localhost:3001/callback.html&' // Updated redirect URI to match Google Cloud Console
//       'response_type=token&'
//       'scope=email profile openid',
//       'google_sign_in_popup',
//       'width=500,height=600'
//     );
    
//     return await _pollForToken();
//   }

//   Future<String?> _pollForToken() async {
//     for (var i = 0; i < 10; i++) {
//       await Future.delayed(Duration(seconds: 1));
//       var token = html.window.localStorage['googleAccessToken'];
//       if (token != null) {
//          print(token);
//         return token;
//       }
//       else{
//         print("No token");
//       }
//     }
//     return null;
//   }

//   Future<Map<String, dynamic>?> _exchangeGoogleTokenForKeycloakTokens(String googleAccessToken) async {
//   final String keycloakUrl = 'http://localhost:8080/realms/G-SSO-Connect/protocol/openid-connect/token';
  
//   final response = await http.post(
//     Uri.parse(keycloakUrl),
//     body: {
//       'grant_type': 'urn:ietf:params:oauth:grant-type:token-exchange', // Token exchange grant type
//       'subject_token': googleAccessToken, // Google access token
//       'client_id': 'frontend-login',
//       'client_secret': '0SSZj01TDs7812fLBxgwTKPA74ghnLQM',
//       'subject_issuer': 'google', // Set this to the identity provider alias for Google in Keycloak
//     },
//     headers: {'Content-Type': 'application/x-www-form-urlencoded'},
//   );
//   print(response.statusCode);
//   if (response.statusCode == 200) {
//     var data = json.decode(response.body);
//     data['email'] = await _getUserEmail(data['access_token']);
//     print(data);
//     return data;
//   } else {
//     print('Failed to exchange token with Keycloak');
//     print(response.body);  // Print response for debugging
//     return null;
//   }
// }

//   Future<String?> _getUserEmail(String keycloakAccessToken) async {
//      List<String> parts = keycloakAccessToken.split('.');
//   if (parts.length == 3) {
//     // Decode the payload (second part of the token)
//     String payload = parts[1];
//     String decoded = utf8.decode(base64Url.decode(base64Url.normalize(payload)));
//     Map<String, dynamic> decodedMap = json.decode(decoded);
    
//     return decodedMap['email']; // Assuming 'email' is the key in the payload
//   }
//     // final response = await http.get(
//     //   Uri.parse('http://localhost:8080/realms/G-SSO-Connect/protocol/openid-connect/userinfo'),
//     //   headers: {'Authorization': 'Bearer $keycloakAccessToken'},
//     // );

//     // if (response.statusCode == 200) {
//     //   var data = json.decode(response.body);
//     //   return data['email'];
//     // }
//     return null;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Login Page')),
//       body: Center(
//         child: ElevatedButton(
//           onPressed: handleSignIn,
//           child: Text('Sign in with Google'),
//         ),
//       ),
//     );
//   }
// }

// //**successful 121124 5.58pm */
// import 'package:flutter/material.dart';
// import 'package:frontend_login/home_page.dart';
// import 'dart:html' as html;
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// class LoginPage extends StatefulWidget {
//   const LoginPage({Key? key}) : super(key: key);

//   @override
//   State<LoginPage> createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginPage> {
//   // Check if token exists before proceeding to sign-in
//   void _checkToken() {
//     String? googleAccessToken = html.window.localStorage['googleAccessToken'];
//     if (googleAccessToken != null) {
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder: (context) => HomePage(
//             googleAccessToken: googleAccessToken,
//             keycloakAccessToken: '',  // Placeholder, you will set the real value later
//             keycloakRefreshToken: '',  // Placeholder
//             email: '',  // Placeholder
//           ),
//         ),
//       );
//     } else {
//       handleSignIn();  // If no token, start Google Sign-in flow
//     }
//   }

//   Future<void> handleSignIn() async {
//     try {
//       var googleAccessToken = await _getGoogleAccessToken();
//       print(googleAccessToken.toString());

//       if (googleAccessToken != null) {
//         var keycloakTokens = await _exchangeGoogleTokenForKeycloakTokens(googleAccessToken);

//         if (keycloakTokens != null && keycloakTokens['access_token'] != null && keycloakTokens['refresh_token'] != null && keycloakTokens['email'] != null && mounted) {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (context) => HomePage(
//                 googleAccessToken: googleAccessToken,
//                 keycloakAccessToken: keycloakTokens['access_token'],
//                 keycloakRefreshToken: keycloakTokens['refresh_token'],
//                 email: keycloakTokens['email'],
//               ),
//             ),
//           );
//         }
//       }
//     } catch (error) {
//       print('Error during sign-in: $error');
//     }
//   }

//   Future<String?> _getGoogleAccessToken() async {
//     html.window.open(
//       'https://accounts.google.com/o/oauth2/v2/auth?'
//       'client_id=950385657379-k0kk7l3nvdm8cbgp31fjvet0c5neluc7.apps.googleusercontent.com&'
//       'redirect_uri=http://localhost:3001/callback.html&'
//       'response_type=token&'
//       'scope=email profile openid',
//       'google_sign_in_popup',
//       'width=500,height=600'
//     );
    
//     return await _pollForToken();
//   }

//   Future<String?> _pollForToken() async {
//     for (var i = 0; i < 10; i++) {
//       await Future.delayed(Duration(seconds: 1));
//       var token = html.window.localStorage['googleAccessToken'];
//       if (token != null) {
//         print(token);
//         return token;
//       } else {
//         print("No token");
//       }
//     }
//     return null;
//   }

//   Future<Map<String, dynamic>?> _exchangeGoogleTokenForKeycloakTokens(String googleAccessToken) async {
//     final String keycloakUrl = 'http://localhost:8080/realms/G-SSO-Connect/protocol/openid-connect/token';
    
//     final response = await http.post(
//       Uri.parse(keycloakUrl),
//       body: {
//         'grant_type': 'urn:ietf:params:oauth:grant-type:token-exchange',
//         'subject_token': googleAccessToken,
//         'client_id': 'frontend-login',
//         'client_secret': '0SSZj01TDs7812fLBxgwTKPA74ghnLQM',
//         'subject_issuer': 'google',
//       },
//       headers: {'Content-Type': 'application/x-www-form-urlencoded'},
//     );
//     print(response.statusCode);
//     if (response.statusCode == 200) {
//       var data = json.decode(response.body);
//       data['email'] = await _getUserEmail(data['access_token']);
//       print(data);
//       return data;
//     } else {
//       print('Failed to exchange token with Keycloak');
//       print(response.body);
//       return null;
//     }
//   }

//   Future<String?> _getUserEmail(String keycloakAccessToken) async {
//     List<String> parts = keycloakAccessToken.split('.');
//     if (parts.length == 3) {
//       String payload = parts[1];
//       String decoded = utf8.decode(base64Url.decode(base64Url.normalize(payload)));
//       Map<String, dynamic> decodedMap = json.decode(decoded);
//       return decodedMap['email'];
//     }
//     return null;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Login Page')),
//       body: Center(
//         child: ElevatedButton(
//           onPressed: _checkToken,
//           child: Text('Sign in with Google'),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:frontend_login/home_page.dart';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

Future<void> _checkForKeycloakSession() async {
  print(html.window.localStorage['keycloakAccessToken'].toString());
  final String keycloakSessionCheckUrl = 'http://localhost:8080/realms/G-SSO-Connect/protocol/openid-connect/token/introspect';
  try {
    final response = await http.post(
      Uri.parse(keycloakSessionCheckUrl),
      body: {
        'client_id': 'frontend-login',
        'client_secret': '0SSZj01TDs7812fLBxgwTKPA74ghnLQM',
        'token': html.window.localStorage['keycloakAccessToken'] ?? '',
      },
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    );
  print(response.statusCode);
    if (response.statusCode == 200) {
      var sessionData = json.decode(response.body);
      if (sessionData['active'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(
              googleAccessToken: '',
              keycloakAccessToken: html.window.localStorage['keycloakAccessToken'] ?? '',
              keycloakRefreshToken: html.window.localStorage['keycloakRefreshToken'] ?? '',
              email: html.window.localStorage['email'] ?? '',
            ),
          ),
        );
      } else {
        handleSignIn();
      }
    } else {
      print("Failed introspect with status: ${response.statusCode}");
      handleSignIn();
    }
  } catch (error) {
    print("Error during introspect: $error");
    _showErrorDialog('Failed to check session');
  }
}


  // Handle Google Sign-In
  Future<void> handleSignIn() async {
    // Open Google Sign-In popup
    html.window.open(
      'https://accounts.google.com/o/oauth2/v2/auth?'
      'client_id=950385657379-k0kk7l3nvdm8cbgp31fjvet0c5neluc7.apps.googleusercontent.com&'
      'redirect_uri=http://localhost:3001/callback.html&'
      'response_type=token&'
      'scope=email profile openid',
      'google_sign_in_popup',
      'width=500,height=600'
    );

    // Wait for a while to ensure Google sign-in is completed
    await Future.delayed(Duration(seconds: 3));

    // Check if the Google token is available
    final String? googleToken = html.window.localStorage['googleAccessToken'];

    if (googleToken != null && googleToken.isNotEmpty) {
      // Google Sign-In successful, store token and navigate to home page
      html.window.localStorage['googleAccessToken'] = googleToken;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(
            googleAccessToken: googleToken,
            keycloakAccessToken: '',
            keycloakRefreshToken: '',
            email: html.window.localStorage['email'] ?? '',
          ),
        ),
      );
    } else {
      // If token not found, show an error message
      _showErrorDialog('Google Sign-In failed');
    }
  }

  // Show error message if needed
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login Page')),
      body: Center(
        child: ElevatedButton(
          onPressed: _checkForKeycloakSession, // Check for Keycloak session first
          child: Text('Sign in with Google'),
        ),
      ),
    );
  }
}




//2. FedCM ERROR -latest successful
// import 'package:flutter/material.dart';
// import 'package:frontend_login/home_page.dart';
// import 'package:google_sign_in/google_sign_in.dart';

// class LoginPage extends StatefulWidget {
//   const LoginPage({Key? key}) : super(key: key);

//   @override
//   State<LoginPage> createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginPage> {
//   final GoogleSignIn _googleSignIn = GoogleSignIn(
//     scopes: <String>[
//       'email', // Access to user's email
//       'profile', // Access to user's profile data
//     ],
//   );

//   Future<void> handleSignIn() async {
//     try {
//       // Trigger the Google sign-in process
//       GoogleSignInAccount? user = await _googleSignIn.signInSilently();

//       if (user != null && mounted) {
//         // Use a post-frame callback to ensure safe navigation
//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           if (mounted) {
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => HomePage(),
//               ),
//             );
//           }
//         });
//       }
//     } catch (error) {
//       print('Error during sign-in: $error');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Login Page')),
//       body: Center(
//         child: ElevatedButton(
//           onPressed: handleSignIn, // Trigger handleSignIn on button press
//           child: Text('Sign in with Google'),
//         ),
//       ),
//     );
//   }
// }

//1.400 ERROR
// import 'package:flutter/material.dart';
// import 'package:frontend_login/home_page.dart';
// import 'package:google_sign_in/google_sign_in.dart';

// class LoginPage extends StatefulWidget {
//   const LoginPage({Key? key}) : super(key: key);

//   @override
//   State<LoginPage> createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginPage> {
//  final GoogleSignIn _googleSignIn = GoogleSignIn(
//     scopes: <String>[
//       'email', // Access to user's email
//       'profile', // Access to user's profile data
//     ],
//   );

//   Future<void> handleSignIn() async {
//     try {
//       // Trigger the Google sign-in process
//       GoogleSignInAccount? user = await _googleSignIn.signIn();

//       if (user != null && mounted) {
//         // Use a post-frame callback to ensure safe navigation
//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           if (mounted) {
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => HomePage(),
//               ),
//             );
//           }
//         });
//       }
//     } catch (error) {
//       print('Error during sign-in: $error');
//     }
//   }


//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Login Page')),
//       body: Center(
//         child: ElevatedButton(
//           onPressed: handleSignIn, // Trigger handleSignIn on button press
//           child: Text('Sign in with Google'),
//         ),
//       ),
//     );
//   }
// }