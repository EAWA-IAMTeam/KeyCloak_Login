import 'dart:convert';
import 'package:frontend_login/config.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class CreateCompanyPage extends StatefulWidget {
  final String keycloakAccessToken;
  const CreateCompanyPage({Key? key, required this.keycloakAccessToken})
      : super(key: key);

  @override
  State<CreateCompanyPage> createState() => _CreateCompanyPageState();
}

class _CreateCompanyPageState extends State<CreateCompanyPage> {
  final _formKey = GlobalKey<FormState>();
  String companyName = '';
  String companyEmail = '';
  List<String> existingGroups = []; // List to store existing group names

  final String keycloakUrl = '${Config.server}:8080/admin/realms/G-SSO-Connect';
  String kcid = '';
  String kcsecret = '';
  final String clientRole = 'Owner';

  Future<void> fetchKeycloakConfig() async {
    final url = Uri.parse('http://localhost:3002/keycloak-config');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          kcid = data['KCID'];
          kcsecret = data['KCSecret'];
        });
      } else {
        print('Failed to fetch Keycloak config: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching Keycloak config: $e');
    }
  }

  Future<String?> _getClientAccessToken() async {
    final keycloakTokenUrl =
        '${Config.server}:8080/realms/G-SSO-Connect/protocol/openid-connect/token';

    try {
      final response = await http.post(
        Uri.parse(keycloakTokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_id': kcid,
          'client_secret': kcsecret,
          'grant_type': 'client_credentials',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        //print(data['access_token']);
        return data['access_token'];
      } else {
        print(
            'Failed to get access token. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error obtaining access token: $e');
    }
    return null;
  }

  Future<String?> _getGroupId(String groupName, {String? parentGroupId}) async {
    final token = await _getClientAccessToken();
    if (token == null) return null;

    try {
      if (parentGroupId == null) {
        // Fetch all top-level groups
        final response = await http.get(
          Uri.parse('$keycloakUrl/groups'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          final groups = jsonDecode(response.body) as List<dynamic>;
          for (var group in groups) {
            if (group['name'] == groupName) return group['id'];
            print("Get Groupid: " + group['name'] + group['id']);
          }
        } else {
          print(
              'Failed to fetch top-level groups. Status: ${response.statusCode}');
          print('Response: ${response.body}');
        }
      } else {
        // Fetch subgroups of the parent group using the `/children` endpoint
        final response = await http.get(
          Uri.parse('$keycloakUrl/groups/$parentGroupId/children'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          final subGroups = jsonDecode(response.body) as List<dynamic>;
          for (var subgroup in subGroups) {
            if (subgroup['name'] == groupName) return subgroup['id'];
            print("Get Subgroup id:" + subgroup["id"]);
          }
        } else {
          print(
              'Failed to fetch subgroups of parent group. Status: ${response.statusCode}');
          print('Response: ${response.body}');
        }
      }
    } catch (e) {
      print('Error fetching group ID: $e');
    }
    return null;
  }

  Future<String?> createGroup(String companyName) async {
    final token = await _getClientAccessToken();
    if (token == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$keycloakUrl/groups'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'name': companyName}),
      );

      if (response.statusCode == 201) {
        print('Group created successfully');
        return await _getGroupId(
            companyName); // Fetch the group ID after creation
      } else {
        print('Failed to create group. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error creating group: $e');
    }
    return null;
  }

  Future<void> createSubgroupAndAssignRole(String groupId) async {
    final token = await _getClientAccessToken();
    if (token == null) return;

    try {
      // Create the Owner subgroup if it doesn't exist
      String? subgroupId = await _getGroupId('Owner', parentGroupId: groupId);

      if (subgroupId == null) {
        final response = await http.post(
          Uri.parse('$keycloakUrl/groups/$groupId/children'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'name': 'Owner'}),
        );

        if (response.statusCode == 201) {
          print('Owner subgroup created successfully');
        } else {
          print(
              'Failed to create Owner subgroup. Status code: ${response.statusCode}');
          print('Response body: ${response.body}');
          return;
        }

        // Retry fetching the subgroup ID after creation
        const int maxRetries = 5;
        const Duration retryDelay = Duration(seconds: 1);
        for (int attempt = 1; attempt <= maxRetries; attempt++) {
          print('Retrying to fetch Owner subgroup ID (Attempt $attempt)...');
          await Future.delayed(retryDelay);
          subgroupId = await _getGroupId('Owner', parentGroupId: groupId);
          print("Subgroup id: $subgroupId");
          if (subgroupId != null) break;
        }

        if (subgroupId == null) {
          print('Failed to retrieve Owner subgroup ID after creation.');
          return;
        }
      }

      // Map the role to the parent group
      await _mapRoleToGroup(subgroupId);

      // Fetch the user ID
      final userId = await _getUserId();
      if (userId == null) {
        print('Failed to fetch user ID.');
        return;
      }

      // Add the user to the Owner subgroup
      await _addUserToSubgroup(groupId, subgroupId, userId);
    } catch (e) {
      print('Error creating subgroup or assigning role: $e');
    }
  }

  Future<String?> _getUserId() async {
    final token = widget.keycloakAccessToken.toString();
    if (token == "") return null;

    try {
      // Decode the JWT token
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);

      // Extract the 'sub' claim, which is the user ID
      String userId = decodedToken['sub'];
      print("userid: " + userId);
      return userId;
    } catch (e) {
      print('Error decoding token: $e');
    }
    return null;
  }

// Add user to the subgroup using the Keycloak API
  Future<void> _addUserToSubgroup(
      String groupId, String subgroupId, String userId) async {
    final token = await _getClientAccessToken();
    if (token == null) return;

    try {
      final response = await http.put(
        Uri.parse('$keycloakUrl/users/$userId/groups/$subgroupId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode([
          {'id': userId}
        ]), // Add user ID to the request body
      );

      if (response.statusCode == 204) {
        print('User added to the Owner subgroup successfully');
      } else {
        print(
            'Failed to add user to subgroup. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error adding user to subgroup: $e');
    }
  }

  Future<void> _mapRoleToGroup(String groupId) async {
    final token = await _getClientAccessToken();
    if (token == null) return;

    try {
      // First, retrieve the internal ID of the client
      final clientResponse = await http.get(
        Uri.parse('$keycloakUrl/clients?clientId=$kcid'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (clientResponse.statusCode == 200) {
        final clients = jsonDecode(clientResponse.body) as List<dynamic>;
        if (clients.isEmpty) {
          print('Client not found.');
          return;
        }

        final clientInternalId = clients[0]['id'];

        // Now, fetch the client role using the internal ID
        final roleResponse = await http.get(
          Uri.parse('$keycloakUrl/clients/$clientInternalId/roles/$clientRole'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        );

        if (roleResponse.statusCode == 200) {
          final role = jsonDecode(roleResponse.body);
          final response = await http.post(
            Uri.parse(
                '$keycloakUrl/groups/$groupId/role-mappings/clients/$clientInternalId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode([role]),
          );

          if (response.statusCode == 204) {
            print('Role mapped successfully');
          } else {
            print('Failed to map role. Status code: ${response.statusCode}');
            print('Response body: ${response.body}');
          }
        } else {
          print(
              'Failed to retrieve client role. Status code: ${roleResponse.statusCode}');
          print('Response body: ${roleResponse.body}');
        }
      } else {
        print(
            'Failed to retrieve client information. Status code: ${clientResponse.statusCode}');
        print('Response body: ${clientResponse.body}');
      }
    } catch (e) {
      print('Error mapping role to group: $e');
    }
  }

  Future<void> _showDialog(String title, String message) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

// Fetch existing groups from Keycloak and store them in the list
  Future<void> _fetchExistingGroups() async {
    final token = await _getClientAccessToken();
    if (token == null) return null;

    final response = await http.get(
      Uri.parse('$keycloakUrl/groups'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> groups = json.decode(response.body);
      setState(() {
        existingGroups =
            groups.map((group) => group['name'].toString()).toList();
      });
    } else {
      // Handle error (e.g., Keycloak server is down or invalid response)
      print("Failed to fetch groups from Keycloak");
    }
  }

  // Validator to check if the company already exists in the existing groups list
  String? _validateCompanyName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a company name';
    }
    if (existingGroups.contains(value)) {
      return 'Company Exists'; // If company exists, return error
    }
    return null;
  }

@override
void initState() {
  super.initState();
  _initialize();
}

Future<void> _initialize() async {
  await fetchKeycloakConfig();
  await _fetchExistingGroups();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Company')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Company Name'),
                onSaved: (value) {
                  companyName = value!;
                },
                validator: _validateCompanyName, // Use the local validator
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Company Email'),
                onSaved: (value) {
                  companyEmail = value!;
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a company email';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();

                    String? groupId = await _getGroupId(companyName);
                    groupId ??= await createGroup(companyName);

                    if (groupId != null) {
                      print("main ui get company group id" + groupId);
                      await createSubgroupAndAssignRole(groupId);
                      String username = JwtDecoder.decode(
                          widget.keycloakAccessToken)['preferred_username'];
                      String formattedTime =
                          DateFormat('dd/MM/yy hh:mm a').format(DateTime.now());
                      String successMessage =
                          'Company "$companyName" created successfully.\nUsername: $username\nTime Created: $formattedTime\n\nRedirecting you to the homepage.';
                      _showDialog('Success', successMessage);
                      //Navigator.pop(context); // Close the page
                    } else {
                      print('Group ID is null. Group creation failed.');
                    }
                  }
                },
                child: Text('Create Company'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
