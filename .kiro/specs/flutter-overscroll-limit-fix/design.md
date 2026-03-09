# Flutter Overscroll Limit Fix - Bugfix Design

## Overview

在 Flutter 滚动列表的 `LimitedOverscrollPhysics` 实现中，用户快速滑动（fling）松手后，卡片会冲出远超 60 像素的限制范围（观察到 -785、2393 像素等）。虽然用户拖动时的限制工作正常，但惯性滚动的限制失效。

当前实现尝试通过预测 `BouncingScrollSimulation` 的最终位置并按比例减小速度来限制 overscroll，但这种方法存在根本性缺陷：`BouncingScrollSimulation` 根据弹性物理规律自由运动，无法保证停留在指定的限制范围内。

修复策略是：当预测到惯性滚动会超出 60 像素限制时，不再使用速度调整的 `BouncingScrollSimulation`，而是直接使用 `ScrollSpringSimulation` 并明确指定目标位置为边界加上允许的 overscroll（`minScrollExtent - maxOverscrollExtent` 或 `maxScrollExtent + maxOverscrollExtent`）。这样可以确保动画精确停留在限制边界，同时保持平滑的视觉效果。

## Glossary

- **Bug_Condition (C)**: 用户快速滑动松手且预测的惯性滚动会超出 60 像素 overscroll 限制的条件
- **Property (P)**: 惯性滚动应该平滑地停留在限制边界内（最大 overscroll 不超过 60 像素）
- **Preservation**: 用户拖动时的限制、正常范围内的弹性滚动、已超限时的回弹行为必须保持不变
- **BouncingScrollSimulation**: Flutter 的弹性滚动模拟，根据物理规律自由运动，会在边界处产生回弹效果
- **ScrollSpringSimulation**: Flutter 的弹簧动画模拟，从起始位置平滑过渡到指定的目标位置
- **maxOverscrollExtent**: 允许的最大 overscroll 距离（当前为 60 像素）
- **createBallisticSimulation**: ScrollPhysics 中的方法，在用户松手后创建惯性滚动动画
- **applyPhysicsToUserOffset**: ScrollPhysics 中的方法，在用户拖动时应用摩擦力和限制

## Bug Details

### Fault Condition

当用户快速滑动松手后，`createBallisticSimulation` 方法预测到惯性滚动会超出 60 像素限制，但使用了错误的修复策略：按比例减小速度后仍使用 `BouncingScrollSimulation`。由于 `BouncingScrollSimulation` 根据弹性物理规律自由运动，即使减小了初始速度，也无法保证最终停留在限制范围内。

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type {position: ScrollMetrics, velocity: double}
  OUTPUT: boolean
  
  // 计算当前 overscroll
  overscrollPastStart := max(position.minScrollExtent - position.pixels, 0.0)
  overscrollPastEnd := max(position.pixels - position.maxScrollExtent, 0.0)
  currentOverscroll := max(overscrollPastStart, overscrollPastEnd)
  
  // 创建临时 simulation 预测最终位置
  testSimulation := BouncingScrollSimulation(
    position: position.pixels,
    velocity: velocity,
    leadingExtent: position.minScrollExtent,
    trailingExtent: position.maxScrollExtent,
    spring: spring,
    tolerance: tolerance
  )
  
  predictedX := testSimulation.x(0.5)  // 预测 0.5 秒后的位置
  predictedOverscroll := predictedX < position.minScrollExtent
      ? position.minScrollExtent - predictedX
      : max(0, predictedX - position.maxScrollExtent)
  
  RETURN currentOverscroll <= maxOverscrollExtent
         AND predictedOverscroll > maxOverscrollExtent
         AND velocity.abs() >= tolerance.velocity
