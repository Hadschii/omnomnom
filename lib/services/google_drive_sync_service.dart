import 'dart:convert';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:path_provider/path_provider.dart';
import '../models/recipe.dart';
import '../models/ingredient.dart';
import '../models/instruction.dart';
import 'sync_service.dart';

class GoogleDriveSyncService implements SyncService {
  // Web Client ID from Google Cloud Console
  static const String _serverClientId = '1096578044836-bqpee1hluiup3jeannrqa23nv307d87b.apps.googleusercontent.com';

  GoogleSignIn get _googleSignIn => GoogleSignIn.instance;
  
  drive.DriveApi? _driveApi;

  @override
  Future<void> init() async {
    print('GoogleDriveSyncService: init() started');
    GoogleSignInAccount? account;
    try {
      print('GoogleDriveSyncService: Initializing GoogleSignIn...');
      try {
        await _googleSignIn.initialize(
          serverClientId: _serverClientId,
        );
        print('GoogleDriveSyncService: GoogleSignIn initialized successfully');
      } catch (e) {
        print('GoogleDriveSyncService: GoogleSignIn initialize error (might be already initialized): $e');
      }

      print('GoogleDriveSyncService: Attempting lightweight authentication...');
      account = await _googleSignIn.attemptLightweightAuthentication();
      
      if (account == null) {
         print('GoogleDriveSyncService: Lightweight auth returned null. Requesting interactive authenticate...');
         try {
            account = await _googleSignIn.authenticate();
            print('GoogleDriveSyncService: Interactive authenticate returned account: ${account?.email}');
         } catch (e) {
            print('GoogleDriveSyncService: Interactive authenticate failed: $e');
            throw Exception('Google interactive authenticate failed: $e');
         }
      } else {
         print('GoogleDriveSyncService: Lightweight auth successful for ${account.email}');
      }
      
      if (account != null) {
        print('GoogleDriveSyncService: Account obtained: ${account.email}');
        
        try {
          print('GoogleDriveSyncService: Requesting authorization for Drive AppData scope...');
          await account.authorizationClient.authorizeScopes([drive.DriveApi.driveAppdataScope]);
          
          print('GoogleDriveSyncService: Retrieving authenticated client via extension...');
          final client = await _googleSignIn.authenticatedClient();
          
          if (client != null) {
              _driveApi = drive.DriveApi(client);
              print('GoogleDriveSyncService: Drive API initialized successfully');
          } else {
              print('GoogleDriveSyncService: Authenticated client was null');
              throw Exception('Failed to obtain authenticated client from Google Sign-In.');
          }
        } catch (e) {
          print('GoogleDriveSyncService: Error creating authenticated client: $e');
          throw Exception('Google Drive client authentication failed: $e');
        }
      } else {
        print('GoogleDriveSyncService: Account is still null after authentication attempts');
        throw Exception('Sign-in failed. Google account is unauthorized.');
      }
    } catch (e) {
      print('GoogleDriveSyncService: Error initializing/signing in to Google: $e');
      _driveApi = null;
      rethrow;
    }
  }

  @override
  Future<bool> isConnected() async {
    return _driveApi != null;
  }

  @override
  Future<void> uploadRecipe(Recipe recipe) async {
    if (_driveApi == null) {
      print('GoogleDriveSyncService: uploadRecipe called but _driveApi is null');
      throw Exception('Google Drive is not connected');
    }

    print('GoogleDriveSyncService: Uploading recipe ${recipe.title} (${recipe.id})');
    final jsonMap = _recipeToJson(recipe);
    final jsonString = jsonEncode(jsonMap);
    final fileName = '${recipe.id}.json';

    // Check if file exists
    final fileId = await _getFileId(fileName);
    
    final jsonBytes = utf8.encode(jsonString);
    final media = drive.Media(Stream.value(jsonBytes), jsonBytes.length);
    
    try {
      if (fileId != null) {
        // Update
        print('GoogleDriveSyncService: Updating existing file $fileId');
         await _driveApi!.files.update(
          drive.File(),
          fileId,
          uploadMedia: media,
        );
      } else {
        // Create
        print('GoogleDriveSyncService: Creating new file $fileName');
        await _driveApi!.files.create(
          drive.File()
            ..name = fileName
            ..parents = ['appDataFolder'],
          uploadMedia: media,
        );
      }
      print('GoogleDriveSyncService: Upload successful');
    } catch (e) {
      print('GoogleDriveSyncService: Error uploading recipe: $e');
      throw Exception('Failed to upload recipe to Google Drive: $e');
    }
  }

  @override
  Future<void> deleteRecipe(String id) async {
    if (_driveApi == null) {
      throw Exception('Google Drive is not connected');
    }
    print('GoogleDriveSyncService: Deleting recipe $id');
    final fileName = '$id.json';
    final fileId = await _getFileId(fileName);
    if (fileId != null) {
      try {
        await _driveApi!.files.delete(fileId);
        print('GoogleDriveSyncService: Delete successful');
      } catch (e) {
        print('GoogleDriveSyncService: Error deleting recipe: $e');
        throw Exception('Failed to delete recipe from Google Drive: $e');
      }
    } else {
      print('GoogleDriveSyncService: File not found for deletion');
    }
  }

