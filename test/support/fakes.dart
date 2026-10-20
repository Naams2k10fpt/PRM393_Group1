import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_management_mobile/data/api/api_client.dart';
import 'package:quiz_management_mobile/data/api/token_storage.dart';
import 'package:quiz_management_mobile/data/api/api_exception.dart';
import 'package:quiz_management_mobile/data/models/app_user.dart';
import 'package:quiz_management_mobile/data/models/deck.dart';
import 'package:quiz_management_mobile/data/models/flashcard.dart';
import 'package:quiz_management_mobile/data/models/subject.dart';
import 'package:quiz_management_mobile/data/repositories/auth_repository.dart';
import 'package:quiz_management_mobile/data/repositories/catalog_repository.dart';
import 'package:quiz_management_mobile/data/repositories/flashcard_repository.dart';
import 'package:quiz_management_mobile/data/repositories/groups_repository.dart';
import 'package:quiz_management_mobile/data/repositories/profile_repository.dart';
import 'package:quiz_management_mobile/data/repositories/quiz_repository.dart';
import 'package:quiz_management_mobile/features/auth/auth_controller.dart';
import 'package:quiz_management_mobile/main.dart';

const demoUser = AppUser(
  id: 'u1',
  username: 'user_demo',
  email: 'user.demo@quiz.local',
  role: 'User',
);
const demoPassword = 'Test@123456';

const unauthorized = ApiException(
  code: 'unauthorized',
  message: 'Bạn cần đăng nhập.',
  statusCode: 401,
);
const offline = ApiException(
  code: ApiException.networkError,
  message: 'Không kết nối được máy chủ.',
);

/// In-memory stand-in for the backend's /api/auth endpoints.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.token});

  String? token;
  ApiException? loginError;
  ApiException? registerError;
  final calls = <String>[];

  @override
  Future<AppUser> login(String email, String password) async {
    calls.add('login:${email.trim()}');
    if (loginError != null) throw loginError!;
    if (email.trim() != demoUser.email || password != demoPassword) {
      throw const ApiException(
        code: 'invalid_credentials',
        message: 'Email hoặc mật khẩu không đúng.',
        statusCode: 401,
      );
    }
    token = 'token';
    return demoUser;
  }

  @override
  Future<String> register({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    calls.add('register:$username:$email');
    if (registerError != null) throw registerError!;
    return 'Đăng ký thành công. Vui lòng kiểm tra email để xác minh tài khoản.';
  }

  @override
  Future<String> resendVerification(String email) async {
    calls.add('resend:$email');
    return 'Nếu tài khoản tồn tại và chưa được xác minh, email mới đã được gửi.';
  }

  @override
  Future<String> forgotPassword(String email) async {
    calls.add('forgot:$email');
    return 'Nếu tài khoản hợp lệ, email đặt lại mật khẩu đã được gửi.';
  }

  @override
  Future<bool> hasToken() async => token != null;

  @override
  Future<void> logout() async => token = null;
}

/// In-memory stand-in for /api/profile.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository([this.user = demoUser]);

  AppUser user;
  ApiException? getError;
  ApiException? updateError;
  ApiException? changePasswordError;
  final calls = <String>[];

  @override
  Future<AppUser> getProfile() async {
    if (getError != null) throw getError!;
    return user;
  }

  @override
  Future<AppUser> updateProfile({
    required String username,
    String? avatarUrl,
  }) async {
    calls.add('update:$username:${avatarUrl ?? ''}');
    if (updateError != null) throw updateError!;
    return user = AppUser(
      id: user.id,
      username: username.trim(),
      email: user.email,
      role: user.role,
      avatarUrl: avatarUrl,
    );
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    calls.add('changePassword');
    if (changePasswordError != null) throw changePasswordError!;
  }
}

const demoSubjects = [
  Subject(id: '1', name: 'Lập trình di động', deckCount: 2, questionCount: 12),
  Subject(id: '2', name: 'Lập trình .NET', deckCount: 1, questionCount: 8),
];

const demoDecks = [
  Deck(
    id: '10',
    title: 'Flutter cơ bản',
    subjectId: '1',
    cardCount: 2,
    dueCount: 2,
  ),
  Deck(id: '11', title: 'State management', subjectId: '1', cardCount: 0),
];

const demoFlashcards = [
  Flashcard(
    questionId: '100',
    content: 'Widget trong Flutter là gì?',
    correctAnswers: ['Đơn vị dựng giao diện'],
    explanation: 'Mọi thứ hiển thị đều là widget.',
  ),
  Flashcard(
    questionId: '101',
    content: 'Hot reload làm gì?',
    correctAnswers: ['Nạp lại code mà không mất trạng thái'],
  ),
];

