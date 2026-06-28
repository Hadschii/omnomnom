import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/tag_repository.dart';
import 'tag_event.dart';
import 'tag_state.dart';

class TagBloc extends Bloc<TagEvent, TagState> {
  final TagRepository _tagRepository;

  TagBloc({required TagRepository tagRepository})
      : _tagRepository = tagRepository,
        super(TagInitial()) {
    on<LoadTags>(_onLoad);
    on<AddTag>(_onAdd);
    on<UpdateTag>(_onUpdate);
    on<DeleteTag>(_onDelete);
    on<ReorderTags>(_onReorderTags);
  }

  void _onLoad(LoadTags event, Emitter<TagState> emit) {
    emit(TagLoading());
    try {
      emit(TagLoaded(
        _tagRepository.getTags(),
        tagOrder: _tagRepository.getTagOrder(),
      ));
    } catch (e) {
      emit(TagError('Failed to load tags: $e'));
    }
  }

  Future<void> _onAdd(AddTag event, Emitter<TagState> emit) async {
    try {
      await _tagRepository.addTag(event.tag);
      add(LoadTags());
    } catch (e) {
      emit(TagError('Failed to add tag: $e'));
    }
  }

  Future<void> _onUpdate(UpdateTag event, Emitter<TagState> emit) async {
    try {
      await _tagRepository.updateTag(event.tag);
      add(LoadTags());
    } catch (e) {
      emit(TagError('Failed to update tag: $e'));
    }
  }

  Future<void> _onDelete(DeleteTag event, Emitter<TagState> emit) async {
    try {
      await _tagRepository.deleteTag(event.id);
      add(LoadTags());
    } catch (e) {
      emit(TagError('Failed to delete tag: $e'));
    }
  }

  Future<void> _onReorderTags(ReorderTags event, Emitter<TagState> emit) async {
    try {
      await _tagRepository.saveTagOrder(event.orderedNames);
      add(LoadTags());
    } catch (e) {
      emit(TagError('Failed to reorder tags: $e'));
    }
  }
}
