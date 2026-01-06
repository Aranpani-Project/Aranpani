import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // Needed for Uint8List

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart'; // To use XFile
import 'package:flutter/foundation.dart' show kIsWeb; // To check if running on Web

class CloudinaryService {
  // Your specific credentials
  static const String _cloudName = 'dvjuryrnz';
  static const String _uploadPreset = 'aranpani_unsigned_upload';

  static Future<String?> uploadImage({
    required XFile imageFile, // CHANGED: Accepts XFile (works on both Web & Mobile)
    required String userId,
    required String projectId,
  }) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', uri);

      // --- NEW LOGIC: Handle Web vs Mobile ---
      if (kIsWeb) {
        // On Web: We must read the file as bytes (memory) because there is no "path"
        Uint8List fileBytes = await imageFile.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: imageFile.name,
        ));
      } else {
        // On Mobile: We can read directly from the file path
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ));
      }
      // ----------------------------------------

      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = 'aranpani/$userId/$projectId';

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = json.decode(responseBody);

      if (response.statusCode != 200 && response.statusCode != 201) {
        print("Upload Error: ${data['error']?['message']}");
        return null;
      }

      return data['secure_url'];
    } catch (e) {
      print("Cloudinary Upload Exception: $e");
      return null;
    }
  }
}