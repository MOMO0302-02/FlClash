import 'package:clash_party/common/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';

/// 空状态。
///
/// 除了图和一行标题，还可以给一句说明和一个下一步动作——空状态是「邀请用户做
/// 下一件事」的地方，只写「暂无数据」等于把人晾在那儿。
/// [description] 与 [action] 都是可选的，老的调用点不用改。
class NullStatus extends StatelessWidget {
  final String label;
  final String? description;
  final Widget? action;
  final Widget illustration;

  const NullStatus({
    super.key,
    required this.label,
    this.description,
    this.action,
    this.illustration = const DataEmptyIllustration(),
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Align(
      alignment: const Alignment(0.0, -0.25),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            illustration,
            const SizedBox(height: 16),
            Text(label, style: textTheme.titleMedium?.toBold.toLight),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class LogEmptyIllustration extends StatelessWidget {
  const LogEmptyIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: context.colorScheme.primaryContainer,
        shape: const StarBorder(
          points: 5,
          innerRadiusRatio: 0.8,
          pointRounding: 0.7,
          valleyRounding: 0.1,
          squash: 0.5,
        ),
      ),
      child: const _ThemeAwareSvg('assets/images/empty/log.svg'),
    );
  }
}

class ProxyEmptyIllustration extends StatelessWidget {
  const ProxyEmptyIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: context.colorScheme.secondaryContainer,
        shape: const StarBorder(
          points: 12,
          innerRadiusRatio: 0.8,
          pointRounding: 0.5,
          valleyRounding: 0.4,
          squash: 0.6,
        ),
      ),
      child: const _ThemeAwareSvg('assets/images/empty/proxy.svg'),
    );
  }
}

class DataEmptyIllustration extends StatelessWidget {
  const DataEmptyIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: context.colorScheme.secondaryContainer,
        shape: const StarBorder(
          points: 3,
          innerRadiusRatio: 1,
          pointRounding: 0.3,
          valleyRounding: 0.5,
          squash: 0.2,
        ),
      ),
      child: const _ThemeAwareSvg('assets/images/empty/data.svg'),
    );
  }
}

class ProfileEmptyIllustration extends StatelessWidget {
  const ProfileEmptyIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: context.colorScheme.secondaryContainer,
        shape: const StarBorder(
          points: 8,
          innerRadiusRatio: 0.6,
          pointRounding: 1,
          valleyRounding: 0,
          squash: 1,
        ),
      ),
      child: const _ThemeAwareSvg('assets/images/empty/profile.svg'),
    );
  }
}

class ScriptEmptyIllustration extends StatelessWidget {
  const ScriptEmptyIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: context.colorScheme.secondaryContainer,
        shape: const StarBorder(
          points: 3,
          innerRadiusRatio: 0.6,
          pointRounding: 0.6,
          valleyRounding: 0.2,
          squash: 0.1,
        ),
      ),
      child: const _ThemeAwareSvg('assets/images/empty/script.svg'),
    );
  }
}

class RuleEmptyIllustration extends StatelessWidget {
  const RuleEmptyIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: context.colorScheme.secondaryContainer,
        shape: const StarBorder(
          points: 7,
          innerRadiusRatio: 0.3,
          pointRounding: 0.9,
          valleyRounding: 0.1,
          squash: 0,
        ),
      ),
      child: const _ThemeAwareSvg('assets/images/empty/rule.svg'),
    );
  }
}

class ConnectionEmptyIllustration extends StatelessWidget {
  const ConnectionEmptyIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: context.colorScheme.secondaryContainer,
        shape: const StarBorder(
          points: 4,
          innerRadiusRatio: 0.1,
          pointRounding: 1,
          valleyRounding: 0,
          squash: 1,
          rotation: 45,
        ),
      ),
      child: const _ThemeAwareSvg('assets/images/empty/connection.svg'),
    );
  }
}

class _ThemeAwareSvg extends StatelessWidget {
  final String assetPath;

  const _ThemeAwareSvg(this.assetPath);

  String _colorToHex(Color color) {
    return color.toARGB32().toRadixString(16).substring(2);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return FutureBuilder<String>(
      future: rootBundle.loadString(assetPath),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          String svgString = snapshot.data!;
          svgString = svgString.replaceAll(
            '#E8DEF8',
            '#${_colorToHex(colorScheme.secondaryContainer)}',
          );
          // 插图里的强调色。`#6750A4` 是 Material 的基线紫，留着就等于把
          // Material 的默认配色画进了空状态；换成本主题的强调色。
          svgString = svgString.replaceAll(
            '#6750A4',
            '#${_colorToHex(context.styleTokens.accent(colorScheme))}',
          );
          // surface ??
          svgString = svgString.replaceAll(
            '#FDF7FF',
            '#${_colorToHex(colorScheme.surface)}',
          );
          svgString = svgString.replaceAll(
            '#C4C7C5',
            '#${_colorToHex(colorScheme.outlineVariant)}',
          );
          return SvgPicture.string(svgString, width: 200, height: 200);
        } else if (snapshot.hasError) {
          return const Icon(Icons.error);
        }
        return const SizedBox(width: 200, height: 200);
      },
    );
  }
}
