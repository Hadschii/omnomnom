import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/recipe_book_repository.dart';
import 'book_event.dart';
import 'book_state.dart';

class BookBloc extends Bloc<BookEvent, BookState> {
  final RecipeBookRepository _bookRepository;

  BookBloc({required RecipeBookRepository bookRepository})
      : _bookRepository = bookRepository,
        super(BookInitial()) {
    on<LoadBooks>(_onLoadBooks);
    on<AddBook>(_onAddBook);
    on<UpdateBook>(_onUpdateBook);
    on<DeleteBook>(_onDeleteBook);
  }

  void _onLoadBooks(LoadBooks event, Emitter<BookState> emit) {
    emit(BookLoading());
    try {
      emit(BookLoaded(_bookRepository.getBooks()));
    } catch (e) {
      emit(BookError('Failed to load books: $e'));
    }
  }

  Future<void> _onAddBook(AddBook event, Emitter<BookState> emit) async {
    try {
      await _bookRepository.addBook(event.book);
      add(LoadBooks());
    } catch (e) {
      emit(BookError('Failed to add book: $e'));
    }
  }

  Future<void> _onUpdateBook(UpdateBook event, Emitter<BookState> emit) async {
    try {
      await _bookRepository.updateBook(event.book);
      add(LoadBooks());
    } catch (e) {
      emit(BookError('Failed to update book: $e'));
    }
  }

  Future<void> _onDeleteBook(DeleteBook event, Emitter<BookState> emit) async {
    try {
      await _bookRepository.deleteBook(event.id);
      add(LoadBooks());
    } catch (e) {
      emit(BookError('Failed to delete book: $e'));
    }
  }
}