END FUNCTION
```

### Examples

- **向上快速滑动超限**: 用户在列表顶部快速向上滑动，松手时 velocity = -3000，预测会到达 -785 像素（超出 minScrollExtent 785 像素），但当前实现只是减小速度后仍使用 `BouncingScrollSimulation`，最终仍冲出到 -785 像素附近
- **向下快速滑动超限**: 用户在列表底部快速向下滑动，松手时 velocity = 5000，预测会到达 2393 像素（超出 maxScrollExtent 2393 像素），当前实现减小速度后仍使用 `BouncingScrollSimulation`，最终仍冲出到 2393 像素附近
- **中等速度滑动**: 用户滑动速度 velocity = 1500，预测 overscroll 为 80 像素（略超 60 像素限制），当前实现减小速度后使用 `BouncingScrollSimulation`，最终可能冲出到 70-90 像素范围
- **边界情况 - 预测刚好不超限**: velocity = 800，预测 overscroll 为 55 像素（未超限），应该继续使用 `BouncingScrollSimulation` 提供自然的弹性体验

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- 用户拖动时，`applyPhysicsToUserOffset` 必须继续正确限制 overscroll 在 60 像素内
- 用户滑动且预测不会超出 60 像素限制时，必须继续使用 `BouncingScrollSimulation` 提供自然的弹性滚动体验
- 当前位置已超过限制（currentOverscroll > maxOverscrollExtent）时，必须继续创建 `ScrollSpringSimulation` 回弹到正常边界
- 速度太小且在正常范围内时，必须继续返回 null，不创建 simulation
- 用户在正常滚动范围内操作时，必须保持滚动的"跟手"感觉和平滑自然的动画效果
- Spring 配置（mass: 0.3, stiffness: 75.0, ratio: 1.8）必须保持不变，确保平滑动画

**Scope:**
所有不涉及"快速滑动且预测会超出 60 像素限制"的输入都应该完全不受此修复影响。这包括：
- 用户拖动操作（由 `applyPhysicsToUserOffset` 处理）
- 慢速滑动（预测不会超限）
- 已经超限的回弹（currentOverscroll > maxOverscrollExtent）
- 正常范围内的滚动

## Hypothesized Root Cause

基于 bug 描述和代码分析，最可能的问题是：

1. **错误的修复策略**: 当前实现尝试通过减小速度来限制 `BouncingScrollSimulation` 的 overscroll，但这是不可靠的
   - `BouncingScrollSimulation` 根据弹性物理规律自由运动，没有明确的目标位置
   - 即使减小初始速度，物理模拟仍可能因为弹簧参数、阻尼等因素导致超出预期范围
   - 速度缩放系数（0.7）是经验值，无法精确控制最终位置

2. **预测不准确**: 使用 0.5 秒时间点预测最终位置可能不够准确
   - `BouncingScrollSimulation` 的运动轨迹是非线性的，0.5 秒可能不是最大 overscroll 的时刻
   - 不同速度下，达到最大 overscroll 的时间不同

3. **缺少明确的目标位置**: 当前实现没有为超限情况指定明确的停止位置
   - 应该使用 `ScrollSpringSimulation` 并指定目标为 `minScrollExtent - maxOverscrollExtent` 或 `maxScrollExtent + maxOverscrollExtent`
   - 这样可以确保动画精确停留在限制边界

## Correctness Properties

Property 1: Fault Condition - 惯性滚动限制在 60 像素内

_For any_ 输入（position, velocity）满足 bug 条件（快速滑动且预测会超出 60 像素限制），修复后的 `createBallisticSimulation` 方法 SHALL 创建 `ScrollSpringSimulation` 并指定目标位置为 `minScrollExtent - maxOverscrollExtent` 或 `maxScrollExtent + maxOverscrollExtent`，确保惯性滚动平滑停留在限制边界内，最大 overscroll 不超过 60 像素。

**Validates: Requirements 2.1, 2.2**

Property 2: Preservation - 非超限情况的行为保持不变

_For any_ 输入（position, velocity）不满足 bug 条件（拖动操作、慢速滑动、已超限回弹、正常范围滚动），修复后的代码 SHALL 产生与原始代码完全相同的行为，保持用户拖动时的限制、正常弹性滚动体验、已超限时的回弹动画、以及平滑自然的滚动感觉。

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**

## Fix Implementation

### Changes Required

假设我们的根因分析正确：

**File**: `lib/recents/limited_overscroll_physics.dart`

**Function**: `createBallisticSimulation`

**Specific Changes**:

1. **修改超限预测的处理逻辑**: 当预测到会超出限制时，不再使用速度调整的 `BouncingScrollSimulation`
   - 删除当前的速度缩放逻辑（`adjustedVelocity = velocity * scale`）
   - 改为直接创建 `ScrollSpringSimulation`

2. **指定明确的目标位置**: 计算目标位置为边界加上允许的 overscroll
   - 如果向上滑动（velocity < 0）：目标位置 = `minScrollExtent - maxOverscrollExtent`
   - 如果向下滑动（velocity > 0）：目标位置 = `maxScrollExtent + maxOverscrollExtent`

3. **合理调整传入的速度**: 避免 `ScrollSpringSimulation` 过度震荡
   - 如果速度过大（例如 > 3000），可以适当缩减到合理范围（例如 2000-2500）
   - 保持速度方向不变，只调整幅度
   - 这样可以保持动画的流畅性，同时避免过度震荡

4. **保持现有的 spring 配置**: 确保平滑动画
   - 继续使用 `mass: 0.3, stiffness: 75.0, ratio: 1.8`
   - 这些参数已经过调优，能提供良好的视觉效果

5. **保持其他逻辑不变**: 确保不影响其他场景
   - 速度太小且在范围内时，继续返回 null
   - 当前已超限时，继续创建回弹到正常边界的 `ScrollSpringSimulation`
   - 预测不会超限时，继续使用 `BouncingScrollSimulation`

### Pseudocode for Fixed Logic

```
FUNCTION createBallisticSimulation_fixed(position, velocity)
  tolerance := toleranceFor(position)
  
  // 1. 速度太小且在范围内，不需要 simulation
  IF velocity.abs() < tolerance.velocity AND NOT position.outOfRange THEN
    RETURN null
  END IF
  
  // 2. 计算当前 overscroll
  overscrollPastStart := max(position.minScrollExtent - position.pixels, 0.0)
  overscrollPastEnd := max(position.pixels - position.maxScrollExtent, 0.0)
  currentOverscroll := max(overscrollPastStart, overscrollPastEnd)
  
  // 3. 如果当前已经超过限制，回弹到正常边界
  IF currentOverscroll > maxOverscrollExtent THEN
    targetPosition := overscrollPastStart > 0 
        ? position.minScrollExtent
        : position.maxScrollExtent
    
    adjustedVelocity := velocity
    IF velocity.abs() > 1000 THEN
      velocityScale := max(0.2, 1.0 - (velocity.abs() - 1000) / 15000)
      adjustedVelocity := velocity * velocityScale
    END IF
    
    RETURN ScrollSpringSimulation(
      spring, position.pixels, targetPosition, adjustedVelocity, tolerance
    )
  END IF
  
  // 4. 预测惯性滚动的最终位置
  testSimulation := BouncingScrollSimulation(
    position.pixels, velocity,
    position.minScrollExtent, position.maxScrollExtent,
    spring, tolerance
  )
  
  predictedX := testSimulation.x(0.5)
  predictedOverscroll := predictedX < position.minScrollExtent
      ? position.minScrollExtent - predictedX
      : max(0, predictedX - position.maxScrollExtent)
  
  // 5. 如果预测会超出限制，使用 ScrollSpringSimulation 到限制边界
  IF predictedOverscroll > maxOverscrollExtent THEN
    // 计算目标位置：边界 + 允许的 overscroll
    targetPosition := predictedX < position.minScrollExtent
        ? position.minScrollExtent - maxOverscrollExtent
        : position.maxScrollExtent + maxOverscrollExtent
    
    // 调整速度，避免过度震荡
    adjustedVelocity := velocity
    IF velocity.abs() > 3000 THEN
      adjustedVelocity := velocity.sign * min(velocity.abs(), 2500)
    END IF
    
    RETURN ScrollSpringSimulation(
      spring, position.pixels, targetPosition, adjustedVelocity, tolerance
    )
  END IF
  
  // 6. 预测不会超限，使用正常的 BouncingScrollSimulation
  RETURN BouncingScrollSimulation(
    position.pixels, velocity,
    position.minScrollExtent, position.maxScrollExtent,
    spring, tolerance
  )
