import 'package:equatable/equatable.dart';
import '../../models/folder.dart';

abstract class FolderState extends Equatable {
  const FolderState();
  
  @override
  List<Object> get props => [];
}

class FolderInitial extends FolderState {}

class FolderLoading extends FolderState {}

class FolderLoaded extends FolderState {
  final List<Folder> folders;

  const FolderLoaded(this.folders);

  @override
  List<Object> get props => [folders];
}

class FolderError extends FolderState {
  final String message;

  const FolderError(this.message);

  @override
  List<Object> get props => [message];
}
