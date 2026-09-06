import 'package:clash_party/common/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Fluent uses the documented Windows geometry and elevation values', () {
    const tokens = AppStyleTokens.fluent;

    expect(tokens.cardRadius, 4);
    expect(tokens.controlRadius, 4);
    expect(tokens.controlRadiusSmall, 2);
    expect(tokens.selectionIndicatorWidth, 3);
    expect(tokens.dividerColor, const Color(0x15FFFFFF));
    expect(tokens.dividerColorLight, const Color(0x0F000000));
    expect(tokens.cardShadow, [
      const BoxShadow(color: Color(0x3D000000), blurRadius: 2),
      const BoxShadow(
        color: Color(0x47000000),
        blurRadius: 8,
        offset: Offset(0, 4),
      ),
    ]);
    expect(tokens.cardShadowLight, [
      const BoxShadow(color: Color(0x1F000000), blurRadius: 2),
      const BoxShadow(
        color: Color(0x24000000),
        blurRadius: 8,
        offset: Offset(0, 4),
      ),
    ]);
  });

  test('iOS uses the Cupertino grouped-list geometry and separators', () {
    const tokens = AppStyleTokens.cupertino;

    expect(tokens.cardRadius, 10);
    expect(tokens.controlRadius, 9);
    expect(tokens.controlRadiusSmall, 7);
    expect(tokens.dividerColor, const Color(0x99545458));
    expect(tokens.dividerColorLight, const Color(0x493C3C43));
    expect(tokens.cardShadow, isEmpty);
    expect(tokens.cardShadowLight, isEmpty);
  });

  test('Clash Party tokens remain unchanged', () {
    const tokens = AppStyleTokens.clashParty;

    expect(tokens.cardRadius, 14);
    expect(tokens.controlRadius, 12);
    expect(tokens.dividerOpacity, 0.15);
    expect(tokens.seed, const Color(0xFF006FEE));
    expect(tokens.cardShadow, hasLength(2));
  });
}
