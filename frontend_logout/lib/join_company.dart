// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:jwt_decoder/jwt_decoder.dart';
// import 'package:frontend_login/config.dart';

// class JoinCompanyPage extends StatefulWidget {
//   final String keycloakAccessToken;
//   const JoinCompanyPage({Key? key, required this.keycloakAccessToken}) : super(key: key);

//   @override
//   State<JoinCompanyPage> createState() => _JoinCompanyPageState();
// }

// class _JoinCompanyPageState extends State<JoinCompanyPage> {
//   final _formKey = GlobalKey<FormState>();
//   String subgroupId = '';
//   String message = '';

//   final String keycloakUrl = '${Config.server}:8080/admin/realms/G-SSO-Connect';
//   final String clientId = 'frontend-login';
//   final String clientSecret = '0SSZj01TDs7812fLBxgwTKPA74ghnLQM';
//   final String clientRole = 'Admin';

//   Future<String?> _getClientAccessToken() async {
//     final keycloakTokenUrl = '${Config.server}:8080/realms/G-SSO-Connect/protocol/openid-connect/token';

//     try {
//       final response = await http.post(
//         Uri.parse(keycloakTokenUrl),
//         headers: {
//           'Content-Type': 'application/x-www-form-urlencoded',
//         },
//         body: {
//           'client_id': clientId,
//           'client_secret': clientSecret,
//           'grant_type': 'client_credentials',
//         },
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         return data['access_token'];
//       } else {
//         print('Failed to get access token. Status code: ${response.statusCode}');
//         print('Response body: ${response.body}');
//       }
//     } catch (e) {
//       print('Error obtaining access token: $e');
//     }
//     return null;
//   }

//   // Fetch user ID from the access token (JWT)
//   Future<String?> _getUserId() async {
//     final token = widget.keycloakAccessToken.toString();
//     if (token.isEmpty) return null;

//     try {
//       // Decode the JWT token
//       Map<String, dynamic> decodedToken = JwtDecoder.decode(token);

//       // Extract the 'sub' claim, which is the user ID
//       String userId = decodedToken['sub'];
//       print("userID: $userId");
//       return userId;
//     } catch (e) {
//       print('Error decoding token: $e');
//     }
//     return null;
//   }

//   // Add the user to the specified subgroup
//   Future<void> _addUserToSubgroup(String subgroupId, String userId) async {
//     final token = await _getClientAccessToken();
//     if (token == null) return;

//     try {
//       final response = await http.put(
//         Uri.parse('$keycloakUrl/users/$userId/groups/$subgroupId'),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//         body: jsonEncode([{'id': userId}]),
//       );

//       if (response.statusCode == 204) {
//         setState(() {
//           message = 'Successfully joined the subgroup!';
//           print("SubgroupId: $subgroupId");
//         });
//       } else {
//         setState(() {
//           message = 'Failed to join the subgroup. Error: ${response.body}';
//         });
//       }
//     } catch (e) {
//       print('Error adding user to subgroup: $e');
//       setState(() {
//         message = 'Error: $e';
//       });
//     }
//   }

//   // Future<void> _mapRoleToGroup(String groupId) async {
//   //   final token = await _getClientAccessToken();
//   //   if (token == null) return;

//   //   try {
//   //     // First, retrieve the internal ID of the client
//   //     final clientResponse = await http.get(
//   //       Uri.parse('$keycloakUrl/clients?clientId=$clientId'),
//   //       headers: {
//   //         'Authorization': 'Bearer $token',
//   //       },
//   //     );

//   //     if (clientResponse.statusCode == 200) {
//   //       final clients = jsonDecode(clientResponse.body) as List<dynamic>;
//   //       if (clients.isEmpty) {
//   //         print('Client not found.');
//   //         return;
//   //       }

//   //       final clientInternalId = clients[0]['id'];

//   //       // Now, fetch the client role using the internal ID
//   //       final roleResponse = await http.get(
//   //         Uri.parse('$keycloakUrl/clients/$clientInternalId/roles/$clientRole'),
//   //         headers: {
//   //           'Authorization': 'Bearer $token',
//   //         },
//   //       );

//   //       if (roleResponse.statusCode == 200) {
//   //         final role = jsonDecode(roleResponse.body);
//   //         final response = await http.post(
//   //           Uri.parse(
//   //               '$keycloakUrl/groups/$groupId/role-mappings/clients/$clientInternalId'),
//   //           headers: {
//   //             'Authorization': 'Bearer $token',
//   //             'Content-Type': 'application/json',
//   //           },
//   //           body: jsonEncode([role]),
//   //         );

