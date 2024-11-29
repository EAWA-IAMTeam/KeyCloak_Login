// import 'dart:convert';
// import 'package:crypto/crypto.dart';
// import 'package:flutter/material.dart';
// import 'package:frontend_login/config.dart';
// import 'package:http/http.dart' as http;
// import 'package:http/http.dart' as http;
// import 'package:jwt_decoder/jwt_decoder.dart';
// import 'package:encrypt/encrypt.dart' as encrypt;

// class JoinCompanyPage extends StatefulWidget {
//   final String keycloakAccessToken;

//   const JoinCompanyPage({Key? key, required this.keycloakAccessToken})
//       : super(key: key);

//   @override
//   State<JoinCompanyPage> createState() => _JoinCompanyPageState();
// }

// class _JoinCompanyPageState extends State<JoinCompanyPage> {
//   final TextEditingController _invitationCodeController =
//       TextEditingController();
//   final _formKey = GlobalKey<FormState>();

//   final String keycloakUrl = '${Config.server}:8080/admin/realms/G-SSO-Connect';

//   Future<String?> _getClientAccessToken() async {
//     final tokenUrl =
//         '${Config.server}:8080/realms/G-SSO-Connect/protocol/openid-connect/token';

//     try {
//       final response = await http.post(
//         Uri.parse(tokenUrl),
//         headers: {'Content-Type': 'application/x-www-form-urlencoded'},
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
//         print(
//             'Failed to get access token. Status code: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error obtaining access token: $e');
//     }
//     return null;
//   }

//   String? _decryptInvitationCode(
//       String encryptedCode, String aesKey, String ivBase64) {
//     try {
//       // Convert the AES key and IV from their Base64/UTF-8 representations
//       final key = encrypt.Key.fromUtf8(aesKey); // AES key
//       final iv = encrypt.IV.fromBase64(
//           ivBase64); // Fixed IV (must match the one used during encryption)

//       // Create the encrypter object with AES CBC mode
//       final encrypter =
//           encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

//       // Convert the encrypted code from Base64 to the Encrypted object
//       final encrypted = encrypt.Encrypted.fromBase64(encryptedCode);

//       // Decrypt the data and handle it as raw bytes
//       final decryptedBytes = encrypter.decryptBytes(encrypted, iv: iv);

//       // Try converting the decrypted bytes to a UTF-8 string (handling malformed data)
//       final decryptedString = utf8.decode(decryptedBytes, allowMalformed: true);

//       print('Decrypted invitation code: $decryptedString');

//       return decryptedString;
//     } catch (e) {
//       print('Error decrypting invitation code: $e');
//     }
//     return null;
//   }

//   Future<void> _joinGroup(String groupId, String? subgroupId) async {
//     final token = await _getClientAccessToken();
//     if (token == null) return null;

//     try {
//       final userId = await _getUserId();
//       if (userId == null) {
//         print('Failed to fetch user ID.');
//         return;
//       }
//       print('Parent Id: ' + groupId);
//       print('Subgroup Id: ' + subgroupId.toString());

//       final targetGroupId = subgroupId ?? groupId;
//       print("targetGroupId: " + targetGroupId);
//       print("userid: " + userId.toString());

//       final response = await http.put(
//         Uri.parse('$keycloakUrl/users/$userId/groups/$targetGroupId'),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       if (response.statusCode == 204) {
//         print('User successfully joined the group/subgroup.');
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Successfully joined the group!')),
//         );
//       } else {
//         print(
//             'Failed to join group. Status code: ${response.statusCode}, Response: ${response.body}');
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Failed to join the group.')),
//         );
//       }
//     } catch (e) {
//       print('Error joining group: $e');
//     }
//   }

//   Future<String?> _getUserId() async {
//     final token = widget.keycloakAccessToken;
//     if (token.isEmpty) return null;

//     try {
//       final decodedToken = json.decode(
//         utf8.decode(base64Url.decode(base64Url.normalize(token.split(".")[1]))),
//       );
//       return decodedToken['sub'] as String?;
//     } catch (e) {
//       print('Error decoding JWT token: $e');
//     }
//     return null;
//   }