END FUNCTION
```

## Testing Strategy

### Validation Approach

测试策略遵循两阶段方法：首先在未修复的代码上运行探索性测试，观察 bug 的具体表现并确认根因分析；然后在修复后的代码上验证修复效果和行为保持。

### Exploratory Fault Condition Checking

**Goal**: 在实施修复之前，在未修复的代码上演示 bug。确认或反驳根因分析。如果反驳，需要重新假设根因。

**Test Plan**: 编写测试模拟快速滑动场景，在未修复的代码上运行，观察实际的 overscroll 距离是否远超 60 像素限制。记录具体的失败模式和数值。

**Test Cases**:
1. **向上快速滑动测试**: 模拟在列表顶部快速向上滑动（velocity = -3000），观察最终 overscroll 是否远超 60 像素（预期在未修复代码上会失败，可能达到 -785 像素）
2. **向下快速滑动测试**: 模拟在列表底部快速向下滑动（velocity = 5000），观察最终 overscroll 是否远超 60 像素（预期在未修复代码上会失败，可能达到 2393 像素）
3. **中等速度滑动测试**: 模拟中等速度滑动（velocity = 1500），观察最终 overscroll 是否略超 60 像素（预期在未修复代码上会失败，可能达到 70-90 像素）
4. **边界速度测试**: 模拟刚好不超限的速度（velocity = 800），观察是否使用了 `BouncingScrollSimulation` 且未超限（预期在未修复代码上应该通过）

**Expected Counterexamples**:
- 快速滑动时，最终 overscroll 远超 60 像素限制（-785、2393 等）
- 可能的原因：速度缩放不准确、`BouncingScrollSimulation` 无法精确控制最终位置、预测时间点不准确

### Fix Checking

**Goal**: 验证对于所有满足 bug 条件的输入，修复后的函数产生预期行为（最大 overscroll 不超过 60 像素）。

**Pseudocode:**
```
FOR ALL input (position, velocity) WHERE isBugCondition(input) DO
  simulation := createBallisticSimulation_fixed(position, velocity)
  
  // 模拟运行 simulation，找到最大 overscroll
  maxOverscroll := 0
  FOR t FROM 0 TO 2.0 STEP 0.01 DO
    x := simulation.x(t)
    overscroll := x < position.minScrollExtent
        ? position.minScrollExtent - x
        : max(0, x - position.maxScrollExtent)
    maxOverscroll := max(maxOverscroll, overscroll)
  END FOR
  
  ASSERT maxOverscroll <= maxOverscrollExtent + tolerance
  ASSERT simulation is ScrollSpringSimulation
