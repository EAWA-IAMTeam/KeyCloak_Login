// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:frontend_login/config.dart';
// import 'package:http/http.dart' as http;
// import 'package:jwt_decoder/jwt_decoder.dart';

// class SelectCompanyPage extends StatefulWidget {
//   final String keycloakAccessToken;

//   const SelectCompanyPage({Key? key, required this.keycloakAccessToken})
//       : super(key: key);

//   @override
//   State<SelectCompanyPage> createState() => _SelectCompanyPageState();
// }

// class _SelectCompanyPageState extends State<SelectCompanyPage> {
//   String? selectedOption;
//   Map<String, Map<String, String>> groupDetails = {};
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
//         print('Failed to get access token. Status code: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error obtaining access token: $e');
//     }
//     return null;
//   }

//   Future<String?> _getUserId() async {
//     final token = widget.keycloakAccessToken;
//     try {
//       Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
//       return decodedToken['sub'];
//     } catch (e) {
//       print('Error decoding token: $e');
//     }
//     return null;
//   }

//   Future<void> _fetchGroups() async {
//     final clientToken = await _getClientAccessToken();
//     final userId = await _getUserId();

//     if (clientToken == null || userId == null) return;

//     try {
//       // Fetch user's groups
//       final response = await http.get(
//         Uri.parse('$keycloakUrl/users/$userId/groups'),
//         headers: {'Authorization': 'Bearer $clientToken'},
//       );

//       if (response.statusCode == 200) {
//         final groups = json.decode(response.body) as List<dynamic>;
//         Map<String, Map<String, String>> fetchedGroupDetails = {};

//         for (var group in groups) {
//           String groupName = group['name'];
//           String groupId = group['id'];
//           String? parentId = group['parentId'];
//           String parentGroupName = 'No Parent';

//           if (parentId != null) {
//             // Fetch parent group name
//             final parentResponse = await http.get(
//               Uri.parse('$keycloakUrl/groups/$parentId'),
//               headers: {'Authorization': 'Bearer $clientToken'},
//             );

//             if (parentResponse.statusCode == 200) {
//               final parentGroup = json.decode(parentResponse.body);
//               parentGroupName = parentGroup['name'];
//             } else {
//               print(
//                   'Failed to fetch parent group. Status: ${parentResponse.statusCode}');
//             }
//           }

//           // Store group details
//           fetchedGroupDetails['$parentGroupName: $groupName'] = {
//             'groupId': groupId,
//             'groupName': groupName,
//             'parentGroupId': parentId ?? 'No Parent',
//             'parentGroupName': parentGroupName,
//           };
//         }

//         // Sort group options alphabetically
//         final sortedKeys = fetchedGroupDetails.keys.toList()
//           ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

//         Map<String, Map<String, String>> sortedGroupDetails = {};
//         for (var key in sortedKeys) {
//           sortedGroupDetails[key] = fetchedGroupDetails[key]!;
//         }

//         setState(() {
//           groupDetails = fetchedGroupDetails;
//           selectedOption = groupDetails.keys.isNotEmpty
//               ? groupDetails.keys.first
//               : null;
//         });
//       } else {
//         print('Failed to fetch groups. Status: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error fetching groups: $e');
//     }
//   }

