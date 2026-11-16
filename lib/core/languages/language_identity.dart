import 'package:flutter/material.dart';

/// Central identity for supported languages. Uses local vector/text marks so
/// language branding is available offline and never depends on remote images.
class LanguageIdentity {
  final String name;
  final String mark;
  final Color color;
  final IconData icon;
  final String family;

  const LanguageIdentity({
    required this.name,
    required this.mark,
    required this.color,
    required this.icon,
    required this.family,
  });

  static const List<LanguageIdentity> all = [
    LanguageIdentity(name: 'Flutter', mark: 'F', color: Color(0xFF42A5F5), icon: Icons.phone_android_rounded, family: 'Mobile'),
    LanguageIdentity(name: 'Dart', mark: 'D', color: Color(0xFF0175C2), icon: Icons.code_rounded, family: 'Language'),
    LanguageIdentity(name: 'Python', mark: 'Py', color: Color(0xFF3776AB), icon: Icons.terminal_rounded, family: 'Language'),
    LanguageIdentity(name: 'JavaScript', mark: 'JS', color: Color(0xFFF7DF1E), icon: Icons.javascript, family: 'Web'),
    LanguageIdentity(name: 'TypeScript', mark: 'TS', color: Color(0xFF3178C6), icon: Icons.data_object_rounded, family: 'Web'),
    LanguageIdentity(name: 'Java', mark: 'J', color: Color(0xFFED8B00), icon: Icons.code_rounded, family: 'JVM'),
    LanguageIdentity(name: 'Kotlin', mark: 'K', color: Color(0xFF7F52FF), icon: Icons.android_rounded, family: 'Android'),
    LanguageIdentity(name: 'Swift', mark: 'Sw', color: Color(0xFFF05138), icon: Icons.phone_iphone_rounded, family: 'Apple'),
    LanguageIdentity(name: 'C', mark: 'C', color: Color(0xFF659AD2), icon: Icons.memory_rounded, family: 'Native'),
    LanguageIdentity(name: 'C++', mark: 'C++', color: Color(0xFF00599C), icon: Icons.memory_rounded, family: 'Native'),
    LanguageIdentity(name: 'HTML', mark: '5', color: Color(0xFFE34F26), icon: Icons.web_rounded, family: 'Web'),
    LanguageIdentity(name: 'CSS', mark: '#', color: Color(0xFF1572B6), icon: Icons.web_rounded, family: 'Web'),
    LanguageIdentity(name: 'JSON', mark: '{}', color: Color(0xFF8BC34A), icon: Icons.data_object_rounded, family: 'Data'),
    LanguageIdentity(name: 'SQL', mark: 'SQL', color: Color(0xFFCC792A), icon: Icons.storage_rounded, family: 'Data'),
    LanguageIdentity(name: 'Bash', mark: '>_', color: Color(0xFF4EAA25), icon: Icons.terminal_rounded, family: 'Shell'),
    LanguageIdentity(name: 'Go', mark: 'Go', color: Color(0xFF00ADD8), icon: Icons.code_rounded, family: 'Language'),
    LanguageIdentity(name: 'Rust', mark: 'Rs', color: Color(0xFFDEA584), icon: Icons.settings_rounded, family: 'Language'),
    LanguageIdentity(name: 'PHP', mark: 'php', color: Color(0xFF777BB4), icon: Icons.code_rounded, family: 'Web'),
    LanguageIdentity(name: 'C#', mark: 'C#', color: Color(0xFF68217A), icon: Icons.code_rounded, family: '.NET'),
    LanguageIdentity(name: 'Ruby', mark: 'Rb', color: Color(0xFFCC342D), icon: Icons.diamond_outlined, family: 'Language'),
    LanguageIdentity(name: 'XML', mark: 'XML', color: Color(0xFF0060AC), icon: Icons.account_tree_rounded, family: 'Data'),
    LanguageIdentity(name: 'YAML', mark: 'YML', color: Color(0xFFCB171E), icon: Icons.data_object_rounded, family: 'Data'),
    LanguageIdentity(name: 'Markdown', mark: 'MD', color: Color(0xFF083FA1), icon: Icons.description_rounded, family: 'Documentation'),
    LanguageIdentity(name: 'TOML', mark: 'TOML', color: Color(0xFF9C4221), icon: Icons.tune_rounded, family: 'Configuration'),
    LanguageIdentity(name: 'PowerShell', mark: 'PS', color: Color(0xFF5391FE), icon: Icons.terminal_rounded, family: 'Shell'),
    LanguageIdentity(name: 'Lua', mark: 'Lua', color: Color(0xFF000080), icon: Icons.code_rounded, family: 'Language'),
    LanguageIdentity(name: 'R', mark: 'R', color: Color(0xFF276DC3), icon: Icons.query_stats_rounded, family: 'Data'),
    LanguageIdentity(name: 'GraphQL', mark: 'GQL', color: Color(0xFFE10098), icon: Icons.schema_rounded, family: 'API'),
    LanguageIdentity(name: 'Dockerfile', mark: 'DK', color: Color(0xFF2496ED), icon: Icons.inventory_2_rounded, family: 'DevOps'),
    LanguageIdentity(name: 'Makefile', mark: 'MK', color: Color(0xFF6D8086), icon: Icons.build_rounded, family: 'Build'),
    LanguageIdentity(name: 'SVG', mark: 'SVG', color: Color(0xFFFFB13B), icon: Icons.image_outlined, family: 'Web'),
    LanguageIdentity(name: 'Plain Text', mark: 'TXT', color: Color(0xFF94A3B8), icon: Icons.text_snippet_outlined, family: 'Text'),
    LanguageIdentity(name: 'Objective-C', mark: 'ObjC', color: Color(0xFF438EFF), icon: Icons.memory_rounded, family: 'Native'),
    LanguageIdentity(name: 'Scala', mark: 'Sc', color: Color(0xFFDC322F), icon: Icons.code_rounded, family: 'JVM'),
    LanguageIdentity(name: 'Groovy', mark: 'Gr', color: Color(0xFF4298B8), icon: Icons.code_rounded, family: 'JVM'),
    LanguageIdentity(name: 'Perl', mark: 'Pl', color: Color(0xFF39457E), icon: Icons.terminal_rounded, family: 'Language'),
    LanguageIdentity(name: 'Haskell', mark: 'Hs', color: Color(0xFF5E5086), icon: Icons.code_rounded, family: 'Language'),
    LanguageIdentity(name: 'Elixir', mark: 'Ex', color: Color(0xFF6E4A7E), icon: Icons.code_rounded, family: 'Language'),
    LanguageIdentity(name: 'Erlang', mark: 'Er', color: Color(0xFFA90533), icon: Icons.code_rounded, family: 'Language'),
    LanguageIdentity(name: 'Julia', mark: 'Jl', color: Color(0xFF9558B2), icon: Icons.query_stats_rounded, family: 'Data'),
    LanguageIdentity(name: 'Clojure', mark: 'Clj', color: Color(0xFF5881D8), icon: Icons.code_rounded, family: 'Language'),
    LanguageIdentity(name: 'Assembly', mark: 'ASM', color: Color(0xFF6B7280), icon: Icons.memory_rounded, family: 'Native'),
    LanguageIdentity(name: 'Terraform', mark: 'TF', color: Color(0xFF7B42BC), icon: Icons.cloud_outlined, family: 'DevOps'),
    LanguageIdentity(name: 'Other', mark: '·', color: Color(0xFF64748B), icon: Icons.insert_drive_file_rounded, family: 'Other'),
  ];

