import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend_login/config.dart';
import 'package:http/http.dart' as http;

class JoinCompanyPage extends StatefulWidget {
  final String keycloakAccessToken; // Accept access token from the previous page

  const JoinCompanyPage({Key? key, required this.keycloakAccessToken}) : super(key: key);

  @override
  State<JoinCompanyPage> createState() => _JoinCompanyPageState();
}

class _JoinCompanyPageState extends State<JoinCompanyPage> {
  final _formKey = GlobalKey<FormState>();
  String companyCode = '';
  String? errorMessage;
  String? user_id; // Store the user ID

  // Updated Keycloak server details
  final String keycloakUrl = '${Config.server}:8080';
  final String realmName = 'G-SSO-Connect';

  // Function to fetch user info and user ID from Keycloak
  Future<void> fetchUserInfo() async {
    Map<String, dynamic> userDetail = {}; // Store the response as a Map

    final userInfoUrl = '$keycloakUrl/realms/$realmName/protocol/openid-connect/userinfo';

    try {
      final response = await http.get(
        Uri.parse(userInfoUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.keycloakAccessToken}', // Use the access token here
        },
      );

      if (response.statusCode == 200) {
        final userInfo = json.decode(response.body);
        print("User Info: ${userInfo.toString()}");
        setState(() {
          userDetail = userInfo; // Store the decoded response as a Map
          user_id = userDetail['sub']; // Extract the user ID
        });
      } else {
        print("Failed to fetch user info");
      }
    } catch (e) {
      print("Error fetching user info: $e");
    }
  }

  // Function to fetch all groups from Keycloak
  Future<List<String>> fetchGroups() async {
    final response = await http.get(
      Uri.parse('$keycloakUrl/admin/realms/$realmName/groups'),
      headers: {
        'Authorization': 'Bearer ${widget.keycloakAccessToken}',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((group) => group['id'].toString()).toList(); // Fetch group IDs
    } else {
      throw Exception('Failed to load groups');
    }
  }

  // Function to add user to the group in Keycloak
  Future<void> addUserToGroup(String groupId) async {
    final response = await http.post(
      Uri.parse('$keycloakUrl/admin/realms/$realmName/users/$user_id/groups/$groupId'),
      headers: {
        'Authorization': 'Bearer ${widget.keycloakAccessToken}',
      },
    );

    if (response.statusCode == 204) {
      // Successfully added to group
      print('User added to group');
    } else {
      throw Exception('Failed to add user to group');
    }
  }

  @override
  void initState() {
    super.initState();
    fetchUserInfo(); // Fetch the user info when the page is initialized
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Join Company')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (errorMessage != null)
                Text(
                  errorMessage!,
                  style: TextStyle(color: Colors.red),
                ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Company Code'),
                onSaved: (value) {
                  companyCode = value!;
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the company code';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    try {
                      // Fetch groups from Keycloak
                      List<String> groups = await fetchGroups();
                      if (groups.contains(companyCode)) {
                        // If the company code matches a group ID, add user to the group
                        if (user_id != null) {
                          await addUserToGroup(companyCode);
                          // Navigate back to the Home page after joining
                          Navigator.pop(context);
                        } else {
                          setState(() {
                            errorMessage = 'User ID is not available.';
                          });
                        }
                      } else {
                        // Show error message if the company code is invalid
                        setState(() {
                          errorMessage = 'Invalid company code';
                        });
                      }
                    } catch (e) {
                      setState(() {
                        errorMessage = 'An error occurred: $e';
                      });
                    }
                  }
                },
                child: Text('Join Company'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