//   Future<void> _processInvitationCode(String invitationCode) async {
//     const aesKey = 'mysecretaeskey23'; // Replace with your actual AES key
//     const IV = 'T6fuCu/7ZdQeIwj8ziM6JA==';
//     final decryptedData = _decryptInvitationCode(invitationCode, aesKey, IV);

//     if (decryptedData == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Invalid invitation code.')),
//       );
//       return;
//     }

//     print('Decrypted invitation code: $decryptedData'); // Debugging output

//     // Remove the labels (groupId:, subgroupId:, expiration:) from the decrypted data
//     final cleanedData = decryptedData
//         .replaceFirst('groupId:', '')
//         .replaceFirst('subgroupId:', '')
//         .replaceFirst('expiration:', '');

//     final parts = cleanedData.split('|');
//     if (parts.length != 3) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Invalid invitation code format.')),
//       );
//       return;
//     }

//     final groupId = parts[0];
//     final subgroupId = parts[1];
//     final expirationTimeStr = parts[2];

//     print('Expiration time string: $expirationTimeStr'); // Debugging output

//     DateTime? expirationTime;

//     try {
//       // Manually parse expiration time string in case milliseconds are causing issues
//       expirationTime = DateTime.parse(expirationTimeStr);
//     } catch (e) {
//       print('Error parsing expiration time: $e');
//     }

//     print('Decrypted expiration time: $expirationTime');
//     print('Current time: ${DateTime.now().toUtc()}'); // For debugging

//     if (expirationTime == null ||
//         expirationTime.isBefore(DateTime.now().toUtc())) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Invitation code has expired.')),
//       );
//       return;
//     }

//     await _joinGroup(groupId, subgroupId.isNotEmpty ? subgroupId : null);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Join Company')),
//       body: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               TextFormField(
//                 controller: _invitationCodeController,
//                 decoration: InputDecoration(labelText: 'Invitation Code'),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter the invitation code.';
//                   }
//                   return null;
//                 },
//               ),
//               SizedBox(height: 20),
//               ElevatedButton(
//                 onPressed: () {
//                   if (_formKey.currentState!.validate()) {
//                     _processInvitationCode(_invitationCodeController.text);
//                   }
//                 },
//                 child: Text('Join'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend_login/config.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:intl/intl.dart'; // For formatting datetime

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
        print(
            'Failed to get access token. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error obtaining access token: $e');
    }
    return null;
  }

  // String? _decryptInvitationCode(
  //     String encryptedCode, String aesKey, String ivBase64) {
  //   try {
  //     final key = encrypt.Key.fromUtf8(aesKey);
  //     final iv = encrypt.IV.fromBase64(ivBase64);

  //     final encrypter =
  //         encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

  //     final encrypted = encrypt.Encrypted.fromBase64(encryptedCode);

  //     final decryptedBytes = encrypter.decryptBytes(encrypted, iv: iv);

  //     final decryptedString = utf8.decode(decryptedBytes, allowMalformed: true);

  //     print('Decrypted invitation code: $decryptedString');

  //     return decryptedString;
  //   } catch (e) {
  //     print('Error decrypting invitation code: $e');
  //   }
  //   return null;
  // }


String? decryptInvitationCode(String encryptedCode) {
  try {
    // Load AES Key and IV from the .env file
    final aesKey = dotenv.env['AES_KEY']!;
    final aesIv = dotenv.env['AES_IV']!;

    final key = encrypt.Key.fromBase64(aesKey);
    final iv = encrypt.IV.fromBase64(aesIv);

    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

    final encrypted = encrypt.Encrypted.fromBase64(encryptedCode);
    final decryptedBytes = encrypter.decryptBytes(encrypted, iv: iv);

    final decryptedString = utf8.decode(decryptedBytes, allowMalformed: true);

    print('Decrypted invitation code: $decryptedString');

    return decryptedString;
  } catch (e) {
    print('Error decrypting invitation code: $e');
    return null;
  }
}


  Future<bool> _isUserInGroup(String userId, String groupId) async {
  final token = await _getClientAccessToken();
  if (token == null) return false;

  try {
    final response = await http.get(
      Uri.parse('$keycloakUrl/users/$userId/groups'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> groups = json.decode(response.body);
      for (var group in groups) {
        if (group['id'] == groupId) {
          return true;
        }
      }
    } else {
      print(
          'Failed to check group membership. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error checking group membership: $e');
  }
  return false;
}

void _showAlreadyJoinedDialog(String username, String companyName, String role) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('You Have Already Joined'),
        content: Text(
          'Username: $username\n'
          'Company Name: $companyName\n'
          'Role: $role\n\n'
          'Redirecting you to the homepage.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Redirect to homepage
            },
            child: Text('OK'),
          ),
        ],
      );
    },
  );
}