/// In-memory stand-in for /api/subjects and /api/decks.
class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository({
    this.subjectList = demoSubjects,
    this.deckList = demoDecks,
  });

  List<Subject> subjectList;
  List<Deck> deckList;
  ApiException? subjectsError;
  ApiException? decksError;
  final calls = <String>[];

  @override
  Future<List<Subject>> subjects() async {
    calls.add('subjects');
    if (subjectsError != null) throw subjectsError!;
    return subjectList;
  }

  @override
  Future<List<Deck>> decksOfSubject(String subjectId) async {
    calls.add('decks:$subjectId');
    if (decksError != null) throw decksError!;
    return deckList.where((deck) => deck.subjectId == subjectId).toList();
  }

  @override
  Future<Deck> deck(String deckId) async {
    calls.add('deck:$deckId');
    if (decksError != null) throw decksError!;
    return deckList.firstWhere(
      (deck) => deck.id == deckId,
      orElse:
          () =>
              throw const ApiException(
                code: 'deck_not_found',
                message: 'Không tìm thấy bộ đề.',
                statusCode: 404,
              ),
    );
  }
}

/// In-memory stand-in for the flashcard endpoints. [reviews] records every card
/// the screen sent, so a test can check one request went out per answer.
class FakeFlashcardRepository implements FlashcardRepository {
  FakeFlashcardRepository({this.cards = demoFlashcards, this.totalCards});

  List<Flashcard> cards;

  /// Cards in the whole deck; defaults to [cards]. Set it higher than the due
  /// list to exercise the "ôn trước cả bộ" path.
  int? totalCards;

  ApiException? loadError;
  ApiException? reviewError;
  final reviews = <({String questionId, bool remembered})>[];
  final calls = <String>[];

  @override
  Future<FlashcardSession> session(
    String deckId, {
    bool studyAll = false,
  }) async {
    calls.add('session:$deckId:${studyAll ? 'all' : 'due'}');
    if (loadError != null) throw loadError!;
    return FlashcardSession(
      deckId: deckId,
      deckName: 'Flutter cơ bản',
      totalCards: totalCards ?? cards.length,
      dueCards: cards.length,
      studyingAll: studyAll,
      cards: studyAll ? cards : cards,
    );
  }

  @override
  Future<FlashcardReview> review({
    required String deckId,
    required String questionId,
    required bool remembered,
  }) async {
    calls.add('review:$questionId:$remembered');
    if (reviewError != null) throw reviewError!;
    reviews.add((questionId: questionId, remembered: remembered));
    return FlashcardReview(
      questionId: questionId,
      repetition: 1,
      intervalMinutes: 10,
    );
  }
}

/// Boots the real app (router, providers, screens) on fake repositories.
class TestApp {
  TestApp({
    String? token,
    FakeProfileRepository? profile,
    FakeCatalogRepository? catalog,
    FakeFlashcardRepository? flashcards,
    QuizRepository? quiz,
    GroupsRepository? groups,
  }) : authRepository = FakeAuthRepository(token: token),
       profileRepository = profile ?? FakeProfileRepository(),
       catalogRepository = catalog ?? FakeCatalogRepository(),
       flashcardRepository = flashcards ?? FakeFlashcardRepository(),
       quizRepository =
           quiz ?? QuizRepository(ApiClient(tokens: InMemoryTokenStorage())),
       groupsRepository =
           groups ??
           GroupsRepository(ApiClient(tokens: InMemoryTokenStorage())) {
    auth = AuthController(authRepository, profileRepository);
  }

  final FakeAuthRepository authRepository;
  final FakeProfileRepository profileRepository;
  final FakeCatalogRepository catalogRepository;
  final FakeFlashcardRepository flashcardRepository;
  final QuizRepository quizRepository;
  final GroupsRepository groupsRepository;
  late final AuthController auth;

  Future<void> start(WidgetTester tester) async {
    // A phone-sized screen, so layout problems show up as they would on a device.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      QuizManagementApp(
        auth: auth,
        authRepository: authRepository,
        profileRepository: profileRepository,
        catalogRepository: catalogRepository,
        flashcardRepository: flashcardRepository,
        quizRepository: quizRepository,
        groupsRepository: groupsRepository,
      ),
    );
    await auth.restoreSession();
    await tester.pumpAndSettle();
  }
}
