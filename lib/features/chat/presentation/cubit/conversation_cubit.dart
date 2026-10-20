import 'package:flutter_bloc/flutter_bloc.dart';

class ConversationCubit extends Cubit<bool> {
  ConversationCubit() : super(false);

  void startConversation() {
    emit(true);
  }

  void resetConversation() {
    emit(false);
  }
}