class ApiConfig {
  static const String baseUrl = 'https://apicafe.datorural.com/api/v1';
  static const String authDomain = 'https://asprounion.datorural.com';
  static const String login = '$baseUrl/auth/email/login';
  static const String refresh = '$baseUrl/auth/refresh';
  static const String forgotPassword = '$baseUrl/auth/forgot/password';
  static const String forms = '$baseUrl/forms';
  static const String userCompanies = '$baseUrl/user-companies';

  // Workspace ID (fijo para todos los módulos)
  static const String workspaceId = 'f1b07ede-296d-4d0c-9a93-5943197d618c';

  // IDs de cada módulo (Route Name)
  static const String fincaFormId = 'dyn-85f82ad2-5fb7-4792-b1bb-7787c1f06a45';
  static const String loteFormId = 'dyn-e979a531-b166-4987-bf2a-3ae0ae36f008';
  static const String actividadFormId =
      'dyn-65516e0f-4404-4cf6-a1a8-efc2cf24bce7';
  static const String insumoFormId = 'dyn-3eb183ec-21dd-490e-ab18-30f327be8e53';
  static const String cosechaFormId =
      'dyn-e11edce7-fb16-4a54-8f94-06299cceca58';

  // URLs base de cada módulo (para usar en los servicios)
  static String get fincaUrl => '$forms/$fincaFormId';
  static String get loteUrl => '$forms/$loteFormId';
  static String get actividadUrl => '$forms/$actividadFormId';
  static String get insumoUrl => '$forms/$insumoFormId';
  static String get cosechaUrl => '$forms/$cosechaFormId';
  static String get userCompaniesUrl => userCompanies;
  static String get userCompaniesByCompanyUrl => '$userCompanies/by-company';
  static String get completeUserUrl => '$userCompanies/complete-user';
  static String userCompanyByIdUrl(String id) => '$userCompanies/$id';
  static String updateCompleteUserUrl(String userId) =>
      '$userCompanies/update-complete/$userId';
}
