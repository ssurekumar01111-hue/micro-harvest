part of 'users_bloc.dart';

sealed class UsersEvent extends Equatable {
  const UsersEvent();

  @override
  List<Object> get props => [];
}

class LoadUsers extends UsersEvent {}

class FilterUsers extends UsersEvent {
  final String? role;
  final String? query; // for name or phone

  const FilterUsers({this.role, this.query});

  @override
  List<Object> get props => [role ?? '', query ?? ''];
}

class SuspendUser extends UsersEvent {
  final String uid;

  const SuspendUser({required this.uid});

  @override
  List<Object> get props => [uid];
}

class ReactivateUser extends UsersEvent {
  final String uid;

  const ReactivateUser({required this.uid});

  @override
  List<Object> get props => [uid];
}

// Internal event to update state from stream
class _UsersUpdated extends UsersEvent {
  final List<Map<String, dynamic>> users;
  final DocumentSnapshot? lastDoc;

  const _UsersUpdated({required this.users, this.lastDoc});

  @override
  List<Object> get props => [users, lastDoc ?? Object()];
}

