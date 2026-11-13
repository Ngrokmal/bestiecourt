import 'package:equatable/equatable.dart';

class ContractTemplate extends Equatable {
  const ContractTemplate({
    required this.code,
    required this.title,
    required this.clauses,
  });

  final String code;
  final String title;
  final List<String> clauses;

  @override
  List<Object?> get props => <Object?>[code, title, clauses];
}

class FriendshipContract extends Equatable {
  const FriendshipContract({
    required this.id,
    required this.title,
    required this.clauses,
    required this.state,
    required this.isCreator,
    required this.creatorName,
    required this.participantName,
    this.expiresAt,
  });

  final String id;
  final String title;
  final List<String> clauses;
  final String state;
  final bool isCreator;
  final String creatorName;
  final String participantName;
  final DateTime? expiresAt;

  bool get isPending => state == 'pending';
  bool get isActive => state == 'active';
  bool get needsMySignature => isPending && !isCreator;

  String get stateLabel {
    switch (state) {
      case 'active':
        return 'সক্রিয় ✅';
      case 'pending':
        return 'সইয়ের অপেক্ষায়';
      case 'declined':
        return 'গ্রহণ করা হয়নি';
      case 'cancelled':
        return 'বাতিল';
      case 'expired':
        return 'মেয়াদ শেষ';
      default:
        return state;
    }
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        title,
        clauses,
        state,
        isCreator,
        creatorName,
        participantName,
      ];
}

abstract class ContractRepository {
  Future<List<ContractTemplate>> fetchTemplates();

  Future<List<FriendshipContract>> fetchContracts();

  Future<void> createContract({
    required String participantId,
    required String templateCode,
  });

  Future<void> respond({required String contractId, required bool accept});

  Future<void> cancel(String contractId);
}
