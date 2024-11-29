import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'dart:io';

void main() {
  final random = Random.secure();

  // Generate 256-bit AES Key (32 bytes)
  final key = List<int>.generate(32, (_) => random.nextInt(256));
  final aesKey = base64Encode(key);

  // Generate 128-bit IV (16 bytes)
  final iv = List<int>.generate(16, (_) => random.nextInt(256));
  final aesIv = base64Encode(iv);

  final envFile = File('.env');

  // Write key and IV to .env file
  envFile.writeAsStringSync('AES_KEY=$aesKey\nAES_IV=$aesIv\n');

  print('AES Key and IV generated and saved to .env');
  print('AES_KEY=$aesKey');
  print('AES_IV=$aesIv');
}
