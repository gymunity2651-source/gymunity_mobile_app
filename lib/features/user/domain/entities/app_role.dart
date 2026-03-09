enum AppRole {
  member,
  coach,
  seller,
}

extension AppRoleX on AppRole {
  String get code {
    switch (this) {
      case AppRole.member:
        return 'member';
      case AppRole.coach:
        return 'coach';
      case AppRole.seller:
        return 'seller';
    }
  }

  int get roleId {
    switch (this) {
      case AppRole.member:
        return 1;
      case AppRole.coach:
        return 2;
      case AppRole.seller:
        return 3;
    }
  }
}

AppRole? appRoleFromCode(String? code) {
  switch (code) {
    case 'member':
      return AppRole.member;
    case 'coach':
      return AppRole.coach;
    case 'seller':
      return AppRole.seller;
    default:
      return null;
  }
}

AppRole? appRoleFromId(int? id) {
  switch (id) {
    case 1:
      return AppRole.member;
    case 2:
      return AppRole.coach;
    case 3:
      return AppRole.seller;
    default:
      return null;
  }
}

