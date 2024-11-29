import 'package:flutter/material.dart';
import 'package:frontend_login/config.dart';
import 'package:frontend_login/create_company.dart';
import 'package:frontend_login/join_company.dart';
import 'package:frontend_login/login_page.dart'; // Import the LoginPage to navigate back
import 'package:frontend_login/select_company.dart';
import 'package:frontend_login/select_companyforuser.dart';
import 'dart:html' as html;
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
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

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<void> _logout(BuildContext context) async {
    // Revoke Google Access Token by calling Google's revocation endpoint
    final googleAccessToken = html.window.localStorage['googleAccessToken'];
    print("GAT: $googleAccessToken");
    if (googleAccessToken != null) {
      final revokeUrl =
          'https://oauth2.googleapis.com/revoke?token=$googleAccessToken';
      try {
        final response = await http.post(Uri.parse(revokeUrl));
        print(response.statusCode);
        if (response.statusCode == 200) {
          print("Google Access Token successfully revoked.");
        } else {
          print("Failed to revoke Google Access Token.");
        }
      } catch (e) {
        print("Error during Google token revocation: $e");
      }
    } else {
      print("Google Access Token already deleted.");
    }

    // Clear local storage
    html.window.localStorage.remove('keycloakAccessToken');
    html.window.localStorage.remove('keycloakRefreshToken');
    html.window.localStorage.remove('googleAccessToken');
    html.window.localStorage.remove('email');
    html.window.localStorage['logoutBool'] = "true";

    // Clear cookies with domain "accounts.google.com"
    _clearGoogleCookies();

    print("Logout completed and cookies cleared.");

    final keycloakLogoutUrl =
        '${Config.server}:8080/realms/G-SSO-Connect/protocol/openid-connect/logout';

    // Perform Keycloak logout by calling Keycloak's logout endpoint
    try {
      final response = await http.post(
        Uri.parse(keycloakLogoutUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_id': 'frontend-login',
          'client_secret': '0SSZj01TDs7812fLBxgwTKPA74ghnLQM',
          'refresh_token':
              widget.keycloakRefreshToken, // Pass the refresh token here
        },
      );

      if (response.statusCode == 204) {
        // If logout is successful on Keycloak, redirect to the Login page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      } else {
        // Handle logout failure
        print('Error logging out from Keycloak: ${response.statusCode}');
      }
    } catch (error) {
      // Handle the error (e.g., network issues)
      print('Error during Keycloak logout: $error');
    }
  }

// Function to clear cookies with domain "accounts.google.com"
  void _clearGoogleCookies() {
    final cookies = [
      "ACCOUNT_CHOOSER",
      "APISID",
      "HSID",
      "LSID",
      "LSOLH",
      "NID",
      "OTZ",
      "SAPISID",
      "SID",
      "SIDCC",
      "SMSV",
      "SSID",
      "__Host-1PLSID",
      "__Host-3PLSID",
      "__Host-GAPS",
      "__Secure-1PAPISID",
      "__Secure-1PSID",
      "__Secure-1PSIDCC",
      "__Secure-3PAPISID",
      "__Secure-3PSID",
      "__Secure-3PSIDCC",
    ];

    // Loop through each cookie name and clear it by setting it to expire in the past
    for (var cookie in cookies) {
      html.document.cookie =
          "$cookie=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/; domain=accounts.google.com;";
    }
  }

  // Function to refresh access token
  Future<String?> _refreshAccessToken() async {
    final refreshToken = widget.keycloakRefreshToken;
    if (refreshToken.isNotEmpty) {
      final url =
          '${Config.server}:8080/realms/G-SSO-Connect/protocol/openid-connect/token';
      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'client_id': 'frontend-login',
            'client_secret': '0SSZj01TDs7812fLBxgwTKPA74ghnLQM',
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
          },
        );

        if (response.statusCode == 200) {
          final responseBody = response.body;
          // Extract the new access token from the response
          final accessToken =
              responseBody; // Modify this to extract the access token from JSON
          return accessToken;
        } else {
          print('Failed to refresh token: ${response.statusCode}');
        }
      } catch (e) {
        print('Error during token refresh: $e');
      }
    }
    return null;
  }

  // Function to call the API with the Keycloak access token
  Future<void> _callApiWithToken() async {
    String token = widget.keycloakAccessToken;
    if (token.isEmpty) {
      token = await _refreshAccessToken() ??
          ''; // Try refreshing the token if empty
    }

    if (token.isNotEmpty) {
      try {
        print('Using token: $token'); // Log token to ensure it's correct
        final response = await http.get(
          Uri.parse(
              'http:/example.com:9080/headers'), // Replace with your actual API
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          print('API call successful');
          print("APISIX response body: ${response.body}");
        } else {
          print('API call failed with status: ${response.statusCode}');
          print(
              'Response body: ${response.body}'); // Log response body for further analysis
        }
      } catch (e) {
        print('Error during API call: $e');
      }
    } else {
      print('No valid access token available');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Home')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              widget.keycloakAccessToken.isNotEmpty
                  ? Column(
                      children: [
                        Text('Email: ${widget.email}'),
                        SizedBox(height: 10),
                        Text(
                            'Keycloak Access Token: ${widget.keycloakAccessToken}'),
                        SizedBox(height: 10),
                        Text(
                            'Keycloak Refresh Token: ${widget.keycloakRefreshToken}'),
                        SizedBox(height: 20),

                        // First Row with Select Company, Create Company, and Join Company
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SelectCompanyPage(
                                      keycloakAccessToken:
                                          widget.keycloakAccessToken,
                                    ),
                                  ),
                                );
                              },
                              child: Text('Select Company'),
                            ),
                            SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        SelectCompanyforuserPage(
                                      keycloakAccessToken:
                                          widget.keycloakAccessToken,
                                    ),
                                  ),
                                );
                              },
                              child: Text('Invite User'),
                            ),
                            SizedBox(
                                width:
                                    10), // Add some space between the buttons
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CreateCompanyPage(
                                      keycloakAccessToken:
                                          widget.keycloakAccessToken,
                                    ),
                                  ),
                                );
                              },
                              child: Text('Create Company'),
                            ),
                            SizedBox(
                                width:
                                    10), // Add some space between the buttons
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => JoinCompanyPage(
                                      keycloakAccessToken:
                                          widget.keycloakAccessToken,
                                    ),
                                  ),
                                );
                              },
                              child: Text('Join Company'),
                            ),
                            SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () {
                                _callApiWithToken();
                              },
                              child: Text('Connect with APISIX'),
                            ),
                          ],
                        ),
                        // Second Row Logout
                        SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => _logout(context),
                              child: Text('Logout'),
                            ),
                          ],
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
      ),
    );
  }
}
