import 'package:flutter/material.dart';

/// Shared visual language for the FinAI screens; no business or network state.
abstract final class FinaiColors {
  static const blue = Color(0xFF0F766E);
  static const violet = Color(0xFF0F766E);
  static const teal = Color(0xFF14B8A6);
  static const amber = Color(0xFF965A0A);
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF115E59), Color(0xFF0F766E), Color(0xFF134E4A)],
  );
  static bool dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color surface(BuildContext context) =>
      dark(context) ? const Color(0xFF0F172A) : Colors.white;
  static Color muted(BuildContext context) =>
      dark(context) ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  static ThemeData theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: blue, brightness: brightness)
        .copyWith(
          primary: isDark ? const Color(0xFF14B8A6) : blue,
          onPrimary: isDark ? const Color(0xFF042F2E) : Colors.white,
          outlineVariant: isDark
              ? const Color(0xFF1E293B)
              : const Color(0xFFE2E8F0),
          secondary: isDark ? const Color(0xFF80D3D6) : teal,
          surface: isDark ? const Color(0xFF0F172A) : Colors.white,
          onSurface: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
        );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    return base.copyWith(
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF090D16)
          : const Color(0xFFF8FAFC),
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.5),
        bodySmall: base.textTheme.bodySmall?.copyWith(height: 1.45),
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surface,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        height: 76,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.55),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class FinaiMark extends StatelessWidget {
  const FinaiMark({super.key, this.size = 44});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: FinaiColors.gradient,
      borderRadius: BorderRadius.circular(size * .3),
    ),
    child: Icon(
      Icons.auto_graph_rounded,
      color: Colors.white,
      size: size * .58,
    ),
  );
}

class FinaiPanel extends StatelessWidget {
  const FinaiPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: FinaiColors.surface(context),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: Theme.of(context).colorScheme.outlineVariant
            .withValues(alpha: .45),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: FinaiColors.dark(context) ? .08 : .025,
          ),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}

class FinaiHeading extends StatelessWidget {
  const FinaiHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.auto_awesome_rounded,
  });
  final String title, subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(subtitle, style: TextStyle(color: FinaiColors.muted(context))),
      ],
    ),
  );
}

class FinaiHero extends StatelessWidget {
  const FinaiHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow = 'FINAI • DỮ LIỆU & GÓC NHÌN',
    this.action,
  });
  final String title, subtitle, eyebrow;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: FinaiColors.gradient,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFB5F0E4),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                eyebrow,
                style: const TextStyle(
                  color: Color(0xFFDDE5FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFFE0E7FF), height: 1.6),
        ),
        if (action != null) ...[const SizedBox(height: 18), action!],
      ],
    ),
  );
}

class FinaiNotice extends StatelessWidget {
  const FinaiNotice(
    this.message, {
    super.key,
    this.warning = false,
    this.error = false,
  });
  final String message;
  final bool warning, error;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = error
        ? scheme.error
        : warning
        ? (FinaiColors.dark(context)
              ? const Color(0xFFF4C477)
              : FinaiColors.amber)
        : scheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error
                ? Icons.error_outline_rounded
                : warning
                ? Icons.info_outline_rounded
                : Icons.lightbulb_outline_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: color, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class FinaiSection extends StatelessWidget {
  const FinaiSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.step,
  });
  final String title;
  final String? subtitle, step;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: FinaiPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (step != null) ...[
                CircleAvatar(
                  radius: 15,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  child: Text(
                    step!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(color: FinaiColors.muted(context)),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

class FinaiMetrics extends StatelessWidget {
  const FinaiMetrics({super.key, required this.values});
  final Map<String, String> values;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 520 ? 4 : 2;
      final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: values.entries
            .map(
              (entry) => SizedBox(
                width: width,
                child: FinaiPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        entry.value,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.key,
                        style: TextStyle(color: FinaiColors.muted(context)),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class FinaiMono extends StatelessWidget {
  const FinaiMono(this.text, {super.key, this.technical = false});
  final String text;
  final bool technical;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: technical
          ? const Color(0xFF111C32)
          : Theme.of(context).colorScheme.primary.withValues(alpha: .04),
      borderRadius: BorderRadius.circular(10),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SelectableText(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.7,
          color: technical ? const Color(0xFFDDE7FF) : null,
        ),
      ),
    ),
  );
}
