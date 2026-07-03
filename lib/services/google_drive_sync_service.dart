import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:path_provider/path_provider.dart';
import '../models/recipe.dart';
import 'recipe_codec.dart';
import 'sync_service.dart';

const _logName = 'GoogleDriveSyncService';

class GoogleDriveSyncService implements SyncService {
  // Web Client ID from Google Cloud Console
  static const String _serverClientId = '1096578044836-bqpee1hluiup3jeannrqa23nv307d87b.apps.googleusercontent.com';

  GoogleSignIn get _googleSignIn => GoogleSignIn.instance;

  drive.DriveApi? _driveApi;

  @override
  Future<void> init() async {
    GoogleSignInAccount? account;
    try {
      try {
        await _googleSignIn.initialize(serverClientId: _serverClientId);
      } catch (e) {
        // Non-fatal: initialize() throws if already initialized.
        log('GoogleSignIn initialize error (may be already initialized)',
            name: _logName, error: e);
      }

      account = await _googleSignIn.attemptLightweightAuthentication();
      if (account == null) {
        try {
          account = await _googleSignIn.authenticate();
        } catch (e) {
          log('Interactive authenticate failed', name: _logName, error: e);
          throw Exception('Google interactive authenticate failed: $e');
        }
      }

      try {
        final scopes = [drive.DriveApi.driveAppdataScope];
        // Try silent authorization first; fall back to interactive prompt.
        GoogleSignInClientAuthorization? authorization =
            await account.authorizationClient.authorizationForScopes(scopes);
        authorization ??= await account.authorizationClient.authorizeScopes(scopes);
        _driveApi = drive.DriveApi(authorization.authClient(scopes: scopes));
      } catch (e) {
        log('Error creating authenticated client', name: _logName, error: e);
        throw Exception('Google Drive client authentication failed: $e');
      }
    } catch (e) {
      log('Error initializing/signing in to Google', name: _logName, error: e);
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
      throw Exception('Google Drive is not connected');
    }

    final jsonMap = recipeToJson(recipe);
    final jsonString = jsonEncode(jsonMap);
    final fileName = '${recipe.id}.json';

    final fileId = await _getFileId(fileName);

    final jsonBytes = utf8.encode(jsonString);
    final media = drive.Media(Stream.value(jsonBytes), jsonBytes.length);

    try {
      if (fileId != null) {
        await _driveApi!.files.update(drive.File(), fileId, uploadMedia: media);
      } else {
        await _driveApi!.files.create(
          drive.File()
            ..name = fileName
            ..parents = ['appDataFolder'],
          uploadMedia: media,
        );
      }
    } catch (e) {
      log('Error uploading recipe ${recipe.id}', name: _logName, error: e);
      throw Exception('Failed to upload recipe to Google Drive: $e');
    }
  }

  @override
  Future<void> deleteRecipe(String id) async {
    if (_driveApi == null) {
      throw Exception('Google Drive is not connected');
    }
    final fileName = '$id.json';
    final fileId = await _getFileId(fileName);
    if (fileId == null) return;
    try {
      await _driveApi!.files.delete(fileId);
    } catch (e) {
      log('Error deleting recipe $id', name: _logName, error: e);
      throw Exception('Failed to delete recipe from Google Drive: $e');
    }
  }

  @override
  Future<List<Recipe>> downloadAllRecipes() async {
    if (_driveApi == null) {
      throw Exception('Google Drive is not connected');
    }

    try {
      final fileList = await _driveApi!.files.list(
        q: "name contains '.json'",
        spaces: 'appDataFolder',
        $fields: 'files(id, name)',
      );

      final recipes = <Recipe>[];
      for (final file in fileList.files ?? const <drive.File>[]) {
        if (file.id == null) continue;
        try {
          final media = await _driveApi!.files
              .get(file.id!, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
          final jsonString = await utf8.decodeStream(media.stream);
          recipes.add(recipeFromJson(jsonDecode(jsonString)));
        } catch (e) {
          // Non-fatal: skip this recipe, keep downloading the rest.
          log('Error downloading recipe ${file.name}', name: _logName, error: e);
        }
      }
      return recipes;
    } catch (e) {
      log('Error listing/downloading recipes', name: _logName, error: e);
      throw Exception('Failed to download recipes from Google Drive: $e');
    }
  }

  @override
  Future<void> uploadImage(String imagePath) async {
    if (_driveApi == null) {
      throw Exception('Google Drive is not connected');
    }

    final fileName = imagePath.split('/').last;
    final fileId = await _getFileId(fileName);
    final file = File(imagePath);
    if (!file.existsSync()) return;

    final media = drive.Media(file.openRead(), file.lengthSync());

    try {
      if (fileId != null) {
        await _driveApi!.files.update(drive.File(), fileId, uploadMedia: media);
      } else {
        await _driveApi!.files.create(
          drive.File()
            ..name = fileName
            ..parents = ['appDataFolder'],
          uploadMedia: media,
        );
      }
    } catch (e) {
      log('Error uploading image $fileName', name: _logName, error: e);
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
        return localPath;
      }

      final fileId = await _getFileId(imageName);
      if (fileId == null) return null;

      final media = await _driveApi!.files
          .get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      final file = File(localPath);
      await media.stream.pipe(file.openWrite());
      return localPath;
    } catch (e) {
      log('Error downloading image $imageName', name: _logName, error: e);
      throw Exception('Failed to download image $imageName: $e');
    }
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
      log('Error getting file ID for $fileName', name: _logName, error: e);
    }
    return null;
  }
}
