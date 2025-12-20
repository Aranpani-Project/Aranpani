import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String _cloudName = 'dvjuryrnz';
  static const String _uploadPreset = 'aranpani_unsigned_upload';

  static Future<String> uploadImage( {
    required File imageFile,
    required String userId,
    required String projectId,
  }) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = 'aranpani/$userId/$projectId'
      ..files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    final data = json.decode(responseBody);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(data['error']?['message'] ?? 'Cloudinary upload failed');
    }

    return data['secure_url'];
  }
}