  /// Resolve a language from a file name, including common compound names.
  /// This catalog is shared by the explorer, editor tabs and project wizard.
  static LanguageIdentity fromFileName(String fileName) {
    final name = fileName.split('/').last.toLowerCase();
    const specialNames = <String, String>{
      'dockerfile': 'Dockerfile',
      'makefile': 'Makefile',
      'gemfile': 'Ruby',
      'rakefile': 'Ruby',
      'gradlew': 'Bash',
      'gradlew.bat': 'PowerShell',
      'cmakelists.txt': 'Other',
      '.gitignore': 'Other',
      '.env': 'Other',
    };
    final special = specialNames[name];
    if (special != null) return of(special);
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return of('Other');
    final extension = name.substring(dot + 1);
    const extensions = <String, String>{
      'dart': 'Dart', 'py': 'Python', 'pyw': 'Python', 'ipynb': 'Python',
      'java': 'Java', 'kt': 'Kotlin', 'kts': 'Kotlin', 'gradle': 'Kotlin', 'properties': 'Other',
      'swift': 'Swift', 'm': 'Objective-C', 'mm': 'Objective-C',
      'c': 'C', 'h': 'C', 'cc': 'C++',
      'cpp': 'C++', 'cxx': 'C++', 'hpp': 'C++', 'hh': 'C++',
      'cs': 'C#', 'js': 'JavaScript', 'mjs': 'JavaScript',
      'cjs': 'JavaScript', 'jsx': 'JavaScript',
      'ts': 'TypeScript', 'tsx': 'TypeScript', 'mts': 'TypeScript', 'cts': 'TypeScript',
      'html': 'HTML', 'htm': 'HTML', 'css': 'CSS', 'scss': 'CSS', 'sass': 'CSS',
      'less': 'CSS', 'php': 'PHP', 'phtml': 'PHP',
      'go': 'Go', 'rs': 'Rust', 'rb': 'Ruby',
      'sql': 'SQL', 'json': 'JSON', 'jsonc': 'JSON',
      'xml': 'XML', 'svg': 'SVG', 'yaml': 'YAML', 'yml': 'YAML',
      'sh': 'Bash', 'bash': 'Bash', 'zsh': 'Bash', 'fish': 'Bash',
      'ps1': 'PowerShell', 'psm1': 'PowerShell',
      'md': 'Markdown', 'markdown': 'Markdown',
      'toml': 'TOML', 'lua': 'Lua', 'r': 'R', 'txt': 'Plain Text', 'log': 'Plain Text', 'ini': 'TOML', 'cfg': 'TOML',
      'graphql': 'GraphQL', 'gql': 'GraphQL', 'proto': 'Other', 'vue': 'HTML', 'svelte': 'HTML',
      'scala': 'Scala', 'sc': 'Scala', 'groovy': 'Groovy',
      'pl': 'Perl', 'pm': 'Perl', 'hs': 'Haskell', 'lhs': 'Haskell',
      'ex': 'Elixir', 'exs': 'Elixir', 'erl': 'Erlang', 'hrl': 'Erlang',
      'jl': 'Julia', 'clj': 'Clojure', 'cljs': 'Clojure', 'cljc': 'Clojure',
      'asm': 'Assembly', 's': 'Assembly', 'tf': 'Terraform', 'tfvars': 'Terraform',
      'bat': 'PowerShell', 'cmd': 'PowerShell',
    };
    return of(extensions[extension] ?? 'Other');
  }


  static LanguageIdentity of(String name) => all.firstWhere(
    (item) => item.name.toLowerCase() == name.toLowerCase(),
    orElse: () => LanguageIdentity(
      name: name, mark: name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
      color: const Color(0xFF64748B), icon: Icons.code_rounded, family: 'Other',
    ),
  );
}

class LanguageBrandBadge extends StatelessWidget {
  final String language;
  final double size;
  const LanguageBrandBadge({super.key, required this.language, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final identity = LanguageIdentity.of(language);
    return Container(
      width: size, height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: identity.color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(size * .28),
        border: Border.all(color: identity.color.withValues(alpha: .55)),
      ),
      child: Text(
        identity.mark,
        maxLines: 1,
        style: TextStyle(
          color: identity.color,
          fontWeight: FontWeight.w900,
          fontSize: size * (identity.mark.length > 2 ? .27 : .38),
          letterSpacing: -.5,
        ),
      ),
    );
  }
}
