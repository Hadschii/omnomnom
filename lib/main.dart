import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'blocs/book/book_bloc.dart';
import 'blocs/book/book_event.dart';
import 'blocs/folder/folder_bloc.dart';
import 'blocs/folder/folder_event.dart';
import 'blocs/recipe/recipe_bloc.dart';
import 'blocs/recipe/recipe_event.dart';
import 'blocs/settings/settings_bloc.dart';
import 'blocs/settings/settings_event.dart';
import 'blocs/settings/settings_state.dart';
import 'models/folder.dart';
import 'models/ingredient.dart';
import 'models/instruction.dart';
import 'models/recipe.dart';
import 'models/recipe_book.dart';
import 'repositories/folder_repository.dart';
import 'repositories/recipe_book_repository.dart';
import 'repositories/recipe_repository.dart';
import 'router.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);

  // Register Adapters
  Hive.registerAdapter(IngredientAdapter());
  Hive.registerAdapter(InstructionAdapter());
  Hive.registerAdapter(FolderAdapter());
  Hive.registerAdapter(RecipeAdapter());
  Hive.registerAdapter(RecipeBookAdapter());

  // Initialize Repositories
  final recipeRepository = RecipeRepository();
  final folderRepository = FolderRepository();
  final bookRepository = RecipeBookRepository();

  await recipeRepository.init();
  await folderRepository.init();
  await bookRepository.init();

  runApp(OmnomnomApp(
    recipeRepository: recipeRepository,
    folderRepository: folderRepository,
    bookRepository: bookRepository,
  ));
}

class OmnomnomApp extends StatelessWidget {
  final RecipeRepository recipeRepository;
  final FolderRepository folderRepository;
  final RecipeBookRepository bookRepository;

  const OmnomnomApp({
    super.key,
    required this.recipeRepository,
    required this.folderRepository,
    required this.bookRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: recipeRepository),
        RepositoryProvider.value(value: folderRepository),
        RepositoryProvider.value(value: bookRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => RecipeBloc(
              recipeRepository: recipeRepository,
            )..add(LoadRecipes()),
          ),
          BlocProvider(
            create: (context) => FolderBloc(
              folderRepository: folderRepository,
            )..add(LoadFolders()),
          ),
          BlocProvider(
            create: (context) => BookBloc(
              bookRepository: bookRepository,
            )..add(LoadBooks()),
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
