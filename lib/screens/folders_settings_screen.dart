import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/folder/folder_bloc.dart';
import '../blocs/folder/folder_event.dart';
import '../blocs/folder/folder_state.dart';
import '../blocs/recipe/recipe_bloc.dart';
import '../blocs/recipe/recipe_event.dart';
import '../models/folder.dart';
import '../repositories/recipe_repository.dart';

const List<Map<String, dynamic>> _folderColors = [
  {'name': 'Orange', 'value': '0xFFF69021'},
  {'name': 'Red', 'value': '0xFFE57373'},
  {'name': 'Pink', 'value': '0xFFF06292'},
  {'name': 'Purple', 'value': '0xFFBA68C8'},
  {'name': 'Deep Purple', 'value': '0xFF9575CD'},
  {'name': 'Blue', 'value': '0xFF64B5F6'},
  {'name': 'Teal', 'value': '0xFF4DB6AC'},
  {'name': 'Green', 'value': '0xFF81C784'},
  {'name': 'Yellow', 'value': '0xFFFFF176'},
  {'name': 'Grey', 'value': '0xFF90A4AE'},
];

class FoldersSettingsScreen extends StatelessWidget {
  const FoldersSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folder Management'),
      ),
      body: BlocBuilder<FolderBloc, FolderState>(
        builder: (context, state) {
          if (state is FolderLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is FolderLoaded) {
            if (state.folders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No folders created yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: state.folders.length,
              itemBuilder: (context, index) {
                final folder = state.folders[index];
                Color folderColor = Colors.grey;
                try {
                  folderColor = Color(int.parse(folder.color));
                } catch (_) {}

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: folderColor,
                    radius: 12,
                  ),
                  title: Text(folder.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showFolderDialog(context, folder: folder),
                        tooltip: 'Rename / Edit Color',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(context, folder),
                        tooltip: 'Delete Folder',
                      ),
                    ],
                  ),
                );
              },
            );
          } else if (state is FolderError) {
            return Center(child: Text(state.message));
          }
          return const SizedBox();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFolderDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showFolderDialog(BuildContext context, {Folder? folder}) {
    final controller = TextEditingController(text: folder?.name ?? '');
    String selectedColorHex = folder?.color ?? _folderColors.first['value'];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(folder == null ? 'Create Folder' : 'Rename Folder'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(labelText: 'Folder Name'),
                      autofocus: true,
                    ),
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Select Color',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _folderColors.map((colorMap) {
                        final colorHex = colorMap['value'];
                        final color = Color(int.parse(colorHex));
                        final isSelected = selectedColorHex == colorHex;

                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedColorHex = colorHex;
                            });
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.black, width: 3)
                                  : null,
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                )
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      if (folder == null) {
                        final newFolder = Folder(
                          id: const Uuid().v4(),
                          name: name,
                          color: selectedColorHex,
                        );
                        context.read<FolderBloc>().add(AddFolder(newFolder));
                      } else {
                        final updatedFolder = Folder(
                          id: folder.id,
                          name: name,
                          color: selectedColorHex,
                        );
                        context.read<FolderBloc>().add(UpdateFolder(updatedFolder));
                      }
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: Text(folder == null ? 'Create' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Folder folder) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Folder?'),
          content: Text(
            'Are you sure you want to delete the folder "${folder.name}"?\n\n'
            'Recipes inside this folder will not be deleted; they will be moved to the Inbox.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                // 1. Delete folder from FolderBloc
                context.read<FolderBloc>().add(DeleteFolder(folder.id));
                
                // 2. Clear folderId in RecipeRepository
                await context.read<RecipeRepository>().removeFolderIdFromRecipes(folder.id);
                
                // 3. Reload recipes in RecipeBloc so UI refreshes
                if (context.mounted) {
                  context.read<RecipeBloc>().add(LoadRecipes());
                }
                
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
