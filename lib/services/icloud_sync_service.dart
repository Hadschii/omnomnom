import 'dart:convert';
import 'dart:io';
import 'package:icloud_storage/icloud_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../models/recipe.dart';
import '../models/ingredient.dart';
import '../models/instruction.dart';
import 'sync_service.dart';

class ICloudSyncService implements SyncService {
  static const String _containerId = 'iCloud.com.example.omnomnom'; // TODO: Replace with actual container ID

  @override
  Future<void> init() async {
    // No specific init needed
  }

  @override
  Future<bool> isConnected() async {
    return true; 
  }

  @override
  Future<void> uploadRecipe(Recipe recipe) async {
    final jsonMap = _recipeToJson(recipe);
    final jsonString = jsonEncode(jsonMap);
    final fileName = '${recipe.id}.json';
    
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');
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
            
            await ICloudStorage.download(
              containerId: _containerId,
              relativePath: file.relativePath,
              destinationFilePath: destPath,
            );

            final jsonString = await File(destPath).readAsString();
            final jsonMap = jsonDecode(jsonString);
            recipes.add(_recipeFromJson(jsonMap));
          } catch (e) {
            print('Error downloading/parsing recipe ${file.relativePath}: $e');
          }
        }
      }
    } catch (e) {
      print('Error gathering files: $e');
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
      print('Error downloading image $imageName: $e');
      return null;
    }
  }

  // Helper methods for JSON serialization (since Recipe model uses Hive)
  Map<String, dynamic> _recipeToJson(Recipe recipe) {
    return {
      'id': recipe.id,
      'title': recipe.title,
      'ingredients': recipe.ingredients.map((e) => {'name': e.name, 'amount': e.amount}).toList(),
      'instructions': recipe.instructions.map((e) => {'description': e.description}).toList(),
      'folderId': recipe.folderId,
      'labels': recipe.labels,
      'createdAt': recipe.createdAt.toIso8601String(),
      'imagePath': recipe.imagePath?.split('/').last, // Store only filename
      'servings': recipe.servings,
      'prepTime': recipe.prepTime,
      'cookTime': recipe.cookTime,
    };
  }

  Recipe _recipeFromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'],
      title: json['title'],
      ingredients: (json['ingredients'] as List).map((e) => Ingredient(name: e['name'], amount: e['amount'])).toList(),
      instructions: (json['instructions'] as List).map((e) => Instruction(description: e['description'])).toList(),
      folderId: json['folderId'],
      labels: List<String>.from(json['labels']),
      createdAt: DateTime.parse(json['createdAt']),
      imagePath: json['imagePath'], // This will be just the filename, need to resolve path later or during download
      servings: json['servings'],
      prepTime: json['prepTime'],
      cookTime: json['cookTime'],
    );
  }
}
