import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../constants/game_config.dart';
import '../constants/strings.dart';

class ImageService {
  static Future<String> pickAndCompressPhoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: GameConfig.photoMaxWidth,
      imageQuality: GameConfig.photoQuality,
    );
    if (image == null) throw _UserCancelledException();

    final bytes = await image.readAsBytes();
    if (bytes.lengthInBytes > GameConfig.photoMaxBytes) {
      throw Exception(Strings.photoTooLarge);
    }

    return base64Encode(bytes);
  }
}

class _UserCancelledException implements Exception {}
