import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'home_screen.dart';
import 'books_screen.dart';
import 'recipe_detail_screen.dart';
import 'settings_screen.dart';

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
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            // Switching tabs leaves any open recipe detail so each tab opens
            // to its own root.
            _selectedRecipeId = null;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Recipes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Books',
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
        const BooksScreen(),
        const SettingsScreen(),
      ],
    );
  }

  Widget _buildDesktopBody() {
    // Books and Settings show full-width; only Recipes uses the master/detail
    // split.
    if (_selectedIndex == 1) {
      return const BooksScreen();
    }
    if (_selectedIndex == 2) {
      return const SettingsScreen();
    }
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
    // Only the Recipes tab uses the master/detail split; Books and Settings
    // are handled full-width in _buildDesktopBody.
    return Column(
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
        Expanded(
          child: RecipeList(
            onRecipeSelected: (recipe) {
              setState(() {
                _selectedRecipeId = recipe.id;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopRightPane() {
    if (_selectedRecipeId != null) {
      return RecipeDetailScreen(
        recipeId: _selectedRecipeId!,
        showBackButton: false,
      );
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