//   //         if (response.statusCode == 204) {
//   //           print('Role mapped successfully');
//   //         } else {
//   //           print('Failed to map role. Status code: ${response.statusCode}');
//   //           print('Response body: ${response.body}');
//   //         }
//   //       } else {
//   //         print(
//   //             'Failed to retrieve client role. Status code: ${roleResponse.statusCode}');
//   //         print('Response body: ${roleResponse.body}');
//   //       }
//   //     } else {
//   //       print(
//   //           'Failed to retrieve client information. Status code: ${clientResponse.statusCode}');
//   //       print('Response body: ${clientResponse.body}');
//   //     }
//   //   } catch (e) {
//   //     print('Error mapping role to group: $e');
//   //   }
//   // }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Join Subgroup')),
//       body: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               TextFormField(
//                 decoration: InputDecoration(labelText: 'Subgroup ID'),
//                 onSaved: (value) {
//                   subgroupId = value!;
//                 },
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter a subgroup ID';
//                   }
//                   return null;
//                 },
//               ),
//               SizedBox(height: 20),
//               ElevatedButton(
//                 onPressed: () async {
//                   if (_formKey.currentState!.validate()) {
//                     _formKey.currentState!.save();

//                     String? userId = await _getUserId();
//                     if (userId != null) {
//                       await _addUserToSubgroup(subgroupId, userId);
//                     } else {
//                       setState(() {
//                         message = 'Failed to retrieve user ID';
//                       });
//                     }
//                   }
//                 },
//                 child: Text('Join Subgroup'),
//               ),
//               SizedBox(height: 20),
//               Text(
//                 message,
//                 style: TextStyle(color: message.contains('Successfully') ? Colors.green : Colors.red),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:frontend_login/config.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class JoinCompanyPage extends StatefulWidget {
  final String keycloakAccessToken;

  const JoinCompanyPage({Key? key, required this.keycloakAccessToken})
      : super(key: key);

  @override
  State<JoinCompanyPage> createState() => _JoinCompanyPageState();
}

class _JoinCompanyPageState extends State<JoinCompanyPage> {
  final TextEditingController _invitationCodeController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final String keycloakUrl = '${Config.server}:8080/admin/realms/G-SSO-Connect';

  Future<String?> _getClientAccessToken() async {
    final tokenUrl =
        '${Config.server}:8080/realms/G-SSO-Connect/protocol/openid-connect/token';

    try {
      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
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

String? _decryptInvitationCode(String encryptedCode, String aesKey) {
  try {
    print('Decrypting invitation code: $encryptedCode');
    
    final key = encrypt.Key.fromUtf8(aesKey);
    final iv = encrypt.IV.fromLength(16); // Ensure the same IV length as used during encryption
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

    // Ensure the encrypted code is decoded properly from base64
    final decrypted = encrypter.decrypt64(encryptedCode, iv: iv);
    
    print('Decrypted invitation code: $decrypted');
    
    return decrypted;
  } catch (e) {
    print('Error decrypting invitation code: $e');
  }
  return null;
}


  Future<void> _joinGroup(String groupId, String? subgroupId) async {
    final token = widget.keycloakAccessToken;

    try {
      final userId = await _getUserId();
      if (userId == null) {
        print('Failed to fetch user ID.');
        return;
      }

      final targetGroupId = subgroupId ?? groupId;
      final response = await http.put(
        Uri.parse('$keycloakUrl/users/$userId/groups/$targetGroupId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 204) {
        print('User successfully joined the group/subgroup.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully joined the group!')),
        );
      } else {
        print(
            'Failed to join group. Status code: ${response.statusCode}, Response: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join the group.')),
        );
      }
    } catch (e) {
      print('Error joining group: $e');
    }
  }

  Future<String?> _getUserId() async {
    final token = widget.keycloakAccessToken;
    if (token.isEmpty) return null;

    try {
      final decodedToken = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(token.split(".")[1]))),
      );
      return decodedToken['sub'] as String?;
    } catch (e) {
      print('Error decoding JWT token: $e');
    }
    return null;
  }

  Future<void> _processInvitationCode(String invitationCode) async {
    const aesKey = 'mysecretaeskey23'; // Replace with your actual AES key
    final decryptedData = _decryptInvitationCode(invitationCode, aesKey);

    if (decryptedData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid invitation code.')),
      );
      return;
    }

    final parts = decryptedData.split('|');
    if (parts.length != 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid invitation code format.')),
      );
      return;
    }

    final groupId = parts[0];
    final subgroupId = parts[1];
    final expirationTime = DateTime.tryParse(parts[2]);

    if (expirationTime == null || expirationTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation code has expired.')),
      );
      return;
    }

    await _joinGroup(groupId, subgroupId.isNotEmpty ? subgroupId : null);
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
              TextFormField(
                controller: _invitationCodeController,
                decoration: InputDecoration(labelText: 'Invitation Code'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the invitation code.';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _processInvitationCode(_invitationCodeController.text);
                  }
                },
                child: Text('Join'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
