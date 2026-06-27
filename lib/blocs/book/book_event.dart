import 'package:equatable/equatable.dart';
import '../../models/recipe_book.dart';

abstract class BookEvent extends Equatable {
  const BookEvent();

  @override
  List<Object> get props => [];
}

class LoadBooks extends BookEvent {}

class AddBook extends BookEvent {
  final RecipeBook book;

  const AddBook(this.book);

  @override
  List<Object> get props => [book];
}

class UpdateBook extends BookEvent {
  final RecipeBook book;

  const UpdateBook(this.book);

  @override
  List<Object> get props => [book];
}

class DeleteBook extends BookEvent {
  final String id;

  const DeleteBook(this.id);

  @override
  List<Object> get props => [id];
}
