import '../models/recipe.dart';

abstract class SyncService {
  Future<void> init();
  Future<void> uploadRecipe(Recipe recipe);
  Future<void> deleteRecipe(String id);
  Future<List<Recipe>> downloadAllRecipes();
  Future<bool> isConnected();
  
  // Image handling
  Future<void> uploadImage(String imagePath);
  Future<String?> downloadImage(String imageName);
}
