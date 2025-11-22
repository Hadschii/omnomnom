import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omnomnom_recipe_app/blocs/recipe/recipe_bloc.dart';
import 'package:omnomnom_recipe_app/blocs/recipe/recipe_event.dart';
import 'package:omnomnom_recipe_app/blocs/recipe/recipe_state.dart';
import 'package:omnomnom_recipe_app/models/recipe.dart';
import 'package:omnomnom_recipe_app/repositories/recipe_repository.dart';

class MockRecipeRepository extends Mock implements RecipeRepository {}

void main() {
  group('RecipeBloc', () {
    late RecipeRepository recipeRepository;

    setUp(() {
      recipeRepository = MockRecipeRepository();
    });

    final recipe = Recipe(
      id: '1',
      title: 'Test Recipe',
      ingredients: [],
      instructions: [],
      labels: [],
      createdAt: DateTime.now(),
    );

    test('initial state is RecipeInitial', () {
      expect(RecipeBloc(recipeRepository: recipeRepository).state, RecipeInitial());
    });

    blocTest<RecipeBloc, RecipeState>(
      'emits [RecipeLoading, RecipeLoaded] when LoadRecipes is added',
      build: () {
        when(() => recipeRepository.getRecipes()).thenReturn([recipe]);
        return RecipeBloc(recipeRepository: recipeRepository);
      },
      act: (bloc) => bloc.add(LoadRecipes()),
      expect: () => [
        RecipeLoading(),
        RecipeLoaded([recipe]),
      ],
    );

    blocTest<RecipeBloc, RecipeState>(
      'emits [RecipeLoading, RecipeError] when LoadRecipes fails',
      build: () {
        when(() => recipeRepository.getRecipes()).thenThrow(Exception('oops'));
        return RecipeBloc(recipeRepository: recipeRepository);
      },
      act: (bloc) => bloc.add(LoadRecipes()),
      expect: () => [
        RecipeLoading(),
        const RecipeError('Failed to load recipes: Exception: oops'),
      ],
    );

    blocTest<RecipeBloc, RecipeState>(
      'adds recipe and reloads',
      build: () {
        when(() => recipeRepository.addRecipe(recipe)).thenAnswer((_) async {});
        when(() => recipeRepository.getRecipes()).thenReturn([recipe]);
        return RecipeBloc(recipeRepository: recipeRepository);
      },
      act: (bloc) => bloc.add(AddRecipe(recipe)),
      expect: () => [
        RecipeLoading(),
        RecipeLoaded([recipe]),
      ],
      verify: (_) {
        verify(() => recipeRepository.addRecipe(recipe)).called(1);
      },
    );
  });
}
