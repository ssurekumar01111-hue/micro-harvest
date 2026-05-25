part of 'users_bloc.dart';

sealed class UsersState extends Equatable {
  const UsersState();

  @override
  List<Object> get props => [];
}

final class UsersInitial extends UsersState {}

final class UsersLoading extends UsersState {}

final class UsersLoaded extends UsersState {
  final List<Map<String, dynamic>> users;
  final DocumentSnapshot? lastDocument;
  final bool isLoadingMore;

  const UsersLoaded({
    required this.users,
    this.lastDocument,
    this.isLoadingMore = false,
  });

  UsersLoaded copyWith({
    List<Map<String, dynamic>>? users,
    DocumentSnapshot? lastDocument,
    bool? isLoadingMore,
  }) {
    return UsersLoaded(
      users: users ?? this.users,
      lastDocument: lastDocument ?? this.lastDocument,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object> get props => [users, lastDocument ?? Object(), isLoadingMore];
}

final class UsersError extends UsersState {
  final String message;

  const UsersError({required this.message});

  @override
  List<Object> get props => [message];
}