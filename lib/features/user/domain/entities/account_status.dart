enum AccountStatus {
  missing,
  active,
  inactive,
  deleted;

  bool get isAccessible =>
      this == AccountStatus.active || this == AccountStatus.missing;
  bool get isDeletedLike =>
      this == AccountStatus.inactive || this == AccountStatus.deleted;
}
