import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/ingredient.dart';
import '../models/instruction.dart';
import '../models/recipe.dart';
import '../models/recipe_book.dart';
import '../models/tag.dart';
import '../repositories/recipe_book_repository.dart';
import '../repositories/recipe_repository.dart';
import '../repositories/tag_repository.dart';

class ImportSummary {
  final int recipes;
  final int books;
  final int tags;
  const ImportSummary(this.recipes, this.books, this.tags);
}

/// Exports the whole library to a portable file and imports it back.
///
/// - **ZIP** (`exportZipFile`): `library.json` + a `photos/` folder of the raw
///   images, referenced by relative path. The complete, self-contained backup.
/// - **JSON** (`exportJsonFile`): the same data with photos omitted — a
///   lightweight, human-readable export.
///
/// Import always adds items as **new copies** (fresh ids), so it never
/// overwrites existing data; `bookIds` are remapped to the freshly created
/// books, and bundled photos are copied into app storage with new paths.
class LibraryIoService {
  final RecipeRepository recipeRepo;
  final RecipeBookRepository bookRepo;
  final TagRepository tagRepo;

  const LibraryIoService({
    required this.recipeRepo,
    required this.bookRepo,
    required this.tagRepo,
  });

  static const int formatVersion = 1;
  static const _uuid = Uuid();

  String _basename(String path) => path.split('/').last;

  // ---- Serialization -------------------------------------------------------

  /// Builds the library as a JSON map. When [photoManifest] is supplied,
  /// referenced images are recorded as `{relativeName: absoluteSourcePath}` and
  /// the JSON points at `photos/<name>`; otherwise photo fields are null.
  Map<String, dynamic> buildJson({Map<String, String>? photoManifest}) {
    String? ref(String? absPath) {
      if (photoManifest == null || absPath == null) return null;
      if (!File(absPath).existsSync()) return null;
      final rel = 'photos/${_basename(absPath)}';
      photoManifest[rel] = absPath;
      return rel;
    }

    return {
      'version': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'recipes': [
        for (final r in recipeRepo.getRecipes())
          {
            'title': r.title,
            'servings': r.servings,
            'prepTime': r.prepTime,
            'cookTime': r.cookTime,
            'labels': r.labels,
            'bookIds': r.bookIds,
            'createdAt': r.createdAt.toIso8601String(),
            'image': ref(r.imagePath),
            'ingredients': [
              for (final i in r.ingredients)
                {'name': i.name, 'amount': i.amount, 'group': i.group},
            ],
            'instructions': [
              for (final s in r.instructions)
                {
                  'description': s.description,
                  'group': s.group,
                  'groups': s.groups,
                  'timerSeconds': s.timerSeconds,
                  'photo': ref(s.photoPath),
                },
            ],
            // Kept last so book membership can be remapped on import.
            'id': r.id,
          },
      ],
      'books': [
        for (final b in bookRepo.getBooks())
          {
            'id': b.id,
            'name': b.name,
            'coverImage': ref(b.coverImagePath),
            'createdAt': b.createdAt.toIso8601String(),
          },
      ],
      'tags': [
        for (final t in tagRepo.getTags())
          {'name': t.name, 'color': t.color},
      ],
    };
  }

  String buildJsonString({Map<String, String>? photoManifest}) =>
      const JsonEncoder.withIndent('  ')
          .convert(buildJson(photoManifest: photoManifest));

  // ---- Import (repos + optional photo resolver) ----------------------------

  /// Adds everything in [jsonStr] as new copies. [resolvePhoto] maps a relative
  /// `photos/...` reference to an absolute on-device path (null = drop photo).
  Future<ImportSummary> importFromJsonString(
    String jsonStr, {
    String? Function(String relPath)? resolvePhoto,
  }) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    String? resolve(Object? r) =>
        (r is String) ? resolvePhoto?.call(r) : null;

    DateTime when(Object? iso) =>
        DateTime.tryParse(iso is String ? iso : '') ?? DateTime.now();

    // Books first, remembering old -> new id so recipes can be remapped.
    final bookIdMap = <String, String>{};
    final books = (data['books'] as List?) ?? const [];
    for (final raw in books) {
      final b = raw as Map<String, dynamic>;
      final newId = _uuid.v4();
      bookIdMap[(b['id'] as String?) ?? ''] = newId;
      await bookRepo.addBook(RecipeBook(
        id: newId,
        name: (b['name'] as String?) ?? 'Untitled',
        coverImagePath: resolve(b['coverImage']),
        createdAt: when(b['createdAt']),
      ));
    }

