// lib/services/cloudinary_service.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  // CHANGE ONLY THESE TWO IF NEEDED
  static const String _cloudName = 'dvjuryrnz';
  static const String _uploadPreset = 'aranpani_unsigned_upload';

  static Future<String?> uploadImage({
    required XFile imageFile,
    required String userId,
    required String projectId,
  }) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', uri);

      // -------- FILE PART (WEB vs MOBILE/DESKTOP) --------
      if (kIsWeb) {
        // On web XFile.path is a blob URL, so always use bytes
        Uint8List bytes = await imageFile.readAsBytes();
        if (bytes.isEmpty) {
          print('Cloudinary: picked file has 0 bytes');
          return null;
        }
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: imageFile.name.isNotEmpty ? imageFile.name : 'upload.jpg',
          ),
        );
      } else {
        // Android / iOS / Windows / macOS / Linux
        if (imageFile.path.isEmpty) {
          print('Cloudinary: empty imageFile.path');
          return null;
        }
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            imageFile.path,
          ),
        );
      }
      // ---------------------------------------------------

      // Required Cloudinary fields
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = 'aranpani/$userId/$projectId';

      // DEBUG: log what is being sent
      print('Cloudinary => POST $uri');
      print('preset: $_uploadPreset, folder: aranpani/$userId/$projectId');
      print('XFile name: ${imageFile.name}, path: ${imageFile.path}');

      final response = await request.send();
      final body = await response.stream.bytesToString();
      print('Cloudinary status: ${response.statusCode}');
      print('Cloudinary body: $body');

      final Map<String, dynamic> data = json.decode(body);

      if (response.statusCode != 200 && response.statusCode != 201) {
        print('Cloudinary error: ${data['error']?['message'] ?? 'Unknown'}');
        return null;
      }

      final String? url =
          data['secure_url']?.toString() ?? data['url']?.toString();
      if (url == null || url.isEmpty) {
        print('Cloudinary: secure_url missing in response');
        return null;
      }

      print('Cloudinary upload success: $url');
      return url;
    } catch (e) {
      print('Cloudinary Upload Exception: $e');
      return null;
    }
  }
}
