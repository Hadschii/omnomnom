import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'home_screen.dart';
import 'recipe_detail_screen.dart';
import 'settings_screen.dart';
import '../models/recipe.dart';
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
