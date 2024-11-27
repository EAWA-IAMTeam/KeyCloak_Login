import 'dart:convert';
import 'package:frontend_login/config.dart';
import 'package:frontend_login/invite_user.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class SelectCompanyforuserPage extends StatefulWidget {
  final String keycloakAccessToken;
  const SelectCompanyforuserPage({Key? key, required this.keycloakAccessToken})
      : super(key: key);

  @override
  State<SelectCompanyforuserPage> createState() => _SelectCompanyforuserPageState();
}

class _SelectCompanyforuserPageState extends State<SelectCompanyforuserPage> {
  final _formKey = GlobalKey<FormState>();
  String? selectedGroup;
  List<String> adminGroups = []; // Cache for admin groups
  // List to store parent group names
  List<String> parentGroupNames = [];

  final String keycloakUrl = '${Config.server}:8080/admin/realms/G-SSO-Connect';
  final String clientId = 'frontend-login';
  final String clientSecret = '0SSZj01TDs7812fLBxgwTKPA74ghnLQM';
  final String clientRole = 'Admin';

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
          'client_id': clientId,
          'client_secret': clientSecret,
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

// Fetch admin groups
  Future<void> _getAdminGroups() async {
    final token = await _getClientAccessToken();
    if (token == null) return;

    final userId = await _getUserId();
    if (userId == null) return;

    try {
      final userGroupsResponse = await http.get(
        Uri.parse('$keycloakUrl/users/$userId/groups'),
        headers: {'Authorization': 'Bearer $token'},
      );
      print(userGroupsResponse.statusCode);
      if (userGroupsResponse.statusCode == 200) {
        print(userGroupsResponse.body);
        final userGroups = jsonDecode(userGroupsResponse.body) as List<dynamic>;
        List<String> fetchedParentIds = []; // List to store parent IDs

        for (var group in userGroups) {
          if (group['name'] == 'Admin' && group['parentId'] != null) {
            fetchedParentIds.add(group['parentId']);
            print("GetAdminGroups (ParentId): " + fetchedParentIds.last);
          }
        }

        // Fetch parent group names and update the state
        await _getParentGroupNames(fetchedParentIds);

        // Sort group names alphabetically before updating state
        parentGroupNames
            .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        setState(() {
          adminGroups = parentGroupNames;
          selectedGroup = adminGroups.isNotEmpty ? adminGroups[0] : null;
        });
      } else {
        print(
            'Failed to fetch user groups. Status: ${userGroupsResponse.statusCode}');
      }
    } catch (e) {
      print('Error fetching admin groups: $e');
    }
  }

// Fetch parent group names using the fetched parent IDs
  Future<void> _getParentGroupNames(List<String> parentIds) async {
    final token = await _getClientAccessToken();
    if (token == null) return;

    List<String> fetchedNames = [];
    try {
      for (var parentId in parentIds) {
        final groupResponse = await http.get(
          Uri.parse('$keycloakUrl/groups/$parentId'),
          headers: {'Authorization': 'Bearer $token'},
        );
        print(groupResponse.statusCode);
        if (groupResponse.statusCode == 200) {
          final group = jsonDecode(groupResponse.body);
          if (group['name'] != null) {
            fetchedNames.add(group['name']);
            print("GetParentGroupNames (Group Name): " + group['name']);
          }
        } else {
          print(
              'Failed to fetch group name for parentId: $parentId. Status: ${groupResponse.statusCode}');
        }
      }

      // Update the parent group names list
      parentGroupNames = fetchedNames;
    } catch (e) {
      print('Error fetching parent group names: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _getAdminGroups();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select Company and Invite User')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [             
              DropdownButton<String>(
                value: selectedGroup,
                items: adminGroups
                    .map((group) => DropdownMenuItem<String>(
                          value: group,
                          child: Text(group),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedGroup = value;
                  });
                },
                hint: Text('Select Parent Group'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (selectedGroup != null) {
                    print('Selected Group: $selectedGroup');

                    try {
                      // Await the group ID resolution
                      final groupId = await _getGroupId(selectedGroup!);

                      if (groupId != null) {
                        print('Resolved Group ID: $groupId');
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InviteUserPage(
                              groupId: groupId,
                              keycloakAccessToken: widget.keycloakAccessToken,
                            ),
                          ),
                        );
                      } else {
                        print('Group ID could not be resolved');
                      }
                    } catch (e) {
                      print('Error resolving group ID: $e');
                    }
                  } else {
                    print('No group selected');
                  }
                },
                child: Text('Invite User'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
