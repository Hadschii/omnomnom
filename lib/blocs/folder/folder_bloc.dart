import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/folder_repository.dart';
import 'folder_event.dart';
import 'folder_state.dart';

class FolderBloc extends Bloc<FolderEvent, FolderState> {
  final FolderRepository _folderRepository;

  FolderBloc({required FolderRepository folderRepository})
      : _folderRepository = folderRepository,
        super(FolderInitial()) {
    on<LoadFolders>(_onLoadFolders);
    on<AddFolder>(_onAddFolder);
    on<UpdateFolder>(_onUpdateFolder);
    on<DeleteFolder>(_onDeleteFolder);
  }

  void _onLoadFolders(LoadFolders event, Emitter<FolderState> emit) {
    emit(FolderLoading());
    try {
      final folders = _folderRepository.getFolders();
      emit(FolderLoaded(folders));
    } catch (e) {
      emit(FolderError("Failed to load folders: $e"));
    }
  }

  Future<void> _onAddFolder(AddFolder event, Emitter<FolderState> emit) async {
    try {
      await _folderRepository.addFolder(event.folder);
      add(LoadFolders());
    } catch (e) {
      emit(FolderError("Failed to add folder: $e"));
    }
  }

  Future<void> _onUpdateFolder(UpdateFolder event, Emitter<FolderState> emit) async {
    try {
      await _folderRepository.updateFolder(event.folder);
      add(LoadFolders());
    } catch (e) {
      emit(FolderError("Failed to update folder: $e"));
    }
  }

  Future<void> _onDeleteFolder(DeleteFolder event, Emitter<FolderState> emit) async {
    try {
      await _folderRepository.deleteFolder(event.id);
      add(LoadFolders());
    } catch (e) {
      emit(FolderError("Failed to delete folder: $e"));
    }
  }
}
