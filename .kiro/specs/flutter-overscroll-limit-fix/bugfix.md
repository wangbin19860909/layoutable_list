# Bugfix Requirements Document

## Introduction

在 Flutter 滚动列表的 `LimitedOverscrollPhysics` 实现中，用户快速滑动（fling）松手后，卡片会冲出远超 60 像素的限制范围（观察到 -785、2393 像素等）。虽然用户拖动时的限制工作正常，但惯性滚动的限制失效。此 bug 影响用户体验，导致卡片滚动超出预期的视觉边界。

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN 用户快速滑动松手且预测会超出 60 像素限制 THEN 系统使用 `BouncingScrollSimulation` 并按比例减小速度，但卡片仍冲出很远（-785、2393 像素等）

1.2 WHEN `createBallisticSimulation` 预测到会超出限制并调整速度后 THEN `BouncingScrollSimulation` 根据弹性物理规律自由运动，无法保证停留在 60 像素限制内

### Expected Behavior (Correct)

2.1 WHEN 用户快速滑动松手且预测会超出 60 像素限制 THEN 系统 SHALL 使用 `ScrollSpringSimulation` 并指定目标位置为 `minScrollExtent - maxOverscrollExtent` 或 `maxScrollExtent + maxOverscrollExtent`，确保最大 overscroll 不超过 60 像素

2.2 WHEN `createBallisticSimulation` 检测到惯性滚动会超出限制 THEN 系统 SHALL 创建平滑的回弹动画到限制边界，而不是依赖速度调整的 `BouncingScrollSimulation`

### Unchanged Behavior (Regression Prevention)

3.1 WHEN 用户拖动滚动列表 THEN 系统 SHALL CONTINUE TO 通过 `applyPhysicsToUserOffset` 正确限制 overscroll 在 60 像素内

3.2 WHEN 用户滑动且预测不会超出 60 像素限制 THEN 系统 SHALL CONTINUE TO 使用 `BouncingScrollSimulation` 提供自然的弹性滚动体验

3.3 WHEN 当前位置已超过限制（currentOverscroll > maxOverscrollExtent）THEN 系统 SHALL CONTINUE TO 创建 `ScrollSpringSimulation` 回弹到正常边界

3.4 WHEN 速度太小且在正常范围内 THEN 系统 SHALL CONTINUE TO 返回 null，不创建 simulation

3.5 WHEN 用户在正常滚动范围内操作 THEN 系统 SHALL CONTINUE TO 保持滚动的"跟手"感觉和平滑自然的动画效果