//   @override
//   void initState() {
//     super.initState();
//     _fetchGroups();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Select Company')),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             DropdownButton<String>(
//               value: selectedOption,
//               items: groupDetails.keys
//                   .map((option) => DropdownMenuItem<String>(
//                         value: option,
//                         child: Text(option),
//                       ))
//                   .toList(),
//               onChanged: (value) {
//                 setState(() {
//                   selectedOption = value;
//                 });
//               },
//               hint: const Text('Select Company'),
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: () {
//                 if (selectedOption != null) {
//                   final details = groupDetails[selectedOption]!;
//                   print('Group ID: ${details['groupId']}');
//                   print('Group Name: ${details['groupName']}');
//                   print('Parent Group ID: ${details['parentGroupId']}');
//                   print('Parent Group Name: ${details['parentGroupName']}');
//                 } else {
//                   print('No group selected.');
//                 }

//                 Navigator.pop(context);
//               },
//               child: const Text('Select Company'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend_login/config.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';

class SelectCompanyPage extends StatefulWidget {
  final String keycloakAccessToken;

  const SelectCompanyPage({Key? key, required this.keycloakAccessToken})
      : super(key: key);

  @override
  State<SelectCompanyPage> createState() => _SelectCompanyPageState();
}

class _SelectCompanyPageState extends State<SelectCompanyPage> {
  String? selectedOption;
  Map<String, Map<String, String>> groupDetails = {};
  final String keycloakUrl = '${Config.server}:8080/admin/realms/G-SSO-Connect';
  String kcid = '';
  String kcsecret = '';

  Future<String?> _getClientAccessToken() async {
    final tokenUrl =
        '${Config.server}:8080/realms/G-SSO-Connect/protocol/openid-connect/token';

    try {
      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': kcid,
          'client_secret': kcsecret,
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

  Future<String?> _getUserId() async {
    final token = widget.keycloakAccessToken;
    try {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      return decodedToken['sub'];
    } catch (e) {
      print('Error decoding token: $e');
    }
    return null;
  }

  Future<void> _fetchGroups() async {
    final clientToken = await _getClientAccessToken();
    final userId = await _getUserId();

    if (clientToken == null || userId == null) return;

    try {
      // Fetch user's groups
      final response = await http.get(
        Uri.parse('$keycloakUrl/users/$userId/groups'),
        headers: {'Authorization': 'Bearer $clientToken'},
      );

      if (response.statusCode == 200) {
        final groups = json.decode(response.body) as List<dynamic>;
        Map<String, Map<String, String>> fetchedGroupDetails = {};

        for (var group in groups) {
          String groupName = group['name'];
          String groupId = group['id'];
          String? parentId = group['parentId'];
          String parentGroupName = 'No Parent';

          if (parentId != null) {
            // Fetch parent group name
            final parentResponse = await http.get(
              Uri.parse('$keycloakUrl/groups/$parentId'),
              headers: {'Authorization': 'Bearer $clientToken'},
            );

            if (parentResponse.statusCode == 200) {
              final parentGroup = json.decode(parentResponse.body);
              parentGroupName = parentGroup['name'];
            } else {
              print(
                  'Failed to fetch parent group. Status: ${parentResponse.statusCode}');
            }
          }

          // Store group details
          fetchedGroupDetails['$parentGroupName: $groupName'] = {
            'groupId': groupId,
            'groupName': groupName,
            'parentGroupId': parentId ?? 'No Parent',
            'parentGroupName': parentGroupName,
          };
        }

        // Sort group options alphabetically
        final sortedKeys = fetchedGroupDetails.keys.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        Map<String, Map<String, String>> sortedGroupDetails = {};
        for (var key in sortedKeys) {
          sortedGroupDetails[key] = fetchedGroupDetails[key]!;
        }

        setState(() {
          groupDetails = sortedGroupDetails;
          selectedOption = groupDetails.keys.isNotEmpty
              ? groupDetails.keys.first
              : null;
        });
      } else {
        print('Failed to fetch groups. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching groups: $e');
    }
  }

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

@override
void initState() {
  super.initState();
  _initialize();
}

Future<void> _initialize() async {
  await fetchKeycloakConfig();
  await _fetchGroups();
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Company')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButton<String>(
              value: selectedOption,
              items: groupDetails.keys
                  .map((option) => DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedOption = value;
                });
              },
              hint: const Text('Select Company'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (selectedOption != null) {
                  final details = groupDetails[selectedOption]!;
                  print('Group ID: ${details['groupId']}');
                  print('Group Name: ${details['groupName']}');
                  print('Parent Group ID: ${details['parentGroupId']}');
                  print('Parent Group Name: ${details['parentGroupName']}');
                } else {
                  print('No group selected.');
                }

                Navigator.pop(context);
              },
              child: const Text('Select Company'),
            ),
          ],
        ),
      ),
    );
  }
}