Future<void> _joinGroup(String groupId, String? subgroupId) async {
  final token = await _getClientAccessToken();
  if (token == null) return;

  try {
    final userId = await _getUserId();
    if (userId == null) {
      print('Failed to fetch user ID.');
      return;
    }

    final targetGroupId = subgroupId ?? groupId;

    // Check if the user is already in the group
    if (await _isUserInGroup(userId, targetGroupId)) {
      final username = await _getUsername();
      final companyName = await _getGroupName(groupId);
      final role =
          subgroupId != null ? await _getGroupName(subgroupId) : "Member";

      _showAlreadyJoinedDialog(username ?? 'Unknown', companyName ?? 'Unknown',
          role ?? 'Unknown');
      return;
    }

    // Proceed to join the group
    final response = await http.put(
      Uri.parse('$keycloakUrl/users/$userId/groups/$targetGroupId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 204) {
      final username = await _getUsername();
      final companyName = await _getGroupName(groupId);
      final role =
          subgroupId != null ? await _getGroupName(subgroupId) : "Member";
      final joinedTime =
          DateFormat('dd/MM/yy hh:mm a').format(DateTime.now());

      _showSuccessDialog(username, companyName, role, joinedTime);
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

  Future<String?> _getUsername() async {
    final token = widget.keycloakAccessToken;
    try {
      final decodedToken = JwtDecoder.decode(token);
      return decodedToken['preferred_username'] as String?;
    } catch (e) {
      print('Error fetching username from token: $e');
    }
    return null;
  }

  Future<String?> _getGroupName(String groupId) async {
    final token = await _getClientAccessToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$keycloakUrl/groups/$groupId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['name'];
      }
    } catch (e) {
      print('Error fetching group name: $e');
    }
    return null;
  }

  void _showSuccessDialog(
      String? username, String? companyName, String? role, String joinedTime) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Successfully Joined Company'),
          content: Text(
            'Username: $username\n'
            'Company Name: $companyName\n'
            'Role: $role\n'
            'Joined Time: $joinedTime',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processInvitationCode(String invitationCode) async {
  final decryptedData = decryptInvitationCode(invitationCode);

  if (decryptedData == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invalid invitation code.')),
    );
    return;
  }

  print('Decrypted invitation code: $decryptedData'); // Debugging output

  // Remove the labels (groupId:, subgroupId:, expiration:) from the decrypted data
  final cleanedData = decryptedData
      .replaceFirst('groupId:', '')
      .replaceFirst('subgroupId:', '')
      .replaceFirst('expiration:', '');

  final parts = cleanedData.split('|');
  if (parts.length != 3) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invalid invitation code format.')),
    );
    return;
  }

  final groupId = parts[0];
  final subgroupId = parts[1];
  final expirationTimeStr = parts[2];

  print('Expiration time string: $expirationTimeStr'); // Debugging output

  DateTime? expirationTime;

  try {
    // Parse the expiration time string
    expirationTime = DateTime.parse(expirationTimeStr).toUtc();
  } catch (e) {
    print('Error parsing expiration time: $e');
  }

  print('Decrypted expiration time: $expirationTime');
  print('Current time: ${DateTime.now().toUtc()}'); // For debugging

  if (expirationTime == null || expirationTime.isBefore(DateTime.now().toUtc())) {
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
                  print("Code Length: ${_invitationCodeController.text.length}");
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
