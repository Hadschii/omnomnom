import 'package:equatable/equatable.dart';
import '../../models/tag.dart';

abstract class TagState extends Equatable {
  const TagState();

  @override
  List<Object> get props => [];
}

class TagInitial extends TagState {}

class TagLoading extends TagState {}

class TagLoaded extends TagState {
  final List<Tag> tags;
  final List<String> tagOrder;
  const TagLoaded(this.tags, {this.tagOrder = const []});
  @override
  List<Object> get props => [tags, tagOrder];
}

class TagError extends TagState {
  final String message;
  const TagError(this.message);
  @override
  List<Object> get props => [message];
}
