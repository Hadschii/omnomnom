import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'blocs/folder/folder_bloc.dart';
import 'blocs/folder/folder_event.dart';
import 'blocs/recipe/recipe_bloc.dart';
import 'blocs/recipe/recipe_event.dart';
import 'models/folder.dart';
import 'models/ingredient.dart';
import 'models/recipe.dart';
import 'repositories/folder_repository.dart';
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
  Hive.registerAdapter(FolderAdapter());
  Hive.registerAdapter(RecipeAdapter());

  // Initialize Repositories
  final recipeRepository = RecipeRepository();
  final folderRepository = FolderRepository();
  
  await recipeRepository.init();
  await folderRepository.init();

  runApp(OmnomnomApp(
    recipeRepository: recipeRepository,
    folderRepository: folderRepository,
  ));
}

class OmnomnomApp extends StatelessWidget {
  final RecipeRepository recipeRepository;
  final FolderRepository folderRepository;

  const OmnomnomApp({
    super.key,
    required this.recipeRepository,
    required this.folderRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: recipeRepository),
        RepositoryProvider.value(value: folderRepository),
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
        ],
        child: MaterialApp.router(
          title: 'Omnomnom',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
