import 'package:flutter/material.dart';

class JoinCompanyPage extends StatefulWidget {
  const JoinCompanyPage({Key? key}) : super(key: key);

  @override
  State<JoinCompanyPage> createState() => _JoinCompanyPageState();
}

class _JoinCompanyPageState extends State<JoinCompanyPage> {
  final _formKey = GlobalKey<FormState>();
  String companyCode = '';

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
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    // Handle company joining logic
                    print('Joining Company: $companyCode');
                    // Navigate back to the Home page after joining
                    Navigator.pop(context);
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
