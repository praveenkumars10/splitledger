import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/household_model.dart';
import '../auth/auth_controller.dart';
import 'household_repository.dart';

final currentHouseholdProvider = StreamProvider<Household?>((ref) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) {
    return Stream.value(null);
  }

  final repo = ref.watch(householdRepositoryProvider);
  return repo.watchUserHousehold(user.uid);
});
