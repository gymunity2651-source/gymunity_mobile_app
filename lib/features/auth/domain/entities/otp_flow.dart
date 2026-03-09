import 'package:supabase_flutter/supabase_flutter.dart';

enum OtpFlowMode { signup, recovery }

extension OtpFlowModeX on OtpFlowMode {
  OtpType get otpType {
    switch (this) {
      case OtpFlowMode.signup:
        return OtpType.signup;
      case OtpFlowMode.recovery:
        return OtpType.recovery;
    }
  }
}

class OtpFlowArgs {
  const OtpFlowArgs({required this.email, this.mode = OtpFlowMode.signup});

  final String email;
  final OtpFlowMode mode;
}
