import 'dart:convert';
import 'package:frontend_login/config.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class CreateCompanyPage extends StatefulWidget {
  final String keycloakAccessToken;
  const CreateCompanyPage({Key? key, required this.keycloakAccessToken}) : super(key: key);

  @override
  State<CreateCompanyPage> createState() => _CreateCompanyPageState();
}

class _CreateCompanyPageState extends State<CreateCompanyPage> {
  final _formKey = GlobalKey<FormState>();
  String companyName = '';
  String companyEmail = '';

  final String keycloakUrl = '${Config.server}:8080/admin/realms/G-SSO-Connect';
  final String clientId = 'frontend-login';
  final String clientSecret = '0SSZj01TDs7812fLBxgwTKPA74ghnLQM';
  final String clientRole = 'Admin';

  Future<String?> _getClientAccessToken() async {
    final keycloakTokenUrl = '${Config.server}:8080/realms/G-SSO-Connect/protocol/openid-connect/token';

    try {
      final response = await http.post(
        Uri.parse(keycloakTokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'grant_type': 'client_credentials',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['access_token'];
      } else {
        print('Failed to get access token. Status code: ${response.statusCode}');
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
          print ("Get Groupid: " + group['id']);
        }
      } else {
        print('Failed to fetch top-level groups. Status: ${response.statusCode}');
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
        print('Failed to fetch subgroups of parent group. Status: ${response.statusCode}');
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
        return await _getGroupId(companyName); // Fetch the group ID after creation
        
      } else {
        print('Failed to create group. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error creating group: $e');
    }
    return null;
  }

  // Future<void> createSubgroupAndAssignRole(String groupId) async {
  //   final token = await _getClientAccessToken();
  //   if (token == null) return;

  //   try {
  //     final subgroupId = await _getGroupId('Admin', parentGroupId: groupId);
  //     if (subgroupId == null) {
  //       final response = await http.post(
  //         Uri.parse('$keycloakUrl/groups/$groupId/children'),
  //         headers: {
  //           'Authorization': 'Bearer $token',
  //           'Content-Type': 'application/json',
  //         },
  //         body: jsonEncode({'name': 'Admin'}),
  //       );

  //       if (response.statusCode == 201) {
  //         print('Admin subgroup created successfully');
  //       } else {
  //         print('Failed to create Admin subgroup. Status code: ${response.statusCode}');
  //         print('Response body: ${response.body}');
  //       }
  //     }

  //     await _mapRoleToGroup(groupId);
  //   } catch (e) {
  //     print('Error creating subgroup or assigning role: $e');
  //   }
  // }

Future<void> createSubgroupAndAssignRole(String groupId) async {
  final token = await _getClientAccessToken();
  if (token == null) return;

  try {
    // Create the Admin subgroup if it doesn't exist
    String? subgroupId = await _getGroupId('Admin', parentGroupId: groupId);

    if (subgroupId == null) {
      final response = await http.post(
        Uri.parse('$keycloakUrl/groups/$groupId/children'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'name': 'Admin'}),
      );

      if (response.statusCode == 201) {
        print('Admin subgroup created successfully');
      } else {
        print('Failed to create Admin subgroup. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        return;
      }

      // Retry fetching the subgroup ID after creation
      const int maxRetries = 5;
      const Duration retryDelay = Duration(seconds: 1);
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        print('Retrying to fetch Admin subgroup ID (Attempt $attempt)...');
        await Future.delayed(retryDelay);
        subgroupId = await _getGroupId('Admin', parentGroupId: groupId);
        print("Subgroup id: $subgroupId");
        if (subgroupId != null) break;
      }

      if (subgroupId == null) {
        print('Failed to retrieve Admin subgroup ID after creation.');
        return;
      }
    }

    // Map the role to the parent group
    await _mapRoleToGroup(groupId);

    // Fetch the user ID
    final userId = await _getUserId();
    if (userId == null) {
      print('Failed to fetch user ID.');
      return;
    }

    // Add the user to the Admin subgroup
    await _addUserToSubgroup(subgroupId, userId);

  } catch (e) {
    print('Error creating subgroup or assigning role: $e');
  }
}


//     // Map the role to the group
//     await _mapRoleToGroup(groupId);

//     // After subgroup creation, add the user to the Admin subgroup
//     final userId = await _getUserId();  // You need to implement the logic to retrieve the user ID
//     if (userId != null) {
//       await _addUserToSubgroup(subgroupId!, userId);  // Add user to subgroup
//     }

//   } catch (e) {
//     print('Error creating subgroup or assigning role: $e');
//   }
// }

// // Fetch the user ID (e.g., using the Keycloak userinfo endpoint)
// Future<String?> _getUserId() async {
//   // final token = await _getClientAccessToken();
//   // if (token == null) return null;

//   try {
//     final response = await http.get(
//       Uri.parse('${Config.server}:8080/realms/G-SSO-Connect/protocol/openid-connect/userinfo'),
//       headers: {
//         'Authorization': 'Bearer ${widget.keycloakAccessToken}',
//         'Content-Type': 'application/json',
//       },
//     );

//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       return data['sub'];  // Assuming 'sub' is the user ID field
//     } else {
//       print('Failed to fetch user info. Status code: ${response.statusCode}');
//       print('Response body: ${response.body}');
//     }
//   } catch (e) {
//     print('Error fetching user info: $e');
//   }
//   return null;
// }
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
Future<void> _addUserToSubgroup(String subgroupId, String userId) async {
  final token = await _getClientAccessToken();
  if (token == null) return;

  try {
    final response = await http.put(
      Uri.parse('$keycloakUrl/users/$userId/groups/$subgroupId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode([{'id': userId}]),  // Add user ID to the request body
    );

    if (response.statusCode == 204) {
      print('User added to the Admin subgroup successfully');
    } else {
      print('Failed to add user to subgroup. Status code: ${response.statusCode}');
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
      Uri.parse('$keycloakUrl/clients?clientId=$clientId'),
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
          Uri.parse('$keycloakUrl/groups/$groupId/role-mappings/clients/$clientInternalId'),
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
        print('Failed to retrieve client role. Status code: ${roleResponse.statusCode}');
        print('Response body: ${roleResponse.body}');
      }
    } else {
      print('Failed to retrieve client information. Status code: ${clientResponse.statusCode}');
      print('Response body: ${clientResponse.body}');
    }
  } catch (e) {
    print('Error mapping role to group: $e');
  }
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a company name';
                  }
                  return null;
                },
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
                    } else {
                      print('Group ID is null. Group creation failed.');
                    }

                    Navigator.pop(context);
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
