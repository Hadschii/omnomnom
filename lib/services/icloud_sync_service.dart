import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:icloud_storage/icloud_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../models/recipe.dart';
import 'recipe_codec.dart';
import 'sync_service.dart';

const _logName = 'ICloudSyncService';

class ICloudSyncService implements SyncService {
  static const String _containerId = 'iCloud.com.example.omnomnom'; // TODO: Replace with actual container ID

  @override
  Future<void> init() async {
    // No init needed. Individual operations handle PlatformException gracefully.
  }

  @override
  Future<bool> isConnected() async {
    try {
      await ICloudStorage.gather(containerId: _containerId);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> uploadRecipe(Recipe recipe) async {
    final jsonMap = recipeToJson(recipe);
    final jsonString = jsonEncode(jsonMap);
    final fileName = '${recipe.id}.json';
    
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.parent.create(recursive: true);
    await tempFile.writeAsString(jsonString);

    await ICloudStorage.upload(
      containerId: _containerId,
      filePath: tempFile.path,
      destinationRelativePath: fileName,
      onProgress: (stream) {
        // Optional: handle progress
      },
    );
  }

  @override
  Future<void> deleteRecipe(String id) async {
    final fileName = '$id.json';
    await ICloudStorage.delete(
      containerId: _containerId,
      relativePath: fileName,
    );
  }

  @override
  Future<List<Recipe>> downloadAllRecipes() async {
    final recipes = <Recipe>[];
    
    try {
      final files = await ICloudStorage.gather(
        containerId: _containerId,
      );

      for (final file in files) {
        if (file.relativePath.endsWith('.json')) {
          try {
            final tempDir = await getTemporaryDirectory();
            final destPath = '${tempDir.path}/${file.relativePath}';
            await File(destPath).parent.create(recursive: true);

            await ICloudStorage.download(
              containerId: _containerId,
              relativePath: file.relativePath,
              destinationFilePath: destPath,
            );

            final jsonString = await File(destPath).readAsString();
            final jsonMap = jsonDecode(jsonString);
            recipes.add(recipeFromJson(jsonMap));
          } catch (e) {
            log('Error downloading/parsing recipe ${file.relativePath}',
                name: _logName, error: e);
          }
        }
      }
    } catch (e) {
      log('Error gathering files', name: _logName, error: e);
    }
    return recipes;
  }

  @override
  Future<void> uploadImage(String imagePath) async {
    final fileName = imagePath.split('/').last;
    await ICloudStorage.upload(
      containerId: _containerId,
      filePath: imagePath,
      destinationRelativePath: fileName,
    );
  }

  @override
  Future<String?> downloadImage(String imageName) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final localPath = '${appDocDir.path}/$imageName';
      
      if (await File(localPath).exists()) {
        return localPath;
      }

      await ICloudStorage.download(
        containerId: _containerId,
        relativePath: imageName,
        destinationFilePath: localPath,
      );
      return localPath;
    } catch (e) {
      log('Error downloading image $imageName', name: _logName, error: e);
      return null;
    }
  }
}
