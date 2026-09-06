import 'dart:io';

import 'package:clash_party/common/common.dart';
import 'package:clash_party/enum/enum.dart';
import 'package:clash_party/models/models.dart';
import 'package:clash_party/providers/action.dart';
import 'package:clash_party/providers/app.dart';
import 'package:clash_party/providers/config.dart';
import 'package:clash_party/state.dart';
import 'package:clash_party/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' hide context;

class ResourcesView extends StatelessWidget {
  const ResourcesView({super.key});

  @override
  Widget build(BuildContext context) {
    const geoResources = GeoResource.values;
    final appLocalizations = context.appLocalizations;
    return CommonScaffold(
      title: context.appLocalizations.resources,
      body: Consumer(
        builder: (_, ref, _) {
          final vm2 = ref.watch(
            patchClashConfigProvider.select(
              (state) => VM2(state.geoAutoUpdate, state.geoUpdateInterval),
            ),
          );
          return generateListView([
            ...generateSection(
              isFirst: true,
              title: appLocalizations.geoOptions,
              items: [
                ListItem.toggle(
                  title: Text(appLocalizations.geoAutoUpdate),
                  value: vm2.a,
                  onChanged: (value) {
                    ref
                        .read(patchClashConfigProvider.notifier)
                        .update(
                          (state) => state.copyWith(geoAutoUpdate: value),
                        );
                  },
                ),
                ListItem.input(
                  title: Text(appLocalizations.geoAutoUpdateInterval),
                  trailing: Text(
                    appLocalizations.hoursCount(vm2.b),
                    style: context.textTheme.bodyMedium?.toSoftBold,
                  ),
                  suffixText: appLocalizations.hours,
                  dialogTitle: appLocalizations.geoAutoUpdateInterval,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return appLocalizations.emptyTip(
                        appLocalizations.geoAutoUpdateInterval,
                      );
                    }
                    final interval = int.tryParse(value);
                    if (interval == null) {
                      return appLocalizations.numberTip(
                        appLocalizations.geoAutoUpdateInterval,
                      );
                    }
                    if (interval <= 0) {
                      return appLocalizations.geoAutoUpdateIntervalTip;
                    }
                    return null;
                  },
                  value: vm2.b.toString(),
                  onChanged: (value) {
                    final intValue = int.tryParse(value ?? '') ?? 0;
                    if (intValue <= 0) {
                      return;
                    }
                    ref
                        .read(patchClashConfigProvider.notifier)
                        .update(
                          (state) =>
                              state.copyWith(geoUpdateInterval: intValue),
                        );
                  },
                ),
              ],
            ),
            ...generateSection(
              title: appLocalizations.geoResources,
              items: [
                for (final geoResource in geoResources)
                  _GeoResourceListItem(geoResource),
              ],
            ),
          ]);
        },
      ),
    );
  }
}

class _GeoResourceListItem extends ConsumerStatefulWidget {
  final GeoResource type;

  const _GeoResourceListItem(this.type);

  @override
  ConsumerState<_GeoResourceListItem> createState() =>
      _GeoResourceListItemState();
}

class _GeoResourceListItemState extends ConsumerState<_GeoResourceListItem> {
  String get fileName {
    return switch (widget.type) {
      GeoResource.MMDB => MMDB,
      GeoResource.ASN => ASN,
      GeoResource.GEOIP => GEOIP,
      GeoResource.GEOSITE => GEOSITE,
    };
  }

  Future<void> _updateUrl(String url) async {
    final newUrl = await globalState.showCommonDialog<String>(
      child: UpdateGeoUrlFormDialog(
        title: widget.type.name,
        url: url,
        defaultValue: defaultGeoXUrl[widget.type],
      ),
    );
    if (newUrl != null && newUrl != url && mounted) {
      try {
        ref
            .read(geoResourceActionProvider.notifier)
            .updateGeoResourceUrl(widget.type, newUrl);
      } catch (e) {
        globalState.showMessage(
          title: widget.type.name,
          message: TextSpan(text: e.toString()),
        );
      }
    }
  }

  Future<FileInfo?> _getGeoFileInfo(String fileName) async {
    final homePath = await appPath.homeDirPath;
    final file = File(join(homePath, fileName));
    return file.getFileInfo();
  }

  Future<void> _handleUpdateGeoDataItem() async {
    await globalState.safeRun<void>(() async {
      await ref
          .read(geoResourceActionProvider.notifier)
          .updateGeoResource(widget.type);
    }, silence: false);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final isUpdating = ref.watch(isUpdatingProvider(widget.type.updatingKey));
    final url = ref.watch(
      patchClashConfigProvider.select((state) => state.geoXUrl[widget.type]),
    );
    return ListItem(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(widget.type.name),
      subtitle: url == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                FutureBuilder<FileInfo?>(
                  future: _getGeoFileInfo(fileName),
                  builder: (_, snapshot) {
                    final height = globalState.measure.bodyMediumHeight;
                    return SizedBox(
                      height: height,
                      // 还在查就留个占位方块；查完确实没有这个文件就直说
                      // 「未下载」。GEOIP.dat 不再随包携带之后，这一格对大多数
                      // 用户是常态——留一行空白会让人以为界面坏了。
                      child: switch (snapshot.connectionState) {
                        ConnectionState.done => Text(
                          snapshot.data?.getDesc(context) ??
                              appLocalizations.geoResourceNotDownloaded,
                          style: context.textTheme.bodyMedium,
                        ),
                        _ => SizedBox(width: height, height: height),
                      },
                    );
                  },
                ),
                const SizedBox(height: 2),
                Text(
                  url,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
      // 原来是两个 Material 的 ActionChip 塞在副标题里，那是安卓原生的样子；
      // 桌面端资源页的「编辑 / 更新」是行尾的两个图标按钮，改成一致的形态。
      trailing: url == null
          ? null
          : CommonMinIconButtonTheme(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: appLocalizations.edit,
                    onPressed: () {
                      _updateUrl(url);
                    },
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  // 更新中把按钮换成同尺寸的转圈，避免行宽跳动。两者之间淡入淡出
                  // （和订阅卡片上的更新按钮同一种处理）：硬切会让人怀疑自己是不是
                  // 点错了别的东西，渐变过去才看得出「就是刚点的那个开始转了」。
                  SizedBox.square(
                    dimension: 36,
                    child: FadeThroughBox(
                      alignment: Alignment.center,
                      child: isUpdating
                          ? const Padding(
                              key: ValueKey('loading'),
                              padding: EdgeInsets.all(8),
                              child: HeroSpinner(),
                            )
                          : IconButton(
                              key: const ValueKey('sync'),
                              tooltip: appLocalizations.sync,
                              onPressed: () {
                                _handleUpdateGeoDataItem();
                              },
                              icon: const Icon(Icons.sync),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class UpdateGeoUrlFormDialog extends StatelessWidget {
  final String title;
  final String url;
  final String? defaultValue;

  const UpdateGeoUrlFormDialog({
    super.key,
    required this.title,
    required this.url,
    this.defaultValue,
  });

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return InputDialog(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      title: title,
      value: url,
      resetValue: defaultValue,
      inputFormatters: TextInputLimits.limit(TextInputLimits.url),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return appLocalizations.emptyTip('').trim();
        }
        if (!value.isUrl) {
          return appLocalizations.urlTip('').trim();
        }
        return null;
      },
    );
  }
}
