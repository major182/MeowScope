import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// 写真の選び方
enum PhotoSource { camera, gallery }

/// 写真を選ぶ部品。テストでは決めた画像を返す版に差し替える
abstract interface class PhotoPicker {
  /// 選んだ画像。選ばずに閉じたら null
  Future<Uint8List?> pick(PhotoSource source);
}

/// 端末のカメラとアルバムから選ぶ（image_picker）。Windows はファイルを選ぶ画面になる
class DevicePhotoPicker implements PhotoPicker {
  DevicePhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
    );
    return file?.readAsBytes();
  }
}
