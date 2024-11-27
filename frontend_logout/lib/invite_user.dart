// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:jwt_decoder/jwt_decoder.dart';
// import 'package:frontend_login/config.dart';

// class InviteUserPage extends StatefulWidget {
//   final String keycloakAccessToken;
//   final String groupId;

//   const InviteUserPage({Key? key, required this.keycloakAccessToken, required this.groupId}) : super(key: key);

//   @override
//   State<InviteUserPage> createState() => _InviteUserPageState();
// }

// class _InviteUserPageState extends State<InviteUserPage> {
//   String? _selectedRole = 'Packer';  // Default value set to "Packer"
//   String? subgroupId;

//   Future<String?> createSubgroup() async {
//     final token = await _getClientAccessToken();
//     if (token == null) return null;

//     try {
//       final response = await http.post(
//         Uri.parse('${Config.server}:8080/admin/realms/G-SSO-Connect/groups/${widget.groupId}/children'),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//         body: jsonEncode({'name': 'Packer'}),  // Subgroup name is "Packer"
//       );

//       if (response.statusCode == 201) {
//         final newSubgroup = jsonDecode(response.body);
//         return newSubgroup['id'];  // Return the subgroup ID
//       } else {
//         print('Failed to create subgroup. Status code: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error creating subgroup: $e');
//     }
//     return null;
//   }

//   Future<String?> _getClientAccessToken() async {
//     final tokenUrl = '${Config.server}:8080/realms/G-SSO-Connect/protocol/openid-connect/token';

//     try {
//       final response = await http.post(
//         Uri.parse(tokenUrl),
//         headers: {
//           'Content-Type': 'application/x-www-form-urlencoded',
//         },
//         body: {
//           'client_id': 'frontend-login',
//           'client_secret': '0SSZj01TDs7812fLBxgwTKPA74ghnLQM',
//           'grant_type': 'client_credentials',
//         },
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         return data['access_token'];
//       } else {
//         print('Failed to get access token. Status code: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error obtaining access token: $e');
//     }
//     return null;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Invite User')),
//       body: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             DropdownButton<String>(
//               value: _selectedRole,
//               onChanged: (value) {
//                 setState(() {
//                   _selectedRole = value;
//                 });
//               },
//               items: ['Packer', 'Courier', 'Account']
//                   .map((role) => DropdownMenuItem(
//                         value: role,
//                         child: Text(role),
//                       ))
//                   .toList(),
//               // Disable "Courier" and "Account" for now
//               disabledHint: Text('Not available'),
//             ),
//             SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: () async {
//                 if (_selectedRole != null) {
//                   subgroupId = await createSubgroup();  // Create the subgroup
//                   if (subgroupId != null) {
//                     setState(() {
//                       // Display the subgroup ID below the button
//                       print("Packer subgroupID: $subgroupId");
//                     });
//                   }
//                 }
//               },
//               child: Text('Create Subgroup'),
//             ),
//             if (subgroupId != null) ...[
//               SizedBox(height: 20),
//               Text('Subgroup ID: $subgroupId'),
              
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }


import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart'; // Add this dependency
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For clipboard functionality
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:frontend_login/config.dart';

class InviteUserPage extends StatefulWidget {
  final String keycloakAccessToken;
  final String groupId;

  const InviteUserPage({
    Key? key,
    required this.keycloakAccessToken,
    required this.groupId,
  }) : super(key: key);

  @override
  State<InviteUserPage> createState() => _InviteUserPageState();
}

class _InviteUserPageState extends State<InviteUserPage> {
  String? _selectedRole;
  String? invitationCode;
  String encryptionKey = 'mysecretaeskey23'; // Ensure 16 characters for AES-128
  TextEditingController _codeController = TextEditingController();

  Future<String?> _getClientAccessToken() async {
    final tokenUrl =
        '${Config.server}:8080/realms/G-SSO-Connect/protocol/openid-connect/token';

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

  Future<String?> _getSubgroupId(String role) async {
  final token = await _getClientAccessToken();
  if (token == null) return null;
  print('Checking subgroup for role: $role');
  try {
    final response = await http.get(
      Uri.parse('${Config.server}:8080/admin/realms/G-SSO-Connect/groups/${widget.groupId}/children'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final subGroups = jsonDecode(response.body) as List<dynamic>;
      for (var subgroup in subGroups) {
        // Ensure the subgroup name matches the selected role
        if (subgroup['name'] == role) {
          print("Found matching subgroup: " + subgroup['name'] + " with ID: " + subgroup['id']);
          return subgroup['id'];
        }
        print("subgroup name: " + subgroup['name'] + " subgroup id: " + subgroup['id']);
      }
    } else {
      print('Failed to fetch subgroups. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching subgroup ID: $e');
  }
  return null;
}

Future<String?> createSubgroup(String role) async {
  final token = await _getClientAccessToken();
  if (token == null) return null;

  try {
    final response = await http.post(
      Uri.parse('${Config.server}:8080/admin/realms/G-SSO-Connect/groups/${widget.groupId}/children'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'name': role}),
    );

    if (response.statusCode == 201) {
      final newSubgroup = jsonDecode(response.body);
      print('Created new subgroup with name: $role and ID: ${newSubgroup['id']}');
      return newSubgroup['id'];
    } else {
      print('Failed to create subgroup. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error creating subgroup: $e');
  }
  return null;
}

void _handleRoleSelection(String role) async {
  print("Selected Role: $role");
  // First, try to get the existing subgroup ID for the selected role
  String? subgroupId = await _getSubgroupId(role);
  if (subgroupId == null) {
    // If no subgroup found, create a new one with the selected role
    subgroupId = await createSubgroup(role);
  }

  if (subgroupId != null) {
    setState(() {
      invitationCode = encryptInvitationCode(widget.groupId, subgroupId.toString());
      _codeController.text = invitationCode!;
    });
  } else {
    print('Failed to generate invitation code.');
  }
}

String encryptInvitationCode(String groupId, String subgroupId) {
  final expirationTime = DateTime.now().add(Duration(hours: 24)).toIso8601String();
  final plainText = 'groupId:$groupId|subgroupId:$subgroupId|expiration:$expirationTime';

  print('Encrypting invitation code: $plainText');

  final key = encrypt.Key.fromUtf8(encryptionKey);
  final iv = encrypt.IV.fromBase64('T6fuCu/7ZdQeIwj8ziM6JA==');
  // final iv = encrypt.IV.fromLength(16);
  //  print('Initialization Vector (IV): ${iv.base64}'); // Print as base64
  final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
  final encrypted = encrypter.encrypt(plainText, iv: iv);

  print('Encrypted invitation code: ${encrypted.base64}');

  // Return encrypted text as base64 string
  return encrypted.base64;
}

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    print("group id: " + widget.groupId.toString());
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
              items: ['Packer', 'Manager', 'Admin'].map((role) {
                return DropdownMenuItem(value: role, child: Text(role));
              }).toList(),
              hint: Text('Select a role'),
              onChanged: (value) {
                setState(() {
                  _selectedRole = value;
                  if (value != null) _handleRoleSelection(value);
                });
              },
            ),
            SizedBox(height: 20),
            TextField(
              controller: _codeController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Invitation Code',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _codeController.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Invitation code copied to clipboard')),
                );
              },
              child: Text('Copy to Clipboard'),
            ),
            //Text(widget.groupId),
          ],
        ),
      ),
    );
  }
}
