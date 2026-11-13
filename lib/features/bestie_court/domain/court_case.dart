import 'package:equatable/equatable.dart';

class CourtCase extends Equatable {
  const CourtCase({
    required this.id,
    required this.plaintiffName,
    required this.defendantName,
    required this.isPlaintiff,
    required this.complaint,
    required this.state,
    required this.createdAt,
    this.response,
    this.verdict,
    this.myVote,
  });

  final String id;
  final String plaintiffName;
  final String defendantName;
  final bool isPlaintiff;
  final String complaint;
  final String state;
  final DateTime? createdAt;
  final String? response;
  final String? verdict;
  final String? myVote;

  bool get awaitingResponse => state == 'awaiting_response';
  bool get needsMyResponse => awaitingResponse && !isPlaintiff;
  bool get canVote => state == 'voting' && myVote == null;
  bool get decided => state == 'decided';

  String get verdictLabel {
    switch (verdict) {
      case 'guilty':
        return 'দোষী 😈';
      case 'not_guilty':
        return 'নির্দোষ 😇';
      case 'split':
        return 'জুরি বিভক্ত — খারিজ';
      case 'dismissed':
        return 'মামলা খারিজ';
      default:
        return 'রায়ের অপেক্ষায়';
    }
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        plaintiffName,
        defendantName,
        isPlaintiff,
        complaint,
        state,
        response,
        verdict,
        myVote,
      ];
}

abstract class CourtRepository {
  Future<List<CourtCase>> fetchCases();

  Future<void> createCase({required String defendantId, required String complaint});

  Future<void> respond({required String caseId, required String? response});

  Future<void> vote({required String caseId, required bool guilty});
}
