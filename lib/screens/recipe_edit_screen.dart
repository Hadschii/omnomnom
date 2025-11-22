import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../blocs/recipe/recipe_bloc.dart';
import '../blocs/recipe/recipe_event.dart';
import '../blocs/recipe/recipe_state.dart';
import '../blocs/folder/folder_bloc.dart';
import '../blocs/folder/folder_event.dart';
import '../blocs/folder/folder_state.dart';
import '../models/folder.dart';
import '../models/ingredient.dart';
import '../models/instruction.dart';
import '../models/recipe.dart';
import 'edit_screen_helpers.dart';

class RecipeEditScreen extends StatefulWidget {
  final String? recipeId;

  const RecipeEditScreen({super.key, this.recipeId});

  @override
  State<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends State<RecipeEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  
  // UI State
  final _uiIngredients = <ListItem>[];
  final _uiInstructions = <ListItem>[];
  String? _editingItemId; // ID of the item currently being edited

  final _labels = <String>[];
  final _labelController = TextEditingController();
  final _servingsController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _cookTimeController = TextEditingController();
  String? _selectedFolderId;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    if (widget.recipeId != null) {
      final state = context.read<RecipeBloc>().state;
      if (state is RecipeLoaded) {
        final recipe = state.recipes.firstWhere((r) => r.id == widget.recipeId);
        _titleController.text = recipe.title;
        
        // Parse Ingredients
        String? currentGroup;
        for (var i in recipe.ingredients) {
          if (i.group != currentGroup) {
            currentGroup = i.group;
            if (currentGroup != null) {
              _uiIngredients.add(HeaderItem(currentGroup));
            }
          }
          _uiIngredients.add(IngredientItem(name: i.name, amount: i.amount));
        }

        // Parse Instructions
        currentGroup = null;
        for (var i in recipe.instructions) {
          if (i.group != currentGroup) {
            currentGroup = i.group;
            if (currentGroup != null) {
              _uiInstructions.add(HeaderItem(currentGroup));
            }
          }
          _uiInstructions.add(InstructionItem(description: i.description, photoPath: i.photoPath));
        }

        _labels.addAll(recipe.labels);
        _selectedFolderId = recipe.folderId;
        _imagePath = recipe.imagePath;
        _servingsController.text = recipe.servings?.toString() ?? '';
        _prepTimeController.text = recipe.prepTime?.toString() ?? '';
        _cookTimeController.text = recipe.cookTime?.toString() ?? '';
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _labelController.dispose();
    _servingsController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    super.dispose();
  }

  void _saveRecipe() {
    if (_formKey.currentState!.validate()) {
      // Reconstruct Ingredients
      final ingredients = <Ingredient>[];
      String? currentGroup;
      for (var item in _uiIngredients) {
        if (item is HeaderItem) {
          currentGroup = item.name;
        } else if (item is IngredientItem) {
          if (item.name.trim().isNotEmpty) {
            ingredients.add(Ingredient(
              name: item.name,
              amount: item.amount,
              group: currentGroup,
            ));
          }
        }
      }

      // Reconstruct Instructions
      final instructions = <Instruction>[];
      currentGroup = null;
      for (var item in _uiInstructions) {
        if (item is HeaderItem) {
          currentGroup = item.name;
        } else if (item is InstructionItem) {
          if (item.description.trim().isNotEmpty) {
            instructions.add(Instruction(
              description: item.description,
              photoPath: item.photoPath,
              group: currentGroup,
            ));
          }
        }
      }

      final recipe = Recipe(
        id: widget.recipeId ?? const Uuid().v4(),
        title: _titleController.text,
        ingredients: ingredients,
        instructions: instructions,
        labels: _labels,
        createdAt: DateTime.now(),
        folderId: _selectedFolderId,
        imagePath: _imagePath,
        servings: int.tryParse(_servingsController.text),
        prepTime: int.tryParse(_prepTimeController.text),
        cookTime: int.tryParse(_cookTimeController.text),
      );

      if (widget.recipeId != null) {
        context.read<RecipeBloc>().add(UpdateRecipe(recipe));
      } else {
        context.read<RecipeBloc>().add(AddRecipe(recipe));
      }
      context.pop();
    }
  }



  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = '${const Uuid().v4()}${pickedFile.path.substring(pickedFile.path.lastIndexOf('.'))}';
        final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');

        setState(() {
          _imagePath = savedImage.path;
        });
      } catch (e) {
        // Handle error (e.g., show snackbar)
        debugPrint('Error saving image: $e');
      }
    }
  }

  void _createFolder() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('New Folder'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Folder Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  final folder = Folder(
                    id: const Uuid().v4(),
                    name: controller.text,
                    color: '0xFF000000', // Default color
                  );
                  context.read<FolderBloc>().add(AddFolder(folder));
                  Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipeId != null ? 'Edit Recipe' : 'New Recipe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveRecipe,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Recipe Title',
                hintText: 'e.g., Grandma\'s Apple Pie',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _servingsController,
                    decoration: const InputDecoration(labelText: 'Servings'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _prepTimeController,
                    decoration: const InputDecoration(labelText: 'Prep (min)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _cookTimeController,
                    decoration: const InputDecoration(labelText: 'Cook (min)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Image Picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).inputDecorationTheme.fillColor,
                  borderRadius: BorderRadius.circular(12),
                  image: _imagePath != null
                      ? DecorationImage(
                          image: FileImage(File(_imagePath!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _imagePath == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text('Add Cover Photo', style: TextStyle(color: Colors.grey[400])),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            // Folder Selection
            BlocBuilder<FolderBloc, FolderState>(
              builder: (context, state) {
                List<Folder> folders = [];
                if (state is FolderLoaded) {
                  folders = state.folders;
                }
                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Folder',
                          prefixIcon: Icon(Icons.folder),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Inbox (No Folder)'),
                          ),
                          ...folders.map((folder) => DropdownMenuItem(
                                value: folder.id,
                                child: Text(folder.name),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedFolderId = value;
                          });
                        },
                        // Ensure value is valid
                        value: folders.any((f) => f.id == _selectedFolderId) ? _selectedFolderId : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _createFolder,
                      icon: const Icon(Icons.create_new_folder),
                      tooltip: 'Create Folder',
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            _buildSectionHeader(
              'Ingredients',
              onAdd: () => _handleAddItem(_uiIngredients, IngredientItem(name: '', amount: '')),
              onAddGroup: () => _handleAddItem(_uiIngredients, HeaderItem('')),
            ),
            _buildReorderableIngredientList(),
            const SizedBox(height: 24),
            _buildSectionHeader(
              'Instructions',
              onAdd: () => _handleAddItem(_uiInstructions, InstructionItem(description: '')),
              onAddGroup: () => _handleAddItem(_uiInstructions, HeaderItem('')),
            ),
            _buildReorderableInstructionList(),
            const SizedBox(height: 24),
            Text('Labels', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ..._labels.map((label) => Chip(
                      label: Text(label),
                      onDeleted: () {
                        setState(() {
                          _labels.remove(label);
                        });
                      },
                    )),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('Add Label'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        final controller = TextEditingController();
                        return AlertDialog(
                          title: const Text('Add Label'),
                          content: TextField(
                            controller: controller,
                            decoration: const InputDecoration(labelText: 'Label name'),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                if (controller.text.isNotEmpty) {
                                  setState(() {
                                    _labels.add(controller.text);
                                  });
                                  Navigator.pop(context);
                                }
                              },
                              child: const Text('Add'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isItemEmpty(ListItem item) {
    if (item is HeaderItem) return item.name.trim().isEmpty || item.name == 'New Group';
    if (item is IngredientItem) return item.name.trim().isEmpty && item.amount.trim().isEmpty;
    if (item is InstructionItem) return item.description.trim().isEmpty;
    return false;
  }

  void _handleAddItem(List<ListItem> targetList, ListItem newItem) {
    setState(() {
      if (_editingItemId != null) {
        // Check Ingredients
        final ingIndex = _uiIngredients.indexWhere((i) => i.id == _editingItemId);
        if (ingIndex != -1) {
          if (_isItemEmpty(_uiIngredients[ingIndex])) {
            if (targetList == _uiIngredients && _uiIngredients[ingIndex].runtimeType == newItem.runtimeType) {
              return; // Same list, same type, empty -> Keep editing
            }
            _uiIngredients.removeAt(ingIndex);
          }
        } else {
          // Check Instructions
          final instIndex = _uiInstructions.indexWhere((i) => i.id == _editingItemId);
          if (instIndex != -1) {
            if (_isItemEmpty(_uiInstructions[instIndex])) {
              if (targetList == _uiInstructions && _uiInstructions[instIndex].runtimeType == newItem.runtimeType) {
                return;
              }
              _uiInstructions.removeAt(instIndex);
            }
          }
        }
      }
      
      targetList.add(newItem);
      _editingItemId = newItem.id;
    });
  }

  Widget _buildSectionHeader(String title, {required VoidCallback onAdd, required VoidCallback onAddGroup}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        _AnimatedAddButton(onTap: onAdd, onLongPress: onAddGroup),
      ],
    );
  }

  Widget _buildReorderableIngredientList() {
    if (_uiIngredients.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text('No ingredients added', style: TextStyle(color: Colors.grey)),
      );
    }

    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          final item = _uiIngredients.removeAt(oldIndex);
          _uiIngredients.insert(newIndex, item);
        });
      },
      children: _uiIngredients.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;

        if (_editingItemId == item.id) {
          return _buildInlineEditor(item);
        }

        return Dismissible(
          key: item.key,
          background: Container(color: Colors.green, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20), child: const Icon(Icons.edit, color: Colors.white)),
          secondaryBackground: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              setState(() {
                _uiIngredients.remove(item);
              });
              return true;
            } else {
              setState(() {
                _editingItemId = item.id;
              });
              return false;
            }
          },
          child: _buildIngredientRow(item, index),
        );
      }).toList(),
    );
  }

  Widget _buildIngredientRow(ListItem item, int index) {
    if (item is HeaderItem) {
      return ListTile(
        key: item.key,
        title: Text(item.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
        tileColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.grey[200],
        dense: true,
        trailing: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle),
        ),
      );
    } else if (item is IngredientItem) {
      return ListTile(
        key: item.key,
        title: Text(item.name),
        subtitle: Text(item.amount),
        trailing: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildReorderableInstructionList() {
    if (_uiInstructions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text('No instructions added', style: TextStyle(color: Colors.grey)),
      );
    }

    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          final item = _uiInstructions.removeAt(oldIndex);
          _uiInstructions.insert(newIndex, item);
        });
      },
      children: _uiInstructions.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;

        if (_editingItemId == item.id) {
          return _buildInlineEditor(item);
        }

        return Dismissible(
          key: item.key,
          background: Container(color: Colors.green, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20), child: const Icon(Icons.edit, color: Colors.white)),
          secondaryBackground: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              setState(() {
                _uiInstructions.remove(item);
              });
              return true;
            } else {
              setState(() {
                _editingItemId = item.id;
              });
              return false;
            }
          },
          child: _buildInstructionRow(item, index),
        );
      }).toList(),
    );
  }

  Widget _buildInstructionRow(ListItem item, int index) {
    if (item is HeaderItem) {
      return ListTile(
        key: item.key,
        title: Text(item.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
        tileColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.grey[200],
        dense: true,
        trailing: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle),
        ),
      );
    } else if (item is InstructionItem) {
      return ListTile(
        key: item.key,
        title: Text(item.description),
        trailing: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildInlineEditor(ListItem item) {
    if (item is HeaderItem) {
      final controller = TextEditingController(text: item.name);
      return Padding(
        key: item.key,
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(child: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Group Name'), autofocus: true)),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                return AnimatedScale(
                  scale: value.text.trim().isNotEmpty ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () {
                      if (value.text.trim().isNotEmpty) {
                        setState(() {
                          item.name = controller.text;
                          _editingItemId = null;
                        });
                      }
                    },
                  ),
                );
              },
            ),
          ],
        ),
      );
    } else if (item is IngredientItem) {
      final nameCtrl = TextEditingController(text: item.name);
      final amountCtrl = TextEditingController(text: item.amount);
      return Padding(
        key: item.key,
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(flex: 1, child: TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Amount'), autofocus: true)),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Ingredient'))),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: nameCtrl,
              builder: (context, value, child) {
                return AnimatedScale(
                  scale: value.text.trim().isNotEmpty ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () {
                      if (value.text.trim().isNotEmpty) {
                        setState(() {
                          item.name = nameCtrl.text;
                          item.amount = amountCtrl.text;
                          _editingItemId = null;
                        });
                      }
                    },
                  ),
                );
              },
            ),
          ],
        ),
      );
    } else if (item is InstructionItem) {
      final descCtrl = TextEditingController(text: item.description);
      return Padding(
        key: item.key,
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(child: TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Step'), maxLines: 3, minLines: 1, autofocus: true)),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: descCtrl,
              builder: (context, value, child) {
                return AnimatedScale(
                  scale: value.text.trim().isNotEmpty ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () {
                      if (value.text.trim().isNotEmpty) {
                        setState(() {
                          item.description = descCtrl.text;
                          _editingItemId = null;
                        });
                      }
                    },
                  ),
                );
              },
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _AnimatedAddButton extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _AnimatedAddButton({required this.onTap, required this.onLongPress});

  @override
  State<_AnimatedAddButton> createState() => _AnimatedAddButtonState();
}

class _AnimatedAddButtonState extends State<_AnimatedAddButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.1,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      onLongPressStart: (_) => _controller.forward(),
      onLongPressEnd: (_) {
        _controller.reverse();
        widget.onLongPress();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 - _controller.value,
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.add_circle_outline,
            color: Colors.grey[600], // Minimalistic grey tone
            size: 24,
          ),
        ),
      ),
    );
  }
}