  @override
  Future<List<Recipe>> downloadAllRecipes() async {
    if (_driveApi == null) {
      print('GoogleDriveSyncService: downloadAllRecipes called but _driveApi is null');
      throw Exception('Google Drive is not connected');
    }

    print('GoogleDriveSyncService: Downloading all recipes...');
    try {
      final fileList = await _driveApi!.files.list(
        q: "name contains '.json'",
        spaces: 'appDataFolder',
        $fields: 'files(id, name)',
      );

      print('GoogleDriveSyncService: Found ${fileList.files?.length ?? 0} files');

      final recipes = <Recipe>[];
      if (fileList.files != null) {
        for (final file in fileList.files!) {
          if (file.id != null) {
            try {
              print('GoogleDriveSyncService: Downloading file ${file.name} (${file.id})');
              final media = await _driveApi!.files.get(file.id!, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
              final jsonString = await utf8.decodeStream(media.stream);
              final jsonMap = jsonDecode(jsonString);
              recipes.add(_recipeFromJson(jsonMap));
            } catch (e) {
              print('GoogleDriveSyncService: Error downloading recipe ${file.name}: $e');
              // Let it continue downloading other files but log the error
            }
          }
        }
      }
      print('GoogleDriveSyncService: Downloaded ${recipes.length} recipes');
      return recipes;
    } catch (e) {
      print('GoogleDriveSyncService: Error listing/downloading recipes: $e');
      throw Exception('Failed to download recipes from Google Drive: $e');
    }
  }

  @override
  Future<void> uploadImage(String imagePath) async {
    if (_driveApi == null) {
      throw Exception('Google Drive is not connected');
    }
    
    final fileName = imagePath.split('/').last;
    print('GoogleDriveSyncService: Uploading image $fileName');
    final fileId = await _getFileId(fileName);
    final file = File(imagePath);
    if (!file.existsSync()) {
      print('GoogleDriveSyncService: Image file not found at $imagePath');
      return;
    }

    final media = drive.Media(file.openRead(), file.lengthSync());

    try {
      if (fileId != null) {
         await _driveApi!.files.update(
          drive.File(),
          fileId,
          uploadMedia: media,
        );
      } else {
        await _driveApi!.files.create(
          drive.File()
            ..name = fileName
            ..parents = ['appDataFolder'],
          uploadMedia: media,
        );
      }
      print('GoogleDriveSyncService: Image upload successful');
    } catch (e) {
      print('GoogleDriveSyncService: Error uploading image: $e');
      throw Exception('Failed to upload recipe image: $e');
    }
  }

  @override
  Future<String?> downloadImage(String imageName) async {
    if (_driveApi == null) {
      throw Exception('Google Drive is not connected');
    }

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final localPath = '${appDocDir.path}/$imageName';
      
      if (await File(localPath).exists()) {
        print('GoogleDriveSyncService: Image $imageName already exists locally');
        return localPath;
      }

      print('GoogleDriveSyncService: Downloading image $imageName');
      final fileId = await _getFileId(imageName);
      if (fileId != null) {
        final media = await _driveApi!.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
        final file = File(localPath);
        await media.stream.pipe(file.openWrite());
        print('GoogleDriveSyncService: Image download successful');
        return localPath;
      } else {
        print('GoogleDriveSyncService: Image file not found in Drive');
      }
    } catch (e) {
      print('GoogleDriveSyncService: Error downloading image $imageName: $e');
      throw Exception('Failed to download image $imageName: $e');
    }
    return null;
  }

  Future<String?> _getFileId(String fileName) async {
    try {
      final fileList = await _driveApi!.files.list(
        q: "name = '$fileName'",
        spaces: 'appDataFolder',
        $fields: 'files(id)',
      );
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id;
      }
    } catch (e) {
      print('GoogleDriveSyncService: Error getting file ID for $fileName: $e');
    }
    return null;
  }

  Map<String, dynamic> _recipeToJson(Recipe recipe) {
    return {
      'id': recipe.id,
      'title': recipe.title,
      'ingredients': recipe.ingredients.map((e) => {'name': e.name, 'amount': e.amount}).toList(),
      'instructions': recipe.instructions.map((e) => {'description': e.description}).toList(),
      'folderId': recipe.folderId,
      'labels': recipe.labels,
      'createdAt': recipe.createdAt.toIso8601String(),
      'imagePath': recipe.imagePath?.split('/').last,
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
      imagePath: json['imagePath'],
      servings: json['servings'],
      prepTime: json['prepTime'],
      cookTime: json['cookTime'],
    );
  }
}
