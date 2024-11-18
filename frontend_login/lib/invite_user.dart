import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:frontend_login/config.dart';

class InviteUserPage extends StatefulWidget {
  final String keycloakAccessToken;
  final String groupId;

  const InviteUserPage({Key? key, required this.keycloakAccessToken, required this.groupId}) : super(key: key);

  @override
  State<InviteUserPage> createState() => _InviteUserPageState();
}

class _InviteUserPageState extends State<InviteUserPage> {
  String? _selectedRole = 'Packer';  // Default value set to "Packer"
  String? subgroupId;

  Future<String?> createSubgroup() async {
    final token = await _getClientAccessToken();
    if (token == null) return null;

    try {
      final response = await http.post(
        Uri.parse('${Config.server}:8080/admin/realms/G-SSO-Connect/groups/${widget.groupId}/children'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'name': 'Packer'}),  // Subgroup name is "Packer"
      );

      if (response.statusCode == 201) {
        final newSubgroup = jsonDecode(response.body);
        return newSubgroup['id'];  // Return the subgroup ID
      } else {
        print('Failed to create subgroup. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating subgroup: $e');
    }
    return null;
  }

  Future<String?> _getClientAccessToken() async {
    final tokenUrl = '${Config.server}:8080/realms/G-SSO-Connect/protocol/openid-connect/token';

    try {
      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_id': 'frontend-login',
          'client_secret': '0SSZj01TDs7812fLBxgwTKPA74ghnLQM',
          'grant_type': 'client_credentials',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['access_token'];
      } else {
        print('Failed to get access token. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error obtaining access token: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Invite User')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<String>(
              value: _selectedRole,
              onChanged: (value) {
                setState(() {
                  _selectedRole = value;
                });
              },
              items: ['Packer', 'Courier', 'Account']
                  .map((role) => DropdownMenuItem(
                        value: role,
                        child: Text(role),
                      ))
                  .toList(),
              // Disable "Courier" and "Account" for now
              disabledHint: Text('Not available'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (_selectedRole != null) {
                  subgroupId = await createSubgroup();  // Create the subgroup
                  if (subgroupId != null) {
                    setState(() {
                      // Display the subgroup ID below the button
                      print("Packer subgroupID: $subgroupId");
                    });
                  }
                }
              },
              child: Text('Create Subgroup'),
            ),
            if (subgroupId != null) ...[
              SizedBox(height: 20),
              Text('Subgroup ID: $subgroupId'),
              
            ],
          ],
        ),
      ),
    );
  }
}
