import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'home_screen.dart';
import 'recipe_detail_screen.dart';
import 'settings_screen.dart';
import 'folders_settings_screen.dart';
import '../blocs/folder/folder_bloc.dart';
import '../blocs/folder/folder_state.dart';
import '../models/folder.dart';
import '../widgets/theme_selector.dart';
import '../widgets/about_view.dart';

class MainScreen extends StatefulWidget {
  final int initialTab;
  final String? selectedRecipeId;

  const MainScreen({
    super.key,
    this.initialTab = 0,
    this.selectedRecipeId,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;
  String? _selectedRecipeId;
  String? _selectedSetting;
  String _desktopSearchQuery = '';
  String? _desktopFolderId;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
    _selectedRecipeId = widget.selectedRecipeId;
  }

  @override
  void didUpdateWidget(MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      _selectedIndex = widget.initialTab;
    }
    if (widget.selectedRecipeId != oldWidget.selectedRecipeId) {
      _selectedRecipeId = widget.selectedRecipeId;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return _buildMobileBody();
          } else {
            return _buildDesktopBody();
          }
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            // Reset selection when switching tabs
            if (index == 0) {
              // Keep recipe selection or reset? Let's keep.
            } else {
              // Default to first setting? Or none.
              _selectedSetting = null;
            }
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Recipes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBody() {
    if (_selectedRecipeId != null) {
      return RecipeDetailScreen(
        recipeId: _selectedRecipeId!,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            setState(() {
              _selectedRecipeId = null;
            });
          }
        },
      );
    }
    return IndexedStack(
      index: _selectedIndex,
      children: [
        const HomeScreen(),
        const SettingsScreen(),
      ],
    );
  }

  Widget _buildDesktopBody() {
    return Row(
      children: [
        // Left Pane (List)
        SizedBox(
          width: 300,
          child: _buildDesktopLeftPane(),
        ),
        const VerticalDivider(width: 1),
        // Right Pane (Content)
        Expanded(
          child: _buildDesktopRightPane(),
        ),
      ],
    );
  }

  Widget _buildDesktopLeftPane() {
    if (_selectedIndex == 0) {
      return BlocBuilder<FolderBloc, FolderState>(
        builder: (context, folderState) {
          final folders =
              folderState is FolderLoaded ? folderState.folders : <Folder>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppBar(
                title: const Text('Recipes'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => context.go('/recipe/new'),
                  ),
                ],
              ),
              _DesktopFolderList(
                folders: folders,
                selectedFolderId: _desktopFolderId,
                onFolderSelected: (id) =>
                    setState(() => _desktopFolderId = id),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12.0, vertical: 8.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search recipes...',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[900]
                            : Colors.grey[200],
                  ),
                  onChanged: (value) =>
                      setState(() => _desktopSearchQuery = value),
                ),
              ),
              Expanded(
                child: RecipeList(
                  searchQuery: _desktopSearchQuery,
                  folderId: _desktopFolderId,
                  onRecipeSelected: (recipe) =>
                      setState(() => _selectedRecipeId = recipe.id),
                ),
              ),
            ],
          );
        },
      );
    } else {
      return Column(
        children: [
          AppBar(
            title: const Text('Settings'),
            automaticallyImplyLeading: false,
          ),
          Expanded(
            child: SettingsList(
              onTap: (setting) {
                setState(() {
                  _selectedSetting = setting;
                });
              },
            ),
          ),
        ],
      );
    }
  }

  Widget _buildDesktopRightPane() {
    if (_selectedIndex == 0) {
      if (_selectedRecipeId != null) {
        return RecipeDetailScreen(
          recipeId: _selectedRecipeId!,
          showBackButton: false,
        );
      }
    } else {
      if (_selectedSetting == 'theme') {
        return const Center(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Theme Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 24),
                ThemeSelector(),
              ],
            ),
          ),
        );
      } else if (_selectedSetting == 'about') {
        return const AboutView();
      } else if (_selectedSetting == 'folders') {
        return const FoldersSettingsScreen();
      } else {
        return Center(
          child: Text(
            'Select a setting',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        );
      }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/app_logo.png',
            width: 150,
            height: 150,
          ),
          const SizedBox(height: 24),
          Text(
            'Select a recipe to view details',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }
}

class _DesktopFolderList extends StatelessWidget {
  final List<Folder> folders;
  final String? selectedFolderId;
  final ValueChanged<String?> onFolderSelected;

  const _DesktopFolderList({
    required this.folders,
    required this.selectedFolderId,
    required this.onFolderSelected,
  });

  @override
  Widget build(BuildContext context) {
    final primaryContainer =
        Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35);
    final primary = Theme.of(context).colorScheme.primary;
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: const Icon(Icons.restaurant_menu, size: 18),
          title: const Text('All Recipes'),
          selected: selectedFolderId == null,
          selectedColor: primary,
          selectedTileColor: primaryContainer,
          shape: shape,
          onTap: () => onFolderSelected(null),
        ),
        if (folders.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
            child: Text(
              'Folders',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
            ),
          ),
          ...folders.map((folder) => ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: CircleAvatar(
                  radius: 8,
                  backgroundColor: Color(int.parse(folder.color)),
                ),
                title: Text(folder.name),
                selected: selectedFolderId == folder.id,
                selectedColor: primary,
                selectedTileColor: primaryContainer,
                shape: shape,
                onTap: () => onFolderSelected(folder.id),
              )),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}