    final tags = (data['tags'] as List?) ?? const [];
    for (final raw in tags) {
      final t = raw as Map<String, dynamic>;
      await tagRepo.addTag(Tag(
        id: _uuid.v4(),
        name: (t['name'] as String?) ?? '',
        color: (t['color'] as num?)?.toInt() ?? 0xFF8E8E93,
      ));
    }

    final recipes = (data['recipes'] as List?) ?? const [];
    for (final raw in recipes) {
      final r = raw as Map<String, dynamic>;
      final oldBookIds = (r['bookIds'] as List?)?.cast<String>() ?? const [];
      final newBookIds = [
        for (final id in oldBookIds)
          if (bookIdMap[id] != null) bookIdMap[id]!,
      ];
      await recipeRepo.addRecipe(Recipe(
        id: _uuid.v4(),
        title: (r['title'] as String?) ?? 'Untitled',
        servings: (r['servings'] as num?)?.toInt(),
        prepTime: (r['prepTime'] as num?)?.toInt(),
        cookTime: (r['cookTime'] as num?)?.toInt(),
        labels: (r['labels'] as List?)?.cast<String>() ?? const [],
        bookIds: newBookIds.isEmpty ? null : newBookIds,
        createdAt: when(r['createdAt']),
        imagePath: resolve(r['image']),
        ingredients: [
          for (final ing in (r['ingredients'] as List?) ?? const [])
            Ingredient(
              name: (ing as Map)['name'] as String? ?? '',
              amount: ing['amount'] as String? ?? '',
              group: ing['group'] as String?,
            ),
        ],
        instructions: [
          for (final ins in (r['instructions'] as List?) ?? const [])
            Instruction(
              description: (ins as Map)['description'] as String? ?? '',
              group: ins['group'] as String?,
              groups: (ins['groups'] as List?)?.cast<String>(),
              timerSeconds: (ins['timerSeconds'] as num?)?.toInt(),
              photoPath: resolve(ins['photo']),
            ),
        ],
      ));
    }

    return ImportSummary(recipes.length, books.length, tags.length);
  }

  // ---- File-based export / import (plugins) --------------------------------

  Future<File> exportJsonFile() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/omnomnom-export-${_stamp()}.json');
    await file.writeAsString(buildJsonString());
    return file;
  }

  Future<File> exportZipFile() async {
    final manifest = <String, String>{};
    final jsonStr = buildJsonString(photoManifest: manifest);

    final archive = Archive();
    final jsonBytes = utf8.encode(jsonStr);
    archive.addFile(ArchiveFile('library.json', jsonBytes.length, jsonBytes));
    for (final entry in manifest.entries) {
      try {
        final bytes = await File(entry.value).readAsBytes();
        archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
      } catch (_) {
        // A missing image is skipped rather than failing the whole export.
      }
    }

    final zipBytes = ZipEncoder().encode(archive);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/omnomnom-export-${_stamp()}.zip');
    await file.writeAsBytes(zipBytes);
    return file;
  }

  Future<ImportSummary> importFromFile(String path) async {
    if (path.toLowerCase().endsWith('.zip')) {
      final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());
      ArchiveFile? jsonEntry;
      final photos = <ArchiveFile>[];
      for (final f in archive) {
        if (!f.isFile) continue;
        if (f.name == 'library.json') {
          jsonEntry = f;
        } else if (f.name.startsWith('photos/')) {
          photos.add(f);
        }
      }
      if (jsonEntry == null) {
        throw const FormatException('Not an OmNomNom export: no library.json');
      }

      // Copy bundled photos into app storage under fresh names.
      final dir = await getApplicationDocumentsDirectory();
      final resolved = <String, String>{};
      for (final p in photos) {
        final dot = p.name.lastIndexOf('.');
        final ext = dot >= 0 ? p.name.substring(dot) : '';
        final dest = File('${dir.path}/${_uuid.v4()}$ext');
        await dest.writeAsBytes(p.content);
        resolved[p.name] = dest.path;
      }

      return importFromJsonString(utf8.decode(jsonEntry.content),
          resolvePhoto: (rel) => resolved[rel]);
    }

    // Plain JSON: data only, no photos to resolve.
    return importFromJsonString(await File(path).readAsString());
  }

  String _stamp() => DateTime.now()
      .toIso8601String()
      .replaceAll(RegExp(r'[:.]'), '-')
      .substring(0, 19);
}
