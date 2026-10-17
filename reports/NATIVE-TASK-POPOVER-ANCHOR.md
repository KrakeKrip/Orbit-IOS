# Меню длинного календарного блока — 2026-10-17

REVIEW. Владелец прислал физические screenshots: для многочасовой задачи popover снизу/сбоку за экраном. Изменены только shared TaskActionPopover и DayTimelineView.

Calendar включает anchorsAtTap: SpatialTapGesture считывает local point, размер Button измерен onGeometryChange, attachmentAnchor — normalized UnitPoint вместо bounds всего многочасового блока. Button открывает popover на следующем main-runloop после записи точки; существующий canOpen guard повторён (hold/resize не должны открыть меню). Native AX activation остаётся Button action, при отсутствии spatial tap используется текущий/default center anchor (AX для длинного частично видимого блока пока не проверен).

Для calendar arrowEdge=nil вместо принудительного.top: выбор направления передан системе. Совместимость проверена по локальному Xcode SDK SwiftUI.swiftinterface: public optional Edge API содержит fallback для прежних iOS, deployment target17 не повышался. List/untimed сохраняют bounds/top. Calendar menu height ограничен min520, viewportHeight−24 (floor140); content ScrollView и все восемь действий/preview/editor transitions сохранены. Ширина прежняя<=300pt. Shared frame теперь finite height вместо ideal/max, content остаётся scrollable.

Targeted device BUILD SUCCEEDED (/private/tmp/orbit-task-popover-anchor.log), diff --check PASS. Core/schema/persistence не менялись, core suite не повторялась. Реальный тап по верхней/нижней видимой части многочасового блока, крайняя правая lane, удержание/resize regression и AXL/VoiceOver требуют physical QA: CUA coordinate input в этой сессии повторно не использовался из-за подтверждённого ранее noWindowsAvailable. Это source/build verification, не visual pass. Main не merge/push.
