import 'package:flutter/material.dart';
import 'service_holder.dart';
import 'layoutablelist/layoutable_list_widget.dart';
import 'layoutablelist/algorithms/grid_layout_algorithm.dart';
import 'layoutablelist/algorithms/flex_layout_algorithm.dart';
import 'layoutablelist/list_adapter.dart';
import 'layoutablelist/animator/item_animator.dart';
import 'layoutablelist/animator/item_animator_controller.dart';
import 'layoutablelist/animator/animation_widget.dart';
import 'layoutablelist/drag/drag_manager.dart';
import 'layoutablelist/drag/drop_target.dart';
import 'layoutablelist/drag/item_draggable.dart';

// ── 数据模型 ──────────────────────────────────────────────────────────────────

class _AppIcon {
  final int id;
  final String name;
  final IconData icon;
  final Color color;

  const _AppIcon({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

// ── 常量 ──────────────────────────────────────────────────────────────────────

const _gridColumns = 8;
const _dockMaxItems = 6;
const _dockHeight = 100.0;
const _dockIconSize = 64.0;

const _appIcons = [
  _AppIcon(id: 1,  name: 'Safari',   icon: Icons.language,        color: Color(0xFF007AFF)),
  _AppIcon(id: 2,  name: 'Mail',     icon: Icons.mail,            color: Color(0xFF007AFF)),
  _AppIcon(id: 3,  name: 'Photos',   icon: Icons.photo,           color: Color(0xFFFF9500)),
  _AppIcon(id: 4,  name: 'Camera',   icon: Icons.camera_alt,      color: Color(0xFF34C759)),
  _AppIcon(id: 5,  name: 'Maps',     icon: Icons.map,             color: Color(0xFF34C759)),
  _AppIcon(id: 6,  name: 'Music',    icon: Icons.music_note,      color: Color(0xFFFF2D55)),
  _AppIcon(id: 7,  name: 'Notes',    icon: Icons.note,            color: Color(0xFFFFCC00)),
  _AppIcon(id: 8,  name: 'Calendar', icon: Icons.calendar_today,  color: Color(0xFFFF3B30)),
  _AppIcon(id: 9,  name: 'Clock',    icon: Icons.access_time,     color: Color(0xFF1C1C1E)),
  _AppIcon(id: 10, name: 'Settings', icon: Icons.settings,        color: Color(0xFF8E8E93)),
  _AppIcon(id: 11, name: 'Files',    icon: Icons.folder,          color: Color(0xFF007AFF)),
  _AppIcon(id: 12, name: 'Contacts', icon: Icons.contacts,        color: Color(0xFF34C759)),
  _AppIcon(id: 13, name: 'FaceTime', icon: Icons.video_call,      color: Color(0xFF34C759)),
  _AppIcon(id: 14, name: 'Messages', icon: Icons.message,         color: Color(0xFF34C759)),
  _AppIcon(id: 15, name: 'Reminders',icon: Icons.checklist,       color: Color(0xFFFF3B30)),
  _AppIcon(id: 16, name: 'Weather',  icon: Icons.wb_sunny,        color: Color(0xFF007AFF)),
  _AppIcon(id: 17, name: 'Stocks',   icon: Icons.show_chart,      color: Color(0xFF1C1C1E)),
  _AppIcon(id: 18, name: 'Books',    icon: Icons.book,            color: Color(0xFFFF9500)),
  _AppIcon(id: 19, name: 'Podcasts', icon: Icons.podcasts,        color: Color(0xFFAF52DE)),
  _AppIcon(id: 20, name: 'TV',       icon: Icons.tv,              color: Color(0xFF1C1C1E)),
  _AppIcon(id: 21, name: 'News',     icon: Icons.newspaper,       color: Color(0xFFFF3B30)),
  _AppIcon(id: 22, name: 'Health',   icon: Icons.favorite,        color: Color(0xFFFF2D55)),
  _AppIcon(id: 23, name: 'Wallet',   icon: Icons.account_balance_wallet, color: Color(0xFF1C1C1E)),
  _AppIcon(id: 24, name: 'App Store',icon: Icons.store,           color: Color(0xFF007AFF)),
];

// ── Demo Widget ───────────────────────────────────────────────────────────────

class IPadDesktopDemo extends StatefulWidget {
  const IPadDesktopDemo({super.key});

  @override
  State<IPadDesktopDemo> createState() => _IPadDesktopDemoState();
}

class _IPadDesktopDemoState extends State<IPadDesktopDemo> {
  // 网格和 Dock 各自的 LayoutManager / Adapter / AnimatorController
  final _gridHolder = ServiceHolder<LayoutManager>();
  final _dockHolder = ServiceHolder<LayoutManager>();

  late ListAdapter<_AppIcon> _gridAdapter;
  late ListAdapter<_AppIcon> _dockAdapter;
  late ItemAnimatorController _gridAnimator;
  late ItemAnimatorController _dockAnimator;

  final _dragManager = DragManager<_AppIcon>(
    flyConfig: const CurveConfig(curve: Curves.easeInOut, durationMs: 250),
  );

  // 拖拽 hover 时的插入占位 index
  int? _gridInsertIndex;
  int? _dockInsertIndex;

  // DropTarget bounds
  final _gridBounds = ValueNotifier<Rect>(Rect.zero);
  final _dockBounds = ValueNotifier<Rect>(Rect.zero);
  final _gridKey = GlobalKey();
  final _dockKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // 前4个放 Dock，其余放网格
    _dockAdapter = ListAdapter<_AppIcon>(
      items: _appIcons.take(4).toList(),
      idExtractor: (e) => e.id,
    );
    _gridAdapter = ListAdapter<_AppIcon>(
      items: _appIcons.skip(4).toList(),
      idExtractor: (e) => e.id,
    );
    _gridAnimator = ItemAnimatorController(
      layoutManagerHolder: _gridHolder,
      curveConfig: const CurveConfig(curve: Curves.easeInOut, durationMs: 300),
    );
    _dockAnimator = ItemAnimatorController(
      layoutManagerHolder: _dockHolder,
      curveConfig: const CurveConfig(curve: Curves.easeInOut, durationMs: 300),
    );
    _gridAdapter.addListener(() => setState(() {}));
    _dockAdapter.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _gridAdapter.dispose();
    _dockAdapter.dispose();
    _gridAnimator.dispose();
    _dockAnimator.dispose();
    _dragManager.dispose();
    _gridBounds.dispose();
    _dockBounds.dispose();
    super.dispose();
  }

  void _updateBounds() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gridBounds.value = _rectOf(_gridKey);
      _dockBounds.value = _rectOf(_dockKey);
    });
  }

  Rect _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Rect.zero;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  // ── 网格 drop 逻辑 ──────────────────────────────────────────────────────────

  int _gridIndexAt(Offset localOffset, double iconSize, double spacing) {
    final col = (localOffset.dx / (iconSize + spacing)).floor().clamp(0, _gridColumns - 1);
    final row = (localOffset.dy / (iconSize + spacing)).floor().clamp(0, 999);
    return (row * _gridColumns + col).clamp(0, _gridAdapter.itemCount);
  }

  DropResult _onDropToGrid(_AppIcon data, Offset localOffset) {
    final iconSize = _currentIconSize;
    final spacing = _currentSpacing;
    final insertIndex = _gridIndexAt(localOffset, iconSize, spacing).clamp(0, _gridAdapter.itemCount);
    final target = _gridItemCenter(insertIndex, iconSize, spacing);
    return DropResult.accept(target);
  }

  void _onDropCompletedGrid(_AppIcon data) {
    final iconSize = _currentIconSize;
    final spacing = _currentSpacing;
    final insertIndex = (_gridInsertIndex ?? _gridAdapter.itemCount).clamp(0, _gridAdapter.itemCount);

    setState(() {
      _gridInsertIndex = null;
      _dockInsertIndex = null;
    });

    // 从 Dock 移到网格
    final fromDock = _dockAdapter.findChildIndex(data.id.toString()) != null;
    if (fromDock) {
      final dockIdx = _dockAdapter.findChildIndex(data.id.toString())!;
      _dockAnimator.performLayoutAnimations(adapter: _dockAdapter, removeIndexes: [dockIdx]);
      _dockAdapter.removeAt(dockIdx);
    }

    // 网格内重排
    final existingIdx = _gridAdapter.findChildIndex(data.id.toString());
    if (existingIdx != null) {
      final targetIdx = insertIndex > existingIdx ? insertIndex - 1 : insertIndex;
      if (existingIdx == targetIdx) return;
      final newOrder = <_AppIcon>[];
      for (int i = 0; i < _gridAdapter.itemCount; i++) newOrder.add(_gridAdapter.getItem(i));
      final item = newOrder.removeAt(existingIdx);
      newOrder.insert(targetIdx, item);
      final diff = _gridAdapter.diffItems(newOrder);
      _gridAnimator.performLayoutAnimations(
        adapter: _gridAdapter,
        moveIndexes: diff.moveIndexes,
        itemSize: Size(iconSize, iconSize),
        itemSpacing: Size(spacing, spacing),
      );
      _gridAdapter.applyDiff(newOrder);
    } else {
      _gridAnimator.performLayoutAnimations(
        adapter: _gridAdapter,
        addIndexes: [insertIndex],
        itemSize: Size(iconSize, iconSize),
        itemSpacing: Size(spacing, spacing),
      );
      _gridAdapter.addItem(data, index: insertIndex);
    }
  }

  // ── Dock drop 逻辑 ──────────────────────────────────────────────────────────

  int _dockIndexAt(Offset localOffset) {
    const leftPadding = 16.0;
    const stride = _dockIconSize + 12.0;
    final x = localOffset.dx - leftPadding;
    return (x / stride).round().clamp(0, _dockAdapter.itemCount);
  }

  DropResult _onDropToDock(_AppIcon data, Offset localOffset) {
    final alreadyInDock = _dockAdapter.findChildIndex(data.id.toString()) != null;
    if (!alreadyInDock && _dockAdapter.itemCount >= _dockMaxItems) {
      return const DropResult.reject();
    }
    final insertIndex = _dockIndexAt(localOffset);
    final target = _dockItemCenter(insertIndex);
    return DropResult.accept(target);
  }

  void _onDropCompletedDock(_AppIcon data) {
    final insertIndex = (_dockInsertIndex ?? _dockAdapter.itemCount).clamp(0, _dockAdapter.itemCount);

    setState(() {
      _gridInsertIndex = null;
      _dockInsertIndex = null;
    });

    // 从网格移到 Dock
    final fromGrid = _gridAdapter.findChildIndex(data.id.toString()) != null;
    if (fromGrid) {
      final gridIdx = _gridAdapter.findChildIndex(data.id.toString())!;
      final iconSize = _currentIconSize;
      final spacing = _currentSpacing;
      _gridAnimator.performLayoutAnimations(
        adapter: _gridAdapter,
        removeIndexes: [gridIdx],
        itemSize: Size(iconSize, iconSize),
        itemSpacing: Size(spacing, spacing),
      );
      _gridAdapter.removeAt(gridIdx);
    }

    // Dock 内重排
    final existingIdx = _dockAdapter.findChildIndex(data.id.toString());
    if (existingIdx != null) {
      final targetIdx = insertIndex > existingIdx ? insertIndex - 1 : insertIndex;
      if (existingIdx == targetIdx) return;
      final newOrder = <_AppIcon>[];
      for (int i = 0; i < _dockAdapter.itemCount; i++) newOrder.add(_dockAdapter.getItem(i));
      final item = newOrder.removeAt(existingIdx);
      newOrder.insert(targetIdx, item);
      final diff = _dockAdapter.diffItems(newOrder);
      _dockAnimator.performLayoutAnimations(
        adapter: _dockAdapter,
        moveIndexes: diff.moveIndexes,
      );
      _dockAdapter.applyDiff(newOrder);
    } else {
      _dockAnimator.performLayoutAnimations(
        adapter: _dockAdapter,
        addIndexes: [insertIndex],
      );
      _dockAdapter.addItem(data, index: insertIndex);
    }
  }

  // ── 位置计算辅助 ────────────────────────────────────────────────────────────

  double _currentIconSize = 72.0;
  double _currentSpacing = 12.0;

  Offset _gridItemCenter(int index, double iconSize, double spacing) {
    final bounds = _gridBounds.value;
    final col = index % _gridColumns;
    final row = index ~/ _gridColumns;
    final x = bounds.left + col * (iconSize + spacing) + iconSize / 2;
    final y = bounds.top + row * (iconSize + spacing) + iconSize / 2;
    return Offset(x, y);
  }

  Offset _dockItemCenter(int index) {
    final bounds = _dockBounds.value;
    final stride = _dockIconSize + 12.0;
    final totalWidth = _dockAdapter.itemCount * stride - 12.0;
    final startX = bounds.left + (bounds.width - totalWidth) / 2;
    return Offset(startX + index * stride + _dockIconSize / 2, bounds.center.dy);
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _updateBounds();
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            // 网格区域
            Expanded(child: _buildGrid()),
            // Dock
            _buildDock(),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(builder: (context, constraints) {
      final W = constraints.maxWidth;
      final spacing = W * 0.015;
      final iconSize = (W - spacing * (_gridColumns + 1)) / _gridColumns;
      _currentIconSize = iconSize;
      _currentSpacing = spacing;

      final edgeSpacing = EdgeInsets.all(spacing);
      final itemSpacing = Size(spacing, spacing);
      final itemSize = Size(iconSize, iconSize);

      return DropTarget<_AppIcon>(
        dragManager: _dragManager,
        boundsListenable: _gridBounds,
        onEnter: (_) {},
        onMove: (data, offset) {
          final idx = _gridIndexAt(offset, iconSize, spacing).clamp(0, _gridAdapter.itemCount);
          if (_gridInsertIndex != idx) setState(() => _gridInsertIndex = idx);
        },
        onExit: (_) => setState(() => _gridInsertIndex = null),
        onDrop: _onDropToGrid,
        onDropBack: (_) => setState(() { _gridInsertIndex = null; _dockInsertIndex = null; }),
        onDropCompleted: _onDropCompletedGrid,
        child: LayoutableListWidget(
          key: _gridKey,
          itemSize: itemSize,
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(),
          layoutManagerHolder: _gridHolder,
          edgeSpacing: edgeSpacing,
          itemSpacing: itemSpacing,
          layoutAlgorithm: GridLayoutAlgorithm(
            scrollDirection: Axis.vertical,
            spanCount: _gridColumns,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              // 插入占位
              if (_gridInsertIndex != null && index == _gridInsertIndex) {
                return _buildPlaceholder(iconSize);
              }
              final itemIndex = _gridInsertIndex != null && index > _gridInsertIndex! ? index - 1 : index;
              if (itemIndex >= _gridAdapter.itemCount) return const SizedBox.shrink();
              final item = _gridAdapter.getItem(itemIndex);
              final itemId = _gridAdapter.getItemId(itemIndex);
              return KeyedSubtree(
                key: ValueKey(itemId),
                child: ItemDraggable<_AppIcon>(
                  dragManager: _dragManager,
                  data: item,
                  shadowBuilder: (_) => _buildIconWidget(item, size: iconSize, shadow: true),
                  child: ItemAnimator(
                    key: ValueKey('ganim_$itemId'),
                    itemId: itemId,
                    paramsNotifier: _gridAnimator.listenAnimatorParams(itemId, itemIndex),
                    layoutParamsListenable: _gridHolder.target!.listenLayoutParamsForPosition(itemIndex),
                    onDispose: _gridAnimator.onItemUnmounted,
                    child: _buildIconWidget(item, size: iconSize),
                  ),
                ),
              );
            },
            childCount: _gridAdapter.itemCount + (_gridInsertIndex != null ? 1 : 0),
            findChildIndexCallback: (key) {
              final id = (key as ValueKey<String>).value;
              final idx = _gridAdapter.findChildIndex(id);
              if (idx == null) return null;
              if (_gridInsertIndex != null && idx >= _gridInsertIndex!) return idx + 1;
              return idx;
            },
          ),
        ),
      );
    });
  }

  Widget _buildDock() {
    return Container(
      height: _dockHeight,
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: DropTarget<_AppIcon>(
        dragManager: _dragManager,
        boundsListenable: _dockBounds,
        onEnter: (_) {},
        onMove: (data, offset) {
          final idx = _dockIndexAt(offset).clamp(0, _dockAdapter.itemCount);
          if (_dockInsertIndex != idx) setState(() => _dockInsertIndex = idx);
        },
        onExit: (_) => setState(() => _dockInsertIndex = null),
        onDrop: _onDropToDock,
        onDropBack: (_) => setState(() { _gridInsertIndex = null; _dockInsertIndex = null; }),
        onDropCompleted: _onDropCompletedDock,
        // SizedBox 强制高度，使 crossAxisExtent == _dockHeight，FlexLayoutAlgorithm 居中计算正确
        child: SizedBox(
          height: _dockHeight,
          child: LayoutableListWidget(
            key: _dockKey,
            // itemSize 高度设为 _dockHeight，item 撑满交叉轴，内部自己居中内容
            itemSize: const Size(_dockIconSize, _dockHeight),
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            layoutManagerHolder: _dockHolder,
            edgeSpacing: const EdgeInsets.symmetric(horizontal: 16),
            itemSpacing: const Size(12, 0),
            layoutAlgorithm: FlexLayoutAlgorithm(
              direction: Axis.horizontal,
              justifyContent: FlexJustifyContent.center,
              alignItems: FlexAlignItems.center,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (_dockInsertIndex != null && index == _dockInsertIndex) {
                  return _buildPlaceholder(_dockIconSize);
                }
                final itemIndex = _dockInsertIndex != null && index > _dockInsertIndex! ? index - 1 : index;
                if (itemIndex >= _dockAdapter.itemCount) return const SizedBox.shrink();
                final item = _dockAdapter.getItem(itemIndex);
                final itemId = _dockAdapter.getItemId(itemIndex);
                return KeyedSubtree(
                  key: ValueKey(itemId),
                  child: ItemDraggable<_AppIcon>(
                    dragManager: _dragManager,
                    data: item,
                    shadowSize: const Size(_dockIconSize, _dockIconSize),
                    shadowBuilder: (_) => _buildDockIconWidget(item, shadow: true),
                    child: ItemAnimator(
                      key: ValueKey('danim_$itemId'),
                      itemId: itemId,
                      paramsNotifier: _dockAnimator.listenAnimatorParams(itemId, itemIndex),
                      layoutParamsListenable: _dockHolder.target!.listenLayoutParamsForPosition(itemIndex),
                      onDispose: _dockAnimator.onItemUnmounted,
                      child: Center(child: _buildDockIconWidget(item)),
                    ),
                  ),
                );
              },
              childCount: _dockAdapter.itemCount + (_dockInsertIndex != null ? 1 : 0),
              findChildIndexCallback: (key) {
                final id = (key as ValueKey<String>).value;
                final idx = _dockAdapter.findChildIndex(id);
                if (idx == null) return null;
                if (_dockInsertIndex != null && idx >= _dockInsertIndex!) return idx + 1;
                return idx;
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
          borderRadius: BorderRadius.circular(size * 0.18),
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
    );
  }

  // 网格图标：正方形，图标+文字叠在一起
  Widget _buildIconWidget(_AppIcon item, {required double size, bool shadow = false}) {
    return SizedBox(
      width: size,
      height: size,
      child: Opacity(
        opacity: shadow ? 0.85 : 1.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: size * 0.72,
              height: size * 0.72,
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: BorderRadius.circular(size * 0.18),
                boxShadow: shadow
                    ? [const BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4))]
                    : null,
              ),
              child: Icon(item.icon, color: Colors.white, size: size * 0.4),
            ),
            const SizedBox(height: 3),
            Text(
              item.name,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.12,
                fontWeight: FontWeight.w500,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Dock 图标：固定尺寸，只显示图标
  Widget _buildDockIconWidget(_AppIcon item, {bool shadow = false}) {
    return SizedBox(
      width: _dockIconSize,
      height: _dockIconSize,
      child: Opacity(
        opacity: shadow ? 0.85 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: item.color,
            borderRadius: BorderRadius.circular(_dockIconSize * 0.22),
            boxShadow: shadow
                ? [const BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4))]
                : null,
          ),
          child: Icon(item.icon, color: Colors.white, size: _dockIconSize * 0.5),
        ),
      ),
    );
  }
}
