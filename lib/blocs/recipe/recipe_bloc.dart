import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/recipe_repository.dart';
import 'recipe_event.dart';
import 'recipe_state.dart';

class RecipeBloc extends Bloc<RecipeEvent, RecipeState> {
  final RecipeRepository _recipeRepository;

  RecipeBloc({required RecipeRepository recipeRepository})
      : _recipeRepository = recipeRepository,
        super(RecipeInitial()) {
    on<LoadRecipes>(_onLoadRecipes);
    on<AddRecipe>(_onAddRecipe);
    on<UpdateRecipe>(_onUpdateRecipe);
    on<DeleteRecipe>(_onDeleteRecipe);
  }

  void _onLoadRecipes(LoadRecipes event, Emitter<RecipeState> emit) {
    emit(RecipeLoading());
    try {
      final recipes = _recipeRepository.getRecipes();
      emit(RecipeLoaded(recipes));
    } catch (e) {
      emit(RecipeError("Failed to load recipes: $e"));
    }
  }

  Future<void> _onAddRecipe(AddRecipe event, Emitter<RecipeState> emit) async {
    try {
      await _recipeRepository.addRecipe(event.recipe);
      add(LoadRecipes());
    } catch (e) {
      emit(RecipeError("Failed to add recipe: $e"));
    }
  }

  Future<void> _onUpdateRecipe(UpdateRecipe event, Emitter<RecipeState> emit) async {
    try {
      await _recipeRepository.updateRecipe(event.recipe);
      add(LoadRecipes());
    } catch (e) {
      emit(RecipeError("Failed to update recipe: $e"));
    }
  }

  Future<void> _onDeleteRecipe(DeleteRecipe event, Emitter<RecipeState> emit) async {
    try {
      await _recipeRepository.deleteRecipe(event.id);
      add(LoadRecipes());
    } catch (e) {
      emit(RecipeError("Failed to delete recipe: $e"));
    }
  }
}