END FOR
```

### Preservation Checking

**Goal**: 验证对于所有不满足 bug 条件的输入，修复后的函数产生与原始函数相同的结果。

**Pseudocode:**
```
FOR ALL input (position, velocity) WHERE NOT isBugCondition(input) DO
  originalSim := createBallisticSimulation_original(position, velocity)
  fixedSim := createBallisticSimulation_fixed(position, velocity)
  
  // 比较 simulation 类型
  ASSERT type(originalSim) = type(fixedSim)
  
  // 如果都不是 null，比较运动轨迹
  IF originalSim IS NOT null AND fixedSim IS NOT null THEN
    FOR t FROM 0 TO 1.0 STEP 0.05 DO
      ASSERT abs(originalSim.x(t) - fixedSim.x(t)) < tolerance
      ASSERT abs(originalSim.dx(t) - fixedSim.dx(t)) < tolerance
    END FOR
  END IF
END FOR
```

**Testing Approach**: 推荐使用基于属性的测试（Property-Based Testing）进行保持性检查，因为：
- 它自动生成大量测试用例覆盖输入域
- 它能捕获手动单元测试可能遗漏的边界情况
- 它为所有非 bug 输入提供强有力的行为不变保证

**Test Plan**: 首先在未修复的代码上观察拖动、慢速滑动、已超限回弹等场景的行为，然后编写基于属性的测试捕获这些行为，确保修复后保持不变。

**Test Cases**:
1. **拖动限制保持**: 观察未修复代码上用户拖动时的限制行为，验证修复后 `applyPhysicsToUserOffset` 继续正确限制 overscroll 在 60 像素内
2. **慢速滑动保持**: 观察未修复代码上慢速滑动（velocity < 1000）的弹性行为，验证修复后继续使用 `BouncingScrollSimulation` 且行为一致
3. **已超限回弹保持**: 观察未修复代码上当前已超限时的回弹行为，验证修复后继续创建回弹到正常边界的 `ScrollSpringSimulation`
4. **正常范围滚动保持**: 观察未修复代码上正常范围内的滚动行为，验证修复后保持相同的平滑感觉

### Unit Tests

- 测试快速滑动场景（velocity = -3000, 5000）的 overscroll 限制
- 测试中等速度滑动场景（velocity = 1500）的 overscroll 限制
- 测试边界情况（velocity 刚好不超限）继续使用 `BouncingScrollSimulation`
- 测试已超限情况继续回弹到正常边界
- 测试速度太小情况继续返回 null
- 测试速度调整逻辑（velocity > 3000 时缩减到 2500）

### Property-Based Tests

- 生成随机的 position 和 velocity，验证满足 bug 条件时使用 `ScrollSpringSimulation` 且 overscroll 不超过 60 像素
- 生成随机的慢速滑动场景，验证继续使用 `BouncingScrollSimulation` 且行为与原始代码一致
- 生成随机的拖动场景，验证 `applyPhysicsToUserOffset` 的限制行为保持不变
- 测试大量随机输入，确保修复不引入新的回归问题

### Integration Tests

- 测试完整的滚动流程：用户快速滑动 -> 松手 -> 惯性滚动 -> 停留在限制边界
- 测试不同 UI 上下文（列表顶部、底部、中间）的快速滑动行为
- 测试连续快速滑动的场景，验证每次都正确限制
- 测试视觉反馈：确保动画平滑，没有突兀的跳跃或震荡
