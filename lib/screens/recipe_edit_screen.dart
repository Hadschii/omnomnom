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
import '../models/recipe.dart';

class RecipeEditScreen extends StatefulWidget {
  final String? recipeId;

  const RecipeEditScreen({super.key, this.recipeId});

  @override
  State<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends State<RecipeEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _ingredients = <Ingredient>[];
  final _instructions = <String>[];
  final _labels = <String>[];
  final _labelController = TextEditingController();
  String? _selectedFolderId;
  String? _imagePath;

  // Inline editing state
  bool _isAddingIngredient = false;
  final _newIngredientNameController = TextEditingController();
  final _newIngredientAmountController = TextEditingController();

  bool _isAddingInstruction = false;
  final _newInstructionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.recipeId != null) {
      final state = context.read<RecipeBloc>().state;
      if (state is RecipeLoaded) {
        final recipe = state.recipes.firstWhere((r) => r.id == widget.recipeId);
        _titleController.text = recipe.title;
        _ingredients.addAll(recipe.ingredients);
        _instructions.addAll(recipe.instructions);
        _labels.addAll(recipe.labels);
        _selectedFolderId = recipe.folderId;
        _imagePath = recipe.imagePath;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _labelController.dispose();
    _newIngredientNameController.dispose();
    _newIngredientAmountController.dispose();
    _newInstructionController.dispose();
    super.dispose();
  }

  void _saveRecipe() {
    if (_formKey.currentState!.validate()) {
      final recipe = Recipe(
        id: widget.recipeId ?? const Uuid().v4(),
        title: _titleController.text,
        ingredients: _ingredients,
        instructions: _instructions,
        labels: _labels,
        createdAt: DateTime.now(),
        folderId: _selectedFolderId,
        imagePath: _imagePath,
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
            _buildSectionHeader('Ingredients', onAdd: () {
              setState(() {
                _isAddingIngredient = true;
              });
            }),
            if (_ingredients.isEmpty && !_isAddingIngredient)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('No ingredients added', style: TextStyle(color: Colors.grey)),
              ),
            ..._ingredients.asMap().entries.map((entry) {
              final index = entry.key;
              final ingredient = entry.value;
              return ListTile(
                title: Text(ingredient.name),
                subtitle: ingredient.amount.isNotEmpty ? Text(ingredient.amount) : null,
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    setState(() {
                      _ingredients.removeAt(index);
                    });
                  },
                ),
              );
            }),
            if (_isAddingIngredient)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _newIngredientAmountController,
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          hintText: 'e.g. 100g',
                        ),
                        autofocus: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _newIngredientNameController,
                        decoration: const InputDecoration(
                          labelText: 'Ingredient',
                          hintText: 'e.g. Sugar',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () {
                        if (_newIngredientNameController.text.isNotEmpty) {
                          setState(() {
                            _ingredients.add(Ingredient(
                              name: _newIngredientNameController.text,
                              amount: _newIngredientAmountController.text,
                            ));
                            _newIngredientNameController.clear();
                            _newIngredientAmountController.clear();
                            // Keep adding mode open for rapid entry
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _isAddingIngredient = false;
                          _newIngredientNameController.clear();
                          _newIngredientAmountController.clear();
                        });
                      },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            _buildSectionHeader('Instructions', onAdd: () {
              setState(() {
                _isAddingInstruction = true;
              });
            }),
            if (_instructions.isEmpty && !_isAddingInstruction)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('No instructions added', style: TextStyle(color: Colors.grey)),
              ),
            ..._instructions.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              return ListTile(
                leading: CircleAvatar(
                  radius: 12,
                  child: Text('${index + 1}', style: const TextStyle(fontSize: 12)),
                ),
                title: Text(step),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    setState(() {
                      _instructions.removeAt(index);
                    });
                  },
                ),
              );
            }),
            if (_isAddingInstruction)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newInstructionController,
                        decoration: const InputDecoration(
                          labelText: 'Step Description',
                          hintText: 'e.g. Mix the ingredients...',
                        ),
                        maxLines: 3,
                        minLines: 1,
                        autofocus: true,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () {
                        if (_newInstructionController.text.isNotEmpty) {
                          setState(() {
                            _instructions.add(_newInstructionController.text);
                            _newInstructionController.clear();
                            // Keep adding mode open
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _isAddingInstruction = false;
                          _newInstructionController.clear();
                        });
                      },
                    ),
                  ],
                ),
              ),
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

  Widget _buildSectionHeader(String title, {required VoidCallback onAdd}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: onAdd,
        ),
      ],
    );
  }
}
