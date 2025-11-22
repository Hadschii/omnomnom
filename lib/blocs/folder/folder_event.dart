import 'package:equatable/equatable.dart';
import '../../models/folder.dart';

abstract class FolderEvent extends Equatable {
  const FolderEvent();

  @override
  List<Object> get props => [];
}

class LoadFolders extends FolderEvent {}

class AddFolder extends FolderEvent {
  final Folder folder;

  const AddFolder(this.folder);

  @override
  List<Object> get props => [folder];
}

class UpdateFolder extends FolderEvent {
  final Folder folder;

  const UpdateFolder(this.folder);

  @override
  List<Object> get props => [folder];
}

class DeleteFolder extends FolderEvent {
  final String id;

  const DeleteFolder(this.id);

  @override
  List<Object> get props => [id];
}
