import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:omnomnom_recipe_app/models/ingredient.dart';
import 'package:omnomnom_recipe_app/models/instruction.dart';
import 'package:omnomnom_recipe_app/models/recipe.dart';
import 'package:omnomnom_recipe_app/models/recipe_book.dart';
import 'package:omnomnom_recipe_app/models/tag.dart';
import 'package:omnomnom_recipe_app/repositories/recipe_book_repository.dart';
import 'package:omnomnom_recipe_app/repositories/recipe_repository.dart';
import 'package:omnomnom_recipe_app/repositories/tag_repository.dart';
import 'package:omnomnom_recipe_app/services/library_io_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late RecipeRepository recipeRepo;
  late RecipeBookRepository bookRepo;
  late TagRepository tagRepo;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('omnomnom_io');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(IngredientAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(RecipeAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(InstructionAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(RecipeBookAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(TagAdapter());
    recipeRepo = RecipeRepository();
    bookRepo = RecipeBookRepository();
    tagRepo = TagRepository();
    await recipeRepo.init();
    await bookRepo.init();
    await tagRepo.init();
    await recipeRepo.clearAll(); // drop the seed recipe
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    dir.deleteSync(recursive: true);
  });

  test('JSON round-trip adds copies with new ids and remapped bookIds',
      () async {
    await bookRepo.addBook(RecipeBook(
        id: 'book-old', name: 'Family', createdAt: DateTime(2026, 1, 1)));
    await tagRepo.addTag(
        Tag(id: 'tag-old', name: 'Weeknight', color: 0xFFF69021));
    await recipeRepo.addRecipe(Recipe(
      id: 'recipe-old',
      title: 'Chicken Paprika Noodles',
      ingredients: [
        Ingredient(name: 'Milk', amount: '100 ml', group: 'Sauce'),
      ],
      instructions: [
        Instruction(
            description: 'Simmer the sauce.',
            group: 'Sauce',
            groups: ['Sauce'],
            timerSeconds: 300),
      ],
      labels: const ['Weeknight'],
      createdAt: DateTime(2026, 6, 26),
      servings: 2,
      bookIds: const ['book-old'],
    ));

    final service = LibraryIoService(
        recipeRepo: recipeRepo, bookRepo: bookRepo, tagRepo: tagRepo);

    final json = service.buildJsonString(); // data only, no photos
    final summary = await service.importFromJsonString(json);

    expect(summary.recipes, 1);
    expect(summary.books, 1);
    expect(summary.tags, 1);

    // Originals + imported copies coexist.
    expect(recipeRepo.getRecipes().length, 2);
    expect(bookRepo.getBooks().length, 2);
    expect(tagRepo.getTags().length, 2);

    // The imported recipe is a new copy...
    final copy =
        recipeRepo.getRecipes().firstWhere((r) => r.id != 'recipe-old');
    expect(copy.title, 'Chicken Paprika Noodles');
    expect(copy.instructions.single.timerSeconds, 300);
    expect(copy.instructions.single.groups, ['Sauce']);

    // ...and its bookIds point at the freshly created book, not the old one.
    final newBook = bookRepo.getBooks().firstWhere((b) => b.id != 'book-old');
    expect(copy.bookIds, [newBook.id]);
    expect(copy.bookIds, isNot(contains('book-old')));
  });
}
