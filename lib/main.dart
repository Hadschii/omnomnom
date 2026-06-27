import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'blocs/book/book_bloc.dart';
import 'blocs/book/book_event.dart';
import 'blocs/recipe/recipe_bloc.dart';
import 'blocs/recipe/recipe_event.dart';
import 'blocs/settings/settings_bloc.dart';
import 'blocs/settings/settings_event.dart';
import 'blocs/settings/settings_state.dart';
import 'blocs/tag/tag_bloc.dart';
import 'blocs/tag/tag_event.dart';
import 'models/ingredient.dart';
import 'models/instruction.dart';
import 'models/recipe.dart';
import 'models/recipe_book.dart';
import 'models/tag.dart';
import 'repositories/recipe_book_repository.dart';
import 'repositories/recipe_repository.dart';
import 'repositories/tag_repository.dart';
import 'router.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);

  // Register Adapters. Type id 1 (Folder) is retired and intentionally left
  // unregistered; never reuse it.
  Hive.registerAdapter(IngredientAdapter());
  Hive.registerAdapter(InstructionAdapter());
  Hive.registerAdapter(RecipeAdapter());
  Hive.registerAdapter(RecipeBookAdapter());
  Hive.registerAdapter(TagAdapter());

  // Initialize Repositories
  final recipeRepository = RecipeRepository();
  final bookRepository = RecipeBookRepository();
  final tagRepository = TagRepository();

  await recipeRepository.init();
  await bookRepository.init();
  await tagRepository.init();

  runApp(OmnomnomApp(
    recipeRepository: recipeRepository,
    bookRepository: bookRepository,
    tagRepository: tagRepository,
  ));
}

class OmnomnomApp extends StatelessWidget {
  final RecipeRepository recipeRepository;
  final RecipeBookRepository bookRepository;
  final TagRepository tagRepository;

  const OmnomnomApp({
    super.key,
    required this.recipeRepository,
    required this.bookRepository,
    required this.tagRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: recipeRepository),
        RepositoryProvider.value(value: bookRepository),
        RepositoryProvider.value(value: tagRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => RecipeBloc(
              recipeRepository: recipeRepository,
            )..add(LoadRecipes()),
          ),
          BlocProvider(
            create: (context) => BookBloc(
              bookRepository: bookRepository,
            )..add(LoadBooks()),
          ),
          BlocProvider(
            create: (context) => TagBloc(
              tagRepository: tagRepository,
            )..add(LoadTags()),
          ),
          BlocProvider(
            create: (context) => SettingsBloc(
              recipeRepository: recipeRepository,
            )..add(LoadSettings()),
          ),
        ],
        child: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, state) {
            return MaterialApp.router(
              title: 'OmNomNom',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: state.themeMode,
              routerConfig: router,
              debugShowCheckedModeBanner: false,
            );
          },
        ),
      ),
    );
  }
}
