/// Central policy for excluding local caches and credentials from GitHub uploads.
class GitHubUploadPolicy {
  GitHubUploadPolicy._();

  static const excludedDirectories = <String>{
    '.git',
    'build',
    '.dart_tool',
    '.gradle',
    '.idea',
    '.ssh',
    '.aws',
    '.azure',
  };

  static const excludedFiles = <String>{
    'local.properties',
    'key.properties',
    '.env',
    '.netrc',
    '.npmrc',
    '.pypirc',
    'credentials',
    'credentials.json',
    'secrets.json',
  };

  static const sensitiveExtensions = <String>{
    '.jks',
    '.keystore',
    '.pem',
    '.p12',
    '.pfx',
    '.key',
    '.p8',
    '.mobileprovision',
  };

  static bool shouldExcludeDirectory(String name) =>
      excludedDirectories.contains(name.toLowerCase());

  static bool shouldExcludeFile(String name) {
    final lower = name.toLowerCase();
    if (excludedFiles.contains(lower)) return true;
    // Keep safe templates while excluding environment-specific secrets.
    if (lower.startsWith('.env.') &&
        lower != '.env.example' && lower != '.env.sample') {
      return true;
    }
    return sensitiveExtensions.any((extension) => lower.endsWith(extension));
  }
}
